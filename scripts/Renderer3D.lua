-- Renderer3D.lua
-- 只读消费 Game / Presentation 快照，将敌人、弹珠、碎片和四辆运输车同步到 3D 场景。

local Renderer3D = {}

local WORLD_SCALE = 0.018
local DESIGN_CENTER_X = 270
local DESIGN_CENTER_Y = 480
local VOXEL_GAP = 0.92

local scene_ = nil
local modelBox_ = nil
local modelSphere_ = nil
local modelCylinder_ = nil
local materialCache_ = {}
local brickNodes_ = {}
local marbleNodes_ = {}
local debrisNodes_ = {}
local trucks_ = {}
local initialized_ = false

local BALL_COLORS = {
    normal = {1.0, 0.82, 0.25},
    ice = {0.35, 0.82, 1.0},
    speed = {1.0, 0.28, 0.08},
    giant = {0.72, 0.35, 1.0},
}

local TRUCK_CONFIG = {
    normal = {x = -3.6, color = {0.92, 0.58, 0.12}, label = "分裂"},
    ice = {x = -1.2, color = {0.20, 0.68, 0.95}, label = "冰冻"},
    speed = {x = 1.2, color = {0.95, 0.20, 0.08}, label = "加速"},
    giant = {x = 3.6, color = {0.62, 0.22, 0.92}, label = "巨型"},
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

local function GetMaterialKey(rgb, metallic, roughness)
    return string.format("%.3f_%.3f_%.3f_%.2f_%.2f",
        rgb[1], rgb[2], rgb[3], metallic or 0, roughness or 0.5)
end

local function CreateMaterial(rgb, metallic, roughness, emissive)
    local key = GetMaterialKey(rgb, metallic, roughness) .. (emissive and "_e" or "")
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

local function CreatePart(parent, name, model, position, scale, material, castShadows)
    local node = parent:CreateChild(name)
    node.position = position
    node.scale = scale
    local staticModel = node:CreateComponent("StaticModel")
    staticModel:SetModel(model)
    staticModel:SetMaterial(material)
    staticModel.castShadows = castShadows ~= false
    return node
end

local function RemoveNode(node)
    if node then node:Remove() end
end

local function SetVoxelMaterial(record, rgb, frozen)
    local color = rgb
    if frozen then
        color = {
            math.min(1.0, rgb[1] * 0.45 + 0.35),
            math.min(1.0, rgb[2] * 0.45 + 0.45),
            math.min(1.0, rgb[3] * 0.45 + 0.55),
        }
    end
    local model = record.node:GetComponent("StaticModel")
    model:SetMaterial(CreateMaterial(color, 0.0, 0.72))
    record.frozen = frozen
end

local function CreateVoxelNode(key, x, y, size, rgb, frozen)
    local node = scene_:CreateChild("Voxel_" .. key)
    node.position = GameToWorld(x, y, 0)
    node.scale = Vector3(
        size * WORLD_SCALE * VOXEL_GAP,
        size * WORLD_SCALE * VOXEL_GAP,
        size * WORLD_SCALE * VOXEL_GAP)
    local color = rgb
    if frozen then
        color = {
            math.min(1.0, rgb[1] * 0.45 + 0.35),
            math.min(1.0, rgb[2] * 0.45 + 0.45),
            math.min(1.0, rgb[3] * 0.45 + 0.55),
        }
    end
    local model = node:CreateComponent("StaticModel")
    model:SetModel(modelBox_)
    model:SetMaterial(CreateMaterial(color, 0.0, 0.72))
    model.castShadows = true
    return node
end

local function SyncVoxels(game, presentation)
    local active = {}
    local visualCatalog = presentation.visualCatalog
    for _, enemy in ipairs(game.veggies) do
        local veggieStyle = game.visualCatalog and game.visualCatalog[enemy.veggieKey]
        for _, brick in ipairs(enemy.bricks) do
            if brick.alive then
                local key = tostring(enemy.id) .. ":" .. tostring(brick.col) .. ":" .. tostring(brick.row)
                active[key] = true
                local rgb = {0.72, 0.32, 0.18}
                if visualCatalog and visualCatalog.GetBrickStyle then
                    local style = visualCatalog.GetBrickStyle(enemy.veggieKey, brick.col, brick.row)
                    if style then
                        rgb = {style.r / 255, style.g / 255, style.b / 255}
                    end
                end
                local x = enemy.x + (brick.col - 0.5) * enemy.brickSize
                local y = enemy.y + (brick.row - 0.5) * enemy.brickSize
                local record = brickNodes_[key]
                if not record then
                    record = {
                        node = CreateVoxelNode(key, x, y,
                            enemy.brickSize, rgb, enemy.frozen > 0),
                        frozen = enemy.frozen > 0,
                    }
                    brickNodes_[key] = record
                else
                    record.node.position = GameToWorld(x, y, 0)
                    record.node.scale = Vector3(
                        enemy.brickSize * WORLD_SCALE * VOXEL_GAP,
                        enemy.brickSize * WORLD_SCALE * VOXEL_GAP,
                        enemy.brickSize * WORLD_SCALE * VOXEL_GAP)
                    if record.frozen ~= (enemy.frozen > 0) then
                        SetVoxelMaterial(record, rgb, enemy.frozen > 0)
                    end
                end
            end
        end
    end

    for key, record in pairs(brickNodes_) do
        if not active[key] then
            RemoveNode(record.node)
            brickNodes_[key] = nil
        end
    end
end

local function CreateMarbleNode(id, marble)
    local node = scene_:CreateChild("Marble_" .. tostring(id))
    node.position = GameToWorld(marble.x, marble.y, -0.2)
    local diameter = marble.radius * WORLD_SCALE * 2.0
    node.scale = Vector3(diameter, diameter, diameter)
    local rgb = BALL_COLORS[marble.ballType] or BALL_COLORS.normal
    local model = node:CreateComponent("StaticModel")
    model:SetModel(modelSphere_)
    model:SetMaterial(CreateMaterial(rgb, 0.15, 0.24, {
        rgb[1] * 0.65, rgb[2] * 0.65, rgb[3] * 0.65,
    }))
    model.castShadows = true
    return node
end

local function SyncMarbles(game)
    local active = {}
    local function SyncOne(marble)
        active[marble.id] = true
        local node = marbleNodes_[marble.id]
        if not node then
            node = CreateMarbleNode(marble.id, marble)
            marbleNodes_[marble.id] = node
        end
        node.position = GameToWorld(marble.x, marble.y, -0.2)
        local diameter = marble.radius * WORLD_SCALE * 2.0
        node.scale = Vector3(diameter, diameter, diameter)
    end

    if game.activeBall then SyncOne(game.activeBall) end
    for _, marble in ipairs(game.marbles) do SyncOne(marble) end

    for id, node in pairs(marbleNodes_) do
        if not active[id] then
            RemoveNode(node)
            marbleNodes_[id] = nil
        end
    end
end

local function CreateTruck(ballType, config)
    local root = scene_:CreateChild("Truck_" .. ballType)
    local baseY = -7.28
    root.position = Vector3(config.x, baseY, -0.45)
    local bodyMat = CreateMaterial(config.color, 0.35, 0.42)
    local darkMat = CreateMaterial({0.08, 0.09, 0.12}, 0.75, 0.28)
    local tireMat = CreateMaterial({0.025, 0.025, 0.03}, 0.0, 0.88)
    local lampMat = CreateMaterial(config.color, 0.1, 0.22,
        {config.color[1] * 1.2, config.color[2] * 1.2, config.color[3] * 1.2})

    CreatePart(root, "Chassis", modelBox_, Vector3(0, 0.18, 0),
        Vector3(1.75, 0.30, 0.72), darkMat)
    CreatePart(root, "Cargo", modelBox_, Vector3(-0.34, 0.62, 0),
        Vector3(1.18, 0.75, 0.68), bodyMat)
    CreatePart(root, "Cab", modelBox_, Vector3(0.72, 0.52, 0),
        Vector3(0.55, 0.62, 0.68), bodyMat)
    CreatePart(root, "Bumper", modelBox_, Vector3(1.02, 0.22, 0),
        Vector3(0.16, 0.20, 0.74), darkMat)

    for _, wheelX in ipairs({-0.62, 0.64}) do
        for _, wheelZ in ipairs({-0.38, 0.38}) do
            local wheel = CreatePart(root, "Wheel", modelCylinder_,
                Vector3(wheelX, 0.02, wheelZ), Vector3(0.28, 0.16, 0.28), tireMat)
            wheel.rotation = Quaternion(90, Vector3(1, 0, 0))
        end
    end

    local launcher = CreatePart(root, "Launcher", modelCylinder_,
        Vector3(0.05, 1.18, 0), Vector3(0.18, 0.62, 0.18), darkMat)
    launcher.rotation = Quaternion(0, Vector3(0, 0, 1))
    local lamp = CreatePart(root, "ActiveLamp", modelSphere_,
        Vector3(0.05, 1.62, 0), Vector3(0.16, 0.16, 0.16), lampMat, false)
    return {root = root, lamp = lamp, basePosition = root.position,
        launchOffset = 0, ballType = ballType}
end

local function SyncTrucks(game, presentation)
    if #trucks_ == 0 then
        for _, ballType in ipairs({"normal", "ice", "speed", "giant"}) do
            trucks_[ballType] = CreateTruck(ballType, TRUCK_CONFIG[ballType])
        end
    end

    local activeType = game.activeBall and game.activeBall.ballType or nil
    for ballType, truck in pairs(trucks_) do
        local flash = presentation.truckLaunchFlash[ballType] or 0
        local pulse = flash > 0 and math.sin((0.28 - flash) * 35) * 0.08 or 0
        local selected = ballType == activeType
        truck.root.position = truck.basePosition + Vector3(0, pulse, 0)
        truck.lamp.scale = Vector3(
            selected and 0.23 or 0.13,
            selected and 0.23 or 0.13,
            selected and 0.23 or 0.13)
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
    modelSphere_ = cache:GetResource("Model", "Models/Sphere.mdl")
    modelCylinder_ = cache:GetResource("Model", "Models/Cylinder.mdl")
    initialized_ = modelBox_ ~= nil and modelSphere_ ~= nil and modelCylinder_ ~= nil
    print("[Renderer3D] initialized, primitives=" .. tostring(initialized_))
    return initialized_
end

function Renderer3D.Render(game, presentation)
    if not initialized_ then return end
    SyncVoxels(game, presentation)
    SyncMarbles(game)
    SyncTrucks(game, presentation)
    SyncDebris(presentation)
end

function Renderer3D.Shutdown()
    for _, node in pairs(marbleNodes_) do RemoveNode(node) end
    for _, record in pairs(brickNodes_) do RemoveNode(record.node) end
    for _, node in pairs(debrisNodes_) do RemoveNode(node) end
    for _, truck in pairs(trucks_) do RemoveNode(truck.root) end
    marbleNodes_ = {}
    brickNodes_ = {}
    debrisNodes_ = {}
    trucks_ = {}
    materialCache_ = {}
    initialized_ = false
    scene_ = nil
end

return Renderer3D
