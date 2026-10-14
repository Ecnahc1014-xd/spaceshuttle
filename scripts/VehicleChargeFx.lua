-- 满蓄表现：独立轮廓材质 + 两层真实车型全息残像，不修改车辆规则与共享白材质。
-- 复用 VehicleGeometry 的六段车体与翻面轮廓；只在新爆发时构建，逐帧仅改变换与透明度。
local VehicleGeometry = require "VehicleGeometry"
local VisualCatalog = require "VisualCatalog"
local M = {}

---@class ChargeFxRecord
---@field root Node
---@field geometry CustomGeometry
---@field chargeOriginalOutline Material|nil

---@class ChargeFxCopy
---@field node Node
---@field geometry CustomGeometry
---@field material Material

---@class ChargeFxState
---@field scene Scene|nil
---@field outline Material|nil
---@field copies ChargeFxCopy[]
---@field shell ChargeFxCopy|nil
---@field serial number
---@field vehicleId number
---@field skin string
---@field position Vector3
---@field rotation Quaternion
---@field scale Vector3
---@field visible integer
---@field shellVisible integer
---@field nodes Node[]
---@field materials Material[]
---@field bound table<number, ChargeFxRecord>
local S = { copies = {}, shell = nil, nodes = {}, materials = {}, bound = {}, serial = -1, vehicleId = -1, skin = "",
    visible = 0, shellVisible = 0,
    position = Vector3(), rotation = Quaternion(), scale = Vector3(1, 1, 1) } --[[@as ChargeFxState]]

---@param records table<number, ChargeFxRecord>|nil
function M.Restore(records)
    for _, record in pairs(records or S.bound) do
        if record.chargeOriginalOutline then
            local original = record.chargeOriginalOutline
            record.chargeOriginalOutline = nil
            -- 宿主正常先恢复再删车；异常清理不能让一个失效节点阻断其他资源释放。
            pcall(function() record.geometry:SetMaterial(6, original) end)
        end
    end
end
---@param records table<number, ChargeFxRecord>|nil
function M.Clear(records)
    M.Restore()
    if records then M.Restore(records) end
    S.bound = {}
    for _, copy in ipairs(S.copies) do pcall(function() copy.node.enabled = false end) end
    if S.shell then pcall(function() S.shell.node.enabled = false end) end
    S.visible, S.shellVisible, S.serial, S.vehicleId = 0, 0, -1, -1
end
---@param records table<number, ChargeFxRecord>|nil
function M.Shutdown(records)
    M.Clear(records)
    for _, node in ipairs(S.nodes) do
        pcall(function() node:Remove(); node:Dispose() end)
    end
    for _, mat in ipairs(S.materials) do pcall(function() mat:Dispose() end) end
    S.copies, S.shell, S.nodes, S.materials = {}, nil, {}, {}
    if S.outline then pcall(function() S.outline:Dispose() end) end
    S.outline, S.scene, S.skin = nil, nil, ""
end
---@param scene Scene
---@return boolean
function M.Init(scene)
    M.Shutdown()
    local ok, err = pcall(function()
        local opaque = cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml")
        local alpha = cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml")
        assert(opaque and alpha, "charge techniques unavailable")
        S.scene = scene
        S.outline = Material()
        S.outline:SetTechnique(0, opaque)
        S.outline:SetShaderParameter("MatDiffColor", Variant(Color(0.12, 0.96, 1.0, 1)))
        S.outline:SetShaderParameter("MatEmissiveColor", Variant(Color(0.06, 0.65, 0.78, 1)))
        S.outline:SetShaderParameter("Metallic", Variant(0.15))
        S.outline:SetShaderParameter("Roughness", Variant(0.24))
        for i = 1, VisualCatalog.CHARGE_HOLOGRAM.copies do
            local node = scene:CreateChild("ChargeHologram_" .. tostring(i), LOCAL)
            S.nodes[#S.nodes + 1] = node
            node.enabled = false
            local geometry = node:CreateComponent("CustomGeometry", LOCAL)
            geometry.castShadows = false
            local mat = Material()
            S.materials[#S.materials + 1] = mat
            mat:SetTechnique(0, alpha)
            mat:SetShaderParameter("MatDiffColor", Variant(Color(0.12, 0.83, 1, 0.16)))
            mat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.02, 0.46, 0.65, 1)))
            mat:SetShaderParameter("Metallic", Variant(0.25))
            mat:SetShaderParameter("Roughness", Variant(0.2))
            S.copies[#S.copies + 1] = {node = node, geometry = geometry, material = mat}
        end
        -- 贴身外套：一层比车略大、极浅透明的同型幻影壳，套在车上跟随实际显示变换。
        local shellNode = scene:CreateChild("ChargeHologramShell", LOCAL)
        S.nodes[#S.nodes + 1] = shellNode
        shellNode.enabled = false
        local shellGeom = shellNode:CreateComponent("CustomGeometry", LOCAL)
        shellGeom.castShadows = false
        local shellMat = Material()
        S.materials[#S.materials + 1] = shellMat
        shellMat:SetTechnique(0, alpha)
        shellMat:SetShaderParameter("MatDiffColor", Variant(Color(0.3, 0.92, 1, 0.10)))
        shellMat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.05, 0.5, 0.68, 1)))
        shellMat:SetShaderParameter("Metallic", Variant(0.2))
        shellMat:SetShaderParameter("Roughness", Variant(0.18))
        S.shell = {node = shellNode, geometry = shellGeom, material = shellMat}
    end)
    if not ok then
        print("[VehicleChargeFx] Init failed: " .. tostring(err))
        M.Shutdown()
        return false
    end
    print("[VehicleChargeFx] initialized: independent cyan outline, two real-mesh echoes")
    return true
