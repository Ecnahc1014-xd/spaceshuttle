-- PlayerData.lua
-- 玩家元数据层（跨局）：软货币「零件」、每日签到、每日任务、敌机图鉴、皮肤与统计。
-- 只做数据处理与本地存档读写；云同步与广告发奖由编排层（main.lua）驱动，
-- 规则层（Game.lua）只通过局内 partsEarned 结算，不直接读写本模块。

local PlayerData = {}

local SAVE_FILE = "player_data.json"
local DATA_VERSION = 1

---@class PlayerDataState
---@field version integer 存档结构版本
---@field parts integer 软货币「零件」余额
---@field totalParts integer 历史累计获得零件（统计）
---@field totalSpent integer 历史累计消费零件（避免云合并恢复已消费余额）
---@field highScore integer 历史最高分（本地副本）
---@field signInDate string 上次签到日期 YYYY-MM-DD
---@field signInStreak integer 连续签到天数
---@field signInTotal integer 累计签到次数
---@field dailyDate string 每日任务所属日期
---@field dailyProgress table<string, integer> 任务 id -> 当前进度
---@field dailyClaimed table<string, boolean> 任务 id -> 是否已领取
---@field codex table<string, boolean> 已解锁敌机 key
---@field skins table<string, boolean> 已解锁皮肤 key
---@field selectedSkin string 当前使用的皮肤 key
---@field shopBought table<string, boolean> 商城一次性商品
---@field passClaimed integer 战斗档案已领到的等级
---@field firstGiftClaimed boolean 首充新手礼包奖励是否已本地补发
---@field createdAt integer 首次运行时间戳（首充限时窗基准）
---@field purchasedPartsClaimed integer 已补领的钻石兑换零件累计额
---@field stats table<string, integer> 通用计数器（复活次数、广告观看等）

---@return PlayerDataState
local function NewState()
    return {
        version = DATA_VERSION,
        parts = 0,
        totalParts = 0,
        totalSpent = 0,
        highScore = 0,
        signInDate = "",
        signInStreak = 0,
        signInTotal = 0,
        dailyDate = "",
        dailyProgress = {},
        dailyClaimed = {},
        codex = {},
        skins = { default = true },
        selectedSkin = "default",
        shopBought = {},
        passClaimed = 0,
        firstGiftClaimed = false,
        createdAt = 0,
        purchasedPartsClaimed = 0,
        stats = {},
    }
end

---@type PlayerDataState
local state = NewState()

---@param v any
---@return integer
local function AsInt(v)
    return math.floor(tonumber(v) or 0)
end

---@param v any
---@return string
local function AsStr(v)
    if type(v) == "string" then return v end
    return ""
end

---@param src any
---@return table<string, integer>
local function AsIntMap(src)
    local out = {}
    if type(src) ~= "table" then return out end
    for k, v in pairs(src --[[@as table]]) do
        local n = math.floor(tonumber(v) or 0)
        if n ~= 0 then out[tostring(k)] = n end
    end
    return out
end

---@param src any
---@return table<string, boolean>
local function AsBoolMap(src)
    local out = {}
    if type(src) ~= "table" then return out end
    for k, v in pairs(src --[[@as table]]) do
        if v then out[tostring(k)] = true end
    end
    return out
end

---@return string
local function Today()
    return os.date("%Y-%m-%d", os.time())
end

-- ============================================================================
-- 存档读写
-- ============================================================================

