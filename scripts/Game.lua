-- Game.lua
-- 货车大战飞机核心玩法。只维护规则、碰撞和权威状态，不依赖任何渲染 API。

local AircraftData = require "AircraftPixelData"
local StageCatalog = require "StageCatalog"
local TalentCatalog = require "TalentCatalog"
local EnchantCatalog = require "EnchantCatalog"

local Game = {}
-- 空手长按只缩放战斗模拟，不改变表现时钟；收表避免增加主块 local 槽位。
Game._holdSpeed = { down = false, active = false, time = 0, threshold = 0.35, epoch = 0 }
-- v0.13.58：局内附魔卡状态（收进一张表，不新增顶层 local，AB-166）。
--   card    = 当前持有的附魔卡（EnchantDef），nil 表示空手
--   pending = 已使用但当前没有待发车时，顺延给「下一个预备发射的车」的附魔卡
--   lastWave= 最近一次发放附魔卡时的波号（用于「每完成一波发一张」判定）
Game._enchant = { card = nil, pending = nil, lastWave = 0 }

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
-- v0.11.0 商业化：局内「零件」产出（软货币），结算时由编排层写入 PlayerData。
local PARTS_PER_BRICK = 1          -- 击碎一个方块
local PARTS_PER_CLEAR = 10         -- 清掉整支编队
local PARTS_PER_WAVE = 25          -- 每推进一波
local BASE_XP_TO_NEXT = 26         -- 第一次升级所需经验（单架侦察机约 50 格，约两架升一级）

-- 数值平衡表（WO-01/P1）：局内不可变数值集中管理，便于调参与离线模拟。
-- 旧常量名仍作为本表的初始化来源，保持向后可读别名。
local BALANCE = {
    baseHp = BASE_HP,
    brickBaseDamage = BRICK_BASE_DAMAGE,
    xpPerBrick = XP_PER_BRICK,
    xpPerClear = XP_PER_CLEAR,
    baseXpToNext = BASE_XP_TO_NEXT,
    xpToNextGrowth = 1.26,          -- WO-02/P1：每级经验阈值指数乘子
    clearStreakBonusCap = 5,
    maxPull = MAX_PULL,
    powerMin = 0.35,   -- 最小蓄力初速比例（轻拖也有基础射程）
    powerMax = 1.0,    -- 满蓄力初速比例
}

local BALL_TYPES = {
    normal = {
        radius = 20, speed = 560, damage = 1,
        splitChance = 0.05, splitAngle = 18, splitSpread = 18,
        maxConcurrent = 15,       -- 待发 + 飞行 + 本帧待加入的分裂车总上限；库存队列不占名额
        bounceElasticity = 1.0,    -- WO-05/P4：反弹弹性，1.0 为标准
    },
    speed = {
        radius = 18, speed = 660, damage = 1,
        speedBoost = 1.06,
        -- v0.13.22：**去掉速度上限**（原 maxSpeed=900 封顶）——速度无限增长，不封顶。
        -- v0.13.23：加**软性递减**——速度越高，每次加速的倍率越接近 1.0（但仍 >1，永远在涨），
        -- 避免后期滚雪球失控；`speedBoostFloor` 是衰减下限（再快也至少按这个倍率涨）。
        speedBoostFloor = 1.012,
        speedSoftCap = 1400,       -- 达到此速度时加速倍率降到下限
        damageStep = 320,
        -- v0.13.22：**去掉伤害封顶**（原 maxDamage=2）——伤害按速度分档无限增长。
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
        areaCooldown = 1.0,       -- 范围伤害内置冷却（秒），每辆巨型车独立计时
        bounceElasticity = 0.92,   -- WO-05/P4：巨型弹更"沉"
    },
}
local BALL_ORDER = { "normal", "ice", "speed", "giant" }
-- v0.13.19：初始车从分裂车改为**加速车**（用户指定「基础的车改为加速车」）。
-- 其余三车（分裂/冰冻/巨型）仍靠局内升级卡「解锁××车」进入本局队列。
local STARTING_BALL_TYPE = "speed"
-- 开局装载的车辆总数（1 辆待发 + ammoCapacity-1 辆备弹）。
-- v0.12.15：开局 3 辆 → 1 辆（只有待发，没有备弹）；「弹药扩容」通用升级每级 +1（最多三级）。
-- 补弹按「回收一辆补一辆」维持这个总量（主球回收时 EnqueueNextBall）。
local BASE_AMMO_TOTAL = 1
local ammoCapacity = BASE_AMMO_TOTAL
local unlockedBalls = { [STARTING_BALL_TYPE] = true }

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
    -- 越线整体伤害净加成：在“越线行数 × ceil(0.5)”合计后一次性附加（玻璃大炮 +1）。
    lineDamageBonus = 0,
    -- v0.13.28 通用卡重做：装甲强化的百分比减伤（0..0.45，结算时四舍五入并保证最低 1）。
    armorReduce = 0,
    -- v0.13.28 通用卡重做：装甲强化的零件产出倍率（1 + 0.08/级）。
    partsMul = 1.0,
    -- v0.13.28 通用卡重做：玻璃巨炮的发射初速倍率（1 + 0.10/级）。
    launchSpeedMul = 1.0,
    -- v0.13.28 通用卡重做：穿甲弹头每击碎一块的额外经验（+1/级）。
    brickXpFlat = 0,
    xpMul = 1.0,
    -- v0.13.55 车型「专属卡」机制维度（与基础卡区分）：
    --   基础卡只给该车主属性的打底数值，专属卡改机制、不是更大的数字。
    -- 分裂：单次分裂产出的弹珠数（基础 2 颗；裂变核每级 +1）。
    splitCount = 2,
    -- 冰冻：对「冻结中」敌机的受击伤害加成（0..0.9，霜裂涂层每级 +0.3）。
    iceShatter = 0,
    -- 加速：每次飞行的穿透次数（动能穿刺每级 +1），穿透时不反弹、连续吃块。
    speedPierce = 0,
    -- 巨型：范围击碎的暴击率（0..0.45，冲击波每级 +0.15），暴击伤害 ×2。
    giantCritChance = 0,
}

local gameState = "menu"
local score = 0
local highScore = 0
local baseHp = BASE_HP
local baseShield = 0               -- 局内护盾吸收值（道具槽「护盾」提供）
local ResetItems                   -- 前向声明：ResetGame 里要调用；后定义会退化成全局查找
-- v0.13.13：局外道具库存拉取函数（编排层注册）。⚠️ 必须在 ResetGame 之前声明——
-- ResetGame 开局就调用它，后置声明会退化成全局 nil（AB-100 同族）。
---@type fun(): table<string, integer>|nil
local itemStockProvider = nil
local wave = 1
local stage = 1
local stageWave = 1
local bossDefeated = false
---@type {stage:integer, stars:integer, rating:string, bonusScore:integer, bonusParts:integer, animAt:integer}|nil
local stageResult = nil   -- stagewin 态展示与存档用（星级/评级/过渡起始时刻）
local elapsed = 0
local waveCooldown = 0
-- v0.13.26：同波错峰生成状态（剩余架数/下次计时/本波机型与砖块参数）。
-- ⚠️ 收进一张表：Game.lua 顶层 local 已逼近 Lua 200 上限（AB-154 同族），禁止再加散装顶层 local。
local pendingSpawn = { remaining = 0, timer = 0, key = nil, brickSize = 0, hp = 1, speed = 0, kind = nil, lane = 0, spawned = 0 }
local INTRO_SECONDS = 3.0
-- v0.13.24：进关准备期（秒）。>0 时玩法冻结：不推进弹珠/敌机/波次，只放行表现层动画。
local introTimer = 0
-- 本局是否成功发射过弹珠。用于「新手下拉手势提示」：玩家还没做过任何操作时循环播放。
local hasLaunched = false
---@type NextWavePlan|nil
local nextWavePlan = nil

-- 幸存者成长状态
local playerLevel = 1
local xp = 0
local xpToNext = BASE_XP_TO_NEXT
local pendingLevelUps = 0          -- 待处理的升级次数（暂停选强化）
local deferredXp = 0               -- 升级触发同帧后续击碎经验原值，完成选卡后结算
---@type UpgradeDef[]|nil
local upgradeChoices = nil         -- 当前可选的三张升级候选
local upgradePicks = {}            -- 已选强化的累计效果（id 列表，可重复）
local upgradeStacks = {}           -- 已选强化各 id 的层数（WO-09/P5 叠加上限判定）
-- P11：已激活词条（来自专属词条升级），作为新弹珠的默认词条第。规则层持有，渲染层只读快照。
local activeWords = {}
local clearStreak = 0              -- 连续清空飞船的连击（经验加成）
local bricksBroken = 0            -- 累计击碎砖块数（WO-11/P8 gameover 回顾）
local previousHighScore = 0      -- 本局开局时的最高纪录（新纪录提示仅与此基准比较）

-- v0.11.0 商业化：局内零件产出与升级面板变现状态（均为单局生命周期）。
local partsEarned = 0              -- 本局累计获得的「零件」，结算时由编排层入库
local runAircraft = {}             -- 本局清掉过的机型和唯一列表（结算时解锁图鉴）
local partsSettled = false         -- 当前战斗阶段零件是否已入库
local partsDoubled = false         -- 本局是否已用广告翻倍（每局一次）
local lastSettledParts = 0         -- 最近一次结算实际入库数
local settledParts = 0             -- 已按基础倍率入库的累计零件（复活后只补增量）
-- 结算账本（v0.14.x 存钱罐）：bricks=已计入跨局统计的击碎数；runCounted=本局是否已计完成；
-- gear=本局累计「齿轮」（200 块 / 100 齿轮，精英机每块按 2 倍计）；gearSettled=已入库齿轮（复活后只补增量）。
local settleBook = { bricks = 0, runCounted = false, gear = 0, gearSettled = 0 }
local upgradeRerollFreeUsed = false -- 每局 1 次免费重抽
local heldUpgradeId = nil          -- 本局保留到下一次升级的候选卡 id（最多一张）
local PANEL_CARD_COUNT = 3         -- 常规候选数（v0.12.5 精简：面板不再有解锁第 4 张）
-- 暂停补给站（看广告，单局限量）
local pauseHealUsed = 0            -- 已用「防线急救」次数
local pauseRareUsed = 0            -- 已用「下次强化保底稀有」次数
local pendingRareRoll = false      -- 下次抽卡强制稀有（由暂停补给站购买）
-- v0.13.58：暂停补给站的常量收进一张表（Game.lua 顶层 local 逼近 Lua 200 上限，AB-166）。
local PAUSE_SUPPLY = { healMax = 1, healAmount = 25, rareMax = 1 }
local EjectBrick
-- v0.13.58：附魔挂载函数——CreateMarble（约 500 行）先于其定义使用，必须前向声明（AB-100）。
local ApplyEnchantToMarble
local pauseOrbitalUsed = false
local pauseReloadUsed = false
local pausePartsBoostUsed = false
local partsBoostTime = 0

-- 幸存者升级强化池（WO-09/P5）：
-- weight 抽卡权重；rarity 稀有度（common/rare/epic）；maxStacks 叠加上限；
-- tradeoff 是否抉择型（apply 同时改正负）；value 单次增量（用于升级卡 delta 预览）。
-- apply(stacks) 接收当前已选层数，支持边际递减（如 damage 每层略减）。
-- apply() 只改 BALL_TUNING / baseHp（规则层），UI 只读 GetSnapshot().upgradeChoices。
-- detail 为天赋卡详情描述（自动换行展示）；value 是单次增量徽标；tradeoff=抉择型风险。
---@class UpgradeDef
---@field id string
---@field name string
---@field desc string
---@field detail string
---@field weight number
---@field rarity string
---@field maxStacks integer
---@field tradeoff boolean
---@field value string
---@field kind string|nil
---@field ballType string|nil 仅对应车型可用的强化
---@field unlockBallType string|nil 未解锁时才进入卡池的车型解锁卡
---@field requiresCard string|nil 需天赋树解锁的通用卡 id（xp/ammo）；未解锁不进卡池
---@field kind string|nil "base"=车解锁即可抽的基础卡；其余带 ballType 的为「专属卡」，需 ballCard 节点
---@field apply fun(stacks: integer)

local UnlockBallType -- 解锁卡先于补弹函数声明，应用时再调用规则层函数
local IncreaseAmmo   -- 「弹药扩容」同上：卡池先定义，apply 时再调用规则层函数
-- v0.13.28：repair 卡的 apply 闭包会读生命上限；该函数定义在卡池之后，
-- 必须前向声明，否则闭包解析成全局 nil（AB-100 同族）。
local GetMaxBaseHp

-- v0.13.5 天赋树派生状态：必须在 UPGRADE_POOL 之前声明——repair 卡的 apply 闭包会读血量加成。
---@type table<string, boolean>
local talentOwned = {}
local talentMaxHpBonus = 0     -- 已解锁节点数 × 每节点血量加成
local talentPartsPct = 0       -- 结算零件百分比加成（来自通用线路非卡节点）
local talentBallStats = {}     -- 车线路数值增强：ballType -> {stat, value, mul}
local talentUnlockedCards = {} -- 天赋解锁的通用卡 id 集合（xp / ammo）
local talentUnlockedBalls = {} -- 天赋解锁的车（局内出场资格）
-- v0.13.16：天赋解锁的「专属卡」资格（ballCard 节点，按车型）。
-- ⚠️ 之前这个节点只存在于目录里、规则层从未消费 → 专属卡只要车解锁就能抽，
-- 天赋树的「解锁专属卡」节点是装饰。现在专属卡必须**先解锁该节点**才进池。
local talentUnlockedBallCards = {}
-- v0.13.15：成长线天赋——暴击率（0..1）与基础攻击加成。
local talentCritChance = 0
local talentAtkBonus = 0
---@type fun(): table<string, boolean>|nil
local talentProvider = nil     -- 编排层注入；ResetGame 时拉取最新解锁集合

