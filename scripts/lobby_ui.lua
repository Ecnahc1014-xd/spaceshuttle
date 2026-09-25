-- lobby_ui.lua
-- 联机大厅换皮（模板换皮路径）：引擎固定加载本文件，用 Lobby.DefineScreen 覆盖内置 5 屏外观。
--
-- 设计意图：
--   · 全部自绘 dark-tech（深海军底 + 酸青强调），不依赖任何外部图片资源。
--   · 玩家不需要点任何东西——进大厅即在 main 屏自动发起 Lobby.QuickMatch()。
--     配合 match_info{player_number:1, immediately_start:true}，等于「每个玩家自动分到一个
--     独立房间直接开打」，这就是本作要的「单机间接联机」：只要一个能跑 Shop.onDeliver 的服务端进程。
--   · 匹配 / 房间 / 连服流程仍由引擎托管，本文件只管外观与自动触发。
--
-- 沙箱约束：不 require、不碰裸 lobby/lobbyBridge；只用 Lobby.* + LobbyUI/LobbyState + urhox-libs/UI。

local Panel = UI.Panel

local DESIGN_W, DESIGN_H = 540, 960

-- 与游戏内 Scene3DBackend 同一套 dark-tech 令牌（同源，禁止另起一套配色）
local C = {
    bg      = { 7, 11, 20, 255 },
    panel   = { 10, 16, 28, 255 },
    card    = { 16, 26, 44, 255 },
    widget  = { 22, 36, 56, 255 },
    cyan    = { 0, 229, 208, 255 },
    cyanDim = { 0, 150, 148, 220 },
    ink     = { 4, 8, 16, 255 },
    text    = { 240, 248, 252, 255 },
    dim     = { 120, 148, 162, 255 },
}

local fontReady = false

local function ensureFont(nvg)
    if fontReady then return end
    fontReady = true
    local id = nvgCreateFont(nvg, "zpix", "Fonts/Zpix.ttf")
    if not id or id < 0 then
        nvgCreateFont(nvg, "sans", "Fonts/MiSans-Regular.ttf")
    end
end

---@param nvg any
---@param font string
local function useFont(nvg, font)
    local ok = pcall(function() nvgFontFace(nvg, font) end)
    if not ok then nvgFontFace(nvg, "sans") end
end

