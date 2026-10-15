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
---@field silhouette string[] 俯视缩略图的六行轮廓

---@type SkinDef[]
local SKINS = {
    { key = "default", name = "平头重卡", cost = 0, desc = "三轴长货厢 · 默认车型",
      silhouette = {".######.", "########", ".######.", ".######.", "########", ".######."} },
    { key = "arctic", name = "越野车", cost = 800, desc = "高车顶 · 双排宽轮",
      silhouette = {"..####..", "########", ".######.", ".######.", "########", "..####.."} },
    { key = "crimson", name = "跑车", cost = 1500, desc = "低趴楔形 · 双轴尾翼",
      silhouette = {"...##...", "..####..", ".######.", "########", ".######.", "..####.."} },
    { key = "jade", name = "厢式车", cost = 2200, desc = "方正高厢 · 双轴车身",
      silhouette = {".######.", "########", "########", "########", "########", ".######."} },
    { key = "obsidian", name = "装甲车", cost = 3200, desc = "厚重外甲 · 三轴底盘",
      silhouette = {"..####..", "########", ".######.", "########", "########", "..####.."} },
    { key = "rally", name = "沙地越野车", cost = 4000, desc = "开放式防滚架 · 外露宽轮",
      silhouette = {"...##...", "##.##.##", ".######.", ".######.", "##.##.##", "...##..."} },
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
-- 拖尾样式（车辆飞行光带）：与车型相互独立，可分别购买与装备。
-- style 决定 Renderer3D 如何生成光带几何；所有样式共用同一条已验证可见的
-- CustomGeometry + DiffVCol 路径，只改变形状/宽度/明暗，不改规则层。

---@class TrailDef
---@field key string
---@field name string
---@field cost integer 0 表示默认拥有
---@field desc string
---@field style string 几何样式：ribbon | comet | neon | dash | twin | ember

---@type TrailDef[]
local TRAILS = {
    { key = "classic", name = "经典尾焰", cost = 0, style = "ribbon",
      desc = "笔直渐细 · 默认样式" },
    { key = "comet",   name = "彗星",     cost = 600, style = "comet",
      desc = "密集粒子彗尾 · 头端灼核拖出光尘" },
    { key = "neon",    name = "霓虹",     cost = 1200, style = "neon",
      desc = "极细光丝 · 螺旋盘绕转品红" },
    { key = "dash",    name = "流光",     cost = 1800, style = "dash",
      desc = "离散光片 · 高速自旋飞散" },
    { key = "twin",    name = "双轨",     cost = 2600, style = "twin",
      desc = "两条光轨 · 蛇形摆动收拢" },
    { key = "ember",   name = "余烬",     cost = 3600, style = "ember",
      desc = "宽幅暖烟 · 漂移明灭" },
}

---@return TrailDef[]
function MetaCatalog.GetTrails()
    return TRAILS
end

---@param key string
---@return TrailDef|nil
function MetaCatalog.GetTrail(key)
    for _, trail in ipairs(TRAILS) do
        if trail.key == key then return trail end
    end
    return nil
end

---@param key string
---@return string
function MetaCatalog.GetTrailStyle(key)
    local trail = MetaCatalog.GetTrail(key)
    return trail and trail.style or "ribbon"
end

-- 拖尾几何参数（纯数据，供 Renderer3D 生成 3D 光带、MetaUI 绘制 2D 预览）：
--   headW/tailW：头/尾半宽（× **车体真实半宽** vHalf；1.0 = 与车体同宽）
--   bright：整体亮度倍率；base：尾部色阶下限（避免尾端纯黑）
--   twin：1=左右双轨；warm：1=向暖色偏移（余烬）
-- 机制轴（每种样式至少在一轴上不同，避免退化成同一条光带的数值微调，见 AB-221）：
--   taper：宽度曲线指数（1=线性；<1 头段更饱满；>1 尾段收束更急）
--   bulge：头端鼓包强度（0=无；头段额外加宽成「实心亮核」）
--   hue：沿长度色相偏移（0=无；尾端向品红游移，霓虹用）
--   waver/waverLen/waverDrift：中线横向正弦波动（幅度×vHalf / 波长(米) / 相位漂移(弧度/秒)）
--     → 让光带不再是一条直线（「可以抛弃线性」）
--   flicker/flickerFreq：逐段明暗噪声幅度 / 频率（空间锚定、非周期，替代等间隔断点）
--   pulse：整体明暗脉动强度（0=无；余火明灭）
--   railSpread/railTaper：双轨头端间距（×headW）与沿长度收拢指数（双轨用）
--   glow/core：外层柔光 / 内层亮芯宽度倍率
--   twist：截面绕切线的扭转（弧度/采样点；0=平带，>0=真实三维螺旋）
---@class TrailStyleParams
---@field headW number
---@field tailW number
---@field bright number
---@field base number
---@field twin integer
---@field warm integer
---@field taper number
---@field bulge number
---@field hue number
---@field waver number
---@field waverLen number
---@field waverDrift number
---@field flicker number
---@field flickerFreq number
---@field pulse number
---@field railSpread number
---@field railTaper number
---@field glow number
---@field core number
---@field twist number
---@field particle integer|nil
---@field emit number|nil
---@field emitSpread number|nil
---@field pSize number|nil
---@field pGrow number|nil
---@field pJitter number|nil
---@field pSpin number|nil
---@field pDrift number|nil
---@field pLife number|nil

---@type table<string, TrailStyleParams>
-- ⚠️ 宽度基准是**车体真实半宽**（`vHalf = radius*WORLD_SCALE*0.5965`，见 Renderer3D），
-- 不再是碰撞半径——碰撞半径比车体宽 2.6 倍，用它当上限会让尾迹粗过车（用户报「比车还粗」）。
-- 所有 width/offset 字段都是 `vHalf` 的**倍数**：headW=0.6 表示头半宽 = 车体半宽的 60%。
-- 机制轴（每样式占不同的轴，禁止只在同一轴上调数值，见 AB-221）：
--   taper：宽度曲线指数（<1 头段饱满、>1 尾段急收）
--   bulge：头端额外加宽倍率（实心亮核）
--   waver/waverLen/waverDrift：中线横向正弦波动（幅度×vHalf / 波长(米) / 相位漂移(弧度/秒)）
--     → 让光带**不再是一条直线**（用户「可以抛弃线性」）
--   flicker/flickerFreq：逐段明暗噪声幅度 / 频率（空间锚定、非周期，替代「等间隔断点」）
--   pulse：整体明暗脉动；hue：沿长度色相游移；twist：截面绕切线扭转（真三维螺旋）
--   twin/railSpread/railTaper：双轨（两条细轨 + 轨距收拢指数）
--   glow/core：柔光层 / 亮芯层宽度倍率
-- 🔴 粒子系（v0.13.58）：particle=1 时**不走三角带**，改为在采样轨迹上撒布 billboard 粒子
--   （见 Renderer3D.SyncTrailParticles）。粒子颜色**烘焙进纹理**——DiffAlpha 不读顶点 rgb
--   （本项目实测契约），故每种粒子样式一个专属纹理（`trailParticle` 键）。
--   emit：每米发射密度（个/米，按弧长均匀 → 速度无关、不随帧率抖）
--   emitSpread：发射点横向抖动（×vHalf）；pSize/pGrow：世界尺寸(×vHalf) / 沿寿命膨胀
--   pJitter：位置抖动(×vHalf)；pSpin：自旋(度/秒)；pLife：粒子寿命(秒)
--   pDrift：沿寿命的横向漂移(×vHalf)（彗尾散开 / 流光飞散）
local TRAIL_STYLE_PARAMS = {
    -- 经典：中性基准——笔直、平滑收细，无波动无噪声（其余样式的参照物）。
    ribbon = {headW = 0.55, tailW = 0.10, bright = 1.00, base = 0.30, twin = 0, warm = 0,
              taper = 1.0, bulge = 0.0, hue = 0.0, waver = 0.0, waverLen = 0.9, waverDrift = 0.0,
              flicker = 0.0, flickerFreq = 0.0, pulse = 0.0, railSpread = 1.35, railTaper = 1.0,
              glow = 1.55, core = 1.25, twist = 0.0},
    -- 彗星（粒子系）：**密集粒子彗尾**——沿轨迹高频撒布亮尘，头端一颗灼核，
    -- 粒子沿寿命横向散开并收缩成尾迹（不是一条光带）。
    comet  = {headW = 0.62, tailW = 0.30, bright = 1.15, base = 0.40, twin = 0, warm = 0,
              taper = 0.55, bulge = 1.1, hue = 0.0, waver = 0.06, waverLen = 0.7, waverDrift = 1.6,
              flicker = 0.55, flickerFreq = 9.0, pulse = 0.0, railSpread = 1.35, railTaper = 1.0,
              glow = 1.50, core = 1.90, twist = 0.0,
              particle = 1, emit = 60, emitSpread = 0.26, pSize = 0.42, pGrow = 0.80,
              pJitter = 0.30, pSpin = 0, pDrift = 0.55, pLife = 0.42},
    -- 霓虹：极细等宽带 + 截面绕切线**扭转成螺旋** + 沿长度青→品红。
    neon   = {headW = 0.20, tailW = 0.20, bright = 1.45, base = 0.66, twin = 0, warm = 0,
              taper = 1.0, bulge = 0.0, hue = 0.65, waver = 0.0, waverLen = 0.9, waverDrift = 0.0,
              flicker = 0.0, flickerFreq = 0.0, pulse = 0.0, railSpread = 1.35, railTaper = 1.0,
              glow = 1.60, core = 1.70, twist = 0.40},
    -- 流光（粒子系）：**离散光片**——低频、大颗、高速自旋，像被甩出的碎光片，
    -- 与「经典尾焰」的连续光带形态完全不同（用户点名「和普通的没区别」）。
    dash   = {headW = 0.44, tailW = 0.10, bright = 1.10, base = 0.28, twin = 0, warm = 0,
              taper = 1.3, bulge = 0.0, hue = 0.0, waver = 0.0, waverLen = 0.9, waverDrift = 0.0,
              flicker = 0.85, flickerFreq = 17.0, pulse = 0.0, railSpread = 1.35, railTaper = 1.0,
              glow = 1.30, core = 1.45, twist = 0.0,
              particle = 1, emit = 22, emitSpread = 0.28, pSize = 0.62, pGrow = 0.15,
              pJitter = 0.35, pSpin = 420, pDrift = 1.10, pLife = 0.40},
    -- 双轨：两条细轨 + 轨距收拢 + **整体蛇形波动**（编成一股会摆的辫）。
    twin   = {headW = 0.34, tailW = 0.06, bright = 1.05, base = 0.20, twin = 1, warm = 0,
              taper = 1.0, bulge = 0.0, hue = 0.0, waver = 0.22, waverLen = 1.1, waverDrift = 2.4,
              flicker = 0.0, flickerFreq = 0.0, pulse = 0.0, railSpread = 1.70, railTaper = 0.30,
              glow = 1.30, core = 1.70, twist = 0.0},
    -- 余烬：宽幅柔光 + 明灭脉动 + **缓慢漂移的烟状波动**（余火）。
    ember  = {headW = 0.78, tailW = 0.06, bright = 1.20, base = 0.22, twin = 0, warm = 1,
              taper = 1.7, bulge = 0.0, hue = 0.0, waver = 0.34, waverLen = 1.5, waverDrift = 1.1,
              flicker = 0.30, flickerFreq = 5.0, pulse = 0.34, railSpread = 1.35, railTaper = 1.0,
              glow = 1.25, core = 1.55, twist = 0.0},
}

---@param style string
---@return TrailStyleParams
function MetaCatalog.GetTrailStyleParams(style)
    return TRAIL_STYLE_PARAMS[style] or TRAIL_STYLE_PARAMS.ribbon
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

-- ============================================================================
-- 天赋 / 升级卡图标（v0.13.8）
-- 卡片 id → ICON_PATHS 键。升级卡与天赋树节点共用同一份映射，
-- 保证同一效果在两处视觉一致。未列出的 id 回退为按类型取通用图标。
-- ============================================================================

---@type table<string, string>
local TALENT_ICONS = {
    damage = "talent_damage",
    armor = "talent_armor",
    repair = "talent_repair",
    xp = "talent_xp",
    glass_cannon = "talent_glass",
    overclock = "talent_overclock",
    ammo = "talent_ammo",
    word_pierce = "talent_word",
    word_chain = "talent_word",
    word_momentum = "talent_word",
    unlock_ice = "talent_unlock",
    unlock_speed = "talent_unlock",
    unlock_giant = "talent_unlock",
    base_split = "ammo_normal",
    split = "ammo_normal",
    base_ice = "ammo_ice",
    ice = "ammo_ice",
    base_speed = "ammo_speed",
    speed = "ammo_speed",
    base_giant = "ammo_giant",
    giant = "ammo_giant",
}

-- 天赋树节点类型/线路的通用图标回退（节点 id 无精确映射时使用）。
---@type table<string, string>
local TALENT_KIND_ICONS = {
    cardUnlock = "talent_xp",
    ballUnlock = "talent_unlock",
    ballCard = "talent_word",
    partsPct = "parts",
    rerollPlus = "reroll",
    stat = "talent_damage",
}

---@param id string|nil
---@return string|nil ICON_PATHS 键
function MetaCatalog.GetTalentIcon(id)
    if not id then return nil end
    return TALENT_ICONS[id]
end

---@param kind string|nil
---@return string|nil
function MetaCatalog.GetTalentKindIcon(kind)
    if not kind then return nil end
    return TALENT_KIND_ICONS[kind]
end

return MetaCatalog
