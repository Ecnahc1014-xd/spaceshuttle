-- ui/StageSelect.lua
-- 选关界面（NanoVG）。v0.13.14：改为**开心消消乐式蜿蜒路径地图**。
--
-- 用户否决了上一版「直线微偏移的细描边圆钮」，参考图给的是消消乐关卡地图：
--   · 一条**粗壮的蜿蜒路径**贯穿全屏，左右来回摆动（振幅大、周期长，肉眼看出"蛇形"）；
--   · 关卡节点是**大圆果冻钮**：亮色外圈 + 内部亮芯 + 粗描边数字，像可点的糖果；
--   · 节点**下方三颗星**（已得=实心亮星，未得=暗星）；
--   · 两侧竖排**圆形图标栏**（左侧道具购买、右侧装饰/收集），图标大而圆；
--   · 第 1 关在最下方，越往上关数越高，可一直往上爬。
--
-- ⚠️ UI 无污染：沿用游戏 dark-tech 令牌与 NanoVG 原语（依赖注入，不引入控件树）。
-- ⚠️ 本模块只画与命中；开某关 / 买道具由编排层（client_main.lua）执行。

local StageCatalog = require "StageCatalog"
local ItemShop = require "ui.ItemShop"
local PlayerData = require "PlayerData"
local DigitFont = require "ui.DigitFont"
local ArtText = require "ui.ArtText"

local StageSelect = {}

---@type table|nil  与 MetaUI.Init 相同的依赖表（C 令牌 + 绘制原语）
local D = nil

---@param deps table
function StageSelect.Init(deps)
    D = deps
end

---@return table
local function Style()
    return D.C
end

---@param r table
---@param px number
---@param py number
---@return boolean
local function Inside(r, px, py)
    return px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
end

-- ============================================================================
-- 常量（蜿蜒路径几何）
-- ============================================================================

local NODE_R = 40            -- 关卡果冻钮半径（比上一版大，像可点的糖果）
local ROW_STEP = 132         -- 相邻关卡的纵向间距（够大才显出"路"）
local SWAY_AMP = 96          -- 横向摆动幅度（大振幅 = 明显蛇形，不再"轻度"）
local SWAY_PERIOD = 3        -- 每几关完成一次左右来回（周期长 = 大 S 弯）
local SIDE_ICON_R = 26       -- 两侧圆形图标半径

-- 路径采样密度（贝塞尔分段数），越大越平滑
local PATH_SEGMENTS = 14

-- ============================================================================
-- 滚动状态（由编排层转发 Scroll* 调用）
-- ============================================================================

local scrollY_ = 0
local dragging_ = false
local dragLastY_ = 0
local dragStartY_ = 0
local dragMoved_ = false
local lastMaxStage_ = 1

-- ============================================================================
-- 布局
-- ============================================================================

---@class StageSelectLayout
---@field content table 可视内容区（含裁剪）
---@field close table
---@field towerX number 路径中心基准 x
---@field nodeY table<integer, number> 每关圆心 y（已应用滚动偏移）
---@field itemRows table[] 左侧道具购买行几何
---@field contentH number 全部内容高度
---@field maxStage integer

---@param w number
---@param maxStage integer
---@return StageSelectLayout
local function GetLayout(w, maxStage)
    local x, y = 18, 108
    local sw, sh = w - 36, 780
    local content = { x = x + 12, y = y + 56, w = sw - 24, h = sh - 72 }
    local close = { x = x + sw - 46, y = y + 8, w = 36, h = 36 }

    local towerX = content.x + content.w * 0.5
    -- 第 1 关在最下方：nodeY(1) = 内容区底部；越往上 y 越小。
    local botPad = NODE_R + 30
    local topPad = NODE_R + 30
    local contentH = topPad + botPad + (maxStage - 1) * ROW_STEP
    -- ⚠️ 关卡数少时内容矮于可视区：贴底会让上方留一大片空白（"没适配"观感）。
    -- 此时把整座塔**垂直居中**，让路径落在视觉中心。
    local freeSpace = content.h - contentH
    local centerOffset = freeSpace > 0 and freeSpace * 0.5 or 0

    ---@type table<integer, number>
    local nodeY = {}
    for stage = 1, maxStage do
        nodeY[stage] = content.y + content.h - botPad - (stage - 1) * ROW_STEP
            + scrollY_ - centerOffset
    end

    -- 左侧道具行：靠左边缘竖排（与路径不重叠：路径振幅 SWAY_AMP + NODE_R）。
    ---@type table[]
    local itemRows = {}
    local rowH = 104
    local gap = 12
    local railW = 84
    for i = 1, #StageSelect.ITEM_ORDER do
        itemRows[i] = {
            x = content.x + 4,
            y = content.y + 12 + (i - 1) * (rowH + gap),
            w = railW,
            h = rowH,
        }
    end

    return {
        content = content, close = close, towerX = towerX, nodeY = nodeY,
        itemRows = itemRows, contentH = contentH, maxStage = maxStage,
        botPad = botPad, centerOffset = centerOffset,
    }
