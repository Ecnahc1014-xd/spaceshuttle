-- 附魔冲击波变体（v0.13.70）：**不使用粒子**，全部是烘焙好的几何冲击波层。
-- 原版车头 V 波（scripts/VehicleBowWave.lua）保持零改动；本模块在它外侧叠一套
-- 「多层 V 带 + 分叉箭头 + 尾迹弧 + 尖端强化 + 竖向褶皱」的复杂变体，按附魔类型变形态。
--
-- 性能：几何是**静态烘焙**，只在「附魔/稀有度/弹种/车体半宽」变化时重建一次；
-- 稳态每帧只写 node.position（前推）、node.scale（呼吸）、node.rotation（轻微侧倾）
-- 与材质 alpha 脉冲 —— 稳态顶点上传 0，每车 1 个 draw call。
-- 尺寸以原版为基准（GAP 0.20 / 纵深 0.62 / 展宽 1.90 / 厚 0.18 / 半高 0.12，局部单位），
-- 外层放大但贴图中线镂空，原波白热核仍是画面最亮的一层。
-- dt 为未乘 timeScale 的玩法时间：广告传 0（相位冻结但仍跟随车辆）。
---@class EnchantWaveMarble
---@field id number
---@field alive boolean
---@field onSling boolean|nil
---@field radius number
---@field ballType string|nil
---@field enchant {id: string|nil, rarity: string|nil}|nil
---@class EnchantWaveGame
---@field state string
---@field introTimer number|nil
---@field elapsed number|nil
---@field timeScale number|nil
---@field activeBall EnchantWaveMarble|nil
---@field marbles EnchantWaveMarble[]|nil
---@class EnchantWaveRecord
---@field root Node
---@field geometry CustomGeometry|nil
---@class EnchantWaveShape
---@field layers integer
---@field prongs integer
---@field fork number
---@field wake number
---@field ribs integer
---@field flare number
---@field rate number
---@field hue number
---@class EnchantWaveSlot
---@field node Node|nil
---@field geometry CustomGeometry|nil
---@field material Material|nil
---@field key string
---@field carId number
---@field parent Node|nil
---@class EnchantWaveState
---@field slots EnchantWaveSlot[]
---@field texture Texture2D|nil
---@field image Image|nil
---@field colors table<string, number[]>
---@field phase number
---@field lastElapsed number|nil
---@field rebuilds integer
---@field lastFrameUploads integer
---@field activeNodes integer
---@field clears integer
---@field faulted boolean
---@field lastError string
local S = {
    slots = {}, colors = {}, phase = 0, lastElapsed = nil,
    rebuilds = 0, lastFrameUploads = 0, activeNodes = 0, clears = 0,
    faulted = false, lastError = "",
} ---@type EnchantWaveState
local M = {}

local MAX_CARS, SEGMENTS, PRONG_SEGMENTS = 4, 8, 3
local TAU = 2 * math.pi

-- 原版 VehicleBowWave 的局部尺寸（只读参照）与叠加层基准倍率。
local GAP = 0.22
local V_DEPTH, V_SPREAD, THICK, HALF_H = 0.62, 1.90, 0.18, 0.12
local W_MUL, D_MUL, T_MUL, H_MUL = 1.55, 1.30, 1.90, 2.05

local RARITY = {
    common = { boost = 1.05, hue = 0 },
    rare   = { boost = 1.18, hue = -8 },
    epic   = { boost = 1.34, hue = 8 },
} ---@type table<string, table>

