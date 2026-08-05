-- Renderer3D.lua
-- 只读消费 Game / Presentation 快照，将体素敌人、车辆和碎片同步到 3D 场景。

local Renderer3D = {}

local WORLD_SCALE = 0.018
local DESIGN_CENTER_X = 270
local DESIGN_CENTER_Y = 480
local VOXEL_GAP = 0.92
local VOXEL_DEPTH = 0.72
local VEHICLE_MODEL_PATH = "model/6d5f1062-5bea-5cf8-a404-280333d4d4c8/Meshes/d257606d8f6d47eea5dfa8c0dba564fa.mdl"
local VEHICLE_DIFFUSE_PATH = "model/6d5f1062-5bea-5cf8-a404-280333d4d4c8/Textures/d257606d8f6d47eea5dfa8c0dba564fa_00_D.jpg"
local VEHICLE_NORMAL_PATH = "model/6d5f1062-5bea-5cf8-a404-280333d4d4c8/Textures/d257606d8f6d47eea5dfa8c0dba564fa_00_N.jpg"

local scene_ = nil
local modelBox_ = nil
local vehicleModel_ = nil
local voxelMaterial_ = nil
local materialCache_ = {}
local vehicleMaterials_ = {}
local enemyMeshes_ = {}
local vehicleNodes_ = {}
local debrisNodes_ = {}
local initialized_ = false

local BALL_COLORS = {
    normal = {1.0, 0.82, 0.25},
    ice = {0.35, 0.82, 1.0},
    speed = {1.0, 0.28, 0.08},
    giant = {0.72, 0.35, 1.0},
}

local function ToColor(rgb, alpha)
    return Color(rgb[1], rgb[2], rgb[3], alpha or 1.0)
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
    local function EmitQuad(v1, v2, v3, v4, normal, color)
        local vertices = {v1, v2, v3, v1, v3, v4}
        for _, vertex in ipairs(vertices) do
            geometry:DefineVertex(vertex)
            geometry:DefineNormal(normal)
            geometry:DefineColor(color)
        end
    end

    for _, brick in ipairs(enemy.bricks) do
        if brick.alive then
            local x0 = (brick.col - 1) * voxelSize
            local x1 = x0 + voxelSize
            local y1 = -(brick.row - 1) * voxelSize
            local y0 = y1 - voxelSize
            local z0 = -halfDepth
            local z1 = halfDepth
            local color = ToColor(GetBrickColor(enemy, brick, visualCatalog))
            local hasLeft = alive[(brick.col - 1) .. ":" .. brick.row] ~= nil
            local hasRight = alive[(brick.col + 1) .. ":" .. brick.row] ~= nil
            local hasTop = alive[brick.col .. ":" .. (brick.row - 1)] ~= nil
            local hasBottom = alive[brick.col .. ":" .. (brick.row + 1)] ~= nil

            -- 正面/背面维持每格颜色；相邻砖块之间的侧面全部剔除。
            EmitQuad(Vector3(x1, y0, z0), Vector3(x0, y0, z0),
                Vector3(x0, y1, z0), Vector3(x1, y1, z0),
                Vector3(0, 0, -1), color)
            EmitQuad(Vector3(x0, y0, z1), Vector3(x1, y0, z1),
                Vector3(x1, y1, z1), Vector3(x0, y1, z1),
                Vector3(0, 0, 1), color)
            if not hasLeft then
                EmitQuad(Vector3(x0, y0, z1), Vector3(x0, y1, z1),
                    Vector3(x0, y1, z0), Vector3(x0, y0, z0),
                    Vector3(-1, 0, 0), color)
            end
            if not hasRight then
                EmitQuad(Vector3(x1, y0, z0), Vector3(x1, y1, z0),
                    Vector3(x1, y1, z1), Vector3(x1, y0, z1),
                    Vector3(1, 0, 0), color)
            end
            if not hasTop then
                EmitQuad(Vector3(x0, y1, z0), Vector3(x0, y1, z1),
                    Vector3(x1, y1, z1), Vector3(x1, y1, z0),
                    Vector3(0, 1, 0), color)
            end
            if not hasBottom then
                EmitQuad(Vector3(x0, y0, z1), Vector3(x0, y0, z0),
                    Vector3(x1, y0, z0), Vector3(x1, y0, z1),
                    Vector3(0, -1, 0), color)
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

