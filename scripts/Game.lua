-- Game.lua
-- 燃烧的蔬菜核心玩法。只维护规则、碰撞和权威状态，不依赖任何渲染 API。

local VeggieData = require "VeggiePixelData"

local Game = {}

local DW = 540
local DH = 960
local BASE_BRICK_SIZE = 20
local SLING_X = 270
local SLING_Y = 850
local MAX_PULL = 150
local DANGER_Y = 900
local BASE_HP = 5

local BALL_TYPES = {
    normal = {
        radius = 9, speed = 560, damage = 1,
        splitChance = 0.05, splitAngle = 18,
    },
    speed = {
        radius = 8, speed = 680, damage = 1,
        speedBoost = 1.15, maxSpeed = 1250,
        damageStep = 190, maxDamage = 3,
    },
    ice = {
        radius = 9, speed = 520, damage = 1,
        freezeDuration = 3.0,
    },
    giant = {
        radius = 16, speed = 420, damage = 2,
        pierceAfterBounce = true,
        areaRadiusCells = 3.5,
    },
}
local BALL_ORDER = { "normal", "ice", "speed", "giant" }

local gameState = "menu"
local score = 0
local highScore = 0
local baseHp = BASE_HP
local wave = 1
local elapsed = 0
local waveCooldown = 0

local veggies = {}
local marbles = {}
local ballQueue = {}
local activeBall = nil
local ballCycleIndex = 0
local aiming = false
local aimX = SLING_X
local aimY = SLING_Y

local pendingEvents = {}
local nextEnemyId = 1
local nextMarbleId = 1
local randomState = 1

local ResetGame
local SpawnWave
local UpdateMarbles
local UpdateEnemies
local UpdateReload
local UpdateWaveLogic

local function Emit(eventType, data)
    data = data or {}
    data.type = eventType
    table.insert(pendingEvents, data)
end

local function SetRandomSeed(seed)
    randomState = math.floor(tonumber(seed) or 1) % 2147483647
    if randomState <= 0 then randomState = 1 end
end

local function Random()
    randomState = (randomState * 16807) % 2147483647
    return (randomState - 1) / 2147483646
end

local function RandomInt(minValue, maxValue)
    return minValue + math.floor(Random() * (maxValue - minValue + 1))
end

local function GetBrickSize(waveNum)
    if waveNum <= 2 then return 18 end
    if waveNum <= 4 then return 19 end
    return BASE_BRICK_SIZE
end

local function GetWaveParams(waveNum)
    local count
    if waveNum <= 1 then count = 1
    elseif waveNum == 2 then count = 2
    elseif waveNum <= 4 then count = 2 + math.floor((waveNum - 2) / 2)
    else count = math.min(6, 3 + math.floor((waveNum - 4) / 2)) end

    local speed = 22 + (waveNum - 1) * 6
    local hp = 1
    if waveNum >= 6 then hp = 2 end
    if waveNum >= 10 then hp = 3 end
    return count, speed, hp
end

local function CreateMarble(ballType)
    local def = BALL_TYPES[ballType]
    local marble = {
        id = nextMarbleId,
        x = SLING_X, y = SLING_Y,
        vx = 0, vy = 0,
        radius = def.radius,
        speed = def.speed,
        ballType = ballType,
        onSling = true,
        alive = true,
        bounceCount = 0,
        isPrimary = true,
        generation = 0,
        ignoredBrick = nil,
        giantPiercing = false,
    }
    nextMarbleId = nextMarbleId + 1
    return marble
end

local function NextBallType()
    ballCycleIndex = ballCycleIndex + 1
    if ballCycleIndex > #BALL_ORDER then ballCycleIndex = 1 end
    return BALL_ORDER[ballCycleIndex]
end

local function EnqueueNextBall()
    table.insert(ballQueue, NextBallType())
end

