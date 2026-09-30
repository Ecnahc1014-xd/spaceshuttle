-- Presentation.lua
-- 表现状态控制器：消费 Game 发布的领域事件，维护与玩法无关的瞬时视觉效果。

local VisualCatalog = require "VisualCatalog"

local Presentation = {}

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
local reloadFlash = 0    -- v0.10.24：主球回库补弹的 Dock 轻闪
local upgradeHintPulse = 0    -- v0.10.24：升级面板空白点击时的提示轻脉冲
local adStatus = nil          -- v0.10.32：nil / "loading"
local adToast = nil
local adToastTimer = 0
-- 云存档状态（**只描述云存档**，不描述联机模式；两者是不同服务，禁止混用文案）：
-- idle / syncing / ok / unavailable
local cloudStatus = "idle"

-- v0.13.12：3D 尾迹两版均"看不见"（软圆串珠+ribbon 光带都在正交 HDR 管线里
-- 无法自证可见），用户拍板改走**已验证可见**的 NanoVG overlay 路径（冲击环/
-- 飘字同款 ProjectGamePoint 投影 + 加色发光描边）。本层只读飞行车辆快照采样，
-- 输出设计坐标光带供 Scene3DBackend 绘制；规则层不感知。
local TRAIL_LIFETIME = 0.34        -- 采样点寿命（秒）
local TRAIL_SAMPLE_SPACING = 11.0  -- 设计像素间距：按路程采样，快慢车拖尾都连续
local TRAIL_MAX_SAMPLES = 20       -- 每辆车采样点上限（寿命到点前截断）
local TRAIL_MAX_VEHICLES = 10      -- 同屏拖尾车辆上限（含待发弹弓车）
local trailSamples_ = {}           -- marbleId -> {ballType, flightTime, x, y, points={{x,y,age},...}}
local vehicleTrails_ = {}          -- 快照输出：每帧重建，[{ballType, polys={{x1..y4,a},...}}, ...]
local trailLastElapsed_ = nil      -- 上一帧 elapsed，检测重开回卷（函数不能挂字段，用模块 local）

