-- StageBadgeShowcase.lua
-- 选关界面的「关卡芯片」3D 展示：独立 Scene + 透视相机 + 三灯，渲染到 RT 后由 NanoVG 贴图。
-- 与 ui/SupplyPodShowcase 同一套 RT 生命周期；只服务选关面板展示，不接玩法。
local StageBadgeGeometry = require "StageBadgeGeometry"

local StageBadgeShowcase = {}

local MIN_W, MAX_W = 256, 1024
-- 水平镜像已改在几何层修正（StageBadgeGeometry 的字形列反序）。
-- 原因：nvgImagePattern 的 paint 矩阵不吃外层 nvgScale，贴图层翻转无效。

local SIZE_STEP = 64
local FRAME_INTERVAL = 1 / 30

-- 与游戏语义一致：有星=金（warn），无星=青（主操作）
local TIER_GOLD = { 0.952, 0.655, 0.243 }
local TIER_STEEL = { 0.886, 0.894, 0.910 }

---@class StageBadgeState
---@field scene Scene|nil
---@field node Node|nil
---@field geometry CustomGeometry|nil
---@field cameraNode Node|nil
---@field camera Camera|nil
---@field texture Texture2D|nil
---@field surface RenderSurface|nil
---@field viewport Viewport|nil
---@field materials Material[]
---@field bodyMaterial Material|nil
---@field panelMaterial Material|nil
---@field digitMaterial Material|nil
---@field starMaterial Material|nil
---@field glowMaterial Material|nil
---@field outlineMaterial Material|nil
---@field dirty boolean
---@field rimLight Light|nil
---@field image integer
---@field imageContext NVGContextWrapper|nil
---@field ready boolean
---@field failed boolean
---@field error string
---@field visible boolean
---@field timer number
---@field phase number
---@field stage integer
---@field stars integer
---@field gold boolean
---@field width integer
---@field height integer
---@field flipY boolean
---@field updates integer
---@field builds integer
---@field switchAt number|nil 上次换关时刻（播放换关演出）
---@field switchDur number
---@field glowBase number[]|nil
local state = {
    scene = nil, node = nil, geometry = nil, cameraNode = nil, camera = nil,
    texture = nil, surface = nil, viewport = nil, materials = {},
    bodyMaterial = nil, panelMaterial = nil, digitMaterial = nil,
    starMaterial = nil, glowMaterial = nil, outlineMaterial = nil, dirty = true, rimLight = nil,
    image = 0, imageContext = nil,
    ready = false, failed = false, error = "", visible = false,
    timer = 0, phase = 0, stage = -1, stars = -1, gold = false,
    width = 0, height = 0, flipY = false, updates = 0, builds = 0,
    switchAt = nil, switchDur = 0.9,
} --[[@as StageBadgeState]]

local function ReleaseImage()
    if state.image > 0 and state.imageContext then
        pcall(nvgDeleteVideo, state.imageContext, state.image)
    end
    state.image, state.imageContext = 0, nil
end

