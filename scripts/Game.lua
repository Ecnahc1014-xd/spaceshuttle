-- Game.lua
-- 燃烧的蔬菜 - 弹弓拖拽发射 + 四种弹珠 + 像素砖块敌人

local VeggieData = require "VeggiePixelData"

local Game = {}

-- 设计尺寸
local DW = 540
local DH = 960

-- 砖块为正方形（基础尺寸，前期波次会缩小）
local BASE_BRICK_SIZE = 14

-- 根据波次获取砖块尺寸：小像素飞船敌人
local function GetBrickSize(waveNum)
    if waveNum <= 2 then return 10 end
    if waveNum <= 4 then return 12 end
    return BASE_BRICK_SIZE
end

-- 弹珠类型定义
local BALL_TYPES = {
    normal = {
        name = "常规", r = 9, speed = 560, damage = 1,
        color = {255, 248, 220}, glow = {255, 220, 120},
        stroke = {220, 160, 50}, trail = {255, 230, 140},
    },
    speed = {
        name = "加速", r = 8, speed = 680, damage = 1,
        color = {255, 120, 60}, glow = {255, 80, 40},
        stroke = {200, 60, 30}, trail = {255, 140, 80},
        speedBoost = 1.06,  -- 每次碰撞加速 6%
        maxSpeed = 1100,
    },
    ice = {
        name = "冰冻", r = 9, speed = 520, damage = 1,
        color = {180, 240, 255}, glow = {100, 200, 255},
        stroke = {60, 140, 200}, trail = {150, 220, 255},
        freezeDuration = 3.0,  -- 命中后冰冻敌人 3 秒
    },
    giant = {
        name = "巨型", r = 16, speed = 420, damage = 2,
        color = {200, 140, 255}, glow = {160, 80, 220},
        stroke = {120, 50, 180}, trail = {190, 130, 255},
    },
}

-- 弹珠装填顺序（弹弓左右各两种）
local BALL_ORDER = { "normal", "ice", "speed", "giant" }

-- 常量
local SLING_X = 270
local SLING_Y = 850       -- 弹弓位置
local MAX_PULL = 150      -- 最大拖拽距离
local DANGER_Y = 900      -- 警戒线（下移，给玩家更大操作空间）
local BASE_HP = 5
local AIM_DETECT_RADIUS = 200

-- 游戏状态
local state = "menu"  -- menu / playing / gameover
local score = 0
local highScore = 0
local baseHp = BASE_HP
local wave = 1
local screenShake = 0
local waveBannerTimer = 0
local elapsed = 0

-- 实体
local veggies = {}
local marbles = {}
local particles = {}
local floatTexts = {}

-- 弹珠装填系统：每颗球独立，消失后立刻补充
local ballQueue = {}       -- 待发射的弹珠类型队列
local activeBall = nil     -- 当前在弹弓上的弹珠
local ballCycleIndex = 0   -- 球类型循环索引

-- 弹弓瞄准
local aiming = false
local aimX = SLING_X
local aimY = SLING_Y

-- 波次
local waveCooldown = 0

----------------------------------------------------------------------
-- 初始化
----------------------------------------------------------------------

local ResetGame  -- 前向声明

function Game.Init(w, h)
    DW = w
    DH = h
    ResetGame()
    state = "menu"
end

function Game.GetState()
    return {
        state = state, score = score, highScore = highScore,
        baseHp = baseHp, maxBaseHp = BASE_HP, wave = wave,
        screenShake = screenShake, waveBannerTimer = waveBannerTimer,
        veggies = veggies, marbles = marbles,
        particles = particles, floatTexts = floatTexts,
        aiming = aiming, aimX = aimX, aimY = aimY,
        slingX = SLING_X, slingY = SLING_Y, maxPull = MAX_PULL,
        activeBall = activeBall, ballQueue = ballQueue,
        ballTypes = BALL_TYPES, ballOrder = BALL_ORDER,
        elapsed = elapsed, DW = DW, DH = DH,
        BASE_BRICK_SIZE = BASE_BRICK_SIZE, DANGER_Y = DANGER_Y,
    }
end

