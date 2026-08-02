-- Game.lua
-- 燃烧的蔬菜 - 弹弓拖拽发射 + 弹珠反弹 + 像素砖块敌人

local VeggieLoader = require "VeggieLoader"

local Game = {}

-- 设计尺寸（由 Init 传入）
local DW = 540
local DH = 960

-- 砖块为正方形
local BRICK_SIZE = 24

-- 常量
local MARBLE_RADIUS = 9
local MAX_LAUNCH_SPEED = 720
local MIN_LAUNCH_SPEED = 320
local MARBLE_SPEED = 560         -- 弹珠匀速飞行速度
local SLING_X = 270              -- 弹弓锚点 X（设计坐标）
local SLING_Y = 880              -- 弹弓锚点 Y
local MAX_PULL = 110             -- 最大拖拽距离
local DANGER_Y = 820             -- 警戒线
local BASE_HP = 5

-- 游戏状态
local state = "menu" -- menu / aiming / flying / waveclear / gameover
local score = 0
local highScore = 0
local baseHp = BASE_HP
local wave = 1
local screenShake = 0
local waveBannerTimer = 0
local elapsed = 0
local canAim = true  -- 是否可以拖拽瞄准（弹珠未在飞行中）

-- 实体
local veggies = {}    -- 蔬菜敌人列表
local marbles = {}    -- 飞行中的弹珠
local particles = {}
local floatTexts = {}

-- 弹弓状态
local aiming = false
local aimX = SLING_X
local aimY = SLING_Y
local currentMarble = nil  -- 待发射的弹珠（在弹弓上）

-- 波次
local waveCooldown = 0
local veggiesDefeated = 0

-- 蔬菜像素数据
local veggieData = nil

----------------------------------------------------------------------
-- 初始化
----------------------------------------------------------------------

-- 前向声明（ResetGame 在 Game.Init 中调用，定义在后面）
local ResetGame

function Game.Init(w, h)
    DW = w
    DH = h

    -- 加载所有蔬菜像素数据
    if veggieData == nil then
        veggieData = VeggieLoader.LoadAll()
    end

    ResetGame()
    state = "menu"
end

function Game.GetState()
    return {
        state = state,
        score = score,
        highScore = highScore,
        baseHp = baseHp,
        maxBaseHp = BASE_HP,
        wave = wave,
        screenShake = screenShake,
        waveBannerTimer = waveBannerTimer,
        veggies = veggies,
        marbles = marbles,
        particles = particles,
        floatTexts = floatTexts,
        aiming = aiming,
        aimX = aimX,
        aimY = aimY,
        slingX = SLING_X,
        slingY = SLING_Y,
        maxPull = MAX_PULL,
        canAim = canAim,
        currentMarble = currentMarble,
        elapsed = elapsed,
        DW = DW, DH = DH,
        BRICK_SIZE = BRICK_SIZE,
        MARBLE_RADIUS = MARBLE_RADIUS,
        DANGER_Y = DANGER_Y,
    }
end

local function SpawnReadyMarble()
    currentMarble = {
        x = SLING_X,
        y = SLING_Y,
        vx = 0, vy = 0,
        r = MARBLE_RADIUS,
        onSling = true,
        trail = {},
    }
end

function ResetGame()
    score = 0
    baseHp = BASE_HP
    wave = 1
    screenShake = 0
    waveBannerTimer = 0
    elapsed = 0
    canAim = true
    veggies = {}
    marbles = {}
    particles = {}
    floatTexts = {}
    aiming = false
    aimX = SLING_X
    aimY = SLING_Y
    currentMarble = nil
    waveCooldown = 0.5
    veggiesDefeated = 0
    SpawnReadyMarble()
end

----------------------------------------------------------------------
-- 敌人生成
----------------------------------------------------------------------

local function GetVeggieSize(veggieKey)
    local d = veggieData[veggieKey]
    return d.gridW * BRICK_SIZE, d.gridH * BRICK_SIZE
end

