-- Renderer.lua
-- 燃烧的蔬菜 - NanoVG 渲染器（纯几何块风格，天际攀登式极简视觉）

local Shapes = require "Shapes"

local Renderer = {}

local BW = Shapes.BRICK_W -- 34
local BH = Shapes.BRICK_H -- 18

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

----------------------------------------------------------------------
-- 颜色辅助
----------------------------------------------------------------------

local function rgba(c, a)
    return nvgRGBA(c[1], c[2], c[3], a or 255)
end

local function lerpColor(a, b, t)
    return {
        a[1] + (b[1] - a[1]) * t,
        a[2] + (b[2] - a[2]) * t,
        a[3] + (b[3] - a[3]) * t,
    }
end

----------------------------------------------------------------------
-- 背景
----------------------------------------------------------------------

local function DrawBackground(ctx, w, h, elapsed)
    -- 深色渐变背景
    local bg = nvgLinearGradient(ctx, 0, 0, 0, h,
        nvgRGBA(26, 16, 51, 255),
        nvgRGBA(10, 18, 38, 255))
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

    -- 顶部暖色辉光（燃烧感）
    local glow = nvgLinearGradient(ctx, 0, 0, 0, 180,
        nvgRGBA(255, 120, 40, 55),
        nvgRGBA(255, 120, 40, 0))
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, w, 180)
    nvgFillPaint(ctx, glow)
    nvgFill(ctx)
end

local function DrawDangerLine(ctx, w, y, elapsed)
    -- 虚线警戒线
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
end

----------------------------------------------------------------------
-- 砖块
----------------------------------------------------------------------

local function DrawBrick(ctx, x, y, w, h, color, darkColor, hp, maxHp, hitFlash, flicker, seed)
    -- 主体填充
    nvgBeginPath(ctx)
    nvgRect(ctx, x, y, w, h)
    nvgFillColor(ctx, rgba(color))
    nvgFill(ctx)

    -- 顶部高光（几何块立体感）
    nvgBeginPath(ctx)
    nvgRect(ctx, x + 1, y + 1, w - 2, math.max(2, h * 0.32))
    nvgFillColor(ctx, nvgRGBA(255, 255, 255, 55))
    nvgFill(ctx)

    -- 底部暗边
    nvgBeginPath(ctx)
    nvgRect(ctx, x + 1, y + h - 2, w - 2, 1)
    nvgFillColor(ctx, nvgRGBA(0, 0, 0, 70))
    nvgFill(ctx)

    -- 燃烧闪烁（叠加橙黄光）
    local flame = 0.5 + 0.5 * math.sin(seed + flicker * 5)
    if flame > 0.45 then
        local fa = (flame - 0.45) * 320
        if fa > 160 then fa = 160 end
        nvgBeginPath(ctx)
        nvgRect(ctx, x + 2, y + 1, w - 4, math.max(2, h * 0.28))
        nvgFillColor(ctx, nvgRGBA(255, 170, 50, math.floor(fa)))
        nvgFill(ctx)
    end

    -- 受损状态：暗色裂纹块
    if maxHp > 1 and hp < maxHp then
        local dmgRatio = (maxHp - hp) / maxHp
        nvgBeginPath(ctx)
        nvgRect(ctx, x + w - 7, y + h - 7, 5, 5)
        nvgFillColor(ctx, rgba(darkColor, 220))
        nvgFill(ctx)
        if dmgRatio >= 0.5 then
            nvgBeginPath(ctx)
            nvgRect(ctx, x + 2, y + 2, 3, 3)
            nvgFillColor(ctx, rgba(darkColor, 200))
            nvgFill(ctx)
        end
    end

    -- 击中闪白
    if hitFlash > 0 then
        local alpha = math.floor((hitFlash / 0.12) * 200)
        nvgBeginPath(ctx)
        nvgRect(ctx, x, y, w, h)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, alpha))
        nvgFill(ctx)
    end

    -- 描边
    nvgBeginPath(ctx)
    nvgRect(ctx, x + 0.5, y + 0.5, w - 1, h - 1)
    nvgStrokeColor(ctx, rgba(darkColor))
    nvgStrokeWidth(ctx, 2)
    nvgStroke(ctx)
end

local function DrawEnemy(ctx, enemy, elapsed)
    local def = Shapes.VEGETABLES[enemy.veggieType]
    for _, b in ipairs(enemy.bricks) do
        if b.alive then
            local bx = enemy.x + (b.col - 1) * BW
            local by = enemy.y + (b.row - 1) * BH
            DrawBrick(ctx, bx, by, BW, BH, def.color, def.darkColor,
                b.hp, b.maxHp, b.hitFlash, elapsed, b.seed)
        end
    end