-- 每种附魔的复杂变体：layers=主 V 带层数 prongs=分叉箭头支数 fork=分叉间距
-- wake=尾迹弧条数 ribs=竖向褶皱条数 flare=尖端高度倍率 rate/hue 同前。
-- v0.13.79：每种附魔一套**专属几何语言**（不再共用同一套 V 带只改数量）。
-- kind     : "v" 经典 V 带 / "ring" 锁定环 / "spike" 放射尖刺 / "zigzag" 折线电弧 /
--            "crystal" 六角冰晶 / "lift" 内收回流弧 / "triple" 三平行带
-- spin     : 稳态绕车头前向轴的旋转角速度（度/秒）
-- pulse    : 稳态缩放脉冲幅度（0 = 不呼吸）
-- travel   : 前推幅度倍率（越大越"推出去"）
local SHAPES = {
    split     = { kind = "v",       layers = 3, prongs = 2, fork = 0.58, wake = 2, ribs = 3, flare = 1.05, rate = 1.15, hue = 0,
                  shards = 6, spin = 0,  pulse = 0.06, travel = 1.00 },
    lifesteal = { kind = "lift",    layers = 2, prongs = 0, fork = 0.00, wake = 1, ribs = 0, flare = 0.85, rate = 0.85, hue = 12,
                  arcs = 4, rings = 1, spin = -14, pulse = 0.05, travel = 0.55,
                  jitter = 0.6 },
    homing    = { kind = "ring",    layers = 2, prongs = 0, fork = 0.00, wake = 2, ribs = 4, flare = 1.00, rate = 1.30, hue = -10,
                  rings = 3, spin = 22, pulse = 0.04, travel = 0.85 },
    pierce    = { kind = "v",       layers = 2, prongs = 1, fork = 0.00, wake = 2, ribs = 6, flare = 1.55, rate = 1.45, hue = 4,
                  spikes = 3, spikeLen = 1.55, spin = 0, pulse = 0.03, travel = 1.25,
                  jitter = 2.2 },
    chain     = { kind = "zigzag",  layers = 2, prongs = 0, fork = 0.00, wake = 2, ribs = 5, flare = 0.95, rate = 1.10, hue = -6,
                  boltSegs = 5, boltAmp = 0.34, rings = 1, spin = 0, pulse = 0.07, travel = 1.05,
                  jitter = 5.0 },
    freeze    = { kind = "crystal", layers = 2, prongs = 0, fork = 0.00, wake = 2, ribs = 4, flare = 0.90, rate = 0.75, hue = 20,
                  crystalLen = 1.15, spokes = 6, shards = 8, spin = 9, pulse = 0.04, travel = 0.75,
                  jitter = 0.8 },
    power     = { kind = "v",       layers = 3, prongs = 0, fork = 0.00, wake = 2, ribs = 2, flare = 1.60, rate = 0.95, hue = 2,
                  rings = 2, spin = 6, pulse = 0.09, travel = 1.10 },
    explode   = { kind = "spike",   layers = 2, prongs = 0, fork = 0.00, wake = 3, ribs = 6, flare = 1.15, rate = 1.35, hue = -12,
                  spikes = 10, spikeLen = 0.95, rings = 1, spin = 34, pulse = 0.10, travel = 1.15,
                  jitter = 3.4 },
    triple    = { kind = "triple",  layers = 2, prongs = 0, fork = 0.62, wake = 2, ribs = 3, flare = 1.05, rate = 1.20, hue = 8,
                  lanes = 3, spin = 0, pulse = 0.05, travel = 1.00 },
    default   = { kind = "v",       layers = 2, prongs = 0, fork = 0.00, wake = 1, ribs = 2, flare = 0.95, rate = 1.00, hue = 0,
                  spin = 0, pulse = 0.05, travel = 1.00 },
} ---@type table<string, table>

---@param x number
---@return boolean
local function Finite(x)
    return x == x and x > -math.huge and x < math.huge
end

---@param action fun()
local function Cleanup(action)
    local ok, err = pcall(action)
    if not ok then
        S.faulted, S.lastError = true, tostring(err)
        print("[VehicleEnchantWave] cleanup failed: " .. S.lastError)
    end
end

---色相微调（只偏几度，保持与原波同色系）。
---@param rgb number[]
---@param degrees number
---@return number, number, number
local function ShiftHue(rgb, degrees)
    local r, g, b = rgb[1], rgb[2], rgb[3]
    if degrees == 0 then return r, g, b end
    local mx, mn = math.max(r, g, b), math.min(r, g, b)
    local d = mx - mn
    if mx <= 1e-6 or d <= 1e-6 then return r, g, b end
    local s = d / mx
    local h
    if mx == r then h = ((g - b) / d) % 6
    elseif mx == g then h = (b - r) / d + 2
    else h = (r - g) / d + 4 end
    h = (h / 6 + degrees / 360) % 1
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p, q, t = mx * (1 - s), mx * (1 - f * s), mx * (1 - (1 - f) * s)
    local k = i % 6
    if k == 0 then return mx, t, p
    elseif k == 1 then return q, mx, p
    elseif k == 2 then return p, mx, t
    elseif k == 3 then return p, q, mx
    elseif k == 4 then return t, p, mx end
    return mx, p, q
end

---包边贴图：白色 RGB + 上下双峰 alpha（中线镂空 → 不盖原波白热核）。
local function BakeRimTexture()
    local N = 64
    local image = Image()
    S.image = image
    assert(image:SetSize(N, N, 4), "rim Image allocation failed")
    for y = 0, N - 1 do
        local v = y / (N - 1)
        local edge = math.max(0, 1 - math.abs(v - 0.10) / 0.13)
            + math.max(0, 1 - math.abs(v - 0.90) / 0.13)
        for x = 0, N - 1 do
            local u = x / (N - 1)
            local along = 0.45 + 0.55 * (1 - math.abs(2 * u - 1))
            image:SetPixel(x, y, Color(1, 1, 1, math.max(0, math.min(1, edge * along * 0.45))))
        end
    end
    local tex = Texture2D:new()
    S.texture = tex
    tex:SetNumLevels(1)
    tex:SetFilterMode(FILTER_BILINEAR)
    tex:SetAddressMode(COORD_U, ADDRESS_CLAMP)
    tex:SetAddressMode(COORD_V, ADDRESS_CLAMP)
    assert(tex:SetData(image, false), "rim texture upload failed")
    tex:SetSRGB(true)
    image:Dispose()
    S.image = nil
end

