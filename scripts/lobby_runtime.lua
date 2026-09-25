-- lobby_runtime.lua
-- 「单机间接联机」的大厅：只做一件事——把玩家送进对局。
--
-- 成功匹配 → 引擎自动连服并切到游戏脚本（本文件不做任何切场景的代码）。
-- 5s 超时 / 匹配失败 → GameMode.SetOffline(true) 后直接在本 Runtime 里启动本地游戏。
--
-- ⚠️ UI 无污染：大厅是进游戏前的另一段 Runtime，用 urhox-libs/UI；
--    游戏本身的 NanoVG 标题/HUD/战斗界面零迁移，退出大厅后由引擎回收 ctx.root。
-- ⚠️ stop 里只退订自己订阅的事件，禁止 UnsubscribeFromAllEvents（会误伤即将启动的游戏）。

local UI = require "urhox-libs.UI"
local DarkTechTheme = require "ui.DarkTechTheme"
local GameMode = require "GameMode"

local MATCH_TIMEOUT_SEC = 5
local LOCAL_GAME_MODULE = "local_game"

local function BuildLobby(ctx)
    local client, root = ctx.client, ctx.root
    -- ⚠️ 必须用项目自己的 dark-tech 主题初始化，否则联机界面会是一套陌生风格。
    UI.Init({ theme = DarkTechTheme, scale = UI.Scale.DEFAULT })
    UI.SetRoot(root)

    local elapsed = 0
    local resolved = false          -- 已匹配成功 / 已降级，停止计时
    local localGame = nil
    local updateSub = nil

    -- ---------------------------------------------------------------- 界面
    local statusLabel = UI.Label {
        text = "正在匹配对局…",
        fontSize = 20,
    }
    local hintLabel = UI.Label {
        text = "匹配到的服务端用于内购发货与余额校验",
        fontSize = 13,
    }
    local titleLabel = UI.Label {
        text = "击碎，飞机大战",
        fontSize = 26,
    }
    -- 深海军底 + 酸青焦点：与游戏内 NanoVG 界面同一套 dark-tech 令牌。
    local screen = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = "background",
        justifyContent = "center", alignItems = "center",
        gap = 16,
        children = { titleLabel, statusLabel, hintLabel },
    }
    -- 用换根的方式挂载，而不是直接改 root.children（组件树由 UI 库持有）。
    UI.SetRoot(screen, true)

    local function setStatus(text, hint)
        statusLabel:SetText(text)
        if hint then hintLabel:SetText(hint) end
    end

    -- ---------------------------------------------------------------- 本地游戏
    local beginMatch  -- 前置声明：本地游戏退出时要重新发起匹配

    local function startLocalGame(reason)
        if resolved then return end
        resolved = true
        GameMode.SetOffline(true)
        setStatus("单机模式启动中…", reason)

        local ok, mod = pcall(function()
            return require(LOCAL_GAME_MODULE)
        end)
        if not ok or type(mod) ~= "table" or type(mod.start) ~= "function" then
            setStatus("本地游戏加载失败", tostring(mod))
            return
        end
        -- ⚠️ 关键：必须**销毁** UI 根节点，而不是只清 children。
        -- 组件树被 urhox-libs/UI 持有，仅置空 children 不会停掉它的渲染层，
        -- 结果是全屏面板一直盖住游戏自己的 NanoVG 界面（表现为「2D 页面全没了」）。
        UI.SetRoot(nil, true)
        localGame = mod.start({
            root = root,
            onExit = function()
                if localGame and localGame.stop then localGame.stop() end
                localGame = nil
                resolved = false
                elapsed = 0
                UI.SetRoot(screen, true)
                setStatus("正在匹配对局…")
                beginMatch()
            end,
            onOnline = function()
                -- 本地游玩期间不提供转联机：本作是单机玩法，联机只承担发货与余额。
            end,
        })
    end

    -- ---------------------------------------------------------------- 匹配
    beginMatch = function()
        if resolved then return end
        client:StartMatch({
            onStarted = function()
                print("[Lobby] matchmaking started")
            end,
            onMatchFound = function(serverInfo)
                resolved = true
                print("[Lobby] match found, engine will connect and switch to game script")
                setStatus("已匹配，正在进入…", "")
                -- 交给引擎前先拆掉组件层，避免残留渲染层盖住游戏界面。
                UI.SetRoot(nil, true)
            end,
            onProgress = function(progress, status)
                if resolved then return end
                local pct = math.floor((progress or 0) * 100)
                setStatus("正在连接服务器… " .. tostring(pct) .. "%", status)
            end,
            onError = function(code, message)
                print("[Lobby] match failed code=" .. tostring(code)
                    .. " msg=" .. tostring(message))
                startLocalGame("匹配失败，已降级单机（可离线游玩）")
            end,
        })
    end

    -- ---------------------------------------------------------------- 计时
    local function tickUpdate(eventType, eventData)
        if resolved then return end
        local dt = 0
        pcall(function()
            dt = eventData:GetFloat("TimeStep")
        end)
        elapsed = elapsed + (dt or 0)
        if elapsed >= MATCH_TIMEOUT_SEC then
            print("[Lobby] matchmaking timeout after " .. tostring(MATCH_TIMEOUT_SEC) .. "s")
            pcall(function() client:CancelMatch() end)
            startLocalGame("匹配超时，已降级单机")
        end
    end
    -- 传函数值订阅：字符串名按文件作用域解析，跨文件/闭包会静默失效。
    SubscribeToEvent("Update", tickUpdate)
    updateSub = tickUpdate

    -- 未登录 / 平台离线时直接走单机，不必等超时。
    if client.IsOnline and not client:IsOnline() then
        startLocalGame("未登录，直接进入单机")
    else
        beginMatch()
    end

    return {
        stop = function()
            -- 只退订自己订阅的事件；禁止 UnsubscribeFromAllEvents（会误伤即将启动的游戏）。
            if updateSub then
                local handler = updateSub --[[@as any]]
                UnsubscribeFromEvent("Update", handler)
                updateSub = nil
            end
            if localGame and localGame.stop then
                localGame.stop()
                localGame = nil
            end
            print("[Lobby] stopped")
        end,
    }
end

return BuildLobby
