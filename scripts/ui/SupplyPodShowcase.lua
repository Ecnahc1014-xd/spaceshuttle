-- SupplyPodShowcase.lua
-- 结算界面的「空投补给舱」3D 展示：独立 Scene + 透视相机 + 三点光，
-- 渲染到 RenderTexture 后由 NanoVG 贴进结算窗口（与 ui/VehicleShowcase 同一套 RT 生命周期）。
-- 只服务结算页展示：不接战斗物理、不改全局渲染配置、不写存档。
local SupplyPodGeometry = require "SupplyPodGeometry"

local SupplyPodShowcase = {}

local MIN_W, MAX_W = 384, 1280
local SIZE_STEP = 64
local FRAME_INTERVAL = 1 / 30

---@class PodShowcaseState
---@field scene Scene|nil
---@field bodyNode Node|nil
---@field bodyGeo CustomGeometry|nil
---@field lidL Node|nil
---@field lidR Node|nil
---@field coreNode Node|nil
---@field gyroA Node|nil
---@field gyroB Node|nil
---@field cameraNode Node|nil
---@field camera Camera|nil
---@field texture Texture2D|nil
---@field surface RenderSurface|nil
---@field viewport Viewport|nil
---@field materials Material[]
---@field tierMaterial Material|nil
---@field glowMaterial Material|nil
---@field coreMaterial Material|nil
---@field gyroMaterial Material|nil
---@field rimNode Node|nil
---@field rimLight Light|nil
---@field image integer
---@field imageContext NVGContextWrapper|nil
---@field ready boolean
---@field failed boolean
---@field error string
---@field visible boolean
---@field dirty boolean
---@field timer number
---@field phase number
---@field openProgress number
---@field tier integer
---@field width integer
---@field height integer
---@field flipY boolean
---@field updates integer
---@field builds integer
---@field openCurve string
local state = {
    scene = nil, bodyNode = nil, bodyGeo = nil, lidL = nil, lidR = nil,
    coreNode = nil, gyroA = nil, gyroB = nil, cameraNode = nil, camera = nil,
    texture = nil, surface = nil, viewport = nil, materials = {},
    tierMaterial = nil, glowMaterial = nil, coreMaterial = nil, gyroMaterial = nil,
    shardNode = nil, shardMaterial = nil,
    rimNode = nil, rimLight = nil, image = 0, imageContext = nil,
    ready = false, failed = false, error = "", visible = false, dirty = true,
    timer = 0, phase = 0, openProgress = 0, tier = 0,
    width = 0, height = 0, flipY = false, updates = 0, builds = 0, openCurve = "idle",
} --[[@as PodShowcaseState]]

-- 等级阶梯（与结算页一致：常规银 → 稀有蓝 → 史诗紫 → 传说金）
local TIER_RGB = {
    { 0.79, 0.83, 0.88 },  -- common 银
    { 0.36, 0.58, 1.00 },  -- rare 蓝
    { 0.64, 0.42, 1.00 },  -- epic 紫
    { 0.95, 0.65, 0.24 },  -- legend 金
}

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
    state.dirty = true
    print("[SupplyPodShowcase] RT=" .. width .. "x" .. height)
    return true
end

local function ReleaseResources()
    ReleaseImage()
    if state.surface then pcall(function() state.surface:SetNumViewports(0) end) end
    state.surface, state.viewport = nil, nil
    if state.texture then pcall(function() state.texture:Dispose() end) end
    state.texture = nil
    if state.scene then pcall(function() state.scene:Dispose() end) end
    state.scene, state.bodyNode, state.bodyGeo = nil, nil, nil
    state.lidL, state.lidR, state.coreNode, state.gyroA, state.gyroB = nil, nil, nil, nil, nil
    state.cameraNode, state.camera, state.rimNode, state.rimLight = nil, nil, nil, nil
    for _, material in ipairs(state.materials) do pcall(function() material:Dispose() end) end
    state.materials = {}
    state.tierMaterial, state.glowMaterial = nil, nil
    state.coreMaterial, state.gyroMaterial = nil, nil
    state.ready = false
