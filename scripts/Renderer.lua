-- Renderer.lua
-- 燃烧的蔬菜 - NanoVG 渲染器

local Renderer = {}

local stars = {}

local function InitStars(w, h, count)
    stars = {}
    for _ = 1, count do
        table.insert(stars, {
            x = math.random() * w, y = math.random() * h,
            size = math.random() < 0.8 and 1 or 2,
            twinkle = math.random() * 6.28,
            speed = 0.5 + math.random() * 1.5,
        })
    end
end

----------------------------------------------------------------------
-- 背景
----------------------------------------------------------------------

local function DrawBackground(ctx, w, h, elapsed)
    local bg = nvgLinearGradient(ctx, 0, 0, 0, h,
        nvgRGBA(30, 18, 55, 255), nvgRGBA(12, 14, 32, 255))
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, w, h)
    nvgFillPaint(ctx, bg)
    nvgFill(ctx)

    for _, s in ipairs(stars) do
        local alpha = 120 + math.floor(120 * (0.5 + 0.5 * math.sin(elapsed * s.speed + s.twinkle)))
        nvgBeginPath(ctx)
        nvgRect(ctx, s.x, s.y, s.size, s.size)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, alpha))
        nvgFill(ctx)
    end

    local glow = nvgLinearGradient(ctx, 0, 0, 0, 200,
        nvgRGBA(255, 120, 40, 50), nvgRGBA(255, 120, 40, 0))
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, w, 200)
    nvgFillPaint(ctx, glow)
    nvgFill(ctx)
end

local function DrawDangerLine(ctx, w, y, elapsed)
    local pulse = 0.5 + 0.5 * math.sin(elapsed * 4)
    nvgBeginPath(ctx)
    nvgStrokeWidth(ctx, 2)
    nvgStrokeColor(ctx, nvgRGBA(255, 70, 70, 120 + 80 * pulse))
    local x = 0
    while x < w do
        nvgMoveTo(ctx, x, y)
        nvgLineTo(ctx, x + 12, y)
        x = x + 20
    end
    nvgStroke(ctx)

    local zone = nvgLinearGradient(ctx, 0, y, 0, y + 140,
        nvgRGBA(255, 50, 50, 30), nvgRGBA(255, 50, 50, 0))
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, y, w, 140)
    nvgFillPaint(ctx, zone)
    nvgFill(ctx)
end

----------------------------------------------------------------------
-- 正方形砖块
----------------------------------------------------------------------

local function DrawBrick(ctx, x, y, size, r, g, b, dr, dg, db, hitFlash, frozen)
    nvgBeginPath(ctx)
    nvgRect(ctx, x, y, size, size)
    if frozen then
        nvgFillColor(ctx, nvgRGBA(
            math.floor(r * 0.5 + 100),
            math.floor(g * 0.5 + 160),
            math.floor(b * 0.5 + 200), 255))
    else
        nvgFillColor(ctx, nvgRGBA(r, g, b, 255))
    end
    nvgFill(ctx)

    -- 高光
    nvgBeginPath(ctx)
    nvgRect(ctx, x + 1, y + 1, size - 2, math.max(2, size * 0.3))
    nvgFillColor(ctx, nvgRGBA(255, 255, 255, 50))
    nvgFill(ctx)

    -- 底暗边
    nvgBeginPath(ctx)
    nvgRect(ctx, x + 1, y + size - 2, size - 2, 1)
    nvgFillColor(ctx, nvgRGBA(0, 0, 0, 80))
    nvgFill(ctx)

    -- 右暗边
    nvgBeginPath(ctx)
    nvgRect(ctx, x + size - 2, y + 1, 1, size - 2)
    nvgFillColor(ctx, nvgRGBA(0, 0, 0, 50))
    nvgFill(ctx)

    -- 描边
    nvgBeginPath(ctx)
    nvgRect(ctx, x + 0.5, y + 0.5, size - 1, size - 1)
    if frozen then
        nvgStrokeColor(ctx, nvgRGBA(180, 230, 255, 255))
    else
        nvgStrokeColor(ctx, nvgRGBA(dr, dg, db, 255))
    end
    nvgStrokeWidth(ctx, 1.5)
    nvgStroke(ctx)

    -- 击中闪白
    if hitFlash > 0 then
        local alpha = math.floor((hitFlash / 0.12) * 200)
        nvgBeginPath(ctx)
        nvgRect(ctx, x, y, size, size)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, alpha))
        nvgFill(ctx)
    end

    -- 冰冻冰晶
    if frozen then
        nvgBeginPath(ctx)
        nvgRect(ctx, x + size * 0.3, y + size * 0.15, 2, size * 0.7)
        nvgRect(ctx, x + size * 0.15, y + size * 0.45, size * 0.7, 2)
        nvgFillColor(ctx, nvgRGBA(220, 245, 255, 180))
        nvgFill(ctx)
    end
