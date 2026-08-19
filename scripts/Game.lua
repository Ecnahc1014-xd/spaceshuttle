-- Game.lua
-- 太空飞机弹珠核心玩法。只维护规则、碰撞和权威状态，不依赖任何渲染 API。

local AircraftData = require "AircraftPixelData"

local Game = {}

local DW = 540
local DH = 960
local BASE_BRICK_SIZE = 16
local SLING_X = 270
local SLING_Y = 850
local MAX_PULL = 150
local DANGER_Y = 900
local BASE_HP = 100

-- 幸存者化参数
local BRICK_BASE_DAMAGE = 3        -- 每个方块越过目标线时对基地造成的伤害
local XP_PER_BRICK = 1             -- 击碎一个方块获得的经验
local XP_PER_CLEAR = 8             -- 清掉整支飞船的额外经验
local BASE_XP_TO_NEXT = 12         -- 第一级所需经验
local WAVE_INTERVAL = 7.0          -- 持续刷新波次的间隔（秒）
local WAVE_INTERVAL_MIN = 2.8      -- 后期最快刷新间隔
local MAX_CONCURRENT = 14          -- 同屏飞船数量上限，避免无限叠加

-- 数值平衡表（WO-01/P1）：局内不可变数值集中管理，便于调参与离线模拟。
-- 旧常量名仍作为本表的初始化来源，保持向后可读别名。
local BALANCE = {
    baseHp = BASE_HP,
    brickBaseDamage = BRICK_BASE_DAMAGE,
    xpPerBrick = XP_PER_BRICK,
    xpPerClear = XP_PER_CLEAR,
    baseXpToNext = BASE_XP_TO_NEXT,
    xpToNextGrowth = 1.18,          -- WO-02/P1：每级经验阈值指数乘子（替代原线性的 *0.35）
    waveInterval = WAVE_INTERVAL,
    waveIntervalMin = WAVE_INTERVAL_MIN,
    waveTightenStep = 0.35,         -- WO-03/P1：波次间隔随波次收紧步长（原写死 0.35）
    maxConcurrent = MAX_CONCURRENT,
    clearStreakBonusCap = 5,        -- WO-03/P1：连击经验加成封顶（原写死 5）
    -- 以下为批次2（P6 WO-12）预留字段，当前 UpdateWaveLogic 尚未使用
    phaseLength = 5,
    phaseTightenBonus = 0.6,
    breatherEvery = 10,
    breatherRelax = 1.5,
    safeGap = 1.2,
    -- 蓄力发射（WO-08/P7）：拖拽距离映射到初速比例，由规则层暴露供输入层消费。
    maxPull = MAX_PULL,
    powerMin = 0.35,   -- 最小蓄力初速比例（轻拖也有基础射程）
    powerMax = 1.0,    -- 满蓄力初速比例
}

local BALL_TYPES = {
    normal = {
        radius = 20, speed = 560, damage = 1,
        splitChance = 0.05, splitAngle = 18, splitSpread = 18,
        bounceElasticity = 1.0,    -- WO-05/P4：反弹弹性，1.0 为标准
    },
    speed = {
        radius = 18, speed = 660, damage = 1,
        speedBoost = 1.06, maxSpeed = 900,
        damageStep = 320, maxDamage = 2,
        redirectThrottle = 0.45,    -- 自动追击的节流（秒），削弱其持续黏着
        redirectMinSpeed = 120,     -- WO-05/P4：低于此速度不触发追击，消除低速抖动
        bounceElasticity = 1.0,    -- 加速弹更"滑"
    },
    ice = {
        radius = 20, speed = 520, damage = 1,
        freezeDuration = 3.0,
        bounceElasticity = 1.0,
    },
    giant = {
        radius = 30, speed = 420, damage = 2,
        pierceAfterBounce = true,
        areaRadiusCells = 3.5,
        bounceElasticity = 0.92,   -- WO-05/P4：巨型弹更"沉"
    },
}
local BALL_ORDER = { "normal", "ice", "speed", "giant" }

-- 局内可调规则（受升级影响），初始值。必须在使用它的升级闭包之前声明。
local BALL_TUNING = {
    damageBonus = 0,
    giantArea = 0,
    splitBonus = 0,
    speedMul = 1.0,
    iceBonus = 0,
    brickDmg = BRICK_BASE_DAMAGE,
    xpMul = 1.0,
}

local gameState = "menu"
local score = 0
local highScore = 0
local baseHp = BASE_HP
local wave = 1
local elapsed = 0
local waveCooldown = 0

-- 幸存者成长状态
local playerLevel = 1
local xp = 0
local xpToNext = BASE_XP_TO_NEXT
local pendingLevelUps = 0          -- 待处理的升级次数（暂停选强化）
local upgradeChoices = nil         -- 当前可选的三选一强化
local upgradePicks = {}            -- 已选强化的累计效果（id 列表，可重复）
local upgradeStacks = {}           -- 已选强化各 id 的层数（WO-09/P5 叠加上限判定）
local clearStreak = 0              -- 连续清空飞船的连击（经验加成）
local bricksBroken = 0            -- 累计击碎砖块数（WO-11/P8 gameover 回顾）

