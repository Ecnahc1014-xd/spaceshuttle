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

-- ===== v0.13.54 装饰纹路组：无关紧要、只做密度与「工程感」，一律低 alpha 且不穿正文 =====

-- 微网格底纹：极淡方格，只用于够大的面板/区域。
local function MicroGrid(ctx, x, y, w, h, step, color, alpha)
    if step < 6 or w < step * 2 or h < step * 2 then return end
    nvgSave(ctx)
    nvgIntersectScissor(ctx, x, y, w, h)
    nvgBeginPath(ctx)
    for gx = x + step, x + w - 1, step do
        nvgMoveTo(ctx, gx, y)
        nvgLineTo(ctx, gx, y + h)
    end
    for gy = y + step, y + h - 1, step do
        nvgMoveTo(ctx, x, gy)
        nvgLineTo(ctx, x + w, gy)
    end
    nvgStrokeColor(ctx, nvgRGBA(color[1], color[2], color[3], alpha or 14))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
    nvgRestore(ctx)
end

-- 稀疏电路刻纹：三条 L 形走线 + 端点焊盘，贴面板边缘，不穿正文。
local function CircuitTrace(ctx, x, y, w, h, color, alpha)
    local a = alpha or 28
    nvgSave(ctx)
    nvgIntersectScissor(ctx, x, y, w, h)
    nvgStrokeWidth(ctx, 1)
    local runs = {
        { x + w * 0.05, y + h * 0.13, w * 0.15, h * 0.15 },
        { x + w * 0.74, y + h * 0.09, w * 0.16, h * 0.20 },
        { x + w * 0.06, y + h * 0.84, w * 0.19, -h * 0.13 },
    }
    for i = 1, #runs do
        local rx, ry, dx, dy = runs[i][1], runs[i][2], runs[i][3], runs[i][4]
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, rx, ry)
        nvgLineTo(ctx, rx + dx, ry)
        nvgLineTo(ctx, rx + dx, ry + dy)
        nvgStrokeColor(ctx, nvgRGBA(color[1], color[2], color[3], a))
        nvgStroke(ctx)
        nvgBeginPath(ctx)
        nvgCircle(ctx, rx, ry, 1.5)
        nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], a + 34))
        nvgFill(ctx)
    end
    nvgRestore(ctx)
end

-- 四角折线括号：给面板一圈「取景框」，比描边更有工艺味。
local function CornerBrackets(ctx, x, y, w, h, len, color, alpha)
    if w < 48 or h < 32 then return end
    local a = alpha or 120
    nvgStrokeColor(ctx, nvgRGBA(color[1], color[2], color[3], a))
    nvgStrokeWidth(ctx, 1)
    for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
        local cx = c[1] < 0 and x + 2.5 or x + w - 2.5
        local cy = c[2] < 0 and y + 2.5 or y + h - 2.5
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, cx + c[1] * len, cy)
        nvgLineTo(ctx, cx, cy)
        nvgLineTo(ctx, cx, cy + c[2] * len)
        nvgStroke(ctx)
    end
end

-- 断线：沿 x 排一段虚线，用于分区/标题下沿的「仪表」节奏。
local function DashRule(ctx, x, y, w, color, alpha, dash, gap)
    dash, gap = dash or 6, gap or 5
    local a = alpha or 60
    nvgBeginPath(ctx)
    local xx = x
    while xx < x + w - 1 do
        local seg = math.min(dash, x + w - xx)
        nvgMoveTo(ctx, xx, y)
        nvgLineTo(ctx, xx + seg, y)
        xx = xx + dash + gap
    end
    nvgStrokeColor(ctx, nvgRGBA(color[1], color[2], color[3], a))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
end

-- 斜向细纹：整块区域的「机加工拉丝」，裁剪在区域内。
local function DiagonalHatch(ctx, x, y, w, h, gap, color, alpha)
    gap = gap or 11
    if w < gap * 2 or h < gap * 2 then return end
    nvgSave(ctx)
    nvgIntersectScissor(ctx, x, y, w, h)
    nvgBeginPath(ctx)
    for d = -h, w, gap do
        nvgMoveTo(ctx, x + d, y + h)
        nvgLineTo(ctx, x + d + h, y)
    end
    nvgStrokeColor(ctx, nvgRGBA(color[1], color[2], color[3], alpha or 9))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
    nvgRestore(ctx)
