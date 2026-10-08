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
local scrollbarDragging_ = false
local scrollbarPointerOffset_ = 0

local CARD_R = 30          -- 圆形卡半径
local LANE_GAP = 10        -- 线路列间距
local LABEL_W = 44         -- 左侧星级门槛栏宽（按横行标注，从下到上）
local SCROLLBAR_GUTTER = 28
local SCROLLBAR_HIT_W = 24
local ROW_STEP = 160       -- 相邻阶段的纵向间距
local DETAIL_RESERVE = 98
local LANE_STAGE_OFFSETS = { general_b = 0.5, ice = 0.5, giant = 0.5 }

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
    -- 顶部标题栏 48 + 表头一行（线路名）；内容区在其下。
    local headerY = y + 56
    local content = { x = x + 14, y = headerY + 30, w = sw - 28, h = sh - 72 - 30 }
    -- 浮窗展开时，内容可视区底部上收，避免被浮窗遮住（几何与命中同源）。
    if selectedId_ then
        content.h = math.max(160, content.h - DETAIL_RESERVE)
    end
    local close = { x = x + sw - 46, y = y + 8, w = 36, h = 36 }
    local lanes = #TalentCatalog.LANES
    local laneAreaW = content.w - SCROLLBAR_GUTTER
    local colW = math.floor((laneAreaW - LABEL_W - LANE_GAP * (lanes - 1)) / lanes)
    ---@type table<integer, number>
    local laneX = {}
    for i = 1, lanes do
        laneX[i] = content.x + LABEL_W + (i - 1) * (colW + LANE_GAP) + colW * 0.5
    end
    local scrollbarTrack = {
        x = content.x + laneAreaW + 12, y = content.y + 4,
        w = 4, h = content.h - 8,
    }
    local scrollbarHit = {
        x = scrollbarTrack.x - (SCROLLBAR_HIT_W - scrollbarTrack.w) * 0.5,
        y = scrollbarTrack.y, w = SCROLLBAR_HIT_W, h = scrollbarTrack.h,
    }
    -- 内容高度覆盖错位后最高线路的完整卡片与留白。
    local maxLaneOffset = 0.5
    local topPad = CARD_R + 4 + maxLaneOffset * ROW_STEP
    local botPad = CARD_R + 24 + maxLaneOffset * ROW_STEP
    local contentH = topPad + botPad
        + (TalentCatalog.MAX_STAGE - 1) * ROW_STEP
    return {
        content = content, close = close, laneX = laneX, colW = colW, headerY = headerY,
        topPad = topPad, botPad = botPad, contentH = contentH,
        scrollbarTrack = scrollbarTrack, scrollbarHit = scrollbarHit,
    }
end

-- 某节点的圆心（应用滚动偏移）。
---@param L TalentLayout
---@param laneIndex integer
---@param stage integer
---@return number cx
---@return number cy
local function NodeCenter(L, laneIndex, stage)
    local lane = TalentCatalog.LANES[laneIndex]
    local stageOffset = LANE_STAGE_OFFSETS[lane] or 0
    local cx = L.laneX[laneIndex]
    local cy = L.content.y + L.content.h - L.botPad
        - (stage - 1 + stageOffset) * ROW_STEP + scrollY_
    return cx, cy
end

---@return number 滚动上限（0 表示内容不高于可视区）
local function MaxScroll(L)
    return math.max(0, L.contentH - L.content.h)
end

local function ClampScroll(L)
    scrollY_ = math.max(0, math.min(MaxScroll(L), scrollY_))
end

---@param L TalentLayout
---@return table|nil thumb
local function GetScrollbarThumb(L)
    local maxScroll = MaxScroll(L)
    local track = L.scrollbarTrack
    if maxScroll <= 0 or track.h <= 0 then return nil end
    local thumbH = math.min(track.h, math.max(42, track.h * L.content.h / L.contentH))
    local travel = track.h - thumbH
    local progress = maxScroll > 0 and scrollY_ / maxScroll or 0
    local y = track.y + (1 - progress) * travel
    return { x = track.x - 4, y = y, w = 12, h = thumbH }
end

local function SetScrollFromThumb(L, pointerY, pointerOffset)
    local thumb = GetScrollbarThumb(L)
    if not thumb then return end
    local travel = L.scrollbarTrack.h - thumb.h
    if travel <= 0 then return end
    local thumbY = math.max(L.scrollbarTrack.y,
        math.min(L.scrollbarTrack.y + travel, pointerY - pointerOffset))
    scrollY_ = (1 - (thumbY - L.scrollbarTrack.y) / travel) * MaxScroll(L)
