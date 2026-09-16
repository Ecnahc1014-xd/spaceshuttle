-- AircraftPixelData.lua
-- 8bit 街机太空飞机剪影（Space Invaders 蟹 / Galaga 蜂蝶 / Galaxian 尖头 / 飞碟）。
-- data: col,row,r,g,b; 空白格不生成砖块，颜色仅用于槽位分类，不表达隐藏 HP。
-- 坐标系：col/row 均从 1 开始，row 越大越靠近玩家（阵列底边）。
-- 底座契约：推进器/引擎在远离玩家一侧（小 row / 设计坐标上方）。

local M = {}

-- 每类飞机的体感性格（仅规则参数，渲染层只读快照消费）。
-- swayAmp/swayFreq 控制横摆；descentMul 在统一下落速度上的额外偏置（>1 更压迫）。
M.behavior = {
    scout       = { swayAmp = 18, swayFreq = 0.40, descentMul = 0.90, agility = 0.6, accent = {120, 124, 150} },
    dart        = { swayAmp = 8,  swayFreq = 1.40, descentMul = 1.32, agility = 1.7, accent = {200, 170, 60} },
    striker     = { swayAmp = 14, swayFreq = 0.90, descentMul = 1.16, agility = 1.0, accent = {150, 78, 54} },
    hive        = { swayAmp = 10, swayFreq = 1.70, descentMul = 1.14, agility = 1.4, accent = {220, 120, 50} },
    manta       = { swayAmp = 32, swayFreq = 0.30, descentMul = 0.80, agility = 0.5, accent = {60, 170, 140} },
    bomber      = { swayAmp = 22, swayFreq = 0.28, descentMul = 0.76, agility = 0.4, accent = {150, 86, 60} },
    cruiser     = { swayAmp = 6,  swayFreq = 0.18, descentMul = 0.66, agility = 0.3, accent = {150, 165, 185} },
    interceptor = { swayAmp = 14, swayFreq = 1.10, descentMul = 1.28, agility = 1.5, accent = {150, 84, 60} },
}

-- 密度档仅供美术/心理预期，规则层不消费（per-brick HP 不变）。
M.densityTier = {
    scout = "sparse", dart = "light", striker = "medium", hive = "sparse",
    manta = "medium", bomber = "dense", cruiser = "heavy", interceptor = "dense",
}

