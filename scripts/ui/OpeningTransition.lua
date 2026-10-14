-- OpeningTransition.lua
-- 沿用 2D 脚手架的 NanoVGRender 宿主：只借 ctx/字体/原语，阶段与计时只读规则快照。
local M = {}
local D = {}

function M.Init(deps)
    D = deps
end

function M.IsSelecting(game)
    return game.openingSelection and game.openingPhase == "select"
end

function M.CanPick(game)
    return M.IsSelecting(game) and (game.openingTimer or 0) <= 0
end

local function Vehicle(ctx, key, x, y, role, arrived)
    local C = D.C
    local color = key and D.colors[key] or C.dim
    local name = key and ((D.names[key] or "") .. "车") or "待选择"
    D.panel(ctx, x, y, 186, 116, C.card, color, 6)
    D.text(ctx, x + 14, y + 12, role, 16, color)
    if key then D.icon(ctx, "ammo_" .. key, x + 16, y + 46, 38) end
    D.text(ctx, x + 112, y + 52, name, 21, C.text, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    D.text(ctx, x + 112, y + 84, arrived and "已就位" or "下一步选择", 15,
        arrived and C.cyan or C.dim, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
end

-- 选卡页的流程轨始终有信息：首发与备弹分开，不占卡片/广告原命中区域。
function M.DrawSteps(ctx, game)
    local C = D.C
    local first, second = game.openingFirstVehicle, game.openingSecondVehicle
    for i = 1, 2 do
        local x = i == 1 and 56 or 292
        local key = i == 1 and first or second
        local current = game.openingRound == i
        local color = key and C.cyan or (current and C.warn or C.dim)
        D.panel(ctx, x, 218, 192, 58, C.card, color, 5)
        D.text(ctx, x + 12, 226, i == 1 and "首发" or "备弹", 15, color)
        D.text(ctx, x + 96, 248, key and ((D.names[key] or "") .. "车")
            or (current and "正在选择" or "稍后选择"), 17, C.text,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
    D.text(ctx, 270, 235, "›", 22, C.dim, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
end

function M.Draw(ctx, game)
    if game.state ~= "levelup" or not game.openingSelection or M.IsSelecting(game) then return end
    local C = D.C
    local phase = game.openingPhase
    local total = math.max(0.001, game.openingPhaseTotal or 1)
    local p = math.max(0, math.min(1, 1 - (game.openingTimer or 0) / total))
    local enter = math.min(1, p / 0.18)
    local leave = math.min(1, (1 - p) / 0.14)
    local ease = 1 - (1 - enter) ^ 3
    local alpha = math.min(enter, leave)
    local title = phase == "briefing" and "两辆车，一起出战"
        or (phase == "between" and "首发已就位" or "出战阵容已就绪")
    local hint = phase == "briefing" and "先选首发，再选一辆备弹"
        or (phase == "between" and "再选一辆不同车型作为备弹" or "接下来准备发射")
    nvgSave(ctx)
    -- 遮罩不随内容缩放，始终遮断玩法；不创建新的 NanoVG 帧或上下文。
    D.backdrop(ctx, 0, 92, 540, 868)
    nvgGlobalAlpha(ctx, alpha)
    nvgTranslate(ctx, 270, 466)
    nvgScale(ctx, 0.94 + 0.06 * ease, 0.94 + 0.06 * ease)
    nvgTranslate(ctx, -270, -466 + 18 * (1 - ease))
    D.panel(ctx, 36, 288, 468, 356, C.panel, C.cyanDim, 8)
    D.text(ctx, 270, 316, string.format("第 %d 关 · 出战准备", game.stage or 1), 18,
        C.cyan, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    D.text(ctx, 270, 354, title, 28, C.text, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    D.text(ctx, 270, 397, hint, 18, C.dim, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    local slide = 22 * (1 - ease)
    Vehicle(ctx, game.openingFirstVehicle, 66 - slide, 448, "01 · 首发车辆",
        game.openingFirstVehicle ~= nil)
    Vehicle(ctx, game.openingSecondVehicle, 288 + slide, 448, "02 · 备弹车辆",
        game.openingSecondVehicle ~= nil)
    D.rect(ctx, 66, 594, 408, 4, C.rail, 2)
    D.rect(ctx, 66, 594, 408 * p, 4, phase == "ready" and C.warn or C.cyan, 2)
    -- 同色刻度合批，既有金属/纹路来自宿主 panel，不再叠全窗点阵。
    nvgBeginPath(ctx)
    for i = 0, 16 do
        local x = 66 + i * 25.5
        nvgMoveTo(ctx, x, 608)
        nvgLineTo(ctx, x, 608 + (i % 4 == 0 and 8 or 4))
    end
    nvgStrokeColor(ctx, nvgRGBA(C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 140))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
    nvgRestore(ctx)
end

return M
