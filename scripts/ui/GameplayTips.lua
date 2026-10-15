-- 共享玩法提示：开局选车、进入关卡和关卡列表加载界面统一使用。
local GameplayTips = {}

local TIPS = {
    "冻结控场后再追击，能让反弹路线更稳定",
    "贴近侧墙发射，利用反弹把弹药送回战区",
    "加速车适合连续输出，别急着在第一个目标前回收",
    "分裂车清理密集敌群，巨型车负责突破厚重阵线",
    "先观察敌机队形，再决定发射角度与车辆顺序",
}

local VEHICLE_TIPS = {
    normal = "分裂车：命中后有机会分裂，适合清理成群敌机",
    ice = "冰冻车：命中会冻结敌机，适合压低推进压力",
    speed = "加速车：反弹后持续提速，适合追击与连续输出",
    giant = "巨型车：体型更大且能范围击破，适合破阵",
}

function GameplayTips.Count()
    return #TIPS
end

function GameplayTips.Get(index)
    local i = math.floor(tonumber(index) or 1)
    i = ((i - 1) % #TIPS) + 1
    return TIPS[i]
end

function GameplayTips.GetVehicleTip(key)
    return VEHICLE_TIPS[key] or "选卡后会立即加入本局弹药队列"
end

return GameplayTips