---@param scene Scene
---@param colors table<string, number[]>|nil 弹种色表（与 VehicleBowWave 同源）
---@return boolean
function M.Init(scene, colors)
    M.Shutdown()
    S.faulted, S.lastError = false, ""
    S.colors = colors or {}
    local ok, err = pcall(function()
        local rimTech = cache:GetResource("Technique", "Techniques/DiffVColUnlitAlpha.xml")
        assert(rimTech, "DiffVColUnlitAlpha unavailable")
        BakeRimTexture()
        for i = 1, MAX_CARS do
            local slot = {} ---@type EnchantWaveSlot
            S.slots[i] = slot
            local mat = Material()
            slot.material = mat
            mat:SetTechnique(0, rimTech)
            mat:SetTexture(TU_DIFFUSE, S.texture)
            mat:SetShaderParameter("MatDiffColor", Variant(Color(1, 1, 1, 1)))
            mat:SetRenderOrder(171) -- 原版波默认 128，叠加层画在它之后。
            slot.key = ""
        end
    end)
    if not ok then
        local reason = tostring(err)
        Cleanup(M.Shutdown)
        S.faulted, S.lastError = true, reason
        print("[VehicleEnchantWave] disabled until Init: " .. reason)
        return false
    end
    print("[VehicleEnchantWave] initialized: baked shockwave variants (no particles), "
        .. MAX_CARS .. " cars")
    return true
end

---模态隐藏但保留相位；新局/Shutdown 复位。
---@param resetPhase boolean|nil
function M.Clear(resetPhase)
    for _, slot in ipairs(S.slots) do
        if slot.node then slot.node.enabled = false end
        slot.carId, slot.parent, slot.key = 0, nil, ""
    end
    S.activeNodes, S.lastFrameUploads = 0, 0
    S.clears = S.clears + 1
    if resetPhase ~= false then S.phase, S.lastElapsed = 0, nil end
end

function M.Shutdown()
    M.Clear(true)
    for _, slot in ipairs(S.slots) do
        if slot.node then
            local node = slot.node
            Cleanup(function() node:Remove() end)
            Cleanup(function() node:Dispose() end)
        end
        if slot.material then
            local mat = slot.material
            Cleanup(function() mat:Dispose() end)
        end
    end
    if S.texture then
        local tex = S.texture
        Cleanup(function() tex:Dispose() end)
    end
    if S.image then
        local image = S.image
        Cleanup(function() image:Dispose() end)
    end
    S.slots, S.texture, S.image, S.colors = {}, nil, nil, {}
    S.activeNodes, S.lastFrameUploads = 0, 0
end

---@param id number
---@return number
local function IdPhase(id)
    local hash = math.sin(id * 12.9898 + 78.233) * 43758.5453
    return (hash - math.floor(hash)) * TAU
end

