-- TalentCatalog.lua
-- 天赋树静态数据与纯判定（无渲染、无存档副作用）。
-- 被 MetaUI 的选卡界面与 Game 的局内规则读取；真正的"已解锁集合"由 PlayerData 持有，
-- 由编排层（client_main）在开局前注入 Game。
--
-- v0.13.15 结构（用户规格）：
--   · 阶段星级门槛 0 / 3 / 9 / 18 / 27 / 36 / 45（第 3 阶起每阶 +9）。
--   · 每阶段 6 个节点 = 2 通用（general_a 成长 / general_b 通用卡）+ 4 车（normal/ice/speed/giant）。
--   · 每节点点一次即满（单级）。
--   · 解锁需满足：①本阶段星级门槛已达标；②同一线路上一阶段节点已解锁（线路链式）。
--   · 每个节点解锁都额外给「极低血量加成」（MAX_HP_PER_NODE）——这是**所有卡通用**的规则，
--     在天赋树顶部**统一说明一次**（HP_RULE_TEXT），不逐条写进节点文案。
--   · 车线路：1 阶=允许该车局内出现，2 阶=解锁该车专属卡，3/4/6/7 阶=小幅基础数值，
--     5 的倍数阶段=专属卡效果增强（数值更大）。
--   · **成长线（general_a）**：每阶「暴击率 +2%」，每 3 阶额外「基础攻击 +1」，
--     最后一阶是「学满奖励：暴击率额外 +5%」。
--   · **通用卡线（general_b）**：1 阶=经验卡、3 阶=弹药扩容卡，其余阶=结算零件 +5%。

local TalentCatalog = {}

-- 每个已解锁节点提供的基地生命上限加成（"极低的血量加成"）。
TalentCatalog.MAX_HP_PER_NODE = 1

-- 暴击：命中时按暴击率判定，暴击伤害倍率。
TalentCatalog.CRIT_MULT = 1.5
-- 成长线：每阶暴击率增量 / 每几阶额外加基础攻击 / 加多少 / 学满奖励。
TalentCatalog.CRIT_PER_STAGE = 2      -- 每阶暴击率 +2%
TalentCatalog.ATK_EVERY = 3           -- 每 3 阶额外 +1 基础攻击
TalentCatalog.ATK_GAIN = 1
TalentCatalog.MASTERY_CRIT = 5        -- 最后一阶额外暴击率 +5%

-- 阶段星级门槛（index = 阶段号 1..7）。满星 15 关 × 3 = 45。
TalentCatalog.STAGE_STARS = { 0, 3, 9, 18, 27, 36, 45 }
TalentCatalog.MAX_STAGE = #TalentCatalog.STAGE_STARS

-- 各阶段单节点解锁花费（零件）；保留入门价，相邻两阶至少翻倍。
-- 六条线路共用此表，界面报价与实际扣费都读取 node.cost；已拥有节点不补扣。
local STAGE_COST = { 200, 500, 1200, 2500, 5000, 10000, 20000 }

-- 六条线路：2 通用 + 4 车。绘制顺序即此顺序（通用在前，车在后）。
TalentCatalog.LANES = { "general_a", "general_b", "normal", "ice", "speed", "giant" }
TalentCatalog.LANE_NAMES = {
    general_a = "成长", general_b = "通用卡",
    normal = "分裂车", ice = "冰冻车", speed = "加速车", giant = "巨型车",
}

-- 开局自动拥有的节点：初始车（**加速车**，v0.13.19 由分裂车改）的"允许局内出场"。
-- v0.13.28：分裂车同样开局自动解锁（用户要求），两张"允许局内出场"节点都不必花零件。
TalentCatalog.AUTO_OWNED = { "speed_1", "normal_1" }

