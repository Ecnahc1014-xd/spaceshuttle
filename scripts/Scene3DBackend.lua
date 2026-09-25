-- Scene3DBackend.lua
-- 3D 场景后端：固定 540x960 设计坐标，使用正交相机呈现体素敌人与运输车。

local Renderer3D = require "Renderer3D"
local SkyUtils = require "urhox-libs.Rendering.SkyUtils"
local VisualCatalog = require "VisualCatalog"
local MetaUI = require "MetaUI"

local Backend = {}

local DESIGN_W = 540
local DESIGN_H = 960
local HUD_HEIGHT = 92
local BOTTOM_DOCK_Y = 866
local MENU_CONTENT_TOP = HUD_HEIGHT
local MENU_CONTENT_BOTTOM = BOTTOM_DOCK_Y

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
---@type VoxelPhysicsWorld|nil
local voxelWorld_ = nil
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
local projectionOffsetX_ = 0
local projectionOffsetY_ = 0
local projectionOriginNdcX_ = 0
local projectionOriginNdcY_ = 0
local projectionScaleX_ = 1
local projectionScaleY_ = 1
local viewportLeft_ = 0
local viewportTop_ = 0
local viewportWidth_ = 0
local viewportHeight_ = 0

-- WO-16/P9：FXAA 探测标志。当前验证环境不可启用 FXAA（ESSL shader cache 失败会吞掉整层 3D），
-- 故默认 fxaaAvailable=false；仅当渲染路径真实存在 FXAA 命令且启用不报错时才置真。
local fxaaAvailable_ = false
local nvgFontZpix_ = -1

-- A1/A2：模态与波次横幅的入场动画计时。记录当前玩法 state 的进入时刻，
-- 渲染时据此计算淡入/滑入进度，避免硬切（不破坏酸性风格，纯透明度/位移 easing）。
local uiState_ = nil
local uiStateEnter_ = 0

-- WO-16/P9：FXAA 能力探测。尝试在渲染路径中定位 FXAA 后处理命令，
-- 任何异常或缺失都判定不可用，保持关闭以保全 3D 画面（绝不强制启用）。
local function ProbeFxaa()
    local ok, renderPath = pcall(function() return renderer:GetRenderPath() end)
    if not ok or not renderPath then
        fxaaAvailable_ = false
        return
    end
    local hasFxaa = false
    local ok2, commands = pcall(function() return renderPath:GetCommands() end)
    if ok2 and commands then
        for _, cmd in ipairs(commands) do
            if cmd and cmd.tag and string.lower(cmd.tag) == "fxaa" then
                hasFxaa = true
                break
            end
        end
    end
    fxaaAvailable_ = hasFxaa
    print("[Scene3DBackend] FXAA probe -> available=" .. tostring(fxaaAvailable_))
end

CleanupFailedInit = function()
    if vg_ then
        nvgDelete(vg_)
        vg_ = nil
    end
    nvgFontZpix_ = -1
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
    voxelWorld_ = nil
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
    voxelWorld_ = nil
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

-- 世界反弹边缘：左右上三边作为可见的边界框，渲染在背景层之后、玩法物体之前。
-- 顶部反弹边位置必须与 Game.lua 的 TOP_BOUND_Y 一致：v0.10.10 取 0 与 -270 的均值 -135，
-- 投影到设计坐标约 y≈105（HUD 下方），载具飞到战场顶部即反弹；左右边仍对齐 0 / 540。
local EDGE_TOP_GAME_Y = -135
local function CreateWorldEdges()
    local edgeNode = scene_:CreateChild("WorldEdges")
    edgeNode.position = Vector3(0, 0, 1.45)
    local material = CreateUnlitMaterial({0.14, 0.30, 0.52})
    material:SetShaderParameter("MatDiffColor", Variant(Color(0.16, 0.36, 0.62, 1)))

    -- 设计坐标 540x960；边界世界坐标由 WorldFromGame 标定。
    local leftX = (0 - DESIGN_W * 0.5) * 0.018
    local rightX = (DESIGN_W - DESIGN_W * 0.5) * 0.018
    local topY = (DESIGN_H * 0.5 - EDGE_TOP_GAME_Y) * 0.018
    local bottomY = (DESIGN_H * 0.5 - DESIGN_H) * 0.018
    local fieldW = rightX - leftX
    local fieldH = topY - bottomY
    local edgeCenterY = (topY + bottomY) * 0.5
    local thickness = 0.05

    local function AddEdge(cx, cy, sx, sy)
        local node = edgeNode:CreateChild("Edge")
        node.position = Vector3(cx, cy, 0)
        node.scale = Vector3(sx, sy, 0.05)
        local model = node:CreateComponent("StaticModel")
        model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        model:SetMaterial(material)
        model.castShadows = false
    end

    -- 左右边线一直延伸到屏幕外的顶边，战场看起来向上延伸出画面。
    AddEdge(leftX + thickness * 0.5, edgeCenterY, thickness, fieldH)
    AddEdge(rightX - thickness * 0.5, edgeCenterY, thickness, fieldH)
    AddEdge(0, topY - thickness * 0.5, fieldW, thickness)
end

local SLOT_TYPES = {"normal", "ice", "speed", "giant"}
local SLOT_NAMES = {
    normal = "分裂", ice = "冰冻", speed = "加速", giant = "巨型",
}
local SLOT_COLORS = {
    normal = {0, 229, 208}, ice = {154, 226, 255},
    speed = {120, 176, 255}, giant = {255, 196, 72},
}

-- Dark-tech 令牌（ecnach-ui-skill）：深黑蓝层级 + 品牌青唯一强调。
local C = {
    bg      = {7, 11, 20, 255},
    panel   = {10, 16, 28, 255},
    rail    = {12, 20, 34, 255},
    card    = {16, 26, 44, 255},
    widget  = {22, 36, 56, 255},
    cyan    = {0, 229, 208, 255},
    cyanDim = {0, 150, 148, 220},
    ink     = {4, 8, 16, 255},
    text    = {240, 248, 252, 255},
    dim     = {120, 148, 162, 255},
    warn    = {255, 196, 72, 255},
    -- v0.11.0 商业化：付费/稀有语义的「未激活」态（金色降饱和，不与 warn 抢焦点）。
    warnDim = {170, 128, 48, 220},
    -- v0.11.0 商业化三色语义：绿色＝看广告（免费获取）。与青（主操作/进度）、
    -- 金（稀有/付费）三分，避免玩家分不清「哪个要花钱、哪个看广告就行」。
    ad      = {46, 232, 107, 255},
    adDim   = {28, 138, 70, 220},
    error   = {232, 76, 76, 255},
}

local BUILD_VERSION = "0.11.0"
local GAME_TITLE = "击碎，飞机大战"

local function WorldFromGame(x, y)
    return Vector3((x - DESIGN_W * 0.5) * 0.018,
        (DESIGN_H * 0.5 - y) * 0.018, 0)
end

local function UpdateProjectionMetrics(logMetrics)
    if not camera_ then return end
    -- 正交相机在 XY 玩法平面内保持线性投影；标定设计坐标用于 HUD 轨迹和点击，避免触摸漂移。
    local origin = camera_:WorldToScreenPoint(WorldFromGame(0, 0))
    local xAxis = camera_:WorldToScreenPoint(WorldFromGame(DESIGN_W, 0))
    local yAxis = camera_:WorldToScreenPoint(WorldFromGame(0, DESIGN_H))
    projectionOriginNdcX_ = origin.x
    projectionOriginNdcY_ = origin.y
    projectionOffsetX_ = origin.x * DESIGN_W
    projectionOffsetY_ = origin.y * DESIGN_H
    projectionScaleX_ = (xAxis.x - origin.x)
    projectionScaleY_ = (yAxis.y - origin.y)
    if math.abs(projectionScaleX_) < 0.0001 then projectionScaleX_ = 1 end
    if math.abs(projectionScaleY_) < 0.0001 then projectionScaleY_ = 1 end
    if logMetrics then
        print(string.format(
            "[Scene3DBackend] gameplay projection offset=(%.2f, %.2f) scale=(%.4f, %.4f)",
            projectionOffsetX_, projectionOffsetY_, projectionScaleX_, projectionScaleY_))
    end
end

local function ProjectGamePoint(x, y)
    return projectionOffsetX_ + x * projectionScaleX_,
        projectionOffsetY_ + y * projectionScaleY_
end

local function UseTechFont(ctx)
    if nvgFontZpix_ and nvgFontZpix_ >= 0 then
        nvgFontFace(ctx, "zpix")
    else
        nvgFontFace(ctx, "sans")
    end
end

local function DrawRect(ctx, x, y, w, h, color, radius)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x, y, w, h, radius or 4)
    nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
    nvgFill(ctx)
end

local function DrawStroke(ctx, x, y, w, h, color, radius, width)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x + 0.5, y + 0.5, w - 1, h - 1, radius or 4)
    nvgStrokeColor(ctx, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
    nvgStrokeWidth(ctx, width or 1.2)
    nvgStroke(ctx)
end

local function DrawLine(ctx, x1, y1, x2, y2, color, width)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x1, y1)
    nvgLineTo(ctx, x2, y2)
    nvgStrokeColor(ctx, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
    nvgStrokeWidth(ctx, width or 1)
    nvgStroke(ctx)
end

local function DrawCornerBrackets(ctx, x, y, w, h, color, length, width)
    local l = length or 12
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x, y + l); nvgLineTo(ctx, x, y); nvgLineTo(ctx, x + l, y)
    nvgMoveTo(ctx, x + w - l, y); nvgLineTo(ctx, x + w, y); nvgLineTo(ctx, x + w, y + l)
    nvgMoveTo(ctx, x, y + h - l); nvgLineTo(ctx, x, y + h); nvgLineTo(ctx, x + l, y + h)
    nvgMoveTo(ctx, x + w - l, y + h); nvgLineTo(ctx, x + w, y + h); nvgLineTo(ctx, x + w, y + h - l)
    nvgStrokeColor(ctx, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
    nvgStrokeWidth(ctx, width or 1.4)
    nvgStroke(ctx)
end

local function DrawBrokenFrame(ctx, x, y, w, h, color, gap)
    local g = gap or 28
    local c = nvgRGBA(color[1], color[2], color[3], color[4] or 255)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x, y); nvgLineTo(ctx, x + w * 0.5 - g, y)
    nvgMoveTo(ctx, x + w * 0.5 + g, y); nvgLineTo(ctx, x + w, y)
    nvgMoveTo(ctx, x, y + h); nvgLineTo(ctx, x + w, y + h)
    nvgMoveTo(ctx, x, y); nvgLineTo(ctx, x, y + h)
    nvgMoveTo(ctx, x + w, y); nvgLineTo(ctx, x + w, y + h)
    nvgStrokeColor(ctx, c)
    nvgStrokeWidth(ctx, 1.0)
    nvgStroke(ctx)
