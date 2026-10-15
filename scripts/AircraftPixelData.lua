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
    -- 精英的平均纵向速度以同波普通机的统一基准速度为 1.0；横向采用不同连续避让波形。
    elite_hook    = { swayAmp = 16, swayFreq = 0.7, descentMul = 0.96, agility = 1.5, dodge = {kind = "zigzag", amp = 17, freq = 2.0} },
    elite_fork    = { swayAmp = 14, swayFreq = 0.9, descentMul = 0.92, agility = 1.3, dodge = {kind = "orbit", amp = 22, freq = 1.08} },
    elite_razor   = { swayAmp = 12, swayFreq = 1.4, descentMul = 0.99, agility = 1.8, dodge = {kind = "zigzag", amp = 19, freq = 1.8} },
    elite_spiral  = { swayAmp = 18, swayFreq = 1.1, descentMul = 0.90, agility = 1.6, dodge = {kind = "orbit", amp = 20, freq = 2.3} },
    elite_anchor  = { swayAmp = 9, swayFreq = 0.45, descentMul = 0.80, agility = 0.8, dodge = {kind = "lurch", amp = 13, freq = 3.0} },
    elite_wisp    = { swayAmp = 24, swayFreq = 0.62, descentMul = 0.98, agility = 1.8, dodge = {kind = "lurch", amp = 18, freq = 3.2} },
    elite_shear   = { swayAmp = 22, swayFreq = 1.25, descentMul = 0.94, agility = 1.7, dodge = {kind = "orbit", amp = 22, freq = 1.6} },
    elite_bracket = { swayAmp = 17, swayFreq = 0.85, descentMul = 0.93, agility = 1.1, dodge = {kind = "zigzag", amp = 15, freq = 2.5} },
    elite_hammer  = { swayAmp = 7, swayFreq = 0.42, descentMul = 0.86, agility = 0.9, dodge = {kind = "lurch", amp = 20, freq = 2.1} },
    elite_rivet   = { swayAmp = 15, swayFreq = 1.02, descentMul = 1.0, agility = 1.4, dodge = {kind = "orbit", amp = 17, freq = 2.8} },
    boss_orrery   = { swayAmp = 10, swayFreq = 0.22, descentMul = 0.55, agility = 0.3 },
    boss_maw      = { swayAmp = 12, swayFreq = 0.26, descentMul = 0.55, agility = 0.4 },
    boss_citadel  = { swayAmp = 6, swayFreq = 0.18, descentMul = 0.5, agility = 0.2 },
    boss_prism    = { swayAmp = 15, swayFreq = 0.24, descentMul = 0.58, agility = 0.5 },
    boss_serpent  = { swayAmp = 17, swayFreq = 0.3, descentMul = 0.56, agility = 0.6 },
}

