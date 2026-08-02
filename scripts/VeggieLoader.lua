-- VeggieLoader.lua
-- 在游戏启动时加载像素图，采样为正方形砖块数据
-- 每个砖块颜色来自像素图对应位置

local M = {}

-- 缓存已加载的蔬菜数据（LoadAll 后可通过 GetData 获取）
local cachedData = nil

local GRID = 14            -- 每种蔬菜采样为 14x14 网格
local ALPHA_THRESHOLD = 100
local QUANT = 16
local FILL_RADIUS = 3

-- 蔬菜资源定义
M.DEFS = {
    {
        key = "tomato", name = "番茄",
        file = "image/tomato_20260802092850.png",
        hp = 2, score = 100, speedMul = 1.00,
    },
    {
        key = "chili", name = "辣椒",
        file = "image/chili_20260802092849.png",
        hp = 1, score = 60, speedMul = 1.55,
    },
    {
        key = "onion", name = "洋葱",
        file = "image/onion_20260802092807.png",
        hp = 3, score = 140, speedMul = 0.85,
    },
    {
        key = "carrot", name = "胡萝卜",
        file = "image/carrot_20260802092756.png",
        hp = 2, score = 110, speedMul = 1.15,
    },
    {
        key = "corn", name = "玉米",
        file = "image/corn_20260802092756.png",
        hp = 2, score = 100, speedMul = 0.95,
    },
    {
        key = "eggplant", name = "茄子",
        file = "image/eggplant_20260802092757.png",
        hp = 3, score = 150, speedMul = 0.90,
    },
}

local function quantize(v)
    local q = math.floor(v / QUANT + 0.5) * QUANT
    if q > 255 then q = 255 end
    if q < 0 then q = 0 end
    return q
end

local function nearestOpaque(img, iw, ih, cx, cy, maxR)
    for radius = 1, maxR do
        for dy = -radius, radius do
            local y = cy + dy
            if y >= 0 and y < ih then
                for dx = -radius, radius do
                    if math.abs(dx) == radius or math.abs(dy) == radius then
                        local x = cx + dx
                        if x >= 0 and x < iw then
                            local c = img:GetPixel(x, y)
                            if c.a * 255 >= ALPHA_THRESHOLD then
                                return c.r * 255, c.g * 255, c.b * 255
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

