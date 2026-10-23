-- main.lua
-- 唯一入口：按运行模式分流。
--
--   服务端（headless）→ network.Server：只承载 IAP 发货 + 氪金代币余额（serverCloud）。
--                        禁止加载任何渲染 / HUD / 商店 UI / 玩法模块。
--   客户端           → game.client_main：完整单机玩法 + 可选联机层（余额同步）。
--
-- 联机启动由完全自建的 `scripts/lobby_runtime.lua` 显示加载界面并自动匹配；
-- 五秒未切到游戏脚本时直接运行离线玩法，联机与降级仍需真实预览验收。
--
-- ⚠️ 本作是「单机间接联机」：服务端不跑战斗、不做场景复制、不模拟敌人。
--    排行榜 / 成就 / 养成存档仍然由客户端 clientCloud + 本地存档负责。

---@type table|nil
local Module = nil

-- 性能压测开关：引擎命令行带 --perf-autoplay 时，客户端自动进关并持续发射。
-- 正式包不带该参数，行为与以往完全一致。
---@return boolean
local function PerfAutoplayRequested()
    local ok, args = pcall(function() return GetArguments() end)
    if not ok or type(args) ~= "table" then return false end
    for i = 1, #args do
        local a = tostring(args[i])
        if a:find("perf%-autoplay") then return true end
    end
    return false
end

function Start()
    if IsServerMode() then
        Module = require "network.Server"
        print("[Main] runtime mode = server")
        Module.Start()
    else
        Module = require "game.client_main"
        print("[Main] runtime mode = client")
        Module.Start({ perfAutoplay = PerfAutoplayRequested() })
    end
end

function Stop()
    if Module and Module.Stop then
        Module.Stop()
    end
    Module = nil
end
