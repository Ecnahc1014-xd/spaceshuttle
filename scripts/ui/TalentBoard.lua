-- ui/TalentBoard.lua
-- 天赋树「全屏 2D 大画布」（v0.13.77）：取代 540×960 里的小窗口面板。
--
-- 结构：6 条线路 = 6 列，每列 13 阶纵向排布；卡片是**大卡**（名字 + 花费 + 状态），
-- 列内相邻阶之间用连线表示前置关系，已解锁段高亮。
-- 交互：拖拽平移（世界画布比视口大很多）、＋/－ 缩放（0.6~1.4）、点卡片选中、
-- 底部详情卡解锁；接口名与 ui/TalentTree.lua 完全一致，编排层只换 require。
--
-- 与 3D 版（ui/TalentGrove.lua）不同：纯 NanoVG 2D，无 RT / 无相机 / 无材质，
-- 可读性和命中都是设计像素直算，不存在"看不清点不到"的问题。
local TalentCatalog = require "TalentCatalog"

local TalentBoard = {}

local DESIGN_W, DESIGN_H = 540, 960
local HUD_H = 104          -- 顶部固定条（标题 + 关闭 + 缩放）
local DETAIL_H = 188       -- 底部详情卡预留

local CARD_W, CARD_H = 110, 96
local COL_GAP, ROW_GAP = 18, 22
local WORLD_PAD = 48

local ZOOM_MIN, ZOOM_MAX = 0.55, 1.3

---@type table|nil MetaUI 依赖（取令牌 + 绘制助手）
local D = nil

-- 画布状态（相机 = 世界坐标左上角 + 缩放）
local S = {
    camX = 0, camY = 0, zoom = 0.63,
    selected = nil,
    dragActive = false, dragMoved = false, dragX = 0, dragY = 0,
    lastTapAt = 0,
} ---@type table

-- ============================================================================
-- 布局
-- ============================================================================

---世界坐标尺寸（6 列 × 13 行）
---@return number worldW
---@return number worldH
local function WorldSize()
    local lanes = #TalentCatalog.LANES
    local rows = TalentCatalog.MAX_STAGE
    local w = WORLD_PAD * 2 + lanes * CARD_W + (lanes - 1) * COL_GAP
    local h = WORLD_PAD * 2 + 34 + rows * CARD_H + (rows - 1) * ROW_GAP
    return w, h
end

---@param laneIndex integer
---@param stage integer
---@return number x 世界坐标（卡片左上角）
---@return number y
local function CardWorldPos(laneIndex, stage)
    local x = WORLD_PAD + (laneIndex - 1) * (CARD_W + COL_GAP)
    local y = WORLD_PAD + 34 + (stage - 1) * (CARD_H + ROW_GAP)
    return x, y
end

---视口内可用高度（去掉顶部条与详情卡）
---@param selected boolean
---@return number viewH
local function ViewHeight(selected)
    return DESIGN_H - HUD_H - (selected and DETAIL_H or 0)
end

---把相机夹在世界范围内
---@param selected boolean
local function ClampCam(selected)
    local worldW, worldH = WorldSize()
    local viewW, viewH = DESIGN_W, ViewHeight(selected)
    local maxX = math.max(0, worldW - viewW / S.zoom)
    local maxY = math.max(0, worldH - viewH / S.zoom)
    S.camX = math.max(0, math.min(maxX, S.camX))
    S.camY = math.max(0, math.min(maxY, S.camY))
end

---世界 → 屏幕（设计坐标）
---@param wx number
---@param wy number
---@return number
---@return number
local function ToScreen(wx, wy)
    return (wx - S.camX) * S.zoom, HUD_H + (wy - S.camY) * S.zoom
end

---屏幕 → 世界
---@param sx number
---@param sy number
---@return number
---@return number
local function ToWorld(sx, sy)
    return S.camX + sx / S.zoom, S.camY + (sy - HUD_H) / S.zoom
end

-- ============================================================================
-- 状态
-- ============================================================================