-- 密度档仅供美术/心理预期，规则层不消费（per-brick HP 不变）。
M.densityTier = {
    scout = "sparse", dart = "light", striker = "medium", hive = "sparse",
    manta = "medium", bomber = "dense", cruiser = "heavy", interceptor = "dense",
    elite_hook = "medium", elite_fork = "medium", elite_razor = "light", elite_spiral = "medium",
    elite_anchor = "heavy", elite_wisp = "light", elite_shear = "light", elite_bracket = "medium",
    elite_hammer = "heavy", elite_rivet = "heavy",
    boss_orrery = "heavy", boss_maw = "heavy", boss_citadel = "heavy",
    boss_prism = "medium", boss_serpent = "heavy",
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
        -- v0.13.65：背侧两枚引擎灯（E）——scout 原本无 E 块，幻影体素块需要「光源块」才能发射。
        "..E.....E..",
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
        "...dCCCd...",
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

-- 十种精英与五种首领各有独立 occupied-cell 剪影，跟旧机型共享逐格伤害与体素路径。
M.elite_hook = {hp = 1, score = 190, speedMul = 1, gridW = 11, gridH = 9,
    data = bitmapToData({
        "..EE.......", "..dd.......", ".dMMd......", "dMMMCC.....",
        ".dMMCCMM...", "..dMMMMMMd.", "...dMM...Md", "....dM..MM.", ".....MMMM..",
    }) }
M.elite_fork = {hp = 1, score = 195, speedMul = 1, gridW = 13, gridH = 10,
    data = bitmapToData({
        "E...........E", "MM.........MM", "MM.........MM", "dM.........Md",
        "dMM.......MMd", ".MMd.....dMM.", "..MMC...CMM..", "...MMM.MMM...",
        "....MCCCM....", ".....MMM.....",
    }) }
M.elite_razor = {hp = 1, score = 200, speedMul = 1, gridW = 9, gridH = 11,
    data = bitmapToData({
        "...E.....", "..dM.....", ".dMM.....", "dMMC.....", ".dMCC....",
        "..MMMM...", "...dMMd..", "..dMMMMd.", ".dMM..MM.", "dMM....M.", "MM......M",
    }) }
M.elite_spiral = {hp = 1, score = 210, speedMul = 1, gridW = 11, gridH = 11,
    data = bitmapToData({
        "...EEE.....", "..dMMMd....", ".dMCCCMd...", ".MM...MMd..",
        "dMM.....Md.", "MM..dM..MM.", "MM..dC...Md", "dMM.dMM..Md",
        ".dMMMMMMMd.", "..ddMMMM...", "....MMM....",
    }) }
M.elite_anchor = {hp = 1, score = 215, speedMul = 1, gridW = 13, gridH = 10,
    data = bitmapToData({
        ".....EEE.....", ".....dMd.....", ".....MCM.....", "dddMMMMMMMddd",
        "MMd..MMM..dMM", ".Md..MMM..dM.", "..d..MMM..d..", "..M..MMM..M..",
        "...MMdMdMM...", "....M...MM...",
    }) }
M.elite_wisp = {hp = 1, score = 195, speedMul = 1, gridW = 11, gridH = 10,
    data = bitmapToData({
        "EE.........", "MMd........", ".MMC.......", "..MMCd.....", "...MMMd....",
        "....MMCd...", ".....MMMd..", "......MMMd.", ".......MMMd", "........MMM",
    }) }
M.elite_shear = {hp = 1, score = 200, speedMul = 1, gridW = 13, gridH = 9,
    data = bitmapToData({
        "E...........E", "dM.........Md", ".dM.......Md.", "..dM.....Md..",
        "...dMCCCMd...", "..MMdCCCdMM..", ".MM...M...MM.", "MM...MMM...MM",
        "M.....M.....M",
    }) }
M.elite_bracket = {hp = 1, score = 205, speedMul = 1, gridW = 11, gridH = 10,
    data = bitmapToData({
        "...EEE.....", "..dMMMd....", ".dMCCCMd...", "dMM...MMd..", "MM......Md.",
        "MM.........", "MM......Md.", "dMM...MMd..", ".dMMMMMd...", "..dMMMM....",
    }) }
M.elite_hammer = {hp = 1, score = 220, speedMul = 1, gridW = 9, gridH = 10,
    data = bitmapToData({
        "EE.....EE", "MM.....MM", "dMMMMMMMd", "MMCCCCCMM", "..MMMd...",
        "...MMd...", "...MMd...", "...MMd...", "...MMd...", "....Md...",
    }) }
M.elite_rivet = {hp = 1, score = 230, speedMul = 1, gridW = 13, gridH = 11,
    data = bitmapToData({
        "...EE........", "..dMMMd......", ".dMCCCMd.....", "dMMMMMMMd....",
        "MMM...MMM....", "MMM...MMMdd..", "dMMMMMMMdMMd.", ".dMMMMMMM.MM.",
        "..MMdMM....M.", "...MM.....MM.", "....MMMMMMM..",
    }) }

M.boss_orrery = {hp = 1, score = 270, speedMul = 1, gridW = 19, gridH = 13,
    summonKey = "hive", data = bitmapToData({
        ".......EEEEE.......", ".....ddMMMMMdd.....", "...dMMM.....MMMd...",
        "..dMM.........MMd..", ".dMM...CCCCC...MMd.", "dMM....C...C....MMd",
        "MMM....C.C.C....MMM", "dMM....C...C....MMd", ".dMM...CCCCC...MMd.",
        "..dMM.........MMd..", "...dMMM.....MMMd...", ".....ddMMMMMdd.....",
        ".......MMMMM.......",
    }) }
M.boss_maw = {hp = 1, score = 290, speedMul = 1, gridW = 19, gridH = 13,
    summonKey = "dart", data = bitmapToData({
        "E.................E", "MMd.............dMM", "MMMd...........dMMM",
        "dMMMd..EEEEE..dMMMd", ".dMMMd.MMMMM.dMMMd.", "..dMMMdMCCCMdMMMd..",
        "...dMMMMCCCMMMMd...", "....dMMMMMMMMMd....", "...dMMMM...MMMMd...",
        "..dMMMM.....MMMMd..", ".dMMMM.......MMMMd.", "MMMMM.........MMMMM",
        "MMMM...........MMMM",
    }) }
M.boss_citadel = {hp = 1, score = 320, speedMul = 1, gridW = 19, gridH = 13,
    summonKey = "scout", data = bitmapToData({
        "EE..EE..EEE..EE..EE", "MM..MM..MMM..MM..MM", "MMMMMMMMMMMMMMMMMMM",
        "dMMdMMdMMMMMdMMdMMd", "MM..MM.CCCCC.MM..MM", "MM..MM.CCCCC.MM..MM",
        "MMMMMMMMMMMMMMMMMMM", "dMMMdMMMMMMMMMdMMMd", "MMMMdMMMMMMMMMdMMMM",
        "MM...MMMMMMMMM...MM", "MM...MM.....MM...MM", "MM...MM.....MM...MM",
        "MMMMMMM.....MMMMMMM",
    }) }
M.boss_prism = {hp = 1, score = 310, speedMul = 1, gridW = 17, gridH = 11,
    summonKey = "bomber", data = bitmapToData({
        "E...............E", "MMd...........dMM", ".MMd.........dMM.",
        "..MMd...E...dMM..", "...MMd.CCC.dMM...", "....MMdCCCdMM....",
        "...MMd.CCC.dMM...", "..MMd...M...dMM..", ".MMd.........dMM.",
        "MMd...........dMM", "M...............M",
    }) }
M.boss_serpent = {hp = 1, score = 300, speedMul = 1, gridW = 17, gridH = 13,
    summonKey = "striker", data = bitmapToData({
        "EEE..............", "MMMdd............", "..MMMMd..........", "....MMMMd........",
        ".....MMCCMd......", "....dMMMMMMMd....", "...dMMM..dMMMd...",
        "..dMMd....dMMd...", ".dMMd......dMMd..", "dMMd........dMMd.",
        "MMd..........dMMd", ".dMMd......dMMd..", "...dMMMMMMMMMd...",
    }) }

return M
