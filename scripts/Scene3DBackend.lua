-- Scene3DBackend.lua
-- 3D 场景后端：固定 540x960 设计坐标，使用正交相机呈现体素敌人与运输车。

local Renderer3D = require "Renderer3D"
local SkyUtils = require "urhox-libs.Rendering.SkyUtils"

local Backend = {}

local DESIGN_W = 540
local DESIGN_H = 960

local scene_ = nil
local cameraNode_ = nil
local camera_ = nil
local cameraBasePosition_ = Vector3(0, 0, 0)
local viewport_ = nil
local lightGroup_ = nil
local zone_ = nil
local dangerBandNode_ = nil
local dangerBandMaterial_ = nil
local skyNode_ = nil
local starNode_ = nil
local starFields_ = {}
local CleanupFailedInit
local ReleaseScene
local vg_ = nil
local physicalWidth_ = 0
local physicalHeight_ = 0
local dpr_ = 1
local logicalWidth_ = 0
local logicalHeight_ = 0
local scale_ = 1
local screenDesignWidth_ = 0
local screenDesignHeight_ = 0
local offsetX_ = 0
local offsetY_ = 0

CleanupFailedInit = function()
    if vg_ then
        nvgDelete(vg_)
        vg_ = nil
    end
    renderer:SetViewport(0, nil)
    viewport_ = nil
    if scene_ then
        scene_:Dispose()
        scene_ = nil
    end
    cameraNode_ = nil
    camera_ = nil
    viewport_ = nil
    lightGroup_ = nil
    zone_ = nil
    dangerBandNode_ = nil
    dangerBandMaterial_ = nil
    skyNode_ = nil
    starNode_ = nil
    starFields_ = {}
end

ReleaseScene = function()
    if scene_ then
        scene_:Dispose()
        scene_ = nil
    end
    cameraNode_ = nil
    camera_ = nil
    viewport_ = nil
    lightGroup_ = nil
    zone_ = nil
    dangerBandNode_ = nil
    dangerBandMaterial_ = nil
    skyNode_ = nil
    starNode_ = nil
    starFields_ = {}
end

local function UpdateScreenMetrics()
    physicalWidth_ = graphics:GetWidth()
    physicalHeight_ = graphics:GetHeight()
    dpr_ = graphics:GetDPR()
    logicalWidth_ = physicalWidth_ / dpr_
    logicalHeight_ = physicalHeight_ / dpr_
    scale_ = math.min(logicalWidth_ / DESIGN_W, logicalHeight_ / DESIGN_H)
    screenDesignWidth_ = logicalWidth_ / scale_
    screenDesignHeight_ = logicalHeight_ / scale_
    offsetX_ = (screenDesignWidth_ - DESIGN_W) * 0.5
    offsetY_ = (screenDesignHeight_ - DESIGN_H) * 0.5
end

