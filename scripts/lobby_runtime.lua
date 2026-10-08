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
-- 4. v0.12.5：平台 SystemNotification 必须换皮成 dark-tech 顶部通知条，禁止
--    默认白底弹窗直出（用户否决）。大厅与游戏是两个 Runtime，切换后各自注册。
-- 5. v0.12.7：加载页必须是游戏自己的 dark-tech 窗口壳（标题栏+识别条+断线+
--    进度轨+扫描点），禁止素色裸面板（用户否决「我的 ui 风格化呢」）。
--    只用 urhox-libs/UI 组件拼装，不引 raw NanoVG——降级顺序契约不变。
--    动态更新走 SetText / SetStyle（urhox-libs/UI 无 ref 机制，控件构建期
--    先拿到局部变量再组装进 children，禁止按下标遍历控件树）。

local UI = require "urhox-libs/UI"
local GameMode = require "GameMode"
local SysNotif = require "urhox-libs.System.SystemNotification"

-- dark-tech 令牌（与 Scene3DBackend.C 同源；改配色两边一起改）
local COL = {
    bg      = { 7, 11, 20, 255 },
    panel   = { 10, 16, 28, 255 },
    card    = { 16, 26, 44, 255 },
    rail    = { 22, 36, 56, 255 },
    cyan    = { 0, 229, 208, 255 },
    cyanDim = { 0, 150, 148, 220 },
    text    = { 240, 248, 252, 255 },
    dim     = { 120, 148, 162, 255 },
    warn    = { 255, 196, 72, 255 },
}
local WAIT_SECONDS = 5