end

local function DrawEnemy(ctx, enemy, brickSize)
    local frozen = enemy.frozen > 0
    for _, b in ipairs(enemy.bricks) do
        if b.alive then
            local bx = enemy.x + (b.col - 1) * brickSize
            local by = enemy.y + (b.row - 1) * brickSize
            DrawBrick(ctx, bx, by, brickSize,
                b.r, b.g, b.b, b.dr, b.dg, b.db, b.hitFlash, frozen)
        end
    end
end

----------------------------------------------------------------------
-- 弹弓
----------------------------------------------------------------------

local function DrawSlingshot(ctx, sx, sy)
    -- 底座立柱
    nvgBeginPath(ctx)
    nvgRect(ctx, sx - 6, sy, 12, 80)
    nvgFillColor(ctx, nvgRGBA(120, 70, 30, 255))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRect(ctx, sx - 6, sy, 12, 80)
    nvgStrokeColor(ctx, nvgRGBA(70, 40, 15, 255))
    nvgStrokeWidth(ctx, 2)
    nvgStroke(ctx)

    -- 左叉
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, sx, sy + 4)
    nvgLineTo(ctx, sx - 22, sy - 28)
    nvgLineTo(ctx, sx - 16, sy - 32)
    nvgLineTo(ctx, sx + 2, sy)
    nvgClosePath(ctx)
    nvgFillColor(ctx, nvgRGBA(140, 85, 40, 255))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(70, 40, 15, 255))
    nvgStrokeWidth(ctx, 2)
    nvgStroke(ctx)

    -- 右叉
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, sx, sy + 4)
    nvgLineTo(ctx, sx + 22, sy - 28)
    nvgLineTo(ctx, sx + 16, sy - 32)
    nvgLineTo(ctx, sx - 2, sy)
    nvgClosePath(ctx)
    nvgFillColor(ctx, nvgRGBA(140, 85, 40, 255))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(70, 40, 15, 255))
    nvgStrokeWidth(ctx, 2)
    nvgStroke(ctx)
end

local function DrawSlingBands(ctx, sx, sy, mx, my, aiming)
    if aiming then
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, sx - 19, sy - 30)
        nvgLineTo(ctx, mx, my)
        nvgStrokeColor(ctx, nvgRGBA(80, 50, 20, 200))
        nvgStrokeWidth(ctx, 4)
        nvgStroke(ctx)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, sx + 19, sy - 30)
        nvgLineTo(ctx, mx, my)
        nvgStrokeColor(ctx, nvgRGBA(80, 50, 20, 200))
        nvgStrokeWidth(ctx, 4)
        nvgStroke(ctx)
    else
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, sx - 19, sy - 30)
        nvgLineTo(ctx, sx + 19, sy - 30)
        nvgStrokeColor(ctx, nvgRGBA(80, 50, 20, 180))
        nvgStrokeWidth(ctx, 3)
        nvgStroke(ctx)
    end
end

----------------------------------------------------------------------
-- 弹珠
----------------------------------------------------------------------

