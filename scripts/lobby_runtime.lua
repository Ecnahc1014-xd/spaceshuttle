-- 自建联机入口：只显示项目自己的加载画面；匹配与连服由 ctx.client 托管。
-- 五秒未切入游戏脚本时直接启动本地玩法，不经过房间或默认五屏大厅。
--
-- 生命周期契约（⚠️ 全部路径必须遵守）：
-- 1. 大厅用 urhox-libs/UI（自带进程级 NanoVG 单例 + 自动 Update/Render 订阅）。
--    游戏 Scene3DBackend 会 nvgCreate 第二个上下文 —— 降级进游戏前必须先
--    UI.Shutdown() 销毁旧上下文，否则两个上下文同帧 BeginFrame 合成顺序不稳定，
--    真机表现为「游戏 UI 只剩零星元素 / 2D 页面全没」（AB-088c）。
-- 2. 匹配成功（连服 progress>=1）后引擎会切游戏脚本：立即 stopWaiting() 撤销
--    五秒兜底计时，避免与脚本切换竞态导致双起。
-- 3. stop()（引擎回收大厅）同样要 UI.Shutdown()，不给游戏遗留上下文。
-- 所有降级入口共用 GoOffline()，禁止在多处各写一遍销毁顺序。

local UI = require "urhox-libs/UI"
local GameMode = require "GameMode"

return function(ctx)
    local root, client = ctx.root, ctx.client
    local active = true
    local localStarted = false
    local uiShutdown = false
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

    -- 先销毁大厅的 UI 上下文，再起游戏（唯一合法的降级顺序）。
    local function shutdownLobbyUI()
        if uiShutdown then return end
        uiShutdown = true
        pcall(function() view:Destroy() end)
        pcall(UI.Shutdown)
    end

    local function goOffline()
        if not active then return end
        stopWaiting()
        pcall(function() client:CancelMatch() end)
        shutdownLobbyUI()
        GameMode.SetOffline(true)
        local ok, started = pcall(function()
            local clientMain = require "game.client_main"
            return clientMain.Start({ offline = true })
        end)
        if ok and started then
            localStarted = true
            print("[Lobby] timeout/error, local game started")
        else
            -- UI 上下文已销毁、游戏后端 Init 失败属于致命错误（可选资源已不得阻断 Init），
            -- 记录完整错误供日志定位；不再伪造回退界面。
            print("[Lobby] FATAL local game start failed: " .. tostring(started))
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
                if active and progress ~= nil and progress >= 1 then
                    -- 连服完成，引擎即将切游戏脚本：撤销兜底计时，防双起竞态。
                    print("[Lobby] server connection completed")
                    stopWaiting()
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
            else
                -- 联机成功被引擎切换：root 由引擎回收，但 UI 单例上下文必须自行销毁。
                shutdownLobbyUI()
            end
        end,
    }
end
