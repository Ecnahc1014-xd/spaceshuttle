-- 自建联机入口：只显示项目自己的加载画面；匹配与连服由 ctx.client 托管。
-- 五秒未切入游戏脚本时直接启动本地玩法，不经过房间或默认五屏大厅。

local UI = require "urhox-libs/UI"
local GameMode = require "GameMode"

return function(ctx)
    local root, client = ctx.root, ctx.client
    local active = true
    local localStarted = false
    local updateSubscribed = false
    local elapsed = 0
    GameMode.SetOffline(false)

    local view = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = { 7, 11, 20, 255 },
        alignItems = "center", justifyContent = "center",
        children = {
            UI.Panel {
                width = "90%", maxWidth = 440, padding = 24,
                flexDirection = "column", alignItems = "center", gap = 24,
                backgroundColor = { 10, 16, 28, 255 },
                borderColor = { 0, 150, 148, 220 }, borderWidth = 1,
                borderRadius = 6,
                children = {
                    UI.Label { text = "正在加载服务器", fontSize = 22,
                        fontColor = { 240, 248, 252, 255 }, textAlign = "center" },
                    UI.Label { text = "5 秒之后自动加入这个单机模式", fontSize = 15,
                        fontColor = { 120, 148, 162, 255 }, textAlign = "center" },
                },
            },
        },
    }
    root:AddChild(view)

    local function stopWaiting()
        active = false
        client:OnError(nil)
        if updateSubscribed then
            UnsubscribeFromEvent("Update")
            updateSubscribed = false
        end
    end

    local function goOffline()
        if not active then return end
        stopWaiting()
        pcall(function() client:CancelMatch() end)
        -- 本地游戏接管根节点；旧大厅内容必须先销毁，防止遮住战斗 UI。
        view:Destroy()
        GameMode.SetOffline(true)
        local ok, started = pcall(function()
            local clientMain = require "game.client_main"
            return clientMain.Start({ offline = true })
        end)
        if ok and started then
            localStarted = true
            print("[Lobby] timeout/error, local game started")
        else
            print("[Lobby] local game start failed: " .. tostring(started))
        end
    end

    client:OnError(function(kind, code)
        print("[Lobby] platform error " .. tostring(kind) .. ": " .. tostring(code))
        goOffline()
    end)

    local function onUpdate(_, data)
        if not active then return end
        elapsed = elapsed + data:GetFloat("TimeStep")
        if elapsed >= 5 then goOffline() end
    end
    SubscribeToEvent("Update", onUpdate)
    updateSubscribed = true

    local ok, err = pcall(function()
        client:StartMatch {
            onStarted = function() print("[Lobby] matchmaking started") end,
            onMatchFound = function() print("[Lobby] server found, connecting") end,
            onProgress = function(progress)
                if active and progress >= 1 then
                    print("[Lobby] server connection completed")
                end
            end,
            onError = function(code, message)
                print("[Lobby] matchmaking failed: " .. tostring(code) .. " " .. tostring(message))
                goOffline()
            end,
        }
    end)
    if not ok then
        print("[Lobby] StartMatch failed: " .. tostring(err))
        goOffline()
    end

    return {
        stop = function()
            if active then stopWaiting() end
            if localStarted then
                require("game.client_main").Stop()
            end
        end,
    }
end