---@param node table
---@param lanes table<integer, table[]>
---@param meta table
---@return boolean owned
---@return boolean canUnlock
local function NodeState(node, lanes, meta)
    local talents = meta.talents or {}
    local owned = talents[node.id] == true
    if owned then return true, false end
    local unlockedStage = meta.talentStageCount or 0
    if node.stage > unlockedStage then return false, false end
    local laneNodes = lanes[node.stage - 1]
    local prevOk = (node.stage == 1) or (laneNodes ~= nil)
    if node.stage > 1 then
        local prevNode = TalentCatalog.GetLaneNodes(node.lane)[node.stage - 1]
        prevOk = prevNode ~= nil and talents[prevNode.id] == true
    end
    local parts = meta.parts or 0
    return false, prevOk and parts >= (node.cost or math.huge)
end

---@param node table
---@param meta table
---@return table rgb
local function LaneRgb(node)
    local C = (D and D.C) or {}
    local palettes = {
        general_a = C.cyan or { 226, 228, 232 },
        general_b = C.warn or { 243, 167, 62 },
        normal = { 90, 164, 255 },
        ice = { 120, 220, 255 },
        speed = { 255, 120, 90 },
        giant = { 176, 120, 255 },
    }
    return palettes[node.lane] or { 226, 228, 232 }
end

-- ============================================================================
-- 绘制
-- ============================================================================

---@param ctx any
---@param x number
---@param y number
---@param w number
---@param h number
---@param fill table
---@param border table|nil
---@param r number
local function Panel(ctx, x, y, w, h, fill, border, r)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x, y, w, h, r)
    nvgFillColor(ctx, nvgRGBA(fill[1], fill[2], fill[3], fill[4] or 255))
    nvgFill(ctx)
    if border then
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, x + 0.5, y + 0.5, w - 1, h - 1, r)
        nvgStrokeColor(ctx, nvgRGBA(border[1], border[2], border[3], border[4] or 200))
        nvgStrokeWidth(ctx, 1.2)
        nvgStroke(ctx)
    end
end

---@param ctx any
---@param x number
---@param y number
---@param str string
---@param size number
---@param color table
---@param align integer|nil
local function Text(ctx, x, y, str, size, color, align)
    if D and D.text then
        D.text(ctx, x, y, str, size, color, align)
    else
        nvgFontSize(ctx, size)
        nvgTextAlign(ctx, align or (NVG_ALIGN_LEFT + NVG_ALIGN_TOP))
        nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
        nvgText(ctx, x, y, tostring(str))
    end
end

