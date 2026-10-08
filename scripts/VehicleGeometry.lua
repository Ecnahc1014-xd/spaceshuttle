-- 六车型共用实车几何：战斗、首页与商店使用同一入口。
-- 项目坐标：+X 为车头、Y 为轮距、-Z 为车顶，不套用案例的 Y-up 车型尺寸。
local VehicleGeometry = {}

local SECTION_COUNT = 6
local PLANAR_RADIUS = 1.84 / 1.12 -- 与 Renderer3D 的 0.98 填充量配合，保留碰撞圆余量。
-- 第 7 段是白色轮廓壳：车体三角面绕包围盒中心等比放大后翻转绕序，
-- 默认背面剔除下只剩“远侧壳”，在车体外缘露出一圈白边。
-- 放大倍率折进 fit，使轮廓（而非车体）恰好占满 PLANAR_RADIUS，整体仍不越碰撞圆。
local OUTLINE_SECTION = SECTION_COUNT + 1
local OUTLINE_SCALE = 1.035

local function FaceNormal(a, b, c)
    local ux, uy, uz = b.x - a.x, b.y - a.y, b.z - a.z
    local vx, vy, vz = c.x - a.x, c.y - a.y, c.z - a.z
    local nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
    local length = math.sqrt(nx * nx + ny * ny + nz * nz)
    if length < 0.000001 then return Vector3(0, 0, -1) end
    return Vector3(nx / length, ny / length, nz / length)
end

local function AddTriangle(buffer, a, b, c, expectedNormal)
    local normal = FaceNormal(a, b, c)
    if expectedNormal and normal:DotProduct(expectedNormal) < 0 then
        b, c = c, b
        normal = FaceNormal(a, b, c)
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
    local b = math.min(bevel, hx * 0.8, hy * 0.8)
    return {
        Vector3(cx + hx - b, cy - hy, z),
        Vector3(cx + hx, cy - hy + b, z),
        Vector3(cx + hx, cy + hy - b, z),
        Vector3(cx + hx - b, cy + hy, z),
        Vector3(cx - hx + b, cy + hy, z),
        Vector3(cx - hx, cy + hy - b, z),
        Vector3(cx - hx, cy - hy + b, z),
        Vector3(cx - hx + b, cy - hy, z),
    }
end

local function ConnectRings(buffer, nearRing, farRing, cx, cy)
    for i = 1, #nearRing do
        local j = i % #nearRing + 1
        local nx = (nearRing[i].x + nearRing[j].x) * 0.5 - cx
        local ny = (nearRing[i].y + nearRing[j].y) * 0.5 - cy
        AddQuad(buffer, nearRing[i], nearRing[j], farRing[j], farRing[i], Vector3(nx, ny, 0))
    end
end

local function CapRing(buffer, ring, cx, cy, z, front)
    for i = 1, #ring do
        local j = i % #ring + 1
        AddTriangle(buffer, Vector3(cx, cy, z), ring[i], ring[j], Vector3(0, 0, front and -1 or 1))
    end
end

local function AddFrustum(buffer, cx, cy, zNear, zFar,
        nearLength, nearWidth, farLength, farWidth, bevel)
    local nearRing = RoundedRing(cx, cy, zNear, nearLength, nearWidth, bevel)
    local farRing = RoundedRing(cx, cy, zFar, farLength, farWidth, bevel)
    CapRing(buffer, nearRing, cx, cy, zNear, true)
    CapRing(buffer, farRing, cx, cy, zFar, false)
    ConnectRings(buffer, nearRing, farRing, cx, cy)
end

local function AddRoundedPrism(buffer, cx, cy, zNear, zFar, length, width, bevel)
    -- XY 四角倒角之外，Z 两端也有真实斜面，形成受光边而非描边贴纸。
    local b = math.min(bevel, (zFar - zNear) * 0.23, length * 0.12, width * 0.12)
    local top = RoundedRing(cx, cy, zNear, length - b, width - b, bevel)
    local upper = RoundedRing(cx, cy, zNear + b, length, width, bevel)
    local lower = RoundedRing(cx, cy, zFar - b, length, width, bevel)
    local bottom = RoundedRing(cx, cy, zFar, length - b, width - b, bevel)
    CapRing(buffer, top, cx, cy, zNear, true)
    CapRing(buffer, bottom, cx, cy, zFar, false)
    ConnectRings(buffer, top, upper, cx, cy)
    ConnectRings(buffer, upper, lower, cx, cy)
    ConnectRings(buffer, lower, bottom, cx, cy)
end

local function AddCylinderY(buffer, cx, cy, cz, radius, width, segments)
    local yMin, yMax = cy - width * 0.5, cy + width * 0.5
    for i = 0, segments - 1 do
        local a0, a1 = i * math.pi * 2 / segments, (i + 1) * math.pi * 2 / segments
        local p0 = Vector3(cx + math.cos(a0) * radius, yMin, cz + math.sin(a0) * radius)
        local p1 = Vector3(p0.x, yMax, p0.z)
        local p2 = Vector3(cx + math.cos(a1) * radius, yMax, cz + math.sin(a1) * radius)
        local p3 = Vector3(p2.x, yMin, p2.z)
        local radial = Vector3(math.cos((a0 + a1) * 0.5), 0, math.sin((a0 + a1) * 0.5))
        AddQuad(buffer, p0, p1, p2, p3, radial)
        AddTriangle(buffer, Vector3(cx, yMin, cz), p3, p0, Vector3(0, -1, 0))
        AddTriangle(buffer, Vector3(cx, yMax, cz), p1, p2, Vector3(0, 1, 0))
    end
