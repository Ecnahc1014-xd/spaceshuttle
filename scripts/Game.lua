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

-- P11 词条系统（规则层）：弹珠可携带的"词条"修饰，影响伤害/弹道/反馈行为。
-- 仅通过 CreateMarble 的 words 表注入；apply() 在生成时改写 marble 字段或挂载行为标记，
-- 不触碰任何渲染 API。视觉表现（词条环绕光、异常染色）推迟到 deferred.md D 由表现层消费事件。
local BALL_WORDS = {
    pierce = {  -- 贯穿：本次飞行的首块命中不反弹，直接穿过继续飞行
        name = "贯穿",
        apply = function(marble) marble.wordPierce = true end,
    },
    lifesteal = {  -- 吸血：每次击碎砖块为基地回复少量生命（最多回到上限）
        name = "吸血",
        value = 1,
        apply = function(marble, def) marble.wordLifesteal = def.value or 1 end,
    },
    chain = {  -- 连锁：命中时向最近另一砖块追加一次小范围溅射
        name = "连锁",
        radius = 1.6,
        apply = function(marble, def) marble.wordChain = def.radius or 1.6 end,
    },
    momentum = {  -- 动量：伤害随当前速度提升（高速球更痛）
        name = "动量",
        apply = function(marble) marble.wordMomentum = true end,
    },
    heavy = {  -- 重弹：反弹弹性更低、命中砖块额外压制（冻结类似减速由 ice 处理）
        name = "重弹",
        apply = function(marble) marble.wordHeavy = true end,
    },
}
local WORD_IDS = { "pierce", "lifesteal", "chain", "momentum", "heavy" }

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
local deferredXp = 0               -- 升级触发同帧后续击碎经验原值，完成选卡后结算
local upgradeChoices = nil         -- 当前可选的三选一强化
local upgradePicks = {}            -- 已选强化的累计效果（id 列表，可重复）
local upgradeStacks = {}           -- 已选强化各 id 的层数（WO-09/P5 叠加上限判定）
-- P11：已激活词条（来自专属词条升级），作为新弹珠的默认词条第。规则层持有，渲染层只读快照。
local activeWords = {}
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
    -- P11 词条系统：专属"词条"升级，apply 把对应 word 加入 activeWords（规则变量），
    -- 新生成弹珠自动携带；视觉染色推迟到表现层消费新事件。
    { id = "word_pierce", name = "贯穿弹芯", desc = "弹珠附带[贯穿]词条",
      weight = 0.5, rarity = "rare", maxStacks = 1, tradeoff = false, value = "词条:贯穿",
      apply = function(stacks) activeWords.pierce = true end },
    { id = "word_chain", name = "链能线圈", desc = "弹珠附带[连锁]词条",
      weight = 0.5, rarity = "rare", maxStacks = 1, tradeoff = false, value = "词条:连锁",
      apply = function(stacks) activeWords.chain = true end },
    { id = "word_momentum", name = "动量储能", desc = "弹珠附带[动量]词条",
      weight = 0.5, rarity = "rare", maxStacks = 1, tradeoff = false, value = "词条:动量",
      apply = function(stacks) activeWords.momentum = true end },
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

-- WO-16/P9：快照缓冲复用，避免每帧构造新 table 触发 GC 抖动。
-- 渲染/表现层只读此表，不得缓存引用越过本帧。
local snapshotBuffer_ = nil

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

local function CreateMarble(ballType, words)
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
        words = {},    -- P11：词条修饰挂载表（行为标记），空表表示无词条
    }
    -- P11：注入词条（来自升级或 Boss 授予），逐个调用 apply() 改写 marble 行为。
    if words then
        for _, wordId in ipairs(words) do
            local wordDef = BALL_WORDS[wordId]
            if wordDef then
                wordDef.apply(marble, wordDef)
                marble.words[wordId] = true
            end
        end
    end
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

