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

local function SpawnParticles(x, y, color, count)
    count = count or 8
    for _ = 1, count do
        local angle = math.random() * math.pi * 2
        local speed = 60 + math.random() * 160
        local p = table.remove(particlePool) or {}
        p.x = x; p.y = y
        p.vx = math.cos(angle) * speed
        p.vy = math.sin(angle) * speed - 50
        p.life = 0.4 + math.random() * 0.3
        p.maxLife = 0.7
        p.r = color[1]; p.g = color[2]; p.b = color[3]
        p.size = 3 + math.random() * 3
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
            SpawnParticles(event.x, event.y, particleColor, 10)
            SpawnFloatText(event.x, event.y - 4, "+" .. event.score, {255, 240, 180}, 0.8)
        else
            SpawnParticles(event.x, event.y, {255, 240, 180}, 4)
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
        SpawnParticles(event.x, event.y, {255, 80, 60}, 24)
        local dmg = event.damage or 1
        local rowTag = event.rows and event.rows > 1 and ("x" .. event.rows .. "行 ") or ""
        SpawnFloatText(event.x, event.y - 34,
            rowTag .. "防线 -" .. tostring(dmg), {255, 110, 80}, 1.05)
    end,
    launchFlash = function(event)
        truckLaunchFlash[event.ballType] = 0.28
        SpawnParticles(event.x or 270, event.y or 850, {
            event.ballType == "ice" and 150 or 255,
            event.ballType == "giant" and 170 or 220,
            event.ballType == "speed" and 80 or 160,
        }, 8)
    end,
    splitSpark = function(event)
        SpawnParticles(event.x, event.y, {255, 230, 140}, 16)
        SpawnFloatText(event.x, event.y - 18,
            "分裂 G" .. event.generation, {255, 235, 150}, 0.8)
    end,
    dashSpark = function(event)
        screenShake = math.max(screenShake, 0.08)
        SpawnParticles(event.x, event.y, {255, 160, 70}, 10)
        SpawnParticles(event.targetX, event.targetY, {255, 210, 80}, 8)
        SpawnFloatText(event.x, event.y - 18,
            "追击 x" .. event.damage, {255, 170, 80}, 0.8)
    end,
    pierceArmed = function(event)
        screenShake = math.max(screenShake, 0.16)
        SpawnParticles(event.x, event.y, {205, 145, 255}, 16)
        SpawnFloatText(event.x, event.y - 22, "贯穿就绪!", {225, 170, 255}, 0.9)
    end,
    giantBurst = function(event)
        screenShake = math.max(screenShake, 0.22)
        SpawnParticles(event.x, event.y, {205, 145, 255},
            math.min(32, 12 + event.hitCount))
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
            p.vy = p.vy + 300 * dt
            p.vx = p.vx * 0.98
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
