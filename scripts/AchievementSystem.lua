-- AchievementSystem.lua
-- 本地成就仍按真实统计重算，平台只是异步镜像；平台失败不挡本地解锁。
-- SDK 写接口没有单次回调/requestId/读进度 API，只能使用一个全局 listener。
-- 所以这不是 exactly-once：每个 id 每个 Lua 会话最多尝试一次（含 unlock），
-- 全局单在途；失败/不确定不重发，超时不释放在途槽、不盲重发。
-- attempted_ 跨 Shutdown/Init 保留，防旧宿主结果被新 listener 误认。
-- 新 Lua 会话只能从 achPushed 的已确认值重新考虑 delta；上次未知成功、
-- Save 失败/旧版虚假确认/跨设备并发仍无法消歧，不能承诺跨会话防重复。

local AchievementCatalog = require "AchievementCatalog"
local PlayerData = require "PlayerData"
local MetaCatalog = require "MetaCatalog"
local GameMode = require "GameMode"

local AchievementSystem = {}
local INT_MAX = 2147483647

---@class AchievementPushRequest
---@field id string
---@field operation AchievementOperation
---@field steps integer
---@field target integer 本次请求至少应达到的累计进度
---@field delta integer
---@field outcome table|nil 仅保存首个匹配的终态，Update 再确认

---@type table<string, boolean>
local attempted_ = {} -- 会话墓碑：绝不在 Shutdown 清空
local running_ = false
local poisoned_ = false -- 无法证明宿主请求已结束：本 Lua 会话不再派发
---@type table|nil
local lifetime_ = nil
---@type SDK|nil
local boundSdk_ = nil
local registrationTried_ = false
local listenerReady_ = false
---@type AchievementPushRequest|nil
local inFlight_ = nil

local pushAttempts_ = 0
local pushOk_ = 0
local pushFail_ = 0

---@return integer
function AchievementSystem.DebugPushAttempts() return pushAttempts_ end
---@return integer
function AchievementSystem.DebugPushOk() return pushOk_ end
---@return integer
function AchievementSystem.DebugPushFail() return pushFail_ end

-- void API 的 nil 返回值不是失败也不是成功；显式 false/异常才是未受理或不确定。
---@return SDK|nil
local function GetSdk()
    local g = _G --[[@as table]]
    local s = g.sdk
    if type(s) ~= "table" and type(s) ~= "userdata" then return nil end
    local ok, available = pcall(function()
        return type(s.UnlockAchievement) == "function"
            and type(s.IncrementAchievement) == "function"
            and type(s.RegisterAchievementListener) == "function"
            and type(s.UnregisterAchievementListener) == "function"
    end)
    if not ok or not available then return nil end
    return s --[[@as SDK]]
end

---@param value any
---@return integer|nil
local function ValidStep(value)
    if type(value) ~= "number" then return nil end
    -- tointeger 同时拒绝 NaN、无穷、非整值和超出 Lua integer 的值；不接受数字字符串。
    local step = math.tointeger(value)
    if not step or step < 0 then return nil end
    return step
end

-- 只缓存结果，不在 listener 中派发下一笔，也不让同步 callback 越过返回 false 的检查。
---@param token table
---@param id any
---@param operation any
---@param outcome table
local function Receive(token, id, operation, outcome)
    if not running_ or token ~= lifetime_ or not boundSdk_ then return end
    local g = _G --[[@as table]]
    if g.sdk ~= boundSdk_ then return end
    local request = inFlight_
    if not request or request.outcome or id ~= request.id then return end
    if operation ~= request.operation then return end
    request.outcome = outcome
end

