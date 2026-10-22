-- StageBadgeGeometry.lua
-- 选关界面的「关卡芯片」3D 几何（Y-up，正面朝 +Z）。
-- 造型与现有 2D 节点一致：尖顶六边形（pointy-top）、立体关号、底部三颗菱形星。
-- 全部实体零件：倒角六棱柱、凹槽、凸起数字段、菱形星、发光槽、黑色轮廓壳。
local StageBadgeGeometry = {}

local R = 1.00          -- 芯片外接圆半径（世界单位）
local T = 0.22          -- 芯片厚度
local BEVEL = 0.05

local function FaceNormal(a, b, c)
    local ux, uy, uz = b.x - a.x, b.y - a.y, b.z - a.z
    local vx, vy, vz = c.x - a.x, c.y - a.y, c.z - a.z
    local nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
    local len = math.sqrt(nx * nx + ny * ny + nz * nz)
    if len < 1e-6 then return Vector3(0, 0, 1) end
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

--- 尖顶六边形的 6 个角点（XY 平面，z 指定）。
---@param radius number
---@param z number
---@param cy number
---@return Vector3[]
local function HexPoints(radius, z, cy)
    local pts = {}
    for i = 0, 5 do
        local a = math.pi / 3 * i - math.pi / 2
        pts[i + 1] = Vector3(math.cos(a) * radius, (cy or 0) + math.sin(a) * radius, z)
    end
    return pts
end

--- 倒角六棱柱：前后两个内缩六边形面 + 侧面 + 前后各一圈 45° 倒角带。
---@param buf table
---@param radius number
---@param thickness number
---@param bevel number
---@param cy number
local function HexPrism(buf, radius, thickness, bevel, cy)
    local b = math.min(bevel, thickness * 0.45, radius * 0.2)
    local zf, zb = thickness * 0.5, -thickness * 0.5
    local ri = radius - b * 0.7          -- 倒角后正面内缩
    local front = HexPoints(ri, zf, cy)
    local back = HexPoints(ri, zb, cy)
    local outer = HexPoints(radius, zf - b, cy)   -- 侧面最外圈（略内含）
    local outerB = HexPoints(radius, zb + b, cy)

    -- 正面（+Z）
    for i = 1, 6 do
        local j = (i % 6) + 1
        AddTri(buf, front[i], front[j], Vector3(0, cy or 0, zf), Vector3(0, 0, 1))
    end
    -- 背面（-Z）
    for i = 1, 6 do
        local j = (i % 6) + 1
        AddTri(buf, back[j], back[i], Vector3(0, cy or 0, zb), Vector3(0, 0, -1))
    end
    -- 侧面 + 前后倒角带
    for i = 1, 6 do
        local j = (i % 6) + 1
        local mid = Vector3((outer[i].x + outer[j].x) * 0.5, (outer[i].y + outer[j].y) * 0.5, 0)
        local outward = Vector3(mid.x, (mid.y - (cy or 0)), 0)
        if outward:Length() > 1e-6 then outward = outward:Normalized() else outward = Vector3(1, 0, 0) end
        -- 侧壁
        AddQuad(buf, outerB[i], outerB[j], outer[j], outer[i], outward)
        -- 前倒角
        local fn = (Vector3(0, 0, 1) + outward):Normalized()
        AddQuad(buf, front[i], front[j], outer[j], outer[i], fn)
        -- 后倒角
        local bn = (Vector3(0, 0, -1) + outward):Normalized()
        AddQuad(buf, back[j], back[i], outerB[i], outerB[j], bn)
    end
end

--- 正面凹槽：比外轮廓小一圈的环形台阶（读作"内嵌面板"）。
---@param buf table
---@param radius number
---@param thickness number
---@param cy number
local function HexFrame(buf, radius, thickness, cy)
    local z = thickness * 0.5
    local inner = HexPoints(radius * 0.80, z + 0.012, cy)
    local outer = HexPoints(radius * 0.93, z + 0.012, cy)
    for i = 1, 6 do
        local j = (i % 6) + 1
        AddQuad(buf, outer[i], outer[j], inner[j], inner[i], Vector3(0, 0, 1))
    end
end