local function CreateMarble(ballType)
    local def = BALL_TYPES[ballType]
    return {
        x = SLING_X, y = SLING_Y,
        vx = 0, vy = 0, r = def.r, speed = def.speed,
        ballType = ballType, onSling = true,
        trail = {}, alive = true,
        bounceCount = 0,
    }
end

-- 获取循环中的下一个球类型
local function NextBallType()
    ballCycleIndex = ballCycleIndex + 1
    if ballCycleIndex > #BALL_ORDER then ballCycleIndex = 1 end
    return BALL_ORDER[ballCycleIndex]
end

-- 向队列补充一颗球（独立重生）
local function EnqueueNextBall()
    table.insert(ballQueue, NextBallType())
end

local function LoadBalls()
    ballQueue = {}
    ballCycleIndex = 0
    for _ = 1, #BALL_ORDER do
        EnqueueNextBall()
    end
    -- 第一颗放到弹弓上
    activeBall = CreateMarble(table.remove(ballQueue, 1))
    -- 立刻补充一颗，保持队列满
    EnqueueNextBall()
end

function ResetGame()
    score = 0
    baseHp = BASE_HP
    wave = 1
    screenShake = 0
    waveBannerTimer = 0
    elapsed = 0
    veggies = {}
    marbles = {}
    particles = {}
    floatTexts = {}
    aiming = false
    aimX = SLING_X
    aimY = SLING_Y
    waveCooldown = 0.5
    LoadBalls()
end

----------------------------------------------------------------------
-- 敌人生成
----------------------------------------------------------------------

local function GetVeggieSize(veggieKey, brickSize)
    local d = VeggieData[veggieKey]
    local bs = brickSize or BASE_BRICK_SIZE
    return d.gridW * bs, d.gridH * bs
end