end
---@param game table
---@param presentation table
---@param records table<number, ChargeFxRecord>
---@param skin string
---@return boolean
function M.Sync(game, presentation, records, skin)
    if not S.scene or not S.outline then return false end
    local playing = game.state == "playing" and (game.introTimer or 0) <= 0
    local chargingId = -1
    if playing and game.chargeActive and (game.chargeProgress or 0) >= 1 and game.activeBall then
        chargingId = game.activeBall.id
    end
    local qualified = {}
    if chargingId >= 0 then qualified[chargingId] = true end
    if playing then
        for _, marble in ipairs(game.marbles or {}) do
            if marble.alive and marble.chargeBoosted then qualified[marble.id] = true end
        end
    end
    for id, record in pairs(records) do
        if qualified[id] then
            if not record.chargeOriginalOutline then
                record.chargeOriginalOutline = record.geometry:GetMaterial(6)
            end
            S.bound[id] = record
            record.geometry:SetMaterial(6, S.outline)
        else
            if record.chargeOriginalOutline then
                record.geometry:SetMaterial(6, record.chargeOriginalOutline)
                record.chargeOriginalOutline = nil
            end
            S.bound[id] = nil
        end
    end
    -- 正常宿主已在删车前恢复材质；此处同时释放借用记录，不跨生命周期持有车辆。
    for id in pairs(S.bound) do
        if not records[id] then S.bound[id] = nil end
    end
    local echo = presentation.chargeHologram
    if not playing or not echo or echo.life <= 0 then
        for _, copy in ipairs(S.copies) do copy.node.enabled = false end
        if S.shell then S.shell.node.enabled = false end
        S.visible, S.shellVisible = 0, 0
        return true
    end
    -- 外套跟随源车：只有源车仍在场时才套在车上，源车回收后外套随之消失。
    local shellRecord = records[echo.vehicleId]
    local shellOn = shellRecord ~= nil
    if S.serial ~= echo.serial then
        local record = records[echo.vehicleId]
        if not record then
            for _, copy in ipairs(S.copies) do copy.node.enabled = false end
            if S.shell then S.shell.node.enabled = false end
            S.visible, S.shellVisible = 0, 0
            return true
        end
        S.serial, S.vehicleId = echo.serial, echo.vehicleId
        -- 值拷贝冻结爆发时的真实显示变换，不能持有逐帧移动的 Node 作为残像位置。
        local p, r, sc = record.root.worldPosition, record.root.worldRotation, record.root.worldScale
        S.position = Vector3(p.x, p.y, p.z)
        S.rotation = Quaternion(r.w, r.x, r.y, r.z)
        S.scale = Vector3(sc.x, sc.y, sc.z)
        if S.skin ~= skin then
            for _, copy in ipairs(S.copies) do
                local mats = {copy.material, copy.material, copy.material,
                    copy.material, copy.material, copy.material}
                VehicleGeometry.Build(copy.geometry, skin, mats, copy.material)
            end
            if S.shell then
                local shellMats = {S.shell.material, S.shell.material, S.shell.material,
                    S.shell.material, S.shell.material, S.shell.material}
                VehicleGeometry.Build(S.shell.geometry, skin, shellMats, S.shell.material)
            end
            S.skin = skin
        end
        print("[VehicleChargeFx] burst #" .. tostring(S.serial) .. " vehicle=" .. tostring(S.vehicleId))
    end
    local t = math.max(0, math.min(1, 1 - echo.life / echo.maxLife))
    local ease = 1 - (1 - t) ^ 3
    S.visible = 0
    for i, copy in ipairs(S.copies) do
        local sign = i % 2 == 1 and -1 or 1
        local distance = VisualCatalog.CHARGE_HOLOGRAM.spread * ease
        local offset = S.rotation * Vector3(-distance * 0.18, sign * distance, -distance * 0.32)
        local grow = 1 + ease * (0.08 + i * 0.04)
        copy.node:SetWorldTransform(S.position + offset, S.rotation, S.scale * grow)
        local opacity = (0.19 - (i - 1) * 0.045) * (1 - t) ^ 1.6
        copy.material:SetShaderParameter("MatDiffColor", Variant(Color(0.12, 0.83, 1, opacity)))
        copy.node.enabled = opacity > 0.001
        if copy.node.enabled then S.visible = S.visible + 1 end
    end
    -- 贴身外套：逐帧取源车当前实际显示变换，等比放大一点点套在车上，随 TTL 淡出。
    S.shellVisible = 0
    if S.shell then
        if shellOn and shellRecord.root then
            local sp = shellRecord.root.worldPosition
            local sr = shellRecord.root.worldRotation
            local ss = shellRecord.root.worldScale
            local grow = VisualCatalog.CHARGE_HOLOGRAM.shellScale
            S.shell.node:SetWorldTransform(sp,
                Quaternion(sr.w, sr.x, sr.y, sr.z),
                Vector3(ss.x * grow, ss.y * grow, ss.z * grow))
            local shellOpacity = VisualCatalog.CHARGE_HOLOGRAM.shellAlpha * (1 - t) ^ 1.2
            S.shell.material:SetShaderParameter("MatDiffColor", Variant(Color(0.3, 0.92, 1, shellOpacity)))
            S.shell.node.enabled = shellOpacity > 0.001
            if S.shell.node.enabled then S.shellVisible = 1 end
        else
            S.shell.node.enabled = false
        end
    end
    return true
end
function M.Debug()
    return {initialized = S.scene ~= nil, visible = S.visible, shellVisible = S.shellVisible,
        serial = S.serial, vehicleId = S.vehicleId, skin = S.skin}
end
return M