end

-- 点阵：小圆网格，只用于窄条/角落。同样合并单一路径（见 Halftone 的坑）。
local function DotMatrix(ctx, x, y, w, h, step, color, alpha)
    step = step or 14
    if w < step or h < step then return end
    nvgSave(ctx)
    nvgIntersectScissor(ctx, x, y, w, h)
    nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], alpha or 30))
    nvgBeginPath(ctx)
    for gx = x + step * 0.5, x + w - 1, step do
        for gy = y + step * 0.5, y + h - 1, step do
            nvgCircle(ctx, gx, gy, 0.9)
        end
    end
    nvgFill(ctx)
    nvgRestore(ctx)
end

-- 半调网点（规范 §3 Halftone）：隔行错位的圆点底纹。
-- ⚠️ 两个约束：①逐点绘制成本随面积增长 → 按面积**自适应放大步长**并钳总点数；
-- ②**必须合并成单一路径**（一次 beginPath + 多个 circle + 一次 fill）——每点各起
-- 一条路径会撑爆 NanoVG 单帧命令缓冲，导致**本帧后续绘制被静默丢弃**（表现为
-- 「只画出背景、卡片与文字全没了」），这是本项目实测踩到的真坑。
local function Halftone(ctx, x, y, w, h, step, color, alpha)
    step = step or 8
    if w < 8 or h < 8 then return end
    local budget = 600
    local cells = (w / step) * (h / step)
    if cells > budget then
        step = math.max(step, math.sqrt(w * h / budget))
    end
    if step < 7 then step = 7 end
    if w < step or h < step then return end
    nvgSave(ctx)
    nvgIntersectScissor(ctx, x, y, w, h)
    nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], alpha or 18))
    nvgBeginPath(ctx)
    local s = step * 2
    local row = 0
    for gy = y + step * 0.5, y + h - 1, step do
        local off = (row % 2 == 0) and 0 or step
        for gx = x + step * 0.5 + off, x + w - 1, s do
            nvgCircle(ctx, gx, gy, 0.9)
        end
        row = row + 1
    end
    nvgFill(ctx)
    nvgRestore(ctx)
end

-- 扫描带 + 拖尾（规范 §3 ScanBand）：容器内部一条缓慢下移的亮线。
local function ScanBand(ctx, x, y, w, h, phase, color)
    if h < 24 or w < 24 or not phase then return end
    local bandY = y + (phase * 18) % h
    Line(ctx, x + 2, bandY, x + w - 2, bandY, color, 44)
    Line(ctx, x + 2, bandY - 4, x + w - 2, bandY - 4, color, 20)
    Line(ctx, x + 6, bandY + 6, x + w - 6, bandY + 6, color, 14)
end

-- 十字取样点（规范 §3 Cross）：4 个角落的定位标记。
local function Cross(ctx, cx, cy, size, color, alpha)
    local a = alpha or 90
    Line(ctx, cx - size, cy, cx + size, cy, color, a)
    Line(ctx, cx, cy - size, cx, cy + size, color, a)
end

-- 环形刻度（规范 §3 TickRing）：每 3 段加长，给圆形主体一圈仪表。
local function TickRing(ctx, cx, cy, r, startDeg, endDeg, stepDeg, color, alpha)
    local steps = math.floor((endDeg - startDeg) / stepDeg)
    if steps < 4 then return end
    local a = alpha or 120
    for i = 0, steps do
        local rad = math.rad(startDeg + i * stepDeg)
        local long = (i % 3 == 0)
        local inner = r - (long and 7 or 3)
        local ox, oy = math.cos(rad), math.sin(rad)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, cx + ox * inner, cy + oy * inner)
        nvgLineTo(ctx, cx + ox * r, cy + oy * r)
        nvgStrokeColor(ctx, nvgRGBA(color[1], color[2], color[3], a))
        nvgStrokeWidth(ctx, long and 1.3 or 0.7)
        nvgStroke(ctx)
    end
end