end

local function AddRod(buffer, start, finish, radius, segments)
    local delta = finish - start
    local axis = delta:Normalized()
    local helper = math.abs(axis.z) < 0.8 and Vector3(0, 0, 1) or Vector3(0, 1, 0)
    local u = axis:CrossProduct(helper):Normalized()
    local v = axis:CrossProduct(u):Normalized()
    for i = 0, segments - 1 do
        local a0, a1 = i * math.pi * 2 / segments, (i + 1) * math.pi * 2 / segments
        local r0 = (u * math.cos(a0) + v * math.sin(a0)) * radius
        local r1 = (u * math.cos(a1) + v * math.sin(a1)) * radius
        AddQuad(buffer, start + r0, start + r1, finish + r1, finish + r0, r0 + r1)
        AddTriangle(buffer, start, start + r1, start + r0, -axis)
        AddTriangle(buffer, finish, finish + r0, finish + r1, axis)
    end
end

local function AddArcY(buffer, cx, cy, cz, inner, outer, width, startAngle, endAngle, steps)
    for i = 0, steps - 1 do
        local a = startAngle + (endAngle - startAngle) * i / steps
        local b = startAngle + (endAngle - startAngle) * (i + 1) / steps
        local lo, hi = {}, {}
        for _, r in ipairs({inner, outer}) do
            lo[#lo + 1] = Vector3(cx + math.cos(a) * r, cy - width * 0.5, cz + math.sin(a) * r)
            lo[#lo + 1] = Vector3(cx + math.cos(b) * r, cy - width * 0.5, cz + math.sin(b) * r)
            hi[#hi + 1] = Vector3(cx + math.cos(a) * r, cy + width * 0.5, cz + math.sin(a) * r)
            hi[#hi + 1] = Vector3(cx + math.cos(b) * r, cy + width * 0.5, cz + math.sin(b) * r)
        end
        AddQuad(buffer, lo[1], lo[2], lo[4], lo[3], Vector3(0, -1, 0))
        AddQuad(buffer, hi[1], hi[3], hi[4], hi[2], Vector3(0, 1, 0))
        local radial = Vector3(math.cos((a + b) * 0.5), 0, math.sin((a + b) * 0.5))
        AddQuad(buffer, lo[3], lo[4], hi[4], hi[3], radial)
        AddQuad(buffer, lo[1], hi[1], hi[2], lo[2], -radial)
        if i == 0 then AddQuad(buffer, lo[1], lo[3], hi[3], hi[1], Vector3(math.sin(a), 0, -math.cos(a))) end
        if i == steps - 1 then AddQuad(buffer, lo[2], hi[2], hi[4], lo[4], Vector3(-math.sin(b), 0, math.cos(b))) end
    end
end

local function AddWheels(tire, metal, positions, offset, radius, spokes)
    -- 侧视轮拱（-Z 为上）：壳体下缘绕轮胎上半圆让位，桥轴接胎内侧。
    --        车身纵梁 ====●====
    --                   /|\ 控制臂
    --                ( 轮心 )  z=0，各轮半径相同，最低点均为 +radius。
    for _, x in ipairs(positions) do
        AddRod(metal, Vector3(x, -offset + 0.08, 0), Vector3(x, offset - 0.08, 0), 0.045, 8)
        for _, sign in ipairs({-1, 1}) do
            local y = sign * offset
            -- 胎冠窄于中段，胎肩为斜面；胎侧、凹轮辋、辐条、中心盖分层。
            local bands = {{-0.10, 0.89}, {-0.075, 1}, {0.075, 1}, {0.10, 0.89}}
            local segments = 16
            for band = 1, #bands - 1 do
                for i = 0, segments - 1 do
                    local a, b = i * math.pi * 2 / segments, (i + 1) * math.pi * 2 / segments
                    local r0, r1 = radius * bands[band][2], radius * bands[band + 1][2]
                    AddQuad(tire,
                        Vector3(x + math.cos(a) * r0, y + bands[band][1], math.sin(a) * r0),
                        Vector3(x + math.cos(b) * r0, y + bands[band][1], math.sin(b) * r0),
                        Vector3(x + math.cos(b) * r1, y + bands[band + 1][1], math.sin(b) * r1),
                        Vector3(x + math.cos(a) * r1, y + bands[band + 1][1], math.sin(a) * r1),
                        Vector3(math.cos((a + b) * 0.5), 0, math.sin((a + b) * 0.5)))
                end
            end
            -- 胎侧只补两个端面，不在胎肩内部再放重叠圆柱；轮辋背面由胎侧遮住。
            for _, faceSign in ipairs({-1, 1}) do
                local cy = y + faceSign * 0.10
                for i = 0, segments - 1 do
                    local a, b = i * math.pi * 2 / segments, (i + 1) * math.pi * 2 / segments
                    AddTriangle(tire, Vector3(x, cy, 0),
                        Vector3(x + math.cos(a) * radius * 0.89, cy, math.sin(a) * radius * 0.89),
                        Vector3(x + math.cos(b) * radius * 0.89, cy, math.sin(b) * radius * 0.89), Vector3(0, faceSign, 0))
                end
            end
            local faceY = y + sign * 0.111
            AddArcY(metal, x, faceY, 0, radius * 0.53, radius * 0.64, 0.014, 0, math.pi * 2, segments)
            AddCylinderY(metal, x, faceY + sign * 0.012, 0, radius * 0.16, 0.025, 8)
            for i = 0, spokes - 1 do
                local angle = i * math.pi * 2 / spokes
                local a = Vector3(x + math.cos(angle) * radius * 0.14, faceY + sign * 0.01, math.sin(angle) * radius * 0.14)
                local b = Vector3(x + math.cos(angle + 0.15) * radius * 0.57, faceY + sign * 0.01, math.sin(angle + 0.15) * radius * 0.57)
                local edge = Vector3(-math.sin(angle), 0, math.cos(angle)) * (radius * 0.046)
                local depth = Vector3(0, -sign * radius * 0.035, 0)
                AddQuad(metal, a - edge, b - edge, b + edge, a + edge, Vector3(0, sign, 0))
                AddQuad(metal, a - edge, a - edge + depth, b - edge + depth, b - edge, -edge)
                AddQuad(metal, a + edge, b + edge, b + edge + depth, a + edge + depth, edge)
                -- 背侧也保留体积面；两端嵌入中心盖/轮圈，无需重复端盖。
                AddQuad(metal, a - edge + depth, a + edge + depth, b + edge + depth, b - edge + depth, Vector3(0, -sign, 0))
            end
            for _, dx in ipairs({-0.16, 0.16}) do
                AddRod(metal, Vector3(x + dx, sign * 0.38, -0.12), Vector3(x, y - sign * 0.095, 0), 0.026, 6)
            end
        end
    end
end

local function AddLowerBody(body, metal, length, width, topZ, bottomZ, positions, radius)
    -- 整段壳体用真实轮洞剖面，避免把实心盒子叠在轮胎上；中间窄底架贯通前后。
    AddRoundedPrism(metal, 0, 0, -0.11, 0.08, length * 0.92, width * 0.57, 0.035)
    local samples = {-length * 0.5, length * 0.5}
    local clearance = radius + 0.035
    for _, x in ipairs(positions) do
        for i = 0, 10 do
            local px = x - clearance + clearance * 2 * i / 10
            if px > -length * 0.5 and px < length * 0.5 then samples[#samples + 1] = px end
        end
    end
    table.sort(samples)
    local function Bottom(x)
        local z = bottomZ
        for _, axle in ipairs(positions) do
            local dx = x - axle
            if math.abs(dx) < clearance then z = math.min(z, -math.sqrt(clearance * clearance - dx * dx)) end
        end
        return math.max(topZ + 0.018, z)
    end
    for i = 1, #samples - 1 do
        local x0, x1 = samples[i], samples[i + 1]
        local z0, z1 = Bottom(x0), Bottom(x1)
        local outer0 = width * 0.5 - math.max(0, math.abs(x0) - length * 0.5 + 0.13) * 0.7
        local outer1 = width * 0.5 - math.max(0, math.abs(x1) - length * 0.5 + 0.13) * 0.7
        for _, sign in ipairs({-1, 1}) do
            AddQuad(body, Vector3(x0, sign * outer0, topZ), Vector3(x1, sign * outer1, topZ),
                Vector3(x1, sign * outer1, z1), Vector3(x0, sign * outer0, z0), Vector3(0, sign, 0))
        end
        AddQuad(body, Vector3(x0, -outer0, topZ), Vector3(x0, outer0, topZ),
            Vector3(x1, outer1, topZ), Vector3(x1, -outer1, topZ), Vector3(0, 0, -1))
        AddQuad(body, Vector3(x0, -outer0, z0), Vector3(x1, -outer1, z1),
            Vector3(x1, outer1, z1), Vector3(x0, outer0, z0), Vector3(0, 0, 1))
    end
    for _, sign in ipairs({-1, 1}) do
        local x, z = sign * length * 0.5, Bottom(sign * length * 0.5)
        AddQuad(body, Vector3(x, -width * 0.5 + 0.091, topZ), Vector3(x, width * 0.5 - 0.091, topZ),
            Vector3(x, width * 0.5 - 0.091, z), Vector3(x, -width * 0.5 + 0.091, z), Vector3(sign, 0, 0))
    end
end

local function AddFenders(body, positions, offset, radius)
    for _, x in ipairs(positions) do
        for _, sign in ipairs({-1, 1}) do
            AddArcY(body, x, sign * (offset - 0.075), 0, radius + 0.038, radius + 0.083,
                0.095, -math.pi + 0.10, -0.10, 12)
        end
    end
end

local function AddWindshield(glass, rearX, frontX, rearZ, frontZ, upperWidth, lowerWidth)
    -- 玻璃是一层贴合前立面的薄片，不在车顶横放一个深色盒子。
    AddQuad(glass, Vector3(rearX, -upperWidth * 0.5, rearZ), Vector3(rearX, upperWidth * 0.5, rearZ),
        Vector3(frontX, lowerWidth * 0.5, frontZ), Vector3(frontX, -lowerWidth * 0.5, frontZ), Vector3(1, 0, -1))
end

local function AddSideWindow(glass, sign, upperRear, upperFront, lowerRear, lowerFront, upperY, lowerY, topZ, bottomZ)
    AddQuad(glass, Vector3(upperRear, sign * upperY, topZ), Vector3(upperFront, sign * upperY, topZ),
        Vector3(lowerFront, sign * lowerY, bottomZ), Vector3(lowerRear, sign * lowerY, bottomZ), Vector3(0, sign, 0))
end

local function AddSurfaceWindows(glass, cx, zNear, zFar, nearLength, nearWidth, farLength, farWidth, bevel,
        topZ, bottomZ, sideRear, sideFront)
    -- 与车壳同一组锥台参数插值，窗角限制在倒角内，法向外偏 0.006 防穿面。
    local function Section(z)
        local t = (z - zNear) / (zFar - zNear)
        return (nearLength + (farLength - nearLength) * t) * 0.5,
            (nearWidth + (farWidth - nearWidth) * t) * 0.5
    end
    local topX, topY = Section(topZ)
    local bottomX, bottomY = Section(bottomZ)
    local slope = (farLength - nearLength) * 0.5 / (zFar - zNear)
    local offsetX = 0.006 * math.sqrt(1 + slope * slope)
    AddWindshield(glass, cx + topX + offsetX, cx + bottomX + offsetX, topZ, bottomZ,
        (topY - bevel) * 1.76, (bottomY - bevel) * 1.76)
    local sideSlope = (farWidth - nearWidth) * 0.5 / (zFar - zNear)
    local offsetY = 0.006 * math.sqrt(1 + sideSlope * sideSlope)
    local topRear = math.max(sideRear, cx - topX + bevel + 0.02)
    local topFront = math.min(sideFront, cx + topX - bevel - 0.02)
    local bottomRear = math.max(sideRear, cx - bottomX + bevel + 0.02)
    local bottomFront = math.min(sideFront, cx + bottomX - bevel - 0.02)
    for _, sign in ipairs({-1, 1}) do
        AddSideWindow(glass, sign, topRear, topFront, bottomRear, bottomFront,
            topY + offsetY, bottomY + offsetY, topZ, bottomZ)
    end
end

local function AddLamps(light, nose, tail, width, z)
    for _, sign in ipairs({-1, 1}) do
        AddRoundedPrism(light, nose, sign * width, z, z + 0.075, 0.022, 0.18, 0.005)
        AddRoundedPrism(light, tail, sign * width, -0.25, -0.17, 0.022, 0.14, 0.005)
    end
end

local function AddMirrors(tire, metal, x, width, z)
    for _, sign in ipairs({-1, 1}) do
        AddRod(metal, Vector3(x, sign * width, z), Vector3(x - 0.07, sign * (width + 0.12), z - 0.05), 0.018, 6)
        AddRoundedPrism(tire, x - 0.07, sign * (width + 0.14), z - 0.11, z + 0.03, 0.15, 0.08, 0.015)
        AddRoundedPrism(metal, x - 0.145, sign * (width + 0.14), z - 0.085, z + 0.005, 0.009, 0.056, 0.003)
    end
end

local function BuildTruck(body, side, tire, metal, glass, light)
    local axles = {1.04, -0.53, -1.18}
    AddLowerBody(body, metal, 3.45, 1.28, -0.40, 0.12, axles, 0.30)
    AddRoundedPrism(body, -0.62, 0, -0.78, -0.39, 1.87, 1.20, 0.08)
    AddFrustum(body, 0.98, 0, -1.02, -0.40, 1.08, 1.16, 1.18, 1.24, 0.07)
    AddRoundedPrism(body, 1.52, 0, -0.65, -0.39, 0.20, 1.18, 0.035)
    AddRoundedPrism(side, -0.62, 0, -0.81, -0.778, 1.69, 1.03, 0.045)
    for _, sign in ipairs({-1, 1}) do
        AddRoundedPrism(side, -0.62, sign * 0.615, -0.67, -0.40, 1.86, 0.036, 0.012)
        AddRoundedPrism(side, 1.02, sign * 0.615, -0.57, -0.40, 0.77, 0.035, 0.012)
        AddRod(tire, Vector3(0.60, sign * 0.622, -0.96), Vector3(0.58, sign * 0.635, -0.48), 0.012, 4)
        AddRoundedPrism(metal, 0.72, sign * 0.638, -0.59, -0.564, 0.15, 0.018, 0.006)
        AddRoundedPrism(metal, 0.47, sign * 0.66, -0.19, -0.12, 0.33, 0.14, 0.015)
        AddRoundedPrism(metal, -0.62, sign * 0.64, -0.75, -0.72, 1.88, 0.035, 0.010)
        for _, x in ipairs({-1.30, -0.95, -0.60, -0.25, 0.10}) do
            AddRoundedPrism(metal, x, sign * 0.638, -0.68, -0.43, 0.014, 0.012, 0.003)
        end
    end
    AddSurfaceWindows(glass, 0.98, -1.02, -0.40, 1.08, 1.16, 1.18, 1.24, 0.07, -0.90, -0.66, 0.63, 1.38)
    for _, y in ipairs({-0.26, 0.26}) do
        AddRod(tire, Vector3(1.558, y - 0.14, -0.682), Vector3(1.549, y + 0.07, -0.77), 0.009, 4)
    end
    AddRoundedPrism(tire, 1.634, 0, -0.59, -0.37, 0.016, 0.82, 0.008)
    for _, z in ipairs({-0.54, -0.47, -0.40}) do
        AddRoundedPrism(metal, 1.645, 0, z, z + 0.018, 0.018, 0.80, 0.004)
    end
    AddRoundedPrism(metal, 1.74, 0, -0.27, -0.17, 0.12, 1.10, 0.025)
    AddRoundedPrism(metal, -1.74, 0, -0.14, -0.045, 0.11, 1.07, 0.025)
    AddRoundedPrism(tire, -1.567, 0, -0.73, -0.43, 0.015, 1.03, 0.01)
    AddRoundedPrism(side, -1.582, 0, -0.70, -0.43, 0.017, 0.98, 0.008)
    AddRoundedPrism(metal, -1.594, 0, -0.70, -0.43, 0.009, 0.025, 0.004)
    AddMirrors(tire, metal, 1.25, 0.61, -0.81)
    AddWheels(tire, metal, axles, 0.73, 0.30, 6)
    AddFenders(body, axles, 0.73, 0.30)
    AddLamps(light, 1.65, -1.797, 0.46, -0.35)
    for _, y in ipairs({-0.39, 0, 0.39}) do
        AddRoundedPrism(light, 1.12, y, -1.053, -1.024, 0.09, 0.065, 0.006)
    end
    for _, x in ipairs({-1.24, -0.54, 0.18}) do
        for _, sign in ipairs({-1, 1}) do
            AddRoundedPrism(light, x, sign * 0.646, -0.54, -0.48, 0.065, 0.012, 0.003)
        end
    end
end

local function BuildSUV(body, side, tire, metal, glass, light)
    local axles = {1.04, -1.03}
    AddLowerBody(body, metal, 3.10, 1.28, -0.37, 0.11, axles, 0.27)
    AddFrustum(body, -0.22, 0, -0.88, -0.36, 1.90, 1.07, 2.18, 1.20, 0.16)
    AddFrustum(body, 1.22, 0, -0.48, -0.36, 0.67, 1.09, 0.79, 1.21, 0.09)
    AddRoundedPrism(body, -0.23, 0, -0.925, -0.874, 1.72, 1.02, 0.12)
    AddSurfaceWindows(glass, -0.22, -0.88, -0.36, 1.90, 1.07, 2.18, 1.20, 0.16, -0.79, -0.49, -1.05, 0.64)
    for _, sign in ipairs({-1, 1}) do
        AddRod(tire, Vector3(-0.47, sign * 0.56, -0.87), Vector3(-0.53, sign * 0.61, -0.41), 0.021, 4)
        AddRoundedPrism(side, 0, sign * 0.64, -0.39, -0.34, 2.40, 0.035, 0.010)
        AddRoundedPrism(metal, -0.0675, sign * 0.69, -0.11, -0.04, 1.355, 0.14, 0.015)
        AddRoundedPrism(metal, -0.15, sign * 0.43, -0.98, -0.94, 1.53, 0.036, 0.008)
        for _, x in ipairs({-0.78, 0.47}) do
            AddRod(metal, Vector3(x, sign * 0.43, -0.905), Vector3(x, sign * 0.43, -0.962), 0.022, 6)
            AddRoundedPrism(metal, x - 0.12, sign * 0.62, -0.43, -0.407, 0.16, 0.016, 0.004)
        end
    end
    AddMirrors(tire, metal, 0.62, 0.59, -0.53)
    AddRoundedPrism(tire, 1.562, 0, -0.43, -0.30, 0.018, 0.62, 0.008)
    AddRoundedPrism(metal, 1.58, 0, -0.28, -0.18, 0.10, 1.06, 0.020)
    AddRoundedPrism(metal, -1.58, 0, -0.29, -0.16, 0.10, 1.06, 0.020)
    AddWheels(tire, metal, axles, 0.69, 0.27, 5)
    AddFenders(body, axles, 0.69, 0.27)
    AddLamps(light, 1.563, -1.58, 0.42, -0.42)
end

local function BuildSports(body, side, tire, metal, glass, light)
    local axles = {0.96, -1.03}
    AddLowerBody(body, metal, 3.28, 1.27, -0.30, 0.08, axles, 0.25)
    AddFrustum(body, 1.00, 0, -0.44, -0.28, 0.98, 0.93, 1.16, 1.18, 0.17)
    AddFrustum(body, -0.19, 0, -0.66, -0.29, 1.22, 0.84, 1.72, 1.12, 0.17)
    AddRoundedPrism(body, -0.22, 0, -0.69, -0.649, 0.72, 0.76, 0.09)
    AddFrustum(body, -1.15, 0, -0.40, -0.29, 0.58, 1.00, 0.67, 1.14, 0.13)
    AddSurfaceWindows(glass, -0.19, -0.66, -0.29, 1.22, 0.84, 1.72, 1.12, 0.17, -0.60, -0.45, -0.72, 0.43)
    AddQuad(glass, Vector3(-0.847, -0.24, -0.60), Vector3(-0.975, -0.30, -0.41),
        Vector3(-0.975, 0.30, -0.41), Vector3(-0.847, 0.24, -0.60), Vector3(-1, 0, -1))
    for _, sign in ipairs({-1, 1}) do
        AddRoundedPrism(side, -0.0675, sign * 0.62, -0.10, -0.055, 1.395, 0.12, 0.012)
        AddRoundedPrism(tire, -0.64, sign * 0.628, -0.27, -0.12, 0.32, 0.012, 0.007)
        AddRoundedPrism(metal, -0.97, sign * 0.38, -0.48, -0.395, 0.07, 0.05, 0.010)
        AddRod(metal, Vector3(-0.97, sign * 0.38, -0.44), Vector3(-1.40, sign * 0.38, -0.535), 0.020, 6)
    end
    -- 双支脚落在后甲板，翼面不悬浮；此处不再叠通用车顶套件。
    AddRoundedPrism(side, -1.40, 0, -0.56, -0.515, 0.19, 1.17, 0.035)
    AddRoundedPrism(tire, 1.634, 0, -0.26, -0.10, 0.018, 0.81, 0.010)
    AddRoundedPrism(metal, 1.64, 0, -0.08, -0.035, 0.10, 1.15, 0.015)
    AddRoundedPrism(metal, -1.63, 0, -0.09, -0.04, 0.10, 1.04, 0.012)
    AddMirrors(tire, metal, 0.35, 0.53, -0.38)
    AddWheels(tire, metal, axles, 0.66, 0.25, 5)
    AddFenders(body, axles, 0.66, 0.25)
    AddLamps(light, 1.61, -1.67, 0.44, -0.285)
end

local function BuildVan(body, side, tire, metal, glass, light)
    local axles = {1.00, -1.15}
    AddLowerBody(body, metal, 3.22, 1.18, -0.36, 0.12, axles, 0.24)
    AddRoundedPrism(body, -0.50, 0, -0.98, -0.35, 2.05, 1.12, 0.085)
    AddFrustum(body, 1.05, 0, -0.90, -0.35, 0.99, 1.02, 1.13, 1.14, 0.06)
    AddRoundedPrism(side, -0.50, 0, -1.01, -0.977, 1.82, 0.99, 0.05)
    AddSurfaceWindows(glass, 1.05, -0.90, -0.35, 0.99, 1.02, 1.13, 1.14, 0.06, -0.81, -0.58, 0.69, 1.45)
    for _, sign in ipairs({-1, 1}) do
        AddRoundedPrism(side, -0.48, sign * 0.573, -0.79, -0.39, 1.82, 0.03, 0.010)
        AddRoundedPrism(tire, -0.45, sign * 0.595, -0.82, -0.40, 0.018, 0.012, 0.004)
        AddRoundedPrism(metal, -0.63, sign * 0.593, -0.81, -0.79, 1.42, 0.020, 0.004)
        AddRoundedPrism(metal, -0.21, sign * 0.604, -0.67, -0.643, 0.15, 0.014, 0.004)
        AddRoundedPrism(metal, 0.14, sign * 0.63, -0.10, -0.05, 1.00, 0.12, 0.012)
    end
    AddRoundedPrism(tire, -1.53, 0, -0.86, -0.39, 0.018, 0.99, 0.008)
    AddRoundedPrism(side, -1.547, 0, -0.84, -0.39, 0.018, 0.95, 0.008)
    AddRoundedPrism(metal, -1.56, 0, -0.83, -0.40, 0.009, 0.025, 0.004)
    AddRoundedPrism(metal, -1.64, 0, -0.11, -0.035, 0.15, 0.91, 0.015)
    AddRoundedPrism(metal, 1.60, 0, -0.27, -0.18, 0.075, 1.01, 0.020)
    AddMirrors(tire, metal, 1.20, 0.56, -0.67)
    AddWheels(tire, metal, axles, 0.65, 0.24, 5)
    AddFenders(body, axles, 0.65, 0.24)
    AddLamps(light, 1.62, -1.64, 0.42, -0.40)
end

local function BuildArmored(body, side, tire, metal, glass, light)
    local axles = {1.10, 0, -1.10}
    AddLowerBody(body, metal, 3.26, 1.35, -0.38, 0.11, axles, 0.23)
    AddFrustum(body, -0.35, 0, -0.85, -0.37, 1.95, 1.05, 2.26, 1.29, 0.15)
    AddFrustum(body, 1.03, 0, -0.66, -0.36, 0.85, 0.91, 1.11, 1.19, 0.15)
    AddRoundedPrism(side, -0.25, 0, -0.89, -0.848, 1.55, 0.88, 0.09)
    AddSurfaceWindows(glass, 1.03, -0.66, -0.36, 0.85, 0.91, 1.11, 1.19, 0.15, -0.59, -0.45, 0.75, 1.35)
    for _, sign in ipairs({-1, 1}) do
        for _, x in ipairs({-1.02, -0.40, 0.22}) do
            AddFrustum(side, x, sign * 0.619, -0.70, -0.41, 0.51, 0.065, 0.56, 0.105, 0.016)
            AddRoundedPrism(metal, x + 0.13, sign * 0.677, -0.59, -0.552, 0.035, 0.012, 0.004)
        end
        AddRod(metal, Vector3(-0.87, sign * 0.37, -0.873), Vector3(-0.87, sign * 0.37, -0.91), 0.025, 6)
        AddRod(metal, Vector3(-0.19, sign * 0.37, -0.873), Vector3(-0.19, sign * 0.37, -0.91), 0.025, 6)
        AddRoundedPrism(metal, -0.53, sign * 0.37, -0.935, -0.90, 0.77, 0.040, 0.008)
    end
    AddRoundedPrism(tire, 1.638, 0, -0.38, -0.25, 0.015, 0.89, 0.009)
    AddRoundedPrism(metal, 1.68, 0, -0.31, -0.18, 0.14, 1.09, 0.025)
    AddRoundedPrism(metal, -1.67, 0, -0.31, -0.18, 0.12, 1.07, 0.025)
    AddWheels(tire, metal, axles, 0.72, 0.23, 8)
    AddFenders(body, axles, 0.72, 0.23)
    AddLamps(light, 1.655, -1.70, 0.43, -0.38)
end

local function BuildBuggy(body, side, tire, metal, glass, light)
    local axles = {0.97, -0.98}
    AddLowerBody(body, metal, 2.96, 1.05, -0.29, 0.07, axles, 0.28)
    AddFrustum(body, 1.06, 0, -0.42, -0.28, 0.75, 0.70, 0.92, 0.94, 0.12)
    AddRoundedPrism(side, -0.39, 0, -0.38, -0.29, 1.06, 0.78, 0.10)
    -- 开放式座舱有座椅和连接到侧围的管架，不用深色实心盒冒充驾驶舱。
    for _, sign in ipairs({-1, 1}) do
        AddRoundedPrism(tire, -0.34, sign * 0.20, -0.46, -0.38, 0.39, 0.28, 0.035)
        AddRoundedPrism(tire, -0.56, sign * 0.20, -0.66, -0.43, 0.095, 0.27, 0.025)
        local footFront = Vector3(0.35, sign * 0.43, -0.27)
        local topFront = Vector3(0.04, sign * 0.40, -0.78)
        local topRear = Vector3(-0.70, sign * 0.40, -0.78)
        local footRear = Vector3(-1.04, sign * 0.43, -0.28)
        AddRod(metal, footFront, topFront, 0.036, 8)
        AddRod(metal, topFront, topRear, 0.036, 8)
        AddRod(metal, topRear, footRear, 0.036, 8)
        AddRod(metal, footFront, footRear, 0.031, 8)
        AddRod(metal, Vector3(-0.72, sign * 0.50, -0.25), Vector3(-0.98, sign * 0.682, 0), 0.028, 6)
        AddRod(metal, Vector3(0.35, sign * 0.43, -0.29), Vector3(0.97, sign * 0.682, 0), 0.028, 6)
    end
    for _, x in ipairs({0.04, -0.70}) do
        AddRod(metal, Vector3(x, -0.40, -0.78), Vector3(x, 0.40, -0.78), 0.036, 8)
    end
    AddRod(metal, Vector3(-0.70, -0.40, -0.78), Vector3(-1.04, 0.43, -0.27), 0.026, 6)
    AddWindshield(glass, 0.055, 0.31, -0.755, -0.32, 0.76, 0.80)
    AddRoundedPrism(metal, 1.51, 0, -0.29, -0.20, 0.075, 1.07, 0.02)
    for _, sign in ipairs({-1, 1}) do
        AddRod(metal, Vector3(1.15, sign * 0.36, -0.20), Vector3(1.51, sign * 0.36, -0.27), 0.025, 6)
        AddRoundedPrism(light, 1.43, sign * 0.29, -0.50, -0.43, 0.09, 0.12, 0.012)
        AddRod(metal, Vector3(1.30, sign * 0.29, -0.37), Vector3(1.43, sign * 0.29, -0.465), 0.023, 6)
    end
    AddRoundedPrism(metal, -1.52, 0, -0.29, -0.20, 0.075, 1.01, 0.02)
    AddWheels(tire, metal, axles, 0.78, 0.28, 6)
    AddFenders(body, axles, 0.78, 0.28)
    -- 沙地车轮距宽于窄侧壳，轮眉必须通过短支座接回侧围，不能悬浮在胎外。
    for _, x in ipairs(axles) do
        for _, sign in ipairs({-1, 1}) do
            AddRod(metal, Vector3(x, sign * 0.50, -0.278), Vector3(x, sign * 0.688, -0.332), 0.022, 6)
        end
    end
    AddLamps(light, 1.55, -1.56, 0.38, -0.32)
end

local BUILDERS = {
    default = BuildTruck, arctic = BuildSUV, crimson = BuildSports,
    jade = BuildVan, obsidian = BuildArmored, rally = BuildBuggy,
}
-- 只保留最近一个车型的不可变顶点/法线，零引擎资源引用；同车型补弹只提交不重算。
local meshCache = {key = "", sections = {}, count = 0, fit = 1, radius = 0}

-- 整车包围盒中心；轮廓围绕它等比放大，所以轮廓到原点的距离不等于车体半径 × 放大倍率。
local function BodyCenter(sections)
    local minX, minY, minZ = math.huge, math.huge, math.huge
    local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
    for i = 1, SECTION_COUNT do
        for _, vertex in ipairs(sections[i]) do
            local p = vertex.position
            minX, minY, minZ = math.min(minX, p.x), math.min(minY, p.y), math.min(minZ, p.z)
            maxX, maxY, maxZ = math.max(maxX, p.x), math.max(maxY, p.y), math.max(maxZ, p.z)
        end
    end
    return Vector3((minX + maxX) * 0.5, (minY + maxY) * 0.5, (minZ + maxZ) * 0.5)
end

local function PlanarRadius(vertices, center, scale)
    local radius = 0
    for _, vertex in ipairs(vertices) do
        local p = vertex.position
        if center then p = center + (p - center) * scale end
        radius = math.max(radius, math.sqrt(p.x * p.x + p.y * p.y))
    end
    return radius
end

-- 轮廓壳由车体全部六段三角面派生：等比放大 → 翻转绕序 → 法线随绕序取反。
-- 必须覆盖全部六段（含侧围/轮胎/金属/玻璃/灯具），只取车身主漆会让轮胎、
-- 轮眉、后视镜穿出白边，轮廓就断成一截一截。
local function BuildOutline(sections, outline, center, scale)
    for sectionIndex = 1, SECTION_COUNT do
        local body = sections[sectionIndex]
        for i = 1, #body, 3 do
            local a = center + (body[i].position - center) * scale
            local b = center + (body[i + 1].position - center) * scale
            local c = center + (body[i + 2].position - center) * scale
            local normal = FaceNormal(c, b, a)
            outline[#outline + 1] = {position = a, normal = normal}
            outline[#outline + 1] = {position = c, normal = normal}
            outline[#outline + 1] = {position = b, normal = normal}
        end
    end
end

local function GetMesh(key)
    if meshCache.key == key then return meshCache end
    ---@type table<integer, {position: Vector3, normal: Vector3}[]>
    local sections = {}
    for i = 1, OUTLINE_SECTION do sections[i] = {} end
    BUILDERS[key](sections[1], sections[2], sections[3], sections[4], sections[5], sections[6])
    -- 轮廓围绕整车包围盒中心放大，缩放后的半径必须单独量，不能拿车体半径乘倍率。
    -- 放大是绕包围盒中心做的，所以“离原点的距离”对车体与轮廓并不单调；
    -- 必须取两者较大值作为碰撞圆约束，否则轮廓会挤掉车体原本的 2% 余量。
    local center = BodyCenter(sections)
    local bodyRadius, outlineRadius = 0, 0
    for i = 1, SECTION_COUNT do
        bodyRadius = math.max(bodyRadius, PlanarRadius(sections[i]))
        outlineRadius = math.max(outlineRadius, PlanarRadius(sections[i], center, OUTLINE_SCALE))
    end
    local maxRadius = math.max(bodyRadius, outlineRadius)
    local fit = math.min(1, PLANAR_RADIUS / maxRadius)
    local count = 0
    for i = 1, SECTION_COUNT do
        local vertices = sections[i]
        for j = 1, #vertices, 3 do
            local a, b, c = vertices[j].position * fit, vertices[j + 1].position * fit, vertices[j + 2].position * fit
            vertices[j].position, vertices[j + 1].position, vertices[j + 2].position = a, b, c
            local normal = FaceNormal(a, b, c)
            vertices[j].normal, vertices[j + 1].normal, vertices[j + 2].normal = normal, normal, normal
        end
        count = count + #vertices
    end
    -- 中心随车体一起缩放，轮廓仍围绕缩放后的包围盒中心对称。
    BuildOutline(sections, sections[OUTLINE_SECTION], center * fit, OUTLINE_SCALE)
    count = count + #sections[OUTLINE_SECTION]
    local radius = outlineRadius * fit
    meshCache = {key = key, sections = sections, count = count, fit = fit, radius = radius}
    print(string.format("[VehicleGeometry] key=%s vertices=%d sections=%d bodyR=%.4f outlineR=%.4f fit=%.4f",
        key, count, OUTLINE_SECTION, bodyRadius * fit, radius, fit))
    return meshCache
end

---@param geometry CustomGeometry
---@param vehicleKey string
---@param materials Material[] 六段车体材质
---@param outlineMaterial Material|nil 白色轮廓壳材质；缺省则不绑定，该段不参与绘制
function VehicleGeometry.Build(geometry, vehicleKey, materials, outlineMaterial)
    local key = BUILDERS[vehicleKey] and vehicleKey or "default"
    local mesh = GetMesh(key)
    geometry:Clear()
    geometry:SetNumGeometries(OUTLINE_SECTION)
    geometry:SetDynamic(false)
    for sectionIndex = 0, OUTLINE_SECTION - 1 do
        geometry:BeginGeometry(sectionIndex, TRIANGLE_LIST)
        for _, vertex in ipairs(mesh.sections[sectionIndex + 1]) do
            geometry:DefineVertex(vertex.position)
            geometry:DefineNormal(vertex.normal)
        end
    end
    geometry:Commit()
    for sectionIndex = 0, SECTION_COUNT - 1 do
        geometry:SetMaterial(sectionIndex, materials[sectionIndex + 1])
    end
    if outlineMaterial then
        ---@cast outlineMaterial Material
        geometry:SetMaterial(SECTION_COUNT, outlineMaterial)
    end
end

return VehicleGeometry
