-- PremiumSurface.lua
-- 深海军技术舱共享工艺：像素字体、金属受光、环境光场与动态扫描，复用宿主 NanoVG。
-- 「贵」来自层次（受光 / 厚度 / 焦点 / 柔光），不是更多装饰线；全部程序化，不新增资源。
local Surface = {}
local state = { context = nil, C = {} }

local function clamp255(v)
    if v < 0 then return 0 elseif v > 255 then return 255 end
    return math.floor(v)
end

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

-- 窄条玻璃高光：只在竖直窄带上模拟反光，不铺满平面（tokens.md highlight 用法）。
local function GlassStrip(ctx, x, y, w, h, alpha)
    nvgBeginPath(ctx)
    nvgRect(ctx, x, y, w, h)
    nvgFillPaint(ctx, nvgLinearGradient(ctx, x, y, x + w, y,
        nvgRGBA(206, 255, 252, 0), nvgRGBA(206, 255, 252, alpha or 22)))
    nvgFill(ctx)
end

-- 四角螺钉：小圆 + 中心暗点，给大面板落地感（只在够大的面板上画，避免小控件糊成一团）。
local function Screws(ctx, x, y, w, h, inset)
    local C = state.C
    for _, sx in ipairs({ x + inset, x + w - inset }) do
        for _, sy in ipairs({ y + inset, y + h - inset }) do
            nvgBeginPath(ctx)
            nvgCircle(ctx, sx, sy, 2.3)
            nvgFillColor(ctx, nvgRGBA(C.dim[1], C.dim[2], C.dim[3], 130))
            nvgFill(ctx)
            nvgBeginPath(ctx)
            nvgCircle(ctx, sx, sy, 1.0)
            nvgFillColor(ctx, nvgRGBA(C.ink[1], C.ink[2], C.ink[3], 225))
            nvgFill(ctx)
        end
    end
end

-- 顶边长短刻度：给宽面板一条可读的「仪器」顶沿。
local function TopTicks(ctx, x, y, w, color, alpha)
    local seg = 16
    local step = w / seg
    if step < 5 then return end
    for i = 0, seg do
        local long = (i % 4 == 0)
        Line(ctx, x + i * step, y, x + i * step, y + (long and 5 or 2.5), color, alpha)
    end
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

