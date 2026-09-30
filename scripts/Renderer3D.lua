-- Renderer3D.lua
-- 只读消费 Game / Presentation 快照，将箱体敌人、精品几何车辆和碎片同步到 3D 场景。

local Renderer3D = {}
local VehicleGeometry = require "VehicleGeometry"

local selectedSkin_ = "default"

local WORLD_SCALE = 0.018
local DESIGN_CENTER_X = 270
local DESIGN_CENTER_Y = 480
local VOXEL_GAP = 0.82
local VOXEL_DEPTH = 2.10
local VOXEL_FRONT_OFFSET = -0.42
local VEHICLE_PLANAR_RADIUS = 1.84
local VEHICLE_COLLISION_FILL = 0.98
local VEHICLE_LOCAL_CENTER_Z = -0.40
local VEHICLE_TURN_SPEED = 420.0

---@type Scene
local scene_ = nil
---@type Model
local modelBox_ = nil
---@type Material
local voxelMaterial_ = nil
---@type Texture2D
local crateTexture_ = nil
---@type Material
local crateMaterial_ = nil
local vehicleMaterialSets_ = {}
local materialCache_ = {}
local enemyMeshes_ = {}
local vehicleRecords_ = {}
local debrisNodes_ = {}
local ejectedBoxNodes_ = {}
---@type VoxelPhysicsWorld|nil
local voxelWorld_ = nil
local voxelPhysicsEnabled_ = false
local voxelPaletteReady_ = false
---@type integer
local voxelDepthVoxels_ = 2
-- 飞散碎块用立方体素，避免 1×1×depth 扁长条（用户可见的 1:1:2）。
---@type integer
local voxelDebrisDepth_ = 1
local MAX_VOXEL_DEBRIS = 24
local VOXEL_DEBRIS_LIFETIME = 1.2  -- 先于世界的 1.4 秒回收，预算以本层存活对象为准
local voxelDebris_ = {}          -- 按出生顺序保存本层创建的碎块
local voxelDebrisClock_ = 0
local consumedEjectIds_ = {}
-- 命中缺口必须同帧重建，不再用每帧 4 架预算把缺口拖到后续帧。
local particleSets_ = nil    -- {spark=..., shard=..., smoke=...}
local particleSetActive_ = {spark = false, shard = false, smoke = false}
local particleMaterials_ = nil
local particleNodes_ = nil
local aimLineSet_ = nil
local aimLineActive_ = false
local aimLineNode_ = nil
local aimLineMaterial_ = nil
-- v0.13.22：尾迹 = **真正的 3D 几何光带**（CustomGeometry 三角带），不是 billboard 精灵。
-- 用户要求复刻「后一种」（渐细渐隐光带）效果，billboard 是 2D 面向相机的四边形，
-- 做不出带厚度/带朝向的光带。走敌机箱体同一条已验证可见的材质路径
-- （DiffVCol + 白底纹理 + 顶点色），并用 SetDynamic(true) 支持每帧重建
-- ——历史 ribbon 版（v0.13.10）正是**漏了 SetDynamic(true)** 才完全画不出来。
local trailGeometries_ = nil   -- {ballType = {node=..., geometry=...}}
local trailSamples_ = {}
local trailActive_ = {normal = false, ice = false, speed = false, giant = false}
local lastRenderElapsed_ = nil
local initialized_ = false

-- v0.10.21：粒子分三类，各用一个 BillboardSet（每类独立槽位预算，共 3 draw call）。
-- spark/shard/smoke 都是小而稀疏的点缀；软圆与三角纹理程序化生成。
local PARTICLE_SLOTS = { spark = 64, shard = 40, smoke = 28 }

-- 车辆尾迹（3D BillboardSet，每弹种一个批次）
local TRAIL_TYPES = {"normal", "ice", "speed", "giant"}
local TRAIL_VEHICLE_LIMIT = 8
local TRAIL_POINTS_PER_VEHICLE = 16   -- 折线采样点（光带细分）
local TRAIL_LIFETIME = 0.42           -- 尾迹存活（越长越像"拉出来的一道"）
local TRAIL_SAMPLE_INTERVAL = 0.016   -- 采样更密 → 折线更顺滑
local TRAIL_BEHIND_Z = 0.16           -- 相对车辆锚点再远 0.16m，光带落在车体之后
local TRAIL_HALF_WIDTH_HEAD = 0.30    -- 头段半宽（× 权威半径 × WORLD_SCALE）
local TRAIL_HALF_WIDTH_TAIL = 0.012   -- 尾段半宽（渐收成一条细线）
local PARTICLE_FRONT_Z = -0.95   -- 浮在敌机体素表面（相机在 -Z 侧）与飞散箱之前


local BALL_COLORS = {
    normal = {1.00, 0.72, 0.12},
    ice = {0.18, 0.78, 1.00},
    speed = {1.00, 0.18, 0.035},
    giant = {0.64, 0.20, 1.00},
}

local VEHICLE_PALETTES = {
    normal = {
        body = {0.84, 0.38, 0.035}, side = {1.00, 0.62, 0.13},
        accent = {1.00, 0.92, 0.24}, glass = {0.10, 0.30, 0.42},
    },
    ice = {
        body = {0.055, 0.48, 0.78}, side = {0.22, 0.80, 1.00},
        accent = {0.62, 0.96, 1.00}, glass = {0.045, 0.18, 0.34},
    },
    speed = {
        body = {0.76, 0.045, 0.015}, side = {1.00, 0.24, 0.055},
        accent = {1.00, 0.72, 0.08}, glass = {0.16, 0.07, 0.13},
    },
    giant = {
        body = {0.39, 0.045, 0.74}, side = {0.72, 0.25, 1.00},
        accent = {0.92, 0.54, 1.00}, glass = {0.14, 0.055, 0.27},
    },
}

local aircraftMaterialSets_ = {}

local WHEEL_COLOR = {0.035, 0.045, 0.065}
local HUB_COLOR = {0.44, 0.48, 0.56}
local HEADLIGHT_COLOR = {1.00, 0.95, 0.56}
local TAILLIGHT_COLOR = {1.00, 0.06, 0.025}

local FACE_DEFS = {
    {neighbor = {-1, 0, 0}, normal = Vector3(-1, 0, 0), tint = 0.72,
        corners = {{-1,-1, 1}, {-1, 1, 1}, {-1, 1,-1}, {-1,-1,-1}}},
    {neighbor = { 1, 0, 0}, normal = Vector3( 1, 0, 0), tint = 0.86,
        corners = {{ 1,-1,-1}, { 1, 1,-1}, { 1, 1, 1}, { 1,-1, 1}}},
    {neighbor = {0, -1, 0}, normal = Vector3(0, -1, 0), tint = 0.68,
        corners = {{-1,-1, 1}, {-1,-1,-1}, { 1,-1,-1}, { 1,-1, 1}}},
    {neighbor = {0,  1, 0}, normal = Vector3(0,  1, 0), tint = 0.90,
        corners = {{-1, 1,-1}, {-1, 1, 1}, { 1, 1, 1}, { 1, 1,-1}}},
    {neighbor = {0, 0, -1}, normal = Vector3(0, 0, -1), tint = 1.00,
        corners = {{ 1,-1,-1}, {-1,-1,-1}, {-1, 1,-1}, { 1, 1,-1}}},
    {neighbor = {0, 0,  1}, normal = Vector3(0, 0,  1), tint = 0.56,
        corners = {{-1,-1, 1}, { 1,-1, 1}, { 1, 1, 1}, {-1, 1, 1}}},
}

local function ToColor(rgb, alpha)
    return Color(rgb[1], rgb[2], rgb[3], alpha or 1.0)
end

local function ShadeColor(rgb, factor)
    return Color(
        math.min(1.0, rgb[1] * factor),
        math.min(1.0, rgb[2] * factor),
        math.min(1.0, rgb[3] * factor),
        1.0
    )
end

local function GameToWorld(x, y, z)
    return Vector3(
        (x - DESIGN_CENTER_X) * WORLD_SCALE,
        (DESIGN_CENTER_Y - y) * WORLD_SCALE,
        z or 0
    )
end

