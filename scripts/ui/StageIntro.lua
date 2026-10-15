-- ui/StageIntro.lua
-- 进关过渡 / 准备动画（v0.13.24）。用户要求「进入关卡的过渡和准备动画」。
--
-- 触发：Game 进入关卡时置 `introTimer = INTRO_SECONDS`（默认 3s），期间玩法冻结
-- （弹珠/敌机/波次都不推进），本模块负责画这段过渡界面：
--   ① 全屏暗化遮罩（战场在背后保留，只是压暗）；
--   ② 中央大号**像素数字贴图**关卡号（DigitFont）+「关卡准备」标题；
--   ③ 环形/条形倒计时 + 数字跳秒；
--   ④ 一道横向扫描光带 + 边框角标（dark-tech 克制装饰）。
--
-- ⚠️ 纯绘制模块：只读 game 快照（introTimer/introTotal/stage），不写规则层。
-- ⚠️ 与 Scene3DBackend 分离，避免后者模块级 local 逼近 200 上限（v0.13.18 教训）。

local DigitFont = require "ui.DigitFont"

local StageIntro = {}

-- 内置 dark-tech 令牌（与 Scene3DBackend.C 同值；本模块不反向依赖后端）。
local C = {
    cyan    = {0, 229, 208, 255},
    cyanDim = {0, 150, 148, 220},
    text    = {240, 248, 252, 255},
    dim     = {120, 148, 162, 255},
    warn    = {255, 196, 72, 255},
}

local function rgba(c, a)
    return nvgRGBA(c[1], c[2], c[3], a or c[4] or 255)
end

local function FillRect(ctx, x, y, w, h, c, r)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x, y, w, h, r or 0)
    nvgFillColor(ctx, rgba(c))
    nvgFill(ctx)
end

local function StrokeRect(ctx, x, y, w, h, c, r, width)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x + 0.5, y + 0.5, w - 1, h - 1, r or 0)
    nvgStrokeColor(ctx, rgba(c))
    nvgStrokeWidth(ctx, width or 1)
    nvgStroke(ctx)
end

-- 大号关卡号：优先像素贴图（DigitFont），缺图回退 zpix 字体。
local function DrawStageNumber(ctx, stage, cx, topY, h, color)
    if DigitFont.DrawNumber(ctx, stage, cx, topY, h, color) then return end
    nvgFontSize(ctx, h)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(ctx, rgba(color))
    nvgText(ctx, cx, topY, tostring(stage), nil)
end