-- 长短交替刻度带（规范 §3 Ticks）：给条带一条「仪器」读数沿。
local function Ticks(ctx, x, y, w, count, longH, shortH, color, alpha)
    count = count or 16
    local step = w / count
    if step < 4 then return end
    local a = alpha or 110
    for i = 0, count do
        local long = (i % 4 == 0)
        Line(ctx, x + i * step, y, x + i * step, y + (long and (longH or 6) or (shortH or 3)),
            color, a)
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
function Surface.Panel(ctx, x, y, w, h, fill, border, radius, emphasis, phase)
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
    -- ③b 装饰纹路（v0.13.54）：微网格 + 斜向拉丝 + 半调网点，给大面板「舱板」密度。
    if big then
        MicroGrid(ctx, x + 2, y + 2, w - 4, h - 4, 18, C.cyanDim, emphasis and 16 or 11)
        Halftone(ctx, x + 3, y + 3, w - 6, h - 6, 8, C.cyanDim, emphasis and 20 or 14)
        if w >= 190 and h >= 96 then
            DiagonalHatch(ctx, x + 2, y + 2, w - 4, h - 4, 13, C.text, 7)
        end
        if w >= 160 and h >= 70 then
            MicroGrid(ctx, x + 2, y + 2, w - 4, h - 4, 46, C.text, 9)
        end
    end
    -- ④ 左缘玻璃高光窄条（只在够宽的面板上）。
    if w >= 90 then
        GlassStrip(ctx, x + 1, y + 2, 3, h - 4, emphasis and 30 or 20)
    end
    -- ④b 玻璃漆面：上半区一道极淡的斜向高光，让色面从「平涂」变成「有漆面反射」。
    if w >= 70 and h >= 34 then
        nvgSave(ctx)
        nvgIntersectScissor(ctx, x + 1, y + 1, w - 2, h - 2)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, x, y + 1)
        nvgLineTo(ctx, x + w * 0.62, y + 1)
        nvgLineTo(ctx, x + w * 0.34, y + h * 0.52)
        nvgLineTo(ctx, x, y + h * 0.52)
        nvgFillPaint(ctx, nvgLinearGradient(ctx, x, y, x + w * 0.4, y + h * 0.5,
            nvgRGBA(255, 255, 255, emphasis and 20 or 12),
            nvgRGBA(255, 255, 255, 0)))
        nvgFill(ctx)
        nvgRestore(ctx)
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
        -- ⑦ 装饰纹路（v0.13.54）：四角取景折线 + 顶部/底部断线 + 角落点阵 + 边缘电路刻纹。
        CornerBrackets(ctx, x, y, w, h, 12, C.dim, emphasis and 130 or 95)
        CornerBrackets(ctx, x + 5, y + 5, w - 10, h - 10, 7, C.cyanDim, emphasis and 92 or 62)
        if w >= 150 then
            DashRule(ctx, x + r + 6, y + h - 6, w - 2 * r - 12, C.cyanDim, 46, 7, 6)
        end
        if w >= 190 then
            Ticks(ctx, x + r + 8, y + h - 13, w - 2 * r - 16, 24, 5, 2, C.cyanDim, 74)
        end
        if w >= 110 and h >= 70 then
            DotMatrix(ctx, x + 5, y + h - 26, 34, 20, 9, C.cyanDim, 46)
        end
        if w >= 170 and h >= 80 then
            CircuitTrace(ctx, x, y, w, h, C.cyanDim, emphasis and 34 or 24)
            Cross(ctx, x + 13, y + 13, 4, C.ghost, 80)
            Cross(ctx, x + w - 13, y + h - 13, 4, C.ghost, 80)
        end
        if w >= 200 and h >= 90 then
            ScanBand(ctx, x + 6, y + 8, w - 12, h - 16, phase, C.cyanDim)
        end
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
    -- 装饰纹路（v0.13.54）：标题舱底断线 + 右上点阵 + 内容区极淡斜纹/半调 + 刻度 + 四角取景线。
    DashRule(ctx, x + 16, y + th + 4, w - 32, C.cyanDim, 40, 5, 6)
    if w >= 150 then
        DotMatrix(ctx, x + w - 40, y + 10, 30, th - 16, 9, C.cyanDim, 44)
        DashRule(ctx, x + 16, y + 10, math.max(20, w * 0.28), C.cyanDim, 34, 4, 5)
    end
    if w >= 180 and h >= 160 then
        DiagonalHatch(ctx, x + 4, y + th + 4, w - 8, h - th - 8, 15, C.text, 6)
        Halftone(ctx, x + 4, y + th + 4, w - 8, h - th - 8, 10, C.cyanDim, 10)
        Ticks(ctx, x + 12, y + h - 12, w - 24, 28, 5, 2, C.cyanDim, 70)
    end
    CornerBrackets(ctx, x + 2, y + 2, w - 4, h - 4, 13, C.cyanDim, 105)
    CornerBrackets(ctx, x + 6, y + 6, w - 12, h - 12, 8, C.dim, 78)
    Cross(ctx, x + 16, y + th + 16, 4, C.ghost, 74)
    Cross(ctx, x + w - 16, y + h - 16, 4, C.ghost, 74)
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
    -- v0.13.53：金色系（付费/稀有）走「贵金属」配方——更亮的受光、更暖的高光、
    -- 更强的常驻辉光。用户「太冷酷，消失消费欲望」：付费入口必须比冷色控件更暖更亮。
    local warm = color[1] > 200 and color[2] > 140 and color[3] < 130
    nvgSave(ctx)
    -- 悬停/常驻：加色外辉光（金色底辉光更强，制造「值钱」的光晕）。
    local baseGlow = warm and math.max(g, 0.42) or g
    if baseGlow > 0.01 then
        nvgBeginPath(ctx)
        nvgRect(ctx, r.x - 8, r.y - 8, r.w + 16, r.h + 16)
        nvgFillPaint(ctx, nvgBoxGradient(ctx, r.x, r.y, r.w, r.h, 4, warm and 12 or 9,
            nvgRGBA(color[1], color[2], color[3], math.floor(baseGlow * (warm and 130 or 105))),
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
    if warm then
        -- 贵金属：高光更亮更暖（向白偏暖），暗端保留金色而非压成灰。
        nvgFillPaint(ctx, nvgLinearGradient(ctx, r.x, r.y, r.x + r.w * 0.24, r.y + r.h,
            nvgRGBA(255, 232, 168, 255),
            nvgRGBA(clamp255(color[1] * 0.66), clamp255(color[2] * 0.54), clamp255(color[3] * 0.34), 255)))
    else
        nvgFillPaint(ctx, nvgLinearGradient(ctx, r.x, r.y, r.x + r.w * 0.24, r.y + r.h,
            nvgRGBA(clamp255(color[1] + 34), clamp255(color[2] + 26), clamp255(color[3] + 28), 255),
            nvgRGBA(clamp255(color[1] * 0.60), clamp255(color[2] * 0.72), clamp255(color[3] * 0.76), 255)))
    end
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
    -- 玻璃漆面斜高光：按钮的「亮面」来源，与面板同语言。
    if r.w >= 40 and r.h >= 22 then
        nvgSave(ctx)
        nvgIntersectScissor(ctx, r.x + 1, r.y + 1, r.w - 2, r.h - 2)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, r.x, r.y + 1)
        nvgLineTo(ctx, r.x + r.w * 0.58, r.y + 1)
        nvgLineTo(ctx, r.x + r.w * 0.30, r.y + r.h * 0.54)
        nvgLineTo(ctx, r.x, r.y + r.h * 0.54)
        nvgFillPaint(ctx, nvgLinearGradient(ctx, r.x, r.y, r.x + r.w * 0.4, r.y + r.h * 0.5,
            nvgRGBA(255, 255, 255, math.floor(26 + g * 26)), nvgRGBA(255, 255, 255, 0)))
        nvgFill(ctx)
        nvgRestore(ctx)
    end
    -- 装饰纹路（v0.13.54）：极淡斜向拉丝 + 顶边刻度 + 角落取样点，给「机加工」密度。
    if r.w >= 110 and r.h >= 40 then
        DiagonalHatch(ctx, r.x + 2, r.y + 2, r.w - 4, r.h - 4, 12, C.ink, 12)
    end
    if r.w >= 96 and r.h >= 34 then
        Ticks(ctx, r.x + 10, r.y + r.h - 8, r.w - 20, 20, 4, 2, C.ink, 66)
    end
    if r.w >= 130 and r.h >= 44 then
        Cross(ctx, r.x + 9, r.y + 9, 3, C.ink, 70)
        Cross(ctx, r.x + r.w - 9, r.y + 9, 3, C.ink, 70)
    end
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
    -- 装饰纹路（v0.13.54）：全屏极淡网格 + 斜纹 + 半调网点 + 点阵，让背景不再是一块平色。
    MicroGrid(ctx, x, y, w, h, 30, C.cyanDim, 10)
    MicroGrid(ctx, x, y, w, h, 90, C.text, 7)
    DiagonalHatch(ctx, x, y, w, h * 0.62, 22, C.text, 5)
    DiagonalHatch(ctx, x, y + h * 0.45, w, h * 0.55, 34, C.cyanDim, 6)
    Halftone(ctx, x, y, w, h, 9, C.cyanDim, 12)
    DotMatrix(ctx, x + 18, y + 150, 44, 120, 12, C.cyanDim, 30)
    DotMatrix(ctx, x + w - 62, y + h - 270, 44, 120, 12, C.cyanDim, 30)
    DotMatrix(ctx, x + w * 0.5 - 60, y + h * 0.42, 120, 90, 13, C.cyanDim, 22)
    for i = 0, 3 do
        Cross(ctx, x + 26 + i * (w - 52) / 3, y + 96, 4, C.ghost, 62)
        Cross(ctx, x + 26 + i * (w - 52) / 3, y + h - 96, 4, C.ghost, 62)
    end
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
    -- 侧轨 + 刻度（v0.13.43：加胶囊标记，与规范 §4 的侧栏同构）。
    for _, xx in ipairs({ x + 3, x + w - 9 }) do
        Box(ctx, xx, y + 28, 6, h - 56, C.rail, 2)
        Line(ctx, xx, y + 28, xx + 6, y + 28, C.dim, 120)
        Line(ctx, xx, y + h - 28, xx + 6, y + h - 28, C.dim, 120)
        for yy = y + 42, y + h - 30, 46 do
            Line(ctx, xx + 1, yy, xx + 5, yy, C.cyanDim, 110)
        end
        -- 胶囊标记：每 46px 一枚，比刻度更亮，给侧轨「仪器格」的读数感。
        for yy = y + 60, y + h - 52, 92 do
            Box(ctx, xx + 1, yy, 4, 11, C.cyanDim, 2, 130)
            Line(ctx, xx + 1, yy + 15, xx + 5, yy + 15, C.cyanDim, 90)
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
    -- 装饰纹路（v0.13.54）：展台地面细网格 + 角落点阵 + 半调 + 环形刻度，让「机库地板」有刻度感。
    MicroGrid(ctx, r.x + 4, cy, r.w - 8, r.y + r.h - cy - 4, 22, C.cyanDim, 12)
    MicroGrid(ctx, r.x + 4, cy, r.w - 8, r.y + r.h - cy - 4, 66, C.text, 8)
    Halftone(ctx, r.x + 4, r.y + 8, r.w - 8, r.h - 16, 9, C.cyanDim, 12)
    DotMatrix(ctx, r.x + 12, r.y + 14, r.w - 24, 22, 10, C.cyanDim, 34)
    DotMatrix(ctx, r.x + 10, cy + 8, 40, 54, 11, C.cyanDim, 26)
    DotMatrix(ctx, r.x + r.w - 50, cy + 8, 40, 54, 11, C.cyanDim, 26)
    Ticks(ctx, r.x + 16, r.y + r.h - 10, r.w - 32, 20, 5, 2, C.cyanDim, 78)
    TickRing(ctx, cx, cy, r.w * 0.30, -20, 200, 12, C.cyanDim, 78)
    Cross(ctx, r.x + 20, r.y + 20, 4, C.ghost, 80)
    Cross(ctx, r.x + r.w - 20, r.y + 20, 4, C.ghost, 80)
    Cross(ctx, r.x + 20, r.y + r.h - 20, 4, C.ghost, 80)
    Cross(ctx, r.x + r.w - 20, r.y + r.h - 20, 4, C.ghost, 80)
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
