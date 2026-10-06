-- Scene3DBackend.lua
-- 3D 场景后端：固定 540x960 设计坐标，使用正交相机呈现体素敌人与运输车。

local Renderer3D = require "Renderer3D"
local SkyUtils = require "urhox-libs.Rendering.SkyUtils"
local VisualCatalog = require "VisualCatalog"
local TalentCatalog = require "TalentCatalog"
local MetaUI = require "MetaUI"
local StageIntro = require "ui.StageIntro"

local Backend = {}

local DESIGN_W = 540
local DESIGN_H = 960
local HUD_HEIGHT = 92
local BOTTOM_DOCK_Y = 866
local MENU_CONTENT_TOP = HUD_HEIGHT

local scene_ = nil
local cameraNode_ = nil
local camera_ = nil
local cameraBasePosition_ = Vector3(0, 0, 0)
local viewport_ = nil
local lightGroup_ = nil
local zone_ = nil
local dangerBandNode_ = nil
local dangerBandMaterial_ = nil
-- v0.11.1：真正扣血的红线。与紫线（视觉警示带）分开：
--   紫线 = 原位置（近相机 z，斜俯视下投影到屏幕偏上），保留观感；
--   红线 = 与规则 brickBottom > DANGER_Y 完全同源的扣血判定位置。
local breachLineNode_ = nil
local breachLineMaterial_ = nil
local skyNode_ = nil
local starNode_ = nil
local starFields_ = {}
---@type VoxelPhysicsWorld|nil
local voxelWorld_ = nil
local CleanupFailedInit
local ReleaseScene
local vg_ = nil
-- v0.11.4：新手下拉手势图（dark-tech 青色线稿），只在 Backend.Init 里加载一次。
local handImage_ = -1
local HAND_IMAGE_PATH = "image/ui_hand_pull3_20260925153601.png"
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
-- 指针与控件缓动状态收进一张表，避免新增顶层 local 超限。
-- 控件主动登记自己的几何；普通面板/禁用控件不按尺寸继承交互。
local uiFx = { hover = { x = -999, y = -999, active = false }, anim = 0.0,
    pressed = false, controls = {}, epoch = 0, scope = "" }
local uiStateEnter_ = 0
local uiGameVisual_ = nil
local uiGameLeaving_ = nil
local uiGameLeaveAt_ = 0
local metaScreen_ = nil
local metaScreenEnter_ = 0
local metaScreenLeaving_ = nil
local metaScreenLeaveAt_ = 0
local metaSupply_ = false
local metaSupplyEnter_ = 0
local metaSupplyLeaving_ = nil
local metaSupplyLeaveAt_ = 0
local metaVisual_ = nil
local uiClock_ = 0
local uiLastElapsed_ = nil
local uiStateMotionEnter_ = 0

local function CopyVisualState(source)
    if not source then return nil end
    local copy = {}
    for k, v in pairs(source) do copy[k] = v end
    return copy
end

---@type table|nil
local lastGame_ = nil
---@type table|nil
local lastMeta_ = nil
-- v0.12.8：像素字标轮播随机起点（在下方 LOGO 块初始化前由 UpdateUiState 写入）。
local logoRollOffset_ = 0

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
    breachLineNode_ = nil
    breachLineMaterial_ = nil
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

-- 防线两条基准线，各司其职：
--   · 紫线 DangerBand —— 原位置（z=0.9 近相机视觉层），保留既有观感；
--   · 红线 BreachLine —— 与规则层 `Game.lua` 的 `brickBottom > DANGER_Y` 完全同源：
--     每帧按快照 dangerY 刷 y、z=0 与敌机体素同平面。
--     46° 斜俯视正交相机下 z 会投影到屏幕 Y，所以只有红线才精确落在“开始扣血”的瞬间。
local function CreateDangerBand()
    dangerBandNode_ = scene_:CreateChild("DangerBand")
    -- 紫线保持旧世界坐标（原位置），玩家已经习惯它作为防线视觉标记。
    dangerBandNode_.position = Vector3(0, -8.0, 0.9)
    dangerBandNode_.scale = Vector3(11.0, 0.06, 0.06)
    local model = dangerBandNode_:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    dangerBandMaterial_ = CreateMaterial({0.39, 0.19, 0.67}, 0.45)
    -- 常驻自发光：深空场景很暗，纯漫反射几乎看不见，防线必须一眼可辨。
    dangerBandMaterial_:SetShaderParameter("MatEmissiveColor",
        Variant(Color(0.26, 0.09, 0.46, 1)))
    model:SetMaterial(dangerBandMaterial_)
    model.castShadows = false

    -- 红线：真正的扣血判定线，初值取 DANGER_Y=900 的世界坐标。
    breachLineNode_ = scene_:CreateChild("BreachLine")
    breachLineNode_.position = Vector3(0, (DESIGN_H * 0.5 - 900) * 0.018, 0)
    breachLineNode_.scale = Vector3(11.0, 0.055, 0.055)
    local breachModel = breachLineNode_:CreateComponent("StaticModel")
    breachModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    breachLineMaterial_ = CreateMaterial({0.95, 0.16, 0.20}, 0.45)
    breachLineMaterial_:SetShaderParameter("MatEmissiveColor",
        Variant(Color(0.85, 0.10, 0.14, 1)))
    breachModel:SetMaterial(breachLineMaterial_)
    breachModel.castShadows = false
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
    -- v0.13.17：dark-tech skill 的「氛围层/装饰母题」令牌（tokens.md 同名）。
    -- wash 与 cyan 同族但更脏，克制档下只用于装饰与残影，不顶替主强调色。
    wash     = {0, 176, 168, 255},
    washDim  = {0, 90, 88, 255},
    ghost    = {186, 214, 255, 255},
    klein    = {48, 80, 240, 255},
    halftone = {20, 48, 120, 255},
    ash      = {128, 148, 154, 255},
    railMark = {92, 168, 162, 255},
}

local BUILD_VERSION = "0.13.32"
local GAME_TITLE = "击碎，飞机大战"
-- 主菜单像素大 logo 用的短名（对外全名仍是 GAME_TITLE，窗口/发布名不变）。
local GAME_SHORT_TITLE = "击碎飞机"

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
    -- v0.13.16：删除 projectionOriginNdcX_/Y_（写而不读的死变量）。
    -- 主块 local 数量逼近 Lua 上限 200——超限即 LoadChunk failed、整模块加载失败
    -- （真渲染才暴露，LSP/build 不报）。新增模块级 local 前先数槽位、优先收进表。
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

-- ============================================================================
-- v0.13.17：dark-tech skill 的「氛围层 + 装饰母题」（atmosphere.md / elements.md §3）。
-- 采用**克制档**（atmosphere.md「克制实装」）：只上底噪、扫描带、半调网点、残影、
-- 虚线/十字/环形刻度；**不接**强调色切换、文本异变、乱码事件——HUD 与战斗读数区
-- 一律不进入这些装饰，避免干扰可读性。全屏共享一个氛围标量（同帧只算一次）。
-- ============================================================================
local uiPulse_ = 0.0
local uiPulseAt_ = -1.0

-- 返回 0..1 的氛围标量：基线不为 0（界面不静止），偶发尖峰用取模周期而非随机。
local function AnomalyPulse(elapsed)
    if uiPulseAt_ == elapsed then return uiPulse_ end
    local pulse = 0.08 + 0.06 * (0.5 + 0.5 * math.sin(elapsed * 0.19))
    local cycle = (elapsed * 0.31) % 8.6
    if cycle < 0.16 then pulse = 1.0
    elseif cycle < 0.38 then pulse = 0.62
    elseif cycle < 0.52 then pulse = 0.28 end
    uiPulse_ = pulse
    uiPulseAt_ = elapsed
    return pulse
end

-- 虚线引线：标注、次级轴、关系连线
local function DrawDashLine(ctx, x1, y1, x2, y2, color, width, dash, gap)
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1 then return end
    local ux, uy = dx / len, dy / len
    local drawn = 0.0
    local d = dash or 4
    local g = gap or 4
    nvgStrokeColor(ctx, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
    nvgStrokeWidth(ctx, width or 1)
    while drawn < len do
        local stop = drawn + d
        if stop > len then stop = len end
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, x1 + ux * drawn, y1 + uy * drawn)
        nvgLineTo(ctx, x1 + ux * stop, y1 + uy * stop)
        nvgStroke(ctx)
        drawn = stop + g
    end
end

-- 十字标注点：取样点 / 定位点 / 激活标记
local function DrawCrossMark(ctx, x, y, size, color)
    DrawLine(ctx, x - size, y, x + size, y, color, 1)
    DrawLine(ctx, x, y - size, x, y + size, color, 1)
end

-- 环形刻度：圆形主体外圈，每 3 段加长
local function DrawTickRing(ctx, cx, cy, r, startDeg, endDeg, stepDeg, color)
    local steps = math.floor((endDeg - startDeg) / stepDeg)
    for idx = 0, steps do
        local rad = math.rad(startDeg + idx * stepDeg)
        local long = (idx % 3 == 0)
        local inner = r - (long and 7 or 3)
        local ox, oy = math.cos(rad), math.sin(rad)
        DrawLine(ctx, cx + ox * inner, cy + oy * inner, cx + ox * r, cy + oy * r,
            color, long and 1.3 or 0.7)
    end
end

-- 半调网点阵：背景/面板底纹（逐点绘制，step 不要小于 7）
local function DrawHalftone(ctx, x, y, w, h, step, alpha)
    local s = (step or 8) * 2
    nvgSave(ctx)
    nvgIntersectScissor(ctx, x, y, w, h)
    nvgFillColor(ctx, nvgRGBA(C.halftone[1], C.halftone[2], C.halftone[3], alpha or 16))
    for gy = y, y + h, s do
        for gx = x, x + w, s do
            nvgBeginPath(ctx)
            nvgCircle(ctx, gx, gy, 0.9)
            nvgFill(ctx)
        end
    end
    nvgRestore(ctx)
end

-- 扫描带 + 拖尾：容器内部/装饰位。速度 18px/s，位置由 elapsed 决定（非随机）。
local function DrawScanBand(ctx, x, y, w, h, elapsed)
    local bandY = y + (elapsed * 18) % h
    DrawRect(ctx, x, bandY, w, 1, {C.ash[1], C.ash[2], C.ash[3], 48}, 0)
    DrawRect(ctx, x, bandY - 5, w, 1, {C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 22}, 0)
    if uiPulse_ > 0.28 then
        local ghostY = y + ((elapsed * 18) - 27) % h
        DrawRect(ctx, x + 6, ghostY, math.max(0, w - 12), 2,
            {C.wash[1], C.wash[2], C.wash[3], math.floor(28 + 70 * uiPulse_)}, 0)
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

-- NanoVG 自绘表面纹理：稀疏电路刻线 + 像素节点。只贴面板边缘，保持文案区干净。
local function DrawCircuitTexture(ctx, x, y, w, h, tint, alpha)
    if w < 28 or h < 14 then return end
    local a = alpha or 18
    local color = nvgRGBA(tint[1], tint[2], tint[3], a)
    nvgSave(ctx)
    nvgIntersectScissor(ctx, x, y, w, h)
    nvgBeginPath(ctx)
    local row = 0
    for yy = y + 5, y + h - 4, 8 do
        row = row + 1
        local startX = x + ((row % 2) * 7) + 2
        local endX = x + w - 5
        nvgMoveTo(ctx, startX, yy)
        nvgLineTo(ctx, endX - 8, yy)
        nvgLineTo(ctx, endX - 8, yy + ((row % 2 == 0) and 3 or -3))
        nvgLineTo(ctx, endX, yy + ((row % 2 == 0) and 3 or -3))
    end
    nvgStrokeColor(ctx, color)
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
    nvgBeginPath(ctx)
    for yy = y + 5, y + h - 4, 16 do
        nvgRect(ctx, x + w - 4, yy - 1, 2, 2)
    end
    nvgFillColor(ctx, color)
    nvgFill(ctx)
    nvgRestore(ctx)
end

-- v0.13.30：机加工金属面板升级（「界面太便宜」的最高杠杆点）。
-- 旧版渐变只有 ±5 RGB（肉眼等同纯色）、描边 1.1px、无厚度；而全项目 13 个界面的
-- 面板/按钮/卡片/窗口壳**全部**走这一个函数（9 处直调 + DrawBluePanel 6 处 +
-- MetaUI 的 D.panel），所以「廉价感」的最大单一来源就在这里。
-- 升级为：①投影落地（厚度）②可读的金属渐变（顶亮底暗 ~20 级）③受光斜面
-- （上缘内高光 / 下缘内暗边）④外描边加粗 ⑤四角螺钉（工业机箱语汇）。
-- ⚠️ 签名不变 → 所有调用点零改动；且**不新增顶层 local**（该文件 196/200，见 AB-166）。
local function DrawMachinedPanel(ctx, x, y, w, h, fill, border, radius, emphasis)
    local r = radius or 6
    local a = fill[4] or 255
    local top = {
        math.min(255, fill[1] + 16), math.min(255, fill[2] + 19),
        math.min(255, fill[3] + 24), a,
    }
    local bottom = {
        math.max(0, fill[1] - 5), math.max(0, fill[2] - 6),
        math.max(0, fill[3] - 8), a,
    }
    -- ① 投影：向下偏移的暗底，让面板「离地」（只给大面板，小按钮加了会糊成一团）。
    if r > 0 and w > 80 and h > 48 then
        DrawRect(ctx, x, y + 2, w, h, {2, 4, 8, 110}, r)
    end
    -- ② 金属渐变主体（顶亮底暗，能读出立体）。
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x, y, w, h, r)
    nvgFillPaint(ctx, nvgLinearGradient(ctx, x, y, x, y + h,
        nvgRGBA(top[1], top[2], top[3], top[4]),
        nvgRGBA(bottom[1], bottom[2], bottom[3], bottom[4])))
    nvgFill(ctx)
    -- ③ 受光斜面：上缘内高光 + 下缘内暗边（叠在渐变上的细线）。
    if w > 30 and h > 16 then
        DrawLine(ctx, x + r, y + 1.2, x + w - r, y + 1.2,
            {255, 255, 255, emphasis and 52 or 34}, 1)
        DrawLine(ctx, x + r, y + h - 1.2, x + w - r, y + h - 1.2,
            {0, 0, 0, 72}, 1)
    end
    -- ④ 外描边（比旧版略粗，强调态更亮）。
    DrawStroke(ctx, x, y, w, h, border, r, emphasis and 1.6 or 1.2)
    -- ⑤ 内槽线（机加工台阶）。
    if w > 46 and h > 24 then
        DrawStroke(ctx, x + 3, y + 3, w - 6, h - 6,
            {border[1], border[2], border[3], math.min(110, border[4] or 110)}, math.max(1, r - 2), 0.7)
    end
    -- ⑥ 四角螺钉（只在大面板 + 有圆角时；HUD 横条 radius=0 天然跳过）。
    if r >= 5 and w > 130 and h > 70 then
        local inset, boltR = 8, 1.7
        for _, p in ipairs({
            {x + inset, y + inset}, {x + w - inset, y + inset},
            {x + inset, y + h - inset}, {x + w - inset, y + h - inset},
        }) do
            nvgBeginPath(ctx)
            nvgCircle(ctx, p[1], p[2], boltR + 1.1)
            nvgFillColor(ctx, nvgRGBA(0, 0, 0, 130))
            nvgFill(ctx)
            nvgBeginPath(ctx)
            nvgCircle(ctx, p[1], p[2], boltR)
            nvgFillColor(ctx, nvgRGBA(C.ash[1], C.ash[2], C.ash[3], 155))
            nvgFill(ctx)
            DrawLine(ctx, p[1] - boltR * 0.7, p[2], p[1] + boltR * 0.7, p[2], {0, 0, 0, 135}, 0.8)
        end
    elseif emphasis and w > 80 and h > 36 then
        for _, px in ipairs({x + 9, x + w - 9}) do
            nvgBeginPath(ctx)
            nvgCircle(ctx, px, y + 9, 1.6)
            nvgFillColor(ctx, nvgRGBA(C.warn[1], C.warn[2], C.warn[3], 150))
            nvgFill(ctx)
        end
    end
end

