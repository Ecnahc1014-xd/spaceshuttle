-- Scene3DBackend.lua
-- 3D 场景后端：固定 540x960 设计坐标，使用正交相机呈现体素敌人与运输车。

-- Renderer3D 是本模块最大的依赖（约 84KB）。**必须 pcall 降级**：若它因任何原因
-- 加载失败（最典型的是打包/预下载漏掉该文件 → `Module not found: Renderer3D`），
-- 裸 require 会让整个 Scene3DBackend 加载失败 → client_main → main.Start 连锁崩溃
-- → **整屏黑屏，连 2D UI 都没有**。降级为 no-op 后，3D 层不画、但菜单/HUD/所有
-- NanoVG UI 仍可用，玩家至少能看到界面而不是黑屏。
-- ⚠️ 用 IIFE 包裹以免新增顶层 local（本文件顶层 local 已达 197/200，AB-166）。
local Renderer3D = (function()
    local ok, mod = pcall(require, "Renderer3D")
    if ok and type(mod) == "table" then return mod end
    print("[Scene3DBackend] WARN: Renderer3D unavailable, running 2D-only fallback: "
        .. tostring(mod))
    local noop = function() end
    return {
        Init = function() return false end,
        Shutdown = noop, Render = noop, Update = noop,
        GetVehicleAnchor = function() return nil end,
        GetVehicleAnchorWorld = function() return nil end,
        DebugTrailVertexCount = function() return 0 end,
        _unavailable = true,
    }
end)()
local SkyUtils = require "urhox-libs.Rendering.SkyUtils"
local VisualCatalog = require "VisualCatalog"
local TalentCatalog = require "TalentCatalog"
local MetaUI = require "MetaUI"
local StageIntro = require "ui.StageIntro"
local StageTransition = require "ui.StageTransition"
local ArtText = require "ui.ArtText"
local DigitFont = require "ui.DigitFont"

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
    if uiFx.surface then uiFx.surface.Shutdown() end
    if uiFx.battle then uiFx.battle.Shutdown() end
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

local BUILD_VERSION = "0.13.60"
local GAME_TITLE = "货车大战飞机"
-- 主菜单像素大 logo 用的短名（对外全名仍是 GAME_TITLE，窗口/发布名不变）。
local GAME_SHORT_TITLE = "货车大战飞机"

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
    if uiFx.surface then uiFx.surface.UseFont(ctx, 17); return end
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
    nvgBeginPath(ctx)
    while drawn < len do
        local stop = drawn + d
        if stop > len then stop = len end
        nvgMoveTo(ctx, x1 + ux * drawn, y1 + uy * drawn)
        nvgLineTo(ctx, x1 + ux * stop, y1 + uy * stop)
        drawn = stop + g
    end
    nvgStrokeColor(ctx, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
    nvgStrokeWidth(ctx, width or 1)
    nvgStroke(ctx)
end

-- 十字标注点：取样点 / 定位点 / 激活标记
local function DrawCrossMark(ctx, x, y, size, color)
    DrawLine(ctx, x - size, y, x + size, y, color, 1)
    DrawLine(ctx, x, y - size, x, y + size, color, 1)
end

-- 环形刻度：圆形主体外圈，每 3 段加长。长短两档各合并成 1 条路径（原来是逐段
-- 各起一条路径 + 描边，O(n) 命令数）。
local function DrawTickRing(ctx, cx, cy, r, startDeg, endDeg, stepDeg, color)
    local steps = math.floor((endDeg - startDeg) / stepDeg)
    if steps < 4 then return end
    for pass = 0, 1 do
        nvgBeginPath(ctx)
        local any = false
        for idx = 0, steps do
            local long = (idx % 3 == 0)
            if (pass == 0) == long then
                any = true
                local rad = math.rad(startDeg + idx * stepDeg)
                local inner = r - (long and 7 or 3)
                local ox, oy = math.cos(rad), math.sin(rad)
                nvgMoveTo(ctx, cx + ox * inner, cy + oy * inner)
                nvgLineTo(ctx, cx + ox * r, cy + oy * r)
            end
        end
        if any then
            nvgStrokeColor(ctx, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
            nvgStrokeWidth(ctx, pass == 0 and 1.3 or 0.7)
            nvgStroke(ctx)
        end
    end
end

-- 半调网点阵：背景/面板底纹。
-- ⚠️ 必须**合并单一路径**（一次 beginPath + 多个 circle + 一次 fill）：逐点各起一条
-- 路径会撑爆 NanoVG 单帧命令缓冲，导致本帧后续绘制被静默丢弃（本项目实测踩到，
-- 表现为「只剩背景、卡片与文字全没了」且零报错，见 AB-216）。同时按面积自适应
-- 放大步长并钳总点数——这是全屏/大卡片底纹，「动画变卡」的主要来源之一。
local function DrawHalftone(ctx, x, y, w, h, step, alpha)
    step = step or 8
    if w < 8 or h < 8 then return end
    local budget = 600
    if (w / step) * (h / step) > budget then
        step = math.max(step, math.sqrt(w * h / budget))
    end
    if step < 7 then step = 7 end
    if w < step or h < step then return end
    local s = step * 2
    nvgSave(ctx)
    nvgIntersectScissor(ctx, x, y, w, h)
    nvgFillColor(ctx, nvgRGBA(C.halftone[1], C.halftone[2], C.halftone[3], alpha or 16))
    nvgBeginPath(ctx)
    local row = 0
    for gy = y + step * 0.5, y + h - 1, step do
        local off = (row % 2 == 0) and 0 or step
        for gx = x + step * 0.5 + off, x + w - 1, s do
            nvgCircle(ctx, gx, gy, 0.9)
        end
        row = row + 1
    end
    nvgFill(ctx)
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

-- 共享表面遵循深海军技术舱规范，调用签名与命中几何保持不变。
local function DrawMachinedPanel(ctx, x, y, w, h, fill, border, radius, emphasis)
    uiFx.surface.Panel(ctx, x, y, w, h, fill, border, radius, emphasis)
end

local function DrawWindowShell(ctx, x, y, w, h, titleH)
    uiFx.surface.Window(ctx, x, y, w, h, titleH)
end

-- 模态窗只保留边缘刻度、虚线与取样点，不在正文背后铺纹理。
-- 克制档：只做静态/低频装饰，不进入窗内正文与按钮命中区。
local function DrawModalTechDecor(ctx, x, y, w, h, elapsed)
    AnomalyPulse(elapsed)
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
        -- 接触瞬间白热细芯压在原红线内，保留紫/红双线坐标与既有重震。
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, 0, dangerScreenY); nvgLineTo(ctx, game.width, dangerScreenY)
        nvgStrokeColor(ctx, nvgRGBA(240, 248, 252, math.floor(alpha * math.min(1, flash * 2))))
        nvgStrokeWidth(ctx, 1.2)
        nvgStroke(ctx)
    end

    for _, impact in ipairs(presentation.baseImpacts or {}) do
        local screenX, screenY = ProjectGamePoint(impact.x, impact.y)
        local progress = 1 - impact.life / impact.maxLife
        local alpha = math.floor(255 * (1 - progress))
        nvgBeginPath(ctx)
        nvgEllipse(ctx, screenX, screenY, impact.radius * math.abs(projectionScaleX_),
            impact.radius * math.abs(projectionScaleY_))
        nvgStrokeColor(ctx, nvgRGBA(C.cyan[1], C.cyan[2], C.cyan[3], alpha))
        nvgStrokeWidth(ctx, 5 * (1 - progress) + 1)
        nvgStroke(ctx)
        nvgBeginPath(ctx)
        nvgEllipse(ctx, screenX, screenY, impact.radius * 0.84 * math.abs(projectionScaleX_),
            impact.radius * 0.84 * math.abs(projectionScaleY_))
        nvgStrokeColor(ctx, nvgRGBA(240, 248, 252, math.floor(alpha * 0.68)))
        nvgStrokeWidth(ctx, 1.3)
        nvgStroke(ctx)
        nvgBeginPath(ctx)
        for spoke = 1, 8 do
            local angle = impact.spin + spoke * math.pi * 0.25
            local inner = impact.radius * 0.45
            local outer = impact.radius * 1.15
            nvgMoveTo(ctx,
                screenX + math.cos(angle) * inner * projectionScaleX_,
                screenY + math.sin(angle) * inner * projectionScaleY_)
            nvgLineTo(ctx,
                screenX + math.cos(angle) * outer * projectionScaleX_,
                screenY + math.sin(angle) * outer * projectionScaleY_)
        end
        nvgStrokeColor(ctx, nvgRGBA(C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], math.floor(alpha * 0.8)))
        nvgStrokeWidth(ctx, 2)
        nvgStroke(ctx)
    end
