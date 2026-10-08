-- CombatImpact.lua
-- 复用宿主 NanoVG 帧的局部冲击绘制；不创建上下文、字体、贴图或场景。
-- 世界模式使用宿主投影；模态模式只在空白带显示紧凑回声，不冒充真实伤害范围。
local VisualCatalog = require "VisualCatalog"
local CombatImpact = {}
local SPARK_COLORS = {{255, 209, 120}, {170, 120, 255}, {100, 233, 232}, {180, 230, 255}, {255, 128, 120}}

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
    StrokeEllipse(ctx, cx, cy, rx * expansion, ry * expansion, color, math.floor(alpha * 0.24), 9)
    StrokeEllipse(ctx, cx, cy, rx * expansion * 0.83, ry * expansion * 0.83,
        {240, 248, 252}, math.floor(alpha * 0.82), 1.3)
    -- 色边/白热核心/碎弧分层；慢一拍的断弧强调冲击传播，不加伤害或震幅。
    nvgBeginPath(ctx)
    for i = 1, 6 do
        local start = impact.phase + i * math.pi / 3 + progress * 0.22
        local sweep = impact.kind == "clear" and 0.36 or 0.66
        local rim = expansion * (impact.kind == "clear" and 1.08 or 1.03)
        for step = 0, 5 do
            local angle = start + sweep * step / 5
            local x, y = cx + math.cos(angle) * rx * rim, cy + math.sin(angle) * ry * rim
            if step == 0 then nvgMoveTo(ctx, x, y) else nvgLineTo(ctx, x, y) end
        end
    end
    nvgStrokeColor(ctx, nvgRGBA(240, 248, 252, math.floor(alpha * 0.74)))
    nvgStrokeWidth(ctx, 2.1)
    nvgStroke(ctx)

    -- 尖头动能楔与窄亮芯，长短错开；同路径合批，避免逐光刺节点。
    nvgBeginPath(ctx)
    for i = 1, style.rays do
        local angle = impact.phase + i * math.pi * 2 / style.rays
        local ux, uy = math.cos(angle), math.sin(angle)
        local reach = expansion * (i % 2 == 0 and 1.26 or 1.03)
        local inner = math.max(0.12, reach - 0.40 * (1 - progress))
        local half = (0.025 + 0.018 * (i % 2)) * (1 - progress)
        nvgMoveTo(ctx, cx + (ux * inner - uy * half) * rx, cy + (uy * inner + ux * half) * ry)
        nvgLineTo(ctx, cx + ux * rx * reach, cy + uy * ry * reach)
        nvgLineTo(ctx, cx + (ux * inner + uy * half) * rx, cy + (uy * inner - ux * half) * ry)
        nvgClosePath(ctx)
    end
    nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], math.floor(alpha * 0.78)))
    nvgFill(ctx)

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

-- 旧击碎/发射环复用原状态与TTL，只升级为两轴投影、色边与白芯。
function CombatImpact.DrawRings(ctx, presentation, project)
    local rings = presentation.shockRings or {}
    nvgSave(ctx)
    nvgIntersectScissor(ctx, 0, 92, 540, 774)
    local drawn = 0
    for i = #rings, math.max(1, #rings - 23), -1 do
        local ring = rings[i]
        if ring.life > 0 and ring.maxLife > 0 then
            local t = math.max(0, math.min(1, 1 - ring.life / ring.maxLife))
            local radius = ring.r0 + (ring.r1 - ring.r0) * t
            local x, y = project(ring.x, ring.y)
            local ex = project(ring.x + radius, ring.y)
            local _, ey = project(ring.x, ring.y + radius)
            local rx, ry = math.abs(ex - x), math.abs(ey - y)
            local a = math.floor(180 * (1 - t))
            local color = {ring.r, ring.g, ring.b}
            StrokeEllipse(ctx, x, y, rx, ry, color, math.floor(a * 0.28), 6)
            StrokeEllipse(ctx, x, y, rx, ry, color, a, 2.5)
            StrokeEllipse(ctx, x, y, rx * 0.82, ry * 0.82, {240, 248, 252}, math.floor(a * 0.78), 1)
            drawn = drawn + 1
        end
    end
    nvgRestore(ctx)
    return drawn