-- 面板：双层扩散投影 + 金属色面 + 内顶受光 / 内底沉影 + 顶边刻度 + 折角 + 螺钉。
-- 普通面板不自动继承控件的悬停发光；签名与命中几何保持不变。
function Surface.Panel(ctx, x, y, w, h, fill, border, radius, emphasis)
    local r, a = radius or 6, fill[4] or 255
    local C = state.C
    local big = (w >= 130 and h >= 66)
    nvgSave(ctx)
    -- ① 双层投影：宽柔扩散 + 紧实暗底，制造离地厚度。
    if r > 0 and w >= 56 and h >= 32 then
        nvgBeginPath(ctx)
        nvgRect(ctx, x - 9, y - 4, w + 18, h + 16)
        nvgFillPaint(ctx, nvgBoxGradient(ctx, x, y + 5, w, h, r, 10,
            nvgRGBA(0, 0, 0, math.floor(a * 0.42)), nvgRGBA(0, 0, 0, 0)))
        nvgFill(ctx)
        nvgBeginPath(ctx)
        nvgRect(ctx, x - 3, y - 1, w + 6, h + 8)
        nvgFillPaint(ctx, nvgBoxGradient(ctx, x, y + 3, w, h, r, 3,
            nvgRGBA(0, 0, 0, math.floor(a * 0.52)), nvgRGBA(0, 0, 0, 0)))
        nvgFill(ctx)
        Box(ctx, x + 1, y + 3, w - 2, h, C.ink, r, a)
    end
    -- ② 金属色面：对角渐变，左上受光、右下沉底（同色族走明度）。
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x, y, w, h, r)
    nvgFillPaint(ctx, nvgLinearGradient(ctx, x, y, x + w * 0.26, y + h,
        nvgRGBA(clamp255(fill[1] + 30), clamp255(fill[2] + 32), clamp255(fill[3] + 38), a),
        nvgRGBA(clamp255(fill[1] - 9), clamp255(fill[2] - 9), clamp255(fill[3] - 11), a)))
    nvgFill(ctx)
    -- ③ 内顶受光带 + 内底沉影：把平面变成有厚度的舱板。
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x + 1, y + 1, w - 2, h * 0.42, math.max(0, r - 1))
    nvgFillPaint(ctx, nvgLinearGradient(ctx, x, y, x, y + h * 0.42,
        nvgRGBA(255, 255, 255, emphasis and 34 or 22), nvgRGBA(255, 255, 255, 0)))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x + 1, y + h * 0.55, w - 2, h * 0.45, math.max(0, r - 1))
    nvgFillPaint(ctx, nvgLinearGradient(ctx, x, y + h * 0.55, x, y + h,
        nvgRGBA(0, 0, 0, 0), nvgRGBA(0, 0, 0, emphasis and 54 or 40)))
    nvgFill(ctx)
    -- ④ 左缘玻璃高光窄条（只在够宽的面板上）。
    if w >= 90 then
        GlassStrip(ctx, x + 1, y + 2, 3, h - 4, emphasis and 30 or 20)
    end
    -- ⑤ 描边：强调面板用语义色，普通面板压暗，不抢焦点。
    local edge = emphasis and border or C.dim
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x + 0.5, y + 0.5, w - 1, h - 1, r)
    nvgStrokeColor(ctx, nvgRGBA(edge[1], edge[2], edge[3],
        emphasis and math.min(235, edge[4] or 235) or 92))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
    -- ⑥ 顶亮边 / 底暗边 / 顶边刻度 / 折角。
    if w >= 60 and h >= 28 then
        Line(ctx, x + r + 3, y + 1.5, x + w - r - 3, y + 1.5, C.text, emphasis and 108 or 70)
        Line(ctx, x + r + 3, y + h - 2, x + w - r - 3, y + h - 2, C.ink, 190)
        if w >= 150 then
            TopTicks(ctx, x + r + 4, y + 3, w - 2 * r - 8, C.cyanDim, 78)
        end
        Line(ctx, x + r + 3, y + 2.5, x + r + math.min(24, w * 0.16), y + 2.5, C.dim, 95)
        Line(ctx, x + w - r - math.min(24, w * 0.16), y + 2.5,
            x + w - r - 3, y + 2.5, C.dim, 95)
    end
    if big then
        Screws(ctx, x, y, w, h, 9)
    end
    nvgRestore(ctx)
end

