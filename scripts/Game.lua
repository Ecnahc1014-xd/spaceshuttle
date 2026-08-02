-- Game.lua
-- 燃烧的蔬菜 - 核心游戏逻辑（弹珠 / 砖块 / 敌人编队 / 波次 / 碰撞）

local Shapes = require "Shapes"

local Game = {}

local BW = Shapes.BRICK_W -- 34
local BH = Shapes.BRICK_H -- 18

-- 设计尺寸（由 Init 传入）
local DW = 540
local DH = 960

-- 常量
local MARBLE_SPEED = 540
local MARBLE_RADIUS = 7
local FIRE_INTERVAL = 0.20
local MAX_MARBLES = 6
local PLAYER_KEYBOARD_SPEED = 420
local DANGER_Y = 855
local PLAYER_Y = 912
local COMBO_TIMEOUT = 1.6

-- 游戏状态
local state = "menu" -- menu / playing / gameover
local score = 0
local highScore = 0
local lives = 3
local wave = 1
local combo = 0
local comboTimer = 0
local screenShake = 0
local waveBannerTimer = 0
local elapsed = 0

-- 实体
local player_ = nil
local marbles = {}
local enemies = {}
local particles = {}
local floatTexts = {}

-- 波次控制
local waveCooldown = 0
local pendingSpawns = {}

-- 输入
local pointerDown = false
local pointerX = 270
local leftKey = false
local rightKey = false

----------------------------------------------------------------------
-- 初始化
----------------------------------------------------------------------

-- 前向声明（部分函数在 Game.Update 中调用，定义在后面）
local ResetGame
local UpdateParticles
local UpdateFloatTexts

function Game.Init(w, h)
    DW = w
    DH = h
    pointerX = DW / 2
    ResetGame()
    state = "menu"
end

function Game.GetState()
    return {
        state = state,
        score = score,
        highScore = highScore,
        lives = lives,
        wave = wave,
        combo = combo,
        comboTimer = comboTimer,
        COMBO_TIMEOUT = COMBO_TIMEOUT,
        screenShake = screenShake,
        waveBannerTimer = waveBannerTimer,
        player = player_,
        marbles = marbles,
        enemies = enemies,
        particles = particles,
        floatTexts = floatTexts,
        elapsed = elapsed,
        DW = DW,
        DH = DH,
    }
end

local function CreatePlayer()
    return {
        x = DW / 2,
        y = PLAYER_Y,
        width = 60,
        height = 22,
        fireCooldown = 0,
        recoil = 0,
    }
end

function ResetGame()
    score = 0
    lives = 3
    wave = 1
    combo = 0
    comboTimer = 0
    screenShake = 0
    waveBannerTimer = 0
    elapsed = 0
    player_ = CreatePlayer()
    marbles = {}
    enemies = {}
    particles = {}
    floatTexts = {}
    pendingSpawns = {}
    waveCooldown = 0.4
    pointerDown = false
    pointerX = DW / 2
end

----------------------------------------------------------------------
-- 敌人生成
----------------------------------------------------------------------

local function CreateEnemy(veggieType, x, y, vx, vy)
    local def = Shapes.VEGETABLES[veggieType]
    local bricks, _, _ = Shapes.ParseShape(def.shape)
    local brickList = {}
    for _, b in ipairs(bricks) do
        table.insert(brickList, {
            col = b.col,
            row = b.row,
            hp = def.hp,
            maxHp = def.hp,
            alive = true,
            hitFlash = 0,
            seed = math.random() * 6.28,
        })
    end
    return {
        veggieType = veggieType,
        x = x,
        y = y,
        vx = vx,
        vy = vy,
        baseX = x,
        swayAmp = 30 + math.random() * 40,
        swayFreq = 0.7 + math.random() * 0.5,
        phase = math.random() * 6.28,
        bricks = brickList,
        dead = false,
        hitFlash = 0,
        enterDelay = 0,
    }
end

local function GetEnemyWidth(enemy)
    local w, _ = Shapes.GetVeggieSize(enemy.veggieType)
    return w
end

local function GetEnemyHeight(enemy)
    local _, h = Shapes.GetVeggieSize(enemy.veggieType)
    return h
end

