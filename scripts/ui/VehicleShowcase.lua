-- VehicleShowcase.lua
-- 基于 scaffold-3d-scene 的 Scene/Octree/Camera/PBR 骨架与 scene-to-nanovg RT 生命周期。
-- 只做客户端展台：复用实车几何，不接入战斗、购买、输入或全局渲染配置。
local VehicleGeometry = require "VehicleGeometry"
local VehicleShowcase = {}

local MIN_WIDTH, MAX_WIDTH = 512, 1920
local ASPECT = 16 / 9
local SIZE_STEP = 64
local FRAME_INTERVAL = 1 / 30
local KEYS = {default = true, arctic = true, crimson = true, jade = true, obsidian = true, rally = true}

---@class VehicleShowcaseState
---@field scene Scene|nil
---@field vehicle Node|nil
---@field geometry CustomGeometry|nil
---@field cameraNode Node|nil
---@field camera Camera|nil
---@field texture Texture2D|nil
---@field surface RenderSurface|nil
---@field viewport Viewport|nil
---@field materials Material[]
---@field outlineMaterial Material|nil
---@field center Vector3
---@field corners Vector3[]
---@field image integer
---@field imageContext NVGContextWrapper|nil
---@field ready boolean
---@field failed boolean
---@field error string
---@field key string
---@field visible boolean
---@field dirty boolean
---@field timer number
---@field phase number
---@field yaw number
---@field updates integer
---@field builds integer
---@field vertices integer
---@field sectionVertices integer[]
---@field orthoSize number
---@field flipY boolean
---@field width integer
---@field height integer
---@field allocations integer
---@field allocationBlocked boolean
local state = {
    scene = nil, vehicle = nil, geometry = nil, cameraNode = nil, camera = nil,
    texture = nil, surface = nil, viewport = nil, materials = {}, outlineMaterial = nil,
    center = Vector3(0, 0, 0), corners = {}, image = 0, imageContext = nil,
    ready = false, failed = false, error = "", key = "default", visible = false,
    dirty = true, timer = 0, phase = 0, yaw = 0, updates = 0, builds = 0,
    vertices = 0, sectionVertices = {}, orthoSize = 0, flipY = false,
    width = 0, height = 0, allocations = 0, allocationBlocked = false,
} --[[@as VehicleShowcaseState]]

local function ReleaseImage()
    if state.image > 0 and state.imageContext then
        pcall(nvgDeleteVideo, state.imageContext, state.image)
    end
    state.image, state.imageContext = 0, nil
end

-- 输入是最终物理显示矩形，不是设计尺寸；16:9 contain 与 Draw 使用同一比例。
-- 预留窗口弹动的 3% 放大，以 64px 分档；上限 1920×1080 控制移动端显存。
---@param physicalW number|nil
---@param physicalH number|nil
---@return integer width, integer height
function VehicleShowcase.ResolveSize(physicalW, physicalH)
    local w, h = physicalW or 0, physicalH or 0
    if w ~= w or h ~= h or w <= 0 or h <= 0 then return MIN_WIDTH, 288 end
    local containedW = math.min(w, h * ASPECT)
    local width = math.min(MAX_WIDTH, math.max(MIN_WIDTH,
        math.ceil(containedW * 1.03 / SIZE_STEP) * SIZE_STEP))
    return width, math.floor(width * 9 / 16)
end

local function ResizeTarget(width, height)
    if state.texture and width <= state.width then return true end
    if state.allocationBlocked then return false end
    -- 先准备新 RT。分配失败保留旧图，不每帧重试；初次分配失败由 Init 降级。
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
        if texture then
            pcall(function()
                local surface = texture:GetRenderSurface()
                if surface then surface:SetNumViewports(0) end
                texture:Dispose()
            end)
        end
        if not state.texture then error(reason) end
        state.allocationBlocked = true
        print("[VehicleShowcase] RT growth unavailable, keeping " .. state.width .. "x" .. state.height
            .. ": " .. tostring(reason))
        return false
    end
    -- 旧图片包装 → 旧 surface 解绑 → 旧纹理；不动场景、几何、相机或取景。
    ReleaseImage()
    if state.surface then state.surface:SetNumViewports(0) end
    if state.texture then state.texture:Dispose() end
    state.texture, state.surface = texture, texture:GetRenderSurface()
    state.width, state.height = width, height
    state.allocations = state.allocations + 1
    state.dirty = true
    print("[VehicleShowcase] RT=" .. width .. "x" .. height .. " levels=1")
    return true
end

