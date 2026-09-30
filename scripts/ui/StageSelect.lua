-- ui/StageSelect.lua
-- 选关界面（NanoVG）。v0.13.13：从「15 关网格」改为**纵向无限爬塔**。
--
-- 形态（用户规格）：
--   · 中间一列**圆形关卡按钮**，圆心带高质量像素数字（用 zpix 位图字体绘制）；
--   · 从下往上关卡号递增——**第 1 关在最下方**，越往上关数越高，可一直往上爬；
--   · 每层有**固定写死在代码里**的横向偏移（确定性正弦，不用随机），形成爬塔的错落感；
--   · 打开时默认定位在**最新（最高已解锁）关**；
--   · 可视区左右两块空余空间用于：
--       1. 花零件购买局内道具（库存/单价；每局每样限用一次，只用明暗+角标表达，不写字）
--       2. 随机的低透明度像素插图（每帧按种子确定性挑选，纯装饰）
--
-- ⚠️ UI 无污染：沿用游戏 dark-tech 令牌与 NanoVG 原语（依赖注入，不引入控件树）。
-- ⚠️ 本模块只画与命中；开某关 / 买道具 / 解锁判定由编排层（client_main.lua）执行。

local StageCatalog = require "StageCatalog"
local ItemShop = require "ui.ItemShop"
local PlayerData = require "PlayerData"

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
-- 常量（爬塔几何）
-- ============================================================================

local NODE_R = 34            -- 圆形关卡按钮半径
local ROW_STEP = 96          -- 相邻关卡的纵向间距
local SWAY_AMP = 46          -- 横向偏移幅度（固定写死，非随机）
local SWAY_PERIOD = 4        -- 每几关完成一次左右摆动
local CENTER_FRAC = 0.5      -- 塔中心在内容区宽度上的位置

-- 侧栏（道具购买 / 装饰插图）宽度：内容区左右各留一块。
local SIDE_W = 96

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
-- 布局（纯几何，绘制与命中共用，禁止两套常量）
-- ============================================================================

---@class StageSelectLayout
---@field content table 可视内容区（含裁剪）
---@field close table
---@field towerX number 塔中心 x
---@field nodeY table<integer, number> 每关圆心 y（已应用滚动偏移）
---@field left table 左侧栏（道具购买）
---@field right table 右侧栏（装饰插图）
---@field itemRows table[] 道具购买行几何
---@field contentH number 全部内容高度
---@field maxStage integer

---@param w number
---@param maxStage integer
---@return StageSelectLayout
local function GetLayout(w, maxStage)
    local x, y = 18, 108
    local sw, sh = w - 36, 780
    local content = { x = x + 14, y = y + 60, w = sw - 28, h = sh - 76 }
    local close = { x = x + sw - 46, y = y + 8, w = 36, h = 36 }

    local towerX = content.x + content.w * CENTER_FRAC
    -- 第 1 关在最下方：nodeY(1) = 内容区底部；越往上 y 越小。
    local botPad = NODE_R + 24
    local topPad = NODE_R + 28
    local contentH = topPad + botPad + (maxStage - 1) * ROW_STEP

    ---@type table<integer, number>
    local nodeY = {}
    for stage = 1, maxStage do
        nodeY[stage] = content.y + content.h - botPad - (stage - 1) * ROW_STEP + scrollY_
    end

    -- 侧栏：左右各一块，避开塔身（塔身占中间 NODE_R*2 + 摆动余量）。
    local towerHalf = NODE_R + SWAY_AMP + 12
    local left = {
        x = content.x, y = content.y,
        w = math.max(SIDE_W, towerX - towerHalf - content.x),
        h = content.h,
    }
    local right = {
        x = towerX + towerHalf, y = content.y,
        w = math.max(SIDE_W, content.x + content.w - (towerX + towerHalf)),
        h = content.h,
    }

    -- 道具购买行：左侧栏内竖排三行（炸弹/冰冻/护盾）。
    ---@type table[]
    local itemRows = {}
    local rowH = 92
    local gap = 10
    for i = 1, #StageSelect.ITEM_ORDER do
        itemRows[i] = {
            x = left.x + 4,
            y = left.y + 10 + (i - 1) * (rowH + gap),
            w = left.w - 8,
            h = rowH,
        }
    end

    return {
        content = content, close = close, towerX = towerX, nodeY = nodeY,
        left = left, right = right, itemRows = itemRows,
        contentH = contentH, maxStage = maxStage,
    }
end

---@return number 滚动上限（0 表示内容不高于可视区）
local function MaxScroll(L)
    return math.max(0, L.contentH - L.content.h)
end

local function ClampScroll(L)
    scrollY_ = math.max(-MaxScroll(L), math.min(0, scrollY_))
end

