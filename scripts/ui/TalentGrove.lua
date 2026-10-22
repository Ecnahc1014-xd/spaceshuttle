-- ui/TalentGrove.lua
-- 天赋树「3D 叶脉大场景」（v0.13.74）：取代原先 540×960 小窗口里的 6×13 圆形卡片列表。
--
-- 造型：中央一根主根（根系），向六个方向长出六条主脉（每条 = 一条天赋线路），
-- 主脉两侧再分出细侧脉（叶脉感）；每条主脉上等距挂 13 个节点（= 13 阶），
-- 节点用面向相机的 billboard + 程序化软光纹理，状态用颜色/大小区分。
--
-- 相机：可拖拽绕行（yaw/pitch）+ ＋/－ 推拉；场景渲染到 RT 后由 NanoVG 贴到整屏，
-- 文字/图标/详情卡继续用 NanoVG 叠画（清晰、无 3D 字体开销）。
--
-- 数据与规则完全复用 TalentCatalog / PlayerData；本模块只读 meta，写操作仍由编排层执行。
local TalentCatalog = require "TalentCatalog"

local TalentGrove = {}

local DESIGN_W, DESIGN_H = 540, 960
local RT_W, RT_H = 768, 768

-- 六条线路的脉色（与现有主题「银白 + 金 + 弹种色」一致）
local LANE_RGB = {
    general_a = { 226, 228, 232, 255 }, -- 成长：银白
    general_b = { 243, 167, 62, 255 },  -- 通用卡：金
    normal    = { 90, 164, 255, 255 },  -- 分裂车：蓝
    ice       = { 120, 220, 255, 255 }, -- 冰冻车：冰蓝
    speed     = { 255, 120, 90, 255 },  -- 加速车：橙红
    giant     = { 176, 120, 255, 255 }, -- 巨型车：紫
}

---@type table|nil MetaUI 依赖（取 C 令牌）
local D = nil

---@class GroveNode
---@field id string
---@field lane string
---@field stage integer
---@field pos Vector3
---@field color table

---@class GroveState
---@field scene Scene|nil
---@field camera Camera|nil
---@field camNode Node|nil
---@field viewport Viewport|nil
---@field surface any|nil
---@field texture Texture2D|nil
---@field image integer
---@field imageCtx any
---@field root Node|nil
---@field branchGeom CustomGeometry|nil
---@field nodeGeom CustomGeometry|nil
---@field nodeKey string
---@field nodeTex Texture2D|nil
---@field nodeImage Image|nil
---@field nodes GroveNode[]
---@field selected string|nil
---@field ownedKey string
---@field yaw number
---@field pitch number
---@field dist number
---@field phase number
---@field built boolean
---@field failed boolean
---@field dragActive boolean
---@field dragMoved boolean
---@field dragX number
---@field dragY number
local S = {
    image = 0, nodes = {}, selected = nil, ownedKey = "",
    yaw = math.rad(-90), pitch = math.rad(80), dist = 42,
    phase = 0, built = false, failed = false,
    dragActive = false, dragMoved = false, dragX = 0, dragY = 0,
} ---@type GroveState

-- ============================================================================
-- 几何 / 场景构建
-- ============================================================================

---三次贝塞尔取点
---@param p0 Vector3
---@param p1 Vector3
---@param p2 Vector3
---@param p3 Vector3
---@param t number
---@return Vector3
local function Bezier(p0, p1, p2, p3, t)
    local u = 1 - t
    local a, b, c, d = u * u * u, 3 * u * u * t, 3 * u * t * t, t * t * t
    return Vector3(
        p0.x * a + p1.x * b + p2.x * c + p3.x * d,
        p0.y * a + p1.y * b + p2.y * c + p3.y * d,
        p0.z * a + p1.z * b + p2.z * c + p3.z * d)
end

---单位二十面体（12 顶点 / 20 面）：节点用真几何，俯视或绕行都有体积，不再是面向相机的贴图。
local ICO_V, ICO_F = nil, nil
local function BuildIcosahedron()
    if ICO_V then return end
    local phi = (1 + math.sqrt(5)) * 0.5
    local raw = {
        { -1, phi, 0 }, { 1, phi, 0 }, { -1, -phi, 0 }, { 1, -phi, 0 },
        { 0, -1, phi }, { 0, 1, phi }, { 0, -1, -phi }, { 0, 1, -phi },
        { phi, 0, -1 }, { phi, 0, 1 }, { -phi, 0, -1 }, { -phi, 0, 1 },
    }
    local out = {}
    for i, v in ipairs(raw) do
        local l = math.sqrt(v[1] * v[1] + v[2] * v[2] + v[3] * v[3])
        out[i] = Vector3(v[1] / l, v[2] / l, v[3] / l)
    end
    ICO_V = out
    ICO_F = {
        { 1, 12, 6 }, { 1, 6, 2 }, { 1, 2, 8 }, { 1, 8, 11 }, { 1, 11, 12 },
        { 2, 6, 10 }, { 6, 12, 5 }, { 12, 11, 3 }, { 11, 8, 7 }, { 8, 2, 9 },
        { 4, 10, 5 }, { 4, 5, 3 }, { 4, 3, 7 }, { 4, 7, 9 }, { 4, 9, 10 },
        { 5, 10, 6 }, { 3, 5, 12 }, { 7, 3, 11 }, { 9, 7, 8 }, { 10, 9, 2 },
    }
