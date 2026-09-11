-- Renderer3D.lua
-- 只读消费 Game / Presentation 快照，将箱体敌人、精品几何车辆和碎片同步到 3D 场景。

local Renderer3D = {}

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
local VEHICLE_SECTION_BODY = 0
local VEHICLE_SECTION_SIDE = 1
local VEHICLE_SECTION_TIRE = 2
local VEHICLE_SECTION_METAL = 3
local VEHICLE_SECTION_GLASS = 4
local VEHICLE_SECTION_LIGHT = 5
local VEHICLE_SECTION_COUNT = 6

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
local particleNode_ = nil
local particleSet_ = nil
local particleMaterial_ = nil
local lastRenderElapsed_ = nil
local initialized_ = false

-- v0.10.18：碰撞火花用单个 BillboardSet 批次渲染（所有粒子共享一个 draw call）。
-- 固定槽位复用，超出预算丢弃，禁止按粒子创建节点。
local PARTICLE_SLOTS = 96
local PARTICLE_FRONT_Z = -0.95   -- 浮在敌机体素表面（相机在 -Z 侧）与飞散箱之前
local PARTICLE_SCALE = 3.4       -- 设计像素尺寸 → 世界米的放大（火花小而亮）

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

local function GetEnemySignature(enemy)
    -- WO-13/P2：冻结按比例量化进签名，使冷色偏移/霜冻高光随冻结态变化触发重建，
    -- 但量化档位足够粗（以避免每次帧级冻结衰减都重建）。HP 仍不进入签名。
    local freezeBucket = math.floor((enemy.freezeRatio or 0) * 8 + 0.5)
    local parts = {enemy.aircraftKey, "F" .. tostring(freezeBucket)}
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