-- 窗口壳：外辉光 + 标题舱受光横带 + 标题竖标发光 + 断线 + 四角折线 + 内容内顶暗。
function Surface.Window(ctx, x, y, w, h, titleH)
    local C, th = state.C, titleH or 48
    nvgSave(ctx)
    -- 外辉光：光从窗口边缘泄出，是「浮起」的关键。
    nvgBeginPath(ctx)
    nvgRect(ctx, x - 12, y - 12, w + 24, h + 24)
    nvgFillPaint(ctx, nvgBoxGradient(ctx, x, y, w, h, 8, 12,
        nvgRGBA(C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 44),
        nvgRGBA(C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 0)))
    nvgFill(ctx)
    Surface.Panel(ctx, x, y, w, h, C.panel, C.cyanDim, 6, false)
    -- 标题舱：受光横带（左亮右暗）。
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x + 2, y + 2, w - 4, th - 2, 4)
    nvgFillPaint(ctx, nvgLinearGradient(ctx, x, y, x + w * 0.4, y + th,
        nvgRGBA(clamp255(C.rail[1] + 26), clamp255(C.rail[2] + 27), clamp255(C.rail[3] + 30), 255),
        nvgRGBA(C.rail[1], C.rail[2], C.rail[3], 255)))
    nvgFill(ctx)
    Box(ctx, x + 2, y + th - 4, w - 4, 4, C.rail)
    Line(ctx, x + 12, y + 3, x + w - 12, y + 3, C.text, 78)
    -- 标题竖标 + 局部辉光。
    nvgBeginPath(ctx)
    nvgRect(ctx, x - 2, y + 12, 10, th - 24)
    nvgFillPaint(ctx, nvgRadialGradient(ctx, x + 3, y + th * 0.5, 1, 16,
        nvgRGBA(C.cyan[1], C.cyan[2], C.cyan[3], 90),
        nvgRGBA(C.cyan[1], C.cyan[2], C.cyan[3], 0)))
    nvgFill(ctx)
    Box(ctx, x + 2, y + 14, 3, th - 28, C.cyan, 1)
    Line(ctx, x + 14, y + th, x + w * 0.5 - 18, y + th, C.cyanDim, 190)
    Line(ctx, x + w * 0.5 + 18, y + th, x + w - 14, y + th, C.cyanDim, 190)
    -- 内容区内顶暗，避免正文贴在亮带上。
    nvgBeginPath(ctx)
    nvgRect(ctx, x + 2, y + th + 1, w - 4, 14)
    nvgFillPaint(ctx, nvgLinearGradient(ctx, x, y + th + 1, x, y + th + 15,
        nvgRGBA(0, 0, 0, 96), nvgRGBA(0, 0, 0, 0)))
    nvgFill(ctx)
    for _, side in ipairs({ -1, 1 }) do
        local xx = side == -1 and x + 2 or x + w - 2
        local inward = -side * 10
        Line(ctx, xx, y + 10, xx, y + 2, C.dim, 160)
        Line(ctx, xx, y + 2, xx + inward, y + 2, C.dim, 160)
        Line(ctx, xx, y + h - 10, xx, y + h - 2, C.dim, 160)
        Line(ctx, xx, y + h - 2, xx + inward, y + h - 2, C.dim, 160)
    end
    nvgRestore(ctx)
end

