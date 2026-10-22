-- Presentation.lua
-- 表现状态控制器：消费 Game 发布的领域事件，维护与玩法无关的瞬时视觉效果。

local VisualCatalog = require "VisualCatalog"

local Presentation = {}
-- 一份可复用释放回声；位置是实际指针，寿命只由表现时间推进。
Presentation._chargeRelease = { life = 0, maxLife = VisualCatalog.LAUNCH_CHARGE.releaseSeconds, progress = 0, x = 0, y = 0,
    uiX = nil, uiY = nil, carX = nil, carY = nil, boosted = false }
-- 只保存标量，不持有复用的规则快照或车辆对象；epoch 区分同车取消后再次起手。
-- life = 两层残像 TTL（爆发后 0.65s）；shellLife = 贴身外套寿命——**发射前常驻满值**，
-- 发射后先按 shellHold(2s) 停留（不透明度保持满值），再按 shellFade(3s) 平滑淡出到 0，
-- 故「发射后 2s 才开始消散，随后 3s 平滑消散完」。
Presentation._chargeHologram = { life = 0, maxLife = VisualCatalog.CHARGE_HOLOGRAM.seconds,
    shellLife = 0, shellMaxLife = VisualCatalog.CHARGE_HOLOGRAM.shellHold + VisualCatalog.CHARGE_HOLOGRAM.shellFade,
    shellFade = VisualCatalog.CHARGE_HOLOGRAM.shellFade,
    serial = 0, vehicleId = -1, gestureId = -1, epoch = -1, fired = false, released = false, lastElapsed = -1 }

function Presentation.ResetChargeHologram()
    local c = Presentation._chargeHologram
    c.life, c.shellLife, c.vehicleId, c.gestureId, c.epoch, c.fired, c.released, c.lastElapsed =
        0, 0, -1, -1, -1, false, false, -1
end

function Presentation.UpdateChargeHologram(dt, game, events)
    local c = Presentation._chargeHologram
    local step = math.max(0, dt)
    c.life = math.max(0, c.life - step)
    if not game or game.state ~= "playing" or (game.introTimer or 0) > 0 then
        Presentation.ResetChargeHologram()
        return
    end
    local now = game.elapsed or 0
    if now < c.lastElapsed then Presentation.ResetChargeHologram() end
    c.lastElapsed = now
    local m = game.activeBall
    local epoch = game.pointerEpoch or 0
    -- 发射事实只锁定一次；发射后外套才开始消散（不再受源车回收/下一车起手截断）。
    if not c.released and c.shellLife > 0 then
        for _, event in ipairs(events or {}) do
            if event.type == "marble_launched" and event.id == c.vehicleId and event.chargeBoosted then
                c.released = true
                break
            end
        end
        if not c.released then
            for _, car in ipairs(game.marbles or {}) do
                if car.id == c.vehicleId and car.alive and car.chargeBoosted then
                    c.released = true
                    break
                end
            end
        end
    end
    -- 外套只在「发射后」开始计时消散；蓄力未发射期间保持满值常驻。
    if c.released then
        c.shellLife = math.max(0, c.shellLife - step)
    end
    if game.chargeActive and m then
        if c.gestureId ~= m.id or c.epoch ~= epoch then
            c.gestureId, c.epoch, c.fired = m.id, epoch, false
        end
        -- 蓄力达到完成阈值（85%）即视作满蓄，立刻爆发全息（不必等到 100%）。
        if game.chargeReady and not c.fired then
            c.serial, c.fired = c.serial + 1, true
            c.vehicleId, c.life, c.released = m.id, c.maxLife, false
            c.shellLife = c.shellMaxLife
            print("[Presentation] full charge hologram #" .. tostring(c.serial))
        elseif not game.chargeReady then
            c.fired = false
        end
    else
        c.fired, c.gestureId, c.epoch = false, -1, -1
        -- 非蓄力中且**未发射**（取消/切车）→ 立刻清空；已发射则让外套继续淡出到 0。
        if not c.released then
            c.life, c.shellLife = 0, 0
        end
    end
end

local screenShake = 0
local waveBannerTimer = 0
local waveBannerBoss = false
local waveBannerKind = "normal"
local waveBannerStage = 1
local waveBannerStageWave = 1
local waveBannerKey = nil
local stageBannerTimer = 0
local stageBannerNumber = 1
local hitStop = 0    -- P12：命中顿帧（hitstop），由大命中事件触发，期间主循环对玩法 dt 打折
local particles = {}
local floatTexts = {}
local hitFlashes = {}
local brickDebris = {}
local ejectedBoxes = {}
local baseImpacts = {}
local baseBarrierFlash = 0
local shockRings = {}    -- v0.10.23：击毁砖块的扩散环（少量、点缀）
local wallFlashes = {}   -- v0.13.66：撞墙贴墙闪光（白热芯短线段，钉在墙面上）
local wallFlashPool = {}
---@class CombatImpact
---@field kind string
---@field x number
---@field y number
---@field radiusX number
---@field radiusY number
---@field life number
---@field maxLife number
---@field phase number
---@type CombatImpact[]
local combatImpacts = {}
---@type CombatImpact[]
local impactPool = {}
local reloadFlash = 0    -- v0.10.24：主球回库补弹的 Dock 轻闪
local upgradeHintPulse = 0    -- v0.10.24：升级面板空白点击时的提示轻脉冲
local adStatus = nil          -- v0.10.32：nil / "loading"
local adToast = nil
-- v0.13.72：广告二次确认弹窗内容（编排层写入，后端 overlay 末段绘制）
---@type table|nil
local adConfirm = nil
local adToastTimer = 0
-- 云存档状态（**只描述云存档**，不描述联机模式；两者是不同服务，禁止混用文案）：
-- idle / syncing / ok / unavailable
local cloudStatus = "idle"