end

---水平带状三角形（XZ 平面），a→b 两点，宽 w
---@param geom CustomGeometry
---@param a Vector3
---@param b Vector3
---@param w number
---@param rgb table
---@param alpha integer
local function FlatSegment(geom, a, b, w, rgb, alpha)
    local dx, dz = b.x - a.x, b.z - a.z
    local len = math.sqrt(dx * dx + dz * dz)
    if len < 1e-5 then return end
    local nx, nz = -dz / len * w * 0.5, dx / len * w * 0.5
    local q = {
        Vector3(a.x - nx, a.y, a.z - nz),
        Vector3(a.x + nx, a.y, a.z + nz),
        Vector3(b.x + nx, b.y, b.z + nz),
        Vector3(b.x - nx, b.y, b.z - nz),
    }
    local col = Color(rgb[1], rgb[2], rgb[3], alpha)
    local order = { 1, 2, 3, 1, 3, 4 }
    for k = 1, 6 do
        local v = q[order[k]]
        geom:DefineVertex(v)
        geom:DefineNormal(Vector3(0, 1, 0))
        geom:DefineColor(col)
        geom:DefineTexCoord(Vector2(0, 0))
    end
end

---有厚度的枝条：向上抬起的「扁管」——XZ 平面铺开 + 顶/底两面，绕行时能看出厚度。
---@param geom CustomGeometry
---@param a Vector3
---@param b Vector3
---@param w number
---@param h number
---@param rgb table
---@param alpha integer
local function TubeSegment(geom, a, b, w, h, rgb, alpha)
    local dx, dz = b.x - a.x, b.z - a.z
    local len = math.sqrt(dx * dx + dz * dz)
    if len < 1e-5 then return end
    local nx, nz = -dz / len * w * 0.5, dx / len * w * 0.5
    local y0, y1 = -h * 0.5, h * 0.5
    local col = Color(rgb[1], rgb[2], rgb[3], alpha)
    ---四点截面
    local function Quad(p, n)
        local order = { 1, 2, 3, 1, 3, 4 }
        for k = 1, 6 do
            local v = p[order[k]]
            geom:DefineVertex(v)
            geom:DefineNormal(n)
            geom:DefineColor(col)
            geom:DefineTexCoord(Vector2(0, 0))
        end
    end
    local top = {
        Vector3(a.x - nx, y1, a.z - nz), Vector3(a.x + nx, y1, a.z + nz),
        Vector3(b.x + nx, y1, b.z + nz), Vector3(b.x - nx, y1, b.z - nz),
    }
    local bot = {
        Vector3(a.x - nx, y0, a.z - nz), Vector3(b.x - nx, y0, b.z - nz),
        Vector3(b.x + nx, y0, b.z + nz), Vector3(a.x + nx, y0, a.z + nz),
    }
    Quad(top, Vector3(0, 1, 0))
    Quad(bot, Vector3(0, -1, 0))
    -- 两侧竖面
    local sideA = {
        Vector3(a.x - nx, y0, a.z - nz), Vector3(a.x - nx, y1, a.z - nz),
        Vector3(b.x - nx, y1, b.z - nz), Vector3(b.x - nx, y0, b.z - nz),
    }
    local sideB = {
        Vector3(a.x + nx, y0, a.z + nz), Vector3(b.x + nx, y0, b.z + nz),
        Vector3(b.x + nx, y1, b.z + nz), Vector3(a.x + nx, y1, a.z + nz),
    }
    Quad(sideA, Vector3(-nx / len, 0, -nz / len))
    Quad(sideB, Vector3(nx / len, 0, nz / len))
end

