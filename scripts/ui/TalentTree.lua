-- ui/TalentTree.lua
-- 天赋树界面（NanoVG）。v0.13.5：主菜单入口，玩家消耗零件解锁节点。
--
-- 布局：6 行（2 通用线 + 4 车线）× 7 列（阶段）。每格一个节点，点一次即满。
-- 节点状态：已解锁（青）/ 可解锁（亮框 + 价格）/ 前置或星级未达（暗）。
--
-- ⚠️ UI 无污染：沿用游戏 dark-tech 令牌与 NanoVG 原语（依赖注入）。
-- ⚠️ 本模块只画与命中；真正的解锁（扣零件 + 落盘）由编排层执行。

local TalentCatalog = require "TalentCatalog"

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

-- ============================================================================
-- 布局（纯几何，绘制与命中共用）
-- ============================================================================

---@class TalentLayout
---@field content table
---@field close table
---@field cells table[][] cells[laneIndex][stage] = rect

---@param w number
---@return TalentLayout
local function GetLayout(w)
    local x, y = 18, 108
    local sw, sh = w - 36, 780
    local content = { x = x + 14, y = y + 66, w = sw - 28, h = sh - 92 }
    local close = { x = x + sw - 46, y = y + 8, w = 36, h = 36 }
    local lanes = TalentCatalog.LANES
    local rows = #lanes
    local cols = TalentCatalog.MAX_STAGE
    local gapX, gapY = 6, 6
    local labelW = 62
    local cellW = math.floor((content.w - labelW - gapX * (cols - 1)) / cols)
    local cellH = math.floor((content.h - gapY * (rows - 1)) / rows)
    ---@type table[][]
    local cells = {}
    for li = 1, rows do
        cells[li] = {}
        for si = 1, cols do
            cells[li][si] = {
                x = content.x + labelW + (si - 1) * (cellW + gapX),
                y = content.y + (li - 1) * (cellH + gapY),
                w = cellW,
                h = cellH,
            }
        end
    end
    return { content = content, close = close, cells = cells, labelW = labelW }
end

-- 关卡星级门槛显示用：每列顶部标「N★」。
local function StageHeaderText(stage)
    local need = TalentCatalog.STAGE_STARS[stage] or 0
    if stage == 1 then return "0★" end
    return need .. "★"
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
    local lanes = TalentCatalog.LANES
    local owned = meta.talents or {}
    local stars = meta.totalStars or 0
    local parts = meta.parts or 0

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

    -- 阶段表头（列）：星级门槛
    for si = 1, TalentCatalog.MAX_STAGE do
        local r = L.cells[1][si]
        local open = stars >= (TalentCatalog.STAGE_STARS[si] or 0)
        D.text(ctx, r.x + r.w * 0.5, L.content.y - 18, StageHeaderText(si), 13,
            open and C.cyan or C.dim, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end

    for li, lane in ipairs(lanes) do
        local laneNodes = TalentCatalog.GetLaneNodes(lane)
        -- 行标签
        local rowRect = L.cells[li][1]
        D.text(ctx, L.content.x, rowRect.y + rowRect.h * 0.5 - 8,
            TalentCatalog.LANE_NAMES[lane] or lane, 13, C.dim)

        for si, node in ipairs(laneNodes) do
            local r = L.cells[li][si]
            local isOwned = owned[node.id] == true
            local prereqMet = TalentCatalog.IsPrereqMet(node, owned, stars)
            local canBuy = (not isOwned) and prereqMet and parts >= node.cost
            local fill, border
            if isOwned then
                fill, border = C.widget, C.cyan
            elseif canBuy then
                fill, border = C.card, C.warn
            elseif prereqMet then
                fill, border = C.card, C.cyanDim
            else
                fill, border = C.rail, C.widget
            end
            D.panel(ctx, r.x, r.y, r.w, r.h, fill, border, 5)
            if isOwned then D.rect(ctx, r.x, r.y, 3, r.h, C.cyan, 0) end

            -- 节点名（取短名：去掉前缀）
            local label = node.name
            local textColor = isOwned and C.text or (prereqMet and C.dim or C.dim)
            D.text(ctx, r.x + r.w * 0.5, r.y + 6, label, 12, textColor,
                NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            -- 状态/价格
            local sub, subColor
            if isOwned then
                sub, subColor = "已解锁", C.cyan
            elseif not prereqMet then
                sub, subColor = "未开放", C.dim
            elseif parts >= node.cost then
                sub, subColor = tostring(node.cost), C.warn
            else
                sub, subColor = tostring(node.cost), C.dim
            end
            D.text(ctx, r.x + r.w * 0.5, r.y + r.h - 18, sub, 12, subColor,
                NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        end
    end

    -- 底部说明
    D.text(ctx, L.content.x, L.content.y + L.content.h + 4,
        "每解锁一个节点 +1 基地生命；同线路需按阶段依次解锁", 12, C.dim)
end

-- ============================================================================
-- 命中：返回 (action, index)。节点 -> "unlock_talent" + nodeId；关闭 -> "close"。
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
    local lanes = TalentCatalog.LANES
    for li, lane in ipairs(lanes) do
        local laneNodes = TalentCatalog.GetLaneNodes(lane)
        for si, node in ipairs(laneNodes) do
            if Inside(L.cells[li][si], uiX, uiY) then
                return "unlock_talent", node.id
            end
        end
    end
    return nil, nil
end

return TalentTree