-- 按钮：双层投影 + 语义色金属渐变 + 上亮下暗倒角 + 玻璃窄条 + 两侧刻度 + 斜扫光 + 底边流光。
-- 语义色不变；材质与光效先于按钮文字绘制；命中几何不变。
function Surface.Button(ctx, r, color, glow, phase)
    local C, g = state.C, math.max(0, math.min(1, glow or 0))
    nvgSave(ctx)
    -- 悬停：加色外辉光。
    if g > 0.01 then
        nvgBeginPath(ctx)
        nvgRect(ctx, r.x - 8, r.y - 8, r.w + 16, r.h + 16)
        nvgFillPaint(ctx, nvgBoxGradient(ctx, r.x, r.y, r.w, r.h, 4, 9,
            nvgRGBA(color[1], color[2], color[3], math.floor(g * 105)),
            nvgRGBA(color[1], color[2], color[3], 0)))
        nvgFill(ctx)
    end
    -- 双层落地投影。
    Box(ctx, r.x + 1, r.y + 4, r.w - 2, r.h, C.ink, 4, 210)
    nvgBeginPath(ctx)
    nvgRect(ctx, r.x - 5, r.y + 2, r.w + 10, r.h + 8)
    nvgFillPaint(ctx, nvgBoxGradient(ctx, r.x, r.y + 3, r.w, r.h, 4, 4,
        nvgRGBA(0, 0, 0, 130), nvgRGBA(0, 0, 0, 0)))
    nvgFill(ctx)
    -- 金属色面。
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, r.x, r.y, r.w, r.h, 4)
    nvgFillPaint(ctx, nvgLinearGradient(ctx, r.x, r.y, r.x + r.w * 0.24, r.y + r.h,
        nvgRGBA(clamp255(color[1] + 34), clamp255(color[2] + 26), clamp255(color[3] + 28), 255),
        nvgRGBA(clamp255(color[1] * 0.60), clamp255(color[2] * 0.72), clamp255(color[3] * 0.76), 255)))
    nvgFill(ctx)
    -- 顶部内受光 + 底部内沉影（倒角）。
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, r.x + 1, r.y + 1, r.w - 2, r.h * 0.46, 3)
    nvgFillPaint(ctx, nvgLinearGradient(ctx, r.x, r.y, r.x, r.y + r.h * 0.46,
        nvgRGBA(255, 255, 255, math.floor(48 + g * 40)), nvgRGBA(255, 255, 255, 0)))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, r.x + 1, r.y + r.h * 0.58, r.w - 2, r.h * 0.42, 3)
    nvgFillPaint(ctx, nvgLinearGradient(ctx, r.x, r.y + r.h * 0.58, r.x, r.y + r.h,
        nvgRGBA(0, 0, 0, 0), nvgRGBA(0, 0, 0, 78)))
    nvgFill(ctx)
    GlassStrip(ctx, r.x + 2, r.y + 2, 3, r.h - 4, math.floor(30 + g * 30))
    -- 亮边。
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, r.x + 0.5, r.y + 0.5, r.w - 1, r.h - 1, 4)
    nvgStrokeColor(ctx, nvgRGBA(C.text[1], C.text[2], C.text[3], math.floor(80 + g * 150)))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
    Line(ctx, r.x + 8, r.y + 2, r.x + r.w - 8, r.y + 2, C.text, math.floor(90 + g * 70))
    Line(ctx, r.x + 8, r.y + r.h - 2, r.x + r.w - 8, r.y + r.h - 2, C.ink, 170)
    if r.w >= 48 and r.h >= 30 then
        for i = 0, 2 do
            Line(ctx, r.x + 5, r.y + r.h * 0.5 - 6 + i * 6,
                r.x + 8, r.y + r.h * 0.5 - 6 + i * 6, C.ink, 110)
            Line(ctx, r.x + r.w - 8, r.y + r.h * 0.5 - 6 + i * 6,
                r.x + r.w - 5, r.y + r.h * 0.5 - 6 + i * 6, C.ink, 110)
        end
    end
    -- 斜扫光（3.2s 周期，前 55% 扫过）+ 底边亮流光（6s 周期）。
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
                bandX + band, r.y, nvgRGBA(255, 255, 255, 0), nvgRGBA(255, 255, 255, 118)))
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
            nvgRGBA(C.text[1], C.text[2], C.text[3], 210)))
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

-- 菜单/模态背景：径向照明 + 顶青环境光 + 上下暗角 + 侧轨刻度 + 慢速斜向高光扫过。
-- 不用于覆盖 playing 中央战场。
function Surface.Background(ctx, x, y, w, h, phase)
    local C = state.C
    nvgSave(ctx)
    nvgBeginPath(ctx)
    nvgRect(ctx, x, y, w, h)
    nvgFillPaint(ctx, nvgRadialGradient(ctx, x + w * 0.5, y + h * 0.34, 30,
        math.max(w, h) * 0.78, nvgRGBA(17, 30, 51, 255),
        nvgRGBA(C.bg[1], C.bg[2], C.bg[3], 255)))
    nvgFill(ctx)
    -- 顶部青环境光。
    nvgBeginPath(ctx)
    nvgRect(ctx, x, y, w, h * 0.5)
    nvgFillPaint(ctx, nvgLinearGradient(ctx, x, y, x, y + h * 0.5,
        nvgRGBA(C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 44),
        nvgRGBA(C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 0)))
    nvgFill(ctx)
    -- 慢速斜向高光扫过（7s 一轮，确定性），给静态底一点「在运行」的感觉。
    if phase then
        local sweep = (phase % 7) / 7
        local bandW = w * 0.5
        local bandX = x - bandW + sweep * (w + bandW * 2)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, bandX, y)
        nvgLineTo(ctx, bandX + bandW, y)
        nvgLineTo(ctx, bandX + bandW - h * 0.35, y + h)
        nvgLineTo(ctx, bandX - h * 0.35, y + h)
        nvgFillPaint(ctx, nvgLinearGradient(ctx, bandX, y, bandX + bandW, y,
            nvgRGBA(C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 0),
            nvgRGBA(C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 20)))
        nvgFill(ctx)
    end
    -- 上下暗角。
    local edgeH = math.min(130, h * 0.18)
    for _, bottom in ipairs({ false, true }) do
        local yy = bottom and y + h - edgeH or y
        nvgBeginPath(ctx)
        nvgRect(ctx, x, yy, w, edgeH)
        nvgFillPaint(ctx, nvgLinearGradient(ctx, x, yy, x, yy + edgeH,
            nvgRGBA(0, 0, 0, bottom and 0 or 118),
            nvgRGBA(0, 0, 0, bottom and 150 or 0)))
        nvgFill(ctx)
    end
    -- 侧轨 + 刻度。
    for _, xx in ipairs({ x + 3, x + w - 9 }) do
        Box(ctx, xx, y + 28, 6, h - 56, C.rail, 2)
        Line(ctx, xx, y + 28, xx + 6, y + 28, C.dim, 120)
        Line(ctx, xx, y + h - 28, xx + 6, y + h - 28, C.dim, 120)
        for yy = y + 42, y + h - 30, 46 do
            Line(ctx, xx + 1, yy, xx + 5, yy, C.cyanDim, 110)
        end
    end
    nvgRestore(ctx)
