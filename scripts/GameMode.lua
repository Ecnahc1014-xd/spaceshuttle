-- GameMode.lua
-- 唯一的「离线」判断入口。
--
-- ⚠️ 禁止用 IsNetworkMode() 判断离线：大厅启动之后 IsNetworkMode() 恒为 true，
-- 即使匹配超时降级成本地游玩也依然是 true。离线只认 GameMode.IsOffline()。

local GameMode = {}

-- 默认 false（在线假定）：由自建大厅在「匹配超时 / 发起异常」时显式置 true。
-- ⚠️ 禁止用 IsNetworkMode() 判断离线——大厅启动后它恒为 true。
local offline_ = false

---@return boolean
function GameMode.IsOffline()
    return offline_
end

---@param value boolean
function GameMode.SetOffline(value)
    offline_ = value == true
    print("[GameMode] offline = " .. tostring(offline_))
end

-- 云能力（排行榜 / 云存档 / 成就 / 余额拉取）是否可用。
---@return boolean
function GameMode.CloudEnabled()
    return not offline_
end

---@return boolean
function GameMode.IsServer()
    if IsServerMode == nil then return false end
    return IsServerMode() == true
end

---@return boolean
function GameMode.IsClient()
    if IsClientMode == nil then return false end
    return IsClientMode() == true
end

return GameMode