end

local function DrawScrollbar(ctx, L)
    local C = Style()
    local track = L.scrollbarTrack
    -- v0.13.16：原轨道用 C.rail（22,36,56）与深色底几乎同色 → 玩家看不出「这里有东西可滑」。
    -- 改为**明显可见的灰色轨道**：外描边 + 中灰填充，做成标准滚动条观感。
    -- ⚠️ 两个关键点：
    --   ① 轨道**常驻**绘制（即使当前内容不需要滚动）——它是"这里能滑"的引导，不是状态指示；
    --      旧实现把整条滚动条放在 GetScrollbarThumb 之后，没内容可滚时连轨道都不画 → 无提示。
    --   ② 箭头画在轨道**上下外侧**，不占用轨道内部——滑块几何与命中（SetScrollFromThumb）
    --      共用同一组数值，改内部会连带影响拖拽，所以这里只加装饰。
    local trackColor = { 96, 112, 132, 255 }      -- 中灰（明显高于底色）
    local trackEdge = { 148, 166, 188, 255 }      -- 浅灰描边
    local tx, ty, tw, th = track.x - 2, track.y, 8, track.h
    D.rect(ctx, tx, ty, tw, th, trackColor, 4)
    D.stroke(ctx, tx, ty, tw, th, trackEdge, 4, 1.2)
    -- 上下箭头（提示可滑动）：逐行收窄的矩形拼三角，放在轨道外侧
    local arrowCol = { 196, 210, 226, 235 }
    local ax = tx + tw * 0.5
    for i = 0, 4 do
        local w = (5 - i) * 2
        D.rect(ctx, ax - w * 0.5, ty - 10 + i, w, 2, arrowCol, 0)         -- 上箭头
        D.rect(ctx, ax - w * 0.5, ty + th + 6 - i, w, 2, arrowCol, 0)     -- 下箭头
    end
    -- 滑块：有内容可滚时才画（压在轨道上）
    local thumb = GetScrollbarThumb(L)
    if thumb then
        D.rect(ctx, thumb.x, thumb.y, thumb.w, thumb.h, C.cyanDim, 6)
        D.rect(ctx, thumb.x + 4, thumb.y + math.max(4, thumb.h * 0.5 - 9),
            4, 18, C.cyan, 2)
    end
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

