-- TalentCatalog.lua
-- 天赋树静态数据与纯判定（无渲染、无存档副作用）。
-- 被 MetaUI 的选卡界面与 Game 的局内规则读取；真正的"已解锁集合"由 PlayerData 持有，
-- 由编排层（client_main）在开局前注入 Game。
--
-- v0.13.5 结构（用户规格）：
--   · 阶段星级门槛 0 / 3 / 9 / 18 / 27 / 36 / 45（第 3 阶起每阶 +9）。
--   · 每阶段 6 个节点 = 2 通用（general_a 成长 / general_b 通用卡）+ 4 车（normal/ice/speed/giant）。
--   · 每节点点一次即满（单级）。
--   · 解锁需满足：①本阶段星级门槛已达标；②同一线路上一阶段节点已解锁（线路链式）。
--   · 每个节点解锁都额外给「极低血量加成」（MAX_HP_PER_NODE）。
--   · 车线路：1 阶=允许该车局内出现，2 阶=解锁该车专属卡，3/4/6/7 阶=小幅基础数值，
--     5 的倍数阶段=专属卡效果增强（数值更大）。
--   · 通用线路：general_a 1 阶=解锁「数据回收」卡，其余阶=结算零件百分比；
--     general_b 3 阶=解锁「弹药扩容」卡，其余阶=结算零件百分比。

local TalentCatalog = {}

-- 每个已解锁节点提供的基地生命上限加成（"极低的血量加成"）。
TalentCatalog.MAX_HP_PER_NODE = 1

-- 阶段星级门槛（index = 阶段号 1..7）。满星 15 关 × 3 = 45。
TalentCatalog.STAGE_STARS = { 0, 3, 9, 18, 27, 36, 45 }
TalentCatalog.MAX_STAGE = #TalentCatalog.STAGE_STARS

-- 各阶段单节点解锁花费（零件），随阶段递增。
local STAGE_COST = { 200, 350, 600, 900, 1300, 1800, 2400 }

-- 六条线路：2 通用 + 4 车。绘制顺序即此顺序（通用在前，车在后）。
TalentCatalog.LANES = { "general_a", "general_b", "normal", "ice", "speed", "giant" }
TalentCatalog.LANE_NAMES = {
    general_a = "成长", general_b = "通用卡",
    normal = "分裂车", ice = "冰冻车", speed = "加速车", giant = "巨型车",
}

-- 开局自动拥有的节点：初始分裂车的"允许局内出场"（用户规格：初始分裂车的卡自动获得）。
TalentCatalog.AUTO_OWNED = { "normal_1" }

-- 车线路的"小幅数值增强"参数：stat 对应 Game 的 BALL_TUNING 字段。
-- mul=true 表示乘法叠加，否则加法；small=小幅，big=专属卡效果增强。
local BALL_STAT = {
    normal = { stat = "splitBonus", small = 0.02, big = 0.05, label = "分裂概率" },
    ice    = { stat = "iceBonus",   small = 0.20, big = 0.50, label = "冰冻时长" },
    speed  = { stat = "speedMul",   small = 1.02, big = 1.05, mul = true, label = "极速" },
    giant  = { stat = "giantArea",  small = 0.25, big = 0.60, label = "贯穿范围" },
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

---@type TalentNode[]
local NODES = {}
---@type table<string, TalentNode>
local NODE_BY_ID = {}

local function AddNode(node)
    NODES[#NODES + 1] = node
    NODE_BY_ID[node.id] = node
end

-- 通用线路：a = 成长线（1 阶经验卡），b = 通用卡线（3 阶弹药卡）。其余阶段=结算零件 +5%。
local GENERAL_CARD = { general_a = { [1] = "xp" }, general_b = { [3] = "ammo" } }
local GENERAL_CARD_NAME = { xp = "经验数据卡", ammo = "弹药扩容卡" }
for _, lane in ipairs({ "general_a", "general_b" }) do
    for stage = 1, TalentCatalog.MAX_STAGE do
        local cardId = GENERAL_CARD[lane][stage]
        local node = {
            id = lane .. "_" .. stage, lane = lane, stage = stage, cost = STAGE_COST[stage],
        }
        if cardId then
            node.kind = "cardUnlock"
            node.cardId = cardId
            node.name = GENERAL_CARD_NAME[cardId]
            node.desc = "解锁「" .. GENERAL_CARD_NAME[cardId] .. "」进入局内卡池"
        else
            node.kind = "partsPct"
            node.value = 5
            node.name = "结算零件 +5%"
            node.desc = "结算时零件获取 +5%"
        end
        AddNode(node)
    end
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
            node.desc = "允许" .. laneName .. "在局内出场"
        elseif stage == 2 then
            node.kind = "ballCard"
            node.name = laneName .. "专属卡"
            node.desc = "解锁" .. laneName .. "的专属天赋卡"
        else
            local isBig = (stage % 5 == 0)
            node.kind = "stat"
            node.stat = st.stat
            node.mul = st.mul
            node.value = isBig and st.big or st.small
            -- 描述：乘法类按百分比显示，分裂概率按百分比，其余按两位小数。
            local desc
            if st.mul then
                desc = string.format("%s +%d%%", st.label,
                    math.floor((node.value - 1) * 100 + 0.5))
            elseif st.stat == "splitBonus" then
                desc = string.format("%s +%d%%", st.label,
                    math.floor(node.value * 100 + 0.5))
            else
                desc = string.format("%s +%.2f", st.label, node.value)
            end
            node.name = (isBig and "专属强化 · " or "小幅强化 · ") .. st.label
            node.desc = desc
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
