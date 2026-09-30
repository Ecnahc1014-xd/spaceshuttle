-- ui/TalentTree.lua
-- 天赋树界面（NanoVG）。v0.13.8：爬塔式圆形卡布局。
--
-- 布局：6 条线路各占一列（通用 2 列 + 车 4 列），每条线路自下而上按阶段爬升
-- （阶段 1 在最下方，阶段越高越靠上），节点用圆环卡表示、相邻阶段之间画连线。
-- 内容高于可视区，可上下拖拽滑动（拖拽输入由编排层转发 Scroll*）。
--
-- 点节点 → 底部弹方形浮窗（天赋名 + 详情 + 解锁按钮/状态），不再直接解锁。
--
-- ⚠️ UI 无污染：沿用游戏 dark-tech 令牌与 NanoVG 原语（依赖注入）。
-- ⚠️ 本模块只画与命中；真正的解锁（扣零件 + 落盘）由编排层执行。

local TalentCatalog = require "TalentCatalog"
local MetaCatalog = require "MetaCatalog"

local TalentTree = {}

---@type table|nil
local D = nil

---@param deps table
function TalentTree.Init(deps)
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

-- 选中节点 id（底部浮窗展示用）；由 HitTest 写入。
-- ⚠️ 必须声明在 GetLayout 之前——GetLayout 会读它决定内容区高度（前向引用=全局 nil）。
local selectedId_ = nil
-- 拖拽滚动状态（由编排层转发 Scroll 系列调用）。
local scrollY_ = 0
local dragging_ = false
local dragLastY_ = 0
local dragStartY_ = 0
local dragMoved_ = false

local CARD_R = 34          -- 圆形卡半径
local LANE_GAP = 12        -- 线路列间距
local ROW_STEP = 92        -- 相邻阶段的纵向间距（爬塔高度）

-- ============================================================================
-- 布局（纯几何，绘制与命中共用）
-- ============================================================================

---@class TalentLayout
---@field content table 可视内容区（含裁剪）
---@field close table
---@field laneX table<integer, number> 每条线路的中心 x
---@field colW number
---@field topPad number
---@field botPad number
---@field contentH number 全部内容高度（用于滚动上限）

---@param w number
---@return TalentLayout
local function GetLayout(w)
    local x, y = 18, 108
    local sw, sh = w - 36, 780
    -- 顶部标题栏 48 + 表头两行（线路名/星级）；内容区在其下。
    local headerY = y + 56
    local content = { x = x + 14, y = headerY + 34, w = sw - 28, h = sh - 72 - 34 }
    -- 浮窗展开时，内容可视区底部上收，避免被浮窗遮住（几何与命中同源）。
    if selectedId_ then
        local detailH = 132 + 18 + 8
        content.h = math.max(120, content.h - detailH)
    end
    local close = { x = x + sw - 46, y = y + 8, w = 36, h = 36 }
    local lanes = #TalentCatalog.LANES
    local labelW = 0
    local colW = math.floor((content.w - labelW - LANE_GAP * (lanes - 1)) / lanes)
    ---@type table<integer, number>
    local laneX = {}
    for i = 1, lanes do
        laneX[i] = content.x + labelW + (i - 1) * (colW + LANE_GAP) + colW * 0.5
    end
    -- 内容高度：最底阶段在内容区底部，向上每个阶段 ROW_STEP。
    local topPad = CARD_R + 34   -- 顶部留出星级门槛标签
    local botPad = CARD_R + 20
    local contentH = topPad + botPad + (TalentCatalog.MAX_STAGE - 1) * ROW_STEP
    return {
        content = content, close = close, laneX = laneX, colW = colW, headerY = headerY,
        topPad = topPad, botPad = botPad, contentH = contentH,
    }
end

-- 某节点的圆心（应用滚动偏移）。
---@param L TalentLayout
---@param laneIndex integer
---@param stage integer
---@return number cx
---@return number cy
local function NodeCenter(L, laneIndex, stage)
    local cx = L.laneX[laneIndex]
    -- stage 1 在底部，越高越靠上
    local cy = L.content.y + L.content.h - L.botPad
        - (stage - 1) * ROW_STEP + scrollY_
    return cx, cy
end

---@return number 滚动上限（0 表示内容不高于可视区）
local function MaxScroll(L)
    return math.max(0, L.contentH - L.content.h)
end

local function ClampScroll(L)
    scrollY_ = math.max(-MaxScroll(L), math.min(0, scrollY_))