local function CreateEnemy(veggieKey, x, y)
    local d = veggieData[veggieKey]
    local bricks = {}
    for _, b in ipairs(d.bricks) do
        table.insert(bricks, {
            col = b.col,
            row = b.row,
            r = b.r, g = b.g, b = b.b,
            dr = b.dr, dg = b.dg, db = b.db,
            hp = d.hp,
            maxHp = d.hp,
            alive = true,
            hitFlash = 0,
        })
    end
    return {
        veggieKey = veggieKey,
        x = x,
        y = y,
        baseX = x,
        vx = (math.random() > 0.5 and 1 or -1) * (15 + math.random() * 20),
        vy = 12 + wave * 1.8,
        swayAmp = 20 + math.random() * 30,
        swayFreq = 0.6 + math.random() * 0.4,
        phase = math.random() * 6.28,
        bricks = bricks,
        dead = false,
    }
end

local function SpawnWave()
    local pool = VeggieLoader.GetAvailableTypes(veggieData, wave)
    if #pool == 0 then
        print("[Game] WARNING: vegetable pool is empty, cannot spawn wave " .. wave)
        return
    end
    local count = math.min(5, 2 + math.floor(wave / 2))
    local margin = 30

    for i = 1, count do
        local vk = pool[math.random(#pool)]
        local vw, vh = GetVeggieSize(vk)
        -- 水平随机分布
        local x = margin + math.random() * math.max(1, DW - vw - margin * 2)
        -- 从屏幕顶部外进入（部分可见），交错排列
        local y = -vh * 0.5 - (i - 1) * (vh * 0.3) - math.random(0, 15)
        local e = CreateEnemy(vk, x, y)
        e.vy = (32 + wave * 4.5) * veggieData[vk].speedMul
        table.insert(veggies, e)
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
    if dx * dx + dy * dy >= r * r then
        return false
    end

    local centerX = rx + rw * 0.5
    local centerY = ry + rh * 0.5
    local ox = math.abs(cx - centerX) / (rw * 0.5 + r)
    local oy = math.abs(cy - centerY) / (rh * 0.5 + r)

    if ox >= oy then
        marble.vx = -marble.vx
        if cx >= centerX then
            marble.x = rx + rw + r + 0.5
        else
            marble.x = rx - r - 0.5
        end
    else
        marble.vy = -marble.vy
        if cy >= centerY then
            marble.y = ry + rh + r + 0.5
        else
            marble.y = ry - r - 0.5
        end
    end
    return true
end

----------------------------------------------------------------------
-- 粒子 / 飘字
----------------------------------------------------------------------

local function SpawnBrickParticles(x, y, r, g, b, count)
    count = count or 8
    for _ = 1, count do
        local angle = math.random() * math.pi * 2
        local speed = 60 + math.random() * 160
        table.insert(particles, {
            x = x, y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed - 50,
            life = 0.4 + math.random() * 0.3,
            maxLife = 0.7,
            r = r, g = g, b = b,
            size = 3 + math.random() * 3,
        })
    end
end

local function SpawnFloatText(x, y, text, color, sizeMul)
    table.insert(floatTexts, {
        x = x, y = y, vy = -40,
        life = 0.9, maxLife = 0.9,
        text = text,
        color = color or {255, 255, 255},
        size = (sizeMul or 1) * 20,
    })
end

----------------------------------------------------------------------
-- 伤害
----------------------------------------------------------------------

local function DamageBrick(enemy, brick)
    brick.hp = brick.hp - 1
    brick.hitFlash = 0.12
    local d = veggieData[enemy.veggieKey]
    local bx = enemy.x + (brick.col - 0.5) * BRICK_SIZE
    local by = enemy.y + (brick.row - 0.5) * BRICK_SIZE

    if brick.hp <= 0 then
        brick.alive = false
        score = score + d.score
        SpawnBrickParticles(bx, by, brick.r, brick.g, brick.b, 10)
        SpawnFloatText(bx, by - 4, "+" .. d.score, {255, 240, 180}, 0.8)
    else
        SpawnBrickParticles(bx, by, 255, 240, 180, 4)
    end
end

local function IsEnemyCleared(enemy)
    for _, b in ipairs(enemy.bricks) do
        if b.alive then return false end
    end
    return true
end

----------------------------------------------------------------------
-- 弹珠
----------------------------------------------------------------------

local function LaunchMarble(dx, dy, power)
    if currentMarble == nil or not canAim then return end
    -- 力度影响速度（在 MIN/MAX 之间），但发射后匀速飞行不受重力
    local speed = MIN_LAUNCH_SPEED + (MAX_LAUNCH_SPEED - MIN_LAUNCH_SPEED) * power
    -- dx,dy 是拖拽向量（向后拉），发射方向取反
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1 then return end
    local nx = -dx / len
    local ny = -dy / len
    currentMarble.vx = nx * speed
    currentMarble.vy = ny * speed
    currentMarble.speed = speed
    currentMarble.onSling = false
    table.insert(marbles, currentMarble)
    currentMarble = nil
    canAim = false
end

local function RecoverMarble()
    -- 弹珠落地回收，准备下一发
    canAim = true
    if state == "flying" then
        state = "aiming"
    end
    SpawnReadyMarble()
end

----------------------------------------------------------------------
-- 更新
----------------------------------------------------------------------

function Game.Update(dt)
    elapsed = elapsed + dt

    if screenShake > 0 then
        screenShake = screenShake - dt
        if screenShake < 0 then screenShake = 0 end
    end
    if waveBannerTimer > 0 then
        waveBannerTimer = waveBannerTimer - dt
        if waveBannerTimer < 0 then waveBannerTimer = 0 end
    end

    UpdateParticles(dt)
    UpdateFloatTexts(dt)

    if state == "menu" or state == "gameover" then
        return
    end

    UpdateAiming(dt)
    UpdateMarbles(dt)
    UpdateEnemies(dt)

    -- 检查波次清空（本波敌人已全部生成且被消灭，且弹珠已回收）
    if state ~= "menu" and state ~= "gameover" and canAim and #veggies == 0 then
        waveCooldown = waveCooldown - dt
        if waveCooldown <= 0 then
            wave = wave + 1
            SpawnWave()
            waveCooldown = 1.5
            state = "aiming"
        end
    end
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

function UpdateAiming(dt)
    if aiming and currentMarble then
        -- 弹珠跟随拖拽点
        currentMarble.x = aimX
        currentMarble.y = aimY
    end
end

function UpdateMarbles(dt)
    -- 更新弹弓上的弹珠（轻微待机动画）
    if currentMarble and currentMarble.onSling and not aiming then
        currentMarble.x = SLING_X
        currentMarble.y = SLING_Y
    end

    for i = #marbles, 1, -1 do
        local m = marbles[i]

        -- 拖尾
        table.insert(m.trail, 1, {x = m.x, y = m.y})
        if #m.trail > 10 then table.remove(m.trail) end

        -- 子步进防穿透（匀速直线运动，无重力）
        local steps = 4
        local sdt = dt / steps
        for _ = 1, steps do
            m.x = m.x + m.vx * sdt
            m.y = m.y + m.vy * sdt

            -- 墙壁反弹（左右+顶部），碰底部不反弹直接退场
            if m.x - m.r < 0 then
                m.x = m.r
                m.vx = math.abs(m.vx)
            elseif m.x + m.r > DW then
                m.x = DW - m.r
                m.vx = -math.abs(m.vx)
            end
            if m.y - m.r < 0 then
                m.y = m.r
                m.vy = math.abs(m.vy)
            end

            -- 砖块碰撞
            local hit = false
            for _, enemy in ipairs(veggies) do
                if not enemy.dead then
                    for _, brick in ipairs(enemy.bricks) do
                        if brick.alive then
                            local rx = enemy.x + (brick.col - 1) * BRICK_SIZE
                            local ry = enemy.y + (brick.row - 1) * BRICK_SIZE
                            if CollideBrick(m, rx + 1, ry + 1, BRICK_SIZE - 2, BRICK_SIZE - 2) then
                                DamageBrick(enemy, brick)
                                hit = true
                                break
                            end
                        end
                    end
                    if hit then break end
                end
            end

            -- 反弹后归一化速度，保持匀速
            if hit then
                local spd = m.speed or MARBLE_SPEED
                local vl = math.sqrt(m.vx * m.vx + m.vy * m.vy)
                if vl > 0.001 then
                    m.vx = m.vx / vl * spd
                    m.vy = m.vy / vl * spd
                end
            end

            -- 掉出底部 = 回收（不反弹）
            if m.y - m.r > DH then
                m.dead = true
                break
            end
        end

        if m.dead then
            table.remove(marbles, i)
            -- 如果所有弹珠都没了，回收
            if #marbles == 0 then
                RecoverMarble()
            end
        end
    end
end

function UpdateEnemies(dt)
    for i = #veggies, 1, -1 do
        local e = veggies[i]
        local d = veggieData[e.veggieKey]
        local vw = d.gridW * BRICK_SIZE
        local vh = d.gridH * BRICK_SIZE

        -- 左右摆动
        e.phase = e.phase + dt * e.swayFreq
        e.x = e.baseX + math.sin(e.phase) * e.swayAmp

        -- 边界
        if e.x < 10 then
            e.baseX = 10 + (e.baseX - e.x)
            e.x = 10
        elseif e.x + vw > DW - 10 then
            e.baseX = DW - 10 - vw - ((e.x + vw) - (DW - 10))
            e.x = DW - 10 - vw
        end

        -- 下落
        e.y = e.y + e.vy * dt

        -- hitFlash
        for _, b in ipairs(e.bricks) do
            if b.hitFlash > 0 then
                b.hitFlash = b.hitFlash - dt
                if b.hitFlash < 0 then b.hitFlash = 0 end
            end
        end

        -- 越过警戒线
        if e.y + vh > DANGER_Y then
            e.dead = true
            baseHp = baseHp - 1
            screenShake = 0.4
            for _ = 1, 16 do
                local angle = math.random() * math.pi * 2
                local speed = 80 + math.random() * 180
                table.insert(particles, {
                    x = e.x + vw / 2, y = DANGER_Y,
                    vx = math.cos(angle) * speed,
                    vy = math.sin(angle) * speed - 80,
                    life = 0.6, maxLife = 0.6,
                    r = 255, g = 80, b = 60,
                    size = 4 + math.random() * 3,
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
            veggiesDefeated = veggiesDefeated + 1
            SpawnFloatText(e.x + vw / 2, e.y + vh / 2, "击破!", {120, 255, 160}, 1.2)
        end

        if e.dead then
            table.remove(veggies, i)
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
    return dx, dy, dist
end

function Game.PointerDown(px, py)
    if state == "menu" then
        ResetGame()
        state = "aiming"
        SpawnWave()
        return
    elseif state == "gameover" then
        ResetGame()
        state = "aiming"
        SpawnWave()
        return
    end

    if state ~= "aiming" then return end
    if not canAim or currentMarble == nil then return end

    -- 只有在弹弓附近按下才开始瞄准
    local dx = px - SLING_X
    local dy = py - SLING_Y
    if dx * dx + dy * dy < 120 * 120 then
        aiming = true
        local pdx, pdy = GetPullState(px, py)
        aimX = SLING_X + pdx
        aimY = SLING_Y + pdy
    end
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
            state = "flying"
        else
            -- 拖拽太短，回弹
            if currentMarble then
                currentMarble.x = SLING_X
                currentMarble.y = SLING_Y
            end
        end
    end
end

function Game.KeyDown(key)
    if key == KEY_SPACE or key == KEY_RETURN then
        if state == "menu" then
            ResetGame()
            state = "aiming"
            SpawnWave()
        elseif state == "gameover" then
            ResetGame()
            state = "aiming"
            SpawnWave()
        end
    end
end

function Game.KeyUp(key)
    -- 预留
end

return Game