-- 某关圆心的横向偏移：固定写死的确定性正弦（同一关永远是同一个偏移）。
---@param stage integer
---@return number
local function StageSway(stage)
    return math.sin((stage - 1) / SWAY_PERIOD * math.pi * 2) * SWAY_AMP
end

-- 把视图滚动到「最新已解锁关」——打开面板时默认定位到它。
---@param w number
---@param maxStage integer
function StageSelect.FocusLatest(w, maxStage)
    lastMaxStage_ = math.max(1, maxStage or 1)
    local L = GetLayout(w, lastMaxStage_)
    -- 目标：让最新关靠近可视区底部偏上一点（留出继续往上的空间感）。
    local target = L.content.y + L.content.h - NODE_R - 90
    local want = target - (L.content.y + L.content.h - (NODE_R + 24)
        - (lastMaxStage_ - 1) * ROW_STEP)
    scrollY_ = want
    ClampScroll(L)
end

-- ============================================================================
-- 装饰插图（随机但确定性的低透明度像素块）
-- ============================================================================

-- 纯程序化的像素小插图：每种是一组 (col,row) 格，画成低透明度方块。
local DECOR = {
    {   -- 小敌机剪影
        w = 5, h = 4,
        cells = {
            {0,1},{1,0},{1,1},{1,2},{2,0},{2,1},{2,2},{3,1},{4,1},
        },
    },
    {   -- 砖块堆
        w = 5, h = 3,
        cells = {
            {0,0},{1,0},{2,0},{0,1},{1,1},{2,1},{3,1},{3,0},{4,1},
        },
    },
    {   -- 星形点缀
        w = 5, h = 5,
        cells = {
            {2,0},{2,1},{0,2},{1,2},{2,2},{3,2},{4,2},{2,3},{2,4},
        },
    },
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
            {C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], alpha}, 0)
    end
end