-- WO-04/P9：单帧体素重建预算护栏。极端同屏 + 批量冻结切换时，
-- 限制每帧实际重建数量，超额脏记录顺延到下一帧（signature 仍不同会被再次命中）。
-- 触发条件维持「仅拓扑或冻结态改变」（GetEnemySignature），预算只限频次不放松语义。
local REBUILD_BUDGET = 4

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

    for i = 1, math.min(REBUILD_BUDGET, #dirty) do
        RebuildEnemyMesh(dirty[i].record, dirty[i].enemy, visualCatalog)
    end
    if #dirty > REBUILD_BUDGET then
        print("[Renderer3D] rebuild budget hit: " .. #dirty .. " dirty, " .. REBUILD_BUDGET .. " rebuilt this frame (deferred)")
    end

    for id, record in pairs(enemyMeshes_) do
        if not active[id] then
            RemoveNode(record.root)
            enemyMeshes_[id] = nil
        end
    end
end

local function FaceNormal(a, b, c)
    local ux, uy, uz = b.x - a.x, b.y - a.y, b.z - a.z
    local vx, vy, vz = c.x - a.x, c.y - a.y, c.z - a.z
    local nx = uy * vz - uz * vy
    local ny = uz * vx - ux * vz
    local nz = ux * vy - uy * vx
    local length = math.sqrt(nx * nx + ny * ny + nz * nz)
    if length < 0.000001 then return Vector3(0, 0, -1) end
    return Vector3(nx / length, ny / length, nz / length)
end

local function AddTriangle(buffer, a, b, c, expectedNormal)
    local normal = FaceNormal(a, b, c)
    if expectedNormal then
        local dot = normal.x * expectedNormal.x + normal.y * expectedNormal.y
            + normal.z * expectedNormal.z
        if dot < 0 then
            b, c = c, b
            normal = FaceNormal(a, b, c)
        end
    end
    buffer[#buffer + 1] = {position = a, normal = normal}
    buffer[#buffer + 1] = {position = b, normal = normal}
    buffer[#buffer + 1] = {position = c, normal = normal}
end

local function AddQuad(buffer, a, b, c, d, expectedNormal)
    AddTriangle(buffer, a, b, c, expectedNormal)
    AddTriangle(buffer, a, c, d, expectedNormal)
end

local function RoundedRing(cx, cy, z, length, width, bevel)
    local hx, hy = length * 0.5, width * 0.5
    bevel = math.min(bevel, hx * 0.8, hy * 0.8)
    return {
        Vector3(cx + hx - bevel, cy - hy, z),
        Vector3(cx + hx, cy - hy + bevel, z),
        Vector3(cx + hx, cy + hy - bevel, z),
        Vector3(cx + hx - bevel, cy + hy, z),
        Vector3(cx - hx + bevel, cy + hy, z),
        Vector3(cx - hx, cy + hy - bevel, z),
        Vector3(cx - hx, cy - hy + bevel, z),
        Vector3(cx - hx + bevel, cy - hy, z),
    }
end

local function AddFrustum(buffer, cx, cy, zNear, zFar,
        nearLength, nearWidth, farLength, farWidth, bevel)
    local nearRing = RoundedRing(cx, cy, zNear, nearLength, nearWidth, bevel)
    local farRing = RoundedRing(cx, cy, zFar, farLength, farWidth, bevel)
    local nearCenter = Vector3(cx, cy, zNear)
    local farCenter = Vector3(cx, cy, zFar)
    for i = 1, #nearRing do
        local nextIndex = i % #nearRing + 1
        AddTriangle(buffer, nearCenter, nearRing[nextIndex], nearRing[i], Vector3(0, 0, -1))
        AddTriangle(buffer, farCenter, farRing[i], farRing[nextIndex], Vector3(0, 0, 1))
        local midX = (nearRing[i].x + nearRing[nextIndex].x) * 0.5 - cx
        local midY = (nearRing[i].y + nearRing[nextIndex].y) * 0.5 - cy
        AddQuad(buffer, nearRing[i], nearRing[nextIndex], farRing[nextIndex], farRing[i],
            Vector3(midX, midY, 0))
    end
end

local function AddRoundedPrism(buffer, cx, cy, zNear, zFar, length, width, bevel)
    AddFrustum(buffer, cx, cy, zNear, zFar, length, width, length, width, bevel)
end

local function AddCylinderY(buffer, cx, cy, cz, radius, width, segments)
    local yMin, yMax = cy - width * 0.5, cy + width * 0.5
    local minCenter = Vector3(cx, yMin, cz)
    local maxCenter = Vector3(cx, yMax, cz)
    for i = 0, segments - 1 do
        local a0 = i * math.pi * 2 / segments
        local a1 = (i + 1) * math.pi * 2 / segments
        local x0, z0 = cx + math.cos(a0) * radius, cz + math.sin(a0) * radius
        local x1, z1 = cx + math.cos(a1) * radius, cz + math.sin(a1) * radius
        local p0 = Vector3(x0, yMin, z0)
        local p1 = Vector3(x0, yMax, z0)
        local p2 = Vector3(x1, yMax, z1)
        local p3 = Vector3(x1, yMin, z1)
        local expected = Vector3(math.cos((a0 + a1) * 0.5), 0, math.sin((a0 + a1) * 0.5))
        AddQuad(buffer, p0, p1, p2, p3, expected)
        AddTriangle(buffer, minCenter, p3, p0, Vector3(0, -1, 0))
        AddTriangle(buffer, maxCenter, p1, p2, Vector3(0, 1, 0))
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
    local cached = vehicleMaterialSets_[ballType]
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
    vehicleMaterialSets_[ballType] = cached
    return cached
end

local function RebuildVehicleGeometry(geometry, ballType)
    local sections = {}
    for i = 1, VEHICLE_SECTION_COUNT do sections[i] = {} end
    local body = sections[VEHICLE_SECTION_BODY + 1]
    local side = sections[VEHICLE_SECTION_SIDE + 1]
    local tire = sections[VEHICLE_SECTION_TIRE + 1]
    local metal = sections[VEHICLE_SECTION_METAL + 1]
    local glass = sections[VEHICLE_SECTION_GLASS + 1]
    local light = sections[VEHICLE_SECTION_LIGHT + 1]

    -- 局部 +X 是车头，XY 是行驶平面，负 Z 朝向镜头。
    -- 采用大运式平头重卡比例：高平头驾驶室、长货厢、三轴六轮、外露保险杠。
    AddRoundedPrism(body, 0, 0, -0.28, 0.18, 3.45, 1.28, 0.12)
    AddRoundedPrism(body, -0.62, 0, -0.76, -0.25, 1.86, 1.20, 0.10)
    AddFrustum(body, 0.98, 0, -1.02, -0.26, 1.08, 1.16, 1.18, 1.24, 0.09)
    AddRoundedPrism(body, 1.54, 0, -0.72, -0.24, 0.18, 1.18, 0.045)

    -- 浅色侧围独立成材质分区，让斜俯视下的车身侧面与主车漆清晰分层。
    for _, sideY in ipairs({-0.625, 0.625}) do
        AddRoundedPrism(side, -0.45, sideY, -0.61, -0.12, 2.15, 0.075, 0.022)
        AddRoundedPrism(side, 1.02, sideY, -0.82, -0.30, 0.82, 0.075, 0.022)
    end
    AddRoundedPrism(side, -0.62, 0, -0.80, -0.755, 1.62, 0.96, 0.06)

    -- 平头重卡的大面积前风挡和左右侧窗。
    AddFrustum(glass, 1.00, 0, -1.055, -0.99, 0.70, 0.92, 0.82, 1.00, 0.07)
    for _, sideY in ipairs({-0.635, 0.635}) do
        AddRoundedPrism(glass, 1.02, sideY, -0.91, -0.56, 0.58, 0.045, 0.015)
    end

    -- 三轴六轮：前桥转向轮 + 后双桥，圆柱轮胎保持真实轮廓。
    for _, wheelX in ipairs({1.03, -0.52, -1.18}) do
        AddCylinderY(tire, wheelX, -0.73, -0.02, 0.30, 0.24, 14)
        AddCylinderY(tire, wheelX, 0.73, -0.02, 0.30, 0.24, 14)
        AddCylinderY(metal, wheelX, -0.865, -0.02, 0.16, 0.035, 14)
        AddCylinderY(metal, wheelX, 0.865, -0.02, 0.16, 0.035, 14)
    end

    -- 重卡格栅、保险杠、货厢骨架、侧裙、后防撞梁与后视镜。
    AddRoundedPrism(metal, 1.70, 0, -0.51, -0.15, 0.12, 1.14, 0.035)
    for _, grilleY in ipairs({-0.34, -0.17, 0, 0.17, 0.34}) do
        AddRoundedPrism(metal, 1.765, grilleY, -0.48, -0.25, 0.025, 0.10, 0.01)
    end
    AddRoundedPrism(metal, -1.74, 0, -0.18, 0.04, 0.12, 1.10, 0.035)
    AddRoundedPrism(metal, -0.62, -0.66, -0.76, -0.24, 1.88, 0.045, 0.015)
    AddRoundedPrism(metal, -0.62, 0.66, -0.76, -0.24, 1.88, 0.045, 0.015)
    AddRoundedPrism(metal, -1.53, 0, -0.79, -0.75, 0.045, 1.10, 0.012)
    AddRoundedPrism(metal, 0.06, -0.69, -0.17, -0.08, 2.72, 0.055, 0.018)
    AddRoundedPrism(metal, 0.06, 0.69, -0.17, -0.08, 2.72, 0.055, 0.018)
    for _, mirrorY in ipairs({-0.79, 0.79}) do
        AddRoundedPrism(metal, 1.26, mirrorY, -0.91, -0.68, 0.19, 0.11, 0.025)
    end

    -- 类型色灯组：前照灯、顶部示廓灯、尾灯与侧标灯。
    for _, y in ipairs({-0.39, 0.39}) do
        AddRoundedPrism(light, 1.775, y, -0.68, -0.51, 0.035, 0.25, 0.012)
        AddRoundedPrism(light, -1.785, y, -0.36, -0.23, 0.035, 0.20, 0.01)
    end
    for _, y in ipairs({-0.42, 0, 0.42}) do
        AddRoundedPrism(light, 1.16, y, -1.085, -1.055, 0.10, 0.07, 0.015)
    end
    for _, x in ipairs({-1.25, -0.55, 0.18}) do
        AddRoundedPrism(light, x, -0.685, -0.54, -0.43, 0.12, 0.025, 0.008)
        AddRoundedPrism(light, x, 0.685, -0.54, -0.43, 0.12, 0.025, 0.008)
    end

    geometry:Clear()
    geometry:SetNumGeometries(VEHICLE_SECTION_COUNT)
    geometry:SetDynamic(false)
    for sectionIndex = 0, VEHICLE_SECTION_COUNT - 1 do
        geometry:BeginGeometry(sectionIndex, TRIANGLE_LIST)
        for _, vertex in ipairs(sections[sectionIndex + 1]) do
            geometry:DefineVertex(vertex.position)
            geometry:DefineNormal(vertex.normal)
        end
    end
    geometry:Commit()

    local materials = GetVehicleMaterials(ballType)
    for sectionIndex = 0, VEHICLE_SECTION_COUNT - 1 do
        geometry:SetMaterial(sectionIndex, materials[sectionIndex + 1])
    end
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
        elseif record.ballType ~= marble.ballType then
            record.ballType = marble.ballType
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

local function SyncEjectedBoxes(presentation)
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
    for id, node in pairs(ejectedBoxNodes_) do
        if not active[id] then
            RemoveNode(node)
            ejectedBoxNodes_[id] = nil
        end
    end
end

-- v0.10.18：碰撞火花。Presentation 的粒子是设计空间的迸发点（含速度/生命/颜色），
-- 同步为世界空间 billboard；一个 BillboardSet 承载全部槽位，只占一个 draw call。
local function SyncParticles(presentation)
    if not particleSet_ then return end
    local particles = presentation.particles or {}
    local count = math.min(#particles, PARTICLE_SLOTS)
    for i = 1, PARTICLE_SLOTS do
        local bb = particleSet_:GetBillboard(i - 1)
        local p = particles[i]
        if p and i <= count then
            bb.enabled = true
            bb.position = GameToWorld(p.x, p.y, PARTICLE_FRONT_Z)
            -- 火花尺寸：初始更大，并随生命周期收缩，保证命中瞬间醒目。
            local lifeT = math.max(0, math.min(1, p.life / p.maxLife))
            local sizeT = 0.45 + 0.55 * lifeT
            local worldSize = math.max(0.05, p.size * WORLD_SCALE * PARTICLE_SCALE * sizeT)
            bb.size = Vector2(worldSize, worldSize)
            -- 前 35% 生命保持全亮，之后平滑淡出。
            local alpha = math.max(0, math.min(1, (lifeT - 0.0) / 0.65))
            bb.color = Color(p.r / 255, p.g / 255, p.b / 255, alpha)
        else
            bb.enabled = false
        end
    end
    particleSet_:Commit()
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
function Renderer3D.Init(scene)
    scene_ = scene
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

    -- v0.10.18：碰撞火花批次（单 BillboardSet，白纹理 DiffVCol，每粒子顶点色）。
    particleNode_ = scene:CreateChild("HitParticles")
    particleSet_ = particleNode_:CreateComponent("BillboardSet")
    particleSet_:SetNumBillboards(PARTICLE_SLOTS)
    particleSet_.castShadows = false
    particleSet_.relative = false
    particleMaterial_ = Material:new()
    particleMaterial_:SetTechnique(0,
        cache:GetResource("Technique", "Techniques/DiffVCol.xml"))
    particleMaterial_:SetTexture(TU_DIFFUSE, CreateWhiteTexture())
    particleMaterial_:SetShaderParameter("MatDiffColor", Variant(Color(1, 1, 1, 1)))
    particleSet_:SetMaterial(particleMaterial_)
    for i = 0, PARTICLE_SLOTS - 1 do
        particleSet_:GetBillboard(i).enabled = false
    end
    particleSet_:Commit()

    -- Box.mdl 仅用于可选碎片；飞散箱体已是程序化六面体，缺它绝不能导致整层初始化失败
    -- （否则 Backend.Init 返回 false，Start 不订阅 Update/NanoVGRender，表现为 UI 全黑且输入无响应）。
    local initialized = voxelMaterial_ ~= nil and crateMaterial_ ~= nil
    initialized_ = initialized
    print("[Renderer3D] initialized, aircraft_crates=true, hidden_brick_hp=true, dayun_heavy_trucks=true")
    return initialized_
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

function Renderer3D.Render(game, presentation)
    if not initialized_ then return end

    local elapsed = game.elapsed or 0
    local dt = 1 / 60
    if lastRenderElapsed_ then
        if elapsed >= lastRenderElapsed_ then
            dt = math.min(elapsed - lastRenderElapsed_, 0.05)
        end
    end
    lastRenderElapsed_ = elapsed

    SyncEnemyMeshes(game, presentation)
    SyncVehicles(game, dt)
    SyncDebris(presentation)
    SyncEjectedBoxes(presentation)
    SyncParticles(presentation)
end

function Renderer3D.Shutdown()
    for _, record in pairs(vehicleRecords_) do RemoveNode(record.root) end
    for _, record in pairs(enemyMeshes_) do RemoveNode(record.root) end
    for _, node in pairs(debrisNodes_) do RemoveNode(node) end
    for _, node in pairs(ejectedBoxNodes_) do RemoveNode(node) end
    if particleNode_ then RemoveNode(particleNode_) end
    if particleSet_ then DisposeComponent(particleSet_) end
    if particleMaterial_ then particleMaterial_:Dispose() end
    particleNode_ = nil
    particleSet_ = nil
    particleMaterial_ = nil
    vehicleRecords_ = {}
    enemyMeshes_ = {}
    debrisNodes_ = {}
    ejectedBoxNodes_ = {}
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