---@param ctx any
---@param game table 快照（需 introTimer/introTotal/stage/width/height）
function StageIntro.Draw(ctx, game)
    local t = game.introTimer or 0
    if t <= 0 then return end
    -- 文字用项目像素字体（与 Scene3DBackend 同名注册；缺字体时引擎回退 sans）。
    nvgFontFace(ctx, "zpix")
    local total = game.introTotal or 3.0
    local w, h = game.width or 540, game.height or 960
    local cx = w * 0.5
    local p = 1 - math.min(1, t / total)   -- 0→1 进度
    local remain = math.max(0, math.ceil(t))
    local tips = require "ui.GameplayTips"

    -- ① 暗化遮罩（渐入：开场 0.25s 内到 0.82，收尾 0.35s 淡出）
    local a = math.min(1, (1 - t / total) / 0.12)
    if t < 0.35 then a = t / 0.35 end
    FillRect(ctx, 0, 0, w, h, { 4, 8, 16, math.floor(210 * a) })

    -- ② 中央面板：入场从 0.92 弹性放大
    local pop = 1 + 0.08 * math.max(0, 1 - p / 0.18)
    local pw, ph = 360, 320
    local px, py = cx - pw * 0.5, h * 0.5 - ph * 0.5 - 40
    nvgSave(ctx)
    nvgTranslate(ctx, cx, py + ph * 0.5)
    nvgScale(ctx, pop, pop)
    nvgTranslate(ctx, -cx, -(py + ph * 0.5))

    FillRect(ctx, px, py, pw, ph, { 10, 16, 28, math.floor(232 * a) }, 8)
    StrokeRect(ctx, px, py, pw, ph, { C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], math.floor(200 * a) }, 8, 1.4)
    -- 四角折角
    local cl, cc = 18, { C.cyan[1], C.cyan[2], C.cyan[3], math.floor(220 * a) }
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, px, py + cl); nvgLineTo(ctx, px, py); nvgLineTo(ctx, px + cl, py)
    nvgMoveTo(ctx, px + pw - cl, py); nvgLineTo(ctx, px + pw, py); nvgLineTo(ctx, px + pw, py + cl)
    nvgMoveTo(ctx, px, py + ph - cl); nvgLineTo(ctx, px, py + ph); nvgLineTo(ctx, px + cl, py + ph)
    nvgMoveTo(ctx, px + pw - cl, py + ph); nvgLineTo(ctx, px + pw, py + ph); nvgLineTo(ctx, px + pw, py + ph - cl)
    nvgStrokeColor(ctx, rgba(cc)); nvgStrokeWidth(ctx, 1.6); nvgStroke(ctx)

    -- 标题「关卡准备」
    nvgFontSize(ctx, 18)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(ctx, rgba({ C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], math.floor(230 * a) }))
    nvgText(ctx, cx, py + 26, "关卡准备", nil)

    -- ③ 大号关卡号（像素贴图）
    local numColor = { C.text[1], C.text[2], C.text[3], math.floor(255 * a) }
    DrawStageNumber(ctx, game.stage or 1, cx, py + 78, 96, numColor)

    -- 在大号关卡号与倒计时之间保留一条可读的作战提示。
    local tipBoxX, tipBoxY, tipBoxW, tipBoxH = px + 26, py + 180, pw - 52, 32
    FillRect(ctx, tipBoxX, tipBoxY, tipBoxW, tipBoxH, { 14, 28, 42, math.floor(220 * a) }, 4)
    StrokeRect(ctx, tipBoxX, tipBoxY, tipBoxW, tipBoxH,
        { C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], math.floor(150 * a) }, 4, 1)
    nvgFontSize(ctx, 12)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(ctx, rgba({ C.text[1], C.text[2], C.text[3], math.floor(235 * a) }))
    nvgText(ctx, cx, tipBoxY + 9, tips.Get((game.stage or 1) + 1), nil)

    -- ④ 倒计时条 + 跳秒数字
    local barW, barH = pw - 80, 10
    local bx, by = cx - barW * 0.5, py + 224
    FillRect(ctx, bx, by, barW, barH, { 4, 8, 16, math.floor(255 * a) }, 5)
    FillRect(ctx, bx, by, barW * p, barH, { C.cyan[1], C.cyan[2], C.cyan[3], math.floor(255 * a) }, 5)
    -- 跳秒：每秒一下的脉冲缩放
    local tick = 1 + 0.35 * math.max(0, 1 - (t % 1) / 0.18)
    nvgSave(ctx)
    nvgTranslate(ctx, cx, py + 268)
    nvgScale(ctx, tick, tick)
    nvgTranslate(ctx, -cx, -(py + 268))
    DrawStageNumber(ctx, remain, cx, py + 256, 30, { C.warn[1], C.warn[2], C.warn[3], math.floor(255 * a) })
    nvgRestore(ctx)
    nvgFontSize(ctx, 13)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(ctx, rgba({ C.dim[1], C.dim[2], C.dim[3], math.floor(220 * a) }))
    nvgText(ctx, cx, py + 292, "秒后开战", nil)

    nvgRestore(ctx)

    -- ⑤ 横向扫描光带（自上而下扫过整屏，克制）
    local scanY = (p * 1.15 - 0.05) * h
    FillRect(ctx, 0, scanY, w, 2, { C.cyan[1], C.cyan[2], C.cyan[3], math.floor(60 * a) })
    FillRect(ctx, 0, scanY - 8, w, 1, { C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], math.floor(28 * a) })
end

return StageIntro