end

-- 展台：顶光锥 + 径向受光 + 椭圆接触影 + 地面倒影 + 侧轨亮标 + 底座亮弧。
-- 真实车辆仍由独立展台绘制在其上方。
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
    -- 顶部光锥：从展台顶部射向车位的柔和梯形。
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, cx - r.w * 0.16, r.y + 1)
    nvgLineTo(ctx, cx + r.w * 0.16, r.y + 1)
    nvgLineTo(ctx, cx + r.w * 0.40, cy)
    nvgLineTo(ctx, cx - r.w * 0.40, cy)
    nvgFillPaint(ctx, nvgLinearGradient(ctx, cx, r.y, cx, cy,
        nvgRGBA(C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 34),
        nvgRGBA(C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 0)))
    nvgFill(ctx)
    -- 接触影（椭圆径向渐变，几何与 paint 同变换）。
    nvgSave(ctx)
    nvgTranslate(ctx, cx, cy)
    nvgScale(ctx, r.w * 0.38, r.h * 0.12)
    nvgBeginPath(ctx)
    nvgEllipse(ctx, 0, 0, 1, 1)
    nvgFillPaint(ctx, nvgRadialGradient(ctx, 0, 0, 0.15, 1,
        nvgRGBA(0, 0, 0, 190), nvgRGBA(0, 0, 0, 0)))
    nvgFill(ctx)
    nvgRestore(ctx)
    -- 地面倒影：接触影下方一道更淡的同族反光。
    nvgBeginPath(ctx)
    nvgEllipse(ctx, cx, cy + r.h * 0.10, r.w * 0.30, r.h * 0.05)
    nvgFillPaint(ctx, nvgRadialGradient(ctx, cx, cy + r.h * 0.10, 1, r.w * 0.30,
        nvgRGBA(C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 26),
        nvgRGBA(C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 0)))
    nvgFill(ctx)
    local top, bottom = r.y + 46, r.y + r.h - 29
    for _, side in ipairs({ -1, 1 }) do
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
            nvgRGBA(C.cyan[1], C.cyan[2], C.cyan[3], 100),
            nvgRGBA(C.cyan[1], C.cyan[2], C.cyan[3], 0)))
        nvgFill(ctx)
        Box(ctx, xx - 1, scanY, 3, 7, C.cyan, 1, 225)
    end
    for i = 1, 2 do
        nvgBeginPath(ctx)
        nvgEllipse(ctx, cx, cy, r.w * (0.38 + (i - 1) * 0.04), r.h * (0.10 + (i - 1) * 0.025))
        nvgStrokeColor(ctx, nvgRGBA(C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], i == 1 and 185 or 90))
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
    nvgStrokeColor(ctx, nvgRGBA(C.cyan[1], C.cyan[2], C.cyan[3], 205))
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
