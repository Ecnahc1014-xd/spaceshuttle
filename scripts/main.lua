-- main.lua
-- 唯一入口：按运行模式分流。
--
--   服务端（headless）→ network.Server：只承载 IAP 发货 + 氪金代币余额（serverCloud）。
--                        禁止加载任何渲染 / HUD / 商店 UI / 玩法模块。
--   客户端           → game.client_main：完整单机玩法 + 可选联机层（余额同步）。
--
-- 联机启动路径下，引擎会先跑自建大厅 `scripts/lobby_runtime.lua`：
--   · 匹配成功 → 引擎自动连服并切到本文件（代码零参与切场景）
--   · 匹配超时 / 发起异常 → 大厅置离线标志，经 local_game 直接起本地单机
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