---@param nvg any
---@param x number
---@param y number
---@param str string
---@param size number
---@param color table
---@param align number|nil
local function text(nvg, x, y, str, size, color, align)
    useFont(nvg, "zpix")
    nvgFontSize(nvg, size)
    nvgTextAlign(nvg, align or (NVG_ALIGN_LEFT + NVG_ALIGN_TOP))
    nvgFillColor(nvg, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
    nvgText(nvg, x, y, str, nil)
end

---@param nvg any
---@param x number
---@param y number
---@param w number
---@param h number
---@param color table
---@param r number|nil
local function fillRect(nvg, x, y, w, h, color, r)
    nvgBeginPath(nvg)
    if r and r > 0 then
        nvgRoundedRect(nvg, x, y, w, h, r)
    else
        nvgRect(nvg, x, y, w, h)
    end
    nvgFillColor(nvg, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
    nvgFill(nvg)
end

-- ============================================================================
-- 自绘背景 Panel：整屏深底 + 微型网格 + 四角括号 + 状态文案 + 进度条
-- 用 Panel 子类承载，是为了在「数据驱动的控件树」里塞进自由绘制内容。
-- ============================================================================

local function visualProps(props, zIndex)
    props = props or {}
    props.position = props.position or "absolute"
    props.left = props.left == nil and 0 or props.left
    props.top = props.top == nil and 0 or props.top
    props.right = props.right == nil and 0 or props.right
    props.bottom = props.bottom == nil and 0 or props.bottom
    props.pointerEvents = "none"
    props.zIndex = props.zIndex == nil and (zIndex or 0) or props.zIndex
    return props
end

local function beginVisual(self, nvg)
    Panel.Render(self, nvg)
    local layout = self:GetAbsoluteLayout()
    nvgSave(nvg)
    nvgTranslate(nvg, layout.x, layout.y)
    nvgIntersectScissor(nvg, 0, 0, layout.w, layout.h)
    return layout
end

local function endVisual(nvg)
    nvgRestore(nvg)
end

---@param nvg any
---@param w number
---@param h number
local function drawChrome(nvg, w, h)
    -- 整屏不透明底：这既是设计背景，也顺手盖住了「引擎清屏 → 首帧覆盖层」之间的空档，
    -- 玩家不会再看到默认清屏色闪一下。
    fillRect(nvg, 0, 0, w, h, C.bg, 0)

    -- 极淡的微型网格（深海军底上的技术舱质感）
    nvgStrokeColor(nvg, nvgRGBA(C.cyan[1], C.cyan[2], C.cyan[3], 14))
    nvgStrokeWidth(nvg, 1)
    local step = 24
    nvgBeginPath(nvg)
    local gx = 0
    while gx <= w do
        nvgMoveTo(nvg, gx, 0)
        nvgLineTo(nvg, gx, h)
        gx = gx + step
    end
    local gy = 0
    while gy <= h do
        nvgMoveTo(nvg, 0, gy)
        nvgLineTo(nvg, w, gy)
        gy = gy + step
    end
    nvgStroke(nvg)

    -- 断线边框 + 四角括号
    local margin = math.max(14, math.min(w, h) * 0.026)
    nvgStrokeColor(nvg, nvgRGBA(C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 90))
    nvgStrokeWidth(nvg, 1.4)
    nvgBeginPath(nvg)
    nvgRect(nvg, margin, margin, w - margin * 2, h - margin * 2)
    nvgStroke(nvg)

    local len = math.max(18, math.min(w, h) * 0.045)
    nvgStrokeColor(nvg, nvgRGBA(C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 200))
    nvgStrokeWidth(nvg, 2)
    local corners = {
        { margin, margin, 1, 1 },
        { w - margin, margin, -1, 1 },
        { margin, h - margin, 1, -1 },
        { w - margin, h - margin, -1, -1 },
    }
    for i = 1, 4 do
        local c = corners[i]
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, c[1], c[2] + c[4] * len)
        nvgLineTo(nvg, c[1], c[2])
        nvgLineTo(nvg, c[1] + c[3] * len, c[2])
        nvgStroke(nvg)
    end
end

local TechBackground = Panel:Extend("LobbyTechBackground")

function TechBackground:Init(props)
    props = visualProps(props, -1000)
    self.title_ = props.title or "击碎，飞机大战"
    self.line1_ = props.line1 or ""
    self.line2_ = props.line2 or ""
    self.progress_ = props.progress or nil
    Panel.Init(self, props)
end

function TechBackground:Render(nvg)
    local layout = beginVisual(self, nvg)
    local w, h = layout.w, layout.h
    ensureFont(nvg)
    drawChrome(nvg, w, h)

    -- 居中内容：按设计画布比例缩放到实际尺寸，保证任意分辨率下版式一致
    local scale = math.min(w / DESIGN_W, h / DESIGN_H)
    local cx = w * 0.5
    local cy = h * 0.5

    text(nvg, cx, cy - 90 * scale, self.title_, 26 * scale, C.cyan,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    if self.line1_ ~= "" then
        text(nvg, cx, cy - 18 * scale, self.line1_, 24 * scale, C.text,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
    if self.line2_ ~= "" then
        text(nvg, cx, cy + 22 * scale, self.line2_, 18 * scale, C.dim,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end

    if self.progress_ then
        local barW, barH = 260 * scale, 4 * scale
        local bx, by = cx - barW * 0.5, cy + 82 * scale
        fillRect(nvg, bx, by, barW, barH, { C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 70 }, barH * 0.5)
        local ratio = math.max(0, math.min(1, self.progress_))
        if ratio > 0 then
            fillRect(nvg, bx, by, barW * ratio, barH, C.cyan, barH * 0.5)
        end
    end

    endVisual(nvg)
end

-- ============================================================================
-- 换皮工具
-- ============================================================================

local function skinBackground(ctrl, visual)
    if not ctrl then return end
    ctrl.style.background = C.bg
    ctrl:addChild(visual)
end

local function skinButton(ctrl, pos, visual)
    if not ctrl then return end
    ctrl:clearChildren()
    ctrl.style.position = "absolute"
    ctrl.style.background = { 0, 0, 0, 0 }
    for k, v in pairs(pos) do ctrl.style[k] = v end
    ctrl:addChild(visual)
end

-- 主操作按钮（青底深字）：与游戏内 CTA 同款
local PrimaryButtonVisual = Panel:Extend("LobbyPrimaryButtonVisual")

function PrimaryButtonVisual:Init(props)
    props = visualProps(props, 0)
    self.label_ = props.label or ""
    Panel.Init(self, props)
end

function PrimaryButtonVisual:Render(nvg)
    local layout = beginVisual(self, nvg)
    local w, h = layout.w, layout.h
    ensureFont(nvg)
    fillRect(nvg, 0, 0, w, h, C.cyan, 8)
    text(nvg, w * 0.5, h * 0.5 - 11, self.label_, 20, C.ink,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    endVisual(nvg)
end

-- 次要按钮（描边卡片）
local GhostButtonVisual = Panel:Extend("LobbyGhostButtonVisual")

function GhostButtonVisual:Init(props)
    props = visualProps(props, 0)
    self.label_ = props.label or ""
    Panel.Init(self, props)
end

function GhostButtonVisual:Render(nvg)
    local layout = beginVisual(self, nvg)
    local w, h = layout.w, layout.h
    ensureFont(nvg)
    fillRect(nvg, 0, 0, w, h, C.card, 8)
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, 0.5, 0.5, w - 1, h - 1, 8)
    nvgStrokeColor(nvg, nvgRGBA(C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 200))
    nvgStrokeWidth(nvg, 1.4)
    nvgStroke(nvg)
    text(nvg, w * 0.5, h * 0.5 - 10, self.label_, 18, C.text,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    endVisual(nvg)
end

-- ============================================================================
-- 各屏构建
-- ============================================================================

-- 匹配超时兜底句柄（重新进屏时要取消上一个，避免叠加定时器）
local waitTimer = nil
local verifyTimer = nil       -- 兜底事后校验句柄
local matchFailed = false     -- 上一次兜底是否也没能开局，用于主界面给出明确提示

---@param fn fun()
---@return boolean
local function tryCall(fn)
    local ok, err = pcall(fn)
    if not ok then
        print("[lobby_ui] call failed: " .. tostring(err))
    end
    return ok
end

-- 自动快速匹配：玩家不需要点任何东西。
-- 用一次性标志，避免从「取消匹配」返回主界面后又被立刻拽回匹配队列。
local autoMatched = false

local function buildMain()
    skinBackground(LobbyUI.main.background, TechBackground {
        title = "击碎，飞机大战",
        line1 = "正在加载服务器",
        line2 = "5 秒之后自动加入这个单机模式",
    })

    -- 快速匹配是唯一主操作，也给玩家一个可点的落点（自动触发失败时的兜底）。
    skinButton(LobbyUI.main.quick_match_button,
        { left = "50%", marginLeft = -110, top = "66%", width = 220, height = 60 },
        PrimaryButtonVisual { label = "开始游戏" })

    -- 浏览房间 / 创建房间：本作不做多人同场，直接藏掉，避免玩家误入。
    if LobbyUI.main.browse_button then
        LobbyUI.main.browse_button.visible = false   -- ⚠️ visible 在控件本体上，不在 style 代理里
    end
    if LobbyUI.main.create_button then
        LobbyUI.main.create_button.visible = false
    end
    if LobbyUI.main.exit_button then
        skinButton(LobbyUI.main.exit_button,
            { left = "50%", marginLeft = -80, top = "78%", width = 160, height = 48 },
            GhostButtonVisual { label = "退出" })
    end

    -- 自动发起快速匹配：player_number=1 + immediately_start → 每人独占一房，秒开。
    if matchFailed and not Lobby.IsMatching() then
        -- 兜底都失败过：允许再次自动尝试（玩家重进主界面时给一条活路）
        matchFailed = false
        autoMatched = false
    end
    -- 连续失败时把副标题换成明确状态，玩家不会以为"卡住了"
    if matchFailed then
        skinBackground(LobbyUI.main.background, TechBackground {
            title = "击碎，飞机大战",
            line1 = "连接失败",
            line2 = "点「开始游戏」重试",
        })
    end
    if not autoMatched then
        autoMatched = true
        if tryCall(function() Lobby.QuickMatch() end) then
            print("[lobby_ui] auto QuickMatch fired")
        else
            print("[lobby_ui] auto QuickMatch failed, stay on main")
        end
    end
end

-- 5 秒还没匹配上 → 取消匹配并尝试直接开局（等价于"自动加入单机模式"）。
-- 沙箱里没有「直接起本地游戏」的动作，能用的只有 Lobby.StartGame()；
-- 它失败时退回主界面，让玩家自己点「开始游戏」，不会卡在等待页。
-- 前向声明：onMatchTimeout 里要调用它；不先声明会被 Lua 当成全局查找 → nil
local escalate

local function onMatchTimeout()
    waitTimer = nil
    if Lobby.IsMatching() then
        tryCall(function() Lobby.CancelMatch() end)
    end

    -- 兜底 1：直接开局（等价于进单机）
    if tryCall(function() Lobby.StartGame() end) then
        print("[lobby_ui] match timeout -> StartGame (solo)")
        -- ⚠️ StartGame 返回成功**不等于**真的进了游戏。挂一次事后校验：
        --    2 秒后若仍在匹配/房间态，判定为软失败，继续走下一级兜底。
        if verifyTimer then pcall(function() Timer.cancel(verifyTimer) end) end
        verifyTimer = Timer.after(2000, function()
            verifyTimer = nil
            if Lobby.IsMatching() or Lobby.IsInRoom() then
                print("[lobby_ui] StartGame soft-failed, escalating")
                escalate()
            end
        end)
        return
    end

    escalate()
end

-- 下一级兜底：再试一次快速匹配；仍不行就回主界面给出明确状态。
escalate = function()
    if tryCall(function() Lobby.QuickMatch() end) then
        print("[lobby_ui] -> retry QuickMatch")
        return
    end
    matchFailed = true
    print("[lobby_ui] all fallbacks failed, back to main")
    tryCall(function() Lobby.GotoMain() end)
end

local function buildQuickMatchWaiting()
    local elapsed = (LobbyState.matchmaking and LobbyState.matchmaking.elapsed) or 0
    skinBackground(LobbyUI.quick_match_waiting.background, TechBackground {
        title = "击碎，飞机大战",
        line1 = "正在加载服务器",
        line2 = "5 秒之后自动加入这个单机模式",
        progress = math.min(1, elapsed / 5),
    })
    skinButton(LobbyUI.quick_match_waiting.cancel_button,
        { left = "50%", marginLeft = -80, top = "78%", width = 160, height = 48 },
        GhostButtonVisual { label = "取消" })

    -- 5 秒兜底：到点仍未匹配成功就自动进单机，不再无限等下去。
    if waitTimer then
        pcall(function() Timer.cancel(waitTimer) end)
        waitTimer = nil
    end
    waitTimer = Timer.after(5000, onMatchTimeout)
end

local function buildConnecting()
    local progress = (LobbyState.connecting and LobbyState.connecting.progress) or 0
    skinBackground(LobbyUI.connecting.background, TechBackground {
        title = "击碎，飞机大战",
        line1 = "正在进入战场",
        line2 = "",
        progress = progress,
    })
end

local function buildRoomList()
    skinBackground(LobbyUI.room_list.background, TechBackground {
        title = "击碎，飞机大战",
        line1 = "正在加载服务器",
        line2 = "5 秒之后自动加入这个单机模式",
    })
end

local function buildRoomWaiting()
    skinBackground(LobbyUI.room_waiting.background, TechBackground {
        title = "击碎，飞机大战",
        line1 = "正在进入战场",
        line2 = "",
    })
end

-- 引擎的 LobbyScreenDef 类型要求列全可选回调；这里补空实现，只覆盖需要的。
---@param def table
---@return LobbyScreenDef
local function screenDef(def)
    def.onRoomList = def.onRoomList or function() end
    def.onRoomPlayers = def.onRoomPlayers or function() end
    def.onServerProgress = def.onServerProgress or function() end
    return def
end

-- ============================================================================
-- 注册（未覆盖的弹窗沿用引擎默认模板）
-- ============================================================================

Lobby.DefineScreen("main", screenDef { enter = buildMain })
Lobby.DefineScreen("quick_match_waiting", screenDef { enter = buildQuickMatchWaiting })
Lobby.DefineScreen("room_list", screenDef { enter = buildRoomList })
Lobby.DefineScreen("room_waiting", screenDef { enter = buildRoomWaiting })
Lobby.DefineScreen("connecting", screenDef { enter = buildConnecting })

print("[lobby_ui] dark-tech lobby skin registered (auto quick match)")