---静态构建一整套冲击波变体（车头局部空间，原点在车头 GAP 处）。
---@param geometry CustomGeometry
---@param hw number 车体半宽（局部）
---@param shape EnchantWaveShape
---@param r number
---@param g number
---@param b number
local function BuildWave(geometry, hw, shape, r, g, b)
    geometry:Clear()
    geometry:SetNumGeometries(1)
    geometry:BeginGeometry(0, TRIANGLE_LIST)
    local written = 0
    ---@type Color
    local col = Color(1, 1, 1, 1)

    ---双面三角：尖刺/冰刺一律双面写，从另一侧看也不会变黑。
    ---@param a Vector3
    ---@param b Vector3
    ---@param c Vector3
    local function AddTri(a, b, c)
        local n = (b - a):CrossProduct(c - a):Normalized()
        local uvs = { Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 1) }
        for k = 1, 3 do
            written = written + 1
            geometry:DefineVertex((k == 1) and a or ((k == 2) and b or c))
            geometry:DefineNormal(n)
            geometry:DefineColor(col)
            geometry:DefineTexCoord(uvs[k])
        end
        for k = 3, 1, -1 do
            written = written + 1
            geometry:DefineVertex((k == 1) and a or ((k == 2) and b or c))
            geometry:DefineNormal(Vector3(-n.x, -n.y, -n.z))
            geometry:DefineColor(col)
            geometry:DefineTexCoord(uvs[k])
        end
    end

    ---@param p Vector3[]
    ---@param expected Vector3
    local function AddQuad(p, expected)
        local a, bb, c, d = p[1], p[2], p[3], p[4]
        if (bb - a):CrossProduct(c - a):DotProduct(expected) < 0 then
            bb, c, d = c, d, bb
        end
        local n = (bb - a):CrossProduct(c - a):Normalized()
        local uv = { Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1) }
        local order = { a, bb, c, a, c, d }
        local orderUV = { 1, 2, 3, 1, 3, 4 }
        for k = 1, 6 do
            written = written + 1
            geometry:DefineVertex(order[k])
            geometry:DefineNormal(n)
            geometry:DefineColor(col)
            geometry:DefineTexCoord(uv[orderUV[k]])
        end
    end

    ---V 形带：中央折角在最前，两翼后掠；层数/宽度/高度按 layer 递减递增。
    ---@param lateral number 横向偏移（相对半宽）
    ---@param widthMul number
    ---@param segs integer
    ---@param layer integer
    ---@param layers integer
    local function EmitV(lateral, widthMul, segs, layer, layers)
        -- 外层最宽最淡，内层最窄最亮；层与层沿前向错开形成纵深。
        local t = (layer - 1) / math.max(1, layers - 1)
        local sHalf = 1.00 - 0.42 * t
        local sDepth = 1.00 - 0.26 * t
        local bright = 0.72 + 0.62 * t
        local halfW = hw * V_SPREAD * W_MUL * widthMul * sHalf
        local depth = V_DEPTH * D_MUL * sDepth
        local thick = THICK * T_MUL * (1.00 - 0.30 * t)
        local hHalf = HALF_H * H_MUL * shape.flare * (1.00 - 0.28 * t)
        local baseX = 0.10 * t
        col = Color(math.min(1, r * bright), math.min(1, g * bright), math.min(1, b * bright), 1)
        ---@param s number
        ---@return Vector3[]
        local function Cross(s)
            local x = baseX + depth * (1 - math.abs(s))
            local y = lateral * hw + s * halfW
            return {
                Vector3(x, y, -hHalf),
                Vector3(x + thick, y, -hHalf),
                Vector3(x + thick, y, hHalf),
                Vector3(x, y, hHalf),
            }
        end
        local prev = Cross(-1)
        for i = 1, segs do
            local s = -1 + i * (2 / segs)
            local cur = Cross(s)
            AddQuad({ prev[2], cur[2], cur[3], prev[3] }, Vector3(0, 0, -1))
            AddQuad({ prev[1], prev[4], cur[4], cur[1] }, Vector3(0, 0, 1))
            AddQuad({ prev[1], cur[1], cur[2], prev[2] }, Vector3(0, 0, -1))
            AddQuad({ prev[4], prev[3], cur[3], cur[4] }, Vector3(0, 0, 1))
            prev = cur
        end
    end

    ---尾迹弧：从两翼向后（负 X）扫出的细弧带，读作被推出的气流边缘。
    ---@param sign number -1 右翼 / 1 左翼
    ---@param band integer 第几条（越外越淡）
    local function EmitWake(sign, band)
        local halfW = hw * V_SPREAD * W_MUL * (0.86 + 0.22 * band)
        local hHalf = HALF_H * H_MUL * shape.flare * (0.55 + 0.18 * band)
        local back = V_DEPTH * D_MUL * (0.55 + 0.30 * band)
        local segs = 4
        col = Color(math.min(1, r * 0.55), math.min(1, g * 0.55), math.min(1, b * 0.55), 1)
        local prev = nil
        for i = 0, segs do
            local u = i / segs
            local x = 0.16 - back * u
            local y = sign * (hw * 0.10 + (halfW - hw * 0.10) * (0.25 + 0.75 * u))
            local thick = THICK * T_MUL * 0.55
            local cur = {
                Vector3(x, y, -hHalf),
                Vector3(x + thick, y, -hHalf),
                Vector3(x + thick, y, hHalf),
                Vector3(x, y, hHalf),
            }
            if prev then
                AddQuad({ prev[2], cur[2], cur[3], prev[3] }, Vector3(0, 0, -1))
                AddQuad({ prev[1], prev[4], cur[4], cur[1] }, Vector3(0, 0, 1))
            end
            prev = cur
        end
    end

    ---竖向褶皱：在中央折角附近立几条细棱，静态几何做出"能量条纹"。
    ---@param index integer
    ---@param total integer
    local function EmitRib(index, total)
        local u = total == 1 and 0 or ((index - 1) / (total - 1) * 2 - 1)
        local halfW = hw * V_SPREAD * W_MUL * 0.72
        local y = u * halfW
        local x0 = V_DEPTH * D_MUL * (1 - math.abs(u)) * 0.55
        local hHalf = HALF_H * H_MUL * shape.flare * 0.85
        local width = THICK * T_MUL * 0.22
        col = Color(math.min(1, r * 1.25), math.min(1, g * 1.25), math.min(1, b * 1.25), 1)
        local a = Vector3(x0, y - width, -hHalf)
        local bb = Vector3(x0 + THICK * T_MUL * 0.6, y - width, -hHalf)
        local c = Vector3(x0 + THICK * T_MUL * 0.6, y + width, hHalf)
        local d = Vector3(x0, y + width, hHalf)
        AddQuad({ a, bb, c, d }, Vector3(0, 0, -1))
    end

    ---通用四边形：中心 c、沿轴 ax（已归一）长 halfLen、侧向侧轴 sx 半宽 halfSide。
    ---@param c Vector3
    ---@param ax Vector3
    ---@param sx Vector3
    ---@param halfLen number
    ---@param halfSide number
    ---@param bright number
    local function EmitFlat(c, ax, sx, halfLen, halfSide, bright)
        col = Color(math.min(1, r * bright), math.min(1, g * bright), math.min(1, b * bright), 1)
        local p1 = c - ax * halfLen - sx * halfSide
        local p2 = c + ax * halfLen - sx * halfSide
        local p3 = c + ax * halfLen + sx * halfSide
        local p4 = c - ax * halfLen + sx * halfSide
        local n = ax:CrossProduct(sx):Normalized()
        AddQuad({ p1, p2, p3, p4 }, n)
    end

    ---环带（YZ 平面，垂直于前向轴）：锁定环 / 爆发核 / 冰晶外框。
    ---@param cx number 前向位置
    ---@param rad number 半径（以半宽为基准）
    ---@param segs integer
    ---@param bright number
    ---@param thickMul number
    local function EmitRing(cx, rad, segs, bright, thickMul)
        local hHalf = HALF_H * H_MUL * shape.flare
        local ry = hw * V_SPREAD * W_MUL * rad * 0.62
        local rz = hHalf * rad
        local tw = THICK * T_MUL * (thickMul or 0.35)
        col = Color(math.min(1, r * bright), math.min(1, g * bright), math.min(1, b * bright), 1)
        local ringSegs = math.max(8, segs)
        local prev = nil
        for i = 0, ringSegs do
            local a = i / ringSegs * TAU
            local y = math.cos(a) * ry
            local z = math.sin(a) * rz
            local cur = {
                Vector3(cx, y, z - tw * 0.5),
                Vector3(cx + tw, y, z - tw * 0.5),
                Vector3(cx + tw, y, z + tw * 0.5),
                Vector3(cx, y, z + tw * 0.5),
            }
            if prev then
                AddQuad({ prev[2], cur[2], cur[3], prev[3] }, Vector3(0, 0, -1))
                AddQuad({ prev[1], prev[4], cur[4], cur[1] }, Vector3(0, 0, 1))
            end
            prev = cur
        end
    end

    ---放射尖刺：从中心向外张开的细长三角片（爆炸 / 穿刺）。
    ---@param count integer
    ---@param len number 相对半宽
    ---@param baseRad number 起点半径
    ---@param bright number
    ---@param phase number 起始角
    local function EmitSpikes(count, len, baseRad, bright, phase)
        local hHalf = HALF_H * H_MUL * shape.flare
        local ry, rz = hw * V_SPREAD * W_MUL * 0.62, hHalf
        for i = 1, count do
            local a = (phase or 0) + (i - 1) / count * TAU
            local dy, dz = math.cos(a), math.sin(a)
            local x0 = V_DEPTH * D_MUL * baseRad
            local x1 = V_DEPTH * D_MUL * (baseRad + len)
            local w1 = hw * V_SPREAD * W_MUL * 0.06
            local h1 = hHalf * 0.10
            local a1 = Vector3(x0, dy * ry * 0.25 - dz * w1, dz * rz * 0.05 + dy * h1)
            local a2 = Vector3(x0, dy * ry * 0.25 + dz * w1, dz * rz * 0.05 - dy * h1)
            local tip = Vector3(x1, dy * ry, dz * rz)
            col = Color(math.min(1, r * bright), math.min(1, g * bright), math.min(1, b * bright), 1)
            AddTri(a1, a2, tip)
        end
    end

    ---折线电弧：左右折返的细带，读作闪电。
    ---@param sign number
    ---@param segs integer
    ---@param amp number
    ---@param bright number
    local function EmitZigzag(sign, segs, amp, bright)
        local hHalf = HALF_H * H_MUL * shape.flare
        local halfW = hw * V_SPREAD * W_MUL
        local depth = V_DEPTH * D_MUL
        local tw = THICK * T_MUL * 0.55
        col = Color(math.min(1, r * bright), math.min(1, g * bright), math.min(1, b * bright), 1)
        local prev = nil
        for i = 0, segs do
            local u = i / segs
            local zig = (i % 2 == 0) and 1 or -1
            local x = depth * (1 - u) * 1.02
            local y = sign * halfW * (0.18 + 0.82 * u) + zig * amp * halfW * 0.30 * (1 - u * 0.5)
            local z = zig * hHalf * 0.55 * (1 - u * 0.4)
            local cur = {
                Vector3(x, y, z - tw * 0.5),
                Vector3(x + tw, y, z - tw * 0.5),
                Vector3(x + tw, y, z + tw * 0.5),
                Vector3(x, y, z + tw * 0.5),
            }
            if prev then
                AddQuad({ prev[2], cur[2], cur[3], prev[3] }, Vector3(0, 0, -1))
                AddQuad({ prev[1], prev[4], cur[4], cur[1] }, Vector3(0, 0, 1))
            end
            prev = cur
        end
    end

    ---内收回流弧：从外侧向后收向车头，读作「把东西吸回来」（吸血）。
    ---@param sign number
    ---@param count integer
    ---@param index integer
    local function EmitLift(sign, count, index)
        local hHalf = HALF_H * H_MUL * shape.flare
        local halfW = hw * V_SPREAD * W_MUL
        local depth = V_DEPTH * D_MUL
        local u = count <= 1 and 0.5 or (index - 1) / (count - 1)
        local tw = THICK * T_MUL * (0.30 + 0.18 * u)
        col = Color(math.min(1, r * (0.75 + 0.5 * u)), math.min(1, g * (0.75 + 0.5 * u)),
            math.min(1, b * (0.75 + 0.5 * u)), 1)
        local segs = 5
        local prev = nil
        for i = 0, segs do
            local t = i / segs
            local x = depth * (1.05 - 0.95 * t)
            local y = sign * halfW * (0.45 + 0.55 * (1 - t)) * (0.85 + 0.15 * u)
            local z = hHalf * (0.55 - 1.05 * t) * (0.6 + 0.4 * math.sin(t * math.pi))
            local cur = {
                Vector3(x, y, z - tw * 0.5),
                Vector3(x + tw, y, z - tw * 0.5),
                Vector3(x + tw, y, z + tw * 0.5),
                Vector3(x, y, z + tw * 0.5),
            }
            if prev then
                AddQuad({ prev[2], cur[2], cur[3], prev[3] }, Vector3(0, 0, -1))
                AddQuad({ prev[1], prev[4], cur[4], cur[1] }, Vector3(0, 0, 1))
            end
            prev = cur
        end
    end

    ---冰晶：六边形外框 + 放射冰刺，读作「撞上来之前先结霜」。
    ---@param len number
    ---@param spokes integer
    local function EmitCrystal(len, spokes)
        local hHalf = HALF_H * H_MUL * shape.flare
        local ry, rz = hw * V_SPREAD * W_MUL * 0.55, hHalf * 0.95
        local cx = V_DEPTH * D_MUL * len
        local tw = THICK * T_MUL * 0.45
        col = Color(math.min(1, r * 1.20), math.min(1, g * 1.20), math.min(1, b * 1.20), 1)
        local prev = nil
        for i = 0, 6 do
            local a = (i % 6) / 6 * TAU + math.pi / 6
            local y, z = math.cos(a) * ry, math.sin(a) * rz
            local cur = {
                Vector3(cx, y, z - tw * 0.5),
                Vector3(cx + tw, y, z - tw * 0.5),
                Vector3(cx + tw, y, z + tw * 0.5),
                Vector3(cx, y, z + tw * 0.5),
            }
            if prev then
                AddQuad({ prev[2], cur[2], cur[3], prev[3] }, Vector3(0, 0, -1))
                AddQuad({ prev[1], prev[4], cur[4], cur[1] }, Vector3(0, 0, 1))
            end
            prev = cur
        end
        for i = 1, spokes do
            local a = (i - 1) / spokes * TAU + math.pi / 12
            local dy, dz = math.cos(a), math.sin(a)
            local y0, z0 = dy * ry * 0.85, dz * rz * 0.85
            local w = THICK * T_MUL * 0.6
            local tipX = cx + V_DEPTH * D_MUL * 0.55
            local c1 = Vector3(cx - V_DEPTH * D_MUL * 0.15, y0 - dz * w, z0 + dy * w)
            local c2 = Vector3(cx - V_DEPTH * D_MUL * 0.15, y0 + dz * w, z0 - dy * w)
            local tip = Vector3(tipX, y0 * 1.02, z0 * 1.02)
            col = Color(math.min(1, r * 1.35), math.min(1, g * 1.35), math.min(1, b * 1.35), 1)
            AddTri(c1, c2, tip)
        end
    end

    ---碎晶/碎块：散在波外的小方片，给分裂与冰霜加碎屑感。
    ---@param count integer
    ---@param spread number
    ---@param bright number
    local function EmitShards(count, spread, bright)
        local hHalf = HALF_H * H_MUL * shape.flare
        local ry = hw * V_SPREAD * W_MUL
        for i = 1, count do
            local u = (i - 1) / math.max(1, count - 1)
            local sign = (i % 2 == 0) and 1 or -1
            local ang = u * TAU * 0.9 + i * 0.7
            local size = (hw * 0.055 + hw * 0.05 * (0.5 + 0.5 * math.sin(ang * 2.1)))
            local y = sign * ry * (0.55 + 0.55 * u) + math.sin(ang) * ry * 0.12
            local z = math.cos(ang * 1.3) * hHalf * 1.25
            local x = V_DEPTH * D_MUL * (0.85 - 0.55 * u) + math.cos(ang) * 0.08
            local c = Vector3(x, y, z)
            local ax = Vector3(0.35, sign * 0.9, 0.25):Normalized()
            local sx = Vector3(0, -0.25, 1):Normalized()
            EmitFlat(c, ax, sx, size * spread, size, bright)
        end
    end

    -- ===== 按附魔类型分派几何语言 =====
    local kind = shape.kind or "v"

    if kind == "ring" then
        for i = 1, (shape.rings or 3) do
            local u = (i - 1) / math.max(1, (shape.rings or 3) - 1)
            EmitRing(V_DEPTH * D_MUL * (0.95 - 0.70 * u), 1.15 - 0.55 * u, 16,
                0.85 + 0.55 * u, 0.30 + 0.12 * u)
        end
        for layer = 1, shape.layers do
            EmitV(0, 0.72, SEGMENTS, layer, shape.layers)
        end
    elseif kind == "spike" then
        EmitSpikes(shape.spikes or 10, shape.spikeLen or 0.95, 0.15, 1.30, 0)
        EmitSpikes(math.max(4, math.floor((shape.spikes or 10) * 0.6)),
            (shape.spikeLen or 0.95) * 0.55, 0.05, 0.95, math.pi / (shape.spikes or 10))
        for i = 1, (shape.rings or 1) do
            EmitRing(V_DEPTH * D_MUL * 0.35 * i, 0.85 + 0.35 * (i - 1), 14, 0.80, 0.28)
        end
        for layer = 1, shape.layers do
            EmitV(0, 0.86, SEGMENTS, layer, shape.layers)
        end
    elseif kind == "zigzag" then
        EmitZigzag(-1, shape.boltSegs or 5, shape.boltAmp or 0.34, 1.45)
        EmitZigzag(1, shape.boltSegs or 5, shape.boltAmp or 0.34, 1.45)
        for i = 1, (shape.rings or 1) do
            EmitRing(V_DEPTH * D_MUL * 0.42, 0.72, 12, 1.05, 0.26)
        end
        for layer = 1, shape.layers do
            EmitV(0, 0.80, SEGMENTS, layer, shape.layers)
        end
    elseif kind == "crystal" then
        EmitCrystal(shape.crystalLen or 1.15, shape.spokes or 6)
        EmitShards(shape.shards or 8, 0.85, 1.10)
        for layer = 1, shape.layers do
            EmitV(0, 0.70, SEGMENTS, layer, shape.layers)
        end
    elseif kind == "lift" then
        for i = 1, (shape.arcs or 4) do
            EmitLift(-1, shape.arcs or 4, i)
            EmitLift(1, shape.arcs or 4, i)
        end
        for i = 1, (shape.rings or 1) do
            EmitRing(V_DEPTH * D_MUL * 0.35, 0.62, 12, 1.10, 0.24)
        end
        for layer = 1, shape.layers do
            EmitV(0, 0.62, SEGMENTS, layer, shape.layers)
        end
    elseif kind == "triple" then
        local lanes = shape.lanes or 3
        for lane = 1, lanes do
            local u = lanes <= 1 and 0 or ((lane - 1) / (lanes - 1) * 2 - 1)
            for layer = 1, shape.layers do
                EmitV(u * (shape.fork or 0.62), 0.58, SEGMENTS, layer, shape.layers)
            end
        end
    else
        for layer = 1, shape.layers do
            EmitV(0, 1.00, SEGMENTS, layer, shape.layers)
        end
        for p = 1, shape.prongs do
            local u = shape.prongs == 1 and 0 or ((p - 1) / (shape.prongs - 1) * 2 - 1)
            EmitV(u * shape.fork, 0.52 - 0.10 * math.abs(u), PRONG_SEGMENTS, shape.layers, shape.layers)
        end
        if shape.spikes then
            EmitSpikes(shape.spikes, shape.spikeLen or 1.0, 0.20, 1.25,
                math.pi / math.max(1, shape.spikes))
        end
        if shape.rings then
            for i = 1, shape.rings do
                EmitRing(V_DEPTH * D_MUL * (0.30 + 0.22 * (i - 1)), 0.78 - 0.12 * (i - 1), 14,
                    0.95, 0.26)
            end
        end
        if shape.shards then
            EmitShards(shape.shards, 1.00, 1.05)
        end
    end
    -- 尾迹弧（两侧，所有类型共用）
    for band = 1, shape.wake do
        EmitWake(-1, band)
        EmitWake(1, band)
    end
    -- 竖向褶皱
    for i = 1, shape.ribs do
        EmitRib(i, shape.ribs)
    end

    geometry:Commit()
    S.rebuilds = S.rebuilds + 1
    S.lastFrameUploads = S.lastFrameUploads + written
