local M = {}
local TAU = math.pi * 2
local function gear(ctx, cx, cy, r, teeth, rot, rgb, alpha)
    if r < 2 then return end
    local root = r * 0.72
    local step = TAU / teeth
    local a = alpha or 96
    nvgBeginPath(ctx)
    for i = 0, teeth - 1 do
        local p = rot + i * step
        nvgLineTo(ctx, cx + math.cos(p) * root, cy + math.sin(p) * root)
        nvgLineTo(ctx, cx + math.cos(p + step * 0.24) * r, cy + math.sin(p + step * 0.24) * r)
        nvgLineTo(ctx, cx + math.cos(p + step * 0.76) * r, cy + math.sin(p + step * 0.76) * r)
        nvgLineTo(ctx, cx + math.cos(p + step) * root, cy + math.sin(p + step) * root)
    end
    nvgClosePath(ctx)
    nvgFillColor(ctx, nvgRGBA(rgb[1], rgb[2], rgb[3], math.floor(a * 0.55)))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(rgb[1], rgb[2], rgb[3], a))
    nvgStrokeWidth(ctx, math.max(1.5, r * 0.07))
    nvgStroke(ctx)
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, r * 0.62)
    nvgStrokeColor(ctx, nvgRGBA(220, 250, 255, math.floor(a * 0.8)))
    nvgStrokeWidth(ctx, math.max(1.2, r * 0.06))
    nvgStroke(ctx)
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, math.max(2, r * 0.2))
    nvgFillColor(ctx, nvgRGBA(2, 8, 15, math.floor(a * 0.9)))
    nvgFill(ctx)
end
local function cluster(ctx, cx, cy, r, t, seed, a1, a2, rgb, dim, alpha)
    local r1 = r * 0.62
    local r2 = r * 0.42
    local rot = t * 0.3
    gear(ctx, cx + math.cos(a1) * (r + r1 * 0.8), cy + math.sin(a1) * (r + r1 * 0.8), r1, 8, -rot, dim, alpha * 0.8)
    gear(ctx, cx + math.cos(a2) * (r + r2 * 0.8), cy + math.sin(a2) * (r + r2 * 0.8), r2, 9, -rot, dim, alpha * 0.7)
    gear(ctx, cx, cy, r, 12 + (seed % 3) * 2, rot, rgb, alpha)
end
function M.Corners(ctx, w, t, x, y)
    cluster(ctx, 0, 960, 17, t, 1, 1.6 * math.pi, 1.9 * math.pi, x, y, 60)
    cluster(ctx, w, 960, 20, t, 2, 1.4 * math.pi, 1.1 * math.pi, y, x, 58)
    cluster(ctx, 0, 0, 16, t, 3, 0.1 * math.pi, 0.4 * math.pi, y, x, 56)
    cluster(ctx, w, 0, 19, t, 4, 0.9 * math.pi, 0.6 * math.pi, x, y, 62)
end
function M.EdgePair(ctx, w, t, x, y)
    cluster(ctx, w * 0.5, 0, 13, t, 8, 0.35 * math.pi, 0.65 * math.pi, y, x, 54)
    cluster(ctx, w * 0.5, 960, 14, t, 9, 1.35 * math.pi, 1.65 * math.pi, x, y, 56)
end
function M.BattleCorners(ctx, w, t, x, y)
    cluster(ctx, 0, 960, 17, t, 10, 1.6 * math.pi, 1.9 * math.pi, x, y, 58)
    cluster(ctx, w, 960, 20, t, 11, 1.4 * math.pi, 1.1 * math.pi, y, x, 56)
end
function M.TopBandPair(ctx, w, t, x, y)
    cluster(ctx, 0, 140, 14, t, 14, 0.1 * math.pi, 0.4 * math.pi, x, y, 52)
    cluster(ctx, w, 140, 15, t, 15, 0.9 * math.pi, 0.6 * math.pi, y, x, 50)
end
function M.HudSides(ctx, w, t, x, y)
    cluster(ctx, 0, 330, 18, t, 16, 0.15 * math.pi, -0.15 * math.pi, x, y, 72)
    cluster(ctx, w, 640, 20, t, 17, 0.85 * math.pi, 1.15 * math.pi, y, x, 68)
end
function M.MenuCenterBottom(ctx, w, t, x, y)
    cluster(ctx, w * 0.25, 960, 18, t, 12, 1.35 * math.pi, 1.65 * math.pi, x, y, 96)
    cluster(ctx, w * 0.75, 960, 20, t, 13, 1.35 * math.pi, 1.65 * math.pi, y, x, 92)
end
function M.MenuCorners(ctx, w, t, x, y)
    cluster(ctx, 0, 960, 17, t, 5, 1.6 * math.pi, 1.9 * math.pi, x, y, 60)
    cluster(ctx, w, 960, 20, t, 6, 1.4 * math.pi, 1.1 * math.pi, y, x, 58)
    cluster(ctx, w, 0, 18, t, 7, 0.9 * math.pi, 0.6 * math.pi, x, y, 62)
end
return M