local function DrawMarble(ctx, m)
    local def = ctx.__ballTypes[m.ballType]
    local r = m.r

    -- 拖尾
    for i, p in ipairs(m.trail) do
        local t = 1 - (i / #m.trail)
        local alpha = math.floor(80 * t)
        local radius = r * (0.4 + 0.6 * t)
        nvgBeginPath(ctx)
        nvgCircle(ctx, p.x, p.y, radius)
        nvgFillColor(ctx, nvgRGBA(def.trail[1], def.trail[2], def.trail[3], alpha))
        nvgFill(ctx)
    end

    -- 外发光
    local glow = nvgRadialGradient(ctx, m.x, m.y, r * 0.5, r * 2.2,
        nvgRGBA(def.glow[1], def.glow[2], def.glow[3], 130),
        nvgRGBA(def.glow[1], def.glow[2], def.glow[3], 0))
    nvgBeginPath(ctx)
    nvgCircle(ctx, m.x, m.y, r * 2.2)
    nvgFillPaint(ctx, glow)
    nvgFill(ctx)

    -- 主体
    nvgBeginPath(ctx)
    nvgCircle(ctx, m.x, m.y, r)
    nvgFillColor(ctx, nvgRGBA(def.color[1], def.color[2], def.color[3], 255))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgCircle(ctx, m.x, m.y, r)
    nvgStrokeColor(ctx, nvgRGBA(def.stroke[1], def.stroke[2], def.stroke[3], 255))
    nvgStrokeWidth(ctx, 1.5)
    nvgStroke(ctx)

    -- 高光
    nvgBeginPath(ctx)
    nvgCircle(ctx, m.x - r * 0.3, m.y - r * 0.3, r * 0.32)
    nvgFillColor(ctx, nvgRGBA(255, 255, 255, 230))
    nvgFill(ctx)

    -- 巨型球标记
    if m.ballType == "giant" then
        nvgFontFace(ctx, "zpix")
        nvgFontSize(ctx, 14)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, 200))
        nvgText(ctx, m.x, m.y + 1, "大", nil)
    -- 加速球标记
    elseif m.ballType == "speed" then
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, m.x + 1, m.y - 5)
        nvgLineTo(ctx, m.x - 3, m.y)
        nvgLineTo(ctx, m.x, m.y)
        nvgLineTo(ctx, m.x - 1, m.y + 5)
        nvgLineTo(ctx, m.x + 4, m.y - 1)
        nvgLineTo(ctx, m.x + 1, m.y - 1)
        nvgClosePath(ctx)
        nvgFillColor(ctx, nvgRGBA(255, 255, 200, 220))
        nvgFill(ctx)
    -- 冰冻球标记
    elseif m.ballType == "ice" then
        nvgBeginPath(ctx)
        nvgRect(ctx, m.x - 1, m.y - 5, 2, 10)
        nvgRect(ctx, m.x - 5, m.y - 1, 10, 2)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, 200))
        nvgFill(ctx)
    end
end

----------------------------------------------------------------------
-- 弹珠槽位（待发射队列）
----------------------------------------------------------------------

local function DrawBallSlot(ctx, x, y, ballType, ballTypes, scale)
    scale = scale or 0.6
    local def = ballTypes[ballType]
    if not def then return end
    local r = def.r * scale

    -- 槽位底圆
    nvgBeginPath(ctx)
    nvgCircle(ctx, x, y, r + 4)
    nvgFillColor(ctx, nvgRGBA(40, 30, 50, 200))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgCircle(ctx, x, y, r + 4)
    nvgStrokeColor(ctx, nvgRGBA(100, 90, 120, 200))
    nvgStrokeWidth(ctx, 1.5)
    nvgStroke(ctx)

    -- 小球
    nvgBeginPath(ctx)
    nvgCircle(ctx, x, y, r)
    nvgFillColor(ctx, nvgRGBA(def.color[1], def.color[2], def.color[3], 255))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgCircle(ctx, x, y, r)
    nvgStrokeColor(ctx, nvgRGBA(def.stroke[1], def.stroke[2], def.stroke[3], 255))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
end

----------------------------------------------------------------------
-- 瞄准轨迹
----------------------------------------------------------------------

local function DrawAimTrajectory(ctx, sx, sy, mx, my, maxPull, ballTypes, activeType, screenW, screenH)
    local def = ballTypes[activeType]
    if not def then return end
    local dx = mx - sx
    local dy = my - sy
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 5 then return end

    local speed = def.speed * (0.7 + 0.3 * math.min(1, dist / maxPull))
    local nx = -dx / dist
    local ny = -dy / dist
    local vx = nx * speed
    local vy = ny * speed

    local px, py = mx, my
    local r = def.r
    local stepDist = 14
    for i = 1, 50 do
        local len = math.sqrt(vx * vx + vy * vy)
        if len < 0.001 then break end
        px = px + (vx / len) * stepDist
        py = py + (vy / len) * stepDist
        if px - r < 0 then px = r; vx = math.abs(vx) end
        if px + r > screenW then px = screenW - r; vx = -math.abs(vx) end
        if py - r < 0 then py = r; vy = math.abs(vy) end
        if py - r > screenH then break end
        local alpha = math.floor(180 * (1 - i / 50))
        local radius = 3 * (1 - i / 50) + 1.5
        nvgBeginPath(ctx)
        nvgCircle(ctx, px, py, radius)
        nvgFillColor(ctx, nvgRGBA(def.trail[1], def.trail[2], def.trail[3], alpha))
        nvgFill(ctx)
    end