end

---@param marble EnchantWaveMarble
---@param records table<number, EnchantWaveRecord>
---@return table|nil
local function ReadCar(marble, records)
    if not marble.alive or not marble.enchant then return nil end
    if not Finite(marble.id) then return nil end
    local record = records[marble.id]
    if not record or not record.root or not record.geometry then return nil end
    local base = S.colors[marble.ballType or "normal"] or S.colors.normal or { 0.24, 0.80, 0.91 }
    local rarity = RARITY[marble.enchant.rarity or "common"] or RARITY.common
    local shape = SHAPES[marble.enchant.id or "default"] or SHAPES.default
    local r, g, b = ShiftHue(base, rarity.hue)
    local boost = rarity.boost * 1.12
    return {
        id = marble.id, record = record, shape = shape,
        enchantId = marble.enchant.id or "default", rarity = marble.enchant.rarity or "common",
        ballType = marble.ballType or "normal",
        r = math.min(1, r * boost), g = math.min(1, g * boost), b = math.min(1, b * boost),
        phase = IdPhase(marble.id),
    }
end

---@param game EnchantWaveGame
---@param records table<number, EnchantWaveRecord>
---@return table[], integer
local function Collect(game, records)
    local chosen, flying, seen = {}, {}, {}
    if game.activeBall then
        local car = ReadCar(game.activeBall, records)
        if car then chosen[1], seen[car.id] = car, true end
    end
    for _, m in ipairs(game.marbles or {}) do
        if not m.onSling and not seen[m.id] then
            local car = ReadCar(m, records)
            if car then flying[#flying + 1], seen[car.id] = car, true end
        end
    end
    table.sort(flying, function(a, b) return a.id < b.id end)
    for _, car in ipairs(flying) do
        if #chosen >= MAX_CARS then break end
        chosen[#chosen + 1] = car
    end
    return chosen, #chosen
end

---@param game EnchantWaveGame
---@param records table<number, EnchantWaveRecord>
---@param dt number
function M.Sync(game, records, dt)
    if S.faulted then return end
    if game.elapsed and Finite(game.elapsed) then
        if S.lastElapsed and game.elapsed < S.lastElapsed then M.Clear(true) end
        S.lastElapsed = game.elapsed
    end
    if game.state ~= "playing" or (game.introTimer or 0) > 0 then M.Clear(false); return end
    local ts = game.timeScale or 1
    if Finite(dt) and dt > 0 and Finite(ts) and ts > 0 then S.phase = (S.phase + dt * ts) % 10000 end
    local cars, count = Collect(game, records)
    S.lastFrameUploads = 0
    if count == 0 then M.Clear(false); return end

    for i = 1, MAX_CARS do
        local slot = S.slots[i]
        local car = cars[i]
        if not car then
            if slot and slot.node then slot.node.enabled = false end
            if slot then slot.carId, slot.key = 0, "" end
        else
            local root = car.record.root
            local box = car.record.geometry:GetBoundingBox()
            local nose = box.max.x
            local hw = math.max(math.abs(box.min.y), math.abs(box.max.y))
            local zc = (box.min.z + box.max.z) * 0.5
            if Finite(nose) and Finite(hw) and hw > 0 and Finite(zc) then
                local key = string.format("%s|%s|%s|%.3f", car.enchantId, car.rarity, car.ballType, hw)
                if slot.node == nil then
                    local node = root:CreateChild("EnchantWave" .. i, LOCAL)
                    local geometry = node:CreateComponent("CustomGeometry", LOCAL)
                    assert(geometry, "CustomGeometry unavailable")
                    geometry:SetDynamic(false)
                    geometry.castShadows = false
                    slot.node, slot.geometry = node, geometry
                    if slot.material then geometry:SetMaterial(0, slot.material) end
                    node.enabled = false
                elseif slot.parent ~= root then
                    -- 车辆根节点被重建（换弹种/皮肤）：重挂并重建。
                    slot.node:Remove()
                    slot.node:Dispose()
                    local node = root:CreateChild("EnchantWave" .. i, LOCAL)
                    local geometry = node:CreateComponent("CustomGeometry", LOCAL)
                    assert(geometry, "CustomGeometry unavailable")
                    geometry:SetDynamic(false)
                    geometry.castShadows = false
                    slot.node, slot.geometry = node, geometry
                    if slot.material then geometry:SetMaterial(0, slot.material) end
                    slot.key = ""
                end
                slot.parent = root
                if slot.key ~= key and slot.geometry then
                    BuildWave(slot.geometry, hw, car.shape, car.r, car.g, car.b)
                    if slot.material then slot.geometry:SetMaterial(0, slot.material) end
                    slot.key = key
                end
                -- 稳态：只写变换与 alpha（不改顶点）。
                local t = S.phase + car.phase
                local shape = car.shape
                local rate = shape.rate
                -- v0.13.79：按附魔各自的动态参数驱动（自转 / 呼吸 / 前推 / 抖动），
                -- 不同附魔的"呼吸节奏"不再一样，避免八种变体看起来只是数量不同。
                local travel = shape.travel or 1.0
                local push = (0.03 + 0.09 * (0.5 + 0.5 * math.sin(t * rate * 2.2))) * travel
                slot.node.position = Vector3(nose + GAP + push, 0, zc)
                local pulse = shape.pulse or 0.05
                local breathe = 1 + pulse * math.sin(t * rate * 1.7)
                slot.node.scale = Vector3(breathe, breathe, breathe)
                -- 绕前向轴（X）复合旋转：tilt 是缓慢侧倾，spin 是自转，jitter 是高频抖动。
                local spin = (shape.spin or 0) * t
                local jitter = (shape.jitter or 0) * math.sin(t * 24.0 + car.phase)
                local tilt = 1.6 * math.sin(t * rate * 1.25)
                slot.node.rotation = Quaternion(math.rad(spin + tilt + jitter), Vector3(1, 0, 0))
                slot.node.enabled = true
                if slot.material then
                    slot.material:SetShaderParameter("MatDiffColor",
                        Variant(Color(1, 1, 1, 0.66 + 0.24 * math.sin(t * rate * 2.0))))
                end
                slot.carId = car.id
            else
                if slot.node then slot.node.enabled = false end
                slot.carId, slot.key = 0, ""
            end
        end
    end
    local active = 0
    for i = 1, (S.slots and #S.slots) or 0 do
        local slot = S.slots[i]
        if slot and slot.node and slot.node.enabled then active = active + 1 end
    end
    S.activeNodes = active
end

---只读诊断：性能三件套（稳态顶点上传 / draw call / 重建次数）+ 每车几何规模。
---@return table
function M.Debug()
    local cars = {}
    for i = 1, (S.slots and #S.slots) or 0 do
        local slot = S.slots[i]
        if slot and slot.carId and slot.carId > 0 then
            local verts = 0
            local okV, readV = false, nil
            if slot.geometry then
                okV, readV = pcall(function() return slot.geometry:GetNumVertices() end)
            end
            if okV and type(readV) == "number" then verts = readV end
            cars[#cars + 1] = { id = slot.carId, key = slot.key, vertices = verts }
        end
    end
    return {
        initialized = S.texture ~= nil,
        count = #cars,
        orbs = S.activeNodes,
        nodes = S.activeNodes,
        particles = 0,
        drawCalls = S.activeNodes,
        rebuilds = S.rebuilds,
        lastFrameVertexUpload = S.lastFrameUploads,
        vertices = 0,
        commits = S.rebuilds,
        clears = S.clears,
        faulted = S.faulted,
        lastError = S.lastError,
        cars = cars,
    }
end

return M
