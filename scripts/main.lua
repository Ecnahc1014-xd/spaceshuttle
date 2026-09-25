-- main.lua
-- 唯一入口：按运行模式分流。
--
--   服务端（headless）→ network.Server：只承载 IAP 发货 + 氪金代币余额（serverCloud）。
--                        禁止加载任何渲染 / HUD / 商店 UI / 玩法模块。
--   客户端           → game.client_main：完整单机玩法 + 可选联机层（余额同步）。
--
-- 采用 background_match：游戏脚本**立即加载**，匹配在后台进行；
-- 服务端就绪时引擎触发 `ServerReady`，届时才启用联机层与云能力。
-- 没有大厅层、没有等待画面——那层带来的所有 UI/合成问题都不复存在。
--
-- ⚠️ 本作是「单机间接联机」：服务端不跑战斗、不做场景复制、不模拟敌人。
--    排行榜 / 成就 / 养成存档仍然由客户端 clientCloud + 本地存档负责。

---@type table|nil
local Module = nil

function Start()
    if IsServerMode() then
        Module = require "network.Server"
        print("[Main] runtime mode = server")
    else
        Module = require "game.client_main"
        print("[Main] runtime mode = client")
    end
    Module.Start()
end

function Stop()
    if Module and Module.Stop then
        Module.Stop()
    end
    Module = nil
end