---环形带（底盘刻度用）
---@param geom CustomGeometry
---@param r0 number
---@param r1 number
---@param rgb table
---@param alpha integer
---@param segs integer|nil
local function Ring(geom, r0, r1, rgb, alpha, segs)
    local n = segs or 96
    local col = Color(rgb[1], rgb[2], rgb[3], alpha)
    for i = 0, n - 1 do
        local a0 = i / n * math.pi * 2
        local a1 = (i + 1) / n * math.pi * 2
        local c0, s0 = math.cos(a0), math.sin(a0)
        local c1, s1 = math.cos(a1), math.sin(a1)
        local q = {
            Vector3(c0 * r0, 0, s0 * r0),
            Vector3(c1 * r0, 0, s1 * r0),
            Vector3(c1 * r1, 0, s1 * r1),
            Vector3(c0 * r1, 0, s0 * r1),
        }
        local order = { 1, 2, 3, 1, 3, 4 }
        for k = 1, 6 do
            local v = q[order[k]]
            geom:DefineVertex(v)
            geom:DefineNormal(Vector3(0, 1, 0))
            geom:DefineColor(col)
            geom:DefineTexCoord(Vector2(0, 0))
        end
    end
end

---星盘底盘：同心刻度环 + 外圈 48 格刻度 + 中心金核（全部在 y=0 的平面）。
---@param geom CustomGeometry
---@param outer number
local function BuildBase(geom, outer)
    Ring(geom, outer * 0.020, outer * 0.030, { 243, 167, 62 }, 220, 40)
    Ring(geom, outer * 0.030, outer * 0.044, { 243, 167, 62 }, 90, 40)
    Ring(geom, outer * 0.30, outer * 0.305, { 150, 152, 158 }, 90)
    Ring(geom, outer * 0.62, outer * 0.624, { 150, 152, 158 }, 70)
    Ring(geom, outer * 0.90, outer * 0.904, { 150, 152, 158 }, 60)
    Ring(geom, outer * 0.985, outer, { 226, 228, 232 }, 130)
    for i = 0, 47 do
        local a = i / 48 * math.pi * 2
        local long = (i % 4 == 0)
        local r0 = outer * (long and 0.90 or 0.94)
        local r1 = outer * 0.985
        FlatSegment(geom, Vector3(math.cos(a) * r0, 0, math.sin(a) * r0),
            Vector3(math.cos(a) * r1, 0, math.sin(a) * r1),
            outer * (long and 0.008 or 0.005), { 226, 228, 232 }, long and 150 or 90)
    end
end

---六条线路的「分叉枝条」路径：内段沿放射方向，外段分叉偏转，节点沿整条路径等距。
---@param laneIndex integer
---@param lanes integer
---@param rInner number
---@param rFork number
---@param rOuter number
---@return Vector3[] waypoints
local function LanePath(laneIndex, lanes, rInner, rFork, rOuter)
    local base = (laneIndex - 1) / lanes * math.pi * 2 - math.pi * 0.5
    local fork = ((laneIndex % 2 == 0) and 1 or -1) * math.rad(17)
    local a0, a1 = base, base + fork
    return {
        Vector3(math.cos(a0) * rInner, 0, math.sin(a0) * rInner),
        Vector3(math.cos(a0) * rFork, 0, math.sin(a0) * rFork),
        Vector3(math.cos(a1) * (rFork + (rOuter - rFork) * 0.55), 0, math.sin(a1) * (rFork + (rOuter - rFork) * 0.55)),
        Vector3(math.cos(a1) * rOuter, 0, math.sin(a1) * rOuter),
    }
end