-- 幸存者升级强化池（WO-09/P5）：
-- weight 抽卡权重；rarity 稀有度（common/rare/epic）；maxStacks 叠加上限；
-- tradeoff 是否抉择型（apply 同时改正负）；value 单次增量（用于升级卡 delta 预览）。
-- apply(stacks) 接收当前已选层数，支持边际递减（如 damage 每层略减）。
-- apply() 只改 BALL_TUNING / baseHp（规则层），UI 只读 GetSnapshot().upgradeChoices。
local UPGRADE_POOL = {
    { id = "damage", name = "穿甲弹头", desc = "所有弹珠伤害 +1",
      weight = 1, rarity = "common", maxStacks = 8, tradeoff = false, value = "+1",
      apply = function(stacks) BALL_TUNING.damageBonus = BALL_TUNING.damageBonus + 1 end },
    { id = "giant", name = "重型化", desc = "巨型弹珠贯穿范围 +1 格",
      weight = 1, rarity = "common", maxStacks = 3, tradeoff = false, value = "+1 格",
      apply = function(stacks) BALL_TUNING.giantArea = BALL_TUNING.giantArea + 1.0 end },
    { id = "split", name = "裂变核", desc = "基础弹分裂概率 +3%",
      weight = 1, rarity = "common", maxStacks = 5, tradeoff = false, value = "+3%",
      apply = function(stacks) BALL_TUNING.splitBonus = BALL_TUNING.splitBonus + 0.03 end },
    { id = "speed", name = "疾速引擎", desc = "弹珠飞行速度 +8%",
      weight = 1, rarity = "common", maxStacks = 6, tradeoff = false, value = "+8%",
      apply = function(stacks) BALL_TUNING.speedMul = BALL_TUNING.speedMul * 1.08 end },
    { id = "ice", name = "深寒涂层", desc = "冰冻时长 +1.2 秒",
      weight = 1, rarity = "common", maxStacks = 5, tradeoff = false, value = "+1.2s",
      apply = function(stacks) BALL_TUNING.iceBonus = BALL_TUNING.iceBonus + 1.2 end },
    { id = "repair", name = "前线维修", desc = "立即恢复 25 点基地生命",
      weight = 1, rarity = "common", maxStacks = 99, tradeoff = false, value = "+25 HP",
      apply = function(stacks) baseHp = math.min(BASE_HP, baseHp + 25) end },
    { id = "armor", name = "装甲强化", desc = "越线方块伤害 -1（最低 1）",
      weight = 1, rarity = "common", maxStacks = 2, tradeoff = false, value = "-1 伤害",
      apply = function(stacks) BALL_TUNING.brickDmg = math.max(1, BALL_TUNING.brickDmg - 1) end },
    { id = "xp", name = "数据回收", desc = "经验获取 +20%",
      weight = 1, rarity = "common", maxStacks = 5, tradeoff = false, value = "+20%",
      apply = function(stacks) BALL_TUNING.xpMul = BALL_TUNING.xpMul + 0.2 end },
    -- WO-09/P5 抉择型：同时改正负规则变量，高风险高回报（仍只改 BALL_TUNING/baseHp）。
    { id = "glass_cannon", name = "玻璃 cannon", desc = "伤害 +2 但越线伤害 +1",
      weight = 0.6, rarity = "rare", maxStacks = 3, tradeoff = true, value = "伤害+2 / 扣血+1",
      apply = function(stacks)
          BALL_TUNING.damageBonus = BALL_TUNING.damageBonus + 2
          BALL_TUNING.brickDmg = BALL_TUNING.brickDmg + 1
      end },
    { id = "overclock", name = "超载核心", desc = "速度 +15% 但基地 -8",
      weight = 0.6, rarity = "rare", maxStacks = 3, tradeoff = true, value = "速度+15% / HP-8",
      apply = function(stacks)
          BALL_TUNING.speedMul = BALL_TUNING.speedMul * 1.15
          baseHp = math.max(1, baseHp - 8)
      end },
}

local veggies = {}
local marbles = {}
local ballQueue = {}
local activeBall = nil
local ballCycleIndex = 0
local aiming = false
local aimX = SLING_X
local aimY = SLING_Y

local pendingEvents = {}
local nextEnemyId = 1
local nextMarbleId = 1
local randomState = 1

local ResetGame
local SpawnWave
local UpdateMarbles
local UpdateEnemies
local UpdateReload
local UpdateWaveLogic
local GainXp
local RollUpgradeChoices

local function Emit(eventType, data)
    data = data or {}
    data.type = eventType
    table.insert(pendingEvents, data)
end

local function SetRandomSeed(seed)
    randomState = math.floor(tonumber(seed) or 1) % 2147483647
    if randomState <= 0 then randomState = 1 end
end

local function Random()
    randomState = (randomState * 16807) % 2147483647
    return (randomState - 1) / 2147483646
end

local function RandomInt(minValue, maxValue)
    return minValue + math.floor(Random() * (maxValue - minValue + 1))
end

local function GetBrickSize(waveNum)
    if waveNum <= 2 then return 14 end
    if waveNum <= 4 then return 15 end
    return BASE_BRICK_SIZE
end

local function GetWaveParams(waveNum)
    local count
    if waveNum <= 1 then count = 1
    elseif waveNum <= 3 then count = 2
    elseif waveNum <= 5 then count = 3
    else count = math.min(6, 3 + math.floor((waveNum - 4) / 2)) end

    -- 敌方砖块保留隐藏 HP：前六波只需一次命中，之后再逐步增加耐久。
    local speed = 18 + (waveNum - 1) * 4
    local hp = 1
    if waveNum >= 7 then hp = 2 end
    if waveNum >= 12 then hp = 3 end
    return count, speed, hp
end

local function CreateMarble(ballType)
    local def = BALL_TYPES[ballType]
    local marble = {
        id = nextMarbleId,
        x = SLING_X, y = SLING_Y,
        vx = 0, vy = 0,
        radius = def.radius,
        speed = def.speed,
        ballType = ballType,
        onSling = true,
        alive = true,
        bounceCount = 0,
        isPrimary = true,
        generation = 0,
        ignoredBrick = nil,
        giantPiercing = false,
    }
    nextMarbleId = nextMarbleId + 1
    return marble
