-- AchievementCatalog.lua
-- 成就目录（纯数据，无渲染、无存档副作用）。
-- 本地成就是唯一权威；平台成就只做镜像（幂等外发，见 client_main 的 SyncAchievements）。
--
-- ⚠️ 平台契约（Achievement.d.lua / MCP create_achievement）：
--   · `id` 长度 1..40，仅允许字母、数字、`-`、`_`（与平台 achievement_id 同一套规则）。
--   · `steps` 为达成所需步数（1 = 单步成就，走 UnlockAchievement；>1 走 IncrementAchievement）。
--   · 平台侧最多允许一定数量成就；本目录是**唯一数量权威**（禁止在别处再散列成就）。
--
-- ⚠️ 新增成就时必须同时：
--   ① 在本表加一行（id/steps/title/desc/icon）；
--   ② 在 client_main 的结算/事件驱动处调 `Ach.Grant(id, ...)`（否则永远不会推进）；
--   ③ 用 MCP `create_achievement` 在平台侧创建同名 id（否则外发被拒，但**本地仍解锁**）。
--
-- 统计来源：PlayerData.stats / codex / stageStars / maxStage / 各系统计数器。

local AchievementCatalog = {}

---@class AchievementDef
---@field id string 平台成就 ID（1..40，字母数字-_）
---@field title string 成就名称
---@field desc string 达成条件说明
---@field steps integer 达成所需步数（1 = 单步）
---@field icon string ICON_PATHS 键（缺图回退程序化奖章）
---@field tone string 语义色："cyan"（免费/常规）| "warn"（稀有/付费）| "ad"（广告）

-- ============================================================================
-- 成就目录（唯一数量权威）
-- ============================================================================
---@type AchievementDef[]
local ACHIEVEMENTS = {
    -- —— 入门 / 里程碑（单步或少量步数）——
    { id = "first_blood",   title = "首次击碎",   desc = "击碎第一块敌机方块",           steps = 1,     icon = "record",            tone = "cyan" },
    { id = "first_win",     title = "旗开得胜",   desc = "首次通关任意关卡",             steps = 1,     icon = "levelup",           tone = "cyan" },
    { id = "first_boss",    title = "斩首行动",   desc = "首次击败首领",                 steps = 1,     icon = "premium_pass_crest", tone = "warn" },

    -- —— 累计击碎（多步）——
    { id = "bricks_1k",     title = "拆解新手",   desc = "累计击碎 1,000 块方块",        steps = 1000,  icon = "record",            tone = "cyan" },
    { id = "bricks_10k",    title = "拆解专家",   desc = "累计击碎 10,000 块方块",       steps = 10000, icon = "record",            tone = "warn" },
    { id = "bricks_50k",    title = "拆解大师",   desc = "累计击碎 50,000 块方块",       steps = 50000, icon = "record",            tone = "warn" },

    -- —— 关卡进度（绝对值：最远关）——
    { id = "stage_5",       title = "初露锋芒",   desc = "抵达第 5 关",                  steps = 5,     icon = "rank",              tone = "cyan" },
    { id = "stage_10",      title = "深入敌后",   desc = "抵达第 10 关",                 steps = 10,    icon = "rank",              tone = "cyan" },
    { id = "stage_20",      title = "星域征服者", desc = "抵达第 20 关",                 steps = 20,    icon = "rank",              tone = "warn" },

    -- —— 图鉴收集（绝对值：收录数）——
    { id = "codex_5",       title = "情报初集",   desc = "图鉴收录 5 种敌机",            steps = 5,     icon = "codex",             tone = "cyan" },
    { id = "codex_all",     title = "全数收录",   desc = "图鉴收录全部敌机",             steps = 23,    icon = "codex",             tone = "warn" },

    -- —— 高分 ——
    { id = "score_100k",    title = "十万火力",   desc = "单局最高分达到 100,000",       steps = 100000, icon = "record",           tone = "cyan" },
    { id = "score_500k",    title = "五十万火力", desc = "单局最高分达到 500,000",       steps = 500000, icon = "record",           tone = "warn" },

    -- —— 局数 / 道具 / 天赋 ——
    { id = "runs_10",       title = "老练车手",   desc = "完成 10 局战斗",               steps = 10,    icon = "home",              tone = "cyan" },
    { id = "runs_50",       title = "身经百战",   desc = "完成 50 局战斗",               steps = 50,    icon = "home",              tone = "warn" },
    { id = "talent_10",     title = "天赋觉醒",   desc = "解锁 10 个天赋节点",           steps = 10,    icon = "talent_xp",         tone = "cyan" },
    { id = "talent_all",    title = "全能车手",   desc = "解锁全部天赋节点",             steps = 42,    icon = "talent_xp",         tone = "warn" },
    { id = "stars_45",      title = "满星猎手",   desc = "累计获得 45 颗星",             steps = 45,    icon = "premium_wheel_medal", tone = "warn" },

    -- —— 商业化 / 收集 ——
    { id = "skin_3",        title = "车库扩充",   desc = "解锁 3 款车型",                steps = 3,     icon = "shop",              tone = "cyan" },
    { id = "trail_3",       title = "流光溢彩",   desc = "解锁 3 款拖尾样式",            steps = 3,     icon = "premium_energy_core", tone = "cyan" },
}

---@return AchievementDef[]
function AchievementCatalog.GetAll()
    return ACHIEVEMENTS
end

---@return integer
function AchievementCatalog.Count()
    return #ACHIEVEMENTS
end

---@param id string
---@return AchievementDef|nil
function AchievementCatalog.Get(id)
    for _, a in ipairs(ACHIEVEMENTS) do
        if a.id == id then return a end
    end
    return nil
end

return AchievementCatalog
