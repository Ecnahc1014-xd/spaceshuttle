-- MetaCatalog.lua
-- 元层静态目录（纯数据，无渲染、无存档副作用）：
-- 敌机图鉴文案、车辆车型、商城条目、转盘奖励。
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
    { key = "interceptor", name = "截击机",   note = "菱形快速截击单位，现归入普通编队。", reward = 320 },
    { key = "elite_hook", name = "钩翼", note = "不规则钩形突进，横摆突然折返。", reward = 340 },
    { key = "elite_fork", name = "双叉", note = "两侧叉翼错相摆动，难以预判。", reward = 340 },
    { key = "elite_razor", name = "斜刃", note = "单侧长刃沿折线路线穿梭。", reward = 350 },
    { key = "elite_spiral", name = "涡轮", note = "偏心旋翼交错画出螺旋轨迹。", reward = 350 },
    { key = "elite_anchor", name = "铁锚", note = "重装锚臂偶尔突然横移。", reward = 360 },
    { key = "elite_wisp", name = "流萤", note = "细长光带以快慢交替游移。", reward = 360 },
    { key = "elite_shear", name = "剪翼", note = "张开的剪刃在战场两侧往返。", reward = 370 },
    { key = "elite_bracket", name = "断环", note = "破裂环身随相位左右摇摆。", reward = 370 },
    { key = "elite_hammer", name = "重锤", note = "顶端宽、尾部窄的高压突进者。", reward = 380 },
    { key = "elite_rivet", name = "铆钉", note = "非对称铆接装甲摆出假动作。", reward = 380 },
    { key = "boss_orrery", name = "星环", note = "环形旗舰，定期召来蜂群小机。", reward = 600 },
    { key = "boss_maw", name = "噬口", note = "双颚舰体，定期召来飞镖机。", reward = 620 },
    { key = "boss_citadel", name = "堡垒", note = "厚重城墙型旗舰，召来侦察机。", reward = 650 },
    { key = "boss_prism", name = "棱镜", note = "中空菱镜旗舰，召来飞碟。", reward = 640 },
    { key = "boss_serpent", name = "蛇脊", note = "曲折脊骨旗舰，召来强袭机。", reward = 630 },
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
-- 六款车型沿用旧涂装 key，既有购买记录及首充礼包的 arctic 权益继续生效。
---@class SkinDef
---@field key string
---@field name string
---@field cost integer 0 表示默认拥有
---@field desc string
---@field silhouette string[] 俯视缩略图的五行轮廓

---@type SkinDef[]
local SKINS = {
    { key = "default", name = "平头重卡", cost = 0, desc = "三轴长货厢 · 默认车型",
      silhouette = {"..####..", ".######.", "########", ".######.", "..####.."} },
    { key = "arctic", name = "越野车", cost = 800, desc = "高车顶 · 双排宽轮",
      silhouette = {"..####..", ".######.", ".######.", ".######.", "..####.."} },
    { key = "crimson", name = "跑车", cost = 1500, desc = "低趴楔形 · 双轴尾翼",
      silhouette = {"...##...", "..####..", ".######.", ".######.", "..####.."} },
    { key = "jade", name = "厢式车", cost = 2200, desc = "方正高厢 · 双轴车身",
      silhouette = {"..####..", ".######.", ".######.", ".######.", ".######."} },
    { key = "obsidian", name = "装甲车", cost = 3200, desc = "厚重外甲 · 三轴底盘",
      silhouette = {"..####..", ".######.", "########", "########", "..####.."} },
    { key = "rally", name = "沙地越野车", cost = 4000, desc = "开放式防滚架 · 外露宽轮",
      silhouette = {"...##...", ".######.", "..####..", ".######.", "...##..."} },
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

-- ============================================================================
-- 商城：车辆车型使用软货币零件；广告礼包为主动观看激励视频后领取。

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
