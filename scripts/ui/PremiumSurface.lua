-- PremiumSurface.lua
-- 深海军技术舱的共享表面：像素字体、断线框与局部刻度，复用宿主 NanoVG。
local Surface = {}
local state = { context = nil, C = {} }

local function Box(ctx, x, y, w, h, color, radius, alpha)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x, y, w, h, radius or 0)
    nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], alpha or color[4] or 255))
    nvgFill(ctx)
end

local function Line(ctx, x1, y1, x2, y2, color, alpha)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x1, y1)
    nvgLineTo(ctx, x2, y2)
    nvgStrokeColor(ctx, nvgRGBA(color[1], color[2], color[3], alpha or color[4] or 255))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
end

function Surface.Init(ctx, colors)
    state.context, state.C = ctx, colors
    -- zpix 已由宿主初始化；不再覆盖成通用正文，也不加载写实环境插画。
    print("[PremiumSurface] 深海军技术舱就绪：Zpix / 程序化展台 / 无环境图片")
end

function Surface.Shutdown()
    state.context, state.C = nil, {}
end

function Surface.UseFont(ctx, size)
    nvgFontFace(ctx, "zpix")
end

-- 相邻深蓝明度分层，不加投影或扩散光；语义边仅由调用方显式强调。
function Surface.Panel(ctx, x, y, w, h, fill, border, radius, emphasis)
    local r, a = radius or 6, fill[4] or 255
    local C = state.C
    nvgSave(ctx)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x, y, w, h, r)
    nvgFillPaint(ctx, nvgLinearGradient(ctx, x, y, x, y + h,
        nvgRGBA(math.min(255, fill[1] + 5), math.min(255, fill[2] + 6), math.min(255, fill[3] + 8), a),
        nvgRGBA(fill[1], fill[2], fill[3], a)))
    nvgFill(ctx)
    local edge = emphasis and border or C.cyanDim
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x + 0.5, y + 0.5, w - 1, h - 1, r)
    nvgStrokeColor(ctx, nvgRGBA(edge[1], edge[2], edge[3], emphasis and math.min(200, edge[4] or 200) or 78))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
    -- 两段短的顶部注册线，替代贯穿整面的玻璃高光。
    if w >= 80 and h >= 36 then
        Line(ctx, x + r + 3, y + 1.5, x + r + math.min(22, w * 0.18), y + 1.5, C.dim, 65)
        Line(ctx, x + w - r - math.min(22, w * 0.18), y + 1.5, x + w - r - 3, y + 1.5, C.dim, 65)
    end
    nvgRestore(ctx)
end

function Surface.Window(ctx, x, y, w, h, titleH)
    local C, th = state.C, titleH or 48
    Surface.Panel(ctx, x, y, w, h, C.panel, C.cyanDim, 6, false)
    Box(ctx, x + 2, y + 2, w - 4, th - 2, C.rail, 4)
    Box(ctx, x + 2, y + th - 4, w - 4, 4, C.rail)
    Box(ctx, x + 2, y + 14, 3, th - 28, C.cyan, 1)
    -- 标题断线与四角折角：窗口只有这两种母题，不在正文后铺花纹。
    Line(ctx, x + 14, y + th, x + w * 0.5 - 18, y + th, C.cyanDim, 130)
    Line(ctx, x + w * 0.5 + 18, y + th, x + w - 14, y + th, C.cyanDim, 130)
    for _, side in ipairs({-1, 1}) do
        local xx = side == -1 and x + 2 or x + w - 2
        local inward = -side * 10
        Line(ctx, xx, y + 10, xx, y + 2, C.dim, 115)
        Line(ctx, xx, y + 2, xx + inward, y + 2, C.dim, 115)
        Line(ctx, xx, y + h - 10, xx, y + h - 2, C.dim, 115)
        Line(ctx, xx, y + h - 2, xx + inward, y + h - 2, C.dim, 115)
    end
end

