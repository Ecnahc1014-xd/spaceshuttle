-- Game.lua
-- 太空飞机弹珠核心玩法。只维护规则、碰撞和权威状态，不依赖任何渲染 API。

local AircraftData = require "AircraftPixelData"

local Game = {}

local DW = 540
local DH = 960
-- 顶部反弹边界（游戏坐标）。调整历史：最初为 0（屏幕内半空反弹），v0.10.8 抬到 -270（完全出屏），
-- v0.10.10 取两者均值 -135：投影到设计坐标约 y≈105，恰在 HUD 下方，载具飞到战场顶部才反弹。
-- 左右边界仍是 0 / DW；视觉边框必须与此常量一致（见 Scene3DBackend.CreateWorldEdges）。
local TOP_BOUND_Y = -135
local BASE_BRICK_SIZE = 16
local SLING_X = 270
local SLING_Y = 850
local MAX_PULL = 150
local DANGER_Y = 900
local BASE_HP = 100

-- 幸存者化参数
local BRICK_BASE_DAMAGE = 0.5      -- 每行方块越过目标线时的基础伤害，逐行向上取整（每行实际扣 1）
local XP_PER_BRICK = 1             -- 击碎一个方块获得的经验
local XP_PER_CLEAR = 8             -- 清掉整支飞船的额外经验
local BASE_XP_TO_NEXT = 26         -- 第一次升级所需经验（单架侦察机约 50 格，约两架升一级）
local WAVE_INTERVAL = 18.0          -- 持续刷新波次的基础间隔（秒，v0.10.27 再放慢）
local WAVE_INTERVAL_MIN = 9.0      -- 后期最快刷新间隔
local MAX_CONCURRENT = 8           -- 同屏飞船数量上限，避免无限叠加

