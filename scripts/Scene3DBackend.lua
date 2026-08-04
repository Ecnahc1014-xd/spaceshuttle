-- Scene3DBackend.lua
-- 3D 场景后端：固定 540x960 设计坐标，使用正交相机呈现体素敌人与运输车。

local Renderer3D = require "Renderer3D"

local Backend = {}

local DESIGN_W = 540
local DESIGN_H = 960

local scene_ = nil
local cameraNode_ = nil
local camera_ = nil
local viewport_ = nil
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
end

ReleaseScene = function()
    if scene_ then
        scene_:Dispose()
        scene_ = nil
    end
    cameraNode_ = nil
    camera_ = nil
    viewport_ = nil
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

local function CreateBackdrop()
    local node = scene_:CreateChild("Backdrop")
    node.position = Vector3(0, 0, 1.4)
    node.scale = Vector3(11.2, 19.5, 0.2)
    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    model:SetMaterial(CreateMaterial({0.035, 0.045, 0.10}, 0.95))
    model.castShadows = false
end

local function CreateDangerBand()
    local node = scene_:CreateChild("DangerBand")
    node.position = Vector3(0, -8.0, 0.9)
    node.scale = Vector3(11.0, 0.06, 0.06)
    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    model:SetMaterial(CreateMaterial({0.85, 0.08, 0.08}, 0.45))
    model.castShadows = false
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

local function DrawTruckLegend(ctx, game)
    local labels = {
        {"分裂运输车", 116, 910, 255, 190, 80},
        {"冰冻运输车", 226, 910, 100, 210, 255},
        {"加速运输车", 336, 910, 255, 110, 70},
        {"巨型运输车", 446, 910, 205, 145, 255},
    }
    nvgFontFace(ctx, "zpix")
    nvgFontSize(ctx, 11)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    for _, label in ipairs(labels) do
        nvgFillColor(ctx, nvgRGBA(label[4], label[5], label[6], 220))
        nvgText(ctx, label[2], label[3], label[1], nil)
    end

    if game.activeBall then
        nvgFontSize(ctx, 13)
        nvgFillColor(ctx, nvgRGBA(255, 245, 190, 240))
        nvgText(ctx, game.width * 0.5, 875,
            "当前发射：" .. tostring(game.activeBall.ballType), nil)
    end
end

local function DrawMenu(ctx, game)
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, game.width, game.height)
    nvgFillColor(ctx, nvgRGBA(8, 10, 24, 220))
    nvgFill(ctx)

    nvgFontFace(ctx, "zpix")
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 48)
    nvgFillColor(ctx, nvgRGBA(255, 110, 40, 255))
    nvgText(ctx, game.width * 0.5, 185, "燃烧的蔬菜", nil)
    nvgFontSize(ctx, 23)
    nvgFillColor(ctx, nvgRGBA(255, 220, 140, 255))
    nvgText(ctx, game.width * 0.5, 235, "体素敌人与四辆运输车", nil)

    nvgFontSize(ctx, 16)
    nvgFillColor(ctx, nvgRGBA(190, 205, 230, 230))
    nvgText(ctx, game.width * 0.5, 355, "敌方体素方块受击后分散旋转并缩小", nil)
    nvgText(ctx, game.width * 0.5, 385, "四种弹珠由对应运输车装载并发射", nil)

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
    DrawHud(vg_, game)
    DrawTruckLegend(vg_, game)
    if game.state == "menu" then
        DrawMenu(vg_, game)
    elseif game.state == "gameover" then
        DrawGameOver(vg_, game)
    end
    nvgRestore(vg_)
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
    local lightGroup = scene_:CreateChild("LightGroup")
    lightGroup:LoadXML(lightGroupFile:GetRoot())

    CreateBackdrop()
    CreateDangerBand()

    cameraNode_ = scene_:CreateChild("Camera")
    cameraNode_.position = Vector3(0, 0, -25)
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
    print("[Scene3DBackend] initialized with voxel field and four trucks")
    return true
end

local function CleanupFailedInit()
    if vg_ then
        nvgDelete(vg_)
        vg_ = nil
    end
    renderer:SetViewport(0, nil)
    if scene_ then
        scene_:Dispose()
        scene_ = nil
    end
    cameraNode_ = nil
    camera_ = nil
    viewport_ = nil
end

local function ReleaseScene()
    if scene_ then
        scene_:Dispose()
        scene_ = nil
    end
    cameraNode_ = nil
    camera_ = nil
    viewport_ = nil
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
    Renderer3D.Render(gameSnapshot, presentationSnapshot)
    RenderOverlay(gameSnapshot, presentationSnapshot)
end

function Backend.GetDesignSize()
    return DESIGN_W, DESIGN_H
end

return Backend
