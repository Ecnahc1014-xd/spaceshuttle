-- Renderer3D.lua
-- 只读消费 Game / Presentation 快照，将彩色体素敌人、体素车辆、拖尾和碎片同步到 3D 场景。

local Renderer3D = {}

local WORLD_SCALE = 0.018
local DESIGN_CENTER_X = 270
local DESIGN_CENTER_Y = 480
local VOXEL_GAP = 0.92
local VOXEL_DEPTH = 0.72
local VEHICLE_VOXEL_SIZE = 0.18

---@type Scene
local scene_ = nil
---@type Model
local modelBox_ = nil
---@type Material
local voxelMaterial_ = nil
---@type Material
local trailMaterial_ = nil
local materialCache_ = {}
local enemyMeshes_ = {}
local vehicleRecords_ = {}
local trailRecords_ = {}
local debrisNodes_ = {}
local initialized_ = false

local BALL_COLORS = {
    normal = {1.00, 0.72, 0.12},
    ice = {0.18, 0.78, 1.00},
    speed = {1.00, 0.18, 0.035},
    giant = {0.64, 0.20, 1.00},
}

local VEHICLE_PALETTES = {
    normal = {
        body = {0.98, 0.58, 0.08}, accent = {1.00, 0.92, 0.24},
        glass = {0.12, 0.34, 0.48}, cargo = {0.58, 0.24, 0.04},
    },
    ice = {
        body = {0.10, 0.66, 0.94}, accent = {0.62, 0.96, 1.00},
        glass = {0.06, 0.20, 0.40}, cargo = {0.12, 0.44, 0.72},
    },
    speed = {
        body = {0.94, 0.10, 0.025}, accent = {1.00, 0.72, 0.08},
        glass = {0.18, 0.10, 0.18}, cargo = {0.54, 0.035, 0.02},
    },
    giant = {
        body = {0.52, 0.10, 0.90}, accent = {0.92, 0.54, 1.00},
        glass = {0.16, 0.08, 0.30}, cargo = {0.30, 0.04, 0.58},
    },
}

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

local function RemoveNode(node)
    if node then node:Remove() end
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
        local style = visualCatalog.GetBrickStyle(enemy.veggieKey, brick.col, brick.row)
        if style then
            return FrozenColor({style.r / 255, style.g / 255, style.b / 255}, enemy.frozen > 0)
        end
    end
    return FrozenColor({0.72, 0.32, 0.18}, enemy.frozen > 0)
end

