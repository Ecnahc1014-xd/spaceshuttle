-- Renderer.lua
-- 燃烧的蔬菜 - NanoVG 渲染器（正方形像素砖块 + 弹弓 + 瞄准轨迹）

local VeggieLoader = require "VeggieLoader"

local Renderer = {}

-- 背景星星（生成一次后复用）
local stars = {}

local function InitStars(w, h, count)
    stars = {}
    for _ = 1, count do
        table.insert(stars, {
            x = math.random() * w,
            y = math.random() * h,
            size = math.random() < 0.8 and 1 or 2,
            twinkle = math.random() * 6.28,
            speed = 0.5 + math.random() * 1.5,
        })
    end
end

local function rgba(r, g, b, a)
    return nvgRGBA(math.floor(r), math.floor(g), math.floor(b), a or 255)
end

----------------------------------------------------------------------
-- 背景
----------------------------------------------------------------------

local function DrawBackground(ctx, w, h, elapsed)
    -- 深色渐变
    local bg = nvgLinearGradient(ctx, 0, 0, 0, h,
        nvgRGBA(30, 18, 55, 255),
        nvgRGBA(12, 14, 32, 255))
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, w, h)
    nvgFillPaint(ctx, bg)
    nvgFill(ctx)

    -- 星星
    for _, s in ipairs(stars) do
        local alpha = 120 + math.floor(120 * (0.5 + 0.5 * math.sin(elapsed * s.speed + s.twinkle)))
        nvgBeginPath(ctx)
        nvgRect(ctx, s.x, s.y, s.size, s.size)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, alpha))
        nvgFill(ctx)
    end

    -- 顶部暖色辉光
    local glow = nvgLinearGradient(ctx, 0, 0, 0, 200,
        nvgRGBA(255, 120, 40, 50),
        nvgRGBA(255, 120, 40, 0))
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, w, 200)
    nvgFillPaint(ctx, glow)
    nvgFill(ctx)
end

local function DrawDangerLine(ctx, w, y, elapsed)
    local dashLen = 12
    local gapLen = 8
    local pulse = 0.5 + 0.5 * math.sin(elapsed * 4)
    nvgBeginPath(ctx)
    nvgStrokeWidth(ctx, 2)
    nvgStrokeColor(ctx, nvgRGBA(255, 70, 70, 120 + 80 * pulse))
    local x = 0
    while x < w do
        nvgMoveTo(ctx, x, y)
        nvgLineTo(ctx, x + dashLen, y)
        x = x + dashLen + gapLen
    end
    nvgStroke(ctx)

    -- 警戒线下方淡红色区域
    local zone = nvgLinearGradient(ctx, 0, y, 0, y + 140,
        nvgRGBA(255, 50, 50, 30),
        nvgRGBA(255, 50, 50, 0))
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, y, w, 140)
    nvgFillPaint(ctx, zone)
    nvgFill(ctx)
end

----------------------------------------------------------------------
-- 正方形砖块
----------------------------------------------------------------------

local function DrawBrick(ctx, x, y, size, r, g, b, dr, dg, db, hitFlash)
    -- 主体
    nvgBeginPath(ctx)
    nvgRect(ctx, x, y, size, size)
    nvgFillColor(ctx, rgba(r, g, b))
    nvgFill(ctx)

    -- 顶部高光（几何块立体感）
    nvgBeginPath(ctx)
    nvgRect(ctx, x + 1, y + 1, size - 2, math.max(2, size * 0.3))
    nvgFillColor(ctx, nvgRGBA(255, 255, 255, 50))
    nvgFill(ctx)

    -- 底部暗边
    nvgBeginPath(ctx)
    nvgRect(ctx, x + 1, y + size - 2, size - 2, 1)
    nvgFillColor(ctx, nvgRGBA(0, 0, 0, 80))
    nvgFill(ctx)

    -- 右侧暗边
    nvgBeginPath(ctx)
    nvgRect(ctx, x + size - 2, y + 1, 1, size - 2)
    nvgFillColor(ctx, nvgRGBA(0, 0, 0, 50))
    nvgFill(ctx)

    -- 描边
    nvgBeginPath(ctx)
    nvgRect(ctx, x + 0.5, y + 0.5, size - 1, size - 1)
    nvgStrokeColor(ctx, rgba(dr, dg, db))
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
end