local function ReleaseResources()
    -- 图片包装必须在旧 ctx/纹理尚有效时释放；从未拥有共享 NanoVG 上下文。
    ReleaseImage()
    if state.surface then pcall(function() state.surface:SetNumViewports(0) end) end
    state.surface, state.viewport = nil, nil
    if state.texture then pcall(function() state.texture:Dispose() end) end
    state.texture = nil
    if state.geometry then pcall(function() state.geometry:Dispose() end) end
    state.geometry = nil
    if state.scene then pcall(function() state.scene:Dispose() end) end
    state.scene, state.vehicle, state.cameraNode, state.camera = nil, nil, nil, nil
    for _, material in ipairs(state.materials) do
        pcall(function() material:Dispose() end)
    end
    state.materials = {}
    state.outlineMaterial = nil -- 轮廓材质也在上面的数组里，已随之释放
    state.ready = false
end

local function Fail(reason)
    if not state.failed then
        print("[VehicleShowcase] unavailable: " .. tostring(reason))
    end
    ReleaseResources()
    state.failed = true
    state.error = tostring(reason)
    return false
end

---@param technique Technique
---@param rgb number[]
---@param metallic number
---@param roughness number
---@param alpha number
---@param emissive number[]|nil
local function CreateMaterial(technique, rgb, metallic, roughness, alpha, emissive)
    local material = Material:new()
    state.materials[#state.materials + 1] = material
    material:SetTechnique(0, technique)
    material:SetShaderParameter("MatDiffColor", Variant(Color(rgb[1] or 0, rgb[2] or 0, rgb[3] or 0, alpha)))
    material:SetShaderParameter("Metallic", Variant(metallic))
    material:SetShaderParameter("Roughness", Variant(roughness))
    if emissive then
        material:SetShaderParameter("MatEmissiveColor", Variant(Color(emissive[1] or 0, emissive[2] or 0, emissive[3] or 0, 1)))
    end
    return material
end

---@param scene Scene
---@param name string
---@param direction Vector3
---@param color Color
---@param brightness number
local function CreateLight(scene, name, direction, color, brightness)
    local node = scene:CreateChild(name, LOCAL)
    node.direction = direction
    local light = node:CreateComponent("Light", LOCAL)
    assert(light, "cannot create " .. name)
    light.lightType = LIGHT_DIRECTIONAL
    light.color = color
    light.brightness = brightness
    light.castShadows = false
end

local function VehicleRotation(yaw)
    -- 实车局部 +X 为车头、-Z 为车顶；先立到 Y-up，再绕展台竖轴摆动。
    return Quaternion(yaw, Vector3.UP) * Quaternion(90, Vector3.RIGHT)
end

local function ApplyPose()
    local rotation = VehicleRotation(state.yaw)
    state.vehicle.rotation = rotation
    -- 按真实 bbox 中心绕转，不沿用战斗碰撞半径/锚点偏移。
    state.vehicle.position = -(rotation * state.center)
end

local function FitCamera()
    local box = state.geometry:GetBoundingBox()
    assert(box:Defined(), "vehicle bounding box undefined")
    local size = box.size
    local radius = size:Length() * 0.5
    assert(radius > 0.0001, "vehicle bounding box empty")
    state.center = box.center
    state.corners = {}
    local lo, hi = box.min, box.max
    for _, x in ipairs({lo.x, hi.x}) do
        for _, y in ipairs({lo.y, hi.y}) do
            for _, z in ipairs({lo.z, hi.z}) do
                state.corners[#state.corners + 1] = Vector3(
                    x - state.center.x, y - state.center.y, z - state.center.z)
            end
        end
    end

    local cameraNode, camera = state.cameraNode, state.camera
    cameraNode.position = Vector3(5, 3.8, -6):Normalized() * (radius * 4)
    cameraNode:LookAt(Vector3(0, 0, 0))
    camera.nearClip = radius * 0.05
    camera.farClip = radius * 8
    camera.orthographic = true
    camera.autoAspectRatio = false
    camera.aspectRatio = ASPECT

    -- 只在车型变化时测全摆动范围的 bbox 投影；留白兜住采样间隙，避免每帧缩放呼吸。
    local inverse = cameraNode.rotation:Inverse()
    local halfW, halfH = 0, 0
    for yaw = -15, 15 do
        local rotation = VehicleRotation(yaw)
        for _, corner in ipairs(state.corners) do
            local viewPoint = inverse * (rotation * corner)
            halfW = math.max(halfW, math.abs(viewPoint.x))
            halfH = math.max(halfH, math.abs(viewPoint.y))
        end
    end
    state.orthoSize = math.max(halfH * 2, halfW * 2 / ASPECT) * 1.12
    camera.orthoSize = state.orthoSize
    -- 此运行时 SetOrthoSize(float) 会把 aspectRatio 复位为 1；必须最后重设。
    camera:SetAspectRatio(ASPECT)
end

local function BuildVehicle(key)
    state.vehicle.enabled = false
    VehicleGeometry.Build(state.geometry, key, state.materials, state.outlineMaterial)
    state.vertices = 0
    state.sectionVertices = {}
    for section = 0, state.geometry:GetNumGeometries() - 1 do
        local count = state.geometry:GetNumVertices(section)
        state.sectionVertices[#state.sectionVertices + 1] = count
        state.vertices = state.vertices + count
    end
    assert(state.vertices > 0, "vehicle has no vertices")
    state.key = key
    FitCamera()
    ApplyPose()
    state.vehicle.enabled = true
    state.builds = state.builds + 1
    state.dirty = true
    print("[VehicleShowcase] vehicle=" .. key .. " vertices=" .. tostring(state.vertices))
end

--- 可显式初始化，也可由首次可见 Update 懒初始化。失败后不逐帧重试，Shutdown 可复位。
---@param width integer|nil
---@param height integer|nil
---@return boolean
function VehicleShowcase.Init(width, height)
    if state.ready then return true end
    if state.failed then return false end
    local ok, reason = pcall(function()
        local forward = assert(cache:GetResource("XMLFile", "EngineRes/RenderPaths/Forward.xml"), "Forward.xml missing")
        -- 当前 GLES 绑定的 RT 图像仍为底部原点，色标实测上/下交换；非 GL 后端不翻。
        local api = graphics:GetApiName()
        state.flipY = api == "GLES" or api == "OpenGL"
        local opaque = assert(cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"), "PBRNoTexture missing")
        local alpha = assert(cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"), "PBRNoTextureAlpha missing")

        -- 预览自有材质，复用 Renderer3D 的 speed 红橙参数，不修改战斗缓存。
        CreateMaterial(opaque, {0.76, 0.045, 0.015}, 0.72, 0.27, 1)
        CreateMaterial(opaque, {1, 0.24, 0.055}, 0.56, 0.34, 1)
        CreateMaterial(opaque, {0.035, 0.045, 0.065}, 0, 0.88, 1)
        CreateMaterial(opaque, {0.44, 0.48, 0.56}, 0.96, 0.18, 1)
        -- 有 IBL 后 0.08 粗糙度的玻璃会把明亮天空反射成一块死白，抬到 0.20 让反射散开。
        local glass = CreateMaterial(alpha, {0.16, 0.07, 0.13}, 0.05, 0.20, 0.68)
        glass:SetRenderOrder(180)
        CreateMaterial(opaque, {1, 0.18, 0.035}, 0.05, 0.20, 1, {3.2, 0.576, 0.112})
        -- 第 7 段白色轮廓壳；CreateMaterial 已把材质登记进 state.materials，随展台一并释放。
        state.outlineMaterial = CreateMaterial(opaque, {0.94, 0.96, 1.0}, 0.0, 0.55, 1, {0.34, 0.36, 0.40})

        local scene = Scene()
        state.scene = scene -- Scene 强持有；Viewport 对 Scene 的引用不承担保活。
        assert(scene:CreateComponent("Octree", LOCAL), "Octree unavailable")
        local zoneNode = scene:CreateChild("ShowcaseZone", LOCAL)
        local zone = assert(zoneNode:CreateComponent("Zone", LOCAL), "Zone unavailable")
        zone.boundingBox = BoundingBox(-1000, 1000)
        -- 展台是全项目唯一的“打光写真”光位：金属度 0.72 的车漆有环境反射（IBL）
        -- 才有金属感，否则只剩三盏灯的直接高光，深红漆会暗成近黑。
        -- ⚠️ v0.14.x：不再引用官方 res 的 uuid:// 天空盒——那会把整个
        --    __official_pinned_refs__ 素材集（18 个引用）钉进构建清单的 #blocking 组，
        --    运行时逐个 DWP 下载，任一失败即刷平台 XHR 错误。
        --    改用本地程序化环境光，金属感略降但零外部依赖。
        zone.ambientSource = AMBIENT_COLOR
        zone.ambientColor = Color(0.18, 0.20, 0.24)
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
        CreateLight(scene, "ShowcaseKey", Vector3(-0.6, -1, 0.7), Color(1, 0.92, 0.84), 1.0)
        CreateLight(scene, "ShowcaseFill", Vector3(0.8, -0.4, 0.2), Color(0.65, 0.80, 1), 0.35)
        CreateLight(scene, "ShowcaseRim", Vector3(0, -0.5, -1), Color(0.75, 0.90, 1), 0.65)

        state.cameraNode = scene:CreateChild("ShowcaseCamera", LOCAL)
        state.camera = assert(state.cameraNode:CreateComponent("Camera", LOCAL), "Camera unavailable")
        state.vehicle = scene:CreateChild("ShowcaseVehicle", LOCAL)
        state.vehicle.enabled = false
        state.geometry = assert(state.vehicle:CreateComponent("CustomGeometry", LOCAL), "CustomGeometry unavailable")
        state.geometry.castShadows = false
        BuildVehicle(state.key)

        local viewport = Viewport:new(scene, state.camera)
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
        ResizeTarget(width or MIN_WIDTH, height or 288)
        state.ready = true
        print("[VehicleShowcase] ready: Forward transparent, adaptive local studio")
    end)
    if not ok then return Fail(reason) end
    return true
end

---@param dt number
---@param visible boolean
---@param vehicleKey string|nil
---@param physicalW number|nil
---@param physicalH number|nil
---@return boolean
function VehicleShowcase.Update(dt, visible, vehicleKey, physicalW, physicalH)
    local wasVisible = state.visible
    state.visible = visible == true
    if not state.visible then
        state.timer = 0
        return not state.failed
    end
    local key = KEYS[vehicleKey or "default"] and (vehicleKey or "default") or "default"
    if not state.ready then state.key = key end
    local width, height = VehicleShowcase.ResolveSize(physicalW, physicalH)
    if not VehicleShowcase.Init(width, height) then return false end
    local ok, reason = pcall(function()
        -- 同次生命周期只升档，避免首页/商店切换和临界尺寸抖动反复分配。
        ResizeTarget(width, height)
        if state.key ~= key then BuildVehicle(key) end
        if not wasVisible then state.dirty = true end
        local elapsed = math.max(0, math.min(dt or 0, 0.25))
        state.phase = (state.phase + elapsed * 0.55) % (math.pi * 2)
        state.timer = state.timer + elapsed
        if not state.dirty and state.timer < FRAME_INTERVAL then return end
        state.yaw = math.sin(state.phase) * 15
        ApplyPose()
        state.surface:QueueUpdate()
        state.updates = state.updates + 1
        state.timer = state.timer % FRAME_INTERVAL
        state.dirty = false
    end)
    if not ok then return Fail(reason) end
    return true
end

--- 在宿主已有 NanoVG 帧内绘制。保留传入 transform/scissor，不创建共享 context。
---@param ctx NVGContextWrapper
---@param x number
---@param y number
---@param w number
---@param h number
---@return boolean
function VehicleShowcase.Draw(ctx, x, y, w, h)
    if not ctx or w <= 0 or h <= 0 or not state.visible or state.failed then return false end
    if not VehicleShowcase.Init() then return false end
    local saved = false
    local ok, reason = pcall(function()
        if state.imageContext and state.imageContext ~= ctx then ReleaseImage() end
        if state.image == 0 then
            state.image = nvgCreateVideo(ctx, state.texture)
            state.imageContext = ctx
            -- 文档失败值为 0；也拒绝旧绑定可能返回的负句柄。
            assert(state.image > 0, "nvgCreateVideo failed")
        end
        -- 目标纹理 16:9 等比 contain，避免宿主展台矩形比例不同把实车拉扁。
        local scale = math.min(w / state.width, h / state.height)
        local dw, dh = state.width * scale, state.height * scale
        local dx, dy = x + (w - dw) * 0.5, y + (h - dh) * 0.5
        nvgSave(ctx)
        saved = true
        nvgIntersectScissor(ctx, x, y, w, h)
        if state.flipY then
            -- 只修 RT 采样的上下方向；车辆 +90° 立正与真实世界光照保持不变。
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

function VehicleShowcase.Shutdown()
    state.visible = false
    ReleaseResources()
    state.failed, state.error, state.key = false, "", "default"
    state.dirty, state.timer, state.phase, state.yaw = true, 0, 0, 0
    state.updates, state.builds, state.vertices, state.orthoSize = 0, 0, 0, 0
    state.flipY = false
    state.width, state.height, state.allocations = 0, 0, 0
    state.allocationBlocked = false
    state.center, state.corners, state.sectionVertices = Vector3(0, 0, 0), {}, {}
end

---@return table
function VehicleShowcase.GetDiagnostics()
    local counts = {}
    for i, count in ipairs(state.sectionVertices) do counts[i] = count end
    return {
        key = state.key, ready = state.ready, failed = state.failed, error = state.error,
        visible = state.visible, image = state.image, imageHandle = state.image,
        updates = state.updates, builds = state.builds, vertices = state.vertices,
        sectionVertices = counts, width = state.width, height = state.height,
        allocations = state.allocations, allocationBlocked = state.allocationBlocked,
        yaw = state.yaw, orthoSize = state.orthoSize,
        renderPath = "EngineRes/RenderPaths/Forward.xml", localScene = state.scene ~= nil,
        flipY = state.flipY, aspectRatio = state.camera and state.camera:GetAspectRatio() or 0,
    }
end

return VehicleShowcase
