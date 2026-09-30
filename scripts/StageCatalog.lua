-- 关卡编排只描述关卡规则；战斗状态、碰撞和实际刷怪仍由 Game 管理。
local StageCatalog = {}

StageCatalog.WAVES_PER_STAGE = 10
StageCatalog.MAX_FLEET = 12
-- v0.13.13：关卡无限——选关列表只列到「最高已解锁关」，可一直往上爬。
-- 数量、速度、召唤与间隔的成长都有软封顶；方块血量继续每 3 关 +1，
-- 精英与 Boss 机型按取模循环复用。该值仅作难度封顶参考，不是关卡硬上限。
StageCatalog.STAGE_SOFT_CAP = 15

local ELITE_KEYS = {
    "elite_hook", "elite_fork", "elite_razor", "elite_spiral", "elite_anchor",
    "elite_wisp", "elite_shear", "elite_bracket", "elite_hammer", "elite_rivet",
}
local BOSS_KEYS = { "boss_orrery", "boss_maw", "boss_citadel", "boss_prism", "boss_serpent" }
local ELITE_SLOTS = { [3] = 1, [6] = 2, [8] = 3 }

local function GetStageProgress(stage)
    stage = math.max(1, math.floor(stage))
    return math.min(stage - 1, StageCatalog.STAGE_SOFT_CAP - 1)
end

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

-- 普通波人数按关内段位与关卡分段共同爬升。
-- 首关 2/3/4；第 7 关 5/6/7；第 15 关 10/11/12；第 15 关末段触及同屏上限。
function StageCatalog.GetNormalCount(stage, stageWave)
    local stageProgress = GetStageProgress(stage)
    local stageRamp = math.floor(stageProgress * 4 / 7)
    local waveRamp = math.floor((stageWave - 1) / 3)
    return math.min(StageCatalog.MAX_FLEET, 2 + stageRamp + waveRamp)
end

-- 精英护航低密度成长：前两关无护航，第 3 关 1 架，此后每三关加一架，最多 3 架。
function StageCatalog.GetEscortCount(stage)
    return math.min(3, math.floor((GetStageProgress(stage) + 1) / 3))
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
    -- Boss 召唤从 1 架起步，每 4 关增加 1 架，后期封顶 4 架。
    return math.min(4, 1 + math.floor(GetStageProgress(stage) / 4))
end

function StageCatalog.GetBossSummonInterval(stage)
    -- 召唤间隔缓慢收紧：12 秒起步，关 15 起封顶 8.5 秒。
    return math.max(8, 12 - GetStageProgress(stage) * 0.25)
end

return StageCatalog
