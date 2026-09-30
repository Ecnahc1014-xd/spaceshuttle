-- 关卡编排只描述关卡规则；战斗状态、碰撞和实际刷怪仍由 Game 管理。
local StageCatalog = {}

StageCatalog.WAVES_PER_STAGE = 10
StageCatalog.MAX_FLEET = 12
-- v0.13.13：关卡无限——选关列表只列到「最高已解锁关」，可一直往上爬。
-- 难度公式全部可外推：速度/召唤次数/间隔已用 math.min 封顶，方块血量继续每 3 关 +1，
-- 精英与 Boss 机型按取模循环复用。此常量仅保留为「难度封顶参考关数」，不再是硬上限。
StageCatalog.STAGE_SOFT_CAP = 15

local ELITE_KEYS = {
    "elite_hook", "elite_fork", "elite_razor", "elite_spiral", "elite_anchor",
    "elite_wisp", "elite_shear", "elite_bracket", "elite_hammer", "elite_rivet",
}
local BOSS_KEYS = { "boss_orrery", "boss_maw", "boss_citadel", "boss_prism", "boss_serpent" }
local ELITE_SLOTS = { [3] = 1, [6] = 2, [8] = 3 }

function StageCatalog.GetStage(wave)
    return math.floor((wave - 1) / StageCatalog.WAVES_PER_STAGE) + 1
end

function StageCatalog.GetStageWave(wave)
    return (wave - 1) % StageCatalog.WAVES_PER_STAGE + 1
end

function StageCatalog.GetKind(stageWave)
    if stageWave == StageCatalog.WAVES_PER_STAGE then return "boss" end
    if ELITE_SLOTS[stageWave] then return "elite" end
    return "normal"
end

function StageCatalog.GetSpecialKey(stage, stageWave)
    if stageWave == StageCatalog.WAVES_PER_STAGE then
        return BOSS_KEYS[(stage - 1) % #BOSS_KEYS + 1]
    end
    local slot = ELITE_SLOTS[stageWave]
    if slot then return ELITE_KEYS[((stage - 1) * 3 + slot - 1) % #ELITE_KEYS + 1] end
    return nil
end

-- v0.13.4：用户要求「一波 = 原先两波以上」——每波编队量取旧基线 2 倍，
-- 波内随进度阶梯递增（6→8→10），逐关 +1；硬顶 12 = MAX_FLEET（同屏预算不放宽）。
function StageCatalog.GetNormalCount(stage, stageWave)
    return math.min(StageCatalog.MAX_FLEET,
        6 + 2 * math.floor((stageWave - 1) / 3) + (stage - 1))
end

function StageCatalog.GetEscortCount(stage)
    return math.min(3, stage)
end

-- 每过三关，普通敌人每块 +1 血；精英 / Boss 另有固定护甲。
function StageCatalog.GetBrickHp(stage, kind)
    local base = 1 + math.floor((stage - 1) / 3)
    if kind == "elite" then return base + 1 end
    if kind == "boss" then return base + 2 end
    return base
end

function StageCatalog.GetBaseSpeed(stage, stageWave)
    return 28 + (stageWave - 1) * 4 + math.min(stage - 1, 12) * 1.5
end

-- 波间隔逐关稍增长：同为十波，关卡时长也会因怪更多、Boss 召唤而增长。
function StageCatalog.GetInterval(stage, stageWave)
    return math.max(12, 15.5 + math.min(stage - 1, 8) * 1.2 - (stageWave - 1) * 0.28)
end

function StageCatalog.GetBossSummonLimit(stage)
    return math.min(7, stage + 2)
end

function StageCatalog.GetBossSummonInterval(stage)
    return math.max(6.5, 10 - math.min(stage - 1, 7) * 0.45)
end

return StageCatalog
