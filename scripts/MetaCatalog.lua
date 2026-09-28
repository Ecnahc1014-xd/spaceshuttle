-- MetaCatalog.lua
-- 元层静态目录（纯数据，无渲染、无存档副作用）：
-- 敌机图鉴文案、车辆皮肤、商城条目、转盘奖励。
-- 只被编排层（main.lua）与表现层（MetaUI.lua）读取。

local MetaCatalog = {}

-- ============================================================================
-- 敌机图鉴
-- ============================================================================

---@class CodexEntry
---@field key string
---@field name string
---@field note string 图鉴描述（一行短句）
---@field reward integer 首次收录奖励零件

---@type CodexEntry[]
local CODEX = {
    { key = "scout",       name = "侦察机",   note = "最基本的蟹形入侵者，成群出现。",   reward = 120 },
    { key = "dart",        name = "飞镖",     note = "后掠翼尖头，俯冲最快的机型。",     reward = 150 },
    { key = "striker",     name = "强袭机",   note = "箭头战机，直线压上不留余地。",     reward = 150 },
    { key = "hive",        name = "蜂群",     note = "最小的橙色小机，靠数量取胜。",     reward = 180 },
    { key = "manta",       name = "宽翼鳐鱼", note = "滑翔横摆，机翼最宽最难打空。",     reward = 200 },
    { key = "bomber",      name = "重型飞碟", note = "黄绿圆盘，缓慢但装甲深厚。",       reward = 220 },
    { key = "cruiser",     name = "重装巡洋舰", note = "钢灰盒体，血最厚推进最慢。",      reward = 260 },
    { key = "interceptor", name = "截击机",   note = "紫色精英，每十波的 Boss 形态。",   reward = 320 },
}

---@return CodexEntry[]
function MetaCatalog.GetCodex()
    return CODEX
end

---@return integer
function MetaCatalog.GetCodexTotal()
    return #CODEX
end

---@param key string
---@return CodexEntry|nil
function MetaCatalog.GetCodexEntry(key)
    for _, entry in ipairs(CODEX) do
        if entry.key == key then return entry end
    end
    return nil
end

-- ============================================================================
-- 车辆皮肤（程序化换色，不依赖外部贴图）
-- ============================================================================

---@class SkinDef
---@field key string
---@field name string
---@field cost integer 0 表示默认拥有
---@field paint table 主车漆 rgb
---@field panel table 浅色侧围 rgb

---@type SkinDef[]
local SKINS = {
    { key = "default", name = "出厂涂装", cost = 0,
      paint = {212, 176, 96},  panel = {236, 232, 220} },
    { key = "arctic",  name = "极地白",   cost = 800,
      paint = {214, 228, 238}, panel = {140, 176, 200} },
    { key = "crimson", name = "烈焰红",   cost = 1500,
      paint = {206, 72, 60},   panel = {244, 214, 190} },
    { key = "jade",    name = "翠玉青",   cost = 2200,
      paint = {54, 178, 156},  panel = {216, 240, 232} },
    { key = "obsidian", name = "玄铁黑",  cost = 3200,
      paint = {58, 62, 78},    panel = {150, 158, 176} },
}

---@return SkinDef[]
function MetaCatalog.GetSkins()
    return SKINS
end

---@param key string
---@return SkinDef|nil
function MetaCatalog.GetSkin(key)
    for _, skin in ipairs(SKINS) do
        if skin.key == key then return skin end
    end
    return nil
end

---@param key string
---@return table 三通道 rgb（缺失时回退出厂涂装）
function MetaCatalog.GetSkinPaint(key)
    local skin = MetaCatalog.GetSkin(key) or SKINS[1]
    return skin.paint
end

---@param key string
---@return table
function MetaCatalog.GetSkinPanel(key)
    local skin = MetaCatalog.GetSkin(key) or SKINS[1]
    return skin.panel
end

-- ============================================================================
-- 商城：车辆涂装使用软货币零件；广告礼包为主动观看激励视频后领取。

-- ============================================================================

---@class ShopEntry
---@field key string
---@field name string
---@field desc string
---@field cost integer 0 表示看广告免费领
---@field kind string "skin" | "ad_gift"

---@type ShopEntry[]
local SHOP = {
    { key = "ad_parts_small", name = "应急补给", desc = "看广告免费领 200 零件", cost = 0,   kind = "ad_gift" },
    { key = "ad_parts_large", name = "战备补给", desc = "看广告免费领 500 零件", cost = 0,   kind = "ad_gift" },
}

---@return ShopEntry[]
function MetaCatalog.GetShopEntries()
    return SHOP
end

---@param key string
---@return ShopEntry|nil
function MetaCatalog.GetShopEntry(key)
    for _, entry in ipairs(SHOP) do
        if entry.key == key then return entry end
    end
    return nil
end

-- 广告礼包每日限领次数（key -> 次数）。
---@param key string
---@return integer
function MetaCatalog.GetAdGiftDailyLimit(key)
    if key == "ad_parts_small" then return 1 end
    if key == "ad_parts_large" then return 1 end
    return 1
end

---@param key string
---@return integer
function MetaCatalog.GetAdGiftReward(key)
    if key == "ad_parts_small" then return 200 end
    if key == "ad_parts_large" then return 500 end
    return 0
end

-- ============================================================================
-- 幸运转盘（看广告免费转，每日一次）
-- ============================================================================

---@type integer[]
local WHEEL_PRIZES = { 120, 200, 320, 200, 480, 200, 320, 800 }

---@return integer[]
function MetaCatalog.GetWheelPrizes()
    return WHEEL_PRIZES
end

---@return integer
function MetaCatalog.RollWheelPrize()
    -- 低面额权重更高；所有画在转盘上的扇区都有非零概率。
    local weights = { 20, 17, 14, 17, 10, 14, 4, 4 }
    local total = 0
    for _, w in ipairs(weights) do total = total + w end
    local roll = math.random() * total
    for i, w in ipairs(weights) do
        roll = roll - w
        if roll <= 0 then return WHEEL_PRIZES[i] or 120 end
    end
    return WHEEL_PRIZES[1] or 120
end

-- ============================================================================
-- 每日补给（进入主菜单时弹出，看广告双倍）
-- ============================================================================

local DAILY_SUPPLY_BASE = 150

---@return integer
function MetaCatalog.GetDailySupplyBase()
    return DAILY_SUPPLY_BASE
end

return MetaCatalog