local function GetAvailableTypes(waveNum)
    local keys = {}
    local allKeys = { "tomato", "chili", "onion", "carrot", "corn", "eggplant" }
    local maxIdx = math.min(#allKeys, 2 + math.floor(waveNum / 1.5))
    for i = 1, maxIdx do
        if VeggieData[allKeys[i]] then
            table.insert(keys, allKeys[i])
        end
    end
    return keys
end

local function CreateEnemy(veggieKey, x, y, brickSize)
    local d = VeggieData[veggieKey]
    if not d then
        print("[Game] ERROR: no veggie data for " .. tostring(veggieKey))
        return nil
    end
    local bs = brickSize or BASE_BRICK_SIZE
    local bricks = {}
    for _, b in ipairs(d.bricks) do
        -- 数组格式: {col, row, r, g, b, dr, dg, db}
        table.insert(bricks, {
            col = b[1], row = b[2],
            r = b[3], g = b[4], b = b[5],
            dr = b[6], dg = b[7], db = b[8],
            hp = 1, maxHp = 1,
            alive = true, hitFlash = 0,
        })
    end
    return {
        veggieKey = veggieKey,
        brickSize = bs,
        x = x, y = y, baseX = x,
        vx = (math.random() > 0.5 and 1 or -1) * (8 + math.random() * 12),
        vy = 16 + wave * 2.5,
        swayAmp = 12 + math.random() * 18,
        swayFreq = 0.4 + math.random() * 0.3,
        phase = math.random() * 6.28,
        bricks = bricks, dead = false,
        frozen = 0,
    }
end

local function SpawnWave()
    local pool = GetAvailableTypes(wave)
    if #pool == 0 then
        print("[Game] WARNING: empty veggie pool")
        return
    end
    -- 小飞船敌人：数量更多
    local count
    if wave <= 1 then count = 6
    elseif wave <= 3 then count = 5
    else count = math.min(7, 4 + math.floor(wave / 3))
    end
    local bs = GetBrickSize(wave)
    local margin = 15

    local usedX = {}
    for i = 1, count do
        local vk = pool[math.random(#pool)]
        local vw, vh = GetVeggieSize(vk, bs)
        local x, tries = margin, 0
        repeat
            x = margin + math.random() * math.max(1, DW - vw - margin * 2)
            local overlap = false
            for _, ux in ipairs(usedX) do
                if math.abs(ux - (x + vw / 2)) < vw * 0.8 then overlap = true break end
            end
            tries = tries + 1
            if not overlap or tries > 20 then break end
        until false
        table.insert(usedX, x + vw / 2)

        -- 从顶部交错进入
        local y = -vh * 0.3 - (i - 1) * (vh * 0.18) - math.random(0, 8)
        local e = CreateEnemy(vk, x, y, bs)
        if e then
            e.vy = (16 + wave * 2.5) * VeggieData[vk].speedMul
            table.insert(veggies, e)
        end
    end
    waveBannerTimer = 1.8
    print("[Game] wave " .. wave .. " spawned " .. #veggies .. " enemies")
end

----------------------------------------------------------------------
-- 碰撞
----------------------------------------------------------------------

local function CollideBrick(marble, rx, ry, rw, rh)
    local cx, cy, r = marble.x, marble.y, marble.r
    local closestX = math.max(rx, math.min(cx, rx + rw))
    local closestY = math.max(ry, math.min(cy, ry + rh))
    local dx = cx - closestX
    local dy = cy - closestY
    if dx * dx + dy * dy >= r * r then return false end

    local centerX = rx + rw * 0.5
    local centerY = ry + rh * 0.5
    local ox = math.abs(cx - centerX) / (rw * 0.5 + r)
    local oy = math.abs(cy - centerY) / (rh * 0.5 + r)

    if ox >= oy then
        marble.vx = -marble.vx
        if cx >= centerX then marble.x = rx + rw + r + 0.5
        else marble.x = rx - r - 0.5 end
    else
        marble.vy = -marble.vy
        if cy >= centerY then marble.y = ry + rh + r + 0.5
        else marble.y = ry - r - 0.5 end
    end
    return true
end

----------------------------------------------------------------------
-- 粒子 / 飘字
----------------------------------------------------------------------

local function SpawnParticles(x, y, r, g, b, count)
    count = count or 8
    for _ = 1, count do
        local angle = math.random() * math.pi * 2
        local speed = 60 + math.random() * 160
        table.insert(particles, {
            x = x, y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed - 50,
            life = 0.4 + math.random() * 0.3, maxLife = 0.7,
            r = r, g = g, b = b, size = 3 + math.random() * 3,
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

----------------------------------------------------------------------
-- 伤害
----------------------------------------------------------------------

local function DamageBrick(enemy, brick, damage)
    damage = damage or 1
    brick.hp = brick.hp - damage
    brick.hitFlash = 0.12
    local d = VeggieData[enemy.veggieKey]
    local bs = enemy.brickSize
    local bx = enemy.x + (brick.col - 0.5) * bs
    local by = enemy.y + (brick.row - 0.5) * bs

    if brick.hp <= 0 then
        brick.alive = false
        score = score + d.score
        SpawnParticles(bx, by, brick.r, brick.g, brick.b, 10)
        SpawnFloatText(bx, by - 4, "+" .. d.score, {255, 240, 180}, 0.8)
    else
        SpawnParticles(bx, by, 255, 240, 180, 4)
    end
end

local function IsEnemyCleared(enemy)
    for _, b in ipairs(enemy.bricks) do
        if b.alive then return false end
    end
    return true
end

----------------------------------------------------------------------
-- 发射 / 装填
----------------------------------------------------------------------

local function LaunchMarble(dx, dy, power)
    if activeBall == nil then return end
    local def = BALL_TYPES[activeBall.ballType]
    local speed = def.speed * (0.7 + 0.3 * power)  -- 力度影响 0.7~1.0 倍速
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1 then return end
    local nx = -dx / len
    local ny = -dy / len
    activeBall.vx = nx * speed
    activeBall.vy = ny * speed
    activeBall.speed = speed
    activeBall.onSling = false
    table.insert(marbles, activeBall)
    activeBall = nil
end

local function QueueNextBall()
    if #ballQueue > 0 then
        local nextType = table.remove(ballQueue, 1)
        activeBall = CreateMarble(nextType)
    end
end

----------------------------------------------------------------------
-- 更新
----------------------------------------------------------------------

function Game.Update(dt)
    elapsed = elapsed + dt
    if screenShake > 0 then screenShake = math.max(0, screenShake - dt) end
    if waveBannerTimer > 0 then waveBannerTimer = math.max(0, waveBannerTimer - dt) end

    UpdateParticles(dt)
    UpdateFloatTexts(dt)

    if state == "menu" or state == "gameover" then return end

    UpdateAiming()
    UpdateMarbles(dt)
    UpdateEnemies(dt)
    UpdateReload(dt)
    UpdateWaveLogic(dt)
end

function UpdateParticles(dt)
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

function UpdateFloatTexts(dt)
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

function UpdateAiming()
    if aiming and activeBall then
        activeBall.x = aimX
        activeBall.y = aimY
    end
end

function UpdateMarbles(dt)
    -- 弹弓上的弹珠回位
    if activeBall and activeBall.onSling and not aiming then
        activeBall.x = SLING_X
        activeBall.y = SLING_Y
    end

    for i = #marbles, 1, -1 do
        local m = marbles[i]
        local def = BALL_TYPES[m.ballType]

        -- 拖尾
        table.insert(m.trail, 1, {x = m.x, y = m.y})
        if #m.trail > 10 then table.remove(m.trail) end

        -- 子步进（匀速直线，无重力）
        local steps = 4
        local sdt = dt / steps
        for _ = 1, steps do
            m.x = m.x + m.vx * sdt
            m.y = m.y + m.vy * sdt

            -- 左右墙反弹
            if m.x - m.r < 0 then
                m.x = m.r; m.vx = math.abs(m.vx); m.bounceCount = m.bounceCount + 1
            elseif m.x + m.r > DW then
                m.x = DW - m.r; m.vx = -math.abs(m.vx); m.bounceCount = m.bounceCount + 1
            end
            -- 顶部反弹
            if m.y - m.r < 0 then
                m.y = m.r; m.vy = math.abs(m.vy); m.bounceCount = m.bounceCount + 1
            end

            -- 砖块碰撞
            local hit = false
            for _, enemy in ipairs(veggies) do
                if not enemy.dead then
                    local ebs = enemy.brickSize
                    for _, brick in ipairs(enemy.bricks) do
                        if brick.alive then
                            local rx = enemy.x + (brick.col - 1) * ebs
                            local ry = enemy.y + (brick.row - 1) * ebs
                            if CollideBrick(m, rx + 1, ry + 1, ebs - 2, ebs - 2) then
                                DamageBrick(enemy, brick, def.damage or 1)
                                -- 冰冻效果
                                if def.freezeDuration then
                                    enemy.frozen = def.freezeDuration
                                end
                                hit = true
                                break
                            end
                        end
                    end
                    if hit then break end
                end
            end

            -- 加速球：碰撞后加速
            if hit and def.speedBoost then
                m.bounceCount = m.bounceCount + 1
                local newSpeed = m.speed * def.speedBoost
                if newSpeed > def.maxSpeed then newSpeed = def.maxSpeed end
                m.speed = newSpeed
                local vl = math.sqrt(m.vx * m.vx + m.vy * m.vy)
                if vl > 0.001 then
                    m.vx = m.vx / vl * newSpeed
                    m.vy = m.vy / vl * newSpeed
                end
            end

            -- 碰底部退场（不反弹）
            if m.y - m.r > DH then
                m.alive = false
                break
            end
        end

        if not m.alive then
            table.remove(marbles, i)
            -- 弹珠消失后立刻独立重生：补充一颗到队列
            EnqueueNextBall()
        end
    end
end

function UpdateEnemies(dt)
    for i = #veggies, 1, -1 do
        local e = veggies[i]
        local d = VeggieData[e.veggieKey]
        local bs = e.brickSize
        local vw = d.gridW * bs
        local vh = d.gridH * bs

        -- 冰冻减速
        local speedMul = 1.0
        if e.frozen > 0 then
            e.frozen = e.frozen - dt
            speedMul = 0.3
        end

        -- 左右摆动
        e.phase = e.phase + dt * e.swayFreq
        e.x = e.baseX + math.sin(e.phase) * e.swayAmp
        if e.x < 10 then
            e.baseX = 10 + (e.baseX - e.x); e.x = 10
        elseif e.x + vw > DW - 10 then
            e.baseX = DW - 10 - vw - ((e.x + vw) - (DW - 10)); e.x = DW - 10 - vw
        end

        -- 下落
        e.y = e.y + e.vy * speedMul * dt

        -- hitFlash 衰减
        for _, b in ipairs(e.bricks) do
            if b.hitFlash > 0 then
                b.hitFlash = math.max(0, b.hitFlash - dt)
            end
        end

        -- 越过警戒线（蔬菜 + 飞船底座）
        local hullH = bs * 0.8
        if e.y + vh + hullH > DANGER_Y then
            e.dead = true
            baseHp = baseHp - 1
            screenShake = 0.4
            for _ = 1, 16 do
                local angle = math.random() * math.pi * 2
                local spd = 80 + math.random() * 180
                table.insert(particles, {
                    x = e.x + vw / 2, y = DANGER_Y,
                    vx = math.cos(angle) * spd,
                    vy = math.sin(angle) * spd - 80,
                    life = 0.6, maxLife = 0.6,
                    r = 255, g = 80, b = 60, size = 4 + math.random() * 3,
                })
            end
            if baseHp <= 0 then
                baseHp = 0
                state = "gameover"
                if score > highScore then highScore = score end
            end
        end

        -- 全灭
        if not e.dead and IsEnemyCleared(e) then
            e.dead = true
            score = score + 50
            SpawnFloatText(e.x + vw / 2, e.y + vh / 2, "击破!", {120, 255, 160}, 1.2)
        end

        if e.dead then table.remove(veggies, i) end
    end
end

function UpdateReload(dt)
    -- 发射后（activeBall 为 nil）立刻从队列取下一颗放到弹弓上
    -- 每颗球独立重生：球退场时在 UpdateMarbles 中已调用 EnqueueNextBall 补充队列
    if activeBall == nil and #ballQueue > 0 then
        QueueNextBall()
    end
end

function UpdateWaveLogic(dt)
    -- 本波敌人全部消灭且弹珠已回收
    if state ~= "menu" and state ~= "gameover" and #veggies == 0 then
        waveCooldown = waveCooldown - dt
        if waveCooldown <= 0 then
            wave = wave + 1
            SpawnWave()
            waveCooldown = 1.5
        end
    end
end

----------------------------------------------------------------------
-- 输入
----------------------------------------------------------------------

local function GetPullState(px, py)
    local dx = px - SLING_X
    local dy = py - SLING_Y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist > MAX_PULL then
        dx = dx / dist * MAX_PULL
        dy = dy / dist * MAX_PULL
        dist = MAX_PULL
    end
    -- 限制弹珠不超出屏幕底部（安全边距）
    local maxDownDy = DH - SLING_Y - 20
    if dy > maxDownDy then dy = maxDownDy end
    return dx, dy, dist
end

function Game.PointerDown(px, py)
    if state == "menu" then
        ResetGame(); state = "playing"; SpawnWave()
        return
    elseif state == "gameover" then
        ResetGame(); state = "playing"; SpawnWave()
        return
    end
    if state ~= "playing" then return end
    if activeBall == nil then return end

    -- 安全区以下任意位置按下都可瞄准拖拽
    if py < DANGER_Y - 100 then return end
    aiming = true
    local pdx, pdy = GetPullState(px, py)
    aimX = SLING_X + pdx
    aimY = SLING_Y + pdy
end

function Game.PointerMove(px, py)
    if aiming then
        local pdx, pdy = GetPullState(px, py)
        aimX = SLING_X + pdx
        aimY = SLING_Y + pdy
    end
end

function Game.PointerUp(px, py)
    if aiming then
        local pdx, pdy, dist = GetPullState(px, py)
        aiming = false
        if dist > 15 then
            local power = dist / MAX_PULL
            LaunchMarble(pdx, pdy, power)
        elseif activeBall then
            activeBall.x = SLING_X
            activeBall.y = SLING_Y
        end
    end
end

function Game.KeyDown(key)
    if key == KEY_SPACE or key == KEY_RETURN then
        if state == "menu" then
            ResetGame(); state = "playing"; SpawnWave()
        elseif state == "gameover" then
            ResetGame(); state = "playing"; SpawnWave()
        end
    end
end

function Game.KeyUp(key)
end

return Game
