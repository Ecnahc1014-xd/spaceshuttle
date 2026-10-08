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

-- v0.13.46：局内随机——每关进入时生成一次布局（精英波位 / 精英与 Boss 机型 / 关卡特性），
-- 打破「每关都是 3/6/8 精英」的同质化；同一关每次进入都不同（种子来自本局开局时间）。
-- 硬约束：第 10 波恒为 Boss（Game 的胜负判定绑定 WAVES_PER_STAGE），只随机它的机型。
StageCatalog.ELITE_COUNT = 3
local MODIFIERS = {
    { id = "standard", label = "标准编队" },
    { id = "standard", label = "标准编队" },   -- 权重 2/5：多数关仍是基准节奏
    { id = "rush",     label = "急行推进", intervalMul = 0.82 },
    { id = "dense",    label = "密集编队", spawnMul = 0.82 },
    { id = "surge",    label = "增援编队", waveAdd = 1 },
}
local currentLayout = nil

-- 小型 LCG：确定性、可复现（探针给同一 seed 必得同一布局），不依赖引擎的 math.random。
local function MakeRng(seed)
    local s = math.floor(tonumber(seed) or 1) % 2147483647
    if s <= 0 then s = 1 end
    return function(lo, hi)
        s = (s * 16807) % 2147483647
        local r = (s - 1) / 2147483646
        if lo == nil then return r end
        return lo + math.floor(r * (hi - lo + 1))
    end
end

-- 只在「布局属于该关」时返回，避免未调用 BeginStage 或跨关残留时读到脏布局。
local function LayoutFor(stage)
    if currentLayout and currentLayout.stage == stage then return currentLayout end
    return nil
end

local function ActiveModifier(stage)
    local layout = LayoutFor(stage)
    return layout and layout.modifier or nil
end

-- 生成本关布局。由 Game 在每次进入关卡时调用一次（选关/下一关/再战/重开都会重掷）。
function StageCatalog.BeginStage(stage, seed)
    stage = math.max(1, math.floor(stage))
    local rng = MakeRng(seed)
    local pool = {}
    for w = 1, StageCatalog.WAVES_PER_STAGE - 1 do pool[#pool + 1] = w end
    local elites = {}
    for _ = 1, math.min(StageCatalog.ELITE_COUNT, #pool) do
        elites[#elites + 1] = table.remove(pool, rng(1, #pool))
    end
    table.sort(elites)
    local eliteKeys = {}
    for i = 1, #elites do
        eliteKeys[elites[i]] = ELITE_KEYS[((stage - 1) * 2 + i - 1) % #ELITE_KEYS + 1]
    end
    local boss = BOSS_KEYS[((stage - 1 + rng(0, #BOSS_KEYS - 1)) % #BOSS_KEYS) + 1]
    local modifier = MODIFIERS[rng(1, #MODIFIERS)]
    local subtitle = string.format("十波防线 · %d 精英 · 1 首领", #elites)
    if modifier.id ~= "standard" then
        subtitle = subtitle .. " · " .. modifier.label
    end
    currentLayout = {
        stage = stage, elites = elites, eliteKeys = eliteKeys,
        boss = boss, modifier = modifier, subtitle = subtitle,
    }
    print("[StageCatalog] stage " .. stage .. " layout: elites@"
        .. table.concat(elites, ",") .. " boss=" .. boss .. " mod=" .. modifier.id)
end

function StageCatalog.GetLayoutSubtitle(stage)
    local layout = LayoutFor(stage)
    return layout and layout.subtitle or nil
end

function StageCatalog.GetEliteWaves(stage)
    local layout = LayoutFor(stage)
    if layout then return layout.elites end
    return { 3, 6, 8 }
end

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

-- v0.13.46：kind/机型改为读本关随机布局（第 10 波恒 boss，只随机其机型）。
-- stage 参数新增——调用点只有 PlanWave 一处。
function StageCatalog.GetKind(stage, stageWave)
    if stageWave == StageCatalog.WAVES_PER_STAGE then return "boss" end
    local layout = LayoutFor(stage)
    if layout then
        for i = 1, #layout.elites do
            if layout.elites[i] == stageWave then return "elite" end
        end
        return "normal"
    end
    if ELITE_SLOTS[stageWave] then return "elite" end
    return "normal"
end

function StageCatalog.GetSpecialKey(stage, stageWave)
    local layout = LayoutFor(stage)
    if stageWave == StageCatalog.WAVES_PER_STAGE then
        if layout then return layout.boss end
        return BOSS_KEYS[(stage - 1) % #BOSS_KEYS + 1]
    end
    if layout and layout.eliteKeys[stageWave] then return layout.eliteKeys[stageWave] end
    local slot = ELITE_SLOTS[stageWave]
    if slot then return ELITE_KEYS[((stage - 1) * 3 + slot - 1) % #ELITE_KEYS + 1] end
    return nil
end
-- 普通波按普通波序号推进：每两关增加一档、每两次普通波增加一架。
-- v0.13.26：起点从 2 架降到 1 架（用户要求「比 2 更低」）；不再追求触到 12 架上限。
-- 第1关 1/1/2/2/3/3；第7关 4/4/5/5/6/6；第15关 8/8/9/9/10/10。
-- 同波内改为一架接一架飞出（见 GetSpawnInterval），数量是该波计划总架数。
-- v0.13.46：本关若掷到「增援编队」特性，每波额外 +1 架。
function StageCatalog.GetNormalCount(stage, stageWave)
    local stageProgress = GetStageProgress(stage)
    local stageRamp = math.floor(stageProgress * 4 / 7)
    local waveOrdinal = NORMAL_WAVE_ORDINAL[stageWave] or 1
    local waveRamp = math.floor((waveOrdinal - 1) / 2)
    local mod = ActiveModifier(stage)
    local add = (mod and mod.waveAdd) or 0
    return math.min(StageCatalog.MAX_FLEET, 1 + stageRamp + waveRamp + add)
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
-- v0.13.46：本关若掷到「急行推进」特性，整关节奏 ×0.82。
function StageCatalog.GetInterval(stage, stageWave)
    local base = math.max(7, 22 - GetStageProgress(stage) * 0.9 - (stageWave - 1) * 0.3)
    local mod = ActiveModifier(stage)
    if mod and mod.intervalMul then base = base * mod.intervalMul end
    return base
end

-- v0.13.26：同波内敌机不再同帧齐出，改为一架接一架飞入。
-- 关1 间隔最长（2.8s），每关 -0.14s，第 13 关起封顶 1.12s。
-- 下限由调用方（Game）按「下落速度 × 1 格 + 余量」动态抬高，保证任意两架初始至少隔 1 格。
-- v0.13.46：本关若掷到「密集编队」特性，出怪间隔 ×0.82。
function StageCatalog.GetSpawnInterval(stage)
    local base = math.max(1.1, 2.8 - GetStageProgress(stage) * 0.14)
    local mod = ActiveModifier(stage)
    if mod and mod.spawnMul then base = base * mod.spawnMul end
    return base
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
