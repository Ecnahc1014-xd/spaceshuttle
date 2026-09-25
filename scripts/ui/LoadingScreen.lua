-- ui/LoadingScreen.lua
-- 全屏加载/等待画面：**自绘 NanoVG**，不使用 urhox-libs/UI。
--
-- 为什么自绘：组件路线的默认主题会在换根瞬间透出（表现为「先变灰一下」），
-- 且主题解析失败时整套配色会漂移。自绘可以保证：
--   ① 第一帧就是我们的深海军底，没有默认主题的过渡帧；
--   ② 与游戏内 HUD/面板同一套 dark-tech 令牌，逐像素可控；
--   ③ 只有调用方要求的文案，不夹带任何别的字。
--
-- 用法：
--   LoadingScreen.Start({ title = "...", lines = { "第一行", "第二行" } })
--   LoadingScreen.SetLine(2, "3 秒后…")
--   LoadingScreen.Stop()   -- 必须调用，否则它的 NanoVG 上下文会和新场景打架

local LoadingScreen = {}

-- 与 Scene3DBackend.C 同源的 dark-tech 令牌（改色两处一起改）
local C = {
    bg      = {7, 11, 20, 255},
    panel   = {10, 16, 28, 255},
    cyan    = {0, 229, 208, 255},
    cyanDim = {0, 150, 148, 220},
    text    = {240, 248, 252, 255},
    dim     = {120, 148, 162, 255},
}

local DESIGN_W, DESIGN_H = 540, 960

---@type any
local vg_ = nil
local active_ = false
---@type string|nil
local title_ = nil
---@type string[]
local lines_ = {}
local elapsed_ = 0
-- 自动关闭秒数（nil 表示一直显示，由调用方 Stop）
---@type number|nil
local autoStopAfter_ = nil

-- ============================================================================
-- 绘制原语（全部自绘，不依赖任何 UI 框架）
-- ============================================================================

---@param ctx any
---@param x number
---@param y number
---@param w number
---@param h number
---@param color table
---@param radius number
local function FillRect(ctx, x, y, w, h, color, radius)
    nvgBeginPath(ctx)
    if radius > 0 then
        nvgRoundedRect(ctx, x, y, w, h, radius)
    else
        nvgRect(ctx, x, y, w, h)
    end
    nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
    nvgFill(ctx)
end

---@param ctx any
---@param x number
---@param y number
---@param w number
---@param h number
---@param color table
---@param radius number
---@param width number
local function StrokeRect(ctx, x, y, w, h, color, radius, width)
    nvgBeginPath(ctx)
    if radius > 0 then
        nvgRoundedRect(ctx, x, y, w, h, radius)
    else
        nvgRect(ctx, x, y, w, h)
    end
    nvgStrokeColor(ctx, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
    nvgStrokeWidth(ctx, width)
    nvgStroke(ctx)
end

---@param ctx any
---@param x number
---@param y number
---@param text string
---@param size number
---@param color table
---@param align number|nil
local function Text(ctx, x, y, text, size, color, align)
    nvgFontFace(ctx, "zpix")
    nvgFontSize(ctx, size)
    nvgTextAlign(ctx, align or (NVG_ALIGN_LEFT + NVG_ALIGN_TOP))
    nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
    nvgText(ctx, x, y, text, nil)
end

-- 装饰：角标 + 断线边框，与游戏内窗口壳同款语言（贴边，不进正文）
---@param ctx any
---@param w number
---@param h number
local function DrawChrome(ctx, w, h)
    local bracket = 22
    local margin = 18
    local col = C.cyanDim
    for _, corner in ipairs({
        { margin, margin, 1, 1 },
        { w - margin, margin, -1, 1 },
        { margin, h - margin, 1, -1 },
        { w - margin, h - margin, -1, -1 },
    }) do
        local cx, cy, sx, sy = corner[1], corner[2], corner[3], corner[4]
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, cx + sx * bracket, cy)
        nvgLineTo(ctx, cx, cy)
        nvgLineTo(ctx, cx, cy + sy * bracket)
        nvgStrokeColor(ctx, nvgRGBA(col[1], col[2], col[3], 140))
        nvgStrokeWidth(ctx, 1.4)
        nvgStroke(ctx)
    end

    -- 断线边框：四边各留一个缺口，呼应游戏内窗口壳
    local gap = 96
    local half = w * 0.5
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, margin, margin)
    nvgLineTo(ctx, half - gap * 0.5, margin)
    nvgMoveTo(ctx, half + gap * 0.5, margin)
    nvgLineTo(ctx, w - margin, margin)
    nvgMoveTo(ctx, margin, h - margin)
    nvgLineTo(ctx, half - gap * 0.5, h - margin)
    nvgMoveTo(ctx, half + gap * 0.5, h - margin)
    nvgLineTo(ctx, w - margin, h - margin)
    nvgMoveTo(ctx, margin, margin)
    nvgLineTo(ctx, margin, h - margin)
    nvgMoveTo(ctx, w - margin, margin)
    nvgLineTo(ctx, w - margin, h - margin)
    nvgStrokeColor(ctx, nvgRGBA(col[1], col[2], col[3], 90))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