end

-- 高频粒子的动能亮芯：原3D软粒子不删；五色合批、24条预算、不新建视觉对象。
function CombatImpact.DrawSparks(ctx, presentation, project)
    local particles = presentation.particles or {}
    local drawn = 0
    nvgSave(ctx)
    nvgIntersectScissor(ctx, 0, 92, 540, 774)
    for group, color in ipairs(SPARK_COLORS) do
        nvgBeginPath(ctx)
        for i = #particles, math.max(1, #particles - 47), -1 do
            local p = particles[i]
            if p.kind == "spark" and p.life > 0 and p.maxLife > 0 then
                local bucket = p.b > p.r + 30 and (p.r > p.g + 20 and 2 or 4)
                    or (p.g > p.r + 35 and 3 or (p.r > p.g + 70 and 5 or 1))
                if bucket == group and drawn < 24 then
                    local life = math.max(0, math.min(1, p.life / p.maxLife))
                    local x, y = project(p.x, p.y)
                    local bx, by = project(p.x - p.vx * 0.018, p.y - p.vy * 0.018)
                    local dx, dy = x - bx, y - by
                    local length = math.sqrt(dx * dx + dy * dy)
                    if length > 0.01 and y > 92 and y < 866 and x > 0 and x < 540 then
                        local ux, uy = dx / length, dy / length
                        local reach = math.min(13, 3 + length * 2.0) * life
                        local half = math.min(1.6, p.size * 0.42) * life
                        nvgMoveTo(ctx, x + ux * 1.5, y + uy * 1.5)
                        nvgLineTo(ctx, x - ux * reach - uy * half, y - uy * reach + ux * half)
                        nvgLineTo(ctx, x - ux * reach + uy * half, y - uy * reach - ux * half)
                        nvgClosePath(ctx)
                        drawn = drawn + 1
                    end
                end
            end
        end
        nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], 195))
        nvgFill(ctx)
    end
    nvgRestore(ctx)
    return drawn
end

-- 接上已存在但未绘制的普通命中闪光；只读存活机体，不触发材质/网格重建。
function CombatImpact.DrawHits(ctx, game, presentation, project)
    local flashes = presentation.hitFlashes or {}
    local drawn = 0
    nvgSave(ctx)
    nvgIntersectScissor(ctx, 0, 92, 540, 774)
    for key, remaining in pairs(flashes) do
        if remaining > 0 and drawn < 24 then
            local id, col, row = key:match("^(%d+):(%d+):(%d+)$")
            local enemyId, c, r = tonumber(id), tonumber(col), tonumber(row)
            if enemyId and c and r then
                for _, enemy in ipairs(game.veggies or {}) do
                    if enemy.id == enemyId then
                        local x, y = project(enemy.x + (c - 0.5) * enemy.brickSize,
                            enemy.y + (r - 0.5) * enemy.brickSize)
                        local flash = math.max(0, math.min(1, remaining / 0.12))
                        local reach = 3 + 7 * flash
                        nvgBeginPath(ctx)
                        nvgMoveTo(ctx, x - reach, y); nvgLineTo(ctx, x + reach, y)
                        nvgMoveTo(ctx, x, y - reach * 0.7); nvgLineTo(ctx, x, y + reach * 0.7)
                        nvgStrokeColor(ctx, nvgRGBA(240, 248, 252, math.floor(205 * flash)))
                        nvgStrokeWidth(ctx, 0.7 + flash)
                        nvgStroke(ctx)
                        drawn = drawn + 1
                        break
                    end
                end
            end
        end
    end
    nvgRestore(ctx)
    return drawn
end

return CombatImpact
