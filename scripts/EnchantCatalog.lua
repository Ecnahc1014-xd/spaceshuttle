-- EnchantCatalog.lua
-- 局内「附魔卡」静态数据（v0.13.58）。
--
-- 玩法：每完成一波，玩家获得/更换一张附魔卡，显示在局内左上角（与右上道具竖列对称）。
-- 使用后卡片消失，效果作用在**预备发射的车**上；若当前没有待发车，则顺延给下一个
-- 预备发射的车。稀有度分蓝/紫/黄三档，波次越高越容易抽到高稀有度。
--
-- ⚠️ 本模块只描述数据与随机规则，不持有任何战斗状态（状态在 Game.lua）。
-- 每个效果都落在**机制**上（不是同一效果的数值大小），与项目「变体要换机制」的纪律一致。

local EnchantCatalog = {}

-- 稀有度：蓝(普通) / 紫(稀有) / 黄(史诗)。颜色供 UI 只读。
EnchantCatalog.RARITY_COLORS = {
    common = { 92, 150, 255 },
    rare   = { 176, 110, 255 },
    epic   = { 255, 196, 72 },
}
EnchantCatalog.RARITY_NAMES = {
    common = "普通",
    rare   = "稀有",
    epic   = "史诗",
}

---@class EnchantDef
---@field id string
---@field name string
---@field rarity string common|rare|epic
---@field desc string 一句话效果说明（UI 只读）
---@field damageMul number|nil 伤害倍率
---@field pierce integer|nil 可穿透的方块数（不反弹，任意车型）
---@field healPerHit integer|nil 每次命中回复的防线生命
---@field homing boolean|nil 命中后自动追向最近的方块
---@field chain boolean|nil 命中时向最近的另一块溅射伤害
---@field chainDamage number|nil 连锁溅射的伤害倍率（相对本次弹珠伤害）
---@field freezeAll number|nil 命中时冻结全场的秒数
---@field explodeRadius number|nil 命中时以命中格为中心的范围爆炸半径（格）
---@field explodeMul number|nil 爆炸伤害倍率（相对本次弹珠伤害）
---@field splitOnHit integer|nil 每次命中额外分裂的弹珠数
---@field tripleShot integer|nil 发射时额外扇形发射的同型车数量

---@type EnchantDef[]
EnchantCatalog.CARDS = {
    -- 蓝（普通）：轻量、常出，提供基础增益。⚠️ 低关卡砖块常 1~2 血，纯「伤害倍率」看不出差别
    --   （同 AB-172），所以蓝卡全走**覆盖/可见**方向（多打几块、追敌、回血）。
    { id = "split",     name = "裂变", rarity = "common", desc = "每次命中额外分裂 3 颗",
      splitOnHit = 3 },
    { id = "lifesteal", name = "吸血", rarity = "common", desc = "每次命中防线回 4 血",
      healPerHit = 4 },
    { id = "homing",    name = "追踪", rarity = "common", desc = "每次命中自动追向新目标",
      homing = true },
    -- 紫（稀有）：改变作用方式。
    { id = "pierce",    name = "穿透", rarity = "rare", desc = "穿透 8 块不反弹",
      pierce = 8 },
    { id = "chain",     name = "连锁", rarity = "rare", desc = "命中溅射附近 +2× 伤害",
      chain = true, chainDamage = 2.0 },
    { id = "freeze",    name = "霜冻", rarity = "rare", desc = "每次命中冻结全场 4 秒",
      freezeAll = 4.0 },
    -- 黄（史诗）：强力、稀有。
    -- 重击：低关卡伤害倍率不显眼，所以额外给穿透——一发贯穿一排，视觉上「一炮打穿」。
    { id = "power",     name = "重击", rarity = "epic", desc = "伤害 ×5 并穿透 4 块",
      damageMul = 5.0, pierce = 4 },
    { id = "explode",   name = "爆裂", rarity = "epic", desc = "命中大范围爆炸",
      explodeRadius = 3.5, explodeMul = 1.6 },
    { id = "triple",    name = "三连", rarity = "epic", desc = "发射扇形四连（4 车）",
      tripleShot = 3 },
}

local BY_ID = {}
for i = 1, #EnchantCatalog.CARDS do
    BY_ID[EnchantCatalog.CARDS[i].id] = EnchantCatalog.CARDS[i]
end

---@param id string|nil
---@return EnchantDef|nil
function EnchantCatalog.GetCard(id)
    if not id then return nil end
    return BY_ID[id]
end

-- 各稀有度在「第 wave 波」的抽取权重。波次越高，高稀有度权重越大。
-- wave=1 → 蓝 80% / 紫 18% / 黄 2%；wave=21+ → 蓝 25% / 紫 45% / 黄 30%。
local function RarityWeights(wave)
    local t = math.min(1, math.max(0, ((wave or 1) - 1) / 20))
    return {
        common = 0.80 - 0.55 * t,
        rare   = 0.18 + 0.27 * t,
        epic   = 0.02 + 0.28 * t,
    }
end

-- 抽取一张附魔卡。rng 为返回 [0,1) 的随机函数（Game 的确定性随机流）。
---@param wave integer
---@param rng fun(): number
---@return EnchantDef
function EnchantCatalog.Roll(wave, rng)
    local w = RarityWeights(wave)
    local total = w.common + w.rare + w.epic
    local r = rng() * total
    local rarity
    if r < w.common then rarity = "common"
    elseif r < w.common + w.rare then rarity = "rare"
    else rarity = "epic" end

    local pool = {}
    for i = 1, #EnchantCatalog.CARDS do
        if EnchantCatalog.CARDS[i].rarity == rarity then pool[#pool + 1] = EnchantCatalog.CARDS[i] end
    end
    if #pool == 0 then return EnchantCatalog.CARDS[1] --[[@as EnchantDef]] end
    return pool[math.min(#pool, math.floor(rng() * #pool) + 1)] --[[@as EnchantDef]]
end

return EnchantCatalog