end

local function DrawMicroGrid(ctx, x, y, w, h, step, alpha)
    local s = step or 12
    nvgSave(ctx)
    nvgIntersectScissor(ctx, x, y, w, h)
    nvgBeginPath(ctx)
    for gx = x, x + w, s do
        nvgMoveTo(ctx, gx, y)
        nvgLineTo(ctx, gx, y + h)
    end
    for gy = y, y + h, s do
        nvgMoveTo(ctx, x, gy)
        nvgLineTo(ctx, x + w, gy)
    end
    nvgStrokeColor(ctx, nvgRGBA(C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], alpha or 28))
    nvgStrokeWidth(ctx, 1.0)
    nvgStroke(ctx)
    nvgRestore(ctx)
end

local function DrawEdgeTicks(ctx, x, y, w, count, color)
    if count < 2 then return end
    local step = w / (count - 1)
    for i = 0, count - 1 do
        local tickH = (i % 5 == 0) and 6 or 3
        DrawLine(ctx, x + i * step, y, x + i * step, y + tickH, color, 1)
    end
end

local function DrawStatusDots(ctx, x, y, count, color)
    for i = 0, count - 1 do
        nvgBeginPath(ctx)
        nvgRect(ctx, x + i * 8, y, 4, 4)
        nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], color[4] or 180))
        nvgFill(ctx)
    end
end

local function DrawWindowShell(ctx, x, y, w, h, titleH)
    DrawRect(ctx, x, y, w, h, C.panel, 6)
    DrawStroke(ctx, x, y, w, h, C.cyanDim, 6, 1.2)
    DrawRect(ctx, x, y, 4, titleH or 46, C.cyan, 0)
    DrawCornerBrackets(ctx, x + 4, y + 4, w - 8, h - 8, C.cyanDim, 14, 1.2)
end

local function DrawBaseImpactFeedback(ctx, game, presentation)
    local _, dangerScreenY = ProjectGamePoint(0, game.dangerY)
    local flash = presentation.baseBarrierFlash or 0
    if flash > 0 then
        local alpha = math.floor(math.min(1, flash / 0.62) * 180)
        local glow = nvgLinearGradient(ctx, 0, dangerScreenY - 52, 0, dangerScreenY + 42,
            nvgRGBA(C.error[1], C.error[2], C.error[3], 0),
            nvgRGBA(C.error[1], C.error[2], C.error[3], alpha))
        nvgBeginPath(ctx)
        nvgRect(ctx, 0, dangerScreenY - 52, game.width, 94)
        nvgFillPaint(ctx, glow)
        nvgFill(ctx)

        nvgBeginPath(ctx)
        nvgMoveTo(ctx, 0, dangerScreenY)
        nvgLineTo(ctx, game.width, dangerScreenY)
        nvgStrokeColor(ctx, nvgRGBA(C.error[1], C.error[2], C.error[3], alpha))
        nvgStrokeWidth(ctx, 4 + 7 * flash)
        nvgStroke(ctx)
    end

    for _, impact in ipairs(presentation.baseImpacts or {}) do
        local screenX, screenY = ProjectGamePoint(impact.x, impact.y)
        local progress = 1 - impact.life / impact.maxLife
        local alpha = math.floor(255 * (1 - progress))
        nvgBeginPath(ctx)
        nvgCircle(ctx, screenX, screenY, impact.radius * math.abs(projectionScaleX_))
        nvgStrokeColor(ctx, nvgRGBA(C.cyan[1], C.cyan[2], C.cyan[3], alpha))
        nvgStrokeWidth(ctx, 5 * (1 - progress) + 1)
        nvgStroke(ctx)
        for spoke = 1, 8 do
            local angle = impact.spin + spoke * math.pi * 0.25
            local inner = impact.radius * 0.45
            local outer = impact.radius * 1.15
            nvgBeginPath(ctx)
            nvgMoveTo(ctx,
                screenX + math.cos(angle) * inner * projectionScaleX_,
                screenY + math.sin(angle) * inner * projectionScaleY_)
            nvgLineTo(ctx,
                screenX + math.cos(angle) * outer * projectionScaleX_,
                screenY + math.sin(angle) * outer * projectionScaleY_)
            nvgStrokeColor(ctx, nvgRGBA(C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], math.floor(alpha * 0.8)))
            nvgStrokeWidth(ctx, 2)
            nvgStroke(ctx)
        end
    end
end

-- v0.10.23：击毁扩散环（少量点缀），从 r0 扩到 r1 并淡出。
local function DrawShockRings(ctx, game, presentation)
    for _, ring in ipairs(presentation.shockRings or {}) do
        local sx, sy = ProjectGamePoint(ring.x, ring.y)
        local progress = 1 - ring.life / ring.maxLife
        local radius = ring.r0 + (ring.r1 - ring.r0) * progress
        local alpha = math.floor(180 * (1 - progress))
        nvgBeginPath(ctx)
        nvgCircle(ctx, sx, sy, radius * math.abs(projectionScaleX_))
        nvgStrokeColor(ctx, nvgRGBA(ring.r, ring.g, ring.b, alpha))
        nvgStrokeWidth(ctx, 2.5)
        nvgStroke(ctx)
    end
end

-- v0.10.23：飘字（+分数/防线扣血/技能提示）。此前 floatTexts 只有旧 2D 后端
-- 消费，3D 后端一直没画；这里在 overlay 按世界坐标投影绘制，随震屏一起动。
local function DrawFloatTexts(ctx, game, presentation)
    for _, f in ipairs(presentation.floatTexts or {}) do
        local sx, sy = ProjectGamePoint(f.x, f.y)
        local lifeT = math.max(0, math.min(1, f.life / (f.maxLife or 0.9)))
        -- 末段淡出 + 轻微放大，提升命中正反馈。
        local alpha = math.floor(235 * math.min(1, lifeT * 3))
        local pop = 1 + 0.18 * (1 - lifeT)
        local size = math.floor((f.size or 32) * pop)
        local col = f.color or {255, 240, 180}
        nvgFontSize(ctx, size)
        UseTechFont(ctx)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER)
        -- 深色描边保证亮字在亮色敌机/烟团上也可读。
        nvgStrokeWidth(ctx, 3)
        nvgStrokeColor(ctx, nvgRGBA(C.ink[1], C.ink[2], C.ink[3], math.min(220, alpha + 40)))
        nvgText(ctx, sx, sy, f.text)
        nvgFillColor(ctx, nvgRGBA(col[1], col[2], col[3], alpha))
        nvgText(ctx, sx, sy, f.text)
    end
end

local function DrawTechPanel(ctx, x, y, width, height, fill, border)
    DrawRect(ctx, x, y, width, height, fill, 4)
    DrawStroke(ctx, x, y, width, height, border, 4, 1.2)
    DrawCornerBrackets(ctx, x + 1, y + 1, width - 2, height - 2, border, math.min(8, width * 0.22), 1)
end

local function DrawPixelText(ctx, x, y, text, size, color, align)
    UseTechFont(ctx)
    nvgFontSize(ctx, size)
    nvgTextAlign(ctx, align or (NVG_ALIGN_LEFT + NVG_ALIGN_TOP))
    nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
    nvgText(ctx, x, y, text, nil)
end

-- 中文/ASCII 混排自动换行：按像素宽度贪心折行，返回行数。
-- 用 nvgTextBounds 实测宽度，避免按固定字数硬切。align: center 时按行居中。
local function WrapTextLines(ctx, text, size, maxWidth)
    local lines = {}
    local line = ""
    UseTechFont(ctx)
    nvgFontSize(ctx, size)
    -- 调用方处于 CONTAIN 缩放（高分屏 scale 可为 2/3）后的 transform 下，
    -- 测量期间临时重置 transform，保证按设计空间宽度折行。
    nvgSave(ctx)
    nvgResetTransform(ctx)
    local function widthOf(s)
        -- 绑定返回 (advance, boundsTable)：bounds = {minx,miny,maxx,maxy}，
        -- 不能按 C API 的多返回值解构（旧写法恒为 nil 导致 fallback 按字节数计宽）。
        local _, bounds = nvgTextBounds(ctx, 0, 0, s, nil)
        if bounds and bounds[1] and bounds[3] then
            return bounds[3] - bounds[1]
        end
        -- fallback：按 UTF-8 字符数（非字节数）估计等宽像素字宽。
        return (utf8.len(s) or #s) * size
    end
    -- 逐字符遍历（兼容 UTF-8 中文字节）
    local i = 1
    while i <= #text do
        local b = string.byte(text, i)
        local step = 1
        if b >= 0xF0 then step = 4 elseif b >= 0xE0 then step = 3
        elseif b >= 0xC0 then step = 2 end
        local ch = text:sub(i, i + step - 1)
        local candidate = line .. ch
        if ch == "\n" then
            lines[#lines + 1] = line
            line = ""
        elseif widthOf(candidate) > maxWidth and #line > 0 then
            lines[#lines + 1] = line
            line = ch
        else
            line = candidate
        end
        i = i + step
    end
    nvgRestore(ctx)
    if #line > 0 then lines[#lines + 1] = line end
    return lines
end

local function DrawModalBackdrop(ctx, x, y, width, height)
    DrawRect(ctx, x, y, width, height, C.bg, 0)
    DrawMicroGrid(ctx, x + 18, y + 18, 132, 168, 12, 22)
    DrawMicroGrid(ctx, x + width - 150, y + height - 210, 120, 150, 12, 18)
    DrawStatusDots(ctx, x + 22, y + height - 28, 4, C.cyanDim)
end

local function DrawBluePanel(ctx, x, y, width, height, fill, border, radius)
    DrawRect(ctx, x, y, width, height, fill, radius or 6)
    DrawStroke(ctx, x, y, width, height, border, radius or 6, 1.2)
end

local function DrawSegmentedRule(ctx, x, y, width, segments, color, activeCount)
    local gap = 5
    local segmentWidth = (width - gap * (segments - 1)) / segments
    for i = 1, segments do
        nvgBeginPath(ctx)
        nvgRect(ctx, x + (i - 1) * (segmentWidth + gap), y, segmentWidth, 2)
        local active = not activeCount or i <= activeCount
        nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], active and (color[4] or 220) or 55))
        nvgFill(ctx)
    end
