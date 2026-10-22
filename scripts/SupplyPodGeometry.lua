-- SupplyPodGeometry.lua
-- 结算补给舱的程序化几何（Y-up 局部空间，中心在原点）。
-- 全部是实体零件：倒角盒、环带、八面体；不含贴图伪造的结构线。
-- 供 scripts/ui/SupplyPodShowcase.lua 渲染到 RenderTexture 后贴进 NanoVG。
local SupplyPodGeometry = {}

-- 与 web 原型一致的舱体尺寸（米）
local W, H, D = 2.66, 1.12, 1.78
local LOWER = 0.84          -- 下箱体高度：以上是围栏 + 真开口
local PLATE_T = 0.10
local GAP = 0.062

local function FaceNormal(a, b, c)
    local ux, uy, uz = b.x - a.x, b.y - a.y, b.z - a.z
    local vx, vy, vz = c.x - a.x, c.y - a.y, c.z - a.z
    local nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
    local len = math.sqrt(nx * nx + ny * ny + nz * nz)
    if len < 1e-6 then return Vector3(0, 1, 0) end
    return Vector3(nx / len, ny / len, nz / len)
end

local function AddTri(buf, a, b, c, expected)
    local n = FaceNormal(a, b, c)
    if expected and n:DotProduct(expected) < 0 then
        b, c = c, b
        n = FaceNormal(a, b, c)
    end
    buf[#buf + 1] = { position = a, normal = n }
    buf[#buf + 1] = { position = b, normal = n }
    buf[#buf + 1] = { position = c, normal = n }
end

local function AddQuad(buf, a, b, c, d, expected)
    AddTri(buf, a, b, c, expected)
    AddTri(buf, a, c, d, expected)
end

--- 倒角盒：6 个主面 + 12 条 45° 倒角带 + 8 个角三角。
---@param buf table
---@param cx number
---@param cy number
---@param cz number
---@param sx number
---@param sy number
---@param sz number
---@param bevel number
local function ChamferBox(buf, cx, cy, cz, sx, sy, sz, bevel)
    local hx, hy, hz = sx * 0.5, sy * 0.5, sz * 0.5
    local b = math.max(0.0005, math.min(bevel, hx * 0.45, hy * 0.45, hz * 0.45))
    local ix, iy, iz = hx - b, hy - b, hz - b
    local function P(x, y, z) return Vector3(cx + x, cy + y, cz + z) end

    -- 6 个主面
    local faces = {
        { axis = 1, sign = 1 }, { axis = 1, sign = -1 },
        { axis = 2, sign = 1 }, { axis = 2, sign = -1 },
        { axis = 3, sign = 1 }, { axis = 3, sign = -1 },
    }
    for _, f in ipairs(faces) do
        local n = Vector3(0, 0, 0)
        if f.axis == 1 then n.x = f.sign elseif f.axis == 2 then n.y = f.sign else n.z = f.sign end
        local pts
        if f.axis == 1 then
            local x = f.sign * hx
            pts = { P(x, -iy, -iz), P(x, -iy, iz), P(x, iy, iz), P(x, iy, -iz) }
        elseif f.axis == 2 then
            local y = f.sign * hy
            pts = { P(-ix, y, -iz), P(ix, y, -iz), P(ix, y, iz), P(-ix, y, iz) }
        else
            local z = f.sign * hz
            pts = { P(-ix, -iy, z), P(ix, -iy, z), P(ix, iy, z), P(-ix, iy, z) }
        end
        AddQuad(buf, pts[1], pts[2], pts[3], pts[4], n)
    end

    -- 12 条边倒角：每对轴 × 4 组符号
    local axes = { { 1, 2, 3 }, { 2, 3, 1 }, { 3, 1, 2 } } -- {主轴 a, 邻轴 b, 第三轴 c}
    local half = { hx, hy, hz }
    local inner = { ix, iy, iz }
    for _, pair in ipairs(axes) do
        local a, b2, c2 = pair[1], pair[2], pair[3]
        for _, sa in ipairs({ 1, -1 }) do
            for _, sb in ipairs({ 1, -1 }) do
                -- 沿第三轴的 ± 两端各生成一条：这里按“a 轴面 + b 轴面”的接缝
                for _, sc in ipairs({ 1, -1 }) do
                    local p1 = { 0, 0, 0 }
                    local p2 = { 0, 0, 0 }
                    local p3 = { 0, 0, 0 }
                    local p4 = { 0, 0, 0 }
                    p1[a] = sa * half[a]; p1[b2] = sb * inner[b2]; p1[c2] = sc * inner[c2]
                    p2[a] = sa * inner[a]; p2[b2] = sb * half[b2]; p2[c2] = sc * inner[c2]
                    p3[a] = sa * inner[a]; p3[b2] = sb * half[b2]; p3[c2] = sc * half[c2]
                    p4[a] = sa * half[a]; p4[b2] = sb * inner[b2]; p4[c2] = sc * half[c2]
                    local n = Vector3(0, 0, 0)
                    if a == 1 then n.x = sa elseif a == 2 then n.y = sa else n.z = sa end
                    if b2 == 1 then n.x = sb elseif b2 == 2 then n.y = sb else n.z = sb end
                    n = n:Normalized()
                    AddQuad(buf,
                        P(p1[1], p1[2], p1[3]), P(p2[1], p2[2], p2[3]),
                        P(p3[1], p3[2], p3[3]), P(p4[1], p4[2], p4[3]), n)
                end
            end
        end
    end

    -- 8 个角三角
    for _, sx2 in ipairs({ 1, -1 }) do
        for _, sy2 in ipairs({ 1, -1 }) do
            for _, sz2 in ipairs({ 1, -1 }) do
                local a = P(sx2 * hx, sy2 * iy, sz2 * iz)
                local b2 = P(sx2 * ix, sy2 * hy, sz2 * iz)
                local c = P(sx2 * ix, sy2 * iy, sz2 * hz)
                AddTri(buf, a, b2, c, Vector3(sx2, sy2, sz2):Normalized())
            end
        end
    end
end

--- 圆环带（绕 Y 轴），用于推进环 / 陀螺环。
---@param buf table
---@param radius number
---@param thickness number
---@param segments integer
---@param cx number|nil
---@param cy number|nil
---@param cz number|nil
local function RingBand(buf, radius, thickness, segments, cx, cy, cz)
    cx, cy, cz = cx or 0, cy or 0, cz or 0
    local r = radius
    local t = thickness
    local segs = math.max(8, segments)
    for i = 0, segs - 1 do
        local a0 = (i / segs) * math.pi * 2
        local a1 = ((i + 1) / segs) * math.pi * 2
        local c0, s0 = math.cos(a0), math.sin(a0)
        local c1, s1 = math.cos(a1), math.sin(a1)
        -- 环截面：内侧 (r-t) 与外侧 (r)
        local o0 = Vector3(cx + c0 * r, cy, cz + s0 * r)
        local o1 = Vector3(cx + c1 * r, cy, cz + s1 * r)
        local i0 = Vector3(cx + c0 * (r - t), cy, cz + s0 * (r - t))
        local i1 = Vector3(cx + c1 * (r - t), cy, cz + s1 * (r - t))
        local up0 = Vector3(o0.x, cy + t * 0.5, o0.z)
        local up1 = Vector3(o1.x, cy + t * 0.5, o1.z)
        local dn0 = Vector3(o0.x, cy - t * 0.5, o0.z)
        local dn1 = Vector3(o1.x, cy - t * 0.5, o1.z)
        local nOut = Vector3((c0 + c1) * 0.5, 0, (s0 + s1) * 0.5):Normalized()
        if nOut:Length() < 0.01 then nOut = Vector3(1, 0, 0) end
        AddQuad(buf, up0, up1, o1, o0, Vector3(0, 1, 0))
        AddQuad(buf, dn0, o0, o1, dn1, Vector3(0, -1, 0))
        AddQuad(buf, i0, i1, up1, up0, Vector3(-nOut.x, 0, -nOut.z))
        AddQuad(buf, dn0, dn1, i1, i0, nOut)
    end
end

--- 切割钻石：上下双锥 + 台面，读作"战利品"。
---@param buf table
---@param cy number
---@param r number
---@param segs integer
local function Diamond(buf, cy, r, segs)
    local n = math.max(6, segs)
    local topY = cy + r * 0.42
    local girdleY = cy
    local botY = cy - r * 0.78
    local inner = r * 0.58
    local top = Vector3(0, topY, 0)
    local bot = Vector3(0, botY, 0)
    for i = 0, n - 1 do
        local a0 = (i / n) * math.pi * 2
        local a1 = ((i + 1) / n) * math.pi * 2
        local am = (a0 + a1) * 0.5
        local g0 = Vector3(math.cos(a0) * r, girdleY, math.sin(a0) * r)
        local g1 = Vector3(math.cos(a1) * r, girdleY, math.sin(a1) * r)
        -- 台面（顶部小平面）
        local t0 = Vector3(math.cos(a0) * inner, topY, math.sin(a0) * inner)
        local t1 = Vector3(math.cos(a1) * inner, topY, math.sin(a1) * inner)
        AddQuad(buf, t1, t0, g0, g1, Vector3(math.cos(am), 0.55, math.sin(am)))
        -- 顶部锥面
        AddTri(buf, t1, g1, g0, Vector3(math.cos(am), 0.9, math.sin(am)))
        -- 底部锥面
        AddTri(buf, g1, bot, g0, Vector3(math.cos(am), -0.9, math.sin(am)))
    end
    -- 顶部封口
    for i = 1, n do
        local a0 = ((i - 1) / n) * math.pi * 2
        local a1 = (i / n) * math.pi * 2
        local p0 = Vector3(math.cos(a0) * inner, topY, math.sin(a0) * inner)
        local p1 = Vector3(math.cos(a1) * inner, topY, math.sin(a1) * inner)
        AddTri(buf, top, p1, p0, Vector3(0, 1, 0))
    end
end

--- 八面体（能量核心）。
---@param buf table
---@param cy number
---@param r number
local function Octahedron(buf, cy, r)
    local px, py, pz = Vector3(r, cy, 0), Vector3(0, cy + r, 0), Vector3(0, cy, r)
    local nx, ny, nz = Vector3(-r, cy, 0), Vector3(0, cy - r, 0), Vector3(0, cy, -r)
    local tris = {
        { px, py, pz }, { pz, py, nx }, { nx, py, nz }, { nz, py, px },
        { pz, ny, px }, { nx, ny, pz }, { nz, ny, nx }, { px, ny, nz },
    }
    for _, t in ipairs(tris) do AddTri(buf, t[1], t[2], t[3]) end
end

local SECTIONS = 8
local SEC_HULL, SEC_ARMOR, SEC_RIB, SEC_WARN, SEC_DARK, SEC_TIER, SEC_GLOW, SEC_OUTLINE = 1, 2, 3, 4, 5, 6, 7, 8

local function NewBuffers(count)
    local bufs = {}
    for i = 1, count do bufs[i] = {} end
    return bufs
end

--- 舱体：下箱体 + 围栏（真开口）+ 装甲分块 + 肋 + 护角 + 警示带 + 推进环。
---@return table[] buffers
function SupplyPodGeometry.BuildBody()
    local b = NewBuffers(SECTIONS)
    local hull, armor, rib, warn, dark, tier, glow = b[1], b[2], b[3], b[4], b[5], b[6], b[7]

    -- 下箱体
    ChamferBox(hull, 0, LOWER * 0.5, 0, W, LOWER, D, 0.05)

    -- 四面围栏（顶部留真开口）
    local railT = 0.14
    local railH = H - LOWER
    for _, sz in ipairs({ 1, -1 }) do
        ChamferBox(hull, 0, LOWER + railH * 0.5, sz * (D * 0.5 - railT * 0.5), W, railH, railT, 0.03)
    end
    for _, sx in ipairs({ 1, -1 }) do
        ChamferBox(hull, sx * (W * 0.5 - railT * 0.5), LOWER + railH * 0.5, 0, railT, railH, D - railT * 2, 0.03)
    end

    -- 内腔：深色内底 + 四壁
    ChamferBox(dark, 0, LOWER + 0.02, 0, W - 0.26, 0.05, D - 0.26, 0.02)
    local wallT = 0.06
    for _, sz in ipairs({ 1, -1 }) do
        ChamferBox(dark, 0, LOWER + 0.19, sz * (D * 0.5 - railT - wallT * 0.5), W - 0.30, 0.42, wallT, 0.02)
    end
    for _, sx in ipairs({ 1, -1 }) do
        ChamferBox(dark, sx * (W * 0.5 - railT - wallT * 0.5), LOWER + 0.19, 0, wallT, 0.42, D - 0.30, 0.02)
    end

    -- 装甲分块：正面 3×3、侧面 2×3（缝是真实间隙）
    local rows, padX = 3, 0.30
    local cellH = (LOWER - 0.16 - GAP * (rows - 1)) / rows
    local colsF = 3
    local cellW = (W - padX * 2 - GAP * (colsF - 1)) / colsF
    for _, sz in ipairs({ 1, -1 }) do
        for r = 0, rows - 1 do
            for c = 0, colsF - 1 do
                local x = -W * 0.5 + padX + cellW * 0.5 + c * (cellW + GAP)
                local y = 0.10 + cellH * 0.5 + r * (cellH + GAP)
                ChamferBox(armor, x, y, sz * (D * 0.5 - PLATE_T * 0.5 + 0.005), cellW, cellH, PLATE_T, 0.03)
            end
        end
    end
    local colsS = 2
    local cellD = (D - 0.34 - GAP) / colsS
    for _, sx in ipairs({ 1, -1 }) do
        for r = 0, rows - 1 do
            for c = 0, colsS - 1 do
                local y = 0.10 + cellH * 0.5 + r * (cellH + GAP)
                local z = -D * 0.5 + 0.17 + cellD * 0.5 + c * (cellD + GAP)
                ChamferBox(armor, sx * (W * 0.5 - PLATE_T * 0.5 + 0.005), y, z, PLATE_T, cellH, cellD, 0.03)
            end
        end
    end

    -- 四角竖肋
    for _, sz in ipairs({ 1, -1 }) do
        for _, sx in ipairs({ 1, -1 }) do
            ChamferBox(rib, sx * (W * 0.5 - 0.15), H * 0.5, sz * (D * 0.5 - 0.035), 0.115, H + 0.02, 0.115, 0.03)
            -- 肋上铆钉
            for k = 0, 2 do
                ChamferBox(dark, sx * (W * 0.5 - 0.15), 0.26 + k * 0.26, sz * (D * 0.5 + 0.03), 0.075, 0.075, 0.04, 0.02)
            end
        end
    end

    -- 顶部导轨
    for _, sz in ipairs({ 1, -1 }) do
        ChamferBox(rib, 0, H - 0.02, sz * (D * 0.5 - 0.02), W + 0.02, 0.10, 0.12, 0.03)
    end
    for _, sx in ipairs({ 1, -1 }) do
        ChamferBox(rib, sx * (W * 0.5 - 0.02), H - 0.02, 0, 0.12, 0.10, D + 0.02, 0.03)
    end

    -- 四角护角（斜切块）
    for _, sz in ipairs({ 1, -1 }) do
        for _, sx in ipairs({ 1, -1 }) do
            ChamferBox(armor, sx * (W * 0.5 - 0.13), 0.15, sz * (D * 0.5 - 0.13), 0.30, 0.30, 0.30, 0.09)
        end
    end

    -- 警示斜纹带（金 / 黑实体小块）
    local segW, segH = 0.165, 0.105
    for i = 0, 5 do
        local x = -W * 0.5 + 0.52 + i * (segW + 0.010)
        local target = (i % 2 == 0) and warn or dark
        ChamferBox(target, x, 0.175, D * 0.5 + 0.015, segW, segH, 0.035, 0.012)
    end

    -- 锁扣座 + 发光灯条
    for _, sz in ipairs({ 1, -1 }) do
        for _, sx in ipairs({ 1, -1 }) do
            ChamferBox(dark, sx * 0.76, H + 0.02, sz * 0.52, 0.20, 0.07, 0.14, 0.03)
            ChamferBox(glow, sx * 0.76, H + 0.058, sz * 0.52, 0.10, 0.02, 0.05, 0.008)
        end
    end

    -- 内腔底部能量接口
    ChamferBox(tier, 0, LOWER - 0.01, 0, 0.68, 0.06, 0.68, 0.02)
    -- 内腔发光底：开盖后舱口不再是黑洞
    ChamferBox(glow, 0, LOWER - 0.05, 0, W - 0.42, 0.02, D - 0.42, 0.02)

    -- 悬浮推进环
    RingBand(tier, 1.00, 0.075, 24, 0, -0.03, 0)
    -- 底部落地暗盘（影子的替代：不依赖贴图，纯几何）
    RingBand(dark, 1.72, 0.36, 28, 0, -0.30, 0)
    -- 舱口内发光台：核心升起时脚下有光
    RingBand(glow, 0.62, 0.05, 24, 0, LOWER + 0.035, 0)

    -- 轮廓壳：整体放大并翻转绕序，背面剔除后只剩远侧壳 → 物体外缘一圈黑边。
    -- 与 VehicleGeometry 第 7 段同款做法；放大率小一些，避免吃进细节。
    local OUTLINE_SCALE = 1.045
    local outline = b[SEC_OUTLINE]
    for sec = 1, SEC_OUTLINE - 1 do
        local src = b[sec]
        for i = 1, #src - 2, 3 do
            local a, bb, c = src[i], src[i + 1], src[i + 2]
            if a and bb and c then
                local function S2(v)
                    return Vector3(v.position.x * OUTLINE_SCALE, v.position.y * OUTLINE_SCALE,
                        v.position.z * OUTLINE_SCALE)
                end
                -- 翻转绕序（重算法线朝内），配合背面剔除
                AddTri(outline, S2(c), S2(bb), S2(a))
            end
        end
    end

    return b
end

--- 单扇舱盖（side = 1 左门 / -1 右门），局部原点在外侧铰链处。
---@param side number
---@return table[] buffers
function SupplyPodGeometry.BuildLid(side)
    local b = NewBuffers(5)
    local panel, armor, rib, glow, dark = b[1], b[2], b[3], b[4], b[5]
    local panelW = W * 0.5 - 0.05
    local panelD = D - 0.02
    local cx = side * panelW * 0.5

    ChamferBox(panel, cx, 0.08, 0, panelW, 0.16, panelD, 0.04)
    for i = 0, 2 do
        local step = (panelD - 0.16) / 3
        local z = -(panelD - 0.16) * 0.5 + step * (i + 0.5)
        ChamferBox(armor, cx, 0.165, z, panelW - 0.14, 0.10, step - 0.04, 0.03)
    end
    -- 外缘压条
    ChamferBox(rib, side * 0.05, 0.14, 0, 0.10, 0.13, panelD + 0.02, 0.03)
    -- 铰链
    for _, dz in ipairs({ -0.56, 0.56 }) do
        ChamferBox(dark, 0, 0.02, dz, 0.16, 0.16, 0.30, 0.06)
    end
    -- 内侧深色衬板
    ChamferBox(dark, cx, -0.035, 0, panelW + 0.02, 0.09, panelD + 0.02, 0.02)
    -- 内侧能量导管（发光）
    for _, dz in ipairs({ -0.50, 0, 0.50 }) do
        ChamferBox(glow, cx, -0.088, dz, panelW - 0.26, 0.04, 0.075, 0.016)
    end
    -- 内侧结构梁
    for _, dx in ipairs({ 0.22, 0.56 }) do
        ChamferBox(dark, side * dx, -0.088, 0, 0.07, 0.05, panelD - 0.14, 0.015)
    end

    return b
end

--- 能量核心（八面体）。
---@return table[] buffers
function SupplyPodGeometry.BuildCore()
    local b = NewBuffers(1)
    Diamond(b[1], 0, 0.44, 8)
    return b
end

--- 环状分布的小钻石群。
---@param count integer
---@param radius number
---@param size number
---@return table[] buffers
function SupplyPodGeometry.BuildShards(count, radius, size)
    local b = NewBuffers(1)
    local buf = b[1]
    for i = 0, count - 1 do
        local a = (i / count) * math.pi * 2
        local cx = math.cos(a) * radius
        local cz = math.sin(a) * radius
        local cy = (i % 2 == 0) and 0.10 or -0.06
        local sub = {}
        Diamond(sub, 0, size, 6)
        for _, v in ipairs(sub) do
            buf[#buf + 1] = {
                position = Vector3(v.position.x + cx, v.position.y + cy, v.position.z + cz),
                normal = v.normal,
            }
        end
    end
    return b
end

--- 陀螺环。
---@return table[] buffers
function SupplyPodGeometry.BuildGyro(radius, thickness)
    local b = NewBuffers(1)
    -- 默认绕 Y 轴；调用方通过节点旋转摆出不同轴向
    RingBand(b[1], radius, thickness, 28, 0, 0, 0)
    return b
end

--- 把 buffer 写入 CustomGeometry（每段一个材质）。
---@param geometry CustomGeometry
---@param buffers table[]
---@param materials Material[]
function SupplyPodGeometry.Apply(geometry, buffers, materials)
    local count = #buffers
    geometry:Clear()
    geometry:SetNumGeometries(count)
    geometry:SetDynamic(false)
    for section = 0, count - 1 do
        geometry:BeginGeometry(section, TRIANGLE_LIST)
        local buf = buffers[section + 1]
        for _, vertex in ipairs(buf) do
            geometry:DefineVertex(vertex.position)
            geometry:DefineNormal(vertex.normal)
        end
    end
    geometry:Commit()
    -- 顶点写完后统一挂材质：Clear/BeginGeometry 都会重置材质槽
    for section = 0, count - 1 do
        local material = materials[section + 1]
        if material then geometry:SetMaterial(section, material) end
    end
end

---@return number
function SupplyPodGeometry.GetWidth() return W end
---@return number
function SupplyPodGeometry.GetDepth() return D end
---@return number
function SupplyPodGeometry.GetHeight() return H end

return SupplyPodGeometry
