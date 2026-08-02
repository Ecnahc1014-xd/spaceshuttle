-- Shapes.lua
-- 燃烧的蔬菜 - 蔬菜敌人形状定义
-- 每个形状由字符网格组成: 'X' = 砖块, '.' = 空

local M = {}

-- 砖块尺寸（设计坐标，9:16 竖屏 540x960）
M.BRICK_W = 34
M.BRICK_H = 18

-- 单个砖块的视觉数据由 shape 字符串解析而来
-- color      : 主体色 {r,g,b}
-- darkColor  : 描边/暗色
-- hp         : 该种蔬菜每块砖的默认血量
-- score      : 每块砖基础得分
-- speedMul   : 下落速度倍率
-- shape      : 字符串网格
M.VEGETABLES = {
    tomato = {
        name = "番茄",
        color = {231, 76, 60},
        darkColor = {152, 32, 26},
        hp = 2,
        score = 100,
        speedMul = 1.0,
        shape = {
            "..XXXXX..",
            ".XXXXXXX.",
            "XXXXXXXXX",
            "XXXXXXXXX",
            "XXXXXXXXX",
            ".XXXXXXX.",
            "...XXX...",
        },
    },
    chili = {
        name = "辣椒",
        color = {210, 50, 40},
        darkColor = {140, 25, 20},
        hp = 1,
        score = 60,
        speedMul = 1.55,
        shape = {
            "..XX.",
            "..XXX",
            ".XXXX",
            ".XXXX",
            ".XXX.",
            ".XXX.",
            "..XX.",
            "...X.",
        },
    },
    onion = {
        name = "洋葱",
        color = {155, 89, 182},
        darkColor = {95, 52, 115},
        hp = 3,
        score = 140,
        speedMul = 0.85,
        shape = {
            "...X...",
            "..XXX..",
            ".XXXXX.",
            "XXXXXXX",
            "XXXXXXX",
            ".XXXXX.",
            "..XXX..",
        },
    },
    carrot = {
        name = "胡萝卜",
        color = {230, 126, 34},
        darkColor = {150, 78, 18},
        hp = 2,
        score = 110,
        speedMul = 1.15,
        shape = {
            "...X...",
            "...X...",
            "..XXX..",
            ".XXXXX.",
            "XXXXXXX",
            ".XXXXX.",
            "..XXX..",
            "...X...",
        },
    },
    corn = {
        name = "玉米",
        color = {241, 196, 15},
        darkColor = {160, 128, 10},
        hp = 2,
        score = 100,
        speedMul = 0.95,
        shape = {
            ".XXX.",
            "XXXXX",
            "XXXXX",
            "XXXXX",
            "XXXXX",
            "XXXXX",
            "XXXXX",
            ".XXX.",
        },
    },
    eggplant = {
        name = "茄子",
        color = {142, 68, 173},
        darkColor = {86, 40, 108},
        hp = 3,
        score = 150,
        speedMul = 0.9,
        shape = {
            "..XX...",
            ".XXXX..",
            "XXXXXX.",
            "XXXXXXX",
            ".XXXXX.",
            "..XXX..",
        },
    },
    broccoli = {
        name = "西兰花",
        color = {39, 174, 96},
        darkColor = {22, 100, 55},
        hp = 4,
        score = 200,
        speedMul = 0.7,
        shape = {
            "..X.X...",
            ".XXXXX..",
            "XXXXXXX.",
            "XXXXXXXX",
            ".XXXXXX.",
            "..XXXX..",
            "...XX...",
        },
    },
    garlic = {
        name = "大蒜",
        color = {236, 240, 241},
        darkColor = {150, 155, 160},
        hp = 2,
        score = 90,
        speedMul = 1.0,
        shape = {
            "..X..",
            ".XXX.",
            "XXXXX",
            "XXXXX",
            ".XXX.",
            "..X..",
        },
    },
}

-- 所有蔬菜类型的有序列表，用于随机关卡生成
M.ORDER = {
    "tomato", "chili", "onion", "carrot",
    "corn", "eggplant", "broccoli", "garlic",
}

-- 根据波次获取可出现的蔬菜类型
-- wave 越高解锁越多蔬菜
function M.GetAvailableTypes(wave)
    local pool = {}
    local maxIndex = math.min(#M.ORDER, 3 + math.floor(wave / 2))
    for i = 1, maxIndex do
        table.insert(pool, M.ORDER[i])
    end
    return pool
end

-- 解析形状字符串为砖块列表（相对坐标）
-- 返回 bricks = { {col, row}, ... } 以及网格宽高
function M.ParseShape(shape)
    local bricks = {}
    local rows = #shape
    local cols = 0
    for r = 1, rows do
        local line = shape[r]
        cols = math.max(cols, #line)
        for c = 1, #line do
            local ch = line:sub(c, c)
            if ch == "X" then
                table.insert(bricks, { col = c, row = r })
            end
        end
    end
    return bricks, cols, rows
end

-- 计算一个蔬菜编队的总像素宽高
function M.GetVeggieSize(veggieType)
    local def = M.VEGETABLES[veggieType]
    local _, cols, rows = M.ParseShape(def.shape)
    return cols * M.BRICK_W, rows * M.BRICK_H
end

return M
