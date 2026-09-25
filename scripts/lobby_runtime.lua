-- lobby_runtime.lua
-- 自建联机入口：1 人秒开匹配；超时 / 异常 → 置离线标志后进本地单机。
--
-- UI 无污染：**完全自绘 NanoVG**，不引入 urhox-libs/UI，也不使用任何平台默认大厅 UI。
-- 整屏用不透明底色填充，盖住「引擎清屏 → 覆盖层就绪」之间那一帧的默认清屏色。
-- 本层生命周期独立：stop 时先 nvgDelete 自己的上下文，再让游戏建自己的，
-- 保证同一帧内永远不会有两个 NanoVG 上下文。

local GameMode = require "GameMode"

local DESIGN_W, DESIGN_H = 540, 960

local C = {
    bg      = {7, 11, 20, 255},
    panel   = {10, 16, 28, 255},
    cyan    = {0, 229, 208, 255},
    cyanDim = {0, 150, 148, 220},
    text    = {240, 248, 252, 255},
    dim     = {120, 148, 162, 255},
}

local vg = nil
local fontZpix = -1
local scale, offsetX, offsetY = 1, 0, 0
local elapsed = 0
local resolved = false
local subscribed = false

local TIMEOUT_SECONDS = 5

local M = {}

-- 降级离线：**必须先销毁自己的 NanoVG 上下文**，游戏才能安全建自己的。
-- 否则同一帧内两个 nvg 上下文各画各的 BeginFrame/EndFrame，合成顺序不稳定，
-- 真机表现为「游戏 UI 只剩零星几个元素」。
local function GoOffline(reason)
    if resolved then return end
    resolved = true
    GameMode.SetOffline(true)
    print("[Lobby] " .. reason .. " -> offline single-player")
    M.stop()
    local ok, err = pcall(function()
        require("local_game").start()
    end)
    if not ok then
        print("[Lobby] local start failed: " .. tostring(err))
    end
end

local function UseFont()
    if fontZpix and fontZpix >= 0 then
        nvgFontFace(vg, "zpix")
    else
        nvgFontFace(vg, "sans")
    end
end