local function CreateVehicleMaterial(ballType)
    if vehicleMaterials_[ballType] then return vehicleMaterials_[ballType] end
    local rgb = BALL_COLORS[ballType] or BALL_COLORS.normal
    local material = Material:new()
    material:SetTechnique(0,
        cache:GetResource("Technique", "Techniques/PBR/PBRDiffNormal.xml"))
    material:SetTexture(TU_DIFFUSE, cache:GetResource("Texture2D", VEHICLE_DIFFUSE_PATH))
    material:SetTexture(TU_NORMAL, cache:GetResource("Texture2D", VEHICLE_NORMAL_PATH))
    material:SetShaderParameter("MatDiffColor", Variant(Color(
        math.min(1.0, rgb[1] * 0.92 + 0.08),
        math.min(1.0, rgb[2] * 0.92 + 0.08),
        math.min(1.0, rgb[3] * 0.92 + 0.08), 1.0)))
    material:SetShaderParameter("Metallic", Variant(0.25))
    material:SetShaderParameter("Roughness", Variant(0.58))
    vehicleMaterials_[ballType] = material
    return material
end

-- 每个 marble.id 对应一个完整车辆模型；待发射、飞行、反弹和分裂对象均走同一同步路径。
local function CreateVehicleNode(id, marble)
    local node = scene_:CreateChild("Vehicle_" .. tostring(id))
    local model = node:CreateComponent("StaticModel")
    model:SetModel(vehicleModel_)
    model:SetMaterial(CreateVehicleMaterial(marble.ballType))
    model.castShadows = false
    return node
end

local function SyncVehicles(game)
    local active = {}
    local function SyncOne(marble)
        active[marble.id] = true
        local node = vehicleNodes_[marble.id]
        if not node then
            node = CreateVehicleNode(marble.id, marble)
            vehicleNodes_[marble.id] = node
        end
        node.position = GameToWorld(marble.x, marble.y, -0.25)
        local worldVx = marble.vx * WORLD_SCALE
        local worldVy = -marble.vy * WORLD_SCALE
        local speedSq = worldVx * worldVx + worldVy * worldVy
        local record = node:GetVar("vehicleHeading")
        local heading = record and record:GetFloat() or 0
        if speedSq > 0.0001 then
            heading = math.deg(math.atan(worldVy, worldVx))
            node:SetVar("vehicleHeading", Variant(heading))
        end
        node.rotation = Quaternion(heading, Vector3(0, 0, 1))

        local scaleFactor = marble.radius / 9.0
        if not marble.isPrimary then scaleFactor = scaleFactor * 0.68 end
        if marble.ballType == "giant" then scaleFactor = scaleFactor * 1.18 end
        local worldScale = 0.72 * scaleFactor
        node.scale = Vector3(worldScale, worldScale, worldScale)
    end

    if game.activeBall then SyncOne(game.activeBall) end
    for _, marble in ipairs(game.marbles) do SyncOne(marble) end

    for id, node in pairs(vehicleNodes_) do
        if not active[id] then
            RemoveNode(node)
            vehicleNodes_[id] = nil
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

function Renderer3D.Init(scene)
    scene_ = scene
    modelBox_ = cache:GetResource("Model", "Models/Box.mdl")
    vehicleModel_ = cache:GetResource("Model", VEHICLE_MODEL_PATH)
    voxelMaterial_ = Material:new()
    voxelMaterial_:SetTechnique(0,
        cache:GetResource("Technique", "Techniques/NoTextureUnlit.xml"))
    initialized_ = modelBox_ ~= nil and vehicleModel_ ~= nil and voxelMaterial_ ~= nil
    print("[Renderer3D] initialized, merged_voxels=" .. tostring(initialized_)
        .. ", vehicle_model=" .. tostring(vehicleModel_ ~= nil))
    return initialized_
end

function Renderer3D.Render(game, presentation)
    if not initialized_ then return end
    SyncEnemyMeshes(game, presentation)
    SyncVehicles(game)
    SyncDebris(presentation)
end

function Renderer3D.Shutdown()
    for _, node in pairs(vehicleNodes_) do RemoveNode(node) end
    for _, record in pairs(enemyMeshes_) do RemoveNode(record.root) end
    for _, node in pairs(debrisNodes_) do RemoveNode(node) end
    vehicleNodes_ = {}
    enemyMeshes_ = {}
    debrisNodes_ = {}
    materialCache_ = {}
    vehicleMaterials_ = {}
    scene_ = nil
    modelBox_ = nil
    vehicleModel_ = nil
    voxelMaterial_ = nil
    initialized_ = false
end

return Renderer3D
