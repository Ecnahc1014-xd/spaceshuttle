-- lobby_runtime.lua
-- 「单机间接联机」的大厅：只做一件事——把玩家送进对局。
--
-- 成功匹配 → 引擎自动连服并切到游戏脚本（本文件不做任何切场景的代码）。
-- 5s 超时 / 匹配失败 / 未登录 → GameMode.SetOffline(true) 后直接启动本地游戏。
--
-- 🔴 UI 全部自绘 NanoVG（ui/LoadingScreen），**不使用 urhox-libs/UI**：
--    组件路线的默认主题会在换根瞬间透出（“先变灰一下”），且主题解析失败时配色漂移。
--    自绘能保证第一帧就是深海军底，且与游戏内 HUD/面板同一套 dark-tech 令牌。
--    文案只有两行，由产品要求写死，不加任何解释性文字。
--
-- ⚠️ stop 里只退订自己订阅的事件，禁止 UnsubscribeFromAllEvents（会误伤即将启动的游戏）。

local LoadingScreen = require "ui.LoadingScreen"
local GameMode = require "GameMode"

local MATCH_TIMEOUT_SEC = 5
local LOCAL_GAME_MODULE = "local_game"

local TITLE = "击碎，飞机大战"

local function BuildLobby(ctx)
    local client = ctx.client
    local elapsed = 0
    local resolved = false      -- 已匹配成功 / 已降级，停止计时
    local localGame = nil

    LoadingScreen.Start({
        title = TITLE,
        lines = {
            "正在加载服务器",
            string.format("%d 秒之后自动加入这个单机模式", MATCH_TIMEOUT_SEC),
        },
    })

    -- ---------------------------------------------------------------- 本地游戏
    -- ⚠️ beginMatch 必须**前置声明**：它被 startLocalGame 里的 onExit 闭包引用，
    --    声明写在后面的话闭包捕获到的是全局 nil（退出本地游戏后无法再匹配）。
    local beginMatch

    local startLocalGame = function(reason)
        if resolved then return end
        resolved = true
        print("[Lobby] fallback to local game: " .. tostring(reason))

        -- 本地游戏接管后大厅不再需要计时与加载画面。
        pcall(function() UnsubscribeFromEvent("Update") end)

        local ok, mod = pcall(function()
            return require(LOCAL_GAME_MODULE)
        end)
        if not ok or type(mod) ~= "table" or type(mod.start) ~= "function" then
            print("[Lobby] local game module unavailable: " .. tostring(mod))
            return
        end

        GameMode.SetOffline(true)
        -- 先把加载画面的 NanoVG 上下文删掉，避免和游戏自己的上下文打架。
        LoadingScreen.Stop()

        localGame = mod.start({
            root = ctx.root,
            onExit = function()
                if localGame and localGame.stop then localGame.stop() end
                localGame = nil
                resolved = false
                elapsed = 0
                LoadingScreen.Start({
                    title = TITLE,
                    lines = { "正在加载服务器",
                        string.format("%d 秒之后自动加入这个单机模式", MATCH_TIMEOUT_SEC) },
                })
                beginMatch()
            end,
            onOnline = function() end,
        })
    end

    -- ---------------------------------------------------------------- 匹配
    beginMatch = function()
        if resolved then return end
        local ok = pcall(function()
            client:StartMatch({
                onStarted = function()
                    print("[Lobby] matchmaking started")
                end,
                onMatchFound = function(serverInfo)
                    resolved = true
                    print("[Lobby] match found, engine will connect and switch to game script")
                    -- ⚠️ 必须在这里拆掉加载画面的 NanoVG 上下文：
                    --    游戏会创建自己的上下文，两者同时在世会抢同一帧、合成顺序不稳定
                    --    （表现为游戏 UI 只剩零星元素）。
                    --    拆掉后到游戏首帧之间的空档，由 Scene3DBackend 的「首帧兜底
                    --    深色底」接住，不会露出引擎清屏色。
                    LoadingScreen.Stop()
                end,
                onProgress = function(progress, status)
                    if resolved then return end
                    if status and status ~= "" then
                        LoadingScreen.SetLine(2, status)
                    end
                end,
                onError = function(code, message)
                    print("[Lobby] match failed code=" .. tostring(code)
                        .. " msg=" .. tostring(message))
                    startLocalGame("match error")
                end,
            })
        end)
        if not ok then
            print("[Lobby] StartMatch threw, going offline")
            startLocalGame("StartMatch threw")
        end
    end

    -- ---------------------------------------------------------------- 计时
    local function tickUpdate(eventType, eventData)
        if resolved then return end
        local dt = 0.016
        pcall(function() dt = eventData:GetFloat("TimeStep") end)
        elapsed = elapsed + (dt or 0.016)
        local left = math.max(0, math.ceil(MATCH_TIMEOUT_SEC - elapsed))
        LoadingScreen.SetLine(2, string.format("%d 秒之后自动加入这个单机模式", left))
        if elapsed >= MATCH_TIMEOUT_SEC then
            print("[Lobby] matchmaking timeout")
            pcall(function() client:CancelMatch() end)
            startLocalGame("timeout")
        end
    end

    -- 函数值订阅：字符串名按文件作用域解析，跨文件/闭包会静默失效。
    SubscribeToEvent("Update", tickUpdate)

    -- 未登录 / 平台离线时不干等，直接进单机。
    local online = true
    pcall(function() online = client:IsOnline() end)
    if online then
        beginMatch()
    else
        startLocalGame("offline account")
    end

    return {
        stop = function()
            -- 只退订自己订阅的事件；禁止 UnsubscribeFromAllEvents（会误伤即将启动的游戏）。
            pcall(function() UnsubscribeFromEvent("Update") end)
            LoadingScreen.Stop()
            if localGame and localGame.stop then
                localGame.stop()
                localGame = nil
            end
            print("[Lobby] stopped")
        end,
    }
end

return BuildLobby
