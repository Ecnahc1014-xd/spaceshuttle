-- AdService.lua
-- 激励视频广告的统一调度层：在途锁、冷却、一次性完成与统一失败文案。
--
-- 引擎侧只暴露 sdk:ShowRewardVideoAd（无横幅/插屏）。所有广告发放都必须经过本模块，
-- 以保证：① 返回值 + 回调双通道都被处理；② 迟到回调不重复发奖；③ UI 不会卡在加载态。
-- 本模块不直接接触表现层，成功/失败都通过回调交回编排层（main.lua）决定后续。

local AdService = {}

-- 两次广告之间的最小间隔（秒）。引擎侧自身还有防抖，这里再兜一层避免连点。
local COOLDOWN_SECONDS = 3
local RESPONSE_TIMEOUT_SECONDS = 120

local inFlight = false
local cooldown = 0
local pendingTimeout = 0
---@type fun()|nil
local timeoutRequest = nil

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
    if cooldown > 0 then
        cooldown = cooldown - dt
        if cooldown < 0 then cooldown = 0 end
    end
    if timeoutRequest then
        pendingTimeout = pendingTimeout - dt
        if pendingTimeout <= 0 then timeoutRequest() end
    end
end

---@return boolean
function AdService.IsBusy()
    return inFlight or cooldown > 0
end

-- 发起一次激励视频。被在途锁或冷却挡住时不会调用 sdk，直接走 busy 提示。
---@param opts AdRequestOpts
---@return boolean accepted 是否真正向 sdk 发起了请求
function AdService.Show(opts)
    local onReward = opts.onReward
    local onFail = opts.onFail
    local onBusy = opts.onBusy or onFail

    if inFlight then
        onBusy("广告加载中，请稍候")
        return false
    end
    if cooldown > 0 then
        onBusy("广告冷却中，请稍后再试")
        return false
    end

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
            onReward()
        else
            print("[AdService] ad failed: " .. msg)
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