local function LoadBalls()
    ballQueue = {}
    ballCycleIndex = 0
    for _ = 1, #BALL_ORDER do EnqueueNextBall() end
    activeBall = CreateMarble(table.remove(ballQueue, 1))
    EnqueueNextBall()
end

ResetGame = function()
    score = 0
    baseHp = BASE_HP
    wave = 1
    elapsed = 0
    veggies = {}
    marbles = {}
    aiming = false
    aimX = SLING_X
    aimY = SLING_Y
    waveCooldown = 0.5
    nextEnemyId = 1
    nextMarbleId = 1
    LoadBalls()
    Emit("game_reset")
end

local function StartGame()
    ResetGame()
    gameState = "playing"
    SpawnWave()
    print("[Game] game started")
end

local function GetVeggieSize(veggieKey, brickSize)
    local data = VeggieData[veggieKey]
    return data.gridW * brickSize, data.gridH * brickSize
end

local function GetAvailableTypes(waveNum)
    local keys = {}
    local allKeys = { "tomato", "chili", "onion", "carrot", "corn", "eggplant" }
    local maxIndex = 1
    if waveNum >= 2 then maxIndex = 2 end
    if waveNum >= 3 then maxIndex = 3 end
    if waveNum >= 5 then maxIndex = 4 end
    if waveNum >= 7 then maxIndex = 5 end
    if waveNum >= 9 then maxIndex = 6 end

    for i = 1, math.min(#allKeys, maxIndex) do
        if VeggieData[allKeys[i]] then table.insert(keys, allKeys[i]) end
    end
    return keys
end

local function CreateEnemy(veggieKey, x, y, brickSize, brickHp, baseSpeed)
    local data = VeggieData[veggieKey]
    if not data then
        print("[Game] ERROR: no veggie data for " .. tostring(veggieKey))
        return nil
    end

    local bricks = {}
    for entry in (data.data .. ";"):gmatch("(.-);") do
        local col, row = entry:match("(%d+),(%d+),%d+,%d+,%d+")
        if col then
            table.insert(bricks, {
                col = tonumber(col), row = tonumber(row),
                hp = brickHp, maxHp = brickHp, alive = true,
            })
        end
    end

    local enemy = {
        id = nextEnemyId,
        veggieKey = veggieKey,
        gridW = data.gridW,
        gridH = data.gridH,
        brickSize = brickSize,
        x = x, y = y, baseX = x,
        vy = baseSpeed * data.speedMul * 0.25,
        swayAmp = 10 + Random() * 14,
        swayFreq = 0.3 + Random() * 0.25,
        phase = Random() * math.pi * 2,
        bricks = bricks,
        dead = false,
        frozen = 0,
    }
    nextEnemyId = nextEnemyId + 1
    return enemy
end

SpawnWave = function()
    local pool = GetAvailableTypes(wave)
    if #pool == 0 then
        print("[Game] WARNING: empty veggie pool")
        return
    end

    local count, baseSpeed, brickHp = GetWaveParams(wave)
    local brickSize = GetBrickSize(wave)
    local margin = 20
    local usedX = {}

    for i = 1, count do
        local veggieKey = pool[RandomInt(1, #pool)]
        local veggieWidth, veggieHeight = GetVeggieSize(veggieKey, brickSize)
        local x, tries = margin, 0
        repeat
            x = margin + Random() * math.max(1, DW - veggieWidth - margin * 2)
            local overlap = false
            for _, usedCenterX in ipairs(usedX) do
                if math.abs(usedCenterX - (x + veggieWidth * 0.5)) < veggieWidth * 0.9 then
                    overlap = true
                    break
                end
            end
            tries = tries + 1
            if not overlap or tries > 25 then break end
        until false
        table.insert(usedX, x + veggieWidth * 0.5)

        local y = -veggieHeight * 0.3 - (i - 1) * (veggieHeight * 0.2) - RandomInt(0, 10)
        local enemy = CreateEnemy(veggieKey, x, y, brickSize, brickHp, baseSpeed)
        if enemy then table.insert(veggies, enemy) end
    end

    Emit("wave_started", {wave = wave})
    print("[Game] wave " .. wave .. " spawned " .. #veggies .. " enemies")
end

-- 碰撞区域设计：圆形弹珠对单个方形砖块。
--
--        圆心 (cx, cy)
--             o
--          .-' '-.
--       +----------+  <- 砖块 AABB (rx, ry, rw, rh)
--       |          |
--       +----------+
--
-- 目的：圆与 AABB 重叠时，按归一化穿透较大的轴反射速度并推出表面。
-- 边界：相切不算命中；推出 0.5 设计单位避免重复卡碰；高速球由四次子步进降低穿透。
local function IntersectsBrick(marble, rx, ry, rw, rh)
    local closestX = math.max(rx, math.min(marble.x, rx + rw))
    local closestY = math.max(ry, math.min(marble.y, ry + rh))
    local dx = marble.x - closestX
    local dy = marble.y - closestY
    return dx * dx + dy * dy < marble.radius * marble.radius
end

local function CollideBrick(marble, rx, ry, rw, rh)
    if not IntersectsBrick(marble, rx, ry, rw, rh) then return false end

    local centerX = rx + rw * 0.5
    local centerY = ry + rh * 0.5
    local overlapX = math.abs(marble.x - centerX) / (rw * 0.5 + marble.radius)
    local overlapY = math.abs(marble.y - centerY) / (rh * 0.5 + marble.radius)

    if overlapX >= overlapY then
        marble.vx = -marble.vx
        if marble.x >= centerX then marble.x = rx + rw + marble.radius + 0.5
        else marble.x = rx - marble.radius - 0.5 end
    else
        marble.vy = -marble.vy
        if marble.y >= centerY then marble.y = ry + rh + marble.radius + 0.5
        else marble.y = ry - marble.radius - 0.5 end
    end
    return true
end

local function DamageBrick(enemy, brick, damage)
    brick.hp = brick.hp - (damage or 1)
    local data = VeggieData[enemy.veggieKey]
    local x = enemy.x + (brick.col - 0.5) * enemy.brickSize
    local y = enemy.y + (brick.row - 0.5) * enemy.brickSize
    local destroyed = brick.hp <= 0

    if destroyed then
        brick.alive = false
        score = score + data.score
    end

    Emit("brick_hit", {
        enemyId = enemy.id,
        veggieKey = enemy.veggieKey,
        col = brick.col,
        row = brick.row,
        x = x, y = y,
        destroyed = destroyed,
        score = destroyed and data.score or 0,
    })
end

local function IsEnemyCleared(enemy)
    for _, brick in ipairs(enemy.bricks) do
        if brick.alive then return false end
    end
    return true
end

local function RotateVelocity(vx, vy, degrees)
    local radians = math.rad(degrees)
    local c = math.cos(radians)
    local s = math.sin(radians)
    return vx * c - vy * s, vx * s + vy * c
end

local function CreateSplitMarble(source, angle, originBrick)
    local vx, vy = RotateVelocity(source.vx, source.vy, angle)
    local marble = {
        id = nextMarbleId,
        x = source.x, y = source.y,
        vx = vx, vy = vy,
        radius = source.radius,
        speed = source.speed,
        ballType = "normal",
        onSling = false,
        alive = true,
        bounceCount = source.bounceCount,
        isPrimary = false,
        generation = source.generation + 1,
        ignoredBrick = originBrick,
        giantPiercing = false,
    }
    nextMarbleId = nextMarbleId + 1
    return marble
end

local function TrySplitNormal(marble, originBrick, pendingMarbles)
    local def = BALL_TYPES.normal
    if Random() >= def.splitChance then return end

    table.insert(pendingMarbles,
        CreateSplitMarble(marble, -def.splitAngle, originBrick))
    table.insert(pendingMarbles,
        CreateSplitMarble(marble, def.splitAngle, originBrick))
    Emit("normal_split", {
        x = marble.x, y = marble.y,
        generation = marble.generation + 1,
    })
    print("[Game] normal marble split, generation=" .. (marble.generation + 1))
end

local function FindNearestBrick(originEnemy, originBrick, originX, originY)
    local nearest = nil
    local nearestDistanceSq = math.huge
    for _, enemy in ipairs(veggies) do
        if not enemy.dead then
            for _, brick in ipairs(enemy.bricks) do
                if brick.alive and not (enemy == originEnemy and brick == originBrick) then
                    local x = enemy.x + (brick.col - 0.5) * enemy.brickSize
                    local y = enemy.y + (brick.row - 0.5) * enemy.brickSize
                    local dx = x - originX
                    local dy = y - originY
                    local distanceSq = dx * dx + dy * dy
                    if distanceSq < nearestDistanceSq then
                        nearestDistanceSq = distanceSq
                        nearest = {x = x, y = y}
                    end
                end
            end
        end
    end
    return nearest
end

local function BoostSpeedMarble(marble)
    local def = BALL_TYPES.speed
    if marble.ballType ~= "speed" then return end

    marble.speed = math.min(def.maxSpeed, marble.speed * def.speedBoost)
    local velocityLength = math.sqrt(marble.vx * marble.vx + marble.vy * marble.vy)
    if velocityLength > 0.001 then
        marble.vx = marble.vx / velocityLength * marble.speed
        marble.vy = marble.vy / velocityLength * marble.speed
    end
end

local function GetMarbleDamage(marble, def)
    if marble.ballType ~= "speed" then return def.damage end
    local bonus = math.floor(math.max(0, marble.speed - def.speed) / def.damageStep)
    return math.min(def.maxDamage, def.damage + bonus)
end

local function RedirectSpeedMarble(marble, originEnemy, originBrick)
    local target = FindNearestBrick(originEnemy, originBrick, marble.x, marble.y)
    if not target then return end

    local dx = target.x - marble.x
    local dy = target.y - marble.y
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance < 0.001 then return end

    marble.vx = dx / distance * marble.speed
    marble.vy = dy / distance * marble.speed
    Emit("speed_dash", {
        x = marble.x, y = marble.y,
        targetX = target.x, targetY = target.y,
        damage = GetMarbleDamage(marble, BALL_TYPES.speed),
    })
end

local function ArmGiantPiercing(marble)
    local def = BALL_TYPES.giant
    if marble.ballType ~= "giant" or not def.pierceAfterBounce or marble.giantPiercing then
        return
    end
    marble.giantPiercing = true
    Emit("giant_pierce_armed", {x = marble.x, y = marble.y})
    print("[Game] giant marble rebound armed circular piercing")
end

-- 巨型弹贯穿伤害区：以命中砖块中心为圆心，直径 7 个敌方单元格。
--
--          o o o
--        o o o o o
--      o o o X o o o    X = 命中格
--        o o o o o       半径 = 3.5 × 命中敌人的单格尺寸
--          o o o
--
-- 圆形边缘按砖块中心判断；跨敌人但仍在圆内的单元格也会受到伤害。
local function DamageGiantArea(originEnemy, originBrick, damage, frameHitBricks)
    local centerX = originEnemy.x + (originBrick.col - 0.5) * originEnemy.brickSize
    local centerY = originEnemy.y + (originBrick.row - 0.5) * originEnemy.brickSize
    local radius = originEnemy.brickSize * BALL_TYPES.giant.areaRadiusCells
    local radiusSq = radius * radius
    local hitCount = 0

    for _, enemy in ipairs(veggies) do
        if not enemy.dead then
            for _, brick in ipairs(enemy.bricks) do
                if brick.alive and not frameHitBricks[brick] then
                    local x = enemy.x + (brick.col - 0.5) * enemy.brickSize
                    local y = enemy.y + (brick.row - 0.5) * enemy.brickSize
                    local dx = x - centerX
                    local dy = y - centerY
                    if dx * dx + dy * dy <= radiusSq then
                        frameHitBricks[brick] = true
                        DamageBrick(enemy, brick, damage)
                        hitCount = hitCount + 1
                    end
                end
            end
        end
    end

    Emit("giant_area_hit", {
        x = centerX, y = centerY,
        radius = radius, hitCount = hitCount,
    })
end

local function LaunchMarble(dx, dy, power)
    if not activeBall then return end
    local length = math.sqrt(dx * dx + dy * dy)
    if length < 1 then return end

    local def = BALL_TYPES[activeBall.ballType]
    local speed = def.speed * (0.7 + 0.3 * power)
    activeBall.vx = -dx / length * speed
    activeBall.vy = -dy / length * speed
    activeBall.speed = speed
    activeBall.onSling = false
    table.insert(marbles, activeBall)
    Emit("marble_launched", {id = activeBall.id, ballType = activeBall.ballType})
    activeBall = nil
end

local function QueueNextBall()
    if #ballQueue > 0 then
        activeBall = CreateMarble(table.remove(ballQueue, 1))
    end
end

local function UpdateAiming()
    if aiming and activeBall then
        activeBall.x = aimX
        activeBall.y = aimY
    elseif activeBall and activeBall.onSling then
        activeBall.x = SLING_X
        activeBall.y = SLING_Y
    end
end

UpdateMarbles = function(dt)
    local pendingMarbles = {}
    for i = #marbles, 1, -1 do
        local marble = marbles[i]
        local def = BALL_TYPES[marble.ballType]
        local steps = 4
        local subDt = dt / steps
        local frameHitBricks = {}

        for _ = 1, steps do
            if not marble.alive then break end

            marble.x = marble.x + marble.vx * subDt
            marble.y = marble.y + marble.vy * subDt

            if marble.x - marble.radius < 0 then
                marble.x = marble.radius
                marble.vx = math.abs(marble.vx)
                marble.bounceCount = marble.bounceCount + 1
                BoostSpeedMarble(marble)
                ArmGiantPiercing(marble)
            elseif marble.x + marble.radius > DW then
                marble.x = DW - marble.radius
                marble.vx = -math.abs(marble.vx)
                marble.bounceCount = marble.bounceCount + 1
                BoostSpeedMarble(marble)
                ArmGiantPiercing(marble)
            end
            if marble.y - marble.radius < 0 then
                marble.y = marble.radius
                marble.vy = math.abs(marble.vy)
                marble.bounceCount = marble.bounceCount + 1
                BoostSpeedMarble(marble)
                ArmGiantPiercing(marble)
            end

            local hit = false
            for _, enemy in ipairs(veggies) do
                if not enemy.dead then
                    for _, brick in ipairs(enemy.bricks) do
                        if marble.ignoredBrick == brick then
                            local irx = enemy.x + (brick.col - 1) * enemy.brickSize + 1
                            local iry = enemy.y + (brick.row - 1) * enemy.brickSize + 1
                            if not IntersectsBrick(marble, irx, iry,
                                enemy.brickSize - 2, enemy.brickSize - 2) then
                                marble.ignoredBrick = nil
                            end
                        elseif brick.alive and not frameHitBricks[brick] then
                            local rx = enemy.x + (brick.col - 1) * enemy.brickSize + 1
                            local ry = enemy.y + (brick.row - 1) * enemy.brickSize + 1
                            local rw = enemy.brickSize - 2
                            local rh = enemy.brickSize - 2
                            local collided = false

                            if marble.giantPiercing then
                                collided = IntersectsBrick(marble, rx, ry, rw, rh)
                                if collided then
                                    marble.x = marble.x + marble.vx * subDt * 0.5
                                    marble.y = marble.y + marble.vy * subDt * 0.5
                                end
                            else
                                collided = CollideBrick(marble, rx, ry, rw, rh)
                            end

                            if collided then
                                if marble.ballType == "speed" then
                                    BoostSpeedMarble(marble)
                                end

                                if marble.giantPiercing then
                                    DamageGiantArea(enemy, brick,
                                        GetMarbleDamage(marble, def), frameHitBricks)
                                else
                                    frameHitBricks[brick] = true
                                    DamageBrick(enemy, brick, GetMarbleDamage(marble, def))
                                end
                                if def.freezeDuration then enemy.frozen = def.freezeDuration end

                                if marble.ballType == "normal" then
                                    TrySplitNormal(marble, brick, pendingMarbles)
                                elseif marble.ballType == "speed" then
                                    RedirectSpeedMarble(marble, enemy, brick)
                                elseif marble.ballType == "giant" and not marble.giantPiercing then
                                    hit = true
                                    ArmGiantPiercing(marble)
                                end

                                if not marble.giantPiercing then hit = true end
                                break
                            end
                        end
                    end
                    if hit or not marble.alive then break end
                end
            end

            if marble.y - marble.radius > DH then
                marble.alive = false
                break
            end
        end

        if not marble.alive then
            table.remove(marbles, i)
            if marble.isPrimary then EnqueueNextBall() end
            Emit("marble_removed", {id = marble.id})
        end
    end

    for _, marble in ipairs(pendingMarbles) do
        table.insert(marbles, marble)
        Emit("marble_split_spawned", {
            id = marble.id,
            generation = marble.generation,
        })
    end
end

UpdateEnemies = function(dt)
    for i = #veggies, 1, -1 do
        local enemy = veggies[i]
        local width = enemy.gridW * enemy.brickSize
        local height = enemy.gridH * enemy.brickSize
        local speedMultiplier = 1

        if enemy.frozen > 0 then
            enemy.frozen = math.max(0, enemy.frozen - dt)
            speedMultiplier = 0.3
        end

        enemy.phase = enemy.phase + dt * enemy.swayFreq
        enemy.x = enemy.baseX + math.sin(enemy.phase) * enemy.swayAmp
        if enemy.x < 10 then
            enemy.baseX = 10 + (enemy.baseX - enemy.x)
            enemy.x = 10
        elseif enemy.x + width > DW - 10 then
            enemy.baseX = DW - 10 - width - ((enemy.x + width) - (DW - 10))
            enemy.x = DW - 10 - width
        end
        enemy.y = enemy.y + enemy.vy * speedMultiplier * dt

        local hullHeight = enemy.brickSize * 0.8
        if enemy.y + height + hullHeight > DANGER_Y then
            enemy.dead = true
            baseHp = baseHp - 1
            Emit("base_hit", {x = enemy.x + width * 0.5, y = DANGER_Y})
            if baseHp <= 0 then
                baseHp = 0
                gameState = "gameover"
                if score > highScore then highScore = score end
                Emit("game_over", {score = score, highScore = highScore, wave = wave})
                print("[Game] game over, score=" .. score .. ", wave=" .. wave)
            end
        end

        if not enemy.dead and IsEnemyCleared(enemy) then
            enemy.dead = true
            score = score + 50
            Emit("enemy_cleared", {
                enemyId = enemy.id,
                x = enemy.x + width * 0.5,
                y = enemy.y + height * 0.5,
            })
        end

        if enemy.dead then table.remove(veggies, i) end
    end
end

UpdateReload = function()
    if not activeBall and #ballQueue > 0 then QueueNextBall() end
end

UpdateWaveLogic = function(dt)
    if gameState == "playing" and #veggies == 0 then
        waveCooldown = waveCooldown - dt
        if waveCooldown <= 0 then
            wave = wave + 1
            SpawnWave()
            waveCooldown = 1.5
        end
    end
end

local function GetPullState(px, py)
    local dx = px - SLING_X
    local dy = py - SLING_Y
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance > MAX_PULL then
        dx = dx / distance * MAX_PULL
        dy = dy / distance * MAX_PULL
        distance = MAX_PULL
    end
    local maxDownDy = DH - SLING_Y - 20
    if dy > maxDownDy then dy = maxDownDy end
    return dx, dy, distance
end

local function BuildAimTrajectory()
    local points = {}
    if not aiming or not activeBall then return points end

    local dx = activeBall.x - SLING_X
    local dy = activeBall.y - SLING_Y
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance < 5 then return points end

    local def = BALL_TYPES[activeBall.ballType]
    local speed = def.speed * (0.7 + 0.3 * math.min(1, distance / MAX_PULL))
    local vx = -dx / distance * speed
    local vy = -dy / distance * speed
    local x, y = activeBall.x, activeBall.y
    local stepDistance = 14

    for i = 1, 50 do
        local velocityLength = math.sqrt(vx * vx + vy * vy)
        if velocityLength < 0.001 then break end
        x = x + vx / velocityLength * stepDistance
        y = y + vy / velocityLength * stepDistance
        if x - activeBall.radius < 0 then
            x = activeBall.radius
            vx = math.abs(vx)
        elseif x + activeBall.radius > DW then
            x = DW - activeBall.radius
            vx = -math.abs(vx)
        end
        if y - activeBall.radius < 0 then
            y = activeBall.radius
            vy = math.abs(vy)
        end
        if y - activeBall.radius > DH then break end
        table.insert(points, {x = x, y = y, progress = i / 50})
    end
    return points
end

function Game.Init(config)
    config = config or {}
    DW = config.width or DW
    DH = config.height or DH
    SetRandomSeed(config.seed or 1)
    pendingEvents = {}
    highScore = 0
    ResetGame()
    pendingEvents = {}
    gameState = "menu"
    print("[Game] core initialized at " .. DW .. "x" .. DH)
end

function Game.Update(dt)
    elapsed = elapsed + dt
    if gameState == "playing" then
        UpdateAiming()
        UpdateMarbles(dt)
        UpdateEnemies(dt)
        UpdateReload()
        UpdateWaveLogic(dt)
    end
end

function Game.PointerDown(px, py)
    if gameState == "menu" or gameState == "gameover" then
        StartGame()
        return
    end
    if gameState ~= "playing" or not activeBall or py < DANGER_Y - 100 then return end

    aiming = true
    local dx, dy = GetPullState(px, py)
    aimX = SLING_X + dx
    aimY = SLING_Y + dy
end

function Game.PointerMove(px, py)
    if not aiming then return end
    local dx, dy = GetPullState(px, py)
    aimX = SLING_X + dx
    aimY = SLING_Y + dy
end

function Game.PointerUp(px, py)
    if not aiming then return end
    local dx, dy, distance = GetPullState(px, py)
    aiming = false
    if distance > 15 then
        LaunchMarble(dx, dy, distance / MAX_PULL)
    elseif activeBall then
        activeBall.x = SLING_X
        activeBall.y = SLING_Y
    end
end

function Game.HandleAction(action, pressed)
    if pressed and action == "start" and (gameState == "menu" or gameState == "gameover") then
        StartGame()
    end
end

function Game.DrainEvents()
    local events = pendingEvents
    pendingEvents = {}
    return events
end

function Game.GetSnapshot()
    return {
        state = gameState,
        score = score,
        highScore = highScore,
        baseHp = baseHp,
        maxBaseHp = BASE_HP,
        wave = wave,
        elapsed = elapsed,
        veggies = veggies,
        marbles = marbles,
        aiming = aiming,
        aimX = aimX,
        aimY = aimY,
        aimTrajectory = BuildAimTrajectory(),
        slingX = SLING_X,
        slingY = SLING_Y,
        maxPull = MAX_PULL,
        activeBall = activeBall,
        ballQueue = ballQueue,
        ballOrder = BALL_ORDER,
        width = DW,
        height = DH,
        dangerY = DANGER_Y,
    }
end

return Game