end

-- ============================================================================
-- 帧
-- ============================================================================

local function Render()
    if not vg_ or not active_ then return end

    local physW, physH = 1280, 720
    local dpr = 1.0
    pcall(function()
        physW, physH = graphics:GetWidth(), graphics:GetHeight()
        dpr = graphics:GetDPR()
    end)
    if dpr <= 0 then dpr = 1.0 end
    local logicalW, logicalH = physW / dpr, physH / dpr

    local scale = math.min(logicalW / DESIGN_W, logicalH / DESIGN_H)
    local offsetX = (logicalW - DESIGN_W * scale) * 0.5
    local offsetY = (logicalH - DESIGN_H * scale) * 0.5

    nvgBeginFrame(vg_, logicalW, logicalH, dpr)
    nvgResetTransform(vg_)
    nvgResetScissor(vg_)
    nvgGlobalAlpha(vg_, 1.0)
    nvgScale(vg_, scale, scale)
    nvgTranslate(vg_, offsetX, offsetY)

    -- ① 第一笔就是整屏不透明底：盖掉任何框架残留的默认背景（“变灰一下”的根因）。
    FillRect(vg_, 0, 0, DESIGN_W, DESIGN_H, C.bg, 0)
    DrawChrome(vg_, DESIGN_W, DESIGN_H)

    -- ② 标题
    if title_ and title_ ~= "" then
        Text(vg_, DESIGN_W * 0.5, 402, title_, 30, C.cyan,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        FillRect(vg_, DESIGN_W * 0.5 - 30, 444, 60, 2, C.cyanDim, 0)
    end

    -- ③ 调用方给的文案（只有这些，不夹带别的字）
    local y = 496
    for i = 1, #lines_ do
        local line = lines_[i]
        if line and line ~= "" then
            local color = (i == 1) and C.text or C.dim
            local size = (i == 1) and 20 or 16
            Text(vg_, DESIGN_W * 0.5, y, line, size, color,
                NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        end
        y = y + 36
    end

    -- ④ 底部一条缓慢扫过的细光带，表示「在动」而不是卡死
    local sweepW = 180
    local t = (elapsed_ * 0.55) % 1.0
    local sx = 120 + (DESIGN_W - 240 - sweepW) * t
    FillRect(vg_, sx, 624, sweepW, 2, { C.cyan[1], C.cyan[2], C.cyan[3], 120 }, 0)
    FillRect(vg_, 120, 624, DESIGN_W - 240, 1, { C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 60 }, 0)

    nvgEndFrame(vg_)
end

---@param eventType string
---@param eventData any
local function HandleLoadingNanoVGRender(eventType, eventData)
    local ok, err = pcall(Render)
    if not ok then
        print("[LoadingScreen] render error: " .. tostring(err))
    end
end

---@param eventType string
---@param eventData any
local function HandleLoadingUpdate(eventType, eventData)
    local dt = 0.016
    pcall(function() dt = eventData:GetFloat("TimeStep") end)
    elapsed_ = elapsed_ + (dt or 0.016)
    if autoStopAfter_ and elapsed_ >= autoStopAfter_ then
        autoStopAfter_ = nil
        LoadingScreen.Stop()
    end
end

-- ============================================================================
-- 生命周期
-- ============================================================================

---@class LoadingScreenOpts
---@field title string|nil
---@field lines string[]|nil
---@field autoStopAfter number|nil 秒；到点自动 Stop（用于跨交接的深色盖板）

---@param opts LoadingScreenOpts
function LoadingScreen.Start(opts)
    opts = opts or {}
    title_ = opts.title
    lines_ = opts.lines or {}
    autoStopAfter_ = opts.autoStopAfter
    elapsed_ = 0

    local ok = pcall(function()
        vg_ = nvgCreate(1)
        if vg_ then
            -- 中文字体；失败也不致命，退回默认字体。
            pcall(function() nvgCreateFont(vg_, "zpix", "Fonts/Zpix.ttf") end)
        end
    end)
    if not ok or not vg_ then
        print("[LoadingScreen] nvgCreate failed, loading screen disabled")
        vg_ = nil
        return false
    end

    active_ = true
    -- 传函数值订阅：字符串名按文件作用域解析，跨文件会静默失效。
    SubscribeToEvent(vg_, "NanoVGRender", HandleLoadingNanoVGRender)
    SubscribeToEvent("Update", HandleLoadingUpdate)
    print("[LoadingScreen] started")
    return true
end

---@param index integer
---@param text string
function LoadingScreen.SetLine(index, text)
    lines_[index] = text
end

function LoadingScreen.Stop()
    if not active_ and not vg_ then return end
    active_ = false
    pcall(function() UnsubscribeFromEvent("Update") end)
    pcall(function() UnsubscribeFromEvent("NanoVGRender") end)
    if vg_ then
        pcall(function() nvgDelete(vg_) end)
        vg_ = nil
    end
    title_, lines_ = nil, {}
    autoStopAfter_ = nil
    print("[LoadingScreen] stopped")
end

return LoadingScreen
