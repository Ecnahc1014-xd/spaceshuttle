-- AchievementSystem.lua
-- 成就驱动层：把各系统的真实统计折算成成就进度，驱动 PlayerData 本地解锁，
-- 并把「新达成/新增步数」幂等外发到平台（sdk:UnlockAchievement / IncrementAchievement）。
--
-- ⚠️ 设计原则（承接 PLATFORM_CAPABILITY_MAP「成就/投影」）：
--   · **本地成就状态是唯一权威**——平台只是镜像。外发失败绝不影响本地解锁。
--   · **幂等外发**：用 PlayerData.achPushed 记录「已上报到平台的步数」，只上报新增部分；
--     换设备/重复进面板不会重复上报（平台侧 increment 是累加的，重复上报会超量）。
--   · 单步成就（steps==1）走 UnlockAchievement；多步成就走 IncrementAchievement。
--   · 平台 SDK 可能不存在（编辑器/离线）→ 全程 pcall，缺失只记日志。
--
-- 数据来源（全部只读 PlayerData / Game 快照）：stats.bricksTotal / runs / maxStage /
-- codex / talents / stageStars 汇总 / 皮肤与拖尾解锁数 / highScore。

local AchievementCatalog = require "AchievementCatalog"
local PlayerData = require "PlayerData"
local MetaCatalog = require "MetaCatalog"

local AchievementSystem = {}

-- 只读诊断计数（供探针自证外发通路）。
local pushAttempts_ = 0
local pushOk_ = 0
local pushFail_ = 0

---@return integer
function AchievementSystem.DebugPushAttempts() return pushAttempts_ end
---@return integer
function AchievementSystem.DebugPushOk() return pushOk_ end
---@return integer
function AchievementSystem.DebugPushFail() return pushFail_ end

-- 平台 SDK 是否可用（编辑器/离线可能没有成就能力）。
---@return boolean
local function SdkAvailable()
    local g = _G --[[@as table]]
    local s = g.sdk
    if type(s) ~= "table" then return false end
    return type(s.UnlockAchievement) == "function"
        and type(s.IncrementAchievement) == "function"
end

-- 把「某个成就的当前值」外发到平台（只发新增步数，幂等）。
-- 单步成就（steps==1）走 UnlockAchievement；多步走 IncrementAchievement。
---@param def AchievementDef
---@param currentValue integer 本地当前进度
local function PushToPlatform(def, currentValue)
    local pushed = PlayerData.GetAchievementPushed(def.id)
    local target = math.min(currentValue, def.steps)
    if target <= pushed then return end
    local delta = target - pushed
    if not SdkAvailable() then
        -- 平台不可用：**不**标记 pushed（下次有 SDK 时补发）；本地解锁不受影响。
        return
    end
    pushAttempts_ = pushAttempts_ + 1
    local ok, err = pcall(function()
        if def.steps <= 1 then
            sdk:UnlockAchievement(def.id)
        else
            sdk:IncrementAchievement(def.id, delta)
        end
    end)
    if ok then
        pushOk_ = pushOk_ + 1
        PlayerData.MarkAchievementPushed(def.id, target)
    else
        pushFail_ = pushFail_ + 1
        print("[Achievement] push failed " .. def.id .. ": " .. tostring(err))
    end
end

-- 计算某成就当前的真实值（从各系统统计折算）。
---@param id string
---@return integer
local function ComputeValue(id)
    if id == "first_blood" then
        return PlayerData.GetStat("bricksTotal") > 0 and 1 or 0
    elseif id == "first_win" then
        return PlayerData.GetStat("stageWins") > 0 and 1 or 0
    elseif id == "first_boss" then
        return PlayerData.GetStat("bossKills") > 0 and 1 or 0
    elseif id == "bricks_1k" or id == "bricks_10k" or id == "bricks_50k" then
        return PlayerData.GetStat("bricksTotal")
    elseif id == "stage_5" or id == "stage_10" or id == "stage_20" then
        return PlayerData.GetMaxStage()
    elseif id == "codex_5" or id == "codex_all" then
        return PlayerData.CodexCount()
    elseif id == "score_100k" or id == "score_500k" then
        return PlayerData.GetHighScore()
    elseif id == "runs_10" or id == "runs_50" then
        return PlayerData.GetStat("runsTotal")
    elseif id == "talent_10" or id == "talent_all" then
        return PlayerData.TalentCount()
    elseif id == "stars_45" then
        return PlayerData.GetTotalStars()
    elseif id == "skin_3" then
        local n = 0
        for _, s in ipairs(MetaCatalog.GetSkins()) do
            if s.cost == 0 or PlayerData.HasSkin(s.key) then n = n + 1 end
        end
        return n
    elseif id == "trail_3" then
        local n = 0
        for _, t in ipairs(MetaCatalog.GetTrails()) do
            if t.cost == 0 or PlayerData.HasTrail(t.key) then n = n + 1 end
        end
        return n
    elseif id == "pass_lv3" or id == "pass_lv5" or id == "pass_lv6" then
        -- v0.14.0：战斗档案里程碑——按当前档案等级（每 200 块升一级、满 6 级）。
        return PlayerData.GetPassLevel()
    end
    return 0
end

-- 全量重算所有成就（幂等）：读真实统计 → 更新本地 → 外发新增步数。
-- 返回本次新解锁的成就数（供 UI 提示）。
---@return integer newlyUnlocked
function AchievementSystem.Refresh()
    local newly = 0
    for _, def in ipairs(AchievementCatalog.GetAll()) do
        local value = ComputeValue(def.id)
        local wasUnlocked = PlayerData.IsAchievementUnlocked(def.id)
        local nowUnlocked = PlayerData.SetAchievementProgress(def.id, value, def.steps, true)
        if nowUnlocked and not wasUnlocked then newly = newly + 1 end
        -- 无论是否刚解锁，都尝试幂等外发（覆盖「上次 SDK 不可用、这次可用」的补发）。
        PushToPlatform(def, value)
    end
    if newly > 0 then PlayerData.Save() end
    return newly
end

-- 打开当前用户的原生成就页面（平台能力；不可用时返回 false 由调用方提示）。
---@return boolean
function AchievementSystem.ShowPlatformAchievements()
    if not SdkAvailable() or type(sdk.ShowAchievements) ~= "function" then return false end
    local ok = pcall(function() sdk:ShowAchievements() end)
    return ok
end

return AchievementSystem