-- v0.13.21：尾迹已回归 3D BillboardSet（Renderer3D），本层不再采样/输出轨迹。

local truckLaunchFlash = {
    normal = 0,
    ice = 0,
    speed = 0,
    giant = 0,
}
local nextDebrisId = 1
local SpawnEjectedBox

-- WO-16/P9：高频视觉对象（粒子/碎片/飘字）对象池，避免每帧 table 分配触发 GC 抖动。
-- 失效对象回收进空闲表，再次生成时优先复用其 table，只覆盖字段。
local particlePool = {}
local debrisPool = {}
local floatPool = {}

-- WO-14/P2：领域事件 → 瞬时反馈的声明式映射。新增反馈只需在此登记处理函数，
-- HandleEvent 遍历命中事件触发对应反馈，所有反馈只写 Presentation 瞬时状态，不触达规则层。
local FEEDBACK_MAP = {
    wave_started = {"waveBanner"},
    stage_started = {"stageStartBanner"},
    boss_summoned = {"summonNotice"},
    brick_hit = {"brickSpark"},
    brick_ejected = {"brickEjected"},
    enemy_cleared = {"clearBanner"},
    enemy_destroyed = {"clearImpact"},
    base_hit = {"baseShake"},
    marble_launched = {"launchFlash", "chargeRelease"},
    -- v0.13.64：车辆撞墙回弹——一圈沿内法线扩散的冲击环 + 少量火花。
    marble_bounce = {"bounceImpact"},
    normal_split = {"splitSpark"},
    speed_dash = {"dashSpark"},
    -- v0.13.55「动能穿刺」：加速车穿透一块时的瞬时反馈。
    speed_pierce = {"pierceSpark"},
    giant_pierce_armed = {"pierceArmed"},
    giant_pierce_consumed = {"pierceConsumed"},
    giant_area_hit = {"giantBurst"},
    upgrade_picked = {"upgradeConfirm"},
    -- v0.13.15：天赋暴击命中——金色暴击飘字（区别于普通 +分数）。
    crit_hit = {"critSpark"},
    marble_reloaded = {"reloadPulse"},
    game_reset = {"fullReset"},
    base_revived = {"reviveConfirm"},
    -- v0.11.0 商业化 P4：局内道具槽
    item_used = {"itemUsed"},
    item_granted = {"itemGranted"},
    -- v0.13.58：局内附魔卡
    enchant_granted = {"enchantGranted"},
    enchant_armed = {"enchantArmed"},
    enchant_applied = {"enchantApplied"},
    enchant_pierce = {"enchantPierce"},
    enchant_explode = {"enchantExplode"},
    enchant_chain = {"enchantChain"},
    enchant_triple = {"enchantTriple"},
    enchant_split = {"enchantSplit"},
    enchant_homing = {"enchantHoming"},
    enchant_lifesteal = {"enchantLifesteal"},
    -- v0.13.65：幻影体素块——发射（源机青白闪光）、被击碎、越线。
    phantom_fired = {"phantomFired"},
    phantom_destroyed = {"phantomDestroyed"},
    phantom_breached = {"phantomBreached"},
}

local function GetBrickKey(enemyId, col, row)
    return tostring(enemyId) .. ":" .. tostring(col) .. ":" .. tostring(row)
end

