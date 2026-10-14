-- 附魔环绕球（可选表现模块）。基于 VehicleBowWave 的 LOCAL 批次/生命周期脚手架，
-- 以及 Renderer3D 的附魔稀有度、烘焙透明纹理路径；不修改玩法或借用的车辆。
-- 宿主须在车辆同步后调用 Sync；删除车辆/新局前 Clear(true)，销毁场景前 Shutdown。
-- dt 是允许推进、未乘 timeScale 的玩法时间：广告传 0；模块只乘一次倍率。
-- 每车严格 3 个实体球 + 各 1 个同心软光，无轨道装饰、拖尾或额外卫星。
---@class EnchantOrbMarble
---@field id number
---@field alive boolean
---@field onSling boolean|nil
---@field radius number
---@field enchant {rarity: string|nil}|nil
---@class EnchantOrbGame
---@field state string
---@field introTimer number|nil
---@field elapsed number|nil
---@field timeScale number|nil
---@field activeBall EnchantOrbMarble|nil
---@field marbles EnchantOrbMarble[]|nil
---@class EnchantOrbRecord
---@field root Node
---@class EnchantOrbCar
---@field id number
---@field rarity string
---@field anchor Vector3
---@field orbitRadius number
---@field sphereRadius number
---@field spin number
---@field centers Vector3[]
---@class EnchantOrbBatch
---@field rarity string
---@field node Node|nil
---@field geometry CustomGeometry|nil
---@field halo BillboardSet|nil
---@field material Material|nil
---@field haloMaterial Material|nil
---@field texture Texture2D|nil
---@field image Image|nil 临时烘焙资源也登记，失败时不会丢失所有权。
---@field dirty boolean
---@field count integer
---@field vertices integer
---@field commits integer
---@field haloCommits integer
---@class EnchantOrbState
---@field batches table<string, EnchantOrbBatch>
---@field unitMesh Vector3[]
---@field cars EnchantOrbCar[]
---@field phase number
---@field lastElapsed number|nil
---@field initialized boolean
---@field faulted boolean
---@field lastError string
local S = { batches = {}, unitMesh = {}, cars = {}, phase = 0,
    initialized = false, faulted = false, lastError = "" } ---@type EnchantOrbState
local M = {}
local MAX_CARS, ORBS_PER_CAR = 4, 3
local MAX_ORBS = MAX_CARS * ORBS_PER_CAR
local SLICES, LATITUDES = 12, 6
local VERTICES_PER_ORB = 6 * SLICES * (LATITUDES - 1) -- 120 三角面/360 顶点。
local TAU, ANGULAR_SPEED = 2 * math.pi, 2.6
local ORBIT_FACTOR, SPHERE_FACTOR, HALO_FACTOR = 0.018 * 1.5, 0.115, 2.2
local TILT = math.rad(32)
local RARITIES = { "common", "rare", "epic" }
local COLORS = { -- 沿用现有蓝/紫/黄金，不按弹种或列表位置改色。
    common = { 0.36, 0.59, 1.00 }, rare = { 0.69, 0.43, 1.00 }, epic = { 1.00, 0.77, 0.28 },
} ---@type table<string, number[]>

---@param x number
---@return boolean
local function Finite(x)
    return x == x and x > -math.huge and x < math.huge
end

---@param v Vector3
---@return Vector3
local function CopyVector(v)
    return Vector3(v.x, v.y, v.z)
end

---清理失败不阻止其它自有资源释放；不 Dispose cache 返回的借用 Technique。
---@param action fun()
local function Cleanup(action)
    local ok, err = pcall(action)
    if not ok then
        S.faulted = true
        S.lastError = tostring(err)
        print("[VehicleEnchantOrbs] cleanup failed: " .. S.lastError)
    end
end

---@param b EnchantOrbBatch
local function Hide(b)
    if b.node then b.node.enabled = false end
    if b.geometry and b.dirty then b.geometry:Clear() end
    -- 不提交 0 顶点几何，也不 Commit 全关闭的 billboard；节点禁用即隐藏。
    if b.halo and b.count > 0 then
        for i = 0, MAX_ORBS - 1 do b.halo:GetBillboard(i).enabled = false end
    end
    b.count, b.vertices, b.dirty = 0, 0, false
