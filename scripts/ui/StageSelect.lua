-- ui/StageSelect.lua
-- 选关界面（NanoVG）。v0.13.4：关卡式玩法的入口——主菜单点「开始战斗」打开本面板，
-- 玩家从已解锁的关卡里手动挑一关进入，而不是自动从第 1 关或下一关开局。
--
-- ⚠️ UI 无污染：沿用游戏 dark-tech 令牌与 NanoVG 原语（依赖注入，不引入控件树）。
-- ⚠️ 本模块只画与命中；开某关 / 解锁判定由编排层（client_main.lua）执行，
--    星级数据从 metaState.stageStars / metaState.maxStage 读取。

local StageCatalog = require "StageCatalog"

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
-- 布局（纯几何，绘制与命中共用，禁止两套常量）
-- ============================================================================

---@class StageSelectLayout
---@field content table
---@field close table
---@field grid table[] 每关一个格子，index = 关卡号
---@field perRow integer

---@param w number
---@return StageSelectLayout
local function GetLayout(w)
    local x, y = 18, 108
    local sw, sh = w - 36, 780
    local content = { x = x + 14, y = y + 60, w = sw - 28, h = sh - 76 }
    local close = { x = x + sw - 46, y = y + 8, w = 36, h = 36 }
    local perRow = 5
    local gap = 10
    local cellW = math.floor((content.w - gap * (perRow - 1)) / perRow)
    local cellH = 84
    local gridTop = content.y + 22
    ---@type table[]
    local grid = {}
    for stage = 1, StageCatalog.STAGE_COUNT do
        local idx = stage - 1
        local col = idx % perRow
        local row = math.floor(idx / perRow)
        grid[stage] = {
            x = content.x + col * (cellW + gap),
            y = gridTop + row * (cellH + gap),
            w = cellW,
            h = cellH,
        }
    end
    return { content = content, close = close, grid = grid, perRow = perRow }
end

-- 三颗星的实心/空心：已得星填 warn 金，未得星只画描边位。返回格子内星条的起始 x。
---@param ctx any
---@param cx number 星条中心 x
---@param cy number
---@param filled integer 0..3
local function DrawStars(ctx, cx, cy, filled)
    local C = Style()
    local starGap = 16
    local totalW = (3 - 1) * starGap
    local startX = cx - totalW * 0.5
    for i = 1, 3 do
        local sx = startX + (i - 1) * starGap
        local on = i <= filled
        D.rect(ctx, sx - 6, cy - 6, 12, 12, on and C.warn or C.widget, 2)
        if on then
            D.rect(ctx, sx - 4, cy - 4, 8, 8, C.ink, 1)
        end
    end
end

-- ============================================================================
-- 绘制
-- ============================================================================

---@param ctx any
---@param w number
---@param meta table 需含 stageStars / maxStage / stageTotal
function StageSelect.Draw(ctx, w, meta)
    local C = Style()
    local L = GetLayout(w)
    D.backdrop(ctx, 0, 0, w, 960)
    D.shell(ctx, 18, 108, w - 36, 780, 48)
    D.rect(ctx, 18, 156, 3, 22, C.cyan, 0)
    D.text(ctx, 34, 118, "选择关卡", 22, C.text)
    local totalStars = 0
    for stage = 1, StageCatalog.STAGE_COUNT do
        totalStars = totalStars + ((meta.stageStars and meta.stageStars[stage]) or 0)
    end
    D.text(ctx, L.content.x + L.content.w - 44, 122,
        string.format("★ %d / %d", totalStars, StageCatalog.STAGE_COUNT * 3), 15, C.warn,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)

    -- 关闭按钮
    D.panel(ctx, L.close.x, L.close.y, L.close.w, L.close.h, C.card, C.cyanDim, 6)
    D.text(ctx, L.close.x + L.close.w * 0.5, L.close.y + 7, "X", 20, C.dim,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    for stage = 1, StageCatalog.STAGE_COUNT do
        local r = L.grid[stage]
        local unlocked = stage <= (meta.maxStage or 1)
        local stars = (meta.stageStars and meta.stageStars[stage]) or 0
        local fill = unlocked and C.card or C.rail
        local border = unlocked and (stars > 0 and C.warn or C.cyanDim) or C.widget
        D.panel(ctx, r.x, r.y, r.w, r.h, fill, border, 6)
        -- 关号
        local labelColor = unlocked and C.text or C.dim
        D.text(ctx, r.x + r.w * 0.5, r.y + 10, string.format("第 %d 关", stage), 16,
            labelColor, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        if unlocked then
            DrawStars(ctx, r.x + r.w * 0.5, r.y + 56, stars)
        else
            -- 锁定：程序化锁形（锁环 + 锁体），只用 D.rect，无 stroke/外部贴图依赖。
            local cx = r.x + r.w * 0.5
            D.rect(ctx, cx - 8, r.y + 38, 16, 12, C.dim, 6)      -- 锁环外圈
            D.rect(ctx, cx - 5, r.y + 41, 10, 9, fill, 4)          -- 掏空成环
            D.rect(ctx, cx - 11, r.y + 48, 22, 16, C.widget, 3)   -- 锁体
            D.text(ctx, cx, r.y + 68, "未解锁", 12, C.dim,
                NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        end
    end
end

-- ============================================================================
-- 命中：返回 (action, index)。已解锁格子 -> "play_stage" + 关号；关闭 -> "close"。
-- ============================================================================

---@param uiX number
---@param uiY number
---@param w number
---@param meta table
---@return string|nil action
---@return integer|nil index
function StageSelect.HitTest(uiX, uiY, w, meta)
    local L = GetLayout(w)
    if Inside(L.close, uiX, uiY) then return "close", nil end
    for stage = 1, StageCatalog.STAGE_COUNT do
        if stage <= (meta.maxStage or 1) and Inside(L.grid[stage], uiX, uiY) then
            return "play_stage", stage
        end
    end
    return nil, nil
end

return StageSelect