local function DrawEnemy(ctx, enemy, brickSize)
    for _, b in ipairs(enemy.bricks) do
        if b.alive then
            local bx = enemy.x + (b.col - 1) * brickSize
            local by = enemy.y + (b.row - 1) * brickSize
            DrawBrick(ctx, bx, by, brickSize,
                b.r, b.g, b.b, b.dr, b.dg, b.db, b.hitFlash)
        end
    end
end

----------------------------------------------------------------------
-- 弹弓
----------------------------------------------------------------------

local function DrawSlingshot(ctx, sx, sy)
    -- Y 形弹弓底座
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
    -- 两根橡皮筋从叉尖连到弹珠
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
        -- 待机时两根叉尖之间的带
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
    -- 拖尾
    for i, p in ipairs(m.trail) do
        local t = 1 - (i / #m.trail)
        local alpha = math.floor(80 * t)
        local radius = m.r * (0.4 + 0.6 * t)
        nvgBeginPath(ctx)
        nvgCircle(ctx, p.x, p.y, radius)
        nvgFillColor(ctx, nvgRGBA(255, 220, 120, alpha))
        nvgFill(ctx)
    end

    -- 外发光
    local glow = nvgRadialGradient(ctx, m.x, m.y, m.r * 0.5, m.r * 2.2,
        nvgRGBA(255, 220, 120, 130),
        nvgRGBA(255, 220, 120, 0))
    nvgBeginPath(ctx)
    nvgCircle(ctx, m.x, m.y, m.r * 2.2)
    nvgFillPaint(ctx, glow)
    nvgFill(ctx)

    -- 主体
    nvgBeginPath(ctx)
    nvgCircle(ctx, m.x, m.y, m.r)
    nvgFillColor(ctx, nvgRGBA(255, 248, 220, 255))
    nvgFill(ctx)

    nvgBeginPath(ctx)
    nvgCircle(ctx, m.x, m.y, m.r)
    nvgStrokeColor(ctx, nvgRGBA(220, 160, 50, 255))
    nvgStrokeWidth(ctx, 1.5)
    nvgStroke(ctx)

    -- 高光
    nvgBeginPath(ctx)
    nvgCircle(ctx, m.x - m.r * 0.3, m.y - m.r * 0.3, m.r * 0.32)
    nvgFillColor(ctx, nvgRGBA(255, 255, 255, 230))
    nvgFill(ctx)
end

----------------------------------------------------------------------
-- 瞄准轨迹预测
----------------------------------------------------------------------

local function DrawAimTrajectory(ctx, sx, sy, mx, my, maxPull, minSpeed, maxSpeed, gravity)
    local dx = mx - sx
    local dy = my - sy
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 5 then return end

    local power = math.min(1, dist / maxPull)
    local speed = minSpeed + (maxSpeed - minSpeed) * power
    local nx = -dx / dist
    local ny = -dy / dist
    local vx = nx * speed
    local vy = ny * speed

    -- 模拟抛物线画点
    local px, py = mx, my
    local dt = 0.025
    nvgBeginPath(ctx)
    for i = 1, 30 do
        vy = vy + gravity * dt
        px = px + vx * dt
        py = py + vy * dt
        if py > 960 then break end
        local alpha = math.floor(200 * (1 - i / 30))
        local radius = 3 * (1 - i / 30) + 1
        nvgBeginPath(ctx)
        nvgCircle(ctx, px, py, radius)
        nvgFillColor(ctx, nvgRGBA(255, 240, 150, alpha))
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
        local scale = 1 + (1 - a) * 0.4
        nvgFontSize(ctx, f.size * scale)
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

    -- 分数
    nvgFontSize(ctx, 30)
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(ctx, nvgRGBA(0, 0, 0, 180))
    nvgText(ctx, 17, 13, tostring(s.score), nil)
    nvgFillColor(ctx, nvgRGBA(255, 230, 120, 255))
    nvgText(ctx, 15, 11, tostring(s.score), nil)

    nvgFontSize(ctx, 14)
    nvgFillColor(ctx, nvgRGBA(180, 190, 220, 200))
    nvgText(ctx, 17, 46, "BEST " .. tostring(s.highScore), nil)

    -- 波次
    nvgFontSize(ctx, 18)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(ctx, nvgRGBA(255, 180, 100, 230))
    nvgText(ctx, s.DW / 2, 14, "WAVE " .. tostring(s.wave), nil)

    -- 基地血量（心形方块）
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
            nvgStrokeWidth(ctx, 1.5)
            nvgStroke(ctx)
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
            nvgStrokeWidth(ctx, 1.5)
            nvgStroke(ctx)
        end
    end

    -- 波次横幅
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
-- 菜单 / 游戏结束
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
    nvgText(ctx, s.DW / 2 + 3, s.DH * 0.24 + 3, "燃烧的蔬菜", nil)
    nvgFillColor(ctx, nvgRGBA(255, 110, 40, 255))
    nvgText(ctx, s.DW / 2, s.DH * 0.24, "燃烧的蔬菜", nil)

    nvgFontSize(ctx, 26)
    nvgFillColor(ctx, nvgRGBA(255, 220, 140, 255))
    nvgText(ctx, s.DW / 2, s.DH * 0.24 + 50, "弹弓弹珠大作战", nil)

    -- 操作说明
    nvgFontSize(ctx, 16)
    nvgFillColor(ctx, nvgRGBA(200, 210, 230, 230))
    nvgText(ctx, s.DW / 2, s.DH * 0.55, "向后拖拽弹弓瞄准", nil)
    nvgText(ctx, s.DW / 2, s.DH * 0.55 + 26, "松开发射弹珠", nil)
    nvgText(ctx, s.DW / 2, s.DH * 0.55 + 52, "弹珠撞墙反弹击碎蔬菜", nil)
    nvgText(ctx, s.DW / 2, s.DH * 0.55 + 78, "别让蔬菜越过警戒线!", nil)

    local blink = 0.5 + 0.5 * math.sin(s.elapsed * 3)
    nvgFontSize(ctx, 22)
    nvgFillColor(ctx, nvgRGBA(255, 255, 220, 180 + 60 * blink))
    nvgText(ctx, s.DW / 2, s.DH * 0.72, "点击屏幕开始", nil)
end

local function DrawGameOver(ctx, s)
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, s.DW, s.DH)
    nvgFillColor(ctx, nvgRGBA(20, 5, 10, 210))
    nvgFill(ctx)

    local panelW = 360
    local panelH = 300
    local px = (s.DW - panelW) / 2
    local py = s.DH * 0.32
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, px, py, panelW, panelH, 8)
    nvgFillColor(ctx, nvgRGBA(35, 25, 40, 245))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, px + 0.5, py + 0.5, panelW - 1, panelH - 1, 8)
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
-- 主渲染入口
----------------------------------------------------------------------