function PlayerData.Load()
    state = NewState()
    state.createdAt = os.time()
    if not fileSystem:FileExists(SAVE_FILE) then
        print("[PlayerData] no local save, start fresh")
        return false
    end
    local file = File(SAVE_FILE, FILE_READ)
    if not file:IsOpen() then
        print("[PlayerData] save file not openable")
        return false
    end
    local text = file:ReadString()
    file:Close()

    local ok, decoded = pcall(cjson.decode, text)
    if not ok or type(decoded) ~= "table" then
        print("[PlayerData] save decode failed, start fresh")
        return false
    end
    local d = decoded --[[@as table]]
    state.version      = AsInt(d.version) ~= 0 and AsInt(d.version) or DATA_VERSION
    state.parts        = math.max(0, AsInt(d.parts))
    state.totalParts   = math.max(0, AsInt(d.totalParts), state.parts)
    state.totalSpent   = math.max(0, AsInt(d.totalSpent), state.totalParts - state.parts)
    state.highScore    = math.max(0, AsInt(d.highScore))
    state.signInDate   = AsStr(d.signInDate)
    state.signInStreak = math.max(0, AsInt(d.signInStreak))
    state.signInTotal  = math.max(0, AsInt(d.signInTotal))
    state.dailyDate    = AsStr(d.dailyDate)
    state.dailyProgress = AsIntMap(d.dailyProgress)
    state.dailyClaimed  = AsBoolMap(d.dailyClaimed)
    state.codex        = AsBoolMap(d.codex)
    state.shopBought   = AsBoolMap(d.shopBought)
    state.passClaimed  = math.max(0, AsInt(d.passClaimed))
    state.firstGiftClaimed = d.firstGiftClaimed == true
    state.createdAt = math.max(0, AsInt(d.createdAt))
    state.purchasedPartsClaimed = math.max(0, AsInt(d.purchasedPartsClaimed))
    state.stats        = AsIntMap(d.stats)
    local skins = AsBoolMap(d.skins)
    skins.default = true
    state.skins = skins
    local selected = AsStr(d.selectedSkin)
    state.selectedSkin = skins[selected] and selected or "default"
    if state.createdAt == 0 then state.createdAt = os.time() end

    PlayerData.RollDaily()
    print("[PlayerData] loaded parts=" .. state.parts .. " highScore=" .. state.highScore
        .. " codex=" .. tostring(PlayerData.CodexCount()))
    return true
end

function PlayerData.Save()
    local file = File(SAVE_FILE, FILE_WRITE)
    if not file:IsOpen() then
        print("[PlayerData] save failed: file not openable")
        return false
    end
    file:WriteString(cjson.encode(state))
    file:Close()
    return true
end

-- 云同步：只做字符串编解码，真正的读写由编排层（main.lua）执行。
---@return string
function PlayerData.ExportForCloud()
    return cjson.encode(state)
end