local function CreateMaterial(rgb, roughness)
    local material = Material:new()
    material:SetTechnique(0,
        cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    material:SetShaderParameter("MatDiffColor", Variant(Color(rgb[1], rgb[2], rgb[3], 1)))
    material:SetShaderParameter("Metallic", Variant(0.0))
    material:SetShaderParameter("Roughness", Variant(roughness or 0.8))
    return material
end

local function CreateUnlitMaterial(rgb)
    local material = Material:new()
    material:SetTechnique(0,
        cache:GetResource("Technique", "Techniques/NoTextureUnlit.xml"))
    material:SetShaderParameter("MatDiffColor", Variant(Color(rgb[1], rgb[2], rgb[3], 1)))
    return material
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

local function CreateStarMaterial(brightness)
    local material = Material:new()
    material:SetTechnique(0,
        cache:GetResource("Technique", "Techniques/DiffVCol.xml"))
    material:SetTexture(TU_DIFFUSE, CreateWhiteTexture())
    material:SetShaderParameter("MatDiffColor",
        Variant(Color(brightness, brightness, brightness, 1)))
    material:SetCullMode(CULL_NONE)
    return material
end

local function CreateStarFieldLayer(parent, layerIndex, starCount, seed, z)
    local state = seed
    local function NextRandom()
        state = (state * 48271) % 2147483647
        return state / 2147483647
    end

    local node = parent:CreateChild("StarLayer_" .. tostring(layerIndex))
    node.position = Vector3(0, 0, z)
    local geometry = node:CreateComponent("CustomGeometry")
    geometry:SetNumGeometries(1)
    geometry:SetDynamic(false)
    geometry:BeginGeometry(0, TRIANGLE_LIST)

    local palettes = {
        {0.58, 0.76, 1.00},
        {0.90, 0.66, 1.00},
        {1.00, 0.88, 0.58},
        {0.72, 0.94, 1.00},
    }
    for i = 1, starCount do
        local x = -5.6 + NextRandom() * 11.2
        local y = -9.7 + NextRandom() * 19.4
        local size = 0.012 + NextRandom() * (0.022 + layerIndex * 0.012)
        local palette = palettes[1 + math.floor(NextRandom() * #palettes)]
        local centerColor = Color(
            math.min(1.0, palette[1] + 0.25),
            math.min(1.0, palette[2] + 0.25),
            math.min(1.0, palette[3] + 0.25), 1)
        local edgeColor = Color(palette[1] * 0.72, palette[2] * 0.72, palette[3] * 0.72, 1)
        local points = (i % 9 == 0) and 8 or 4
        local phase = NextRandom() * math.pi
        for p = 1, points do
            local angle0 = phase + (p - 1) * math.pi * 2 / points
            local angle1 = phase + p * math.pi * 2 / points
            local radius0 = size * ((points == 8 and p % 2 == 0) and 0.34 or 1.0)
            local radius1 = size * ((points == 8 and (p + 1) % 2 == 0) and 0.34 or 1.0)
            local function Vertex(px, py, color)
                geometry:DefineVertex(Vector3(px, py, 0))
                geometry:DefineNormal(Vector3(0, 0, -1))
                geometry:DefineColor(color)
            end
            Vertex(x, y, centerColor)
            Vertex(x + math.cos(angle1) * radius1, y + math.sin(angle1) * radius1, edgeColor)
            Vertex(x + math.cos(angle0) * radius0, y + math.sin(angle0) * radius0, edgeColor)
        end
    end

    geometry:Commit()
    local material = CreateStarMaterial(0.92 + layerIndex * 0.10)
    geometry:SetMaterial(material)
    geometry.castShadows = false
    starFields_[#starFields_ + 1] = {
        node = node,
        material = material,
        baseBrightness = 0.92 + layerIndex * 0.10,
        speed = (0.35 + layerIndex * 0.16) * (layerIndex % 2 == 0 and -1 or 1),
        phase = layerIndex * 1.73,
    }
end

local function CreateSpaceEnvironment()
    -- 深空底板负责稳定的竖屏渐变，三层星群位于底板前、游戏物体后。
    local backdrop = scene_:CreateChild("DeepSpaceBackdrop")
    backdrop.position = Vector3(0, 0, 1.65)
    backdrop.scale = Vector3(11.4, 19.8, 0.08)
    local backdropModel = backdrop:CreateComponent("StaticModel")
    backdropModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    backdropModel:SetMaterial(CreateUnlitMaterial({0.0025, 0.0035, 0.018}))
    backdropModel.castShadows = false

    skyNode_ = SkyUtils.CreateGradientSky(scene_, {
        zenith = Color(0.003, 0.006, 0.030),
        horizon = Color(0.035, 0.012, 0.100),
        ground = Color(0.002, 0.003, 0.012),
        skyExp = 0.38,
        groundExp = 1.8,
        size = 128,
        hdrBoost = 2.7,
    })

    starNode_ = scene_:CreateChild("DynamicStarField")
    CreateStarFieldLayer(starNode_, 1, 46, 27183, 1.18)
    CreateStarFieldLayer(starNode_, 2, 30, 91457, 1.12)
    CreateStarFieldLayer(starNode_, 3, 16, 158923, 1.06)
    print("[Scene3DBackend] dynamic star field created, stars=92, batches=3")
end

local function UpdateSpaceEnvironment(elapsed)
    if skyNode_ then
        skyNode_.rotation = Quaternion(elapsed * 0.18, Vector3(0, 1, 0))
    end
    for i, field in ipairs(starFields_) do
        field.node.rotation = Quaternion(elapsed * field.speed, Vector3(0, 0, 1))
        field.node.position = Vector3(
            math.sin(elapsed * (0.07 + i * 0.011) + field.phase) * 0.055 * i,
            math.cos(elapsed * (0.052 + i * 0.009) + field.phase) * 0.075 * i,
            field.node.position.z)
        local twinkle = 0.88 + 0.12 * math.sin(elapsed * (1.15 + i * 0.31) + field.phase)
        local brightness = field.baseBrightness * twinkle
        field.material:SetShaderParameter("MatDiffColor",
            Variant(Color(brightness, brightness, brightness, 1)))
    end
end

local function CreateDangerBand()
    dangerBandNode_ = scene_:CreateChild("DangerBand")
    dangerBandNode_.position = Vector3(0, -8.0, 0.9)
    dangerBandNode_.scale = Vector3(11.0, 0.06, 0.06)
    local model = dangerBandNode_:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    dangerBandMaterial_ = CreateMaterial({0.85, 0.08, 0.08}, 0.45)
    model:SetMaterial(dangerBandMaterial_)
    model.castShadows = false
end

local SLOT_TYPES = {"normal", "ice", "speed", "giant"}
local SLOT_NAMES = {
    normal = "分裂", ice = "冰冻", speed = "加速", giant = "巨型",
}
local SLOT_COLORS = {
    normal = {255, 184, 55}, ice = {72, 204, 255},
    speed = {255, 75, 35}, giant = {185, 88, 255},
}

local function DrawAimTrajectory(ctx, game)
    if not game.aiming or not game.activeBall then return end
    local color = SLOT_COLORS[game.activeBall.ballType] or SLOT_COLORS.normal
    for _, point in ipairs(game.aimTrajectory) do
        local alpha = math.floor(210 * (1 - point.progress))
        local radius = 1.8 + 3.0 * (1 - point.progress)
        nvgBeginPath(ctx)
        nvgCircle(ctx, point.x, point.y, radius)
        nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], alpha))
        nvgFill(ctx)
    end