end

local function NextBallType()
    ballCycleIndex = ballCycleIndex + 1
    if ballCycleIndex > #BALL_ORDER then ballCycleIndex = 1 end
    return BALL_ORDER[ballCycleIndex]
end

local function EnqueueNextBall()
    table.insert(ballQueue, NextBallType())
end

local function LoadBalls()
    ballQueue = {}
    ballCycleIndex = 0
    for _ = 1, #BALL_ORDER do EnqueueNextBall() end
    activeBall = CreateMarble(table.remove(ballQueue, 1))
    EnqueueNextBall()
end

ResetGame = function()
    score = 0
    baseHp = BASE_HP
    wave = 1
    elapsed = 0
    veggies = {}
    marbles = {}
    aiming = false
    aimX = SLING_X
    aimY = SLING_Y
    waveCooldown = 0.5
    nextEnemyId = 1
    nextMarbleId = 1
    -- 幸存者成长状态复位
    playerLevel = 1
    xp = 0
    xpToNext = BALANCE.baseXpToNext
    pendingLevelUps = 0
    upgradeChoices = nil
    upgradePicks = {}
    upgradeStacks = {}
    clearStreak = 0
    bricksBroken = 0
    BALL_TUNING.damageBonus = 0
    BALL_TUNING.giantArea = 0
    BALL_TUNING.splitBonus = 0
    BALL_TUNING.speedMul = 1.0
    BALL_TUNING.iceBonus = 0
    BALL_TUNING.brickDmg = BRICK_BASE_DAMAGE
    BALL_TUNING.xpMul = 1.0
    LoadBalls()
    Emit("game_reset")
end

local function StartGame()
    ResetGame()
    gameState = "playing"
    SpawnWave()
    print("[Game] game started")
end

local function GetAircraftSize(aircraftKey, brickSize)
    local data = AircraftData[aircraftKey]
    return data.gridW * brickSize, data.gridH * brickSize
end