local function UpdateVehicleTrails(dt, gameSnapshot)
    -- 重开/回卷检测：elapsed 变小视为新一局，全量清空
    local elapsed = gameSnapshot.elapsed or 0
    if trailLastElapsed_ and elapsed < trailLastElapsed_ - 0.001 then
        trailSamples_ = {}
    end
    trailLastElapsed_ = elapsed

    local playing = gameSnapshot.state == "playing"
    local visible = {}
    local result = {}
    local polysByType = {}
    local count = 0
    if playing then
        local function collect(marble)
            if not marble or count >= TRAIL_MAX_VEHICLES then return end
            local ballType = marble.ballType
            if not ballType then return end
            local id = marble.id
            -- 发射瞬间 activeBall 与 marbles 里是同一对象，按 id 去重防双倍老化。
            if visible[id] then return end
            visible[id] = true
            local track = trailSamples_[id]
            if not track or track.ballType ~= ballType
                or (marble.flightTime or 0) < (track.flightTime or 0) then
                track = {ballType = ballType, flightTime = marble.flightTime or 0,
                    x = marble.x, y = marble.y, points = {}}
                trailSamples_[id] = track
            end
            track.flightTime = marble.flightTime or 0
            local pts = track.points
            for i = #pts, 1, -1 do
                pts[i].age = pts[i].age + dt
                if pts[i].age >= TRAIL_LIFETIME then table.remove(pts, i) end
            end
            -- 静止（暂停在弹弓位/慢速）不补采样也不画，避免原地点糊成一坨
            local speed2 = (marble.vx or 0) ^ 2 + (marble.vy or 0) ^ 2
            local still = marble.onSling and speed2 <= 1 and not gameSnapshot.aiming
            if still then
                pts = {}
                track.points = pts
                return
            end
            local dx, dy = marble.x - track.x, marble.y - track.y
            if dx * dx + dy * dy > 2500 then -- >50px 瞬移（复活/传送），清轨防拉丝
                track.points = {}
                pts = track.points
            end
            local moved = math.sqrt(dx * dx + dy * dy)
            if moved >= TRAIL_SAMPLE_SPACING then
                pts[#pts + 1] = {x = track.x, y = track.y, age = 0}
                if #pts > TRAIL_MAX_SAMPLES then table.remove(pts, 1) end
                track.x, track.y = marble.x, marble.y
            end
            if #pts < 2 then return end
            count = count + 1
            local headX, headY = marble.x, marble.y
            -- 颜色不在这里定：后端按 ballType 用 SLOT_COLORS 统一注入（样式单一来源）。
            local group = polysByType[ballType]
            if not group then
                group = {}
                polysByType[ballType] = group
                result[#result + 1] = {ballType = ballType, polys = group}
            end
            local n = #pts
            local radius = marble.radius or 20
            local widthScale = radius / 20.0
            for i = 1, n do
                local ax, ay = pts[i].x, pts[i].y
                local bx, by
                if i < n then bx, by = pts[i + 1].x, pts[i + 1].y
                else bx, by = headX, headY end
                local sdx, sdy = bx - ax, by - ay
                local slen = math.sqrt(sdx * sdx + sdy * sdy)
                if slen > 0.5 then
                    local nx, ny = -sdy / slen, sdx / slen
                    -- 尾细头粗：半宽沿采样序列线性放大（t=0 尾 → t=1 头）
                    local t0 = (i - 1) / n
                    local t1 = i / n
                    local wa = (2.2 + 12.5 * t0) * widthScale
                    local wb = (2.2 + 12.5 * t1) * widthScale
                    local lifeA = 1 - pts[i].age / TRAIL_LIFETIME
                    local alpha = 200 * (t1 ^ 1.25) * math.min(1, lifeA + 0.35)
                    group[#group + 1] = {
                        x1 = ax + nx * wa, y1 = ay + ny * wa,
                        x2 = bx + nx * wb, y2 = by + ny * wb,
                        x3 = bx - nx * wb, y3 = by - ny * wb,
                        x4 = ax - nx * wa, y4 = ay - ny * wa,
                        a = alpha,
                    }
                end
            end
        end
        collect(gameSnapshot.activeBall)
        for _, marble in ipairs(gameSnapshot.marbles or {}) do
            if not marble.onSling then collect(marble) end
        end
        for id in pairs(trailSamples_) do
            if not visible[id] then trailSamples_[id] = nil end
        end
    else
        trailSamples_ = {}
    end
    vehicleTrails_ = result
    return result
end

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
    base_hit = {"baseShake"},
    marble_launched = {"launchFlash"},
    normal_split = {"splitSpark"},
    speed_dash = {"dashSpark"},
    giant_pierce_armed = {"pierceArmed"},
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

-- WO-14/P2：每个反馈名对应一个只写 Presentation 瞬时状态的处理函数。
-- HandleEvent 按 FEEDBACK_MAP 分派，新增反馈只需补充映射 + 处理函数。
local FEEDBACK_HANDLERS = {
    fullReset = function(event)
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
        reloadFlash = 0
        upgradeHintPulse = 0
        adStatus = nil
        adToast = nil
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
        -- v0.10.24：发射点一个快速扩散的青色小环，作为"离弦"反馈。
        shockRings[#shockRings + 1] = {
            x = event.x or 270, y = event.y or 850,
            life = 0.24, maxLife = 0.24,
            r0 = 8, r1 = 26,
            r = launchColor[1], g = launchColor[2], b = launchColor[3],
        }
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
    pierceArmed = function(event)
        screenShake = math.max(screenShake, 0.16)
        SpawnParticles(event.x, event.y, {205, 145, 255}, math.random(2, 4), "spark")
        SpawnFloatText(event.x, event.y - 22, "可以贯穿", {225, 170, 255}, 0.9)
    end,
    giantBurst = function(event)
        screenShake = math.max(screenShake, 0.22)
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
        SpawnFloatText(270, 430, "复活  +" .. tostring(event.hp or 50) .. " 血", {0, 229, 208}, 1.2)
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
    reloadFlash = 0
    upgradeHintPulse = 0
    adStatus = nil
    adToast = nil
    adToastTimer = 0
    cloudStatus = "idle"
    trailSamples_ = {}
    vehicleTrails_ = {}
    trailLastElapsed_ = nil
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

    UpdateParticles(dt)
    UpdateFloatTexts(dt)
    UpdateHitFlashes(dt)
    UpdateBrickDebris(dt)
    UpdateEjectedBoxes(dt)
    UpdateBaseImpacts(dt)
    UpdateShockRings(dt)
    UpdateTruckLaunchFlashes(dt)
    UpdateVehicleTrails(dt, gameSnapshot)
end

function Presentation.GetSnapshot()
    return {
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
        ejectedBoxes = ejectedBoxes,
        baseBarrierFlash = baseBarrierFlash,
        reloadFlash = reloadFlash,
        upgradeHintPulse = upgradeHintPulse,
        adStatus = adStatus,
        adToast = adToast,
        cloudStatus = cloudStatus,
        truckLaunchFlash = truckLaunchFlash,
        vehicleTrails = vehicleTrails_,
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

function Presentation.SetCloudStatus(status)
    cloudStatus = status or "idle"
end

return Presentation