---@param text any
---@return boolean
function PlayerData.ImportFromCloud(text)
    if type(text) ~= "string" or text == "" then return false end
    local ok, decoded = pcall(cjson.decode, text)
    if not ok or type(decoded) ~= "table" then
        print("[PlayerData] cloud decode failed")
        return false
    end
    local d = decoded --[[@as table]]
    local cloudParts = math.max(0, AsInt(d.parts))
    local cloudTotal = math.max(0, AsInt(d.totalParts), cloudParts)
    local cloudSpent = math.max(0, AsInt(d.totalSpent), cloudTotal - cloudParts)
    local cloudCodex = AsBoolMap(d.codex)
    local cloudSkins = AsBoolMap(d.skins)
    local cloudStats = AsIntMap(d.stats)
    local cloudHigh  = math.max(0, AsInt(d.highScore))

    local cloudClaimed = math.max(0, AsInt(d.purchasedPartsClaimed))
    -- 累计兑换额已经包含在 totalParts 中，先拆出普通收入再合并，
    -- 否则旧设备本地补领后再读取未更新的云档，会把同一笔零件算两遍。
    -- 注意普通收入/消费仍是跨设备取最大值，并非事务账本；并发游玩无法保证无损。
    local localEarned = math.max(0, state.totalParts - state.purchasedPartsClaimed)
    local cloudEarned = math.max(0, cloudTotal - cloudClaimed)
    state.purchasedPartsClaimed = math.max(state.purchasedPartsClaimed, cloudClaimed)
    state.totalParts = math.max(localEarned, cloudEarned) + state.purchasedPartsClaimed
    state.totalSpent = math.max(state.totalSpent, cloudSpent)
    state.parts = math.max(0, state.totalParts - state.totalSpent)
    -- 仅合并当天的每日状态；不同日期的任务/广告限次不能互相污染。
    if AsStr(d.dailyDate) == Today() then
        if state.dailyDate ~= Today() then PlayerData.RollDaily() end
        for k, v in pairs(AsIntMap(d.dailyProgress)) do
            state.dailyProgress[k] = math.max(state.dailyProgress[k] or 0, v)
        end
        for k in pairs(AsBoolMap(d.dailyClaimed)) do state.dailyClaimed[k] = true end
    end
    local cloudSignDate = AsStr(d.signInDate)
    if cloudSignDate <= Today() and cloudSignDate > state.signInDate then
        state.signInDate = cloudSignDate
        state.signInStreak = math.max(0, AsInt(d.signInStreak))
    elseif cloudSignDate == state.signInDate then
        state.signInStreak = math.max(state.signInStreak, math.max(0, AsInt(d.signInStreak)))
    end
    state.passClaimed = math.max(state.passClaimed, math.max(0, AsInt(d.passClaimed)))
    if d.firstGiftClaimed == true then state.firstGiftClaimed = true end
    local cloudCreated = math.max(0, AsInt(d.createdAt))
    -- 首次运行时间取两台设备中更早的那个（限时窗基准）。
    if cloudCreated > 0 and (state.createdAt == 0 or cloudCreated < state.createdAt) then
        state.createdAt = cloudCreated
    end
    state.highScore  = math.max(state.highScore, cloudHigh)
    for k in pairs(cloudCodex) do state.codex[k] = true end
    for k in pairs(cloudSkins) do state.skins[k] = true end
    for k, v in pairs(cloudStats) do
        local cur = state.stats[k] or 0
        if v > cur then state.stats[k] = v end
    end
    local cloudSignTotal = math.max(0, AsInt(d.signInTotal))
    state.signInTotal = math.max(state.signInTotal, cloudSignTotal)
    print("[PlayerData] cloud merged parts=" .. state.parts)
    return true
end

-- ============================================================================
-- 软货币「零件」
-- ============================================================================

---@return integer
function PlayerData.GetParts()
    return state.parts
end

---@return integer
function PlayerData.AddParts(amount)
    local n = math.floor(amount)
    if n <= 0 then return state.parts end
    state.parts = state.parts + n
    state.totalParts = state.totalParts + n
    PlayerData.Save()
    return state.parts
end

-- 服务端每次推累计额；本地与云端均记录已补领进度，不依赖单次扣款回调。
---@param total integer
---@return integer granted
function PlayerData.ClaimPurchasedParts(total)
    local n = math.max(0, math.floor(total))
    if n <= state.purchasedPartsClaimed then return 0 end
    local delta = n - state.purchasedPartsClaimed
    state.purchasedPartsClaimed = n
    state.parts = state.parts + delta
    state.totalParts = state.totalParts + delta
    PlayerData.Save()
    return delta
end

---@param amount integer
---@return boolean
function PlayerData.SpendParts(amount)
    local n = math.floor(amount)
    if n <= 0 then return false end
    if state.parts < n then return false end
    state.parts = state.parts - n
    state.totalSpent = state.totalSpent + n
    PlayerData.Save()
    return true
end

-- ============================================================================
-- 每日签到
-- ============================================================================

---@return boolean
function PlayerData.CanSignIn()
    return state.signInDate ~= Today()
end

-- 连续签到奖励递增，7 天封顶；断签从头计算。
---@type integer[]
local SIGN_IN_TABLE = { 100, 120, 140, 160, 200, 240, 300 }

---@return integer parts
---@return integer streak
function PlayerData.GetSignInPreview()
    local streak = state.signInStreak
    if PlayerData.CanSignIn() then
        local yesterday = os.date("%Y-%m-%d", os.time() - 86400)
        streak = state.signInDate == yesterday and streak + 1 or 1
    end
    return PlayerData.SignInReward(streak), streak
end