-- ============================================================================
-- 绘制
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
    -- 圆底 + 圆环：已解锁亮青（有星则金），未解锁压暗。
    local ring = unlocked and (stars > 0 and C.warn or C.cyan) or C.widget
    local fill = unlocked and C.card or C.rail
    -- 圆底（用内切方 + 圆角模拟，避免依赖 arc 原语）
    local r = NODE_R
    D.rect(ctx, cx - r + 6, cy - r, r * 2 - 12, r * 2, fill, 12)
    D.rect(ctx, cx - r, cy - r + 6, r * 2, r * 2 - 12, fill, 12)
    D.rect(ctx, cx - r + 3, cy - r + 3, r * 2 - 6, r * 2 - 6, fill, 14)
    -- 圆环描边（上下左右四条，近似圆）
    D.stroke(ctx, cx - r + 6, cy - r, r * 2 - 12, r * 2, ring, 12, current and 2.5 or 1.6)
    D.stroke(ctx, cx - r, cy - r + 6, r * 2, r * 2 - 12, ring, 12, current and 2.5 or 1.6)

    if unlocked then
        -- 高质量像素数字（zpix 位图字体，两/三位数自动缩小）
        local label = tostring(stage)
        local size = (#label >= 3) and 22 or 30
        D.text(ctx, cx, cy - size * 0.62, label, size,
            current and C.cyan or C.text, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        -- 星条（三颗小方块，与旧版一致的表达）
        local starGap = 11
        local startX = cx - starGap
        for i = 1, 3 do
            local on = i <= stars
            D.rect(ctx, startX + (i - 1) * starGap - 3, cy + 18, 7, 7,
                on and C.warn or C.widget, 1)
        end
    else
        -- 未解锁：程序化锁形 + 关号（压暗）
        D.rect(ctx, cx - 8, cy - 16, 16, 12, C.dim, 6)
        D.rect(ctx, cx - 5, cy - 13, 10, 9, fill, 4)
        D.rect(ctx, cx - 11, cy - 6, 22, 16, C.widget, 3)
        D.text(ctx, cx, cy + 16, tostring(stage), 15, C.dim,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
end

---@param ctx any
---@param r table
---@param key string
---@param name string
---@param color integer[]
---@param count integer
---@param price integer
---@param iconKey string
local function DrawItemRow(ctx, r, key, name, color, count, price, iconKey)
    local C = Style()
    local parts = PlayerData.GetParts()
    local atCap = count >= ItemShop.MAX_STOCK
    local affordable = (not atCap) and parts >= price
    local border = atCap and C.widget or (affordable and C.cyan or C.cyanDim)
    D.panel(ctx, r.x, r.y, r.w, r.h, C.card, border, 6)
    -- 图标：库存为 0 时压暗（明暗表达「没有」）
    local alpha = count > 0 and 1 or 0.28
    if not D.icon(ctx, iconKey, r.x + r.w * 0.5 - 16, r.y + 8, 32, alpha) then
        D.rect(ctx, r.x + r.w * 0.5 - 12, r.y + 12, 24, 24, color, 4)
    end
    -- 库存角标（右上角数字，不写文字说明）
    if count > 0 then
        D.rect(ctx, r.x + r.w - 24, r.y + 4, 20, 18, C.ink, 3)
        D.text(ctx, r.x + r.w - 14, r.y + 6, tostring(count), 13, C.cyan,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
    D.text(ctx, r.x + r.w * 0.5, r.y + 46, name, 14, count > 0 and C.text or C.dim,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    -- 价格（零件）；买满/买不起用颜色区分
    local priceColor = atCap and C.dim or (affordable and C.cyan or C.error)
    D.text(ctx, r.x + r.w * 0.5, r.y + 68, tostring(price), 14, priceColor,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
end

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
    D.text(ctx, 34, 118, "选择关卡", 22, C.text)
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

    -- 连接线：相邻关卡之间画一条竖直短虚线（爬塔感）
    for stage = 1, maxStage - 1 do
        local y1 = L.nodeY[stage] - NODE_R
        local y2 = L.nodeY[stage + 1] + NODE_R
        if y2 < y1 then
            local x1 = L.towerX + StageSway(stage)
            local x2 = L.towerX + StageSway(stage + 1)
            local segs = 4
            for s = 1, segs do
                local t0 = (s - 1) / segs
                local t1 = t0 + 0.5 / segs
                local ya = y1 + (y2 - y1) * t0
                local yb = y1 + (y2 - y1) * t1
                local xa = x1 + (x2 - x1) * t0
                D.rect(ctx, xa - 1, ya, 2, math.max(1, yb - ya), C.cyanDim, 0)
            end
        end
    end

    -- 关卡圆钮（从高到低画，避免重叠时低关压住高关）
    for stage = maxStage, 1, -1 do
        local cx = L.towerX + StageSway(stage)
        local cy = L.nodeY[stage]
        if cy > L.content.y - NODE_R and cy < L.content.y + L.content.h + NODE_R then
            local unlocked = stage <= maxStage
            local stars = (meta.stageStars and meta.stageStars[stage]) or 0
            DrawStageNode(ctx, cx, cy, stage, unlocked, stars, stage == maxStage)
        end
    end

    nvgRestore(ctx)

    -- ---- 左侧栏：道具购买 ----
    for i = 1, #StageSelect.ITEM_ORDER do
        local def = StageSelect.ITEM_ORDER[i]
        local r = L.itemRows[i]
        if r.y < L.content.y + L.content.h then
            DrawItemRow(ctx, r, def.key, def.name, def.color,
                PlayerData.GetItemCount(def.key), ItemShop.GetPrice(def.key), def.icon)
        end
    end

    -- ---- 右侧栏：随机低透明度像素插图（按滚动位置确定性挑选）----
    local seed = math.floor(-scrollY_ / 90)
    for k = 0, 3 do
        local idx = (seed + k) % #DECOR + 1
        local dy = L.content.y + 40 + k * 150
        if dy < L.content.y + L.content.h - 60 then
            DrawDecor(ctx, L.right.x + 14, dy, 7, idx, 26 + (k % 2) * 14)
        end
    end

    -- 底部提示（保留「上滑」指引，不写道具规则）
    D.text(ctx, L.content.x + L.content.w * 0.5, L.content.y + L.content.h + 6,
        "上下滑动查看关卡", 13, C.dim, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
end

-- ============================================================================
-- 命中：返回 (action, index)。
--   "play_stage" + 关号 / "buy_item" + 道具序号 / "close"
-- ============================================================================

-- 道具 key 与图标/名称（顺序即左侧栏从上到下的顺序）。
StageSelect.ITEM_ORDER = {
    { key = "bomb",   name = "炸弹", color = {196, 120, 255}, icon = "bomb" },
    { key = "freeze", name = "冰冻", color = {120, 216, 255}, icon = "freeze" },
    { key = "shield", name = "护盾", color = {90, 200, 255},  icon = "shield" },
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

    -- 道具购买行（在左侧栏，不参与裁剪——整行都在可视区内）
    for i = 1, #StageSelect.ITEM_ORDER do
        if Inside(L.itemRows[i], uiX, uiY) then return "buy_item", i end
    end

    -- 关卡圆钮：命中半径略放大便于点按
    local hitR = NODE_R + 4
    for stage = maxStage, 1, -1 do
        local cy = L.nodeY[stage]
        if cy > L.content.y - NODE_R and cy < L.content.y + L.content.h + NODE_R then
            local cx = L.towerX + StageSway(stage)
            local dx, dy = uiX - cx, uiY - cy
            if dx * dx + dy * dy <= hitR * hitR then
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