---@return table
local function LaneColor(node)
    local lane = node and node.lane
    local color = lane and LANE_COLORS[lane] or nil
    if color then return color end
    return Style().cyan
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
    -- v0.13.16：血量加成是**所有卡通用**的规则 → 全局说明一次，不在每个节点里重复。
    D.text(ctx, 34, 146, TalentCatalog.HP_RULE_TEXT or "", 13, C.cyanDim,
        NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
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
                local col = LaneColor(node)
                local fill, width
                if isOwned then
                    fill, width = C.widget, 3
                elseif canBuy then
                    fill, width = C.card, 2.4
                elseif prereqMet then
                    fill, width = C.card, 2
                    col = LaneColor(node)
                else
                    fill, width = C.rail, 1.6
                    col = LaneColor(node)
                    local laneCol = col
                    col = { laneCol[1] * 0.42, laneCol[2] * 0.42, laneCol[3] * 0.42, 255 }
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
                -- 阶段序号不再画在卡片上（左侧栏已按横行标注星级门槛）
            end
        end
    end

    -- ③ 左侧星级门槛栏：按「横行（阶段）」从下到上标注（第 1 行 0★、第 2 行 3★…）。
    -- ⚠️ 门槛属于「阶段（横行）」而非「线路（纵列）」——早期版本误用 LANES 索引，
    -- 显示成每条线路要求不同星级，语义错误。
    for si = 1, TalentCatalog.MAX_STAGE do
        local cy = L.content.y + L.content.h - L.botPad - (si - 1) * ROW_STEP + scrollY_
        if cy + CARD_R >= L.content.y - 4 and cy - CARD_R <= L.content.y + L.content.h + 4 then
            local need = TalentCatalog.STAGE_STARS[si] or 0
            local open = stars >= need
            D.text(ctx, L.content.x + LABEL_W - 10, cy - 8, (need == 0 and "0★" or (need .. "★")),
                13, open and C.cyan or C.dim, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
        end
    end

    nvgRestore(ctx)

    -- ④ 右侧固定滚动条，滑块位置反映当前爬塔进度
    DrawScrollbar(ctx, L)

    -- ⑤ 顶部固定表头（裁剪区外，不随内容滚动）：仅线路名
    for li, lane in ipairs(lanes) do
        local laneCol = (LANE_COLORS[lane]) or C.cyan
        D.text(ctx, L.laneX[li], L.headerY, TalentCatalog.LANE_NAMES[lane] or lane, 13,
            laneCol, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end

    -- ⑥ 底部浮窗（选中节点时）
    TalentTree.DrawDetail(ctx, w, meta)
end

-- ============================================================================
-- 底部方形浮窗：天赋名 + 详情 + 解锁按钮/状态
-- ============================================================================

---@param w number
---@return table
function TalentTree.GetDetailLayout(w)
    local x, y = 30, 960 - 178
    local pw, ph = w - 60, 160
    return {
        x = x, y = y, w = pw, h = ph,
        btn = { x = x + 14, y = y + 112, w = pw - 28, h = 38 },
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
    D.rect(ctx, L.x, L.y, 3, L.h, LaneColor(node), 0)
    -- v0.13.50：补内受光 / 内沉影 / 顶亮线，与其余面板同一套厚度语言（只加不减）。
    D.rect(ctx, L.x + 2, L.y + 2, L.w - 4, math.floor(L.h * 0.34), {255, 255, 255, 18}, 6)
    D.rect(ctx, L.x + 2, L.y + math.floor(L.h * 0.6), L.w - 4,
        L.h - math.floor(L.h * 0.6) - 2, {0, 0, 0, 42}, 6)
    D.rect(ctx, L.x + 6, L.y + 1, L.w - 12, 1, {C.dim[1], C.dim[2], C.dim[3], 80}, 0)
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
    if Inside(L.scrollbarHit, uiX, uiY) then return nil, nil end
    if Inside(L.content, uiX, uiY) then
        local lanes = TalentCatalog.LANES
        local bestId, bestCy, bestLaneIndex, bestStage = nil, nil, nil, nil
        local bestDist = (CARD_R + 6) * (CARD_R + 6)
        for li, lane in ipairs(lanes) do
            local laneNodes = TalentCatalog.GetLaneNodes(lane)
            for si, node in ipairs(laneNodes) do
                local cx, cy = NodeCenter(L, li, si)
                local dx, dy = uiX - cx, uiY - cy
                local d2 = dx * dx + dy * dy
                if d2 < bestDist then
                    bestId, bestCy, bestLaneIndex, bestStage, bestDist = node.id, cy, li, si, d2
                end
            end
        end
        if bestId then
            selectedId_ = bestId
            local detail = TalentTree.GetDetailLayout(w)
            local newLayout = GetLayout(w)
            local minCy = newLayout.content.y + CARD_R + 4
            local maxCy = math.min(
                newLayout.content.y + newLayout.content.h - CARD_R - 12,
                detail.y - CARD_R - 12)
            local targetCy = math.max(minCy, math.min(maxCy, bestCy))
            local _, newCy = NodeCenter(newLayout, bestLaneIndex, bestStage)
            scrollY_ = scrollY_ + targetCy - newCy
            ClampScroll(newLayout)
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
    ClampScroll(L)
    if not Inside(L.scrollbarHit, uiX, uiY) and not Inside(L.content, uiX, uiY) then
        return false
    end
    dragging_ = true
    dragLastY_ = uiY
    dragStartY_ = uiY
    dragMoved_ = false
    scrollbarDragging_ = Inside(L.scrollbarHit, uiX, uiY)
    if scrollbarDragging_ then
        local thumb = GetScrollbarThumb(L)
        if thumb and Inside(thumb, uiX, uiY) then
            scrollbarPointerOffset_ = uiY - thumb.y
        else
            scrollbarPointerOffset_ = thumb and thumb.h * 0.5 or 0
            SetScrollFromThumb(L, uiY, scrollbarPointerOffset_)
            dragMoved_ = true
        end
        ClampScroll(L)
    end
    return true
end

---@param uiY number
---@param w number
---@return boolean consumed
function TalentTree.ScrollMove(uiY, w)
    if not dragging_ then return false end
    local L = GetLayout(w)
    if math.abs(uiY - dragStartY_) > 6 then dragMoved_ = true end
    if scrollbarDragging_ then
        SetScrollFromThumb(L, uiY, scrollbarPointerOffset_)
    else
        scrollY_ = scrollY_ + (uiY - dragLastY_)
    end
    dragLastY_ = uiY
    ClampScroll(L)
    return true
end

---@return boolean 本次手势是否发生了拖拽（用于抑制点击）
function TalentTree.ScrollEnd()
    if not dragging_ then return false end
    dragging_ = false
    local moved = dragMoved_
    scrollbarDragging_ = false
    return moved
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