local function DrawWindowShell(ctx, x, y, w, h, titleH)
    local th = titleH or 46
    -- v0.13.30b：窗口加**外辉光 + 内凹内容区**——旧版只有一层平描边，窗口像贴纸
    -- 不像「一块发光的仪器面板」。外辉光用 boxGradient 在窗体外缘铺一圈青色柔光；
    -- 内容区再压一层向内渐暗，让里面的卡片「陷进去」。
    nvgBeginPath(ctx)
    nvgRect(ctx, x - 22, y - 22, w + 44, h + 44)
    nvgFillPaint(ctx, nvgBoxGradient(ctx, x, y, w, h, 8, 22,
        nvgRGBA(0, 200, 184, 46), nvgRGBA(0, 200, 184, 0)))
    nvgFill(ctx)
    DrawMachinedPanel(ctx, x, y, w, h, C.panel, C.cyanDim, 6, true)
    DrawRect(ctx, x, y, 4, th, C.cyan, 0)
    DrawCornerBrackets(ctx, x + 4, y + 4, w - 8, h - 8, C.cyanDim, 14, 1.2)
    DrawLine(ctx, x + 12, y + th, x + w - 12, y + th,
        {C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 118}, 1)
    -- 内容区内凹：标题栏之下压一层极淡的向内暗角，制造「屏幕嵌进机壳」的纵深。
    if h > th + 40 then
        nvgBeginPath(ctx)
        nvgRect(ctx, x + 3, y + th + 2, w - 6, h - th - 5)
        nvgFillPaint(ctx, nvgBoxGradient(ctx, x + 3, y + th + 2, w - 6, h - th - 5, 5, 16,
            nvgRGBA(0, 0, 0, 90), nvgRGBA(0, 0, 0, 0)))
        nvgFill(ctx)
    end
end

-- v0.13.17：模态窗（结算/胜利/暂停）的 dark-tech 装饰叠加——环形刻度 + 虚线轴 + 半调底纹。
-- 克制档：只做静态/低频装饰，不进入窗内正文与按钮命中区。
local function DrawModalTechDecor(ctx, x, y, w, h, elapsed)
    AnomalyPulse(elapsed)
    DrawHalftone(ctx, x + 4, y + 4, w - 8, h - 10, 8, 16)
    DrawTickRing(ctx, x + w - 40, y + 40, 22, -30, 210, 15,
        {C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 120})
    DrawDashLine(ctx, x + 10, y + h - 14, x + 84, y + h - 14,
        {C.klein[1], C.klein[2], C.klein[3], 80}, 1, 5, 4)
    DrawCrossMark(ctx, x + 20, y + 20, 3, {C.ghost[1], C.ghost[2], C.ghost[3], 90})
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
        -- 末段淡出；入场弹性放大（出生 1.42 倍、二次收拢），数字"跳"出来更有冲击感。
        local alpha = math.floor(235 * math.min(1, lifeT * 3))
        local pop = 1 + 0.42 * lifeT * lifeT
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