-- v0.10.21：粒子分三类，小而稀疏、偶尔点缀。
--  spark 小亮点（软圆）/ shard 三角碎片（自旋、重力）/ smoke 烟雾（上飘、膨胀、半透明）。
-- v0.13.66：可选 (dirX, dirY) 单位方向——火花沿该方向带抖动喷出（撞墙内法线），
-- 不传时保持原全向随机。
local function SpawnParticles(x, y, color, count, kind, dirX, dirY)
    kind = kind or "spark"
    count = count or 4
    for _ = 1, count do
        local p = table.remove(particlePool) or {}
        p.kind = kind
        p.x = x; p.y = y
        p.r = color[1]; p.g = color[2]; p.b = color[3]
        if kind == "smoke" then
            -- 烟只在出生点附近缓慢漂移，不持续上升（否则会堆到屏幕顶部）。
            local angle = -math.pi / 2 + (math.random() - 0.5) * 2.0
            local speed = 4 + math.random() * 12
            p.vx = math.cos(angle) * speed
            p.vy = math.sin(angle) * speed
            -- 生命与尺寸拉开随机范围，避免每缕烟一样大、一样久。
            p.life = 0.4 + math.random() * 0.35
            p.maxLife = p.life
            p.size = 4 + math.random() * 5
            p.spin = 0
        elseif kind == "shard" then
            local angle = math.random() * math.pi * 2
            local speed = 45 + math.random() * 130
            p.vx = math.cos(angle) * speed
            p.vy = math.sin(angle) * speed - 40
            p.life = 0.35 + math.random() * 0.3
            p.maxLife = p.life
            p.size = 2 + math.random() * 2.5
            p.angle = math.random() * math.pi * 2
            p.spin = (math.random() - 0.5) * 16
        else
            local dx, dy = dirX or 0, dirY or 0
            local angle
            if dx == 0 and dy == 0 then
                angle = math.random() * math.pi * 2
            else
                angle = math.atan2(dy, dx) + (math.random() - 0.5) * 1.1
            end
            local speed = 40 + math.random() * 140
            p.vx = math.cos(angle) * speed
            p.vy = math.sin(angle) * speed - 35
            p.life = 0.18 + math.random() * 0.24
            p.maxLife = p.life
            p.size = 1.4 + math.random() * 2
            p.spin = 0
        end
        particles[#particles + 1] = p
    end
end

local function SpawnFloatText(x, y, text, color, sizeMul, kind)
    local f = table.remove(floatPool) or {}
    f.x = x; f.y = y
    -- 跳字手感：出生带随机初速的上飘，UpdateFloatTexts 中线性减速到停（不回坠）。
    f.vy = -(70 + math.random() * 20)
    f.life = 0.9; f.maxLife = 0.9
    f.text = text
    f.color = color or {255, 255, 255}
    f.size = (sizeMul or 1) * 32
    f.kind = kind or "text"
    f.value = nil
    f.marbleId = nil
    floatTexts[#floatTexts + 1] = f
    return f
end

-- 击碎分数飘字：一次范围击碎会连发多个 brick_hit，逐块飘字会刷屏且互相重叠。
-- 这里做就近聚合——同一片区域内的分数累加到同一条飘字上（数字变大、寿命刷新重跳），
-- 并设同屏数量上限，超出时并入最近一条，保证「少而准」。
local SCORE_FLOAT_MAX = 6
local SCORE_MERGE_DIST = 46

local function ScoreFloatSize(value)
    if value >= 600 then return 30 end
    if value >= 250 then return 27 end
    return 24
end

local function SpawnScoreFloat(x, y, value)
    local best, bestDist2, count = nil, nil, 0
    local mergeDist2 = SCORE_MERGE_DIST * SCORE_MERGE_DIST
    for _, f in ipairs(floatTexts) do
        if f.kind == "score" then
            count = count + 1
            local dx, dy = f.x - x, f.y - y
            local d2 = dx * dx + dy * dy
            if not bestDist2 or d2 < bestDist2 then best, bestDist2 = f, d2 end
        end
    end
    if best then
        -- 附近且仍年轻的分数字直接吸收；达到上限时即使较远也并入最近一条（不丢分）。
        local near = bestDist2 <= mergeDist2 and best.life > best.maxLife * 0.3
        if near or count >= SCORE_FLOAT_MAX then
            best.value = (best.value or 0) + value
            best.text = "+" .. best.value
            best.size = ScoreFloatSize(best.value)
            best.life = best.maxLife
            return
        end
    end
    local f = SpawnFloatText(x + (math.random() - 0.5) * 20, y - 4,
        "+" .. value, {255, 240, 180}, 1, "score")
    f.value = value
    f.size = ScoreFloatSize(value)
    f.life = 0.78; f.maxLife = 0.78
end

local function SpawnBrickDebris(event, color)
    local count = 6
    for i = 1, count do
        local angle = math.pi * 2 * (i - 1) / count + (math.random() - 0.5) * 0.35
        local speed = 45 + math.random() * 95
        local d = table.remove(debrisPool) or {}
        d.id = nextDebrisId
        d.x = event.x
        d.y = event.y
        d.vx = math.cos(angle) * speed
        d.vy = math.sin(angle) * speed - 75 - math.random() * 35
        d.z = (math.random() - 0.5) * 12
        d.vz = (math.random() - 0.5) * 28
        d.rotation = math.random() * math.pi * 2
        d.angularVelocity = (math.random() - 0.5) * 12
        d.scale = 0.9 + math.random() * 0.25
        d.shrinkRate = 1.1 + math.random() * 0.5
        d.age = 0
        d.lifetime = 0.65 + math.random() * 0.3
        d.r = color.r
        d.g = color.g
        d.b = color.b
        d.aircraftKey = event.aircraftKey
        d.enemyId = event.enemyId
        d.col = event.col
        d.row = event.row
        brickDebris[#brickDebris + 1] = d
        nextDebrisId = nextDebrisId + 1
    end
end

-- 一次实际圆域命中或整机击败只生成一个冲击对象，不逐砖复制；同帧轻震取最大值。
local function SpawnCombatImpact(kind, event)
    local style = VisualCatalog.GetCombatImpactStyle(kind)
    if not style then return end
    local budget = VisualCatalog.GetCombatImpactBudget()
    local impact = #combatImpacts >= budget and table.remove(combatImpacts, 1)
        or table.remove(impactPool)
    impact = impact or {} --[[@as CombatImpact]]
    impact.kind = kind
    impact.x, impact.y = event.x, event.y
    impact.radiusX = kind == "area" and event.radius or (event.width or 48) * 0.5
    impact.radiusY = kind == "area" and event.radius or (event.height or 48) * 0.5
    impact.life, impact.maxLife = style.life, style.life
    impact.phase = ((event.enemyId or 0) % 12) * math.pi / 6
    combatImpacts[#combatImpacts + 1] = impact
    screenShake = math.max(screenShake, style.shake)
    print(string.format("[Presentation] combat impact %s at %.1f,%.1f radius=%.1f/%.1f active=%d",
        kind, impact.x, impact.y, impact.radiusX, impact.radiusY, #combatImpacts))
end

local function ClearCombatImpacts()
    for _, impact in ipairs(combatImpacts) do impactPool[#impactPool + 1] = impact end
    combatImpacts = {}
end

local function UpdateCombatImpacts(dt)
    for i = #combatImpacts, 1, -1 do
        local impact = combatImpacts[i]
        impact.life = impact.life - dt
        if impact.life <= 0 then
            table.remove(combatImpacts, i)
            impactPool[#impactPool + 1] = impact
        end
    end
end

-- WO-14/P2：每个反馈名对应一个只写 Presentation 瞬时状态的处理函数。
-- HandleEvent 按 FEEDBACK_MAP 分派，新增反馈只需补充映射 + 处理函数。
local FEEDBACK_HANDLERS = {
    fullReset = function(event)
        Presentation._chargeRelease.life = 0
        Presentation.ResetChargeHologram()
        screenShake = 0
        waveBannerTimer = 0
        waveBannerBoss = false
        waveBannerKind = "normal"
        waveBannerKey = nil
        stageBannerTimer = 0
        -- WO-16/P9：重置时把存活对象回收进对象池，保持池规模稳定。
        for _, p in ipairs(particles) do particlePool[#particlePool + 1] = p end
        for _, f in ipairs(floatTexts) do floatPool[#floatPool + 1] = f end
        for _, d in ipairs(brickDebris) do debrisPool[#debrisPool + 1] = d end
        particles = {}
        floatTexts = {}
        hitFlashes = {}
        brickDebris = {}
        ejectedBoxes = {}
        baseImpacts = {}
        baseBarrierFlash = 0
        shockRings = {}
        wallFlashes = {}
        ClearCombatImpacts()
        reloadFlash = 0
        upgradeHintPulse = 0
        adStatus = nil
        adToast = nil
    adConfirm = nil
        adConfirm = nil
        adToastTimer = 0
        nextDebrisId = 1
        truckLaunchFlash = {
            normal = 0,
            ice = 0,
            speed = 0,
            giant = 0,
        }
    end,
    waveBanner = function(event)
        waveBannerTimer = 1.8
        waveBannerBoss = event.isBoss == true
        waveBannerKind = event.kind or "normal"
        waveBannerStage = event.stage or 1
        waveBannerStageWave = event.stageWave or event.wave or 1
        waveBannerKey = event.aircraftKey
    end,
    stageStartBanner = function(event)
        stageBannerTimer = 2.2
        stageBannerNumber = event.stage or 1
    end,
    summonNotice = function(event)
        SpawnFloatText(270, 188, "首领召唤增援", {255, 181, 93}, 1.1)
    end,
    brickSpark = function(event)
        local color = VisualCatalog.GetBrickStyle(event.aircraftKey, event.col, event.row)
            or {r = 255, g = 240, b = 180}
        local particleColor = {color.r, color.g, color.b}
        hitFlashes[GetBrickKey(event.enemyId, event.col, event.row)] = 0.12
        if event.destroyed then
            -- v0.10.22：数量与大小随机，多数击毁只给 1~2 火花 + 0~1 碎片，
            -- 约 1/5 概率一缕烟，整体稀疏不重复。
            SpawnParticles(event.x, event.y, particleColor, math.random(1, 2), "spark")
            if math.random() < 0.55 then
                SpawnParticles(event.x, event.y, particleColor, 1, "shard")
            end
            if math.random() < 0.2 then
                SpawnParticles(event.x, event.y,
                    {math.min(255, color.r * 0.5 + 60),
                     math.min(255, color.g * 0.5 + 60),
                     math.min(255, color.b * 0.5 + 70)}, 1, "smoke")
            end
            -- 仅真实得分（玩家击碎）才飘分数字；越线碎裂 score=0，不飘（其惩罚由防线提示承接）。
            local gained = event.score or 0
            if gained > 0 then
                SpawnScoreFloat(event.x, event.y, gained)
            end
            -- v0.10.23：约 1/3 击毁给一个扩散白环，作为点缀式冲击波。
            if math.random() < 0.34 then
                shockRings[#shockRings + 1] = {
                    x = event.x, y = event.y,
                    life = 0.3, maxLife = 0.3,
                    r0 = 6, r1 = 20,
                    r = particleColor and particleColor[1] or 255,
                    g = particleColor and particleColor[2] or 240,
                    b = particleColor and particleColor[3] or 200,
                }
            end
        elseif math.random() < 0.35 then
            -- 普通命中仅约 1/3 概率冒 1 粒小火星。
            SpawnParticles(event.x, event.y, {255, 240, 180}, 1, "spark")
        end
    end,
    brickEjected = function(event)
        SpawnEjectedBox(event)
    end,
    clearBanner = function(event)
        SpawnFloatText(event.x, event.y, "击破", {120, 255, 160}, 1.2)
    end,
    clearImpact = function(event)
        SpawnCombatImpact("clear", event)
    end,
    -- WO-15/P2：防线四位一体（震屏 + 危险带脉冲 + 冲击波 + 警示文字）由 base_hit 单点触发。
    baseShake = function(event)
        screenShake = 0.55
        -- P12：防线受创触发短促命中顿帧，强化冲击重量感（主循环据此对玩法 dt 打折）。
        hitStop = math.max(hitStop, 0.06)
        baseBarrierFlash = 0.62
        table.insert(baseImpacts, {
            id = nextDebrisId,
            x = event.x,
            y = event.y,
            life = 0.72,
            maxLife = 0.72,
            radius = 18,
            spin = (math.random() - 0.5) * 2.4,
        })
        nextDebrisId = nextDebrisId + 1
        SpawnParticles(event.x, event.y, {255, 80, 60}, math.random(4, 7), "spark")
        if math.random() < 0.35 then
            SpawnParticles(event.x, event.y, {180, 150, 150}, 1, "smoke")
        end
        local dmg = event.damage or 1
        local rowTag = event.rows and event.rows > 1 and ("x" .. event.rows .. "行 ") or ""
        SpawnFloatText(event.x, event.y - 34,
            rowTag .. "防线 -" .. tostring(dmg), {255, 110, 80}, 1.05)
    end,
    chargeRelease = function(event)
        if event.chargeProgress == nil then return end
        local r = Presentation._chargeRelease
        r.life = r.maxLife
        r.progress = event.chargeProgress
        r.x, r.y = event.chargeX, event.chargeY
        r.uiX, r.uiY = event.chargeUiX, event.chargeUiY
        -- 释放回声的圈心与蓄力圈共用车辆权威位置，保证发射前后圆心连续。
        r.carX, r.carY = event.carX, event.carY
        r.boosted = event.chargeBoosted == true
    end,
    launchFlash = function(event)
        -- 玩家点击发射：轻度反馈，2 粒随弹种颜色的小火花 + 偶尔一缕烟。
        truckLaunchFlash[event.ballType] = 0.28
        local launchColor = {
            event.ballType == "ice" and 150 or 255,
            event.ballType == "giant" and 170 or 220,
            event.ballType == "speed" and 80 or 160,
        }
        SpawnParticles(event.x or 270, event.y or 850, launchColor, 1, "spark")
        if math.random() < 0.15 then
            SpawnParticles(event.x or 270, (event.y or 850) + 6,
                {200, 200, 210}, 1, "smoke")
        end
        -- v0.10.24：发射点一个快速扩散的青色小环，作为"离弦"反馈。
        shockRings[#shockRings + 1] = {
            x = event.x or 270, y = event.y or 850,
            life = 0.24, maxLife = 0.24,
            r0 = 8, r1 = 26,
            r = launchColor[1], g = launchColor[2], b = launchColor[3],
        }
    end,
    -- v0.13.64：撞墙回弹——沿内法线的一圈扩散环 + 少量弹种色火花，读作「撞上去弹回来」。
    bounceImpact = function(event)
        local color = VisualCatalog.GetBallStyle(event.ballType or "normal")
        local rgb = color and color.color or {255, 240, 200}
        shockRings[#shockRings + 1] = {
            x = event.x, y = event.y, life = 0.26, maxLife = 0.26,
            r0 = 5, r1 = 22,
            r = rgb[1], g = rgb[2], b = rgb[3],
        }
        -- v0.13.66：火花沿内法线定向喷出（从墙面弹向场内），并钉一条贴墙闪光，
        -- 明确读出「撞在墙上」而不是在墙内侧凭空爆发。
        local nx, ny = event.nx or 0, event.ny or 0
        SpawnParticles(event.x, event.y, rgb, math.random(3, 5), "spark", nx, ny)
        local wf = table.remove(wallFlashPool) or {}
        wf.x, wf.y = event.x, event.y
        wf.nx, wf.ny = nx, ny
        wf.life, wf.maxLife = 0.16, 0.16
        wf.r, wf.g, wf.b = rgb[1], rgb[2], rgb[3]
        wallFlashes[#wallFlashes + 1] = wf
        screenShake = math.max(screenShake, 0.05)
    end,
    splitSpark = function(event)
        SpawnParticles(event.x, event.y, {255, 230, 140}, math.random(2, 4), "spark")
        SpawnFloatText(event.x, event.y - 18,
            "分裂", {255, 235, 150}, 0.8)
    end,
    dashSpark = function(event)
        screenShake = math.max(screenShake, 0.08)
        SpawnParticles(event.x, event.y, {255, 160, 70}, 2, "spark")
        SpawnParticles(event.targetX, event.targetY, {255, 210, 80}, 1, "spark")
        SpawnFloatText(event.x, event.y - 18,
            "追击", {255, 170, 80}, 0.8)
    end,
    -- v0.13.55「动能穿刺」：加速车穿块——橙色火花轻推，与「追击」同色系但更短促。
    pierceSpark = function(event)
        SpawnParticles(event.x, event.y, {255, 190, 110}, math.random(2, 3), "spark")
    end,
    pierceArmed = function(event)
        screenShake = math.max(screenShake, 0.16)
        SpawnParticles(event.x, event.y, {205, 145, 255}, math.random(2, 4), "spark")
        local f = SpawnFloatText(event.x, event.y - 22,
            "可以贯穿", {225, 170, 255}, 0.9, "giantReady")
        f.marbleId = event.id
    end,
    pierceConsumed = function(event)
        -- 就绪已被本车消耗，撤掉旧提示；同帧就绪→命中也不能残留到冷却期。
        for i = #floatTexts, 1, -1 do
            local f = floatTexts[i]
            if f.kind == "giantReady" and f.marbleId == event.id then
                floatTexts[i] = floatTexts[#floatTexts]
                floatTexts[#floatTexts] = nil
                floatPool[#floatPool + 1] = f
            end
        end
    end,
    giantBurst = function(event)
        SpawnCombatImpact("area", event)
        SpawnParticles(event.x, event.y, {205, 145, 255},
            math.min(5, 2 + event.hitCount), "spark")
        if math.random() < 0.25 then
            SpawnParticles(event.x, event.y, {190, 160, 210}, 1, "smoke")
        end
        SpawnFloatText(event.x, event.y - 28,
            "范围击碎", {235, 190, 255}, 1.0)
    end,
    -- v0.10.24：主球回库补弹，Dock 轻闪一下。
    reloadPulse = function(event)
        reloadFlash = 0.3
    end,
    -- v0.10.24：选中升级后的中心确认提示（飘字在恢复 playing 后显示）。
    -- v0.13.15：暴击命中反馈——金色"暴击"飘字 + 少量火花，与普通命中区分。
    critSpark = function(event)
        SpawnFloatText(event.x, event.y - 30, "暴击", {255, 214, 96}, 1.15)
        SpawnParticles(event.x, event.y, {255, 214, 96}, math.random(2, 3), "spark")
    end,
    upgradeConfirm = function(event)
        SpawnFloatText(270, 430, (event.name or "强化") .. "  已选择", {140, 235, 255}, 1.1)
        screenShake = math.max(screenShake, 0.05)
    end,
    reviveConfirm = function(event)
        SpawnFloatText(270, 430, "复活  +" .. tostring(event.hp or 50) .. " 血", {226, 228, 232}, 1.2)
        screenShake = math.max(screenShake, 0.12)
    end,
    -- v0.11.0 商业化 P4：道具槽反馈（只写瞬时状态，不触达规则层）
    itemUsed = function(event)
        local label = ({ bomb = "炸弹引爆", freeze = "全场冻结", shield = "护盾展开" })[event.key]
            or "道具生效"
        SpawnFloatText(270, 470, label, {120, 255, 160}, 1.4)
        screenShake = math.max(screenShake, 0.18)
    end,
    itemGranted = function(event)
        SpawnFloatText(270, 780, "道具已入库 · 点一下使用", {120, 255, 160}, 1.0)
    end,
    -- v0.13.58：局内附魔卡反馈（只写瞬时状态，不触达规则层）。
    enchantGranted = function(event)
        local col = ({ common = {92, 150, 255}, rare = {176, 110, 255}, epic = {255, 196, 72} })[event.rarity]
            or {140, 235, 255}
        SpawnFloatText(128, 210, "附魔 · " .. (event.name or ""), col, 1.15)
        SpawnParticles(128, 200, col, 4, "spark")
    end,
    enchantArmed = function(event)
        SpawnFloatText(128, 210, "已顺延 · " .. (event.name or ""), {120, 255, 160}, 1.0)
    end,
    enchantApplied = function(event)
        local col = ({ common = {92, 150, 255}, rare = {176, 110, 255}, epic = {255, 196, 72} })[event.rarity]
            or {140, 235, 255}
        SpawnFloatText(270, 470, "附魔生效 · " .. (event.name or ""), col, 1.3)
        screenShake = math.max(screenShake, 0.14)
    end,
    enchantPierce = function(event)
        -- 穿透：一道向前的亮色速度线 + 火花。
        SpawnParticles(event.x, event.y, {255, 210, 120}, 5, "spark")
        shockRings[#shockRings + 1] = {
            x = event.x, y = event.y, life = 0.2, maxLife = 0.2,
            r0 = 3, r1 = 22, r = 255, g = 210, b = 120,
        }
    end,
    enchantExplode = function(event)
        -- v0.13.58：爆炸 = 大范围扩散双环 + 白芯 + 火花 + 烟 + 震屏（更戏剧化）。
        local rr = (event.radius or 24) * 4.2
        shockRings[#shockRings + 1] = {
            x = event.x, y = event.y, life = 0.5, maxLife = 0.5,
            r0 = 10, r1 = rr, r = 255, g = 150, b = 80,
        }
        shockRings[#shockRings + 1] = {
            x = event.x, y = event.y, life = 0.34, maxLife = 0.34,
            r0 = 4, r1 = rr * 0.62, r = 255, g = 232, b = 190,
        }
        SpawnParticles(event.x, event.y, {255, 150, 80}, 18, "spark")
        SpawnParticles(event.x, event.y, {255, 220, 140}, 6, "smoke")
        SpawnParticles(event.x, event.y, {255, 246, 220}, 5, "shard")
        screenShake = math.max(screenShake, 0.42)
    end,
    enchantChain = function(event)
        -- 连锁 = 命中点向目标点的一串火花 + 冲击环，读作「电弧跳过去」。
        SpawnParticles(event.targetX or event.x, event.targetY or event.y, {150, 200, 255}, 8, "spark")
        SpawnParticles(event.x, event.y, {150, 200, 255}, 6, "spark")
        shockRings[#shockRings + 1] = {
            x = event.targetX or event.x, y = event.targetY or event.y,
            life = 0.32, maxLife = 0.32, r0 = 5, r1 = 24, r = 150, g = 200, b = 255,
        }
        screenShake = math.max(screenShake, 0.1)
    end,
    enchantTriple = function(event)
        SpawnParticles(event.x, event.y, {255, 196, 72}, 8, "spark")
        shockRings[#shockRings + 1] = {
            x = event.x, y = event.y, life = 0.26, maxLife = 0.26,
            r0 = 4, r1 = 26, r = 255, g = 196, b = 72,
        }
    end,
    enchantSplit = function(event)
        SpawnParticles(event.x, event.y, {92, 220, 255}, 5, "spark")
    end,
    enchantHoming = function(event)
        SpawnParticles(event.targetX or event.x, event.targetY or event.y, {120, 255, 200}, 3, "spark")
    end,
    enchantLifesteal = function(event)
        SpawnFloatText(event.x, event.y - 26, "+" .. tostring(event.amount or 1), {120, 255, 160}, 1.0)
        SpawnParticles(event.x, event.y, {120, 255, 160}, 4, "spark")
    end,
    -- v0.13.65：幻影体素块三条反馈。
    phantomFired = function(event)
        -- 源机引擎灯处青白闪光（幻影块「弹出」的瞬间）。
        SpawnParticles(event.x, event.y, {180, 255, 245}, 3, "spark")
        shockRings[#shockRings + 1] = {
            x = event.x, y = event.y, life = 0.22, maxLife = 0.22,
            r0 = 4, r1 = 18,
            r = 150, g = 240, b = 230,
        }
    end,
    phantomDestroyed = function(event)
        -- 幻影块被击碎：青白火花 + 少量碎片。
        SpawnParticles(event.x, event.y, {200, 255, 250}, 4, "spark")
        if math.random() < 0.5 then
            SpawnParticles(event.x, event.y, {170, 230, 230}, 1, "shard")
        end
    end,
    phantomBreached = function(event)
        -- 幻影块越过防线：警示色小冲击环（真正的扣血反馈由 base_hit 承担）。
        shockRings[#shockRings + 1] = {
            x = event.x, y = event.y, life = 0.3, maxLife = 0.3,
            r0 = 6, r1 = 26,
            r = 120, g = 220, b = 255,
        }
    end,
    -- marble_removed 无需维护拖尾状态。
}

local function HandleEvent(event)
    -- WO-15/P2：未登记事件直派到同名处理器（如 marble_removed），保持向后兼容。
    if type(event) ~= "table" or not event.type then return end
    local names = FEEDBACK_MAP[event.type]
    if names then
        for _, name in ipairs(names) do
            local handler = FEEDBACK_HANDLERS[name]
            if handler then handler(event) end
        end
    elseif FEEDBACK_HANDLERS[event.type] then
        FEEDBACK_HANDLERS[event.type](event)
    end
end

local function UpdateParticles(dt)
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.life = p.life - dt
        if p.life <= 0 then
            -- WO-16/P9：回收进对象池，避免每次重新分配 table。
            particles[i] = particles[#particles]
            particles[#particles] = nil
            particlePool[#particlePool + 1] = p
        else
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            if p.kind == "smoke" then
                -- 烟雾：原地附近强阻尼缓漂、无重力、不断膨胀，不堆向屏顶。
                p.vx = p.vx * 0.90
                p.vy = p.vy * 0.90
                p.size = p.size + 9 * dt
            elseif p.kind == "shard" then
                -- 碎片：受重力、自转。
                p.vy = p.vy + 300 * dt
                p.vx = p.vx * 0.98
                p.angle = (p.angle or 0) + (p.spin or 0) * dt
            else
                p.vy = p.vy + 300 * dt
                p.vx = p.vx * 0.98
            end
        end
    end
end

local function UpdateFloatTexts(dt)
    for i = #floatTexts, 1, -1 do
        local f = floatTexts[i]
        f.life = f.life - dt
        if f.life <= 0 then
            floatTexts[i] = floatTexts[#floatTexts]
            floatTexts[#floatTexts] = nil
            floatPool[#floatPool + 1] = f
        else
            f.y = f.y + f.vy * dt
            -- 上飘线性减速到停（不回坠），数字停在顶点淡出，避免飘出屏幕。
            f.vy = math.min(0, f.vy + 170 * dt)
        end
    end
end

local function UpdateHitFlashes(dt)
    for key, timeLeft in pairs(hitFlashes) do
        timeLeft = timeLeft - dt
        if timeLeft <= 0 then hitFlashes[key] = nil
        else hitFlashes[key] = timeLeft end
    end
end

SpawnEjectedBox = function(event)
    local box = {
        id = nextDebrisId,
        x = event.x,
        y = event.y,
        vx = event.vx,
        vy = event.vy,
        z = 0.0,
        vz = 4.5 + math.random() * 3.0,
        rotation = event.rotation,
        pitch = event.pitch or 0,
        roll = event.roll or 0,
        angularVelocity = event.angularVelocity,
        axisPitchSpeed = event.axisPitchSpeed or 0,
        axisRollSpeed = event.axisRollSpeed or 0,
        age = 0,
        lifetime = math.max(1.6, event.lifetime or 1.6),
        size = event.brickSize,
        style = event.style or event.aircraftKey,
        enemyId = event.enemyId,
        col = event.col,
        row = event.row,
    }
    ejectedBoxes[#ejectedBoxes + 1] = box
    nextDebrisId = nextDebrisId + 1
end

-- WO-17：被命中的敌方方块从编队脱离，持续旋转并沿规则层给出的随机向量飞散。
-- 同屏飞散箱体硬上限：每个箱体是独立 3D 节点 + draw call，超出预算时丢弃最旧对象，
-- 防止高命中频率下真机 draw call/节点堆积导致帧率归零（表现为 UI 不刷新、画面卡死）。
local MAX_EJECTED_BOXES = 24
local function UpdateEjectedBoxes(dt)
    for i = #ejectedBoxes, 1, -1 do
        local box = ejectedBoxes[i]
        box.age = box.age + dt
        box.x = box.x + box.vx * dt
        box.y = box.y + box.vy * dt
        box.z = box.z + box.vz * dt
        box.vy = box.vy + 260 * dt
        box.vx = box.vx * (1 - math.min(0.75, dt * 1.5))
        box.vz = box.vz - 12 * dt
        box.rotation = box.rotation + box.angularVelocity * dt
        box.pitch = box.pitch + box.axisPitchSpeed * dt
        box.roll = box.roll + box.axisRollSpeed * dt
        if box.age >= box.lifetime then
            ejectedBoxes[i] = ejectedBoxes[#ejectedBoxes]
            ejectedBoxes[#ejectedBoxes] = nil
        end
    end
    while #ejectedBoxes > MAX_EJECTED_BOXES do
        ejectedBoxes[1] = ejectedBoxes[#ejectedBoxes]
        ejectedBoxes[#ejectedBoxes] = nil
    end
end

local function UpdateBrickDebris(dt)
    for i = #brickDebris, 1, -1 do
        local debris = brickDebris[i]
        debris.age = debris.age + dt
        debris.x = debris.x + debris.vx * dt
        debris.y = debris.y + debris.vy * dt
        debris.z = debris.z + debris.vz * dt
        debris.vy = debris.vy + 240 * dt
        debris.vx = debris.vx * (1 - math.min(0.8, dt * 1.8))
        debris.vz = debris.vz * (1 - math.min(0.6, dt * 1.2))
        debris.rotation = debris.rotation + debris.angularVelocity * dt
        debris.scale = math.max(0, debris.scale - debris.shrinkRate * dt)
        if debris.age >= debris.lifetime or debris.scale <= 0 then
            brickDebris[i] = brickDebris[#brickDebris]
            brickDebris[#brickDebris] = nil
            debrisPool[#debrisPool + 1] = debris
        end
    end
end

local function UpdateBaseImpacts(dt)
    baseBarrierFlash = math.max(0, baseBarrierFlash - dt)
    for i = #baseImpacts, 1, -1 do
        local impact = baseImpacts[i]
        impact.life = impact.life - dt
        impact.radius = impact.radius + 190 * dt
        impact.spin = impact.spin + dt * 4.5
        if impact.life <= 0 then
            table.remove(baseImpacts, i)
        end
    end
end

local function UpdateShockRings(dt)
    for i = #shockRings, 1, -1 do
        local ring = shockRings[i]
        ring.life = ring.life - dt
        if ring.life <= 0 then
            shockRings[i] = shockRings[#shockRings]
            shockRings[#shockRings] = nil
        end
    end
    for i = #wallFlashes, 1, -1 do
        local f = wallFlashes[i]
        f.life = f.life - dt
        if f.life <= 0 then
            wallFlashes[i] = wallFlashes[#wallFlashes]
            wallFlashes[#wallFlashes] = nil
            wallFlashPool[#wallFlashPool + 1] = f
        end
    end
end

local function UpdateTruckLaunchFlashes(dt)
    for ballType, timeLeft in pairs(truckLaunchFlash) do
        truckLaunchFlash[ballType] = math.max(0, timeLeft - dt)
    end
end

function Presentation.Init()
    screenShake = 0
    waveBannerTimer = 0
    waveBannerBoss = false
    waveBannerKind = "normal"
    waveBannerKey = nil
    stageBannerTimer = 0
    particles = {}
    floatTexts = {}
    hitFlashes = {}
    brickDebris = {}
    ejectedBoxes = {}
    baseImpacts = {}
    baseBarrierFlash = 0
    shockRings = {}
    wallFlashes = {}
    combatImpacts = {}
    impactPool = {}
    reloadFlash = 0
    upgradeHintPulse = 0
    adStatus = nil
    adToast = nil
    adToastTimer = 0
    cloudStatus = "idle"
    nextDebrisId = 1
    -- WO-16/P9：对象池在重开时清空回收对象，避免旧局残留引用（id 已随 nextDebrisId 重置）。
    particlePool = {}
    debrisPool = {}
    floatPool = {}
    truckLaunchFlash = {
        normal = 0,
        ice = 0,
        speed = 0,
        giant = 0,
    }
    Presentation._chargeRelease.life = 0
    Presentation.ResetChargeHologram()
    print("[Presentation] visual state initialized")
end

function Presentation.Update(dt, gameSnapshot, events)
    Presentation.UpdateChargeHologram(dt, gameSnapshot, events)
    Presentation._chargeRelease.life = math.max(0, Presentation._chargeRelease.life - dt)
    if screenShake > 0 then screenShake = math.max(0, screenShake - dt) end
    if waveBannerTimer > 0 then waveBannerTimer = math.max(0, waveBannerTimer - dt) end
    if stageBannerTimer > 0 then stageBannerTimer = math.max(0, stageBannerTimer - dt) end
    if hitStop > 0 then hitStop = math.max(0, hitStop - dt) end
    if reloadFlash > 0 then reloadFlash = math.max(0, reloadFlash - dt) end
    if upgradeHintPulse > 0 then upgradeHintPulse = math.max(0, upgradeHintPulse - dt) end
    if adToastTimer > 0 then
        adToastTimer = math.max(0, adToastTimer - dt)
        if adToastTimer <= 0 then adToast = nil end
    end

    for _, event in ipairs(events) do
        HandleEvent(event)
    end

    -- 退菜单立即回收；战斗暂停/升级时只衰减视觉，不推进技能冷却。
    if gameSnapshot and gameSnapshot.state == "menu" then ClearCombatImpacts() end
    UpdateCombatImpacts(dt)
    UpdateParticles(dt)
    UpdateFloatTexts(dt)
    UpdateHitFlashes(dt)
    UpdateBrickDebris(dt)
    UpdateEjectedBoxes(dt)
    UpdateBaseImpacts(dt)
    UpdateShockRings(dt)
    UpdateTruckLaunchFlashes(dt)
end

function Presentation.GetSnapshot()
    return {
        chargeRelease = Presentation._chargeRelease,
        chargeHologram = Presentation._chargeHologram,
        screenShake = screenShake,
        hitStop = hitStop,    -- P12：主循环读取，对玩法 dt 打折实现顿帧
        waveBannerTimer = waveBannerTimer,    -- A2：波次横幅入场计时（秒，1.8 起递减）
        waveBannerBoss = waveBannerBoss,
        waveBannerKind = waveBannerKind,
        waveBannerStage = waveBannerStage,
        waveBannerStageWave = waveBannerStageWave,
        waveBannerKey = waveBannerKey,
        stageBannerTimer = stageBannerTimer,
        stageBannerNumber = stageBannerNumber,
        particles = particles,
        floatTexts = floatTexts,
        hitFlashes = hitFlashes,
        brickDebris = brickDebris,
        baseImpacts = baseImpacts,
        shockRings = shockRings,
        wallFlashes = wallFlashes,
        combatImpacts = combatImpacts,
        ejectedBoxes = ejectedBoxes,
        baseBarrierFlash = baseBarrierFlash,
        reloadFlash = reloadFlash,
        upgradeHintPulse = upgradeHintPulse,
        adStatus = adStatus,
        adToast = adToast,
        adConfirm = adConfirm, -- v0.13.72：广告确认弹窗
        cloudStatus = cloudStatus,
        truckLaunchFlash = truckLaunchFlash,
        visualCatalog = VisualCatalog,
    }
end

-- v0.10.24：升级面板空白区域被点按时，由编排层直接触发提示脉冲（非领域事件）。
function Presentation.PulseUpgradeHint()
    upgradeHintPulse = 0.5
end

function Presentation.SetAdStatus(status)
    adStatus = status
end

function Presentation.SetAdToast(message)
    adToast = message
    adToastTimer = 2.2
end

-- v0.13.72：广告二次确认弹窗状态（nil = 不显示）。绘制在后端 overlay 末段。
---@param state table|nil { point, title, reward, hint }
function Presentation.SetAdConfirm(state)
    adConfirm = state
end

function Presentation.SetCloudStatus(status)
    cloudStatus = status or "idle"
end

return Presentation