-- 车线路的"小幅数值增强"参数：stat 对应 Game 的 BALL_TUNING 字段。
-- mul=true 表示乘法叠加，否则加法；small=小幅，big=专属卡效果增强。
-- v0.13.16：用户要求「局内卡要显著强于局外的树」→ 天赋数值按「局内卡的 1/3~1/5」定，
-- 保证一局内抽到的一张卡就明显强于树上同属性的一整条线。对照（局内基础卡/强化卡）：
--   分裂 2%/3%、冰冻 0.5/1.2 秒、加速度 4%/8%、贯穿 0.5/1.0 格。
local BALL_STAT = {
    normal = { stat = "splitBonus", small = 0.005, big = 0.008, label = "分裂概率" },
    ice    = { stat = "iceBonus",   small = 0.12,  big = 0.30,  label = "冰冻时长" },
    speed  = { stat = "speedMul",   small = 1.01,  big = 1.02,  mul = true, label = "加速度" },
    giant  = { stat = "giantArea",  small = 0.12,  big = 0.25,  label = "贯穿范围" },
}

---@class TalentNode
---@field id string
---@field lane string
---@field stage integer
---@field name string
---@field desc string
---@field cost integer
---@field kind string "cardUnlock"|"ballUnlock"|"ballCard"|"stat"|"partsPct"
---@field cardId string|nil
---@field ballType string|nil
---@field stat string|nil
---@field value number|nil
---@field mul boolean|nil
---@field atkBonus integer|nil 基础攻击加成（成长线每 3 阶 +1）
---@field icon string|nil ICON_PATHS 键（v0.13.8 圆形卡图标）
---@field tint string|nil 线路配色："cyan"（通用）|"gold"（稀有/付费感）

---@type TalentNode[]
local NODES = {}
---@type table<string, TalentNode>
local NODE_BY_ID = {}

-- 车线路配色（通用线路用青色）。
local LANE_TINT = {
    general_a = "cyan", general_b = "cyan",
    normal = "cyan", ice = "cyan", speed = "cyan", giant = "cyan",
}

-- 节点图标与配色的统一回退（v0.13.8）：精确 cardId 映射优先，否则按 kind 取通用图标。
-- 稀有/付费感节点（专属卡、解锁、通用卡解锁）用金色描边，其余用线路色。
local function DecorateNode(node)
    node.tint = LANE_TINT[node.lane] or "cyan"
    local icon = node.cardId and TalentCatalog.ICON_BY_CARD[node.cardId] or nil
    if not icon then icon = TalentCatalog.ICON_BY_KIND[node.kind] end
    -- 车线路按弹种取弹药图标，视觉与底部弹药槽一致。
    if node.ballType then
        icon = TalentCatalog.ICON_BY_BALL[node.ballType] or icon
    end
    node.icon = icon
end