---@param ctx any
---@param meta table
---@return table closeBtn
---@return table zoomIn
---@return table zoomOut
local function DrawHud(ctx, meta)
    local C = (D and D.C) or { text = { 242, 239, 234 }, dim = { 148, 147, 145 }, cyan = { 226, 228, 232 }, warn = { 243, 167, 62 }, card = { 24, 25, 31 }, cyanDim = { 150, 152, 158 } }
    local closeBtn = { x = DESIGN_W - 52, y = 30, w = 36, h = 36 }
    local zoomIn = { x = DESIGN_W - 96, y = 30, w = 36, h = 36 }
    local zoomOut = { x = DESIGN_W - 140, y = 30, w = 36, h = 36 }

    Text(ctx, 20, 22, "天赋树", 22, C.text)
    Text(ctx, 20, 52, string.format("已解锁 %d/%d · 已开放 %d/%d 阶 · 星级 %d",
        meta.talentCount or 0, meta.talentTotal or 0,
        meta.talentStageCount or 0, meta.talentMaxStage or 0, meta.totalStars or 0),
        12, C.dim)
    if D and D.rule then D.rule(ctx, 20, 78, DESIGN_W - 88, 12, C.cyanDim, 6) end

    local function smallBtn(r, label)
        Panel(ctx, r.x, r.y, r.w, r.h, { C.card[1], C.card[2], C.card[3], 240 }, C.cyanDim, 8)
        Text(ctx, r.x + r.w * 0.5, r.y + 9, label, 18, C.text, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
    smallBtn(closeBtn, "×")
    smallBtn(zoomIn, "+")
    smallBtn(zoomOut, "−")
    return closeBtn, zoomIn, zoomOut
end

---绘制一张天赋卡（世界坐标经 ToScreen 映射）
---@param ctx any
---@param node table
---@param meta table
---@param selected boolean
local function DrawCard(ctx, node, meta, selected)
    local C = (D and D.C) or { text = { 242, 239, 234 }, dim = { 148, 147, 145 }, cyan = { 226, 228, 232 }, warn = { 243, 167, 62 }, card = { 24, 25, 31 }, panel = { 14, 15, 19 }, ink = { 5, 5, 7 }, cyanDim = { 150, 152, 158 } }
    local lanes = {}
    local owned, canUnlock = NodeState(node, lanes, meta)
    local rgb = LaneRgb(node)
    local x, y = CardWorldPos(node.laneIndex, node.stage)
    local sx, sy = ToScreen(x, y)
    local w, h = CARD_W * S.zoom, CARD_H * S.zoom

    -- 视口外快速裁剪
    if sx > DESIGN_W or sx + w < 0 or sy > DESIGN_H or sy + h < HUD_H then return end

    local fill = owned and { rgb[1] * 0.22 + 18, rgb[2] * 0.22 + 18, rgb[3] * 0.22 + 20, 245 }
        or (canUnlock and { 34, 30, 22, 245 } or { C.panel[1] + 6, C.panel[2] + 6, C.panel[3] + 8, 235 })
    local border = selected and C.warn
        or (owned and rgb or (canUnlock and C.warn or { 96, 98, 106, 150 }))
    Panel(ctx, sx, sy, w, h, fill, border, 9)
    -- 左侧线路识别竖条
    nvgBeginPath(ctx)
    nvgRect(ctx, sx + 6, sy + 10, 3, h - 20)
    nvgFillColor(ctx, nvgRGBA(rgb[1], rgb[2], rgb[3], owned and 230 or 150))
    nvgFill(ctx)

    -- 字号固定（不随缩放变小），只让卡片几何缩放：大地图缩到 0.6 时文字仍清晰
    local small, mid = 10, 12
    local name = node.name or node.id
    local nameSize = mid
    -- 名字超宽：先按字符截断加省略号（中文按 utf8 字符边界切），再不行才缩字号
    local maxW = w - 18
    if D and D.measure and utf8 and utf8.len and utf8.offset then
        local okLen, charCount = pcall(utf8.len, name)
        if okLen and charCount and charCount > 1 and D.measure(ctx, name, nameSize) > maxW then
            for k = charCount - 1, 1, -1 do
                local okOff, off = pcall(utf8.offset, name, k + 1)
                if okOff and off then
                    local cut = string.sub(name, 1, off - 1) .. "…"
                    if D.measure(ctx, cut, nameSize) <= maxW or k == 1 then
                        name = cut
                        break
                    end
                end
            end
        end
    end
    Text(ctx, sx + 14, sy + 7, string.format("%d 阶", node.stage), small, C.dim)
    Text(ctx, sx + 14, sy + 22, name, nameSize, owned and C.text or (canUnlock and C.text or C.dim))
    Text(ctx, sx + 14, sy + h - 19, string.format("%d", node.cost or 0), small,
        owned and C.dim or (canUnlock and C.warn or C.dim))
    Text(ctx, sx + w - 9, sy + h - 19, owned and "已解锁" or (canUnlock and "可解锁" or "未开放"),
        9, owned and rgb or (canUnlock and C.warn or C.dim), NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
end

---@param ctx any
---@param w number
---@param meta table
function TalentBoard.Draw(ctx, w, meta)
    local C = (D and D.C) or { bg = { 9, 10, 13 }, text = { 242, 239, 234 }, dim = { 148, 147, 145 }, cyan = { 226, 228, 232 }, warn = { 243, 167, 62 }, card = { 24, 25, 31 }, panel = { 14, 15, 19 }, ink = { 5, 5, 7 }, cyanDim = { 150, 152, 158 } }

    -- 底：与全游戏一致的深海军渐变 + 微网格
    local g = nvgLinearGradient(ctx, 0, 0, w * 0.7, DESIGN_H,
        nvgRGBA(12, 17, 27, 255), nvgRGBA(5, 7, 12, 255))
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, w, DESIGN_H)
    nvgFillPaint(ctx, g)
    nvgFill(ctx)
    if D and D.grid then D.grid(ctx, 0, 0, w, DESIGN_H, 46, 18) end

    local selected = S.selected ~= nil
    ClampCam(selected)
    local closeBtn, zoomIn, zoomOut = DrawHud(ctx, meta or {})
    S.closeRect, S.zoomIn, S.zoomOut = closeBtn, zoomIn, zoomOut

    local viewBottom = DESIGN_H - (selected and DETAIL_H or 0)
    nvgSave(ctx)
    nvgIntersectScissor(ctx, 0, HUD_H, DESIGN_W, math.max(0, viewBottom - HUD_H))

    -- 列标题（线路名 + 已解锁进度）
    local talents = (meta and meta.talents) or {}
    for laneIndex, lane in ipairs(TalentCatalog.LANES) do
        local cx = WORLD_PAD + (laneIndex - 1) * (CARD_W + COL_GAP)
        local sx, sy = ToScreen(cx, WORLD_PAD - 6)
        local nodes = TalentCatalog.GetLaneNodes(lane)
        local ownedCount = 0
        for _, n in ipairs(nodes) do
            if talents[n.id] then ownedCount = ownedCount + 1 end
        end
        local rgb = LaneRgb({ lane = lane })
        nvgBeginPath(ctx)
        nvgRect(ctx, sx, sy - 16, CARD_W * S.zoom, 22)
        nvgFillColor(ctx, nvgRGBA(rgb[1], rgb[2], rgb[3], 40))
        nvgFill(ctx)
        Text(ctx, sx + 4, sy - 13, string.format("%s %d/%d", TalentCatalog.LANE_NAMES[lane] or lane, ownedCount, #nodes),
            11, { rgb[1], rgb[2], rgb[3], 235 })
    end

    -- 连线（同列相邻阶）：已解锁段用线路色，其余暗灰
    for laneIndex, lane in ipairs(TalentCatalog.LANES) do
        local nodes = TalentCatalog.GetLaneNodes(lane)
        local rgb = LaneRgb({ lane = lane })
        for stage = 1, #nodes - 1 do
            local x0, y0 = CardWorldPos(laneIndex, stage)
            local x1, y1 = CardWorldPos(laneIndex, stage + 1)
            local ax, ay = ToScreen(x0 + CARD_W * 0.5, y0 + CARD_H)
            local bx, by = ToScreen(x1 + CARD_W * 0.5, y1)
            local lit = talents[nodes[stage].id] == true
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, ax, ay)
            nvgLineTo(ctx, bx, by)
            nvgStrokeColor(ctx, lit and nvgRGBA(rgb[1], rgb[2], rgb[3], 200)
                or nvgRGBA(96, 98, 106, 140))
            nvgStrokeWidth(ctx, lit and 2.4 or 1.4)
            nvgStroke(ctx)
        end
    end

    -- 卡片
    for laneIndex, lane in ipairs(TalentCatalog.LANES) do
        local nodes = TalentCatalog.GetLaneNodes(lane)
        for stage, node in ipairs(nodes) do
            node.laneIndex = laneIndex
            DrawCard(ctx, node, meta or {}, S.selected == node.id)
        end
    end
    nvgRestore(ctx)

    -- 底部详情卡
    if selected then
        local node = TalentCatalog.GetNode(S.selected)
        if not node then S.selected = nil; return end
        local card = { x = 16, y = DESIGN_H - DETAIL_H + 8, w = DESIGN_W - 32, h = DETAIL_H - 20 }
        local btn = { x = card.x + card.w - 140, y = card.y + card.h - 52, w = 124, h = 42 }
        local rgb = LaneRgb(node)
        local owned, canUnlock = NodeState(node, {}, meta or {})
        Panel(ctx, card.x, card.y, card.w, card.h, { 20, 21, 26, 246 }, C.cyanDim, 10)
        nvgBeginPath(ctx)
        nvgRect(ctx, card.x + 14, card.y + 14, 3, 24)
        nvgFillColor(ctx, nvgRGBA(rgb[1], rgb[2], rgb[3], 220))
        nvgFill(ctx)
        Text(ctx, card.x + 26, card.y + 12, node.name or node.id, 17, C.text)
        Text(ctx, card.x + 26, card.y + 38, string.format("%s · 第 %d 阶 · %d 零件",
            TalentCatalog.LANE_NAMES[node.lane] or node.lane, node.stage, node.cost or 0), 11, C.dim)
        if D and D.wrap and node.desc then
            local lines = D.wrap(ctx, node.desc, 12, card.w - 190)
            for i, line in ipairs(lines) do
                if i > 3 then break end
                Text(ctx, card.x + 26, card.y + 60 + (i - 1) * 16, line, 12, { 196, 196, 192, 255 })
            end
        elseif node.desc then
            Text(ctx, card.x + 26, card.y + 60, node.desc, 12, { 196, 196, 192, 255 })
        end
        Panel(ctx, btn.x, btn.y, btn.w, btn.h, owned and { 40, 41, 47, 246 }
            or { C.warn[1], C.warn[2], C.warn[3], 238 }, nil, 9)
        Text(ctx, btn.x + btn.w * 0.5, btn.y + 11, owned and "已解锁" or (canUnlock and "解锁" or "条件不足"),
            16, owned and C.dim or C.ink, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        S.detailBtn = owned and nil or btn
        S.detailRect = card
    else
        S.detailBtn, S.detailRect = nil, nil
    end
end

-- ============================================================================
-- 命中
-- ============================================================================

---@param uiX number
---@param uiY number
---@param w number
---@param meta table
---@return string|nil action
---@return string|nil index
function TalentBoard.HitTest(uiX, uiY, w, meta)
    local function inside(r)
        return r and uiX >= r.x and uiX <= r.x + r.w and uiY >= r.y and uiY <= r.y + r.h
    end
    if inside(S.closeRect) then return "close", nil end
    if inside(S.zoomIn) then S.zoom = math.min(ZOOM_MAX, S.zoom + 0.1); return "__zoom", nil end
    if inside(S.zoomOut) then S.zoom = math.max(ZOOM_MIN, S.zoom - 0.1); return "__zoom", nil end
    -- 详情卡按钮
    if inside(S.detailBtn) and S.selected then return "unlock_talent", S.selected end
    if inside(S.detailRect) then return nil, nil end

    -- 卡片命中（世界坐标反算，按可见顺序倒序取最上层）
    local wx, wy = ToWorld(uiX, uiY)
    for laneIndex = #TalentCatalog.LANES, 1, -1 do
        local lane = TalentCatalog.LANES[laneIndex]
        local nodes = TalentCatalog.GetLaneNodes(lane)
        for stage = #nodes, 1, -1 do
            local x, y = CardWorldPos(laneIndex, stage)
            if wx >= x and wx <= x + CARD_W and wy >= y and wy <= y + CARD_H then
                S.selected = nodes[stage].id
                return "select_talent", nodes[stage].id
            end
        end
    end
    S.selected = nil
    return nil, nil
end

-- ============================================================================
-- 拖拽平移 / 缩放（编排层转发；兼容两参与三参调用）
-- ============================================================================

---@param a number uiX（三参）或 uiY（两参）
---@param b number|nil uiY（三参）或 w（两参）
---@param c number|nil w（三参）
---@return boolean consumed
function TalentBoard.ScrollBegin(a, b, c)
    local uiY = c and b or a
    if uiY < HUD_H or uiY > DESIGN_H then return false end
    local uiX = c and a or 0
    S.dragActive, S.dragMoved = true, false
    S.dragX, S.dragY = uiX, uiY
    return true
end

---@param a number uiX 或 uiY
---@param b number|nil uiY 或 w
---@param c number|nil w
function TalentBoard.ScrollMove(a, b, c)
    if not S.dragActive then return end
    local uiX, uiY = c and a or 0, c and b or a
    local dx, dy = uiX - S.dragX, uiY - S.dragY
    if not S.dragMoved and (dx * dx + dy * dy) > 36 then S.dragMoved = true end
    if not S.dragMoved then return end
    S.camX = S.camX - dx / S.zoom
    S.camY = S.camY - dy / S.zoom
    S.dragX, S.dragY = uiX, uiY
end

---@return boolean moved 是否真的拖动过（true 时编排层吞掉这次点击）
function TalentBoard.ScrollEnd()
    local moved = S.dragMoved
    S.dragActive, S.dragMoved = false, false
    return moved
end

---@return boolean
function TalentBoard.IsDragging()
    return S.dragActive and S.dragMoved
end

---@param id string|nil
function TalentBoard.SetSelected(id)
    S.selected = id
end

---@return string|nil
function TalentBoard.GetSelected()
    return S.selected
end

---@param deps table
function TalentBoard.Init(deps)
    D = deps
end

return TalentBoard
