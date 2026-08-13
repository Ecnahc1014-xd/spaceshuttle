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
local viewportLeft_ = 0
local viewportTop_ = 0
local viewportWidth_ = 0
local viewportHeight_ = 0

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

    -- 9:16 是不可变的玩法画布。所有显示器只做 CONTAIN，绝不拉伸或裁切。
    scale_ = math.min(logicalWidth_ / DESIGN_W, logicalHeight_ / DESIGN_H)
    screenDesignWidth_ = logicalWidth_ / scale_
    screenDesignHeight_ = logicalHeight_ / scale_
    offsetX_ = (screenDesignWidth_ - DESIGN_W) * 0.5
    offsetY_ = (screenDesignHeight_ - DESIGN_H) * 0.5

    viewportWidth_ = math.max(1, math.floor(DESIGN_W * scale_ * dpr_ + 0.5))
    viewportHeight_ = math.max(1, math.floor(DESIGN_H * scale_ * dpr_ + 0.5))
    viewportLeft_ = math.floor((physicalWidth_ - viewportWidth_) * 0.5)
    viewportTop_ = math.floor((physicalHeight_ - viewportHeight_) * 0.5)
    if viewport_ then
        viewport_:SetRect(IntRect(viewportLeft_, viewportTop_,
            viewportLeft_ + viewportWidth_, viewportTop_ + viewportHeight_))
    end
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
    dangerBandMaterial_ = CreateMaterial({0.39, 0.19, 0.67}, 0.45)
    model:SetMaterial(dangerBandMaterial_)
    model.castShadows = false
end

local SLOT_TYPES = {"normal", "ice", "speed", "giant"}
local SLOT_NAMES = {
    normal = "分裂", ice = "冰冻", speed = "加速", giant = "巨型",
}
local SLOT_COLORS = {
    normal = {190, 160, 255}, ice = {154, 226, 255},
    speed = {112, 176, 255}, giant = {226, 194, 255},
}

local ACID = {
    void = {10, 4, 28, 255},
    deepPurple = {32, 12, 68, 250},
    purple = {103, 61, 166, 255},
    brightPurple = {184, 133, 255, 255},
    paleBlue = {166, 229, 255, 255},
    coldBlue = {94, 169, 228, 255},
    carbon = {16, 12, 35, 255},
    muted = {125, 140, 184, 230},
}

local function DrawAcidGrid(ctx, width, height)
    nvgStrokeWidth(ctx, 1)
    nvgStrokeColor(ctx, nvgRGBA(137, 203, 255, 18))
    for x = 0, width, 36 do
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, x, 0)
        nvgLineTo(ctx, x, height)
        nvgStroke(ctx)
    end
    for y = 0, height, 36 do
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, 0, y)
        nvgLineTo(ctx, width, y)
        nvgStroke(ctx)
    end
end

local function DrawHalo(ctx, cx, cy, radius, alpha)
    nvgStrokeColor(ctx, nvgRGBA(166, 229, 255, alpha))
    nvgStrokeWidth(ctx, 1.5)
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, radius)
    nvgStroke(ctx)
    for angle = 0, 350, 10 do
        local radians = math.rad(angle)
        local inner = radius - (angle % 30 == 0 and 11 or 5)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, cx + math.cos(radians) * inner, cy + math.sin(radians) * inner)
        nvgLineTo(ctx, cx + math.cos(radians) * radius, cy + math.sin(radians) * radius)
        nvgStroke(ctx)
    end