function Renderer.Render(ctx, s)
    if #stars == 0 then
        InitStars(s.DW, s.DH, 70)
    end

    nvgSave(ctx)

    if s.screenShake > 0 then
        local amp = s.screenShake * 12
        nvgTranslate(ctx,
            (math.random() - 0.5) * amp,
            (math.random() - 0.5) * amp)
    end

    DrawBackground(ctx, s.DW, s.DH, s.elapsed)
    DrawDangerLine(ctx, s.DW, s.DANGER_Y, s.elapsed)

    -- 敌人
    for _, e in ipairs(s.veggies) do
        DrawEnemy(ctx, e, s.BRICK_SIZE)
    end

    -- 弹弓橡皮筋（在弹珠后面）
    if s.currentMarble then
        local mx, my = s.currentMarble.x, s.currentMarble.y
        DrawSlingBands(ctx, s.slingX, s.slingY, mx, my, s.aiming)
    else
        DrawSlingBands(ctx, s.slingX, s.slingY, s.slingX, s.slingY, false)
    end

    -- 弹弓本体
    DrawSlingshot(ctx, s.slingX, s.slingY)

    -- 弹弓上的弹珠
    if s.currentMarble then
        DrawMarble(ctx, s.currentMarble)
    end

    -- 飞行弹珠
    for _, m in ipairs(s.marbles) do
        DrawMarble(ctx, m)
    end

    -- 瞄准轨迹
    if s.aiming and s.currentMarble then
        DrawAimTrajectory(ctx, s.slingX, s.slingY,
            s.currentMarble.x, s.currentMarble.y,
            s.maxPull, 200, 820, 520)
    end

    -- 粒子
    DrawParticles(ctx, s.particles)

    -- 飘字
    DrawFloatTexts(ctx, s.floatTexts)

    nvgRestore(ctx)

    -- HUD
    DrawHUD(ctx, s)

    if s.state == "menu" then
        DrawMenu(ctx, s)
    elseif s.state == "gameover" then
        DrawGameOver(ctx, s)
    end
end

return Renderer
