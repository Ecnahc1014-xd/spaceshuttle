-- 车辆前方三维弧壳：在 SyncVehicles 后同步，新局删除车辆前 Clear(true)。
-- 局部 +X 为车头、Y 为轮距、-Z 为车顶；批次节点保持世界恒等变换。
-- dt 是允许推进且未乘倍率的玩法时间，暂停/广告冻结传 0；本模块只乘一次 timeScale。
-- 死区读取完整 aim 输入距离，不能从仅移动 0.6 倍的车位反推。
---@class BowWaveMarble
---@field id number
---@field alive boolean
---@field onSling boolean
---@field ballType string
---@field chargeBoosted boolean|nil
---@class BowWaveGame
---@field state string
---@field introTimer number|nil
---@field aiming boolean|nil
---@field aimX number|nil
---@field aimY number|nil
---@field slingX number|nil
---@field slingY number|nil
---@field timeScale number|nil
---@field elapsed number|nil
---@field activeBall BowWaveMarble|nil
---@field marbles BowWaveMarble[]
---@class BowWaveRecord
---@field root Node
---@field geometry CustomGeometry
---@field heading number|nil
---@class BowWaveCarDebug
---@field id number
---@field noseGap number
---@field widthRatio number
---@field anchor Vector3
---@field heading number
---@field headingError number
---@field transforms integer
---@class BowWaveState
---@field node Node|nil
---@field geometry CustomGeometry|nil
---@field material Material|nil
---@field texture Texture2D|nil
---@field colors table<string, number[]>
---@field cars BowWaveCarDebug[]
---@field count integer
---@field vertices integer
---@field phase number
---@field lastElapsed number|nil
---@field clearCalls integer
---@field commits integer
---@field faulted boolean
---@field dirty boolean
---@field firstSubmit boolean
---@type BowWaveState
local S = {
    colors = {},
    cars = {},
    count = 0,
    vertices = 0,
    phase = 0,
    clearCalls = 0,
    commits = 0,
    firstSubmit = false,
    dirty = false,
    faulted = false,
}
local M = {}
local SEGMENTS, MAX_CARS = 16, 8
-- V 形冲击波：中央折角朝车头前方，两翼后掠并展开到车体半宽之外。
local V_DEPTH, V_SPREAD, THICKNESS, HALF_HEIGHT, GAP = 0.34, 1.12, 0.12, 0.05, 0.16
local PER_CAR = SEGMENTS * 24 + 12

-- V 字形冲击波贴图：横截面软边 + 沿波长热核。DiffAlpha 只读纹理 alpha（不读顶点
-- rgb），颜色由 MatDiffColor 承载，故这里是灰阶 + alpha 剖面。
local function CreateBowWaveTexture()
    local N = 64
    local image = Image()
    image:SetSize(N, N, 4)
    for y = 0, N - 1 do
        local v = y / (N - 1)
        local band = math.sin(math.pi * v) ^ 0.7
        local core = math.max(0, 1 - math.abs(v - 0.5) / 0.16) ^ 1.6
        for x = 0, N - 1 do
            local u = x / (N - 1)
            -- 沿 V 长：中央折角最亮，两翼渐弱，叠一条细热核。
            local along = 0.55 + 0.45 * (1 - math.abs(2 * u - 1))
            local a = math.max(0, math.min(1, band * along * 0.85 + core * 0.6))
            local g = 0.55 + 0.45 * core
            image:SetPixel(x, y, Color(g, g, g, a))
        end
    end
    local tex = Texture2D:new()
    tex:SetData(image, false)
    tex:SetSRGB(true)
    return tex
end

---@param x number
---@return boolean
local function Finite(x)
    return x == x and x > -math.huge and x < math.huge
end

---新局默认复位相位；模态调用 Clear(false) 只清弧壳。
---@param resetPhase boolean|nil
function M.Clear(resetPhase)
    if S.node then S.node.enabled = false end
    if S.geometry and S.dirty then
        S.geometry:Clear()
        S.clearCalls = S.clearCalls + 1
    end
    S.count, S.vertices, S.cars, S.dirty = 0, 0, {}, false
    if resetPhase ~= false then
        S.phase, S.lastElapsed = 0, nil
    end
end
function M.Shutdown()
    M.Clear(true)
    -- 仅释放自有父节点，不重复 Dispose 子组件，更不释放借用的车辆。
    if S.node then
        S.node:Remove()
        S.node:Dispose()
    end
    S.node, S.geometry = nil, nil
    if S.material then S.material:Dispose() end
    S.material = nil
    if S.texture then S.texture:Dispose() end
    S.texture = nil
    S.colors, S.firstSubmit = {}, false