end

-- v0.10.23：击毁扩散环（少量点缀），从 r0 扩到 r1 并淡出。
local function DrawShockRings(ctx, game, presentation)
    uiFx.impact.DrawRings(ctx, presentation, ProjectGamePoint)
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
        -- 实际提交四方向深色描边；nvgStrokeColor 不会改变 nvgText 的填充。
        nvgFillColor(ctx, nvgRGBA(C.ink[1], C.ink[2], C.ink[3], math.min(220, alpha)))
        nvgText(ctx, sx - 1, sy, f.text); nvgText(ctx, sx + 1, sy, f.text)
        nvgText(ctx, sx, sy - 1, f.text); nvgText(ctx, sx, sy + 1, f.text)
        nvgFillColor(ctx, nvgRGBA(col[1], col[2], col[3], alpha))
        nvgText(ctx, sx, sy, f.text)
    end
end

local function DrawTechPanel(ctx, x, y, width, height, fill, border)
    DrawRect(ctx, x, y, width, height, fill, 4)
    DrawStroke(ctx, x, y, width, height, border, 4, 1.2)
    DrawCornerBrackets(ctx, x + 1, y + 1, width - 2, height - 2, border, math.min(8, width * 0.22), 1)
end

-- 文字描边（v0.13.43）：规范 §8 的清晰度做法——四方向偏移同字绘制，
-- 不是 nvgStrokeText。大字才有必要，小字描边会糊。outlined 省略时按字号自动判定。
local function DrawPixelText(ctx, x, y, text, size, color, align, outlined)
    UseTechFont(ctx)
    uiFx.surface.UseFont(ctx, size)
    nvgFontSize(ctx, size)
    nvgTextAlign(ctx, align or (NVG_ALIGN_LEFT + NVG_ALIGN_TOP))
    local alpha = color[4] or 255
    local wantOutline = outlined
    if wantOutline == nil then wantOutline = size >= 17 end
    -- v0.13.50：描边色按字色亮度选，避免「黑边黑字」——暗字（青/绿/金底上的 ink 字）
    -- 若也用近黑描边，会把字糊成一团。亮字用深描边托出，暗字用亮描边（或干脆不描）。
    local lum = 0.299 * color[1] + 0.587 * color[2] + 0.114 * color[3]
    if wantOutline and size >= 12 and lum >= 120 then
        nvgFillColor(ctx, nvgRGBA(C.ink[1], C.ink[2], C.ink[3], math.min(235, alpha)))
        nvgText(ctx, x - 1, y, text, nil)
        nvgText(ctx, x + 1, y, text, nil)
        nvgText(ctx, x, y - 1, text, nil)
        nvgText(ctx, x, y + 1, text, nil)
    end
    nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], alpha))
    nvgText(ctx, x, y, text, nil)
end

-- 中文/ASCII 混排自动换行：按像素宽度贪心折行，返回行数。
-- 用 nvgTextBounds 实测宽度，避免按固定字数硬切。align: center 时按行居中。
local function WrapTextLines(ctx, text, size, maxWidth)
    local lines = {}
    local line = ""
    UseTechFont(ctx)
    uiFx.surface.UseFont(ctx, size)
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
    uiFx.surface.UseFont(ctx, size)
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

-- 模态外层沿用技术舱屏边支架，正文背景保持干净。
local function DrawModalBackdrop(ctx, x, y, width, height)
    uiFx.surface.Background(ctx, x, y, width, height, uiFx.anim)
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
    uiFx.battle.DrawPreview(ctx, game, VisualCatalog.GetAircraftPreview(plan.aircraftKey),
        AIRCRAFT_LABELS[plan.aircraftKey] or plan.aircraftKey)