end

----------------------------------------------------------------------
-- 弹珠
----------------------------------------------------------------------

local function DrawMarble(ctx, m)
    -- 拖尾
    for i, p in ipairs(m.trail) do
        local t = 1 - (i / #m.trail)
        local alpha = math.floor(70 * t)
        local radius = m.r * (0.4 + 0.6 * t)
        nvgBeginPath(ctx)
        nvgCircle(ctx, p.x, p.y, radius)
        nvgFillColor(ctx, nvgRGBA(255, 230, 140, alpha))
        nvgFill(ctx)
    end

    -- 外发光
    local glow = nvgRadialGradient(ctx, m.x, m.y, m.r * 0.5, m.r * 2.4,
        nvgRGBA(255, 220, 120, 140),
        nvgRGBA(255, 220, 120, 0))
    nvgBeginPath(ctx)
    nvgCircle(ctx, m.x, m.y, m.r * 2.4)
    nvgFillPaint(ctx, glow)
    nvgFill(ctx)

    -- 主体
    nvgBeginPath(ctx)
    nvgCircle(ctx, m.x, m.y, m.r)
    nvgFillColor(ctx, nvgRGBA(255, 250, 220, 255))
    nvgFill(ctx)

    -- 主体描边
    nvgBeginPath(ctx)
    nvgCircle(ctx, m.x, m.y, m.r)
    nvgStrokeColor(ctx, nvgRGBA(230, 170, 60, 255))
    nvgStrokeWidth(ctx, 1.5)
    nvgStroke(ctx)

    -- 高光点
    nvgBeginPath(ctx)
    nvgCircle(ctx, m.x - m.r * 0.3, m.y - m.r * 0.3, m.r * 0.32)
    nvgFillColor(ctx, nvgRGBA(255, 255, 255, 230))
    nvgFill(ctx)
end

----------------------------------------------------------------------
-- 玩家（几何块炮管）
----------------------------------------------------------------------

local function DrawPlayer(ctx, p)
    local cx = p.x
    local baseY = p.y
    local recoil = p.recoil * 2

    -- 炮管
    local barrelW = 14
    local barrelH = 22
    local barrelX = cx - barrelW / 2
    local barrelY = baseY - barrelH - recoil
    nvgBeginPath(ctx)
    nvgRect(ctx, barrelX, barrelY, barrelW, barrelH)
    nvgFillColor(ctx, nvgRGBA(80, 200, 255, 255))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRect(ctx, barrelX, barrelY, barrelW, barrelH)
    nvgStrokeColor(ctx, nvgRGBA(30, 120, 180, 255))
    nvgStrokeWidth(ctx, 2)
    nvgStroke(ctx)
    -- 炮管高光
    nvgBeginPath(ctx)
    nvgRect(ctx, barrelX + 2, barrelY + 2, 3, barrelH - 4)
    nvgFillColor(ctx, nvgRGBA(200, 240, 255, 180))
    nvgFill(ctx)
    -- 炮口
    nvgBeginPath(ctx)
    nvgRect(ctx, barrelX - 2, barrelY - 3, barrelW + 4, 4)
    nvgFillColor(ctx, nvgRGBA(255, 200, 80, 255))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRect(ctx, barrelX - 2, barrelY - 3, barrelW + 4, 4)
    nvgStrokeColor(ctx, nvgRGBA(180, 120, 30, 255))
    nvgStrokeWidth(ctx, 1.5)
    nvgStroke(ctx)

    -- 底座（梯形）
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, cx - p.width / 2, baseY + p.height)
    nvgLineTo(ctx, cx + p.width / 2, baseY + p.height)
    nvgLineTo(ctx, cx + p.width / 2 - 8, baseY)
    nvgLineTo(ctx, cx - p.width / 2 + 8, baseY)
    nvgClosePath(ctx)
    nvgFillColor(ctx, nvgRGBA(60, 160, 220, 255))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, cx - p.width / 2, baseY + p.height)
    nvgLineTo(ctx, cx + p.width / 2, baseY + p.height)
    nvgLineTo(ctx, cx + p.width / 2 - 8, baseY)
    nvgLineTo(ctx, cx - p.width / 2 + 8, baseY)
    nvgClosePath(ctx)
    nvgStrokeColor(ctx, nvgRGBA(25, 90, 150, 255))
    nvgStrokeWidth(ctx, 2)
    nvgStroke(ctx)

    -- 底座高光
    nvgBeginPath(ctx)
    nvgRect(ctx, cx - p.width / 2 + 6, baseY + 3, p.width - 20, 3)
    nvgFillColor(ctx, nvgRGBA(180, 230, 255, 160))
    nvgFill(ctx)