---@param streak integer
---@return integer
function PlayerData.SignInReward(streak)
    local idx = math.min(math.max(streak, 1), 7)
    return SIGN_IN_TABLE[idx] or 100
end

---@return integer 实际发放的零件数（0 表示今天已签到）
function PlayerData.SignIn()
    if not PlayerData.CanSignIn() then return 0 end
    local yesterday = os.date("%Y-%m-%d", os.time() - 86400)
    if state.signInDate == yesterday then
        state.signInStreak = state.signInStreak + 1
    else
        state.signInStreak = 1
    end
    state.signInDate = Today()
    state.signInTotal = state.signInTotal + 1
    local reward = PlayerData.SignInReward(state.signInStreak)
    PlayerData.AddParts(reward)
    print("[PlayerData] sign in streak=" .. state.signInStreak .. " reward=" .. reward)
    return reward
end

-- ============================================================================
-- 每日任务
-- ============================================================================

---@class DailyTaskDef
---@field id string
---@field name string
---@field target integer
---@field reward integer

---@type DailyTaskDef[]
local DAILY_TASKS = {
    { id = "break_bricks", name = "击碎 300 块敌机方块", target = 300, reward = 150 },
    { id = "reach_wave",   name = "抵达第 8 波",         target = 8,   reward = 200 },
    { id = "play_runs",    name = "完成 3 局战斗",        target = 3,   reward = 150 },
}

---@return DailyTaskDef[]
function PlayerData.GetDailyTasks()
    return DAILY_TASKS
end

-- 跨天时清空任务进度；签到状态由 SignIn 自行按日期判定。
function PlayerData.RollDaily()
    local today = Today()
    if state.dailyDate == today then return end
    state.dailyDate = today
    state.dailyProgress = {}
    state.dailyClaimed = {}
    print("[PlayerData] daily tasks rolled to " .. today)
end

-- 累加当日任务进度（只增不减，同一天内多次结算安全）。
---@param id string
---@param amount integer
---@param absolute boolean|nil true 表示取最大值而不是累加（如"抵达第 N 波"）
function PlayerData.AddDailyProgress(id, amount, absolute)
    PlayerData.RollDaily()
    local cur = state.dailyProgress[id] or 0
    if absolute then
        if amount > cur then state.dailyProgress[id] = amount end
    else
        state.dailyProgress[id] = cur + amount
    end
end

---@param id string
---@return integer
function PlayerData.GetDailyProgress(id)
    PlayerData.RollDaily()
    return state.dailyProgress[id] or 0
end

-- 通用每日计数器（跨天自动清零），用于转盘/补给/广告礼包等「每日 N 次」限制。
---@param key string
---@return integer
function PlayerData.GetDailyCount(key)
    PlayerData.RollDaily()
    return state.dailyProgress["__cnt_" .. key] or 0
end

---@param key string
---@param amount integer
function PlayerData.AddDailyCount(key, amount)
    PlayerData.RollDaily()
    local full = "__cnt_" .. key
    state.dailyProgress[full] = (state.dailyProgress[full] or 0) + math.floor(amount)
end

---@param id string
---@return boolean
function PlayerData.IsDailyClaimed(id)
    PlayerData.RollDaily()
    return state.dailyClaimed[id] == true
end

---@param id string
---@return boolean
function PlayerData.CanClaimDaily(id)
    PlayerData.RollDaily()
    if state.dailyClaimed[id] then return false end
    for _, task in ipairs(DAILY_TASKS) do
        if task.id == id then
            return PlayerData.GetDailyProgress(id) >= task.target
        end
    end
    return false
end

---@param id string
---@return integer 实际发放的零件数（0 表示不可领取）
function PlayerData.ClaimDaily(id)
    if not PlayerData.CanClaimDaily(id) then return 0 end
    for _, task in ipairs(DAILY_TASKS) do
        if task.id == id then
            state.dailyClaimed[id] = true
            PlayerData.AddParts(task.reward)
            print("[PlayerData] daily claimed " .. id .. " +" .. task.reward)
            return task.reward
        end
    end
    return 0
