-- Presentation.lua
-- 表现状态控制器：消费 Game 发布的领域事件，维护与玩法无关的瞬时视觉效果。

local VisualCatalog = require "VisualCatalog"

local Presentation = {}

local screenShake = 0
local waveBannerTimer = 0
local hitStop = 0    -- P12：命中顿帧（hitstop），由大命中事件触发，期间主循环对玩法 dt 打折
local particles = {}
local floatTexts = {}
local hitFlashes = {}
local brickDebris = {}
local ejectedBoxes = {}
local baseImpacts = {}
local baseBarrierFlash = 0
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
    brick_hit = {"brickSpark"},
    brick_ejected = {"brickEjected"},
    enemy_cleared = {"clearBanner"},
    base_hit = {"baseShake"},
    marble_launched = {"launchFlash"},
    normal_split = {"splitSpark"},
    speed_dash = {"dashSpark"},
    giant_pierce_armed = {"pierceArmed"},
    giant_area_hit = {"giantBurst"},
    game_reset = {"fullReset"},
}

local function GetBrickKey(enemyId, col, row)
    return tostring(enemyId) .. ":" .. tostring(col) .. ":" .. tostring(row)
end

-- v0.10.21：粒子分三类，小而稀疏、偶尔点缀。
--  spark 小亮点（软圆）/ shard 三角碎片（自旋、重力）/ smoke 烟雾（上飘、膨胀、半透明）。
local function SpawnParticles(x, y, color, count, kind)
    kind = kind or "spark"
    count = count or 4
    for _ = 1, count do
        local p = table.remove(particlePool) or {}
        p.kind = kind
        p.x = x; p.y = y
        p.r = color[1]; p.g = color[2]; p.b = color[3]
        if kind == "smoke" then
            local angle = -math.pi / 2 + (math.random() - 0.5) * 1.8
            local speed = 8 + math.random() * 26
            p.vx = math.cos(angle) * speed
            p.vy = math.sin(angle) * speed
            -- 生命与尺寸拉开随机范围，避免每缕烟一样大、一样久。
            p.life = 0.45 + math.random() * 0.45
            p.maxLife = p.life
            p.size = 4 + math.random() * 6
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
            local angle = math.random() * math.pi * 2
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

local function SpawnFloatText(x, y, text, color, sizeMul)
    local f = table.remove(floatPool) or {}
    f.x = x; f.y = y; f.vy = -40
    f.life = 0.9; f.maxLife = 0.9
    f.text = text
    f.color = color or {255, 255, 255}
    f.size = (sizeMul or 1) * 20
    floatTexts[#floatTexts + 1] = f
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

-- WO-14/P2：每个反馈名对应一个只写 Presentation 瞬时状态的处理函数。
-- HandleEvent 按 FEEDBACK_MAP 分派，新增反馈只需补充映射 + 处理函数。
local FEEDBACK_HANDLERS = {
    fullReset = function(event)
        screenShake = 0
        waveBannerTimer = 0
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
            SpawnFloatText(event.x, event.y - 4, "+" .. event.score, {255, 240, 180}, 0.8)
        elseif math.random() < 0.35 then
            -- 普通命中仅约 1/3 概率冒 1 粒小火星。
            SpawnParticles(event.x, event.y, {255, 240, 180}, 1, "spark")
        end
    end,
    brickEjected = function(event)
        SpawnEjectedBox(event)
    end,
    clearBanner = function(event)
        SpawnFloatText(event.x, event.y, "击破!", {120, 255, 160}, 1.2)
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
    end,
    splitSpark = function(event)
        SpawnParticles(event.x, event.y, {255, 230, 140}, math.random(2, 4), "spark")
        SpawnFloatText(event.x, event.y - 18,
            "分裂 G" .. event.generation, {255, 235, 150}, 0.8)
    end,
    dashSpark = function(event)
        screenShake = math.max(screenShake, 0.08)
        SpawnParticles(event.x, event.y, {255, 160, 70}, 2, "spark")
        SpawnParticles(event.targetX, event.targetY, {255, 210, 80}, 1, "spark")
        SpawnFloatText(event.x, event.y - 18,
            "追击 x" .. event.damage, {255, 170, 80}, 0.8)
    end,
    pierceArmed = function(event)
        screenShake = math.max(screenShake, 0.16)
        SpawnParticles(event.x, event.y, {205, 145, 255}, math.random(2, 4), "spark")
        SpawnFloatText(event.x, event.y - 22, "贯穿就绪!", {225, 170, 255}, 0.9)
    end,
    giantBurst = function(event)
        screenShake = math.max(screenShake, 0.22)
        SpawnParticles(event.x, event.y, {205, 145, 255},
            math.min(5, 2 + event.hitCount), "spark")
        if math.random() < 0.25 then
            SpawnParticles(event.x, event.y, {190, 160, 210}, 1, "smoke")
        end
        SpawnFloatText(event.x, event.y - 28,
            "圆域 x" .. event.hitCount, {235, 190, 255}, 1.0)
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
                -- 烟雾：轻微上飘减速、无重力、不断膨胀。
                p.vx = p.vx * 0.94
                p.vy = p.vy * 0.96 - 14 * dt
                p.size = p.size + 10 * dt
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
            f.vy = f.vy * 0.96
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

local function UpdateTruckLaunchFlashes(dt)
    for ballType, timeLeft in pairs(truckLaunchFlash) do
        truckLaunchFlash[ballType] = math.max(0, timeLeft - dt)
    end
end

function Presentation.Init()
    screenShake = 0
    waveBannerTimer = 0
    particles = {}
    floatTexts = {}
    hitFlashes = {}
    brickDebris = {}
    ejectedBoxes = {}
    baseImpacts = {}
    baseBarrierFlash = 0
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
    print("[Presentation] visual state initialized")
end

function Presentation.Update(dt, gameSnapshot, events)
    if screenShake > 0 then screenShake = math.max(0, screenShake - dt) end
    if waveBannerTimer > 0 then waveBannerTimer = math.max(0, waveBannerTimer - dt) end
    if hitStop > 0 then hitStop = math.max(0, hitStop - dt) end

    for _, event in ipairs(events) do
        HandleEvent(event)
    end

    UpdateParticles(dt)
    UpdateFloatTexts(dt)
    UpdateHitFlashes(dt)
    UpdateBrickDebris(dt)
    UpdateEjectedBoxes(dt)
    UpdateBaseImpacts(dt)
    UpdateTruckLaunchFlashes(dt)
end

function Presentation.GetSnapshot()
    return {
        screenShake = screenShake,
        hitStop = hitStop,    -- P12：主循环读取，对玩法 dt 打折实现顿帧
        waveBannerTimer = waveBannerTimer,    -- A2：波次横幅入场计时（秒，1.8 起递减）
        particles = particles,
        floatTexts = floatTexts,
        hitFlashes = hitFlashes,
        brickDebris = brickDebris,
        baseImpacts = baseImpacts,
        ejectedBoxes = ejectedBoxes,
        baseBarrierFlash = baseBarrierFlash,
        truckLaunchFlash = truckLaunchFlash,
        visualCatalog = VisualCatalog,
    }
end

return Presentation
