local VehicleGeometry = {}

local SECTION_COUNT = 6
local PLANAR_RADIUS = 1.84

local function FaceNormal(a, b, c)
    local ux, uy, uz = b.x - a.x, b.y - a.y, b.z - a.z
    local vx, vy, vz = c.x - a.x, c.y - a.y, c.z - a.z
    local nx = uy * vz - uz * vy
    local ny = uz * vx - ux * vz
    local nz = ux * vy - uy * vx
    local length = math.sqrt(nx * nx + ny * ny + nz * nz)
    if length < 0.000001 then return Vector3(0, 0, -1) end
    return Vector3(nx / length, ny / length, nz / length)
end

local function AddTriangle(buffer, a, b, c, expectedNormal)
    local normal = FaceNormal(a, b, c)
    if expectedNormal then
        local dot = normal.x * expectedNormal.x + normal.y * expectedNormal.y
            + normal.z * expectedNormal.z
        if dot < 0 then
            b, c = c, b
            normal = FaceNormal(a, b, c)
        end
    end
    buffer[#buffer + 1] = {position = a, normal = normal}
    buffer[#buffer + 1] = {position = b, normal = normal}
    buffer[#buffer + 1] = {position = c, normal = normal}
end

local function AddQuad(buffer, a, b, c, d, expectedNormal)
    AddTriangle(buffer, a, b, c, expectedNormal)
    AddTriangle(buffer, a, c, d, expectedNormal)
end

local function RoundedRing(cx, cy, z, length, width, bevel)
    local hx, hy = length * 0.5, width * 0.5
    bevel = math.min(bevel, hx * 0.8, hy * 0.8)
    return {
        Vector3(cx + hx - bevel, cy - hy, z),
        Vector3(cx + hx, cy - hy + bevel, z),
        Vector3(cx + hx, cy + hy, z),
        Vector3(cx + hx - bevel, cy + hy, z),
        Vector3(cx - hx + bevel, cy + hy, z),
        Vector3(cx - hx, cy + hy - bevel, z),
        Vector3(cx - hx, cy - hy + bevel, z),
        Vector3(cx - hx + bevel, cy - hy, z),
    }
end

local function AddFrustum(buffer, cx, cy, zNear, zFar,
        nearLength, nearWidth, farLength, farWidth, bevel)
    local nearRing = RoundedRing(cx, cy, zNear, nearLength, nearWidth, bevel)
    local farRing = RoundedRing(cx, cy, zFar, farLength, farWidth, bevel)
    local nearCenter = Vector3(cx, cy, zNear)
    local farCenter = Vector3(cx, cy, zFar)
    for i = 1, #nearRing do
        local nextIndex = i % #nearRing + 1
        AddTriangle(buffer, nearCenter, nearRing[nextIndex], nearRing[i], Vector3(0, 0, -1))
        AddTriangle(buffer, farCenter, farRing[i], farRing[nextIndex], Vector3(0, 0, 1))
        local midX = (nearRing[i].x + nearRing[nextIndex].x) * 0.5 - cx
        local midY = (nearRing[i].y + nearRing[nextIndex].y) * 0.5 - cy
        AddQuad(buffer, nearRing[i], nearRing[nextIndex], farRing[nextIndex], farRing[i],
            Vector3(midX, midY, 0))
    end
end

local function AddRoundedPrism(buffer, cx, cy, zNear, zFar, length, width, bevel)
    AddFrustum(buffer, cx, cy, zNear, zFar, length, width, length, width, bevel)
end

local function AddCylinderY(buffer, cx, cy, cz, radius, width, segments)
    local yMin, yMax = cy - width * 0.5, cy + width * 0.5
    local minCenter = Vector3(cx, yMin, cz)
    local maxCenter = Vector3(cx, yMax, cz)
    for i = 0, segments - 1 do
        local a0 = i * math.pi * 2 / segments
        local a1 = (i + 1) * math.pi * 2 / segments
        local x0, z0 = cx + math.cos(a0) * radius, cz + math.sin(a0) * radius
        local x1, z1 = cx + math.cos(a1) * radius, cz + math.sin(a1) * radius
        local p0 = Vector3(x0, yMin, z0)
        local p1 = Vector3(x0, yMax, z0)
        local p2 = Vector3(x1, yMax, z1)
        local p3 = Vector3(x1, yMin, z1)
        local expected = Vector3(math.cos((a0 + a1) * 0.5), 0, math.sin((a0 + a1) * 0.5))
        AddQuad(buffer, p0, p1, p2, p3, expected)
        AddTriangle(buffer, minCenter, p3, p0, Vector3(0, -1, 0))
        AddTriangle(buffer, maxCenter, p1, p2, Vector3(0, 1, 0))
    end
end

local function AddWheels(tire, metal, positions, offset, radius)
    for _, x in ipairs(positions) do
        for _, sign in ipairs({-1, 1}) do
            AddCylinderY(tire, x, sign * offset, -0.02, radius, 0.20, 12)
            AddCylinderY(metal, x, sign * (offset + 0.11), -0.02, radius * 0.52, 0.025, 12)
        end
    end
end

local function AddLamps(light, nose, tail, width, z)
    for _, sign in ipairs({-1, 1}) do
        AddRoundedPrism(light, nose, sign * width, z, z + 0.09, 0.035, 0.19, 0.01)
        AddRoundedPrism(light, tail, sign * width, -0.25, -0.17, 0.035, 0.15, 0.01)
    end
end

local function BuildTruck(body, side, tire, metal, glass, light)
    AddRoundedPrism(body, 0, 0, -0.28, 0.18, 3.45, 1.28, 0.12)
    AddRoundedPrism(body, -0.62, 0, -0.76, -0.25, 1.86, 1.20, 0.10)
    AddFrustum(body, 0.98, 0, -1.02, -0.26, 1.08, 1.16, 1.18, 1.24, 0.09)
    AddRoundedPrism(body, 1.54, 0, -0.72, -0.24, 0.18, 1.18, 0.045)
    for _, sideY in ipairs({-0.625, 0.625}) do
        AddRoundedPrism(side, -0.45, sideY, -0.61, -0.12, 2.15, 0.075, 0.022)
        AddRoundedPrism(side, 1.02, sideY, -0.82, -0.30, 0.82, 0.075, 0.022)
    end
    AddRoundedPrism(side, -0.62, 0, -0.80, -0.755, 1.62, 0.96, 0.06)
    AddFrustum(glass, 1.00, 0, -1.055, -0.99, 0.70, 0.92, 0.82, 1.00, 0.07)
    for _, sideY in ipairs({-0.635, 0.635}) do
        AddRoundedPrism(glass, 1.02, sideY, -0.91, -0.56, 0.58, 0.045, 0.015)
    end
    AddWheels(tire, metal, {1.03, -0.52, -1.18}, 0.73, 0.30)
    AddRoundedPrism(metal, 1.70, 0, -0.51, -0.15, 0.12, 1.14, 0.035)
    for _, grilleY in ipairs({-0.34, -0.17, 0, 0.17, 0.34}) do
        AddRoundedPrism(metal, 1.765, grilleY, -0.48, -0.25, 0.025, 0.10, 0.01)
    end
    AddRoundedPrism(metal, -1.74, 0, -0.18, 0.04, 0.12, 1.10, 0.035)
    for _, sign in ipairs({-1, 1}) do
        AddRoundedPrism(metal, -0.62, sign * 0.66, -0.76, -0.24, 1.88, 0.045, 0.015)
        AddRoundedPrism(metal, 0.06, sign * 0.69, -0.17, -0.08, 2.72, 0.055, 0.018)
    end
    AddRoundedPrism(metal, -1.53, 0, -0.79, -0.75, 0.045, 1.10, 0.012)
    for _, mirrorY in ipairs({-0.79, 0.79}) do
        AddRoundedPrism(metal, 1.26, mirrorY, -0.91, -0.68, 0.19, 0.11, 0.025)
    end
    AddLamps(light, 1.775, -1.785, 0.39, -0.68)
    for _, y in ipairs({-0.42, 0, 0.42}) do
        AddRoundedPrism(light, 1.16, y, -1.085, -1.055, 0.10, 0.07, 0.015)
    end
    for _, x in ipairs({-1.25, -0.55, 0.18}) do
        for _, sign in ipairs({-1, 1}) do
            AddRoundedPrism(light, x, sign * 0.685, -0.54, -0.43, 0.12, 0.025, 0.008)
        end
    end
end

local function BuildSUV(body, side, tire, metal, glass, light)
    AddRoundedPrism(body, 0, 0, -0.33, 0.13, 3.10, 1.28, 0.19)
    AddFrustum(body, -0.22, 0, -0.88, -0.34, 1.90, 1.07, 2.18, 1.20, 0.22)
    AddFrustum(body, 1.20, 0, -0.48, -0.30, 0.68, 1.10, 0.80, 1.20, 0.12)
    AddRoundedPrism(side, 0, 0, -0.92, -0.87, 1.56, 0.97, 0.12)
    AddFrustum(glass, 0.73, 0, -0.88, -0.67, 0.35, 0.89, 0.44, 1.02, 0.08)
    for _, sign in ipairs({-1, 1}) do
        AddRoundedPrism(glass, -0.37, sign * 0.56, -0.78, -0.47, 0.88, 0.03, 0.025)
        AddRoundedPrism(metal, -0.20, sign * 0.52, -0.97, -0.92, 1.45, 0.035, 0.012)
        AddRoundedPrism(side, 0, sign * 0.64, -0.38, -0.19, 2.45, 0.065, 0.018)
    end
    AddWheels(tire, metal, {1.04, -1.03}, 0.69, 0.27)
    AddRoundedPrism(metal, 1.55, 0, -0.27, -0.18, 0.09, 1.10, 0.025)
    AddRoundedPrism(metal, -1.57, 0, -0.28, -0.16, 0.09, 1.08, 0.025)
    AddLamps(light, 1.55, -1.57, 0.39, -0.35)
end

local function BuildSports(body, side, tire, metal, glass, light)
    AddFrustum(body, 0, 0, -0.25, 0.09, 3.08, 1.07, 3.32, 1.31, 0.28)
    AddFrustum(body, 1.02, 0, -0.45, -0.25, 0.97, 0.78, 1.08, 1.01, 0.20)
    AddFrustum(body, -0.19, 0, -0.64, -0.27, 1.35, 0.91, 1.67, 1.03, 0.25)
    AddRoundedPrism(side, -1.08, 0, -0.27, -0.22, 0.48, 1.15, 0.14)
    for _, sign in ipairs({-1, 1}) do
        AddRoundedPrism(side, 0, sign * 0.56, -0.32, -0.16, 2.06, 0.055, 0.018)
        AddRoundedPrism(glass, -0.14, sign * 0.48, -0.57, -0.38, 0.59, 0.025, 0.012)
    end
    AddFrustum(glass, 0.35, 0, -0.66, -0.62, 0.38, 0.73, 0.53, 0.85, 0.10)
    AddWheels(tire, metal, {0.96, -1.03}, 0.66, 0.25)
    AddRoundedPrism(metal, -1.52, 0, -0.37, -0.29, 0.07, 1.25, 0.015)
    AddRoundedPrism(metal, -1.52, 0, -0.18, -0.10, 0.08, 0.82, 0.015)
    AddLamps(light, 1.60, -1.62, 0.38, -0.31)
end

local function BuildVan(body, side, tire, metal, glass, light)
    AddRoundedPrism(body, 0, 0, -0.23, 0.14, 3.22, 1.18, 0.10)
    AddRoundedPrism(body, -0.50, 0, -0.98, -0.22, 2.05, 1.12, 0.08)
    AddFrustum(body, 1.05, 0, -0.90, -0.22, 0.99, 1.02, 1.13, 1.14, 0.08)
    AddRoundedPrism(side, -0.50, 0, -1.025, -0.98, 1.80, 0.90, 0.06)
    for _, sign in ipairs({-1, 1}) do
        AddRoundedPrism(side, -0.48, sign * 0.58, -0.86, -0.27, 1.82, 0.05, 0.015)
        AddRoundedPrism(glass, 1.03, sign * 0.60, -0.75, -0.50, 0.45, 0.025, 0.010)
        AddRoundedPrism(metal, -0.55, sign * 0.613, -0.86, -0.38, 0.03, 0.016, 0.006)
    end
    AddFrustum(glass, 1.49, 0, -0.83, -0.77, 0.08, 0.85, 0.15, 0.93, 0.025)
    AddWheels(tire, metal, {1.00, -1.15}, 0.65, 0.24)
    AddRoundedPrism(metal, -1.58, 0, -0.66, -0.26, 0.035, 0.78, 0.012)
    AddLamps(light, 1.63, -1.63, 0.40, -0.42)
end

local function BuildArmored(body, side, tire, metal, glass, light)
    AddFrustum(body, 0, 0, -0.38, 0.13, 3.08, 1.30, 3.26, 1.35, 0.19)
    AddFrustum(body, -0.35, 0, -0.85, -0.37, 1.95, 1.05, 2.26, 1.29, 0.23)
    AddFrustum(body, 1.03, 0, -0.66, -0.31, 0.85, 0.91, 1.11, 1.19, 0.20)
    AddRoundedPrism(side, -0.25, 0, -0.91, -0.85, 1.65, 0.84, 0.12)
    for _, sign in ipairs({-1, 1}) do
        AddRoundedPrism(side, -0.35, sign * 0.60, -0.59, -0.25, 1.97, 0.075, 0.024)
        AddRoundedPrism(metal, 0.20, sign * 0.70, -0.34, -0.22, 2.49, 0.11, 0.025)
        AddRoundedPrism(glass, 0.30, sign * 0.57, -0.65, -0.55, 0.33, 0.030, 0.012)
        AddRoundedPrism(metal, -0.43, sign * 0.49, -0.96, -0.90, 0.76, 0.04, 0.015)
    end
    AddFrustum(glass, 0.84, 0, -0.69, -0.66, 0.18, 0.57, 0.25, 0.72, 0.045)
    AddWheels(tire, metal, {1.10, 0, -1.10}, 0.72, 0.23)
    AddRoundedPrism(metal, 1.58, 0, -0.43, -0.27, 0.10, 1.08, 0.025)
    AddRoundedPrism(metal, -1.60, 0, -0.44, -0.29, 0.09, 1.06, 0.025)
    AddLamps(light, 1.63, -1.63, 0.39, -0.46)
end

local function BuildBuggy(body, side, tire, metal, glass, light)
    AddFrustum(body, 0, 0, -0.26, 0.07, 2.57, 0.84, 2.96, 1.05, 0.27)
    AddFrustum(body, 1.06, 0, -0.42, -0.23, 0.75, 0.70, 0.92, 0.94, 0.18)
    AddRoundedPrism(side, -0.39, 0, -0.40, -0.27, 1.06, 0.78, 0.14)
    AddFrustum(glass, 0.23, 0, -0.72, -0.43, 0.54, 0.61, 0.70, 0.74, 0.14)
    AddWheels(tire, metal, {0.97, -0.98}, 0.78, 0.28)
    for _, sign in ipairs({-1, 1}) do
        AddRoundedPrism(metal, -0.16, sign * 0.48, -0.78, -0.30, 0.08, 0.045, 0.015)
        AddRoundedPrism(metal, -0.71, sign * 0.43, -0.78, -0.30, 0.08, 0.045, 0.015)
        AddRoundedPrism(metal, -0.43, sign * 0.46, -0.80, -0.73, 0.64, 0.05, 0.014)
        AddRoundedPrism(metal, -0.32, sign * 0.52, -0.39, -0.20, 1.84, 0.055, 0.015)
        AddRoundedPrism(light, 1.46, sign * 0.28, -0.51, -0.43, 0.07, 0.13, 0.02)
    end
    AddRoundedPrism(metal, 1.51, 0, -0.29, -0.20, 0.075, 1.07, 0.025)
    AddRoundedPrism(metal, -1.52, 0, -0.30, -0.20, 0.075, 1.05, 0.025)
    AddLamps(light, 1.53, -1.54, 0.39, -0.32)
end

local BUILDERS = {
    default = BuildTruck,
    arctic = BuildSUV,
    crimson = BuildSports,
    jade = BuildVan,
    obsidian = BuildArmored,
    rally = BuildBuggy,
}

function VehicleGeometry.Build(geometry, vehicleKey, materials)
    local sections = {}
    for i = 1, SECTION_COUNT do sections[i] = {} end
    (BUILDERS[vehicleKey] or BuildTruck)(
        sections[1], sections[2], sections[3], sections[4], sections[5], sections[6])

    for _, vertices in ipairs(sections) do
        for _, vertex in ipairs(vertices) do
            local p = vertex.position
            assert(p.x * p.x + p.y * p.y <= PLANAR_RADIUS * PLANAR_RADIUS + 0.001,
                "vehicle geometry exceeds collision radius: " .. tostring(vehicleKey))
        end
    end

    geometry:Clear()
    geometry:SetNumGeometries(SECTION_COUNT)
    geometry:SetDynamic(false)
    for sectionIndex = 0, SECTION_COUNT - 1 do
        geometry:BeginGeometry(sectionIndex, TRIANGLE_LIST)
        for _, vertex in ipairs(sections[sectionIndex + 1]) do
            geometry:DefineVertex(vertex.position)
            geometry:DefineNormal(vertex.normal)
        end
    end
    geometry:Commit()
    for sectionIndex = 0, SECTION_COUNT - 1 do
        geometry:SetMaterial(sectionIndex, materials[sectionIndex + 1])
    end
end

return VehicleGeometry