end

-- 任意关号的圆心 y（含滚动与居中偏移）——供「未来关幽灵节点」这类 stage > maxStage 的绘制用。
---@param L StageSelectLayout
---@param stage integer
---@return number
local function NodeYAt(L, stage)
    return L.content.y + L.content.h - L.botPad - (stage - 1) * ROW_STEP
        + scrollY_ - L.centerOffset
end

---@return number 滚动上限（0 表示内容不高于可视区）
local function MaxScroll(L)
    return math.max(0, L.contentH - L.content.h)
end

local function ClampScroll(L)
    -- 塔从下往上延伸：更高关要靠正偏移移入可视区，不能套普通列表的负偏移范围。
    scrollY_ = math.max(0, math.min(MaxScroll(L), scrollY_))
end

-- 某关的横向偏移：**大振幅确定性正弦**（写死在代码里，非随机）。
-- 周期 SWAY_PERIOD 关一次来回 → 形成明显的大 S 弯，而不是"轻微抖动"。
---@param stage integer
---@return number
local function StageSway(stage)
    return math.sin((stage - 1) / SWAY_PERIOD * math.pi * 2) * SWAY_AMP
end

---@param L StageSelectLayout
---@param stage integer
---@return number cx
---@return number cy
local function NodeCenter(L, stage)
    return L.towerX + StageSway(stage), L.nodeY[stage]
end

-- 把视图滚动到「最新已解锁关」——打开面板时默认定位到它。
---@param w number
---@param maxStage integer
function StageSelect.FocusLatest(w, maxStage)
    lastMaxStage_ = math.max(1, maxStage or 1)
    scrollY_ = 0
    local L = GetLayout(w, lastMaxStage_)
    -- 让最新关落在可视区底部偏上，露出下方路径的"来路"。
    local target = L.content.y + L.content.h - NODE_R - 110
    scrollY_ = target - L.nodeY[lastMaxStage_]
    ClampScroll(L)
end

-- ============================================================================
-- 绘制原语（圆、平滑路径）
-- ============================================================================

---@param ctx any
---@param cx number
---@param cy number
---@param r number
---@param color integer[]
local function Circle(ctx, cx, cy, r, color)
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, r)
    nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
    nvgFill(ctx)
end