return function(ctx)
    local root, client = ctx.root, ctx.client
    local active = true
    local localStarted = false
    local uiShutdown = false
    local updateSubscribed = false
    local elapsed = 0
    GameMode.SetOffline(false)

    -- v0.12.5：顶部通知条（大厅阶段）。绝对定位，按需 AddChild/Destroy。
    ---@type table|nil
    local bannerWidget = nil
    local bannerTimer = 0

    local function hideBanner()
        if bannerWidget then
            pcall(function() bannerWidget:Destroy() end)
            bannerWidget = nil
        end
        bannerTimer = 0
    end

    local function showBanner(title, message)
        hideBanner()
        bannerWidget = UI.Panel {
            position = "absolute",
            top = 18,
            left = "7%", width = "86%",
            padding = 14,
            flexDirection = "column", gap = 6,
            backgroundColor = COL.panel,
            borderColor = COL.warn, borderWidth = 1,
            borderRadius = 8,
            children = {
                UI.Label { text = title or "连接提示", fontSize = 18,
                    fontColor = COL.warn },
                UI.Label { text = message or "", fontSize = 14,
                    fontColor = COL.text, textAlign = "left" },
            },
        }
        root:AddChild(bannerWidget)
        bannerTimer = 15
    end

    pcall(function()
        SysNotif.RegisterHandler(function(info)
            local ok, view = pcall(function() return SysNotif.Resolve(info) end)
            if not ok or type(view) ~= "table" then return false end
            local message = view.message or ""
            if view.reason and view.reason ~= "" then
                message = message .. " 原因：" .. view.reason
            end
            showBanner(view.title or "连接提示", message)
            print("[Lobby] system notification banner: " .. tostring(view.id))
            return true
        end)
    end)

    -- =========================================================================
    -- dark-tech 加载窗口壳。控件先建为局部变量，再组装进 children；
    -- 运行期用 SetText / SetStyle 更新（无 ref 机制，也禁止按下标遍历控件树）。
    -- =========================================================================
    local statusLabel = UI.Label { text = "正在连接服务器", fontSize = 26,
        fontColor = COL.text, textAlign = "center" }
    local subLabel = UI.Label { text = WAIT_SECONDS .. " 秒后自动进入单机模式",
        fontSize = 15, fontColor = COL.dim, textAlign = "center" }
    local fillWidget = UI.Panel { width = "8%", height = 10, borderRadius = 5,
        backgroundColor = COL.cyan }
    local dot1 = UI.Panel { width = 8, height = 8, borderRadius = 4,
        backgroundColor = { COL.cyan[1], COL.cyan[2], COL.cyan[3], 240 } }
    local dot2 = UI.Panel { width = 8, height = 8, borderRadius = 4,
        backgroundColor = { COL.cyan[1], COL.cyan[2], COL.cyan[3], 70 } }
    local dot3 = UI.Panel { width = 8, height = 8, borderRadius = 4,
        backgroundColor = { COL.cyan[1], COL.cyan[2], COL.cyan[3], 70 } }
    local dotWidgets = { dot1, dot2, dot3 }

    local view = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = COL.bg,
        alignItems = "center", justifyContent = "center",
        children = {
            UI.Panel {
                width = "90%", maxWidth = 460,
                flexDirection = "column",
                backgroundColor = COL.panel,
                borderColor = COL.cyanDim, borderWidth = 1,
                borderRadius = 6,
                children = {
                    -- 标题栏：青色识别竖条 + 游戏名 + 版本号
                    UI.Panel {
                        width = "100%", height = 46,
                        flexDirection = "row", alignItems = "center",
                        gap = 10, paddingLeft = 14, paddingRight = 16,
                        backgroundColor = COL.card,
                        borderTopLeftRadius = 6, borderTopRightRadius = 6,
                        children = {
                            UI.Panel { width = 4, height = 22, borderRadius = 2,
                                backgroundColor = COL.cyan },
                            UI.Label { text = "击碎，飞机大战", fontSize = 18,
                                fontColor = COL.cyan },
                            UI.Label { text = "v0.13.44", fontSize = 13,
                                fontColor = COL.dim, marginLeft = "auto" },
                        },
                    },
                    -- 断线分隔
                    UI.Panel { width = "100%", height = 1, backgroundColor = COL.cyanDim },
                    -- 内容区
                    UI.Panel {
                        width = "100%", padding = 28,
                        flexDirection = "column", alignItems = "center", gap = 16,
                        children = {
                            statusLabel,
                            -- 进度轨（rail 底 + 青色填充，按连服进度%）
                            UI.Panel {
                                width = "100%", height = 10, borderRadius = 5,
                                backgroundColor = COL.rail,
                                children = { fillWidget },
                            },
                            subLabel,
                            -- 扫描点（依次点亮，暗示链路活动）
                            UI.Panel {
                                flexDirection = "row", gap = 10, alignItems = "center",
                                children = { dot1, dot2, dot3 },
                            },
                        },
                    },
                },
            },
        },
    }
    root:AddChild(view)

    local function setStatus(text)
        if statusLabel then pcall(function() statusLabel:SetText(text) end) end
    end

    local function refreshCountdown()
        if not subLabel then return end
        local left = math.max(0, math.ceil(WAIT_SECONDS - elapsed))
        pcall(function() subLabel:SetText(left .. " 秒后自动进入单机模式") end)
    end

    local function setFill(percent)
        if not fillWidget then return end
        local p = math.max(0.02, math.min(1, percent or 0))
        pcall(function() fillWidget:SetStyle({ width = (p * 100) .. "%" }) end)
    end

    local dotAcc = 0
    local function tickDots(dt)
        dotAcc = dotAcc + dt
        if dotAcc < 0.22 then return end
        dotAcc = 0
        local lit = math.random(1, #dotWidgets)
        for i, w in ipairs(dotWidgets) do
            local a = i == lit and 240 or 60
            pcall(function()
                w:SetStyle({ backgroundColor = { COL.cyan[1], COL.cyan[2], COL.cyan[3], a } })
            end)
        end
    end

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
        hideBanner()
        pcall(function() view:Destroy() end)
        pcall(UI.Shutdown)
        pcall(SysNotif.UnregisterHandler)
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
        setStatus("连接失败，进入单机模式")
        goOffline()
    end)

    local function onUpdate(_, data)
        if not active then return end
        local step = data:GetFloat("TimeStep")
        elapsed = elapsed + step
        if bannerWidget then
            bannerTimer = bannerTimer - step
            if bannerTimer <= 0 then hideBanner() end
        end
        refreshCountdown()
        tickDots(step)
        if elapsed >= WAIT_SECONDS then goOffline() end
    end
    SubscribeToEvent("Update", onUpdate)
    updateSubscribed = true

    local ok, err = pcall(function()
        client:StartMatch {
            onStarted = function() print("[Lobby] matchmaking started") end,
            onMatchFound = function()
                print("[Lobby] server found, connecting")
                setStatus("正在接入战斗服务器")
                setFill(0.5)
            end,
            onProgress = function(progress)
                if not active then return end
                if progress ~= nil then
                    setFill(progress)
                    if progress >= 1 then
                        -- 连服完成，引擎即将切游戏脚本：撤销兜底计时，防双起竞态。
                        print("[Lobby] server connection completed")
                        setStatus("连接完成，正在进入")
                        stopWaiting()
                        -- v0.12.9 修复：nvgCreate 是**全局单例**，lobby 与游戏后端共用同一个
                        -- NanoVG 上下文。引擎不保证在新脚本 Init **之前**调用大厅的 stop()：
                        -- 晚 shutdown → UI.Shutdown 把游戏刚持有的上下文连带 nvgDelete（2D 全没）；
                        -- 不 shutdown → lobby 的空 UI 订阅持续抢帧（零星/全没，AB-093 同族）。
                        -- 成功路径当场幂等自毁，两条时序收敛为唯一安全顺序：
                        -- 销毁订阅+上下文 → 引擎切换 → 新脚本 nvgCreate 拿到干净单例。
                        shutdownLobbyUI()
                    end
                end
            end,
            onError = function(code, message)
                print("[Lobby] matchmaking failed: " .. tostring(code) .. " " .. tostring(message))
                setStatus("服务器不可用，进入单机模式")
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