local function SpawnWave()
    local pool = Shapes.GetAvailableTypes(wave)
    local count = 2 + math.floor(wave / 2)
    if count > 5 then count = 5 end
    if wave >= 6 then count = 4 + (wave % 2) end

    local margin = 18
    local usedX = {}

    for i = 1, count do
        local veggieType = pool[math.random(#pool)]
        local w = GetEnemyWidth({ veggieType = veggieType })

        -- 尝试找一个不重叠的 x
        local x = margin + math.random() * (DW - w - margin * 2)
        for _ = 1, 10 do
            local overlap = false
            for _, ux in ipairs(usedX) do
                if math.abs(ux - (x + w / 2)) < 90 then
                    overlap = true
                    break
                end
            end
            if not overlap then break end
            x = margin + math.random() * (DW - w - margin * 2)
        end
        table.insert(usedX, x + w / 2)

        local def = Shapes.VEGETABLES[veggieType]
        local baseSpeed = 16 + wave * 2.6
        if baseSpeed > 52 then baseSpeed = 52 end
        local vy = baseSpeed * def.speedMul
        local vx = (math.random() > 0.5 and 1 or -1) * (18 + math.random() * 22)

        local enemy = CreateEnemy(veggieType, x, -GetEnemyHeight({ veggieType = veggieType }) - i * 90, vx, vy)
        enemy.baseX = x
        enemy.swayAmp = 25 + math.random() * 35
        table.insert(enemies, enemy)
    end

    waveBannerTimer = 1.6
end

----------------------------------------------------------------------
-- 碰撞
----------------------------------------------------------------------

-- 圆 vs 矩形碰撞并反弹。返回是否命中。
local function CollideBrick(marble, rx, ry, rw, rh)
    local cx, cy, r = marble.x, marble.y, marble.r
    local closestX = math.max(rx, math.min(cx, rx + rw))
    local closestY = math.max(ry, math.min(cy, ry + rh))
    local dx = cx - closestX
    local dy = cy - closestY
    if dx * dx + dy * dy >= r * r then
        return false
    end

    -- 用圆心相对矩形中心的偏移比例判断碰撞主轴
    local centerX = rx + rw * 0.5
    local centerY = ry + rh * 0.5
    local ox = math.abs(cx - centerX) / (rw * 0.5 + r)
    local oy = math.abs(cy - centerY) / (rh * 0.5 + r)

    if ox >= oy then
        marble.vx = -marble.vx
        if cx >= centerX then
            marble.x = rx + rw + r + 0.1
        else
            marble.x = rx - r - 0.1
        end
    else
        marble.vy = -marble.vy
        if cy >= centerY then
            marble.y = ry + rh + r + 0.1
        else
            marble.y = ry - r - 0.1
        end
    end
    return true
end

----------------------------------------------------------------------
-- 粒子 / 飘字
----------------------------------------------------------------------

local function SpawnBrickParticles(x, y, color, count)
    count = count or 9
    for _ = 1, count do
        local angle = math.random() * math.pi * 2
        local speed = 70 + math.random() * 180
        table.insert(particles, {
            x = x, y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed - 60,
            life = 0.45 + math.random() * 0.35,
            maxLife = 0.8,
            color = color,
            size = 3 + math.random() * 3,
            gravity = 320,
        })
    end
end

local function SpawnHitSpark(x, y, color)
    for _ = 1, 4 do
        local angle = math.random() * math.pi * 2
        local speed = 40 + math.random() * 90
        table.insert(particles, {
            x = x, y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = 0.25 + math.random() * 0.2,
            maxLife = 0.45,
            color = color,
            size = 2 + math.random() * 2,
            gravity = 120,
        })
    end
end

local function SpawnFloatText(x, y, text, color, sizeMul)
    table.insert(floatTexts, {
        x = x, y = y,
        vy = -42,
        life = 0.9,
        maxLife = 0.9,
        text = text,
        color = color or { 255, 255, 255 },
        size = (sizeMul or 1) * 20,
    })
end

----------------------------------------------------------------------
-- 伤害
----------------------------------------------------------------------

local function DamageBrick(enemy, brick)
    brick.hp = brick.hp - 1
    brick.hitFlash = 0.12

    local bx = enemy.x + (brick.col - 0.5) * BW
    local by = enemy.y + (brick.row - 0.5) * BH

    if brick.hp <= 0 then
        brick.alive = false
        local def = Shapes.VEGETABLES[enemy.veggieType]

        combo = combo + 1
        comboTimer = COMBO_TIMEOUT
        local multiplier = math.min(combo, 10)
        local gain = def.score * multiplier
        score = score + gain

        SpawnBrickParticles(bx, by, def.color, 10)

        if multiplier >= 2 then
            SpawnFloatText(bx, by - 6, "x" .. multiplier, { 255, 220, 90 }, 1.1)
        else
            SpawnFloatText(bx, by - 6, "+" .. def.score, { 255, 255, 200 }, 0.85)
        end
    else
        local def = Shapes.VEGETABLES[enemy.veggieType]
        SpawnHitSpark(bx, by, { 255, 240, 180 })
    end
end

local function IsEnemyCleared(enemy)
    for _, b in ipairs(enemy.bricks) do
        if b.alive then return false end
    end
    return true
end

----------------------------------------------------------------------
-- 发射
----------------------------------------------------------------------

local function FindNearestEnemyY(fromX)
    local nearestY = nil
    local nearestX = nil
    local nearestDist = math.huge
    for _, e in ipairs(enemies) do
        if not e.dead then
            for _, b in ipairs(e.bricks) do
                if b.alive then
                    local bx = e.x + (b.col - 0.5) * BW
                    local by = e.y + (b.row - 0.5) * BH
                    local d = (bx - fromX) * (bx - fromX) + by * by
                    if d < nearestDist then
                        nearestDist = d
                        nearestY = by
                        nearestX = bx
                    end
                end
            end
        end
    end
    return nearestX, nearestY
end

local function FireMarble()
    if #marbles >= MAX_MARBLES then return end

    -- 基础朝上，带小随机偏差
    local angle = -math.pi / 2 + (math.random() * 0.25 - 0.125)

    -- 若有敌人，轻微瞄准最近砖块
    local tx, ty = FindNearestEnemyY(player_.x)
    if tx and ty and ty < player_.y - 40 then
        local targetAngle = math.atan(ty - player_.y, tx - player_.x)
        -- 限制在接近垂直向上的扇形内
        local minA = -math.pi + 0.45
        local maxA = -0.45
        if targetAngle >= minA and targetAngle <= maxA then
            -- 只取 60% 的瞄准修正，保留一定散射
            angle = angle + (targetAngle - angle) * 0.6
        end
    end

    local m = {
        x = player_.x,
        y = player_.y - 16,
        vx = math.cos(angle) * MARBLE_SPEED,
        vy = math.sin(angle) * MARBLE_SPEED,
        r = MARBLE_RADIUS,
        trail = {},
        alive = true,
    }
    table.insert(marbles, m)
    player_.recoil = 1
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

    if state ~= "playing" then
        -- 菜单态也让粒子动
        return
    end

    -- combo 计时
    if comboTimer > 0 then
        comboTimer = comboTimer - dt
        if comboTimer <= 0 then
            combo = 0
            comboTimer = 0
        end
    end

    UpdatePlayer(dt)
    UpdateMarbles(dt)
    UpdateEnemies(dt)

    -- 检查波次
    local anyAlive = false
    for _, e in ipairs(enemies) do
        if not e.dead then anyAlive = true break end
    end
    if not anyAlive then
        waveCooldown = waveCooldown - dt
        if waveCooldown <= 0 then
            wave = wave + 1
            SpawnWave()
            waveCooldown = 2.0
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
            p.vy = p.vy + (p.gravity or 200) * dt
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

function UpdatePlayer(dt)
    local p = player_

    -- 键盘移动
    if leftKey then
        p.x = p.x - PLAYER_KEYBOARD_SPEED * dt
    end
    if rightKey then
        p.x = p.x + PLAYER_KEYBOARD_SPEED * dt
    end

    -- 指针移动
    if pointerDown then
        p.x = p.x + (pointerX - p.x) * math.min(1, dt * 18)
    end

    -- 边界
    local half = p.width * 0.5
    if p.x < half then p.x = half end
    if p.x > DW - half then p.x = DW - half end

    -- 后坐力衰减
    if p.recoil > 0 then
        p.recoil = p.recoil - dt * 5
        if p.recoil < 0 then p.recoil = 0 end
    end

    -- 自动发射
    p.fireCooldown = p.fireCooldown - dt
    if p.fireCooldown <= 0 then
        FireMarble()
        p.fireCooldown = FIRE_INTERVAL
    end
end

function UpdateMarbles(dt)
    for i = #marbles, 1, -1 do
        local m = marbles[i]

        -- 拖尾
        table.insert(m.trail, 1, { x = m.x, y = m.y })
        if #m.trail > 9 then table.remove(m.trail) end

        -- 子步进，防止高速穿透
        local steps = 2
        local sdt = dt / steps
        for _ = 1, steps do
            m.x = m.x + m.vx * sdt
            m.y = m.y + m.vy * sdt
            HandleMarbleCollisions(m)
            if not m.alive then break end
        end

        if not m.alive or m.y - m.r > DH then
            table.remove(marbles, i)
        end
    end
end

function HandleMarbleCollisions(m)
    -- 墙壁反弹
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

    -- 砖块碰撞（每帧每弹珠最多命中一块，避免多次反弹异常）
    for _, enemy in ipairs(enemies) do
        if not enemy.dead then
            for _, brick in ipairs(enemy.bricks) do
                if brick.alive then
                    local rx = enemy.x + (brick.col - 1) * BW
                    local ry = enemy.y + (brick.row - 1) * BH
                    if CollideBrick(m, rx + 1, ry + 1, BW - 2, BH - 2) then
                        DamageBrick(enemy, brick)
                        return
                    end
                end
            end
        end
    end
end

function UpdateEnemies(dt)
    for i = #enemies, 1, -1 do
        local e = enemies[i]

        if e.enterDelay > 0 then
            e.enterDelay = e.enterDelay - dt
        else
            -- 左右摆动 + 下落
            e.phase = e.phase + dt * e.swayFreq
            local targetX = e.baseX + math.sin(e.phase) * e.swayAmp
            e.x = targetX

            -- 边界夹紧
            local ew = GetEnemyWidth(e)
            if e.x < 10 then
                e.baseX = 10 + (e.baseX - e.x)
                e.x = 10
                e.vx = math.abs(e.vx)
            elseif e.x + ew > DW - 10 then
                e.baseX = DW - 10 - ew - ((e.x + ew) - (DW - 10))
                e.x = DW - 10 - ew
                e.vx = -math.abs(e.vx)
            end

            e.y = e.y + e.vy * dt

            -- hitFlash 衰减
            if e.hitFlash > 0 then
                e.hitFlash = e.hitFlash - dt
                if e.hitFlash < 0 then e.hitFlash = 0 end
            end
            for _, b in ipairs(e.bricks) do
                if b.hitFlash > 0 then
                    b.hitFlash = b.hitFlash - dt
                    if b.hitFlash < 0 then b.hitFlash = 0 end
                end
            end

            -- 越过警戒线
            local eh = GetEnemyHeight(e)
            if e.y + eh > DANGER_Y then
                e.dead = true
                lives = lives - 1
                screenShake = 0.45
                combo = 0
                comboTimer = 0
                -- 突破的爆炸粒子
                for _ = 1, 18 do
                    local angle = math.random() * math.pi * 2
                    local speed = 80 + math.random() * 200
                    table.insert(particles, {
                        x = e.x + ew / 2,
                        y = DANGER_Y,
                        vx = math.cos(angle) * speed,
                        vy = math.sin(angle) * speed - 80,
                        life = 0.6 + math.random() * 0.3,
                        maxLife = 0.9,
                        color = { 255, 90, 60 },
                        size = 4 + math.random() * 3,
                        gravity = 280,
                    })
                end
                if lives <= 0 then
                    lives = 0
                    state = "gameover"
                    if score > highScore then highScore = score end
                end
            end
        end

        -- 全灭判定
        if not e.dead and IsEnemyCleared(e) then
            e.dead = true
            -- 整颗蔬菜消灭奖励
            score = score + 50
            local cx = e.x + GetEnemyWidth(e) / 2
            local cy = e.y + GetEnemyHeight(e) / 2
            SpawnFloatText(cx, cy, "击破!", { 120, 255, 160 }, 1.2)
        end

        if e.dead then
            -- 死亡敌人可以留一帧再移除，这里直接移除
            table.remove(enemies, i)
        end
    end
end

----------------------------------------------------------------------
-- 输入
----------------------------------------------------------------------

function Game.PointerDown(x, y)
    pointerDown = true
    pointerX = x

    if state == "menu" then
        ResetGame()
        state = "playing"
        SpawnWave()
        return
    elseif state == "gameover" then
        ResetGame()
        state = "playing"
        SpawnWave()
        return
    end
end

function Game.PointerMove(x, y)
    pointerX = x
end

function Game.PointerUp(x, y)
    pointerDown = false
end

function Game.KeyDown(key)
    if key == KEY_A or key == KEY_LEFT then
        leftKey = true
    elseif key == KEY_D or key == KEY_RIGHT then
        rightKey = true
    elseif key == KEY_SPACE or key == KEY_RETURN then
        if state == "menu" then
            ResetGame()
            state = "playing"
            SpawnWave()
        elseif state == "gameover" then
            ResetGame()
            state = "playing"
            SpawnWave()
        end
    end
end

function Game.KeyUp(key)
    if key == KEY_A or key == KEY_LEFT then
        leftKey = false
    elseif key == KEY_D or key == KEY_RIGHT then
        rightKey = false
    end
end

return Game
