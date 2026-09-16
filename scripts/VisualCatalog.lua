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

-- v0.10.9 敌机太空战机化：像素原色只作为“部件槽位”识别依据，
-- 具体颜色由各机型统一配色表给出，让四类敌人远看就能区分。
-- 槽位：hullMain 主装甲 / hullDark 暗装甲与翼面 / canopy 座舱玻璃 / engine 引擎与翼尖灯。
local AIRCRAFT_PALETTES = {
    -- scout 侦察机：青蓝（高频、灵巧）
    scout = {
        hullMain = {108, 198, 232}, hullDark = { 64, 122, 162},
        canopy   = {176, 242, 255}, engine   = {126, 228, 255},
    },
    -- striker 强袭机：红橙（直冲、压迫）
    striker = {
        hullMain = {230,  96,  62}, hullDark = {120, 40,  36},
        canopy   = {255, 228, 154}, engine   = {255, 168,  66},
    },
    -- bomber 重型飞碟：黄绿（缓慢、厚重）
    bomber = {
        hullMain = {172, 196,  80}, hullDark = { 84,  96,  42},
        canopy   = {196, 255, 216}, engine   = {255, 208,  88},
    },
    -- interceptor 截击机/Boss：品紫（高速、精英）
    interceptor = {
        hullMain = {180,  94, 226}, hullDark = { 86,  44, 122},
        canopy   = {234, 186, 255}, engine   = {255, 120, 222},
    },
    -- v0.10.20 新四型，色相与前四型拉开，远看即可分辨。
    -- dart 飞镖：金黄（最快、俯冲）
    dart = {
        hullMain = {240, 202,  74}, hullDark = {150, 112,  30},
        canopy   = {255, 246, 200}, engine   = {255, 170,  60},
    },
    -- manta 宽翼鳐鱼：翡翠绿（滑翔、宽扁）
    manta = {
        hullMain = { 72, 210, 170}, hullDark = { 30, 110,  92},
        canopy   = {190, 255, 235}, engine   = {120, 255, 210},
    },
    -- hive 蜂群小机：警示橙（小、成群）
    hive = {
        hullMain = {244, 146,  52}, hullDark = {150,  66,  30},
        canopy   = {255, 222, 150}, engine   = {255,  96,  54},
    },
    -- cruiser 重装巡洋舰：钢银灰（厚重、缓压）
    cruiser = {
        hullMain = {176, 192, 208}, hullDark = { 88, 100, 116},
        canopy   = {170, 226, 255}, engine   = {120, 200, 255},
    },
}

-- 按像素原色归类部件槽位（阈值按 AircraftPixelData 实际像素标定）：
-- 座舱玻璃是高亮蓝（如 70,120,160，b-r≈90），必须与灰蓝装甲（b-r≈30）区分；
-- 引擎/翼尖灯是低亮度深色（如 110,46,40）；红棕(r 明显大于 b)是主装甲；其余灰蓝为暗装甲。
local function ClassifySlot(r, g, b)
    local luminance = (r + g + b) / 3
    if b - r >= 55 and g >= 100 then return "canopy" end
    if luminance < 80 then return "engine" end
    if r - b >= 18 then return "hullMain" end
    return "hullDark"
end

local function BuildAircraftStyle(aircraftKey)
    local data = AircraftData[aircraftKey]
    if not data then return nil end
    local palette = AIRCRAFT_PALETTES[aircraftKey] or AIRCRAFT_PALETTES.scout

    local style = {}
    for entry in (data.data .. ";"):gmatch("(.-);") do
        local col, row, r, g, b = entry:match("(%d+),(%d+),(%d+),(%d+),(%d+)")
        if col then
            local slot = ClassifySlot(tonumber(r), tonumber(g), tonumber(b))
            local c = palette[slot] or palette.hullMain
            local rv, gv, bv = c[1], c[2], c[3]
            style[col .. ":" .. row] = {
                r = rv, g = gv, b = bv,
                slot = slot,
                -- 背面/暗面色：整体压暗，保持机型色相。
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

-- v0.10.31：HUD 下一波小图。返回上色 occupied cells，渲染层只画不重算槽位。
---@class AircraftPreviewCell
---@field col integer
---@field row integer
---@field r integer
---@field g integer
---@field b integer

---@class AircraftPreview
---@field gridW number
---@field gridH number
---@field cells AircraftPreviewCell[]

---@param aircraftKey string
---@return AircraftPreview|nil
function VisualCatalog.GetAircraftPreview(aircraftKey)
    local data = AircraftData[aircraftKey]
    if not data then return nil end
    local styleMap = aircraftStyles[aircraftKey] or BuildAircraftStyle(aircraftKey)
    if not styleMap then return nil end
    ---@type AircraftPreviewCell[]
    local cells = {}
    for entry in (data.data .. ";"):gmatch("(.-);") do
        local colS, rowS = entry:match("(%d+),(%d+),%d+,%d+,%d+")
        if colS then
            ---@type integer
            local col = math.floor(tonumber(colS) or 0)
            ---@type integer
            local row = math.floor(tonumber(rowS) or 0)
            local style = styleMap[colS .. ":" .. rowS]
            if style then
                cells[#cells + 1] = {
                    col = col, row = row,
                    r = style.r, g = style.g, b = style.b,
                }
            end
        end
    end
    ---@type AircraftPreview
    local preview = { gridW = data.gridW, gridH = data.gridH, cells = cells }
    return preview
end

-- v0.10.25：体素物理调色板槽位。手建体积占用 1-64（8 机型 × 4 槽 × 冻结/正常）。
-- 渲染层按 (aircraftKey, slot, frozen) 取全局索引，禁止在 Renderer3D 里再发明一套编号。
local AIRCRAFT_KEYS = {
    "scout", "striker", "bomber", "interceptor",
    "dart", "manta", "hive", "cruiser",
}
---@type table<string, integer>
local SLOT_INDEX = { hullMain = 0, hullDark = 1, canopy = 2, engine = 3 }
---@type integer
local VOXEL_MAT_BASE = 1
---@type integer
local VOXEL_MAT_FREEZE_BASE = 33

function VisualCatalog.GetAircraftKeys()
    return AIRCRAFT_KEYS
end

function VisualCatalog.GetAircraftPalette(aircraftKey)
    return AIRCRAFT_PALETTES[aircraftKey] or AIRCRAFT_PALETTES.scout
end

---@param aircraftKey string
---@param slot string
---@param frozen boolean|nil
---@return integer
function VisualCatalog.GetVoxelMatIndex(aircraftKey, slot, frozen)
    ---@type integer
    local keyIndex = 1
    for i = 1, #AIRCRAFT_KEYS do
        if AIRCRAFT_KEYS[i] == aircraftKey then
            keyIndex = i
            break
        end
    end
    ---@type integer
    local slotIndex = SLOT_INDEX[slot] or 0
    ---@type integer
    local base = frozen and VOXEL_MAT_FREEZE_BASE or VOXEL_MAT_BASE
    return base + (keyIndex - 1) * 4 + slotIndex
end

return VisualCatalog