end

----------------------------------------------------------------------
-- 粒子 / 飘字
----------------------------------------------------------------------

local function DrawParticles(ctx, plist)
    for _, p in ipairs(plist) do
        local a = p.life / p.maxLife
        local alpha = math.floor(a * 255)
        local s = p.size * (0.6 + 0.4 * a)
        nvgBeginPath(ctx)
        nvgRect(ctx, p.x - s / 2, p.y - s / 2, s, s)
        nvgFillColor(ctx, nvgRGBA(p.r, p.g, p.b, alpha))
        nvgFill(ctx)
    end
end

local function DrawFloatTexts(ctx, list)
    nvgFontFace(ctx, "zpix")
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    for _, f in ipairs(list) do
        local a = f.life / f.maxLife
        local alpha = math.floor(math.min(1, a * 1.5) * 255)
        local sc = 1 + (1 - a) * 0.4
        nvgFontSize(ctx, f.size * sc)
        nvgFillColor(ctx, nvgRGBA(0, 0, 0, alpha * 0.6))
        nvgText(ctx, f.x + 2, f.y + 2, f.text, nil)
        nvgFillColor(ctx, nvgRGBA(f.color[1], f.color[2], f.color[3], alpha))
        nvgText(ctx, f.x, f.y, f.text, nil)
    end
end

----------------------------------------------------------------------
-- HUD
----------------------------------------------------------------------

local function DrawHUD(ctx, s)
    nvgFontFace(ctx, "zpix")
    nvgFontSize(ctx, 30)
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(ctx, nvgRGBA(0, 0, 0, 180))
    nvgText(ctx, 17, 13, tostring(s.score), nil)
    nvgFillColor(ctx, nvgRGBA(255, 230, 120, 255))
    nvgText(ctx, 15, 11, tostring(s.score), nil)

    nvgFontSize(ctx, 14)
    nvgFillColor(ctx, nvgRGBA(180, 190, 220, 200))
    nvgText(ctx, 17, 46, "BEST " .. tostring(s.highScore), nil)

    nvgFontSize(ctx, 18)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(ctx, nvgRGBA(255, 180, 100, 230))
    nvgText(ctx, s.DW / 2, 14, "WAVE " .. tostring(s.wave), nil)

    for i = 1, s.maxBaseHp do
        local hx = s.DW - 20 - (s.maxBaseHp - i) * 24
        local hy = 22
        local filled = i <= s.baseHp
        nvgBeginPath(ctx)
        if filled then
            nvgCircle(ctx, hx - 4, hy, 5)
            nvgCircle(ctx, hx + 4, hy, 5)
            nvgMoveTo(ctx, hx - 8.5, hy + 2)
            nvgLineTo(ctx, hx, hy + 12)
            nvgLineTo(ctx, hx + 8.5, hy + 2)
            nvgClosePath(ctx)
            nvgFillColor(ctx, nvgRGBA(255, 80, 90, 255))
            nvgFill(ctx)
            nvgStrokeColor(ctx, nvgRGBA(180, 40, 50, 255))
        else
            nvgCircle(ctx, hx - 4, hy, 5)
            nvgCircle(ctx, hx + 4, hy, 5)
            nvgMoveTo(ctx, hx - 8.5, hy + 2)
            nvgLineTo(ctx, hx, hy + 12)
            nvgLineTo(ctx, hx + 8.5, hy + 2)
            nvgClosePath(ctx)
            nvgFillColor(ctx, nvgRGBA(60, 60, 80, 200))
            nvgFill(ctx)
            nvgStrokeColor(ctx, nvgRGBA(100, 100, 130, 255))
        end
        nvgStrokeWidth(ctx, 1.5)
        nvgStroke(ctx)
    end

    if s.waveBannerTimer > 0 then
        local t = s.waveBannerTimer
        local alpha = t > 1.5 and (1.8 - t) / 0.3 or (t < 0.3 and t / 0.3 or 1)
        alpha = math.floor(math.max(0, math.min(1, alpha)) * 255)
        nvgFontSize(ctx, 40)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(0, 0, 0, alpha))
        nvgText(ctx, s.DW / 2 + 3, s.DH * 0.35 + 3, "WAVE " .. tostring(s.wave), nil)
        nvgFillColor(ctx, nvgRGBA(255, 180, 80, alpha))
        nvgText(ctx, s.DW / 2, s.DH * 0.35, "WAVE " .. tostring(s.wave), nil)
    end
