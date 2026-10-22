-- AdService.lua
-- 激励视频广告的统一调度层：在途锁、冷却、一次性完成与统一失败文案。
--
-- 引擎侧只暴露 sdk:ShowRewardVideoAd（无横幅/插屏）。所有广告发放都必须经过本模块，
-- 以保证：① 返回值 + 回调双通道都被处理；② 迟到回调不重复发奖；③ UI 不会卡在加载态。
-- 本模块不直接接触表现层，成功/失败都通过回调交回编排层（main.lua）决定后续。

local UIInspectorCompat = require "ui.UIInspectorCompat"

local AdService = {}

-- 两次广告之间的最小间隔（秒）。引擎侧自身还有防抖，这里再兜一层避免连点。
local COOLDOWN_SECONDS = 3
local RESPONSE_TIMEOUT_SECONDS = 120
-- v0.13.71 运营护栏：每日成功观看上限 + 硬失败后的可用性冷却。
local AD_DAILY_CAP = 25
local UNAVAILABLE_BACKOFF_SECONDS = 120

local inFlight = false
local cooldown = 0
local pendingTimeout = 0
---@type fun()|nil
local timeoutRequest = nil
local clock = 0
---@type fun()|nil
local unavailableRequest = nil
local unavailableUntil = 0
local dayStamp = ""
local dayCount = 0
---@class AdPointStat
---@field shown integer 发起次数
---@field ok integer 完整观看并发奖
---@field fail integer 未完成/失败
---@field busy integer 被在途锁/冷却/上限挡住
---@type table<string, AdPointStat>
local pointStats = {}

---@class AdRequestOpts
---@field onReward fun() 完整观看后的发奖回调
---@field onFail fun(msg: string) 未完整观看或不可用时的提示回调
---@field onBusy fun(msg: string)|nil 被在途锁/冷却挡住时的提示回调（缺省走 onFail）

---@param result table|nil
---@return boolean success
---@return string msg
local function Normalize(result)
    if not result then return false, "广告暂不可用" end
    local r = result --[[@as table]]
    if r.success == true then
        return true, ""
    end
    local raw = r.msg
    if raw == "embed manual close" then
        return false, "需完整观看才能领取"
    end
    return false, "广告未完成，请稍后重试"
end

-- 每帧推进冷却。
---@param dt number
function AdService.Update(dt)
    if dt and dt > 0 then clock = clock + dt end
    if cooldown > 0 then
        cooldown = cooldown - dt
        if cooldown < 0 then cooldown = 0 end
    end
    if timeoutRequest then
        pendingTimeout = pendingTimeout - dt
        if pendingTimeout <= 0 then timeoutRequest() end
    end
    -- 跨日重置每日计数（与 PlayerData 同源的本地日期）。
    local today = os.date("%Y-%m-%d", os.time())
    if today ~= dayStamp then
        dayStamp, dayCount = today, 0
    end
end

---@return boolean
function AdService.IsBusy()
    return inFlight or cooldown > 0
end

---@param point string
---@return AdPointStat
local function PointStat(point)
    local key = point or "unknown"
    local st = pointStats[key]
    if not st then
        st = { shown = 0, ok = 0, fail = 0, busy = 0 }
        pointStats[key] = st
    end
    return st
end

--- 广告是否还值得发起：SDK 存在、未在途、未冷却、未超日上限、未处于硬失败冷却。
--- 供 UI 决定按钮是否可点 / 是否降级为"广告暂不可用"。
---@return boolean ok
---@return string reason
function AdService.IsAvailable()
    if type(sdk) ~= "table" or type(sdk.ShowRewardVideoAd) ~= "function" then
        return false, "广告未接入"
    end
    if inFlight then return false, "广告加载中" end
    if cooldown > 0 then return false, "广告冷却中" end
    if clock < unavailableUntil then return false, "广告暂不可用" end
    if dayCount >= AD_DAILY_CAP then return false, "今日广告次数已达上限" end
    return true, ""
end

