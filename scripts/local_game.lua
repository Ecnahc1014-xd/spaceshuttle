-- local_game.lua
-- 大厅「降级本地游玩」路径的载体：把游戏生命周期包成大厅能管理的模块。
--
-- 大厅（lobby_runtime.lua）在匹配超时/失败时调用 LocalGame.start(ctx)，
-- stop 时归还资源。契约与 Example_Custom_LobbyRuntime 的 local_game 一致。

local ClientMain = require "game.client_main"
local GameMode = require "GameMode"

local LocalGame = {}

---@class LocalGameCtx
---@field root any 大厅的 UI 根节点（本作玩法用 NanoVG，不需要挂载，仅保持契约形状）
---@field onExit fun()|nil 请求回到大厅
---@field onOnline fun()|nil 请求转联机（本作不使用）

---@param ctx LocalGameCtx
---@return table { stop = fun() }
function LocalGame.start(ctx)
    -- 大厅已经 SetOffline(true)；这里再兜一次，保证任何调用路径都是单机。
    if not GameMode.IsOffline() then
        GameMode.SetOffline(true)
    end
    print("[LocalGame] starting offline session")

    ClientMain.Start({ offline = true })

    return {
        stop = function()
            ClientMain.Stop()
            print("[LocalGame] stopped")
        end,
    }
end

return LocalGame