end

----------------------------------------------------------------------
-- 菜单 / 结束
----------------------------------------------------------------------

local function DrawMenu(ctx, s)
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, s.DW, s.DH)
    nvgFillColor(ctx, nvgRGBA(8, 10, 24, 200))
    nvgFill(ctx)

    nvgFontFace(ctx, "zpix")
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    nvgFontSize(ctx, 52)
    nvgFillColor(ctx, nvgRGBA(60, 10, 0, 255))
    nvgText(ctx, s.DW / 2 + 3, s.DH * 0.20 + 3, "燃烧的蔬菜", nil)
    nvgFillColor(ctx, nvgRGBA(255, 110, 40, 255))
    nvgText(ctx, s.DW / 2, s.DH * 0.20, "燃烧的蔬菜", nil)

    nvgFontSize(ctx, 24)
    nvgFillColor(ctx, nvgRGBA(255, 220, 140, 255))
    nvgText(ctx, s.DW / 2, s.DH * 0.20 + 48, "四弹珠连射", nil)

    -- 四种球说明
    local bt = s.ballTypes
    local descY = s.DH * 0.40
    local descs = {
        { "常规", "normal", "标准弹珠" },
        { "冰冻", "ice", "冰冻减速敌人" },
        { "加速", "speed", "碰撞后越弹越快" },
        { "巨型", "giant", "双倍伤害大范围" },
    }
    for i, d in ipairs(descs) do
        local y = descY + (i - 1) * 48
        local def = bt[d[2]]
        nvgBeginPath(ctx)
        nvgCircle(ctx, s.DW / 2 - 110, y, def.r * 0.9)
        nvgFillColor(ctx, nvgRGBA(def.color[1], def.color[2], def.color[3], 255))
        nvgFill(ctx)
        nvgBeginPath(ctx)
        nvgCircle(ctx, s.DW / 2 - 110, y, def.r * 0.9)
        nvgStrokeColor(ctx, nvgRGBA(def.stroke[1], def.stroke[2], def.stroke[3], 255))
        nvgStrokeWidth(ctx, 1.5)
        nvgStroke(ctx)

        nvgFontSize(ctx, 18)
        nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(255, 240, 200, 255))
        nvgText(ctx, s.DW / 2 - 80, y - 8, d[1], nil)
        nvgFontSize(ctx, 13)
        nvgFillColor(ctx, nvgRGBA(180, 190, 210, 220))
        nvgText(ctx, s.DW / 2 - 80, y + 12, d[3], nil)
    end

    nvgFontSize(ctx, 14)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(200, 210, 230, 220))
    nvgText(ctx, s.DW / 2, s.DH * 0.72, "向后拖拽弹弓瞄准,松开发射", nil)
    nvgText(ctx, s.DW / 2, s.DH * 0.72 + 22, "四颗弹珠可连射,同场反弹", nil)

    local blink = 0.5 + 0.5 * math.sin(s.elapsed * 3)
    nvgFontSize(ctx, 22)
    nvgFillColor(ctx, nvgRGBA(255, 255, 220, 180 + 60 * blink))
    nvgText(ctx, s.DW / 2, s.DH * 0.82, "点击屏幕开始", nil)
end