end

---@param reason string
---@return boolean
local function Fail(reason)
    if not state.failed then
        print("[SupplyPodShowcase] unavailable: " .. tostring(reason))
    end
    ReleaseResources()
    state.failed, state.error = true, tostring(reason)
    return false
end

--- 生成一组节点 + 几何（body / lid / core / gyro 共用）。
---@param parent Node
---@param name string
---@param buffers table[]
---@param materials Material[]
---@return Node, CustomGeometry
local function CreatePart(parent, name, buffers, materials)
    local node = parent:CreateChild(name, LOCAL)
    local geo = node:CreateComponent("CustomGeometry", LOCAL)
    assert(geo, "CustomGeometry unavailable")
    geo.castShadows = false
    SupplyPodGeometry.Apply(geo, buffers, materials)
    return node, geo
end

---@return boolean
function SupplyPodShowcase.Init()
    if state.ready then return true end
    if state.failed then return false end
    local ok, reason = pcall(function()
        local opaque = assert(cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"),
            "PBRNoTexture missing")
        -- RT 采样方向：GLES/OpenGL 下 NanoVG 图像为底部原点，需要翻转
        local api = graphics:GetApiName()
        state.flipY = (api == "GLES" or api == "OpenGL")

        -- 材质顺序必须与 SupplyPodGeometry.BuildBody 的段序一致
        local hull   = CreateMaterial(opaque, { 0.075, 0.090, 0.115 }, 0.18, 0.55)
        local armor  = CreateMaterial(opaque, { 0.720, 0.760, 0.820 }, 0.22, 0.44)
        local rib    = CreateMaterial(opaque, { 0.885, 0.900, 0.920 }, 0.35, 0.30)
        local warn   = CreateMaterial(opaque, { 0.952, 0.655, 0.243 }, 0.25, 0.40)
        local dark   = CreateMaterial(opaque, { 0.055, 0.062, 0.078 }, 0.20, 0.72)
        state.tierMaterial = CreateMaterial(opaque, TIER_RGB[1], 0.25, 0.40)
        state.glowMaterial = CreateMaterial(opaque, TIER_RGB[1], 0.10, 0.35,
            { TIER_RGB[1][1] * 1.6, TIER_RGB[1][2] * 1.6, TIER_RGB[1][3] * 1.6 })
        -- 第 8 段：纯黑轮廓壳（与 UI 的深墨描边同色系）
        local outline = CreateMaterial(opaque, { 0.020, 0.024, 0.032 }, 0.0, 0.90,
            { 0.010, 0.012, 0.016 })
        local bodyMaterials = { hull, armor, rib, warn, dark, state.tierMaterial,
            state.glowMaterial, outline }
        -- 盖：面板 / 装甲 / 压条 / 发光导管 / 深色内衬
        local lidMaterials = { armor, rib, rib, state.glowMaterial, dark }
        local b1 = TIER_RGB[1]
        state.coreMaterial = CreateMaterial(opaque,
            { (1 + b1[1]) * 0.5, (1 + b1[2]) * 0.5, (1 + b1[3]) * 0.5 }, 0.0, 0.16,
            { b1[1] * 0.75, b1[2] * 0.75, b1[3] * 0.75 })
        state.shardMaterial = CreateMaterial(opaque, TIER_RGB[1], 0.0, 0.20,
            { TIER_RGB[1][1] * 1.5, TIER_RGB[1][2] * 1.5, TIER_RGB[1][3] * 1.5 })
        state.gyroMaterial = CreateMaterial(opaque, { 0.88, 0.92, 0.97 }, 0.20, 0.30,
            { 0.75, 0.82, 0.92 })

        local scene = Scene()
        state.scene = scene
        assert(scene:CreateComponent("Octree", LOCAL), "Octree unavailable")

        local zoneNode = scene:CreateChild("PodZone", LOCAL)
        local zone = assert(zoneNode:CreateComponent("Zone", LOCAL), "Zone unavailable")
        zone.boundingBox = BoundingBox(-1000, 1000)
        zone.ambientSource = AMBIENT_COLOR
        zone.ambientColor = Color(0.52, 0.56, 0.66)
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

        -- 相机：透视，略微俯视，足够看到舱口内部与两扇打开的门
        local cameraNode = scene:CreateChild("PodCamera", LOCAL)
        cameraNode.position = Vector3(0, 2.38, 4.95)
        cameraNode:LookAt(Vector3(0, 1.06, 0))
        local camera = assert(cameraNode:CreateComponent("Camera", LOCAL), "Camera unavailable")
        camera.fov = 32
        camera.nearClip = 0.1
        camera.farClip = 40
        camera.autoAspectRatio = false
        camera.aspectRatio = 1.6
        state.cameraNode, state.camera = cameraNode, camera

        -- 主光（冷白、侧上）
        local keyNode = scene:CreateChild("PodKey", LOCAL)
        keyNode.direction = Vector3(-0.55, -0.75, -0.35):Normalized()
        local key = assert(keyNode:CreateComponent("Light", LOCAL), "Light unavailable")
        key.lightType = LIGHT_DIRECTIONAL
        key.color = Color(1.0, 0.975, 0.93)
        key.brightness = 2.25
        key.castShadows = false

        -- 轮廓光（等级色、逆光）
        local rimNode = scene:CreateChild("PodRim", LOCAL)
        rimNode.direction = Vector3(0.65, -0.35, 0.68):Normalized()
        local rim = assert(rimNode:CreateComponent("Light", LOCAL), "Light unavailable")
        rim.lightType = LIGHT_DIRECTIONAL
        rim.color = Color(TIER_RGB[1][1], TIER_RGB[1][2], TIER_RGB[1][3])
        rim.brightness = 1.10
        rim.castShadows = false
        state.rimNode, state.rimLight = rimNode, rim

        -- 补光（底部，压掉纯黑）
        local fillNode = scene:CreateChild("PodFill", LOCAL)
        fillNode.direction = Vector3(0.2, 0.8, 0.45):Normalized()
        local fill = assert(fillNode:CreateComponent("Light", LOCAL), "Light unavailable")
        fill.lightType = LIGHT_DIRECTIONAL
        fill.color = Color(0.62, 0.70, 0.85)
        fill.brightness = 0.55
        fill.castShadows = false

        -- 舱体
        local root = scene:CreateChild("PodRoot", LOCAL)
        local bodyNode, bodyGeo = CreatePart(root, "PodBody", SupplyPodGeometry.BuildBody(), bodyMaterials)
        state.bodyNode, state.bodyGeo = bodyNode, bodyGeo

        -- 两扇舱盖：局部原点在外侧铰链处
        state.lidL = select(1, CreatePart(root, "PodLidL", SupplyPodGeometry.BuildLid(1), lidMaterials))
        state.lidL.position = Vector3(-1.31, 1.15, 0)
        state.lidR = select(1, CreatePart(root, "PodLidR", SupplyPodGeometry.BuildLid(-1), lidMaterials))
        state.lidR.position = Vector3(1.31, 1.15, 0)

        -- 能量核心 + 陀螺环
        local coreNode = CreatePart(root, "PodCore", SupplyPodGeometry.BuildCore(),
            { state.coreMaterial })
        state.coreNode = coreNode
        state.gyroA = select(1, CreatePart(root, "PodGyroA", SupplyPodGeometry.BuildGyro(0.74, 0.034),
            { state.gyroMaterial }))
        state.gyroB = select(1, CreatePart(root, "PodGyroB", SupplyPodGeometry.BuildGyro(0.96, 0.028),
            { state.gyroMaterial }))
        state.shardNode = select(1, CreatePart(root, "PodShards",
            SupplyPodGeometry.BuildShards(5, 0.96, 0.15), { state.shardMaterial }))

        -- 诊断：确认每段几何确实有顶点（0 说明 Buffer 写入失败）
        local counts = {}
        for sec = 0, bodyGeo:GetNumGeometries() - 1 do
            counts[#counts + 1] = bodyGeo:GetNumVertices(sec)
        end
        print("[SupplyPodShowcase] body sections vertices=" .. table.concat(counts, ","))

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
        state.ready = true
        state.failed, state.error = false, ""
        state.builds = state.builds + 1
        print("[SupplyPodShowcase] ready")
    end)
    if not ok then
        return Fail(tostring(reason))
    end
    return true
end

---@param physicalW number
---@param physicalH number
---@return integer width, integer height
function SupplyPodShowcase.ResolveSize(physicalW, physicalH)
    local w = math.max(1, physicalW or 1)
    local h = math.max(1, physicalH or 1)
    local width = math.min(MAX_W, math.max(MIN_W,
        math.ceil(w / SIZE_STEP) * SIZE_STEP))
    local height = math.max(SIZE_STEP, math.ceil(h / SIZE_STEP) * SIZE_STEP)
    return width, height
end

--- 每帧推进展示动画。RT 只在可见时刷新（32ms 节流）。
---@param dt number
---@param visible boolean
---@param tier integer 0..3
---@param physicalW number|nil
---@param physicalH number|nil
function SupplyPodShowcase.Update(dt, visible, tier, physicalW, physicalH)
    if state.failed then return end
    state.visible = visible and true or false
    if not state.visible then return end
    if not SupplyPodShowcase.Init() then return end

    local width, height = SupplyPodShowcase.ResolveSize(physicalW or 512, physicalH or 320)
    if not ResizeTarget(width, height) and not state.texture then return end
    -- 相机宽高比必须等于 RT 比例，否则透视画面会被拉伸/压扁
    if state.camera and state.height > 0 then
        local ar = state.width / state.height
        if math.abs((state.camera.aspectRatio or 0) - ar) > 0.001 then
            state.camera.aspectRatio = ar
            state.camera:SetAspectRatio(ar)
        end
    end

    if tier and tier ~= state.tier then
        state.tier = tier
        local rgb = TIER_RGB[math.min(4, math.max(1, tier + 1))]
        if state.tierMaterial then
            state.tierMaterial:SetShaderParameter("MatDiffColor", Variant(Color(rgb[1], rgb[2], rgb[3], 1)))
            state.tierMaterial:SetShaderParameter("MatEmissiveColor",
                Variant(Color(rgb[1] * 0.35, rgb[2] * 0.35, rgb[3] * 0.35, 1)))
        end
        if state.glowMaterial then
            state.glowMaterial:SetShaderParameter("MatDiffColor", Variant(Color(rgb[1], rgb[2], rgb[3], 1)))
            state.glowMaterial:SetShaderParameter("MatEmissiveColor",
                Variant(Color(rgb[1] * 1.7, rgb[2] * 1.7, rgb[3] * 1.7, 1)))
        end
        if state.coreMaterial then
            state.coreMaterial:SetShaderParameter("MatDiffColor", Variant(Color(
                (1 + rgb[1]) * 0.5, (1 + rgb[2]) * 0.5, (1 + rgb[3]) * 0.5, 1)))
            state.coreMaterial:SetShaderParameter("MatEmissiveColor",
                Variant(Color(rgb[1] * 0.75, rgb[2] * 0.75, rgb[3] * 0.75, 1)))
        end
        if state.shardMaterial then
            state.shardMaterial:SetShaderParameter("MatDiffColor",
                Variant(Color(rgb[1], rgb[2], rgb[3], 1)))
            state.shardMaterial:SetShaderParameter("MatEmissiveColor",
                Variant(Color(rgb[1] * 1.5, rgb[2] * 1.5, rgb[3] * 1.5, 1)))
        end
        if state.rimLight then
            state.rimLight.color = Color(rgb[1], rgb[2], rgb[3])
        end
        state.dirty = true
    end

    state.timer = state.timer + (dt or 0)
    state.phase = state.phase + (dt or 0)
    -- 开盖节奏：0→1 用 0.85s，停 1.6s，再合上 0.6s，循环 5.4s
    local cycle = 5.4
    local t = state.phase % cycle
    local open
    if t < 0.85 then
        local u = t / 0.85
        open = u * u * (3 - 2 * u)          -- smoothstep
    elseif t < 3.05 then
        open = 1
    elseif t < 3.65 then
        local u = (t - 3.05) / 0.6
        open = 1 - u * u * (3 - 2 * u)
    else
        open = 0
    end
    state.openProgress = open

    -- 待机摆动 + 缓慢旋转
    if state.scene then
        local root = state.scene:GetChild("PodRoot", false)
        if root then
            root.rotation = Quaternion(math.sin(state.phase * 0.6) * 14, Vector3.UP)
        end
    end
    -- 左门（原点在左边缘、面板向 +x）绕 +Z 转正角上台；右门相反
    local angle = open * 118
    if state.lidL then state.lidL.rotation = Quaternion(angle, Vector3.FORWARD) end
    if state.lidR then state.lidR.rotation = Quaternion(-angle, Vector3.FORWARD) end

    if state.coreNode then
        local rise = open
        state.coreNode.position = Vector3(0, 1.12 + rise * 0.55, 0)
        state.coreNode.rotation = Quaternion(state.phase * 42, Vector3.UP)
        local breathe = 0.55 + 0.45 * rise
        state.coreNode.scale = Vector3(breathe, breathe, breathe)
    end
    if state.shardNode then
        state.shardNode.position = Vector3(0, 1.05 + open * 0.52, 0)
        state.shardNode.rotation = Quaternion(-state.phase * 46, Vector3.UP)
        local ss = 0.45 + 0.55 * open
        state.shardNode.scale = Vector3(ss, ss, ss)
    end
    if state.gyroA then
        state.gyroA.position = Vector3(0, 1.12 + open * 0.55, 0)
        state.gyroA.rotation = Quaternion(state.phase * 60, Vector3.RIGHT)
        local ga = 0.5 + 0.5 * open
        state.gyroA.scale = Vector3(ga, ga, ga)
    end
    if state.gyroB then
        state.gyroB.position = Vector3(0, 1.12 + open * 0.55, 0)
        state.gyroB.rotation = Quaternion(state.phase * 38, Vector3.FORWARD)
            * Quaternion(58, Vector3.RIGHT)
        local gb = 0.5 + 0.5 * open
        state.gyroB.scale = Vector3(gb, gb, gb)
    end

    if state.timer < FRAME_INTERVAL then return end
    state.timer = 0
    if state.surface then
        state.surface:QueueUpdate()
        state.updates = state.updates + 1
    end
end

--- 把 RT 贴到 NanoVG 指定矩形（等比 contain）。
---@param ctx NVGContextWrapper
---@param x number
---@param y number
---@param w number
---@param h number
---@return boolean
function SupplyPodShowcase.Draw(ctx, x, y, w, h)
    if not ctx or w <= 0 or h <= 0 or not state.visible or state.failed then return false end
    if not SupplyPodShowcase.Init() then return false end
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

function SupplyPodShowcase.Shutdown()
    state.visible = false
    ReleaseResources()
    state.failed, state.error = false, ""
    state.dirty, state.timer, state.phase, state.openProgress = true, 0, 0, 0
    state.width, state.height, state.updates = 0, 0, 0
    state.flipY = false
end

---@return table
function SupplyPodShowcase.GetDiagnostics()
    return {
        ready = state.ready, failed = state.failed, error = state.error,
        visible = state.visible, tier = state.tier,
        image = state.image, updates = state.updates,
        width = state.width, height = state.height,
        openProgress = state.openProgress,
        flipY = state.flipY,
    }
end

--- 物理像素 → RT 尺寸变化时由外部调用（结算窗口尺寸变化）。
function SupplyPodShowcase.ResolveFlipY()
    local api = graphics:GetApiName()
    state.flipY = api == "GLES" or api == "OpenGL"
    return state.flipY
end

return SupplyPodShowcase