end

local function DrawBaseImpactFeedback(ctx, game, presentation)
    local flash = presentation.baseBarrierFlash or 0
    if flash > 0 then
        local alpha = math.floor(math.min(1, flash / 0.62) * 180)
        local glow = nvgLinearGradient(ctx, 0, game.dangerY - 52, 0, game.dangerY + 42,
            nvgRGBA(255, 36, 18, 0), nvgRGBA(255, 96, 32, alpha))
        nvgBeginPath(ctx)
        nvgRect(ctx, 0, game.dangerY - 52, game.width, 94)
        nvgFillPaint(ctx, glow)
        nvgFill(ctx)

        nvgBeginPath(ctx)
        nvgMoveTo(ctx, 0, game.dangerY)
        nvgLineTo(ctx, game.width, game.dangerY)
        nvgStrokeColor(ctx, nvgRGBA(255, 225, 145, alpha))
        nvgStrokeWidth(ctx, 4 + 7 * flash)
        nvgStroke(ctx)
    end

    for _, impact in ipairs(presentation.baseImpacts or {}) do
        local progress = 1 - impact.life / impact.maxLife
        local alpha = math.floor(255 * (1 - progress))
        nvgBeginPath(ctx)
        nvgCircle(ctx, impact.x, impact.y, impact.radius)
        nvgStrokeColor(ctx, nvgRGBA(255, 112, 44, alpha))
        nvgStrokeWidth(ctx, 5 * (1 - progress) + 1)
        nvgStroke(ctx)
        for spoke = 1, 8 do
            local angle = impact.spin + spoke * math.pi * 0.25
            local inner = impact.radius * 0.45
            local outer = impact.radius * 1.15
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, impact.x + math.cos(angle) * inner,
                impact.y + math.sin(angle) * inner)
            nvgLineTo(ctx, impact.x + math.cos(angle) * outer,
                impact.y + math.sin(angle) * outer)
            nvgStrokeColor(ctx, nvgRGBA(255, 210, 100, math.floor(alpha * 0.8)))
            nvgStrokeWidth(ctx, 2)
            nvgStroke(ctx)
        end
    end
end

