-- VisualCatalog.lua
-- 当前 2D 表现层的视觉定义。核心玩法只能使用类型键，不依赖这里的颜色或绘制参数。

local AircraftData = require "AircraftPixelData"

local VisualCatalog = {}

local BALL_STYLES = {
    normal = {
        displayRadius = 9,
        color = {255, 248, 220}, glow = {255, 220, 120},
        stroke = {220, 160, 50}, trail = {255, 230, 140},
    },
    speed = {
        displayRadius = 8,
        color = {255, 120, 60}, glow = {255, 80, 40},
        stroke = {200, 60, 30}, trail = {255, 140, 80},
    },
    ice = {
        displayRadius = 9,
        color = {180, 240, 255}, glow = {100, 200, 255},
        stroke = {60, 140, 200}, trail = {150, 220, 255},
    },
    giant = {
        displayRadius = 16,
        color = {200, 140, 255}, glow = {160, 80, 220},
        stroke = {120, 50, 180}, trail = {190, 130, 255},
    },
}

local aircraftStyles = {}

local function BuildAircraftStyle(aircraftKey)
    local data = AircraftData[aircraftKey]
    if not data then return nil end

    local style = {}
    for entry in (data.data .. ";"):gmatch("(.-);") do
        local col, row, r, g, b = entry:match("(%d+),(%d+),(%d+),(%d+),(%d+)")
        if col then
            local rv, gv, bv = tonumber(r), tonumber(g), tonumber(b)
            style[col .. ":" .. row] = {
                r = rv, g = gv, b = bv,
                dr = math.floor(rv * 0.55),
                dg = math.floor(gv * 0.55),
                db = math.floor(bv * 0.55),
            }
        end
    end
    aircraftStyles[aircraftKey] = style
    return style
end

function VisualCatalog.GetBallStyle(ballType)
    return BALL_STYLES[ballType]
end

function VisualCatalog.GetBrickStyle(aircraftKey, col, row)
    local style = aircraftStyles[aircraftKey] or BuildAircraftStyle(aircraftKey)
    if not style then return nil end
    return style[tostring(col) .. ":" .. tostring(row)]
end

return VisualCatalog
