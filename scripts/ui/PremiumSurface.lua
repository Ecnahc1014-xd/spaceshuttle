-- PremiumSurface.lua
-- 深海军技术舱共享工艺：像素字体、金属受光、环境光场与动态扫描，复用宿主 NanoVG。
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
    -- 字体仍由宿主一次注册；表面与光场均程序化，不新增图片或上下文。
    print("[PremiumSurface] 技术舱工艺就绪：Zpix / 金属倒角 / 环境光场 / 扫光与交互受光")
end

function Surface.Shutdown()
    state.context, state.C = nil, {}
end

function Surface.UseFont(ctx, size)
    nvgFontFace(ctx, "zpix")
end

-- 恢复可辨明暗和落地厚度，普通面板不自动继承控件的悬停发光。
function Surface.Panel(ctx, x, y, w, h, fill, border, radius, emphasis)
    local r, a = radius or 6, fill[4] or 255
    local C = state.C
    nvgSave(ctx)
    if r > 0 and w >= 60 and h >= 36 then
        nvgBeginPath(ctx)
        nvgRect(ctx, x - 6, y - 3, w + 12, h + 12)
        nvgFillPaint(ctx, nvgBoxGradient(ctx, x, y + 3, w, h, r, 6,
            nvgRGBA(0, 0, 0, math.floor(a * 0.38)), nvgRGBA(0, 0, 0, 0)))
        nvgFill(ctx)
        Box(ctx, x + 1, y + 2, w - 2, h, C.ink, r, a)
    end
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x, y, w, h, r)
    nvgFillPaint(ctx, nvgLinearGradient(ctx, x, y, x + w * 0.15, y + h,
        nvgRGBA(math.min(255, fill[1] + 14), math.min(255, fill[2] + 16), math.min(255, fill[3] + 20), a),
        nvgRGBA(math.max(0, fill[1] - 3), math.max(0, fill[2] - 3), math.max(0, fill[3] - 4), a)))
    nvgFill(ctx)
    local edge = emphasis and border or C.dim
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x + 0.5, y + 0.5, w - 1, h - 1, r)
    nvgStrokeColor(ctx, nvgRGBA(edge[1], edge[2], edge[3],
        emphasis and math.min(220, edge[4] or 220) or 85))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
    if w >= 60 and h >= 28 then
        Line(ctx, x + r + 3, y + 1.5, x + w - r - 3, y + 1.5, C.text, emphasis and 90 or 56)
        Line(ctx, x + r + 3, y + h - 2, x + w - r - 3, y + h - 2, C.ink, 175)
        Line(ctx, x + r + 3, y + 2.5, x + r + math.min(22, w * 0.18), y + 2.5, C.dim, 85)
        Line(ctx, x + w - r - math.min(22, w * 0.18), y + 2.5,
            x + w - r - 3, y + 2.5, C.dim, 85)
    end
    nvgRestore(ctx)
end

function Surface.Window(ctx, x, y, w, h, titleH)
    local C, th = state.C, titleH or 48
    nvgSave(ctx)
    -- 光从标题舱和侧边泄出，而不是把正文区铺成发光壁纸。
    nvgBeginPath(ctx)
    nvgRect(ctx, x - 8, y - 8, w + 16, th + 22)
    nvgFillPaint(ctx, nvgBoxGradient(ctx, x + 4, y + 3, w - 8, th, 6, 8,
        nvgRGBA(C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 52),
        nvgRGBA(C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 0)))
    nvgFill(ctx)
    Surface.Panel(ctx, x, y, w, h, C.panel, C.cyanDim, 6, false)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x + 2, y + 2, w - 4, th - 2, 4)
    nvgFillPaint(ctx, nvgLinearGradient(ctx, x, y, x + w * 0.35, y + th,
        nvgRGBA(C.rail[1] + 19, C.rail[2] + 20, C.rail[3] + 22, 255),
        nvgRGBA(C.rail[1], C.rail[2], C.rail[3], 255)))
    nvgFill(ctx)
    Box(ctx, x + 2, y + th - 4, w - 4, 4, C.rail)
    Line(ctx, x + 12, y + 3, x + w - 12, y + 3, C.text, 66)
    Box(ctx, x + 2, y + 14, 3, th - 28, C.cyan, 1)
    Line(ctx, x + 14, y + th, x + w * 0.5 - 18, y + th, C.cyanDim, 180)
    Line(ctx, x + w * 0.5 + 18, y + th, x + w - 14, y + th, C.cyanDim, 180)
    for _, side in ipairs({-1, 1}) do
        local xx = side == -1 and x + 2 or x + w - 2
        local inward = -side * 10
        Line(ctx, xx, y + 10, xx, y + 2, C.dim, 150)
        Line(ctx, xx, y + 2, xx + inward, y + 2, C.dim, 150)
        Line(ctx, xx, y + h - 10, xx, y + h - 2, C.dim, 150)
        Line(ctx, xx, y + h - 2, xx + inward, y + h - 2, C.dim, 150)
    end
    nvgRestore(ctx)
end