local function DrawAmmoSlots(ctx, game, presentation)
    local queueCounts = {}
    for _, ballType in ipairs(game.ballQueue) do
        queueCounts[ballType] = (queueCounts[ballType] or 0) + 1
    end
    if game.activeBall then
        queueCounts[game.activeBall.ballType] = (queueCounts[game.activeBall.ballType] or 0) + 1
    end

    local startX, slotY, slotW, slotH, gap = 34, 884, 112, 60, 8
    nvgFontFace(ctx, "zpix")
    for i, ballType in ipairs(SLOT_TYPES) do
        local x = startX + (i - 1) * (slotW + gap)
        local color = SLOT_COLORS[ballType]
        local selected = game.activeBall and game.activeBall.ballType == ballType
        local flash = presentation.truckLaunchFlash[ballType] or 0
        local lift = selected and -7 or 0

        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, x, slotY + lift, slotW, slotH, 10)
        local bg = nvgLinearGradient(ctx, x, slotY + lift, x, slotY + lift + slotH,
            nvgRGBA(34, 39, 67, 245), nvgRGBA(12, 15, 34, 245))
        nvgFillPaint(ctx, bg)
        nvgFill(ctx)
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, x + 1, slotY + lift + 1, slotW - 2, slotH - 2, 9)
        nvgStrokeColor(ctx, nvgRGBA(color[1], color[2], color[3],
            selected and 255 or 155 + math.floor(flash * 320)))
        nvgStrokeWidth(ctx, selected and 3 or 1.5 + flash * 7)
        nvgStroke(ctx)

        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, x + 8, slotY + lift + 9, 30, 30, 7)
        nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], 220))
        nvgFill(ctx)
        nvgFontSize(ctx, 14)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(18, 20, 38, 255))
        nvgText(ctx, x + 23, slotY + lift + 24, tostring(i), nil)

        nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFontSize(ctx, 15)
        nvgFillColor(ctx, nvgRGBA(245, 248, 255, 255))
        nvgText(ctx, x + 45, slotY + lift + 20, SLOT_NAMES[ballType], nil)
        nvgFontSize(ctx, 12)
        nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], 235))
        nvgText(ctx, x + 45, slotY + lift + 42,
            selected and "装填中" or ("储备 ×" .. tostring(queueCounts[ballType] or 0)), nil)
    end
end

local function DrawOverlayBackground(ctx, width, height)
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, width, height)
    nvgFillColor(ctx, nvgRGBA(7, 9, 24, 35))
    nvgFill(ctx)
end

local function DrawHud(ctx, game)
    nvgFontFace(ctx, "zpix")
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFontSize(ctx, 30)
    nvgFillColor(ctx, nvgRGBA(255, 230, 120, 255))
    nvgText(ctx, 15, 11, tostring(game.score), nil)

    nvgFontSize(ctx, 14)
    nvgFillColor(ctx, nvgRGBA(180, 190, 220, 220))
    nvgText(ctx, 17, 47, "BEST " .. tostring(game.highScore), nil)

    nvgFontSize(ctx, 18)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(ctx, nvgRGBA(255, 180, 100, 240))
    nvgText(ctx, game.width * 0.5, 14, "WAVE " .. tostring(game.wave), nil)

    for i = 1, game.maxBaseHp do
        local hx = game.width - 20 - (game.maxBaseHp - i) * 24
        local filled = i <= game.baseHp
        nvgBeginPath(ctx)
        nvgCircle(ctx, hx - 4, 22, 5)
        nvgCircle(ctx, hx + 4, 22, 5)
        nvgMoveTo(ctx, hx - 8.5, 24)
        nvgLineTo(ctx, hx, 34)
        nvgLineTo(ctx, hx + 8.5, 24)
        nvgClosePath(ctx)
        nvgFillColor(ctx, filled and nvgRGBA(255, 80, 90, 255)
            or nvgRGBA(60, 60, 80, 200))
        nvgFill(ctx)
    end
end

