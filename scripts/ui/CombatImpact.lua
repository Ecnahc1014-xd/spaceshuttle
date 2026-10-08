-- CombatImpact.lua
-- 复用宿主 NanoVG 帧的局部冲击绘制；不创建上下文、字体、贴图或场景。
-- 世界模式使用宿主投影；模态模式只在空白带显示紧凑回声，不冒充真实伤害范围。
local VisualCatalog = require "VisualCatalog"
local CombatImpact = {}

local function StrokeEllipse(ctx, x, y, rx, ry, color, alpha, width)
    nvgBeginPath(ctx)
    nvgEllipse(ctx, x, y, rx, ry)
    nvgStrokeColor(ctx, nvgRGBA(color[1], color[2], color[3], alpha))
    nvgStrokeWidth(ctx, width)
    nvgStroke(ctx)
end

---@param ctx NVGContextWrapper
---@param impact CombatImpact
local function DrawBurst(ctx, impact, cx, cy, rx, ry)
    local style = VisualCatalog.GetCombatImpactStyle(impact.kind)
    if not style or rx <= 0 or ry <= 0 then return end
    local progress = math.max(0, math.min(1, 1 - impact.life / impact.maxLife))
    local fade = (1 - progress) ^ 1.6
    local expansion = 0.18 + 0.82 * (1 - (1 - progress) ^ 3)
    local color = style.color
    local alpha = math.floor(220 * fade)

    -- 柔光只占冲击局部，不启用 HDR，不遮断中央战场。
    nvgSave(ctx)
    nvgTranslate(ctx, cx, cy)
    nvgScale(ctx, rx, ry)
    nvgBeginPath(ctx)
    nvgCircle(ctx, 0, 0, 1.12)
    nvgFillPaint(ctx, nvgRadialGradient(ctx, 0, 0, 0.06, 1.12,
        nvgRGBA(color[1], color[2], color[3], math.floor(60 * fade)),
        nvgRGBA(color[1], color[2], color[3], 0)))
    nvgFill(ctx)
    nvgRestore(ctx)

    local flash = math.max(0, 1 - progress / 0.24)
    if flash > 0 then
        nvgBeginPath(ctx)
        nvgEllipse(ctx, cx, cy, rx * (0.12 + progress), ry * (0.12 + progress))
        nvgFillColor(ctx, nvgRGBA(240, 248, 252, math.floor(155 * flash)))
        nvgFill(ctx)
    end
    StrokeEllipse(ctx, cx, cy, rx * expansion, ry * expansion, color, alpha, 3.2)
    StrokeEllipse(ctx, cx, cy, rx * expansion * 0.83, ry * expansion * 0.83,
        {240, 248, 252}, math.floor(alpha * 0.82), 1.3)

    -- 固定数量的短光刺一次批量提交；朝向仅由事件身份派生，不在每帧掷随机。
    nvgBeginPath(ctx)
    for i = 1, style.rays do
        local angle = impact.phase + i * math.pi * 2 / style.rays
        local ux, uy = math.cos(angle), math.sin(angle)
        local reach = expansion * (i % 2 == 0 and 1.13 or 0.96)
        local inner = math.max(0.15, reach - 0.24 * (1 - progress))
        nvgMoveTo(ctx, cx + ux * rx * inner, cy + uy * ry * inner)
        nvgLineTo(ctx, cx + ux * rx * reach, cy + uy * ry * reach)
    end
    nvgStrokeColor(ctx, nvgRGBA(240, 248, 252, math.floor(alpha * 0.9)))
    nvgStrokeWidth(ctx, 1.7)
    nvgStroke(ctx)

    if impact.kind == "clear" then
        -- 整机消灭的离散碎光，与技能的连续紫环区分；不产生额外 3D 碎块节点。
        nvgBeginPath(ctx)
        for i = 1, 8 do
            local angle = impact.phase + i * math.pi / 4
            local reach = 0.24 + progress * 0.95
            local size = 2.0 + 2.0 * (1 - progress)
            local x = cx + math.cos(angle) * rx * reach
            local y = cy + math.sin(angle) * ry * reach
            nvgRect(ctx, x - size * 0.5, y - size * 0.5, size, size)
        end
        nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], alpha))
        nvgFill(ctx)
    end
end

---@param ctx NVGContextWrapper
---@param presentation table
---@param project fun(x:number, y:number):number,number
---@param echoY number|nil 模态空白带中心；nil 为真实世界投影
---@return integer drawn 实际提交的冲击数量
function CombatImpact.Draw(ctx, presentation, project, echoY)
    local impacts = presentation.combatImpacts or {}
    if #impacts == 0 then return 0 end
    nvgSave(ctx)
    if echoY then
        nvgIntersectScissor(ctx, 24, echoY - 27, 492, 54)
    else
        nvgIntersectScissor(ctx, 0, 92, 540, 774)
    end
    local first = echoY and math.max(1, #impacts - 2) or 1
    local count = #impacts - first + 1
    local drawn = 0
    for i = first, #impacts do
        local impact = impacts[i] --[[@as CombatImpact]]
        if impact.life > 0 and impact.maxLife > 0 then
            local cx, cy, rx, ry
            if echoY then
                cx, cy = 270 + (i - first - (count - 1) * 0.5) * 68, echoY
                rx, ry = 25, 16
            else
                cx, cy = project(impact.x, impact.y)
                local edgeX = project(impact.x + impact.radiusX, impact.y)
                local _, edgeY = project(impact.x, impact.y + impact.radiusY)
                local style = VisualCatalog.GetCombatImpactStyle(impact.kind)
                rx = math.abs(edgeX - cx) * style.expand
                ry = math.abs(edgeY - cy) * style.expand
            end
            DrawBurst(ctx, impact, cx, cy, rx, ry)
            drawn = drawn + 1
        end
    end
    nvgRestore(ctx)
    return drawn
end

return CombatImpact