-- 数值平衡表（WO-01/P1）：局内不可变数值集中管理，便于调参与离线模拟。
-- 旧常量名仍作为本表的初始化来源，保持向后可读别名。
local BALANCE = {
    baseHp = BASE_HP,
    brickBaseDamage = BRICK_BASE_DAMAGE,
    xpPerBrick = XP_PER_BRICK,
    xpPerClear = XP_PER_CLEAR,
    baseXpToNext = BASE_XP_TO_NEXT,
    xpToNextGrowth = 1.26,          -- WO-02/P1：每级经验阈值指数乘子（v0.10.10 随基础阈值上调重调）
    waveInterval = WAVE_INTERVAL,
    waveIntervalMin = WAVE_INTERVAL_MIN,
    waveTightenStep = 0.15,         -- 波次间隔随波次收紧步长（v0.10.27 随基础间隔上调一并放缓）
    maxConcurrent = MAX_CONCURRENT,
    clearStreakBonusCap = 5,        -- WO-03/P1：连击经验加成封顶（原写死 5）
    -- 以下为批次2（P6 WO-12）预留字段，当前 UpdateWaveLogic 尚未使用
    phaseLength = 6,
    phaseTightenBonus = 0.35,
    breatherEvery = 12,
    breatherRelax = 2.0,
    safeGap = 2.0,
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
    -- 越线整体伤害净加成：在“越线行数 × ceil(0.5)”合计后一次性附加（装甲 -1 / 玻璃大炮 +1）。
    lineDamageBonus = 0,
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
-- detail 为天赋卡详情描述（自动换行展示）；value 是单次增量徽标；tradeoff=抉择型风险。
local UPGRADE_POOL = {
    { id = "damage", name = "穿甲弹头", desc = "所有弹珠伤害 +1",
      detail = "所有弹珠命中砖块时额外造成 1 点伤害，更快击碎高耐久敌机。",
      weight = 1, rarity = "common", maxStacks = 8, tradeoff = false, value = "+1 伤害",
      apply = function(stacks) BALL_TUNING.damageBonus = BALL_TUNING.damageBonus + 1 end },
    { id = "giant", name = "重型化", desc = "巨型弹贯穿范围 +1 格",
      detail = "巨型弹贯穿爆发的圆形杀伤半径扩大 1 格，一次反弹波及更多砖块。",
      weight = 1, rarity = "common", maxStacks = 3, tradeoff = false, value = "+1 格",
      apply = function(stacks) BALL_TUNING.giantArea = BALL_TUNING.giantArea + 1.0 end },
    { id = "split", name = "裂变核", desc = "基础弹分裂概率 +3%",
      detail = "基础弹命中砖块时分裂出两颗小弹的概率提高 3%，弹幕更密集。",
      weight = 1, rarity = "common", maxStacks = 5, tradeoff = false, value = "+3% 概率",
      apply = function(stacks) BALL_TUNING.splitBonus = BALL_TUNING.splitBonus + 0.03 end },
    { id = "speed", name = "疾速引擎", desc = "弹珠飞行速度 +8%",
      detail = "全部弹珠飞行速度提高 8%，往返更快、单位时间命中更多，但更难瞄准。",
      weight = 1, rarity = "common", maxStacks = 6, tradeoff = false, value = "+8% 速度",
      apply = function(stacks) BALL_TUNING.speedMul = BALL_TUNING.speedMul * 1.08 end },
    { id = "ice", name = "深寒涂层", desc = "冰冻时长 +1.2 秒",
      detail = "冰冻弹命中的敌机冻结时间延长 1.2 秒，更长时间迟滞其推进。",
      weight = 1, rarity = "common", maxStacks = 5, tradeoff = false, value = "+1.2 秒",
      apply = function(stacks) BALL_TUNING.iceBonus = BALL_TUNING.iceBonus + 1.2 end },
    { id = "repair", name = "前线维修", desc = "立即恢复 25 点基地生命",
      detail = "立即修复基地 25 点生命（不会超过 100 点上限），可反复选择。",
      weight = 1, rarity = "common", maxStacks = 99, tradeoff = false, value = "+25 HP",
      apply = function(stacks) baseHp = math.min(BASE_HP, baseHp + 25) end },
    { id = "armor", name = "装甲强化", desc = "防线受创伤害 -1（最低 1）",
      detail = "敌机编队越过防线时，整次受创伤害降低 1 点；多行越线时也只在总计上减免。",
      weight = 1, rarity = "common", maxStacks = 2, tradeoff = false, value = "-1 受创",
      apply = function(stacks) BALL_TUNING.lineDamageBonus = BALL_TUNING.lineDamageBonus - 1 end },
    { id = "xp", name = "数据回收", desc = "经验获取 +20%",
      detail = "击碎砖块与清空编队获得的经验提高 20%，更频繁触发三选一升级。",
      weight = 1, rarity = "common", maxStacks = 5, tradeoff = false, value = "+20% 经验",
      apply = function(stacks) BALL_TUNING.xpMul = BALL_TUNING.xpMul + 0.2 end },
    -- WO-09/P5 抉择型：同时改正负规则变量，高风险高回报（仍只改 BALL_TUNING/baseHp）。
    { id = "glass_cannon", name = "玻璃巨炮", desc = "伤害 +2 但越线伤害 +1",
      detail = "所有弹珠伤害 +2，输出显著提升；代价是敌机越线时防线每次多受 1 点伤害。",
      weight = 0.6, rarity = "rare", maxStacks = 3, tradeoff = true, value = "伤害+2 / 受创+1",
      apply = function(stacks)
          BALL_TUNING.damageBonus = BALL_TUNING.damageBonus + 2
          BALL_TUNING.lineDamageBonus = BALL_TUNING.lineDamageBonus + 1
      end },
    { id = "overclock", name = "超载核心", desc = "速度 +15% 但基地 -8",
      detail = "弹珠飞行速度立即提高 15%，但引擎过载直接损失 8 点基地生命。",
      weight = 0.6, rarity = "rare", maxStacks = 3, tradeoff = true, value = "速度+15% / HP-8",
      apply = function(stacks)
          BALL_TUNING.speedMul = BALL_TUNING.speedMul * 1.15
          baseHp = math.max(1, baseHp - 8)
      end },
    -- P11 词条系统：专属"词条"升级，apply 把对应 word 加入 activeWords（规则变量），
    -- 新生成弹珠自动携带；视觉染色推迟到表现层消费新事件。
    { id = "word_pierce", name = "贯穿弹芯", desc = "弹珠附带[贯穿]词条",
      detail = "之后生成的弹珠附带[贯穿]：命中首块砖块附加电击并直线穿透，不被反弹。一次性。",
      weight = 0.5, rarity = "rare", maxStacks = 1, tradeoff = false, value = "词条·贯穿", kind = "word",
      apply = function(stacks) activeWords.pierce = true end },
    { id = "word_chain", name = "链能线圈", desc = "弹珠附带[连锁]词条",
      detail = "之后生成的弹珠附带[连锁]：腐蚀命中砖块，并向最近的另一块追加一次溅射。一次性。",
      weight = 0.5, rarity = "rare", maxStacks = 1, tradeoff = false, value = "词条·连锁", kind = "word",
      apply = function(stacks) activeWords.chain = true end },
    { id = "word_momentum", name = "动量储能", desc = "弹珠附带[动量]词条",
      detail = "之后生成的弹珠附带[动量]：命中附加燃烧，弹珠速度越高造成的伤害越高。一次性。",
      weight = 0.5, rarity = "rare", maxStacks = 1, tradeoff = false, value = "词条·动量", kind = "word",
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
-- v0.10.15：全屏起手时记录手指按下点，拉弓量 = 当前点 - 按下点。
local grabStartX = SLING_X
local grabStartY = SLING_Y
-- v0.10.24：菜单/结算改为松手确认开始；只有按下时本就处于菜单/结算态才武装，
-- 避免死亡瞬间手指还按着、抬手即误重开。
local startArmed = false

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
    -- v0.10.28：前三波固定 3 机，保证 8bit 阵型从开局可读。
    local count
    if waveNum <= 3 then count = 3
    elseif waveNum <= 6 then count = 4
    else count = math.min(5, 3 + math.floor((waveNum - 4) / 3)) end

    -- 敌方砖块保留隐藏 HP：前六波只需一次命中，之后再逐步增加耐久。
    -- v0.10.27：首波基础速度从 18 提到 28，入场不再贴着屏顶蠕动。
    local speed = 28 + (waveNum - 1) * 4
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
    startArmed = false
    aimX = SLING_X
    aimY = SLING_Y
    grabStartX = SLING_X
    grabStartY = SLING_Y
    waveCooldown = 3.2    -- v0.10.27：开局喘息再拉长，避免首波贴脸
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
    BALL_TUNING.lineDamageBonus = 0
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

-- 编队间距与全场 AABB 防重叠：生成候选和逐帧分离共用同一套判定，
-- 必须对“本批次已放置 + 场上仍存活”的所有飞机生效，禁止只检查其中一边。
local ENEMY_SPACING = 8

local function EnemyAABB(enemy)
    return enemy.x, enemy.y,
        enemy.gridW * enemy.brickSize, enemy.gridH * enemy.brickSize
end

local function RectsOverlap(x, y, w, h, ox, oy, ow, oh, gap)
    gap = gap or ENEMY_SPACING
    return x < ox + ow + gap and x + w + gap > ox
        and y < oy + oh + gap and y + h + gap > oy
end

-- 候选矩形是否与本批次 placed 或场上存活飞机（ignore 可排除自身）重叠。
local function FleetPositionOccupied(x, y, w, h, placed, ignore)
    for _, item in ipairs(placed) do
        if RectsOverlap(x, y, w, h, item.x, item.y, item.w, item.h) then
            return true
        end
    end
    for _, other in ipairs(veggies) do
        if other ~= ignore and not other.dead then
            local ow, oh = other.gridW * other.brickSize, other.gridH * other.brickSize
            if RectsOverlap(x, y, w, h, other.x, other.y, ow, oh) then
                return true
            end
        end
    end
    return false
end

-- v0.10.20：8 种敌机按波次门槛逐步解锁（顺序即难度曲线）。
-- 蜂群 hive 可更早出现形成数量压力；重型/精英靠后；interceptor 仍是精英与 Boss。
local WAVE_ROSTER = {
    { key = "scout",       minWave = 1 },
    { key = "dart",        minWave = 2 },
    { key = "striker",     minWave = 3 },
    { key = "hive",        minWave = 4 },
    { key = "manta",       minWave = 5 },
    { key = "bomber",      minWave = 7 },
    { key = "cruiser",     minWave = 8 },
    { key = "interceptor", minWave = 9 },
}

local function GetAvailableTypes(waveNum)
    local keys = {}
    for _, entry in ipairs(WAVE_ROSTER) do
        if waveNum >= entry.minWave and AircraftData[entry.key] then
            table.insert(keys, entry.key)
        end
    end
    return keys
end

local function CreateEnemy(aircraftKey, x, y, brickSize, brickHp, baseSpeed, opts)
    local data = AircraftData[aircraftKey]
    if not data then
        print("[Game] ERROR: no aircraft data for " .. tostring(aircraftKey))
        return nil
    end

    -- A3：行为分化——读取该型性格参数，使不同飞机横摆/节奏/下压感各异。
    -- 同波阵型可锁定 sway，避免各自乱摆把阵型拆散。
    local beh = AircraftData.behavior and AircraftData.behavior[aircraftKey]
        or { swayAmp = 18, swayFreq = 0.4, descentMul = 1.0, agility = 0.8 }
    local swayAmp = beh.swayAmp + Random() * beh.swayAmp * 0.3
    local swayFreq = beh.swayFreq * (0.85 + Random() * 0.3)
    local descent = beh.descentMul
    local spawnPhase = 0
    if opts then
        if opts.swayAmp then swayAmp = opts.swayAmp end
        if opts.swayFreq then swayFreq = opts.swayFreq end
        if opts.phase then spawnPhase = opts.phase end
    end

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
        -- v0.10.27：全局下落 0.25→0.42，首波入场不再贴着屏顶蠕动。
        vy = baseSpeed * data.speedMul * 0.42 * descent,
        swayAmp = swayAmp,
        swayFreq = swayFreq,
        agility = beh.agility,    -- A3：节奏/反应质感标记（渲染层可读）
        -- 默认 phase=0：首帧位置即 baseX。阵型可传入统一相位，保证同波一起摆。
        phase = spawnPhase,
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
        local bossW, bossH = GetAircraftSize(bossKey, brickSize)
        local bossX = DW * 0.5 - bossW * 0.5
        -- 整机置于屏外（可见顶约 -102）再加余量。
        local bossY = -102 - bossH - 24
        -- Boss 同样从屏外进入，且不允许与场上编队重叠，冲突时整体继续抬高。
        while FleetPositionOccupied(bossX, bossY, bossW, bossH, {}) do
            bossY = bossY - bossH - ENEMY_SPACING
        end
        local enemy = CreateEnemy(bossKey, bossX, bossY, brickSize, bossHp, 14)
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
        Emit("wave_started", {wave = wave, isBoss = true})
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

    -- 候选检查同时覆盖本批次与场上存活飞机，gap 统一使用 ENEMY_SPACING。
    local function Overlaps(candidateX, candidateY, candidateW, candidateH)
        return FleetPositionOccupied(candidateX, candidateY, candidateW, candidateH, placed)
    end

    for i = 1, count do
        local aircraftKey = pool[RandomInt(1, #pool)]
        local aircraftWidth, aircraftHeight = GetAircraftSize(aircraftKey, brickSize)
        -- 所有新编队必须“整机”位于可见战场顶之上的屏外区。
        -- 可见战场顶约 gameY=-102（HUD 下沿投影），故按飞机自身高度上推，
        -- 再留 24px 余量；同波后续飞机继续向上排队，禁止任何像素在屏幕内生成。
        local VISIBLE_TOP_Y = -102
        local SPAWN_ENTRY_Y = VISIBLE_TOP_Y - aircraftHeight - 24
        local baseY = SPAWN_ENTRY_Y - (i - 1) * (aircraftHeight + ENEMY_SPACING)
        local x, y = margin, baseY
        local found = false
        -- 先在同一屏外层做随机横向候选（y 始终是屏外 baseY，禁止落到屏幕内）。
        for _ = 1, 80 do
            local candidateX = margin + Random() * math.max(1, DW - aircraftWidth - margin * 2)
            if not Overlaps(candidateX, baseY, aircraftWidth, aircraftHeight) then
                x, y, found = candidateX, baseY, true
                break
            end
        end
        if not found then
            -- 确定性 fallback：继续向上逐层排开，每层扫描均匀 X 槽，绝不进入可见区。
            local slotSpan = math.max(1, DW - margin * 2 - aircraftWidth)
            local slotCount = math.min(8, math.max(1, math.floor(slotSpan / 40) + 1))
            for layer = 0, 60 do
                local tryY = baseY - (layer + 1) * (aircraftHeight + ENEMY_SPACING)
                for slot = 0, slotCount - 1 do
                    local tryX = margin
                        + (slotCount == 1 and 0
                            or slot * slotSpan / (slotCount - 1))
                    if not Overlaps(tryX, tryY, aircraftWidth, aircraftHeight) then
                        x, y, found = tryX, tryY, true
                        break
                    end
                end
                if found then break end
            end
            if not found then
                y = baseY - 62 * (aircraftHeight + ENEMY_SPACING)
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
-- 边界：相切不算命中；推出 0.5 设计单位避免重复卡碰。
-- v0.10.27：高速球除分子步进，还对本帧位移做线段-AABB 扫掠，避免擦边/对角穿格丢失碰撞。
local function IntersectsBrick(marble, rx, ry, rw, rh)
    local closestX = math.max(rx, math.min(marble.x, rx + rw))
    local closestY = math.max(ry, math.min(marble.y, ry + rh))
    local dx = marble.x - closestX
    local dy = marble.y - closestY
    return dx * dx + dy * dy < marble.radius * marble.radius
end

-- 圆沿 (px,py)→(cx,cy) 扫过膨胀后的砖块 AABB。用于本帧位移漏检。
local function SweptHitsBrick(px, py, cx, cy, radius, rx, ry, rw, rh)
    local minX = rx - radius
    local minY = ry - radius
    local maxX = rx + rw + radius
    local maxY = ry + rh + radius
    if cx >= minX and cx <= maxX and cy >= minY and cy <= maxY then
        return true
    end
    local dx = cx - px
    local dy = cy - py
    local steps = 1
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist > radius * 0.5 then
        steps = math.max(2, math.ceil(dist / math.max(4, radius * 0.45)))
    end
    for s = 1, steps do
        local t = s / steps
        local x = px + dx * t
        local y = py + dy * t
        if x >= minX and x <= maxX and y >= minY and y <= maxY then
            return true
        end
    end
    return false
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

-- 发射单个方块的碎裂视觉事件（火花 + 独立飞散箱体）。不修改存活状态，由调用方负责。
local function EmitBrickShatterFx(enemy, brick, x, y)
    local angle = Random() * math.pi * 2
    -- v0.10.23：降低飞散速度/上抛，避免碎片飞到屏顶长期堆积、与新小粒子抢戏。
    local speed = 120 + Random() * 150
    local lift = 80 + Random() * 90
    Emit("brick_hit", {
        enemyId = enemy.id, aircraftKey = enemy.aircraftKey,
        col = brick.col, row = brick.row, x = x, y = y,
        destroyed = true, score = 0,
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
        lifetime = 0.7 + Random() * 0.4,
        brickSize = enemy.brickSize,
        style = enemy.aircraftKey,
    })
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
    EmitBrickShatterFx(enemy, brick, x, y)
    return true
end

-- 越线碎裂：该行方块脱离编队并播放相同飞散视觉，但不加分、不给经验
-- （它是“突破防线”的惩罚，不是被玩家击碎）。
local function ShatterBreachedBrick(enemy, brick)
    if brick.ejected or not brick.alive then return end
    local x = enemy.x + (brick.col - 0.5) * enemy.brickSize
    local y = enemy.y + (brick.row - 0.5) * enemy.brickSize
    brick.alive = false
    brick.ejected = true
    EmitBrickShatterFx(enemy, brick, x, y)
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
        -- v0.10.24：与 Pause 一致，进入升级面板时取消进行中的拖拽并让待发车归位，
        -- 防止选完强化回到 playing 后残留旧 aiming/grabStart。
        aiming = false
        if activeBall then
            activeBall.x = SLING_X
            activeBall.y = SLING_Y
        end
        gameState = "levelup"
        RollUpgradeChoices()
        Emit("level_up", {level = playerLevel})
        print("[Game] level up -> " .. playerLevel .. ", waiting for upgrade pick")
    end
end

RollUpgradeChoices = function()
    -- WO-09/P5：加权抽卡 + 叠加上限 + 稀有保底 + 同次三选一去重。
    upgradeChoices = {}
    local sinceRare = 0
    local chosenThisRoll = {}
    for _ = 1, 3 do
        local avail = {}
        local totalW = 0
        for _, u in ipairs(UPGRADE_POOL) do
            local stacks = upgradeStacks[u.id] or 0
            if stacks < u.maxStacks and not chosenThisRoll[u.id] then
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
        chosenThisRoll[picked.id] = true
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
            id = c.id, name = c.name, desc = c.desc, detail = c.detail,
            value = c.value, rarity = c.rarity, kind = c.kind or "buff",
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
        -- v0.10.27：按本帧位移自适应子步进，高速弹不再 4 步打穿薄格。
        local move = math.sqrt(marble.vx * marble.vx + marble.vy * marble.vy) * dt
        local steps = math.max(4, math.min(12, math.ceil(move / math.max(6, marble.radius * 0.4))))
        local subDt = dt / steps
        local frameHitBricks = {}

        for _ = 1, steps do
            if not marble.alive then break end

            if marble.redirectCooldown and marble.redirectCooldown > 0 then
                marble.redirectCooldown = marble.redirectCooldown - subDt
            end

            local prevX = marble.x
            local prevY = marble.y
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
            if marble.y - marble.radius < TOP_BOUND_Y then
                marble.y = TOP_BOUND_Y + marble.radius
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
                                    or SweptHitsBrick(prevX, prevY, marble.x, marble.y,
                                        marble.radius, rx, ry, rw, rh)
                                if collided then
                                    marble.x = marble.x + marble.vx * subDt * 0.5
                                    marble.y = marble.y + marble.vy * subDt * 0.5
                                end
                            else
                                collided = CollideBrick(marble, rx, ry, rw, rh)
                                if not collided and SweptHitsBrick(prevX, prevY, marble.x, marble.y,
                                    marble.radius, rx, ry, rw, rh) then
                                    marble.x = prevX
                                    marble.y = prevY
                                    collided = CollideBrick(marble, rx, ry, rw, rh)
                                    if not collided then
                                        -- 扫掠命中但终点已越过：仍结算伤害，避免擦边穿格无反馈。
                                        collided = true
                                    end
                                end
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

            -- 回收线在防线 DANGER_Y（车回落进入底部 Dock 安全层即回库补弹）。
            -- 必须同时满足 vy>0（正在向下运动）：弹弓向下拉、向上发射时出生点可能就在
            -- DANGER_Y 之下（待发位 y≈850、拉满可到 940，巨型车半径 30），若无此条件
            -- 球一发射还没往上走就被判回收，表现为“射不出去”。
            if marble.vy > 0 and marble.y - marble.radius > DANGER_Y then
                marble.alive = false
                break
            end
        end

        if not marble.alive then
            table.remove(marbles, i)
            if marble.isPrimary then
                EnqueueNextBall()
                -- v0.10.24：主球回库补弹，给表现层一个轻量反馈事件。
                Emit("marble_reloaded", {ballType = activeBall and activeBall.ballType or "normal"})
            end
            Emit("marble_removed", {id = marble.id, isPrimary = marble.isPrimary == true})
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

-- 逐帧全机群防重叠：摆动/下移完成后对所有存活飞机做多轮 AABB 迭代求解。
-- 水平穿透：两架对称让位（顶到战场边界的一侧不动，全量推给另一侧）；
-- 垂直穿透：只把更靠上的飞机整体抬高（y 减小），绝不向下挤压导致提前越线扣血。
-- 多轮迭代用于消解 A 推开 B、B 又撞上 C 的链式穿插；最后统一钳制左右边界并回写 baseX。
local FLEET_SOLVE_ITERATIONS = 8
local FLEET_SIDE_MARGIN = 10

local function ClampEnemyX(enemy, width)
    if enemy.x < FLEET_SIDE_MARGIN then
        enemy.x = FLEET_SIDE_MARGIN
    elseif enemy.x + width > DW - FLEET_SIDE_MARGIN then
        enemy.x = DW - FLEET_SIDE_MARGIN - width
    end
end

local function ResolveFleetOverlaps()
    local count = #veggies
    if count < 2 then
        for i = 1, count do
            local a = veggies[i]
            if not a.dead then
                ClampEnemyX(a, a.gridW * a.brickSize)
                a.baseX = a.x - math.sin(a.phase) * a.swayAmp
            end
        end
        return
    end

    for _ = 1, FLEET_SOLVE_ITERATIONS do
        for i = 1, count do ClampEnemyX(veggies[i], veggies[i].gridW * veggies[i].brickSize) end
        for i = 1, count - 1 do
            local a = veggies[i]
            if not a.dead then
                local ax, ay, aw, ah = EnemyAABB(a)
                for j = i + 1, count do
                    local b = veggies[j]
                    if not b.dead then
                        local bx, by, bw, bh = EnemyAABB(b)
                        -- 纵向已由生成排序保证至少间隔 ENEMY_SPACING；只在纵向真正重叠时
                        -- 才允许横向让位，避免临界浮点（overlapY≈0）误判把新机瞬间横推（“回撤”）。
                        local overlapX = math.min(ax + aw + ENEMY_SPACING, bx + bw + ENEMY_SPACING)
                            - math.max(ax - ENEMY_SPACING, bx - ENEMY_SPACING)
                        local overlapY = math.min(ay + ah + ENEMY_SPACING, by + bh + ENEMY_SPACING)
                            - math.max(ay - ENEMY_SPACING, by - ENEMY_SPACING)
                        if overlapX > 1.0 and overlapY > 1.0 then
                            -- 只要有一方还在可见战场顶（-102）之上，优先纵向把靠上的继续抬高，
                            -- 避免新机进场时被对称横推造成“突然横向回撤”。
                            local aOffscreen = ay + ah < -102
                            local bOffscreen = by + bh < -102
                            if aOffscreen or bOffscreen then
                                if ay <= by then
                                    a.y = by - ah - ENEMY_SPACING
                                else
                                    b.y = ay - bh - ENEMY_SPACING
                                end
                            elseif overlapX <= overlapY then
                                local aBlocked = ax <= FLEET_SIDE_MARGIN + 0.01
                                local bBlocked = bx + bw >= DW - FLEET_SIDE_MARGIN - 0.01
                                if aBlocked and not bBlocked then
                                    b.x = b.x + overlapX
                                elseif bBlocked and not aBlocked then
                                    a.x = a.x - overlapX
                                else
                                    a.x = a.x - overlapX * 0.5
                                    b.x = b.x + overlapX * 0.5
                                end
                            elseif ay <= by then
                                a.y = by - ah - ENEMY_SPACING
                            else
                                b.y = ay - bh - ENEMY_SPACING
                            end
                        end
                        ax, ay, aw, ah = EnemyAABB(a)
                    end
                end
            end
        end
    end

    for i = 1, count do
        local enemy = veggies[i]
        if not enemy.dead then
            ClampEnemyX(enemy, enemy.gridW * enemy.brickSize)
            -- 分离后的实际 x 回写为摆动中心，避免下一帧 sin(phase) 变化又把飞机拉回重叠位。
            enemy.baseX = enemy.x - math.sin(enemy.phase) * enemy.swayAmp
        end
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
                -- 阶段切换：phase 1 普通；phase 2 加速下移；phase 3 狂暴（视觉标记，越线伤害按行结算）。
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
    end

    -- 所有编队本帧摆动/下移完成后统一做多轮 AABB 分离，避免逐机单轮求解漏判。
    ResolveFleetOverlaps()

    -- 第二趟：在最终位置上做越线判定（按行）、碎裂、清空与移除。
    -- 本帧所有越线行先收集并逐块碎裂，扣血在整体合计后只结算一次。
    local breachedRows = {}
    for i = #veggies, 1, -1 do
        if gameState == "gameover" then break end
        local enemy = veggies[i]

        -- 越线判定按“行”分组：同一架飞机里越过目标线的方块按 brick.row 归组。
        local rows = {}
        for _, brick in ipairs(enemy.bricks) do
            if brick.alive then
                local brickBottom = enemy.y + brick.row * enemy.brickSize
                if brickBottom > DANGER_Y then
                    local list = rows[brick.row]
                    if not list then list = {}; rows[brick.row] = list end
                    list[#list + 1] = brick
                end
            end
        end

        for row, list in pairs(rows) do
            -- 该行方块全部碎裂（独立飞散箱体），视觉反馈取该行中心。
            local sumX = 0
            for _, brick in ipairs(list) do
                ShatterBreachedBrick(enemy, brick)
                sumX = sumX + enemy.x + (brick.col - 0.5) * enemy.brickSize
            end
            local rowCenterX = sumX / #list
            local rowY = enemy.y + (row - 0.5) * enemy.brickSize
            breachedRows[#breachedRows + 1] = {x = rowCenterX, y = DANGER_Y, rowY = rowY}
        end
    end

    -- 每行基础伤害 0.5 向上取整（=每行 1）；加成只在整体合计后附加一次，最终不低于 1。
    if #breachedRows > 0 and gameState ~= "gameover" then
        local baseDamage = math.ceil(#breachedRows * BRICK_BASE_DAMAGE)
        local totalDamage = math.max(1, baseDamage + BALL_TUNING.lineDamageBonus)
        baseHp = baseHp - totalDamage
        -- 防线反馈：一条聚合事件（震屏/冲击波/飘字），碎裂方块的飞箱由各自事件呈现。
        local focus = breachedRows[1]
        Emit("base_hit", {x = focus.x, y = DANGER_Y, brick = true, damage = totalDamage, rows = #breachedRows})
        if baseHp <= 0 then
            baseHp = 0
            gameState = "gameover"
            if score > highScore then highScore = score end
            Emit("game_over", {score = score, highScore = highScore, wave = wave})
            print("[Game] game over, score=" .. score .. ", wave=" .. wave)
        end
    end

    -- 清空与移除：越线碎裂后整架飞机的砖块都没了则视为被突破清空（不加分）。
    for i = #veggies, 1, -1 do
        local enemy = veggies[i]
        local width = enemy.gridW * enemy.brickSize
        local height = enemy.gridH * enemy.brickSize
        if gameState == "gameover" then
            enemy.dead = true
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

    -- 动态同屏上限：每 10 波 +1（v0.10.10 基数下调到 8，节奏更松）。
    local concurrentCap = BALANCE.maxConcurrent + math.floor(wave / 10)

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

-- v0.10.15：全屏起手的相对拖拽。pull 为手指相对按下点的位移（不再相对固定弹弓点），
-- 车辆视觉锚定 SLING 附近，手指在屏幕任意位置起手都不会遮挡车辆。
-- 向下位移单独钳制，避免拉弓时车辆被拖出屏幕底部 Dock。
local PULL_MAX_DOWN_DY = DH - SLING_Y - 20
local function ClampPull(dx, dy)
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance > MAX_PULL then
        dx = dx / distance * MAX_PULL
        dy = dy / distance * MAX_PULL
    end
    if dy > PULL_MAX_DOWN_DY then dy = PULL_MAX_DOWN_DY end
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
        -- v0.10.24：仅武装，松手才真正开始，给结算画面留出阅读时间、防误触。
        startArmed = true
        return
    end
    startArmed = false
    -- v0.10.24：移动端无键盘，暂停态点按任意处恢复（桌面端仍可用 P/ESC）。
    if gameState == "paused" then
        Game.Resume()
        return
    end
    if gameState ~= "playing" then return end

    -- 只有待发车辆时才能起手拖拽；空仓时车辆会自然回落补弹，无需召回。
    if not activeBall then return end

    -- 全屏任意位置起手：记录按下点，拉弓量按相对位移计算，
    -- 车辆只在弹弓点附近移动，手指不再遮挡车辆。
    aiming = true
    grabStartX = px
    grabStartY = py
    aimX = SLING_X
    aimY = SLING_Y
end

function Game.PointerMove(px, py)
    if not aiming then return end
    local dx, dy = ClampPull(px - grabStartX, py - grabStartY)
    aimX = SLING_X + dx
    aimY = SLING_Y + dy
end

function Game.PointerUp(px, py)
    -- v0.10.24：菜单/结算在松手确认时才开局。
    if gameState == "menu" or gameState == "gameover" then
        if startArmed then
            startArmed = false
            StartGame()
        end
        return
    end
    startArmed = false
    if not aiming then return end
    local dx, dy, distance = ClampPull(px - grabStartX, py - grabStartY)
    aiming = false
    if distance <= 15 then
        -- 死区内松手：待发车辆归位，不发射。
        if activeBall then
            activeBall.x = SLING_X
            activeBall.y = SLING_Y
        end
        return
    end
    if activeBall then
        LaunchMarble(dx, dy, distance / BALANCE.maxPull)
    end
end

function Game.HandleAction(action, pressed)
    if pressed and action == "start" and (gameState == "menu" or gameState == "gameover") then
        StartGame()
    end
end

function Game.Pause()
    if gameState == "playing" then
        -- v0.10.24：暂停时取消进行中的拖拽并让待发车归位，
        -- 避免恢复瞬间带着旧蓄力/残留 aiming 状态。
        aiming = false
        if activeBall then
            activeBall.x = SLING_X
            activeBall.y = SLING_Y
        end
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

-- v0.10.19：瞄准直线。仅在拖拽蓄力超过 15px 死区时返回起点+到最近玩法边界的终点；
-- 方向与 LaunchMarble 完全一致（-pull 归一化）。只算一条直线，不做反弹预测。
local AIM_DEAD_ZONE = 15
local function ComputeAimLine()
    if not (aiming and activeBall) then return nil end
    local pullX = aimX - SLING_X
    local pullY = aimY - SLING_Y
    local length = math.sqrt(pullX * pullX + pullY * pullY)
    if length <= AIM_DEAD_ZONE then return nil end
    local dirX = -pullX / length
    local dirY = -pullY / length
    local radius = activeBall.radius or 0
    local x0, y0 = activeBall.x, activeBall.y

    -- 求射线与左/右/顶三边的最近正参数 t（发射向上，底边不参与）。
    local t = math.huge
    if dirX < -0.0001 then
        t = math.min(t, (radius - x0) / dirX)
    elseif dirX > 0.0001 then
        t = math.min(t, (DW - radius - x0) / dirX)
    end
    if dirY < -0.0001 then
        t = math.min(t, (TOP_BOUND_Y + radius - y0) / dirY)
    end
    if t == math.huge or t <= 0 then return nil end
    -- v0.10.23：输出归一化蓄力 (死区→满拉 映射到 0..1)，供渲染层做弱拉渐显。
    local power01 = math.max(0, math.min(1, (length - AIM_DEAD_ZONE) / (MAX_PULL - AIM_DEAD_ZONE)))
    return {
        x1 = x0, y1 = y0,
        x2 = x0 + dirX * t, y2 = y0 + dirY * t,
        power = power01,
    }
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
    s.brickDmg = math.max(1, math.ceil(BRICK_BASE_DAMAGE) + BALL_TUNING.lineDamageBonus)
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
    -- v0.10.19：拖拽蓄力超过死区时输出一条直瞄线（规则层算到最近玩法边界的交点），
    -- 3D 后端只负责画，不做反弹预测。
    s.aimLine = ComputeAimLine()
    s.ballQueue = ballQueue
    s.ballOrder = BALL_ORDER
    s.width = DW
    s.height = DH
    s.dangerY = DANGER_Y
    s.topBound = TOP_BOUND_Y
    return s
end

return Game