---@param ctx any
---@param cx number
---@param cy number
---@param r number
---@param color integer[]
---@param width number
local function CircleStroke(ctx, cx, cy, r, color, width)
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, r)
    nvgStrokeColor(ctx, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
    nvgStrokeWidth(ctx, width)
    nvgStroke(ctx)
end

-- ============================================================================
-- 星图原语（v0.13.59 风格重做：六边形关卡芯片 + 星座连线 + 星空）
-- ============================================================================

-- 正六边形路径（尖角朝上下）。绘制与命中共用同一形状，保证「看着能点=点得到」。
---@param ctx any
---@param cx number
---@param cy number
---@param r number
local function HexPath(ctx, cx, cy, r)
    nvgBeginPath(ctx)
    for i = 0, 5 do
        local a = math.pi / 3 * i - math.pi / 2
        local x, y = cx + math.cos(a) * r, cy + math.sin(a) * r
        if i == 0 then nvgMoveTo(ctx, x, y) else nvgLineTo(ctx, x, y) end
    end
    nvgClosePath(ctx)
end

---@param ctx any
---@param cx number
---@param cy number
---@param r number
---@param color integer[]
local function HexFill(ctx, cx, cy, r, color)
    HexPath(ctx, cx, cy, r)
    nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
    nvgFill(ctx)
end

---@param ctx any
---@param cx number
---@param cy number
---@param r number
---@param color integer[]
---@param width number
local function HexStroke(ctx, cx, cy, r, color, width)
    HexPath(ctx, cx, cy, r)
    nvgStrokeColor(ctx, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
    nvgStrokeWidth(ctx, width)
    nvgStroke(ctx)
end

-- 确定性星空（无随机状态；滚动时整体视差，营造「航行」感）。合并成单一路径避免命令缓冲溢出（AB-216）。
---@param ctx any
---@param area table {x,y,w,h}
local function DrawStarfield(ctx, area)
    local C = Style()
    nvgSave(ctx)
    nvgIntersectScissor(ctx, area.x, area.y, area.w, area.h)
    nvgBeginPath(ctx)
    for i = 0, 96 do
        local sx = area.x + ((i * 137 + 43) % math.max(1, math.floor(area.w)))
        local baseY = area.y + ((i * 89 + 17) % math.max(1, math.floor(area.h)))
        local sy = area.y + ((baseY - area.y + scrollY_ * 0.35) % math.max(1, math.floor(area.h)))
        nvgCircle(ctx, sx, sy, (i % 11 == 0) and 1.5 or 0.9)
    end
    nvgFillColor(ctx, nvgRGBA(C.text[1], C.text[2], C.text[3], 60))
    nvgFill(ctx)
    -- 少量亮星
    nvgBeginPath(ctx)
    for i = 0, 11 do
        local sx = area.x + ((i * 271 + 97) % math.max(1, math.floor(area.w)))
        local sy = area.y + ((i * 173 + 61 - scrollY_ * 0.35) % math.max(1, math.floor(area.h)))
        nvgCircle(ctx, sx, sy, 1.8)
    end
    nvgFillColor(ctx, nvgRGBA(C.cyan[1], C.cyan[2], C.cyan[3], 90))
    nvgFill(ctx)
    nvgRestore(ctx)
end

-- 关卡芯片的水平半宽（命中与连线让位共用）。
local function NodeHalfW()
    return NODE_R * 0.87
end

-- 沿两节点的连线方向各内缩 `pad`，得到不压住芯片的线段端点。
---@param ax number
---@param ay number
---@param bx number
---@param by number
---@param pad number
---@return number x1
---@return number y1
---@return number x2
---@return number y2
local function LinkGaps(ax, ay, bx, by, pad)
    local dx, dy = bx - ax, by - ay
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1 then return ax, ay, bx, by end
    local ux, uy = dx / len, dy / len
    return ax + ux * pad, ay + uy * pad, bx - ux * pad, by - uy * pad
end

-- 两节点间的星座连线：外发光 + 主线 + 芯线（三层做出「有能量」的观感）。
---@param ctx any
---@param ax number
---@param ay number
---@param bx number
---@param by number
---@param color integer[]
---@param lit boolean
local function DrawLink(ctx, ax, ay, bx, by, color, lit)
    local C = Style()
    local pad = NodeHalfW() * 0.98
    local x1, y1, x2, y2 = LinkGaps(ax, ay, bx, by, pad)
    local glowA = lit and 70 or 26
    local mainA = lit and 200 or 70
    nvgBeginPath(ctx); nvgMoveTo(ctx, x1, y1); nvgLineTo(ctx, x2, y2)
    nvgStrokeColor(ctx, nvgRGBA(color[1], color[2], color[3], glowA))
    nvgStrokeWidth(ctx, lit and 7 or 5); nvgLineCap(ctx, NVG_ROUND); nvgStroke(ctx)
    nvgBeginPath(ctx); nvgMoveTo(ctx, x1, y1); nvgLineTo(ctx, x2, y2)
    nvgStrokeColor(ctx, nvgRGBA(color[1], color[2], color[3], mainA))
    nvgStrokeWidth(ctx, lit and 2.4 or 1.6); nvgStroke(ctx)
    nvgBeginPath(ctx); nvgMoveTo(ctx, x1, y1); nvgLineTo(ctx, x2, y2)
    nvgStrokeColor(ctx, nvgRGBA(C.text[1], C.text[2], C.text[3], lit and 90 or 28))
    nvgStrokeWidth(ctx, 0.9); nvgStroke(ctx)
end

-- ============================================================================
-- 装饰插图（确定性挑选的低透明度像素块）
-- ============================================================================

local DECOR = {
    { w = 5, h = 4, cells = { {0,1},{1,0},{1,1},{1,2},{2,0},{2,1},{2,2},{3,1},{4,1} } },
    { w = 5, h = 3, cells = { {0,0},{1,0},{2,0},{0,1},{1,1},{2,1},{3,1},{3,0},{4,1} } },
    { w = 5, h = 5, cells = { {2,0},{2,1},{0,2},{1,2},{2,2},{3,2},{4,2},{2,3},{2,4} } },
}

---@param ctx any
---@param x number
---@param y number
---@param scale number
---@param index integer
---@param alpha number
local function DrawDecor(ctx, x, y, scale, index, alpha)
    local C = Style()
    local d = DECOR[index]
    if not d then return end
    for i = 1, #d.cells do
        local c = d.cells[i]
        D.rect(ctx, x + c[1] * scale, y + c[2] * scale, scale - 1, scale - 1,
            { C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], alpha }, 0)
    end
end

-- ============================================================================
-- 关卡节点（果冻钮 + 粗数字 + 三颗星）
-- ============================================================================

---@param ctx any
---@param cx number
---@param cy number
---@param stage integer
---@param unlocked boolean
---@param stars integer
---@param current boolean
local function DrawStageNode(ctx, cx, cy, stage, unlocked, stars, current)
    local C = Style()
    local r = NODE_R

    if not unlocked then
        -- 未解锁：暗色六边形 + 程序化小锁 + 压暗关号（贴图叠色表达，不写文字）。
        HexFill(ctx, cx, cy, r, { 16, 22, 34, 255 })
        HexStroke(ctx, cx, cy, r, { C.dim[1], C.dim[2], C.dim[3], 95 }, 1.4)
        D.rect(ctx, cx - 9, cy - 13, 18, 12, { 120, 138, 160, 235 }, 5)
        D.rect(ctx, cx - 5.5, cy - 9.5, 11, 8, { 16, 22, 34, 255 }, 4)
        D.rect(ctx, cx - 12, cy - 1, 24, 17, { 74, 88, 108, 235 }, 3)
        if not DigitFont.DrawNumber(ctx, stage, cx, cy - r + 20, 14, C.dim) then
            D.text(ctx, cx, cy - r + 22, tostring(stage), 13, C.dim,
                NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        end
        return
    end

    -- 已解锁：亮色六边形芯片（有星=金 / 无星=青，与「稀有/主操作」语义一致）。
    local accent = stars > 0 and C.warn or C.cyan
    -- 外发光（宽描边低 alpha，不填充以免糊住底图）
    HexStroke(ctx, cx, cy, r + 3.5, { accent[1], accent[2], accent[3], 60 }, 7)
    -- 底盘 + 内环（厚度）
    HexFill(ctx, cx, cy, r, { 26, 40, 62, 255 })
    HexStroke(ctx, cx, cy, r - 5, { accent[1], accent[2], accent[3], 105 }, 1)
    -- 当前关：整片亮色实心底（深字），是全屏最亮的焦点
    if current then HexFill(ctx, cx, cy, r - 8, accent) end
    -- 主环
    HexStroke(ctx, cx, cy, r, accent, current and 3 or 2.2)
    -- 顶面受光（沿上左/上右两条边画一道亮线，做出「斜切金属」感）
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, cx - r * 0.5, cy - r * 0.866)
    nvgLineTo(ctx, cx, cy - r)
    nvgLineTo(ctx, cx + r * 0.5, cy - r * 0.866)
    nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, current and 120 or 70))
    nvgStrokeWidth(ctx, 1.2)
    nvgStroke(ctx)

    -- 关号（贴图；缺图回退 zpix）。当前关深字、其余亮字。
    local label = tostring(stage)
    local size = (#label >= 3) and 28 or 38
    local digitColor = current and C.ink or C.text
    if not DigitFont.DrawNumber(ctx, stage, cx, cy - size * 0.60, size, digitColor) then
        D.text(ctx, cx, cy - size * 0.58, label, size, digitColor,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end

    -- 当前关：随共享相位脉冲一圈（低频动态，非随机）。
    if current then
        local phase = (D.anim and D.anim() or 0)
        local pulse = 0.5 + 0.5 * math.sin(phase * math.pi * 0.8)
        HexStroke(ctx, cx, cy, r + 6 + pulse * 3,
            { accent[1], accent[2], accent[3], math.floor(120 * (1 - pulse)) }, 2)
    end

    -- 三星：画在芯片**下方外侧**，用菱形（与六边形/科技语言一致），实心=已得。
    local gap = 15
    local sy = cy + r + 13
    for i = 1, 3 do
        local on = i <= stars
        local sx = cx + (i - 2) * gap
        if on then
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, sx, sy - 5.5); nvgLineTo(ctx, sx + 5.5, sy)
            nvgLineTo(ctx, sx, sy + 5.5); nvgLineTo(ctx, sx - 5.5, sy)
            nvgClosePath(ctx)
            nvgFillColor(ctx, nvgRGBA(C.warn[1], C.warn[2], C.warn[3], 255))
            nvgFill(ctx)
        else
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, sx, sy - 5.5); nvgLineTo(ctx, sx + 5.5, sy)
            nvgLineTo(ctx, sx, sy + 5.5); nvgLineTo(ctx, sx - 5.5, sy)
            nvgClosePath(ctx)
            nvgStrokeColor(ctx, nvgRGBA(96, 112, 132, 200))
            nvgStrokeWidth(ctx, 1.2)
            nvgStroke(ctx)
        end
    end