-- 语义色不变；薄底座、金属色面、亮边和两种扫描都先于按钮文字绘制。
function Surface.Button(ctx, r, color, glow, phase)
    local C, g = state.C, math.max(0, math.min(1, glow or 0))
    nvgSave(ctx)
    if g > 0.01 then
        nvgBeginPath(ctx)
        nvgRect(ctx, r.x - 6, r.y - 6, r.w + 12, r.h + 12)
        nvgFillPaint(ctx, nvgBoxGradient(ctx, r.x, r.y, r.w, r.h, 4, 6,
            nvgRGBA(color[1], color[2], color[3], math.floor(g * 85)),
            nvgRGBA(color[1], color[2], color[3], 0)))
        nvgFill(ctx)
    end
    Box(ctx, r.x + 1, r.y + 3, r.w - 2, r.h, C.ink, 4, 220)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, r.x, r.y, r.w, r.h, 4)
    nvgFillPaint(ctx, nvgLinearGradient(ctx, r.x, r.y, r.x + r.w * 0.22, r.y + r.h,
        nvgRGBA(math.min(255, color[1] + 25), math.min(255, color[2] + 18), math.min(255, color[3] + 20), 255),
        nvgRGBA(math.floor(color[1] * 0.68), math.floor(color[2] * 0.78), math.floor(color[3] * 0.80), 255)))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, r.x + 0.5, r.y + 0.5, r.w - 1, r.h - 1, 4)
    nvgStrokeColor(ctx, nvgRGBA(C.text[1], C.text[2], C.text[3], math.floor(65 + g * 155)))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
    Line(ctx, r.x + 8, r.y + 2, r.x + r.w - 8, r.y + 2, C.text, math.floor(70 + g * 75))
    Line(ctx, r.x + 8, r.y + r.h - 2, r.x + r.w - 8, r.y + r.h - 2, C.ink, 155)
    if r.w >= 48 and r.h >= 30 then
        for i = 0, 2 do
            Line(ctx, r.x + 5, r.y + r.h * 0.5 - 6 + i * 6,
                r.x + 8, r.y + r.h * 0.5 - 6 + i * 6, C.ink, 100)
            Line(ctx, r.x + r.w - 8, r.y + r.h * 0.5 - 6 + i * 6,
                r.x + r.w - 5, r.y + r.h * 0.5 - 6 + i * 6, C.ink, 100)
        end
    end
    if phase and r.w >= 48 and r.h >= 28 then
        nvgSave(ctx)
        nvgIntersectScissor(ctx, r.x + 7, r.y + 4, r.w - 14, r.h - 8)
        local sweep = (phase % 3.2) / 3.2
        if sweep < 0.55 then
            local band = math.min(58, r.w * 0.18)
            local bandX = r.x - band * 2 + sweep / 0.55 * (r.w + band * 4)
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, bandX, r.y + 4)
            nvgLineTo(ctx, bandX + band, r.y + 4)
            nvgLineTo(ctx, bandX + band * 0.38, r.y + r.h - 4)
            nvgLineTo(ctx, bandX - band * 0.62, r.y + r.h - 4)
            nvgFillPaint(ctx, nvgLinearGradient(ctx, bandX - band * 0.62, r.y,
                bandX + band, r.y, nvgRGBA(255, 255, 255, 0), nvgRGBA(255, 255, 255, 105)))
            nvgFill(ctx)
        end
        nvgRestore(ctx)
        nvgSave(ctx)
        nvgIntersectScissor(ctx, r.x + 7, r.y + r.h - 4, r.w - 14, 2)
        local length = math.min(48, r.w * 0.32)
        local scanX = r.x - length + (phase % 6) / 6 * (r.w + length * 2)
        nvgBeginPath(ctx)
        nvgRect(ctx, scanX, r.y + r.h - 4, length, 2)
        nvgFillPaint(ctx, nvgLinearGradient(ctx, scanX, r.y, scanX + length, r.y,
            nvgRGBA(C.text[1], C.text[2], C.text[3], 0),
            nvgRGBA(C.text[1], C.text[2], C.text[3], 195)))
        nvgFill(ctx)
        nvgRestore(ctx)
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

-- 菜单/模态的同族径向光场和边缘暗角，不用于覆盖 playing 中央战场。
function Surface.Background(ctx, x, y, w, h)
    local C = state.C
    nvgSave(ctx)
    nvgBeginPath(ctx)
    nvgRect(ctx, x, y, w, h)
    nvgFillPaint(ctx, nvgRadialGradient(ctx, x + w * 0.5, y + h * 0.34, 30,
        math.max(w, h) * 0.78, nvgRGBA(17, 30, 51, 255),
        nvgRGBA(C.bg[1], C.bg[2], C.bg[3], 255)))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRect(ctx, x, y, w, h * 0.5)
    nvgFillPaint(ctx, nvgLinearGradient(ctx, x, y, x, y + h * 0.5,
        nvgRGBA(C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 38),
        nvgRGBA(C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 0)))
    nvgFill(ctx)
    local edgeH = math.min(130, h * 0.18)
    for _, bottom in ipairs({false, true}) do
        local yy = bottom and y + h - edgeH or y
        nvgBeginPath(ctx)
        nvgRect(ctx, x, yy, w, edgeH)
        nvgFillPaint(ctx, nvgLinearGradient(ctx, x, yy, x, yy + edgeH,
            nvgRGBA(0, 0, 0, bottom and 0 or 110),
            nvgRGBA(0, 0, 0, bottom and 140 or 0)))
        nvgFill(ctx)
    end
    for _, xx in ipairs({x + 3, x + w - 9}) do
        Box(ctx, xx, y + 28, 6, h - 56, C.rail, 2)
        for yy = y + 42, y + h - 30, 46 do
            Line(ctx, xx + 1, yy, xx + 5, yy, C.cyanDim, 100)
        end
    end
    nvgRestore(ctx)
