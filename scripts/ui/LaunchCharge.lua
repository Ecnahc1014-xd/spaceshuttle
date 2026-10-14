-- LaunchCharge.lua
-- 基于 2D 脚手架的宿主 NanoVG 绘制回调：不自建帧/字体/资源，不参与伤害判定。
-- 圈心为实际指针设计坐标；旧二参规则调用才用玩法投影作为兼容回退。
local VisualCatalog = require "VisualCatalog"
local M = {}

local function Stroke(ctx, x, y, radius, color, alpha, width)
    if radius <= 0 or alpha <= 0 then return end
    nvgBeginPath(ctx)
    nvgCircle(ctx, x, y, radius)
    nvgStrokeColor(ctx, nvgRGBA(color[1], color[2], color[3], math.floor(alpha)))
    nvgStrokeWidth(ctx, width)
    nvgStroke(ctx)
end

-- 公开纯几何接口，供验证线性收缩与准确归零；没有最小半径兜底。
function M.Radius(progress)
    return VisualCatalog.LAUNCH_CHARGE.radius * (1 - math.max(0, math.min(1, progress or 0)))
end

---@param ctx NVGContextWrapper
---@param game table
---@param presentation table
---@param project fun(x:number,y:number):number,number
---@param colors table
function M.Draw(ctx, game, presentation, project, colors)
    if game.state ~= "playing" or (game.introTimer or 0) > 0 then return end
    local release = presentation.chargeRelease
    local active = game.chargeActive == true
    if not active and (not release or release.life <= 0) then return end
    local x, y, radius, fade, color, phase
    if active then
        -- 圆心锚定待发车权威位置；车辆中心即玩法平面 z=0 上的 (marble.x, marble.y)，
        -- 用同一玩法投影即得车辆屏幕中心。指针坐标仅作旧调用回退。
        x, y = nil, nil
        if game.chargeCarX ~= nil and game.chargeCarY ~= nil then
            x, y = project(game.chargeCarX, game.chargeCarY)
        end
        if x == nil or y == nil then x, y = game.chargeUiX, game.chargeUiY end
        if x == nil or y == nil then x, y = project(game.chargeX, game.chargeY) end
        radius = M.Radius(game.chargeProgress)
        fade, color, phase = 1, colors.cyan, game.elapsed or 0
    else
        x, y = nil, nil
        if release.carX ~= nil and release.carY ~= nil then
            x, y = project(release.carX, release.carY)
        end
        if x == nil or y == nil then x, y = release.uiX, release.uiY end
        if x == nil or y == nil then x, y = project(release.x, release.y) end
        local t = math.max(0, math.min(1, 1 - release.life / release.maxLife))
        radius = M.Radius(release.progress) + t * 24
        fade = (1 - t) ^ 2
        color, phase = release.boosted and colors.warn or colors.cyan, 0
    end
    if radius <= 0 then return end
    nvgSave(ctx)
    -- 局部细环而非不透明遮罩；底舱/HUD 保持可读，圈心本身不被移动。
    nvgIntersectScissor(ctx, 0, 92, 540, 774)
    Stroke(ctx, x, y, radius, color, 40 * fade, 10)
    Stroke(ctx, x, y, radius, color, 225 * fade, 2.4)
    Stroke(ctx, x, y, radius, colors.text, 180 * fade, 0.8)
    -- 仪器刻度沿同一半径收拢，全部合成一个路径，不逐刻度提交。
    if radius > 10 then
        nvgBeginPath(ctx)
        for i = 1, 24 do
            local a = i * math.pi / 12 + phase * 0.24
            local c, s = math.cos(a), math.sin(a)
            local len = math.min(radius * 0.15, i % 3 == 0 and 11 or 5)
            nvgMoveTo(ctx, x + c * (radius - len), y + s * (radius - len))
            nvgLineTo(ctx, x + c * radius, y + s * radius)
        end
        nvgStrokeColor(ctx, nvgRGBA(color[1], color[2], color[3], math.floor(170 * fade)))
        nvgStrokeWidth(ctx, 1.2)
        nvgStroke(ctx)
    end
    nvgRestore(ctx)
end
return M