--- 从一张 Image 采样出砖块列表
---@return table bricks, number gridW, number gridH, table mainColor
local function sampleImage(img, grid)
    local iw = img:GetWidth()
    local ih = img:GetHeight()

    -- 找 alpha bbox
    local minX, minY, maxX, maxY = iw, ih, -1, -1
    for y = 0, ih - 1 do
        for x = 0, iw - 1 do
            local c = img:GetPixel(x, y)
            if c.a * 255 >= ALPHA_THRESHOLD then
                if x < minX then minX = x end
                if x > maxX then maxX = x end
                if y < minY then minY = y end
                if y > maxY then maxY = y end
            end
        end
    end

    if maxX < 0 then
        return {}, grid, grid, {128, 128, 128}
    end

    local bw = maxX - minX + 1
    local bh = maxY - minY + 1

    -- CONTAIN：保持宽高比
    local scale = math.min(grid / bw, grid / bh)
    local outW = math.max(1, math.floor(bw * scale + 0.5))
    local outH = math.max(1, math.floor(bh * scale + 0.5))
    if outW > grid then outW = grid end
    if outH > grid then outH = grid end
    local offX = math.floor((grid - outW) / 2)
    local offY = math.floor((grid - outH) / 2)
    local stepX = bw / outW
    local stepY = bh / outH

    local bricks = {}
    local colorCount = {}

    for gy = 0, grid - 1 do
        for gx = 0, grid - 1 do
            local lx = gx - offX
            local ly = gy - offY
            if lx >= 0 and lx < outW and ly >= 0 and ly < outH then
                local sx0 = minX + math.floor(lx * stepX)
                local sx1 = minX + math.floor((lx + 1) * stepX + 0.5) - 1
                local sy0 = minY + math.floor(ly * stepY)
                local sy1 = minY + math.floor((ly + 1) * stepY + 0.5) - 1
                if sx1 < sx0 then sx1 = sx0 end
                if sy1 < sy0 then sy1 = sy0 end

                local ar, ag, ab, cnt = 0, 0, 0, 0
                for sy = sy0, sy1 do
                    for sx = sx0, sx1 do
                        if sx >= 0 and sx < iw and sy >= 0 and sy < ih then
                            local c = img:GetPixel(sx, sy)
                            if c.a * 255 >= ALPHA_THRESHOLD then
                                ar = ar + c.r * 255
                                ag = ag + c.g * 255
                                ab = ab + c.b * 255
                                cnt = cnt + 1
                            end
                        end
                    end
                end

                local r, g, b
                if cnt > 0 then
                    r = quantize(ar / cnt)
                    g = quantize(ag / cnt)
                    b = quantize(ab / cnt)
                else
                    local ccx = math.floor((sx0 + sx1) / 2)
                    local ccy = math.floor((sy0 + sy1) / 2)
                    local searchR = math.max(FILL_RADIUS, math.ceil(math.max(stepX, stepY) * 0.6))
                    local nr, ng, nb = nearestOpaque(img, iw, ih, ccx, ccy, searchR)
                    if nr then
                        r, g, b = quantize(nr), quantize(ng), quantize(nb)
                    else
                        goto continue
                    end
                end

                local dr = quantize(r * 0.55)
                local dg = quantize(g * 0.55)
                local db = quantize(b * 0.55)
                table.insert(bricks, {
                    col = gx + 1, row = gy + 1,
                    r = r, g = g, b = b,
                    dr = dr, dg = dg, db = db,
                })
                local key = string.format("%d,%d,%d", r, g, b)
                colorCount[key] = (colorCount[key] or 0) + 1
            end
            ::continue::
        end
    end

    -- 主色
    local mainKey = "0,0,0"
    local mainCount = 0
    for k, v in pairs(colorCount) do
        if v > mainCount then
            mainCount = v
            mainKey = k
        end
    end
    local mr, mg, mb = mainKey:match("(%d+),(%d+),(%d+)")

    return bricks, grid, grid, { tonumber(mr), tonumber(mg), tonumber(mb) }
end

--- 加载所有蔬菜像素数据（已缓存则直接返回缓存）
---@return table @以 key 为索引的蔬菜数据表
function M.LoadAll()
    if cachedData then return cachedData end
    cachedData = {}
    for _, def in ipairs(M.DEFS) do
        local img = cache:GetResource("Image", def.file)
        if img == nil then
            print("[VeggieLoader] WARNING: failed to load " .. def.file)
        else
            local bricks, gw, gh, mainColor = sampleImage(img, GRID)
            cachedData[def.key] = {
                name = def.name,
                hp = def.hp,
                score = def.score,
                speedMul = def.speedMul,
                gridW = gw,
                gridH = gh,
                mainColor = mainColor,
                bricks = bricks,
            }
            print(string.format("[VeggieLoader] %s: %d bricks, main (%d,%d,%d)",
                def.key, #bricks, mainColor[1], mainColor[2], mainColor[3]))
        end
    end
    return cachedData
end

--- 获取已缓存的蔬菜像素数据
---@return table
function M.GetData()
    return cachedData or M.LoadAll()
end

--- 根据波次获取可出现的蔬菜 key 列表
function M.GetAvailableTypes(veggies, wave)
    local pool = {}
    local maxIndex = math.min(#M.DEFS, 2 + math.floor(wave / 1.5))
    for i = 1, maxIndex do
        if veggies[M.DEFS[i].key] then
            table.insert(pool, M.DEFS[i].key)
        end
    end
    return pool
end

return M