local function AddNode(node)
    DecorateNode(node)
    NODES[#NODES + 1] = node
    NODE_BY_ID[node.id] = node
end

-- 图标映射表（与 MetaCatalog 的 ICON_PATHS 键一致；在下方赋值，避免前向引用）。
---@type table<string, string>
TalentCatalog.ICON_BY_CARD = {
    xp = "talent_xp", ammo = "talent_ammo",
    -- v0.13.21：词条卡（通用卡）也用各自的图标，与局内卡一致。
    word_pierce = "talent_word", word_chain = "talent_word",
    word_momentum = "talent_word",
}
---@type table<string, string>
TalentCatalog.ICON_BY_KIND = {
    cardUnlock = "talent_xp",
    ballUnlock = "talent_unlock",
    ballCard = "talent_word",
    partsPct = "parts",
    stat = "talent_damage",
}
---@type table<string, string>
TalentCatalog.ICON_BY_BALL = {
    normal = "ammo_normal", ice = "ammo_ice",
    speed = "ammo_speed", giant = "ammo_giant",
}

-- v0.13.16：血量加成是**所有卡通用**的规则，因此**不在每个节点里重复**，
-- 改由天赋树顶部统一说明一次（见 TalentCatalog.HP_RULE_TEXT / TalentTree 表头）。
-- 这里保留直通函数，避免调用点散落改动。
local function WithHp(text)
    return text
end

-- 天赋树顶部展示的全局规则文案（所有卡一视同仁）。
TalentCatalog.HP_RULE_TEXT = string.format("每解锁 1 个天赋：生命上限 +%d",
    TalentCatalog.MAX_HP_PER_NODE)

-- 通用卡线（general_b）：全部是**无车型的通用卡**，须在天赋树解锁对应节点才进局内卡池。
-- v0.13.21：词条卡（贯穿/连锁/动量）也归入通用卡——此前它们无任何门控、开局常驻（用户点名）。
--   1 阶=经验数据卡、2 阶=贯穿弹芯、3 阶=弹药扩容卡、4 阶=连锁弹、5 阶=动量加速；
--   其余阶=结算零件 +5%（填充）。
local GENERAL_CARD = {
    general_b = { [1] = "xp", [2] = "word_pierce", [3] = "ammo",
                  [4] = "word_chain", [5] = "word_momentum" },
}
local GENERAL_CARD_NAME = {
    xp = "经验数据卡", ammo = "弹药扩容卡",
    word_pierce = "贯穿弹芯", word_chain = "连锁弹", word_momentum = "动量加速",
}
for stage = 1, TalentCatalog.MAX_STAGE do
    local cardId = GENERAL_CARD.general_b[stage]
    local node = {
        id = "general_b_" .. stage, lane = "general_b", stage = stage,
        cost = STAGE_COST[stage],
    }
    if cardId then
        node.kind = "cardUnlock"
        node.cardId = cardId
        node.name = GENERAL_CARD_NAME[cardId]
        node.desc = WithHp("解锁「" .. GENERAL_CARD_NAME[cardId] .. "」进入局内卡池")
    else
        node.kind = "partsPct"
        node.value = 5
        node.name = "结算零件 +5%"
        node.desc = WithHp("结算时零件获取 +5%")
    end
    AddNode(node)
end

-- 成长线（general_a）：每阶「暴击率 +2%」，每 3 阶额外「基础攻击 +1」，
-- 最后一阶是「学满奖励：暴击率额外 +5%」。
for stage = 1, TalentCatalog.MAX_STAGE do
    local node = {
        id = "general_a_" .. stage, lane = "general_a", stage = stage,
        cost = STAGE_COST[stage], kind = "stat",
        stat = "critChance", value = TalentCatalog.CRIT_PER_STAGE / 100,
    }
    local crit = TalentCatalog.CRIT_PER_STAGE
    local parts = { string.format("暴击率 +%d%%", crit) }
    if stage == TalentCatalog.MAX_STAGE then
        -- 学满奖励：额外暴击率（累加到同一节点）。
        node.value = (crit + TalentCatalog.MASTERY_CRIT) / 100
        node.name = "学满 · 暴击率"
        parts = { string.format("暴击率 +%d%%", crit + TalentCatalog.MASTERY_CRIT),
                  "学满奖励" }
    else
        node.name = "暴击率"
    end
    -- 每 3 阶额外加基础攻击。
    if stage % TalentCatalog.ATK_EVERY == 0 then
        node.atkBonus = (node.atkBonus or 0) + TalentCatalog.ATK_GAIN
        parts[#parts + 1] = string.format("基础攻击 +%d", TalentCatalog.ATK_GAIN)
    end
    node.desc = WithHp(table.concat(parts, " · "))
    AddNode(node)
end

-- 车线路：1 阶解锁车，2 阶解锁专属卡，3/4/6/7 阶小幅数值，5 的倍数阶专属卡效果增强。
for _, lane in ipairs({ "normal", "ice", "speed", "giant" }) do
    local st = BALL_STAT[lane]
    local laneName = TalentCatalog.LANE_NAMES[lane]
    for stage = 1, TalentCatalog.MAX_STAGE do
        local node = {
            id = lane .. "_" .. stage, lane = lane, stage = stage,
            cost = STAGE_COST[stage], ballType = lane,
        }
        if stage == 1 then
            node.kind = "ballUnlock"
            node.name = "解锁" .. laneName
            node.desc = WithHp("允许" .. laneName .. "在局内出场")
        elseif stage == 2 then
            node.kind = "ballCard"
            node.name = laneName .. "专属卡"
            node.desc = WithHp("解锁" .. laneName .. "的专属天赋卡")
        else
            local isBig = (stage % 5 == 0)
            node.kind = "stat"
            node.stat = st.stat
            node.mul = st.mul
            node.value = isBig and st.big or st.small
            -- 描述：乘法类按百分比显示，分裂概率按百分比，其余按两位小数。
            -- v0.13.16：天赋数值下调后（如分裂 +0.5%），整数百分比会四舍五入成 +1%
            -- 让小幅/强化节点显示一样——改按实际精度输出（能整除用整数，否则一位小数）。
            local desc
            if st.mul then
                local pct = (node.value - 1) * 100
                desc = string.format("%s +%s%%", st.label,
                    (math.abs(pct - math.floor(pct + 0.5)) < 1e-6)
                        and tostring(math.floor(pct + 0.5)) or string.format("%.1f", pct))
            elseif st.stat == "splitBonus" then
                local pct = node.value * 100
                desc = string.format("%s +%s%%", st.label,
                    (math.abs(pct - math.floor(pct + 0.5)) < 1e-6)
                        and tostring(math.floor(pct + 0.5)) or string.format("%.1f", pct))
            else
                desc = string.format("%s +%.2f", st.label, node.value)
            end
            node.name = (isBig and "专属强化 · " or "小幅强化 · ") .. st.label
            node.desc = WithHp(desc)
        end
        AddNode(node)
    end
end

---@return TalentNode[]
function TalentCatalog.GetNodes()
    return NODES
end

---@param id string
---@return TalentNode|nil
function TalentCatalog.GetNode(id)
    return NODE_BY_ID[id]
end

---@param lane string
---@return TalentNode[]
function TalentCatalog.GetLaneNodes(lane)
    local out = {}
    for _, n in ipairs(NODES) do
        if n.lane == lane then out[#out + 1] = n end
    end
    return out
end

---@param stage integer
---@return number 该阶段所需星级（超出范围返回极大值）
function TalentCatalog.GetStageStars(stage)
    return TalentCatalog.STAGE_STARS[stage] or math.huge
end

-- 星级进度 → 已开放的阶段数（0..MAX_STAGE）。
---@param totalStars integer
---@return integer
function TalentCatalog.GetUnlockedStageCount(totalStars)
    local count = 0
    for stage = 1, TalentCatalog.MAX_STAGE do
        if totalStars >= TalentCatalog.STAGE_STARS[stage] then count = stage else break end
    end
    return count
end

-- 节点是否满足前置：本阶段星级达标 + 同线路上一阶段节点已解锁。
---@param node TalentNode
---@param owned table<string, boolean>
---@param totalStars integer
---@return boolean
function TalentCatalog.IsPrereqMet(node, owned, totalStars)
    if totalStars < TalentCatalog.GetStageStars(node.stage) then return false end
    if node.stage <= 1 then return true end
    local prev = NODE_BY_ID[node.lane .. "_" .. (node.stage - 1)]
    return prev ~= nil and owned[prev.id] == true
end

-- 是否可解锁（含已拥有 / 前置 判定）。返回 ok, reason。
---@param nodeId string
---@param owned table<string, boolean>
---@param totalStars integer
---@param parts integer
---@return boolean
---@return string|nil reason
function TalentCatalog.CanUnlock(nodeId, owned, totalStars, parts)
    local node = NODE_BY_ID[nodeId]
    if not node then return false, "no_node" end
    if owned[nodeId] then return false, "owned" end
    if totalStars < TalentCatalog.GetStageStars(node.stage) then return false, "stars" end
    if not TalentCatalog.IsPrereqMet(node, owned, totalStars) then return false, "prereq" end
    if (parts or 0) < node.cost then return false, "parts" end
    return true
end

return TalentCatalog