-- 不调用其它模块的 listener，不订阅 Update；编排层独占接线。
---@return boolean listenerReady
function AchievementSystem.Init()
    if not running_ then
        running_ = true
        lifetime_ = {}
        registrationTried_ = false
        listenerReady_ = false
    end
    if GameMode.IsOffline() then return false end
    if registrationTried_ then
        return listenerReady_ and not poisoned_ and boundSdk_ == GetSdk()
    end
    if poisoned_ then return false end
    local s = GetSdk()
    if not s then return false end -- SDK 尚未就绪可以之后 Init/Update 再检查
    registrationTried_ = true
    boundSdk_ = s
    local token = lifetime_ --[[@as table]]
    local ok, accepted = pcall(function()
        return s:RegisterAchievementListener({
            onSuccess = function(result)
                if type(result) ~= "table" then return end
                if result.achievementType ~= "normal" then return end
                Receive(token, result.achievementId, result.operation,
                    { success = true, currentStep = result.currentStep })
            end,
            onFailure = function(code, err)
                if type(err) ~= "table" then return end
                local request = inFlight_
                if not request then return end
                -- 官方 AchievementError 不带 operation。按唯一在途的 operation 归属；
                -- 若宿主额外提供该字段，必须一致，不能伪造不存在的 SDK 参数。
                local errorInfo = err --[[@as table]]
                local operation = errorInfo.operation or request.operation
                Receive(token, err.achievementId, operation,
                    { success = false, code = code, message = err.message })
            end,
        })
    end)
    if not ok or accepted == false then
        print("[Achievement] listener unavailable; no platform writes this lifetime: "
            .. tostring(accepted))
        -- 注册可能部分完成；token 作废，迟到 listener 无法确认。
        lifetime_ = {}
        return false
    end
    listenerReady_ = true
    return true
end

local function ConfirmOutcome()
    local request = inFlight_
    if not request or not request.outcome then return end
    local outcome = request.outcome
    inFlight_ = nil -- 已收到匹配终态，下一次 Update 才可能派发其它 id
    if outcome.success ~= true then
        pushFail_ = pushFail_ + 1
        print("[Achievement] isolated " .. request.id .. ": failure "
            .. tostring(outcome.code) .. " " .. tostring(outcome.message))
        return
    end
    local step = ValidStep(outcome.currentStep)
    if (request.operation == "unlock" and step ~= 0)
        or (request.operation == "increment" and (not step or step < request.target)) then
        pushFail_ = pushFail_ + 1
        print("[Achievement] isolated " .. request.id .. ": invalid currentStep="
            .. tostring(outcome.currentStep))
        return
    end
    -- unlock 的 currentStep 按类型固定 0；increment 必须使用平台累计值，不是本地 target。
    local confirmed = request.operation == "unlock" and 1
        or math.min(step --[[@as integer]], request.steps)
    pushOk_ = pushOk_ + 1
    local ok, saved = pcall(function()
        PlayerData.MarkAchievementPushed(request.id, confirmed)
        return PlayerData.Save()
    end)
    if not ok or saved == false then
        print("[Achievement] confirmed but persistence failed " .. request.id
            .. "; next Lua session may repeat unknown delta: " .. tostring(saved))
    end
end

---@param def AchievementDef
---@param currentValue integer
---@return boolean attempted
local function PushToPlatform(def, currentValue)
    if attempted_[def.id] then return false end
    local pushed = PlayerData.GetAchievementPushed(def.id)
    local target = math.min(currentValue, def.steps)
    if target <= pushed then return false end
    local delta = math.min(target - pushed, INT_MAX)
    local s = boundSdk_
    if not s or GameMode.IsOffline() or s ~= GetSdk() then return false end
    local request = {
        id = def.id, operation = def.steps <= 1 and "unlock" or "increment",
        steps = def.steps, target = pushed + delta, delta = delta, outcome = nil,
    } --[[@as AchievementPushRequest]]
    attempted_[def.id] = true -- 先占墓碑/在途槽，再进入可能同步 callback 的 SDK
    inFlight_ = request
    pushAttempts_ = pushAttempts_ + 1
    local ok, accepted = pcall(function()
        if request.operation == "unlock" then return s:UnlockAchievement(def.id) end
        return s:IncrementAchievement(def.id, delta)
    end)
    if not ok or accepted == false then
        pushFail_ = pushFail_ + 1
        -- throw/false 无法保证 SDK 没有副作用；拒绝同调用内 callback，且不放行重叠写入。
        inFlight_ = nil
        poisoned_ = true
        print("[Achievement] isolated " .. def.id .. "; dispatch halted (uncertain SDK return): "
            .. tostring(accepted))
    end
    return true
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