-- P11：把 activeWords 规则表展开为有序词条 id 列表，供 CreateMarble 注入。
local function CollectActiveWords()
    local list = {}
    for _, id in ipairs(WORD_IDS) do
        if activeWords[id] then list[#list + 1] = id end
    end
    return list
end

local function LoadBalls()
    ballQueue = {}
    ballCycleIndex = 0
    for _ = 1, #BALL_ORDER do EnqueueNextBall() end
    activeBall = CreateMarble(table.remove(ballQueue, 1), CollectActiveWords())
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
    deferredXp = 0
    upgradeChoices = nil
    upgradePicks = {}
    upgradeStacks = {}
    activeWords = {}    -- P11：词条重置
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

    -- A3：行为分化——读取该型性格参数，使不同飞机横摆/节奏/下压感各异。
    local beh = AircraftData.behavior and AircraftData.behavior[aircraftKey]
        or { swayAmp = 18, swayFreq = 0.4, descentMul = 1.0, agility = 0.8 }
    local swayAmp = beh.swayAmp + Random() * beh.swayAmp * 0.3
    local swayFreq = beh.swayFreq * (0.85 + Random() * 0.3)
    local descent = beh.descentMul

    local bricks = {}
    for entry in (data.data .. ";"):gmatch("(.-);") do
        local col, row = entry:match("(%d+),(%d+),%d+,%d+,%d+")
        if col then
            table.insert(bricks, {
                col = tonumber(col), row = tonumber(row),
                hp = brickHp, maxHp = brickHp, alive = true,
                ejected = false,
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
        vy = baseSpeed * data.speedMul * 0.25 * descent,
        swayAmp = swayAmp,
        swayFreq = swayFreq,
        agility = beh.agility,    -- A3：节奏/反应质感标记（渲染层可读）
        phase = Random() * math.pi * 2,
        bricks = bricks,
        dead = false,
        frozen = 0,
        freezeRatio = 0,    -- WO-13/P2：渲染层只读冻结比例（0..1），初始化为零
    }
    nextEnemyId = nextEnemyId + 1
    return enemy
end

SpawnWave = function()
    -- P11：Boss 波（每 10 波一次）。Boss 是单支高血量巨型编队，拥有阶段机；
    -- 仅规则（HP/阶段/vulnerable），视觉由表现层推迟消费 boss_phase 事件。
    if wave % 10 == 0 then
        local bossKey = "interceptor"
        if not AircraftData[bossKey] then
            for key in pairs(AircraftData) do bossKey = key; break end
        end
        local brickSize = GetBrickSize(wave)
        local bossHp = 6 + math.floor(wave / 10) * 2
        local enemy = CreateEnemy(bossKey, DW * 0.5 - 60, -120, brickSize, bossHp, 14)
        if enemy then
            enemy.isBoss = true
            enemy.bossPhase = 1
            enemy.vulnerable = false
            enemy.swayAmp = 26
            enemy.swayFreq = 0.22
            veggies[#veggies + 1] = enemy
            Emit("boss_spawn", {enemyId = enemy.id, wave = wave})
            print("[Game] BOSS spawned at wave " .. wave)
        end
        Emit("wave_started", {wave = wave})
        print("[Game] wave " .. wave .. " (BOSS) spawned")
        return
    end

    local pool = GetAvailableTypes(wave)
    if #pool == 0 then
        print("[Game] WARNING: empty aircraft pool")
        return
    end

    local count, baseSpeed, brickHp = GetWaveParams(wave)
    local brickSize = GetBrickSize(wave)
    local margin = 20
    local placed = {}
    local gap = 8
    local maxYStep = 7

    local function Overlaps(candidateX, candidateY, candidateW, candidateH)
        for _, item in ipairs(placed) do
            if candidateX < item.x + item.w + gap
                and candidateX + candidateW + gap > item.x
                and candidateY < item.y + item.h + gap
                and candidateY + candidateH + gap > item.y then
                return true
            end
        end
        return false
    end

    for i = 1, count do
        local aircraftKey = pool[RandomInt(1, #pool)]
        local aircraftWidth, aircraftHeight = GetAircraftSize(aircraftKey, brickSize)
        local x, y = margin, -aircraftHeight * 0.3
        local found = false
        for _ = 1, 80 do
            local candidateX = margin + Random() * math.max(1, DW - aircraftWidth - margin * 2)
            local candidateY = -aircraftHeight * 0.3 - (i - 1) * maxYStep - RandomInt(0, 10)
            if not Overlaps(candidateX, candidateY, aircraftWidth, aircraftHeight) then
                x, y, found = candidateX, candidateY, true
                break
            end
        end
        if not found then
            -- 确定性纵向 fallback：继续向上错层，绝不接受与已放置飞机重叠的位置。
            y = -aircraftHeight * 0.3 - (i - 1) * (aircraftHeight + gap)
            local guard = 0
            while Overlaps(x, y, aircraftWidth, aircraftHeight) do
                y = y - aircraftHeight - gap
                guard = guard + 1
                if guard > count then break end
            end
        end
        placed[#placed + 1] = {x = x, y = y, w = aircraftWidth, h = aircraftHeight}
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

local function EjectBrick(enemy, brick)
    if brick.ejected or not brick.alive then return false end
    local data = AircraftData[enemy.aircraftKey]
    local x = enemy.x + (brick.col - 0.5) * enemy.brickSize
    local y = enemy.y + (brick.row - 0.5) * enemy.brickSize
    brick.alive = false
    brick.ejected = true
    score = score + data.score
    bricksBroken = bricksBroken + 1
    GainXp(XP_PER_BRICK)

    local angle = Random() * math.pi * 2
    local speed = 240 + Random() * 260
    local lift = 180 + Random() * 120
    Emit("brick_hit", {
        enemyId = enemy.id, aircraftKey = enemy.aircraftKey,
        col = brick.col, row = brick.row, x = x, y = y,
        destroyed = true, score = data.score,
    })
    Emit("brick_ejected", {
        enemyId = enemy.id, aircraftKey = enemy.aircraftKey,
        col = brick.col, row = brick.row, x = x, y = y,
        vx = math.cos(angle) * speed,
        vy = math.sin(angle) * speed - lift,
        rotation = Random() * math.pi * 2,
        angularVelocity = (Random() * 2 - 1) * 13,
        pitch = (Random() * 2 - 1) * 0.9,
        roll = (Random() * 2 - 1) * 0.9,
        axisPitchSpeed = (Random() * 2 - 1) * 8,
        axisRollSpeed = (Random() * 2 - 1) * 8,
        lifetime = 1.15 + Random() * 0.55,
        brickSize = enemy.brickSize,
        style = enemy.aircraftKey,
    })
    return true
end

local function DamageBrick(enemy, brick, damage)
    if brick.ejected or not brick.alive then return end
    -- 命中即脱离编队：该方块立刻失去规则碰撞，作为独立箱体飞散。
    if enemy.isBoss and enemy.vulnerable then
        damage = (damage or 1) * 1.5
    end
    brick.hp = brick.hp - (damage or 1)
    EjectBrick(enemy, brick)
end

-- P11 五异常反应系统（规则层）：砖块可携带 burn/shock/corrode/freeze/volatile 五种异常状态，
-- 由命中弹珠的词条或类型施加；状态间存在反应（冻结+灼烧=融穿、电击+冻结=碎裂）额外结算。
-- 仅记录计时与伤害，视觉染色由表现层推迟消费 status 事件。
local function ApplyBrickStatus(brick, status, duration, power)
    brick.status = brick.status or {}
    local cur = brick.status[status] or {time = 0, power = 0}
    cur.time = math.max(cur.time, duration)
    cur.power = math.max(cur.power, power or 1)
    brick.status[status] = cur
end

local function TickBrickStatus(enemy, brick, dt)
    if not brick.status then return end
    local x = enemy.x + (brick.col - 0.5) * enemy.brickSize
    local y = enemy.y + (brick.row - 0.5) * enemy.brickSize
    local hasFreeze = (brick.status.freeze and brick.status.freeze.time > 0)
    local hasBurn = (brick.status.burn and brick.status.burn.time > 0)
    -- 反应：冻结 + 灼烧 = 融穿，每帧追加伤害并加速冻结消退。
    if hasFreeze and hasBurn then
        brick.hp = brick.hp - (0.6 + brick.status.burn.power) * dt
        brick.status.freeze.time = brick.status.freeze.time - dt * 2
        if brick.hp <= 0 and brick.alive then
            EjectBrick(enemy, brick)
            Emit("status_reaction", {enemyId = enemy.id, kind = "melt", x = x, y = y})
        end
    elseif hasBurn then
        brick.hp = brick.hp - (0.35 + brick.status.burn.power) * dt
        if brick.hp <= 0 and brick.alive then
            EjectBrick(enemy, brick)
        end
    end
    -- 腐蚀：持续削减该砖块有效护甲（这里直接换算为每秒小伤害）。
    if brick.status.corrode and brick.status.corrode.time > 0 then
        brick.hp = brick.hp - 0.25 * dt
        if brick.hp <= 0 and brick.alive then
            EjectBrick(enemy, brick)
        end
    end
    -- 易暴：寿终时引爆邻格（volatile），额外范围伤害由 base_hit 风格事件广播。
    local volatile = brick.status.volatile
    if volatile and volatile.time > 0 and not brick.alive and not volatile.detonated then
        volatile.detonated = true
        local radius = enemy.brickSize * (volatile.power or 1.5)
        local radiusSq = radius * radius
        for _, other in ipairs(enemy.bricks) do
            if other.alive and other ~= brick then
                local ox = enemy.x + (other.col - 0.5) * enemy.brickSize
                local oy = enemy.y + (other.row - 0.5) * enemy.brickSize
                local dx = ox - x; local dy = oy - y
                if dx * dx + dy * dy <= radiusSq then
                    DamageBrick(enemy, other, 1)
                end
            end
        end
        Emit("status_reaction", {enemyId = enemy.id, kind = "volatile", x = x, y = y})
    end
    for _, status in ipairs({"burn", "shock", "corrode", "freeze", "volatile"}) do
        local s = brick.status[status]
        if s and s.time > 0 then s.time = s.time - dt end
    end
end

local function IsEnemyCleared(enemy)
    for _, brick in ipairs(enemy.bricks) do
        if brick.alive then return false end
    end
    return true
end

-- 幸存者升级：获得经验，跨级时累计待处理的升级选择。
GainXp = function(amount)
    if pendingLevelUps > 0 then
        deferredXp = deferredXp + amount
        return
    end
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

RollUpgradeChoices = function()
    -- WO-09/P5：加权抽卡 + 叠加上限 + 稀有保底。
    upgradeChoices = {}
    local sinceRare = 0
    for _ = 1, 3 do
        local avail = {}
        local totalW = 0
        for _, u in ipairs(UPGRADE_POOL) do
            local stacks = upgradeStacks[u.id] or 0
            if stacks < u.maxStacks then
                local w = u.weight
                if u.id == "repair" and stacks >= 4 then w = w * 0.4 end
                if u.id == "xp" and stacks >= 4 then w = w * 0.5 end
                avail[#avail + 1] = {u = u, w = w}
                totalW = totalW + w
            end
        end
        if #avail == 0 then break end

        local picked
        if sinceRare >= 6 then
            local rares = {}
            local rareWeight = 0
            for _, candidate in ipairs(avail) do
                if candidate.u.rarity ~= "common" then
                    rares[#rares + 1] = candidate
                    rareWeight = rareWeight + candidate.w
                end
            end
            if #rares > 0 then
                local roll = Random() * rareWeight
                for _, candidate in ipairs(rares) do
                    roll = roll - candidate.w
                    if roll <= 0 then picked = candidate.u; break end
                end
                picked = picked or rares[1].u
            end
        end
        if not picked then
            local roll = Random() * totalW
            for _, candidate in ipairs(avail) do
                roll = roll - candidate.w
                if roll <= 0 then picked = candidate.u; break end
            end
            picked = picked or avail[1].u
        end

        if picked.rarity ~= "common" then
            sinceRare = 0
        else
            sinceRare = sinceRare + 1
        end
        upgradeChoices[#upgradeChoices + 1] = picked
    end

    -- 抽卡候选不足时仍必须提供可点击的完整三选一，禁止进入不可恢复的空升级态。
    if #upgradeChoices < 3 then
        for _, u in ipairs(UPGRADE_POOL) do
            if #upgradeChoices >= 3 then break end
            local duplicate = false
            for _, picked in ipairs(upgradeChoices) do
                if picked.id == u.id then duplicate = true; break end
            end
            if not duplicate and (upgradeStacks[u.id] or 0) < u.maxStacks then
                upgradeChoices[#upgradeChoices + 1] = u
            end
        end
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
        if deferredXp > 0 then
            local bufferedXp = deferredXp
            deferredXp = 0
            GainXp(bufferedXp)
        end
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
    -- 碰撞区只遍历仍在编队中的 alive 方块；ejected 方块不会再次命中。
    for _, enemy in ipairs(veggies) do
        if not enemy.dead then
            for _, brick in ipairs(enemy.bricks) do
                if brick.alive and not brick.ejected and not (enemy == originEnemy and brick == originBrick) then
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
                if brick.alive and not brick.ejected and not frameHitBricks[brick] then
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
        activeBall = CreateMarble(table.remove(ballQueue, 1), CollectActiveWords())
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
                        elseif brick.alive and not brick.ejected and not frameHitBricks[brick] then
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

                                -- P11：命中时按弹珠词条/类型施加异常状态（仅记录，视觉推迟）。
                                if marble.words and marble.words.pierce then
                                    ApplyBrickStatus(brick, "shock", 1.2, 1)
                                end
                                if marble.words and marble.words.chain then
                                    ApplyBrickStatus(brick, "corrode", 2.0, 1)
                                end
                                if marble.words and marble.words.momentum then
                                    ApplyBrickStatus(brick, "burn", 1.5, 1)
                                end
                                if marble.ballType == "giant" then
                                    ApplyBrickStatus(brick, "volatile", 1.5, 1.5)
                                end
                                if def.freezeDuration then
                                    ApplyBrickStatus(brick, "freeze",
                                        def.freezeDuration + BALL_TUNING.iceBonus, 1)
                                end

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

local function ResolveEnemyOverlap(enemy)
    if enemy.dead then return end
    local enemyWidth = enemy.gridW * enemy.brickSize
    local enemyHeight = enemy.gridH * enemy.brickSize
    local gap = 8
    local ownLeft = enemy.x
    local ownTop = enemy.y
    for _, other in ipairs(veggies) do
        if other ~= enemy and not other.dead and other.id < enemy.id then
            local otherWidth = other.gridW * other.brickSize
            local otherHeight = other.gridH * other.brickSize
            local overlapX = math.min(enemy.x + enemyWidth + gap,
                other.x + otherWidth + gap)
                - math.max(enemy.x - gap, other.x - gap)
            local overlapY = math.min(enemy.y + enemyHeight + gap,
                other.y + otherHeight + gap)
                - math.max(enemy.y - gap, other.y - gap)
            if overlapX > 0 and overlapY > 0 then
                if overlapX <= overlapY then
                    local direction = enemy.x < other.x and -1 or 1
                    if math.abs(enemy.x - other.x) < 0.001 then direction = 1 end
                    enemy.x = enemy.x + direction * overlapX
                    enemy.baseX = enemy.x - math.sin(enemy.phase) * enemy.swayAmp
                else
                    enemy.y = other.y - enemyHeight - gap
                end
            end
        end
    end
    if enemy.x ~= ownLeft or enemy.y ~= ownTop then
        enemy.baseX = enemy.x - math.sin(enemy.phase) * enemy.swayAmp
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

        -- WO-13/P2：暴露冻结比例给渲染层，用于顶点色冷色偏移与正面霜冻高光。
        -- 基准为冰弹冻结时长 + 深寒涂层加成，渲染层只读此值，不得反向修改权威状态。
        local freezeRef = BALL_TYPES.ice.freezeDuration + BALL_TUNING.iceBonus
        enemy.freezeRatio = enemy.frozen > 0
            and math.max(0, math.min(1, enemy.frozen / freezeRef))
            or 0

        -- P11：异常状态逐帧结算（DoT/反应/易暴），仅在砖块存活时推进。
        for _, brick in ipairs(enemy.bricks) do
            if brick.alive and brick.status then
                TickBrickStatus(enemy, brick, dt)
            end
        end

        -- P11：Boss 阶段机（仅规则）。按存活砖块比例切换阶段，阶段决定 vulnerability 窗口。
        if enemy.isBoss then
            local aliveCount = 0
            for _, brick in ipairs(enemy.bricks) do
                if brick.alive then aliveCount = aliveCount + 1 end
            end
            local ratio = aliveCount / math.max(1, #enemy.bricks)
            local newPhase = ratio > 0.66 and 1 or (ratio > 0.33 and 2 or 3)
            if newPhase ~= enemy.bossPhase then
                enemy.bossPhase = newPhase
                -- 阶段切换：phase 1 普通；phase 2 加速下移；phase 3 狂暴（越线伤害提升由 brickDmg 决定）。
                enemy.vulnerable = (newPhase == 2)
                Emit("boss_phase", {enemyId = enemy.id, phase = newPhase, vulnerable = enemy.vulnerable})
            end
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
        ResolveEnemyOverlap(enemy)

        -- 每个方块独立判定越线：越过目标线的方块立即销毁并对基地造成伤害。
        -- 飞行器以编队整体下移，单个方块越线即视为该块突破防线。
        for _, brick in ipairs(enemy.bricks) do
            if brick.alive then
                local brickBottom = enemy.y + brick.row * enemy.brickSize
                if brickBottom > DANGER_Y then
                    brick.alive = false
                    brick.ejected = true
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
    if gameState ~= "playing" then
        -- 非战斗态只保留时钟，供暂停/升级/菜单表现动画使用。
        return
    end

    UpdateAiming()
    UpdateMarbles(dt)
    if gameState ~= "playing" then return end
    UpdateEnemies(dt)
    if gameState ~= "playing" then return end
    UpdateReload()
    UpdateWaveLogic(dt)
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
    -- WO-16/P9：复用常驻缓冲，仅每帧覆盖字段。瞄准状态只供拖拽发射，不再生成预瞄轨迹。
    local s = snapshotBuffer_ or {}
    snapshotBuffer_ = s
    s.state = gameState
    s.score = score
    s.highScore = highScore
    s.baseHp = baseHp
    s.maxBaseHp = BASE_HP
    s.wave = wave
    s.elapsed = elapsed
    s.playerLevel = playerLevel
    s.xp = xp
    s.xpToNext = xpToNext
    s.pendingLevelUps = pendingLevelUps
    s.upgradePicks = upgradePicks
    s.clearStreak = clearStreak
    s.bricksBroken = bricksBroken
    s.concurrentCount = #veggies    -- WO-12/P6：当前同屏编队数（HUD 指标）
    s.brickDmg = BALL_TUNING.brickDmg
    -- P11：已激活词条（只读列表，供 HUD 展示，不反向写规则）。
    local words = {}
    for _, id in ipairs(WORD_IDS) do
        if activeWords[id] then words[#words + 1] = id end
    end
    s.activeWords = words
    s.upgradeChoices = (gameState == "levelup" and upgradeChoices) or nil
    s.veggies = veggies
    s.marbles = marbles
    s.aiming = aiming
    s.aimX = aimX
    s.aimY = aimY
    s.slingX = SLING_X
    s.slingY = SLING_Y
    s.maxPull = MAX_PULL
    s.activeBall = activeBall
    s.ballQueue = ballQueue
    s.ballOrder = BALL_ORDER
    s.width = DW
    s.height = DH
    s.dangerY = DANGER_Y
    return s
end

return Game