--- 立体数字：5×7 像素点阵，每个亮点挤出一小块立方体。
--- 与游戏像素字（zpix）同气质，且『1』有顶部起笔与底部横，不会退化成一根竖杠。
---@param buf table
---@param digits integer[]
---@param height number 单字高度
---@param z number 正面位置
---@param cy number 中心 y
---@param depth number 凸出厚度
local function Digits(buf, digits, height, z, cy, depth)
    local GLYPH = {
        ["0"] = { "01110", "10001", "10011", "10101", "11001", "10001", "01110" },
        ["1"] = { "00100", "01100", "00100", "00100", "00100", "00100", "01110" },
        ["2"] = { "01110", "10001", "00001", "00010", "00100", "01000", "11111" },
        ["3"] = { "11111", "00010", "00100", "00010", "00001", "10001", "01110" },
        ["4"] = { "00010", "00110", "01010", "10010", "11111", "00010", "00010" },
        ["5"] = { "11111", "10000", "11110", "00001", "00001", "10001", "01110" },
        ["6"] = { "00110", "01000", "10000", "11110", "10001", "10001", "01110" },
        ["7"] = { "11111", "00001", "00010", "00100", "01000", "01000", "01000" },
        ["8"] = { "01110", "10001", "10001", "01110", "10001", "10001", "01110" },
        ["9"] = { "01110", "10001", "10001", "01111", "00001", "00010", "01100" },
    }
    local COLS, ROWS = 5, 7
    local cell = height / ROWS
    local glyphW = COLS * cell
    local gapX = cell * 1.2
    local total = #digits * glyphW + math.max(0, #digits - 1) * gapX
    local x0 = -total * 0.5
    local y0 = (cy or 0) - height * 0.5
    local half = cell * 0.42
    local zf, zb = z + depth, z

    ---@param cx number
    ---@param cyy number
    local function Block(cx, cyy)
        local p1 = Vector3(cx - half, cyy - half, zf)
        local p2 = Vector3(cx + half, cyy - half, zf)
        local p3 = Vector3(cx + half, cyy + half, zf)
        local p4 = Vector3(cx - half, cyy + half, zf)
        AddQuad(buf, p1, p2, p3, p4, Vector3(0, 0, 1))                       -- 前面
        local b1 = Vector3(p1.x, p1.y, zb)
        local b2 = Vector3(p2.x, p2.y, zb)
        local b3 = Vector3(p3.x, p3.y, zb)
        local b4 = Vector3(p4.x, p4.y, zb)
        AddQuad(buf, p4, p3, b3, b4, Vector3(0, 1, 0))                        -- 顶
        AddQuad(buf, p1, p2, b2, b1, Vector3(0, -1, 0))                       -- 底
        AddQuad(buf, p2, p3, b3, b2, Vector3(1, 0, 0))                        -- 右
        AddQuad(buf, p1, p4, b4, b1, Vector3(-1, 0, 0))                       -- 左
    end

    for di, num in ipairs(digits) do
        local rows = GLYPH[tostring(num)] or GLYPH["0"]
        local ox = x0 + (di - 1) * (glyphW + gapX)
        for r = 1, ROWS do
            local line = rows[r] or ""
            for c = 1, COLS do
                if line:sub(c, c) == "1" then
                    -- 实测 RT 出来的字形是水平镜像的，这里在几何层直接把列反序修正
                    -- （NanoVG 的 imagePattern 对变换不敏感，只能从几何改）
                    local bx = ox + (COLS - c + 0.5) * cell
                    local by = y0 + height - (r - 0.5) * cell
                    Block(bx, by)
                end
            end
        end
    end
end

--- 菱形（扁四棱柱，旋转 45°）。
---@param buf table
---@param cx number
---@param cy number
---@param z number
---@param half number
---@param depth number
local function Diamond(buf, cx, cy, z, half, depth)
    local pts = {
        Vector3(cx, cy + half, 0), Vector3(cx + half, cy, 0),
        Vector3(cx, cy - half, 0), Vector3(cx - half, cy, 0),
    }
    local zf, zb = z + depth, z
    for i = 1, 4 do
        local j = (i % 4) + 1
        local p1 = Vector3(pts[i].x, pts[i].y, zf)
        local p2 = Vector3(pts[j].x, pts[j].y, zf)
        local p3 = Vector3(pts[j].x, pts[j].y, zb)
        local p4 = Vector3(pts[i].x, pts[i].y, zb)
        local mid = Vector3((p1.x + p3.x) * 0.5 - cx, (p1.y + p3.y) * 0.5 - cy, 0)
        if mid:Length() > 1e-6 then mid = mid:Normalized() else mid = Vector3(0, 1, 0) end
        AddQuad(buf, p1, p2, p3, p4, mid)
    end
    -- 正反面
    AddQuad(buf, Vector3(cx, cy + half, zf), Vector3(cx + half, cy, zf),
        Vector3(cx, cy - half, zf), Vector3(cx - half, cy, zf), Vector3(0, 0, 1))