end

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
            nvgRGBA(103, 61, 166, 0), nvgRGBA(166, 229, 255, alpha))
        nvgBeginPath(ctx)
        nvgRect(ctx, 0, game.dangerY - 52, game.width, 94)
        nvgFillPaint(ctx, glow)
        nvgFill(ctx)

        nvgBeginPath(ctx)
        nvgMoveTo(ctx, 0, game.dangerY)
        nvgLineTo(ctx, game.width, game.dangerY)
        nvgStrokeColor(ctx, nvgRGBA(186, 229, 255, alpha))
        nvgStrokeWidth(ctx, 4 + 7 * flash)
        nvgStroke(ctx)
    end

    for _, impact in ipairs(presentation.baseImpacts or {}) do
        local progress = 1 - impact.life / impact.maxLife
        local alpha = math.floor(255 * (1 - progress))
        nvgBeginPath(ctx)
        nvgCircle(ctx, impact.x, impact.y, impact.radius)
        nvgStrokeColor(ctx, nvgRGBA(184, 133, 255, alpha))
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
            nvgStrokeColor(ctx, nvgRGBA(166, 229, 255, math.floor(alpha * 0.8)))
            nvgStrokeWidth(ctx, 2)
            nvgStroke(ctx)
        end
    end
end

local function DrawTechPanel(ctx, x, y, width, height, fill, border)
    nvgBeginPath(ctx)
    nvgRect(ctx, x, y, width, height)
    nvgFillColor(ctx, nvgRGBA(fill[1], fill[2], fill[3], fill[4] or 255))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(border[1], border[2], border[3], border[4] or 255))
    nvgStrokeWidth(ctx, 2)
    nvgBeginPath(ctx)
    nvgRect(ctx, x + 1, y + 1, width - 2, height - 2)
    nvgStroke(ctx)
    local corner = 10
    nvgStrokeWidth(ctx, 1)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x, y + corner)
    nvgLineTo(ctx, x + corner, y)
    nvgMoveTo(ctx, x + width - corner, y)
    nvgLineTo(ctx, x + width, y + corner)
    nvgMoveTo(ctx, x, y + height - corner)
    nvgLineTo(ctx, x + corner, y + height)
    nvgMoveTo(ctx, x + width - corner, y + height)
    nvgLineTo(ctx, x + width, y + height - corner)
    nvgStroke(ctx)
end

local function DrawPixelText(ctx, x, y, text, size, color, align)
    nvgFontFace(ctx, "zpix")
    nvgFontSize(ctx, size)
    nvgTextAlign(ctx, align or (NVG_ALIGN_LEFT + NVG_ALIGN_TOP))
    nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
    nvgText(ctx, x, y, text, nil)
end

local function DrawPixelBar(ctx, x, y, width, height, value, color)
    DrawTechPanel(ctx, x, y, width, height,
        {10, 4, 28, 255}, {81, 105, 158, 255})
    local fillWidth = math.max(0, (width - 6) * math.max(0, math.min(1, value)))
    if fillWidth > 0 then
        nvgBeginPath(ctx)
        nvgRect(ctx, x + 3, y + 3, fillWidth, height - 6)
        nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
        nvgFill(ctx)
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

    local slotY, slotW, slotH, gap = 889, 132, 71, 4
    DrawPixelText(ctx, 8, slotY - 18, "// ORDNANCE ARRAY :: 04", 9, ACID.muted)
    for i, ballType in ipairs(SLOT_TYPES) do
        local x = (i - 1) * (slotW + gap)
        local color = SLOT_COLORS[ballType]
        local selected = game.activeBall and game.activeBall.ballType == ballType
        local flash = presentation.truckLaunchFlash[ballType] or 0
        local fill = selected and {53, 24, 91, 255} or ACID.carbon
        DrawTechPanel(ctx, x, slotY, slotW, slotH, fill,
            {color[1], color[2], color[3], selected and 255 or 150 + math.floor(flash * 105)})
        DrawHalo(ctx, x + 24, slotY + 27, 15, selected and 230 or 110)
        DrawPixelText(ctx, x + 24, slotY + 19, tostring(i), 12, color,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        DrawPixelText(ctx, x + 46, slotY + 12, SLOT_NAMES[ballType], 14,
            ACID.paleBlue)
        DrawPixelText(ctx, x + 46, slotY + 37,
            selected and "LINK ACTIVE" or ("RESERVE " .. tostring(queueCounts[ballType] or 0)),
            9, color)
        nvgBeginPath(ctx)
        nvgRect(ctx, x + 8, slotY + slotH - 8, slotW - 16, selected and 4 or 2)
        nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], selected and 255 or 125))
        nvgFill(ctx)
    end