end

-- ============================================================================
-- 圆形卡绘制（对齐局内道具槽观感：圆底 + 彩色描边 + 图标 + 状态角标）
-- ============================================================================

-- 线路配色（v0.13.8）：通用=品牌青；四条车线路用各自弹种色，与底部弹药槽一致。
local LANE_COLORS = {
    general_a = {0, 229, 208},
    general_b = {0, 229, 208},
    normal = {0, 229, 208},
    ice = {154, 226, 255},
    speed = {120, 176, 255},
    giant = {255, 196, 72},
}

local function LaneColor(node)
    local C = Style()
    if node and node.tint == "gold" then return C.warn end
    local lane = node and node.lane
    return (lane and LANE_COLORS[lane]) or C.cyan
end

---@param ctx any
---@param cx number
---@param cy number
---@param r number
---@param color table
---@param fill table
---@param width number
local function RingCard(ctx, cx, cy, r, color, fill, width)
    -- 圆底
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, r)
    nvgFillColor(ctx, nvgRGBA(fill[1], fill[2], fill[3], fill[4] or 255))
    nvgFill(ctx)
    -- 彩色圆环
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, r)
    nvgStrokeColor(ctx, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
    nvgStrokeWidth(ctx, width)
    nvgStroke(ctx)
end

---@param ctx any
---@param cx number
---@param cy number
---@param key string|nil
---@param size number
---@param alpha number
local function DrawNodeIcon(ctx, cx, cy, key, size, alpha)
    if key and D.icon and D.icon(ctx, key, cx - size * 0.5, cy - size * 0.5, size, alpha) then
        return true
    end
    return false
end

-- ============================================================================
-- 绘制
-- ============================================================================

---@param ctx any
---@param w number
---@param meta table 需含 talents(owned) / totalStars / parts
function TalentTree.Draw(ctx, w, meta)
    local C = Style()
    local L = GetLayout(w)
    local owned = meta.talents or {}
    local stars = meta.totalStars or 0
    local parts = meta.parts or 0
    ClampScroll(L)

    D.backdrop(ctx, 0, 0, w, 960)
    D.shell(ctx, 18, 108, w - 36, 780, 48)
    D.rect(ctx, 18, 156, 3, 22, C.cyan, 0)
    D.text(ctx, 34, 118, "天赋树", 22, C.text)
    D.text(ctx, L.content.x + L.content.w - 44, 122,
        string.format("零件 %d    ★ %d", parts, stars), 15, C.warn,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    -- 关闭按钮
    D.panel(ctx, L.close.x, L.close.y, L.close.w, L.close.h, C.card, C.cyanDim, 6)
    D.text(ctx, L.close.x + L.close.w * 0.5, L.close.y + 7, "X", 20, C.dim,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    -- 内容区裁剪：圆形卡与连线只在可视区内绘制
    nvgSave(ctx)
    nvgIntersectScissor(ctx, L.content.x, L.content.y, L.content.w, L.content.h)

    local lanes = TalentCatalog.LANES

    -- ① 先画连线（相邻阶段之间），再画卡片盖住线端
    for li, lane in ipairs(lanes) do
        local laneNodes = TalentCatalog.GetLaneNodes(lane)
        for si = 1, #laneNodes - 1 do
            local cx1, cy1 = NodeCenter(L, li, si)
            local cx2, cy2 = NodeCenter(L, li, si + 1)
            local unlocked = owned[laneNodes[si].id] == true
            local lineCol = unlocked and C.cyan or C.cyanDim
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, cx1, cy1)
            nvgLineTo(ctx, cx2, cy2)
            nvgStrokeColor(ctx, nvgRGBA(lineCol[1], lineCol[2], lineCol[3], unlocked and 200 or 90))
            nvgStrokeWidth(ctx, unlocked and 3 or 2)
            nvgStroke(ctx)
        end
    end

    -- ② 圆形卡
    for li, lane in ipairs(lanes) do
        local laneNodes = TalentCatalog.GetLaneNodes(lane)
        for si, node in ipairs(laneNodes) do
            local cx, cy = NodeCenter(L, li, si)
            if cy + CARD_R >= L.content.y - 4 and cy - CARD_R <= L.content.y + L.content.h + 4 then
                local isOwned = owned[node.id] == true
                local prereqMet = TalentCatalog.IsPrereqMet(node, owned, stars)
                local canBuy = (not isOwned) and prereqMet and parts >= node.cost
                local col = LaneColor(node.tint)
                local fill, width
                if isOwned then
                    fill, width = C.widget, 3
                elseif canBuy then
                    fill, width = C.card, 2.4
                    col = C.warn
                elseif prereqMet then
                    fill, width = C.card, 2
                else
                    fill, width = C.rail, 1.6
                    col = C.cyanDim
                end
                RingCard(ctx, cx, cy, CARD_R, col, fill, width)
                local iconAlpha = isOwned and 1.0 or (prereqMet and 0.75 or 0.3)
                if not DrawNodeIcon(ctx, cx, cy, node.icon, 30, iconAlpha) then
                    -- 缺图回退：画节点名首字
                    D.text(ctx, cx, cy - 10, (node.name or "?"):sub(1, 1), 22,
                        isOwned and C.text or C.dim, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
                end
                -- 状态角标：已解锁=青勾；未开放=右下小锁；可买=左下价格胶囊
                if isOwned then
                    nvgBeginPath(ctx)
                    nvgCircle(ctx, cx + CARD_R * 0.72, cy - CARD_R * 0.72, 11)
                    nvgFillColor(ctx, nvgRGBA(C.cyan[1], C.cyan[2], C.cyan[3], 255))
                    nvgFill(ctx)
                    D.text(ctx, cx + CARD_R * 0.72, cy - CARD_R * 0.72 - 8, "✓", 15, C.ink,
                        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
                elseif not prereqMet then
                    -- 未开放：不写文字，只在卡片下方画一把程序化小锁
                    local lx, ly = cx - 7, cy + CARD_R - 4
                    D.rect(ctx, lx, ly + 5, 14, 11, C.dim, 3)
                    D.rect(ctx, lx + 3, ly, 8, 8, fill, 4)
                elseif parts >= node.cost then
                    -- 可买：价格胶囊（金色）
                    D.panel(ctx, cx - 24, cy + CARD_R - 4, 48, 18, C.widget, C.warn, 9)
                    D.text(ctx, cx, cy + CARD_R + 1, tostring(node.cost), 12, C.warn,
                        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
                end
                -- 阶段序号（卡片上方小字，弱化）
                D.text(ctx, cx, cy - CARD_R - 15, tostring(si), 11, C.dim,
                    NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            end
        end
    end

    nvgRestore(ctx)

    -- ③ 顶部固定表头（裁剪区外，不随内容滚动）：线路名 + 星级门槛
    for li, lane in ipairs(lanes) do
        local need = TalentCatalog.STAGE_STARS[li] or 0
        local open = stars >= need
        local laneCol = (LANE_COLORS[lane]) or C.cyan
        D.text(ctx, L.laneX[li], L.headerY, TalentCatalog.LANE_NAMES[lane] or lane, 13,
            open and laneCol or C.dim, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        D.text(ctx, L.laneX[li], L.headerY + 16, (li == 1 and "0★" or (need .. "★")),
            12, open and C.cyan or C.dim, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end

    -- ④ 底部浮窗（选中节点时）
    TalentTree.DrawDetail(ctx, w, meta)
end

-- ============================================================================
-- 底部方形浮窗：天赋名 + 详情 + 解锁按钮/状态
-- ============================================================================

---@param w number
---@return table
function TalentTree.GetDetailLayout(w)
    local pw = w - 60
    local ph = 132
    return {
        x = 30, y = 960 - ph - 18, w = pw, h = ph,
        btn = { x = 30 + pw - 150, y = 960 - ph - 18 + ph - 50, w = 132, h = 40 },
    }
end

---@param ctx any
---@param w number
---@param meta table
function TalentTree.DrawDetail(ctx, w, meta)
    local node = selectedId_ and TalentCatalog.GetNode(selectedId_) or nil
    if not node then return end
    local C = Style()
    local owned = meta.talents or {}
    local stars = meta.totalStars or 0
    local parts = meta.parts or 0
    local L = TalentTree.GetDetailLayout(w)
    local isOwned = owned[node.id] == true
    local prereqMet = TalentCatalog.IsPrereqMet(node, owned, stars)

    D.panel(ctx, L.x, L.y, L.w, L.h, C.panel, C.cyanDim, 8)
    D.rect(ctx, L.x, L.y, 3, L.h, LaneColor(node.tint), 0)
    D.text(ctx, L.x + 14, L.y + 10, node.name or "天赋", 19, C.text)
    D.text(ctx, L.x + L.w - 14, L.y + 13,
        string.format("%s · 阶段 %d", TalentCatalog.LANE_NAMES[node.lane] or "", node.stage),
        14, C.dim, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    local lines = D.wrap(ctx, node.desc or "", 15, L.w - 28)
    for i = 1, math.min(2, #lines) do
        D.text(ctx, L.x + 14, L.y + 42 + (i - 1) * 20, lines[i], 15, C.dim)
    end

    -- 按钮状态：已解锁 / 未开放 / 零件不足(还差 x) / 解锁(花 N)
    local label, kind
    if isOwned then
        label, kind = "已解锁", "disabled"
    elseif not prereqMet then
        label, kind = "未开放", "disabled"
    elseif parts >= node.cost then
        label, kind = string.format("解锁 %d", node.cost), "primary"
    else
        label, kind = string.format("零件不足 还差 %d", node.cost - parts), "disabled"
    end
    local btn = L.btn
    local fill = kind == "primary" and C.cyan or C.widget
    D.panel(ctx, btn.x, btn.y, btn.w, btn.h, fill, kind == "primary" and C.cyan or C.cyanDim, 6)
    D.text(ctx, btn.x + btn.w * 0.5, btn.y + 11, label, 17,
        kind == "primary" and C.ink or C.dim, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
end

-- ============================================================================
-- 命中：节点 -> "select_talent"+nodeId（弹浮窗）；浮窗按钮 -> "unlock_talent"；关闭 -> "close"。
-- ============================================================================

---@param uiX number
---@param uiY number
---@param w number
---@param meta table
---@return string|nil action
---@return string|nil nodeId
function TalentTree.HitTest(uiX, uiY, w, meta)
    local L = GetLayout(w)
    if Inside(L.close, uiX, uiY) then return "close", nil end

    -- 浮窗按钮优先
    if selectedId_ then
        local D2 = TalentTree.GetDetailLayout(w)
        if Inside(D2.btn, uiX, uiY) then
            return "unlock_talent", selectedId_
        end
        -- 浮窗内其它区域：吞掉（不穿透到卡片）
        if Inside({ x = D2.x, y = D2.y, w = D2.w, h = D2.h }, uiX, uiY) then
            return nil, nil
        end
    end

    -- 圆形卡命中（取最近圆心）
    if Inside(L.content, uiX, uiY) then
        local lanes = TalentCatalog.LANES
        local bestId, bestDist = nil, (CARD_R + 6) * (CARD_R + 6)
        for li, lane in ipairs(lanes) do
            local laneNodes = TalentCatalog.GetLaneNodes(lane)
            for si, node in ipairs(laneNodes) do
                local cx, cy = NodeCenter(L, li, si)
                local dx, dy = uiX - cx, uiY - cy
                local d2 = dx * dx + dy * dy
                if d2 < bestDist then bestId, bestDist = node.id, d2 end
            end
        end
        if bestId then
            selectedId_ = bestId
            return "select_talent", bestId
        end
    end
    return nil, nil
end

-- ============================================================================
-- 拖拽滚动（编排层转发鼠标/触摸的按下/移动/抬起）
-- ============================================================================

---@param uiX number
---@param uiY number
---@param w number
---@return boolean consumed
function TalentTree.ScrollBegin(uiX, uiY, w)
    local L = GetLayout(w)
    if not Inside(L.content, uiX, uiY) then return false end
    dragging_ = true
    dragLastY_ = uiY
    dragStartY_ = uiY
    dragMoved_ = false
    return true
end

---@param uiY number
---@param w number
---@return boolean consumed
function TalentTree.ScrollMove(uiY, w)
    if not dragging_ then return false end
    local L = GetLayout(w)
    scrollY_ = scrollY_ + (uiY - dragLastY_)
    dragLastY_ = uiY
    if math.abs(uiY - dragStartY_) > 6 then dragMoved_ = true end
    ClampScroll(L)
    return true
end

---@return boolean 本次手势是否发生了拖拽（用于抑制点击）
function TalentTree.ScrollEnd()
    if not dragging_ then return false end
    dragging_ = false
    return dragMoved_
end

---@return boolean
function TalentTree.IsDragging()
    return dragging_
end

---@return string|nil
function TalentTree.GetSelected()
    return selectedId_
end

---@param id string|nil
function TalentTree.SetSelected(id)
    selectedId_ = id
end

return TalentTree
