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

local function HandleEvent(event)
    if event.type == "game_reset" then
        screenShake = 0
        waveBannerTimer = 0
        particles = {}
        floatTexts = {}
        marbleTrails = {}
        hitFlashes = {}
    elseif event.type == "wave_started" then
        waveBannerTimer = 1.8
    elseif event.type == "brick_hit" then
        local color = VisualCatalog.GetBrickStyle(event.veggieKey, event.col, event.row)
            or {r = 255, g = 240, b = 180}
        local particleColor = {color.r, color.g, color.b}
        hitFlashes[GetBrickKey(event.enemyId, event.col, event.row)] = 0.12
        if event.destroyed then
            SpawnParticles(event.x, event.y, particleColor, 10)
            SpawnFloatText(event.x, event.y - 4, "+" .. event.score, {255, 240, 180}, 0.8)
        else
            SpawnParticles(event.x, event.y, {255, 240, 180}, 4)
        end
    elseif event.type == "enemy_cleared" then
        SpawnFloatText(event.x, event.y, "击破!", {120, 255, 160}, 1.2)
    elseif event.type == "base_hit" then
        screenShake = 0.4
        SpawnParticles(event.x, event.y, {255, 80, 60}, 16)
    elseif event.type == "marble_removed" then
        marbleTrails[event.id] = nil
    elseif event.type == "normal_echo" then
        SpawnParticles(event.x, event.y, {255, 230, 140}, 12)
        SpawnFloatText(event.x, event.y - 18, "双响!", {255, 235, 150}, 0.8)
    elseif event.type == "speed_overload" then
        screenShake = math.max(screenShake, 0.12)
        SpawnParticles(event.x, event.y, {255, 160, 70}, 12)
        SpawnFloatText(event.x, event.y - 18, "超载 x" .. #event.targets, {255, 170, 80}, 0.8)
        for _, target in ipairs(event.targets) do
            SpawnParticles(target.x, target.y, {255, 210, 80}, 6)
        end
    elseif event.type == "giant_pierce_armed" then
        screenShake = math.max(screenShake, 0.16)
        SpawnParticles(event.x, event.y, {205, 145, 255}, 16)
        SpawnFloatText(event.x, event.y - 22, "贯穿!", {225, 170, 255}, 0.9)
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
        visualCatalog = VisualCatalog,
    }
end

return Presentation