-- 实测文本像素宽度（设计空间）。测量期间临时重置 transform，
-- 与 WrapTextLines 同一套约定（调用方处于 CONTAIN 缩放 transform 下）。
local function MeasurePixelWidth(ctx, text, size)
    UseTechFont(ctx)
    nvgFontSize(ctx, size)
    nvgSave(ctx)
    nvgResetTransform(ctx)
    local _, bounds = nvgTextBounds(ctx, 0, 0, text, nil)
    local w
    if bounds and bounds[1] and bounds[3] then
        w = bounds[3] - bounds[1]
    else
        w = (utf8.len(text) or #text) * size
    end
    nvgRestore(ctx)
    return w
end

-- v0.13.29：升级卡数值条文案自适应折行。value 文案由数据驱动（Game.lua 的 UPGRADE_POOL[].value），
-- 长度不一，固定单行会溢出卡片。做法：先按 " / " 拆成语义段，再贪心打包——能塞进同一行的段合在一起，
-- 塞不下就换行（**不在段中间切断**，避免 "弹速+10%" 被切成 "弹速+1"/"0% ..."）。
-- 一行装不下时整条降到 14px 重排（既避免溢出，分段也更均衡）；仍超宽才逐字符兜底。
-- 返回 lines, size，调用方按返回的 size 绘制，保证测量与绘制同一字号。
local function SplitValueLines(ctx, text, size, maxWidth)
    local segs = {}
    for seg in string.gmatch(text, "[^/]+") do
        local s = seg:gsub("^%s+", "")
        s = s:gsub("%s+$", "")
        if s ~= "" then segs[#segs + 1] = s end
    end
    if #segs == 0 then return { text }, size end

    local function pack(atSize)
        local packed = { segs[1] }
        for i = 2, #segs do
            local cand = packed[#packed] .. " / " .. segs[i]
            if #packed < 2 and MeasurePixelWidth(ctx, cand, atSize) <= maxWidth then
                packed[#packed] = cand
            else
                packed[#packed + 1] = segs[i]
            end
        end
        return packed
    end

    local function layout(atSize)
        local lines = {}
        for _, seg in ipairs(pack(atSize)) do
            for _, l in ipairs(WrapTextLines(ctx, seg, atSize, maxWidth)) do
                lines[#lines + 1] = l
            end
        end
        return lines
    end

    -- 优先 16px；只有在该字号下折出 3 行以上（长数值卡，如玻璃巨炮）才降一档重排，
    -- 避免"单行能装下"的卡被无谓缩小。
    local lines, useSize = layout(size), size
    if #lines > 2 then
        useSize = math.max(12, size - 2)
        lines = layout(useSize)
    end

    if #lines <= 2 then return lines, useSize end
    -- 仍超 2 行：溢出部分并回第 2 行，用 " / " 保持分隔语义（不要退化成空格）。
    local merged = lines[2]
    for i = 3, #lines do merged = merged .. " / " .. lines[i] end
    return { lines[1], merged }, useSize
end

-- v0.13.30b：模态背景从「平色 C.bg + 小网格」升级为**有光的环境**——
-- 旧版是一整块纯色，占屏 80% 面积却毫无层次，是「廉价」的最大来源。
-- 现为：径向渐变底（中心偏亮的深海军蓝 → 四周近黑，模拟穹顶照明）+ 顶部青色
-- 环境辉光 + 四角暗角（把视线收拢到中央内容）。仍是单次 fill，性能无忧。
local function DrawModalBackdrop(ctx, x, y, width, height)
    local cx, cy = x + width * 0.5, y + height * 0.34
    local rOut = math.max(width, height) * 0.78
    nvgBeginPath(ctx)
    nvgRect(ctx, x, y, width, height)
    nvgFillPaint(ctx, nvgRadialGradient(ctx, cx, cy, 30, rOut,
        nvgRGBA(15, 26, 47, 255), nvgRGBA(4, 7, 15, 255)))
    nvgFill(ctx)
    -- 顶部环境辉光：青色自顶部淡入，给界面一个「上方有光源」的暗示。
    nvgBeginPath(ctx)
    nvgRect(ctx, x, y, width, height * 0.5)
    nvgFillPaint(ctx, nvgLinearGradient(ctx, x, y, x, y + height * 0.5,
        nvgRGBA(0, 190, 176, 34), nvgRGBA(0, 190, 176, 0)))
    nvgFill(ctx)
    -- 四角暗角：向内的黑色渐变，收拢视觉焦点。
    local vig = 130
    nvgBeginPath(ctx)
    nvgRect(ctx, x, y, width, vig)
    nvgFillPaint(ctx, nvgLinearGradient(ctx, x, y, x, y + vig, nvgRGBA(0, 0, 0, 150), nvgRGBA(0, 0, 0, 0)))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRect(ctx, x, y + height - vig, width, vig)
    nvgFillPaint(ctx, nvgLinearGradient(ctx, x, y + height, x, y + height - vig, nvgRGBA(0, 0, 0, 170), nvgRGBA(0, 0, 0, 0)))
    nvgFill(ctx)
    DrawMicroGrid(ctx, x + 18, y + 18, 132, 168, 12, 22)
    DrawMicroGrid(ctx, x + width - 150, y + height - 210, 120, 150, 12, 18)
    DrawStatusDots(ctx, x + 22, y + height - 28, 4, C.cyanDim)
end

local function DrawBluePanel(ctx, x, y, width, height, fill, border, radius)
    DrawMachinedPanel(ctx, x, y, width, height, fill, border, radius or 6,
        border == C.cyan or border == C.warn or border == C.ad)
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
    local ratio = math.max(0, math.min(1, value or 0))
    DrawRect(ctx, x, y, width, height, C.ink, math.min(4, height * 0.5))
    DrawStroke(ctx, x, y, width, height, C.cyanDim, math.min(4, height * 0.5), 1)
    local fillWidth = math.max(0, (width - 4) * ratio)
    if fillWidth > 0 then
        local r, g, b = color[1], color[2], color[3]
        local hi = {
            math.min(255, r + math.floor((255 - r) * 0.18)),
            math.min(255, g + math.floor((255 - g) * 0.18)),
            math.min(255, b + math.floor((255 - b) * 0.18)), 255,
        }
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, x + 2, y + 2, fillWidth, math.max(2, height - 4), math.min(3, height * 0.4))
        nvgFillPaint(ctx, nvgLinearGradient(ctx, x, y + 2, x, y + height - 2,
            nvgRGBA(hi[1], hi[2], hi[3], 255),
            nvgRGBA(r, g, b, 225)))
        nvgFill(ctx)
        if height >= 8 then
            DrawLine(ctx, x + 4, y + 2.5, x + 2 + fillWidth - 2, y + 2.5,
                {255, 255, 255, 72}, 1)
        end
    end
    if width >= 90 then
        for notch = 1, math.floor(width / 24) - 1 do
            local nx = x + notch * 24
            DrawLine(ctx, nx, y + 1, nx, y + height - 1,
                {C.ink[1], C.ink[2], C.ink[3], 100}, 1)
        end
    end
end

local function DrawPremiumProgress(ctx, x, y, width, ratio, color, height)
    DrawPixelBar(ctx, x, y, width, height or 8, ratio, color)
end

-- A1/A2：缓动与模态入场计时。
local function EaseOutCubic(t)
    t = math.max(0, math.min(1, t))
    return 1 - (1 - t) * (1 - t) * (1 - t)
end

-- 窗口按统一的视觉时钟入场/退场，退场保留上一帧只读快照而不拦截操作。
local WINDOW_IN = 0.32
local WINDOW_OUT = 0.18

local function AdvanceUiClock(game)
    local elapsed = game.elapsed or 0
    if uiLastElapsed_ then
        if elapsed < uiLastElapsed_ then
            uiClock_ = 0
            uiGameLeaving_, metaScreenLeaving_, metaSupplyLeaving_ = nil, nil, nil
        else
            uiClock_ = uiClock_ + math.min(0.05, elapsed - uiLastElapsed_)
        end
    end
    uiLastElapsed_ = elapsed
end

local function WindowMotion(enterAt, leaving)
    local duration = leaving and WINDOW_OUT or WINDOW_IN
    local age = math.max(0, uiClock_ - enterAt)
    if leaving then
        local t = math.min(1, age / duration)
        return 1 - EaseOutCubic(t), 1 - t * 0.035
    end
    local t = math.min(1, age / duration)
    local scale
    if t < 0.70 then
        local u = t / 0.70
        scale = 0.91 + 0.12 * EaseOutCubic(u)
    else
        local u = (t - 0.70) / 0.30
        scale = 1.03 - 0.03 * (1 - (1 - u) * (1 - u))
    end
    return math.min(1, t * 3), scale
end

-- 视觉变换和命中逆变换同用一个函数，避免弹动时按钮与可见位置分离。
local function WindowInput(x, y, startAt)
    local _, scale = WindowMotion(startAt, false)
    local cx, cy = DESIGN_W * 0.5, DESIGN_H * 0.5
    return cx + (x - cx) / scale, cy + (y - cy) / scale
end

local function UpdateUiState(game, meta)
    AdvanceUiClock(game)
    if game.state ~= uiState_ then
        local old = uiState_
        if old == "gameover" or old == "levelup" or old == "paused" or old == "stagewin" then
            uiGameLeaving_ = {state = old, visual = uiGameVisual_}
            uiGameLeaveAt_ = uiClock_
            uiGameVisual_ = nil
        end
        uiState_ = game.state
        uiStateEnter_ = game.elapsed
        uiStateMotionEnter_ = uiClock_
        if game.state == "gameover" or game.state == "levelup" or game.state == "paused"
            or game.state == "stagewin" then
            -- 重新开局立刻收掉旧窗口退场残影，避免旧快照叠在新窗口下面。
            uiGameLeaving_ = nil
        end
        if game.state == "menu" then
            -- v0.12.8：每次进主页重新摇字标轮播起点（仅状态切换时一次）。
            logoRollOffset_ = math.random(0, 3)
        end
    end
    if game.state == "gameover" or game.state == "levelup" or game.state == "paused"
        or game.state == "stagewin" then
        uiGameVisual_ = {game = CopyVisualState(game), meta = CopyVisualState(meta)}
        uiGameVisual_.game.upgradeChoices = CopyVisualState(game.upgradeChoices)
    end
    if metaScreen_ ~= (meta and meta.screen or nil) then
        if metaScreen_ then
            metaScreenLeaving_ = {screen = metaScreen_, meta = metaVisual_}
            metaScreenLeaveAt_ = uiClock_
        end
        metaScreen_ = meta and meta.screen or nil
        metaScreenEnter_ = uiClock_
        -- 任何开关切换都取消另一窗残影，防止快速关闭重开时旧快照叠在新面板下面。
        metaScreenLeaving_ = nil
        metaSupplyLeaving_ = nil
    end
    if metaSupply_ ~= (meta and meta.supplyOpen == true or false) then
        if metaSupply_ then
            metaSupplyLeaving_ = metaVisual_
            metaSupplyLeaveAt_ = uiClock_
        end
        metaSupply_ = meta and meta.supplyOpen == true or false
        metaSupplyEnter_ = uiClock_
        metaScreenLeaving_ = nil
        metaSupplyLeaving_ = nil
    end
    if meta then
        metaVisual_ = CopyVisualState(meta)
    end
    if uiGameLeaving_ and uiClock_ - uiGameLeaveAt_ >= WINDOW_OUT then uiGameLeaving_ = nil end
    if metaScreenLeaving_ and uiClock_ - metaScreenLeaveAt_ >= WINDOW_OUT then metaScreenLeaving_ = nil end
    if metaSupplyLeaving_ and uiClock_ - metaSupplyLeaveAt_ >= WINDOW_OUT then metaSupplyLeaving_ = nil end
end

-- 主菜单保持全屏淡入；窗口内容改由 DrawAnimatedWindow 统一处理。
local function ModalIntro(game)
    if game.state ~= "menu" then return 1 end
    local t = (game.elapsed - uiStateEnter_) / 0.28
    return EaseOutCubic(t)
end

local AIRCRAFT_LABELS = {
    scout = "侦察", dart = "飞镖", striker = "强袭", hive = "蜂群",
    manta = "鳐鱼", bomber = "飞碟", cruiser = "巡洋", interceptor = "截击",
    elite_hook = "钩翼", elite_fork = "双叉", elite_razor = "斜刃", elite_spiral = "涡轮",
    elite_anchor = "铁锚", elite_wisp = "流萤", elite_shear = "剪翼",
    elite_bracket = "断环", elite_hammer = "重锤", elite_rivet = "铆钉",
    boss_orrery = "星环", boss_maw = "噬口", boss_citadel = "堡垒",
    boss_prism = "棱镜", boss_serpent = "蛇脊",
}

-- v0.10.31：底部 Dock 中央下一波小图。四弹药槽左右分组，中间 256px 留给预告。
-- 只读 game.nextWave（规则层预抽），像素格来自 VisualCatalog，禁止再抽随机。
-- v0.13.26：新增「远方飞入」说明——敌机在屏幕上沿之外生成，下落一段才进画面。
local function DrawNextWavePreview(ctx, game)
    local plan = game.nextWave
    if not plan then return end
    local preview = VisualCatalog.GetAircraftPreview(plan.aircraftKey)
    local panelW, panelH = 168, 86
    local px = DESIGN_W * 0.5 - panelW * 0.5
    local py = BOTTOM_DOCK_Y + 4
    local kind = plan.kind or "normal"
    local accent = kind == "boss" and C.error or (kind == "elite" and C.warn or C.cyan)
    DrawTechPanel(ctx, px, py, panelW, panelH, C.card, accent)
    DrawRect(ctx, px, py, 3, panelH, accent, 0)

    local cooldown = game.waveCooldown or 0
    local eta = string.format("%d", math.max(0, math.floor(cooldown + 0.999)))
    DrawPixelText(ctx, px + 8, py + 4,
        kind == "boss" and "首领" or (kind == "elite" and "精英" or "下一波"), 15, accent)
    DrawPixelText(ctx, px + panelW - 8, py + 4, eta .. "秒", 15, C.cyan,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)

    if preview and preview.cells then
        local cell = math.max(2, math.floor(math.min(52 / preview.gridW, 26 / preview.gridH)))
        local artW = preview.gridW * cell
        local artH = preview.gridH * cell
        local ax = px + math.floor((panelW - artW) * 0.5)
        local ay = py + 22 + math.floor((26 - artH) * 0.5)
        for i = 1, #preview.cells do
            local c = preview.cells[i]
            nvgBeginPath(ctx)
            nvgRect(ctx, ax + (c.col - 1) * cell, ay + (c.row - 1) * cell, cell - 0.5, cell - 0.5)
            nvgFillColor(ctx, nvgRGBA(c.r, c.g, c.b, 255))
            nvgFill(ctx)
        end
    end

    -- v0.13.26：说明敌人在屏幕上沿之外生成，需要下落一段才进入画面。
    DrawPixelText(ctx, px + 8, py + 52, "自远方飞入", 12, C.dim)

    local label = AIRCRAFT_LABELS[plan.aircraftKey] or plan.aircraftKey
    local countText = kind == "boss" and "首领" or (kind == "elite" and "精英" or (tostring(plan.count or 0) .. "架"))
    DrawPixelText(ctx, px + 8, py + 68, label, 15, C.text)
    DrawPixelText(ctx, px + panelW - 8, py + 68, countText, 15,
        accent, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
end

-- v0.12.11 修复（AB-100 前向引用）：DrawIcon 的 local function 定义在本文件后段
-- （图标表区域，~1141 行），而 DrawAmmoSlots 等调用点早于它——不加前向声明时调用点
-- 解析成全局 nil，战斗中每帧 attempt to call a nil value，nvgEndFrame 被跳过 =
-- 整个 NanoVG 帧被丢弃 = 「3D 正常、2D 全没」。
local DrawIcon = nil

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
    DrawCircuitTexture(ctx, 6, BOTTOM_DOCK_Y + 18, DESIGN_W - 12, 72, C.cyanDim, 12)
    DrawEdgeTicks(ctx, 16, BOTTOM_DOCK_Y + 1, DESIGN_W - 32, 21,
        {C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 90})

    -- v0.10.24：主球回库补弹时 Dock 顶边一道青色轻扫光（0.3s 衰减）。
    local reload = presentation.reloadFlash or 0
    if reload > 0 then
        local a = math.floor(190 * (reload / 0.3))
        local sweep = reload / 0.3
        local sx = DESIGN_W * (1 - sweep)
        DrawLine(ctx, sx, BOTTOM_DOCK_Y, DESIGN_W, BOTTOM_DOCK_Y,
            {C.cyan[1], C.cyan[2], C.cyan[3], a}, 2)
    end

    DrawPixelText(ctx, 14, BOTTOM_DOCK_Y + 4, "弹药矩阵", 15, C.cyan)
    DrawPixelText(ctx, DESIGN_W - 14, BOTTOM_DOCK_Y + 4,
        "升级解锁车辆 · 拖拽发射", 14, C.dim, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    DrawLine(ctx, 14, BOTTOM_DOCK_Y + 22, DESIGN_W - 14, BOTTOM_DOCK_Y + 22,
        {C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 85}, 1)

    local slotSize = 64
    local slotGap = 6
    local slotY = BOTTOM_DOCK_Y + 26
    local leftStart = 10
    local rightStart = DESIGN_W - 10 - slotSize * 2 - slotGap
    local ammoIcons = {
        normal = "ammo_normal", ice = "ammo_ice", speed = "ammo_speed", giant = "ammo_giant",
    }
    for i, ballType in ipairs(SLOT_TYPES) do
        local pairIndex = (i - 1) % 2
        local x = (i <= 2 and leftStart or rightStart) + pairIndex * (slotSize + slotGap)
        local color = SLOT_COLORS[ballType]
        local unlocked = game.unlockedBalls and game.unlockedBalls[ballType] == true
        local selected = unlocked and game.activeBall and game.activeBall.ballType == ballType
        local fill = selected and C.widget or (unlocked and C.card or C.rail)
        local border = selected and C.cyan
            or (unlocked and {color[1], color[2], color[3], 170} or C.cyanDim)
        if selected then
            DrawRect(ctx, x - 2, slotY - 2, slotSize + 4, slotSize + 4,
                {C.cyan[1], C.cyan[2], C.cyan[3], 32}, 8)
        end
        DrawMachinedPanel(ctx, x, slotY, slotSize, slotSize, fill, border, 6, selected == true)
        if selected then
            DrawRect(ctx, x, slotY, 3, slotSize, C.cyan, 0)
        end
        DrawPixelText(ctx, x + 6, slotY + 3, string.format("%d", i), 12, C.dim)
        DrawPixelText(ctx, x + slotSize - 6, slotY + 3,
            unlocked and ("×" .. tostring(queueCounts[ballType] or 0)) or "锁", 13,
            selected and C.cyan or (unlocked and color or C.dim),
            NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
        -- 32×32 图标始终原生尺寸，锁定态降低亮度而不改变图标资源。
        DrawIcon(ctx, ammoIcons[ballType], x + 16, slotY + 7, 32,
            selected and 1 or (unlocked and 0.86 or 0.28))
        DrawPixelText(ctx, x + slotSize * 0.5, slotY + 40, SLOT_NAMES[ballType], 14,
            selected and C.text or C.dim, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        DrawPixelText(ctx, x + slotSize * 0.5, slotY + 54,
            selected and "待发" or (unlocked and "待命" or "待解锁"), 11,
            selected and C.cyan or C.dim, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        DrawRect(ctx, x + 6, slotY + slotSize - 3, slotSize - 12, selected and 2 or 1,
            unlocked and {color[1], color[2], color[3], selected and 230 or 105}
                or C.cyanDim, 0)
    end

    DrawNextWavePreview(ctx, game)
end

-- v0.11.4：新手下拉提示。玩家本局还没发射过、也没在拖拽时，在弹弓车辆上方
-- 循环播放「手从上往下拉」的动画：手沿一条虚线从高处下移到发射位，再淡出重来。
-- 纯表现层，只读快照 showPullHint / slingX / slingY，不触达规则层。
local function DrawPullHint(ctx, game)
    if not game.showPullHint then return end
    if not handImage_ or handImage_ <= 0 then return end

    local slingX = game.slingX or DESIGN_W * 0.5
    local slingY = game.slingY or (BOTTOM_DOCK_Y - 16)
    -- 循环周期 1.6s：前 0.15 淡入 → 0.75 下滑 → 0.35 停在低位 → 0.35 淡出。
    local period = 1.6
    local t = (game.elapsed or 0) % period
    local progress = math.min(1, t / 0.9)
    local eased = 1 - (1 - progress) * (1 - progress)
    -- 手部从上往下：起点在车辆上方 ~120px，终点贴近车辆。
    local handW, handH = 92, 138
    local topY = slingY - 150
    local bottomY = slingY - handH + 26
    local handX = slingX - handW * 0.5
    local handY = topY + (bottomY - topY) * eased

    local alpha = 1.0
    if t < 0.15 then
        alpha = t / 0.15
    elseif t > period - 0.35 then
        alpha = math.max(0, (period - t) / 0.35)
    end

    nvgSave(ctx)
    nvgGlobalAlpha(ctx, alpha)

    -- 拖拽轨迹：从手起点到终点的一条青色点状虚线。
    local trackX = slingX
    local trackTop = topY + 8
    local trackBottom = bottomY + handH - 20
    local dots = 9
    for i = 1, dots do
        local dt = (i - 1) / (dots - 1)
        local dy = trackTop + (trackBottom - trackTop) * dt
        -- 已滑过的位置更亮，未到的更暗，形成方向感。
        local passed = dt <= eased + 0.02
        local a = passed and 210 or 70
        local r = passed and 3.0 or 2.2
        nvgBeginPath(ctx)
        nvgCircle(ctx, trackX, dy, r)
        nvgFillColor(ctx, nvgRGBA(C.cyan[1], C.cyan[2], C.cyan[3], a))
        nvgFill(ctx)
    end

    -- 手势图（青色线稿，直接用原图）。
    nvgBeginPath(ctx)
    nvgRect(ctx, handX, handY, handW, handH)
    nvgFillPaint(ctx, nvgImagePattern(ctx, handX, handY, handW, handH, 0, handImage_, 1))
    nvgFill(ctx)

    -- 文案：放在手下方，跟着手一起走。
    DrawPixelText(ctx, slingX, bottomY + handH - 8, "向下拖拽 松手发射",
        15, C.cyan, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    nvgRestore(ctx)
end

-- ============================================================================
-- v0.12.5：局内道具改右上角竖列（默认收起标签 ⇄ 展开三槽）。
-- 视觉几何与命中判定共用 GetItemPanelLayout，禁止在 main.lua 另写常量。
-- ============================================================================

-- ============================================================================
-- v0.11.0 商业化：32×32 像素图标表。
-- ⚠️ 全部按「可选资源」处理：缺图只跳过该图标，绝不进 Init 的成功条件。
-- ⚠️ 必须用 NVG_IMAGE_NEAREST 采样，否则像素画缩放会糊成一片。
-- ============================================================================

local ICON_PATHS = {
    bomb   = "image/ui_icon_bomb_20260928005024.png",
    freeze = "image/ui_icon_freeze_20260928005014.png",
    shield = "image/ui_icon_shield_20260928005021.png",
    parts  = "image/ui_icon_parts_20260928005017.png",
    gem    = "image/ui_icon_gem_20260928005033.png",
    shop   = "image/ui_icon_shop_20260928005019.png",
    codex  = "image/ui_icon_codex_20260928005024.png",
    task   = "image/ui_icon_task_20260928005023.png",
    rank   = "image/ui_icon_rank_20260928005022.png",
    signin = "image/ui_icon_signin_20260928011015.png",
    reroll = "image/ui_icon_reroll_20260928011012.png",
    rarity = "image/ui_icon_rarity_20260928011021.png",
    double = "image/ui_icon_double_20260928011016.png",
    orbital = "image/ui_icon_orbital_20260928011016.png",
    reload = "image/ui_icon_reload_20260928011013.png",
    record = "image/ui_icon_record_20260928011019.png",
    boost = "image/ui_icon_boost_20260928011116.png",
    -- v0.12.5 界面增强：HUD 暂停入口 / 主页出口 / 防线与等级读数图标
    pause = "image/ui_icon_pause_20260928094729.png",
    home = "image/ui_icon_home_20260928094732.png",
    barrier = "image/ui_icon_barrier_20260928094833.png",
    levelup = "image/ui_icon_levelup_20260928094730.png",
    -- v0.12.9 premium dark-tech 素材套件（0718-pixelimage-aigc 后处理，32×32/8 色）。
    premium_supply_crate = "image/ui_premium_supply_crate.png",
    premium_pass_crest = "image/ui_premium_pass_crest.png",
    premium_energy_core = "image/ui_premium_energy_core.png",
    premium_wheel_medal = "image/ui_premium_wheel_medal.png",
    ammo_normal = "image/ui_ammo_split_core.png",
    ammo_ice = "image/ui_ammo_frost_shard.png",
    ammo_speed = "image/ui_ammo_velocity_coil.png",
    ammo_giant = "image/ui_ammo_giant_shell.png",
    -- v0.13.8 天赋/升级卡图标（0718-pixelimage-aigc 后处理，32×32/≤9 色）。
    talent_damage = "image/ui_icon_talent_damage.png",
    talent_repair = "image/ui_icon_talent_repair.png",
    talent_armor = "image/ui_icon_talent_armor.png",
    talent_xp = "image/ui_icon_talent_xp.png",
    talent_glass = "image/ui_icon_talent_glass.png",
    talent_overclock = "image/ui_icon_talent_overclock.png",
    talent_ammo = "image/ui_icon_talent_ammo.png",
    talent_unlock = "image/ui_icon_talent_unlock.png",
    talent_word = "image/ui_icon_talent_word.png",
}

---@type table<string, integer>
local iconImages_ = {}

local function LoadIcons()
    iconImages_ = {}
    local loaded = 0
    for key, path in pairs(ICON_PATHS) do
        local ok, img = pcall(function()
            return nvgCreateImage(vg_, path, NVG_IMAGE_NEAREST)
        end)
        if ok and type(img) == "number" and img > 0 then
            iconImages_[key] = img
            loaded = loaded + 1
        end
    end
    -- ⚠️ ICON_PATHS 是字符串键表，`#` 恒为 0，必须手动计数。
    local total = 0
    for _ in pairs(ICON_PATHS) do total = total + 1 end
    print("[Scene3DBackend] pixel icons loaded=" .. loaded .. "/" .. total)
end

-- ============================================================================
-- v0.12.8：AI 生图像素字标（0718-pixelimage-aigc 管线：草案 → 包围盒裁切 →
-- LANCZOS 等比缩到 120 高母版 → alpha 二值化 → 7 色 dark-tech 量化）。
-- 主页轮播：进菜单随机起点，每 5 秒切换下一张，NEAREST 1× 显示。
-- ⚠️ 可选资源：缺图只回退整串 zpix 大字，绝不进 Init 成功条件。
-- ============================================================================
-- 母版 = 显示尺寸（各字标按内容等比裁到 120 高，宽 207–264 不等），1× 最近邻。
local LOGO_PATHS = {
    { path = "image/ui_logo_a_20260929162106.png", w = 207 },
    { path = "image/ui_logo_b_20260929162106.png", w = 235 },
    { path = "image/ui_logo_c_20260929162106.png", w = 244 },
    { path = "image/ui_logo_d_20260929162106.png", w = 264 },
}
local LOGO_H = 120
local LOGO_SWITCH_SECONDS = 5

---@type {img: integer, w: number}[]
local logoImages_ = {}
-- 随机起点 logoRollOffset_ 已在文件前部与 uiState_ 一起声明，由 UpdateUiState 写入。

local function LoadLogoTitles()
    logoImages_ = {}
    for _, item in ipairs(LOGO_PATHS) do
        local ok, img = pcall(function()
            return nvgCreateImage(vg_, item.path, NVG_IMAGE_NEAREST)
        end)
        if ok and type(img) == "number" and img > 0 then
            logoImages_[#logoImages_ + 1] = { img = img, w = item.w }
        end
    end
    print("[Scene3DBackend] pixel logo titles loaded=" .. #logoImages_ .. "/" .. #LOGO_PATHS)
end

-- 当前应显示的字标；未加载任何图时返回 nil（调用方回退 zpix 整串）。
local function PickLogoImage(elapsed, enteredAt)
    local n = #logoImages_
    if n == 0 then return nil end
    local t = math.max(0, (elapsed or 0) - (enteredAt or 0))
    local idx = (math.floor(t / LOGO_SWITCH_SECONDS) + logoRollOffset_) % n + 1
    return logoImages_[idx]
end

---@param ctx any
---@param key string
---@param x number
---@param y number
---@param size number
---@param alpha number|nil
---@return boolean drawn
DrawIcon = function(ctx, key, x, y, size, alpha)
    local img = iconImages_[key]
    if not img then return false end
    nvgBeginPath(ctx)
    nvgRect(ctx, x, y, size, size)
    nvgFillPaint(ctx, nvgImagePattern(ctx, x, y, size, size, 0, img, alpha or 1))
    nvgFill(ctx)
    return true
end

-- v0.12.5：局内道具改「右上角竖列」，默认收起为一个小标签，点开展示三个槽位。
-- 开合状态是纯 UI 瞬时状态，由本模块持有；发放道具后编排层会主动展开。
local itemPanelOpen_ = false

local function GetItemPanelLayout()
    local tab = { x = DESIGN_W - 52, y = 100, w = 44, h = 36 }
    local slots = {}
    for i = 1, 3 do
        slots[i] = { x = DESIGN_W - 60, y = 146 + (i - 1) * 58, w = 52, h = 52 }
    end
    return tab, slots
end

---@param ctx any
---@param game table
local function DrawItemSlots(ctx, game)
    local items = game.items
    if not items then return end
    local tab, slots = GetItemPanelLayout()

    local totalCharges = 0
    local grantable = 0
    for i = 1, #items do
        local def = items[i]
        if def then
            if (def.charges or 0) > 0 then totalCharges = totalCharges + 1 end
            if def.canGrant then grantable = grantable + 1 end
        end
    end

    -- 收起/展开标签
    DrawRect(ctx, tab.x, tab.y, tab.w, tab.h, itemPanelOpen_ and C.card or C.widget, 6)
    DrawStroke(ctx, tab.x, tab.y, tab.w, tab.h,
        totalCharges > 0 and C.cyan or C.cyanDim, 6, 1.2)
    DrawPixelText(ctx, tab.x + tab.w * 0.5, tab.y + 9,
        itemPanelOpen_ and "收起" or "道具", 15,
        totalCharges > 0 and C.cyan or C.dim, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    if not itemPanelOpen_ and totalCharges > 0 then
        DrawRect(ctx, tab.x + tab.w - 10, tab.y - 4, 16, 16, C.cyan, 8)
        DrawPixelText(ctx, tab.x + tab.w - 2, tab.y - 2, tostring(totalCharges), 13, C.ink,
            NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    end
    if not itemPanelOpen_ and totalCharges == 0 and grantable > 0 then
        DrawRect(ctx, tab.x + tab.w - 8, tab.y - 2, 8, 8, C.ad, 4)
    end

    if not itemPanelOpen_ then return end
    for i = 1, #slots do
        local def = items[i]
        if def then
            local r = slots[i]
            local col = def.color or C.cyan
            local owned = (def.charges or 0) > 0
            local iconSize = 26
            local iconX = r.x + (r.w - iconSize) * 0.5
            if owned then
                DrawRect(ctx, r.x, r.y, r.w, r.h, C.card, 6)
                DrawStroke(ctx, r.x, r.y, r.w, r.h, col, 6, 1.4)
                DrawIcon(ctx, def.key, iconX, r.y + 6, iconSize, 1)
                DrawPixelText(ctx, r.x + r.w - 4, r.y + r.h - 18,
                    "×" .. tostring(def.charges), 14, col, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
                DrawPixelText(ctx, r.x + 4, r.y + r.h - 18, def.name or "", 13, C.text)
            elseif def.canGrant then
                DrawRect(ctx, r.x, r.y, r.w, r.h, C.widget, 6)
                DrawStroke(ctx, r.x, r.y, r.w, r.h, C.adDim, 6, 1.2)
                DrawIcon(ctx, def.key, iconX, r.y + (r.h - iconSize) * 0.5, iconSize, 0.5)
                DrawRect(ctx, r.x + r.w - 10, r.y + 2, 8, 8, C.ad, 4)
            else
                DrawRect(ctx, r.x, r.y, r.w, r.h, C.widget, 6)
                DrawIcon(ctx, def.key, iconX, r.y + (r.h - iconSize) * 0.5, iconSize, 0.2)
            end
        end
    end
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
    local y = HUD_HEIGHT + 34
    DrawPixelText(ctx, cx, y - 24, "首领阶段", 16, C.warn,
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

-- v0.12.5：HUD 右上角暂停按钮（绘制与命中共用）。
local function GetHudPauseRect(game)
    local w = (game and game.width) or DESIGN_W
    return { x = w - 42, y = 10, w = 28, h = 28 }
end

local function DrawHud(ctx, game, presentation)
    local hpRatio = game.maxBaseHp > 0 and game.baseHp / game.maxBaseHp or 0
    local hpColor
    if hpRatio > 0.35 then
        hpColor = C.text
    else
        local pulse = 0.5 + 0.5 * math.sin((game.elapsed or 0) * 7)
        hpColor = {235 + math.floor(20 * pulse), 70 + math.floor(40 * pulse), 70}
    end

    DrawMachinedPanel(ctx, 0, 0, game.width, HUD_HEIGHT, C.panel, C.cyanDim, 0, false)
    DrawRect(ctx, 0, 0, 4, HUD_HEIGHT, C.cyan, 0)
    DrawLine(ctx, 0, HUD_HEIGHT - 1, game.width, HUD_HEIGHT - 1, C.cyanDim, 1)
    DrawEdgeTicks(ctx, 16, HUD_HEIGHT - 8, game.width - 32, 21,
        {C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 95})
    DrawLine(ctx, 151, 12, 151, 62, {C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 90}, 1)
    DrawLine(ctx, 377, 12, 377, 62, {C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 90}, 1)

    DrawPixelText(ctx, 14, 5, "本局得分", 13, C.dim)
    DrawPixelText(ctx, 14, 20, string.format("%d", game.score), 28, C.text)
    local cloud = presentation and presentation.cloudStatus
    local cloudColor = cloud == "ok" and C.cyan or (cloud == "unavailable" and C.warn or C.cyanDim)
    DrawRect(ctx, 140, 8, 5, 5, cloudColor, 3)
    DrawPixelText(ctx, 14, 58, "最高 " .. tostring(game.highScore), 12, C.dim)

    local centerX = 264
    DrawPixelText(ctx, centerX, 5, string.format("第 %d 关 · 作战波次", game.stage or 1), 13, C.cyanDim,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawPixelText(ctx, centerX, 19, string.format("%d / %d", game.stageWave or game.wave,
        game.wavesPerStage or 10), 29, C.text,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    local combo = game.clearStreak or 0
    local comboColor = combo >= 2 and C.warn or C.dim
    local comboSize = combo >= 2 and (13 + math.floor(2 * (0.5 + 0.5 * math.sin((game.elapsed or 0) * 8)))) or 13
    DrawPixelText(ctx, centerX, 57,
        string.format("敌机 %d   连击 ×%d", game.concurrentCount or 0, combo),
        comboSize, comboColor, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    DrawIcon(ctx, "barrier", 391, 4, 18, 0.9)
    DrawPixelText(ctx, 414, 5, "基地耐久", 13, C.dim)
    DrawPixelText(ctx, 384, 23, string.format("%d", game.baseHp), 22, hpColor)
    DrawPixelText(ctx, 426, 29, "/ " .. tostring(game.maxBaseHp), 13, C.dim)
    DrawPixelBar(ctx, 384, 53, 106, 8, hpRatio, hpRatio > 0.35 and C.cyan or hpColor)
    DrawPixelText(ctx, 384, 68, "零件 +" .. tostring(game.runParts or 0), 12,
        (game.partsBoostTime or 0) > 0 and C.ad or C.warn)
    if (game.partsBoostTime or 0) > 0 then
        -- v0.13.17：用上 boost 图标（此前已加载却从未绘制），标出「零件翻倍」增益生效。
        DrawIcon(ctx, "boost", 464, 66, 16, 1)
        DrawPixelText(ctx, 490, 68, "×2", 12, C.ad, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    end

    if game.state == "playing" then
        local pauseBtn = GetHudPauseRect(game)
        DrawMachinedPanel(ctx, pauseBtn.x, pauseBtn.y, pauseBtn.w, pauseBtn.h, C.card, C.cyanDim, 6, false)
        if not DrawIcon(ctx, "pause", pauseBtn.x + 4, pauseBtn.y + 4, 20, 1) then
            DrawRect(ctx, pauseBtn.x + 8, pauseBtn.y + 7, 4, 14, C.cyan, 1)
            DrawRect(ctx, pauseBtn.x + 16, pauseBtn.y + 7, 4, 14, C.cyan, 1)
        end
    end

    local xpRatio = game.xpToNext > 0 and game.xp / game.xpToNext or 0
    DrawIcon(ctx, "levelup", 16, 71, 16, 0.9)
    DrawPixelText(ctx, 36, 72, string.format("Lv.%d", game.playerLevel), 12, C.cyan)
    DrawPixelBar(ctx, 78, 75, 68, 7, xpRatio, C.cyan)
end

-- v0.12.7：像素大 logo。⚠️ zpix 位图字体逐字（单码位）绘制在超大字号会退化成
-- 空框（v0.12.6 逐字排版真机只有两个空心矩形），改回「整串一次绘制 + 硬偏移阴影」，
-- 与既有 36px「击碎飞机」同一条已验证可渲染的路径，只是加大字号。
local function DrawPixelLogo(ctx, cx, topY, title, size, bodyColor, shadowColor)
    -- 阴影层（右下偏移暗青）
    DrawPixelText(ctx, cx + size * 0.045, topY + size * 0.045, title, size,
        shadowColor or C.cyanDim, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    -- 主层
    DrawPixelText(ctx, cx, topY, title, size, bodyColor or C.text,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
end

-- v0.13.4：主菜单「开始战斗」CTA 几何（绘制与命中共用，禁止两套常量）。
local function GetMenuCtaRect(game)
    local w = (game and game.width) or DESIGN_W
    return { x = 42, y = 430, w = w - 84, h = 72 }
end

local function DrawMenu(ctx, game, meta)
    nvgSave(ctx)
    nvgIntersectScissor(ctx, 0, 0, game.width, game.height)
    nvgGlobalAlpha(ctx, ModalIntro(game))
    -- v0.13.30b：首页背景由平色升级为「有光的环境」——径向渐变 + 顶部青色辉光 +
    -- 底部暗角，与模态背景同一套语言（旧版整块纯色是廉价感的主要来源）。
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, game.width, game.height)
    nvgFillPaint(ctx, nvgRadialGradient(ctx, game.width * 0.5, game.height * 0.30,
        40, math.max(game.width, game.height) * 0.82,
        nvgRGBA(16, 28, 50, 255), nvgRGBA(4, 7, 15, 255)))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, game.width, game.height * 0.45)
    nvgFillPaint(ctx, nvgLinearGradient(ctx, 0, 0, 0, game.height * 0.45,
        nvgRGBA(0, 190, 176, 30), nvgRGBA(0, 190, 176, 0)))
    nvgFill(ctx)
    -- 留出整块实车主视觉，不再把网格/扫描带铺过商品与标题。
    DrawCornerBrackets(ctx, 8, 8, game.width - 16, game.height - 16,
        {C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 100}, 18, 1)

    -- ① 像素字标标题（v0.12.8）：AI 生成+管线量化的成品图，母版 120 高，
    -- NEAREST 1× 等比居中显示，每 5 秒轮播下一张（起点在进菜单时随机）；
    -- 缺图回退 zpix 整串大 logo。
    local logo = PickLogoImage(game.elapsed, uiStateEnter_)
    if logo then
        local lx = (game.width - logo.w) * 0.5
        nvgBeginPath(ctx)
        nvgRect(ctx, lx, 28, logo.w, LOGO_H)
        nvgFillPaint(ctx, nvgImagePattern(ctx, lx, 28, logo.w, LOGO_H,
            0, logo.img, 1))
        nvgFill(ctx)
    else
        DrawPixelLogo(ctx, game.width * 0.5, 32, GAME_SHORT_TITLE, 104, C.cyan)
    end
    DrawPixelText(ctx, game.width * 0.5, 164, "拖拽发射重卡 · 逐块撕碎敌机编队", 17, C.dim,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    if meta then MetaUI.DrawHomeVehicle(ctx, game.width, meta) end

    -- ② 主 CTA：v0.13.4 起点击打开「选关界面」，不再直接开局。几何走 GetMenuCtaRect。
    local cta = GetMenuCtaRect(game)
    local ctaY = cta.y
    local glow, press = Backend.GetControlFx(cta, true)
    nvgSave(ctx)
    nvgTranslate(ctx, 0, press * 2)
    DrawMachinedPanel(ctx, 34, ctaY - 5, game.width - 68, cta.h + 10, C.rail, C.warnDim, 10, true)
    -- v0.13.30：主 CTA 由「纯青平板」改为**受光金属按钮**——旧版 DrawRect 平铺 C.cyan
    -- 把下面的机加工面板整块盖掉，首页最大元素反而最廉价。现改为：亮→深的青色金属
    -- 渐变 + 上缘倒角高光 + 下缘内暗边 + 顶三分之一斜向光泽（polished metal）。
    -- 青底仍配 ink 字，对比度不变；命中几何 GetMenuCtaRect 未动。
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, cta.x, cta.y, cta.w, cta.h, 7)
    nvgFillPaint(ctx, nvgLinearGradient(ctx, cta.x, cta.y, cta.x, cta.y + cta.h,
        nvgRGBA(74, 246, 228, 255), nvgRGBA(0, 176, 162, 255)))
    nvgFill(ctx)
    -- 斜向光泽：左上白 → 中部透明，铺在顶 45%（不做整面，避免发灰）。
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, cta.x, cta.y, cta.w, cta.h * 0.45, 7)
    nvgFillPaint(ctx, nvgLinearGradient(ctx, cta.x, cta.y, cta.x + cta.w * 0.7, cta.y + cta.h * 0.45,
        nvgRGBA(255, 255, 255, 86), nvgRGBA(255, 255, 255, 0)))
    nvgFill(ctx)
    -- 倒角：上缘内高光 + 下缘内暗边（厚度感）。
    DrawStroke(ctx, cta.x + 3, cta.y + 3, cta.w - 6, cta.h - 6, {255, 255, 255, 92}, 5, 1.2)
    DrawRect(ctx, cta.x + 10, cta.y + 4, cta.w - 20, 1, {255, 255, 255, 140}, 0)
    DrawRect(ctx, cta.x + 10, cta.y + cta.h - 4, cta.w - 20, 1, {0, 0, 0, 60}, 0)
    -- v0.13.30c「华丽 + 动态」：一条斜向高光带周期性扫过 CTA（3.2s 一轮，确定性）。
    -- 裁进圆角内侧的矩形区域，避免光带碰到宿主边缘。
    local sweep = (game.elapsed % 3.2) / 3.2
    if sweep < 0.55 then
        local t = sweep / 0.55
        local bandX = cta.x - 120 + t * (cta.w + 240)
        nvgSave(ctx)
        nvgIntersectScissor(ctx, cta.x + 7, cta.y + 3, cta.w - 14, cta.h - 6)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, bandX, cta.y)
        nvgLineTo(ctx, bandX + 58, cta.y)
        nvgLineTo(ctx, bandX + 22, cta.y + cta.h)
        nvgLineTo(ctx, bandX - 36, cta.y + cta.h)
        nvgFillPaint(ctx, nvgLinearGradient(ctx, bandX - 36, cta.y, bandX + 58, cta.y,
            nvgRGBA(255, 255, 255, 0), nvgRGBA(255, 255, 255, 120)))
        nvgFill(ctx)
        nvgRestore(ctx)
    end
    if glow > 0.01 then
        DrawStroke(ctx, cta.x, cta.y, cta.w, cta.h,
            {255, 255, 255, math.floor(glow * 220)}, 7, 2)
    end
    DrawPixelText(ctx, game.width * 0.5, ctaY + 8, "开始战斗", 31, C.ink,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width * 0.5, ctaY + 45, "选择关卡", 14, C.ink,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgRestore(ctx)
    DrawPixelText(ctx, game.width * 0.5, 932,
        "v" .. BUILD_VERSION .. " · " .. GAME_TITLE, 12, C.dim,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    -- ③ 变现闭环三段式：钱包连接器 + 今日福利(赚) + 养成收藏(花) + 图鉴/排行（布局/命中同源 MetaUI）
    if meta then MetaUI.DrawMenuBar(ctx, game.width, meta) end
    nvgRestore(ctx)
end

-- v0.12.5：结算页四出口（复活 / 双倍+再来一局 / 回主菜单）。
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
    -- v0.12.5：回主菜单（用户否决「游戏结束不让回主菜单」）。窗口壳底边 720，
    -- 第四行放 616..664，窗口内、toast 提示上方，不压既有三行几何。
    local menu = {
        x = rowX,
        y = double.y + btnH + gap,
        w = rowPairW,
        h = 44,
    }
    return revive, double, restart, menu
end

local function DrawGameOver(ctx, game, presentation)
    nvgSave(ctx)
    nvgIntersectScissor(ctx, 0, MENU_CONTENT_TOP,
        game.width, game.height - MENU_CONTENT_TOP)

    local winX, winY = 24, 200
    local winW, winH = game.width - 48, 520
    DrawWindowShell(ctx, winX, winY, winW, winH, 48)
    DrawModalTechDecor(ctx, winX, winY, winW, winH, game.elapsed)
    DrawPixelText(ctx, winX + 18, winY + 10, "防线失守", 22, C.cyan)
    DrawPixelText(ctx, winX + winW - 16, winY + 14, "本局结束", 15, C.warn,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)

    if game.newRecord then
        DrawIcon(ctx, "record", game.width * 0.5 - 104, 266, 32)
        DrawPixelText(ctx, game.width * 0.5 + 14, 272, "刷新最高分", 20, C.warn,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    else
        DrawPixelText(ctx, game.width * 0.5, 278, "游戏结束", 36, C.text,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
    DrawPixelText(ctx, game.width * 0.5, 322, "敌机突破了底部防线", 18, C.dim,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width * 0.5, 348,
        string.format("分数 %d    最高 %d    第 %d 关 %d/%d 波",
            game.score, game.highScore, game.stage or 1,
            game.stageWave or game.wave, game.wavesPerStage or 10), 18, C.text,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    DrawBluePanel(ctx, 44, 370, game.width - 88, 92, C.rail, C.cyanDim, 6)
    DrawPixelText(ctx, 60, 380, string.format("到达第 %d 关", game.stage or 1), 17, C.text)
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
    DrawIcon(ctx, "parts", game.width * 0.5 - 184, 439, 28)

    local reviveBtn, doubleBtn, restartBtn, menuBtn = GetGameOverButtonLayout(game)
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
        DrawIcon(ctx, "double", doubleBtn.x + 9, doubleBtn.y + 10, 28)
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

    -- v0.12.5：回主菜单（次级出口：widget 底 + 青 dim 描边，不与主 CTA 抢焦点）
    DrawRect(ctx, menuBtn.x, menuBtn.y, menuBtn.w, menuBtn.h, C.widget, 8)
    DrawStroke(ctx, menuBtn.x, menuBtn.y, menuBtn.w, menuBtn.h, C.cyanDim, 8, 1.4)
    DrawIcon(ctx, "home", menuBtn.x + menuBtn.w * 0.5 - 58, menuBtn.y + 10, 24, 1)
    DrawPixelText(ctx, menuBtn.x + menuBtn.w * 0.5 + 14, menuBtn.y + 10, "回主菜单", 18, C.text,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    local toast = presentation and presentation.adToast
    if toast and toast ~= "" then
        DrawPixelText(ctx, game.width * 0.5, menuBtn.y + menuBtn.h + 10, toast, 15, C.warn,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
    nvgRestore(ctx)
end

-- ============================================================================
-- v0.13.4：胜利结算界面（stagewin）。击败本关首领后弹出，展示按剩余防线血量
-- 折算的评级 + 星级，由玩家手动选择「下一关 / 再战本关 / 回主菜单」。
-- 视觉几何与命中判定共用 GetStageWinButtonLayout，禁止第二套常量。
-- ============================================================================

-- 三颗星横排（大字号，供胜利页中央展示）。filled=0..3。
local function DrawStarRow(ctx, cx, cy, filled, cell, gapPx)
    local total = 3 * cell + 2 * gapPx
    local x0 = cx - total * 0.5
    for i = 1, 3 do
        local on = i <= filled
        local col = on and C.warn or C.widget
        local bx = x0 + (i - 1) * (cell + gapPx)
        -- 程序化五角星用两块菱形近似拼出，避免外部贴图；未得星只画暗底。
        DrawRect(ctx, bx, cy, cell, cell, col, math.floor(cell * 0.22))
        if on then
            DrawRect(ctx, bx + cell * 0.25, cy + cell * 0.12, cell * 0.5, cell * 0.76, C.ink, 1)
            DrawRect(ctx, bx + cell * 0.12, cy + cell * 0.25, cell * 0.76, cell * 0.5, C.ink, 1)
        end
    end
end

local function GetStageWinButtonLayout(game)
    local w = (game and game.width) or DESIGN_W
    local btnH, gap = 48, 12
    local rowW = 216
    local rowPairW = rowW * 2 + gap
    local rowX = (w - rowPairW) * 0.5
    local menu = { x = (w - rowW) * 0.5, y = 496, w = rowW, h = btnH }
    local retry = { x = rowX, y = menu.y + btnH + gap, w = rowW, h = btnH }
    local nextBtn = { x = rowX + rowW + gap, y = retry.y, w = rowW, h = btnH }
    return retry, nextBtn, menu
end

local function DrawStageWin(ctx, game, presentation)
    local result = game.stageResult or {}
    local stars = math.min(3, math.max(1, math.floor(result.stars or 1)))
    nvgSave(ctx)
    nvgIntersectScissor(ctx, 0, MENU_CONTENT_TOP,
        game.width, game.height - MENU_CONTENT_TOP)
    DrawModalBackdrop(ctx, 0, MENU_CONTENT_TOP, game.width, game.height - MENU_CONTENT_TOP)

    local winX, winY = 24, 200
    local winW, winH = game.width - 48, 468
    DrawWindowShell(ctx, winX, winY, winW, winH, 48)
    DrawModalTechDecor(ctx, winX, winY, winW, winH, game.elapsed)
    DrawPixelText(ctx, winX + 18, winY + 10, "防线守住", 22, C.cyan)
    DrawPixelText(ctx, winX + winW - 16, winY + 14,
        string.format("第 %d 关告捷", result.stage or game.stage or 1), 15, C.warn,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)

    DrawPixelText(ctx, game.width * 0.5, winY + 70, result.rating or "通关", 34, C.text,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawStarRow(ctx, game.width * 0.5, winY + 120, stars, 40, 18)

    DrawPixelText(ctx, game.width * 0.5, winY + 188,
        string.format("剩余防线 %d / %d", math.floor(game.baseHp or 0), game.maxBaseHp or 100),
        17, C.dim, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width * 0.5, winY + 214,
        string.format("本关奖励  +%d 分   +%d 零件", math.floor(result.bonusScore or 0),
            math.floor(result.bonusParts or 0)), 16, C.warn, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    if game.newRecord then
        DrawPixelText(ctx, game.width * 0.5, winY + 240, "刷新最高分", 16, C.warn,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end

    local retryBtn, nextBtn, menuBtn = GetStageWinButtonLayout(game)
    -- 下一关：有下一关时青底主 CTA，通关到最后一关时置灰。
    if game.stageHasNext then
        DrawRect(ctx, nextBtn.x, nextBtn.y, nextBtn.w, nextBtn.h, C.cyan, 8)
        DrawPixelText(ctx, nextBtn.x + nextBtn.w * 0.5, nextBtn.y + 12, "下一关", 20, C.ink,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    else
        DrawRect(ctx, nextBtn.x, nextBtn.y, nextBtn.w, nextBtn.h, C.widget, 8)
        DrawStroke(ctx, nextBtn.x, nextBtn.y, nextBtn.w, nextBtn.h, C.cyanDim, 8, 1)
        DrawPixelText(ctx, nextBtn.x + nextBtn.w * 0.5, nextBtn.y + 12, "已通关全部", 18, C.dim,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
    -- 再战本关（次级）+ 回主菜单（次级）。
    DrawRect(ctx, retryBtn.x, retryBtn.y, retryBtn.w, retryBtn.h, C.card, 8)
    DrawStroke(ctx, retryBtn.x, retryBtn.y, retryBtn.w, retryBtn.h, C.cyanDim, 8, 1.4)
    DrawPixelText(ctx, retryBtn.x + retryBtn.w * 0.5, retryBtn.y + 12, "再战本关", 20, C.text,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    DrawRect(ctx, menuBtn.x, menuBtn.y, menuBtn.w, menuBtn.h, C.widget, 8)
    DrawStroke(ctx, menuBtn.x, menuBtn.y, menuBtn.w, menuBtn.h, C.cyanDim, 8, 1.4)
    DrawIcon(ctx, "home", menuBtn.x + menuBtn.w * 0.5 - 58, menuBtn.y + 10, 24, 1)
    DrawPixelText(ctx, menuBtn.x + menuBtn.w * 0.5 + 14, menuBtn.y + 10, "回主菜单", 18, C.text,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    local toast = presentation and presentation.adToast
    if toast and toast ~= "" then
        DrawPixelText(ctx, game.width * 0.5, menuBtn.y + menuBtn.h + 22, toast, 15, C.warn,
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
    -- v0.13.29：300 → 340。带说明条（解锁/高风险/词条）的卡要同时容纳
    -- 详情 2 行 + 说明条 + 数值条 2 行，300 高会把详情挤成 1 行并截断文案。
    local cardH = 340
    local gap = 8
    local totalW = 3 * cardW + 2 * gap
    local startX = game.width * 0.5 - totalW * 0.5 + cardW * 0.5
    -- v0.10.17：卡片在标题区与底部操作提示之间垂直居中（卡 360..700）。
    local cy = 530
    return cardW, cardH, gap, startX, cy
end

-- 卡片序号圆点渲染在 DrawUpgradeCard 内。

---@class UiRect
---@field x number
---@field y number
---@field w number
---@field h number

-- 锁定/保留角标：卡片左上角（v0.12.5 面板唯一卡级角标）。
---@return UiRect
local function GetHoldBadgeRect(cx, cardTop, cardW)
    return { x = cx - cardW * 0.5 + 6, y = cardTop + 6, w = 46, h = 22 }
end

-- v0.13.8：升级卡图标——优先按卡 id 取专属图标，其次按 kind/ballType 回退。
local function UpgradeCardIconKey(choice)
    local key = TalentCatalog.ICON_BY_CARD[choice.id]
    if key then return key end
    if choice.ballType and TalentCatalog.ICON_BY_BALL[choice.ballType] then
        return TalentCatalog.ICON_BY_BALL[choice.ballType]
    end
    if choice.kind == "unlock" then return TalentCatalog.ICON_BY_KIND.ballUnlock end
    if choice.kind == "word" then return TalentCatalog.ICON_BY_KIND.ballCard end
    return TalentCatalog.ICON_BY_KIND.stat
end

local function DrawUpgradeCard(ctx, index, choice, cx, cy, cardW, cardH)
    local x = cx - cardW * 0.5
    local y = cy - cardH * 0.5
    local rare = UPGRADE_RARITY[choice.rarity] or UPGRADE_RARITY.common
    local accent = rare.color
    DrawBluePanel(ctx, x, y, cardW, cardH, C.card, C.cyanDim, 6)
    DrawCornerBrackets(ctx, x + 4, y + 4, cardW - 8, cardH - 8, accent, 10, 1.2)
    DrawRect(ctx, x, y, 3, cardH, accent, 0)

    -- 图标：卡片顶部居中 34px（与局内道具槽同源），下衬暗色圆角底板提升可读性
    local iconKey = UpgradeCardIconKey(choice)
    local iconSize = 34
    local iconX = x + cardW * 0.5 - iconSize * 0.5
    local iconY = y + 32
    DrawRect(ctx, iconX - 6, iconY - 6, iconSize + 12, iconSize + 12, C.rail, 8)
    DrawStroke(ctx, iconX - 6, iconY - 6, iconSize + 12, iconSize + 12,
        {accent[1], accent[2], accent[3], 120}, 8, 1)
    if not DrawIcon(ctx, iconKey, iconX, iconY, iconSize, 1) then
        DrawPixelText(ctx, x + cardW * 0.5, iconY + 4, (choice.name or "?"):sub(1, 1), 24,
            C.text, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end

    -- 锁定角标移到右上（避让顶部图标）
    DrawPixelText(ctx, x + cardW - 6, y + 7, choice.held and "保留" or "锁定", 14,
        choice.held and C.warn or C.cyanDim, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    DrawPixelText(ctx, x + cardW * 0.5, y + 86, choice.name or "强化", 22, C.text,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawPixelText(ctx, x + cardW * 0.5, y + 114,
        (choice.kind == "word" and "特殊效果 · " or "") .. rare.tag, 16, accent,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawSegmentedRule(ctx, x + 14, y + 136, cardW - 28, 6, C.cyanDim)

    -- v0.13.29：数值条文案长度不一（数据驱动），先量出所需行数（1~2 行），
    -- 再据此抬高数值条、并让详情区与角标避让，避免长文案溢出卡片。
    local valueText = choice.value or "强化"
    local valueLines, valueSize = SplitValueLines(ctx, valueText, 16, cardW - 34)
    local valueLineCount = math.min(2, math.max(1, #valueLines))
    local valueLineH = 19
    local valueBoxH = 8 + valueLineCount * valueLineH
    local valueBoxBottom = y + cardH - 34
    local valueBoxTop = valueBoxBottom - valueBoxH

    -- 说明条（解锁 / 高风险 / 词条）位于数值条正上方，详情区不能压到它。
    local hasFooter = choice.kind == "unlock" or choice.tradeoff or choice.kind == "word"
    local footerTop = valueBoxTop - 36
    local detailAreaTop = y + 146
    local detailAreaBottom = (hasFooter and (footerTop - 8) or (valueBoxTop - 10))
    local detailAvail = detailAreaBottom - detailAreaTop

    -- 详情自适应：17px 下装不下就降到 15px 重排（行距随之收窄），
    -- 保证长详情（如玻璃巨炮）不因可用高度不足而被截断。
    local detailText = choice.detail or choice.desc or "提升当前弹珠性能"
    local detailSize = 17
    local detailLineH = 25
    local detailLines = WrapTextLines(ctx, detailText, detailSize, cardW - 18)
    if #detailLines * detailLineH > detailAvail then
        detailSize = 15
        detailLineH = 22
        local smaller = WrapTextLines(ctx, detailText, detailSize, cardW - 18)
        if #smaller * detailLineH <= detailAvail then detailLines = smaller end
    end
    local maxDetailLines = math.max(1, math.floor(detailAvail / detailLineH))
    local detailCount = math.min(maxDetailLines, #detailLines)
    local detailTop = detailAreaTop
        + math.max(0, (detailAvail - detailCount * detailLineH) * 0.5)
    for li = 1, detailCount do
        DrawPixelText(ctx, x + cardW * 0.5, detailTop + (li - 1) * detailLineH,
            detailLines[li], detailSize, C.dim, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end

    if choice.kind == "unlock" then
        DrawTechPanel(ctx, x + 10, footerTop, cardW - 20, 26, C.widget, C.cyan)
        DrawPixelText(ctx, x + cardW * 0.5, footerTop + 4, "新车型 · 本局解锁", 15,
            C.cyan, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    elseif choice.tradeoff then
        DrawTechPanel(ctx, x + 10, footerTop, cardW - 20, 26, C.widget, C.warn)
        DrawPixelText(ctx, x + cardW * 0.5, footerTop + 4, "高风险 / 高回报", 15,
            C.warn, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    elseif choice.kind == "word" then
        DrawTechPanel(ctx, x + 10, footerTop, cardW - 20, 26, C.widget, accent)
        DrawPixelText(ctx, x + cardW * 0.5, footerTop + 4, "本局生效 · 只装一次", 15, accent,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end

    DrawRect(ctx, x + 14, valueBoxTop, cardW - 28, valueBoxH, C.widget, 6)
    DrawStroke(ctx, x + 14, valueBoxTop, cardW - 28, valueBoxH, accent, 6, 1)
    local valueTextTop = valueBoxTop + (valueBoxH - valueLineCount * valueLineH) * 0.5
    for li = 1, valueLineCount do
        DrawPixelText(ctx, x + cardW * 0.5, valueTextTop + (li - 1) * valueLineH,
            valueLines[li] or "", valueSize or 16, accent, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end

    local stacks = choice.stacks or 0
    local maxText = choice.maxStacks and choice.maxStacks >= 90 and "∞" or tostring(choice.maxStacks or "-")
    DrawPixelText(ctx, x + cardW * 0.5, y + cardH - 22,
        "已选 " .. tostring(stacks) .. " / " .. maxText, 14, C.dim,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
end

-- ============================================================================
-- v0.12.5 精简：升级面板只保留「免费重抽 + 看广告重抽」两个按钮，
-- 视觉几何与命中判定共用 GetUpgradePanelLayout，禁止在 main.lua 另写常量。
-- ============================================================================

---@class UpgradePanelLayout
---@field cardW number
---@field cardH number
---@field gap number
---@field startX number
---@field cy number
---@field cardCount integer
---@field rerollFree UiRect
---@field rerollAd UiRect
---@field hintY number

---@return UpgradePanelLayout
local function GetUpgradePanelLayout(game)
    local cardW, cardH, gap, startX, cy = GetUpgradeCardLayout(game)
    local w = game.width or DESIGN_W
    local margin = 24
    local innerW = w - margin * 2
    local btnGap = 12
    local btnW = math.floor((innerW - btnGap) / 2)
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
        rerollFree = { x = rowX, y = btnY, w = btnW, h = btnH },
        rerollAd = { x = rowX + btnW + btnGap, y = btnY, w = btnW, h = btnH },
        hintY = btnY + btnH + 14,
    }
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
    DrawIcon(ctx, "reroll", layout.rerollFree.x + 6, layout.rerollFree.y + 12, 26)
    -- 看广告重抽实际触发 Game.RerollUpgrades("ad_rare")，首张强制稀有。
    DrawPanelButton(ctx, layout.rerollAd, "看广告 重抽", "必出稀有",
        true, C.ad)
    DrawIcon(ctx, "rarity", layout.rerollAd.x + 6, layout.rerollAd.y + 12, 26)
end

local function DrawLevelUp(ctx, game, presentation)
    nvgSave(ctx)
    nvgIntersectScissor(ctx, 0, MENU_CONTENT_TOP, game.width, game.height - MENU_CONTENT_TOP)

    local choices = game.upgradeChoices or {}
    local layout = GetUpgradePanelLayout(game)

    DrawPixelText(ctx, 24, 106, "升级", 18, C.cyan)
    DrawPixelText(ctx, game.width - 24, 106,
        string.format("%d 选一", math.min(3, #choices)), 18, C.warn,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width * 0.5, 130, "选择一项强化", 30, C.text,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width * 0.5, 168,
        string.format("当前等级 %d    点一张卡片继续", game.playerLevel), 17, C.dim,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    local toast = presentation and presentation.adToast
    if toast and toast ~= "" then
        DrawPixelText(ctx, game.width * 0.5, 300, toast, 16, C.warn,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end

    if #choices > 0 then
        for i = 1, layout.cardCount do
            DrawUpgradeCard(ctx, i, choices[i],
                layout.startX + (i - 1) * (layout.cardW + layout.gap),
                layout.cy, layout.cardW, layout.cardH)
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
---@field orbital UiRect
---@field reload UiRect
---@field partsBoost UiRect

---@return PausePanelLayout
local function GetPausePanelLayout(w)
    local margin = 44
    local innerW = w - margin * 2
    local btnW, btnGap = 216, 12
    local pairW = btnW * 2 + btnGap
    local pairX = (w - pairW) * 0.5
    return {
        win = { x = 24, y = 178, w = w - 48, h = 630 },
        heal = { x = margin, y = 380, w = innerW, h = 64 },
        rare = { x = margin, y = 452, w = innerW, h = 64 },
        orbital = { x = margin, y = 524, w = innerW, h = 64 },
        reload = { x = margin, y = 596, w = innerW, h = 64 },
        partsBoost = { x = margin, y = 668, w = innerW, h = 64 },
        -- v0.12.5：显式出口按钮（移动端无键盘，必须给「继续/回主菜单」）
        resume = { x = pairX, y = 740, w = btnW, h = 48 },
        menu = { x = pairX + btnW + btnGap, y = 740, w = btnW, h = 48 },
    }
end

local function DrawPaused(ctx, game, meta, presentation)
    nvgSave(ctx)
    nvgIntersectScissor(ctx, 0, MENU_CONTENT_TOP,
        game.width, game.height - MENU_CONTENT_TOP)
    DrawModalBackdrop(ctx, 0, MENU_CONTENT_TOP, game.width, game.height - MENU_CONTENT_TOP)
    local layout = GetPausePanelLayout(game.width)
    DrawWindowShell(ctx, layout.win.x, layout.win.y, layout.win.w, layout.win.h, 46)
    DrawModalTechDecor(ctx, layout.win.x, layout.win.y, layout.win.w, layout.win.h, game.elapsed)
    DrawPixelText(ctx, layout.win.x + 18, layout.win.y + 10, "暂停控制台", 18, C.text)
    DrawPixelText(ctx, layout.win.x + layout.win.w - 16, layout.win.y + 14,
        "战斗已冻结", 13, C.cyan, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    DrawRect(ctx, game.width * 0.5 - 31, 218, 62, 62, C.rail, 10)
    DrawStroke(ctx, game.width * 0.5 - 31, 218, 62, 62, C.cyanDim, 10, 1.2)
    DrawIcon(ctx, "pause", game.width * 0.5 - 18, 231, 36, 1)
    DrawPixelText(ctx, game.width * 0.5, 291, "补给战场优势", 25, C.text,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width * 0.5, 326, "限时资源 · 本局可用", 14, C.dim,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawSegmentedRule(ctx, 62, 354, game.width - 124, 12, C.cyanDim, 6)

    local offers = {
        {rect=layout.heal, icon="premium_energy_core", ready=game.canPauseHeal,
         title=game.canPauseHeal and "防线急救" or (game.baseHp >= game.maxBaseHp and "防线状态良好" or "急救补给已用完"),
         detail=game.canPauseHeal and "+25 基地生命" or "恢复基地耐久", tag=game.canPauseHeal and "看广告" or "已用完"},
        {rect=layout.rare, icon="premium_pass_crest", ready=game.canPauseRarePick,
         title=game.canPauseRarePick and "稀有强化保障" or "稀有保障已启用",
         detail=game.canPauseRarePick and "下一次强化必出稀有" or "本局已购买", tag=game.canPauseRarePick and "看广告" or "已启用"},
        {rect=layout.orbital, icon="orbital", ready=game.canPauseOrbital,
         title=game.canPauseOrbital and "首领轨道支援" or "轨道支援待命",
         detail=game.canPauseOrbital and "轰击首领装甲" or "首领出现时开放", tag=game.canPauseOrbital and "看广告" or "未开放"},
        {rect=layout.reload, icon="reload", ready=game.canPauseReload,
         title=game.canPauseReload and "弹药补给" or "弹药补给已领取",
         detail=game.canPauseReload and "补充一辆待发重卡" or "本局限领一次", tag=game.canPauseReload and "看广告" or "已领取"},
        {rect=layout.partsBoost, icon="double", ready=game.canPausePartsBoost,
         title=game.canPausePartsBoost and "零件加倍协议" or "加倍协议已领取",
         detail=game.canPausePartsBoost and "45 秒零件产出 ×2" or "本局限领一次", tag=game.canPausePartsBoost and "看广告" or "已领取"},
    }
    for i, offer in ipairs(offers) do
        local r = offer.rect
        local glow, press = Backend.GetControlFx(r, offer.ready == true and presentation.adStatus ~= "loading")
        nvgSave(ctx)
        nvgTranslate(ctx, 0, press * 2)
        DrawMachinedPanel(ctx, r.x, r.y, r.w, r.h,
            offer.ready and C.card or C.widget,
            offer.ready and C.adDim or C.cyanDim, 7, offer.ready)
        if glow > 0.01 then
            DrawStroke(ctx, r.x, r.y, r.w, r.h,
                {C.ad[1], C.ad[2], C.ad[3], math.floor(glow * 210)}, 7, 1.8)
        end
        DrawRect(ctx, r.x + 10, r.y + 8, 48, 48,
            offer.ready and C.rail or C.panel, 6)
        DrawStroke(ctx, r.x + 10, r.y + 8, 48, 48,
            offer.ready and C.adDim or C.cyanDim, 6, 1)
        local iconKey = offer.icon
        if i == 1 and offer.ready then iconKey = "premium_supply_crate" end
        DrawIcon(ctx, iconKey, r.x + 18, r.y + 16, 32, offer.ready and 1 or 0.5)
        DrawPixelText(ctx, r.x + 68, r.y + 7, offer.title, 16,
            offer.ready and C.text or C.dim)
        DrawPixelText(ctx, r.x + 68, r.y + 34, offer.detail, 12, C.dim)
        local pill = {x=r.x+r.w-92,y=r.y+18,w=78,h=28}
        local pillFill = offer.ready and C.ad or C.panel
        DrawRect(ctx, pill.x, pill.y, pill.w, pill.h, pillFill, 5)
        if not offer.ready then DrawStroke(ctx, pill.x, pill.y, pill.w, pill.h, C.cyanDim, 5, 1) end
        DrawPixelText(ctx, pill.x + pill.w * 0.5, pill.y + 7, offer.tag, 12,
            offer.ready and C.ink or C.dim, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgRestore(ctx)
    end

    DrawRect(ctx, layout.resume.x, layout.resume.y, layout.resume.w, layout.resume.h, C.cyan, 8)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, layout.resume.x + 58, layout.resume.y + 14)
    nvgLineTo(ctx, layout.resume.x + 58, layout.resume.y + 34)
    nvgLineTo(ctx, layout.resume.x + 74, layout.resume.y + 24)
    nvgClosePath(ctx)
    nvgFillColor(ctx, nvgRGBA(C.ink[1], C.ink[2], C.ink[3], 255))
    nvgFill(ctx)
    DrawPixelText(ctx, layout.resume.x + layout.resume.w * 0.5 + 14, layout.resume.y + 12,
        "继续战斗", 19, C.ink, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    local menuGlow, menuPress = Backend.GetControlFx(layout.menu, true)
    nvgSave(ctx)
    nvgTranslate(ctx, 0, menuPress * 2)
    DrawMachinedPanel(ctx, layout.menu.x, layout.menu.y, layout.menu.w, layout.menu.h,
        C.widget, C.cyanDim, 8, false)
    if menuGlow > 0.01 then
        DrawStroke(ctx, layout.menu.x, layout.menu.y, layout.menu.w, layout.menu.h,
            {C.cyan[1], C.cyan[2], C.cyan[3], math.floor(menuGlow * 200)}, 8, 1.5)
    end
    DrawIcon(ctx, "home", layout.menu.x + 56, layout.menu.y + 12, 24, 1)
    DrawPixelText(ctx, layout.menu.x + layout.menu.w * 0.5 + 14, layout.menu.y + 12,
        "返回主菜单", 17, C.text, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgRestore(ctx)

    local toast = presentation and presentation.adToast
    if toast and toast ~= "" then
        DrawPixelText(ctx, game.width * 0.5, layout.menu.y + layout.menu.h + 10, toast, 15, C.warn,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
    nvgRestore(ctx)
end

local function DrawWaveBanner(ctx, game, presentation)
    local stageTime = presentation.stageBannerTimer or 0
    if stageTime > 0 then
        local number = presentation.stageBannerNumber or game.stage or 1
        nvgSave(ctx)
        nvgGlobalAlpha(ctx, math.min(1, stageTime / 0.4))
        DrawBluePanel(ctx, game.width * 0.5 - 166, 250, 332, 92, C.card, C.cyan, 6)
        DrawPixelText(ctx, game.width * 0.5, 264, string.format("第 %d 关开始", number), 27, C.cyan,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        DrawPixelText(ctx, game.width * 0.5, 306,
            "十波防线 · 三精英一首领", 16, C.text,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgRestore(ctx)
        return
    end
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
    local kind = presentation.waveBannerKind or "normal"
    local stageNumber = presentation.waveBannerStage or game.stage or 1
    local waveNumber = presentation.waveBannerStageWave or game.stageWave or 1
    local label = AIRCRAFT_LABELS[presentation.waveBannerKey] or ""
    if kind == "boss" or kind == "elite" then
        local accent = kind == "boss" and C.error or C.warn
        DrawBluePanel(ctx, cx - 156, 138 + yOff, 312, 70, C.card, accent, 6)
        DrawPixelText(ctx, cx, 144 + yOff, kind == "boss" and "首领来袭" or "精英来袭", 16, accent,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        DrawPixelText(ctx, cx, 168 + yOff,
            string.format("第 %d 关 · %d/10 波 · %s", stageNumber, waveNumber, label), 20,
            accent, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    else
        DrawBluePanel(ctx, cx - 156, 142 + yOff, 312, 60, C.card, C.cyan, 6)
        DrawPixelText(ctx, cx, 154 + yOff,
            string.format("第 %d 关 · 第 %d 波", stageNumber, waveNumber), 22,
            C.cyan, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
    nvgRestore(ctx)
end

-- ============================================================================
-- v0.12.5：顶端通知条（dark-tech 换皮通道）。
-- 用途①：平台 SystemNotification（服务器资源不足 / 被踢 / 掉线）不允许再走
--         引擎默认白底弹窗；编排层把 SN.Resolve 的结果喂进来。
-- 用途②：付费档案轨等一次性营销提示，也用它而不是常驻大面板行。
-- ⚠️ banner 显示时不拦截其它输入——玩家点 X 关掉即可，游戏逻辑照常。
-- ⚠️ 计时用 gameSnapshot.elapsed 差分（菜单/暂停/战斗中 elapsed 都持续递增）。
-- ============================================================================

---@type table|nil
local sysBanner_ = nil
local bannerLastElapsed_ = 0

---@param spec table {title:string, message:string, actionText:string|nil, tone:"warn"|"error"|"cyan", ttl:number|nil, actionId:string|nil}
function Backend.ShowSystemBanner(spec)
    if type(spec) ~= "table" then return end
    sysBanner_ = {
        title = spec.title or "",
        message = spec.message or "",
        actionText = spec.actionText,
        actionId = spec.actionId,
        tone = spec.tone or "warn",
        ttl = spec.ttl or 12,
    }
end

function Backend.DismissSystemBanner()
    sysBanner_ = nil
end

function Backend.HasSystemBanner()
    return sysBanner_ ~= nil
end

---@return string|nil actionId 点中按钮返回绑定动作 id；点关闭/条体返回 "__close__"
function Backend.HitTestSystemBanner(uiX, uiY)
    local b = sysBanner_
    if not b then return nil end
    local w = DESIGN_W - 40
    local x = 20
    local h = 74
    local y = HUD_HEIGHT + 8
    if uiX < x or uiX > x + w or uiY < y or uiY > y + h then return nil end
    local closeR = { x = x + w - 30, y = y + 6, w = 24, h = 24 }
    if uiX >= closeR.x and uiX <= closeR.x + closeR.w and uiY >= closeR.y and uiY <= closeR.y + closeR.h then
        Backend.DismissSystemBanner()
        return "__close__"
    end
    if b.actionText and b.actionText ~= "" then
        local btnR = { x = x + w - 30 - 96, y = y + 5, w = 90, h = 26 }
        if uiX >= btnR.x and uiX <= btnR.x + btnR.w and uiY >= btnR.y and uiY <= btnR.y + btnR.h then
            return b.actionId or "banner_action"
        end
    end
    Backend.DismissSystemBanner()
    return "__close__"
end

local function TickSystemBanner(elapsed)
    if not sysBanner_ then bannerLastElapsed_ = elapsed return end
    if bannerLastElapsed_ > elapsed then bannerLastElapsed_ = elapsed end
    local d = elapsed - bannerLastElapsed_
    bannerLastElapsed_ = elapsed
    if sysBanner_.ttl and d > 0 then
        sysBanner_.ttl = sysBanner_.ttl - d
        if sysBanner_.ttl <= 0 then
            sysBanner_ = nil
            return
        end
    end
end

local function DrawSystemBanner(ctx)
    local b = sysBanner_
    if not b then return end
    local tone = C.warn
    if b.tone == "error" then tone = C.error end
    if b.tone == "cyan" then tone = C.cyan end

    local w = DESIGN_W - 40
    local x = 20
    local h = 74
    local y = HUD_HEIGHT + 8
    local alpha = 1
    if b.ttl and b.ttl < 0.4 then alpha = math.max(0, b.ttl / 0.4) end
    nvgSave(ctx)
    nvgGlobalAlpha(ctx, alpha)
    DrawRect(ctx, x, y, w, h, C.panel, 8)
    DrawStroke(ctx, x, y, w, h, tone, 8, 1.5)
    DrawRect(ctx, x + 4, y + 10, 4, h - 20, tone, 2)
    DrawPixelText(ctx, x + 18, y + 10, b.title, 18, tone)
    local lines = WrapTextLines(ctx, b.message, 15, w - 150)
    for li = 1, math.min(2, #lines) do
        DrawPixelText(ctx, x + 18, y + 36 + (li - 1) * 18, lines[li], 15, C.text)
    end
    if b.actionText and b.actionText ~= "" then
        local bx = x + w - 30 - 96
        local by = y + 5
        DrawRect(ctx, bx, by, 90, 26, C.card, 5)
        DrawStroke(ctx, bx, by, 90, 26, C.cyan, 5, 1.2)
        DrawPixelText(ctx, bx + 45, by + 5, b.actionText, 14, C.cyan,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
    local cx0 = x + w - 30
    local cy0 = y + 6
    DrawRect(ctx, cx0, cy0, 24, 24, C.widget, 5)
    nvgStrokeColor(ctx, nvgRGBA(C.dim[1], C.dim[2], C.dim[3], 230))
    nvgStrokeWidth(ctx, 1.6)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, cx0 + 7, cy0 + 7)
    nvgLineTo(ctx, cx0 + 17, cy0 + 17)
    nvgMoveTo(ctx, cx0 + 17, cy0 + 7)
    nvgLineTo(ctx, cx0 + 7, cy0 + 17)
    nvgStroke(ctx)
    nvgRestore(ctx)
end

-- v0.12.11 修复（AB-100 前向引用）：同样先用后声明——此前任何 stage 出错时
-- 错误处理器本身是 nil，把可恢复的绘制错误升级成整个 overlay 回调崩溃
-- （nvgEndFrame 被跳过、整帧丢弃、且真实错误被吞掉）。
local ReportOverlayStageError = nil

local function ApplyOverlayDesignTransform()
    nvgResetScissor(vg_)
    nvgResetTransform(vg_)
    nvgGlobalAlpha(vg_, 1.0)
    nvgScale(vg_, scale_, scale_)
    nvgTranslate(vg_, offsetX_, offsetY_)
end

local function RunOverlayStage(stage, callback)
    nvgSave(vg_)
    local ok, err = pcall(callback)
    nvgRestore(vg_)
    if not ok then ReportOverlayStageError(stage, err) end
    return ok
end

-- 窗口开合统一走弹动缩放 + 渐显渐隐。backdropMode：
--   "game" = 战斗模态：遮罩由本函数绘制且不随缩放（缩放会把遮罩边缘内缩、漏出 3D 世界）；
--   其他   = 元层面板：Shell/SupplyPopup 内部自带全屏遮罩，其下永远是实心菜单背景，
--            弹动时缝隙只露菜单不会露世界，无需外层重复铺。
local function DrawAnimatedWindow(stage, startAt, leaving, drawer, backdropMode)
    local alpha, scale = WindowMotion(startAt, leaving)
    if alpha <= 0 then return end
    RunOverlayStage(stage, function()
        ApplyOverlayDesignTransform()
        nvgGlobalAlpha(vg_, alpha)
        if backdropMode == "game" then
            DrawModalBackdrop(vg_, 0, MENU_CONTENT_TOP, DESIGN_W, DESIGN_H - MENU_CONTENT_TOP)
        end
        nvgTranslate(vg_, DESIGN_W * 0.5, DESIGN_H * 0.5)
        nvgScale(vg_, scale, scale)
        nvgTranslate(vg_, -DESIGN_W * 0.5, -DESIGN_H * 0.5)
        drawer()
    end)
end

local function DrawMinimalHudFallback(game)
    ApplyOverlayDesignTransform()
    nvgBeginPath(vg_)
    nvgRect(vg_, 0, 0, game.width, HUD_HEIGHT)
    nvgFillColor(vg_, nvgRGBA(C.panel[1], C.panel[2], C.panel[3], 255))
    nvgFill(vg_)
    nvgBeginPath(vg_)
    nvgRect(vg_, 0, HUD_HEIGHT - 2, game.width, 2)
    nvgFillColor(vg_, nvgRGBA(C.cyan[1], C.cyan[2], C.cyan[3], 255))
    nvgFill(vg_)
    UseTechFont(vg_)
    nvgFontSize(vg_, 17)
    nvgFillColor(vg_, nvgRGBA(C.text[1], C.text[2], C.text[3], 255))
    nvgText(vg_, 12, 16, "得分 " .. tostring(game.score or 0), nil)
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgText(vg_, game.width * 0.5, 16,
        string.format("第 %d 关 · %d/10 波", game.stage or 1, game.stageWave or game.wave or 1), nil)
    nvgTextAlign(vg_, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    nvgText(vg_, game.width - 48, 16,
        "基地 " .. tostring(game.baseHp or 0) .. "/" .. tostring(game.maxBaseHp or 0), nil)
end

local function DrawMinimalDockFallback(game)
    ApplyOverlayDesignTransform()
    nvgBeginPath(vg_)
    nvgRect(vg_, 0, BOTTOM_DOCK_Y, DESIGN_W, DESIGN_H - BOTTOM_DOCK_Y)
    nvgFillColor(vg_, nvgRGBA(C.panel[1], C.panel[2], C.panel[3], 255))
    nvgFill(vg_)
    nvgBeginPath(vg_)
    nvgRect(vg_, 0, BOTTOM_DOCK_Y, DESIGN_W, 2)
    nvgFillColor(vg_, nvgRGBA(C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 255))
    nvgFill(vg_)
    UseTechFont(vg_)
    nvgFontSize(vg_, 13)
    nvgFillColor(vg_, nvgRGBA(C.dim[1], C.dim[2], C.dim[3], 255))
    nvgText(vg_, 12, BOTTOM_DOCK_Y + 6, "弹药矩阵", nil)
    nvgFontSize(vg_, 15)
    for i, ballType in ipairs(SLOT_TYPES) do
        local x = (i <= 2 and 10 or DESIGN_W - 10 - 2 * 64 - 6)
            + ((i - 1) % 2) * 70
        local y = BOTTOM_DOCK_Y + 26
        local unlocked = game.unlockedBalls and game.unlockedBalls[ballType] == true
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, x, y, 64, 64, 5)
        local fill = unlocked and C.card or C.rail
        nvgFillColor(vg_, nvgRGBA(fill[1], fill[2], fill[3], 255))
        nvgFill(vg_)
        nvgStrokeColor(vg_, nvgRGBA(C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 255))
        nvgStrokeWidth(vg_, 1)
        nvgStroke(vg_)
        nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg_, nvgRGBA(C.text[1], C.text[2], C.text[3], 255))
        nvgText(vg_, x + 32, y + 15, SLOT_NAMES[ballType], nil)
        nvgFontSize(vg_, 12)
        nvgText(vg_, x + 32, y + 40, unlocked and "已解锁" or "待解锁", nil)
        nvgFontSize(vg_, 15)
    end
end

local function RenderOverlay(game, presentation, meta)
    if not vg_ then return end
    local beginOk, beginErr = pcall(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        nvgBeginFrame(vg_, logicalWidth_, logicalHeight_, dpr_)
    end)
    if not beginOk then
        ReportOverlayStageError("begin-frame", beginErr)
        return
    end

    RunOverlayStage("letterbox", function()
        nvgResetScissor(vg_)
        nvgResetTransform(vg_)
        nvgGlobalAlpha(vg_, 1.0)
        nvgScale(vg_, scale_, scale_)
        DrawLetterboxBackground(vg_, screenDesignWidth_, screenDesignHeight_)
    end)

    RunOverlayStage("frame-decoration", function()
        ApplyOverlayDesignTransform()
        DrawCornerBrackets(vg_, 2, 2, DESIGN_W - 4, DESIGN_H - 4,
            {C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 140}, 18, 1.4)
        DrawBrokenFrame(vg_, 0.5, 0.5, DESIGN_W - 1, DESIGN_H - 1,
            {C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 90}, 42)
    end)

    if game.state == "playing" then
        RunOverlayStage("world-fx", function()
            ApplyOverlayDesignTransform()
            if presentation.screenShake > 0 then
                local amplitude = presentation.screenShake * 13
                nvgTranslate(vg_, math.sin(game.elapsed * 91) * amplitude,
                    math.cos(game.elapsed * 73) * amplitude * 0.65)
            end
            DrawBaseImpactFeedback(vg_, game, presentation)
            DrawShockRings(vg_, game, presentation)
            DrawFloatTexts(vg_, game, presentation)
            DrawWaveBanner(vg_, game, presentation)
        end)
    end

    ApplyOverlayDesignTransform()
    if game.state ~= "menu" then
        if not RunOverlayStage("hud", function() DrawHud(vg_, game, presentation) end) then
            RunOverlayStage("hud-fallback", function() DrawMinimalHudFallback(game) end)
        end
    end

    if game.state == "playing" then
        if not RunOverlayStage("playing-dock", function()
            DrawAmmoSlots(vg_, game, presentation)
            DrawItemSlots(vg_, game)
            DrawPullHint(vg_, game)
        end) then
            RunOverlayStage("dock-fallback", function() DrawMinimalDockFallback(game) end)
        end
        RunOverlayStage("damage-vignette", function() DrawDamageVignette(vg_, game, presentation) end)
        -- v0.13.17：Boss 在场时画阶段条（DrawBossPhaseBar 此前定义了却从未调用）。
        RunOverlayStage("boss-phase", function()
            local boss = FindBoss(game)
            if boss then DrawBossPhaseBar(vg_, game, boss) end
        end)
        -- v0.13.24：进关准备期过渡界面——画在 HUD/Dock 之后，作为模态压住整屏。
        if (game.introTimer or 0) > 0 then
            RunOverlayStage("stage-intro", function()
                ApplyOverlayDesignTransform()
                StageIntro.Draw(vg_, game)
            end)
        end
    elseif game.state == "menu" then
        RunOverlayStage("menu", function() DrawMenu(vg_, game, meta) end)
    end

    local currentWindow = game.state == "gameover" or game.state == "levelup"
        or game.state == "paused" or game.state == "stagewin"
    if uiGameLeaving_ and uiGameLeaving_.visual and not currentWindow then
        local old = uiGameLeaving_
        DrawAnimatedWindow("game-window-out", uiGameLeaveAt_, true, function()
            local oldGame = old.visual.game
            if old.state == "gameover" then DrawGameOver(vg_, oldGame, presentation)
            elseif old.state == "levelup" then DrawLevelUp(vg_, oldGame, presentation)
            elseif old.state == "paused" then DrawPaused(vg_, oldGame, old.visual.meta, presentation)
            elseif old.state == "stagewin" then DrawStageWin(vg_, oldGame, presentation) end
        end, "game")
    end
    if currentWindow then
        DrawAnimatedWindow("game-window-in", uiStateMotionEnter_, false, function()
            if game.state == "gameover" then DrawGameOver(vg_, game, presentation)
            elseif game.state == "levelup" then DrawLevelUp(vg_, game, presentation)
            elseif game.state == "stagewin" then DrawStageWin(vg_, game, presentation)
            else DrawPaused(vg_, game, meta, presentation) end
        end, "game")
    end

    if metaScreenLeaving_ and metaScreenLeaving_.meta then
        local old = metaScreenLeaving_
        DrawAnimatedWindow("meta-screen-out", metaScreenLeaveAt_, true, function()
            old.meta.screen = old.screen
            MetaUI.DrawScreen(vg_, DESIGN_W, old.meta)
        end)
    end
    if meta and meta.screen then
        DrawAnimatedWindow("meta-screen-in", metaScreenEnter_, false,
            function() MetaUI.DrawScreen(vg_, DESIGN_W, meta) end)
    end
    if metaSupplyLeaving_ then
        DrawAnimatedWindow("supply-out", metaSupplyLeaveAt_, true,
            function() MetaUI.DrawSupplyPopup(vg_, DESIGN_W, metaSupplyLeaving_) end)
    end
    if meta and meta.supplyOpen then
        DrawAnimatedWindow("supply-in", metaSupplyEnter_, false,
            function() MetaUI.DrawSupplyPopup(vg_, DESIGN_W, meta) end)
    end
    ApplyOverlayDesignTransform()
    RunOverlayStage("system-banner", function() DrawSystemBanner(vg_) end)

    local endOk, endErr = pcall(nvgEndFrame, vg_)
    if not endOk then ReportOverlayStageError("end-frame", endErr) end
end

-- ============================================================================
-- v0.12.1：NanoVG 覆盖层用**函数引用**订阅，不再依赖字符串函数名。
--
-- ⚠️ `SubscribeToEvent(event, "HandleXxx")` 的字符串形式按「文件作用域」解析：
--    处理器定义在别的文件、或入口搬迁之后，订阅会**静默失效**（不报错、不触发），
--    表现为「3D 正常但 2D 界面全部消失」。
--    这里的做法是让后端自己闭环：订阅与处理器、快照都在本文件内，不依赖任何外部函数名。
-- ============================================================================

---@type table|nil
local lastPresentation_ = nil
local overlayStageErrors_ = {}
local overlayFirstFrameLogged_ = false
local overlaySnapshotLogged_ = false

ReportOverlayStageError = function(stage, err)
    if overlayStageErrors_[stage] then return end
    overlayStageErrors_[stage] = true
    print("[Scene3DBackend] overlay stage failed: " .. stage .. " / " .. tostring(err))
end

---@param eventType string
---@param eventData any
local function HandleBackendNanoVGRender(eventType, eventData)
    if not vg_ then return end
    if not overlayFirstFrameLogged_ then
        overlayFirstFrameLogged_ = true
        print("[Scene3DBackend] NanoVGRender callback active; waiting for game snapshot")
    end
    if lastGame_ and lastPresentation_ then
        if not overlaySnapshotLogged_ then
            overlaySnapshotLogged_ = true
            print("[Scene3DBackend] overlay snapshot active state=" .. tostring(lastGame_.state))
        end
        RenderOverlay(lastGame_, lastPresentation_, lastMeta_)
        return
    end
    -- 首帧兜底：覆盖层要等第一次 Update 之后才有快照可画，这中间恰好空掉一帧。
    -- 不兜的话会露出引擎默认清屏色——玩家看到的就是「切进游戏时闪一下灰」。
    --
    -- ⚠️ 这里必须**整屏实心填充**，不能调用 DrawLetterboxBackground：
    --    那个函数只填设计画布**外**的 letterbox（画布内部要留给 3D），
    --    而 9:16 屏幕上 offsetX_/offsetY_ 都是 0 → 它一笔都不画 → 灰帧照旧。
    nvgBeginFrame(vg_, logicalWidth_, logicalHeight_, dpr_)
    nvgResetTransform(vg_)
    nvgResetScissor(vg_)
    nvgGlobalAlpha(vg_, 1.0)
    nvgScale(vg_, scale_, scale_)
    nvgTranslate(vg_, offsetX_ or 0, offsetY_ or 0)
    nvgBeginPath(vg_)
    nvgRect(vg_, 0, 0, DESIGN_W, DESIGN_H)
    nvgFillColor(vg_, nvgRGBA(C.bg[1], C.bg[2], C.bg[3], 255))
    nvgFill(vg_)
    nvgEndFrame(vg_)
end

function Backend.Init()
    if scene_ then
        MetaUI.Shutdown()
        Backend.ClearPointer()
        uiFx.controls = {}
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
        progress = DrawPremiumProgress,
        shell = DrawWindowShell,
        corner = DrawCornerBrackets,
        grid = DrawMicroGrid,
        rule = DrawSegmentedRule,
        backdrop = DrawModalBackdrop,
        wrap = WrapTextLines,
        icon = DrawIcon,
        -- v0.13.30c：把「悬停查询 + 动画相位」注入元层，让 MetaUI 的按钮也能悬停发光、
        -- 分区标题/进度条也能动起来（避免 MetaUI 反向 require 后端）。
        hovering = Backend.IsHovering,
        hoverGlow = Backend.GetHoverGlow,
        anim = Backend.GetAnimPhase,
        controlFx = Backend.GetControlFx,
        measure = MeasurePixelWidth,
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

    -- 手势图是可选资源：缺失时只跳过提示，绝不纳入初始化成功条件。
    handImage_ = nvgCreateImage(vg_, HAND_IMAGE_PATH, 0)
    -- ⚠️ 必须在 vg_ 创建之后加载；vg_ 为 nil 时所有图标都会静默失败。
    LoadIcons()
    LoadLogoTitles()
    if not handImage_ or handImage_ <= 0 then
        handImage_ = -1
        print("[Scene3DBackend] hand hint image unavailable: " .. HAND_IMAGE_PATH)
    end

    if not Renderer3D.Init(scene_, voxelWorld_) then
        print("[Scene3DBackend] ERROR: Renderer3D initialization failed")
        CleanupFailedInit()
        return false
    end
    -- 传函数值而非函数名：不受「处理器定义在哪个文件」影响。
    SubscribeToEvent(vg_, "NanoVGRender", HandleBackendNanoVGRender)
    print("[Scene3DBackend] initialized: 9:16 locked viewport, dark-tech HUD, orthographic 46-degree aircraft camera")
    return true
end

function Backend.Shutdown()
    MetaUI.Shutdown()
    Backend.ClearPointer()
    uiFx.controls = {}
    uiFx.anim, uiFx.epoch, uiFx.scope = 0, 0, ""
    Renderer3D.Shutdown()
    uiState_, uiGameVisual_, uiGameLeaving_ = nil, nil, nil
    metaScreen_, metaScreenLeaving_, metaSupplyLeaving_ = nil, nil, nil
    metaSupply_, metaVisual_ = false, nil
    uiClock_, uiLastElapsed_ = 0, nil
    lastGame_, lastPresentation_, lastMeta_ = nil, nil, nil
    if vg_ then
        nvgDelete(vg_)
        vg_ = nil
    end
    nvgFontZpix_ = -1
    handImage_ = -1
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
function Backend.UpdateScene(gameSnapshot, presentationSnapshot, metaState)
    UpdateUiState(gameSnapshot, metaState)
    -- 共享时间只驱动循环动画；各控件的进入/退出与按压分别缓动。
    local dtAnim = math.min(0.05, math.max(0, gameSnapshot.elapsed - uiFx.anim))
    uiFx.anim = gameSnapshot.elapsed
    uiFx.epoch = uiFx.epoch + 1
    uiFx.scope = tostring(gameSnapshot.state) .. ":" .. tostring(metaState and metaState.screen or "")
        .. ":" .. tostring(metaState and metaState.supplyOpen or false)
    for key, control in pairs(uiFx.controls) do
        if uiFx.epoch - control.seen > 2 then
            uiFx.controls[key] = nil
        else
            local hoverTarget = control.hit and uiFx.hover.active and 1 or 0
            local pressTarget = control.hit and uiFx.pressed and 1 or 0
            control.glow = control.glow + (hoverTarget - control.glow) * math.min(1, dtAnim * 12)
            control.press = control.press + (pressTarget - control.press) * math.min(1, dtAnim * 22)
        end
    end
    MetaUI.Update(dtAnim, metaState, gameSnapshot.state)
    -- 缓存本帧快照，供本文件内的 NanoVGRender 处理器直接使用（不依赖外部调用）。
    lastGame_ = gameSnapshot
    lastPresentation_ = presentationSnapshot
    lastMeta_ = metaState
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
    -- A6：Boss 波期间危险带常驻染成紫色警示，与普通波区分。
    local bossActive = false
    for _, enemy in ipairs(gameSnapshot.veggies or {}) do
        if enemy.isBoss then bossActive = true; break end
    end
    local flash = presentationSnapshot.baseBarrierFlash or 0
    -- 紫线：固定原位置，只做受击 / Boss 的视觉警示，不跟规则线走。
    if dangerBandNode_ then
        local baseR, baseG, baseB = 0.39, 0.19, 0.67
        if bossActive then baseR, baseG, baseB = 0.62, 0.20, 0.74 end
        dangerBandNode_.scale = Vector3(11.0, 0.06 + flash * 0.18, 0.06 + flash * 0.12)
        if dangerBandMaterial_ then
            dangerBandMaterial_:SetShaderParameter("MatDiffColor", Variant(Color(
                math.min(1.0, baseR + flash * 0.20),
                math.min(1.0, baseG + flash * 0.48),
                math.min(1.0, baseB + flash * 0.33), 1)))
            dangerBandMaterial_:SetShaderParameter("MatEmissiveColor", Variant(Color(
                math.min(1.0, 0.26 + flash * 1.7 + (bossActive and 0.22 or 0)),
                math.min(1.0, 0.09 + flash * 3.1 + (bossActive and 0.08 or 0)),
                math.min(1.0, 0.46 + flash * 4.0 + (bossActive and 0.45 or 0)), 1)))
        end
    end
    -- 红线：与规则层越线判定同源（Game.lua 的 brickBottom > DANGER_Y），
    -- 每帧按快照 dangerY 刷 y，z=0 与敌机体素同平面，精确落在扣血瞬间。
    if breachLineNode_ then
        local dangerY = gameSnapshot.dangerY
        if dangerY then
            -- 只取 y：横线要横跨整个场地，x 必须居中 0（不能用 WorldFromGame(0,..) 的 x=-4.86）。
            breachLineNode_.position = Vector3(0, (DESIGN_H * 0.5 - dangerY) * 0.018, 0)
        end
        breachLineNode_.scale = Vector3(11.0, 0.055 + flash * 0.16, 0.055 + flash * 0.10)
        if breachLineMaterial_ then
            breachLineMaterial_:SetShaderParameter("MatDiffColor", Variant(Color(
                math.min(1.0, 0.95 + flash * 0.05),
                math.max(0.0, 0.16 - flash * 0.10),
                math.max(0.0, 0.20 - flash * 0.12), 1)))
            breachLineMaterial_:SetShaderParameter("MatEmissiveColor", Variant(Color(
                math.min(1.0, 0.85 + flash * 1.4),
                math.min(1.0, 0.10 + flash * 2.2),
                math.min(1.0, 0.14 + flash * 2.6), 1)))
        end
    end
    -- 升级/暂停/菜单时停体素求解，避免碎块在模态下继续飞。
    if voxelWorld_ then
        local playing = gameSnapshot.state == "playing"
        voxelWorld_:SetSimulationPaused(not playing)
    end
    -- v0.12.5：顶端通知条按快照 elapsed 差分计时（菜单/暂停也持续递减）。
    TickSystemBanner(gameSnapshot.elapsed or 0)
    Renderer3D.Render(gameSnapshot, presentationSnapshot, metaState and metaState.selectedSkin)
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
    local x, y = WindowInput(uiX, uiY, metaScreenEnter_)
    return MetaUI.HitTestScreen(x, y, DESIGN_W, metaState)
end

---@return string|nil action
function Backend.HitTestSupplyPopup(uiX, uiY, metaState)
    if not metaState or not metaState.supplyOpen then return nil end
    local x, y = WindowInput(uiX, uiY, metaSupplyEnter_)
    return MetaUI.HitTestSupplyPopup(x, y, DESIGN_W)
end

function Backend.HitTestGameOverButton(uiX, uiY, game)
    uiX, uiY = WindowInput(uiX, uiY, uiStateMotionEnter_)
    local revive, double, restart, menu = GetGameOverButtonLayout(game or {})
    local function inside(btn)
        return uiX >= btn.x and uiX <= btn.x + btn.w
            and uiY >= btn.y and uiY <= btn.y + btn.h
    end
    if inside(revive) then return "revive" end
    if inside(double) then return "double" end
    if inside(restart) then return "restart" end
    -- v0.12.5：结算页「回主菜单」出口
    if inside(menu) then return "menu" end
    return nil
end

-- v0.13.4：胜利结算页命中（再战本关 / 下一关 / 回主菜单）。几何与 DrawStageWin 同源。
function Backend.HitTestStageWinButton(uiX, uiY, game)
    uiX, uiY = WindowInput(uiX, uiY, uiStateMotionEnter_)
    local retry, nextBtn, menu = GetStageWinButtonLayout(game or {})
    local function inside(btn)
        return uiX >= btn.x and uiX <= btn.x + btn.w
            and uiY >= btn.y and uiY <= btn.y + btn.h
    end
    if inside(retry) then return "retry" end
    -- 「下一关」仅在还有下一关时可点。
    if inside(nextBtn) then return (game and game.stageHasNext) and "next" or nil end
    if inside(menu) then return "menu" end
    return nil
end

-- v0.13.4：主菜单「开始战斗」CTA 命中（几何与 DrawMenu 共用 GetMenuCtaRect）。
function Backend.HitTestMenuCta(uiX, uiY, game)
    local cta = GetMenuCtaRect(game or {})
    return (uiX >= cta.x and uiX <= cta.x + cta.w and uiY >= cta.y and uiY <= cta.y + cta.h)
end

-- v0.12.5 精简：升级面板命中（只保留免费重抽/看广告重抽/锁定/选卡）。
-- 与 DrawLevelUp 共用 GetUpgradePanelLayout，视觉与命中永远同源。
---@param uiX number
---@param uiY number
---@param game table
---@return string|nil kind
---@return integer|nil index
function Backend.HitTestUpgradePanel(uiX, uiY, game)
    uiX, uiY = WindowInput(uiX, uiY, uiStateMotionEnter_)
    local layout = GetUpgradePanelLayout(game or {})
    local function inside(rect)
        return uiX >= rect.x and uiX <= rect.x + rect.w
            and uiY >= rect.y and uiY <= rect.y + rect.h
    end

    if inside(layout.rerollFree) then return "reroll_free", nil end
    if inside(layout.rerollAd) then return "reroll_ad", nil end

    local choices = (game and game.upgradeChoices) or {}
    local cardTop = layout.cy - layout.cardH * 0.5
    for i = 1, layout.cardCount do
        local cx = layout.startX + (i - 1) * (layout.cardW + layout.gap)
        local choice = choices[i]
        -- 左上「锁定/保留」角标先于卡体判定。
        if choice and inside(GetHoldBadgeRect(cx, cardTop, layout.cardW)) then
            return "hold", i
        end
        if math.abs(uiX - cx) <= layout.cardW * 0.5 + 4
            and math.abs(uiY - layout.cy) <= layout.cardH * 0.5 + 4 then
            return "card", i
        end
    end
    return nil, nil
end

-- v0.11.0 商业化：暂停补给站命中判定（与 DrawPaused 同源）。
---@return string|nil kind "pause_heal" | "pause_rare" | "pause_orbital" | "pause_reload" | "pause_parts_boost" | "pause_resume" | "pause_menu"
function Backend.HitTestPausePanel(uiX, uiY, game)
    uiX, uiY = WindowInput(uiX, uiY, uiStateMotionEnter_)
    local layout = GetPausePanelLayout((game and game.width) or DESIGN_W)
    local function inside(r)
        return uiX >= r.x and uiX <= r.x + r.w and uiY >= r.y and uiY <= r.y + r.h
    end
    -- v0.12.5：出口按钮先于补给行（虽几何不重叠，保持顺序防御后续改布局）
    if inside(layout.resume) then return "pause_resume" end
    if inside(layout.menu) then return "pause_menu" end
    if inside(layout.heal) then return "pause_heal" end
    if inside(layout.rare) then return "pause_rare" end
    if inside(layout.orbital) then return "pause_orbital" end
    if inside(layout.reload) then return "pause_reload" end
    if inside(layout.partsBoost) then return "pause_parts_boost" end
    return nil
end

-- v0.12.5：HUD 右上角暂停按钮命中（与 DrawHud 同源）。
function Backend.HitTestHudPause(uiX, uiY, game)
    local r = GetHudPauseRect(game)
    if uiX >= r.x and uiX <= r.x + r.w and uiY >= r.y and uiY <= r.y + r.h then
        return true
    end
    return false
end

-- v0.12.5：局内道具竖列命中判定（与 DrawItemSlots 共用 GetItemPanelLayout）。
---@return string|nil kind "toggle" | "slot"
---@return integer|nil index 槽位序号（kind=="slot" 时）
function Backend.HitTestItemSlot(uiX, uiY, game)
    local items = (game and game.items) or {}
    local tab, slots = GetItemPanelLayout()
    local function inside(r)
        return uiX >= r.x and uiX <= r.x + r.w and uiY >= r.y and uiY <= r.y + r.h
    end
    if itemPanelOpen_ then
        for i = 1, #slots do
            if items[i] and inside(slots[i]) then
                return "slot", i
            end
        end
        -- 展开态标签区仍是「收起」按钮
        if inside(tab) then return "toggle" end
        return nil
    end
    if inside(tab) then return "toggle" end
    return nil
end

---@return boolean open
function Backend.IsItemPanelOpen()
    return itemPanelOpen_
end

-- 控件显式登记几何，缓动统一由 UpdateScene 推进。
-- 持续按住的主触点拥有反馈；其他触点及鼠标不能覆盖它。
---@param uiX number 设计坐标 X（已过 ScreenToUi）
---@param uiY number 设计坐标 Y
---@param touchId integer|nil 省略表示鼠标
function Backend.SetPointer(uiX, uiY, touchId)
    if uiFx.touchId ~= nil and touchId ~= uiFx.touchId then return end
    uiFx.hover.x = uiX
    uiFx.hover.y = uiY
    uiFx.hover.active = true
end

-- 指针离开画布/触摸结束：熄灭悬停（强度会平滑降下来，不是硬切）。
function Backend.ClearPointer()
    uiFx.hover.active = false
    uiFx.pressed = false
    uiFx.touchId = nil
end

function Backend.BeginTouchPointer(id, x, y)
    if uiFx.touchId ~= nil then return false end
    uiFx.touchId = id
    Backend.SetPointer(x, y, id)
    Backend.SetPointerPressed(true, id)
    return true
end

function Backend.MoveTouchPointer(id, x, y)
    if uiFx.touchId == id then Backend.SetPointer(x, y, id) end
end

function Backend.EndTouchPointer(id)
    if uiFx.touchId == id then Backend.ClearPointer() end
end

---@param pressed boolean
---@param touchId integer|nil 省略表示鼠标
function Backend.SetPointerPressed(pressed, touchId)
    if uiFx.touchId ~= nil and touchId ~= uiFx.touchId then return end
    uiFx.pressed = pressed == true
end

-- 只由可交互控件显式调用，不能按面板尺寸猜按钮。缓动在 UpdateScene 推进。
function Backend.GetControlFx(rect, enabled)
    local key = uiFx.scope .. string.format(":%.2f:%.2f:%.2f:%.2f", rect.x, rect.y, rect.w, rect.h)
    local control = uiFx.controls[key]
    if not control then
        control = {glow = 0, press = 0, hit = false, seen = uiFx.epoch}
        uiFx.controls[key] = control
    end
    control.seen = uiFx.epoch
    if not enabled then
        control.hit, control.glow, control.press = false, 0, 0
        return 0, 0
    end
    local x, y = uiFx.hover.x, uiFx.hover.y
    if lastMeta_ and lastMeta_.supplyOpen then
        x, y = WindowInput(x, y, metaSupplyEnter_)
    elseif lastMeta_ and lastMeta_.screen and lastMeta_.screen ~= "" then
        x, y = WindowInput(x, y, metaScreenEnter_)
    elseif lastGame_ and lastGame_.state ~= "menu" and lastGame_.state ~= "playing" then
        x, y = WindowInput(x, y, uiStateMotionEnter_)
    end
    control.hit = uiFx.hover.active and x >= rect.x and x <= rect.x + rect.w
        and y >= rect.y and y <= rect.y + rect.h
    return control.glow, control.press
end

---@param rect table {x,y,w,h}
---@return boolean
function Backend.IsHovering(rect)
    if not uiFx.hover.active or not rect then return false end
    local x, y = uiFx.hover.x, uiFx.hover.y
    return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

---@return number 0..1 平滑悬停强度（全屏共享，不针对单个控件）
function Backend.GetHoverGlow()
    local glow = 0
    for _, control in pairs(uiFx.controls) do glow = math.max(glow, control.glow) end
    return glow
end

---@return number 持续动画相位（秒），全屏共享
function Backend.GetAnimPhase()
    return uiFx.anim
end

function Backend.SetItemPanelOpen(open)
    itemPanelOpen_ = open and true or false
end

function Backend.ToggleItemPanel()
    itemPanelOpen_ = not itemPanelOpen_
end

function Backend.GetDesignSize()
    return DESIGN_W, DESIGN_H
end

return Backend
