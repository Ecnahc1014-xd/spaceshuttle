-- Scene3DBackend.lua
-- 3D 场景后端：固定 540x960 设计坐标，使用正交相机呈现体素敌人与运输车。

local Renderer3D = require "Renderer3D"
local SkyUtils = require "urhox-libs.Rendering.SkyUtils"

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
    normal = {190, 160, 255}, ice = {154, 226, 255},
    speed = {112, 176, 255}, giant = {226, 194, 255},
}

local ACID = {
    void = {26, 17, 64, 255},
    deepPurple = {42, 31, 94, 250},
    purple = {100, 76, 194, 255},
    brightPurple = {168, 85, 247, 255},
    paleBlue = {61, 214, 232, 255},
    coldBlue = {74, 139, 245, 255},
    carbon = {42, 31, 94, 255},
    muted = {255, 255, 255, 85},
}

-- Astroon 蓝紫宇宙主题：深蓝紫背景、紫色分层表面、蓝/青强调、白色文字、金色唯一主 CTA。
local UI_BLUE = {74, 139, 245, 255}
local UI_CYAN = {61, 214, 232, 255}
local UI_BLUE_DARK = {42, 31, 94, 255}
local UI_SURFACE = {61, 42, 138, 255}
local UI_WHITE = {255, 255, 255, 255}
local UI_COLD = {255, 255, 255, 170}
local UI_MUTED = {255, 255, 255, 85}
local UI_GOLD = {255, 213, 79, 255}
local UI_INK = {26, 17, 64, 255}
local UI_BLACK = {12, 8, 32, 255}

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

local function DrawBaseImpactFeedback(ctx, game, presentation)
    local _, dangerScreenY = ProjectGamePoint(0, game.dangerY)
    local flash = presentation.baseBarrierFlash or 0
    if flash > 0 then
        local alpha = math.floor(math.min(1, flash / 0.62) * 180)
        local glow = nvgLinearGradient(ctx, 0, dangerScreenY - 52, 0, dangerScreenY + 42,
            nvgRGBA(103, 61, 166, 0), nvgRGBA(166, 229, 255, alpha))
        nvgBeginPath(ctx)
        nvgRect(ctx, 0, dangerScreenY - 52, game.width, 94)
        nvgFillPaint(ctx, glow)
        nvgFill(ctx)

        nvgBeginPath(ctx)
        nvgMoveTo(ctx, 0, dangerScreenY)
        nvgLineTo(ctx, game.width, dangerScreenY)
        nvgStrokeColor(ctx, nvgRGBA(186, 229, 255, alpha))
        nvgStrokeWidth(ctx, 4 + 7 * flash)
        nvgStroke(ctx)
    end

    for _, impact in ipairs(presentation.baseImpacts or {}) do
        local screenX, screenY = ProjectGamePoint(impact.x, impact.y)
        local progress = 1 - impact.life / impact.maxLife
        local alpha = math.floor(255 * (1 - progress))
        nvgBeginPath(ctx)
        nvgCircle(ctx, screenX, screenY, impact.radius * math.abs(projectionScaleX_))
        nvgStrokeColor(ctx, nvgRGBA(184, 133, 255, alpha))
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

-- 中文/ASCII 混排自动换行：按像素宽度贪心折行，返回行数。
-- 用 nvgTextBounds 实测宽度，避免按固定字数硬切。align: center 时按行居中。
local function WrapTextLines(ctx, text, size, maxWidth)
    local lines = {}
    local line = ""
    nvgFontFace(ctx, "zpix")
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

local function DrawAstroonBackdrop(ctx, x, y, width, height)
    local gradient = nvgLinearGradient(ctx, x, y, x, y + height,
        nvgRGBA(26, 17, 64, 255), nvgRGBA(45, 27, 105, 255))
    nvgBeginPath(ctx)
    nvgRect(ctx, x, y, width, height)
    nvgFillPaint(ctx, gradient)
    nvgFill(ctx)
end