end
---@param scene Scene
---@param colors table<string, number[]>|nil 按 ballType 索引的 0..1 RGB 色板。
---@return boolean
function M.Init(scene, colors)
    M.Shutdown()
    local ok, err = pcall(function()
        -- 半透明带纹理：DiffAlpha 只读纹理 alpha，颜色走 MatDiffColor（顶点 rgb 无效）。
        local tech = cache:GetResource("Technique", "Techniques/DiffAlpha.xml")
        assert(tech, "DiffAlpha unavailable")
        S.texture = CreateBowWaveTexture()
        S.material = Material()
        S.material:SetTechnique(0, tech)
        S.material:SetCullMode(CULL_NONE)
        S.material:SetTexture(TU_DIFFUSE, S.texture)
        S.material:SetShaderParameter("MatDiffColor", Variant(Color(1, 1, 1, 0.55)))
        S.node = scene:CreateChild("VehicleBowWave", LOCAL)
        S.node.enabled = false
        S.node:SetWorldTransform(Vector3(0, 0, 0), Quaternion(), Vector3(1, 1, 1))
        S.geometry = S.node:CreateComponent("CustomGeometry", LOCAL)
        assert(S.geometry, "CustomGeometry unavailable")
        S.geometry:SetDynamic(true)
        S.geometry.castShadows = false
        for key, rgb in pairs(colors or {}) do
            assert(#rgb >= 3, "RGB palette requires three channels")
            S.colors[key] = {
                math.max(0, math.min(1, rgb[1])),
                math.max(0, math.min(1, rgb[2])),
                math.max(0, math.min(1, rgb[3])),
            }
        end
    end)
    if not ok then
        print("[VehicleBowWave] Init failed: " .. tostring(err))
        M.Shutdown()
        return false
    end
    S.clearCalls, S.commits, S.faulted = 0, 0, false
    print("[VehicleBowWave] initialized: LOCAL dynamic batch, budget=8/3168")
    return true
end
---@param root Node
---@param box BoundingBox
---@return boolean
local function Valid(root, box)
    if not box:Defined() then return false end
    local lo, hi = box.min, box.max
    for _, n in ipairs({ lo.x, lo.y, lo.z, hi.x, hi.y, hi.z }) do
        if not Finite(n) then return false end
    end
    local hw = math.max(math.abs(lo.y), math.abs(hi.y))
    if hi.x <= lo.x or hi.y <= lo.y or hi.z <= lo.z or hw <= 1e-6 then return false end
    -- 只接受正值等比世界变换；反射、剪切、非等比缩放安全跳过。
    local scale = root:GetSignedWorldScale()
    if scale.x <= 1e-6 or math.abs(scale.x - scale.y) > scale.x * 1e-5 or math.abs(scale.x - scale.z) > scale.x * 1e-5 then return false end
    local o = root:LocalToWorld(Vector3(0, 0, 0))
    local x = root:LocalToWorld(Vector3(1, 0, 0)) - o
    local y = root:LocalToWorld(Vector3(0, 1, 0)) - o
    local z = root:LocalToWorld(Vector3(0, 0, 1)) - o
    local eps = scale.x * scale.x * 1e-5
    return math.abs(x:DotProduct(y)) < eps and math.abs(x:DotProduct(z)) < eps and math.abs(y:DotProduct(z)) < eps and x:CrossProduct(y):DotProduct(z) > 0
end
---@param marble BowWaveMarble
---@param record BowWaveRecord
---@param box BoundingBox
---@return BowWaveCarDebug
local function EmitCar(marble, record, box)
    local geom, root = S.geometry, record.root
    assert(geom)
    local nose = box.max.x
    local hw = math.max(math.abs(box.min.y), math.abs(box.max.y))
    local zc = (box.min.z + box.max.z) * 0.5
    -- V 形中线：中央折角在车头正前 (nose+GAP+depth)，两翼后掠回落到 nose+GAP。
    local halfW = hw * V_SPREAD
    local baseX = nose + GAP
    local tipX = baseX + V_DEPTH
    local rotation = root:GetWorldRotation()
    local axis = rotation * Vector3(1, 0, 0)
    local heading = math.deg(math.atan(axis.y, axis.x))
    local he = record.heading and math.abs((heading - record.heading + 180) % 360 - 180) or 0
    local d = { id = marble.id, noseGap = math.huge, widthRatio = V_SPREAD,
        anchor = root:LocalToWorld(Vector3(tipX, 0, zc)), heading = heading, headingError = he, transforms = 1 } ---@type BowWaveCarDebug
    local rgb = marble.chargeBoosted and { 1.0, 0.72, 0.16 }
        or S.colors[marble.ballType]
    local r1 = rgb and (rgb[1] --[[@as number]]) or 0.24
    local g1 = rgb and (rgb[2] --[[@as number]]) or 0.80
    local b1 = rgb and (rgb[3] --[[@as number]]) or 0.91
    -- 周期位移在车鼻前平滑往返，不改变宽度或进入最小间隙。
    local forward = 0.05 * (1 - math.cos(S.phase * (2 * math.pi / 0.9)))
    local b = Color(r1, g1, b1, 1)
    ---@param s number
    ---@return number
    local function CentreX(s) return baseX + forward + V_DEPTH * (1 - math.abs(s)) end
    ---@param s number
    ---@return Vector3[]
    local function Cross(s)
        local x = CentreX(s)
        return {
            Vector3(x, s * halfW, zc - HALF_HEIGHT),
            Vector3(x + THICKNESS, s * halfW, zc - HALF_HEIGHT),
            Vector3(x + THICKNESS, s * halfW, zc + HALF_HEIGHT),
            Vector3(x, s * halfW, zc + HALF_HEIGHT),
        }
    end
    ---@param s number
    ---@return Vector3[], Vector3[]
    local function Ring(s)
        local p = Cross(s)
        local w = {} ---@type Vector3[]
        for i, v in ipairs(p) do
            d.noseGap = math.min(d.noseGap, v.x - nose)
            w[i] = root:LocalToWorld(v)
            d.transforms = d.transforms + 1
        end
        return p, w
    end
    ---@param a Vector3
    ---@param bb Vector3
    ---@param c Vector3
    ---@param wa Vector3
    ---@param wb Vector3
    ---@param wc Vector3
    ---@param expected Vector3
    ---@param color Color
    local function Triangle(a, bb, c, wa, wb, wc, expected, color)
        if (bb - a):CrossProduct(c - a):DotProduct(expected) < 0 then
            bb, c, wb, wc = c, bb, wc, wb
        end
        local n = (bb - a):CrossProduct(c - a):Normalized()
        local wn = rotation * n
        geom:DefineVertex(wa)
        geom:DefineNormal(wn)
        geom:DefineColor(color)
        geom:DefineTexCoord(Vector2(0, 0))
        geom:DefineVertex(wb)
        geom:DefineNormal(wn)
        geom:DefineColor(color)
        geom:DefineTexCoord(Vector2(1, 0))
        geom:DefineVertex(wc)
        geom:DefineNormal(wn)
        geom:DefineColor(color)
        geom:DefineTexCoord(Vector2(0, 1))
    end
    ---@param p Vector3[]
    ---@param w Vector3[]
    ---@param expected Vector3
    ---@param color Color
    local function Quad(p, w, expected, color)
        Triangle(p[1], p[2], p[3], w[1], w[2], w[3], expected, color)
        Triangle(p[1], p[3], p[4], w[1], w[3], w[4], expected, color)
    end
    -- 沿 s=-1（右翼尖）到 s=+1（左翼尖）铺 V 形带，中点即中央折角。
    local prev, wp = Ring(-1)
    for i = 1, SEGMENTS do
        local s = -1 + i * (2 / SEGMENTS)
        local cur, wc = Ring(s)
        local frontN = Vector3(0, 0, -1)
        Quad({ prev[2], cur[2], cur[3], prev[3] }, { wp[2], wc[2], wc[3], wp[3] }, frontN, b)
        Quad({ prev[1], prev[4], cur[4], cur[1] }, { wp[1], wp[4], wc[4], wc[1] }, Vector3(0, 0, 1), b)
        Quad({ prev[1], cur[1], cur[2], prev[2] }, { wp[1], wc[1], wc[2], wp[2] }, frontN, b)
        Quad({ prev[4], prev[3], cur[3], cur[4] }, { wp[4], wp[3], wc[3], wc[4] }, Vector3(0, 0, 1), b)
        prev, wp = cur, wc
    end
    return d
end
---@param game BowWaveGame
---@param vehicleRecords table<number, BowWaveRecord> 仅本次同步借用，不保留引用。
---@param dt number 未乘倍率的允许推进时间；只在此处乘一次 timeScale。
local function Sync(game, vehicleRecords, dt)
    if S.faulted or not S.geometry or not S.node then return end
    if game.elapsed and S.lastElapsed and game.elapsed < S.lastElapsed then
        M.Clear(true)
    end
    S.lastElapsed = game.elapsed
    if game.state ~= "playing" or (game.introTimer or 0) > 0 then
        M.Clear(false)
        return
    end
    local ts = game.timeScale or 1
    if Finite(dt) and dt > 0 and Finite(ts) and ts > 0 then S.phase = S.phase + dt * ts end
    local chosen = {} ---@type {marble: BowWaveMarble, record: BowWaveRecord, box: BoundingBox}[]
    local seen = {} ---@type table<number, boolean>
    ---@param m BowWaveMarble
    local function Choose(m)
        if #chosen >= MAX_CARS or seen[m.id] or not m.alive then return end
        if m.onSling then
            if not game.aiming or not game.aimX or not game.aimY or not game.slingX or not game.slingY then return end
            local dx, dy = game.aimX - game.slingX, game.aimY - game.slingY
            if not Finite(dx) or not Finite(dy) or dx * dx + dy * dy <= 15 * 15 then return end
        end
        local r = vehicleRecords[m.id]
        if not r or not r.root or not r.geometry then return end
        local box = r.geometry:GetBoundingBox()
        if not Valid(r.root, box) then return end
        seen[m.id] = true
        chosen[#chosen + 1] = { marble = m, record = r, box = box }
    end
    if game.activeBall then Choose(game.activeBall) end
    for _, m in ipairs(game.marbles or {}) do
        Choose(m)
    end
    if #chosen == 0 then
        M.Clear(false)
        return
    end
    S.node.enabled = false
    S.dirty = true
    S.node:SetWorldTransform(Vector3(0, 0, 0), Quaternion(), Vector3(1, 1, 1))
    S.geometry:Clear()
    S.clearCalls = S.clearCalls + 1
    S.geometry:SetNumGeometries(1)
    S.geometry:BeginGeometry(0, TRIANGLE_LIST)
    S.cars = {}
    for _, c in ipairs(chosen) do
        S.cars[#S.cars + 1] = EmitCar(c.marble, c.record, c.box)
    end
    S.geometry:Commit()
    S.geometry:SetMaterial(0, S.material) -- Clear 会清材质槽，每次有效 Commit 后重新绑定。
    S.count, S.vertices = #chosen, #chosen * PER_CAR
    S.commits = S.commits + 1
    S.node.enabled = true
    if not S.firstSubmit then
        print(string.format("[VehicleBowWave] first batch: count=%d vertices=%d", S.count, S.vertices))
        S.firstSubmit = true
    end
end

---@param game BowWaveGame
---@param vehicleRecords table<number, BowWaveRecord>
---@param dt number
---@return boolean
function M.Sync(game, vehicleRecords, dt)
    if S.faulted or not S.geometry or not S.node then return false end
    -- 包含候选读取与构建的整条路径；一次错误后停用，直到下次 Init。
    local ok, err = pcall(Sync, game, vehicleRecords, dt)
    if not ok then
        M.Shutdown()
        S.faulted = true
        print("[VehicleBowWave] Sync failed, disabled until Init: " .. tostring(err))
        return false
    end
    return true
end

---@return table 只返回复制的诊断数值，不泄露借用节点或模块可变表。
function M.Debug()
    local cars = {} ---@type BowWaveCarDebug[]
    for i, d in ipairs(S.cars) do
        cars[i] = { id = d.id, noseGap = d.noseGap, widthRatio = d.widthRatio, anchor = Vector3(d.anchor.x, d.anchor.y, d.anchor.z),
            heading = d.heading, headingError = d.headingError, transforms = d.transforms }
    end
    return { count = S.count, vertices = S.vertices, phase = S.phase, budget = MAX_CARS, vertexBudget = MAX_CARS * PER_CAR, cars = cars,
        enabled = S.node and S.node.enabled or false, material = S.geometry and S.count > 0 and S.geometry:GetMaterial(0) ~= nil or false,
        actualVertices = S.geometry and S.count > 0 and S.geometry:GetNumVertices(0) or 0,
        clearCalls = S.clearCalls, commits = S.commits, initialized = S.node ~= nil, faulted = S.faulted }
end
return M