-- Update 只处理平台镜像，不偷偷重算/消费本地解锁通知；Refresh 保留原返回值契约。
-- dt 留给编排层统一接线；刻意没有超时重试（无回调时宁停发，不重叠）。
---@param dt number
function AchievementSystem.Update(dt)
    if not running_ then return end
    local g = _G --[[@as table]]
    if boundSdk_ and (g.sdk ~= boundSdk_ or GetSdk() ~= boundSdk_) then
        if inFlight_ then
            pushFail_ = pushFail_ + 1
            poisoned_ = true
            print("[Achievement] SDK changed with outstanding write; dispatch halted")
            inFlight_ = nil
        end
        return -- 不自动接管新 SDK/listener
    end
    if inFlight_ then
        ConfirmOutcome()
        return -- 同一帧最多处理一笔；callback 不递归派发
    end
    if poisoned_ or GameMode.IsOffline() or not AchievementSystem.Init() then return end
    for _, def in ipairs(AchievementCatalog.GetAll()) do
        if not attempted_[def.id] then
            -- 每次真正派发前重读统计/确认值，避免 Refresh 之后云合并导致陈旧 delta。
            if PushToPlatform(def, ComputeValue(def.id)) then return end
        end
    end
end

-- 先处理已经收到的真实终态，再作废 token；未知请求无法取消，StopStart 不再派发。
function AchievementSystem.Shutdown()
    if not running_ then return end
    ConfirmOutcome()
    if inFlight_ then
        pushFail_ = pushFail_ + 1
        poisoned_ = true
        print("[Achievement] shutdown with unknown outcome " .. inFlight_.id
            .. "; dispatch halted for this Lua session")
    end
    running_ = false
    lifetime_ = nil -- Unregister 可能同步触发旧 callback，先使其无效
    inFlight_ = nil
    local s = boundSdk_
    boundSdk_ = nil
    if s then
        local ok, accepted = pcall(function() return s:UnregisterAchievementListener() end)
        if not ok or accepted == false then
            poisoned_ = true
            print("[Achievement] listener teardown uncertain: " .. tostring(accepted))
        end
    end
end

-- 全量重算本地成就（幂等），兼容旧调用自动 Init；本地失败不由平台状态裁决。
---@return integer newlyUnlocked
function AchievementSystem.Refresh()
    AchievementSystem.Init()
    local newly = 0
    for _, def in ipairs(AchievementCatalog.GetAll()) do
        local value = ComputeValue(def.id)
        local wasUnlocked = PlayerData.IsAchievementUnlocked(def.id)
        local nowUnlocked = PlayerData.SetAchievementProgress(def.id, value, def.steps, true)
        if nowUnlocked and not wasUnlocked then newly = newly + 1 end
    end
    if newly > 0 then PlayerData.Save() end
    AchievementSystem.Update(0)
    return newly
end

-- 打开原生页面也须在线。void 返回表示调用未被显式拒绝，不代表页面实际显示。
---@return boolean
function AchievementSystem.ShowPlatformAchievements()
    if GameMode.IsOffline() then return false end
    local s = GetSdk()
    if not s then return false end
    local ok, accepted = pcall(function()
        if type(s.ShowAchievements) ~= "function" then return false end
        return s:ShowAchievements()
    end)
    return ok and accepted ~= false
end

return AchievementSystem
