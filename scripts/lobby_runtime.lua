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
    -- ⚠️ 这三个必须**在 UI 闭包创建之前**声明：Lua 的闭包捕获的是「创建时可见的局部变量」，
    --    声明写在按钮之后的话，按钮回调里拿到的是全局 nil（点了没反应）。
    local startLocalGame      -- 降级进入单机
    local startLocalGameRef   -- 同上，供按钮/事件回调引用
    local beginMatch          -- 发起匹配（本地游戏退出后要能重发）
    -- ⚠️ 必须用项目自己的 dark-tech 主题初始化，否则联机界面会是一套陌生风格。
    -- 包 pcall：主题/UI 初始化失败也要能继续走到「超时进单机」。
    local okUi, errUi = pcall(function()
        UI.Init({ theme = DarkTechTheme, scale = UI.Scale.DEFAULT })
    end)
    if not okUi then
        print("[Lobby] UI.Init failed (continue anyway): " .. tostring(errUi))
    end
    UI.SetRoot(root)

    local elapsed = 0
    local resolved = false          -- 已匹配成功 / 已降级，停止计时
    local localGame = nil

    -- ---------------------------------------------------------------- 界面
    -- dark-tech 令牌（与 Scene3DBackend.C 同源，改色两处一起改）
    local CYAN, TEXT, DIM, WARN = {0,229,208,255}, {240,248,252,255}, {120,148,162,255}, {255,196,72,255}

    local titleLabel = UI.Label {
        text = "击碎，飞机大战",
        fontSize = 30,
        color = CYAN,
    }
    local statusLabel = UI.Label {
        text = "正在连接服务器…",
        fontSize = 20,
        color = TEXT,
    }
    local hintLabel = UI.Label {
        text = "服务器只负责内购发货与钻石余额",
        fontSize = 14,
        color = DIM,
    }
    local countLabel = UI.Label {
        text = string.format("%d 秒后自动进入单机", MATCH_TIMEOUT_SEC),
        fontSize = 14,
        color = DIM,
    }
    local skipBtn = UI.Button {
        text = "不等了，直接单机开始",
        onClick = function()
            if startLocalGameRef then startLocalGameRef("你选择了直接单机") end
        end,
    }
    -- 深海军底 + 酸青焦点：与游戏内 NanoVG 界面同一套 dark-tech 令牌。
    local screen = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = "background",
        justifyContent = "center", alignItems = "center",
        gap = 14,
        children = { titleLabel, statusLabel, hintLabel, countLabel, skipBtn },
    }
    -- 用换根的方式挂载，而不是直接改 root.children（组件树由 UI 库持有）。
    UI.SetRoot(screen, true)

    local function setStatus(text, hint)
        statusLabel:SetText(text)
        if hint and hint ~= "" then hintLabel:SetText(hint) end
    end

    local function setCountdown(secondsLeft)
        if secondsLeft > 0 then
            countLabel:SetText(string.format("%d 秒后自动进入单机", secondsLeft))
        else
            countLabel:SetText("")
        end
    end

    -- ---------------------------------------------------------------- 本地游戏
    startLocalGame = function(reason)
        if resolved then return end
        resolved = true
        GameMode.SetOffline(true)
        setStatus("正在进入单机模式…", reason or "")
        -- 本地游戏接管后大厅不再需要计时。
        pcall(function() UnsubscribeFromEvent("Update") end)

        local ok, mod = pcall(function()
            return require(LOCAL_GAME_MODULE)
        end)
        if not ok or type(mod) ~= "table" or type(mod.start) ~= "function" then
            setStatus("游戏加载失败", tostring(mod))
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
                setStatus("正在连接服务器…")
                beginMatch()
            end,
            onOnline = function()
                -- 本地游玩期间不提供转联机：本作是单机玩法，联机只承担发货与余额。
            end,
        })
    end
    startLocalGameRef = startLocalGame

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
                startLocalGame("连不上服务器，已进入单机模式")
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
        setCountdown(math.max(0, math.ceil(MATCH_TIMEOUT_SEC - elapsed)))
        if elapsed >= MATCH_TIMEOUT_SEC then
            print("[Lobby] matchmaking timeout after " .. tostring(MATCH_TIMEOUT_SEC) .. "s")
            pcall(function() client:CancelMatch() end)
            startLocalGame("连接超时，已进入单机模式")
        end
    end
    -- 传函数值订阅：字符串名按文件作用域解析，跨文件/闭包会静默失效。
    SubscribeToEvent("Update", tickUpdate)

    -- 未登录 / 平台离线时直接走单机，不必等超时。
    if client.IsOnline and not client:IsOnline() then
        startLocalGame("未登录，直接进入单机")
    else
        beginMatch()
    end

    return {
        stop = function()
            -- ⚠️ UnsubscribeFromEvent 只有 (eventName) 和 (sender, eventName) 两种签名，
            --    传 ("Update", handler) 会把字符串当 sender，直接报
            --    「argument #1 is 'string'; 'userdata' expected」并中断入口停止。
            --    这里按事件名退订；**禁止** UnsubscribeFromAllEvents（会误伤即将启动的游戏）。
            -- 再包一层 pcall：入口停止阶段绝不允许抛错（曾导致
            -- 「[LobbyBootstrap] 入口停止失败」+ 后续 Function name='' 的连锁故障）。
            pcall(function() UnsubscribeFromEvent("Update") end)
            -- 拆掉 UI 组件层，避免残留渲染层盖住游戏界面。
            pcall(function() UI.SetRoot(nil, true) end)
            if localGame and localGame.stop then
                localGame.stop()
                localGame = nil
            end
            print("[Lobby] stopped")
        end,
    }
end

return BuildLobby