local function GetAvailableTypes(waveNum)
    local keys = {}
    local allKeys = { "scout", "striker", "bomber", "interceptor" }
    local maxIndex = 1
    if waveNum >= 3 then maxIndex = 2 end
    if waveNum >= 6 then maxIndex = 3 end
    if waveNum >= 9 then maxIndex = 4 end

    for i = 1, math.min(#allKeys, maxIndex) do
        if AircraftData[allKeys[i]] then table.insert(keys, allKeys[i]) end
    end
    return keys
end

local function CreateEnemy(aircraftKey, x, y, brickSize, brickHp, baseSpeed)
    local data = AircraftData[aircraftKey]
    if not data then
        print("[Game] ERROR: no aircraft data for " .. tostring(aircraftKey))
        return nil
    end

    local bricks = {}
    for entry in (data.data .. ";"):gmatch("(.-);") do
        local col, row = entry:match("(%d+),(%d+),%d+,%d+,%d+")
        if col then
            table.insert(bricks, {
                col = tonumber(col), row = tonumber(row),
                hp = brickHp, maxHp = brickHp, alive = true,
            })
        end
    end

    local enemy = {
        id = nextEnemyId,
        aircraftKey = aircraftKey,
        gridW = data.gridW,
        gridH = data.gridH,
        brickSize = brickSize,
        x = x, y = y, baseX = x,
        vy = baseSpeed * data.speedMul * 0.25,
        swayAmp = 10 + Random() * 14,
        swayFreq = 0.3 + Random() * 0.25,
        phase = Random() * math.pi * 2,
        bricks = bricks,
        dead = false,
        frozen = 0,
    }
    nextEnemyId = nextEnemyId + 1
    return enemy
end

SpawnWave = function()
    local pool = GetAvailableTypes(wave)
    if #pool == 0 then
        print("[Game] WARNING: empty aircraft pool")
        return
    end

    local count, baseSpeed, brickHp = GetWaveParams(wave)
    local brickSize = GetBrickSize(wave)
    local margin = 20
    local usedX = {}

    for i = 1, count do
        local aircraftKey = pool[RandomInt(1, #pool)]
        local aircraftWidth, aircraftHeight = GetAircraftSize(aircraftKey, brickSize)
        local x, tries = margin, 0
        repeat
            x = margin + Random() * math.max(1, DW - aircraftWidth - margin * 2)
            local overlap = false
            for _, usedCenterX in ipairs(usedX) do
                if math.abs(usedCenterX - (x + aircraftWidth * 0.5)) < aircraftWidth * 0.9 then
                    overlap = true
                    break
                end
            end
            tries = tries + 1
            if not overlap or tries > 25 then break end
        until false
        table.insert(usedX, x + aircraftWidth * 0.5)

        local y = -aircraftHeight * 0.3 - (i - 1) * (aircraftHeight * 0.2) - RandomInt(0, 10)
        local enemy = CreateEnemy(aircraftKey, x, y, brickSize, brickHp, baseSpeed)
        if enemy then table.insert(veggies, enemy) end
    end

    Emit("wave_started", {wave = wave})
    print("[Game] wave " .. wave .. " spawned " .. #veggies .. " aircraft")
end

-- 碰撞区域设计：圆形弹珠对单个方形砖块。
--
--        圆心 (cx, cy)
--             o
--          .-' '-.
--       +----------+  <- 砖块 AABB (rx, ry, rw, rh)
--       |          |
--       +----------+
--
-- 目的：圆与 AABB 重叠时，按归一化穿透较大的轴反射速度并推出表面。
-- 边界：相切不算命中；推出 0.5 设计单位避免重复卡碰；高速球由四次子步进降低穿透。
local function IntersectsBrick(marble, rx, ry, rw, rh)
    local closestX = math.max(rx, math.min(marble.x, rx + rw))
    local closestY = math.max(ry, math.min(marble.y, ry + rh))
    local dx = marble.x - closestX
    local dy = marble.y - closestY
    return dx * dx + dy * dy < marble.radius * marble.radius
end

local function CollideBrick(marble, rx, ry, rw, rh)
    if not IntersectsBrick(marble, rx, ry, rw, rh) then return false end

    local centerX = rx + rw * 0.5
    local centerY = ry + rh * 0.5
    local overlapX = math.abs(marble.x - centerX) / (rw * 0.5 + marble.radius)
    local overlapY = math.abs(marble.y - centerY) / (rh * 0.5 + marble.radius)

    if overlapX >= overlapY then
        marble.vx = -marble.vx
        if marble.x >= centerX then marble.x = rx + rw + marble.radius + 0.5
        else marble.x = rx - marble.radius - 0.5 end
    else
        marble.vy = -marble.vy
        if marble.y >= centerY then marble.y = ry + rh + marble.radius + 0.5
        else marble.y = ry - marble.radius - 0.5 end
    end
    return true
end

local function DamageBrick(enemy, brick, damage)
    brick.hp = brick.hp - (damage or 1)
    local data = AircraftData[enemy.aircraftKey]
    local x = enemy.x + (brick.col - 0.5) * enemy.brickSize
    local y = enemy.y + (brick.row - 0.5) * enemy.brickSize
    local destroyed = brick.hp <= 0

    if destroyed then
        brick.alive = false
        score = score + data.score
        bricksBroken = bricksBroken + 1
        GainXp(XP_PER_BRICK)
    end

    Emit("brick_hit", {
        enemyId = enemy.id,
        aircraftKey = enemy.aircraftKey,
        col = brick.col,
        row = brick.row,
        x = x, y = y,
        destroyed = destroyed,
        score = destroyed and data.score or 0,
    })
end

local function IsEnemyCleared(enemy)
    for _, brick in ipairs(enemy.bricks) do
        if brick.alive then return false end
    end
    return true
end

-- 幸存者升级：获得经验，跨级时累计待处理的升级选择。
local function GainXp(amount)
    if pendingLevelUps > 0 then return end   -- 升级选择期间冻结经验累计
    xp = xp + amount * BALL_TUNING.xpMul
    while xp >= xpToNext do
        xp = xp - xpToNext
        playerLevel = playerLevel + 1
        xpToNext = math.floor(BALANCE.baseXpToNext * BALANCE.xpToNextGrowth ^ (playerLevel - 1))
        pendingLevelUps = pendingLevelUps + 1
    end
    if pendingLevelUps > 0 then
        gameState = "levelup"
        RollUpgradeChoices()
        Emit("level_up", {level = playerLevel})
        print("[Game] level up -> " .. playerLevel .. ", waiting for upgrade pick")
    end
end

local function RollUpgradeChoices()
    -- WO-09/P5：加权抽卡 + 叠加上限 + 稀有保底。
    upgradeChoices = {}
    local sinceRare = 0  -- 连续未出 rare+ 的次数，用于保底
    for _ = 1, 3 do
        -- 构造可用候选（未达 maxStacks）
        local avail = {}
        local totalW = 0
        for _, u in ipairs(UPGRADE_POOL) do
            local stacks = upgradeStacks[u.id] or 0
            if stacks < u.maxStacks then
                -- 后期无意义项（repair/xp 已高叠）轻微降权
                local w = u.weight
                if u.id == "repair" and stacks >= 4 then w = w * 0.4 end
                if u.id == "xp" and stacks >= 4 then w = w * 0.5 end
                avail[#avail + 1] = {u = u, w = w}
                totalW = totalW + w
            end
        end
        if #avail == 0 then break end

        -- 保底：连续 6 次未出 rare+，本次强制从 rare+ 候选抽
        local picked
        if sinceRare >= 6 then
            local rares = {}
            local rw = 0
            for _, a in ipairs(avail) do
                if a.u.rarity ~= "common" then rares[#rares + 1] = a; rw = rw + a.w end
            end
            if #rares > 0 then
                local r = Random() * rw
                for _, a in ipairs(rares) do r = r - a.w; if r <= 0 then picked = a.u; break end end
                picked = picked or rares[1].u
            end
        end
        if not picked then
            local r = Random() * totalW
            for _, a in ipairs(avail) do r = r - a.w; if r <= 0 then picked = a.u; break end end
            picked = picked or avail[1].u
        end

        if picked.rarity ~= "common" then sinceRare = 0 else sinceRare = sinceRare + 1 end
        upgradeChoices[#upgradeChoices + 1] = picked
    end
end

-- 由外部 UI 调用：选择第 index（1-based）项强化，恢复 playing。
function Game.PickUpgrade(index)
    if gameState ~= "levelup" or not upgradeChoices then return end
    local choice = upgradeChoices[index]
    if choice then
        local stacks = upgradeStacks[choice.id] or 0
        choice.apply(stacks)   -- 传入当前层数，支持边际递减
        upgradeStacks[choice.id] = stacks + 1
        table.insert(upgradePicks, choice.id)
        Emit("upgrade_picked", {id = choice.id, name = choice.name, stacks = stacks + 1})
        print("[Game] upgrade picked: " .. choice.name .. " (stacks=" .. (stacks + 1) .. ")")
    end
    pendingLevelUps = pendingLevelUps - 1
    upgradeChoices = nil
    if pendingLevelUps > 0 then
        RollUpgradeChoices()
        Emit("level_up", {level = playerLevel})
    else
        gameState = "playing"
    end
end

function Game.GetUpgradeChoices()
    if gameState ~= "levelup" then return nil end
    local list = {}
    -- WO-10/P5：升级卡 delta 预览字段，UI 只读展示，不在此做规则计算。
    for _, c in ipairs(upgradeChoices) do
        table.insert(list, {
            id = c.id, name = c.name, desc = c.desc,
            value = c.value, rarity = c.rarity,
            stacks = upgradeStacks[c.id] or 0, maxStacks = c.maxStacks,
            tradeoff = c.tradeoff,
        })
    end
    return list
end

local function RotateVelocity(vx, vy, degrees)
    local radians = math.rad(degrees)
    local c = math.cos(radians)
    local s = math.sin(radians)
    return vx * c - vy * s, vx * s + vy * c
end

local function CreateSplitMarble(source, angle, originBrick)
    local vx, vy = RotateVelocity(source.vx, source.vy, angle)
    local marble = {
        id = nextMarbleId,
        x = source.x, y = source.y,
        vx = vx, vy = vy,
        radius = source.radius,
        speed = source.speed,
        ballType = "normal",
        onSling = false,
        alive = true,
        bounceCount = source.bounceCount,
        isPrimary = false,
        generation = source.generation + 1,
        ignoredBrick = originBrick,
        giantPiercing = false,
    }
    nextMarbleId = nextMarbleId + 1
    return marble
end

local function TrySplitNormal(marble, originBrick, pendingMarbles)
    local def = BALL_TYPES.normal
    if Random() >= def.splitChance + BALL_TUNING.splitBonus then return end

    -- WO-06/P4：分裂弹继承母弹速度向量，沿 ±splitSpread 扩散，避免高速重叠。
    table.insert(pendingMarbles,
        CreateSplitMarble(marble, -def.splitSpread, originBrick))
    table.insert(pendingMarbles,
        CreateSplitMarble(marble, def.splitSpread, originBrick))
    Emit("normal_split", {
        x = marble.x, y = marble.y,
        generation = marble.generation + 1,
    })
    print("[Game] normal marble split, generation=" .. (marble.generation + 1))
end

local function FindNearestBrick(originEnemy, originBrick, originX, originY)
    local nearest = nil
    local nearestDistanceSq = math.huge
    for _, enemy in ipairs(veggies) do
        if not enemy.dead then
            for _, brick in ipairs(enemy.bricks) do
                if brick.alive and not (enemy == originEnemy and brick == originBrick) then
                    local x = enemy.x + (brick.col - 0.5) * enemy.brickSize
                    local y = enemy.y + (brick.row - 0.5) * enemy.brickSize
                    local dx = x - originX
                    local dy = y - originY
                    local distanceSq = dx * dx + dy * dy
                    if distanceSq < nearestDistanceSq then
                        nearestDistanceSq = distanceSq
                        nearest = {x = x, y = y}
                    end
                end
            end
        end
    end
    return nearest
end

local function BoostSpeedMarble(marble)
    local def = BALL_TYPES.speed
    if marble.ballType ~= "speed" then return end

    local effMax = def.maxSpeed * BALL_TUNING.speedMul
    marble.speed = math.min(effMax, marble.speed * def.speedBoost)
    local velocityLength = math.sqrt(marble.vx * marble.vx + marble.vy * marble.vy)
    if velocityLength > 0.001 then
        marble.vx = marble.vx / velocityLength * marble.speed
        marble.vy = marble.vy / velocityLength * marble.speed
    end
end

local function GetMarbleDamage(marble, def)
    if marble.ballType ~= "speed" then return def.damage + BALL_TUNING.damageBonus end
    local bonus = math.floor(math.max(0, marble.speed - def.speed) / def.damageStep)
    return math.min(def.maxDamage, def.damage + bonus + BALL_TUNING.damageBonus)
end

local function RedirectSpeedMarble(marble, originEnemy, originBrick)
    -- 削弱：受 redirectThrottle 节流，避免每次命中都黏着追踪。
    -- WO-05/P4：低于 redirectMinSpeed 不追击，消除低速段轨迹抖动。
    if marble.speed < (BALL_TYPES.speed.redirectMinSpeed or 0) then return end
    local target = FindNearestBrick(originEnemy, originBrick, marble.x, marble.y)
    if not target then return end
    if (marble.redirectCooldown or 0) > 0 then return end
    marble.redirectCooldown = BALL_TYPES.speed.redirectThrottle

    local dx = target.x - marble.x
    local dy = target.y - marble.y
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance < 0.001 then return end

    marble.vx = dx / distance * marble.speed
    marble.vy = dy / distance * marble.speed
    Emit("speed_dash", {
        x = marble.x, y = marble.y,
        targetX = target.x, targetY = target.y,
        damage = GetMarbleDamage(marble, BALL_TYPES.speed),
    })
end

local function ArmGiantPiercing(marble)
    local def = BALL_TYPES.giant
    if marble.ballType ~= "giant" or not def.pierceAfterBounce or marble.giantPiercing then
        return
    end
    marble.giantPiercing = true
    Emit("giant_pierce_armed", {x = marble.x, y = marble.y})
    print("[Game] giant marble rebound armed circular piercing")
end

-- 巨型弹贯穿伤害区：以命中砖块中心为圆心，直径 7 个敌方单元格。
--
--          o o o
--        o o o o o
--      o o o X o o o    X = 命中格
--        o o o o o       半径 = 3.5 × 命中敌人的单格尺寸
--          o o o
--
-- 圆形边缘按砖块中心判断；跨敌人但仍在圆内的单元格也会受到伤害。
local function DamageGiantArea(originEnemy, originBrick, damage, frameHitBricks)
    local centerX = originEnemy.x + (originBrick.col - 0.5) * originEnemy.brickSize
    local centerY = originEnemy.y + (originBrick.row - 0.5) * originEnemy.brickSize
    local radius = originEnemy.brickSize * (BALL_TYPES.giant.areaRadiusCells + BALL_TUNING.giantArea)
    local radiusSq = radius * radius
    local hitCount = 0

    for _, enemy in ipairs(veggies) do
        if not enemy.dead then
            for _, brick in ipairs(enemy.bricks) do
                if brick.alive and not frameHitBricks[brick] then
                    local x = enemy.x + (brick.col - 0.5) * enemy.brickSize
                    local y = enemy.y + (brick.row - 0.5) * enemy.brickSize
                    local dx = x - centerX
                    local dy = y - centerY
                    if dx * dx + dy * dy <= radiusSq then
                        frameHitBricks[brick] = true
                        DamageBrick(enemy, brick, damage)
                        hitCount = hitCount + 1
                    end
                end
            end
        end
    end

    Emit("giant_area_hit", {
        x = centerX, y = centerY,
        radius = radius, hitCount = hitCount,
    })
end

local function LaunchMarble(dx, dy, power)
    if not activeBall then return end
    local length = math.sqrt(dx * dx + dy * dy)
    if length < 1 then return end

    local def = BALL_TYPES[activeBall.ballType]
    -- WO-08/P7：power 为归一化蓄力 (0..1)，映射到 [powerMin, powerMax] 初速比例。
    local powerRatio = math.max(0, math.min(1, power or 0))
    local speedScale = BALANCE.powerMin + (BALANCE.powerMax - BALANCE.powerMin) * powerRatio
    local speed = def.speed * speedScale
    activeBall.vx = -dx / length * speed
    activeBall.vy = -dy / length * speed
    activeBall.speed = speed
    activeBall.onSling = false
    table.insert(marbles, activeBall)
    Emit("marble_launched", {
        id = activeBall.id,
        ballType = activeBall.ballType,
        x = activeBall.x,
        y = activeBall.y,
    })
    activeBall = nil
end

local function QueueNextBall()
    if #ballQueue > 0 then
        activeBall = CreateMarble(table.remove(ballQueue, 1))
    end
end

local function UpdateAiming()
    if aiming and activeBall then
        activeBall.x = aimX
        activeBall.y = aimY
    elseif activeBall and activeBall.onSling then
        activeBall.x = SLING_X
        activeBall.y = SLING_Y
    end
end

UpdateMarbles = function(dt)
    local pendingMarbles = {}
    for i = #marbles, 1, -1 do
        local marble = marbles[i]
        local def = BALL_TYPES[marble.ballType]
        local steps = 4
        local subDt = dt / steps
        local frameHitBricks = {}

        for _ = 1, steps do
            if not marble.alive then break end

            if marble.redirectCooldown and marble.redirectCooldown > 0 then
                marble.redirectCooldown = marble.redirectCooldown - subDt
            end

            marble.x = marble.x + marble.vx * subDt
            marble.y = marble.y + marble.vy * subDt

            -- WO-05/P4：反弹弹性由 ballType 决定（巨型更沉、加速更滑），默认 1.0。
            local elastic = def.bounceElasticity or 1.0
            if marble.x - marble.radius < 0 then
                marble.x = marble.radius
                marble.vx = math.abs(marble.vx) * elastic
                marble.bounceCount = marble.bounceCount + 1
                BoostSpeedMarble(marble)
                ArmGiantPiercing(marble)
            elseif marble.x + marble.radius > DW then
                marble.x = DW - marble.radius
                marble.vx = -math.abs(marble.vx) * elastic
                marble.bounceCount = marble.bounceCount + 1
                BoostSpeedMarble(marble)
                ArmGiantPiercing(marble)
            end
            if marble.y - marble.radius < 0 then
                marble.y = marble.radius
                marble.vy = math.abs(marble.vy) * elastic
                marble.bounceCount = marble.bounceCount + 1
                BoostSpeedMarble(marble)
                ArmGiantPiercing(marble)
            end

            local hit = false
            for _, enemy in ipairs(veggies) do
                if not enemy.dead then
                    for _, brick in ipairs(enemy.bricks) do
                        if marble.ignoredBrick == brick then
                            local irx = enemy.x + (brick.col - 1) * enemy.brickSize + 1
                            local iry = enemy.y + (brick.row - 1) * enemy.brickSize + 1
                            if not IntersectsBrick(marble, irx, iry,
                                enemy.brickSize - 2, enemy.brickSize - 2) then
                                marble.ignoredBrick = nil
                            end
                        elseif brick.alive and not frameHitBricks[brick] then
                            local rx = enemy.x + (brick.col - 1) * enemy.brickSize + 1
                            local ry = enemy.y + (brick.row - 1) * enemy.brickSize + 1
                            local rw = enemy.brickSize - 2
                            local rh = enemy.brickSize - 2
                            local collided = false

                            if marble.giantPiercing then
                                collided = IntersectsBrick(marble, rx, ry, rw, rh)
                                if collided then
                                    marble.x = marble.x + marble.vx * subDt * 0.5
                                    marble.y = marble.y + marble.vy * subDt * 0.5
                                end
                            else
                                collided = CollideBrick(marble, rx, ry, rw, rh)
                            end

                            if collided then
                                if marble.ballType == "speed" then
                                    BoostSpeedMarble(marble)
                                end

                                if marble.giantPiercing then
                                    -- WO-07/P4：巨型弹每次有效反弹只武装一次贯穿。本次圆范围伤害结算后
                                    -- 立即解除武装，继续直线飞行，下次反弹由 ArmGiantPiercing 重新武装一次。
                                    DamageGiantArea(enemy, brick,
                                        GetMarbleDamage(marble, def), frameHitBricks)
                                    marble.giantPiercing = false
                                    Emit("giant_pierce_consumed", {x = marble.x, y = marble.y})
                                else
                                    frameHitBricks[brick] = true
                                    DamageBrick(enemy, brick, GetMarbleDamage(marble, def))
                                end
                                if def.freezeDuration then enemy.frozen = def.freezeDuration + BALL_TUNING.iceBonus end

                                if marble.ballType == "normal" then
                                    TrySplitNormal(marble, brick, pendingMarbles)
                                elseif marble.ballType == "speed" then
                                    RedirectSpeedMarble(marble, enemy, brick)
                                elseif marble.ballType == "giant" and not marble.giantPiercing then
                                    hit = true
                                    ArmGiantPiercing(marble)
                                end

                                if not marble.giantPiercing then hit = true end
                                break
                            end
                        end
                    end
                    if hit or not marble.alive then break end
                end
            end

            if marble.y - marble.radius > DH then
                marble.alive = false
                break
            end
        end

        if not marble.alive then
            table.remove(marbles, i)
            if marble.isPrimary then EnqueueNextBall() end
            Emit("marble_removed", {id = marble.id})
        end
    end

    for _, marble in ipairs(pendingMarbles) do
        table.insert(marbles, marble)
        Emit("marble_split_spawned", {
            id = marble.id,
            generation = marble.generation,
        })
    end
end

UpdateEnemies = function(dt)
    for i = #veggies, 1, -1 do
        if gameState == "gameover" then break end
        local enemy = veggies[i]
        local width = enemy.gridW * enemy.brickSize
        local height = enemy.gridH * enemy.brickSize
        local speedMultiplier = 1

        if enemy.frozen > 0 then
            enemy.frozen = math.max(0, enemy.frozen - dt)
            speedMultiplier = 0.3
        end

        enemy.phase = enemy.phase + dt * enemy.swayFreq
        enemy.x = enemy.baseX + math.sin(enemy.phase) * enemy.swayAmp
        if enemy.x < 10 then
            enemy.baseX = 10 + (enemy.baseX - enemy.x)
            enemy.x = 10
        elseif enemy.x + width > DW - 10 then
            enemy.baseX = DW - 10 - width - ((enemy.x + width) - (DW - 10))
            enemy.x = DW - 10 - width
        end
        enemy.y = enemy.y + enemy.vy * speedMultiplier * dt

        -- 每个方块独立判定越线：越过目标线的方块立即销毁并对基地造成伤害。
        -- 飞行器以编队整体下移，单个方块越线即视为该块突破防线。
        for _, brick in ipairs(enemy.bricks) do
            if brick.alive then
                local brickBottom = enemy.y + brick.row * enemy.brickSize
                if brickBottom > DANGER_Y then
                    brick.alive = false
                    baseHp = baseHp - BALL_TUNING.brickDmg
                    local bx = enemy.x + (brick.col - 0.5) * enemy.brickSize
                    Emit("base_hit", {x = bx, y = DANGER_Y, brick = true})
                    if baseHp <= 0 then
                        baseHp = 0
                        enemy.dead = true
                        break
                    end
                end
            end
        end

        if baseHp <= 0 then
            gameState = "gameover"
            if score > highScore then highScore = score end
            Emit("game_over", {score = score, highScore = highScore, wave = wave})
            print("[Game] game over, score=" .. score .. ", wave=" .. wave)
            break
        end

        if not enemy.dead and IsEnemyCleared(enemy) then
            enemy.dead = true
            score = score + 50
            clearStreak = clearStreak + 1
            -- 连续清空的连击经验加成，鼓励连续压制。
            local bonus = math.min(clearStreak - 1, BALANCE.clearStreakBonusCap)
            GainXp(XP_PER_CLEAR + bonus)
            Emit("enemy_cleared", {
                enemyId = enemy.id,
                x = enemy.x + width * 0.5,
                y = enemy.y + height * 0.5,
                streak = clearStreak,
            })
        end

        if enemy.dead then table.remove(veggies, i) end
    end
end

UpdateReload = function()
    if not activeBall and #ballQueue > 0 then QueueNextBall() end
end

UpdateWaveLogic = function(dt)
    -- 幸存者节奏（WO-12/P6）：持续涌出，间隔随波次收紧并呈「阶段呼吸」，
    -- 受同屏上限约束。升级期间（pendingLevelUps>0）不刷怪，既有编队继续下移。
    if gameState ~= "playing" or pendingLevelUps > 0 then return end

    waveCooldown = waveCooldown - dt
    if waveCooldown > 0 then return end

    -- 阶段呼吸：每 phaseLength 波额外收紧，每 breatherEvery 波回弹 relax 制造喘息。
    local interval = BALANCE.waveInterval
        - (wave - 1) * BALANCE.waveTightenStep
        - math.floor(wave / BALANCE.phaseLength) * BALANCE.phaseTightenBonus
    if wave % BALANCE.breatherEvery == 0 then
        interval = interval + BALANCE.breatherRelax
    end
    interval = math.max(BALANCE.waveIntervalMin, interval)

    -- 动态同屏上限：每 8 波 +1（受 maxConcurrent 基准，护栏上限由 P9 帧预算约束）。
    local concurrentCap = BALANCE.maxConcurrent + math.floor(wave / 8)

    -- 安全窗口：场上已清空且距上次 spawn 超过 safeGap 时，给一次短喘息不强制刷。
    if #veggies == 0 then
        local sinceClear = (BALANCE.waveInterval - waveCooldown)
        if sinceClear < BALANCE.safeGap then return end
    end

    if #veggies < concurrentCap then
        wave = wave + 1
        SpawnWave()
    end
    waveCooldown = interval
end

local function GetPullState(px, py)
    local dx = px - SLING_X
    local dy = py - SLING_Y
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance > MAX_PULL then
        dx = dx / distance * MAX_PULL
        dy = dy / distance * MAX_PULL
    end
    local maxDownDy = DH - SLING_Y - 20
    if dy > maxDownDy then dy = maxDownDy end
    distance = math.sqrt(dx * dx + dy * dy)
    return dx, dy, distance
end

local function BuildAimTrajectory()
    local points = {}
    if not aiming or not activeBall then return points end

    local dx = activeBall.x - SLING_X
    local dy = activeBall.y - SLING_Y
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance < 5 then return points end

    local def = BALL_TYPES[activeBall.ballType]
    -- WO-08/P7：预测线初速比例与 LaunchMarble 共用 BALANCE 曲线，保证预测一致。
    local powerRatio = math.max(0, math.min(1, distance / BALANCE.maxPull))
    local speed = def.speed * (BALANCE.powerMin + (BALANCE.powerMax - BALANCE.powerMin) * powerRatio)
    local vx = -dx / distance * speed
    local vy = -dy / distance * speed
    local x, y = activeBall.x, activeBall.y
    local stepDistance = 8
    local sampleCount = 140
    table.insert(points, {x = x, y = y, progress = 0})

    for i = 1, sampleCount do
        local velocityLength = math.sqrt(vx * vx + vy * vy)
        if velocityLength < 0.001 then break end
        x = x + vx / velocityLength * stepDistance
        y = y + vy / velocityLength * stepDistance
        if x - activeBall.radius < 0 then
            x = activeBall.radius
            vx = math.abs(vx)
        elseif x + activeBall.radius > DW then
            x = DW - activeBall.radius
            vx = -math.abs(vx)
        end
        if y - activeBall.radius < 0 then
            y = activeBall.radius
            vy = math.abs(vy)
        end
        if y - activeBall.radius > DH then break end
        table.insert(points, {x = x, y = y, progress = i / sampleCount})
    end
    return points
end

function Game.Init(config)
    config = config or {}
    DW = config.width or DW
    DH = config.height or DH
    SetRandomSeed(config.seed or 1)
    pendingEvents = {}
    highScore = 0
    ResetGame()
    pendingEvents = {}
    gameState = "menu"
    print("[Game] core initialized at " .. DW .. "x" .. DH)
end

function Game.Update(dt)
    elapsed = elapsed + dt
    if gameState == "playing" then
        UpdateAiming()
        UpdateMarbles(dt)
        UpdateEnemies(dt)
        UpdateReload()
        UpdateWaveLogic(dt)
    elseif gameState == "paused" then
        -- 暂停态冻结所有玩法推进，仅保留 elapsed 累加用于 UI 动画。
    end
end

function Game.IsLevelUp()
    return gameState == "levelup"
end

function Game.PointerDown(px, py)
    if gameState == "menu" or gameState == "gameover" then
        StartGame()
        return
    end
    if gameState ~= "playing" or not activeBall or py < DANGER_Y - 100 then return end

    aiming = true
    local dx, dy = GetPullState(px, py)
    aimX = SLING_X + dx
    aimY = SLING_Y + dy
end

function Game.PointerMove(px, py)
    if not aiming then return end
    local dx, dy = GetPullState(px, py)
    aimX = SLING_X + dx
    aimY = SLING_Y + dy
end

function Game.PointerUp(px, py)
    if not aiming then return end
    local dx, dy, distance = GetPullState(px, py)
    aiming = false
    if distance > 15 then
        LaunchMarble(dx, dy, distance / BALANCE.maxPull)
    elseif activeBall then
        activeBall.x = SLING_X
        activeBall.y = SLING_Y
    end
end

function Game.HandleAction(action, pressed)
    if pressed and action == "start" and (gameState == "menu" or gameState == "gameover") then
        StartGame()
    end
end

function Game.Pause()
    if gameState == "playing" then
        gameState = "paused"
        Emit("game_paused")
    end
end

function Game.Resume()
    if gameState == "paused" then
        gameState = "playing"
        Emit("game_resumed")
    end
end

function Game.IsPaused()
    return gameState == "paused"
end

function Game.DrainEvents()
    local events = pendingEvents
    pendingEvents = {}
    return events
end

function Game.GetSnapshot()
    return {
        state = gameState,
        score = score,
        highScore = highScore,
        baseHp = baseHp,
        maxBaseHp = BASE_HP,
        wave = wave,
        elapsed = elapsed,
        playerLevel = playerLevel,
        xp = xp,
        xpToNext = xpToNext,
        pendingLevelUps = pendingLevelUps,
        upgradePicks = upgradePicks,
        clearStreak = clearStreak,
        bricksBroken = bricksBroken,
        concurrentCount = #veggies,    -- WO-12/P6：当前同屏编队数（HUD 指标）
        brickDmg = BALL_TUNING.brickDmg,
        upgradeChoices = (gameState == "levelup" and upgradeChoices) or nil,
        veggies = veggies,
        marbles = marbles,
        aiming = aiming,
        aimX = aimX,
        aimY = aimY,
        aimTrajectory = BuildAimTrajectory(),
        slingX = SLING_X,
        slingY = SLING_Y,
        maxPull = MAX_PULL,
        activeBall = activeBall,
        ballQueue = ballQueue,
        ballOrder = BALL_ORDER,
        width = DW,
        height = DH,
        dangerY = DANGER_Y,
    }
end

return Game