end

local function DrawOverlayBackground(ctx, width, height)
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, width, height)
    nvgFillColor(ctx, nvgRGBA(10, 4, 28, 72))
    nvgFill(ctx)
end

local function DrawHud(ctx, game)
    local hpRatio = game.maxBaseHp > 0 and game.baseHp / game.maxBaseHp or 0
    local hpColor = hpRatio > 0.35 and ACID.paleBlue or ACID.brightPurple

    -- 顶部整条技术仪表直接贴住 9:16 画布边缘。
    DrawTechPanel(ctx, 0, 0, game.width, 78, ACID.carbon, ACID.purple)
    DrawAcidGrid(ctx, game.width, 78)
    DrawPixelText(ctx, 10, 8, "SYS::MARBLE FLIGHT CONTROL", 9, ACID.muted)
    DrawPixelText(ctx, 10, 25, tostring(game.score), 25, ACID.paleBlue)
    DrawPixelText(ctx, 10, 55, "BEST/" .. tostring(game.highScore), 9, ACID.coldBlue)

    DrawHalo(ctx, game.width * 0.5, 38, 29, 190)
    DrawPixelText(ctx, game.width * 0.5, 22, string.format("WAVE %02d", game.wave), 14,
        ACID.brightPurple, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width * 0.5, 48, "VECTOR LOCK", 8, ACID.paleBlue,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    DrawPixelText(ctx, game.width - 12, 8, "BASE INTEGRITY", 9, ACID.muted,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width - 12, 25,
        string.format("%02d / %02d", game.baseHp, game.maxBaseHp), 17, hpColor,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    DrawPixelBar(ctx, game.width - 170, 57, 158, 11, hpRatio, hpColor)
end

local function DrawMenu(ctx, game)
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 78, game.width, 811)
    nvgFillColor(ctx, nvgRGBA(20, 7, 49, 205))
    nvgFill(ctx)
    DrawAcidGrid(ctx, game.width, game.height)
    DrawHalo(ctx, game.width * 0.5, 322, 154, 140)
    DrawHalo(ctx, game.width * 0.5, 322, 112, 90)

    -- 半调点阵与工程标注形成酸性拼贴，不使用原风格的蓝白配色。
    nvgFillColor(ctx, nvgRGBA(166, 229, 255, 42))
    for row = 0, 8 do
        for col = 0, 12 do
            nvgBeginPath(ctx)
            nvgCircle(ctx, 35 + col * 12, 185 + row * 12, 1.6 + (col % 3) * 0.35)
            nvgFill(ctx)
        end
    end
    DrawPixelText(ctx, 14, 96, "[ NAVIGATION PROTOCOL :: ACTIVE ]", 9, ACID.paleBlue)
    DrawPixelText(ctx, game.width - 14, 96, "9:16 / LOCKED", 9, ACID.brightPurple,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)

    DrawPixelText(ctx, game.width * 0.5, 235, "太空飞机弹珠", 39,
        ACID.paleBlue, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width * 0.5, 286, "SPACECRAFT MARBLE", 12,
        ACID.brightPurple, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width * 0.5, 348, "轨道计算 / 碰撞反射 / 火控链接", 13,
        {192, 209, 244, 255}, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    DrawTechPanel(ctx, 0, 432, game.width, 72, ACID.deepPurple, ACID.paleBlue)
    local blink = 0.5 + 0.5 * math.sin(game.elapsed * 3)
    DrawPixelText(ctx, game.width * 0.5, 450, "点击屏幕建立链接", 20,
        {186, 232, 255, 180 + math.floor(75 * blink)}, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width * 0.5, 482, "INITIATE FLIGHT VECTOR", 8,
        ACID.muted, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    DrawPixelText(ctx, 14, 532, "COORD/Y 0890", 8, ACID.muted)
    DrawPixelText(ctx, 14, 548, "EDGE FIELD / VISIBLE", 8, ACID.muted)
    DrawPixelText(ctx, game.width - 14, 532, "UNIT SCALE / AUTH", 8, ACID.muted,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width - 14, 548, "CAMERA / ORTHO", 8, ACID.muted,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
end

local function DrawGameOver(ctx, game)
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 78, game.width, 811)
    nvgFillColor(ctx, nvgRGBA(14, 5, 36, 232))
    nvgFill(ctx)
    DrawAcidGrid(ctx, game.width, game.height)
    DrawHalo(ctx, game.width * 0.5, 390, 125, 180)
    DrawPixelText(ctx, game.width * 0.5, 330, "链接中断", 36, ACID.paleBlue,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width * 0.5, 380, "FLIGHT CONTROL OFFLINE", 10,
        ACID.brightPurple, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width * 0.5, 430,
        string.format("SCORE %d  /  BEST %d  /  WAVE %02d",
            game.score, game.highScore, game.wave), 13, ACID.paleBlue,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawTechPanel(ctx, 0, 530, game.width, 66, ACID.deepPurple, ACID.paleBlue)
    DrawPixelText(ctx, game.width * 0.5, 548, "点击重新建立链接", 18,
        ACID.paleBlue, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
end

local function RenderOverlay(game, presentation)
    if not vg_ then return end
    nvgBeginFrame(vg_, logicalWidth_, logicalHeight_, dpr_)
    nvgScale(vg_, scale_, scale_)
    DrawOverlayBackground(vg_, screenDesignWidth_, screenDesignHeight_)
    nvgTranslate(vg_, offsetX_, offsetY_)
    nvgSave(vg_)
    nvgIntersectScissor(vg_, 0, 0, DESIGN_W, DESIGN_H)
    nvgBeginPath(vg_)
    nvgRect(vg_, 0, 0, DESIGN_W, DESIGN_H)
    nvgStrokeColor(vg_, nvgRGBA(166, 229, 255, 180))
    nvgStrokeWidth(vg_, 2)
    nvgStroke(vg_)
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

    -- 正交投影保持无近大远小；38° 斜俯视让体素侧面、车辆侧围和厚度更明确。
    cameraNode_ = scene_:CreateChild("Camera")
    local cameraDistance = 25.0
    local cameraTilt = math.rad(38.0)
    cameraBasePosition_ = Vector3(
        0,
        cameraDistance * math.sin(cameraTilt),
        -cameraDistance * math.cos(cameraTilt)
    )
    cameraNode_.position = cameraBasePosition_
    cameraNode_:LookAt(Vector3(0, 0, 0))
    camera_ = cameraNode_:CreateComponent("Camera")
    camera_.orthographic = true
    camera_.orthoSize = 18.0
    camera_.nearClip = 0.1
    camera_.farClip = 100.0
    viewport_ = Viewport:new(scene_, camera_, IntRect(viewportLeft_, viewportTop_,
        viewportLeft_ + viewportWidth_, viewportTop_ + viewportHeight_))
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
    print("[Scene3DBackend] initialized: 9:16 locked viewport, orthographic 38-degree camera, spacecraft marble UI")
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
                math.min(1.0, 0.39 + flash * 0.20),
                math.min(1.0, 0.19 + flash * 0.48),
                math.min(1.0, 0.67 + flash * 0.33), 1)))
            dangerBandMaterial_:SetShaderParameter("MatEmissiveColor", Variant(Color(
                flash * 1.7, flash * 3.1, flash * 4.0, 1)))
        end
    end
    Renderer3D.Render(gameSnapshot, presentationSnapshot)
    RenderOverlay(gameSnapshot, presentationSnapshot)
end

function Backend.GetDesignSize()
    return DESIGN_W, DESIGN_H
end

return Backend