-- 主按钮是明确的语义色面；窄刻度与底边扫描表达状态，不用玻璃扫光/外发光。
function Surface.Button(ctx, r, color, glow, phase)
    local C = state.C
    nvgSave(ctx)
    Box(ctx, r.x, r.y, r.w, r.h, color, 4)
    if (glow or 0) > 0 then
        Box(ctx, r.x + 1, r.y + 1, r.w - 2, r.h - 2, C.ink, 3, math.floor(glow * 24))
    end
    Line(ctx, r.x + 8, r.y + 2, r.x + 30, r.y + 2, C.ink, 100)
    Line(ctx, r.x + r.w - 30, r.y + r.h - 3, r.x + r.w - 8, r.y + r.h - 3, C.ink, 100)
    for i = 0, 2 do
        Line(ctx, r.x + 5, r.y + r.h * 0.5 - 6 + i * 6,
            r.x + 8, r.y + r.h * 0.5 - 6 + i * 6, C.ink, 100)
        Line(ctx, r.x + r.w - 8, r.y + r.h * 0.5 - 6 + i * 6,
            r.x + r.w - 5, r.y + r.h * 0.5 - 6 + i * 6, C.ink, 100)
    end
    if phase then
        local length = math.min(28, r.w * 0.18)
        local x = r.x + 10 + (phase % 6) / 6 * (r.w - 20 - length)
        Line(ctx, x, r.y + r.h - 3, x + length, r.y + r.h - 3, C.ink, 130)
    end
    nvgRestore(ctx)
end

function Surface.FitText(ctx, text, size, width, minimum)
    nvgSave(ctx)
    nvgResetTransform(ctx)
    local fitted = size
    while true do
        Surface.UseFont(ctx, fitted)
        nvgFontSize(ctx, fitted)
        local advance = nvgTextBounds(ctx, 0, 0, text, nil)
        if advance <= width or fitted <= (minimum or 15) then
            nvgRestore(ctx)
            return fitted, advance <= width
        end
        fitted = fitted - 1
    end
end

-- 背景仅保留深蓝层级与屏边支架，中央文字和主视觉不铺网格。
function Surface.Background(ctx, x, y, w, h)
    local C = state.C
    nvgSave(ctx)
    nvgBeginPath(ctx)
    nvgRect(ctx, x, y, w, h)
    nvgFillPaint(ctx, nvgLinearGradient(ctx, x, y, x, y + h,
        nvgRGBA(C.panel[1], C.panel[2], C.panel[3], 255),
        nvgRGBA(C.bg[1], C.bg[2], C.bg[3], 255)))
    nvgFill(ctx)
    for _, xx in ipairs({x + 3, x + w - 9}) do
        Box(ctx, xx, y + 28, 6, h - 56, C.rail, 2)
        for yy = y + 42, y + h - 30, 46 do
            Line(ctx, xx + 1, yy, xx + 5, yy, C.cyanDim, 62)
        end
    end
    nvgRestore(ctx)
end

-- 展台的支架、断线轮廓与刻度落在车辆以外，扫描仅沿侧轨移动。
function Surface.Stage(ctx, r, phase)
    local C = state.C
    nvgSave(ctx)
    nvgIntersectScissor(ctx, r.x, r.y, r.w, r.h)
    Box(ctx, r.x + 1, r.y + 1, r.w - 2, r.h - 2, C.rail, 6)
    local top, bottom = r.y + 46, r.y + r.h - 29
    for _, side in ipairs({-1, 1}) do
        local xx = side == -1 and r.x + 8 or r.x + r.w - 8
        local inward = -side * 18
        Line(ctx, xx, top + 12, xx, bottom - 12, C.cyanDim, 115)
        Line(ctx, xx, top, xx + inward, top, C.dim, 115)
        Line(ctx, xx, top, xx, top + 12, C.dim, 115)
        Line(ctx, xx, bottom, xx + inward, bottom, C.dim, 115)
        Line(ctx, xx, bottom - 12, xx, bottom, C.dim, 115)
        for i = 0, 8 do
            local yy = top + 18 + (bottom - top - 36) * i / 8
            Line(ctx, xx, yy, xx - side * (i % 4 == 0 and 6 or 3), yy, C.dim, 75)
        end
        local scanY = top + 12 + ((phase or 0) % 8) / 8 * (bottom - top - 24)
        Box(ctx, xx - 1, scanY, 3, 7, C.cyanDim, 1, 160)
    end
    -- 底座是两条扁椭圆仪器刻线，而不是写实反光地坪。
    local cx, cy = r.x + r.w * 0.5, r.y + r.h * 0.73
    for i = 1, 2 do
        nvgBeginPath(ctx)
        nvgEllipse(ctx, cx, cy, r.w * (0.38 + (i - 1) * 0.04), r.h * (0.10 + (i - 1) * 0.025))
        nvgStrokeColor(ctx, nvgRGBA(C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], i == 1 and 105 or 45))
        nvgStrokeWidth(ctx, 1)
        nvgStroke(ctx)
    end
    for i = 0, 16 do
        local angle = math.pi * i / 16
        local xx, yy = cx + math.cos(angle) * r.w * 0.42, cy + math.sin(angle) * r.h * 0.125
        Line(ctx, xx, yy, xx, yy - (i % 4 == 0 and 5 or 2), C.dim, 85)
    end
    nvgRestore(ctx)
end

return Surface