end

---模态 Clear(false) 隐藏但保留相位；新局/Shutdown 默认复位。
---@param resetPhase boolean|nil
function M.Clear(resetPhase)
    for _, b in pairs(S.batches) do Cleanup(function() Hide(b) end) end
    S.cars = {}
    if resetPhase ~= false then S.phase, S.lastElapsed = 0, nil end
end

function M.Shutdown()
    S.initialized = false
    M.Clear(true)
    for _, b in pairs(S.batches) do
        -- 父节点拥有两个组件，只释放父节点，绝不重复 Dispose 子组件。
        if b.node then
            local node = b.node
            Cleanup(function() node:Remove() end)
            Cleanup(function() node:Dispose() end)
        end
        if b.material then
            local mat = b.material
            Cleanup(function() mat:Dispose() end)
        end
        if b.haloMaterial then
            local mat = b.haloMaterial
            Cleanup(function() mat:Dispose() end)
        end
        if b.texture then
            local texture = b.texture
            Cleanup(function() texture:Dispose() end)
        end
        if b.image then
            local image = b.image
            Cleanup(function() image:Dispose() end)
        end
    end
    S.batches, S.unitMesh = {}, {}
end

---@param reason string
local function Fault(reason)
    M.Shutdown()
    S.faulted, S.lastError = true, reason
    print("[VehicleEnchantOrbs] disabled until Init: " .. reason)
end

