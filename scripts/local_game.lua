-- local_game.lua
-- 离线降级入口：由自建大厅在「匹配超时 / 发起异常」时调用。
-- 只做一件事——把游戏按离线模式拉起来；玩法、UI、渲染全部与联机路径同一份代码。

local GameMode = require "GameMode"

local M = {}

function M.start()
    GameMode.SetOffline(true)
    local mod = require("game.client_main")
    mod.Start({ offline = true })
    print("[local_game] offline single-player started")
end

return M