local function DrawGameOver(ctx, s)
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, s.DW, s.DH)
    nvgFillColor(ctx, nvgRGBA(20, 5, 10, 210))
    nvgFill(ctx)

    local pw, ph = 360, 300
    local px = (s.DW - pw) / 2
    local py = s.DH * 0.32
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, px, py, pw, ph, 8)
    nvgFillColor(ctx, nvgRGBA(35, 25, 40, 245))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, px + 0.5, py + 0.5, pw - 1, ph - 1, 8)
    nvgStrokeColor(ctx, nvgRGBA(255, 100, 60, 255))
    nvgStrokeWidth(ctx, 3)
    nvgStroke(ctx)

    nvgFontFace(ctx, "zpix")
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 38)
    nvgFillColor(ctx, nvgRGBA(255, 90, 70, 255))
    nvgText(ctx, s.DW / 2, py + 55, "游戏结束", nil)
    nvgFontSize(ctx, 18)
    nvgFillColor(ctx, nvgRGBA(200, 200, 220, 255))
    nvgText(ctx, s.DW / 2, py + 105, "SCORE", nil)
    nvgFontSize(ctx, 32)
    nvgFillColor(ctx, nvgRGBA(255, 230, 120, 255))
    nvgText(ctx, s.DW / 2, py + 138, tostring(s.score), nil)
    nvgFontSize(ctx, 16)
    nvgFillColor(ctx, nvgRGBA(180, 190, 220, 255))
    nvgText(ctx, s.DW / 2, py + 178, "BEST " .. tostring(s.highScore), nil)
    nvgText(ctx, s.DW / 2, py + 202, "WAVE " .. tostring(s.wave), nil)
    local blink = 0.5 + 0.5 * math.sin(s.elapsed * 3)
    nvgFontSize(ctx, 20)
    nvgFillColor(ctx, nvgRGBA(255, 255, 220, 160 + 70 * blink))
    nvgText(ctx, s.DW / 2, py + 255, "点击重新开始", nil)
end

----------------------------------------------------------------------
-- 主渲染
----------------------------------------------------------------------

function Renderer.Render(ctx, s)
    if #stars == 0 then InitStars(s.DW, s.DH, 70) end
    ctx.__ballTypes = s.ballTypes  -- 传递给 DrawMarble

    nvgSave(ctx)
    if s.screenShake > 0 then
        local amp = s.screenShake * 12
        nvgTranslate(ctx, (math.random() - 0.5) * amp, (math.random() - 0.5) * amp)
    end

    DrawBackground(ctx, s.DW, s.DH, s.elapsed)
    DrawDangerLine(ctx, s.DW, s.DANGER_Y, s.elapsed)

    for _, e in ipairs(s.veggies) do
        DrawEnemy(ctx, e, e.brickSize)
    end

    -- 橡皮筋
    if s.activeBall then
        DrawSlingBands(ctx, s.slingX, s.slingY, s.activeBall.x, s.activeBall.y, s.aiming)
    else
        DrawSlingBands(ctx, s.slingX, s.slingY, s.slingX, s.slingY, false)
    end

    DrawSlingshot(ctx, s.slingX, s.slingY)

    -- 槽位中待发射的球（弹弓左右各两种）
    local slotPositions = {
        { x = s.slingX - 55, y = s.slingY + 40 },
        { x = s.slingX - 55, y = s.slingY + 68 },
        { x = s.slingX + 55, y = s.slingY + 40 },
        { x = s.slingX + 55, y = s.slingY + 68 },
    }
    for i, bt in ipairs(s.ballQueue) do
        if slotPositions[i] then
            DrawBallSlot(ctx, slotPositions[i].x, slotPositions[i].y, bt, s.ballTypes, 0.6)
        end
    end

    -- 弹弓上的弹珠
    if s.activeBall then
        DrawMarble(ctx, s.activeBall)
    end

    -- 飞行中的弹珠
    for _, m in ipairs(s.marbles) do
        DrawMarble(ctx, m)
    end

    -- 瞄准轨迹
    if s.aiming and s.activeBall then
        DrawAimTrajectory(ctx, s.slingX, s.slingY,
            s.activeBall.x, s.activeBall.y,
            s.maxPull, s.ballTypes, s.activeBall.ballType, s.DW, s.DH)
    end

    DrawParticles(ctx, s.particles)
    DrawFloatTexts(ctx, s.floatTexts)

    nvgRestore(ctx)
    DrawHUD(ctx, s)

    if s.state == "menu" then
        DrawMenu(ctx, s)
    elseif s.state == "gameover" then
        DrawGameOver(ctx, s)
    end
end

return Renderer