local function DrawBluePanel(ctx, x, y, width, height, fill, border, radius)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x, y, width, height, radius or 8)
    nvgFillColor(ctx, nvgRGBA(fill[1], fill[2], fill[3], fill[4] or 255))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(border[1], border[2], border[3], border[4] or 255))
    nvgStrokeWidth(ctx, 2)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x + 1, y + 1, width - 2, height - 2, radius or 8)
    nvgStroke(ctx)
end

local function DrawSegmentedRule(ctx, x, y, width, segments, color, activeCount)
    local gap = 5
    local segmentWidth = (width - gap * (segments - 1)) / segments
    for i = 1, segments do
        nvgBeginPath(ctx)
        nvgRect(ctx, x + (i - 1) * (segmentWidth + gap), y, segmentWidth, 4)
        local active = not activeCount or i <= activeCount
        nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], active and 255 or 55))
        nvgFill(ctx)
    end
end

local function DrawDotMatrix(ctx, x, y, columns, rows, spacing, color, radius)
    nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
    for row = 0, rows - 1 do
        for col = 0, columns - 1 do
            nvgBeginPath(ctx)
            nvgCircle(ctx, x + col * spacing, y + row * spacing, radius or 1.4)
            nvgFill(ctx)
        end
    end
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

local function DrawAmmoSlots(ctx, game, presentation)
    local queueCounts = {}
    for _, ballType in ipairs(game.ballQueue or {}) do
        queueCounts[ballType] = (queueCounts[ballType] or 0) + 1
    end
    if game.activeBall then
        queueCounts[game.activeBall.ballType] = (queueCounts[game.activeBall.ballType] or 0) + 1
    end

    nvgBeginPath(ctx)
    nvgRect(ctx, 0, BOTTOM_DOCK_Y, DESIGN_W, DESIGN_H - BOTTOM_DOCK_Y)
    nvgFillColor(ctx, nvgRGBA(UI_INK[1], UI_INK[2], UI_INK[3], 255))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, 0, BOTTOM_DOCK_Y)
    nvgLineTo(ctx, DESIGN_W, BOTTOM_DOCK_Y)
    nvgStrokeColor(ctx, nvgRGBA(UI_WHITE[1], UI_WHITE[2], UI_WHITE[3], 230))
    nvgStrokeWidth(ctx, 2)
    nvgStroke(ctx)

    DrawPixelText(ctx, 12, BOTTOM_DOCK_Y + 10, "ORDNANCE / FIRE CONTROL", 9, UI_COLD)
    DrawPixelText(ctx, DESIGN_W - 12, BOTTOM_DOCK_Y + 10,
        "SLOT LINK // ACTIVE", 8, UI_GOLD, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)

    local slotSize = 62
    local slotGap = 8
    local slotY = BOTTOM_DOCK_Y + 28
    local leftStart = 10
    local rightStart = DESIGN_W - 10 - slotSize * 2 - slotGap
    for i, ballType in ipairs(SLOT_TYPES) do
        local pairIndex = (i - 1) % 2
        local x = (i <= 2 and leftStart or rightStart) + pairIndex * (slotSize + slotGap)
        local color = SLOT_COLORS[ballType]
        local selected = game.activeBall and game.activeBall.ballType == ballType
        local flash = presentation.truckLaunchFlash[ballType] or 0
        local fill = selected and {23, 37, 112, 255} or {11, 16, 54, 255}
        local border = selected and UI_GOLD or {color[1], color[2], color[3], 220}
        DrawTechPanel(ctx, x, slotY, slotSize, slotSize, fill, border)
        DrawPixelText(ctx, x + 7, slotY + 6, string.format("%02d", i), 8, color)
        DrawPixelText(ctx, x + slotSize - 7, slotY + 6,
            "x" .. tostring(queueCounts[ballType] or 0), 8, color,
            NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
        DrawPixelText(ctx, x + slotSize * 0.5, slotY + 22, SLOT_NAMES[ballType], 12,
            UI_WHITE, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        DrawPixelText(ctx, x + slotSize * 0.5, slotY + 43,
            selected and "READY" or "STANDBY", 7, selected and UI_GOLD or UI_COLD,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgBeginPath(ctx)
        nvgRect(ctx, x + 6, slotY + slotSize - 7, slotSize - 12, selected and 3 or 1)
        nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], selected and 255 or 125))
        nvgFill(ctx)
    end