end

-- 展台恢复光场、椭圆接触影和亮环，真实车辆仍由独立展台绘制在其上方。
function Surface.Stage(ctx, r, phase)
    local C = state.C
    nvgSave(ctx)
    nvgIntersectScissor(ctx, r.x, r.y, r.w, r.h)
    Box(ctx, r.x + 1, r.y + 1, r.w - 2, r.h - 2, C.rail, 6)
    local cx, cy = r.x + r.w * 0.5, r.y + r.h * 0.73
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, r.x + 1, r.y + 1, r.w - 2, r.h - 2, 6)
    nvgFillPaint(ctx, nvgRadialGradient(ctx, cx, cy - r.h * 0.25, 8, r.w * 0.52,
        nvgRGBA(26, 57, 74, 200), nvgRGBA(C.rail[1], C.rail[2], C.rail[3], 0)))
    nvgFill(ctx)
    nvgSave(ctx)
    nvgTranslate(ctx, cx, cy)
    nvgScale(ctx, r.w * 0.38, r.h * 0.12)
    nvgBeginPath(ctx)
    nvgEllipse(ctx, 0, 0, 1, 1)
    nvgFillPaint(ctx, nvgRadialGradient(ctx, 0, 0, 0.15, 1,
        nvgRGBA(0, 0, 0, 180), nvgRGBA(0, 0, 0, 0)))
    nvgFill(ctx)
    nvgRestore(ctx)
    local top, bottom = r.y + 46, r.y + r.h - 29
    for _, side in ipairs({-1, 1}) do
        local xx = side == -1 and r.x + 8 or r.x + r.w - 8
        local inward = -side * 18
        Line(ctx, xx, top + 12, xx, bottom - 12, C.cyanDim, 150)
        Line(ctx, xx, top, xx + inward, top, C.dim, 135)
        Line(ctx, xx, top, xx, top + 12, C.dim, 135)
        Line(ctx, xx, bottom, xx + inward, bottom, C.dim, 135)
        Line(ctx, xx, bottom - 12, xx, bottom, C.dim, 135)
        for i = 0, 8 do
            local yy = top + 18 + (bottom - top - 36) * i / 8
            Line(ctx, xx, yy, xx - side * (i % 4 == 0 and 6 or 3), yy, C.dim, 90)
        end
        local scanY = top + 12 + ((phase or 0) % 8) / 8 * (bottom - top - 24)
        nvgBeginPath(ctx)
        nvgRect(ctx, xx - 7, scanY - 8, 14, 23)
        nvgFillPaint(ctx, nvgRadialGradient(ctx, xx, scanY + 3, 1, 12,
            nvgRGBA(C.cyan[1], C.cyan[2], C.cyan[3], 95),
            nvgRGBA(C.cyan[1], C.cyan[2], C.cyan[3], 0)))
        nvgFill(ctx)
        Box(ctx, xx - 1, scanY, 3, 7, C.cyan, 1, 220)
    end
    for i = 1, 2 do
        nvgBeginPath(ctx)
        nvgEllipse(ctx, cx, cy, r.w * (0.38 + (i - 1) * 0.04), r.h * (0.10 + (i - 1) * 0.025))
        nvgStrokeColor(ctx, nvgRGBA(C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], i == 1 and 180 or 85))
        nvgStrokeWidth(ctx, 1)
        nvgStroke(ctx)
    end
    -- 共相位亮弧沿底座走一圈，文字仍绘制在展台效果之后。
    local arcStart = ((phase or 0) % 8) / 8 * math.pi * 2
    nvgBeginPath(ctx)
    for i = 0, 8 do
        local angle = arcStart + i / 8 * 0.45
        local xx, yy = cx + math.cos(angle) * r.w * 0.38, cy + math.sin(angle) * r.h * 0.10
        if i == 0 then nvgMoveTo(ctx, xx, yy) else nvgLineTo(ctx, xx, yy) end
    end
    nvgStrokeColor(ctx, nvgRGBA(C.cyan[1], C.cyan[2], C.cyan[3], 200))
    nvgStrokeWidth(ctx, 2)
    nvgStroke(ctx)
    for i = 0, 16 do
        local angle = math.pi * i / 16
        local xx, yy = cx + math.cos(angle) * r.w * 0.42, cy + math.sin(angle) * r.h * 0.125
        Line(ctx, xx, yy, xx, yy - (i % 4 == 0 and 5 or 2), C.dim, 110)
    end
    nvgRestore(ctx)
end

return Surface