end

-- v0.12.11 修复（AB-100 前向引用）：DrawIcon 的 local function 定义在本文件后段
-- （图标表区域，~1141 行），而 DrawAmmoSlots 等调用点早于它——不加前向声明时调用点
-- 解析成全局 nil，战斗中每帧 attempt to call a nil value，nvgEndFrame 被跳过 =
-- 整个 NanoVG 帧被丢弃 = 「3D 正常、2D 全没」。
local DrawIcon = nil

local function DrawAmmoSlots(ctx, game, presentation)
    uiFx.battle.DrawAmmo(ctx, game, presentation)
    DrawNextWavePreview(ctx, game)
end

-- v0.11.4：新手下拉提示。玩家本局还没发射过、也没在拖拽时，在弹弓车辆上方
-- 循环播放「手从上往下拉」的动画：手沿一条虚线从高处下移到发射位，再淡出重来。
-- 纯表现层，只读快照 showPullHint / slingX / slingY，不触达规则层。
local function DrawPullHint(ctx, game)
    if not game.showPullHint then return end
    if not handImage_ or handImage_ <= 0 then return end

    local slingX, projectedY = ProjectGamePoint(game.slingX or DESIGN_W * 0.5,
        game.slingY or (BOTTOM_DOCK_Y - 16))
    local slingY = math.min(BOTTOM_DOCK_Y - 48, projectedY)
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
    -- 整块手势和文案均裁在战场内，不压住HUD或下一波预告。
    nvgIntersectScissor(ctx, 0, HUD_HEIGHT, DESIGN_W, BOTTOM_DOCK_Y - HUD_HEIGHT - 4)

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

    -- 文案放在整段动画**上方**：既不与手势图重叠，也远离下方扣血红线（旧版贴在
    -- 手势底部，会同时压住手和红线，读起来像两行糊在一起）。
    DrawPixelText(ctx, slingX, topY - 24, "向下拖拽 松手发射",
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
    -- v0.13.59：主菜单左上角「设置」齿轮入口
    gear = "image/ui_icon_gear_20261011.png",
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
    -- v0.13.58 局内附魔卡图标（0718-pixelimage-aigc 后处理，32×32/≤7 色）。
    ench_split = "image/ui_ench_split.png",
    ench_lifesteal = "image/ui_ench_lifesteal.png",
    ench_homing = "image/ui_ench_homing.png",
    ench_pierce = "image/ui_ench_pierce.png",
    ench_chain = "image/ui_ench_chain.png",
    ench_freeze = "image/ui_ench_freeze.png",
    ench_power = "image/ui_ench_power.png",
    ench_explode = "image/ui_ench_explode.png",
    ench_triple = "image/ui_ench_triple.png",
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
-- 母版 = 显示尺寸（各字标按内容等比裁到 120 高，宽 201–294 不等），1× 最近邻。
local LOGO_PATHS = {
    { path = "image/ui_logo_truck_a_20261008175431.png", w = 294 },
    { path = "image/ui_logo_truck_b_20261008175431.png", w = 268 },
    { path = "image/ui_logo_truck_c_20261008175431.png", w = 201 },
    { path = "image/ui_logo_truck_d_20261008175431.png", w = 232 },
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

-- v0.13.58：局内附魔卡常驻左上角，与右上道具竖列镜像对称。
-- ⚠️ 宽度限制在 132：Boss 阶段条从 x=150 起（DrawBossPhaseBar），更宽会与之重叠。
-- ⚠️ 挂到 Backend 表上（不是顶层 local）——Scene3DBackend 顶层 local 已到 199，
--    再加 local 会撞 Lua 200 上限导致 LoadChunk 全屏黑（AB-166）。
function Backend.GetEnchantRect()
    return { x = 12, y = 100, w = 132, h = 104 }
end

---@param ctx any
---@param game table
local function DrawItemSlots(ctx, game)
    if not game.items then return end
    local tab, slots = GetItemPanelLayout()
    uiFx.battle.DrawItems(ctx, game, tab, slots, itemPanelOpen_)
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

local function DrawBossPhaseBar(ctx, game, boss, presentation)
    -- 短时入场预告优先，避免阶段提示与首领横幅互相叠字。
    if (presentation.waveBannerTimer or 0) > 0 then return end
    uiFx.battle.DrawBoss(ctx, game, boss)
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

-- v0.13.59：HUD 暂停按钮改到**左上角**（原右上角）。绘制与命中共用。
-- ⚠️ 左栏内容（BattleHUD）相应右移 28px 让位。
local function GetHudPauseRect(game)
    return { x = 10, y = 8, w = 28, h = 28 }
end

local function DrawHud(ctx, game, presentation)
    uiFx.battle.DrawHud(ctx, game, presentation, GetHudPauseRect(game))
end

-- v0.12.7：像素大 logo。⚠️ zpix 位图字体逐字（单码位）绘制在超大字号会退化成
-- 空框（v0.12.6 逐字排版真机只有两个空心矩形），改回「整串一次绘制 + 硬偏移阴影」，
-- 与既有 36px「货车大战飞机」同一条已验证可渲染的路径，只是加大字号。
local function DrawPixelLogo(ctx, cx, topY, title, size, bodyColor, shadowColor)
    -- 阴影层（右下偏移暗青）
    DrawPixelText(ctx, cx + size * 0.045, topY + size * 0.045, title, size,
        shadowColor or C.cyanDim, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    -- 主层
    DrawPixelText(ctx, cx, topY, title, size, bodyColor or C.text,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
end

-- v0.13.4：主菜单「开始战斗」CTA 几何（绘制与命中共用，禁止两套常量）。
-- v0.13.58：按钮 72→84 高——艺术字母版由 38 改 44 后，44(字) + 铭牌留白 + 13(副标题)
-- 在 72 里塞不下，副标题会压到铭牌底边（实测重叠 ~4px）。加高后内容才有呼吸空间。
local function GetMenuCtaRect(game)
    local w = (game and game.width) or DESIGN_W
    return { x = 42, y = 430, w = w - 84, h = 84 }
end

local function DrawMenu(ctx, game, meta)
    nvgSave(ctx)
    nvgIntersectScissor(ctx, 0, 0, game.width, game.height)
    nvgGlobalAlpha(ctx, ModalIntro(game))
    -- 首页、功能页共享深海军底与屏边支架；真实车辆仍使用独立正交展台。
    uiFx.surface.Background(ctx, 0, 0, game.width, game.height, uiFx.anim)
    DrawCornerBrackets(ctx, 8, 8, game.width - 16, game.height - 16,
        {C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 100}, 18, 1)

    -- v0.13.59：主菜单左上角「设置」齿轮按钮（几何与命中同源，见 Backend.HitTestMenuGear）。
    -- ⚠️ Scene3DBackend 顶层 local 已满 200（AB-166），几何内联、不加模块级 local。
    do
        local gr = { x = 14, y = 14, w = 40, h = 40 }
        local gGlow, gPress = Backend.GetControlFx(gr, true)
        uiFx.surface.Button(ctx, gr, C.cyanDim, gGlow, uiFx.anim)
        if not DrawIcon(ctx, "gear", gr.x + 6, gr.y + 6 + gPress * 2, 28, 1) then
            -- 缺图回退：程序化齿轮（八齿圆环 + 中心孔）。
            local cx, cy = gr.x + gr.w * 0.5, gr.y + gr.h * 0.5 + gPress * 2
            nvgBeginPath(ctx)
            for i = 0, 7 do
                local a = i * math.pi / 4
                nvgMoveTo(ctx, cx + math.cos(a) * 6, cy + math.sin(a) * 6)
                nvgLineTo(ctx, cx + math.cos(a) * 12, cy + math.sin(a) * 12)
            end
            nvgStrokeColor(ctx, nvgRGBA(C.text[1], C.text[2], C.text[3], 230))
            nvgStrokeWidth(ctx, 4)
            nvgStroke(ctx)
            nvgBeginPath(ctx)
            nvgCircle(ctx, cx, cy, 6)
            nvgStroke(ctx)
        end
    end

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
        -- 回退：字数随标题变化，按可用宽度反推字号，避免 6 字标题溢出画布。
        local n = math.max(1, utf8.len(GAME_SHORT_TITLE) or 1)
        local fbSize = math.min(104, (game.width - 56) / n)
        DrawPixelLogo(ctx, game.width * 0.5, 32, GAME_SHORT_TITLE, fbSize, C.cyan)
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
    uiFx.surface.Button(ctx, cta, C.cyan, glow, uiFx.anim)
    -- Surface统一绘制扫光和交互受光，主CTA只补折角，避免重复叠扫光。
    if glow > 0.01 then
        DrawCornerBrackets(ctx, cta.x + 2, cta.y + 2, cta.w - 4, cta.h - 4,
            {C.text[1], C.text[2], C.text[3], math.floor(glow * 220)}, 10, 1)
    end
    -- v0.13.58：CTA 主标题改用 AI 像素艺术字。⚠️ 青底上**不能用深色 tint**——
    -- 双色母版的「白芯+近黑轮廓」乘深色后两级都塌成黑，整块读成黑疙瘩（实测）。
    -- 但**青色 tint 同样会塌**：金属灰被乘成扁平暗青，立体倒角全丢（实测对比）。
    -- 最终形态（用户要求「直接占满按钮、无黑幕」+ 去掉「选择关卡」小字让主标题更大）：
    -- 去暗色铭牌 + 去副标题，艺术字白 tint 放大铺满按钮；横向再拉伸填满按钮宽度
    -- （用户追加「开始战斗横向也需要拉长」——纵向保持 FitHeight 的 60，横向拉伸见下）。
    if ArtText.Has("startbattle") then
        local s = ArtText.FitHeight("startbattle", 67)
        -- ⚠️ 用户直接提供的成品（带青晕的斜体金属字）——纵向 FitHeight 67 铺满按钮高度，
        -- **横向拉到按钮宽 ~66%**（上限 1.9）。此前误设上限 1.0 把字压成自然宽度（仅占按钮 ~13%），
        -- 用户「谁要你缩小了」——上限必须放开，让字横向铺开。
        local sx = math.min(1.9, ArtText.FitWidth("startbattle", cta.w * 0.66, s))
        ArtText.DrawCentered(ctx, "startbattle", cta, {255, 255, 255}, 0, s, sx)
    else
        DrawPixelText(ctx, game.width * 0.5, ctaY + 22, "开始战斗", 40, C.ink,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
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
    local btnH, gap = 56, 14
    local rowW = 216
    local rowPairW = rowW * 2 + gap
    local rowX = (w - rowPairW) * 0.5
    -- v0.13.60：用户「浪费UI空间且广告太过密集」——窗口下移加高后重排：
    -- 主 CTA「再来一局」置顶整行宽（唯一实心青），两个广告按钮降为**次级描边**并列一行
    -- （不再两块实心绿），回主菜单在底。视觉上只剩一个实心 CTA，广告不再密集。
    local restart = { x = rowX, y = 560, w = rowPairW, h = btnH }
    local revive  = { x = rowX, y = restart.y + btnH + gap, w = rowW, h = btnH }
    local double  = { x = rowX + rowW + gap, y = revive.y, w = rowW, h = btnH }
    local menu    = { x = rowX, y = revive.y + btnH + gap, w = rowPairW, h = 48 }
    return revive, double, restart, menu
end

local function DrawGameOver(ctx, game, presentation)
    nvgSave(ctx)
    nvgIntersectScissor(ctx, 0, MENU_CONTENT_TOP,
        game.width, game.height - MENU_CONTENT_TOP)

    -- v0.13.60：窗口垂直居中于可视区（92..960，高 868）——原 200..720 偏上、下方大片空白。
    -- winH=620 → winY=92+(868-620)/2=216，上下留白各 124，窗口内按钮下方也留白均匀。
    local winY = 216
    local winX, winW, winH = 24, game.width - 48, 620
    DrawWindowShell(ctx, winX, winY, winW, winH, 48)
    DrawModalTechDecor(ctx, winX, winY, winW, winH, game.elapsed)
    DrawPixelText(ctx, winX + 18, winY + 10, "防线失守", 22, C.cyan)
    DrawPixelText(ctx, winX + winW - 16, winY + 14, "本局结束", 15, C.warn,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)

    if game.newRecord then
        DrawIcon(ctx, "record", game.width * 0.5 - 104, winY + 62, 32)
        DrawPixelText(ctx, game.width * 0.5 + 14, winY + 68, "刷新最高分", 20, C.warn,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    else
        DrawPixelText(ctx, game.width * 0.5, winY + 74, "游戏结束", 36, C.text,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
    DrawPixelText(ctx, game.width * 0.5, winY + 118, "敌机突破了底部防线", 18, C.dim,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width * 0.5, winY + 144,
        string.format("分数 %d    最高 %d    第 %d 关 %d/%d 波",
            game.score, game.highScore, game.stage or 1,
            game.stageWave or game.wave, game.wavesPerStage or 10), 18, C.text,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    DrawBluePanel(ctx, 44, winY + 178, game.width - 88, 92, C.rail, C.cyanDim, 6)
    DrawPixelText(ctx, 60, winY + 188, string.format("到达第 %d 关", game.stage or 1), 17, C.text)
    DrawPixelText(ctx, 60, winY + 210, string.format("等级 %d", game.playerLevel), 17, C.text)
    DrawPixelText(ctx, 60, winY + 232, string.format("击碎 %d 块", game.bricksBroken or 0), 17, C.dim)
    DrawPixelText(ctx, game.width - 60, winY + 188, string.format("强化 %d 次", #(game.upgradePicks or {})), 17,
        C.text, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width - 60, winY + 210, string.format("连击 %d", game.clearStreak or 0), 17,
        C.text, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width - 60, winY + 232, string.format("存活 %.0f 秒", game.elapsed or 0), 17,
        C.dim, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    -- v0.11.0 商业化：本局零件产出（结算页最直观的变现锚点）。
    DrawPixelText(ctx, game.width * 0.5, winY + 288,
        string.format("本局获得  零件 ×%d", game.runParts or 0), 19, C.warn,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawIcon(ctx, "parts", game.width * 0.5 - 184, winY + 281, 28)

    local reviveBtn, doubleBtn, restartBtn, menuBtn = GetGameOverButtonLayout(game)
    local canRevive = game.canRevive
    local adBusy = presentation and presentation.adStatus == "loading"

    -- 主 CTA「再来一局」：唯一实心青块，置顶整行宽（视觉焦点）。
    DrawRect(ctx, restartBtn.x, restartBtn.y, restartBtn.w, restartBtn.h, C.cyan, 8)
    DrawPixelText(ctx, restartBtn.x + restartBtn.w * 0.5, restartBtn.y + 16, "再来一局", 22, C.ink,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    -- v0.13.60：两个广告按钮降为**次级描边**（不再两块实心绿）——绿只保留描边+文字，
    -- 底用暗 card，避免「广告密集」的观感。副行字号缩到 14 容纳在 56 高内。
    if canRevive then
        DrawRect(ctx, reviveBtn.x, reviveBtn.y, reviveBtn.w, reviveBtn.h, C.card, 8)
        DrawStroke(ctx, reviveBtn.x, reviveBtn.y, reviveBtn.w, reviveBtn.h, C.ad, 8, 1.6)
        if adBusy then
            DrawPixelText(ctx, reviveBtn.x + reviveBtn.w * 0.5, reviveBtn.y + 8, "广告加载中…", 16, C.dim,
                NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        else
            DrawPixelText(ctx, reviveBtn.x + reviveBtn.w * 0.5, reviveBtn.y + 8, "看广告复活", 18, C.ad,
                NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            DrawPixelText(ctx, reviveBtn.x + reviveBtn.w * 0.5, reviveBtn.y + 32, "防线回 50 血 · 本局一次", 14, C.dim,
                NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        end
    else
        DrawRect(ctx, reviveBtn.x, reviveBtn.y, reviveBtn.w, reviveBtn.h, C.widget, 8)
        DrawStroke(ctx, reviveBtn.x, reviveBtn.y, reviveBtn.w, reviveBtn.h, C.cyanDim, 8, 1)
        DrawPixelText(ctx, reviveBtn.x + reviveBtn.w * 0.5, reviveBtn.y + 16, "本局已复活", 17, C.dim,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end

    -- 看广告双倍零件：次级描边；已翻倍后置灰，不可重复领取。
    if game.canDoubleSettle then
        DrawRect(ctx, doubleBtn.x, doubleBtn.y, doubleBtn.w, doubleBtn.h, C.card, 8)
        DrawStroke(ctx, doubleBtn.x, doubleBtn.y, doubleBtn.w, doubleBtn.h, C.ad, 8, 1.6)
        DrawIcon(ctx, "double", doubleBtn.x + 9, doubleBtn.y + 14, 28)
        DrawPixelText(ctx, doubleBtn.x + doubleBtn.w * 0.5, doubleBtn.y + 8, "看广告 双倍零件", 17, C.ad,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        DrawPixelText(ctx, doubleBtn.x + doubleBtn.w * 0.5, doubleBtn.y + 32,
            string.format("再得 %d 零件", game.runParts or 0), 14, C.dim,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    else
        DrawRect(ctx, doubleBtn.x, doubleBtn.y, doubleBtn.w, doubleBtn.h, C.widget, 8)
        DrawStroke(ctx, doubleBtn.x, doubleBtn.y, doubleBtn.w, doubleBtn.h, C.cyanDim, 8, 1)
        DrawPixelText(ctx, doubleBtn.x + doubleBtn.w * 0.5, doubleBtn.y + 16,
            game.partsDoubled and "零件已翻倍" or "零件已入库", 17, C.dim,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end

    -- v0.12.5：回主菜单（次级出口：widget 底 + 青 dim 描边，不与主 CTA 抢焦点）
    DrawRect(ctx, menuBtn.x, menuBtn.y, menuBtn.w, menuBtn.h, C.widget, 8)
    DrawStroke(ctx, menuBtn.x, menuBtn.y, menuBtn.w, menuBtn.h, C.cyanDim, 8, 1.4)
    DrawIcon(ctx, "home", menuBtn.x + menuBtn.w * 0.5 - 58, menuBtn.y + 12, 24, 1)
    DrawPixelText(ctx, menuBtn.x + menuBtn.w * 0.5 + 14, menuBtn.y + 12, "回主菜单", 18, C.text,
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
    local btnH, gap = 56, 14
    local rowW = 216
    local rowPairW = rowW * 2 + gap
    local rowX = (w - rowPairW) * 0.5
    -- v0.13.60：主 CTA「下一关」置顶整行宽（唯一实心青，视觉焦点）；
    -- 再战本关 + 回主菜单并列一行（次级）。与失败页同语言。
    local nextBtn = { x = rowX, y = 560, w = rowPairW, h = btnH }
    local retry = { x = rowX, y = nextBtn.y + btnH + gap, w = rowW, h = btnH }
    local menu = { x = rowX + rowW + gap, y = retry.y, w = rowW, h = btnH }
    return retry, nextBtn, menu
end

local function DrawStageWin(ctx, game, presentation)
    local result = game.stageResult or {}
    local stars = math.min(3, math.max(1, math.floor(result.stars or 1)))
    nvgSave(ctx)
    nvgIntersectScissor(ctx, 0, MENU_CONTENT_TOP,
        game.width, game.height - MENU_CONTENT_TOP)
    DrawModalBackdrop(ctx, 0, MENU_CONTENT_TOP, game.width, game.height - MENU_CONTENT_TOP)

    -- v0.13.60：窗口垂直居中于可视区（92..960，高 868）——原 200..668 偏上、下方大片空白。
    local winY = 216
    local winX, winW, winH = 24, game.width - 48, 620
    DrawWindowShell(ctx, winX, winY, winW, winH, 48)
    DrawModalTechDecor(ctx, winX, winY, winW, winH, game.elapsed)
    DrawPixelText(ctx, winX + 18, winY + 10, "防线守住", 22, C.cyan)
    DrawPixelText(ctx, winX + winW - 16, winY + 14,
        string.format("第 %d 关告捷", result.stage or game.stage or 1), 15, C.warn,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)

    DrawPixelText(ctx, game.width * 0.5, winY + 78, result.rating or "通关", 34, C.text,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawStarRow(ctx, game.width * 0.5, winY + 128, stars, 44, 20)

    DrawPixelText(ctx, game.width * 0.5, winY + 208,
        string.format("剩余防线 %d / %d", math.floor(game.baseHp or 0), game.maxBaseHp or 100),
        18, C.dim, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawPixelText(ctx, game.width * 0.5, winY + 238,
        string.format("本关奖励  +%d 分   +%d 零件", math.floor(result.bonusScore or 0),
            math.floor(result.bonusParts or 0)), 17, C.warn, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    if game.newRecord then
        DrawPixelText(ctx, game.width * 0.5, winY + 268, "刷新最高分", 17, C.warn,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end

    local retryBtn, nextBtn, menuBtn = GetStageWinButtonLayout(game)
    -- 主 CTA「下一关」：唯一实心青块，置顶整行宽；通关到最后一关时置灰。
    if game.stageHasNext then
        DrawRect(ctx, nextBtn.x, nextBtn.y, nextBtn.w, nextBtn.h, C.cyan, 8)
        DrawPixelText(ctx, nextBtn.x + nextBtn.w * 0.5, nextBtn.y + 16, "下一关", 22, C.ink,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    else
        DrawRect(ctx, nextBtn.x, nextBtn.y, nextBtn.w, nextBtn.h, C.widget, 8)
        DrawStroke(ctx, nextBtn.x, nextBtn.y, nextBtn.w, nextBtn.h, C.cyanDim, 8, 1)
        DrawPixelText(ctx, nextBtn.x + nextBtn.w * 0.5, nextBtn.y + 16, "已通关全部", 19, C.dim,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
    -- 再战本关 + 回主菜单（并列次级）。
    DrawRect(ctx, retryBtn.x, retryBtn.y, retryBtn.w, retryBtn.h, C.card, 8)
    DrawStroke(ctx, retryBtn.x, retryBtn.y, retryBtn.w, retryBtn.h, C.cyanDim, 8, 1.4)
    DrawPixelText(ctx, retryBtn.x + retryBtn.w * 0.5, retryBtn.y + 16, "再战本关", 20, C.text,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    DrawRect(ctx, menuBtn.x, menuBtn.y, menuBtn.w, menuBtn.h, C.widget, 8)
    DrawStroke(ctx, menuBtn.x, menuBtn.y, menuBtn.w, menuBtn.h, C.cyanDim, 8, 1.4)
    DrawIcon(ctx, "home", menuBtn.x + menuBtn.w * 0.5 - 58, menuBtn.y + 16, 24, 1)
    DrawPixelText(ctx, menuBtn.x + menuBtn.w * 0.5 + 14, menuBtn.y + 16, "回主菜单", 18, C.text,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    local toast = presentation and presentation.adToast
    if toast and toast ~= "" then
        DrawPixelText(ctx, game.width * 0.5, menuBtn.y + menuBtn.h + 18, toast, 15, C.warn,
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
    -- v0.13.54：升级卡补「无关紧要的纹路」——双层网格 + 半调 + 内圈折角 + 底边刻度。
    DrawMicroGrid(ctx, x + 5, y + 5, cardW - 10, cardH - 10, 14, 11)
    DrawMicroGrid(ctx, x + 5, y + 5, cardW - 10, cardH - 10, 38, 7)
    DrawHalftone(ctx, x + 6, y + 6, cardW - 12, cardH - 12, 9, 12)
    DrawCornerBrackets(ctx, x + 9, y + 9, cardW - 18, cardH - 18,
        {accent[1], accent[2], accent[3], 96}, 7, 1)
    for i = 0, 14 do
        local long = (i % 4 == 0)
        DrawRect(ctx, x + 12 + i * (cardW - 24) / 14, y + cardH - 9, 1, long and 4 or 2,
            {C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 84}, 0)
    end
    DrawDashLine(ctx, x + 12, y + cardH - 14, x + cardW * 0.42, y + cardH - 14,
        {C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 74}, 1, 5, 4)
    DrawCrossMark(ctx, x + 13, y + 13, 3, {C.ghost[1], C.ghost[2], C.ghost[3], 92})
    DrawCrossMark(ctx, x + cardW - 13, y + 13, 3, {C.ghost[1], C.ghost[2], C.ghost[3], 92})

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
    -- 播放三角放在左半区居中，文字整体右移让出三角（旧版文字 x 加了 14 又居中，
    -- 结果「继续战斗」压住三角尖端）。
    local triCx = layout.resume.x + layout.resume.w * 0.30
    local triCy = layout.resume.y + layout.resume.h * 0.5
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, triCx - 8, triCy - 10)
    nvgLineTo(ctx, triCx - 8, triCy + 10)
    nvgLineTo(ctx, triCx + 8, triCy)
    nvgClosePath(ctx)
    nvgFillColor(ctx, nvgRGBA(C.ink[1], C.ink[2], C.ink[3], 255))
    nvgFill(ctx)
    -- v0.13.58：继续战斗改用艺术字。同 CTA——青/深 tint 都会把金属灰压塌，
    -- 且用户要求「同款问题一并修」：**去掉暗色铭牌**，白 tint 放大铺满按钮高度。
    if ArtText.Has("resume") then
        local s, aw = ArtText.FitHeight("resume", 34)
        local pcx = layout.resume.x + layout.resume.w * 0.60
        ArtText.DrawCentered(ctx, "resume",
            { x = pcx - aw * 0.5, y = layout.resume.y, w = aw, h = layout.resume.h }, {255, 255, 255}, 0, s)
    else
        DrawPixelText(ctx, layout.resume.x + layout.resume.w * 0.60, layout.resume.y + 13,
            "继续战斗", 19, C.ink, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
    local menuGlow, menuPress = Backend.GetControlFx(layout.menu, true)
    nvgSave(ctx)
    nvgTranslate(ctx, 0, menuPress * 2)
    DrawMachinedPanel(ctx, layout.menu.x, layout.menu.y, layout.menu.w, layout.menu.h,
        C.widget, C.cyanDim, 8, false)
    if menuGlow > 0.01 then
        DrawStroke(ctx, layout.menu.x, layout.menu.y, layout.menu.w, layout.menu.h,
            {C.cyan[1], C.cyan[2], C.cyan[3], math.floor(menuGlow * 200)}, 8, 1.5)
    end
    DrawIcon(ctx, "home", layout.menu.x + 40, layout.menu.y + 14, 22, 1)
    -- v0.13.58：返回主菜单改用艺术字（深底亮字 → tint C.text）；排在 home 图标**右侧**，
    -- 用剩余宽度，无图回退 zpix。
    if ArtText.Has("menu") then
        local aw, ah = ArtText.Width("menu"), ArtText.Height("menu")
        local mx = layout.menu.x + 74 + aw * 0.5
        ArtText.Draw(ctx, "menu", mx, layout.menu.y + (layout.menu.h - ah) * 0.5, C.text)
    else
        DrawPixelText(ctx, layout.menu.x + layout.menu.w * 0.5 + 14, layout.menu.y + 12,
            "返回主菜单", 17, C.text, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
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
            game.stageSubtitle or "十波防线 · 三精英一首领", 16, C.text,
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
            -- 先固定世界层边界，再震动图形；避免冲击裁剪随位移漏入letterbox。
            nvgIntersectScissor(vg_, 0, HUD_HEIGHT, DESIGN_W, BOTTOM_DOCK_Y - HUD_HEIGHT)
            if presentation.screenShake > 0 then
                local amplitude = presentation.screenShake * 13
                nvgTranslate(vg_, math.sin(game.elapsed * 91) * amplitude,
                    math.cos(game.elapsed * 73) * amplitude * 0.65)
            end
            DrawBaseImpactFeedback(vg_, game, presentation)
            DrawShockRings(vg_, game, presentation)
            uiFx.impact.DrawHits(vg_, game, presentation, ProjectGamePoint)
            uiFx.impact.DrawSparks(vg_, presentation, ProjectGamePoint)
            uiFx.impact.Draw(vg_, presentation, ProjectGamePoint)
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
            uiFx.battle.DrawEnchant(vg_, game, Backend.GetEnchantRect())
            DrawPullHint(vg_, game)
        end) then
            RunOverlayStage("dock-fallback", function() DrawMinimalDockFallback(game) end)
        end
        RunOverlayStage("damage-vignette", function() DrawDamageVignette(vg_, game, presentation) end)
        -- v0.13.17：Boss 在场时画阶段条（DrawBossPhaseBar 此前定义了却从未调用）。
        RunOverlayStage("boss-phase", function()
            local boss = FindBoss(game)
            if boss then DrawBossPhaseBar(vg_, game, boss, presentation) end
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

    local currentWindow = (game.state == "gameover" or game.state == "levelup"
        or game.state == "paused" or game.state == "stagewin")
        and StageTransition.WindowVisible(game)
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

    -- v0.13.57：关卡结束 → 结算窗口的过渡动画。画在结算窗之上（过渡期间结算窗
    -- 尚未弹出），星级越高越华丽；结束后自身淡出，玩家可点击跳过。
    -- v0.13.60：失败（gameover）也走过渡——「防线崩溃」动态漫（4.0s），与胜利同门控。
    if (game.state == "stagewin" or game.state == "gameover")
        and StageTransition.IsActive(game) then
        RunOverlayStage("stage-transition", function()
            ApplyOverlayDesignTransform()
            nvgGlobalAlpha(vg_, 1.0)
            StageTransition.Draw(vg_, game)
        end)
    end

    -- 击毁可能在同帧触发升级/胜利；只在窗口空白带画短回声，不穿过正文或按钮。
    -- 不放开全部旧 world-fx 的模态门控，也不把回声位置当成真实伤害范围。
    if game.state == "levelup" or game.state == "stagewin" then
        RunOverlayStage("combat-impact-echo", function()
            ApplyOverlayDesignTransform()
            uiFx.impact.Draw(vg_, presentation, ProjectGamePoint,
                game.state == "levelup" and 270 or 155)
        end)
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
    if uiFx.battle then uiFx.battle.Shutdown() end
    if scene_ then
        MetaUI.Shutdown()
        if uiFx.surface then uiFx.surface.Shutdown() end
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
    uiFx.surface = require "ui.PremiumSurface"
    uiFx.impact = require "ui.CombatImpact"
    -- 音频总控：8bit 太空公路风格 BGM + 领域事件音效（可选资源，缺文件静默跳过）。
    uiFx.audio = require "AudioDirector"
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
        stage = uiFx.surface.Stage,
        button = function(ctx, rect, color, glow)
            uiFx.surface.Button(ctx, rect, color, glow, uiFx.anim)
        end,
        fit = uiFx.surface.FitText,
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
    uiFx.surface.Init(vg_, C)
    -- 独立组件子树共享宿主画布，不新增主块local，不接管UI全局root。
    uiFx.battle = require "ui.BattleHUD"
    uiFx.battle.Init(vg_, { C = C, rect = DrawRect, stroke = DrawStroke,
        icon = DrawIcon, anim = Backend.GetAnimPhase, controlFx = Backend.GetControlFx,
        slotTypes = SLOT_TYPES, slotNames = SLOT_NAMES, slotColors = SLOT_COLORS })

    -- 手势图是可选资源：缺失时只跳过提示，绝不纳入初始化成功条件。
    handImage_ = nvgCreateImage(vg_, HAND_IMAGE_PATH, 0)
    -- ⚠️ 必须在 vg_ 创建之后加载；vg_ 为 nil 时所有图标都会静默失败。
    LoadIcons()
    LoadLogoTitles()
    -- 艺术字/数字贴图**必须在这里预加载一次**：Has()/Width()/Height() 不触发加载，
    -- 只有 Draw() 才加载。多数调用点是 `if Has() then Draw() else zpix`，若首次绘制前
    -- images_ 仍为空则 Has() 恒 false → 永远走 zpix 回退（表现为「有时艺术字、有时文字」
    -- 的间歇性错误，只有先打开过选关屏触发 Draw("stage") 后才会「恢复」）。
    ArtText.Ensure(vg_)
    DigitFont.Ensure(vg_)
    if not handImage_ or handImage_ <= 0 then
        handImage_ = -1
        print("[Scene3DBackend] hand hint image unavailable: " .. HAND_IMAGE_PATH)
    end

    if not Renderer3D.Init(scene_, voxelWorld_) then
        if Renderer3D._unavailable then
            -- 3D 层缺席不阻断启动：菜单/HUD/所有 NanoVG UI 仍可用，
            -- 比「整屏黑屏」对玩家好得多（见文件头 pcall 降级说明）。
            print("[Scene3DBackend] WARN: 3D renderer unavailable, starting in 2D-only mode")
        else
            print("[Scene3DBackend] ERROR: Renderer3D initialization failed")
            CleanupFailedInit()
            return false
        end
    end
    -- 音频总控绑定场景（音源节点挂在 3D 场景下；2D 玩法用非定位 SoundSource）。
    pcall(function() uiFx.audio.Init(scene_) end)
    -- 传函数值而非函数名：不受「处理器定义在哪个文件」影响。
    SubscribeToEvent(vg_, "NanoVGRender", HandleBackendNanoVGRender)
    print("[Scene3DBackend] initialized: 9:16 locked viewport, dark-tech HUD, orthographic 46-degree aircraft camera")
    return true
end

function Backend.Shutdown()
    if uiFx.audio then uiFx.audio.Shutdown() end
    if uiFx.battle then uiFx.battle.Shutdown() end
    MetaUI.Shutdown()
    if uiFx.surface then uiFx.surface.Shutdown() end
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

-- 音频总控每帧推进：消费同一份领域事件（与 Presentation 共用），按状态切换 BGM。
-- 编排层在 Presentation.Update 之后调用，事件数组原样传入（只读消费）。
function Backend.TickAudio(dt, gameSnapshot, events)
    if uiFx.audio then uiFx.audio.Update(dt, gameSnapshot, events) end
end

-- 供 UI 交互直接调用的音效入口（按钮点击/确认）。
---@param kind string|nil
function Backend.PlayUiSfx(kind)
    if uiFx.audio then uiFx.audio.PlayUi(kind) end
end

-- 设置页开关：音乐/音效开与关（挂 Backend 表，零新增顶层 local，AB-265/268）。
---@param enabled boolean
function Backend.SetMusicEnabled(enabled)
    if uiFx.audio then uiFx.audio.SetMusicEnabled(enabled) end
end

---@param enabled boolean
function Backend.SetSfxEnabled(enabled)
    if uiFx.audio then uiFx.audio.SetSfxEnabled(enabled) end
end

---@return boolean, boolean
function Backend.AudioEnabled()
    if uiFx.audio then return uiFx.audio.IsMusicEnabled(), uiFx.audio.IsSfxEnabled() end
    return true, true
end

-- 游戏快照在 Update 结束后已经稳定；在本帧 3D 绘制之前同步场景与体素。
-- NanoVGRender 晚于 3D Viewport，不能在其中才 RebuildGeometry，否则必然看到旧网格。
function Backend.UpdateScene(gameSnapshot, presentationSnapshot, metaState)
    UpdateUiState(gameSnapshot, metaState)
    -- 共享时间只驱动循环动画；各控件的进入/退出与按压分别缓动。
    local dtAnim = math.min(0.05, math.max(0, gameSnapshot.elapsed - uiFx.anim))
    uiFx.anim = gameSnapshot.elapsed
    if uiFx.battle then uiFx.battle.Update(gameSnapshot, dtAnim) end
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
    Renderer3D.Render(gameSnapshot, presentationSnapshot,
        metaState and metaState.selectedSkin, metaState and metaState.selectedTrail)
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
    -- 过渡动画期间结算窗尚未显示，任何按钮都不可点（点击由编排层用于「跳过」）。
    if not StageTransition.WindowVisible(game) then return nil end
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

-- v0.13.59：主菜单左上角「设置」齿轮按钮命中（几何与 DrawMenu 内联块同源）。
function Backend.HitTestMenuGear(uiX, uiY, game)
    return (uiX >= 14 and uiX <= 54 and uiY >= 14 and uiY <= 54)
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

-- v0.13.58：左上角附魔卡命中（与 DrawEnchantCard 共用 GetEnchantRect）。
---@return boolean
function Backend.HitTestEnchant(uiX, uiY, game)
    if not (game and game.enchantCard) then return false end
    local r = Backend.GetEnchantRect()
    return uiX >= r.x and uiX <= r.x + r.w and uiY >= r.y and uiY <= r.y + r.h
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