local function CreateMaterial(rgb, metallic, roughness, emissive)
    local key = string.format("%.3f_%.3f_%.3f_%.2f_%.2f%s",
        rgb[1], rgb[2], rgb[3], metallic or 0, roughness or 0.5,
        emissive and "_e" or "")
    if materialCache_[key] then return materialCache_[key] end

    local material = Material:new()
    material:SetTechnique(0,
        cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    material:SetShaderParameter("MatDiffColor", Variant(ToColor(rgb)))
    material:SetShaderParameter("Metallic", Variant(metallic or 0.0))
    material:SetShaderParameter("Roughness", Variant(roughness or 0.5))
    if emissive then
        material:SetShaderParameter("MatEmissiveColor", Variant(ToColor(emissive)))
    end
    materialCache_[key] = material
    return material
end

-- WO-16/P9：Dispose 审计。所有由本渲染层创建的 Object 子类（Node/Component）
-- 在移除时必须显式 Dispose 立即释放，避免拖到 GC。RemoveNode 仅移除并释放根节点；
-- 子组件随节点销毁链统一释放，但 CustomGeometry/StaticModel 等需显式 Dispose。
local function RemoveNode(node)
    if not node then return end
    node:Remove()
    node:Dispose()
end

-- 显式释放单个模型组件（碎片 StaticModel / 敌人 CustomGeometry）。
local function DisposeComponent(component)
    if component then component:Dispose() end
end

local function FrozenColor(rgb, frozen)
    if not frozen then return rgb end
    return {
        math.min(1.0, rgb[1] * 0.45 + 0.35),
        math.min(1.0, rgb[2] * 0.45 + 0.45),
        math.min(1.0, rgb[3] * 0.45 + 0.55),
    }
end

local function GetBrickColor(enemy, brick, visualCatalog)
    if visualCatalog and visualCatalog.GetBrickStyle then
        local style = visualCatalog.GetBrickStyle(enemy.aircraftKey, brick.col, brick.row)
        if style then
            return FrozenColor({style.r / 255, style.g / 255, style.b / 255}, enemy.frozen > 0),
                style.slot
        end
    end
    return FrozenColor({0.42, 0.55, 0.66}, enemy.frozen > 0), "hullMain"
end

-- 程序化金属面板纹理（64×64）：深色底 + 四角铆钉 + 边框 + 面板高光，
-- 顶点色负责染色，材质本身是中性灰白，适合任意机型配色。
local function CreateMetalPanelTexture()
    local size = 64
    local image = Image()
    image:SetSize(size, size, 4)
    local function Put(x, y, shade)
        x = math.max(0, math.min(size - 1, x))
        y = math.max(0, math.min(size - 1, y))
        image:SetPixel(x, y, Color(shade, shade, shade, 1))
    end
    local base = 0.62
    for y = 0, size - 1 do
        for x = 0, size - 1 do
            -- 轻微拉丝噪点，避免大面积纯色。
            local grain = ((x * 37 + y * 61) % 7) / 7 * 0.06 - 0.03
            Put(x, y, math.max(0, math.min(1, base + grain)))
        end
    end
    -- 边框 3px（暗）。
    for t = 0, 2 do
        for i = 0, size - 1 do
            Put(i, t, 0.22); Put(i, size - 1 - t, 0.18)
            Put(t, i, 0.22); Put(size - 1 - t, i, 0.20)
        end
    end
    -- 内面板线 1px（稍暗）。
    for i = 6, size - 7 do
        Put(i, 6, 0.42); Put(i, size - 7, 0.38)
        Put(6, i, 0.42); Put(size - 7, i, 0.40)
    end
    -- 四角铆钉（亮点）。
    local function Rivet(cx, cy)
        for dy = -2, 2 do
            for dx = -2, 2 do
                if dx * dx + dy * dy <= 4 then
                    local d = math.sqrt(dx * dx + dy * dy)
                    Put(cx + dx, cy + dy, d <= 1 and 0.82 or 0.40)
                end
            end
        end
    end
    Rivet(10, 10); Rivet(size - 11, 10); Rivet(10, size - 11); Rivet(size - 11, size - 11)

    local texture = Texture2D:new()
    texture:SetData(image, false)
    texture:SetSRGB(true)
    return texture
end

local function GetEnemySignature(enemy, frozen)
    -- 两条渲染路径都只在实际换色时重建：后备网格在 frozen>0 变色，
    -- 体素色板在 freezeRatio>0.35 切槽位。冻结比例的其余档位不影响几何。
    if frozen == nil then frozen = (enemy.frozen or 0) > 0 end
    local parts = {enemy.aircraftKey, frozen and "F" or "N"}
    for _, brick in ipairs(enemy.bricks) do
        parts[#parts + 1] = brick.alive and "1" or "0"
    end
    return table.concat(parts)
end

local function EmitQuad(geometry, v1, v2, v3, v4, normal, color, uvScale)
    local vertices = {v1, v2, v3, v1, v3, v4}
    local uvs = {
        Vector2(0, uvScale), Vector2(0, 0), Vector2(uvScale, 0),
        Vector2(0, uvScale), Vector2(uvScale, 0), Vector2(uvScale, uvScale),
    }
    for i, vertex in ipairs(vertices) do
        geometry:DefineVertex(vertex)
        geometry:DefineNormal(normal)
        geometry:DefineColor(color)
        geometry:DefineTexCoord(uvs[i])
    end
end

local function EmitEdgeStrip(buffer, a, b, normal, halfWidth, color)
    local dx = b.x - a.x
    local dy = b.y - a.y
    local dz = b.z - a.z
    local length = math.sqrt(dx * dx + dy * dy + dz * dz)
    if length < 0.000001 then return end
    dx, dy, dz = dx / length, dy / length, dz / length
    local sx = normal.y * dz - normal.z * dy
    local sy = normal.z * dx - normal.x * dz
    local sz = normal.x * dy - normal.y * dx
    local sideLength = math.sqrt(sx * sx + sy * sy + sz * sz)
    if sideLength < 0.000001 then return end
    sx, sy, sz = sx / sideLength * halfWidth, sy / sideLength * halfWidth,
        sz / sideLength * halfWidth
    local offset = 0.003
    local function OffsetPoint(point, sideSign)
        return Vector3(
            point.x + sx * sideSign + normal.x * offset,
            point.y + sy * sideSign + normal.y * offset,
            point.z + sz * sideSign + normal.z * offset)
    end
    local p0 = OffsetPoint(a, 1)
    local p1 = OffsetPoint(b, 1)
    local p2 = OffsetPoint(b, -1)
    local p3 = OffsetPoint(a, -1)
    local vertices = {p0, p1, p2, p0, p2, p3}
    for _, vertex in ipairs(vertices) do
        buffer[#buffer + 1] = {position = vertex, normal = normal, color = color}
    end
end

local function EmitVoxelFace(geometry, edgeVertices, v1, v2, v3, v4, normal, color, edgeWidth)
    EmitQuad(geometry, v1, v2, v3, v4, normal, color, 0.55)
    EmitEdgeStrip(edgeVertices, v1, v2, normal, edgeWidth, Color(0.012, 0.018, 0.038, 1))
    EmitEdgeStrip(edgeVertices, v2, v3, normal, edgeWidth, Color(0.012, 0.018, 0.038, 1))
    EmitEdgeStrip(edgeVertices, v3, v4, normal, edgeWidth, Color(0.012, 0.018, 0.038, 1))
    EmitEdgeStrip(edgeVertices, v4, v1, normal, edgeWidth, Color(0.012, 0.018, 0.038, 1))
end

-- 敌机是由 AircraftPixelData occupied cells 逐块构成的单体素网格。
-- 每个敌人仍只有一个 CustomGeometry；section 0 是暴露体素面，section 1 是棱线。
local GetCrateMaterial

local function RebuildEnemyMesh(record, enemy, visualCatalog)
    local geometry = record.geometry
    geometry:Clear()
    geometry:SetNumGeometries(2)
    geometry:SetDynamic(false)
    geometry:BeginGeometry(0, TRIANGLE_LIST)

    local pitch = enemy.brickSize * WORLD_SCALE
    local unit = pitch * 0.96
    local depth = unit * VOXEL_DEPTH
    local edgeWidth = math.max(0.004, unit * 0.045)
    local edgeVertices = {}
    local alive = {}

    -- 正面朝向相机（Z-）最亮，其余面用 FACE_DEFS.tint 压暗；
    -- 座舱/引擎是发光感部件，给一个最低亮度保证在翼面里跳得出来。
    local function FaceColor(base, slot, face)
        local factor = face.tint
        if slot == "canopy" then factor = math.max(factor, 0.88)
        elseif slot == "engine" then factor = math.max(factor, 0.74) end
        return Color(base[1] * factor, base[2] * factor, base[3] * factor, 1)
    end

    for _, brick in ipairs(enemy.bricks) do
        if brick.alive then
            local key = tostring(brick.col) .. ":" .. tostring(brick.row)
            alive[key] = brick
        end
    end

    for _, brick in ipairs(enemy.bricks) do
        if brick.alive then
            local key = tostring(brick.col) .. ":" .. tostring(brick.row)
            local rgb, slot = GetBrickColor(enemy, brick, visualCatalog)
            local cx = (brick.col - 0.5) * pitch
            local cy = -(brick.row - 0.5) * pitch
            local minX, maxX = cx - unit * 0.5, cx + unit * 0.5
            local minY, maxY = cy - unit * 0.5, cy + unit * 0.5
            local frontZ, backZ = -depth * 0.5, depth * 0.5

            for _, face in ipairs(FACE_DEFS) do
                -- 飞机是二维 occupied cells 向 Z 轴挤出的单层体素：
                -- 只有 XY 侧面存在二维邻居，前后 Z 面必须始终生成。
                local hasNeighbor = false
                if face.neighbor[1] ~= 0 or face.neighbor[2] ~= 0 then
                    local neighborCol = brick.col + face.neighbor[1]
                    local neighborRow = brick.row + face.neighbor[2]
                    local neighborKey = tostring(neighborCol) .. ":" .. tostring(neighborRow)
                    hasNeighbor = alive[neighborKey] ~= nil
                end
                if not hasNeighbor then
                    local c = face.corners
                    local vertices = {}
                    for i, corner in ipairs(c) do
                        local x = corner[1] < 0 and minX or maxX
                        local y = corner[2] < 0 and minY or maxY
                        local z = corner[3] < 0 and frontZ or backZ
                        vertices[i] = Vector3(x, y, z)
                    end
                    -- 每格按机型配色 + 面朝向明暗；座舱/引擎槽位有最低亮度。
                    local color = FaceColor(rgb, slot, face)
                    EmitVoxelFace(geometry, edgeVertices,
                        vertices[1], vertices[2], vertices[3], vertices[4],
                        face.normal, color, edgeWidth)
                end
            end
        end
    end

    geometry:BeginGeometry(1, TRIANGLE_LIST)
    for _, vertex in ipairs(edgeVertices) do
        geometry:DefineVertex(vertex.position)
        geometry:DefineNormal(vertex.normal)
        geometry:DefineColor(vertex.color)
        geometry:DefineTexCoord(Vector2(0, 0))
    end
    geometry:Commit()
    geometry:SetMaterial(0, GetCrateMaterial())
    geometry:SetMaterial(1, voxelMaterial_)
    record.signature = GetEnemySignature(enemy)
end

-- 敌机只在客户端表现，不参与场景复制；颜色必须写进 LOCAL 色板，
-- 否则客户端 LOCAL Volume 会从空色板取色，显示为无色方块。
local VOXEL_COLOR_DOMAIN = VOXEL_PALETTE_LOCAL

-- 体素调色板：原有 8 型 + 10 精英 + 5 首领，各四槽、正常/冰冻，总计 184 槽。
-- 必须在任何 CreateVolume 之前设完；颜色来自 VisualCatalog，硬度低到弹珠伤害能挖掉。
local function EnsureVoxelPalette(visualCatalog)
    if voxelPaletteReady_ or not voxelWorld_ or not visualCatalog then return end
    if not visualCatalog.GetAircraftKeys or not visualCatalog.GetAircraftPalette then return end
    local keys = visualCatalog.GetAircraftKeys()
    for _, key in ipairs(keys) do
        local palette = visualCatalog.GetAircraftPalette(key)
        for _, frozen in ipairs({ false, true }) do
            for _, slot in ipairs({ "hullMain", "hullDark", "canopy", "engine" }) do
                local rgb = palette[slot] or palette.hullMain
                local r, g, b = rgb[1] / 255, rgb[2] / 255, rgb[3] / 255
                if frozen then
                    r = math.min(1.0, r * 0.45 + 0.35)
                    g = math.min(1.0, g * 0.45 + 0.45)
                    b = math.min(1.0, b * 0.45 + 0.55)
                end
                local index = visualCatalog.GetVoxelMatIndex(key, slot, frozen)
                voxelWorld_:SetPaletteEntry(index, Color(r, g, b), 0.2, 0, VOXEL_COLOR_DOMAIN)
                local metallic = (slot == "hullMain" or slot == "hullDark") and 0.55 or 0.08
                local roughness = slot == "canopy" and 0.18 or 0.42
                local emissive = nil
                if slot == "engine" then
                    emissive = Color(r, g, b, frozen and 2.0 or 4.0)
                elseif slot == "canopy" then
                    emissive = Color(r, g, b, 1.2)
                end
                if emissive then
                    voxelWorld_:SetPaletteEntryPBR(index, roughness, metallic, 0.5, emissive,
                        VOXEL_COLOR_DOMAIN)
                else
                    voxelWorld_:SetPaletteEntryPBR(index, roughness, metallic, 0.5,
                        Color(0, 0, 0, 0), VOXEL_COLOR_DOMAIN)
                end
                voxelWorld_:SetPaletteCutColor(index, Color(r * 0.55, g * 0.55, b * 0.55),
                    VOXEL_COLOR_DOMAIN)
            end
        end
    end
    voxelPaletteReady_ = true
    print("[Renderer3D] voxel palette ready (LOCAL, " .. #keys .. " aircraft x 4 slots x freeze)")
end

---@return integer
local function VoxelDepthCount()
    return voxelDepthVoxels_
end

-- 体积原点在网格最小角。规则层 enemy.x/y 是阵列左上角（设计坐标，Y 向下），
-- 世界 Y 向上，所以最小角对齐阵列底边：GameToWorld(x, y+gridH*brickSize)。
-- 体素 (col-1, gridH-row, z) 对应规则格 (col,row)：row=1 在世界 +Y（远离玩家）。
local function EnemyVolumeWorldOrigin(enemy, voxelSize)
    local origin = GameToWorld(enemy.x, enemy.y + enemy.gridH * enemy.brickSize, 0)
    local depth = VoxelDepthCount()
    origin.z = origin.z - voxelSize * depth * 0.5
    return origin
end

local function FillEnemyVolume(volume, enemy, visualCatalog)
    if not visualCatalog or not visualCatalog.GetVoxelMatIndex then return end
    local grid = volume:GetGrid()
    grid:Clear()
    local dimX = math.tointeger(enemy.gridW) or 1
    local dimY = math.tointeger(enemy.gridH) or 1
    local dimZ = VoxelDepthCount()
    local frozen = (enemy.freezeRatio or 0) > 0.35
    for _, brick in ipairs(enemy.bricks) do
        if brick.alive then
            local col = math.tointeger(brick.col)
            local row = math.tointeger(brick.row)
            if col and row then
                local style = visualCatalog.GetBrickStyle
                    and visualCatalog.GetBrickStyle(enemy.aircraftKey, col, row)
                local slot = style and style.slot or "hullMain"
                local mat = visualCatalog.GetVoxelMatIndex(enemy.aircraftKey, slot, frozen)
                local gx = col - 1
                local gy = dimY - row
                if gx >= 0 and gx < dimX and gy >= 0 and gy < dimY then
                    for z = 0, dimZ - 1 do
                        grid:SetSolid(gx, gy, z, true)
                    end
                    grid:PaintBox(gx, gy, 0, gx, gy, dimZ - 1, mat)
                end
            end
        end
    end
end

local function CreateEnemyVolume(enemy, visualCatalog)
    if not voxelWorld_ then return nil end
    EnsureVoxelPalette(visualCatalog)
    local voxelSize = enemy.brickSize * WORLD_SCALE
    local dimX = math.tointeger(enemy.gridW) or 1
    local dimY = math.tointeger(enemy.gridH) or 1
    local dimZ = VoxelDepthCount()
    local origin = EnemyVolumeWorldOrigin(enemy, voxelSize)
    local okCreate, volume = pcall(function()
        return voxelWorld_:CreateVolume(dimX, dimY, dimZ, voxelSize, origin, Quaternion(), LOCAL)
    end)
    if not okCreate or not volume then
        print("[Renderer3D] CreateVolume failed: " .. tostring(volume))
        return nil
    end
    local okFill, errFill = pcall(function()
        FillEnemyVolume(volume, enemy, visualCatalog)
        -- 编队主体必须是静态体积：动态体 Node 在质心，每帧把 position 设回网格最小角
        -- 会把整机平移出视野（Preview 上表现为敌机消失、只剩 1:1:2 碎块）。
        -- 规则层仍用 AABB；体素只做表现，每帧只改静态 Node 位置，不让 Jolt 推编队。
        volume.destructible = false
        volume.evictable = false
        volume.collisionLayer = 1
        volume.collisionMask = 0
        volume.material = voxelWorld_:GetPaletteMaterial(0, VOXEL_COLOR_DOMAIN)
        voxelWorld_:FinalizeVolume(volume)
        volume:RebuildGeometry()
        local node = volume:GetNode()
        if node then node.position = origin end
    end)
    if not okFill then
        pcall(function() voxelWorld_:RemoveVolume(volume) end)
        print("[Renderer3D] enemy volume init failed id=" .. tostring(enemy.id)
            .. " error=" .. tostring(errFill))
        return nil
    end
    print("[Renderer3D] enemy volume id=" .. tostring(enemy.id)
        .. " " .. tostring(enemy.aircraftKey)
        .. " " .. tostring(dimX) .. "x" .. tostring(dimY) .. "x" .. tostring(dimZ)
        .. " voxel=" .. string.format("%.3f", voxelSize))
    return volume
end

local function BrickWorldCenter(record, col, row)
    local node = record.volume:GetNode()
    if not node then return nil end
    local size = record.voxelSize
    local colI = math.tointeger(col)
    local rowI = math.tointeger(row)
    if not colI or not rowI then return nil end
    local gx = colI - 1
    local gy = record.gridH - rowI
    local gz = (VoxelDepthCount() - 1) * 0.5
    local origin = node.position
    return Vector3(
        origin.x + (gx + 0.5) * size,
        origin.y + (gy + 0.5) * size,
        origin.z + (gz + 0.5) * size)
end

-- 主体网格以规则快照为准，不依赖有寿命/数量上限的飞散箱事件。
-- 同帧多个格子变化只重建一次；Update 晚于物理步，必须在本帧渲染前完成重建。
local function SyncEnemyVolumeCells(record, enemy, visualCatalog, signature)
    if record.signature == signature then return end
    local volume = record.volume
    local grid = volume:GetGrid()
    local dimZ = VoxelDepthCount()
    local frozen = (enemy.freezeRatio or 0) > 0.35
    local recolor = record.frozen ~= frozen
    local removed, added = 0, 0
    local minX, minY = record.gridW, record.gridH
    local maxX, maxY = -1, -1

    local ok, err = pcall(function()
        for _, brick in ipairs(enemy.bricks) do
            local gx = brick.col - 1
            local gy = record.gridH - brick.row
            local changed = false
            for z = 0, dimZ - 1 do
                if grid:IsSolid(gx, gy, z) ~= brick.alive then
                    grid:SetSolid(gx, gy, z, brick.alive)
                    changed = true
                end
            end
            if changed then
                if brick.alive then added = added + 1 else removed = removed + 1 end
            end
            if brick.alive and (changed or recolor) then
                local style = visualCatalog.GetBrickStyle
                    and visualCatalog.GetBrickStyle(enemy.aircraftKey, brick.col, brick.row)
                local slot = style and style.slot or "hullMain"
                local mat = visualCatalog.GetVoxelMatIndex(enemy.aircraftKey, slot, frozen)
                grid:PaintBox(gx, gy, 0, gx, gy, dimZ - 1, mat)
            end
            if changed or recolor then
                minX, minY = math.min(minX, gx), math.min(minY, gy)
                maxX, maxY = math.max(maxX, gx), math.max(maxY, gy)
            end
        end
        if maxX >= 0 then
            volume:MarkRegionDirty(minX, minY, 0, maxX, maxY, dimZ - 1)
            volume:RebuildGeometry()
        end
        for _, brick in ipairs(enemy.bricks) do
            local gx = brick.col - 1
            local gy = record.gridH - brick.row
            for z = 0, dimZ - 1 do
                if grid:IsSolid(gx, gy, z) ~= brick.alive then
                    error("grid mismatch col=" .. tostring(brick.col)
                        .. " row=" .. tostring(brick.row) .. " z=" .. tostring(z))
                end
            end
        end
    end)
    if not ok then
        print("[Renderer3D][voxel-repair] FAILED enemy=" .. tostring(enemy.id)
            .. " removed=" .. tostring(removed) .. " added=" .. tostring(added)
            .. " error=" .. tostring(err))
        error(err)
    end
    record.signature = signature
    record.frozen = frozen
    if removed > 0 or added > 0 then
        print("[Renderer3D][voxel-repair] enemy=" .. tostring(enemy.id)
            .. " removed=" .. tostring(removed) .. " added=" .. tostring(added)
            .. " rebuilt=true grid=ok")
    end
end

local function SpawnVoxelDebris(record, event, visualCatalog)
    if not voxelWorld_ or not visualCatalog or not visualCatalog.GetVoxelMatIndex then return false end
    local worldPos = BrickWorldCenter(record, event.col, event.row)
        or GameToWorld(event.x, event.y, VOXEL_FRONT_OFFSET)
    local size = record.voxelSize
    local dimZ = voxelDebrisDepth_
    local origin = Vector3(
        worldPos.x - size * 0.5,
        worldPos.y - size * 0.5,
        worldPos.z - size * dimZ * 0.5)
    local okCreate, debris = pcall(function()
        return voxelWorld_:CreateVolume(1, 1, dimZ, size, origin, Quaternion(), LOCAL)
    end)
    if not okCreate or not debris then return false end
    local style = visualCatalog.GetBrickStyle
        and visualCatalog.GetBrickStyle(record.aircraftKey, event.col, event.row)
    local slot = style and style.slot or "hullMain"
    local mat = visualCatalog.GetVoxelMatIndex(record.aircraftKey, slot, false)
    local okFill = pcall(function()
        local grid = debris:GetGrid()
        grid:FillBox(0, 0, 0, 0, 0, dimZ - 1, true)
        grid:PaintBox(0, 0, 0, 0, 0, dimZ - 1, mat)
        debris.density = 280.0
        debris.evictable = true
        debris.destructible = true
        debris.gravityFactor = 1.0
        debris.linearDamping = 0.18
        debris.angularDamping = 0.22
        debris.material = voxelWorld_:GetPaletteMaterial(0, VOXEL_COLOR_DOMAIN)
        voxelWorld_:FinalizeVolumeAsDynamic(debris)
        debris:RebuildGeometry()
        local vx = (event.vx or 0) * WORLD_SCALE
        local vy = -(event.vy or 0) * WORLD_SCALE
        -- 朝相机抛一点，避免碎块卡在编队厚度里看不见。
        local vz = -3.4
        debris:SetLinearVelocity(Vector3(vx, vy, vz))
        debris:SetAngularVelocity(Vector3(
            event.axisPitchSpeed or 0,
            event.axisRollSpeed or 0,
            event.angularVelocity or 0))
    end)
    if not okFill then
        pcall(function() voxelWorld_:RemoveVolume(debris) end)
        return false
    end
    -- 碎块由本层单独登记并显式回收，预算不依赖体素世界的其他 volume
    -- 或枚举顺序。
    voxelDebris_[#voxelDebris_ + 1] = {volume = debris, born = voxelDebrisClock_}
    return true
end

-- 主动管理本层碎块的寿命与预算，避免引擎自动老化后 Lua 计数失准。
-- 新碎块只在下一次场景同步中老化，上一帧旧碎块优先移除。
local function TrimVoxelDebris()
    if not voxelWorld_ then return end
    for i = #voxelDebris_, 1, -1 do
        local entry = voxelDebris_[i]
        if voxelDebrisClock_ - entry.born >= VOXEL_DEBRIS_LIFETIME then
            voxelWorld_:RemoveVolume(entry.volume)
            table.remove(voxelDebris_, i)
        end
    end
    while #voxelDebris_ > MAX_VOXEL_DEBRIS do
        voxelWorld_:RemoveVolume(voxelDebris_[1].volume)
        table.remove(voxelDebris_, 1)
    end
end

local function ClearVoxelDebris()
    if voxelWorld_ then
        for _, entry in ipairs(voxelDebris_) do
            pcall(function() voxelWorld_:RemoveVolume(entry.volume) end)
        end
    end
    voxelDebris_ = {}
    voxelDebrisClock_ = 0
end

local function SyncVoxelEnemies(game, presentation)
    local visualCatalog = presentation.visualCatalog
    EnsureVoxelPalette(visualCatalog)
    local active = {}
    for _, enemy in ipairs(game.veggies) do
        if not enemy.dead then
            active[enemy.id] = true
            local record = enemyMeshes_[enemy.id]
            if not record or (not record.volume and not record.root) then
                local volume = CreateEnemyVolume(enemy, visualCatalog)
                if volume then
                    record = {
                        volume = volume,
                        signature = GetEnemySignature(enemy,
                            (enemy.freezeRatio or 0) > 0.35),
                        voxelSize = enemy.brickSize * WORLD_SCALE,
                        gridW = math.tointeger(enemy.gridW) or 1,
                        gridH = math.tointeger(enemy.gridH) or 1,
                        aircraftKey = enemy.aircraftKey,
                        frozen = (enemy.freezeRatio or 0) > 0.35,
                    }
                    enemyMeshes_[enemy.id] = record
                else
                    error("CreateVolume returned nil")
                end
            end
            if record and record.volume then
                local node = record.volume:GetNode()
                if node then
                    node.position = EnemyVolumeWorldOrigin(enemy, record.voxelSize)
                end
            end
        end
    end

    -- 权威规则快照决定全部主体占用；飞散事件仅用于独立碎块，丢事件不会留下幽灵块。
    -- 先对齐网格，后生成碎块；每架飞机一帧最多重建一次。
    for _, enemy in ipairs(game.veggies) do
        local record = enemyMeshes_[enemy.id]
        if record and record.volume and not enemy.dead then
            SyncEnemyVolumeCells(record, enemy, visualCatalog,
                GetEnemySignature(enemy, (enemy.freezeRatio or 0) > 0.35))
        end
    end

    local boxes = presentation.ejectedBoxes or {}
    local liveEjectIds = {}
    for i = 1, #boxes do
        local box = boxes[i]
        liveEjectIds[box.id] = true
        if box.enemyId and not consumedEjectIds_[box.id] then
            local record = enemyMeshes_[box.enemyId]
            if record and record.volume then
                if SpawnVoxelDebris(record, box, visualCatalog) then
                    consumedEjectIds_[box.id] = true
                else
                    if not box.needVisualFallback then
                        print("[Renderer3D][voxel-repair] debris fallback enemy="
                            .. tostring(box.enemyId) .. " col=" .. tostring(box.col)
                            .. " row=" .. tostring(box.row))
                    end
                    box.needVisualFallback = true
                end
            else
                box.needVisualFallback = true
            end
        end
    end
    for id in pairs(consumedEjectIds_) do
        if not liveEjectIds[id] then consumedEjectIds_[id] = nil end
    end

    for id, record in pairs(enemyMeshes_) do
        if not active[id] then
            if record.volume then
                voxelWorld_:RemoveVolume(record.volume)
            elseif record.root then
                RemoveNode(record.root)
            end
            enemyMeshes_[id] = nil
        end
    end
end

-- CustomGeometry 回退路径：签名变化（拓扑/实际冻结色切换）同帧重建，保证缺口即时可见。
local function SyncEnemyMeshes(game, presentation)
    local active = {}
    local visualCatalog = presentation.visualCatalog
    local dirty = {}
    for _, enemy in ipairs(game.veggies) do
        if not enemy.dead then
            active[enemy.id] = true
            local record = enemyMeshes_[enemy.id]
            if not record then
                local root = scene_:CreateChild("VoxelEnemy_" .. tostring(enemy.id))
                local geometry = root:CreateComponent("CustomGeometry")
                geometry.castShadows = false
                record = {root = root, geometry = geometry, signature = ""}
                enemyMeshes_[enemy.id] = record
                dirty[#dirty + 1] = {record = record, enemy = enemy}
            elseif record.signature ~= GetEnemySignature(enemy) then
                dirty[#dirty + 1] = {record = record, enemy = enemy}
            end
            record.root.position = GameToWorld(enemy.x, enemy.y, 0)
        end
    end

    -- 命中缺口必须同帧消失；预算推迟会让玩家看到“物块刷新不及时”。
    for i = 1, #dirty do
        RebuildEnemyMesh(dirty[i].record, dirty[i].enemy, visualCatalog)
    end

    for id, record in pairs(enemyMeshes_) do
        if not active[id] then
            RemoveNode(record.root)
            enemyMeshes_[id] = nil
        end
    end
end

local function CreateGlassMaterial(rgb)
    local material = Material:new()
    material:SetTechnique(0,
        cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
    material:SetShaderParameter("MatDiffColor", Variant(Color(rgb[1], rgb[2], rgb[3], 0.68)))
    material:SetShaderParameter("Metallic", Variant(0.05))
    material:SetShaderParameter("Roughness", Variant(0.08))
    material:SetRenderOrder(180)
    return material
end

local function GetVehicleMaterials(ballType)
    local key = ballType
    local cached = vehicleMaterialSets_[key]
    if cached then return cached end
    local palette = VEHICLE_PALETTES[ballType] or VEHICLE_PALETTES.normal
    local lightColor = BALL_COLORS[ballType] or BALL_COLORS.normal
    cached = {
        CreateMaterial(palette.body, 0.72, 0.27),
        CreateMaterial(palette.side, 0.56, 0.34),
        CreateMaterial(WHEEL_COLOR, 0.0, 0.88),
        CreateMaterial(HUB_COLOR, 0.96, 0.18),
        CreateGlassMaterial(palette.glass),
        CreateMaterial(lightColor, 0.05, 0.20, {
            lightColor[1] * 3.2, lightColor[2] * 3.2, lightColor[3] * 3.2,
        }),
    }
    vehicleMaterialSets_[key] = cached
    return cached
end

local function RebuildVehicleGeometry(geometry, ballType)
    VehicleGeometry.Build(geometry, selectedSkin_, GetVehicleMaterials(ballType))
end

local function MoveAngleToward(current, target, maxStep)
    local delta = (target - current + 180) % 360 - 180
    if math.abs(delta) <= maxStep then return target end
    return current + (delta > 0 and maxStep or -maxStep)
end

local function GetVehicleTargetHeading(game, marble)
    if marble.onSling and game.aiming then
        local launchX = game.slingX - marble.x
        local launchY = marble.y - game.slingY
        if launchX * launchX + launchY * launchY > 0.0001 then
            return math.deg(math.atan(launchY, launchX))
        end
    end

    local worldVx = marble.vx * WORLD_SCALE
    local worldVy = -marble.vy * WORLD_SCALE
    if worldVx * worldVx + worldVy * worldVy > 0.0001 then
        return math.deg(math.atan(worldVy, worldVx))
    end
    if marble.onSling then return -90 end
    return nil
end

local function CreateVehicleRecord(id, marble, initialHeading)
    local root = scene_:CreateChild("Vehicle_" .. tostring(id))
    local geometry = root:CreateComponent("CustomGeometry")
    geometry.castShadows = false
    RebuildVehicleGeometry(geometry, marble.ballType)
    return {
        root = root,
        geometry = geometry,
        ballType = marble.ballType,
        skin = selectedSkin_,
        heading = initialHeading,
        targetHeading = initialHeading,
    }
end

local GetVehicleAnchorWorld

local function SyncVehicles(game, dt)
    local active = {}
    local function SyncOne(marble)
        active[marble.id] = true
        local targetHeading = GetVehicleTargetHeading(game, marble)
        local record = vehicleRecords_[marble.id]
        if not record then
            local initialHeading = targetHeading or -90
            record = CreateVehicleRecord(marble.id, marble, initialHeading)
            vehicleRecords_[marble.id] = record
        elseif record.ballType ~= marble.ballType or record.skin ~= selectedSkin_ then
            record.ballType = marble.ballType
            record.skin = selectedSkin_
            RebuildVehicleGeometry(record.geometry, marble.ballType)
        end

        if targetHeading then record.targetHeading = targetHeading end
        record.heading = MoveAngleToward(
            record.heading,
            record.targetHeading,
            VEHICLE_TURN_SPEED * dt)
        record.root.rotation = Quaternion(record.heading, Vector3(0, 0, 1))

        -- 规则层使用圆形碰撞体；车辆 XY 最远外轮廓必须完整落在该圆内。
        -- marble.radius 已包含普通、加速、分裂与巨型弹的权威尺寸差异。
        local collisionRadiusWorld = marble.radius * WORLD_SCALE
        local vehicleScale = collisionRadiusWorld * VEHICLE_COLLISION_FILL
            / VEHICLE_PLANAR_RADIUS
        -- 视觉车体在权威碰撞圆内放大约 12%，不改变规则半径或输入坐标。
        local scaleFactor = vehicleScale * 1.12
        record.root.scale = Vector3(scaleFactor, scaleFactor, scaleFactor)
        -- 车辆几何主要位于局部负 Z；用缩放后的视觉中心补偿根节点深度，
        -- 使屏幕投影中心继续精确对应权威 marble.x/y。
        record.root.position = GetVehicleAnchorWorld(marble)
    end

    if game.activeBall then SyncOne(game.activeBall) end
    for _, marble in ipairs(game.marbles) do SyncOne(marble) end

    for id, record in pairs(vehicleRecords_) do
        if not active[id] then
            RemoveNode(record.root)
            vehicleRecords_[id] = nil
        end
    end
end

local function GetVehicleScale(marble)
    local collisionRadiusWorld = marble.radius * WORLD_SCALE
    return collisionRadiusWorld * VEHICLE_COLLISION_FILL * 1.12 / VEHICLE_PLANAR_RADIUS
end

GetVehicleAnchorWorld = function(marble)
    local scaleFactor = GetVehicleScale(marble)
    return GameToWorld(marble.x, marble.y, -VEHICLE_LOCAL_CENTER_Z * scaleFactor)
end

local function SyncDebris(presentation)
    -- 碎片走内置 Box 模型；该资源缺失时直接跳过，禁止让可选碎片拖垮整个 3D 初始化。
    if not modelBox_ then return end
    local active = {}
    for _, debris in ipairs(presentation.brickDebris) do
        active[debris.id] = true
        local node = debrisNodes_[debris.id]
        if not node then
            node = scene_:CreateChild("VoxelDebris_" .. tostring(debris.id))
            local model = node:CreateComponent("StaticModel")
            model:SetModel(modelBox_)
            model:SetMaterial(CreateMaterial({debris.r / 255, debris.g / 255, debris.b / 255}, 0, 0.8))
            model.castShadows = false
            debrisNodes_[debris.id] = node
        end
        node.position = GameToWorld(debris.x, debris.y, debris.z * 0.01)
        local size = math.max(0.001, debris.scale * 0.20)
        node.scale = Vector3(size, size, size)
        node.rotation = Quaternion(math.deg(debris.rotation), Vector3(0, 0, 1))
    end

    for id, node in pairs(debrisNodes_) do
        if not active[id] then
            RemoveNode(node)
            debrisNodes_[id] = nil
        end
    end
end

GetCrateMaterial = function()
    if crateMaterial_ then return crateMaterial_ end
    return voxelMaterial_
end

local function BuildEjectedBoxGeometry(geometry, rgb)
    -- 飞散箱体不再依赖内置 Box.mdl：直接生成闭合六面体，确保节点、尺寸、UV 和法线都可控。
    -- 顶点色使用该格的机型配色（正面最亮、背面更暗），材质面板纹理只负责金属细节。
    local base = Color(rgb[1], rgb[2], rgb[3], 1)
    local front = Color(math.min(1, rgb[1] * 1.0), math.min(1, rgb[2] * 1.0), math.min(1, rgb[3] * 1.0), 1)
    local back = Color(rgb[1] * 0.55, rgb[2] * 0.55, rgb[3] * 0.55, 1)
    local side = Color(rgb[1] * 0.78, rgb[2] * 0.78, rgb[3] * 0.78, 1)
    local half = 0.5
    local faces = {
        {Vector3(-half, -half, -half), Vector3(-half, half, -half),
            Vector3(half, half, -half), Vector3(half, -half, -half), Vector3(0, 0, -1), front},
        {Vector3(half, -half, half), Vector3(half, half, half),
            Vector3(-half, half, half), Vector3(-half, -half, half), Vector3(0, 0, 1), back},
        {Vector3(-half, -half, half), Vector3(-half, half, half),
            Vector3(-half, half, -half), Vector3(-half, -half, -half), Vector3(-1, 0, 0), side},
        {Vector3(half, -half, -half), Vector3(half, half, -half),
            Vector3(half, half, half), Vector3(half, -half, half), Vector3(1, 0, 0), side},
        {Vector3(-half, half, -half), Vector3(-half, half, half),
            Vector3(half, half, half), Vector3(half, half, -half), Vector3(0, 1, 0), side},
        {Vector3(-half, -half, half), Vector3(-half, -half, -half),
            Vector3(half, -half, -half), Vector3(half, -half, half), Vector3(0, -1, 0), side},
    }
    geometry:Clear()
    geometry:SetNumGeometries(1)
    geometry:SetDynamic(false)
    geometry:BeginGeometry(0, TRIANGLE_LIST)
    for _, face in ipairs(faces) do
        EmitQuad(geometry, face[1], face[2], face[3], face[4], face[5], face[6] or base, 1.0)
    end
    geometry:Commit()
    geometry:SetMaterial(0, GetCrateMaterial())
end

local function SyncEjectedBoxes(presentation, voxelFallbackOnly)
    local active = {}
    local boxes = presentation.ejectedBoxes or {}
    local visualCatalog = presentation.visualCatalog
    -- 飞散箱继承所属格的机型配色；VisualCatalog 只在槽位识别时用到原始像素色，
    -- 因此这里直接用 box 自带原色走同一套映射结果（GetBrickStyle 已含最终颜色）。
    local function ResolveBoxColor(box)
        if visualCatalog and visualCatalog.GetBrickStyle then
            local style = visualCatalog.GetBrickStyle(box.style, box.col, box.row)
            if style then return {style.r / 255, style.g / 255, style.b / 255} end
        end
        return {0.62, 0.68, 0.78}
    end
    -- 渲染侧节点预算双保险：即使表现层快照异常堆积，也不允许无限创建 CustomGeometry 节点。
    local MAX_RENDERED_BOXES = 28
    for i = 1, math.min(#boxes, MAX_RENDERED_BOXES) do
        local box = boxes[i]
        -- 体素路径下只画创建失败的飞散箱，避免和立方碎块叠两份。
        if not voxelFallbackOnly or box.needVisualFallback then
            active[box.id] = true
            local node = ejectedBoxNodes_[box.id]
            if not node then
                node = scene_:CreateChild("EjectedCrate_" .. tostring(box.id))
                local geometry = node:CreateComponent("CustomGeometry")
                geometry.castShadows = false
                BuildEjectedBoxGeometry(geometry, ResolveBoxColor(box))
                ejectedBoxNodes_[box.id] = node
            end
            -- 独立箱体始终放在敌体朝向相机的一侧，避免主体网格遮挡刚脱离的第一帧。
            node.position = GameToWorld(box.x, box.y, VOXEL_FRONT_OFFSET - 0.24 + box.z * WORLD_SCALE)
            node.enabled = true
            -- 前 0.10 秒保持完整尺寸，确保命中瞬间能读到“整块脱离”；末段再缩放消散。
            local fade = 1.0
            if box.age > 0.10 and box.lifetime - box.age < 0.45 then
                fade = math.max(0, (box.lifetime - box.age) / 0.45)
            end
            local size = math.max(0.01, box.size * WORLD_SCALE * 1.28)
            node.scale = Vector3(size * fade, size * fade, size * fade)
            local rotation = Quaternion()
            rotation:FromEulerAngles(math.deg(box.pitch), math.deg(box.roll), math.deg(box.rotation))
            node.rotation = rotation
        end
    end
    for id, node in pairs(ejectedBoxNodes_) do
        if not active[id] then
            RemoveNode(node)
            ejectedBoxNodes_[id] = nil
        end
    end
end

-- v0.10.21：软圆/三角程序纹理（无外部资源）。
-- ⚠️实测 DiffAlpha 透明技术不读 billboard 顶点 rgb，颜色必须烘焙进纹理；
-- 顶点色只用于 enabled/alpha，淡出统一靠末段尺寸收缩（见 SyncParticles）。
local function CreateSoftCircleTexture(r, g, b, centerA, edgeA)
    local N = 32
    local image = Image()
    image:SetSize(N, N, 4)
    local c = (N - 1) * 0.5
    centerA = centerA or 1
    edgeA = edgeA or 0
    for y = 0, N - 1 do
        for x = 0, N - 1 do
            local d = math.sqrt((x - c) ^ 2 + (y - c) ^ 2) / c
            local t = math.max(0, math.min(1, math.max(0, (d - 0.45)) / 0.55))
            local a = centerA + (edgeA - centerA) * t
            a = math.max(0, math.min(1, a))
            image:SetPixel(x, y, Color(r, g, b, a))
        end
    end
    local tex = Texture2D:new()
    tex:SetData(image, false)
    tex:SetSRGB(true)
    return tex
end

local function CreateTriangleTexture(r, g, b)
    local N = 32
    local image = Image()
    image:SetSize(N, N, 4)
    for y = 0, N - 1 do
        for x = 0, N - 1 do
            local nx = (x / (N - 1)) * 2 - 1
            -- Billboard UV 的 V 轴相对图像 y 翻转，这里在图像里画“尖朝下”，
            -- 实际 billboard 上即尖朝上。
            local ny = -((y / (N - 1)) * 2 - 1)
            local halfW = 0.72 * (0.7 - ny) / (0.7 + 0.8)
            local inside = (ny <= 0.7 and ny >= -0.8 and math.abs(nx) <= halfW)
            image:SetPixel(x, y, Color(r, g, b, inside and 1.0 or 0.0))
        end
    end
    local tex = Texture2D:new()
    tex:SetData(image, false)
    tex:SetSRGB(true)
    return tex
end

-- v0.10.21：粒子按 kind 分到三个 BillboardSet（spark 暖白软圆 / shard 浅金属
-- 三角自旋 / smoke 灰软圆膨胀）。颜色已烘焙进 DiffAlpha 纹理，淡出走末段尺寸收缩。
local function SyncParticles(presentation)
    if not particleSets_ then return end
    local used = { spark = 0, shard = 0, smoke = 0 }
    for _, p in ipairs(presentation.particles or {}) do
        local kind = (p.kind == "shard" or p.kind == "smoke") and p.kind or "spark"
        local slots = PARTICLE_SLOTS[kind]
        if used[kind] < slots then
            used[kind] = used[kind] + 1
            local bb = particleSets_[kind]:GetBillboard(used[kind] - 1)
            bb.enabled = true
            bb.position = GameToWorld(p.x, p.y, PARTICLE_FRONT_Z)
            local lifeT = math.max(0, math.min(1, p.life / p.maxLife))
            local worldSize
            if kind == "smoke" then
                -- 烟雾：小幅膨胀、整体偏小，末段收缩消散。
                local grow = 0.5 + 0.55 * (1 - lifeT)
                local shrink = lifeT < 0.25 and (lifeT / 0.25) or 1
                worldSize = math.max(0.015, p.size * WORLD_SCALE * 0.85 * grow * shrink)
                bb.rotation = 0
            elseif kind == "shard" then
                -- 碎片：小而稳定，末 35% 快速收缩，持续自旋。
                local shrink = lifeT < 0.35 and (lifeT / 0.35) or 1
                worldSize = math.max(0.015, p.size * WORLD_SCALE * 1.25 * shrink)
                bb.rotation = p.angle or 0
            else
                -- 火花：小亮点，整段快速收缩。
                worldSize = math.max(0.012, p.size * WORLD_SCALE * 0.85 * (0.3 + 0.7 * lifeT))
                bb.rotation = 0
            end
            -- DiffAlpha 不读顶点 rgb；保留白顶点，alpha 恒 1（透明度已在纹理里）。
            bb.color = Color(1, 1, 1, 1)
            bb.size = Vector2(worldSize, worldSize)
        end
    end
    for kind, set in pairs(particleSets_) do
        if used[kind] > 0 or particleSetActive_[kind] then
            for i = used[kind] + 1, PARTICLE_SLOTS[kind] do
                set:GetBillboard(i - 1).enabled = false
            end
            set:Commit()
        end
        particleSetActive_[kind] = used[kind] > 0
    end
end

-- v0.10.22：3D 直瞄线。规则层快照 aimLine 给设计坐标起终点，这里转世界坐标，
-- 沿射线排青色软圆点，从车辆到边界渐小。彩色+软边必须颜色烘焙进纹理 + DiffAlpha
-- （DiffVCol 会忽略纹理 alpha 显示成方块）。起点 z 取车辆锚点 z，因相机为 46°
-- 斜俯视正交，z 差会投影到屏幕 Y，不能用固定近相机 z。
local AIM_LINE_Z = -6.0          -- 正交投影下 z 不改变屏幕 XY，只避开遮挡与雾
local AIM_LINE_SEGMENTS = 14     -- 沿线排布的软圆点数
local AIM_LINE_DOT_WORLD = 0.10  -- 起点端点尺寸（世界米），向终点渐小
local AIM_LINE_COLOR = Color(0.30, 0.90, 1.0, 1)

local function ClearTrailSamples()
    trailSamples_ = {}
    if not trailGeometries_ then return end
    for _, ballType in ipairs(TRAIL_TYPES) do
        if trailActive_[ballType] then
            local record = trailGeometries_[ballType]
            -- ⚠️ 清空时只清几何并禁用节点，**不要提交 0 顶点几何**
            -- （会报 "VertexBuffer is empty\!"，AB-136）。
            record.geometry:Clear()
            record.node.enabled = false
        end
        trailActive_[ballType] = false
    end
end

-- 3D 几何光带：把每辆飞行车的轨迹折线做成**渐细渐暗的三角带**（CustomGeometry）。
-- 与敌机箱体共用 DiffVCol + 白底纹理 + 顶点色这条已验证可见的路径；
-- ⚠️ 每帧重建必须 SetDynamic(true)（v0.13.10 漏设导致整条尾迹不可见）。
local function SyncVehicleTrails(game, dt)
    if not trailGeometries_ then return end
    if game.state ~= "playing" then
        if next(trailSamples_) or trailActive_.normal or trailActive_.ice
            or trailActive_.speed or trailActive_.giant then ClearTrailSamples() end
        return
    end
    local tracked = {normal = 0, ice = 0, speed = 0, giant = 0}
    local visible = {}
    local perType = {normal = {}, ice = {}, speed = {}, giant = {}}
    local function collect(marble)
        if not marble then return end
        local ballType = marble.ballType
        if not ballType or not trailGeometries_[ballType] then return end
        if visible[marble.id] then return end
        if tracked[ballType] >= TRAIL_VEHICLE_LIMIT then return end
        visible[marble.id] = true
        local pos = GetVehicleAnchorWorld(marble)
        local track = trailSamples_[marble.id]
        if not track or track.ballType ~= ballType
            or (marble.flightTime or 0) < (track.flightTime or 0) then
            track = {ballType = ballType, points = {}, clock = TRAIL_SAMPLE_INTERVAL,
                x = pos.x, y = pos.y, z = pos.z}
            trailSamples_[marble.id] = track
        end
        local points = track.points
        for i = #points, 1, -1 do
            points[i].age = points[i].age + dt
            if points[i].age >= TRAIL_LIFETIME then table.remove(points, i) end
        end
        local dx, dy = pos.x - track.x, pos.y - track.y
        if dx * dx + dy * dy > 4.0 then      -- >2m 瞬移（复活/传送）：清轨防拉丝
            track.points = {}
            points = track.points
            track.clock = TRAIL_SAMPLE_INTERVAL
        end
        track.clock = track.clock + dt
        if track.clock >= TRAIL_SAMPLE_INTERVAL and dx * dx + dy * dy > 0.0004 then
            points[#points + 1] = {x = track.x, y = track.y, z = track.z,
                age = 0, radius = marble.radius}
            if #points > TRAIL_POINTS_PER_VEHICLE then table.remove(points, 1) end
            track.clock = 0
        end
        track.x, track.y, track.z = pos.x, pos.y, pos.z
        track.flightTime = marble.flightTime or 0
        if #points >= 2 then
            tracked[ballType] = tracked[ballType] + 1
            perType[ballType][#perType[ballType] + 1] = {
                points = points, head = pos, radius = marble.radius,
            }
        end
    end
    collect(game.activeBall)
    for _, marble in ipairs(game.marbles or {}) do
        if not marble.onSling then collect(marble) end
    end
    for id in pairs(trailSamples_) do
        if not visible[id] then trailSamples_[id] = nil end
    end

    for _, ballType in ipairs(TRAIL_TYPES) do
        local record = trailGeometries_[ballType]
        local tracks = perType[ballType]
        local active = #tracks > 0
        if active or trailActive_[ballType] then
            local verts = {}
            local base = BALL_COLORS[ballType] or BALL_COLORS.normal
            for _, track in ipairs(tracks) do
                local samples = track.points
                local n = #samples
                local halfHead = track.radius * WORLD_SCALE * TRAIL_HALF_WIDTH_HEAD
                local halfTail = track.radius * WORLD_SCALE * TRAIL_HALF_WIDTH_TAIL
                for i = 1, n - 1 do
                    local a = samples[i]
                    local b = samples[i + 1]
                    local sdx, sdy = b.x - a.x, b.y - a.y
                    local len = math.sqrt(sdx * sdx + sdy * sdy)
                    if len > 0.0005 then
                        local nx, ny = -sdy / len, sdx / len
                        -- t：1 = 头（新），0 = 尾（旧）
                        local t0 = (i - 1) / (n - 1)
                        local t1 = i / (n - 1)
                        local w0 = halfTail + (halfHead - halfTail) * t0
                        local w1 = halfTail + (halfHead - halfTail) * t1
                        -- 亮度：头亮尾暗（顶点色，DiffVCol 消费）
                        local c0 = Color(base[1] * t0, base[2] * t0, base[3] * t0, 1)
                        local c1 = Color(base[1] * t1, base[2] * t1, base[3] * t1, 1)
                        local az, bz = a.z + TRAIL_BEHIND_Z, b.z + TRAIL_BEHIND_Z
                        local p1 = Vector3(a.x + nx * w0, a.y + ny * w0, az)
                        local p2 = Vector3(a.x - nx * w0, a.y - ny * w0, az)
                        local p3 = Vector3(b.x - nx * w1, b.y - ny * w1, bz)
                        local p4 = Vector3(b.x + nx * w1, b.y + ny * w1, bz)
                        verts[#verts + 1] = {p1, c0}
                        verts[#verts + 1] = {p2, c0}
                        verts[#verts + 1] = {p3, c1}
                        verts[#verts + 1] = {p1, c0}
                        verts[#verts + 1] = {p3, c1}
                        verts[#verts + 1] = {p4, c1}
                    end
                end
            end
            local geometry = record.geometry
            if #verts > 0 then
                geometry:Clear()
                geometry:SetNumGeometries(1)
                -- ⚠️ 每帧重建的几何必须 Dynamic，否则顶点缓冲提交后不可改（历史不可见真因）。
                geometry:SetDynamic(true)
                geometry:BeginGeometry(0, TRIANGLE_LIST)
                for _, v in ipairs(verts) do
                    geometry:DefineVertex(v[1])
                    geometry:DefineNormal(Vector3(0, 0, -1))
                    geometry:DefineColor(v[2])
                    geometry:DefineTexCoord(Vector2(0, 0))
                end
                geometry:Commit()
                record.node.enabled = true
            else
                geometry:Clear()
                record.node.enabled = false
            end
        end
        trailActive_[ballType] = active
    end
end

local function SyncAimLine(game)
    if not aimLineSet_ then return end
    local line = game.aimLine
    if not line and not aimLineActive_ then return end
    local activeCount = 0
    if line then
        -- 相机是 46° 斜俯视正交（非纯俯视），z 会投影到屏幕 Y：
        -- 瞄准线必须与待发车辆锚点同一 z 平面，否则起点相对车辆偏移。
        local zWorld = AIM_LINE_Z
        if game.activeBall then
            zWorld = GetVehicleAnchorWorld(game.activeBall).z
        end
        local a
        if game.activeBall then
            a = GetVehicleAnchorWorld(game.activeBall)
        else
            a = GameToWorld(line.x1, line.y1, zWorld)
        end
        local b = GameToWorld(line.x2, line.y2, zWorld)
        -- v0.10.23：弱拉弓只显示前段，随蓄力从 30% 增长到 100%，
        -- 避免刚过死区就整条拉到边界的突兀感。
        local power = line.power or 1
        local shown = math.max(3, math.floor(AIM_LINE_SEGMENTS * (0.3 + 0.7 * power) + 0.5))
        shown = math.min(shown, AIM_LINE_SEGMENTS)
        for i = 1, AIM_LINE_SEGMENTS do
            -- t 从 0（车辆中心）到 1（边界），点与点略重叠形成连续虚线。
            local t = (i - 1) / (AIM_LINE_SEGMENTS - 1)
            local bb = aimLineSet_:GetBillboard(i - 1)
            if i > shown then
                bb.enabled = false
            else
                bb.enabled = true
                bb.position = Vector3(
                    a.x + (b.x - a.x) * t,
                    a.y + (b.y - a.y) * t,
                    zWorld)
                -- 从车辆到边界逐渐变小，避免等大均一；弱拉整体更小。
                local dot = AIM_LINE_DOT_WORLD * (1.0 - 0.55 * t) * (0.7 + 0.3 * power)
                bb.size = Vector2(dot, dot)
                -- DiffAlpha 不读顶点 rgb；alpha 恒 1，淡出已烘焙在软圆边缘。
                bb.color = Color(1, 1, 1, 1)
                activeCount = shown
            end
        end
    end
    for i = activeCount + 1, AIM_LINE_SEGMENTS do
        aimLineSet_:GetBillboard(i - 1).enabled = false
    end
    aimLineSet_:Commit()
    aimLineActive_ = line ~= nil
end

local function CreateWhiteTexture()
    local image = Image()
    image:SetSize(1, 1, 4)
    image:SetPixel(0, 0, Color(1, 1, 1, 1))
    local texture = Texture2D:new()
    texture:SetData(image, false)
    texture:SetSRGB(true)
    return texture
end

local function CreateCrateMaterial()
    -- 必须使用 DiffVCol：敌机与飞散箱的机型配色走顶点色，
    -- 普通 Diff 不消费顶点色，会导致金属纹理把整机盖成灰白。
    local material = Material:new()
    local technique = cache:GetResource("Technique", "Techniques/DiffVCol.xml")
        or cache:GetResource("Technique", "Techniques/Diff.xml")
    material:SetTechnique(0, technique)
    material:SetTexture(TU_DIFFUSE, crateTexture_ or CreateWhiteTexture())
    material:SetShaderParameter("MatDiffColor", Variant(Color(1, 1, 1, 1)))
    material:SetCullMode(CULL_NONE)
    return material
end
function Renderer3D.Init(scene, voxelWorld)
    scene_ = scene
    voxelWorld_ = voxelWorld
    voxelPhysicsEnabled_ = voxelWorld ~= nil
    voxelPaletteReady_ = false
    voxelDebris_ = {}
    voxelDebrisClock_ = 0
    consumedEjectIds_ = {}
    particleSetActive_ = {spark = false, shard = false, smoke = false}
    aimLineActive_ = false
    lastRenderElapsed_ = nil
    modelBox_ = cache:GetResource("Model", "Models/Box.mdl")

    voxelMaterial_ = Material:new()
    voxelMaterial_:SetTechnique(0,
        cache:GetResource("Technique", "Techniques/DiffVCol.xml"))
    voxelMaterial_:SetTexture(TU_DIFFUSE, CreateWhiteTexture())
    voxelMaterial_:SetShaderParameter("MatDiffColor", Variant(Color(1, 1, 1, 1)))

    -- v0.10.9：程序化金属面板纹理，无外部资源依赖，顶点色按机型染色。
    crateTexture_ = CreateMetalPanelTexture()
    crateMaterial_ = CreateCrateMaterial()
    print("[Renderer3D] procedural aircraft panel texture ready")

    -- v0.10.21：碰撞粒子三批次，DiffAlpha 透明混合；颜色烘焙进程序纹理
    -- （实测 DiffAlpha 不读 billboard 顶点 rgb）。
    local sparkTex = CreateSoftCircleTexture(1.0, 0.92, 0.62, 1.0, 0.0)
    local shardTex = CreateTriangleTexture(0.95, 0.82, 0.52)
    local smokeTex = CreateSoftCircleTexture(0.72, 0.74, 0.80, 0.5, 0.0)
    local function CreateParticleSet(name, slots, texture)
        local node = scene:CreateChild(name)
        local set = node:CreateComponent("BillboardSet")
        set:SetNumBillboards(slots)
        set.castShadows = false
        set.relative = false
        local mat = Material:new()
        mat:SetTechnique(0,
            cache:GetResource("Technique", "Techniques/DiffAlpha.xml"))
        mat:SetTexture(TU_DIFFUSE, texture)
        mat:SetShaderParameter("MatDiffColor", Variant(Color(1, 1, 1, 1)))
        set:SetMaterial(mat)
        for i = 0, slots - 1 do set:GetBillboard(i).enabled = false end
        set:Commit()
        return set, mat, node
    end
    local sparkSet, sparkMat, sparkNode = CreateParticleSet("SparkParticles", PARTICLE_SLOTS.spark, sparkTex)
    local shardSet, shardMat, shardNode = CreateParticleSet("ShardParticles", PARTICLE_SLOTS.shard, shardTex)
    local smokeSet, smokeMat, smokeNode = CreateParticleSet("SmokeParticles", PARTICLE_SLOTS.smoke, smokeTex)
    particleSets_ = { spark = sparkSet, shard = shardSet, smoke = smokeSet }
    particleMaterials_ = { sparkMat, shardMat, smokeMat }
    particleNodes_ = { sparkNode, shardNode, smokeNode }

    -- v0.10.22：直瞄线用青色软圆纹理 + DiffAlpha（颜色烘焙，软边半透明）。
    aimLineNode_ = scene:CreateChild("AimLine")
    aimLineSet_ = aimLineNode_:CreateComponent("BillboardSet")
    aimLineSet_:SetNumBillboards(AIM_LINE_SEGMENTS)
    aimLineSet_.castShadows = false
    aimLineSet_.relative = false
    aimLineMaterial_ = Material:new()
    aimLineMaterial_:SetTechnique(0,
        cache:GetResource("Technique", "Techniques/DiffAlpha.xml"))
    aimLineMaterial_:SetTexture(TU_DIFFUSE,
        CreateSoftCircleTexture(AIM_LINE_COLOR.r, AIM_LINE_COLOR.g, AIM_LINE_COLOR.b, 1.0, 0.0))
    aimLineMaterial_:SetShaderParameter("MatDiffColor", Variant(Color(1, 1, 1, 1)))
    aimLineSet_:SetMaterial(aimLineMaterial_)
    for i = 0, AIM_LINE_SEGMENTS - 1 do
        aimLineSet_:GetBillboard(i).enabled = false
    end
    aimLineSet_:Commit()

    -- 车辆尾迹：每弹种一个 CustomGeometry 三角带，材质走敌机箱体同一条已验证可见的
    -- 路径（DiffVCol + 白底纹理，颜色由顶点色给出）。创建后先禁用节点，
    -- 等有非空几何再启用（避免 "VertexBuffer is empty\!"，AB-136）。
    trailGeometries_ = {}
    for _, ballType in ipairs(TRAIL_TYPES) do
        local node = scene:CreateChild("VehicleTrail_" .. ballType)
        node.enabled = false
        local geometry = node:CreateComponent("CustomGeometry")
        geometry.castShadows = false
        geometry:SetMaterial(0, voxelMaterial_)
        trailGeometries_[ballType] = {node = node, geometry = geometry}
    end
    print("[Renderer3D] vehicle trails ready (3D ribbon geometry)")


    -- Box.mdl 仅用于可选碎片；飞散箱体已是程序化六面体，缺它绝不能导致整层初始化失败
    -- （否则 Backend.Init 返回 false，Start 不订阅 Update/NanoVGRender，表现为 UI 全黑且输入无响应）。
    local initialized = voxelMaterial_ ~= nil and crateMaterial_ ~= nil
    initialized_ = initialized
    print("[Renderer3D] initialized, aircraft_crates=true, voxel_physics="
        .. tostring(voxelPhysicsEnabled_) .. ", dayun_heavy_trucks=true")
    return initialized_
end

-- v0.13.16：车辆根节点的 world Z（车身视觉平面深度）。NanoVG overlay 画尾迹时
-- 必须投影到这个深度平面——46° 斜俯视正交相机下 z 会进屏幕 Y，按 z=0 玩法平面
-- 标定就会让光带与车体分离（用户报「和车分离」）。
function Renderer3D.VehicleDepthZ(radius)
    return -VEHICLE_LOCAL_CENTER_Z * GetVehicleScale({radius = radius or 20})
end

function Renderer3D.GetVehicleAnchor(x, y, marble)
    local record = vehicleRecords_[marble.id]
    if record and record.root then
        local currentBase = GameToWorld(marble.x, marble.y, 0)
        local targetBase = GameToWorld(x, y, 0)
        return record.root.position + (targetBase - currentBase)
    end
    return GetVehicleAnchorWorld({x = x, y = y, radius = marble.radius})
end

local function ClearRunVisuals()
    ClearVoxelDebris()
    ClearTrailSamples()
    for id, record in pairs(enemyMeshes_) do
        if record.volume and voxelWorld_ then
            voxelWorld_:RemoveVolume(record.volume)
        elseif record.root then
            RemoveNode(record.root)
        end
        enemyMeshes_[id] = nil
    end
    for id, record in pairs(vehicleRecords_) do
        RemoveNode(record.root)
        vehicleRecords_[id] = nil
    end
    for id, node in pairs(ejectedBoxNodes_) do
        RemoveNode(node)
        ejectedBoxNodes_[id] = nil
    end
    for id, node in pairs(debrisNodes_) do
        RemoveNode(node)
        debrisNodes_[id] = nil
    end
    consumedEjectIds_ = {}
    lastRenderElapsed_ = nil
    print("[Renderer3D][perf] new run: previous 3D objects cleared")
end

function Renderer3D.Render(game, presentation, skin)
    if not initialized_ then return end
    selectedSkin_ = skin or "default"

    local elapsed = game.elapsed or 0
    if lastRenderElapsed_ and elapsed < lastRenderElapsed_ - 0.0001 then
        ClearRunVisuals()
    end
    local dt = 1 / 60
    if lastRenderElapsed_ then
        if elapsed >= lastRenderElapsed_ then
            dt = math.min(elapsed - lastRenderElapsed_, 0.05)
        end
    end
    lastRenderElapsed_ = elapsed

    if voxelPhysicsEnabled_ then
        voxelDebrisClock_ = voxelDebrisClock_ + dt
        local okSync, syncErr = pcall(function()
            TrimVoxelDebris()
            SyncVoxelEnemies(game, presentation)
            TrimVoxelDebris()
        end)
        if not okSync then
            print("[Renderer3D] voxel sync failed, fallback CustomGeometry: " .. tostring(syncErr))
            ClearVoxelDebris()
            voxelPhysicsEnabled_ = false
            for id, record in pairs(enemyMeshes_) do
                if record.volume and voxelWorld_ then
                    pcall(function() voxelWorld_:RemoveVolume(record.volume) end)
                    enemyMeshes_[id] = nil
                end
            end
            SyncEnemyMeshes(game, presentation)
            SyncEjectedBoxes(presentation)
        else
            -- 体素碎块失败或编队体积尚未建好时，仍画 CustomGeometry 飞散箱，
            -- 避免部分命中只有缺口没有碎裂特效。
            SyncEjectedBoxes(presentation, true)
        end
    else
        SyncEnemyMeshes(game, presentation)
        SyncEjectedBoxes(presentation)
    end
    SyncVehicles(game, dt)
    SyncVehicleTrails(game, dt)
    SyncDebris(presentation)
    SyncParticles(presentation)
    SyncAimLine(game)
end

function Renderer3D.Shutdown()
    ClearVoxelDebris()
    for _, record in pairs(vehicleRecords_) do RemoveNode(record.root) end
    for _, record in pairs(enemyMeshes_) do
        if record.volume and voxelWorld_ then
            voxelWorld_:RemoveVolume(record.volume)
        elseif record.root then
            RemoveNode(record.root)
        end
    end
    for _, node in pairs(debrisNodes_) do RemoveNode(node) end
    for _, node in pairs(ejectedBoxNodes_) do RemoveNode(node) end
    if particleNodes_ then
        for _, node in ipairs(particleNodes_) do RemoveNode(node) end
    end
    if particleSets_ then
        for _, set in pairs(particleSets_) do DisposeComponent(set) end
    end
    if particleMaterials_ then
        for _, mat in ipairs(particleMaterials_) do mat:Dispose() end
    end
    particleSets_ = nil
    particleSetActive_ = {spark = false, shard = false, smoke = false}
    particleMaterials_ = nil
    particleNodes_ = nil
    if aimLineNode_ then RemoveNode(aimLineNode_) end
    if aimLineSet_ then DisposeComponent(aimLineSet_) end
    if aimLineMaterial_ then aimLineMaterial_:Dispose() end
    aimLineNode_ = nil
    aimLineSet_ = nil
    aimLineActive_ = false
    aimLineMaterial_ = nil
    ClearTrailSamples()
    if trailGeometries_ then
        for _, record in pairs(trailGeometries_) do
            DisposeComponent(record.geometry)
            RemoveNode(record.node)
        end
    end
    trailGeometries_ = nil
    trailSamples_ = {}
    vehicleRecords_ = {}
    enemyMeshes_ = {}
    debrisNodes_ = {}
    ejectedBoxNodes_ = {}
    voxelWorld_ = nil
    voxelPhysicsEnabled_ = false
    voxelPaletteReady_ = false
    voxelDebris_ = {}
    voxelDebrisClock_ = 0
    consumedEjectIds_ = {}
    materialCache_ = {}
    vehicleMaterialSets_ = {}
    scene_ = nil
    modelBox_ = nil
    voxelMaterial_ = nil
    crateMaterial_ = nil
    crateTexture_ = nil
    lastRenderElapsed_ = nil
    initialized_ = false
end

return Renderer3D