end

--- 六边形环带（发光槽）。
---@param buf table
---@param radius number
---@param width number
---@param z number
---@param cy number
local function HexRing(buf, radius, width, z, cy)
    local outer = HexPoints(radius, z, cy)
    local inner = HexPoints(radius - width, z, cy)
    for i = 1, 6 do
        local j = (i % 6) + 1
        AddQuad(buf, outer[i], outer[j], inner[j], inner[i], Vector3(0, 0, 1))
    end
end

local SECTIONS = 7
-- 段序：1 主体 / 2 面板 / 3 数字 / 4 星 / 5 发光槽 / 6 轮廓壳 / 7 备用
local SEC_BODY, SEC_PANEL, SEC_DIGIT, SEC_STAR, SEC_GLOW, SEC_OUTLINE = 1, 2, 3, 4, 5, 6

--- 构建芯片几何。
---@param stage integer 关卡号
---@param stars integer 0..3
---@param hasStars boolean 星级>0（决定配色，几何不变）
---@return table[] buffers
function StageBadgeGeometry.Build(stage, stars, hasStars)
    local bufs = {}
    for i = 1, SECTIONS do bufs[i] = {} end
    local body, panel, digit, star, glow = bufs[SEC_BODY], bufs[SEC_PANEL],
        bufs[SEC_DIGIT], bufs[SEC_STAR], bufs[SEC_GLOW]

    HexPrism(body, R, T, BEVEL, 0)
    HexFrame(panel, R, T, 0)

    -- 立体关号：按位数缩放，避免 3 位数溢出
    local label = tostring(math.max(1, math.floor(stage or 1)))
    local digits = {}
    for i = 1, #label do digits[#digits + 1] = tonumber(label:sub(i, i)) or 0 end
    local digitH = (#digits >= 3) and 0.46 or ((#digits == 2) and 0.58 or 0.66)
    Digits(digit, digits, digitH, T * 0.5 + 0.010, 0.10, 0.055)

    -- 底部三颗菱形星（与 2D 节点同语言：菱形=星）
    local sy = -R * 0.62
    local gap = 0.20
    for i = 1, 3 do
        local on = i <= (stars or 0)
        local target = on and star or panel     -- 未点亮的做成暗色面板材质
        Diamond(target, (i - 2) * gap, sy, T * 0.5 + 0.014, 0.075, on and 0.06 or 0.02)
    end

    -- 外圈发光槽（六边形一周）
    HexRing(glow, R * 0.985, 0.055, T * 0.5 + 0.008, 0)

    -- 轮廓壳：放大 + 翻转绕序（全项目统一描边做法）
    local OUTLINE_SCALE = 1.045
    local outline = bufs[SEC_OUTLINE]
    for sec = 1, SEC_OUTLINE - 1 do
        local src = bufs[sec]
        for i = 1, #src - 2, 3 do
            local a, bb, c = src[i], src[i + 1], src[i + 2]
            if a and bb and c then
                local function S2(v)
                    return Vector3(v.position.x * OUTLINE_SCALE, v.position.y * OUTLINE_SCALE,
                        v.position.z * OUTLINE_SCALE)
                end
                AddTri(outline, S2(c), S2(bb), S2(a))
            end
        end
    end

    return bufs
end

---@param geometry CustomGeometry
---@param buffers table[]
---@param materials Material[]
function StageBadgeGeometry.Apply(geometry, buffers, materials)
    local count = #buffers
    geometry:Clear()
    geometry:SetNumGeometries(count)
    geometry:SetDynamic(false)
    for section = 0, count - 1 do
        geometry:BeginGeometry(section, TRIANGLE_LIST)
        for _, vertex in ipairs(buffers[section + 1]) do
            geometry:DefineVertex(vertex.position)
            geometry:DefineNormal(vertex.normal)
        end
    end
    geometry:Commit()
    for section = 0, count - 1 do
        local material = materials[section + 1]
        if material then geometry:SetMaterial(section, material) end
    end
end

---@return number
function StageBadgeGeometry.GetRadius() return R end
---@return number
function StageBadgeGeometry.GetThickness() return T end

return StageBadgeGeometry