---@type UpgradeDef[]
local UPGRADE_POOL = {
    -- v0.13.28 通用卡重做（用户点名「常驻通用卡在关1 毫无帮助」）：
    -- 旧 damage「伤害 +1」在关1~3（砖块 1 血）是纯溢出、repair/armor 在几乎不掉血的前期空转。
    -- 四张卡改为挂在**低难度也真实存在的变量**上：经验 / 生命上限 / 零件产出 / 发射初速。
    { id = "damage", name = "穿甲弹头", desc = "所有弹珠伤害 +1，击碎额外 +1 经验",
      detail = "弹珠伤害 +1，每击碎一块多 +1 经验。",
      weight = 1, rarity = "common", maxStacks = 8, tradeoff = false, value = "+1 伤害 / +1 经验",
      apply = function(stacks)
          BALL_TUNING.damageBonus = BALL_TUNING.damageBonus + 1
          BALL_TUNING.brickXpFlat = BALL_TUNING.brickXpFlat + 1
      end },
    -- v0.13.55 车型「专属卡」= 改机制；对应的「基础卡」（base_*，见下方）只给主属性打底数值。
    -- 旧版专属卡与基础卡都只改同一个 BALL_TUNING 字段、只是数字更大 → 四条公式各写两遍。
    { id = "giant", name = "冲击波", desc = "范围击碎 15% 概率造成双倍伤害",
      detail = "范围击碎 15% 概率双倍伤害。",
      weight = 0.6, rarity = "rare", maxStacks = 3, tradeoff = false, value = "+15% 范围暴击", ballType = "giant",
      apply = function(stacks) BALL_TUNING.giantCritChance = BALL_TUNING.giantCritChance + 0.15 end },
    { id = "split", name = "裂变核", desc = "分裂时额外产出 1 颗小弹",
      detail = "每次分裂多产 1 颗小弹。",
      weight = 0.6, rarity = "rare", maxStacks = 2, tradeoff = false, value = "+1 分裂数", ballType = "normal",
      apply = function(stacks) BALL_TUNING.splitCount = BALL_TUNING.splitCount + 1 end },
    { id = "speed", name = "动能穿刺", desc = "飞行中可穿透 1 块不反弹",
      detail = "飞行中穿透 1 块继续飞。",
      weight = 0.6, rarity = "rare", maxStacks = 3, tradeoff = false, value = "穿透 +1 块", ballType = "speed",
      apply = function(stacks) BALL_TUNING.speedPierce = BALL_TUNING.speedPierce + 1 end },
    { id = "ice", name = "霜裂涂层", desc = "冻结中的敌机受击伤害 +30%",
      detail = "冻结中的敌机受击 +30%。",
      weight = 0.6, rarity = "rare", maxStacks = 3, tradeoff = false, value = "+30% 碎冰伤害", ballType = "ice",
      apply = function(stacks) BALL_TUNING.iceShatter = BALL_TUNING.iceShatter + 0.30 end },
    -- v0.13.28：改为「生命上限 +12 且立即回 12」——低难度不掉血时也有**永久**收益（不再是空过一轮）。
    { id = "repair", name = "前线维修", desc = "生命上限 +12，并立即回复 12",
      detail = "生命上限永久 +12，立刻回 12 点。",
      weight = 1, rarity = "common", maxStacks = 99, tradeoff = false, value = "+12 上限 / +12 生命",
      apply = function(stacks)
          BALL_TUNING.maxHpBonus = BALL_TUNING.maxHpBonus + 12
          baseHp = math.min(GetMaxBaseHp(), baseHp + 12)
      end },
    -- v0.13.28：改为「百分比减伤 + 零件产出 +8%/级」——关1 单行越线伤害被钳成 1，旧 -1 减伤完全无效；
    -- 百分比减伤在单行也会生效，且零件加成与难度无关、第一关就看得见。
    { id = "armor", name = "装甲强化", desc = "防线受创 -20%，零件产出 +8%",
      detail = "每次受创少 20%，零件 +8%。",
      weight = 1, rarity = "common", maxStacks = 3, tradeoff = false, value = "-20% 受创 / +8% 零件",
      apply = function(stacks)
          BALL_TUNING.armorReduce = BALL_TUNING.armorReduce + 0.20
          BALL_TUNING.partsMul = BALL_TUNING.partsMul + 0.08
      end },
    { id = "xp", name = "数据回收", desc = "经验获取 +20%",
      detail = "经验 +20%，升级更快。",
      weight = 1, rarity = "common", maxStacks = 5, tradeoff = false, value = "+20% 经验",
      requiresCard = "xp",
      apply = function(stacks) BALL_TUNING.xpMul = BALL_TUNING.xpMul + 0.2 end },
    -- WO-09/P5 抉择型：同时改正负规则变量，高风险高回报（仍只改 BALL_TUNING/baseHp）。
    -- v0.13.28：伤害 +2→+3，并追加「发射初速 +10%/级」——低难度砖块 1 血时，伤害溢出但**弹速**立刻有感。
    { id = "glass_cannon", name = "玻璃巨炮", desc = "伤害 +3、弹速 +10%，但越线伤害 +1",
      detail = "伤害 +3、弹速 +10%，但被撞多掉 1 点。",
      weight = 0.6, rarity = "rare", maxStacks = 3, tradeoff = true, value = "伤害+3 / 弹速+10% / 受创+1",
      apply = function(stacks)
          BALL_TUNING.damageBonus = BALL_TUNING.damageBonus + 3
          BALL_TUNING.launchSpeedMul = BALL_TUNING.launchSpeedMul * 1.10
          BALL_TUNING.lineDamageBonus = BALL_TUNING.lineDamageBonus + 1
      end },
    { id = "overclock", name = "超载核心", desc = "加速车加速度 +15%，基地 -8",
      detail = "加速车加速更快，但 -8 生命。",
      weight = 0.6, rarity = "rare", maxStacks = 3, tradeoff = true, value = "加速度+15% / 生命-8", ballType = "speed",
      apply = function(stacks)
          BALL_TUNING.speedMul = BALL_TUNING.speedMul * 1.15
          baseHp = math.max(1, baseHp - 8)
      end },
    -- v0.13.19：四车都能靠局内卡解锁。初始车是加速车（见 STARTING_BALL_TYPE），
    -- 所以「解锁分裂车」也进池；加速车自己已解锁，其解锁卡由 unlockBallType 门控自动退池。
    { id = "unlock_normal", name = "解锁分裂车", desc = "分裂车加入本局弹药队列",
      detail = "解锁分裂车，命中后分裂小弹。",
      weight = 1.4, rarity = "common", maxStacks = 1, tradeoff = false, value = "分裂车入队",
      kind = "unlock", unlockBallType = "normal",
      apply = function(stacks) UnlockBallType("normal") end },
    { id = "unlock_ice", name = "解锁冰冻车", desc = "冰冻车加入本局弹药队列",
      detail = "解锁冰冻车，命中可冻结敌机。",
      weight = 1.4, rarity = "common", maxStacks = 1, tradeoff = false, value = "冰冻车入队",
      kind = "unlock", unlockBallType = "ice",
      apply = function(stacks) UnlockBallType("ice") end },
    { id = "unlock_speed", name = "解锁加速车", desc = "加速车加入本局弹药队列",
      detail = "解锁加速车，反弹后越跑越快。",
      weight = 1.4, rarity = "common", maxStacks = 1, tradeoff = false, value = "加速车入队",
      kind = "unlock", unlockBallType = "speed",
      apply = function(stacks) UnlockBallType("speed") end },
    { id = "unlock_giant", name = "解锁巨型车", desc = "巨型车加入本局弹药队列",
      detail = "解锁巨型车，反弹后范围击碎。",
      weight = 1.4, rarity = "common", maxStacks = 1, tradeoff = false, value = "巨型车入队",
      kind = "unlock", unlockBallType = "giant",
      apply = function(stacks) UnlockBallType("giant") end },
    -- 通用弹药卡：需天赋树解锁（3 阶通用卡节点）后才会进入卡池。
    { id = "ammo", name = "弹药扩容", desc = "本局弹药数量 +1",
      detail = "本局弹药数量 +1。",
      weight = 1, rarity = "common", maxStacks = 3, tradeoff = false, value = "+1 弹药",
      requiresCard = "ammo",
      apply = function(stacks) IncreaseAmmo() end },
    -- v0.13.5 基础天赋池重构：四车各补一张「基础数值」卡（不依赖解锁卡，车解锁即可抽）。
    -- v0.13.55：基础卡 = 该车主属性的**打底数值**（常出、可叠高），机制差异交给上面的专属卡。
    { id = "base_split", name = "分裂增幅", desc = "分裂车分裂概率 +2%",
      detail = "分裂小车概率 +2%。",
      weight = 1, rarity = "common", maxStacks = 5, tradeoff = false, value = "+2% 概率",
      ballType = "normal", kind = "base",
      apply = function(stacks) BALL_TUNING.splitBonus = BALL_TUNING.splitBonus + 0.02 end },
    { id = "base_ice", name = "寒能扩散", desc = "冰冻时长 +0.5 秒",
      detail = "冰冻时间 +0.5 秒。",
      weight = 1, rarity = "common", maxStacks = 5, tradeoff = false, value = "+0.5 秒",
      ballType = "ice", kind = "base",
      apply = function(stacks) BALL_TUNING.iceBonus = BALL_TUNING.iceBonus + 0.5 end },
    { id = "base_speed", name = "引擎调校", desc = "加速车加速度 +4%",
      detail = "加速车加速更快。",
      weight = 1, rarity = "common", maxStacks = 5, tradeoff = false, value = "+4% 加速度",
      ballType = "speed", kind = "base",
      apply = function(stacks) BALL_TUNING.speedMul = BALL_TUNING.speedMul * 1.04 end },
    { id = "base_giant", name = "弹体增重", desc = "巨型车贯穿范围 +0.5 格",
      detail = "巨型车爆炸范围 +0.5 格。",
      weight = 1, rarity = "common", maxStacks = 5, tradeoff = false, value = "+0.5 格",
      ballType = "giant", kind = "base",
      apply = function(stacks) BALL_TUNING.giantArea = BALL_TUNING.giantArea + 0.5 end },
    -- 通用卡（无车型）：全部需天赋树解锁对应节点才进局内卡池。
    -- v0.13.21：词条卡归入通用卡——此前它们无任何门控、开局常驻（用户点名）。
    { id = "word_pierce", name = "贯穿弹芯", desc = "弹珠附带贯穿效果",
      detail = "弹珠穿透第一块继续飞。",
      weight = 0.5, rarity = "rare", maxStacks = 1, tradeoff = false, value = "贯穿",
      kind = "word", requiresCard = "word_pierce",
      apply = function(stacks) activeWords.pierce = true end },
    { id = "word_chain", name = "连锁弹", desc = "弹珠附带连锁溅射",
      detail = "命中后溅射到最近另一块。",
      weight = 0.5, rarity = "rare", maxStacks = 1, tradeoff = false, value = "连锁",
      kind = "word", requiresCard = "word_chain",
      apply = function(stacks) activeWords.chain = true end },
    { id = "word_momentum", name = "动量加速", desc = "弹珠越快伤害越高",
      detail = "弹珠越快，伤害越高。",
      weight = 0.5, rarity = "rare", maxStacks = 1, tradeoff = false, value = "动量",
      kind = "word", requiresCard = "word_momentum",
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
-- v0.10.24 遗留：菜单/结算松手确认的武装标志。v0.13.4 起菜单不再直接开局
-- （改走选关界面），此处仅作死亡瞬间防误触的复位守卫。
local startArmed = false
-- v0.10.32：每局一次广告复活；结算页按钮由编排层消费几何。
local reviveUsed = false
local REVIVE_HP = 50

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
local PlanWave
local EnsureNextWavePlan
-- v0.13.26：同波错峰生成 / 精英护航延迟释放（AB-100 前向引用：声明先于使用点）。
local ReleaseEscortVolley
local SpawnNextNormalEnemy

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
    local currentStageWave = StageCatalog.GetStageWave(waveNum)
    if currentStageWave <= 2 then return 14 end
    if currentStageWave <= 4 then return 15 end
    return BASE_BRICK_SIZE
end

local function GetWaveParams(waveNum)
    local currentStage = StageCatalog.GetStage(waveNum)
    local currentStageWave = StageCatalog.GetStageWave(waveNum)
    return StageCatalog.GetNormalCount(currentStage, currentStageWave),
        StageCatalog.GetBaseSpeed(currentStage, currentStageWave),
        StageCatalog.GetBrickHp(currentStage, "normal")
end

-- 只按存活实例计算名额，不持有跨帧计数器；同帧预生成也立即占预算。
-- 库存队列只有车型键，尚未生成车辆，不计入同时存在数量。
---@param pendingMarbles table[]|nil
---@return integer
function Game._NormalMarbleSlots(pendingMarbles)
    local count = 0
    if activeBall and activeBall.alive and activeBall.ballType == "normal" then
        count = count + 1
    end
    for _, marble in ipairs(marbles) do
        if marble.alive and marble.ballType == "normal" then count = count + 1 end
    end
    for _, marble in ipairs(pendingMarbles or {}) do
        if marble.alive and marble.ballType == "normal" then count = count + 1 end
    end
    return math.max(0, BALL_TYPES.normal.maxConcurrent - count)
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
        flightTime = 0,
        ignoredBrick = nil,
        giantPiercing = false,
        giantPiercePending = false, -- 冷却中只保留反弹资格，不代表已经可以贯穿
        giantAreaCooldown = 0,
        -- v0.13.55 动能穿刺：本弹剩余穿透次数（每次穿透不反弹、直接吃下块）。
        pierceLeft = BALL_TUNING.speedPierce,
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
    -- v0.13.58：优先消费「顺延」的附魔卡（使用附魔卡时没有待发车 → 挂给下一个预备发射的车）。
    if Game._enchant.pending then
        local pendingCard = Game._enchant.pending
        Game._enchant.pending = nil
        ApplyEnchantToMarble(marble, pendingCard)
    end
    return marble
end

local function NextBallType()
    -- 固定顺序轮换，但只产出本局已解锁的车型；即使仅有初始车也始终可补弹。
    for _ = 1, #BALL_ORDER do
        ballCycleIndex = ballCycleIndex % #BALL_ORDER + 1
        local ballType = BALL_ORDER[ballCycleIndex]
        if unlockedBalls[ballType] then return ballType end
    end
    return STARTING_BALL_TYPE
end

local function EnqueueNextBall()
    table.insert(ballQueue, NextBallType())
end

UnlockBallType = function(ballType)
    if not BALL_TYPES[ballType] or unlockedBalls[ballType] then return end
    unlockedBalls[ballType] = true
    -- 把新车放进下一发槽位，不替换待发车，也不修改已在飞行中的车辆。
    table.insert(ballQueue, 1, ballType)
    print("[Game] ball unlocked: " .. ballType .. ", queued=" .. #ballQueue)
end

-- 「弹药扩容」：本局弹药总量 +1，并立刻补一辆进备弹队列；
-- 之后主球回收仍按「回收一辆补一辆」维持新总量。
IncreaseAmmo = function()
    ammoCapacity = ammoCapacity + 1
    EnqueueNextBall()
    print("[Game] ammo capacity -> " .. ammoCapacity)
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
    -- 先放 1 辆待发，再排入 ammoCapacity-1 辆备弹（「弹药扩容」升级会提高总量）。
    activeBall = CreateMarble(NextBallType(), CollectActiveWords())
    for _ = 1, ammoCapacity - 1 do EnqueueNextBall() end
end

local function CanOfferUpgrade(u)
    -- v0.13.16：带 ballType 且非 base 的卡是「专属卡」——必须天赋树解锁了
    -- 该车型的「专属卡」节点才进池（base 卡只需车解锁）。
    local ballOk = (not u.ballType) or unlockedBalls[u.ballType] == true
    if ballOk and u.ballType and u.kind ~= "base" then
        ballOk = talentUnlockedBallCards[u.ballType] == true
    end
    -- v0.13.20：局内「解锁××车」卡**必须天赋树先解锁该车**才进池（用户澄清）。
    -- 即：天赋树解锁车 ≠ 开局能用该车，而是「局内才会出现这张解锁卡」；
    -- 未在天赋树解锁的车，局内既不出它的解锁卡、也不出它的 base/专属卡。
    if ballOk and u.unlockBallType then
        ballOk = talentUnlockedBalls[u.unlockBallType] == true
    end
    return ballOk
        and (not u.unlockBallType or unlockedBalls[u.unlockBallType] ~= true)
        and (not u.requiresCard or talentUnlockedCards[u.requiresCard] == true)
        and (upgradeStacks[u.id] or 0) < u.maxStacks
end

-- v0.13.5：编排层开局前注入天赋树解锁集合；把节点 id 汇总成规则层可用的加成。
-- 幂等：可多次调用（每次重算派生值）。开局前调用一次即可。
---@param owned table<string, boolean>|nil
function Game.SetTalents(owned)
    talentOwned = {}
    talentMaxHpBonus = 0
    talentPartsPct = 0
    talentBallStats = {}
    talentUnlockedCards = {}
    talentUnlockedBalls = {}
    talentUnlockedBallCards = {}
    talentCritChance = 0
    talentAtkBonus = 0
    if type(owned) ~= "table" then return end
    local count = 0
    for id, v in pairs(owned) do
        if v then
            talentOwned[id] = true
            local node = TalentCatalog.GetNode(id)
            if node then
                count = count + 1
                if node.kind == "cardUnlock" then
                    talentUnlockedCards[node.cardId] = true
                elseif node.kind == "ballUnlock" then
                    talentUnlockedBalls[node.ballType] = true
                elseif node.kind == "ballCard" then
                    -- 专属卡资格（按车型）：未解锁该节点则专属卡不进池。
                    talentUnlockedBallCards[node.ballType] = true
                elseif node.kind == "partsPct" then
                    talentPartsPct = talentPartsPct + (node.value or 0)
                elseif node.kind == "stat" then
                    if node.stat == "critChance" then
                        -- 成长线：暴击率累加；每 3 阶还额外给基础攻击。
                        talentCritChance = talentCritChance + (node.value or 0)
                        talentAtkBonus = talentAtkBonus + (node.atkBonus or 0)
                    else
                        local acc = talentBallStats[node.ballType]
                        if not acc then
                            acc = { stat = node.stat, mul = node.mul == true, add = 0, factor = 1.0 }
                            talentBallStats[node.ballType] = acc
                        end
                        if node.mul then acc.factor = acc.factor * (node.value or 1.0)
                        else acc.add = acc.add + (node.value or 0) end
                    end
                end
            end
        end
    end
    talentMaxHpBonus = count * TalentCatalog.MAX_HP_PER_NODE
    local cardCount, ballCount = 0, 0
    for _ in pairs(talentUnlockedCards) do cardCount = cardCount + 1 end
    for _ in pairs(talentUnlockedBalls) do ballCount = ballCount + 1 end
    print(string.format("[Game] talents applied: nodes=%d hpBonus=%d partsPct=%d%% cards=%d balls=%d",
        count, talentMaxHpBonus, talentPartsPct, cardCount, ballCount))
end

-- 本局基地生命上限 = 基础 + 天赋血量加成 + 局内「前线维修」的永久上限加成。
GetMaxBaseHp = function()
    return BASE_HP + talentMaxHpBonus + BALL_TUNING.maxHpBonus
end

-- 供界面读取：当前注入天赋派生出的加成摘要（只读）。
---@return {hpBonus:integer, partsPct:integer, nodeCount:integer}
function Game.GetTalentBonuses()
    local n = 0
    for _ in pairs(talentOwned) do n = n + 1 end
    return {
        hpBonus = talentMaxHpBonus, partsPct = talentPartsPct, nodeCount = n,
        critChance = talentCritChance, atkBonus = talentAtkBonus,
    }
end

-- v0.13.5：编排层注册一次天赋提供者；每次 ResetGame（含选关/下一关/重开）自动重新拉取，
-- 避免在多个开局入口各写一次注入。
---@param provider fun(): table<string, boolean>
function Game.SetTalentProvider(provider)
    talentProvider = provider
end

-- 只取消倍速，不移动待发车；真实发射必须保留拉弓后的出生点。
function Game.CancelHoldSpeed()
    if Game._holdSpeed.active then print("[Game] hold speed -> 1x") end
    Game._holdSpeed.down = false
    Game._holdSpeed.active = false
    Game._holdSpeed.time = 0
    Game._holdSpeed.epoch = Game._holdSpeed.epoch + 1
end

function Game.CancelPointer()
    Game.CancelHoldSpeed()
    aiming = false
    startArmed = false
    if activeBall then
        activeBall.x = SLING_X
        activeBall.y = SLING_Y
    end
end

function Game.CanHoldSpeed()
    return gameState == "playing" and introTimer <= 0 and not aiming and activeBall == nil
end

-- startStage：选关界面挑选的关卡（v0.13.4）。默认 1；wave 换算为全局累计波号，
-- 使每日任务「抵达第 N 波」在后期关卡仍按真实进度计量。
ResetGame = function(startStage)
    Game.CancelPointer()
    startStage = math.max(1, math.floor(tonumber(startStage) or 1))
    -- v0.13.5：每次开局重新拉取天赋解锁集合，派生加成在本局生效。
    if talentProvider then Game.SetTalents(talentProvider()) end
    score = 0
    -- v0.13.28：局内通用卡字段必须在 baseHp 之前复位——「前线维修」的永久上限加成
    -- 写在 BALL_TUNING.maxHpBonus 里，若晚于 GetMaxBaseHp 复位，会把上一局的上限带进新局。
    BALL_TUNING.armorReduce = 0
    BALL_TUNING.partsMul = 1.0
    BALL_TUNING.launchSpeedMul = 1.0
    BALL_TUNING.brickXpFlat = 0
    BALL_TUNING.maxHpBonus = 0
    baseHp = GetMaxBaseHp()
    stage = startStage
    stageWave = 1
    wave = (startStage - 1) * StageCatalog.WAVES_PER_STAGE + 1
    -- v0.13.46：进入关卡时生成本关随机布局（精英波位 / 精英与 Boss 机型 / 关卡特性）。
    -- 选关、下一关、再战、重开都会重掷——同一关每次进入都可能不同。
    StageCatalog.BeginStage(startStage, os.time())
    bossDefeated = false
    stageResult = nil
    elapsed = 0
    veggies = {}
    marbles = {}
    aiming = false
    hasLaunched = false
    startArmed = false
    reviveUsed = false
    -- v0.11.0 商业化：局内零件与升级面板变现状态复位
    partsEarned = 0
    partsSettled = false
    partsDoubled = false
    lastSettledParts = 0
    settledParts = 0
    settleBook.bricks = 0
    settleBook.runCounted = false
    settleBook.gear = 0
    settleBook.gearSettled = 0
    runAircraft = {}
    baseShield = 0
    -- v0.13.13：开局自动拉取局外道具库存（覆盖选关/下一关/再战/重开全部入口）。
    if itemStockProvider then
        local ok, stock = pcall(itemStockProvider)
        if ok and type(stock) == "table" then Game.SetItemStock(stock) end
    end
    ResetItems()
    upgradeRerollFreeUsed = false
    heldUpgradeId = nil
    pauseHealUsed = 0
    pauseRareUsed = 0
    pendingRareRoll = false
    -- v0.13.58：附魔卡状态复位（开局空手；lastWave 记录当前波，使本波完成时发放第一张）。
    Game._enchant.card = nil
    Game._enchant.pending = nil
    Game._enchant.lastWave = wave
    pauseOrbitalUsed = false
    pauseReloadUsed = false
    pausePartsBoostUsed = false
    partsBoostTime = 0
    aimX = SLING_X
    aimY = SLING_Y
    grabStartX = SLING_X
    grabStartY = SLING_Y
    waveCooldown = 3.2    -- 开局短暂喘息；后续按关卡节奏刷新
    introTimer = 0
    nextWavePlan = nil
    -- v0.13.26：复位同波错峰生成状态。
    pendingSpawn.remaining = 0
    pendingSpawn.timer = 0
    pendingSpawn.kind = nil
    pendingSpawn.lane = 0
    pendingSpawn.spawned = 0
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
    unlockedBalls = { [STARTING_BALL_TYPE] = true }
    -- v0.13.20：天赋树的「解锁车」节点**不再**让车开局即可用（用户澄清）——
    -- 它只决定「局内那张『解锁××车』卡是否进池」。开局自带的永远只有 STARTING_BALL_TYPE。
    ammoCapacity = BASE_AMMO_TOTAL
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
    -- v0.13.55 专属卡机制字段复位（必须在 LoadBalls 之前——它读 splitCount 等）。
    BALL_TUNING.splitCount = 2
    BALL_TUNING.iceShatter = 0
    BALL_TUNING.speedPierce = 0
    BALL_TUNING.giantCritChance = 0
    -- v0.13.5：叠加天赋树的车线路数值增强（加法先、乘法后，量级可控）。
    for _, acc in pairs(talentBallStats) do
        if acc.stat == "splitBonus" then
            BALL_TUNING.splitBonus = BALL_TUNING.splitBonus + acc.add
        elseif acc.stat == "giantArea" then
            BALL_TUNING.giantArea = BALL_TUNING.giantArea + acc.add
        elseif acc.stat == "iceBonus" then
            BALL_TUNING.iceBonus = BALL_TUNING.iceBonus + acc.add
        elseif acc.stat == "speedMul" then
            BALL_TUNING.speedMul = BALL_TUNING.speedMul * acc.factor
        end
    end
    LoadBalls()
    Emit("game_reset")
end

-- 从选关界面进入某关。stageNum 缺省为 1。
local function StartGameAt(stageNum)
    previousHighScore = highScore
    ResetGame(stageNum)
    gameState = "playing"
    -- v0.13.24：进入「进关准备期」——不立刻刷怪，先放一段准备动画，
    -- 期间玩法冻结（弹珠/敌机/波次都不推进），给玩家「关卡开始」的过渡感。
    introTimer = INTRO_SECONDS
    EnsureNextWavePlan()
    -- v0.13.24：关号播报改由「进关准备期」过渡界面承担（对所有关卡统一），
    -- 原 stage_started 横幅会与过渡界面重复，故不再发出。
    print("[Game] game started at stage " .. stage .. " (intro " .. INTRO_SECONDS .. "s)")
end

local function StartGame()
    StartGameAt(1)
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
-- gap 省略时用 ENEMY_SPACING（既有行为）；同波错峰生成传 brickSize 以强制「至少隔 1 格」。
local function FleetPositionOccupied(x, y, w, h, placed, ignore, gap)
    for _, item in ipairs(placed) do
        if RectsOverlap(x, y, w, h, item.x, item.y, item.w, item.h, gap) then
            return true
        end
    end
    for _, other in ipairs(veggies) do
        if other ~= ignore and not other.dead then
            local ow, oh = other.gridW * other.brickSize, other.gridH * other.brickSize
            if RectsOverlap(x, y, w, h, other.x, other.y, ow, oh, gap) then
                return true
            end
        end
    end
    return false
end

-- 普通机按关内波次依次从原有机型中选择；特殊机不混入普通随机池。
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
    local currentStageWave = StageCatalog.GetStageWave(waveNum)
    for _, entry in ipairs(WAVE_ROSTER) do
        if currentStageWave >= entry.minWave and AircraftData[entry.key] then
            table.insert(keys, entry.key)
        end
    end
    return keys
end

---@param aircraftKey string
---@param x number
---@param y number
---@param brickSize number
---@param brickHp integer
---@param baseSpeed number
---@param opts {swayAmp:number?, swayFreq:number?, phase:number?}?
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
        if opts.swayAmp ~= nil then swayAmp = opts.swayAmp end
        if opts.swayFreq ~= nil then swayFreq = opts.swayFreq end
        if opts.phase ~= nil then spawnPhase = opts.phase end
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
        normalVy = baseSpeed * 0.42,
        swayAmp = swayAmp,
        swayFreq = swayFreq,
        agility = beh.agility,    -- A3：节奏/反应质感标记（渲染层可读）
        -- 默认 phase=0：首帧位置即 baseX。阵型可传入统一相位，保证同波一起摆。
        phase = spawnPhase,
        bricks = bricks,
        dead = false,
        breached = false,
        frozen = 0,
        freezeRatio = 0,    -- WO-13/P2：渲染层只读冻结比例（0..1），初始化为零
    }
    nextEnemyId = nextEnemyId + 1
    return enemy
end

-- v0.10.28：8bit 街机阵型。同波同机、整队锁定横摆，避免随机散点把剪影拆散。
local FORMATION_CYCLE = { "line", "vee", "grid", "swarm", "wedge", "stream" }

local function PickWaveAircraft(pool)
    if #pool == 1 then return pool[1] end
    -- 新解锁机型优先露脸，其余波次仍可抽到老机型。
    if Random() < 0.6 then return pool[#pool] end
    return pool[RandomInt(1, #pool)]
end

---@class NextWavePlan
---@field wave integer
---@field stage integer
---@field stageWave integer
---@field kind string
---@field aircraftKey string
---@field count integer
---@field formation string
---@field isBoss boolean
---@field escortKey string|nil
---@field escortCount integer|nil

local function PickFormation(waveNum, count, aircraftKey)
    if aircraftKey == "hive" then return "swarm" end
    if count <= 1 then return "line" end
    local kind = FORMATION_CYCLE[((waveNum - 1) % #FORMATION_CYCLE) + 1]
    -- 宽机横排塞不下 540 宽，3 机改 2+1 网格，避免退化成纵列。
    if (aircraftKey == "manta" or aircraftKey == "cruiser" or aircraftKey == "bomber")
        and count >= 3 then
        return "grid"
    end
    local shipWidth = AircraftData[aircraftKey].gridW * GetBrickSize(waveNum)
    if count * shipWidth + (count - 1) * ENEMY_SPACING > DW - 40 then
        return "grid"
    end
    if kind == "grid" and count <= 2 then return "line" end
    return kind
end

---@param waveNum integer
---@return NextWavePlan
PlanWave = function(waveNum)
    local currentStage = StageCatalog.GetStage(waveNum)
    local currentStageWave = StageCatalog.GetStageWave(waveNum)
    local kind = StageCatalog.GetKind(currentStage, currentStageWave)
    if kind ~= "normal" then
        local escortPool = GetAvailableTypes(waveNum)
        return {
            wave = waveNum, stage = currentStage, stageWave = currentStageWave,
            kind = kind,
            aircraftKey = StageCatalog.GetSpecialKey(currentStage, currentStageWave),
            count = 1, formation = "line", isBoss = kind == "boss",
            escortKey = kind == "elite" and PickWaveAircraft(escortPool) or nil,
            escortCount = kind == "elite" and StageCatalog.GetEscortCount(currentStage) or 0,
        }
    end
    local pool = GetAvailableTypes(waveNum)
    local count = GetWaveParams(waveNum)
    local key = (#pool > 0) and PickWaveAircraft(pool) or "scout"
    return {
        wave = waveNum, stage = currentStage, stageWave = currentStageWave,
        kind = kind,
        aircraftKey = key,
        count = count,
        formation = PickFormation(waveNum, count, key),
        isBoss = false,
    }
end

---@return NextWavePlan|nil
EnsureNextWavePlan = function()
    if stageWave >= StageCatalog.WAVES_PER_STAGE then return nil end
    local upcoming = wave + 1
    if not nextWavePlan or nextWavePlan.wave ~= upcoming then
        nextWavePlan = PlanWave(upcoming)
    end
    return nextWavePlan
end

-- 精英/首领单机从屏外进入：即使数量增加，特殊目标也始终占一个机群名额。
-- v0.13.26：特殊机用 brickSize 作间距查找空位，保证「至少隔 1 格」；
-- 且一旦本波有敌机在场，改用「从更远处生成」而非上抬——避免「Boss 已到场又瞬移到头顶」。
local function SpawnSpecialEnemy(plan)
    local key = plan.aircraftKey
    if not AircraftData[key] then
        print("[Game] ERROR: missing special aircraft " .. tostring(key))
        return nil
    end
    local brickSize = GetBrickSize(wave)
    local shipW, shipH = GetAircraftSize(key, brickSize)
    local x = DW * 0.5 - shipW * 0.5
    local y = -102 - shipH - 24
    -- 与在场敌机至少隔 1 格（brickSize）：有人占位就往更远处挪，保证「任意两架初始≥1格」。
    -- 特殊机是新生成的（尚未可见），往屏外更远处放不会造成「瞬移」。
    local guard = 0
    while FleetPositionOccupied(x, y, shipW, shipH, {}, nil, brickSize) and guard < 200 do
        y = y - brickSize
        guard = guard + 1
    end
    local baseSpeed = StageCatalog.GetBaseSpeed(stage, stageWave)
    local enemy = CreateEnemy(key, x, y, brickSize,
        StageCatalog.GetBrickHp(stage, plan.kind), baseSpeed)
    if not enemy then return nil end
    enemy.isElite = plan.kind == "elite"
    enemy.isBoss = plan.kind == "boss"
    enemy.stage = stage
    if enemy.isBoss then
        enemy.bossPhase = 1
        enemy.vulnerable = false
        enemy.summonTimer = StageCatalog.GetBossSummonInterval(stage)
        enemy.summonCount = 0
        Emit("boss_spawn", {enemyId = enemy.id, wave = wave, stage = stage, aircraftKey = key})
    end
    veggies[#veggies + 1] = enemy
    return enemy
end

-- v0.13.26：本波敌机逐架放出的时间间隔。下限按「一架在间隔内下落 ≥ 1 格 + 余量」动态抬高，
-- 保证任意两架初始位置至少隔一个格子（用户要求）；上限由 StageCatalog 的逐关收紧曲线给出。
-- ⚠️ 下落速度按**最慢机型**保守取值（基准 × 0.42 × 最慢 descentMul）：间隔太短时最慢那架
-- 来不及拉开，就会与后一架挤在同一个格子带内。用基准速度估算会在高关卡漏掉这个下界。
local SLOWEST_DESCENT_MUL = 0.66
local function CurrentSpawnInterval()
    local base = StageCatalog.GetSpawnInterval(stage)
    local descent = StageCatalog.GetBaseSpeed(stage, stageWave) * 0.42 * SLOWEST_DESCENT_MUL
    local minInterval = (pendingSpawn.brickSize + 6) / math.max(1, descent)
    return math.max(base, minInterval)
end

-- v0.13.26：从屏幕上沿之外放出本波一架敌机。屏幕是俯视 3D，敌机在屏幕外生成后
-- 下落一段才进画面——所以「刚生成时看不见」是预期，不是没刷出来。
SpawnNextNormalEnemy = function()
    if pendingSpawn.remaining <= 0 then return end
    -- 满场：本架推迟，等有空位再放（不能强行落位，否则两架会叠在一起）。
    if #veggies >= StageCatalog.MAX_FLEET then
        pendingSpawn.timer = 0.5
        return
    end
    -- v0.13.57：屏幕外（尚未进入可见战场，底边仍在 -102 之上）的敌机达到上限时，
    -- **暂停生成队列**——等屏外机下落进场后再放下一架，避免一波多架全堆在屏幕上沿之外。
    -- ⚠️ 这里只数**在场**屏外机（逐架放出一架、停一次）；待放架数由波次启动门控统一考虑
    --    （见 UpdateWaveLogic），否则把 remaining 也算进来会让整波一开始就被永久推迟（死锁）。
    -- 计数内联在函数内（不新增顶层 local，Game.lua 已逼近 Lua 200 上限，AB-166）。
    local offscreen = 0
    for i = 1, #veggies do
        local e = veggies[i]
        if not e.dead then
            local _, ey, _, eh = EnemyAABB(e)
            if ey + eh < -102 then offscreen = offscreen + 1 end
        end
    end
    if offscreen >= StageCatalog.MAX_OFFSCREEN then
        pendingSpawn.timer = 0.3
        return
    end
    local key = pendingSpawn.key
    if not AircraftData[key] then
        pendingSpawn.remaining = 0
        pendingSpawn.kind = nil
        return
    end
    local brickSize = pendingSpawn.brickSize
    local shipW, shipH = GetAircraftSize(key, brickSize)
    -- v0.13.27：横向分道——逐架轮换不同 x（确定性，非随机），避免整波都叠在正中一条竖线上。
    -- 车道数用函数内局部量，不新增顶层 local（Game.lua 已逼近 Lua 200 上限）。
    local laneCount = 5
    local margin = 20
    local maxX = math.max(margin, DW - margin - shipW)
    local lane = pendingSpawn.lane % laneCount
    pendingSpawn.lane = lane + 1
    local x = margin + (maxX - margin) * (lane / (laneCount - 1))
    local y = -102 - shipH - 24
    -- 与在场敌机（含本波前几架）至少隔 1 格：仍在屏外时再往前放，不下落瞬移。
    local guard = 0
    while FleetPositionOccupied(x, y, shipW, shipH, {}, nil, brickSize) and guard < 200 do
        y = y - brickSize
        guard = guard + 1
    end
    if FleetPositionOccupied(x, y, shipW, shipH, {}, nil, brickSize) then
        -- 屏外空间也找不到空位（极端拥挤）：推迟本架，绝不叠放。
        pendingSpawn.timer = 1.0
        return
    end
    -- v0.13.51：本关内按**出场序号**给普通敌机血量封顶（第1架≤1血、第2架≤3血、第3架≤5血…），
    -- 让关卡前段由弱到强平滑递进；只封顶不抬升（曲线更低时保持曲线值）。
    -- ⚠️ 用 `pendingSpawn.spawned`（本关已放出计数）而不是「场上无敌机」——否则首机被打掉后，
    -- 同波第二架会被误判成第一个（AB-204）。本关第一波开波时复位。
    local firstShipHp = pendingSpawn.hp
    if wave == (stage - 1) * StageCatalog.WAVES_PER_STAGE + 1 then
        local cap = StageCatalog.GetFirstShipHpCap(pendingSpawn.spawned + 1)
        if firstShipHp > cap then firstShipHp = cap end
    end
    local enemy = CreateEnemy(key, x, y, brickSize, firstShipHp, pendingSpawn.speed, {
        swayAmp = 6, swayFreq = 0.22, phase = 0,
    })
    if enemy then
        pendingSpawn.spawned = pendingSpawn.spawned + 1
        enemy.formation = "stream"
        veggies[#veggies + 1] = enemy
        pendingSpawn.remaining = pendingSpawn.remaining - 1
    end
    if pendingSpawn.remaining > 0 then
        pendingSpawn.timer = CurrentSpawnInterval()
    else
        if pendingSpawn.kind == "normal" then
            Emit("wave_started", {wave = wave, stage = stage, stageWave = stageWave,
                kind = "normal", formation = "stream", aircraftKey = key})
            print("[Game] stage " .. stage .. " wave " .. stageWave .. " stream released: " .. key)
        end
        pendingSpawn.kind = nil
    end
end

-- v0.13.26：精英护航也改为一架接一架飞入（与普通波共用同一套错峰机制）。
ReleaseEscortVolley = function(plan)
    local count = math.min(plan.escortCount or 0, math.max(0, StageCatalog.MAX_FLEET - #veggies - 1))
    if count <= 0 then return end
    local key = plan.escortKey
    if not AircraftData[key] then return end
    pendingSpawn.key = key
    pendingSpawn.kind = "escort"
    pendingSpawn.brickSize = GetBrickSize(wave)
    pendingSpawn.hp = StageCatalog.GetBrickHp(stage, "normal")
    pendingSpawn.speed = StageCatalog.GetBaseSpeed(stage, stageWave)
    pendingSpawn.remaining = count
    pendingSpawn.timer = 0
end

SpawnWave = function(availableSlots)
    -- 下一波预告、实际编队和特殊目标名称必须消费同一份预抽计划。
    local plan = nextWavePlan
    if not plan or plan.wave ~= wave then plan = PlanWave(wave) end
    nextWavePlan = nil

    if plan.kind == "elite" then
        local enemy = SpawnSpecialEnemy(plan)
        if enemy then
            ReleaseEscortVolley(plan)
            Emit("wave_started", {wave = wave, stage = stage, stageWave = stageWave,
                kind = "elite", aircraftKey = plan.aircraftKey, isBoss = false})
            print("[Game] stage " .. stage .. " wave " .. stageWave .. " elite spawned: "
                .. plan.aircraftKey)
        end
        return
    end

    if plan.kind == "boss" then
        -- v0.13.26：Boss 不再冻结本波；从屏幕外较远处飞入（SpawnSpecialEnemy 处理避让），
        -- 不把已在场的敌机顶到天上，也不做瞬移。
        local enemy = SpawnSpecialEnemy(plan)
        if enemy then
            Emit("wave_started", {wave = wave, stage = stage, stageWave = stageWave,
                kind = "boss", aircraftKey = plan.aircraftKey, isBoss = true})
            print("[Game] stage " .. stage .. " wave " .. stageWave .. " boss spawned: "
                .. plan.aircraftKey)
        end
        return
    end

    -- 普通波：登记本波参数，由 SpawnNextNormalEnemy 按错峰间隔逐架放出（第一架立即入场）。
    local count, baseSpeed, brickHp = GetWaveParams(wave)
    count = math.min(count, availableSlots or count)
    local aircraftKey = plan.aircraftKey
    if not AircraftData[aircraftKey] then
        print("[Game] WARNING: empty aircraft pool")
        return
    end
    pendingSpawn.key = aircraftKey
    pendingSpawn.kind = "normal"
    pendingSpawn.brickSize = GetBrickSize(wave)
    pendingSpawn.hp = brickHp
    pendingSpawn.speed = baseSpeed
    pendingSpawn.remaining = count
    pendingSpawn.timer = 0
    -- 起始车道随波次错开，避免每波第一架总从最左出来。
    pendingSpawn.lane = (wave - 1) % 5
    -- v0.13.51：出场序号计数随每波开波复位——它只在本关第一波生效（血量封顶判定带 wave 约束），
    -- 复位保证第一波从「第 1 架」重新计数。
    pendingSpawn.spawned = 0
    SpawnNextNormalEnemy()
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
-- 先以本子步的线段包围盒粗筛整架/单格，覆盖擦边和高速穿越。
-- v0.10.27：高速球除分子步进，还对本帧位移做线段-AABB 扫掠，避免擦边/对角穿格丢失碰撞。
local function SegmentNearRect(x0, y0, x1, y1, rx, ry, rw, rh, radius)
    return math.max(x0, x1) + radius >= rx
        and math.min(x0, x1) - radius <= rx + rw
        and math.max(y0, y1) + radius >= ry
        and math.min(y0, y1) - radius <= ry + rh
end

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
-- scoreValue 为本次击碎的真实得分；越线碎裂（惩罚）不传，表现层据此不飘分数。
local function EmitBrickShatterFx(enemy, brick, x, y, scoreValue)
    local angle = Random() * math.pi * 2
    -- v0.10.23：降低飞散速度/上抛，避免碎片飞到屏顶长期堆积、与新小粒子抢戏。
    local speed = 120 + Random() * 150
    local lift = 80 + Random() * 90
    Emit("brick_hit", {
        enemyId = enemy.id, aircraftKey = enemy.aircraftKey,
        col = brick.col, row = brick.row, x = x, y = y,
        destroyed = true, score = scoreValue or 0,
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

EjectBrick = function(enemy, brick)
    if brick.ejected or not brick.alive then return false end
    local data = AircraftData[enemy.aircraftKey]
    local x = enemy.x + (brick.col - 0.5) * enemy.brickSize
    local y = enemy.y + (brick.row - 0.5) * enemy.brickSize
    brick.alive = false
    brick.ejected = true
    score = score + data.score
    bricksBroken = bricksBroken + 1
    -- v0.14.x 存钱罐：每击碎 1 块累积 1 点进度；精英机每块按 2 倍计（=> 精英 100 齿轮 / 100 块）。
    settleBook.gear = settleBook.gear + (enemy.isElite and 2 or 1)
    -- v0.13.28：「装甲强化」的零件产出倍率在产出点统一结算（击碎/清机/过波/结算同源）。
    partsEarned = partsEarned + PARTS_PER_BRICK * (partsBoostTime > 0 and 2 or 1) * BALL_TUNING.partsMul
    -- v0.13.28：「穿甲弹头」每级额外 +1 经验，低难度也能立刻加速升级。
    GainXp(XP_PER_BRICK + BALL_TUNING.brickXpFlat)
    EmitBrickShatterFx(enemy, brick, x, y, data.score)
    -- 最后存活格消失即发布完整击毁事实；奖励仍留在 UpdateEnemies，不能因升级提前结算。
    if not enemy.breached then
        local fullyDestroyed = true
        for _, remaining in ipairs(enemy.bricks) do
            if remaining.alive then fullyDestroyed = false; break end
        end
        if fullyDestroyed then
            local width = enemy.gridW * enemy.brickSize
            local height = enemy.gridH * enemy.brickSize
            Emit("enemy_destroyed", {
                enemyId = enemy.id,
                x = enemy.x + width * 0.5, y = enemy.y + height * 0.5,
                width = width, height = height,
            })
        end
    end
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
    if enemy.isBoss and enemy.vulnerable then
        damage = (damage or 1) * 1.5
    end
    -- v0.13.55「霜裂涂层」：冻结中的敌机受击更痛（脆化碎冰）。
    if enemy.frozen and enemy.frozen > 0 and BALL_TUNING.iceShatter > 0 then
        damage = (damage or 1) * (1 + BALL_TUNING.iceShatter)
    end
    brick.hp = brick.hp - (damage or 1)
    if brick.hp <= 0 then
        EjectBrick(enemy, brick)
    else
        -- 装甲命中不脱落；实际耐久由每三关增长一次的 brick.hp 决定。
        Emit("brick_hit", {enemyId = enemy.id, aircraftKey = enemy.aircraftKey,
            col = brick.col, row = brick.row,
            x = enemy.x + (brick.col - 0.5) * enemy.brickSize,
            y = enemy.y + (brick.row - 0.5) * enemy.brickSize,
            destroyed = false, score = 0})
    end
end

-- P11 五异常反应系统（规则层）：砖块可携带 burn/shock/corrode/freeze/volatile 五种异常状态，
-- 由命中弹珠的词条或类型施加；状态间存在反应（冻结+灼烧=融穿、电击+冻结=碎裂）额外结算。
-- 仅记录计时与伤害，视觉染色由表现层推迟消费 status 事件。
local STATUS_BITS = {burn = 1, shock = 2, corrode = 4, freeze = 8, volatile = 16}
local STATUS_ORDER = {"burn", "shock", "corrode", "freeze", "volatile"}

local function ApplyBrickStatus(brick, status, duration, power)
    brick.status = brick.status or {}
    brick.statusMask = brick.statusMask or 0
    local bit = STATUS_BITS[status]
    if bit then brick.statusMask = brick.statusMask | bit end
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
    for _, status in ipairs(STATUS_ORDER) do
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
        Game.CancelHoldSpeed()
        RollUpgradeChoices({})
        Emit("level_up", {level = playerLevel})
        print("[Game] level up -> " .. playerLevel .. ", waiting for upgrade pick")
    end
end

---@class RollUpgradeOpts
---@field count integer|nil 候选卡数量（缺省 3）
---@field forceRare boolean|nil 广告「卡池升格」：优先抽稀有卡

---@param opts RollUpgradeOpts|nil
RollUpgradeChoices = function(opts)
    -- WO-09/P5：加权抽卡 + 叠加上限 + 稀有保底 + 同次候选去重。
    -- v0.11.0：支持自定义候选数与广告「卡池升格」的稀有保底。
    opts = opts or {}
    local cardCount = math.max(1, math.floor(opts.count or PANEL_CARD_COUNT))
    local forceRare = opts.forceRare == true
    -- 暂停补给站买的「保底稀有」一次性生效后即清空。
    if pendingRareRoll then
        forceRare = true
        pendingRareRoll = false
    end
    upgradeChoices = {}
    local sinceRare = 0
    local forcedRareDone = false
    local chosenThisRoll = {}
    if heldUpgradeId then
        for _, u in ipairs(UPGRADE_POOL) do
            if u.id == heldUpgradeId and CanOfferUpgrade(u) then
                upgradeChoices[1] = u
                chosenThisRoll[u.id] = true
                if u.rarity ~= "common" then forcedRareDone = true end
                break
            end
        end
        if upgradeChoices[1] == nil then heldUpgradeId = nil end
    end

    ---@param avail {u: UpgradeDef, w: number}[]
    ---@param rareOnly boolean
    ---@return UpgradeDef|nil
    local function PickWeighted(avail, rareOnly)
        local total = 0
        for _, candidate in ipairs(avail) do
            if not rareOnly or candidate.u.rarity ~= "common" then
                total = total + candidate.w
            end
        end
        if total <= 0 then return nil end
        local roll = Random() * total
        for _, candidate in ipairs(avail) do
            if not rareOnly or candidate.u.rarity ~= "common" then
                roll = roll - candidate.w
                if roll <= 0 then return candidate.u end
            end
        end
        for _, candidate in ipairs(avail) do
            if not rareOnly or candidate.u.rarity ~= "common" then
                return candidate.u
            end
        end
        return nil
    end

    for _ = #upgradeChoices + 1, cardCount do
        local avail = {}
        for _, u in ipairs(UPGRADE_POOL) do
            local stacks = upgradeStacks[u.id] or 0
            if CanOfferUpgrade(u) and not chosenThisRoll[u.id] then
                local w = u.weight
                -- v0.13.28：「前线维修」现在给永久生命上限，不再随叠层贬值，只在很高层数轻微降权。
                if u.id == "repair" and stacks >= 8 then w = w * 0.6 end
                if u.id == "xp" and stacks >= 4 then w = w * 0.5 end
                avail[#avail + 1] = {u = u, w = w}
            end
        end
        if #avail == 0 then break end

        local picked
        -- 「卡池升格」：本次首张强制稀有（该标志只生效一次，不依赖 sinceRare）。
        if forceRare and not forcedRareDone then
            picked = PickWeighted(avail, true)
            if picked then forcedRareDone = true end
        end
        -- 常规稀有保底：连续 6 张普通后强制出稀有。
        if not picked and sinceRare >= 6 then
            picked = PickWeighted(avail, true)
        end
        if not picked then
            picked = PickWeighted(avail, false)
        end
        if not picked then break end

        if picked.rarity ~= "common" then
            sinceRare = 0
        else
            sinceRare = sinceRare + 1
        end
        chosenThisRoll[picked.id] = true
        upgradeChoices[#upgradeChoices + 1] = picked
    end

    -- 抽卡候选不足时仍必须提供可点击的完整候选，禁止进入不可恢复的空升级态。
    if #upgradeChoices < cardCount then
        for _, u in ipairs(UPGRADE_POOL) do
            if #upgradeChoices >= cardCount then break end
            local duplicate = false
            for _, picked in ipairs(upgradeChoices) do
                if picked.id == u.id then duplicate = true; break end
            end
            if not duplicate and CanOfferUpgrade(u) then
                upgradeChoices[#upgradeChoices + 1] = u
            end
        end
    end
end

-- 由外部 UI 调用：选择第 index（1-based）项强化，恢复 playing。
-- v0.12.5 精简：面板广告触点收敛为「免费重抽 + 看广告重抽」，
-- 删除第 4 张解锁 / 单卡升格 / 额外再选 / 选卡倒计时（触点过密招致反感）。
---@param index integer
---@return boolean picked
function Game.PickUpgrade(index)
    if gameState ~= "levelup" or not upgradeChoices then return false end
    local choice = upgradeChoices[index]
    if not choice or not CanOfferUpgrade(choice) then return false end

    local stacks = upgradeStacks[choice.id] or 0
    local times = math.min(choice.maxStacks - stacks, 1)
    if times <= 0 then return false end
    for _ = 1, times do
        choice.apply(stacks)   -- 传入当前层数，支持边际递减
        stacks = stacks + 1
    end
    upgradeStacks[choice.id] = stacks
    if heldUpgradeId == choice.id then heldUpgradeId = nil end
    table.insert(upgradePicks, choice.id)
    Emit("upgrade_picked", {
        id = choice.id, name = choice.name, stacks = stacks,
    })
    print("[Game] upgrade picked: " .. choice.name .. " (stacks=" .. stacks .. ")")

    pendingLevelUps = pendingLevelUps - 1
    upgradeChoices = nil
    if pendingLevelUps > 0 then
        RollUpgradeChoices({})
        Emit("level_up", {level = playerLevel})
    else
        gameState = "playing"
        if deferredXp > 0 then
            local bufferedXp = deferredXp
            deferredXp = 0
            GainXp(bufferedXp)
        end
    end
    return true
end

function Game.GetUpgradeChoices()
    if gameState ~= "levelup" then return nil end
    local current = upgradeChoices
    if not current then return nil end
    local list = {}
    -- WO-10/P5：升级卡 delta 预览字段，UI 只读展示，不在此做规则计算。
    for _, c in ipairs(current) do
        table.insert(list, {
            id = c.id, name = c.name, desc = c.desc, detail = c.detail,
            value = c.value, rarity = c.rarity, kind = c.kind or "buff",
            ballType = c.ballType, unlockBallType = c.unlockBallType,
            stacks = upgradeStacks[c.id] or 0, maxStacks = c.maxStacks,
            tradeoff = c.tradeoff,
            held = heldUpgradeId == c.id,
        })
    end
    return list
end

-- ============================================================================
-- v0.11.0 商业化：升级面板变现接口。
-- 规则层只回答「能不能做」与「做了什么」，是否播放广告由编排层（main.lua）决定。
-- ============================================================================

---@return boolean
function Game.CanFreeReroll()
    return gameState == "levelup" and not upgradeRerollFreeUsed
end

---@return boolean
function Game.CanReroll()
    return gameState == "levelup" and upgradeChoices ~= nil
end

-- 锁住一张已有候选卡，下一次升级（或本次重抽）固定保留在首位；再次点击解除。
---@param index integer
---@return boolean ok
function Game.ToggleHeldUpgrade(index)
    if gameState ~= "levelup" or not upgradeChoices then return false end
    local choice = upgradeChoices[index]
    if not choice then return false end
    heldUpgradeId = (heldUpgradeId == choice.id) and nil or choice.id
    Emit("upgrade_hold", {id = choice.id, held = heldUpgradeId == choice.id})
    print("[Game] upgrade hold " .. choice.id .. "=" .. tostring(heldUpgradeId == choice.id))
    return true
end

---@param mode string "free" | "ad_rare"
---@return boolean ok
function Game.RerollUpgrades(mode)
    if gameState ~= "levelup" or not upgradeChoices then return false end
    if mode == "free" then
        if upgradeRerollFreeUsed then return false end
        upgradeRerollFreeUsed = true
    end
    RollUpgradeChoices({ forceRare = (mode == "ad_rare") })
    Emit("upgrade_reroll", {mode = mode})
    print("[Game] upgrade reroll mode=" .. mode)
    return true
end

-- ============================================================================
-- 暂停补给站（看广告，单局限量）。规则层只判定「能不能用」，广告由编排层播。
-- ============================================================================

---@return boolean
function Game.CanPauseHeal()
    return gameState == "paused" and pauseHealUsed < PAUSE_SUPPLY.healMax and baseHp < GetMaxBaseHp()
end

---@return integer 剩余可用次数
function Game.GetPauseHealLeft()
    return math.max(0, PAUSE_SUPPLY.healMax - pauseHealUsed)
end

---@return boolean ok
function Game.PauseHeal()
    if not Game.CanPauseHeal() then return false end
    pauseHealUsed = pauseHealUsed + 1
    baseHp = math.min(GetMaxBaseHp(), baseHp + PAUSE_SUPPLY.healAmount)
    Emit("base_healed", {amount = PAUSE_SUPPLY.healAmount, hp = baseHp})
    print("[Game] pause supply: base healed to " .. baseHp)
    return true
end

---@return boolean
function Game.CanPauseRarePick()
    return gameState == "paused" and pauseRareUsed < PAUSE_SUPPLY.rareMax
end

---@return integer
function Game.GetPauseRareLeft()
    return math.max(0, PAUSE_SUPPLY.rareMax - pauseRareUsed)
end

-- 买「下一个强化面板保底出稀有」。
---@return boolean ok
function Game.PauseRarePick()
    if not Game.CanPauseRarePick() then return false end
    pauseRareUsed = pauseRareUsed + 1
    pendingRareRoll = true
    Emit("rare_roll_armed", {})
    print("[Game] pause supply: next upgrade roll guaranteed rare")
    return true
end

function Game.CanPauseOrbital()
    if gameState ~= "paused" or pauseOrbitalUsed then return false end
    for _, enemy in ipairs(veggies) do
        if enemy.isBoss and not enemy.dead then return true end
    end
    return false
end

function Game.PauseOrbital()
    if not Game.CanPauseOrbital() then return false end
    pauseOrbitalUsed = true
    local destroyed = 0
    for _, enemy in ipairs(veggies) do
        if enemy.isBoss and not enemy.dead then
            for _, brick in ipairs(enemy.bricks) do
                if brick.alive and (brick.col + brick.row) % 4 == 0 then
                    if EjectBrick(enemy, brick) then destroyed = destroyed + 1 end
                end
            end
        end
    end
    Emit("orbital_strike", {count = destroyed})
    print("[Game] orbital strike destroyed=" .. destroyed)
    return true
end

function Game.CanPauseReload()
    return gameState == "paused" and not pauseReloadUsed
end

function Game.PauseReload()
    if not Game.CanPauseReload() then return false end
    pauseReloadUsed = true
    -- v0.13.19：兜底用初始车类型（加速车），不再写死分裂车。
    local nextType = ballQueue[1] or (activeBall and activeBall.ballType) or STARTING_BALL_TYPE
    table.insert(ballQueue, 1, nextType)
    if not activeBall and (nextType ~= "normal" or Game._NormalMarbleSlots() > 0) then
        activeBall = CreateMarble(table.remove(ballQueue, 1), CollectActiveWords())
    end
    Emit("marble_reloaded", {ballType = nextType})
    print("[Game] reserve ammo +1: " .. nextType)
    return true
end

function Game.CanPausePartsBoost()
    return gameState == "paused" and not pausePartsBoostUsed
end

function Game.PausePartsBoost()
    if not Game.CanPausePartsBoost() then return false end
    pausePartsBoostUsed = true
    partsBoostTime = 45
    Emit("parts_boost", {duration = 45})
    print("[Game] parts x2 for 45 seconds")
    return true
end

-- ============================================================================
-- 局内道具槽（v0.11.0 商业化 P4）。
-- 三格：炸弹 / 冰冻 / 护盾。每格单局可用广告获取 1 次，获取后点一下立即生效。
-- 规则层只管「能不能拿 / 拿到没 / 用了什么效果」，广告播放由编排层决定。
-- ============================================================================

---@class ItemDef
---@field key string
---@field name string
---@field color integer[] 槽位主色（UI 只读）

---@type ItemDef[]
local ITEM_DEFS = {
    { key = "bomb",   name = "炸弹", color = {196, 120, 255} },
    { key = "freeze", name = "冰冻", color = {120, 216, 255} },
    { key = "shield", name = "护盾", color = {90, 200, 255} },
}
local ITEM_BY_KEY = {}
for i = 1, #ITEM_DEFS do ITEM_BY_KEY[ITEM_DEFS[i].key] = ITEM_DEFS[i] end

---@type table<string, integer>
local itemCharges = { bomb = 0, freeze = 0, shield = 0 }  -- 槽位存量
---@type table<string, boolean>
local itemGranted = {}                                     -- 本局是否已用广告领过
-- v0.13.13：局外买来的永久库存（选关界面花零件购买），进局时注入。
-- 规则：**每种道具每局最多使用一次**（用户要求，不在 UI 里写明，靠精灵明暗+角标表达）。
---@type table<string, integer>
local itemStock = { bomb = 0, freeze = 0, shield = 0 }
---@type table<string, boolean>
local itemUsedThisRun = {}                                 -- 本局该道具是否已用过
local FREEZE_SECONDS = 4.0                                 -- 冰冻持续
local SHIELD_POINTS = 30                                   -- 护盾吸收量

ResetItems = function()
    itemCharges = { bomb = 0, freeze = 0, shield = 0 }
    itemGranted = {}
    itemUsedThisRun = {}
    -- 把永久库存注入本局槽位（每样 1 个；本局限用一次由 itemUsedThisRun 兜底）。
    for i = 1, #ITEM_DEFS do
        local key = ITEM_DEFS[i].key
        if (itemStock[key] or 0) > 0 then
            itemCharges[key] = 1
        end
    end
end

-- 局外库存由编排层在开局前注入（PlayerData → Game）。
---@param stock table<string, integer>
function Game.SetItemStock(stock)
    itemStock = { bomb = 0, freeze = 0, shield = 0 }
    for i = 1, #ITEM_DEFS do
        local key = ITEM_DEFS[i].key
        itemStock[key] = math.max(0, math.floor((stock and stock[key]) or 0))
    end
end

-- v0.13.13：库存 provider——ResetGame 每次开局自动拉取，
-- 覆盖「选关 / 下一关 / 再战 / 重开」全部入口，避免逐个入口手动注入漏掉。
---@param fn fun(): table<string, integer>
function Game.SetItemStockProvider(fn)
    itemStockProvider = fn
end

---@return table<string, integer>
function Game.GetItemStock()
    return itemStock
end

---@param key string
---@return boolean
function Game.CanGrantItem(key)
    if gameState ~= "playing" then return false end
    if not ITEM_BY_KEY[key] then return false end
    return itemGranted[key] ~= true
end

---@param key string
---@return integer
function Game.GetItemCharges(key)
    return itemCharges[key] or 0
end

-- 广告看完后发放到槽位。
---@param key string
---@return boolean ok
function Game.GrantItem(key)
    if not Game.CanGrantItem(key) then return false end
    itemGranted[key] = true
    itemCharges[key] = (itemCharges[key] or 0) + 1
    Emit("item_granted", {key = key})
    print("[Game] item granted: " .. key)
    return true
end

---@param key string
---@return boolean
function Game.CanUseItem(key)
    if gameState ~= "playing" then return false end
    -- v0.13.13：每种道具每局最多使用一次（无论库存多少）。
    if itemUsedThisRun[key] then return false end
    return (itemCharges[key] or 0) > 0
end

-- 立即生效。炸弹=全场每机炸掉数格；冰冻=全场冻结；护盾=防线获得吸收值。
---@param key string
---@return boolean ok
function Game.UseItem(key)
    if not Game.CanUseItem(key) then return false end
    itemCharges[key] = itemCharges[key] - 1
    itemUsedThisRun[key] = true

    if key == "bomb" then
        local popped = 0
        for _, enemy in ipairs(veggies) do
            if not enemy.dead then
                local live = {}
                for _, brick in ipairs(enemy.bricks) do
                    if brick.alive then live[#live + 1] = brick end
                end
                -- 每机随机炸掉至多 4 格，避免一键清场破坏节奏
                for _ = 1, math.min(4, #live) do
                    local idx = RandomInt(1, #live)
                    local brick = table.remove(live, idx)
                    if EjectBrick(enemy, brick) then popped = popped + 1 end
                end
            end
        end
        Emit("item_used", {key = key, count = popped})
        print("[Game] bomb used, bricks=" .. popped)
        return true
    end

    if key == "freeze" then
        for _, enemy in ipairs(veggies) do
            if not enemy.dead then
                enemy.frozen = FREEZE_SECONDS
                enemy.freezeRatio = 1
            end
        end
        Emit("item_used", {key = key, duration = FREEZE_SECONDS})
        print("[Game] freeze used for " .. FREEZE_SECONDS .. "s")
        return true
    end

    if key == "shield" then
        baseShield = baseShield + SHIELD_POINTS
        Emit("item_used", {key = key, amount = SHIELD_POINTS})
        print("[Game] shield used, shield=" .. baseShield)
        return true
    end

    return false
end

---@return ItemDef[]
function Game.GetItemDefs()
    return ITEM_DEFS
end

-- ============================================================================
-- 局内附魔卡（v0.13.58）。
-- 每完成一波获得/更换一张附魔卡，显示在左上角（与右上道具竖列对称）。
-- 使用后卡片消失，效果作用在**预备发射的车**上；若当前没有待发车（球在飞/补弹中），
-- 则顺延给「下一个预备发射的车」。稀有度蓝/紫/黄，波次越高越容易出高稀有度。
-- 规则层只判定「能不能用 / 用了什么效果」，绘制与命中在 UI 层。
-- ============================================================================

-- 把附魔卡挂到一颗弹珠上（改写行为字段；不改弹种定义，禁止硬编码到渲染层）。
---@param marble table
---@param card EnchantDef|nil
ApplyEnchantToMarble = function(marble, card)
    if not marble or not card then return end
    marble.enchant = card
    if card.pierce then marble.enchantPierce = card.pierce end
    Emit("enchant_applied", {
        id = marble.id, cardId = card.id, name = card.name, rarity = card.rarity,
    })
end

-- 当前是否有附魔卡在手。
---@return boolean
function Game.HasEnchant()
    return Game._enchant.card ~= nil
end

-- 能不能使用附魔卡：只在战斗中、且手上有卡时可用。
---@return boolean
function Game.CanUseEnchant()
    return gameState == "playing" and Game._enchant.card ~= nil
end

-- 使用附魔卡。有预备发射的车 → 立即生效；否则顺延给下一个预备发射的车。
-- 无论立即生效还是顺延，卡片都会从手上消失（用掉即消耗）。
---@return boolean ok
function Game.UseEnchant()
    if not Game.CanUseEnchant() then return false end
    local card = Game._enchant.card
    Game._enchant.card = nil
    if activeBall then
        ApplyEnchantToMarble(activeBall, card)
        print("[Game] enchant applied immediately: " .. card.id)
    else
        Game._enchant.pending = card
        Emit("enchant_armed", {cardId = card.id, name = card.name, rarity = card.rarity})
        print("[Game] enchant deferred to next vehicle: " .. card.id)
    end
    return true
end

-- 新一波完成时发放/更换一张附魔卡。由 UpdateWaveLogic 在波次推进处调用一次。
local function GrantEnchant()
    local card = EnchantCatalog.Roll(wave, Random)
    Game._enchant.card = card
    Emit("enchant_granted", {
        cardId = card.id, name = card.name, rarity = card.rarity, wave = wave,
    })
    print("[Game] enchant granted at wave " .. wave .. ": " .. card.id .. " (" .. card.rarity .. ")")
end

-- 读取当前附魔状态（供渲染层只读展示）。
---@return {card: EnchantDef|nil, pending: EnchantDef|nil}
function Game.GetEnchantState()
    return { card = Game._enchant.card, pending = Game._enchant.pending }
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
        flightTime = 0,
        ignoredBrick = originBrick,
        giantPiercing = false,
    }
    nextMarbleId = nextMarbleId + 1
    return marble
end

local function TrySplitNormal(marble, originBrick, pendingMarbles)
    local def = BALL_TYPES.normal
    if Random() >= def.splitChance + BALL_TUNING.splitBonus then return end

    -- v0.13.55「裂变核」：分裂数量由 splitCount 决定（基础 2 颗，专属卡每级 +1）。
    -- 预算同时扣除母弹、待发车和本帧待加入的子弹；不足时只生成剩余名额。
    local count = math.min(math.max(2, math.floor(BALL_TUNING.splitCount or 2)),
        Game._NormalMarbleSlots(pendingMarbles))
    if count <= 0 then return end
    -- 以母弹速度方向为中心铺开；只剩一个名额时居中，避免恒向左偏。
    local spread = def.splitSpread or 18
    for i = 1, count do
        local angle = count == 1 and 0 or -spread + (2 * spread) * (i - 1) / (count - 1)
        table.insert(pendingMarbles,
            CreateSplitMarble(marble, angle, originBrick))
    end
    Emit("normal_split", {
        x = marble.x, y = marble.y,
        generation = marble.generation + 1,
        count = count,
    })
    print("[Game] normal marble split, generation=" .. (marble.generation + 1) .. " count=" .. count)
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

    -- v0.13.22：不再有速度上限（原 effMax = maxSpeed * speedMul）。
    -- v0.13.23：加速倍率随当前速度**软性递减**——从**初始速度**起算，到 speedSoftCap 时降到下限，
    -- 之后恒定按下限稳步增长（仍严格 >1，速度永远在涨、无硬上限）。
    -- 例：初速 660 时 ×1.06（不吃衰减）；1400 及以上恒 ×1.012。
    local boost = def.speedBoost
    local softCap = def.speedSoftCap
    if softCap and softCap > def.speed then
        local t = math.min(1, math.max(0, (marble.speed - def.speed) / (softCap - def.speed)))
        boost = def.speedBoost + (def.speedBoostFloor - def.speedBoost) * t
    end
    -- speedMul（天赋/卡）作为「加速度加成」叠加在倍率上。
    local gain = boost + (BALL_TUNING.speedMul - 1.0) * 0.1
    marble.speed = marble.speed * gain
    local velocityLength = math.sqrt(marble.vx * marble.vx + marble.vy * marble.vy)
    if velocityLength > 0.001 then
        marble.vx = marble.vx / velocityLength * marble.speed
        marble.vy = marble.vy / velocityLength * marble.speed
    end
end

-- v0.13.15：天赋「基础攻击 +N」直接并入伤害加成（对所有弹种生效）。
local function TalentDamageBonus()
    return talentAtkBonus
end

-- 暴击判定：按天赋暴击率掷一次；命中则伤害 ×TalentCatalog.CRIT_MULT。
-- ⚠️ GetMarbleDamage 会在子步进里被多次调用，但每次调用都对应「一次命中结算」，
-- 且同一帧同一砖块已由 frameHitBricks 去重，因此不会重复掷。
---@param base number
---@param marble table|nil 用于给表现层提供飘字坐标
---@return number damage
local function ApplyCrit(base, marble)
    if talentCritChance <= 0 then return base end
    if Random() >= talentCritChance then return base end
    if marble then
        Emit("crit_hit", { x = marble.x, y = marble.y, damage = base * TalentCatalog.CRIT_MULT })
    end
    return base * TalentCatalog.CRIT_MULT
end

local function GetMarbleDamage(marble, def)
    local base
    if marble.ballType ~= "speed" then
        base = def.damage + BALL_TUNING.damageBonus + TalentDamageBonus()
    else
        -- v0.13.22：加速车伤害按速度分档**无限增长**（原 min(maxDamage, ...) 封顶已去）。
        local bonus = math.floor(math.max(0, marble.speed - def.speed) / def.damageStep)
        base = def.damage + bonus + BALL_TUNING.damageBonus + TalentDamageBonus()
    end
    -- v0.13.58：附魔「重击」——直接放大本次弹珠的基础伤害。
    if marble.enchant and marble.enchant.damageMul then
        base = base * marble.enchant.damageMul
    end
    -- 暴击只影响本次结算，不改弹珠状态；表现层消费 crit_hit 出飘字。
    return ApplyCrit(base, marble)
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
    if (marble.giantAreaCooldown or 0) > 0 then
        marble.giantPiercePending = true
        return
    end
    marble.giantPiercePending = false
    marble.giantPiercing = true
    -- 只有冷却结束才发布就绪，表现层据此提示「可以贯穿」。
    Emit("giant_pierce_armed", {id = marble.id, x = marble.x, y = marble.y})
    print("[Game] giant marble circular piercing ready id=" .. tostring(marble.id))
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
                        -- v0.13.55「冲击波」：范围击碎按概率暴击（双倍伤害），复用暴击飘字。
                        local cellDamage = damage
                        if BALL_TUNING.giantCritChance > 0 and Random() < BALL_TUNING.giantCritChance then
                            cellDamage = damage * 2
                            Emit("crit_hit", { x = x, y = y, damage = cellDamage })
                        end
                        DamageBrick(enemy, brick, cellDamage)
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
    Game.CancelHoldSpeed()

    local def = BALL_TYPES[activeBall.ballType]
    -- WO-08/P7：power 为归一化蓄力 (0..1)，映射到 [powerMin, powerMax] 初速比例。
    local powerRatio = math.max(0, math.min(1, power or 0))
    local speedScale = BALANCE.powerMin + (BALANCE.powerMax - BALANCE.powerMin) * powerRatio
    -- v0.13.28：「玻璃巨炮」的发射初速倍率——低难度砖块 1 血时伤害是溢出，但更快的弹道立刻有感。
    local speed = def.speed * speedScale * BALL_TUNING.launchSpeedMul
    activeBall.vx = -dx / length * speed
    activeBall.vy = -dy / length * speed
    activeBall.speed = speed
    activeBall.onSling = false
    activeBall.flightTime = 0
    hasLaunched = true
    table.insert(marbles, activeBall)
    Emit("marble_launched", {
        id = activeBall.id,
        ballType = activeBall.ballType,
        x = activeBall.x,
        y = activeBall.y,
    })
    -- v0.13.58：附魔「三连」——发射时额外扇形射出同型车（继承附魔与词条，共享同一发射方向）。
    local triple = activeBall.enchant and activeBall.enchant.tripleShot or 0
    for k = 1, triple do
        local sign = (k % 2 == 1) and 1 or -1
        local spread = 16 * math.ceil(k / 2) * sign
        local baseAngle = math.atan(-dy, -dx)
        local a = baseAngle + math.rad(spread)
        local extra = CreateSplitMarble(activeBall, 0, nil)
        extra.ballType = activeBall.ballType
        extra.radius = activeBall.radius
        extra.speed = speed
        extra.vx = math.cos(a) * speed
        extra.vy = math.sin(a) * speed
        extra.isPrimary = false
        extra.enchant = activeBall.enchant
        extra.enchantPierce = activeBall.enchantPierce
        table.insert(marbles, extra)
    end
    if triple > 0 then
        Emit("enchant_triple", { x = activeBall.x, y = activeBall.y, count = triple })
    end
    activeBall = nil
end

local function QueueNextBall()
    if #ballQueue > 0 then
        -- 满额时保持队首与库存，等已有分裂车回收后再装填，不绕过同屏上限。
        if ballQueue[1] == "normal" and Game._NormalMarbleSlots() <= 0 then return end
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

-- 允许弹珠在场上持续发挥作用，但纯水平发射可能永不越过回收线；
-- 极端长飞行兜底回收避免无界累积，不改变分裂概率或正常轨迹。
local MAX_MARBLE_FLIGHT_TIME = 60

UpdateMarbles = function(dt)
    local pendingMarbles = {}
    for i = #marbles, 1, -1 do
        local marble = marbles[i]
        local def = BALL_TYPES[marble.ballType]
        -- v0.10.28：按本帧位移自适应子步进，高速弹不再打穿薄格。
        local move = math.sqrt(marble.vx * marble.vx + marble.vy * marble.vy) * dt
        -- 倍速最多把客户端0.05秒模拟扩为0.1秒，碰撞预算同步翻倍。
        -- 不重复整个规则帧：同车同砖去重与越线按行聚合仍只结算一次。
        local stepScale = math.max(1, math.ceil(dt / 0.05 - 1e-9))
        local steps = math.max(6 * stepScale, math.min(16 * stepScale, math.ceil(move / math.max(4, marble.radius * 0.32))))
        local subDt = dt / steps
        local frameHitBricks = {}
        marble.flightTime = (marble.flightTime or 0) + dt

        for _ = 1, steps do
            if not marble.alive then break end

            if marble.redirectCooldown and marble.redirectCooldown > 0 then
                marble.redirectCooldown = marble.redirectCooldown - subDt
            end
            -- 冷却只随玩法子步推进；暂停、升级与广告冻结时不消耗。
            if (marble.giantAreaCooldown or 0) > 0 then
                local remaining = marble.giantAreaCooldown - subDt
                -- 消除累计浮点尾数，确保满 1 秒不多等一个子步。
                marble.giantAreaCooldown = remaining > 1e-9 and remaining or 0
                if marble.giantAreaCooldown == 0 and marble.giantPiercePending then
                    ArmGiantPiercing(marble)
                end
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

            -- v0.10.28：先收集本步所有重叠格，再打最近的一格。
            -- 旧逻辑按 bricks 数组顺序命中第一格就 break，会漏掉真正碰到的格，
            -- 表现为“球穿过机翼/座舱无碰撞、碎裂不完整”。
            if marble.ignoredBrick then
                local ib = marble.ignoredBrick
                local found = false
                for _, enemy in ipairs(veggies) do
                    if not enemy.dead then
                        for _, brick in ipairs(enemy.bricks) do
                            if brick == ib then
                                found = true
                                local irx = enemy.x + (brick.col - 1) * enemy.brickSize + 1
                                local iry = enemy.y + (brick.row - 1) * enemy.brickSize + 1
                                if not IntersectsBrick(marble, irx, iry,
                                    enemy.brickSize - 2, enemy.brickSize - 2) then
                                    marble.ignoredBrick = nil
                                end
                                break
                            end
                        end
                    end
                    if found then break end
                end
                if not found then marble.ignoredBrick = nil end
            end

            local best = nil
            local bestDist = 1e12
            for _, enemy in ipairs(veggies) do
                if not enemy.dead
                    and SegmentNearRect(prevX, prevY, marble.x, marble.y,
                        enemy.x, enemy.y,
                        enemy.gridW * enemy.brickSize, enemy.gridH * enemy.brickSize,
                        marble.radius) then
                    for _, brick in ipairs(enemy.bricks) do
                        if brick ~= marble.ignoredBrick
                            and brick.alive and not brick.ejected
                            and not frameHitBricks[brick] then
                            local rx = enemy.x + (brick.col - 1) * enemy.brickSize + 1
                            local ry = enemy.y + (brick.row - 1) * enemy.brickSize + 1
                            local rw = enemy.brickSize - 2
                            local rh = enemy.brickSize - 2
                            if SegmentNearRect(prevX, prevY, marble.x, marble.y,
                                rx, ry, rw, rh, marble.radius) then
                                local overlap = IntersectsBrick(marble, rx, ry, rw, rh)
                                    or SweptHitsBrick(prevX, prevY, marble.x, marble.y,
                                        marble.radius, rx, ry, rw, rh)
                                if overlap then
                                    local cx = rx + rw * 0.5
                                    local cy = ry + rh * 0.5
                                    local dx = marble.x - cx
                                    local dy = marble.y - cy
                                    local dist = dx * dx + dy * dy
                                    if dist < bestDist then
                                        bestDist = dist
                                        best = {
                                            enemy = enemy, brick = brick,
                                            rx = rx, ry = ry, rw = rw, rh = rh,
                                        }
                                    end
                                end
                            end
                        end
                    end
                end
            end

            if best then
                local enemy = best.enemy
                local brick = best.brick
                if marble.giantPiercing and (marble.giantAreaCooldown or 0) <= 0 then
                    -- 仅实际圆域命中启动冷却，先置位防同帧连续触发；
                    -- 冷却期间走普通碰撞，保留反弹武装但不提前释放圆域。
                    marble.giantAreaCooldown = def.areaCooldown
                    DamageGiantArea(enemy, brick,
                        GetMarbleDamage(marble, def), frameHitBricks)
                    Emit("giant_pierce_consumed", {id = marble.id, x = marble.x, y = marble.y})
                    marble.giantPiercing = false
                else
                    -- v0.13.55「动能穿刺」：加速车带穿透次数时不反弹，直接吃下这一块并继续飞行。
                    -- 位置沿速度方向前推约 0.75 格，避免下一帧仍卡在同一砖内重复结算。
                    local pierced = false
                    if marble.ballType == "speed" and (marble.pierceLeft or 0) > 0 then
                        marble.pierceLeft = marble.pierceLeft - 1
                        marble.ignoredBrick = brick
                        frameHitBricks[brick] = true
                        DamageBrick(enemy, brick, GetMarbleDamage(marble, def))
                        local vlen = math.sqrt(marble.vx * marble.vx + marble.vy * marble.vy)
                        if vlen > 0.001 then
                            local push = enemy.brickSize * 0.75
                            marble.x = marble.x + marble.vx / vlen * push
                            marble.y = marble.y + marble.vy / vlen * push
                        end
                        pierced = true
                        Emit("speed_pierce", { id = marble.id, x = marble.x, y = marble.y,
                            remaining = marble.pierceLeft })
                    end
                    -- v0.13.58：附魔「穿透」——任意车型都能带穿透次数，不反弹、连续吃块。
                    if not pierced and (marble.enchantPierce or 0) > 0 then
                        marble.enchantPierce = marble.enchantPierce - 1
                        marble.ignoredBrick = brick
                        frameHitBricks[brick] = true
                        DamageBrick(enemy, brick, GetMarbleDamage(marble, def))
                        local vlen = math.sqrt(marble.vx * marble.vx + marble.vy * marble.vy)
                        if vlen > 0.001 then
                            local push = enemy.brickSize * 0.75
                            marble.x = marble.x + marble.vx / vlen * push
                            marble.y = marble.y + marble.vy / vlen * push
                        end
                        pierced = true
                        Emit("enchant_pierce", { id = marble.id, x = marble.x, y = marble.y,
                            remaining = marble.enchantPierce })
                    end
                    if not pierced then
                        local resolved = CollideBrick(marble, best.rx, best.ry, best.rw, best.rh)
                        if not resolved then
                            marble.x = prevX
                            marble.y = prevY
                            resolved = CollideBrick(marble, best.rx, best.ry, best.rw, best.rh)
                        end
                        frameHitBricks[brick] = true
                        DamageBrick(enemy, brick, GetMarbleDamage(marble, def))
                    end
                end

                if marble.ballType == "speed" then
                    BoostSpeedMarble(marble)
                end
                if def.freezeDuration then enemy.frozen = def.freezeDuration + BALL_TUNING.iceBonus end

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
                    ArmGiantPiercing(marble)
                end

                -- v0.13.58：附魔卡命中效果（全部落在机制上，与词条/弹种效果相互独立）。
                local enchant = marble.enchant
                if enchant then
                    if enchant.healPerHit and baseHp < GetMaxBaseHp() then
                        baseHp = math.min(GetMaxBaseHp(), baseHp + enchant.healPerHit)
                        Emit("enchant_lifesteal", { x = marble.x, y = marble.y,
                            amount = enchant.healPerHit })
                    end
                    if enchant.freezeAll and not marble.enchantFrozen then
                        marble.enchantFrozen = true
                        for _, other in ipairs(veggies) do
                            if not other.dead then
                                other.frozen = enchant.freezeAll
                                other.freezeRatio = 1
                            end
                        end
                    end
                    if enchant.chain then
                        local target = FindNearestBrick(enemy, brick, marble.x, marble.y)
                        if target then
                            Emit("enchant_chain", { x = marble.x, y = marble.y,
                                targetX = target.x, targetY = target.y,
                                damage = GetMarbleDamage(marble, def) })
                        end
                    end
                    if enchant.explodeRadius then
                        local radius = enemy.brickSize * enchant.explodeRadius
                        local radiusSq = radius * radius
                        local cx = enemy.x + (brick.col - 0.5) * enemy.brickSize
                        local cy = enemy.y + (brick.row - 0.5) * enemy.brickSize
                        for _, other in ipairs(veggies) do
                            if not other.dead then
                                for _, otherBrick in ipairs(other.bricks) do
                                    if otherBrick.alive and not otherBrick.ejected
                                        and otherBrick ~= brick and not frameHitBricks[otherBrick] then
                                        local bx = other.x + (otherBrick.col - 0.5) * other.brickSize
                                        local by = other.y + (otherBrick.row - 0.5) * other.brickSize
                                        local ddx, ddy = bx - cx, by - cy
                                        if ddx * ddx + ddy * ddy <= radiusSq then
                                            frameHitBricks[otherBrick] = true
                                            DamageBrick(other, otherBrick,
                                                GetMarbleDamage(marble, def) * 0.6)
                                        end
                                    end
                                end
                            end
                        end
                        Emit("enchant_explode", { x = cx, y = cy, radius = radius })
                    end
                    if enchant.splitOnHit then
                        local room = Game._NormalMarbleSlots(pendingMarbles)
                        for _ = 1, math.min(enchant.splitOnHit, room) do
                            local angle = -18 + Random() * 36
                            table.insert(pendingMarbles, CreateSplitMarble(marble, angle, brick))
                        end
                        Emit("enchant_split", { x = marble.x, y = marble.y })
                    end
                    if enchant.homing then
                        local target = FindNearestBrick(enemy, brick, marble.x, marble.y)
                        if target then
                            local dx, dy = target.x - marble.x, target.y - marble.y
                            local d = math.sqrt(dx * dx + dy * dy)
                            if d > 0.001 then
                                local sp = math.sqrt(marble.vx * marble.vx + marble.vy * marble.vy)
                                marble.vx = dx / d * sp
                                marble.vy = dy / d * sp
                                Emit("enchant_homing", { x = marble.x, y = marble.y,
                                    targetX = target.x, targetY = target.y })
                            end
                        end
                    end
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

        if marble.alive and marble.flightTime >= MAX_MARBLE_FLIGHT_TIME then
            marble.alive = false
            print("[Game][perf] expired marble id=" .. tostring(marble.id)
                .. " flight=" .. string.format("%.1f", marble.flightTime))
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
                a.baseX = a.x - (a.drift or math.sin(a.phase) * a.swayAmp)
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
            enemy.baseX = enemy.x - (enemy.drift or math.sin(enemy.phase) * enemy.swayAmp)
        end
    end
end

local function SummonBossEscort(boss)
    local def = AircraftData[boss.aircraftKey]
    local key = def and def.summonKey or "scout"
    local data = AircraftData[key]
    if not data then return false end
    local brickSize = GetBrickSize(wave)
    local shipW, shipH = GetAircraftSize(key, brickSize)
    local side = (boss.summonCount % 2 == 0) and -1 or 1
    local x = math.max(10, math.min(DW - shipW - 10,
        boss.x + boss.gridW * boss.brickSize * 0.5 + side * (boss.gridW * boss.brickSize * 0.5 + shipW * 0.6)
            - shipW * 0.5))
    local y = math.min(-102 - shipH - 24, boss.y - shipH - 16)
    local attempts = 0
    while FleetPositionOccupied(x, y, shipW, shipH, {}) and attempts < 50 do
        y = y - shipH - ENEMY_SPACING
        attempts = attempts + 1
    end
    if attempts >= 50 then return false end
    local enemy = CreateEnemy(key, x, y, brickSize,
        StageCatalog.GetBrickHp(stage, "normal"),
        StageCatalog.GetBaseSpeed(stage, stageWave), {phase = 0})
    if not enemy then return false end
    enemy.summonedBy = boss.id
    veggies[#veggies + 1] = enemy
    boss.summonCount = boss.summonCount + 1
    Emit("boss_summoned", {enemyId = boss.id, summonedId = enemy.id,
        aircraftKey = key, count = boss.summonCount})
    print("[Game] boss " .. boss.aircraftKey .. " summoned " .. key
        .. " " .. boss.summonCount .. "/" .. StageCatalog.GetBossSummonLimit(stage))
    return true
end

UpdateEnemies = function(dt)
    -- 先用固定长度遍历本帧已有编队，召唤机延后一帧进入更新。
    local existingCount = #veggies
    for i = existingCount, 1, -1 do
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

        if enemy.isBoss then
            local aliveCount = 0
            for _, brick in ipairs(enemy.bricks) do
                if brick.alive then aliveCount = aliveCount + 1 end
            end
            local ratio = aliveCount / math.max(1, #enemy.bricks)
            local newPhase = ratio > 0.66 and 1 or (ratio > 0.33 and 2 or 3)
            if newPhase ~= enemy.bossPhase then
                enemy.bossPhase = newPhase
                enemy.vulnerable = (newPhase == 2)
                Emit("boss_phase", {enemyId = enemy.id, phase = newPhase, vulnerable = enemy.vulnerable})
            end
            -- 召唤名额包含普通波余留编队，硬上限避免后期手机被机群压垮。
            enemy.summonTimer = enemy.summonTimer - dt
            if enemy.summonTimer <= 0 then
                enemy.summonTimer = StageCatalog.GetBossSummonInterval(stage)
                if aliveCount > 0 and #veggies < StageCatalog.MAX_FLEET
                    and enemy.summonCount < StageCatalog.GetBossSummonLimit(stage) then
                    SummonBossEscort(enemy)
                end
            end
        end

        enemy.phase = enemy.phase + dt * enemy.swayFreq
        local drift = math.sin(enemy.phase) * enemy.swayAmp
        if enemy.isElite then
            local beh = AircraftData.behavior[enemy.aircraftKey]
            local dodge = beh.dodge or {}
            local t = enemy.phase
            -- 双频波与方波/折返组合，位置连续；仅在水平方向做不稳定漂移。
            if dodge.kind == "zigzag" then
                drift = drift + (2 / math.pi) * (dodge.amp or 12)
                    * math.asin(math.sin(t * (dodge.freq or 2)))
            elseif dodge.kind == "lurch" then
                drift = drift + (dodge.amp or 12) * math.sin(t * (dodge.freq or 2)) ^ 3
            elseif dodge.kind == "orbit" then
                drift = drift + (dodge.amp or 12) * math.sin(t * (dodge.freq or 2))
                    * math.cos(t * 0.4)
            else
                drift = drift + (dodge.amp or 12) * math.sin(t * (dodge.freq or 2))
            end
            -- 纵向瞬时速度 0.75～1.05 × 普通机；均值不超过 1.1 倍。
            enemy.y = enemy.y + math.min(enemy.normalVy * 1.1,
                enemy.vy * (0.90 + 0.15 * math.sin(t * 1.9))) * speedMultiplier * dt
        else
            enemy.y = enemy.y + enemy.vy * speedMultiplier * dt
        end
        enemy.x = enemy.baseX + drift
        enemy.drift = drift
        if enemy.x < 10 then
            enemy.baseX = 10 + (enemy.baseX - enemy.x)
            enemy.x = 10
        elseif enemy.x + width > DW - 10 then
            enemy.baseX = DW - 10 - width - ((enemy.x + width) - (DW - 10))
            enemy.x = DW - 10 - width
        end
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

        local bossBreachedThisFrame = false
        for row, list in pairs(rows) do
            -- 该行方块全部碎裂（独立飞散箱体），视觉反馈取该行中心。
            local sumX = 0
            enemy.breached = true
            if enemy.isBoss then bossBreachedThisFrame = true end
            for _, brick in ipairs(list) do
                ShatterBreachedBrick(enemy, brick)
                sumX = sumX + enemy.x + (brick.col - 0.5) * enemy.brickSize
            end
            local rowCenterX = sumX / #list
            local rowY = enemy.y + (row - 0.5) * enemy.brickSize
            breachedRows[#breachedRows + 1] = {x = rowCenterX, y = DANGER_Y, rowY = rowY}
        end
        if bossBreachedThisFrame and IsEnemyCleared(enemy) then
            enemy.escaped = true
        end
    end

    -- 每行基础伤害 0.5 向上取整（=每行 1）；加成只在整体合计后附加一次，最终不低于 1。
    if #breachedRows > 0 and gameState ~= "gameover" then
        local baseDamage = math.ceil(#breachedRows * BRICK_BASE_DAMAGE)
        -- v0.13.28：「装甲强化」由固定 -1 改为**百分比减伤**——旧 -1 在单行越线（伤害被钳成 1）时完全无效；
        -- 百分比对单行也生效（1 行 × 20% 四舍五入为 0，故再用 max(1,…) 保住下限 1，不多减）。
        local mitigated = baseDamage + BALL_TUNING.lineDamageBonus
        if BALL_TUNING.armorReduce > 0 then
            mitigated = math.floor(mitigated * (1 - BALL_TUNING.armorReduce) + 0.5)
        end
        local totalDamage = math.max(1, mitigated)
        -- 护盾优先吸收，吸完还有剩才扣血。
        if baseShield > 0 then
            local absorbed = math.min(baseShield, totalDamage)
            baseShield = baseShield - absorbed
            totalDamage = totalDamage - absorbed
        end
        if totalDamage > 0 then baseHp = baseHp - totalDamage end
        -- 防线反馈：一条聚合事件（震屏/冲击波/飘字），碎裂方块的飞箱由各自事件呈现。
        local focus = breachedRows[1]
        Emit("base_hit", {x = focus.x, y = DANGER_Y, brick = true, damage = totalDamage, rows = #breachedRows})
        if baseHp <= 0 then
            baseHp = 0
            gameState = "gameover"
            Game.CancelHoldSpeed()
            aiming = false
            startArmed = false
            if score > highScore then highScore = score end
            Emit("game_over", {
                score = score, highScore = highScore, wave = wave,
                canRevive = not reviveUsed,
            })
            print("[Game] game over, score=" .. score .. ", wave=" .. wave
                .. ", canRevive=" .. tostring(not reviveUsed))
        end
    end

    -- 清空与移除：越线碎裂后整架飞机的砖块都没了则视为被突破清空（不加分）。
    for i = #veggies, 1, -1 do
        local enemy = veggies[i]
        local width = enemy.gridW * enemy.brickSize
        local height = enemy.gridH * enemy.brickSize
        if not enemy.dead and IsEnemyCleared(enemy) then
            enemy.dead = true
            -- Boss 仍可在受到部分越线伤害后被击败；只有最后存活格越线才算逃脱。
            if enemy.isBoss and not enemy.escaped then
                bossDefeated = true
                Emit("boss_defeated", {enemyId = enemy.id, stage = stage, aircraftKey = enemy.aircraftKey})
            end
            if not enemy.breached or (enemy.isBoss and bossDefeated) then
                score = score + 50
                partsEarned = partsEarned + PARTS_PER_CLEAR * (partsBoostTime > 0 and 2 or 1) * BALL_TUNING.partsMul
                runAircraft[enemy.aircraftKey] = true
                clearStreak = clearStreak + 1
                -- 连续清空的连击经验加成，鼓励连续压制。
                local bonus = math.min(clearStreak - 1, BALANCE.clearStreakBonusCap)
                GainXp(XP_PER_CLEAR + bonus)
                Emit("enemy_cleared", {
                    enemyId = enemy.id,
                    x = enemy.x + width * 0.5,
                    y = enemy.y + height * 0.5,
                    streak = clearStreak,
                    width = width, height = height,
                    -- 只描述消灭事实：越线损失过机体的击败不是完整击毁。
                    fullDestroyed = not enemy.breached,
                })
            end
        end

        if enemy.dead then table.remove(veggies, i) end
    end
end

UpdateReload = function()
    if not activeBall and #ballQueue > 0 then QueueNextBall() end
end

-- 通关评级（v0.13.4）：剩余防线血量决定星级；额外分数与零件奖励进结算。
-- 一星=险胜（<40%）、两星=优良（40~74%）、三星=完美（>=75%）。
local function ComputeStageResult()
    local ratio = baseHp / GetMaxBaseHp()
    local stars, rating
    if ratio >= 0.75 then stars, rating = 3, "完美"
    elseif ratio >= 0.40 then stars, rating = 2, "优良"
    else stars, rating = 1, "险胜" end
    return {
        stage = stage,
        stars = stars,
        rating = rating,
        bonusScore = 200 * stars,
        bonusParts = 50 * stars,
        -- v0.13.57：结算过渡动画的起始时刻（表现层据此算过渡进度）。
        -- 用全局 elapsed 而非新增变量，避免 Game 顶层 local 超限（AB-166）。
        animAt = elapsed,
    }
end

UpdateWaveLogic = function(dt)
    if gameState ~= "playing" or pendingLevelUps > 0 then return end

    if stageWave == StageCatalog.WAVES_PER_STAGE then
        local bossStillAlive = false
        for _, enemy in ipairs(veggies) do
            if enemy.isBoss and not enemy.dead and not IsEnemyCleared(enemy) then
                bossStillAlive = true
                break
            end
        end
        -- 首领逃脱只按现有越线规则扣血，不足以结束本局时重新派出同一首领。
        if not bossDefeated and not bossStillAlive then
            if baseHp <= 0 then return end
            nextWavePlan = PlanWave(wave)
            SpawnWave(StageCatalog.MAX_FLEET - #veggies)
            return
        end
        -- v0.13.4：首领击败即**结束本关并进入胜利结算态**（不再自动进下一关）。
        -- 残余护航与召唤机退场；星级由剩余防线血量决定，玩家看完结算后手动进关。
        if bossDefeated then
            stageResult = ComputeStageResult()
            score = score + stageResult.bonusScore
            partsEarned = partsEarned + stageResult.bonusParts * (partsBoostTime > 0 and 2 or 1) * BALL_TUNING.partsMul
            if score > highScore then highScore = score end
            nextWavePlan = nil
            aiming = false
            if activeBall then activeBall.x, activeBall.y = SLING_X, SLING_Y end
            for i = #veggies, 1, -1 do
                local enemy = veggies[i]
                Emit("enemy_withdrawn", {enemyId = enemy.id, aircraftKey = enemy.aircraftKey})
                table.remove(veggies, i)
            end
            gameState = "stagewin"
            Game.CancelHoldSpeed()
            Emit("stage_cleared", {
                stage = stage, wave = wave,
                stars = stageResult.stars, rating = stageResult.rating,
                bonusScore = stageResult.bonusScore, bonusParts = stageResult.bonusParts,
                baseHp = baseHp, maxBaseHp = GetMaxBaseHp(),
            })
            print("[Game] stage " .. stage .. " cleared: " .. stageResult.rating
                .. " " .. stageResult.stars .. "星")
        end
        return
    end

    EnsureNextWavePlan()
    waveCooldown = waveCooldown - dt
    if waveCooldown > 0 then return end

    local plan = nextWavePlan
    local requiredSlots = plan and (1 + (plan.escortCount or 0)) or 1
    local availableSlots = StageCatalog.MAX_FLEET - #veggies
    if availableSlots < requiredSlots then
        waveCooldown = 1
        return
    end
    -- v0.13.57：屏幕外敌机已达上限时**不开新一波**——精英/护航/首领不走 pendingSpawn 队列，
    -- 若不在此拦截，它们会在队列已堆满屏外时再叠一架，把屏外数顶到上限之上。
    -- ⚠️ 口径 = 屏外**在场**数 + 本波**待放**数：待放的普通机将来也会生成在屏外，
    --    只数在场会让「屏外2 + 队列还有1架」放行精英波后立刻顶到上限之上（本批踩到）。
    -- 计数内联（不新增顶层 local，AB-166），与 SpawnNextNormalEnemy 同口径。
    local offscreen = 0
    for i = 1, #veggies do
        local e = veggies[i]
        if not e.dead and e.y + e.gridH * e.brickSize < -102 then offscreen = offscreen + 1 end
    end
    if offscreen + pendingSpawn.remaining >= StageCatalog.MAX_OFFSCREEN then
        waveCooldown = 1
        return
    end

    stageWave = stageWave + 1
    wave = wave + 1
    partsEarned = partsEarned + PARTS_PER_WAVE * (partsBoostTime > 0 and 2 or 1) * BALL_TUNING.partsMul
    SpawnWave(availableSlots)
    waveCooldown = StageCatalog.GetInterval(stage, stageWave)
    EnsureNextWavePlan()
    -- v0.13.58：每完成一波发放/更换一张附魔卡（高波次更容易出高稀有度）。
    -- 放在波次真正推进处（stageWave 已 +1），不在 Boss 重派/开波失败路径触发。
    GrantEnchant()
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
    highScore = math.max(0, math.floor(tonumber(config.highScore) or 0))
    previousHighScore = highScore
    ResetGame()
    pendingEvents = {}
    gameState = "menu"
    print("[Game] core initialized at " .. DW .. "x" .. DH
        .. " highScore=" .. tostring(highScore))
end

---@param dt number 规则时间（已叠加顿帧）
---@param inputDt number|nil 原始输入时间；不传时使用 dt
function Game.Update(dt, inputDt)
    elapsed = elapsed + dt
    if gameState ~= "playing" then
        if Game._holdSpeed.down or Game._holdSpeed.active then Game.CancelHoldSpeed() end
        -- 非战斗态只保留时钟，供暂停/升级/菜单表现动画使用。
        return
    end

    -- v0.13.24：进关准备期内冻结玩法（只推进计时器），动画放行给表现层。
    if introTimer > 0 then
        if Game._holdSpeed.down or Game._holdSpeed.active then Game.CancelHoldSpeed() end
        introTimer = math.max(0, introTimer - dt)
        if introTimer > 0 then return end
        SpawnWave()
        waveCooldown = StageCatalog.GetInterval(stage, stageWave)
    end

    if Game._holdSpeed.down and not Game._holdSpeed.active then
        if not Game.CanHoldSpeed() then
            Game.CancelHoldSpeed()
        else
            Game._holdSpeed.time = Game._holdSpeed.time + math.max(0, inputDt or dt)
            if Game._holdSpeed.time + 1e-9 >= Game._holdSpeed.threshold then
                Game._holdSpeed.active = true
                print("[Game] empty-hand hold -> 2x")
            end
        end
    end
    -- elapsed、准备动画只推进原始规则时间；其余战斗计时统一使用模拟时间。
    -- 已开启后不因补车退出，只由松手、真实发射或生命周期取消。
    dt = dt * (Game._holdSpeed.active and 2 or 1)
    UpdateAiming()
    partsBoostTime = math.max(0, partsBoostTime - dt)
    UpdateMarbles(dt)
    if gameState ~= "playing" then return end
    UpdateEnemies(dt)
    if gameState ~= "playing" then return end
    -- v0.13.26：同波错峰生成——本波还没放完时按间隔逐架放出（精英护航同机制）。
    if pendingSpawn.remaining > 0 then
        pendingSpawn.timer = pendingSpawn.timer - dt
        if pendingSpawn.timer <= 0 then
            SpawnNextNormalEnemy()
            if gameState ~= "playing" then return end
        end
    end
    UpdateReload()
    UpdateWaveLogic(dt)
end

function Game.IsLevelUp()
    return gameState == "levelup"
end

function Game.PointerDown(px, py)
    if gameState == "menu" then
        -- v0.13.4：菜单不再直接开局——开始按钮由编排层路由到选关界面，
        -- 玩法层在菜单态不接收任何指针输入。
        return
    end
    if gameState == "gameover" or gameState == "stagewin" then
        -- 结算/胜利页按钮由编排层按 UI 几何分发，规则层不接收玩法 PointerDown。
        return
    end
    startArmed = false
    -- v0.10.24：移动端无键盘，暂停态点按任意处恢复（桌面端仍可用 P/ESC）。
    if gameState == "paused" then
        Game.Resume()
        return
    end
    if gameState ~= "playing" then return end

    -- 空手起手只武装长按；补车后本次手势不会自动转为拉弓或发射。
    if not activeBall then
        if Game.CanHoldSpeed() then
            Game._holdSpeed.down = true
            Game._holdSpeed.time = 0
        end
        return
    end
    if introTimer > 0 then return end

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
    -- 空手手势没有 aiming，也必须在任何早退之前恢复原速。
    Game.CancelHoldSpeed()
    -- v0.10.24：菜单在松手确认时才开局。结算页按钮由编排层分发。
    if gameState == "menu" then
        if startArmed then
            startArmed = false
            StartGame()
        end
        return
    end
    if gameState == "gameover" or gameState == "stagewin" then
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
    if not pressed then return end
    if action == "start" and gameState == "menu" then
        StartGame()
    elseif action == "restart" and gameState == "gameover" then
        StartGameAt(stage)
    end
end

-- 选关界面确认后由编排层直接调用；stageNumber 已按解锁进度校验。
function Game.StartStageAt(stageNumber)
    if gameState ~= "menu" then return false end
    StartGameAt(math.max(1, math.floor(tonumber(stageNumber) or 1)))
    return true
end

-- 胜利结算页「再战本关」：重开当前关（保留已解锁进度，成长重置）。
function Game.RetryStage()
    if gameState ~= "stagewin" or not stageResult then return false end
    StartGameAt(stageResult.stage)
    return true
end

-- 胜利结算页「下一关」：仅当下一关存在时有效。
function Game.NextStage()
    if gameState ~= "stagewin" or not stageResult then return false end
    local nextStage = stageResult.stage + 1
    -- v0.13.13：关卡无限，「下一关」永远可用。
    StartGameAt(nextStage)
    return true
end

function Game.IsGameOver()
    return gameState == "gameover"
end

function Game.IsStageWin()
    return gameState == "stagewin"
end

function Game.CanRevive()
    return gameState == "gameover" and not reviveUsed
end

-- 激励视频看完后由编排层调用：回 50 血、把仍存活的编队抬回屏外，继续本局。
function Game.ReviveFromAd()
    if gameState ~= "gameover" or reviveUsed then return false end
    reviveUsed = true
    Game.CancelPointer()
    baseHp = REVIVE_HP
    aiming = false
    startArmed = false
    local spawnY = -102
    local bossAlive = false
    for _, enemy in ipairs(veggies) do
        if enemy.isBoss and not enemy.dead and not IsEnemyCleared(enemy) then
            bossAlive = true
        end
        if not enemy.dead then
            local height = enemy.gridH * enemy.brickSize
            enemy.y = spawnY - height - 24
        end
    end
    gameState = "playing"
    -- 首领在越线导致生命归零的帧消失时，复活后补齐当前十波的目标。
    if stageWave == StageCatalog.WAVES_PER_STAGE and not bossDefeated and not bossAlive then
        for i = #veggies, 1, -1 do
            if veggies[i].isBoss then table.remove(veggies, i) end
        end
        nextWavePlan = PlanWave(wave)
        SpawnWave(StageCatalog.MAX_FLEET - #veggies)
    end
    -- 保留本局已结算基线；复活后再次死亡只入库新增零件。
    partsSettled = false
    lastSettledParts = 0
    Emit("base_revived", {hp = baseHp})
    print("[Game] revived from ad, hp=" .. tostring(baseHp))
    return true
end

function Game.RestartFromOver()
    if gameState ~= "gameover" then return end
    StartGame()
end

-- ============================================================================
-- v0.11.0 商业化：局内零件结算。
-- 结算页一出现就由编排层按 ×1 入库；「看广告双倍」再补发等额零件。
-- ============================================================================

---@return integer 当前阶段待结算或已结算的零件
function Game.GetRunParts()
    if partsSettled then return lastSettledParts end
    -- v0.13.28：partsEarned 可能因「装甲强化」的 partsMul 而是浮点；展示/入库一律取整。
    return math.floor(math.max(0, partsEarned - settledParts))
end

-- 跨局统计只认增量；复活后再次死亡不重复计「完成一局」与旧砖块。
-- 胜利结算（stagewin）同样入库零件与统计。
function Game.TakeSettlementStats()
    if (gameState ~= "gameover" and gameState ~= "stagewin") or partsSettled then return 0, false, 0 end
    local delta = math.max(0, bricksBroken - settleBook.bricks)
    settleBook.bricks = bricksBroken
    local firstFinish = not settleBook.runCounted
    settleBook.runCounted = true
    -- v0.14.x 存钱罐：只回传本局新增齿轮（复活后再次结算不重复计旧值）。
    local gearDelta = math.max(0, settleBook.gear - settleBook.gearSettled)
    settleBook.gearSettled = settleBook.gear
    return delta, firstFinish, gearDelta
end

---@param multiplier integer
---@return integer granted 本次入库的新增零件（0 表示没有新增）
function Game.SettleParts(multiplier)
    if partsSettled then return 0 end
    partsSettled = true
    -- v0.13.28：先取整到整数再算百分比加成，避免 partsMul 的浮点渗进入库值。
    local delta = math.floor(math.max(0, partsEarned - settledParts))
    settledParts = partsEarned
    -- v0.13.5：天赋树通用线路的结算零件百分比加成（在广告倍数前叠加）。
    local pctBonus = math.floor(delta * talentPartsPct / 100 + 0.5)
    delta = delta + pctBonus
    lastSettledParts = delta * math.max(1, math.floor(multiplier or 1))
    if multiplier and multiplier > 1 then partsDoubled = true end
    print("[Game] parts settled: +" .. lastSettledParts .. " (pctBonus=" .. pctBonus .. ")")
    return lastSettledParts
end

---@return boolean
function Game.CanDoubleSettle()
    return partsSettled and not partsDoubled and lastSettledParts > 0
end

---@return integer extra 广告双倍补发的零件数（0 表示不可用）
function Game.DoubleSettlement()
    if not Game.CanDoubleSettle() then return 0 end
    partsDoubled = true
    Emit("settle_doubled", {amount = lastSettledParts})
    print("[Game] settlement doubled: +" .. lastSettledParts)
    return lastSettledParts
end

function Game.ApplyCloudHighScore(value)
    local n = math.max(0, math.floor(tonumber(value) or 0))
    if n > highScore then
        highScore = n
        print("[Game] cloud highScore applied=" .. tostring(highScore))
    end
    return highScore
end

function Game.Pause()
    if gameState == "playing" then
        Game.CancelPointer()
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

-- v0.12.5：主动回主菜单（暂停页「返回主菜单」/ 结算页「回主菜单」出口）。
-- 升级态必须先选完卡（面板是强制三选一），不走这里。
function Game.GoToMenu()
    if gameState == "playing" or gameState == "paused" or gameState == "gameover"
        or gameState == "stagewin" then
        Game.CancelPointer()
        gameState = "menu"
        Emit("game_reset")
        print("[Game] returned to menu")
        return true
    end
    return false
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
    s.newRecord = (gameState == "gameover" or gameState == "stagewin")
        and score > previousHighScore and score > 0
    s.baseHp = baseHp
    s.maxBaseHp = GetMaxBaseHp()
    s.talentHpBonus = talentMaxHpBonus
    s.talentPartsPct = talentPartsPct
    -- v0.13.15：成长线天赋读数（供 UI 显示暴击率/基础攻击）。
    s.talentCritChance = talentCritChance
    s.talentAtkBonus = talentAtkBonus
    s.talentHpPerNode = TalentCatalog.MAX_HP_PER_NODE
    s.wave = wave
    s.stage = stage
    s.stageWave = stageWave
    s.wavesPerStage = StageCatalog.WAVES_PER_STAGE
    s.stageSubtitle = StageCatalog.GetLayoutSubtitle(stage)
    s.stageResult = stageResult
    -- v0.13.13：关卡无限——永远有下一关；stageTotal 只是「难度封顶参考关数」。
    s.stageHasNext = (gameState == "stagewin" and stageResult ~= nil) or false
    s.stageTotal = StageCatalog.STAGE_SOFT_CAP
    s.elapsed = elapsed
    s.timeScale = gameState == "playing" and Game._holdSpeed.active and 2 or 1
    s.canHoldSpeed = Game.CanHoldSpeed()
    s.holdSpeedPending = Game._holdSpeed.down and not Game._holdSpeed.active
    s.pointerEpoch = Game._holdSpeed.epoch
    s.playerLevel = playerLevel
    s.xp = xp
    s.xpToNext = xpToNext
    s.pendingLevelUps = pendingLevelUps
    s.upgradePicks = upgradePicks
    s.clearStreak = clearStreak
    s.bricksBroken = bricksBroken
    -- v0.14.x 存钱罐：本局累计齿轮（200 块/100 齿轮，精英机每块 2 倍）；只读标量。
    s.gear = settleBook.gear
    s.concurrentCount = #veggies    -- WO-12/P6：当前同屏编队数（HUD 指标）
    -- 当前关卡格子尺寸（14/15/16）：权威值，供表现层按「格」偏移，波间隙无敌机时也可用。
    s.brickSize = GetBrickSize(wave)
    s.brickDmg = math.max(1, math.ceil(BRICK_BASE_DAMAGE) + BALL_TUNING.lineDamageBonus)
    -- v0.13.28：局内通用卡的派生读数（只读标量，供 UI 与校验；不新建 table 以免每帧 GC）。
    s.brickXpFlat = BALL_TUNING.brickXpFlat
    s.partsMul = BALL_TUNING.partsMul
    s.armorReduce = BALL_TUNING.armorReduce
    s.launchSpeedMul = BALL_TUNING.launchSpeedMul
    -- P11：已激活词条（只读列表，供 HUD 展示，不反向写规则）。
    local words = {}
    for _, id in ipairs(WORD_IDS) do
        if activeWords[id] then words[#words + 1] = id end
    end
    s.activeWords = words
    s.upgradeChoices = Game.GetUpgradeChoices()
    s.veggies = veggies
    s.marbles = marbles
    s.aiming = aiming
    -- v0.11.4：新手下拉提示只在「本局还没发射过、也没正在拖拽」时显示。
    s.showPullHint = (gameState == "playing") and (not hasLaunched) and (not aiming)
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
    s.unlockedBalls = unlockedBalls
    -- v0.12.15：本局弹药总量（1 辆待发 + 备弹），供「弹药扩容」展示与校验。
    s.ammoCapacity = ammoCapacity
    s.width = DW
    s.height = DH
    s.dangerY = DANGER_Y
    s.topBound = TOP_BOUND_Y
    -- v0.10.31：下一波预告只读计划，渲染层画小图，不反向写规则。
    s.nextWave = (gameState == "playing") and nextWavePlan or nil
    s.waveCooldown = waveCooldown
    -- v0.13.24：进关准备期剩余秒数（渲染层画过渡/准备界面；>0 = 未开战）
    s.introTimer = introTimer
    s.introTotal = INTRO_SECONDS
    s.canRevive = (gameState == "gameover") and not reviveUsed
    s.reviveUsed = reviveUsed
    -- v0.11.0 商业化：局内零件与升级面板变现状态（渲染层只读）。
    s.partsEarned = math.floor(partsEarned)
    local aircraftList = {}
    for key in pairs(runAircraft) do aircraftList[#aircraftList + 1] = key end
    s.runAircraft = aircraftList
    s.runParts = Game.GetRunParts()
    s.partsSettled = partsSettled
    s.partsDoubled = partsDoubled
    s.canDoubleSettle = Game.CanDoubleSettle()
    s.rerollFreeAvailable = Game.CanFreeReroll()
    -- 暂停补给站（只读，供暂停面板画按钮）
    s.canPauseHeal = Game.CanPauseHeal()
    s.pauseHealLeft = Game.GetPauseHealLeft()
    s.canPauseRarePick = Game.CanPauseRarePick()
    s.pauseRareLeft = Game.GetPauseRareLeft()
    s.canPauseOrbital = Game.CanPauseOrbital()
    s.canPauseReload = Game.CanPauseReload()
    s.canPausePartsBoost = Game.CanPausePartsBoost()
    s.partsBoostTime = partsBoostTime
    -- 局内道具槽（渲染层只读）：每格 {key,name,color,charges,canGrant,usedThisRun}
    -- usedThisRun 供渲染层用「精灵变暗 + 角标」表达「本局已用过」，不写文字。
    local items = {}
    for i = 1, #ITEM_DEFS do
        local def = ITEM_DEFS[i]
        items[i] = {
            key = def.key, name = def.name, color = def.color,
            charges = itemCharges[def.key] or 0,
            canGrant = Game.CanGrantItem(def.key),
            usedThisRun = itemUsedThisRun[def.key] == true,
        }
    end
    s.items = items
    s.baseShield = baseShield
    -- v0.13.58：附魔卡只读快照（左上角展示）。card=在手，pending=已顺延给下一辆待发车。
    -- 只在有卡/有顺延时新建小表，避免每帧 GC（无卡时置 nil）。
    local ecard, epend = Game._enchant.card, Game._enchant.pending
    s.enchantCard = ecard and {
        id = ecard.id, name = ecard.name, rarity = ecard.rarity, desc = ecard.desc,
    } or nil
    s.enchantPending = epend and { id = epend.id, name = epend.name, rarity = epend.rarity } or nil
    return s
end

return Game