end

---@return boolean 是否有任意任务可领取（用于红点）
function PlayerData.HasClaimableDaily()
    for _, task in ipairs(DAILY_TASKS) do
        if PlayerData.CanClaimDaily(task.id) then return true end
    end
    return false
end

-- ============================================================================
-- 敌机图鉴
-- ============================================================================

---@param key string
---@return boolean
function PlayerData.IsCodexUnlocked(key)
    return state.codex[key] == true
end

---@param key string
---@return boolean 是否发生了新的解锁
function PlayerData.UnlockCodex(key)
    if state.codex[key] then return false end
    state.codex[key] = true
    PlayerData.Save()
    print("[PlayerData] codex unlocked " .. key)
    return true
end

---@return integer
function PlayerData.CodexCount()
    local n = 0
    for _ in pairs(state.codex) do n = n + 1 end
    return n
end

-- ============================================================================
-- 皮肤与商城
-- ============================================================================

---@param key string
---@return boolean
function PlayerData.HasSkin(key)
    return state.skins[key] == true
end

---@param key string
function PlayerData.UnlockSkin(key)
    if state.skins[key] then return end
    state.skins[key] = true
    PlayerData.Save()
    print("[PlayerData] skin unlocked " .. key)
end

---@return string
function PlayerData.GetSelectedSkin()
    return state.selectedSkin
end

---@param key string
---@return boolean
function PlayerData.SelectSkin(key)
    if not state.skins[key] then return false end
    state.selectedSkin = key
    PlayerData.Save()
    return true
end

---@param key string
---@return boolean
function PlayerData.IsShopBought(key)
    return state.shopBought[key] == true
end

---@param key string
function PlayerData.MarkShopBought(key)
    state.shopBought[key] = true
    PlayerData.Save()
end

-- ============================================================================
-- 战斗档案（累计击碎方块，每 200 块解锁一级免费奖励）
-- ============================================================================

local PASS_STEP = 200

function PlayerData.GetPassLevel()
    return math.min(6, 1 + math.floor((state.stats.bricksTotal or 0) / PASS_STEP))
end

function PlayerData.GetPassProgress()
    local total = state.stats.bricksTotal or 0
    return total % PASS_STEP, PASS_STEP
end

function PlayerData.GetPassClaimed()
    return state.passClaimed
end

-- 首充新手礼包：限时窗剩余秒数（<=0 表示窗口已关）。
---@param windowSeconds integer
---@return integer secondsLeft
function PlayerData.GetFirstGiftWindow(windowSeconds)
    if state.createdAt <= 0 then return 0 end
    local elapsed = os.time() - state.createdAt
    local left = windowSeconds - elapsed
    return left > 0 and left or 0
end

---@return boolean
function PlayerData.IsFirstGiftClaimed()
    return state.firstGiftClaimed
end

function PlayerData.MarkFirstGiftClaimed()
    state.firstGiftClaimed = true
    PlayerData.Save()
end

function PlayerData.ClaimPass(level, multiplier)
    if level ~= state.passClaimed + 1 or level > PlayerData.GetPassLevel() then return 0 end
    state.passClaimed = level
    local reward = (100 + level * 100) * math.max(1, math.floor(multiplier or 1))
    PlayerData.AddParts(reward)
    print("[PlayerData] battle record level=" .. level .. " reward=" .. reward)
    return reward
end

-- ============================================================================
-- 统计
-- ============================================================================

---@param key string
---@param delta integer
function PlayerData.AddStat(key, delta)
    state.stats[key] = (state.stats[key] or 0) + delta
end

---@param key string
---@return integer
function PlayerData.GetStat(key)
    return state.stats[key] or 0
end

---@param value integer
function PlayerData.SetHighScore(value)
    if value <= state.highScore then return end
    state.highScore = value
    PlayerData.Save()
end

---@return integer
function PlayerData.GetHighScore()
    return state.highScore
end

return PlayerData