--- 硬失败（超时/未配置）后进入可用性冷却，避免整屏按钮反复打 SDK。
---@param seconds number|nil
function AdService.MarkUnavailable(seconds)
    unavailableUntil = clock + (seconds or UNAVAILABLE_BACKOFF_SECONDS)
end

--- 只读统计：按点位的 shown/ok/fail/busy + 今日已用次数与上限。
---@return table
function AdService.DebugStats()
    local byPoint = {}
    for key, st in pairs(pointStats) do
        byPoint[key] = { shown = st.shown, ok = st.ok, fail = st.fail, busy = st.busy }
    end
    return {
        today = dayStamp, todayCount = dayCount, dailyCap = AD_DAILY_CAP,
        inFlight = inFlight, cooldown = cooldown,
        unavailableIn = math.max(0, unavailableUntil - clock),
        byPoint = byPoint,
    }
end

function AdService.IsInFlight()
    return inFlight
end

-- 发起一次激励视频。被在途锁或冷却挡住时不会调用 sdk，直接走 busy 提示。
---@param opts AdRequestOpts
---@return boolean accepted 是否真正向 sdk 发起了请求
function AdService.Show(opts)
    local onReward = opts.onReward
    local onFail = opts.onFail
    local onBusy = opts.onBusy or onFail
    local point = opts.point or "unknown"
    local stat = PointStat(point)

    -- v0.12.14：平台用 urhox-libs/FakeAd 模拟激励视频时会调用 UI.Init 初始化 UI 系统，
    -- 而 UI.Init 在预览环境会自动请求 F9 检查器；必须先保证 UI 侧的 Inspector 字段存在，
    -- 否则每次首播广告都会写一条「UI Inspector requested but failed to load」ERROR。
    UIInspectorCompat.Ensure()

    if inFlight then
        stat.busy = stat.busy + 1
        onBusy("广告加载中，请稍候")
        return false
    end
    if cooldown > 0 then
        stat.busy = stat.busy + 1
        onBusy("广告冷却中，请稍后再试")
        return false
    end
    if clock < unavailableUntil then
        stat.busy = stat.busy + 1
        onBusy("广告暂不可用，请稍后再试")
        return false
    end
    if dayCount >= AD_DAILY_CAP then
        stat.busy = stat.busy + 1
        onBusy("今日广告次数已达上限")
        return false
    end
    stat.shown = stat.shown + 1

    inFlight = true
    local completed = false
    local callbackFired = false

    ---@param result table|nil
    local function finish(result)
        if completed then return end
        completed = true
        timeoutRequest = nil
        pendingTimeout = 0
        inFlight = false
        cooldown = COOLDOWN_SECONDS
        local success, msg = Normalize(result)
        if success then
            stat.ok = stat.ok + 1
            dayCount = dayCount + 1
            onReward()
        else
            stat.fail = stat.fail + 1
            -- 用户主动关闭不算"广告不可用"；超时/未接入才进入可用性冷却。
            if msg == "广告响应超时" or msg == "广告暂不可用" then
                AdService.MarkUnavailable()
            end
            print("[AdService] ad failed(" .. point .. "): " .. msg)
            onFail(msg)
        end
    end

    local okCall, acceptedOrErr = pcall(function()
        return sdk:ShowRewardVideoAd(function(result)
            callbackFired = true
            finish(result)
        end)
    end)

    local accepted = false
    if okCall then
        accepted = acceptedOrErr == true
    else
        print("[AdService] ShowRewardVideoAd error: " .. tostring(acceptedOrErr))
    end

    -- 请求未被受理且回调也没同步触发：必须自己收尾，否则 UI 会卡在加载态。
    if not accepted and not callbackFired then
        finish(nil)
        return false
    end
    if accepted and not completed then
        pendingTimeout = RESPONSE_TIMEOUT_SECONDS
        timeoutRequest = function()
            print("[AdService] callback timeout")
            finish({ success = false, msg = "广告响应超时" })
        end
    end
    return accepted
end

return AdService