end

-- ============================================================================
-- 两侧圆形图标栏
-- ============================================================================

---@param ctx any
---@param r table
---@param iconKey string
---@param label string
---@param value string
---@param valueColor integer[]
---@param badge string|nil
---@param badgeColor integer[]
---@param dimmed boolean
---@param ring integer[]
local function DrawRoundIcon(ctx, r, iconKey, label, value, valueColor,
    badge, badgeColor, dimmed, ring)
    local C = Style()
    local cx, cy = r.x + r.w * 0.5, r.y + SIDE_ICON_R
    local body = dimmed and { 16, 22, 34, 255 } or { 26, 40, 62, 255 }
    Circle(ctx, cx, cy, SIDE_ICON_R, body)
    CircleStroke(ctx, cx, cy, SIDE_ICON_R, ring, 2.5)
    local alpha = dimmed and 0.3 or 1
    if not D.icon(ctx, iconKey, cx - 14, cy - 14, 28, alpha) then
        Circle(ctx, cx, cy, 9, ring)
    end
    -- 角标（库存/数量），用数字表达，不写说明文字
    if badge then
        local bx, by = cx + SIDE_ICON_R - 6, cy - SIDE_ICON_R + 6
        Circle(ctx, bx, by, 11, badgeColor)
        D.text(ctx, bx, by - 7, badge, 13, C.ink, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
    D.text(ctx, cx, cy + SIDE_ICON_R + 3, label, 13,
        dimmed and C.dim or C.text, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    D.text(ctx, cx, cy + SIDE_ICON_R + 20, value, 14, valueColor,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
end

-- ============================================================================
-- 绘制
-- ============================================================================

---@param ctx any
---@param w number
---@param meta table 需含 stageStars / maxStage / itemStock / itemPrices
function StageSelect.Draw(ctx, w, meta)
    local C = Style()
    local maxStage = math.max(1, meta.maxStage or 1)
    lastMaxStage_ = maxStage
    local L = GetLayout(w, maxStage)
    D.backdrop(ctx, 0, 0, w, 960)
    D.shell(ctx, 18, 108, w - 36, 780, 48)
    D.rect(ctx, 18, 156, 3, 22, C.cyan, 0)
    -- v0.13.58：面板主标题改用 AI 像素艺术字（深底亮字 → tint C.text）；无图回退 zpix。
    if not ArtText.Draw(ctx, "stage", 34 + ArtText.Width("stage") * 0.5, 116, C.text) then
        D.text(ctx, 34, 118, "选择关卡", 22, C.text)
    end
    local totalStars = 0
    for stage = 1, maxStage do
        totalStars = totalStars + ((meta.stageStars and meta.stageStars[stage]) or 0)
    end
    D.text(ctx, L.content.x + L.content.w - 44, 122,
        string.format("★ %d", totalStars), 15, C.warn,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)

    -- 关闭按钮
    D.panel(ctx, L.close.x, L.close.y, L.close.w, L.close.h, C.card, C.cyanDim, 6)
    D.text(ctx, L.close.x + L.close.w * 0.5, L.close.y + 7, "X", 20, C.dim,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    -- ---- 塔身（裁剪到内容区）----
    nvgSave(ctx)
    nvgIntersectScissor(ctx, L.content.x, L.content.y, L.content.w, L.content.h)

    -- 星空底（滚动视差），作为整片星图的基座。
    DrawStarfield(ctx, L.content)

    -- 仪器边框：四角折线 + 极淡网格 + 顶/底刻度带（与其余面板同语言，只画不进命中）。
    D.corner(ctx, L.content.x + 4, L.content.y + 4, L.content.w - 8, L.content.h - 8,
        {C.dim[1], C.dim[2], C.dim[3], 120}, 12, 1)
    D.grid(ctx, L.content.x + 6, L.content.y + 6, L.content.w - 12, L.content.h - 12,
        34, 7)
    D.rule(ctx, L.content.x + 12, L.content.y + 6, L.content.w - 24, 10,
        {C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 90})
    D.rule(ctx, L.content.x + 12, L.content.y + L.content.h - 6, L.content.w - 24, 10,
        {C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 90})

    -- 星座连线：相邻关之间一段；已解锁段亮青、未解锁段暗。
    for stage = 1, maxStage - 1 do
        local ax, ay = NodeCenter(L, stage)
        local bx, by = NodeCenter(L, stage + 1)
        DrawLink(ctx, ax, ay, bx, by, C.cyan, true)
    end
    -- 从当前最新关继续往前，延伸出通往「未来关」的暗线（纯装饰，不参与命中）。
    local px, py = NodeCenter(L, maxStage)
    for k = 1, 5 do
        local nx = L.towerX + StageSway(maxStage + k)
        local ny = NodeYAt(L, maxStage + k)
        DrawLink(ctx, px, py, nx, ny, C.cyanDim, false)
        px, py = nx, ny
    end

    -- 流动能量点：沿整条航线（已解锁段 + 延伸段）按共享相位前进（确定性，非随机）。
    do
        local phase = (D.anim and D.anim() or 0)
        local fpts = {}
        for stage = 1, maxStage + 5 do
            fpts[#fpts + 1] = { x = L.towerX + StageSway(stage), y = NodeYAt(L, stage) }
        end
        local nseg = #fpts - 1
        if nseg >= 1 then
            for d = 0, 3 do
                local t = ((phase * 0.4) + d * 0.25) % 1
                local seg = math.min(nseg, math.floor(t * nseg) + 1)
                local lt = t * nseg - (seg - 1)
                local p1, p2 = fpts[seg], fpts[seg + 1]
                if p1 and p2 then
                    local fx = p1.x + (p2.x - p1.x) * lt
                    local fy = p1.y + (p2.y - p1.y) * lt
                    Circle(ctx, fx, fy, 6.4, { C.cyan[1], C.cyan[2], C.cyan[3], 60 })
                    Circle(ctx, fx, fy, 3.0, { C.text[1], C.text[2], C.text[3], 200 })
                end
            end
        end
    end

    -- 未来关幽灵六边形：补满内容区、让「航线还很长」可见（极低 alpha，不参与命中）。
    for stage = maxStage + 1, maxStage + 6 do
        local cx = L.towerX + StageSway(stage)
        local cy = NodeYAt(L, stage)
        if cy > L.content.y - NODE_R and cy < L.content.y + L.content.h + NODE_R then
            HexFill(ctx, cx, cy, NODE_R, { 14, 22, 34, 110 })
            HexStroke(ctx, cx, cy, NODE_R, { C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 40 }, 1.4)
        end
    end

    -- 关卡芯片（从高到低画，避免重叠时低关压住高关）
    for stage = maxStage, 1, -1 do
        local cx, cy = NodeCenter(L, stage)
        if cy > L.content.y - NODE_R and cy < L.content.y + L.content.h + NODE_R then
            local stars = (meta.stageStars and meta.stageStars[stage]) or 0
            DrawStageNode(ctx, cx, cy, stage, true, stars, stage == maxStage)
        end
    end

    -- 右侧装饰插图（确定性挑选）
    local seed = math.floor(scrollY_ / 110)
    for k = 0, 4 do
        local idx = (seed + k) % #DECOR + 1
        local dy = L.content.y + 60 + k * 150
        if dy < L.content.y + L.content.h - 60 then
            DrawDecor(ctx, L.content.x + L.content.w - 62, dy, 7, idx, 26 + (k % 2) * 14)
        end
    end

    nvgRestore(ctx)

    -- ---- 左侧栏：道具购买（圆形图标 + 角标库存 + 价格）----
    local parts = PlayerData.GetParts()
    for i = 1, #StageSelect.ITEM_ORDER do
        local def = StageSelect.ITEM_ORDER[i]
        local r = L.itemRows[i]
        if r.y < L.content.y + L.content.h then
            local count = PlayerData.GetItemCount(def.key)
            local price = ItemShop.GetPrice(def.key)
            local atCap = count >= ItemShop.MAX_STOCK
            local affordable = (not atCap) and parts >= price
            local ring = atCap and C.widget or (affordable and C.cyan or C.cyanDim)
            DrawRoundIcon(ctx, r, def.icon, def.name, tostring(price),
                atCap and C.dim or (affordable and C.cyan or C.error),
                count > 0 and tostring(count) or nil,
                count > 0 and C.cyan or C.widget,
                count <= 0, ring)
        end
    end

    D.text(ctx, L.content.x + L.content.w * 0.5, L.content.y + L.content.h + 4,
        "上下滑动查看关卡", 13, C.dim, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
end

-- ============================================================================
-- 命中：返回 (action, index)。
--   "play_stage" + 关号 / "buy_item" + 道具序号 / "close"
-- ============================================================================

-- 道具 key 与图标/名称（顺序即左侧栏从上到下的顺序）。
StageSelect.ITEM_ORDER = {
    { key = "bomb",   name = "炸弹", color = { 196, 120, 255 }, icon = "bomb" },
    { key = "freeze", name = "冰冻", color = { 120, 216, 255 }, icon = "freeze" },
    { key = "shield", name = "护盾", color = { 90, 200, 255 },  icon = "shield" },
}

---@param uiX number
---@param uiY number
---@param w number
---@param meta table
---@return string|nil action
---@return integer|nil index
function StageSelect.HitTest(uiX, uiY, w, meta)
    local maxStage = math.max(1, meta.maxStage or 1)
    local L = GetLayout(w, maxStage)
    if Inside(L.close, uiX, uiY) then return "close", nil end

    -- 道具：命中整块竖条（含图标与文字），便于点按
    for i = 1, #StageSelect.ITEM_ORDER do
        if Inside(L.itemRows[i], uiX, uiY) then return "buy_item", i end
    end

    -- 关卡芯片：六边形命中（与绘制同形，保证「看着能点=点得到」）。
    -- 六边形（尖角朝上下）用三个约束判定：|dy| ≤ r，以及两条斜边 ±(dy·0.5 + |dx|·0.866) ≤ r。
    local hr = NODE_R + 3
    for stage = maxStage, 1, -1 do
        local cy = L.nodeY[stage]
        if cy > L.content.y - NODE_R and cy < L.content.y + L.content.h + NODE_R then
            local cx = L.towerX + StageSway(stage)
            local dx, dy = math.abs(uiX - cx), math.abs(uiY - cy)
            if dy <= hr and (dy * 0.5 + dx * 0.866) <= hr then
                return "play_stage", stage
            end
        end
    end
    return nil, nil
end

-- ============================================================================
-- 滚动（由编排层从鼠标/触摸转发）
-- ============================================================================

---@param uiX number
---@param uiY number
---@param w number
---@return boolean armed
function StageSelect.ScrollBegin(uiX, uiY, w)
    local L = GetLayout(w, lastMaxStage_)
    if not Inside(L.content, uiX, uiY) then return false end
    dragging_ = true
    dragLastY_ = uiY
    dragStartY_ = uiY
    dragMoved_ = false
    return true
end

---@param uiY number
---@param w number
function StageSelect.ScrollMove(uiY, w)
    if not dragging_ then return end
    local delta = uiY - dragLastY_
    dragLastY_ = uiY
    if math.abs(uiY - dragStartY_) > 8 then dragMoved_ = true end
    scrollY_ = scrollY_ + delta
    ClampScroll(GetLayout(w, lastMaxStage_))
end

---@return boolean moved 是否真的拖动过（拖动过则吞掉本次点击）
function StageSelect.ScrollEnd()
    if not dragging_ then return false end
    dragging_ = false
    return dragMoved_
end

---@return boolean
function StageSelect.IsDragging()
    return dragging_
end

return StageSelect