-- ASCII 位图 → 砖块 entry 串。
--   M 主装甲(hullMain) / d 暗装甲·翼面(hullDark) / C 座舱玻璃(canopy) / E 引擎灯(engine)
--   . 或空格为空。row 越大越靠近玩家。
local function bitmapToData(rows)
    local slotColor = {
        M = "150,82,56",    -- 红棕：ClassifySlot 归 hullMain
        d = "120,124,150",  -- 灰蓝：归 hullDark
        C = "70,120,160",   -- 高亮蓝：归 canopy
        E = "110,46,40",    -- 低亮度：归 engine
    }
    local width = #rows[1]
    local parts = {}
    for row, line in ipairs(rows) do
        if #line ~= width then
            print("[AircraftPixelData] bitmap width mismatch row=" .. tostring(row)
                .. " got=" .. tostring(#line) .. " expected=" .. tostring(width))
        end
        for col = 1, #line do
            local rgb = slotColor[line:sub(col, col)]
            if rgb then
                parts[#parts + 1] = string.format("%d,%d,%s", col, row, rgb)
            end
        end
    end
    return table.concat(parts, ";") .. ";"
end

-- scout：Space Invaders 蟹形（11×8），触角在背侧，钳足朝向玩家。
M.scout = {
    hp = 1,
    score = 100,
    speedMul = 1.00,
    gridW = 11,
    gridH = 8,
    data = bitmapToData({
        "..M.....M..",
        ".d.M...M.d.",
        "d.MMMMMMM.d",
        ".MMCCCCCMM.",
        "dMM.MMM.MMd",
        ".M.M...M.M.",
        "M..M...M..M",
        ".M.......M.",
    }),
}

-- dart：Galaxian 尖头黄蜂（9×10），细中脊 + 后掠，引擎在背侧、尖鼻朝玩家。
M.dart = {
    hp = 1,
    score = 130,
    speedMul = 1.24,
    gridW = 9,
    gridH = 10,
    data = bitmapToData({
        "....E....",
        "...EEE...",
        "...dCd...",
        "..dCCCd..",
        ".ddCCCdd.",
        ".dMCCCMd.",
        "MM.....MM",
        "M...M...M",
        "...MMM...",
        "....M....",
    }),
}

-- striker：Galaga 蝴蝶（13×9），宽翼对称，座舱居中。
M.striker = {
    hp = 1,
    score = 120,
    speedMul = 1.08,
    gridW = 13,
    gridH = 9,
    data = bitmapToData({
        "E.....E.....E",
        ".d...ddd...d.",
        "..d.dCCCd.d..",
        ".dMMMCCCMMMd.",
        "dddMMMMMMMddd",
        ".ddMMMMMMMdd.",
        "..MM.....MM..",
        ".M.M.....M.M.",
        "M...........M",
    }),
}

-- hive：Galaga 蜜蜂（7×7），体型最小，适合蜂群阵。
M.hive = {
    hp = 1,
    score = 80,
    speedMul = 1.16,
    gridW = 7,
    gridH = 7,
    data = bitmapToData({
        "..E.E..",
        ".dCCCd.",
        "dMCCCMd",
        "MMM.MMM",
        ".M...M.",
        "M.M.M.M",
        ".M...M.",
    }),
}

-- manta：Galaxian 旗舰宽翼（15×8），平直长翼。
M.manta = {
    hp = 1,
    score = 150,
    speedMul = 0.86,
    gridW = 15,
    gridH = 8,
    data = bitmapToData({
        "......EEE......",
        "....ddCCCdd....",
        "..dddCCCCCddd..",
        ".ddMMCCCCCMMdd.",
        "MMMMMMMMMMMMMMM",
        ".MMM.......MMM.",
        "..M.........M..",
        ".M...........M.",
    }),
}

-- bomber：经典飞碟（13×8），圆盘 + 中央穹顶，引擎在背侧。
M.bomber = {
    hp = 1,
    score = 140,
    speedMul = 0.90,
    gridW = 13,
    gridH = 8,
    data = bitmapToData({
        "....EEEEE....",
        "...d.....d...",
        "..dMMMMMMMd..",
        ".MMCCCCCCCMM.",
        "MMMMMMMMMMMMM",
        ".MMMMMMMMMMM.",
        "..dMMM.MMMd..",
        "....MM.MM....",
    }),
}

-- cruiser：Galaga Boss 双荚重甲（15×10），方正厚重。
M.cruiser = {
    hp = 1,
    score = 180,
    speedMul = 0.80,
    gridW = 15,
    gridH = 10,
    data = bitmapToData({
        "E.....EEE.....E",
        ".dd...ddd...dd.",
        "ddMMMMMMMMMMMdd",
        "MMMMCCCCCCCCMMM",
        "MMMMMMMMMMMMMMM",
        "dMMMMMMMMMMMMMd",
        "MMMMM.....MMMMM",
        "dMMM..MMM..MMMd",
        ".MMM.......MMM.",
        "..MM.......MM..",
    }),
}

-- interceptor：精英截击机（11×11），菱形尖头，Boss 复用此剪影。
M.interceptor = {
    hp = 1,
    score = 160,
    speedMul = 1.20,
    gridW = 11,
    gridH = 11,
    data = bitmapToData({
        "....EEE....",
        "....dCCd...",
        "...dCCCCd..",
        "..dMCCCCMd.",
        ".dMMCCCCMMd",
        "dMMMMMMMMMd",
        "MMM.....MMM",
        "MM.M...M.MM",
        "M...M.M...M",
        ".....M.....",
        "....MMM....",
    }),
}

return M