end

local function DrawPixelBar(ctx, x, y, width, height, value, color)
    DrawRect(ctx, x, y, width, height, C.widget, 3)
    DrawStroke(ctx, x, y, width, height, C.cyanDim, 3, 1)
    local fillWidth = math.max(0, (width - 4) * math.max(0, math.min(1, value)))
    if fillWidth > 0 then
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, x + 2, y + 2, fillWidth, height - 4, 2)
        nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
        nvgFill(ctx)
    end
end

-- A1/A2：缓动与模态入场计时。
local function EaseOutCubic(t)
    t = math.max(0, math.min(1, t))
    return 1 - (1 - t) * (1 - t) * (1 - t)
end

local function UpdateUiState(game)
    if game.state ~= uiState_ then
        uiState_ = game.state
        uiStateEnter_ = game.elapsed
    end
end

-- 模态入场进度（0..1），0.28s 缓入。返回 alpha 与可选滑动偏移。
local function ModalIntro(game)
    local t = (game.elapsed - uiStateEnter_) / 0.28
    return EaseOutCubic(t)
end

local AIRCRAFT_LABELS = {
    scout = "侦察", dart = "飞镖", striker = "强袭", hive = "蜂群",
    manta = "鳐鱼", bomber = "飞碟", cruiser = "巡洋", interceptor = "截击",
}