---@param technique Technique
---@param rgb number[]
---@param metallic number
---@param roughness number
---@param emissive number[]|nil
---@return Material
local function CreateMaterial(technique, rgb, metallic, roughness, emissive)
    local material = Material:new()
    state.materials[#state.materials + 1] = material
    material:SetTechnique(0, technique)
    material:SetShaderParameter("MatDiffColor", Variant(Color(rgb[1], rgb[2], rgb[3], 1)))
    material:SetShaderParameter("Metallic", Variant(metallic))
    material:SetShaderParameter("Roughness", Variant(roughness))
    if emissive then
        material:SetShaderParameter("MatEmissiveColor",
            Variant(Color(emissive[1], emissive[2], emissive[3], 1)))
    end
    return material
end

---@param width integer
---@param height integer
---@return boolean
local function ResizeTarget(width, height)
    if state.texture and width <= state.width and height <= state.height then return true end
    ---@type Texture2D|nil
    local texture = nil
    local ok, reason = pcall(function()
        texture = Texture2D:new()
        texture:SetNumLevels(1)
        assert(texture:SetSize(width, height, Graphics:GetRGBAFormat(), TEXTURE_RENDERTARGET),
            "RT allocation failed")
        texture:SetFilterMode(FILTER_BILINEAR)
        local surface = assert(texture:GetRenderSurface(), "RT surface unavailable")
        surface:SetViewport(0, state.viewport)
        surface:SetUpdateMode(SURFACE_MANUALUPDATE)
    end)
    if not ok then
        if texture then pcall(function() texture:Dispose() end) end
        if not state.texture then error(reason) end
        return false
    end
    ReleaseImage()
    if state.surface then state.surface:SetNumViewports(0) end
    if state.texture then state.texture:Dispose() end
    state.texture, state.surface = texture, texture:GetRenderSurface()
    state.width, state.height = width, height
    return true
end

local function ReleaseResources()
    ReleaseImage()
    if state.surface then pcall(function() state.surface:SetNumViewports(0) end) end
    state.surface, state.viewport = nil, nil
    if state.texture then pcall(function() state.texture:Dispose() end) end
    state.texture = nil
    if state.scene then pcall(function() state.scene:Dispose() end) end
    state.scene, state.node, state.geometry = nil, nil, nil
    state.cameraNode, state.camera, state.rimLight = nil, nil, nil
    for _, material in ipairs(state.materials) do pcall(function() material:Dispose() end) end
    state.materials = {}
    state.bodyMaterial, state.panelMaterial, state.digitMaterial = nil, nil, nil
    state.starMaterial, state.glowMaterial, state.outlineMaterial = nil, nil, nil
    state.ready = false
end

---@param reason string
---@return boolean
local function Fail(reason)
    if not state.failed then
        print("[StageBadgeShowcase] unavailable: " .. tostring(reason))
    end
    ReleaseResources()
    state.failed, state.error = true, tostring(reason)
    return false
end

---@param stage integer
---@param stars integer
local function BuildBadge(stage, stars)
    if not state.geometry then return end
    local gold = (stars or 0) > 0
    local buffers = StageBadgeGeometry.Build(stage, stars, gold)
    StageBadgeGeometry.Apply(state.geometry, buffers, {
        state.bodyMaterial, state.panelMaterial, state.digitMaterial,
        state.starMaterial, state.glowMaterial, state.outlineMaterial, state.panelMaterial,
    })
    state.stage, state.stars, state.gold = stage, stars, gold

    -- 配色：有星=金，无星=银白主操作色
    local accent = gold and TIER_GOLD or TIER_STEEL
    local dim = { accent[1] * 0.42, accent[2] * 0.42, accent[3] * 0.46 }
    state.glowBase = accent
    if state.glowMaterial then
        state.glowMaterial:SetShaderParameter("MatDiffColor",
            Variant(Color(accent[1], accent[2], accent[3], 1)))
        state.glowMaterial:SetShaderParameter("MatEmissiveColor",
            Variant(Color(accent[1] * 1.4, accent[2] * 1.4, accent[3] * 1.4, 1)))
    end
    if state.starMaterial then
        state.starMaterial:SetShaderParameter("MatDiffColor",
            Variant(Color(accent[1], accent[2], accent[3], 1)))
        state.starMaterial:SetShaderParameter("MatEmissiveColor",
            Variant(Color(accent[1] * 0.85, accent[2] * 0.85, accent[3] * 0.85, 1)))
    end
    if state.panelMaterial then
        state.panelMaterial:SetShaderParameter("MatDiffColor",
            Variant(Color(dim[1], dim[2], dim[3], 1)))
    end
    if state.rimLight then
        state.rimLight.color = Color(accent[1], accent[2], accent[3])
    end
    state.dirty = true
    state.builds = state.builds + 1
    print(string.format("[StageBadgeShowcase] badge stage=%d stars=%d gold=%s vertices=%d",
        stage, stars, tostring(gold), state.geometry:GetNumVertices(0)))
end

---@return boolean
function StageBadgeShowcase.Init()
    if state.ready then return true end
    if state.failed then return false end
    local ok, reason = pcall(function()
        local opaque = assert(cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"),
            "PBRNoTexture missing")
        local api = graphics:GetApiName()
        -- D3D11 实测不需要翻转（翻了会把星翻到顶部）；GLES/OpenGL 需要。
        state.flipY = (api == "GLES" or api == "OpenGL")

        state.bodyMaterial = CreateMaterial(opaque, { 0.185, 0.220, 0.275 }, 0.26, 0.42)
        state.panelMaterial = CreateMaterial(opaque, { 0.440, 0.470, 0.520 }, 0.20, 0.44)
        state.digitMaterial = CreateMaterial(opaque, { 0.905, 0.915, 0.935 }, 0.15, 0.35)
        state.starMaterial = CreateMaterial(opaque, TIER_STEEL, 0.12, 0.34,
            { TIER_STEEL[1] * 0.5, TIER_STEEL[2] * 0.5, TIER_STEEL[3] * 0.5 })
        state.glowMaterial = CreateMaterial(opaque, TIER_STEEL, 0.10, 0.30,
            { TIER_STEEL[1] * 1.4, TIER_STEEL[2] * 1.4, TIER_STEEL[3] * 1.4 })
        state.outlineMaterial = CreateMaterial(opaque, { 0.022, 0.026, 0.034 }, 0.0, 0.90,
            { 0.010, 0.012, 0.016 })

        local scene = Scene()
        state.scene = scene
        assert(scene:CreateComponent("Octree", LOCAL), "Octree unavailable")

        local zoneNode = scene:CreateChild("BadgeZone", LOCAL)
        local zone = assert(zoneNode:CreateComponent("Zone", LOCAL), "Zone unavailable")
        zone.boundingBox = BoundingBox(-1000, 1000)
        zone.ambientSource = AMBIENT_COLOR
        zone.ambientColor = Color(0.50, 0.54, 0.62)
        zone.ambientIntensity = 1.0
        zone.fogColor = Color(0, 0, 0, 0)
        zone.fogDensity = 0
        zone.heightFog = false
        zone.volumetricFogEnabled = false
        zone.autoExposureEnabled = false
        zone.fxaaEnabled = false
        zone.vignetteEnabled = false
        zone.ssrEnabled = false
        zone.ssgiEnabled = false
        zone.motionBlurEnabled = false
        zone.bloomPlusEnabled = false
        zone.bloomWeight = 0
        zone.tonemapMode = TONEMAP_MODE_NONE

        local cameraNode = scene:CreateChild("BadgeCamera", LOCAL)
        cameraNode.position = Vector3(0, 0.02, 3.55)
        cameraNode:LookAt(Vector3(0, 0, 0))
        local camera = assert(cameraNode:CreateComponent("Camera", LOCAL), "Camera unavailable")
        camera.fov = 34
        camera.nearClip = 0.1
        camera.farClip = 30
        camera.autoAspectRatio = false
        camera.aspectRatio = 1
        state.cameraNode, state.camera = cameraNode, camera

        local keyNode = scene:CreateChild("BadgeKey", LOCAL)
        keyNode.direction = Vector3(-0.45, -0.70, -0.55):Normalized()
        local key = assert(keyNode:CreateComponent("Light", LOCAL), "Light unavailable")
        key.lightType = LIGHT_DIRECTIONAL
        key.color = Color(1.0, 0.975, 0.93)
        key.brightness = 2.05
        key.castShadows = false

        local rimNode = scene:CreateChild("BadgeRim", LOCAL)
        rimNode.direction = Vector3(0.62, -0.10, 0.72):Normalized()
        local rim = assert(rimNode:CreateComponent("Light", LOCAL), "Light unavailable")
        rim.lightType = LIGHT_DIRECTIONAL
        rim.color = Color(TIER_STEEL[1], TIER_STEEL[2], TIER_STEEL[3])
        rim.brightness = 1.15
        rim.castShadows = false
        state.rimLight = rim

        local fillNode = scene:CreateChild("BadgeFill", LOCAL)
        fillNode.direction = Vector3(0.15, 0.85, 0.45):Normalized()
        local fill = assert(fillNode:CreateComponent("Light", LOCAL), "Light unavailable")
        fill.lightType = LIGHT_DIRECTIONAL
        fill.color = Color(0.62, 0.70, 0.85)
        fill.brightness = 0.40
        fill.castShadows = false

        local node = scene:CreateChild("BadgeNode", LOCAL)
        local geometry = assert(node:CreateComponent("CustomGeometry", LOCAL), "CustomGeometry unavailable")
        geometry.castShadows = false
        state.node, state.geometry = node, geometry
        BuildBadge(math.max(1, state.stage), math.max(0, state.stars))

        local forward = assert(cache:GetResource("XMLFile", "EngineRes/RenderPaths/Forward.xml"),
            "Forward.xml missing")
        local viewport = Viewport:new(scene, camera)
        state.viewport = viewport
        viewport:SetRenderPath(forward)
        local path = viewport:GetRenderPath()
        local clears = 0
        for i = 0, path:GetNumCommands() - 1 do
            local command = path:GetCommand(i)
            if command.type == CMD_CLEAR then
                command.useFogColor = false
                command.clearColor = Color(0, 0, 0, 0)
                path:SetCommand(i, command)
                clears = clears + 1
            end
        end
        assert(clears > 0, "Forward path has no clear command")

        state.ready, state.failed, state.error = true, false, ""
        print(string.format("[StageBadgeShowcase] api=%s flipY=%s", tostring(api), tostring(state.flipY)))
        print("[StageBadgeShowcase] ready")
    end)
    if not ok then return Fail(tostring(reason)) end
    return true
end

---@param physicalW number
---@param physicalH number
---@return integer width, integer height
function StageBadgeShowcase.ResolveSize(physicalW, physicalH)
    local w = math.max(1, physicalW or 1)
    local h = math.max(1, physicalH or 1)
    local width = math.min(MAX_W, math.max(MIN_W, math.ceil(w / SIZE_STEP) * SIZE_STEP))
    local height = math.min(MAX_W, math.max(MIN_W, math.ceil(h / SIZE_STEP) * SIZE_STEP))
    return width, height
end

--- 每帧推进（RT 只在可见时刷新，32ms 节流）。
---@param dt number
---@param visible boolean
---@param stage integer
---@param stars integer
---@param physicalW number|nil
---@param physicalH number|nil
function StageBadgeShowcase.Update(dt, visible, stage, stars, physicalW, physicalH)
    if state.failed then return end
    state.visible = visible == true
    if not state.visible then return end
    if not StageBadgeShowcase.Init() then return end

    local width, height = StageBadgeShowcase.ResolveSize(physicalW or 320, physicalH or 320)
    if not ResizeTarget(width, height) and not state.texture then return end
    if state.camera and state.height > 0 then
        local ar = state.width / state.height
        if math.abs((state.camera.aspectRatio or 0) - ar) > 0.001 then
            state.camera.aspectRatio = ar
            state.camera:SetAspectRatio(ar)
        end
    end

    if stage ~= state.stage or stars ~= state.stars then
        local first = state.stage < 0
        BuildBadge(math.max(1, stage or 1), math.max(0, stars or 0))
        -- 换关演出：首帧不播，之后每次换关从 0 起算
        if not first then state.switchAt = state.phase end
    end

    state.timer = state.timer + (dt or 0)
    state.phase = state.phase + (dt or 0)
    -- 换关演出：0~0.25 从 0.82 弹到 1.06，0.25~0.55 回落到 1.0（easeOutBack 近似）
    local scale = 1
    local glowBoost = 0
    if state.switchAt then
        local age = state.phase - state.switchAt
        if age < 0 or age > state.switchDur then
            state.switchAt = nil
        else
            local t = age / state.switchDur
            if t < 0.28 then
                local u = t / 0.28
                scale = 0.82 + 0.24 * (1 - (1 - u) * (1 - u))
            elseif t < 0.55 then
                local u = (t - 0.28) / 0.27
                scale = 1.06 - 0.06 * u
            end
            -- 发光槽在演出前半段更亮（0.9 → 1.9 倍自发光）
            glowBoost = (t < 0.55) and (1.0 - t / 0.55) or ((t < 0.8) and (1 - (t - 0.55) / 0.25) * 0.45 or 0)
        end
    end

    -- 待机：绕竖轴慢摆 + 轻微起伏（看得到侧面厚度）
    local yaw = math.sin(state.phase * 0.55) * 15
    local tilt = math.sin(state.phase * 0.37) * 2.5
    local bob = math.sin(state.phase * 1.05) * 0.05
    if state.node then
        state.node.rotation = Quaternion(yaw, Vector3.UP) * Quaternion(tilt, Vector3.RIGHT)
        state.node.position = Vector3(0, bob, 0)
        state.node.scale = Vector3(scale, scale, scale)
    end
    if state.glowMaterial then
        local accent = state.glowBase or TIER_STEEL
        local k = 1.4 + 1.2 * glowBoost
        state.glowMaterial:SetShaderParameter("MatEmissiveColor",
            Variant(Color(accent[1] * k, accent[2] * k, accent[3] * k, 1)))
    end

    if state.timer < FRAME_INTERVAL then return end
    state.timer = 0
    if state.surface then
        state.surface:QueueUpdate()
        state.updates = state.updates + 1
    end
end

---@param ctx NVGContextWrapper
---@param x number
---@param y number
---@param w number
---@param h number
---@return boolean
function StageBadgeShowcase.Draw(ctx, x, y, w, h)
    if not ctx or w <= 0 or h <= 0 or not state.visible or state.failed then return false end
    if not StageBadgeShowcase.Init() then return false end
    if not state.texture then return false end
    local saved = false
    local ok, reason = pcall(function()
        if state.imageContext and state.imageContext ~= ctx then ReleaseImage() end
        if state.image == 0 then
            state.image = nvgCreateVideo(ctx, state.texture)
            state.imageContext = ctx
            assert(state.image > 0, "nvgCreateVideo failed")
        end
        local scale = math.min(w / state.width, h / state.height)
        local dw, dh = state.width * scale, state.height * scale
        local dx, dy = x + (w - dw) * 0.5, y + (h - dh) * 0.5
        nvgSave(ctx)
        saved = true
        nvgIntersectScissor(ctx, x, y, w, h)
        -- 水平/垂直翻转统一在局部坐标系里做：先把原点挪到目标矩形要翻转的那条边，
        -- 再对轴取负，然后把图按 (0,0,dw,dh) 画进去。
        if state.flipY then
            nvgTranslate(ctx, dx, dy + dh)
            nvgScale(ctx, 1, -1)
            nvgBeginPath(ctx)
            nvgRect(ctx, 0, 0, dw, dh)
            nvgFillPaint(ctx, nvgImagePattern(ctx, 0, 0, dw, dh, 0, state.image, 1))
        else
            nvgBeginPath(ctx)
            nvgRect(ctx, dx, dy, dw, dh)
            nvgFillPaint(ctx, nvgImagePattern(ctx, dx, dy, dw, dh, 0, state.image, 1))
        end
        nvgFill(ctx)
    end)
    if saved then pcall(nvgRestore, ctx) end
    if not ok then return Fail(reason) end
    return true
end

function StageBadgeShowcase.Shutdown()
    state.visible = false
    ReleaseResources()
    state.failed, state.error = false, ""
    state.timer, state.phase = 0, 0
    state.width, state.height, state.updates, state.builds = 0, 0, 0, 0
    state.stage, state.stars = -1, -1
    state.flipY = false
end

---@return table
function StageBadgeShowcase.GetDiagnostics()
    return {
        ready = state.ready, failed = state.failed, error = state.error,
        visible = state.visible, stage = state.stage, stars = state.stars,
        gold = state.gold, image = state.image, updates = state.updates,
        builds = state.builds, width = state.width, height = state.height,
        flipY = state.flipY,
    }
end

return StageBadgeShowcase