local function DrawMenu(ctx, game)
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, game.width, game.height)
    nvgFillColor(ctx, nvgRGBA(8, 10, 24, 116))
    nvgFill(ctx)

    nvgFontFace(ctx, "zpix")
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 48)
    nvgFillColor(ctx, nvgRGBA(255, 110, 40, 255))
    nvgText(ctx, game.width * 0.5, 185, "燃烧的蔬菜", nil)
    nvgFontSize(ctx, 23)
    nvgFillColor(ctx, nvgRGBA(255, 220, 140, 255))
    nvgText(ctx, game.width * 0.5, 235, "正交斜俯视 · 大运重卡车队", nil)

    nvgFontSize(ctx, 16)
    nvgFillColor(ctx, nvgRGBA(190, 205, 230, 230))
    nvgText(ctx, game.width * 0.5, 355, "彩色敌军方块受击后立体崩解", nil)
    nvgText(ctx, game.width * 0.5, 385, "拖拽重卡瞄准 · 发射 · 反弹 · 连锁", nil)

    local blink = 0.5 + 0.5 * math.sin(game.elapsed * 3)
    nvgFontSize(ctx, 22)
    nvgFillColor(ctx, nvgRGBA(255, 255, 220, 180 + 60 * blink))
    nvgText(ctx, game.width * 0.5, 760, "点击屏幕开始", nil)
end

local function DrawGameOver(ctx, game)
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, game.width, game.height)
    nvgFillColor(ctx, nvgRGBA(20, 5, 10, 215))
    nvgFill(ctx)

    nvgFontFace(ctx, "zpix")
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 38)
    nvgFillColor(ctx, nvgRGBA(255, 90, 70, 255))
    nvgText(ctx, game.width * 0.5, 390, "游戏结束", nil)
    nvgFontSize(ctx, 18)
    nvgFillColor(ctx, nvgRGBA(200, 200, 220, 255))
    nvgText(ctx, game.width * 0.5, 450, "SCORE " .. tostring(game.score), nil)
    nvgText(ctx, game.width * 0.5, 480, "BEST " .. tostring(game.highScore), nil)
    nvgText(ctx, game.width * 0.5, 510, "WAVE " .. tostring(game.wave), nil)
    nvgFontSize(ctx, 20)
    nvgFillColor(ctx, nvgRGBA(255, 255, 220, 220))
    nvgText(ctx, game.width * 0.5, 590, "点击重新开始", nil)
end

local function RenderOverlay(game, presentation)
    if not vg_ then return end
    nvgBeginFrame(vg_, logicalWidth_, logicalHeight_, dpr_)
    nvgScale(vg_, scale_, scale_)
    DrawOverlayBackground(vg_, screenDesignWidth_, screenDesignHeight_)
    nvgTranslate(vg_, offsetX_, offsetY_)
    nvgSave(vg_)
    nvgIntersectScissor(vg_, 0, 0, DESIGN_W, DESIGN_H)
    DrawAimTrajectory(vg_, game)
    if presentation.screenShake > 0 then
        local amplitude = presentation.screenShake * 13
        nvgTranslate(vg_, math.sin(game.elapsed * 91) * amplitude,
            math.cos(game.elapsed * 73) * amplitude * 0.65)
    end
    DrawBaseImpactFeedback(vg_, game, presentation)
    nvgRestore(vg_)

    DrawHud(vg_, game)
    DrawAmmoSlots(vg_, game, presentation)
    if game.state == "menu" then
        DrawMenu(vg_, game)
    elseif game.state == "gameover" then
        DrawGameOver(vg_, game)
    end
    nvgEndFrame(vg_)
end