---沿折线取点（按累计长度等距重采样）。
---@param pts Vector3[]
---@param t number 0..1
---@return Vector3
local function AlongPath(pts, t)
    local total = 0
    local lens = {}
    for i = 2, #pts do
        local d = (pts[i] - pts[i - 1])
        local l = math.sqrt(d.x * d.x + d.z * d.z)
        lens[i] = l
        total = total + l
    end
    local target = total * math.max(0, math.min(1, t))
    local acc = 0
    for i = 2, #pts do
        local l = lens[i]
        if acc + l >= target or i == #pts then
            local u = l > 1e-6 and (target - acc) / l or 0
            return pts[i - 1] + (pts[i] - pts[i - 1]) * u
        end
        acc = acc + l
    end
    return pts[#pts]
end

---@return boolean
local function Build()
    if S.built then return not S.failed end
    local errMsg = nil
    local ok
    ok, errMsg = pcall(function()
        local scene = Scene()
        S.scene = scene
        assert(scene:CreateComponent("Octree", LOCAL), "Octree unavailable")
        -- 必须有 Zone：没有 Zone 时 Forward 渲染路径可能整体跳过，RT 会保留上一帧内容（花屏）。
        local zoneNode = scene:CreateChild("GroveZone", LOCAL)
        local zone = assert(zoneNode:CreateComponent("Zone", LOCAL), "Zone unavailable")
        zone.boundingBox = BoundingBox(-80, 80)
        zone.ambientSource = AMBIENT_COLOR
        zone.ambientColor = Color(0.34, 0.36, 0.40)
        zone.fogDensity = 0
        zone.heightFog = false

        local camNode = scene:CreateChild("GroveCamera", LOCAL)
        S.camNode = camNode
        local camera = assert(camNode:CreateComponent("Camera", LOCAL), "Camera unavailable")
        S.camera = camera
        camera.fov = 38
        camera.nearClip = 0.5
        camera.farClip = 90

        -- 无光照管线 + 顶点色；背景透明，靠 NanoVG 底图透出来。
        -- 方向光：整体几何（底盘/枝条/节点）用带光照的 DiffVCol，靠明暗出体积。

        local lightNode = scene:CreateChild("GroveLight", LOCAL)
        lightNode.direction = Vector3(-0.35, -1.0, 0.45)
        local light = assert(lightNode:CreateComponent("Light", LOCAL), "Light unavailable")
        light.lightType = LIGHT_DIRECTIONAL
        light.color = Color(0.95, 0.97, 1.0, 1.0)
        light.brightness = 0.85

        local root = scene:CreateChild("GroveRoot", LOCAL)
        S.root = root


        -- 节点几何（二十面体，带光照）
        local nodeLitMat = Material:new()
        local nodeTech = assert(cache:GetResource("Technique", "Techniques/DiffVCol.xml"), "DiffVCol unavailable")
        nodeLitMat:SetTechnique(0, nodeTech)
        nodeLitMat:SetShaderParameter("MatDiffColor", Variant(Color(1, 1, 1, 1)))
        local nodeGeomNode = root:CreateChild("GroveNodes", LOCAL)
        local nodeGeom = assert(nodeGeomNode:CreateComponent("CustomGeometry", LOCAL), "CustomGeometry unavailable")
        nodeGeom.castShadows = false
        S.nodeGeom = nodeGeom
        S.nodeMat = nodeLitMat
        BuildIcosahedron()

        -- v0.13.76：星盘底盘 + 六条**分叉枝条**（内段放射、外段偏转），13 阶沿枝条等距。
        local lanes = TalentCatalog.LANES
        local stageCount = TalentCatalog.MAX_STAGE
        local R_INNER, R_FORK, R_OUTER = 1.9, 7.4, 12.2
        -- 枝条几何统一在 UpdateNodes 阶段重建（那里 Commit→SetMaterial 的绑定路径已验证生效）。
        S.rOuter, S.paths, S.branchBuilt = R_OUTER, {}, false
        local nodes = {}
        for i, lane in ipairs(lanes) do
            local rgb = LANE_RGB[lane] or LANE_RGB.normal
            local path = LanePath(i, #lanes, R_INNER, R_FORK, R_OUTER)
            S.paths[i] = { path = path, rgb = rgb }
            -- 13 阶节点沿枝条等距
            local laneNodes = TalentCatalog.GetLaneNodes(lane)
            for stage = 1, stageCount do
                local node = laneNodes[stage]
                if node then
                    local t = (stage - 1) / math.max(1, stageCount - 1)
                    local p = AlongPath(path, t)
                    nodes[#nodes + 1] = {
                        id = node.id, lane = lane, stage = stage,
                        pos = Vector3(p.x, 0.30, p.z), color = rgb,
                    }
                end
            end
        end
        S.nodes = nodes

        -- RT + viewport（透明底）
        local forward = assert(cache:GetResource("XMLFile", "EngineRes/RenderPaths/Forward.xml"), "Forward.xml missing")
        local viewport = Viewport:new(scene, camera)
        S.viewport = viewport
        viewport:SetRenderPath(forward)
        local path = viewport:GetRenderPath()
        for i = 0, path:GetNumCommands() - 1 do
            local command = path:GetCommand(i)
            if command.type == CMD_CLEAR then
                command.useFogColor = false
                command.clearColor = Color(0, 0, 0, 0)
                path:SetCommand(i, command)
            end
        end
        local tex = Texture2D:new()
        tex:SetNumLevels(1)
        assert(tex:SetSize(RT_W, RT_H, Graphics:GetRGBAFormat(), TEXTURE_RENDERTARGET), "RT allocation failed")
        tex:SetFilterMode(FILTER_BILINEAR)
        S.texture = tex
        local surface = assert(tex:GetRenderSurface(), "RT surface unavailable")
        S.surface = surface
        surface:SetViewport(0, viewport)
        surface:SetUpdateMode(SURFACE_MANUALUPDATE)
        S.built = true
    end)
    if not ok then
        S.failed = true
        print("[TalentGrove] build failed: " .. tostring(errMsg))
    end
    return not S.failed
end

-- ============================================================================
-- 相机 / 节点状态
-- ============================================================================

local function UpdateCamera()
    if not (S.camNode and S.camera) then return end
    local center = Vector3(0, 0, 0)
    -- 星盘要「俯视」：pitch 限制在 52°~88°（接近正俯视，允许轻微倾斜看厚度）
    local pitch = math.max(math.rad(52), math.min(math.rad(88), S.pitch))
    local yaw = S.yaw
    local dist = math.max(18, math.min(70, S.dist))
    local x = center.x + dist * math.cos(pitch) * math.cos(yaw)
    local y = center.y + dist * math.sin(pitch)
    local z = center.z + dist * math.cos(pitch) * math.sin(yaw)
    S.camNode.position = Vector3(x, y, z)
    S.camNode:LookAt(center)
end

---在调用方已经 BeginGeometry 的缓冲里追加：底盘刻度 + 六条分叉枝条。
local function RebuildBranches()
    local geom = S.nodeGeom
    if not geom then return end
    local outer = S.rOuter or 12.2
    BuildBase(geom, outer)
    for _, entry in ipairs(S.paths or {}) do
        local segs = 18
        for i = 1, segs do
            local a = AlongPath(entry.path, (i - 1) / segs)
            local b = AlongPath(entry.path, i / segs)
            local w = 0.40 - 0.22 * ((i - 1) / segs)
            local c = entry.rgb
            TubeSegment(geom, Vector3(a.x, 0.10, a.z), Vector3(b.x, 0.10, b.z), w, 0.14,
                { c[1] * 0.55, c[2] * 0.55, c[3] * 0.55 }, 235)
        end
    end
    S.branchBuilt = true
end

---节点几何：78 个二十面体，状态变化时才重建（颜色/大小由 owned/可解锁决定）。
---@param meta table
local function UpdateNodes(meta)
    local geom = S.nodeGeom
    if not geom then return end
    local talents = meta.talents or {}
    local unlockedStage = meta.talentStageCount or 0
    local parts = meta.parts or 0
    local ownedCount = 0
    for _ in pairs(talents) do ownedCount = ownedCount + 1 end
    -- 只在「已解锁数量 / 开放阶段 / 零件档次」变化时重建，避免每帧上传顶点。
    local key = string.format("%d|%d|%d", ownedCount, unlockedStage, math.floor(parts / 200))
    if key == S.nodeKey then return end
    S.nodeKey = key

    local pulse = 0.80 + 0.20 * math.abs(math.sin(S.phase * 1.6))
    geom:Clear()
    geom:SetNumGeometries(1)
    geom:BeginGeometry(0, TRIANGLE_LIST)
    -- 底盘 + 枝条 + 节点一起写进同一个几何（同材质、同一次 Commit）：
    -- 第二套 CustomGeometry 的材质绑定在本引擎里不生效，合并后彻底避免。
    RebuildBranches()
    for _, node in ipairs(S.nodes) do
        local owned = talents[node.id] == true
        local canUnlock = false
        if not owned and node.stage <= unlockedStage then
            local prevOwned = (node.stage == 1)
                or talents[TalentCatalog.GetLaneNodes(node.lane)[node.stage - 1].id] == true
            local cost = (TalentCatalog.GetNode(node.id) or {}).cost or math.huge
            canUnlock = prevOwned and parts >= cost
        end
        local radius, bright
        if owned then
            radius, bright = 0.40, 1.00
        elseif canUnlock then
            radius, bright = 0.34, pulse
        else
            radius, bright = 0.24, 0.42
        end
        local c = node.color
        local col = Color(
            math.min(1, c[1] / 255 * bright),
            math.min(1, c[2] / 255 * bright),
            math.min(1, c[3] / 255 * bright), 1)
        -- 二十面体：20 个面，法线用平滑径向法线（俯视/绕行都有体积）
        for _, face in ipairs(ICO_F) do
            for k = 1, 3 do
                local v = ICO_V[face[k]]
                geom:DefineVertex(node.pos + v * radius)
                geom:DefineNormal(v)
                geom:DefineColor(col)
                geom:DefineTexCoord(Vector2(0, 0))
            end
        end
    end
    geom:Commit()
    -- ⚠️ CustomGeometry:Clear() 会清掉材质槽（AB-168），重建后必须重绑，否则整批变默认白材质。
    if S.nodeMat then geom:SetMaterial(0, S.nodeMat) end
end

-- ============================================================================
-- 绘制
-- ============================================================================

---@param ctx any
---@param x number
---@param y number
---@param text string
---@param size number
---@param color table
---@param align integer|nil
local function Text(ctx, x, y, text, size, color, align)
    nvgFontSize(ctx, size)
    nvgTextAlign(ctx, align or (NVG_ALIGN_LEFT + NVG_ALIGN_TOP))
    nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
    nvgText(ctx, x, y, tostring(text))
end

---@param meta table
---@return string|nil
local function SelectedNodeId(meta)
    return S.selected
end

--- 详情卡几何（绘制与命中共用）
---@param w number
---@return table card
---@return table btn
local function GetDetailLayout(w)
    local card = { x = 18, y = DESIGN_H - 188, w = w - 36, h = 170 }
    local btn = { x = card.x + card.w - 148, y = card.y + card.h - 60, w = 130, h = 44 }
    return card, btn
end

local function GetZoomLayout(w)
    local size = 38
    return {
        inBtn = { x = w - 56, y = DESIGN_H - 300, w = size, h = size },
        outBtn = { x = w - 56, y = DESIGN_H - 254, w = size, h = size },
    }
end

---@param uiX number
---@param uiY number
---@param w number
---@return Vector2|nil nx, ny  (归一化 0..1) 或 nil
local function ProjectNode(node, w)
    if not (S.camera and S.texture) then return nil end
    local ok, sp = pcall(function() return S.camera:WorldToScreenPoint(node.pos) end)
    if not ok or not sp then return nil end
    local nx, ny = sp.x / RT_W, sp.y / RT_H
    if nx < -0.2 or nx > 1.2 or ny < -0.2 or ny > 1.2 then return nil end
    return Vector2(nx, ny)
end

-- v0.13.74：RT 渲染必须在**游戏更新阶段**做（NanoVG 绘制通道里创建/更新 render target
-- 会让目标缓冲仍然指向主帧，贴出来是上一帧画面碎片）。Draw 只负责把已有纹理贴上去。
---@param dt number
---@param visible boolean
---@param meta table|nil
function TalentGrove.Update(dt, visible, meta)
    S.visible = visible == true
    if not S.visible then return end
    if S.failed then return end
    if not Build() then return end
    S.phase = S.phase + math.max(0, math.min(dt or 0, 0.1))
    UpdateCamera()
    if meta then UpdateNodes(meta) end
    if S.surface then
        pcall(function() S.surface:QueueUpdate() end)
    end
end

---@param ctx any
---@param w number
---@param meta table
function TalentGrove.Draw(ctx, w, meta)
    if S.failed then return end
    if not Build() then return end
    local C = (D and D.C) or {
        bg = { 9, 10, 13, 255 }, panel = { 14, 15, 19, 255 }, card = { 24, 25, 31, 255 },
        cyan = { 226, 228, 232, 255 }, cyanDim = { 150, 152, 158, 220 },
        text = { 242, 239, 234, 255 }, dim = { 148, 147, 145, 255 },
        warn = { 243, 167, 62, 255 }, ink = { 5, 5, 7, 255 },
    }
    local function tx(x, y, str, size, color, align)
        if D and D.text then
            D.text(ctx, x, y, str, size, color, align)
        else
            nvgFontSize(ctx, size)
            nvgTextAlign(ctx, align or (NVG_ALIGN_LEFT + NVG_ALIGN_TOP))
            nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
            nvgText(ctx, x, y, tostring(str))
        end
    end

    -- ① 与全游戏一致的深海军底 + 微网格（不再是纯黑大黑块）
    local g = nvgLinearGradient(ctx, 0, 0, w * 0.6, DESIGN_H,
        nvgRGBA(12, 17, 27, 255), nvgRGBA(5, 7, 12, 255))
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, w, DESIGN_H)
    nvgFillPaint(ctx, g)
    nvgFill(ctx)
    if D and D.grid then D.grid(ctx, 0, 0, w, DESIGN_H, 46, 20) end

    -- ② 窗口壳 + 像素字标题（和任务/商店/天赋旧面板同一套外壳）
    local shellX, shellY, shellW = 16, 92, w - 32
    local shellH = DESIGN_H - shellY - 16
    if D and D.shell then
        D.shell(ctx, shellX, shellY, shellW, shellH, 46)
    else
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, shellX, shellY, shellW, shellH, 10)
        nvgFillColor(ctx, nvgRGBA(14, 15, 19, 240))
        nvgFill(ctx)
    end
    tx(shellX + 16, shellY + 12, "天赋星盘", 20, C.text)
    tx(shellX + 16, shellY + 38, string.format("已解锁 %d/%d · 已开放 %d/%d 阶 · 星级 %d",
        meta and meta.talentCount or 0, meta and meta.talentTotal or 0,
        meta and meta.talentStageCount or 0, meta and meta.talentMaxStage or 0,
        meta and meta.totalStars or 0), 12, C.dim)
    if D and D.rule then
        D.rule(ctx, shellX + 16, shellY + 58, shellW - 32, 10, C.cyanDim, 6)
    end
    if D and D.corner then
        D.corner(ctx, shellX + 4, shellY + 4, shellW - 8, shellH - 8, C.cyanDim, 16, 1.2)
    end

    -- ③ 星盘 RT：裁进窗口内容区（顶部 66 给标题，底部 190 给详情卡）
    local viewX, viewY = shellX + 2, shellY + 66
    local viewW, viewH = shellW - 4, shellH - 66 - 8
    -- 方形 RT 等比居中（拉伸会把圆盘压成椭圆）
    local side = math.min(viewW, viewH)
    local drawX = viewX + (viewW - side) * 0.5
    local drawY = viewY + (viewH - side) * 0.5
    S.drawRect = { x = drawX, y = drawY, w = side, h = side }
    if S.texture then
        if S.image == 0 then
            local ok, img = pcall(nvgCreateVideo, ctx, S.texture)
            if ok and type(img) == "number" and img > 0 then S.image, S.imageCtx = img, ctx else S.image = -1 end
        end
        if S.image > 0 then
            nvgSave(ctx)
            nvgIntersectScissor(ctx, viewX, viewY, viewW, viewH)
            nvgBeginPath(ctx)
            nvgRect(ctx, drawX, drawY, side, side)
            nvgFillPaint(ctx, nvgImagePattern(ctx, drawX, drawY, side, side, 0, S.image, 1))
            nvgFill(ctx)
            nvgRestore(ctx)
        end
    end

    -- ④ 线路名（贴在每条枝条末端，用像素字）
    for _, lane in ipairs(TalentCatalog.LANES) do
        local laneNodes = TalentCatalog.GetLaneNodes(lane)
        local lastNode = nil
        for _, node in ipairs(S.nodes) do
            if node.lane == lane and node.stage == #laneNodes then lastNode = node end
        end
        if lastNode then
            local p = ProjectNode(lastNode, w)
            if p then
                local rgb = LANE_RGB[lane] or LANE_RGB.normal
                local sx = drawX + p.x * side
                local sy = drawY + p.y * side + 18
                if sy > viewY and sy < viewY + viewH - 8 then
                    tx(sx, sy, TalentCatalog.LANE_NAMES[lane] or lane, 11,
                        { rgb[1], rgb[2], rgb[3], 200 }, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
                end
            end
        end
    end

    -- ⑤ 关闭 + 缩放（同一套小方按钮语言）
    local function smallButton(x, y, label, hot)
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, x, y, 34, 34, 7)
        nvgFillColor(ctx, nvgRGBA(C.card[1], C.card[2], C.card[3], 240))
        nvgFill(ctx)
        nvgStrokeColor(ctx, hot and nvgRGBA(C.warn[1], C.warn[2], C.warn[3], 190)
            or nvgRGBA(C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 140))
        nvgStrokeWidth(ctx, 1.1)
        nvgStroke(ctx)
        tx(x + 17, y + 8, label, 17, C.text, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
    local close = { x = shellX + shellW - 44, y = shellY + 8, w = 34, h = 34 }
    smallButton(close.x, close.y, "×", false)
    local zoom = GetZoomLayout(w)
    smallButton(zoom.inBtn.x, zoom.inBtn.y, "+", false)
    smallButton(zoom.outBtn.x, zoom.outBtn.y, "−", false)
    S.zoomIn, S.zoomOut, S.closeRect = zoom.inBtn, zoom.outBtn, close

    -- ⑥ 详情卡（沿用同一套 panel + 金/银语义）
    local nodeId = SelectedNodeId(meta)
    local node = nodeId and TalentCatalog.GetNode(nodeId) or nil
    if node then
        local card, btn = GetDetailLayout(w)
        if D and D.panel then
            D.panel(ctx, card.x, card.y, card.w, card.h, { 20, 21, 26, 244 }, C.cyanDim, 10)
        else
            nvgBeginPath(ctx)
            nvgRoundedRect(ctx, card.x, card.y, card.w, card.h, 10)
            nvgFillColor(ctx, nvgRGBA(20, 21, 26, 244))
            nvgFill(ctx)
        end
        local laneRgb = LANE_RGB[node.lane] or LANE_RGB.normal
        nvgBeginPath(ctx)
        nvgRect(ctx, card.x + 14, card.y + 14, 3, 24)
        nvgFillColor(ctx, nvgRGBA(laneRgb[1], laneRgb[2], laneRgb[3], 210))
        nvgFill(ctx)
        tx(card.x + 26, card.y + 12, node.name or node.id, 17, C.text)
        tx(card.x + 26, card.y + 38, string.format("%s · 第 %d 阶 · %d 零件",
            TalentCatalog.LANE_NAMES[node.lane] or node.lane, node.stage, node.cost or 0),
            11, C.dim)
        tx(card.x + 26, card.y + 60, node.desc or "", 12, { 196, 196, 192, 255 })
        local owned = meta and meta.talents and meta.talents[node.id] == true
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, btn.x, btn.y, btn.w, btn.h, 8)
        nvgFillColor(ctx, owned and nvgRGBA(40, 41, 47, 245)
            or nvgRGBA(C.warn[1], C.warn[2], C.warn[3], 235))
        nvgFill(ctx)
        tx(btn.x + btn.w * 0.5, btn.y + 11, owned and "已解锁" or "解锁", 16,
            owned and C.dim or C.ink, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    else
        S.closeRect = close
    end
end

-- ============================================================================
-- 命中
-- ============================================================================

---@param uiX number
---@param uiY number
---@param w number
---@param meta table
---@return string|nil action
---@return string|nil index
function TalentGrove.HitTest(uiX, uiY, w, meta)
    if S.failed or not S.built then return nil, nil end
    -- 关闭（矩形由 Draw 写入，保证绘制与命中同源）
    local close = S.closeRect or { x = w - 50, y = 22, w = 34, h = 34 }
    if uiX >= close.x and uiX <= close.x + close.w and uiY >= close.y and uiY <= close.y + close.h then
        return "close", nil
    end
    -- 缩放（就地改状态，返回占位 action 只用于吞掉这次点击）
    local zoom = GetZoomLayout(w)
    if S.zoomIn then zoom.inBtn = S.zoomIn ; zoom.outBtn = S.zoomOut end
    for _, pair in ipairs({ { zoom.inBtn, -1.6 }, { zoom.outBtn, 1.6 } }) do
        local r, delta = pair[1], pair[2]
        if uiX >= r.x and uiX <= r.x + r.w and uiY >= r.y and uiY <= r.y + r.h then
            S.dist = math.max(18, Math and 18 or 18, math.min(70, S.dist + delta))
            return "__zoom", nil
        end
    end
    -- 详情卡按钮
    local nodeId = SelectedNodeId(meta)
    if nodeId then
        local card, btn = GetDetailLayout(w)
        if uiX >= btn.x and uiX <= btn.x + btn.w and uiY >= btn.y and uiY <= btn.y + btn.h then
            local owned = meta and meta.talents and meta.talents[nodeId] == true
            if owned then return nil, nil end
            return "unlock_talent", nodeId
        end
        if uiX >= card.x and uiX <= card.x + card.w and uiY >= card.y and uiY <= card.y + card.h then
            return nil, nil -- 详情卡内部吞掉，不穿透
        end
    end
    -- 节点：屏幕最近命中（半径 30 设计像素）
    local bestId, bestDist = nil, 30 * 30
    for _, node in ipairs(S.nodes) do
        local p = ProjectNode(node, w)
        if p then
            local sx, sy = p.x * w, p.y * DESIGN_H
            local dx, dy = uiX - sx, uiY - sy
            local d2 = dx * dx + dy * dy
            if d2 < bestDist then bestId, bestDist = node.id, d2 end
        end
    end
    if bestId then
        S.selected = bestId
        return "select_talent", bestId
    end
    -- 点空白：取消选中（并吞掉）
    S.selected = nil
    return nil, nil
end

-- ============================================================================
-- 相机拖拽（编排层转发）
-- ============================================================================

---@param uiX number
---@param uiY number
---@param w number
---@return boolean consumed
function TalentGrove.ScrollBegin(uiX, uiY, w)
    if uiY < 90 or uiY > DESIGN_H - 200 then return false end
    S.dragActive, S.dragMoved = true, false
    S.dragX, S.dragY = uiX, uiY
    return true
end

---@param uiX number
---@param uiY number
---@param w number
function TalentGrove.ScrollMove(uiX, uiY, w)
    if not S.dragActive then return end
    local dx, dy = uiX - S.dragX, uiY - S.dragY
    if not S.dragMoved and (dx * dx + dy * dy) > 36 then S.dragMoved = true end
    if not S.dragMoved then return end
    S.yaw = S.yaw + dx * 0.006
    S.pitch = math.max(math.rad(52), math.min(math.rad(88), S.pitch - dy * 0.004))
    S.dragX, S.dragY = uiX, uiY
end

---@return boolean moved 是否真的拖动过（true 时编排层吞掉这次点击）
function TalentGrove.ScrollEnd()
    local moved = S.dragMoved
    S.dragActive, S.dragMoved = false, false
    return moved
end

---@return boolean
function TalentGrove.IsDragging()
    return S.dragActive and S.dragMoved
end

---@param id string|nil
function TalentGrove.SetSelected(id)
    S.selected = id
end

---@return string|nil
function TalentGrove.GetSelected()
    return S.selected
end

---@param deps table
function TalentGrove.Init(deps)
    D = deps
end

function TalentGrove.Shutdown()
    if S.image and S.image > 0 and S.imageCtx then pcall(nvgDeleteVideo, S.imageCtx, S.image) end
    S.image = 0
    S.imageCtx = nil
    if S.texture then pcall(function() S.texture:Dispose() end) end
    S.texture, S.surface = nil, nil
    if S.scene then pcall(function()
        local scene = S.scene
        scene = nil
    end) end
    S.scene, S.camera, S.camNode = nil, nil, nil
    S.built = false
end

return TalentGrove