end

local function DrawLetterboxBackground(ctx, width, height)
    -- NanoVG 位于 3D Viewport 之后：只填充设计画布外的 letterbox，绝不能覆盖画布内部。
    nvgFillColor(ctx, nvgRGBA(UI_BLACK[1], UI_BLACK[2], UI_BLACK[3], 255))
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

local function DrawWaveThemeTint(ctx, width, height, game)
    -- A5：背景主题色随波次缓慢轮转（酸性风格内，仅边缘渐变为冷/暖色相位移），
    -- 让长局不单调。色调由 wave 驱动，不破坏深紫基调与工程线美学。
    local phase = (game.wave or 1) * 0.18
    local r = math.floor(40 + 22 * math.sin(phase))
    local b = math.floor(90 + 26 * math.cos(phase * 0.7))
    local g = math.floor(30 + 14 * math.sin(phase * 1.3 + 1.2))
    local glow = nvgLinearGradient(ctx, 0, 0, 0, height,
        nvgRGBA(r, g, b, 16), nvgRGBA(UI_BLUE_DARK[1], UI_BLUE_DARK[2], UI_BLUE_DARK[3], 0))
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, width, height)
    nvgFillPaint(ctx, glow)
    nvgFill(ctx)
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
    DrawPixelText(ctx, cx, y - 14, "BOSS // PHASE LOCK", 9, ACID.brightPurple,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    local segments = 3
    local segW = barW / segments
    for s = 1, segments do
        local filled = s <= (boss.bossPhase or 1)
        local vul = (boss.bossPhase == 2)
        local col = filled and (vul and {235, 190, 255} or {166, 229, 255}) or {81, 105, 158}
        DrawTechPanel(ctx, x0 + (s - 1) * segW + 2, y, segW - 4, 12,
            filled and {40, 18, 70, 255} or {16, 12, 35, 255}, col)
        if filled then
            DrawPixelText(ctx, x0 + (s - 1) * segW + segW * 0.5, y + 1, tostring(s), 9,
                col, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        end
    end
    if boss.bossPhase == 2 then
        local pulse = 0.5 + 0.5 * math.sin(game.elapsed * 6)
        DrawPixelText(ctx, cx, y + 16,
            string.format("VULNERABLE x1.5  (%.0f%%)", (boss.bossPhase or 1) / segments * 100),
            9, {235, 190, 255, 150 + math.floor(105 * pulse)},
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
end

local function DrawHud(ctx, game)
    local hpRatio = game.maxBaseHp > 0 and game.baseHp / game.maxBaseHp or 0
    local hpColor = hpRatio > 0.35 and UI_COLD or UI_GOLD

    -- 重构后的战术仪表盘：左侧分数，中部波次，右侧基地状态，底部统一经验进度。
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, game.width, HUD_HEIGHT)
    nvgFillColor(ctx, nvgRGBA(UI_INK[1], UI_INK[2], UI_INK[3], 255))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, 0, HUD_HEIGHT - 1)
    nvgLineTo(ctx, game.width, HUD_HEIGHT - 1)
    nvgStrokeColor(ctx, nvgRGBA(UI_WHITE[1], UI_WHITE[2], UI_WHITE[3], 220))
    nvgStrokeWidth(ctx, 2)
    nvgStroke(ctx)

    DrawPixelText(ctx, 12, 9, "FLIGHT CONTROL", 8, UI_COLD)
    DrawPixelText(ctx, 12, 25, string.format("%06d", game.score), 23, UI_WHITE)
    DrawPixelText(ctx, 12, 57, "BEST " .. string.format("%06d", game.highScore), 8, ACID.muted)

    local centerX = game.width * 0.5
    DrawPixelText(ctx, centerX, 8, "WAVE", 8, UI_GOLD, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawPixelText(ctx, centerX, 22, string.format("%02d", game.wave), 25, UI_WHITE,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawPixelText(ctx, centerX, 53,
        string.format("HOSTILES %02d  //  COMBO %02d", game.concurrentCount or 0, game.clearStreak or 0),
        7, UI_COLD, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    DrawPixelText(ctx, game.width - 12, 9, "BASE INTEGRITY", 8, UI_COLD,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width - 12, 24,
        string.format("%03d / %03d", game.baseHp, game.maxBaseHp), 19, hpColor,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width - 12, 52, "CORE STATUS / " .. (hpRatio > 0.35 and "STABLE" or "CRITICAL"),
        7, hpColor, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    DrawPixelBar(ctx, game.width - 164, 66, 152, 8, hpRatio, hpColor)

    local xpRatio = game.xpToNext > 0 and game.xp / game.xpToNext or 0
    DrawPixelText(ctx, 12, 76, string.format("LV %02d", game.playerLevel), 7, UI_GOLD)
    DrawPixelBar(ctx, 52, 78, 220, 5, xpRatio, UI_BLUE)
    DrawPixelText(ctx, 282, 76,
        string.format("XP %d/%d", math.floor(game.xp or 0), game.xpToNext or 0), 7, ACID.muted)

    local words = game.activeWords or {}
    -- 词条徽标：NanoVG 程序化绘制（不依赖外部 PNG），每个词条一个高亮方块 + 汉字。
    local WORD_BADGE = {
        pierce = {label = "贯", color = {255, 213, 79}},
        chain = {label = "链", color = {120, 224, 168}},
        momentum = {label = "量", color = {255, 138, 101}},
    }
    local iconSize = 24
    local iconX = game.width - 12 - #words * (iconSize + 5)
    local iconY = 64
    for i, wordId in ipairs(words) do
        local badge = WORD_BADGE[wordId]
        local ix = iconX + (i - 1) * (iconSize + 5)
        local bc = badge and badge.color or UI_COLD
        DrawTechPanel(ctx, ix, iconY, iconSize, iconSize, UI_BLUE_DARK, bc)
        if badge then
            DrawPixelText(ctx, ix + iconSize * 0.5, iconY + 5, badge.label, 13, bc,
                NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        end
    end

    local boss = FindBoss(game)
    if boss then DrawBossPhaseBar(ctx, game, boss) end
end

local function DrawMenu(ctx, game)
    nvgSave(ctx)
    nvgIntersectScissor(ctx, 0, MENU_CONTENT_TOP, game.width, game.height - MENU_CONTENT_TOP)
    nvgGlobalAlpha(ctx, ModalIntro(game))
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, MENU_CONTENT_TOP, game.width, game.height - MENU_CONTENT_TOP)
    DrawAstroonBackdrop(ctx, 0, MENU_CONTENT_TOP, game.width, game.height - MENU_CONTENT_TOP)
    DrawAcidGrid(ctx, game.width, game.height)
    DrawDotMatrix(ctx, 34, 142, 11, 8, 13, {61, 214, 232, 36}, 1.5)
    DrawDotMatrix(ctx, 414, 318, 8, 13, 13, {28, 62, 224, 36}, 1.5)

    DrawPixelText(ctx, 24, 112, "SANCTUARY / FLIGHT TRIAL", 8, UI_BLUE)
    DrawPixelText(ctx, game.width - 24, 112, "BUILD 0.10.17", 8, UI_BLUE,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    DrawSegmentedRule(ctx, 24, 132, game.width - 48, 8, UI_BLUE)

    DrawHalo(ctx, game.width * 0.5, 270, 116, 150)
    DrawHalo(ctx, game.width * 0.5, 270, 84, 95)
    nvgBeginPath(ctx)
    nvgCircle(ctx, game.width * 0.5, 270, 7)
    nvgFillColor(ctx, nvgRGBA(UI_GOLD[1], UI_GOLD[2], UI_GOLD[3], 255))
    nvgFill(ctx)
    DrawPixelText(ctx, game.width * 0.5, 215, "太空飞机弹珠", 35, UI_BLUE,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width * 0.5, 320, "SPACECRAFT MARBLE", 11, UI_BLUE,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width * 0.5, 348, "轨道计算  /  碰撞反射  /  火控链接", 12, UI_INK,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    DrawBluePanel(ctx, 30, 414, game.width - 60, 92, UI_BLUE, UI_BLUE, 7)
    DrawPixelText(ctx, 52, 432, "PILOT LINK", 9, UI_WHITE)
    DrawPixelText(ctx, 52, 457, "点击屏幕开始飞行", 19, UI_WHITE)
    DrawPixelText(ctx, 52, 484, "INITIATE FLIGHT VECTOR", 8, UI_COLD)
    DrawPixelText(ctx, game.width - 52, 447, "01", 30, UI_GOLD,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width - 52, 484, "READY", 8, UI_WHITE,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)

    DrawPixelText(ctx, 30, 550, "MISSION PARAMETERS", 8, UI_BLUE)
    DrawBluePanel(ctx, 30, 568, game.width - 60, 106, UI_BLUE_DARK, UI_BLUE, 10)
    DrawPixelText(ctx, 48, 586, "BASE CORE", 8, UI_BLUE)
    DrawPixelText(ctx, 48, 608, "100", 24, UI_WHITE)
    DrawPixelText(ctx, 108, 615, "INTEGRITY", 8, UI_COLD)
    DrawPixelText(ctx, 290, 586, "ORDNANCE", 8, UI_BLUE)
    DrawPixelText(ctx, 290, 608, "04", 24, UI_WHITE)
    DrawPixelText(ctx, 350, 615, "LOADOUTS", 8, UI_COLD)
    DrawSegmentedRule(ctx, 48, 650, game.width - 96, 12, UI_BLUE)

    DrawPixelText(ctx, 30, 716, "TOUCH / MOUSE  :  AIM + RELEASE", 8, UI_BLUE)
    DrawPixelText(ctx, 30, 739, "P / ESC          :  PAUSE", 8, UI_BLUE)
    DrawPixelText(ctx, game.width - 30, 786, "SYSTEM LINKED", 8, UI_GOLD,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    DrawSegmentedRule(ctx, 30, 812, game.width - 60, 4, UI_GOLD)
    nvgRestore(ctx)
end

local function DrawGameOver(ctx, game)
    nvgSave(ctx)
    nvgIntersectScissor(ctx, 0, MENU_CONTENT_TOP,
        game.width, game.height - MENU_CONTENT_TOP)
    nvgGlobalAlpha(ctx, ModalIntro(game))    -- A1：结算缓入
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, MENU_CONTENT_TOP, game.width, game.height - MENU_CONTENT_TOP)
    DrawAstroonBackdrop(ctx, 0, MENU_CONTENT_TOP, game.width, game.height - MENU_CONTENT_TOP)
    DrawAcidGrid(ctx, game.width, game.height)
    DrawHalo(ctx, game.width * 0.5, 390, 125, 180)
    DrawPixelText(ctx, game.width * 0.5, 330, "链接中断", 36, UI_WHITE,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width * 0.5, 380, "FLIGHT CONTROL OFFLINE", 10,
        UI_CYAN, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width * 0.5, 430,
        string.format("SCORE %d  /  BEST %d  /  WAVE %02d",
            game.score, game.highScore, game.wave), 13, ACID.paleBlue,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    -- WO-11/P8：结算回顾面板（只读快照统计，强化幸存者正反馈）。
    DrawBluePanel(ctx, 24, 446, game.width - 48, 76, UI_BLUE_DARK, UI_BLUE, 10)
    DrawPixelText(ctx, 40, 458, string.format("到达波次 %02d", game.wave), 12, ACID.paleBlue,
        NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    DrawPixelText(ctx, 40, 478, string.format("等级 LV %02d", game.playerLevel), 12, ACID.brightPurple,
        NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    DrawPixelText(ctx, 40, 498, string.format("击碎砖块 %d", game.bricksBroken or 0), 12, ACID.coldBlue,
        NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width - 40, 458, string.format("强化 %d 次", #(game.upgradePicks or {})), 12,
        ACID.paleBlue, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width - 40, 478, string.format("连击 %d", game.clearStreak or 0), 12,
        ACID.brightPurple, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width - 40, 498, string.format("存活 %.0fs", game.elapsed or 0), 12,
        ACID.coldBlue, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    DrawTechPanel(ctx, 0, 530, game.width, 66, ACID.deepPurple, ACID.paleBlue)
    DrawPixelText(ctx, game.width * 0.5, 548, "点击重新建立链接", 18,
        ACID.paleBlue, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width * 0.5, 614, "SESSION SEALED // AWAITING RESTART", 8,
        ACID.muted, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgRestore(ctx)
end

local UPGRADE_RARITY = {
    common = {tag = "标准", color = {120, 200, 245}},
    rare = {tag = "稀有", color = {255, 213, 79}},
    epic = {tag = "史诗", color = {214, 130, 255}},
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

local function DrawUpgradeCard(ctx, index, choice, cx, cy, cardW, cardH)
    local x = cx - cardW * 0.5
    local y = cy - cardH * 0.5
    local rare = UPGRADE_RARITY[choice.rarity] or UPGRADE_RARITY.common
    local accent = rare.color
    local titleColor = UI_WHITE
    DrawBluePanel(ctx, x, y, cardW, cardH, UI_SURFACE, accent, 12)

    -- 顶部强调条 + 序号圆点。
    nvgBeginPath(ctx)
    nvgRect(ctx, x + 10, y, cardW - 20, 6)
    nvgFillColor(ctx, nvgRGBA(accent[1], accent[2], accent[3], 255))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgCircle(ctx, x + cardW - 22, y + 30, 13)
    nvgFillColor(ctx, nvgRGBA(UI_INK[1], UI_INK[2], UI_INK[3], 235))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(accent[1], accent[2], accent[3], 255))
    nvgStrokeWidth(ctx, 1.5)
    nvgStroke(ctx)
    DrawPixelText(ctx, x + cardW - 22, y + 22, tostring(index), 13, accent,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    -- 标题：15px 单行（当前天赋名最长 7 个汉字，实测宽度收在卡片内）。
    DrawPixelText(ctx, x + cardW * 0.5, y + 22, choice.name or "强化协议", 15, titleColor,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    -- 稀有度标签（居中一行）。
    DrawPixelText(ctx, x + cardW * 0.5, y + 50,
        (choice.kind == "word" and "词条 · " or "强化 · ") .. rare.tag, 11, rare.color,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    -- 分隔线。
    DrawSegmentedRule(ctx, x + 16, y + 74, cardW - 32, 6, accent)

    -- 详情：12px 自动换行展示完整效果说明。文本块在分隔线与底部信息区之间垂直居中，
    -- 避免 2-3 行短文案堆在卡片上部、中下部留空洞。
    local detailLines = WrapTextLines(ctx,
        choice.detail or choice.desc or "提升当前火控系统性能", 12, cardW - 28)
    local detailLineH = 18
    local maxDetailLines = 6
    local detailCount = math.min(maxDetailLines, #detailLines)
    local detailAreaTop = y + 88
    local detailAreaBottom = y + cardH - 92     -- 底部标签/徽标区从 y+208 起
    local detailTop = detailAreaTop
        + math.max(0, (detailAreaBottom - detailAreaTop - detailCount * detailLineH) * 0.5)
    for li = 1, detailCount do
        DrawPixelText(ctx, x + cardW * 0.5, detailTop + (li - 1) * detailLineH,
            detailLines[li], 12, UI_COLD, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end

    -- 风险/词条说明（抉择型），固定在底部信息区，避免与详情重叠。
    local footerTop = y + cardH - 84
    if choice.tradeoff then
        DrawTechPanel(ctx, x + 12, footerTop, cardW - 24, 24, {38, 20, 58}, {255, 138, 101})
        DrawPixelText(ctx, x + cardW * 0.5, footerTop + 5, "高风险 / 高回报", 11,
            {255, 168, 130}, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    elseif choice.kind == "word" then
        DrawTechPanel(ctx, x + 12, footerTop, cardW - 24, 24, {24, 34, 66}, accent)
        DrawPixelText(ctx, x + cardW * 0.5, footerTop + 5, "永久词条 · 一次性", 11, accent,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end

    -- 增量徽标。
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x + 16, y + cardH - 52, cardW - 32, 26, 6)
    nvgFillColor(ctx, nvgRGBA(accent[1], accent[2], accent[3], 38))
    nvgFill(ctx)
    DrawPixelText(ctx, x + cardW * 0.5, y + cardH - 46, choice.value or "强化", 13, accent,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    -- 已选层数 / 上限（无上限的维修显示 ∞）。提亮并上移，不再贴住卡底圆角边。
    local stacks = choice.stacks or 0
    local maxText = choice.maxStacks and choice.maxStacks >= 90 and "∞" or tostring(choice.maxStacks or "-")
    DrawPixelText(ctx, x + cardW * 0.5, y + cardH - 21,
        "已装配 " .. tostring(stacks) .. " / " .. maxText, 9, {184, 196, 226, 255},
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
end

local function DrawLevelUp(ctx, game)
    nvgSave(ctx)
    nvgIntersectScissor(ctx, 0, MENU_CONTENT_TOP, game.width, game.height - MENU_CONTENT_TOP)
    nvgGlobalAlpha(ctx, ModalIntro(game))
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, MENU_CONTENT_TOP, game.width, game.height - MENU_CONTENT_TOP)
    DrawAstroonBackdrop(ctx, 0, MENU_CONTENT_TOP, game.width, game.height - MENU_CONTENT_TOP)
    DrawAcidGrid(ctx, game.width, game.height)
    DrawDotMatrix(ctx, 28, 152, 10, 7, 14, {61, 214, 232, 28}, 1.3)
    DrawDotMatrix(ctx, 414, 700, 8, 8, 14, {74, 139, 245, 36}, 1.3)

    DrawPixelText(ctx, 24, 104, "SANCTUARY / UPGRADE RITE", 8, UI_BLUE)
    DrawPixelText(ctx, game.width - 24, 104, "PAUSED / SELECT ONE", 8, UI_GOLD,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    DrawSegmentedRule(ctx, 24, 124, game.width - 48, 8, UI_BLUE)
    DrawPixelText(ctx, game.width * 0.5, 150, "升级 // 选择强化", 29, UI_BLUE,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width * 0.5, 196,
        string.format("LEVEL %02d  /  CHOOSE ONE PROTOCOL", game.playerLevel), 9, UI_COLD,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    local choices = game.upgradeChoices or {}
    local cardW, cardH, gap, startX, cy = GetUpgradeCardLayout(game)
    if #choices > 0 then
        for i, choice in ipairs(choices) do
            DrawUpgradeCard(ctx, i, choice,
                startX + (i - 1) * (cardW + gap), cy, cardW, cardH)
        end
    else
        DrawBluePanel(ctx, 30, 365, game.width - 60, 100, UI_BLUE_DARK, UI_BLUE, 8)
        DrawPixelText(ctx, game.width * 0.5, 395, "NO PROTOCOLS AVAILABLE", 12, UI_WHITE,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        DrawPixelText(ctx, game.width * 0.5, 423, "WAITING FOR RULE TABLE", 8, UI_COLD,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end

    DrawPixelText(ctx, 24, 704, "CHOOSE ONE  /  GAMEPLAY PAUSED", 9, UI_BLUE)
    DrawPixelText(ctx, game.width - 24, 704, "TAP A CARD TO EQUIP", 9, UI_GOLD,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    DrawSegmentedRule(ctx, 24, 726, game.width - 48, 4, UI_GOLD)
    nvgRestore(ctx)
end

local function DrawPaused(ctx, game)
    nvgSave(ctx)
    nvgIntersectScissor(ctx, 0, MENU_CONTENT_TOP,
        game.width, game.height - MENU_CONTENT_TOP)
    nvgGlobalAlpha(ctx, ModalIntro(game))    -- A1：暂停缓入
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, MENU_CONTENT_TOP, game.width, game.height - MENU_CONTENT_TOP)
    DrawAstroonBackdrop(ctx, 0, MENU_CONTENT_TOP, game.width, game.height - MENU_CONTENT_TOP)
    DrawAcidGrid(ctx, game.width, game.height)
    DrawHalo(ctx, game.width * 0.5, 470, 120, 160)
    DrawPixelText(ctx, game.width * 0.5, 430, "暂停", 34, UI_WHITE,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width * 0.5, 482, "SYSTEM HALTED // PRESS P TO RESUME", 9,
        UI_COLD, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgRestore(ctx)
end

local function DrawWaveBanner(ctx, game, presentation)
    -- A2：波次横幅。waveBannerTimer 由 Presentation 维护（1.8 起递减），
    -- 入场用 ease 从上方滑入，生命周期尾部淡出；不破坏酸性风格，仅位移+透明度。
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
    DrawBluePanel(ctx, cx - 120, 150 + yOff, 240, 46, UI_BLUE_DARK, UI_CYAN, 10)
    DrawPixelText(ctx, cx, 160 + yOff, string.format("WAVE %02d INCOMING", game.wave), 14,
        UI_CYAN, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgRestore(ctx)
end

local function RenderOverlay(game, presentation)
    if not vg_ then return end
    nvgBeginFrame(vg_, logicalWidth_, logicalHeight_, dpr_)
    nvgResetTransform(vg_)
    nvgResetScissor(vg_)
    nvgGlobalAlpha(vg_, 1.0)
    nvgScale(vg_, scale_, scale_)
    DrawLetterboxBackground(vg_, screenDesignWidth_, screenDesignHeight_)
    nvgTranslate(vg_, offsetX_, offsetY_)
    nvgSave(vg_)
    nvgBeginPath(vg_)
    nvgRect(vg_, 0, 0, DESIGN_W, DESIGN_H)
    nvgStrokeColor(vg_, nvgRGBA(UI_CYAN[1], UI_CYAN[2], UI_CYAN[3], 180))
    nvgStrokeWidth(vg_, 2)
    nvgStroke(vg_)
    nvgBeginPath(vg_)
    nvgMoveTo(vg_, 0, 0)
    nvgLineTo(vg_, 0, DESIGN_H)
    nvgLineTo(vg_, DESIGN_W, DESIGN_H)
    nvgLineTo(vg_, DESIGN_W, 0)
    nvgStrokeColor(vg_, nvgRGBA(UI_CYAN[1], UI_CYAN[2], UI_CYAN[3], 150))
    nvgStrokeWidth(vg_, 3)
    nvgStroke(vg_)
    if game.state == "playing" then
        if presentation.screenShake > 0 then
            local amplitude = presentation.screenShake * 13
            nvgTranslate(vg_, math.sin(game.elapsed * 91) * amplitude,
                math.cos(game.elapsed * 73) * amplitude * 0.65)
        end
        DrawBaseImpactFeedback(vg_, game, presentation)
        DrawWaveBanner(vg_, game, presentation)
    end
    nvgRestore(vg_)

    nvgResetScissor(vg_)
    nvgResetTransform(vg_)
    nvgScale(vg_, scale_, scale_)
    nvgTranslate(vg_, offsetX_, offsetY_)
    nvgGlobalAlpha(vg_, 1.0)
    DrawHud(vg_, game)
    if game.state == "playing" then
        DrawAmmoSlots(vg_, game, presentation)
    elseif game.state == "menu" then
        DrawMenu(vg_, game)
    elseif game.state == "gameover" then
        DrawGameOver(vg_, game)
    elseif game.state == "levelup" then
        DrawLevelUp(vg_, game)
    elseif game.state == "paused" then
        DrawPaused(vg_, game)
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
        CleanupFailedInit()
        return false
    end

    if not Renderer3D.Init(scene_) then
        print("[Scene3DBackend] ERROR: Renderer3D initialization failed")
        CleanupFailedInit()
        return false
    end
    SubscribeToEvent(vg_, "NanoVGRender", renderHandlerName)
    print("[Scene3DBackend] initialized: 9:16 locked viewport, orthographic 46-degree aircraft camera, spacecraft aircraft UI")
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

function Backend.Render(gameSnapshot, presentationSnapshot)
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
    Renderer3D.Render(gameSnapshot, presentationSnapshot)
    RenderOverlay(gameSnapshot, presentationSnapshot)
end

function Backend.GetDesignSize()
    return DESIGN_W, DESIGN_H
end

return Backend
