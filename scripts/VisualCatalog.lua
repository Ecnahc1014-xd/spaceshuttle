-- VisualCatalog.lua
-- 当前 2D 表现层的视觉定义。核心玩法只能使用类型键，不依赖这里的颜色或绘制参数。

local AircraftData = require "AircraftPixelData"

local VisualCatalog = {}

-- 蓄力圈：设计空间匀速归零，不随世界透视/震屏移动；参数是表现层拟值。
VisualCatalog.LAUNCH_CHARGE = { radius = 240, releaseSeconds = 0.22 }
-- 满蓄全息爆发：两层真实车型残像，参数为表现层拟值，不改变发射强化。
-- shell*：爆发后套在车上、比车略大的极浅全息外套，跟随车辆实际显示变换。
VisualCatalog.CHARGE_HOLOGRAM = { seconds = 0.65, copies = 2, spread = 0.65,
    shellScale = 1.06, shellAlpha = 0.40 }

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

---@class BrickVisualStyle
---@field r integer
---@field g integer
---@field b integer
---@field slot string
---@field dr integer
---@field dg integer
---@field db integer

---@type table<string, table<string, BrickVisualStyle>>
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
    elite_hook = {hullMain={174,202,116}, hullDark={62,82,48}, canopy={232,250,183}, engine={255,95,64}},
    elite_fork = {hullMain={90,136,225}, hullDark={34,53,115}, canopy={205,230,255}, engine={255,90,190}},
    elite_razor = {hullMain={229,226,203}, hullDark={110,111,98}, canopy={85,240,247}, engine={255,163,70}},
    elite_spiral = {hullMain={169,109,224}, hullDark={69,40,110}, canopy={246,205,255}, engine={114,238,245}},
    elite_anchor = {hullMain={203,131,88}, hullDark={98,53,43}, canopy={181,230,255}, engine={255,91,83}},
    elite_wisp = {hullMain={102,183,190}, hullDark={40,89,110}, canopy={218,255,250}, engine={212,111,255}},
    elite_shear = {hullMain={141,223,115}, hullDark={52,105,69}, canopy={235,255,197}, engine={252,119,123}},
    elite_bracket = {hullMain={125,143,213}, hullDark={48,59,115}, canopy={215,232,255}, engine={241,190,101}},
    elite_hammer = {hullMain={207,183,108}, hullDark={95,77,42}, canopy={255,239,188}, engine={117,204,255}},
    elite_rivet = {hullMain={210,103,133}, hullDark={104,43,71}, canopy={255,202,215}, engine={255,202,87}},
    boss_orrery = {hullMain={142,201,186}, hullDark={49,90,99}, canopy={224,255,234}, engine={255,207,116}},
    boss_maw = {hullMain={220,86,91}, hullDark={94,32,50}, canopy={255,177,144}, engine={246,203,89}},
    boss_citadel = {hullMain={180,178,146}, hullDark={76,81,76}, canopy={210,248,229}, engine={250,125,100}},
    boss_prism = {hullMain={192,148,239}, hullDark={76,54,116}, canopy={244,224,255}, engine={122,235,248}},
    boss_serpent = {hullMain={105,194,91}, hullDark={43,103,62}, canopy={235,244,140}, engine={255,150,83}},
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
            ---@type integer
            local rv = math.floor(tonumber(c[1]) or 255)
            ---@type integer
            local gv = math.floor(tonumber(c[2]) or 255)
            ---@type integer
            local bv = math.floor(tonumber(c[3]) or 255)
            ---@type BrickVisualStyle
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

---@type table<string, AircraftPreview>
local aircraftPreviews = {}

---@param aircraftKey string
---@return AircraftPreview|nil
function VisualCatalog.GetAircraftPreview(aircraftKey)
    -- 机型像素网格与配色是静态目录：战斗每帧都会画同一预告，缓存解析后的只读 cells。
    local cached = aircraftPreviews[aircraftKey]
    if cached then return cached end
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
                ---@type AircraftPreviewCell
                local cell = {
                    col = col,
                    row = row,
                    r = style.r,
                    g = style.g,
                    b = style.b,
                }
                cells[#cells + 1] = cell
            end
        end
    end
    ---@type AircraftPreview
    local preview = { gridW = data.gridW, gridH = data.gridH, cells = cells }
    aircraftPreviews[aircraftKey] = preview
    return preview
end

-- 每种机型四种部件色，各有正常／冰冻两组。23 型共 184 槽，bank 0 的 1..255 内互不重叠。
local AIRCRAFT_KEYS = {
    "scout", "striker", "bomber", "interceptor", "dart", "manta", "hive", "cruiser",
    "elite_hook", "elite_fork", "elite_razor", "elite_spiral", "elite_anchor",
    "elite_wisp", "elite_shear", "elite_bracket", "elite_hammer", "elite_rivet",
    "boss_orrery", "boss_maw", "boss_citadel", "boss_prism", "boss_serpent",
}
local AIRCRAFT_INDEX = {}
for index, key in ipairs(AIRCRAFT_KEYS) do AIRCRAFT_INDEX[key] = index end
---@type table<string, integer>
local SLOT_INDEX = { hullMain = 0, hullDark = 1, canopy = 2, engine = 3 }

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
    local keyIndex = AIRCRAFT_INDEX[aircraftKey] or 1
    local slotIndex = SLOT_INDEX[slot] or 0
    return 1 + (keyIndex - 1) * 8 + (frozen and 4 or 0) + slotIndex
end

-- 战斗冲击参数单一来源：技能紫色沿用巨型车，整机击毁使用品牌青与白芯。
local COMBAT_IMPACT_STYLES = {
    area = { life = 0.48, shake = 0.22, color = BALL_STYLES.giant.color,
        rays = 10, expand = 1.0 },
    clear = { life = 0.62, shake = 0.18, color = {0, 229, 208},
        rays = 12, expand = 1.18 },
}

function VisualCatalog.GetCombatImpactStyle(kind)
    return COMBAT_IMPACT_STYLES[kind]
end

function VisualCatalog.GetCombatImpactBudget()
    return 8
end

return VisualCatalog