end

----------------------------------------------------------------------
-- 粒子 / 飘字
----------------------------------------------------------------------

local function DrawParticles(ctx, particles)
    for _, p in ipairs(particles) do
        local a = (p.life / p.maxLife)
        local alpha = math.floor(a * 255)
        local s = p.size * (0.6 + 0.4 * a)
        nvgBeginPath(ctx)
        nvgRect(ctx, p.x - s / 2, p.y - s / 2, s, s)
        nvgFillColor(ctx, nvgRGBA(p.color[1], p.color[2], p.color[3], alpha))
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

    -- 分数（左上）
    nvgFontSize(ctx, 30)
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(ctx, nvgRGBA(0, 0, 0, 180))
    nvgText(ctx, 17, 13, tostring(s.score), nil)
    nvgFillColor(ctx, nvgRGBA(255, 230, 120, 255))
    nvgText(ctx, 15, 11, tostring(s.score), nil)

    -- 最高分（小）
    nvgFontSize(ctx, 14)
    nvgFillColor(ctx, nvgRGBA(180, 190, 220, 200))
    nvgText(ctx, 17, 44, "BEST " .. tostring(s.highScore), nil)

    -- 波次（顶部中央）
    nvgFontSize(ctx, 18)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(ctx, nvgRGBA(255, 180, 100, 230))
    nvgText(ctx, s.DW / 2, 14, "WAVE " .. tostring(s.wave), nil)

    -- 生命（右上，几何心形方块）
    nvgTextAlign(ctx, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    nvgFontSize(ctx, 14)
    nvgFillColor(ctx, nvgRGBA(255, 150, 150, 220))
    nvgText(ctx, s.DW - 15, 14, "LIVES", nil)
    for i = 1, 3 do
        local hx = s.DW - 15 - (3 - i + 1) * 22
        local hy = 36
        local filled = i <= s.lives
        -- 用心形几何块（两个方块 + 一个三角太复杂，用方块代表）
        nvgBeginPath(ctx)
        if filled then
            -- 简单心形：两个圆 + 三角
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

    -- Combo
    if s.combo >= 2 then
        local ratio = s.comboTimer / s.COMBO_TIMEOUT
        local cx = s.DW / 2
        local cy = s.DH - 140
        nvgFontSize(ctx, 28)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(0, 0, 0, 180))
        nvgText(ctx, cx + 2, cy + 2, "COMBO x" .. tostring(s.combo), nil)
        nvgFillColor(ctx, nvgRGBA(255, 200, 60, 255))
        nvgText(ctx, cx, cy, "COMBO x" .. tostring(s.combo), nil)

        -- 进度条
        local barW = 120
        local barH = 5
        nvgBeginPath(ctx)
        nvgRect(ctx, cx - barW / 2, cy + 20, barW, barH)
        nvgFillColor(ctx, nvgRGBA(60, 50, 30, 200))
        nvgFill(ctx)
        nvgBeginPath(ctx)
        nvgRect(ctx, cx - barW / 2, cy + 20, barW * ratio, barH)
        nvgFillColor(ctx, nvgRGBA(255, 180, 60, 255))
        nvgFill(ctx)
    end

    -- 波次横幅
    if s.waveBannerTimer > 0 then
        local t = s.waveBannerTimer
        local alpha = t > 1.3 and (1.6 - t) / 0.3 or (t < 0.3 and t / 0.3 or 1)
        alpha = math.floor(math.max(0, math.min(1, alpha)) * 255)
        nvgFontSize(ctx, 40)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(0, 0, 0, alpha))
        nvgText(ctx, s.DW / 2 + 3, s.DH / 2 - 60 + 3, "WAVE " .. tostring(s.wave), nil)
        nvgFillColor(ctx, nvgRGBA(255, 180, 80, alpha))
        nvgText(ctx, s.DW / 2, s.DH / 2 - 60, "WAVE " .. tostring(s.wave), nil)
    end
end

----------------------------------------------------------------------
-- 菜单 / 游戏结束
----------------------------------------------------------------------