function Backend.Init(renderHandlerName)
    if scene_ then
        Renderer3D.Shutdown()
        if vg_ then
            nvgDelete(vg_)
            vg_ = nil
        end
        renderer:SetViewport(0, nil)
        viewport_ = nil
        ReleaseScene()
    end
    UpdateScreenMetrics()
    scene_ = Scene()
    scene_:CreateComponent("Octree")
    scene_:CreateComponent("DebugRenderer")

    local lightGroupFile = cache:GetResource("XMLFile", "LightGroup/Daytime.xml")
    if not lightGroupFile then
        print("[Scene3DBackend] ERROR: missing LightGroup/Daytime.xml")
        CleanupFailedInit()
        return false
    end
    lightGroup_ = scene_:CreateChild("LightGroup")
    lightGroup_:LoadXML(lightGroupFile:GetRoot())
    zone_ = lightGroup_:GetComponent("Zone", true)
    if zone_ then
        zone_.fogColor = Color(0.006, 0.008, 0.025)
        zone_.fogStart = 32.0
        zone_.fogEnd = 80.0
        zone_.ambientIntensity = 0.52
    end

    CreateSpaceEnvironment()
    CreateDangerBand()

    -- 正交投影保持无近大远小；30° 斜俯视配合加厚敌人体素与高顶重卡暴露侧面深度。
    cameraNode_ = scene_:CreateChild("Camera")
    local cameraDistance = 25.0
    local cameraTilt = math.rad(30.0)
    cameraBasePosition_ = Vector3(
        0,
        cameraDistance * math.sin(cameraTilt),
        -cameraDistance * math.cos(cameraTilt)
    )
    cameraNode_.position = cameraBasePosition_
    cameraNode_:LookAt(Vector3(0, 0, 0))
    camera_ = cameraNode_:CreateComponent("Camera")
    camera_.orthographic = true
    camera_.orthoSize = 19.2
    camera_.nearClip = 0.1
    camera_.farClip = 100.0
    viewport_ = Viewport:new(scene_, camera_)
    renderer:SetViewport(0, viewport_)
    renderer.hdrRendering = true

    vg_ = nvgCreate(1)
    if not vg_ then
        print("[Scene3DBackend] ERROR: failed to create NanoVG overlay")
        CleanupFailedInit()
        return false
    end
    local fontId = nvgCreateFont(vg_, "zpix", "Fonts/Zpix.ttf")
    if fontId == -1 then
        print("[Scene3DBackend] ERROR: failed to load Fonts/Zpix.ttf")
        nvgDelete(vg_)
        vg_ = nil
        CleanupFailedInit()
        return false
    end

    if not Renderer3D.Init(scene_) then
        print("[Scene3DBackend] ERROR: Renderer3D initialization failed")
        CleanupFailedInit()
        return false
    end
    SubscribeToEvent(vg_, "NanoVGRender", renderHandlerName)
    print("[Scene3DBackend] initialized with orthographic 30-degree camera, Dayun-style heavy trucks, four ammo slots and impact feedback")
    return true
end

function Backend.Shutdown()
    Renderer3D.Shutdown()
    if vg_ then
        nvgDelete(vg_)
        vg_ = nil
    end
    renderer:SetViewport(0, nil)
    ReleaseScene()
end

function Backend.Resize()
    UpdateScreenMetrics()
end

function Backend.ScreenToGame(screenX, screenY)
    local logicalX = screenX / dpr_
    local logicalY = screenY / dpr_
    return logicalX / scale_ - offsetX_, logicalY / scale_ - offsetY_
end

function Backend.Render(gameSnapshot, presentationSnapshot)
    UpdateSpaceEnvironment(gameSnapshot.elapsed)
    local shake = presentationSnapshot.screenShake or 0
    if cameraNode_ then
        cameraNode_.position = cameraBasePosition_ + Vector3(
            math.sin(gameSnapshot.elapsed * 97) * shake * 0.10,
            math.cos(gameSnapshot.elapsed * 79) * shake * 0.08,
            math.sin(gameSnapshot.elapsed * 61) * shake * 0.035)
    end
    if dangerBandNode_ then
        local flash = presentationSnapshot.baseBarrierFlash or 0
        dangerBandNode_.scale = Vector3(11.0, 0.06 + flash * 0.18, 0.06 + flash * 0.12)
        if dangerBandMaterial_ then
            dangerBandMaterial_:SetShaderParameter("MatDiffColor", Variant(Color(
                math.min(1.0, 0.85 + flash * 0.5),
                math.min(1.0, 0.08 + flash * 0.42),
                math.min(1.0, 0.08 + flash * 0.12), 1)))
            dangerBandMaterial_:SetShaderParameter("MatEmissiveColor", Variant(Color(
                flash * 4.0, flash * 0.7, flash * 0.16, 1)))
        end
    end
    Renderer3D.Render(gameSnapshot, presentationSnapshot)
    RenderOverlay(gameSnapshot, presentationSnapshot)
end

function Backend.GetDesignSize()
    return DESIGN_W, DESIGN_H
end

return Backend