-- v0.10.31：底部 Dock 中央下一波小图。四弹药槽左右分组，中间 256px 留给预告。
-- 只读 game.nextWave（规则层预抽），像素格来自 VisualCatalog，禁止再抽随机。
local function DrawNextWavePreview(ctx, game)
    local plan = game.nextWave
    if not plan then return end
    local preview = VisualCatalog.GetAircraftPreview(plan.aircraftKey)
    local panelW, panelH = 168, 76
    local px = DESIGN_W * 0.5 - panelW * 0.5
    local py = BOTTOM_DOCK_Y + 12
    local border = plan.isBoss and C.error or C.cyanDim
    DrawTechPanel(ctx, px, py, panelW, panelH, C.card, border)
    DrawRect(ctx, px, py, 3, panelH, plan.isBoss and C.error or C.cyan, 0)

    local cooldown = game.waveCooldown or 0
    local eta = string.format("%d", math.max(0, math.floor(cooldown + 0.999)))
    DrawPixelText(ctx, px + 8, py + 4, plan.isBoss and "首领" or "下一波", 15,
        plan.isBoss and C.error or C.dim)
    DrawPixelText(ctx, px + panelW - 8, py + 4, eta .. "秒", 15, C.cyan,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)

    if preview and preview.cells then
        local cell = math.max(2, math.floor(math.min(52 / preview.gridW, 36 / preview.gridH)))
        local artW = preview.gridW * cell
        local artH = preview.gridH * cell
        local ax = px + math.floor((panelW - artW) * 0.5)
        local ay = py + 22 + math.floor((34 - artH) * 0.5)
        for i = 1, #preview.cells do
            local c = preview.cells[i]
            nvgBeginPath(ctx)
            nvgRect(ctx, ax + (c.col - 1) * cell, ay + (c.row - 1) * cell, cell - 0.5, cell - 0.5)
            nvgFillColor(ctx, nvgRGBA(c.r, c.g, c.b, 255))
            nvgFill(ctx)
        end
    end

    local label = AIRCRAFT_LABELS[plan.aircraftKey] or plan.aircraftKey
    local countText = plan.isBoss and "首领" or (tostring(plan.count or 0) .. "架")
    DrawPixelText(ctx, px + 8, py + panelH - 20, label, 15, C.text)
    DrawPixelText(ctx, px + panelW - 8, py + panelH - 20, countText, 15,
        plan.isBoss and C.error or C.cyan, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
end

local function DrawAmmoSlots(ctx, game, presentation)
    local queueCounts = {}
    for _, ballType in ipairs(game.ballQueue or {}) do
        queueCounts[ballType] = (queueCounts[ballType] or 0) + 1
    end
    if game.activeBall then
        queueCounts[game.activeBall.ballType] = (queueCounts[game.activeBall.ballType] or 0) + 1
    end

    DrawRect(ctx, 0, BOTTOM_DOCK_Y, DESIGN_W, DESIGN_H - BOTTOM_DOCK_Y, C.panel, 0)
    DrawLine(ctx, 0, BOTTOM_DOCK_Y, DESIGN_W, BOTTOM_DOCK_Y, C.cyanDim, 1)
    DrawRect(ctx, 0, BOTTOM_DOCK_Y, 4, DESIGN_H - BOTTOM_DOCK_Y, C.cyan, 0)
    DrawEdgeTicks(ctx, 16, BOTTOM_DOCK_Y + 1, DESIGN_W - 32, 21, {C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 90})

    -- v0.10.24：主球回库补弹时 Dock 顶边一道青色轻扫光（0.3s 衰减）。
    local reload = presentation.reloadFlash or 0
    if reload > 0 then
        local a = math.floor(190 * (reload / 0.3))
        local sweep = reload / 0.3
        local sx = DESIGN_W * (1 - sweep)
        DrawLine(ctx, sx, BOTTOM_DOCK_Y, DESIGN_W, BOTTOM_DOCK_Y, {C.cyan[1], C.cyan[2], C.cyan[3], a}, 2)
    end

    DrawPixelText(ctx, 14, BOTTOM_DOCK_Y + 4, "弹药", 16, C.dim)
    DrawPixelText(ctx, DESIGN_W - 14, BOTTOM_DOCK_Y + 4,
        "拖拽发射", 16, C.cyan, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)

    local slotSize = 64
    local slotGap = 6
    local slotY = BOTTOM_DOCK_Y + 26
    local leftStart = 10
    local rightStart = DESIGN_W - 10 - slotSize * 2 - slotGap
    for i, ballType in ipairs(SLOT_TYPES) do
        local pairIndex = (i - 1) % 2
        local x = (i <= 2 and leftStart or rightStart) + pairIndex * (slotSize + slotGap)
        local color = SLOT_COLORS[ballType]
        local selected = game.activeBall and game.activeBall.ballType == ballType
        local fill = selected and C.widget or C.card
        if selected and reload > 0 then
            local lift = math.floor(18 * (reload / 0.3))
            fill = {22 + lift, 36 + lift, 56 + lift, 255}
        end
        local border = selected and C.cyan or {color[1], color[2], color[3], 180}
        DrawTechPanel(ctx, x, slotY, slotSize, slotSize, fill, border)
        if selected then
            DrawRect(ctx, x, slotY, 3, slotSize, C.cyan, 0)
        end
        DrawPixelText(ctx, x + 6, slotY + 3, string.format("%d", i), 13, C.dim)
        DrawPixelText(ctx, x + slotSize - 6, slotY + 3,
            "x" .. tostring(queueCounts[ballType] or 0), 15, selected and C.cyan or color,
            NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
        DrawPixelText(ctx, x + slotSize * 0.5, slotY + 20, SLOT_NAMES[ballType], 18,
            C.text, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        if selected then
            DrawRect(ctx, x + 8, slotY + 42, slotSize - 16, 16, C.cyan, 6)
            DrawPixelText(ctx, x + slotSize * 0.5, slotY + 43, "待发", 15, C.ink,
                NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        else
            DrawPixelText(ctx, x + slotSize * 0.5, slotY + 43, "待命", 15, C.dim,
                NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        end
        nvgBeginPath(ctx)
        nvgRect(ctx, x + 6, slotY + slotSize - 7, slotSize - 12, selected and 3 or 1)
        nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], selected and 255 or 125))
        nvgFill(ctx)
    end

    DrawNextWavePreview(ctx, game)
end

local function DrawLetterboxBackground(ctx, width, height)
    -- NanoVG 位于 3D Viewport 之后：只填充设计画布外的 letterbox，绝不能覆盖画布内部。
    nvgFillColor(ctx, nvgRGBA(C.bg[1], C.bg[2], C.bg[3], 255))
    if offsetY_ > 0 then
        nvgBeginPath(ctx)
        nvgRect(ctx, 0, 0, width, offsetY_)
        nvgRect(ctx, 0, offsetY_ + DESIGN_H, width, math.max(0, height - offsetY_ - DESIGN_H))
        nvgFill(ctx)
    end
    if offsetX_ > 0 then
        nvgBeginPath(ctx)
        nvgRect(ctx, 0, offsetY_, offsetX_, DESIGN_H)
        nvgRect(ctx, offsetX_ + DESIGN_W, offsetY_, math.max(0, width - offsetX_ - DESIGN_W), DESIGN_H)
        nvgFill(ctx)
    end
end

local function FindBoss(game)
    for _, enemy in ipairs(game.veggies or {}) do
        if enemy.isBoss then return enemy end
    end
    return nil
end

local function DrawBossPhaseBar(ctx, game, boss)
    -- A6：Boss 阶段条。纯规则字段驱动（bossPhase 1/2/3，vulnerable 时高亮），
    -- 渲染层只读消费，不触达规则层。酸性风格：分段硬边指示 + 易伤脉冲。
    local cx = game.width * 0.5
    local barW = 220
    local x0 = cx - barW * 0.5
    local y = 84
    DrawPixelText(ctx, cx, y - 18, "首领阶段", 16, C.warn,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    local segments = 3
    local segW = barW / segments
    for s = 1, segments do
        local filled = s <= (boss.bossPhase or 1)
        local vul = (boss.bossPhase == 2)
        local col = filled and (vul and C.warn or C.cyan) or C.dim
        DrawTechPanel(ctx, x0 + (s - 1) * segW + 2, y, segW - 4, 12,
            filled and C.widget or C.card, col)
        if filled then
            DrawPixelText(ctx, x0 + (s - 1) * segW + segW * 0.5, y + 1, tostring(s), 14,
                col, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        end
    end
    if boss.bossPhase == 2 then
        local pulse = 0.5 + 0.5 * math.sin(game.elapsed * 6)
        DrawPixelText(ctx, cx, y + 16, "虚弱中 伤害×1.5",
            15, {C.warn[1], C.warn[2], C.warn[3], 150 + math.floor(105 * pulse)},
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
end

-- v0.10.23：基地受击时屏幕四边向内的红色危险渐变（不遮挡中心战斗区）。
local function DrawDamageVignette(ctx, game, presentation)
    local flash = presentation.baseBarrierFlash or 0
    if flash <= 0 then return end
    local a = math.min(1, flash / 0.62)
    local edge = 90
    local rgba = function(alpha) return nvgRGBA(232, 64, 64, math.floor(alpha)) end
    -- 上/下/左/右四条向内淡出的渐变条。
    local g
    g = nvgLinearGradient(ctx, 0, 0, 0, edge, rgba(150 * a), rgba(0))
    nvgBeginPath(ctx); nvgRect(ctx, 0, 0, game.width, edge); nvgFillPaint(ctx, g); nvgFill(ctx)
    g = nvgLinearGradient(ctx, 0, game.height, 0, game.height - edge, rgba(170 * a), rgba(0))
    nvgBeginPath(ctx); nvgRect(ctx, 0, game.height - edge, game.width, edge); nvgFillPaint(ctx, g); nvgFill(ctx)
    g = nvgLinearGradient(ctx, 0, 0, edge, 0, rgba(130 * a), rgba(0))
    nvgBeginPath(ctx); nvgRect(ctx, 0, 0, edge, game.height); nvgFillPaint(ctx, g); nvgFill(ctx)
    g = nvgLinearGradient(ctx, game.width, 0, game.width - edge, 0, rgba(130 * a), rgba(0))
    nvgBeginPath(ctx); nvgRect(ctx, game.width - edge, 0, edge, game.height); nvgFillPaint(ctx, g); nvgFill(ctx)
end

local function DrawHud(ctx, game, presentation)
    local hpRatio = game.maxBaseHp > 0 and game.baseHp / game.maxBaseHp or 0
    -- v0.10.24：低血量（≤35%）基地读数与血条红色脉冲，强化危险提示。
    local hpColor
    if hpRatio > 0.35 then
        hpColor = C.text
    else
        local pulse = 0.5 + 0.5 * math.sin((game.elapsed or 0) * 7)
        hpColor = {235 + math.floor(20 * pulse), 70 + math.floor(40 * pulse), 70}
    end
    DrawRect(ctx, 0, 0, game.width, HUD_HEIGHT, C.panel, 0)
    DrawRect(ctx, 0, 0, 4, HUD_HEIGHT, C.cyan, 0)
    DrawLine(ctx, 0, HUD_HEIGHT - 1, game.width, HUD_HEIGHT - 1, C.cyanDim, 1)
    DrawEdgeTicks(ctx, 16, HUD_HEIGHT - 8, game.width - 32, 21,
        {C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 90})

    DrawPixelText(ctx, 14, 4, "分数", 15, C.dim)
    DrawPixelText(ctx, 14, 20, string.format("%d", game.score), 30, C.text)
    local cloud = presentation and presentation.cloudStatus
    local bestLine = "最高 " .. tostring(game.highScore)
    local bestColor = C.dim
    if cloud == "ok" then
        bestLine = bestLine .. " · 已同步"
        bestColor = C.cyan
    elseif cloud == "syncing" then
        bestLine = bestLine .. " · 同步中"
    elseif cloud == "offline" then
        bestLine = bestLine .. " · 本地"
        bestColor = C.warn
    end
    DrawPixelText(ctx, 14, 52, bestLine, 15, bestColor)

    local centerX = game.width * 0.5
    DrawPixelText(ctx, centerX, 4, "波次", 15, C.cyan, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawPixelText(ctx, centerX, 20, string.format("%d", game.wave), 30, C.text,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    -- v0.10.24：连击≥2 时整句转强调色并轻微脉冲放大，给连续清场正反馈。
    local combo = game.clearStreak or 0
    local comboColor = C.dim
    local comboSize = 14
    if combo >= 2 then
        comboColor = C.warn
        comboSize = 14 + math.floor(2 * (0.5 + 0.5 * math.sin((game.elapsed or 0) * 8)))
    end
    DrawPixelText(ctx, centerX, 52,
        string.format("敌机 %d    连击 ×%d", game.concurrentCount or 0, combo),
        comboSize, comboColor, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    DrawPixelText(ctx, game.width - 12, 4, "防线", 15, C.dim,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width - 12, 20,
        string.format("%d / %d", game.baseHp, game.maxBaseHp), 26, hpColor,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width - 12, 48, hpRatio > 0.35 and "正常" or "危险",
        14, hpColor, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    DrawPixelBar(ctx, game.width - 168, 64, 156, 8, hpRatio, hpRatio > 0.35 and C.cyan or hpColor)
    -- v0.11.0 商业化：本局零件实时计数。放在血条下方的空白带（y=74 起），
    -- 不占「等级/经验」那一行，也不与血条 x 区间打架。
    DrawPixelText(ctx, game.width - 12, 74, string.format("零件 +%d", game.runParts or 0), 15, C.warn,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)

    local xpRatio = game.xpToNext > 0 and game.xp / game.xpToNext or 0
    DrawPixelText(ctx, 14, 70, string.format("等级 %d", game.playerLevel), 15, C.cyan)
    DrawPixelBar(ctx, 100, 74, 128, 10, xpRatio, C.cyan)
    DrawPixelText(ctx, 236, 70,
        string.format("经验 %d/%d", math.floor(game.xp or 0), game.xpToNext or 0), 15, C.dim)

    local words = game.activeWords or {}
    -- 词条徽标：NanoVG 程序化绘制（不依赖外部 PNG），每个词条一个高亮方块 + 汉字。
    local WORD_BADGE = {
        pierce = {label = "贯", color = C.warn},
        chain = {label = "链", color = C.cyan},
        momentum = {label = "量", color = {255, 138, 101}},
    }
    local iconSize = 20
    local iconX = game.width - 176 - #words * (iconSize + 5)
    local iconY = 46
    for i, wordId in ipairs(words) do
        local badge = WORD_BADGE[wordId]
        local ix = iconX + (i - 1) * (iconSize + 5)
        local bc = badge and badge.color or C.dim
        DrawTechPanel(ctx, ix, iconY, iconSize, iconSize, C.card, bc)
        if badge then
            DrawPixelText(ctx, ix + iconSize * 0.5, iconY + 2, badge.label, 15, bc,
                NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        end
    end

    local boss = FindBoss(game)
    if boss then DrawBossPhaseBar(ctx, game, boss) end
end

local function DrawMenu(ctx, game, meta)
    nvgSave(ctx)
    nvgIntersectScissor(ctx, 0, MENU_CONTENT_TOP, game.width, game.height - MENU_CONTENT_TOP)
    nvgGlobalAlpha(ctx, ModalIntro(game))
    DrawModalBackdrop(ctx, 0, MENU_CONTENT_TOP, game.width, game.height - MENU_CONTENT_TOP)

    local winX, winY = 18, 108
    local winW, winH = game.width - 36, 540
    DrawWindowShell(ctx, winX, winY, winW, winH, 48)
    DrawPixelText(ctx, winX + 18, winY + 10, GAME_TITLE, 22, C.cyan)
    DrawPixelText(ctx, winX + winW - 16, winY + 14, "v" .. BUILD_VERSION, 14, C.dim,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    DrawBrokenFrame(ctx, winX + 10, winY + 52, winW - 20, winH - 64, {C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 90}, 36)
    DrawEdgeTicks(ctx, winX + 18, winY + 50, winW - 36, 17, {C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 80})

    DrawPixelText(ctx, game.width * 0.5, 184, "击碎飞机", 36, C.text,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width * 0.5, 228, "拖拽发射重卡，一块一块打掉敌机", 18, C.dim,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width * 0.5, 254, "别让飞机飞过底部防线", 18, C.dim,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    -- 主操作：青底深字胶囊。
    DrawRect(ctx, 40, 292, game.width - 80, 76, C.cyan, 8)
    DrawPixelText(ctx, game.width * 0.5, 302, "点击开始", 28, C.ink,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width * 0.5, 338, "松手确认", 16, C.ink,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    DrawPixelText(ctx, 40, 384, "本局目标", 18, C.cyan)
    DrawBluePanel(ctx, 40, 404, game.width - 80, 112, C.rail, C.cyanDim, 6)
    DrawMicroGrid(ctx, 48, 412, game.width - 96, 96, 12, 18)
    DrawPixelText(ctx, 58, 416, "防线生命", 15, C.dim)
    DrawPixelText(ctx, 58, 436, "100", 30, C.text)
    DrawPixelText(ctx, 138, 450, "点", 15, C.dim)
    DrawPixelText(ctx, 292, 416, "弹种", 15, C.dim)
    DrawPixelText(ctx, 292, 436, "4", 30, C.text)
    DrawPixelText(ctx, 334, 450, "种轮换", 15, C.dim)
    DrawSegmentedRule(ctx, 58, 488, game.width - 116, 10, C.cyanDim)

    DrawPixelText(ctx, 40, 532, "怎么玩", 18, C.cyan)
    DrawBluePanel(ctx, 40, 554, game.width - 80, 86, C.card, C.cyanDim, 6)
    DrawPixelText(ctx, 58, 564, "拖拽瞄准", 15, C.dim)
    DrawPixelText(ctx, 58, 584, "松手发射", 18, C.text)
    DrawPixelText(ctx, 292, 564, "按 P", 15, C.dim)
    DrawPixelText(ctx, 292, 584, "暂停游戏", 18, C.text)

    -- v0.11.0 商业化：菜单下半区（货币栏 / 四入口 / 签到 / 每日补给）。
    if meta then MetaUI.DrawMenuBar(ctx, game.width, meta) end
    nvgRestore(ctx)
end

-- v0.11.0 商业化：结算页三按钮（复活 / 看广告双倍零件 / 再来一局）。
-- 视觉几何与命中判定共用此处，禁止在 main.lua 再写一套常量。
local function GetGameOverButtonLayout(game)
    local w = game.width or DESIGN_W
    local btnH, gap = 48, 12
    local rowW = 216
    local rowPairW = rowW * 2 + gap
    local rowX = (w - rowPairW) * 0.5
    local revive = {
        x = (w - rowW) * 0.5,
        y = 496,
        w = rowW,
        h = btnH,
    }
    local double = {
        x = rowX,
        y = revive.y + btnH + gap,
        w = rowW,
        h = btnH,
    }
    local restart = {
        x = rowX + rowW + gap,
        y = double.y,
        w = rowW,
        h = btnH,
    }
    return revive, double, restart
end

local function DrawGameOver(ctx, game, presentation)
    nvgSave(ctx)
    nvgIntersectScissor(ctx, 0, MENU_CONTENT_TOP,
        game.width, game.height - MENU_CONTENT_TOP)
    nvgGlobalAlpha(ctx, ModalIntro(game))
    DrawModalBackdrop(ctx, 0, MENU_CONTENT_TOP, game.width, game.height - MENU_CONTENT_TOP)

    local winX, winY = 24, 200
    local winW, winH = game.width - 48, 520
    DrawWindowShell(ctx, winX, winY, winW, winH, 48)
    DrawPixelText(ctx, winX + 18, winY + 10, "防线失守", 22, C.cyan)
    DrawPixelText(ctx, winX + winW - 16, winY + 14, "本局结束", 15, C.warn,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)

    DrawPixelText(ctx, game.width * 0.5, 278, "游戏结束", 36, C.text,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width * 0.5, 322, "敌机突破了底部防线", 18, C.dim,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width * 0.5, 348,
        string.format("分数 %d    最高 %d    第 %d 波",
            game.score, game.highScore, game.wave), 18, C.text,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    DrawBluePanel(ctx, 44, 370, game.width - 88, 92, C.rail, C.cyanDim, 6)
    DrawPixelText(ctx, 60, 380, string.format("到达第 %d 波", game.wave), 17, C.text)
    DrawPixelText(ctx, 60, 402, string.format("等级 %d", game.playerLevel), 17, C.text)
    DrawPixelText(ctx, 60, 424, string.format("击碎 %d 块", game.bricksBroken or 0), 17, C.dim)
    DrawPixelText(ctx, game.width - 60, 380, string.format("强化 %d 次", #(game.upgradePicks or {})), 17,
        C.text, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width - 60, 402, string.format("连击 %d", game.clearStreak or 0), 17,
        C.text, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width - 60, 424, string.format("存活 %.0f 秒", game.elapsed or 0), 17,
        C.dim, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    -- v0.11.0 商业化：本局零件产出（结算页最直观的变现锚点）。
    DrawPixelText(ctx, game.width * 0.5, 446,
        string.format("本局获得  零件 ×%d", game.runParts or 0), 18, C.warn,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    local reviveBtn, doubleBtn, restartBtn = GetGameOverButtonLayout(game)
    local canRevive = game.canRevive
    local adBusy = presentation and presentation.adStatus == "loading"
    if canRevive then
        if adBusy then
            DrawRect(ctx, reviveBtn.x, reviveBtn.y, reviveBtn.w, reviveBtn.h, C.widget, 8)
            DrawStroke(ctx, reviveBtn.x, reviveBtn.y, reviveBtn.w, reviveBtn.h, C.cyanDim, 8, 1)
            DrawPixelText(ctx, game.width * 0.5, reviveBtn.y + 12, "广告加载中…", 18, C.dim,
                NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        else
            DrawRect(ctx, reviveBtn.x, reviveBtn.y, reviveBtn.w, reviveBtn.h, C.ad, 8)
            DrawPixelText(ctx, game.width * 0.5, reviveBtn.y + 4, "看广告复活", 20, C.ink,
                NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            DrawPixelText(ctx, game.width * 0.5, reviveBtn.y + 28, "防线回 50 血 · 本局一次", 15, C.ink,
                NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        end
    else
        DrawRect(ctx, reviveBtn.x, reviveBtn.y, reviveBtn.w, reviveBtn.h, C.widget, 8)
        DrawStroke(ctx, reviveBtn.x, reviveBtn.y, reviveBtn.w, reviveBtn.h, C.cyanDim, 8, 1)
        DrawPixelText(ctx, game.width * 0.5, reviveBtn.y + 12, "本局已复活", 18, C.dim,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end

    -- 看广告双倍零件：已翻倍后置灰，不可重复领取。
    if game.canDoubleSettle then
        DrawRect(ctx, doubleBtn.x, doubleBtn.y, doubleBtn.w, doubleBtn.h, C.card, 8)
        DrawStroke(ctx, doubleBtn.x, doubleBtn.y, doubleBtn.w, doubleBtn.h, C.ad, 8, 1.5)
        DrawPixelText(ctx, doubleBtn.x + doubleBtn.w * 0.5, doubleBtn.y + 5, "看广告 双倍零件", 18, C.ad,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        DrawPixelText(ctx, doubleBtn.x + doubleBtn.w * 0.5, doubleBtn.y + 28,
            string.format("再得 %d 零件", game.runParts or 0), 15, C.dim,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    else
        DrawRect(ctx, doubleBtn.x, doubleBtn.y, doubleBtn.w, doubleBtn.h, C.widget, 8)
        DrawStroke(ctx, doubleBtn.x, doubleBtn.y, doubleBtn.w, doubleBtn.h, C.cyanDim, 8, 1)
        DrawPixelText(ctx, doubleBtn.x + doubleBtn.w * 0.5, doubleBtn.y + 12,
            game.partsDoubled and "零件已翻倍" or "零件已入库", 17, C.dim,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end

    DrawRect(ctx, restartBtn.x, restartBtn.y, restartBtn.w, restartBtn.h, C.cyan, 8)
    DrawPixelText(ctx, restartBtn.x + restartBtn.w * 0.5, restartBtn.y + 12, "再来一局", 20, C.ink,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    local toast = presentation and presentation.adToast
    if toast and toast ~= "" then
        DrawPixelText(ctx, game.width * 0.5, restartBtn.y + restartBtn.h + 10, toast, 15, C.warn,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
    nvgRestore(ctx)
end

local UPGRADE_RARITY = {
    common = {tag = "标准", color = C.cyanDim},
    rare = {tag = "稀有", color = C.warn},
    epic = {tag = "史诗", color = C.cyan},
}

local function GetUpgradeCardLayout(game)
    -- v0.10.14：540 宽内三卡 + 两间距，两侧各留 10px 安全边距。
    -- 与 main.lua:TryPickUpgradeAt 的命中常量必须保持一致。
    local cardW = 168
    local cardH = 300
    local gap = 8
    local totalW = 3 * cardW + 2 * gap
    local startX = game.width * 0.5 - totalW * 0.5 + cardW * 0.5
    -- v0.10.17：卡片在标题区与底部操作提示之间垂直居中（卡 380..680）。
    local cy = 530
    return cardW, cardH, gap, startX, cy
end

-- 卡片序号圆点渲染在 DrawUpgradeCard 内。

---@class UiRect
---@field x number
---@field y number
---@field w number
---@field h number

-- 升格角标：卡片右上角，未升格时是入口、已升格时是状态标识。
---@return UiRect
local function GetBoostBadgeRect(cx, cardTop, cardW)
    local w, h = 46, 22
    return { x = cx + cardW * 0.5 - w - 6, y = cardTop + 6, w = w, h = h }
end

local function DrawUpgradeCard(ctx, index, choice, cx, cy, cardW, cardH)
    local x = cx - cardW * 0.5
    local y = cy - cardH * 0.5
    local rare = UPGRADE_RARITY[choice.rarity] or UPGRADE_RARITY.common
    local accent = rare.color
    DrawBluePanel(ctx, x, y, cardW, cardH, C.card, C.cyanDim, 6)
    DrawCornerBrackets(ctx, x + 4, y + 4, cardW - 8, cardH - 8, accent, 10, 1.2)
    DrawRect(ctx, x, y, 3, cardH, accent, 0)

    DrawPixelText(ctx, x + 10, y + 8, string.format("%02d", index), 15, C.dim)
    DrawPixelText(ctx, x + cardW * 0.5, y + 24, choice.name or "强化", 22, C.text,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawPixelText(ctx, x + cardW * 0.5, y + 52,
        (choice.kind == "word" and "特殊效果 · " or "") .. rare.tag, 16, accent,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawSegmentedRule(ctx, x + 14, y + 76, cardW - 28, 6, C.cyanDim)

    local detailLines = WrapTextLines(ctx,
        choice.detail or choice.desc or "提升当前弹珠性能", 17, cardW - 18)
    local detailLineH = 25
    local maxDetailLines = 3
    local detailCount = math.min(maxDetailLines, #detailLines)
    local detailAreaTop = y + 88
    local detailAreaBottom = y + cardH - 98
    local detailTop = detailAreaTop
        + math.max(0, (detailAreaBottom - detailAreaTop - detailCount * detailLineH) * 0.5)
    for li = 1, detailCount do
        DrawPixelText(ctx, x + cardW * 0.5, detailTop + (li - 1) * detailLineH,
            detailLines[li], 17, C.dim, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end

    local footerTop = y + cardH - 90
    if choice.tradeoff then
        DrawTechPanel(ctx, x + 10, footerTop, cardW - 20, 26, C.widget, C.warn)
        DrawPixelText(ctx, x + cardW * 0.5, footerTop + 4, "高风险 / 高回报", 15,
            C.warn, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    elseif choice.kind == "word" then
        DrawTechPanel(ctx, x + 10, footerTop, cardW - 20, 26, C.widget, accent)
        DrawPixelText(ctx, x + cardW * 0.5, footerTop + 4, "本局生效 · 只装一次", 15, accent,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end

    DrawRect(ctx, x + 14, y + cardH - 56, cardW - 28, 28, C.widget, 6)
    DrawStroke(ctx, x + 14, y + cardH - 56, cardW - 28, 28, accent, 6, 1)
    DrawPixelText(ctx, x + cardW * 0.5, y + cardH - 51, choice.value or "强化", 16, accent,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    local stacks = choice.stacks or 0
    local maxText = choice.maxStacks and choice.maxStacks >= 90 and "∞" or tostring(choice.maxStacks or "-")
    DrawPixelText(ctx, x + cardW * 0.5, y + cardH - 22,
        "已选 " .. tostring(stacks) .. " / " .. maxText, 14, C.dim,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    -- v0.11.0 商业化：广告升格角标 / 升格入口（同位置切换，不额外占版面）。
    local badge = GetBoostBadgeRect(cx, y, cardW)
    if choice.boosted then
        DrawRect(ctx, badge.x, badge.y, badge.w, badge.h, C.widget, 4)
        DrawStroke(ctx, badge.x, badge.y, badge.w, badge.h, C.ad, 4, 1.2)
        DrawPixelText(ctx, badge.x + badge.w * 0.5, badge.y + 4, "已升格", 14, C.ad,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    else
        DrawStroke(ctx, badge.x, badge.y, badge.w, badge.h, C.adDim, 4, 1)
        DrawPixelText(ctx, badge.x + badge.w * 0.5, badge.y + 4, "升格", 14, C.adDim,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
end

-- ============================================================================
-- v0.11.0 商业化：升级面板变现区（第 4 张宽卡 + 底部动作按钮）。
-- 视觉几何与命中判定共用 GetUpgradePanelLayout，禁止在 main.lua 另写常量。
-- ============================================================================

---@class UpgradePanelLayout
---@field cardW number
---@field cardH number
---@field gap number
---@field startX number
---@field cy number
---@field cardCount integer
---@field extra UiRect
---@field rerollFree UiRect
---@field rerollAd UiRect
---@field fourth UiRect
---@field extraPick UiRect
---@field hintY number

---@return UpgradePanelLayout
local function GetUpgradePanelLayout(game)
    local cardW, cardH, gap, startX, cy = GetUpgradeCardLayout(game)
    local w = game.width or DESIGN_W
    local margin = 24
    local innerW = w - margin * 2
    local btnGap = 12
    local btnW = math.floor((innerW - btnGap * 2) / 3)
    local btnY = 806
    local btnH = 50
    local rowX = margin
    local choices = game.upgradeChoices or {}
    return {
        cardW = cardW,
        cardH = cardH,
        gap = gap,
        startX = startX,
        cy = cy,
        cardCount = math.min(3, #choices),
        extra = { x = margin, y = 692, w = innerW, h = 104 },
        rerollFree = { x = rowX, y = btnY, w = btnW, h = btnH },
        rerollAd = { x = rowX + btnW + btnGap, y = btnY, w = btnW, h = btnH },
        fourth = { x = rowX + (btnW + btnGap) * 2, y = btnY, w = btnW, h = btnH },
        extraPick = { x = margin, y = btnY + btnH + 10, w = innerW, h = 42 },
        hintY = btnY + btnH + 10 + 42 + 12,
    }
end

-- 第 4 张宽卡：未解锁时是金色锁条，解锁后展示追加候选。
local function DrawExtraChoiceCard(ctx, choice, rect)
    local x, y, w, h = rect.x, rect.y, rect.w, rect.h
    if choice.locked then
        DrawRect(ctx, x, y, w, h, C.widget, 6)
        DrawStroke(ctx, x, y, w, h, C.adDim, 6, 1.2)
        DrawPixelText(ctx, x + 18, y + 14, "??", 26, C.adDim)
        DrawPixelText(ctx, x + 66, y + 14, "看广告 解锁第 4 张", 20, C.ad)
        DrawPixelText(ctx, x + 66, y + 46, "神秘词条优先 · 本局多一个选择", 16, C.dim)
        DrawPixelText(ctx, x + w - 18, y + 30, "广告", 16, C.adDim,
            NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
        return
    end
    local rare = UPGRADE_RARITY[choice.rarity] or UPGRADE_RARITY.common
    local accent = rare.color
    DrawBluePanel(ctx, x, y, w, h, C.card, accent, 6)
    DrawCornerBrackets(ctx, x + 4, y + 4, w - 8, h - 8, accent, 10, 1.2)
    DrawRect(ctx, x, y, 3, h, accent, 0)
    DrawPixelText(ctx, x + 16, y + 12, "04", 15, C.dim)
    DrawPixelText(ctx, x + 48, y + 8, choice.name or "强化", 22, C.text)
    DrawPixelText(ctx, x + 48, y + 38,
        (choice.kind == "word" and "神秘词条 · " or "") .. rare.tag, 16, accent)
    local lines = WrapTextLines(ctx, choice.detail or choice.desc or "", 17, w - 190)
    if #lines > 0 then
        DrawPixelText(ctx, x + w - 16, y + 20, lines[1], 17, C.dim,
            NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
        if #lines > 1 then
            DrawPixelText(ctx, x + w - 16, y + 46, lines[2], 17, C.dim,
                NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
        end
    end
    DrawRect(ctx, x + w - 16 - 130, y + h - 36, 130, 26, C.widget, 6)
    DrawStroke(ctx, x + w - 16 - 130, y + h - 36, 130, 26, accent, 6, 1)
    DrawPixelText(ctx, x + w - 16 - 65, y + h - 31, choice.value or "强化", 16, accent,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
end

---@param rect UiRect
---@param label string
---@param sub string
---@param enabled boolean
---@param accent table
local function DrawPanelButton(ctx, rect, label, sub, enabled, accent)
    local border = enabled and accent or C.cyanDim
    local labelColor = enabled and accent or C.dim
    DrawRect(ctx, rect.x, rect.y, rect.w, rect.h, enabled and C.card or C.widget, 6)
    DrawStroke(ctx, rect.x, rect.y, rect.w, rect.h, border, 6, enabled and 1.4 or 1)
    DrawPixelText(ctx, rect.x + rect.w * 0.5, rect.y + (sub ~= "" and 6 or 14), label, 17,
        labelColor, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    if sub ~= "" then
        DrawPixelText(ctx, rect.x + rect.w * 0.5, rect.y + 28, sub, 14, C.dim,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
end

local function DrawUpgradeActions(ctx, game, layout)
    local freeLabel = game.rerollFreeAvailable and "免费重抽 1/1" or "免费重抽 已用"
    DrawPanelButton(ctx, layout.rerollFree, freeLabel, "",
        game.rerollFreeAvailable == true, C.cyan)
    -- 绿色＝看广告（免费获取），与青色免费重抽、金色稀有度区分开。
    DrawPanelButton(ctx, layout.rerollAd, "看广告 重抽", "或升格卡池", true, C.ad)
    DrawPanelButton(ctx, layout.fourth,
        game.fourthChoiceUnlocked and "已解锁第 4 张" or "看广告 四选一",
        game.fourthChoiceUnlocked and "本局有效" or "多一个选择",
        game.fourthChoiceUnlocked ~= true, C.ad)

    local extraRect = layout.extraPick
    if game.canArmExtraPick then
        DrawPanelButton(ctx, extraRect, "看广告 · 本次额外再选一张", "", true, C.ad)
    else
        DrawPanelButton(ctx, extraRect, "已启用额外选卡", "选完后会再开一次面板", false, C.cyan)
    end
end

local function DrawLevelUp(ctx, game, presentation)
    nvgSave(ctx)
    nvgIntersectScissor(ctx, 0, MENU_CONTENT_TOP, game.width, game.height - MENU_CONTENT_TOP)
    nvgGlobalAlpha(ctx, ModalIntro(game))
    DrawModalBackdrop(ctx, 0, MENU_CONTENT_TOP, game.width, game.height - MENU_CONTENT_TOP)

    local choices = game.upgradeChoices or {}
    local layout = GetUpgradePanelLayout(game)

    DrawPixelText(ctx, 24, 106, "升级", 18, C.cyan)
    DrawPixelText(ctx, game.width - 24, 106,
        string.format("%d 选一", math.max(3, #choices)), 18, C.warn,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width * 0.5, 130, "选择一项强化", 30, C.text,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width * 0.5, 168,
        string.format("当前等级 %d    点一张卡片继续", game.playerLevel), 17, C.dim,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    if #choices > 0 then
        for i = 1, layout.cardCount do
            DrawUpgradeCard(ctx, i, choices[i],
                layout.startX + (i - 1) * (layout.cardW + layout.gap),
                layout.cy, layout.cardW, layout.cardH)
        end
        if choices[4] then
            DrawExtraChoiceCard(ctx, choices[4], layout.extra)
        end
    else
        DrawBluePanel(ctx, 30, 365, game.width - 60, 100, C.rail, C.cyanDim, 6)
        DrawPixelText(ctx, game.width * 0.5, 395, "暂无强化可选", 20, C.text,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        DrawPixelText(ctx, game.width * 0.5, 423, "请稍后再试", 16, C.dim,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end

    DrawUpgradeActions(ctx, game, layout)

    DrawPixelText(ctx, 24, layout.hintY, "战斗已暂停", 16, C.dim)
    local hintPulse = presentation and presentation.upgradeHintPulse or 0
    local hintColor = C.warn
    local hintSize = 16
    if hintPulse > 0 then
        local p = hintPulse / 0.5
        hintColor = {
            C.warn[1] + math.floor((255 - C.warn[1]) * p),
            C.warn[2] + math.floor((248 - C.warn[2]) * p),
            C.warn[3] + math.floor((210 - C.warn[3]) * p),
            255,
        }
        hintSize = 16 + math.floor(3 * p)
    end
    DrawPixelText(ctx, game.width - 24, layout.hintY, "点选一张卡片", hintSize, hintColor,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    nvgRestore(ctx)
end

-- v0.11.0 商业化：暂停补给站（看广告的局内触点）。视觉与命中同源。
---@class PausePanelLayout
---@field win UiRect
---@field heal UiRect
---@field rare UiRect

---@return PausePanelLayout
local function GetPausePanelLayout(w)
    local margin = 44
    local innerW = w - margin * 2
    return {
        win = { x = 24, y = 280, w = w - 48, h = 400 },
        heal = { x = margin, y = 478, w = innerW, h = 64 },
        rare = { x = margin, y = 552, w = innerW, h = 64 },
    }
end

local function DrawPaused(ctx, game, meta, presentation)
    nvgSave(ctx)
    nvgIntersectScissor(ctx, 0, MENU_CONTENT_TOP,
        game.width, game.height - MENU_CONTENT_TOP)
    nvgGlobalAlpha(ctx, ModalIntro(game))
    DrawModalBackdrop(ctx, 0, MENU_CONTENT_TOP, game.width, game.height - MENU_CONTENT_TOP)
    local layout = GetPausePanelLayout(game.width)
    DrawWindowShell(ctx, layout.win.x, layout.win.y, layout.win.w, layout.win.h, 46)
    DrawPixelText(ctx, layout.win.x + 18, layout.win.y + 10, "已暂停", 18, C.cyan)
    DrawPixelText(ctx, game.width * 0.5, 330, "休息一下", 34, C.text,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width * 0.5, 382, "点击屏幕继续 · 或按 P", 18, C.text,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawSegmentedRule(ctx, 72, 418, game.width - 144, 10, C.cyanDim)

    -- 战场补给站：本局内看广告换即时资源。
    DrawPixelText(ctx, 44, 444, "战场补给站", 18, C.ad)
    DrawPixelText(ctx, game.width - 44, 448, "本局限量", 14, C.dim,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)

    local heal = layout.heal
    if game.canPauseHeal then
        DrawRect(ctx, heal.x, heal.y, heal.w, heal.h, C.card, 6)
        DrawStroke(ctx, heal.x, heal.y, heal.w, heal.h, C.ad, 6, 1.5)
        DrawPixelText(ctx, heal.x + 18, heal.y + 12, "看广告 · 防线急救", 18, C.ad)
        DrawPixelText(ctx, heal.x + heal.w - 18, heal.y + 14,
            string.format("+%d 血", 25), 16, C.dim, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    else
        DrawRect(ctx, heal.x, heal.y, heal.w, heal.h, C.widget, 6)
        DrawStroke(ctx, heal.x, heal.y, heal.w, heal.h, C.cyanDim, 6, 1)
        DrawPixelText(ctx, heal.x + 18, heal.y + 12,
            game.baseHp >= game.maxBaseHp and "防线已满" or "防线急救 已用完", 18, C.dim)
    end

    local rare = layout.rare
    if game.canPauseRarePick then
        DrawRect(ctx, rare.x, rare.y, rare.w, rare.h, C.card, 6)
        DrawStroke(ctx, rare.x, rare.y, rare.w, rare.h, C.ad, 6, 1.5)
        DrawPixelText(ctx, rare.x + 18, rare.y + 12, "看广告 · 下个强化必出稀有", 18, C.ad)
    else
        DrawRect(ctx, rare.x, rare.y, rare.w, rare.h, C.widget, 6)
        DrawStroke(ctx, rare.x, rare.y, rare.w, rare.h, C.cyanDim, 6, 1)
        DrawPixelText(ctx, rare.x + 18, rare.y + 12, "稀有保底 已购买", 18, C.dim)
    end

    local toast = presentation and presentation.adToast
    if toast and toast ~= "" then
        DrawPixelText(ctx, game.width * 0.5, layout.win.y + layout.win.h + 12, toast, 15, C.warn,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    else
        DrawPixelText(ctx, game.width * 0.5, layout.win.y + layout.win.h + 12,
            "暂停不会消耗时间", 14, C.dim, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
    nvgRestore(ctx)
end

local function DrawWaveBanner(ctx, game, presentation)
    -- A2：波次横幅。waveBannerTimer 由 Presentation 维护（1.8 起递减），
    -- 入场用 ease 从上方滑入，生命周期尾部淡出。v0.10.23：Boss 波红框警告。
    local t = presentation.waveBannerTimer or 0
    if t <= 0 then return end
    local life = 1.8
    local age = life - t
    local slide = EaseOutCubic(math.min(1, age / 0.35))
    local yOff = (1 - slide) * -40
    local alpha = math.min(1, t / 0.4)
    nvgSave(ctx)
    nvgGlobalAlpha(ctx, alpha)
    local cx = game.width * 0.5
    if presentation.waveBannerBoss then
        local pulse = 220 + math.floor(35 * math.abs(math.sin(game.elapsed * 8)))
        local warn = {232, 76, 76}
        DrawBluePanel(ctx, cx - 156, 138 + yOff, 312, 70, C.card, warn, 6)
        DrawPixelText(ctx, cx, 144 + yOff, "首领来袭", 16, {pulse, 90, 90},
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        DrawPixelText(ctx, cx, 168 + yOff, string.format("第 %d 波", game.wave), 22,
            warn, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    else
        DrawBluePanel(ctx, cx - 156, 142 + yOff, 312, 60, C.card, C.cyan, 6)
        DrawPixelText(ctx, cx, 154 + yOff, string.format("第 %d 波来了", game.wave), 22,
            C.cyan, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
    nvgRestore(ctx)
end

local function RenderOverlay(game, presentation, meta)
    if not vg_ then return end
    nvgBeginFrame(vg_, logicalWidth_, logicalHeight_, dpr_)
    nvgResetTransform(vg_)
    nvgResetScissor(vg_)
    nvgGlobalAlpha(vg_, 1.0)
    nvgScale(vg_, scale_, scale_)
    DrawLetterboxBackground(vg_, screenDesignWidth_, screenDesignHeight_)
    nvgTranslate(vg_, offsetX_, offsetY_)
    nvgSave(vg_)
    DrawCornerBrackets(vg_, 2, 2, DESIGN_W - 4, DESIGN_H - 4, {C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 140}, 18, 1.4)
    DrawBrokenFrame(vg_, 0.5, 0.5, DESIGN_W - 1, DESIGN_H - 1, {C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 90}, 42)
    if game.state == "playing" then
        if presentation.screenShake > 0 then
            local amplitude = presentation.screenShake * 13
            nvgTranslate(vg_, math.sin(game.elapsed * 91) * amplitude,
                math.cos(game.elapsed * 73) * amplitude * 0.65)
        end
        DrawBaseImpactFeedback(vg_, game, presentation)
        DrawShockRings(vg_, game, presentation)
        DrawFloatTexts(vg_, game, presentation)
        DrawWaveBanner(vg_, game, presentation)
    end
    nvgRestore(vg_)

    nvgResetScissor(vg_)
    nvgResetTransform(vg_)
    nvgScale(vg_, scale_, scale_)
    nvgTranslate(vg_, offsetX_, offsetY_)
    nvgGlobalAlpha(vg_, 1.0)
    DrawHud(vg_, game, presentation)
    if game.state == "playing" then
        DrawAmmoSlots(vg_, game, presentation)
        DrawDamageVignette(vg_, game, presentation)
    elseif game.state == "menu" then
        DrawMenu(vg_, game, meta)
    elseif game.state == "gameover" then
        DrawGameOver(vg_, game, presentation)
    elseif game.state == "levelup" then
        DrawLevelUp(vg_, game, presentation)
    elseif game.state == "paused" then
        DrawPaused(vg_, game, meta, presentation)
    end
    -- v0.11.0 商业化：元层功能面板与每日补给弹窗画在最上层（含模态遮罩）。
    if meta and meta.screen then
        MetaUI.DrawScreen(vg_, DESIGN_W, meta)
    end
    if meta and meta.supplyOpen then
        MetaUI.DrawSupplyPopup(vg_, DESIGN_W, meta)
    end
    nvgResetScissor(vg_)
    nvgGlobalAlpha(vg_, 1.0)
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
    -- v0.11.0 商业化：把游戏 UI 的令牌与绘制原语注入元层界面，保证两处风格同源。
    MetaUI.Init({
        C = C,
        text = DrawPixelText,
        rect = DrawRect,
        stroke = DrawStroke,
        panel = DrawBluePanel,
        shell = DrawWindowShell,
        corner = DrawCornerBrackets,
        grid = DrawMicroGrid,
        rule = DrawSegmentedRule,
        backdrop = DrawModalBackdrop,
        wrap = WrapTextLines,
    })
    scene_ = Scene()
    scene_:CreateComponent("Octree")
    scene_:CreateComponent("DebugRenderer")
    -- v0.10.25：探测体素物理模块。当前运行时未启用时 CreateComponent 返回 nil，
    -- 渲染层回退到手搓 CustomGeometry，禁止把探测失败当成初始化失败。
    -- 一个 Scene 只能有 PhysicsWorld 或 VoxelPhysicsWorld 其一；本项目不用 Bullet。
    local okVoxel, voxelWorld = pcall(function()
        return scene_:CreateComponent("VoxelPhysicsWorld")
    end)
    if okVoxel and voxelWorld then
        voxelWorld_ = voxelWorld
        voxelWorld_.gravity = Vector3(0, -9.81, 0)
        voxelWorld_.updateEnabled = true
        voxelWorld_:SetMinFragmentVoxels(1)
        voxelWorld_:SetSpallChunkVoxels(1)
        voxelWorld_:SetMaxSpallChunks(4)
        voxelWorld_:SetSpallSpeed(3.2)
        voxelWorld_:SetDamageNoise(0.12)
        voxelWorld_:SetStressBreakFactor(0)
        voxelWorld_:SetMinDamageableVoxels(1)
        voxelWorld_:SetDebrisMaxAge(1.4)
        voxelWorld_:SetMaxFrozenFragments(48)
        voxelWorld_:SetContactEventThreshold(0)
        print("[Scene3DBackend] VoxelPhysicsWorld ready")
    else
        voxelWorld_ = nil
        print("[Scene3DBackend] VoxelPhysicsWorld unavailable, fallback CustomGeometry ok="
            .. tostring(okVoxel) .. " result=" .. tostring(voxelWorld))
    end

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
    CreateWorldEdges()
    CreateDangerBand()

    -- 保持项目的固定 9:16 玩法契约，用斜俯视正交投影呈现飞机厚度，避免透视导致敌人远近缩放和触控映射漂移。
    cameraNode_ = scene_:CreateChild("Camera")
    local cameraDistance = 25.0
    local cameraTilt = math.rad(46.0)
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
    UpdateProjectionMetrics(true)
    ProbeFxaa()    -- WO-16/P9：FXAA 探测（本环境应判定不可用并保持关闭，保全 3D 画面）

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
        nvgFontZpix_ = -1
        CleanupFailedInit()
        return false
    end
    nvgFontZpix_ = fontId

    if not Renderer3D.Init(scene_, voxelWorld_) then
        print("[Scene3DBackend] ERROR: Renderer3D initialization failed")
        CleanupFailedInit()
        return false
    end
    SubscribeToEvent(vg_, "NanoVGRender", renderHandlerName)
    print("[Scene3DBackend] initialized: 9:16 locked viewport, dark-tech HUD, orthographic 46-degree aircraft camera")
    return true
end

function Backend.Shutdown()
    Renderer3D.Shutdown()
    if vg_ then
        nvgDelete(vg_)
        vg_ = nil
    end
    nvgFontZpix_ = -1
    renderer:SetViewport(0, nil)
    ReleaseScene()
end

function Backend.Resize()
    UpdateScreenMetrics()
    UpdateProjectionMetrics(true)
end

-- WO-15/P2：封装投影刷新。相机震屏位移后必须由后端统一刷新当前投影 offset/scale，
-- 使 NanoVG 轨迹、瞄准输入与空间反馈共享同一组参数，禁止各自重算或把屏幕坐标直传规则层。
function Backend.RefreshProjection()
    UpdateProjectionMetrics(false)
end

-- WO-15/P2：投影参数只读暴露，供表现层在不重算的前提下复用（如主调用已刷新）。
function Backend.GetProjection()
    return projectionOffsetX_, projectionOffsetY_, projectionScaleX_, projectionScaleY_
end

function Backend.IsInsideGameCanvas(screenX, screenY)
    return screenX >= viewportLeft_
        and screenX < viewportLeft_ + viewportWidth_
        and screenY >= viewportTop_
        and screenY < viewportTop_ + viewportHeight_
end

function Backend.ScreenToUi(screenX, screenY)
    local logicalX = screenX / dpr_
    local logicalY = screenY / dpr_
    return logicalX / scale_ - offsetX_, logicalY / scale_ - offsetY_
end

function Backend.ScreenToGame(screenX, screenY)
    local canvasX, canvasY = Backend.ScreenToUi(screenX, screenY)
    return (canvasX - projectionOffsetX_) / projectionScaleX_,
        (canvasY - projectionOffsetY_) / projectionScaleY_
end

-- 游戏快照在 Update 结束后已经稳定；在本帧 3D 绘制之前同步场景与体素。
-- NanoVGRender 晚于 3D Viewport，不能在其中才 RebuildGeometry，否则必然看到旧网格。
function Backend.UpdateScene(gameSnapshot, presentationSnapshot)
    UpdateUiState(gameSnapshot)
    UpdateSpaceEnvironment(gameSnapshot.elapsed)
    local shake = presentationSnapshot.screenShake or 0
    if cameraNode_ then
        cameraNode_.position = cameraBasePosition_ + Vector3(
            math.sin(gameSnapshot.elapsed * 97) * shake * 0.10,
            math.cos(gameSnapshot.elapsed * 79) * shake * 0.08,
            math.sin(gameSnapshot.elapsed * 61) * shake * 0.035)
        -- P12：防线受创时的相机推近（orthoSize 下沉），与四位一体反馈同步。
        -- 仍正交投影，仅瞬时缩放视野，不引入透视近大远小。
        if camera_ then
            local pushIn = (presentationSnapshot.baseBarrierFlash or 0) * 1.6
            camera_.orthoSize = 18.0 - pushIn
        end
        UpdateProjectionMetrics(false)
    end
    if dangerBandNode_ then
        local flash = presentationSnapshot.baseBarrierFlash or 0
        -- A6：Boss 波期间危险带常驻染成紫色警示，与普通波区分。
        local bossActive = false
        for _, enemy in ipairs(gameSnapshot.veggies or {}) do
            if enemy.isBoss then bossActive = true; break end
        end
        local baseR, baseG, baseB = 0.39, 0.19, 0.67
        if bossActive then baseR, baseG, baseB = 0.62, 0.20, 0.74 end
        dangerBandNode_.scale = Vector3(11.0, 0.06 + flash * 0.18, 0.06 + flash * 0.12)
        if dangerBandMaterial_ then
            dangerBandMaterial_:SetShaderParameter("MatDiffColor", Variant(Color(
                math.min(1.0, baseR + flash * 0.20),
                math.min(1.0, baseG + flash * 0.48),
                math.min(1.0, baseB + flash * 0.33), 1)))
            dangerBandMaterial_:SetShaderParameter("MatEmissiveColor", Variant(Color(
                flash * 1.7 + (bossActive and 1.2 or 0),
                flash * 3.1 + (bossActive and 0.6 or 0),
                flash * 4.0 + (bossActive and 2.4 or 0), 1)))
        end
    end
    -- 升级/暂停/菜单时停体素求解，避免碎块在模态下继续飞。
    if voxelWorld_ then
        local playing = gameSnapshot.state == "playing"
        voxelWorld_:SetSimulationPaused(not playing)
    end
    Renderer3D.Render(gameSnapshot, presentationSnapshot)
end

function Backend.RenderOverlay(gameSnapshot, presentationSnapshot, metaState)
    RenderOverlay(gameSnapshot, presentationSnapshot, metaState)
end

-- v0.11.0 商业化：元层界面命中判定（与绘制共用同一批布局函数）。
---@return string|nil action
function Backend.HitTestMenuBar(uiX, uiY, metaState)
    if not metaState then return nil end
    return MetaUI.HitTestMenuBar(uiX, uiY, metaState)
end

---@return string|nil action
---@return integer|nil index
function Backend.HitTestMetaScreen(uiX, uiY, metaState)
    if not metaState or not metaState.screen then return nil, nil end
    return MetaUI.HitTestScreen(uiX, uiY, DESIGN_W, metaState)
end

---@return string|nil action
function Backend.HitTestSupplyPopup(uiX, uiY, metaState)
    if not metaState or not metaState.supplyOpen then return nil end
    return MetaUI.HitTestSupplyPopup(uiX, uiY, DESIGN_W)
end

function Backend.HitTestGameOverButton(uiX, uiY, game)
    local revive, double, restart = GetGameOverButtonLayout(game or {})
    local function inside(btn)
        return uiX >= btn.x and uiX <= btn.x + btn.w
            and uiY >= btn.y and uiY <= btn.y + btn.h
    end
    if inside(revive) then return "revive" end
    if inside(double) then return "double" end
    if inside(restart) then return "restart" end
    return nil
end

-- v0.11.0 商业化：升级面板命中判定。
-- 与 DrawLevelUp 共用 GetUpgradePanelLayout，视觉与命中永远同源。
---@param uiX number
---@param uiY number
---@param game table
---@return string|nil kind
---@return integer|nil index
function Backend.HitTestUpgradePanel(uiX, uiY, game)
    local layout = GetUpgradePanelLayout(game or {})
    local function inside(rect)
        return uiX >= rect.x and uiX <= rect.x + rect.w
            and uiY >= rect.y and uiY <= rect.y + rect.h
    end

    if inside(layout.rerollFree) then return "reroll_free", nil end
    if inside(layout.rerollAd) then return "reroll_ad", nil end
    if inside(layout.fourth) then return "fourth", nil end
    if inside(layout.extraPick) then return "extra_pick", nil end

    local choices = (game and game.upgradeChoices) or {}
    local cardTop = layout.cy - layout.cardH * 0.5
    for i = 1, layout.cardCount do
        local cx = layout.startX + (i - 1) * (layout.cardW + layout.gap)
        -- 升格角标优先于卡片本体，避免点角标被当成选卡。
        if inside(GetBoostBadgeRect(cx, cardTop, layout.cardW)) then
            return "boost", i
        end
        if math.abs(uiX - cx) <= layout.cardW * 0.5 + 4
            and math.abs(uiY - layout.cy) <= layout.cardH * 0.5 + 4 then
            return "card", i
        end
    end
    if choices[4] and inside(layout.extra) then
        if choices[4].locked then return "fourth", nil end
        return "card", 4
    end
    return nil, nil
end

-- v0.11.0 商业化：暂停补给站命中判定（与 DrawPaused 同源）。
---@return string|nil kind "pause_heal" | "pause_rare"
function Backend.HitTestPausePanel(uiX, uiY, game)
    local layout = GetPausePanelLayout((game and game.width) or DESIGN_W)
    local function inside(r)
        return uiX >= r.x and uiX <= r.x + r.w and uiY >= r.y and uiY <= r.y + r.h
    end
    if inside(layout.heal) then return "pause_heal" end
    if inside(layout.rare) then return "pause_rare" end
    return nil
end

function Backend.GetDesignSize()
    return DESIGN_W, DESIGN_H
end

return Backend
