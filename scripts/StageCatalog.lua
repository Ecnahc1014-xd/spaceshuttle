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
local NORMAL_WAVE_ORDINAL = { [1] = 1, [2] = 2, [4] = 3, [5] = 4, [7] = 5, [9] = 6 }

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

-- 普通波按普通波序号推进：每两关增加一档、每两次普通波增加一架。
-- v0.13.26：起点从 2 架降到 1 架（用户要求「比 2 更低」）；不再追求触到 12 架上限。
-- 第1关 1/1/2/2/3/3；第7关 4/4/5/5/6/6；第15关 8/8/9/9/10/10。
-- 同波内改为一架接一架飞出（见 GetSpawnInterval），数量是该波计划总架数。
function StageCatalog.GetNormalCount(stage, stageWave)
    local stageProgress = GetStageProgress(stage)
    local stageRamp = math.floor(stageProgress * 4 / 7)
    local waveOrdinal = NORMAL_WAVE_ORDINAL[stageWave] or 1
    local waveRamp = math.floor((waveOrdinal - 1) / 2)
    return math.min(StageCatalog.MAX_FLEET, 1 + stageRamp + waveRamp)
end

-- 精英护航低密度成长：前 3 关无护航，第 4 关起每三关加一架，最多 3 架。
function StageCatalog.GetEscortCount(stage)
    return math.min(3, math.floor(GetStageProgress(stage) / 3))
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

-- v0.13.26：波间隔改为**逐关收紧**（旧版随关卡变长 15.5→25.1s，方向反了）。
-- 关1 首波后 22s（比旧的 15.5s「延长一点」），每关 -0.9s；关内每波再 -0.3s（下限 7s）。
function StageCatalog.GetInterval(stage, stageWave)
    return math.max(7, 22 - GetStageProgress(stage) * 0.9 - (stageWave - 1) * 0.3)
end

-- v0.13.26：同波内敌机不再同帧齐出，改为一架接一架飞入。
-- 关1 间隔最长（2.8s），每关 -0.14s，第 13 关起封顶 1.12s。
-- 下限由调用方（Game）按「下落速度 × 1 格 + 余量」动态抬高，保证任意两架初始至少隔 1 格。
function StageCatalog.GetSpawnInterval(stage)
    return math.max(1.1, 2.8 - GetStageProgress(stage) * 0.14)
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