---@param x number
---@param y number
---@param text string
---@param size number
---@param color table
---@param align number|nil
local function Text(x, y, text, size, color, align)
    UseFont()
    nvgFontSize(vg, size)
    nvgTextAlign(vg, align or (NVG_ALIGN_LEFT + NVG_ALIGN_TOP))
    nvgFillColor(vg, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
    nvgText(vg, x, y, text, nil)
end

local function UpdateMetrics()
    local physW, physH = graphics:GetWidth(), graphics:GetHeight()
    local dpr = graphics:GetDPR()
    if not dpr or dpr <= 0 then dpr = 1 end
    local logicalW, logicalH = physW / dpr, physH / dpr
    scale = math.min(logicalW / DESIGN_W, logicalH / DESIGN_H)
    offsetX = (logicalW - DESIGN_W * scale) * 0.5
    offsetY = (logicalH - DESIGN_H * scale) * 0.5
end

-- 深色底 + 四角括号 + 断线边框：与游戏内 UI 同一套 dark-tech 视觉语言。
local function DrawChrome()
    local margin = 18
    local w = DESIGN_W - margin * 2
    local h = DESIGN_H - margin * 2
    nvgStrokeColor(vg, nvgRGBA(C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 90))
    nvgStrokeWidth(vg, 1.4)
    nvgBeginPath(vg)
    nvgRect(vg, margin, margin, w, h)
    nvgStroke(vg)

    local len = 26
    nvgStrokeColor(vg, nvgRGBA(C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 200))
    nvgStrokeWidth(vg, 2)
    local corners = {
        { margin, margin, 1, 1 },
        { margin + w, margin, -1, 1 },
        { margin, margin + h, 1, -1 },
        { margin + w, margin + h, -1, -1 },
    }
    for i = 1, 4 do
        local c = corners[i]
        nvgBeginPath(vg)
        nvgMoveTo(vg, c[1], c[2] + c[4] * len)
        nvgLineTo(vg, c[1], c[2])
        nvgLineTo(vg, c[1] + c[3] * len, c[2])
        nvgStroke(vg)
    end
end

---@param eventType string
---@param eventData UpdateEventData
local function HandleUpdate(eventType, eventData)
    local dt = eventData:GetFloat("TimeStep")
    elapsed = elapsed + dt
    if resolved then return end
    if elapsed >= TIMEOUT_SECONDS then
        GoOffline("match timeout")
    end
end

local function HandleRender()
    if not vg then return end
    nvgBeginFrame(vg, graphics:GetWidth() / graphics:GetDPR(), graphics:GetHeight() / graphics:GetDPR(), 1.0)
    nvgResetTransform(vg)
    nvgResetScissor(vg)
    nvgGlobalAlpha(vg, 1.0)
    nvgScale(vg, scale, scale)

    -- 整屏不透明填充：这既是设计背景，也是「切换那一帧」的兜底，杜绝灰屏。
    nvgBeginPath(vg)
    nvgRect(vg, -DESIGN_W, -DESIGN_H, DESIGN_W * 3, DESIGN_H * 3)
    nvgFillColor(vg, nvgRGBA(C.bg[1], C.bg[2], C.bg[3], 255))
    nvgFill(vg)

    nvgTranslate(vg, offsetX, offsetY)
    DrawChrome()

    local cx = DESIGN_W * 0.5
    Text(cx, 400, "击碎，飞机大战", 26, C.cyan, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    Text(cx, 472, "正在加载服务器", 24, C.text, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    Text(cx, 512, "5 秒之后自动加入这个单机模式", 18, C.dim,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    -- 进度条（不是文字，只表达「还剩多久」）
    local barW, barH = 260, 4
    local bx, by = cx - barW * 0.5, 572
    nvgBeginPath(vg)
    nvgRect(vg, bx, by, barW, barH)
    nvgFillColor(vg, nvgRGBA(C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 70))
    nvgFill(vg)
    local ratio = math.min(1, elapsed / TIMEOUT_SECONDS)
    if ratio > 0 then
        nvgBeginPath(vg)
        nvgRect(vg, bx, by, barW * ratio, barH)
        nvgFillColor(vg, nvgRGBA(C.cyan[1], C.cyan[2], C.cyan[3], 255))
        nvgFill(vg)
    end

    nvgEndFrame(vg)
end

function M.start(ctx)
    GameMode.SetOffline(false)
    elapsed = 0
    resolved = false

    UpdateMetrics()
    vg = nvgCreate(1)
    fontZpix = nvgCreateFont(vg, "zpix", "Fonts/Zpix.ttf")
    if not fontZpix or fontZpix < 0 then
        nvgCreateFont(vg, "sans", "Fonts/MiSans-Regular.ttf")
    end

    -- ⚠️ 用函数引用订阅：字符串名按文件作用域解析，跨文件会静默失效。
    SubscribeToEvent("Update", HandleUpdate)
    SubscribeToEvent(vg, "NanoVGRender", HandleRender)
    subscribed = true

    ctx.permanent = false
    print("[Lobby] self-drawn lobby started, timeout=" .. TIMEOUT_SECONDS .. "s")

    -- 1 人秒开：配置了 immediately_start + player_number=1，这里主动拉一次匹配。
    local okMatch, errMatch = pcall(function()
        local bridge = ctx.lobby
        if bridge and bridge.StartMatch then
            bridge:StartMatch()
        end
    end)
    if not okMatch then
        -- 匹配发起异常 → 立刻降级离线，不等 5 秒。
        print("[Lobby] StartMatch failed: " .. tostring(errMatch))
        GoOffline("StartMatch error")
        return
    end

    ctx.Update = function(dt)
        -- 时间推进走事件订阅，这里留空避免双重计时。
    end
end

function M.stop()
    if not subscribed then return end
    subscribed = false
    -- ⚠️ 只退订自己订阅的事件；禁止 UnsubscribeFromAllEvents（会误伤即将启动的游戏）。
    -- ⚠️ 单参数形式才是 (eventName)；传两个参数会被解析成 (sender, eventName) 并报
    --    「argument #1 is 'string'; 'userdata' expected」。
    pcall(function() UnsubscribeFromEvent("Update") end)
    pcall(function() UnsubscribeFromEvent("NanoVGRender") end)
    -- ⚠️ 必须先销毁自己的 NanoVG 上下文，游戏才能建自己的，否则同帧两个上下文抢帧。
    if vg then
        nvgDelete(vg)
        vg = nil
    end
    print("[Lobby] stopped, nvg context released")
end

return M
