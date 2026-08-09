-- Presentation.lua
-- 表现状态控制器：消费 Game 发布的领域事件，维护与玩法无关的瞬时视觉效果。

local VisualCatalog = require "VisualCatalog"

local Presentation = {}

local screenShake = 0
local waveBannerTimer = 0
local particles = {}
local floatTexts = {}
local marbleTrails = {}
local hitFlashes = {}
local brickDebris = {}
local baseImpacts = {}
local baseBarrierFlash = 0
local truckLaunchFlash = {
    normal = 0,
    ice = 0,
    speed = 0,
    giant = 0,
}
local nextDebrisId = 1

local function GetBrickKey(enemyId, col, row)
    return tostring(enemyId) .. ":" .. tostring(col) .. ":" .. tostring(row)
end

local function SpawnParticles(x, y, color, count)
    count = count or 8
    for _ = 1, count do
        local angle = math.random() * math.pi * 2
        local speed = 60 + math.random() * 160
        table.insert(particles, {
            x = x, y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed - 50,
            life = 0.4 + math.random() * 0.3, maxLife = 0.7,
            r = color[1], g = color[2], b = color[3],
            size = 3 + math.random() * 3,
        })
    end
end

local function SpawnFloatText(x, y, text, color, sizeMul)
    table.insert(floatTexts, {
        x = x, y = y, vy = -40,
        life = 0.9, maxLife = 0.9, text = text,
        color = color or {255, 255, 255},
        size = (sizeMul or 1) * 20,
    })
end

local function SpawnBrickDebris(event, color)
    local count = 6
    for i = 1, count do
        local angle = math.pi * 2 * (i - 1) / count + (math.random() - 0.5) * 0.35
        local speed = 45 + math.random() * 95
        table.insert(brickDebris, {
            id = nextDebrisId,
            x = event.x,
            y = event.y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed - 75 - math.random() * 35,
            z = (math.random() - 0.5) * 12,
            vz = (math.random() - 0.5) * 28,
            rotation = math.random() * math.pi * 2,
            angularVelocity = (math.random() - 0.5) * 12,
            scale = 0.9 + math.random() * 0.25,
            shrinkRate = 1.1 + math.random() * 0.5,
            age = 0,
            lifetime = 0.65 + math.random() * 0.3,
            r = color.r,
            g = color.g,
            b = color.b,
            veggieKey = event.veggieKey,
            enemyId = event.enemyId,
            col = event.col,
            row = event.row,
        })
        nextDebrisId = nextDebrisId + 1
    end
end

local function HandleEvent(event)
    if event.type == "game_reset" then
        screenShake = 0
        waveBannerTimer = 0
        particles = {}
        floatTexts = {}
        marbleTrails = {}
        hitFlashes = {}
        brickDebris = {}
        baseImpacts = {}
        baseBarrierFlash = 0
        nextDebrisId = 1
        truckLaunchFlash = {
            normal = 0,
            ice = 0,
            speed = 0,
            giant = 0,
        }
    elseif event.type == "wave_started" then
        waveBannerTimer = 1.8
    elseif event.type == "brick_hit" then
        local color = VisualCatalog.GetBrickStyle(event.veggieKey, event.col, event.row)
            or {r = 255, g = 240, b = 180}
        local particleColor = {color.r, color.g, color.b}
        hitFlashes[GetBrickKey(event.enemyId, event.col, event.row)] = 0.12
        if event.destroyed then
            SpawnParticles(event.x, event.y, particleColor, 10)
            SpawnBrickDebris(event, color)
            SpawnFloatText(event.x, event.y - 4, "+" .. event.score, {255, 240, 180}, 0.8)
        else
            SpawnParticles(event.x, event.y, {255, 240, 180}, 4)
        end
    elseif event.type == "enemy_cleared" then
        SpawnFloatText(event.x, event.y, "击破!", {120, 255, 160}, 1.2)
    elseif event.type == "base_hit" then
        screenShake = 0.55
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
        SpawnFloatText(event.x, event.y - 34, "防线受创!", {255, 110, 80}, 1.05)
    elseif event.type == "marble_launched" then
        truckLaunchFlash[event.ballType] = 0.28
        SpawnParticles(event.x or 270, event.y or 850, {
            event.ballType == "ice" and 150 or 255,
            event.ballType == "giant" and 170 or 220,
            event.ballType == "speed" and 80 or 160,
        }, 8)
    elseif event.type == "marble_removed" then
        marbleTrails[event.id] = nil
    elseif event.type == "normal_split" then
        SpawnParticles(event.x, event.y, {255, 230, 140}, 16)
        SpawnFloatText(event.x, event.y - 18,
            "分裂 G" .. event.generation, {255, 235, 150}, 0.8)
    elseif event.type == "speed_dash" then
        screenShake = math.max(screenShake, 0.08)
        SpawnParticles(event.x, event.y, {255, 160, 70}, 10)
        SpawnParticles(event.targetX, event.targetY, {255, 210, 80}, 8)
        SpawnFloatText(event.x, event.y - 18,
            "追击 x" .. event.damage, {255, 170, 80}, 0.8)
    elseif event.type == "giant_pierce_armed" then
        screenShake = math.max(screenShake, 0.16)
        SpawnParticles(event.x, event.y, {205, 145, 255}, 16)
        SpawnFloatText(event.x, event.y - 22, "贯穿就绪!", {225, 170, 255}, 0.9)
    elseif event.type == "giant_area_hit" then
        screenShake = math.max(screenShake, 0.22)
        SpawnParticles(event.x, event.y, {205, 145, 255},
            math.min(32, 12 + event.hitCount))
        SpawnFloatText(event.x, event.y - 28,
            "圆域 x" .. event.hitCount, {235, 190, 255}, 1.0)
    end
end

local function UpdateParticles(dt)
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(particles, i)
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
            table.remove(floatTexts, i)
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
            table.remove(brickDebris, i)
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

local function UpdateTrails(gameSnapshot)
    local activeIds = {}
    for _, marble in ipairs(gameSnapshot.marbles) do
        activeIds[marble.id] = true
        local trail = marbleTrails[marble.id]
        if not trail then
            trail = {}
            marbleTrails[marble.id] = trail
        end
        table.insert(trail, 1, {x = marble.x, y = marble.y})
        if #trail > 10 then table.remove(trail) end
    end
    for id in pairs(marbleTrails) do
        if not activeIds[id] then marbleTrails[id] = nil end
    end
end

function Presentation.Init()
    screenShake = 0
    waveBannerTimer = 0
    particles = {}
    floatTexts = {}
    marbleTrails = {}
    hitFlashes = {}
    brickDebris = {}
    baseImpacts = {}
    baseBarrierFlash = 0
    nextDebrisId = 1
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

    for _, event in ipairs(events) do
        HandleEvent(event)
    end

    UpdateParticles(dt)
    UpdateFloatTexts(dt)
    UpdateHitFlashes(dt)
    UpdateBrickDebris(dt)
    UpdateBaseImpacts(dt)
    UpdateTruckLaunchFlashes(dt)
    UpdateTrails(gameSnapshot)
end

function Presentation.GetSnapshot()
    return {
        screenShake = screenShake,
        waveBannerTimer = waveBannerTimer,
        particles = particles,
        floatTexts = floatTexts,
        marbleTrails = marbleTrails,
        hitFlashes = hitFlashes,
        brickDebris = brickDebris,
        baseImpacts = baseImpacts,
        baseBarrierFlash = baseBarrierFlash,
        truckLaunchFlash = truckLaunchFlash,
        visualCatalog = VisualCatalog,
    }
end

return Presentation