local function DrawMenu(ctx, s)
    -- 半透明遮罩
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, s.DW, s.DH)
    nvgFillColor(ctx, nvgRGBA(8, 10, 24, 200))
    nvgFill(ctx)

    nvgFontFace(ctx, "zpix")
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- 标题（燃烧色，带描边）
    nvgFontSize(ctx, 52)
    nvgFillColor(ctx, nvgRGBA(60, 10, 0, 255))
    nvgText(ctx, s.DW / 2 + 3, s.DH * 0.30 + 3, "燃烧的蔬菜", nil)
    nvgFillColor(ctx, nvgRGBA(255, 110, 40, 255))
    nvgText(ctx, s.DW / 2, s.DH * 0.30, "燃烧的蔬菜", nil)

    nvgFontSize(ctx, 26)
    nvgFillColor(ctx, nvgRGBA(255, 220, 140, 255))
    nvgText(ctx, s.DW / 2, s.DH * 0.30 + 50, "弹珠砖块大战", nil)

    -- 装饰：几个几何蔬菜砖块预览
    local demoY = s.DH * 0.45
    local veggieTypes = { "tomato", "corn", "broccoli", "onion", "carrot" }
    local totalW = #veggieTypes * 44
    local startX = (s.DW - totalW) / 2 + 22
    for i, vt in ipairs(veggieTypes) do
        local def = Shapes.VEGETABLES[vt]
        local x = startX + (i - 1) * 44 - 17
        local y = demoY
        -- 画一个2x2简化砖块
        DrawBrick(ctx, x, y, 17, 9, def.color, def.darkColor, 1, 1, 0, s.elapsed + i, i)
        DrawBrick(ctx, x + 17, y, 17, 9, def.color, def.darkColor, 1, 1, 0, s.elapsed + i + 1, i + 10)
        DrawBrick(ctx, x, y + 9, 17, 9, def.color, def.darkColor, 1, 1, 0, s.elapsed + i + 2, i + 20)
        DrawBrick(ctx, x + 17, y + 9, 17, 9, def.color, def.darkColor, 1, 1, 0, s.elapsed + i + 3, i + 30)
    end

    -- 开始提示（闪烁）
    local blink = 0.5 + 0.5 * math.sin(s.elapsed * 3)
    nvgFontSize(ctx, 22)
    nvgFillColor(ctx, nvgRGBA(255, 255, 220, 180 + 60 * blink))
    nvgText(ctx, s.DW / 2, s.DH * 0.66, "点击屏幕开始", nil)

    -- 操作说明
    nvgFontSize(ctx, 14)
    nvgFillColor(ctx, nvgRGBA(170, 180, 210, 220))
    nvgText(ctx, s.DW / 2, s.DH * 0.74, "拖动 / A D / 方向键 移动", nil)
    nvgText(ctx, s.DW / 2, s.DH * 0.74 + 22, "弹珠自动发射,击碎蔬菜!", nil)
    nvgText(ctx, s.DW / 2, s.DH * 0.74 + 44, "别让蔬菜越过红色警戒线", nil)
end

local function DrawGameOver(ctx, s)
    -- 遮罩
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, s.DW, s.DH)
    nvgFillColor(ctx, nvgRGBA(20, 5, 10, 210))
    nvgFill(ctx)

    -- 面板
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

    -- 屏幕震动
    if s.screenShake > 0 then
        local amp = s.screenShake * 12
        nvgTranslate(ctx,
            (math.random() - 0.5) * amp,
            (math.random() - 0.5) * amp)
    end

    DrawBackground(ctx, s.DW, s.DH, s.elapsed)

    -- 警戒线
    DrawDangerLine(ctx, s.DW, 855, s.elapsed)

    -- 敌人
    for _, e in ipairs(s.enemies) do
        DrawEnemy(ctx, e, s.elapsed)
    end

    -- 弹珠
    for _, m in ipairs(s.marbles) do
        DrawMarble(ctx, m)
    end

    -- 玩家
    if s.player then
        DrawPlayer(ctx, s.player)
    end

    -- 粒子
    DrawParticles(ctx, s.particles)

    -- 飘字
    DrawFloatTexts(ctx, s.floatTexts)

    nvgRestore(ctx)

    -- HUD（不受震动影响）
    DrawHUD(ctx, s)

    -- 菜单 / 结束界面
    if s.state == "menu" then
        DrawMenu(ctx, s)
    elseif s.state == "gameover" then
        DrawGameOver(ctx, s)
    end
end

return Renderer