---单位球缓存只存值，不持有引擎资源。显式极帽，禁止提交退化三角形。
local function BuildUnitSphere()
    local mesh = {} ---@type Vector3[]
    ---@param latitude integer
    ---@param longitude integer
    ---@return Vector3
    local function Point(latitude, longitude)
        if latitude == 0 then return Vector3(0, 1, 0) end
        if latitude == LATITUDES then return Vector3(0, -1, 0) end
        local theta, phi = latitude * math.pi / LATITUDES, longitude * TAU / SLICES
        return Vector3(math.sin(theta) * math.cos(phi), math.cos(theta), math.sin(theta) * math.sin(phi))
    end
    ---@param a Vector3
    ---@param b Vector3
    ---@param c Vector3
    local function Triangle(a, b, c)
        -- 正面朝外；平滑径向法线保留小球高光，不用双面掩盖绕序错误。
        if (b - a):CrossProduct(c - a):DotProduct(a + b + c) < 0 then b, c = c, b end
        mesh[#mesh + 1], mesh[#mesh + 2], mesh[#mesh + 3] = a, b, c
    end
    for latitude = 0, LATITUDES - 1 do
        for longitude = 0, SLICES - 1 do
            local a, b = Point(latitude, longitude), Point(latitude, longitude + 1)
            local c, d = Point(latitude + 1, longitude), Point(latitude + 1, longitude + 1)
            if latitude > 0 then Triangle(a, b, c) end
            if latitude < LATITUDES - 1 then Triangle(b, d, c) end
        end
    end
    assert(#mesh == VERTICES_PER_ORB, "sphere topology budget mismatch")
    S.unitMesh = mesh
end

---仅一个无环纹/无偏心亮点的精细径向软光，中心与实体球完全相同。
---@param batch EnchantOrbBatch
---@param rgb number[]
local function BakeHalo(batch, rgb)
    local red, green, blue = rgb[1] or 1, rgb[2] or 1, rgb[3] or 1
    local image = Image()
    batch.image = image
    assert(image:SetSize(64, 64, 4), "halo Image allocation failed")
    local c = 31.5
    for y = 0, 63 do
        for x = 0, 63 do
            local d = math.sqrt((x - c) ^ 2 + (y - c) ^ 2) / c
            local edge = math.max(0, 1 - d * d)
            local alpha = 0.26 * math.exp(-4.8 * d * d) * edge * edge
            image:SetPixel(x, y, Color(red, green, blue, alpha))
        end
    end
    local tex = Texture2D:new()
    batch.texture = tex -- 上传失败也由 Shutdown 释放。
    tex:SetNumLevels(1)
    tex:SetFilterMode(FILTER_BILINEAR)
    tex:SetAddressMode(COORD_U, ADDRESS_CLAMP)
    tex:SetAddressMode(COORD_V, ADDRESS_CLAMP)
    assert(tex:SetData(image, false), "halo texture upload failed")
    tex:SetSRGB(true)
    image:Dispose()
    batch.image = nil
end

---Init 失败返回 false，宿主可继续游戏/选择降级；只有显式 Init 才允许重试。
---@param scene Scene
---@return boolean
function M.Init(scene)
    M.Shutdown()
    S.faulted, S.lastError = false, ""
    local ok, err = pcall(function()
        -- materials skill 的真实内置路径；无资源文件、外部模型或自定义 shader。
        local sphereTech = cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml")
        local haloTech = cache:GetResource("Technique", "Techniques/DiffAlpha.xml")
        assert(sphereTech and haloTech, "required built-in technique unavailable")
        BuildUnitSphere()
        for _, rarity in ipairs(RARITIES) do
            local b = { rarity = rarity, dirty = false, count = 0, vertices = 0,
                commits = 0, haloCommits = 0 } ---@type EnchantOrbBatch
            S.batches[rarity] = b -- 任何后续一步失败都能找到全部已分配资源。
            local rgb = COLORS[rarity]
            local red, green, blue = rgb[1] or 1, rgb[2] or 1, rgb[3] or 1
            local mat = Material()
            b.material = mat
            mat:SetTechnique(0, sphereTech)
            mat:SetShaderParameter("MatDiffColor", Variant(Color(red, green, blue, 1)))
            mat:SetShaderParameter("MatSpecColor", Variant(Color(0.92, 0.95, 1, 1)))
            mat:SetShaderParameter("Metallic", Variant(0.28))
            mat:SetShaderParameter("Roughness", Variant(0.19))
            mat:SetShaderParameter("MatEmissiveColor", Variant(Color(red * 0.32, green * 0.32, blue * 0.32)))
            BakeHalo(b, rgb)
            local haloMat = Material()
            b.haloMaterial = haloMat
            haloMat:SetTechnique(0, haloTech)
            assert(b.texture, "halo texture unavailable")
            haloMat:SetTexture(TU_DIFFUSE, b.texture)
            haloMat:SetShaderParameter("MatDiffColor", Variant(Color(1, 1, 1, 1)))
            local node = scene:CreateChild("VehicleEnchantOrbs_" .. rarity, LOCAL)
            b.node = node
            node.enabled = false
            node:SetWorldTransform(Vector3(0, 0, 0), Quaternion(), Vector3(1, 1, 1))
            local geometry = node:CreateComponent("CustomGeometry", LOCAL)
            assert(geometry, "CustomGeometry unavailable")
            b.geometry = geometry
            geometry:SetDynamic(true)
            geometry.castShadows = false
            local halo = node:CreateComponent("BillboardSet", LOCAL)
            assert(halo, "BillboardSet unavailable")
            b.halo = halo
            halo:SetNumBillboards(MAX_ORBS)
            halo.relative, halo.scaled, halo.sorted, halo.castShadows = false, false, true, false
            halo:SetMaterial(haloMat)
            for i = 0, MAX_ORBS - 1 do halo:GetBillboard(i).enabled = false end
            -- 初始节点关闭；不 Commit 空集合，首次有效 Sync 才提交。
        end
    end)
    if not ok then Fault("Init: " .. tostring(err)); return false end
    S.initialized = true
    print("[VehicleEnchantOrbs] initialized: 3 orbs/car, 4 cars, 4320 vertices max")
    return true
end

---id 决定相位偏移，增删/重排其它车辆不会改变该车相位；不保存无界 id 表。
---@param id number
---@return number
local function IdPhase(id)
    local hash = math.sin(id * 12.9898 + 78.233) * 43758.5453
    return (hash - math.floor(hash)) * TAU
end

---@param marble EnchantOrbMarble
---@param records table<number, EnchantOrbRecord>
---@return EnchantOrbCar|nil
local function ReadCar(marble, records)
    if not marble.alive or not marble.enchant or not Finite(marble.id)
        or not Finite(marble.radius) or marble.radius <= 0 then return nil end
    local record = records[marble.id]
    if not record or not record.root then return nil end
    -- 只借用真实显示根节点，不读玩法 x/y、不猜 Z/屏幕投影或另加经验偏移。
    local anchor = record.root:LocalToWorld(Vector3(0, 0, 0))
    if not Finite(anchor.x) or not Finite(anchor.y) or not Finite(anchor.z) then return nil end
    local rarity = marble.enchant.rarity or "common"
    if not COLORS[rarity] then rarity = "common" end
    local rr = marble.radius * ORBIT_FACTOR
    return { id = marble.id, rarity = rarity, anchor = anchor, orbitRadius = rr,
        sphereRadius = rr * SPHERE_FACTOR, spin = 0, centers = {} }
end

---@param game EnchantOrbGame
---@param records table<number, EnchantOrbRecord>
local function Collect(game, records)
    local chosen, flying = {}, {} ---@type EnchantOrbCar[], EnchantOrbCar[]
    local seen = {} ---@type table<number, boolean>
    if game.activeBall then
        local car = ReadCar(game.activeBall, records)
        if car then chosen[1], seen[car.id] = car, true end
    end
    for _, m in ipairs(game.marbles or {}) do
        if not m.onSling and not seen[m.id] then
            local car = ReadCar(m, records)
            if car then flying[#flying + 1], seen[car.id] = car, true end
        end
    end
    -- 待发优先，其余按稳定 id 取预算，列表重排不导致预算内对象闪换。
    table.sort(flying, function(a, b) return a.id < b.id end)
    for _, car in ipairs(flying) do
        if #chosen >= MAX_CARS then break end
        chosen[#chosen + 1] = car
    end
    return chosen
end

---@param batch EnchantOrbBatch
---@param car EnchantOrbCar
local function EmitCar(batch, car)
    local geometry, halo = batch.geometry, batch.halo
    assert(geometry and halo)
    local spin = (S.phase + IdPhase(car.id)) % TAU
    car.spin = spin
    for k = 1, ORBS_PER_CAR do
        local angle = spin + (k - 1) * TAU / ORBS_PER_CAR
        -- 固定正交单位基 u=(1,0,0), v=(0,sin(tilt),cos(tilt))。
        -- 三球共享一个倾斜圆，禁止逐球 bob：球心距恒为 sqrt(3)*rr，重心恒为 anchor。
        local radial = car.orbitRadius * math.sin(angle)
        local center = car.anchor + Vector3(car.orbitRadius * math.cos(angle), radial * math.sin(TILT), radial * math.cos(TILT))
        car.centers[k] = center
        for _, normal in ipairs(S.unitMesh) do
            geometry:DefineVertex(center + normal * car.sphereRadius)
            geometry:DefineNormal(normal)
            geometry:DefineTexCoord(Vector2(0, 0))
        end
        batch.count = batch.count + 1
        batch.vertices = batch.vertices + VERTICES_PER_ORB
        local bb = halo:GetBillboard(batch.count - 1)
        bb.position, bb.size = center, Vector2(car.sphereRadius * HALO_FACTOR, car.sphereRadius * HALO_FACTOR)
        bb.color, bb.rotation, bb.enabled = Color(1, 1, 1, 1), 0, true
    end
end

---@param game EnchantOrbGame
---@param records table<number, EnchantOrbRecord>
---@param dt number
local function Sync(game, records, dt)
    if game.elapsed and Finite(game.elapsed) then
        if S.lastElapsed and game.elapsed < S.lastElapsed then M.Clear(true) end
        S.lastElapsed = game.elapsed
    end
    if game.state ~= "playing" or (game.introTimer or 0) > 0 then M.Clear(false); return end
    local ts = game.timeScale or 1
    if Finite(dt) and dt > 0 and Finite(ts) and ts > 0 then
        local advance = dt * ts * ANGULAR_SPEED
        if Finite(advance) then S.phase = (S.phase + advance % TAU) % TAU end
    end
    -- 广告 dt=0 时相位完全冻结；仍追随 records 中的实际显示锚点，不积累 elapsed 补时。
    local cars = Collect(game, records)
    for _, rarity in ipairs(RARITIES) do
        local batch = S.batches[rarity]
        local count = 0
        for _, car in ipairs(cars) do if car.rarity == rarity then count = count + 1 end end
        if count == 0 then
            Hide(batch)
        else
            local node, geometry, halo = batch.node, batch.geometry, batch.halo
            assert(node and geometry and halo and batch.material and batch.haloMaterial)
            node.enabled = false
            node:SetWorldTransform(Vector3(0, 0, 0), Quaternion(), Vector3(1, 1, 1))
            batch.dirty, batch.count, batch.vertices = true, 0, 0
            geometry:Clear()
            geometry:SetNumGeometries(1)
            geometry:BeginGeometry(0, TRIANGLE_LIST)
            for _, car in ipairs(cars) do if car.rarity == rarity then EmitCar(batch, car) end end
            assert(batch.count == count * ORBS_PER_CAR and batch.count <= MAX_ORBS, "orb budget mismatch")
            for i = batch.count, MAX_ORBS - 1 do halo:GetBillboard(i).enabled = false end
            geometry:Commit()
            assert(geometry:SetMaterial(0, batch.material), "sphere material bind failed") -- Clear 清材质槽。
            halo:Commit()
            halo:SetMaterial(batch.haloMaterial)
            batch.commits, batch.haloCommits = batch.commits + 1, batch.haloCommits + 1
            node.enabled = true
        end
    end
    S.cars = cars -- 仅数值与 Vector3；不保留 game、records、root 或 marble 引用。
end

---@param game EnchantOrbGame
---@param records table<number, EnchantOrbRecord>
---@param dt number 未乘 timeScale 的允许玩法 dt；本模块不再钳 dt 或读真实时钟。
---@return boolean
function M.Sync(game, records, dt)
    if not S.initialized or S.faulted then return false end
    local ok, err = pcall(Sync, game, records, dt)
    if not ok then Fault("Sync: " .. tostring(err)); return false end
    return not S.faulted
end

---只返回复制的诊断值，包含真正提交的数量；不暴露组件、材质、纹理或内部表。
---@return table
function M.Debug()
    local cars = {} ---@type EnchantOrbCar[]
    local batches = {} ---@type table<string, table>
    local orbs, halos, vertices = 0, 0, 0
    for i, c in ipairs(S.cars) do
        local centers = {} ---@type Vector3[]
        for k, center in ipairs(c.centers) do centers[k] = CopyVector(center) end
        cars[i] = { id = c.id, rarity = c.rarity, anchor = CopyVector(c.anchor),
            orbitRadius = c.orbitRadius, sphereRadius = c.sphereRadius, spin = c.spin, centers = centers }
    end
    for _, rarity in ipairs(RARITIES) do
        local b = S.batches[rarity]
        if b then
            local enabled = b.node and b.node.enabled or false
            local actualVertices, activeHalos = 0, 0
            if enabled and b.count > 0 then
                if b.geometry then actualVertices = b.geometry:GetNumVertices(0) end
                if b.halo then
                    for i = 0, MAX_ORBS - 1 do if b.halo:GetBillboard(i).enabled then activeHalos = activeHalos + 1 end end
                end
            end
            batches[rarity] = { orbs = b.count, halos = activeHalos, vertices = b.vertices,
                actualVertices = actualVertices, enabled = enabled, commits = b.commits, haloCommits = b.haloCommits,
                materialBound = b.geometry and b.count > 0 and b.geometry:GetMaterial(0) ~= nil or false }
            orbs, halos, vertices = orbs + b.count, halos + activeHalos, vertices + actualVertices
        else
            batches[rarity] = { orbs = 0, halos = 0, vertices = 0, actualVertices = 0, enabled = false }
        end
    end
    return { initialized = S.initialized, faulted = S.faulted, lastError = S.lastError,
        phase = S.phase, cars = cars, count = #cars, orbs = orbs, halos = halos, vertices = vertices,
        batches = batches, maxCars = MAX_CARS, orbsPerCar = ORBS_PER_CAR, orbBudget = MAX_ORBS,
        verticesPerOrb = VERTICES_PER_ORB, vertexBudget = MAX_ORBS * VERTICES_PER_ORB,
        tiltDegrees = math.deg(TILT), angularSpeed = ANGULAR_SPEED }
end

return M