local function GetEnemySignature(enemy)
    local parts = {enemy.frozen > 0 and "F" or "N"}
    for _, brick in ipairs(enemy.bricks) do
        parts[#parts + 1] = brick.alive and "1" or "0"
    end
    return table.concat(parts)
end

local function EmitQuad(geometry, v1, v2, v3, v4, normal, color)
    local vertices = {v1, v2, v3, v1, v3, v4}
    for _, vertex in ipairs(vertices) do
        geometry:DefineVertex(vertex)
        geometry:DefineNormal(normal)
        geometry:DefineColor(color)
    end
end

-- 体素敌人只创建一个根节点和一个 CustomGeometry。
-- 根节点随敌人移动，网格只在砖块拓扑或冰冻状态变化时重建。
local function RebuildEnemyMesh(record, enemy, visualCatalog)
    local geometry = record.geometry
    geometry:Clear()
    geometry:SetNumGeometries(1)
    geometry:SetDynamic(false)
    geometry:BeginGeometry(0, TRIANGLE_LIST)

    local alive = {}
    for _, brick in ipairs(enemy.bricks) do
        if brick.alive then
            alive[brick.col .. ":" .. brick.row] = brick
        end
    end

    local voxelSize = enemy.brickSize * WORLD_SCALE * VOXEL_GAP
    local halfDepth = voxelSize * VOXEL_DEPTH * 0.5
    for _, brick in ipairs(enemy.bricks) do
        if brick.alive then
            local x0 = (brick.col - 1) * voxelSize
            local x1 = x0 + voxelSize
            local y1 = -(brick.row - 1) * voxelSize
            local y0 = y1 - voxelSize
            local z0 = -halfDepth
            local z1 = halfDepth
            local rgb = GetBrickColor(enemy, brick, visualCatalog)
            local hasLeft = alive[(brick.col - 1) .. ":" .. brick.row] ~= nil
            local hasRight = alive[(brick.col + 1) .. ":" .. brick.row] ~= nil
            local hasTop = alive[brick.col .. ":" .. (brick.row - 1)] ~= nil
            local hasBottom = alive[brick.col .. ":" .. (brick.row + 1)] ~= nil

            -- 正面颜色必须走支持 vertex color 的 DiffVCol technique。
            EmitQuad(geometry, Vector3(x1, y0, z0), Vector3(x0, y0, z0),
                Vector3(x0, y1, z0), Vector3(x1, y1, z0),
                Vector3(0, 0, -1), ShadeColor(rgb, 1.0))
            EmitQuad(geometry, Vector3(x0, y0, z1), Vector3(x1, y0, z1),
                Vector3(x1, y1, z1), Vector3(x0, y1, z1),
                Vector3(0, 0, 1), ShadeColor(rgb, 0.56))
            if not hasLeft then
                EmitQuad(geometry, Vector3(x0, y0, z1), Vector3(x0, y1, z1),
                    Vector3(x0, y1, z0), Vector3(x0, y0, z0),
                    Vector3(-1, 0, 0), ShadeColor(rgb, 0.72))
            end
            if not hasRight then
                EmitQuad(geometry, Vector3(x1, y0, z0), Vector3(x1, y1, z0),
                    Vector3(x1, y1, z1), Vector3(x1, y0, z1),
                    Vector3(1, 0, 0), ShadeColor(rgb, 0.86))
            end
            if not hasTop then
                EmitQuad(geometry, Vector3(x0, y1, z0), Vector3(x0, y1, z1),
                    Vector3(x1, y1, z1), Vector3(x1, y1, z0),
                    Vector3(0, 1, 0), ShadeColor(rgb, 0.90))
            end
            if not hasBottom then
                EmitQuad(geometry, Vector3(x0, y0, z1), Vector3(x0, y0, z0),
                    Vector3(x1, y0, z0), Vector3(x1, y0, z1),
                    Vector3(0, -1, 0), ShadeColor(rgb, 0.68))
            end
        end
    end

    geometry:Commit()
    geometry:SetMaterial(voxelMaterial_)
    record.signature = GetEnemySignature(enemy)
end

local function SyncEnemyMeshes(game, presentation)
    local active = {}
    local visualCatalog = presentation.visualCatalog
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
                RebuildEnemyMesh(record, enemy, visualCatalog)
            elseif record.signature ~= GetEnemySignature(enemy) then
                RebuildEnemyMesh(record, enemy, visualCatalog)
            end
            record.root.position = GameToWorld(enemy.x, enemy.y, 0)
        end
    end

    for id, record in pairs(enemyMeshes_) do
        if not active[id] then
            RemoveNode(record.root)
            enemyMeshes_[id] = nil
        end
    end
end

local function CellKey(x, y, z)
    return tostring(x) .. ":" .. tostring(y) .. ":" .. tostring(z)
end

local function BuildVehicleCells(ballType)
    local palette = VEHICLE_PALETTES[ballType] or VEHICLE_PALETTES.normal
    local cells = {}

    local function SetCell(x, y, z, color)
        local key = CellKey(x, y, z)
        local cell = cells[key]
        if cell then
            cell.color = color
        else
            cells[key] = {x = x, y = y, z = z, color = color}
        end
    end

    -- 车辆局部 +X 为车头。所有部件落在统一体素网格，最终合并成一个网格。
    for x = -4, 4 do
        for y = -2, 2 do
            if not (math.abs(x) == 4 and math.abs(y) == 2) then
                SetCell(x, y, 0, palette.body)
            end
        end
    end
    for x = -3, 3 do
        for y = -2, 2 do
            if not (math.abs(x) == 3 and math.abs(y) == 2) then
                local color = x <= -2 and palette.cargo or palette.body
                SetCell(x, y, -1, color)
            end
        end
    end

    -- 驾驶舱、顶窗与车型识别条。
    for x = -1, 1 do
        for y = -1, 1 do
            SetCell(x, y, -2, palette.accent)
        end
    end
    for y = -1, 1 do
        SetCell(2, y, -2, palette.glass)
        SetCell(-2, y, -2, palette.glass)
    end
    for x = -1, 1 do
        SetCell(x, -2, -2, palette.glass)
        SetCell(x, 2, -2, palette.glass)
    end
    SetCell(0, 0, -3, palette.accent)

    -- 前后保险杠、车灯和货斗边框。
    for y = -1, 1 do
        SetCell(5, y, 0, palette.body)
        SetCell(-5, y, 0, palette.cargo)
    end
    SetCell(5, -1, -1, HEADLIGHT_COLOR)
    SetCell(5, 1, -1, HEADLIGHT_COLOR)
    SetCell(-5, -1, -1, TAILLIGHT_COLOR)
    SetCell(-5, 1, -1, TAILLIGHT_COLOR)
    for y = -2, 2, 4 do
        SetCell(-3, y, -2, palette.accent)
        SetCell(-2, y, -2, palette.accent)
    end

    -- 四组外凸轮胎和轮毂，让俯视轮廓一眼可辨。
    for _, wheelX in ipairs({-3, 2}) do
        for _, wheelY in ipairs({-3, 3}) do
            SetCell(wheelX, wheelY, 0, WHEEL_COLOR)
            SetCell(wheelX + 1, wheelY, 0, WHEEL_COLOR)
            SetCell(wheelX, wheelY, -1, HUB_COLOR)
        end
    end

    return cells
end

local function RebuildVehicleGeometry(geometry, ballType)
    local cells = BuildVehicleCells(ballType)
    local half = VEHICLE_VOXEL_SIZE * 0.5
    geometry:Clear()
    geometry:SetNumGeometries(1)
    geometry:SetDynamic(false)
    geometry:BeginGeometry(0, TRIANGLE_LIST)

    for _, cell in pairs(cells) do
        local cx = cell.x * VEHICLE_VOXEL_SIZE
        local cy = cell.y * VEHICLE_VOXEL_SIZE
        local cz = cell.z * VEHICLE_VOXEL_SIZE
        for _, face in ipairs(FACE_DEFS) do
            local neighbor = face.neighbor
            if not cells[CellKey(cell.x + neighbor[1], cell.y + neighbor[2], cell.z + neighbor[3])] then
                local corners = {}
                for i, corner in ipairs(face.corners) do
                    corners[i] = Vector3(
                        cx + corner[1] * half,
                        cy + corner[2] * half,
                        cz + corner[3] * half
                    )
                end
                EmitQuad(geometry, corners[1], corners[2], corners[3], corners[4],
                    face.normal, ShadeColor(cell.color, face.tint))
            end
        end
    end

    geometry:Commit()
    geometry:SetMaterial(voxelMaterial_)
end

local function CreateVehicleRecord(id, marble)
    local root = scene_:CreateChild("VoxelVehicle_" .. tostring(id))
    local geometry = root:CreateComponent("CustomGeometry")
    geometry.castShadows = false
    RebuildVehicleGeometry(geometry, marble.ballType)
    return {
        root = root,
        geometry = geometry,
        ballType = marble.ballType,
        heading = 0,
    }
end

local function SyncVehicles(game)
    local active = {}
    local function SyncOne(marble)
        active[marble.id] = true
        local record = vehicleRecords_[marble.id]
        if not record then
            record = CreateVehicleRecord(marble.id, marble)
            vehicleRecords_[marble.id] = record
        elseif record.ballType ~= marble.ballType then
            record.ballType = marble.ballType
            RebuildVehicleGeometry(record.geometry, marble.ballType)
        end

        record.root.position = GameToWorld(marble.x, marble.y, -0.28)
        local worldVx = marble.vx * WORLD_SCALE
        local worldVy = -marble.vy * WORLD_SCALE
        if worldVx * worldVx + worldVy * worldVy > 0.0001 then
            record.heading = math.deg(math.atan(worldVy, worldVx))
        end
        record.root.rotation = Quaternion(record.heading, Vector3(0, 0, 1))

        local scaleFactor = marble.radius / 9.0
        if not marble.isPrimary then scaleFactor = scaleFactor * 0.78 end
        if marble.ballType == "giant" then scaleFactor = scaleFactor * 1.12 end
        record.root.scale = Vector3(scaleFactor, scaleFactor, scaleFactor)
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

local function TrailPoint(x, y)
    local p = GameToWorld(x, y, -0.08)
    return {x = p.x, y = p.y}
end

local function DefineTrailVertex(geometry, point, z, color)
    geometry:DefineVertex(Vector3(point.x, point.y, z))
    geometry:DefineNormal(Vector3(0, 0, -1))
    geometry:DefineColor(color)
end

local function RebuildTrailGeometry(record, marble, trail)
    local points = {TrailPoint(marble.x, marble.y)}
    for _, point in ipairs(trail or {}) do
        local converted = TrailPoint(point.x, point.y)
        local previous = points[#points]
        local dx = converted.x - previous.x
        local dy = converted.y - previous.y
        if dx * dx + dy * dy > 0.00002 then
            points[#points + 1] = converted
        end
    end

    local geometry = record.geometry
    geometry:Clear()
    if #points < 2 then return end

    geometry:SetNumGeometries(2)
    geometry:SetDynamic(true)
    local rgb = BALL_COLORS[marble.ballType] or BALL_COLORS.normal
    local baseWidth = (marble.ballType == "giant" and 0.19 or 0.115)
        * math.max(0.72, marble.radius / 9.0)

    local function EmitLayer(index, widthScale, core)
        geometry:BeginGeometry(index, TRIANGLE_LIST)
        for i = 1, #points - 1 do
            local p0 = points[i]
            local p1 = points[i + 1]
            local dx = p1.x - p0.x
            local dy = p1.y - p0.y
            local length = math.sqrt(dx * dx + dy * dy)
            if length > 0.0001 then
                local nx = -dy / length
                local ny = dx / length
                local t0 = (i - 1) / (#points - 1)
                local t1 = i / (#points - 1)
                local w0 = baseWidth * widthScale * (1.0 - t0 * 0.78)
                local w1 = baseWidth * widthScale * (1.0 - t1 * 0.78)
                local brightness0 = 0.12 + 0.88 * (1.0 - t0)
                local brightness1 = 0.12 + 0.88 * (1.0 - t1)
                local function MakeColor(brightness)
                    if core then
                        return Color(
                            math.min(1.0, rgb[1] * brightness + 0.34 * brightness),
                            math.min(1.0, rgb[2] * brightness + 0.34 * brightness),
                            math.min(1.0, rgb[3] * brightness + 0.34 * brightness), 1)
                    end
                    return Color(rgb[1] * brightness, rgb[2] * brightness,
                        rgb[3] * brightness, 1)
                end
                local a = {x = p0.x + nx * w0, y = p0.y + ny * w0}
                local b = {x = p0.x - nx * w0, y = p0.y - ny * w0}
                local c = {x = p1.x - nx * w1, y = p1.y - ny * w1}
                local d = {x = p1.x + nx * w1, y = p1.y + ny * w1}
                local c0 = MakeColor(brightness0)
                local c1 = MakeColor(brightness1)
                DefineTrailVertex(geometry, a, -0.08, c0)
                DefineTrailVertex(geometry, b, -0.08, c0)
                DefineTrailVertex(geometry, c, -0.08, c1)
                DefineTrailVertex(geometry, a, -0.08, c0)
                DefineTrailVertex(geometry, c, -0.08, c1)
                DefineTrailVertex(geometry, d, -0.08, c1)
            end
        end
    end

    EmitLayer(0, 1.0, false)
    EmitLayer(1, 0.34, true)
    geometry:Commit()
    geometry:SetMaterial(0, trailMaterial_)
    geometry:SetMaterial(1, trailMaterial_)
end

local function SyncVehicleTrails(game, presentation)
    local active = {}
    for _, marble in ipairs(game.marbles) do
        active[marble.id] = true
        local record = trailRecords_[marble.id]
        if not record then
            local root = scene_:CreateChild("VehicleTrail_" .. tostring(marble.id))
            local geometry = root:CreateComponent("CustomGeometry")
            geometry.castShadows = false
            record = {root = root, geometry = geometry}
            trailRecords_[marble.id] = record
        end
        RebuildTrailGeometry(record, marble, presentation.marbleTrails[marble.id])
    end

    for id, record in pairs(trailRecords_) do
        if not active[id] then
            RemoveNode(record.root)
            trailRecords_[id] = nil
        end
    end
end

local function SyncDebris(presentation)
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

local function CreateWhiteTexture()
    local image = Image()
    image:SetSize(1, 1, 4)
    image:SetPixel(0, 0, Color(1, 1, 1, 1))
    local texture = Texture2D:new()
    texture:SetData(image, false)
    texture:SetSRGB(true)
    return texture
end

function Renderer3D.Init(scene)
    scene_ = scene
    modelBox_ = cache:GetResource("Model", "Models/Box.mdl")

    voxelMaterial_ = Material:new()
    voxelMaterial_:SetTechnique(0,
        cache:GetResource("Technique", "Techniques/DiffVCol.xml"))
    voxelMaterial_:SetTexture(TU_DIFFUSE, CreateWhiteTexture())
    voxelMaterial_:SetShaderParameter("MatDiffColor", Variant(Color(1, 1, 1, 1)))

    trailMaterial_ = Material:new()
    trailMaterial_:SetTechnique(0,
        cache:GetResource("Technique", "Techniques/DiffVCol.xml"))
    trailMaterial_:SetTexture(TU_DIFFUSE, CreateWhiteTexture())
    trailMaterial_:SetShaderParameter("MatDiffColor", Variant(Color(1, 1, 1, 1)))
    trailMaterial_:SetCullMode(CULL_NONE)

    initialized_ = modelBox_ ~= nil and voxelMaterial_ ~= nil and trailMaterial_ ~= nil
    print("[Renderer3D] initialized, colored_voxels=" .. tostring(initialized_)
        .. ", voxel_vehicles=true, world_trails=true")
    return initialized_
end

function Renderer3D.Render(game, presentation)
    if not initialized_ then return end
    SyncEnemyMeshes(game, presentation)
    SyncVehicleTrails(game, presentation)
    SyncVehicles(game)
    SyncDebris(presentation)
end

function Renderer3D.Shutdown()
    for _, record in pairs(vehicleRecords_) do RemoveNode(record.root) end
    for _, record in pairs(trailRecords_) do RemoveNode(record.root) end
    for _, record in pairs(enemyMeshes_) do RemoveNode(record.root) end
    for _, node in pairs(debrisNodes_) do RemoveNode(node) end
    vehicleRecords_ = {}
    trailRecords_ = {}
    enemyMeshes_ = {}
    debrisNodes_ = {}
    materialCache_ = {}
    scene_ = nil
    modelBox_ = nil
    voxelMaterial_ = nil
    trailMaterial_ = nil
    initialized_ = false
end

return Renderer3D
