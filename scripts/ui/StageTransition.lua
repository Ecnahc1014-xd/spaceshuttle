-- ui/StageTransition.lua
-- 关卡结束 → 结算窗口的过渡动画（用户需求：「需要关卡结束后有一个过渡动画进结算窗口，
-- 不同得分动画不同」）。
--
-- 设计：
--   ① 过渡与结算窗**共用同一份 `game.stageResult`**（规则层已含 stars/rating/bonusScore/
--      bonusParts/animAt），不新增快照字段、不新增 Game 顶层 local（Game.lua 已 199/200）。
--   ② 计时基准 = `game.elapsed - stageResult.animAt`。`animAt` 由 Game 在进入 stagewin 的
--      同一帧写入（`elapsed` 在非 playing 态仍持续推进，见 Game.Update 顶部）。
--   ③ 结算窗口**延迟到过渡结束**（`DURATION`）才弹出——由本模块的 `WindowVisible` 统一裁决，
--      渲染层与命中层都读它，保证「过渡期间点不到结算按钮」。
--   ④ **星级越高，动画越华丽**：放射光线数量/长度、冲击环半径、震屏幅度、粒子/火花数量、
--      数字配色全部按 stars(1..3) 分档（1★ 收敛 / 2★ 标准 / 3★ 华丽 + 金色火花）。
--
-- ⚠️ 纯绘制模块：只读快照，不写规则层。与 Scene3DBackend 分离，避免后者模块级 local
--    逼近 200 上限（AB-166 / AB-217）。依赖用 require 直接取（同 StageIntro 的做法）。

local DigitFont = require "ui.DigitFont"

local StageTransition = {}

-- 过渡总时长（秒）。结算窗口在此之前不显示、不可点。
StageTransition.DURATION = 2.15
local COUNT_UP_END = 1.25

-- 内置 dark-tech 令牌（与 Scene3DBackend.C 同值；本模块不反向依赖后端）。
local C = {
    cyan    = {0, 229, 208, 255},
    cyanDim = {0, 150, 148, 220},
    text    = {240, 248, 252, 255},
    dim     = {120, 148, 162, 255},
    warn    = {255, 196, 72, 255},
}

-- 按星级分档的动画参数：数值越高的档，光线更多更长、冲击环更大、震屏更强、配色更亮。
-- 1★ 险胜=收敛青；2★ 优良=标准青；3★ 完美=亮青 + 金色火花（金=稀有/最好的语义）。
local TIERS = {
    [1] = {
        accent = {0, 150, 148}, glow = {120, 200, 196},
        rays = 10, rayLen = 58, ringR = 116,
        shake = 2.2, sparkle = false,
    },
    [2] = {
        accent = {0, 229, 208}, glow = {150, 250, 242},
        rays = 16, rayLen = 86, ringR = 132,
        shake = 4.0, sparkle = false,
    },
    [3] = {
        accent = {120, 255, 236}, glow = {255, 226, 150},
        rays = 24, rayLen = 116, ringR = 148,
        shake = 6.0, sparkle = true,
    },
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

-- 段落归一化：t 在 [a,b] 内返回 0..1，外返回 0/1。
local function seg(t, a, b)
    if b <= a then return t >= b and 1 or 0 end
    return math.max(0, math.min(1, (t - a) / (b - a)))
end

-- 缓出（与后端 EaseOutCubic 同式，避免依赖）。
local function easeOut(t)
    t = math.max(0, math.min(1, t))
    return 1 - (1 - t) * (1 - t) * (1 - t)
end

-- 大号关卡号：优先像素贴图（DigitFont），缺图回退 zpix 字体（同 StageIntro）。
local function DrawNumber(ctx, value, cx, topY, h, color)
    if DigitFont.DrawNumber(ctx, value, cx, topY, h, color) then return end
    nvgFontSize(ctx, h)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(ctx, rgba(color))
    nvgText(ctx, cx, topY, tostring(math.floor(tonumber(value) or 0)), nil)
end

-- 五角星路径（外径 outer / 内径 inner / 起始角 rot）。
local function StarPath(ctx, cx, cy, outer, inner, rot)
    nvgBeginPath(ctx)
    for i = 0, 9 do
        local ang = rot + i * math.pi / 5
        local r = (i % 2 == 0) and outer or inner
        local px = cx + math.cos(ang) * r
        local py = cy + math.sin(ang) * r
        if i == 0 then nvgMoveTo(ctx, px, py) else nvgLineTo(ctx, px, py) end
    end
    nvgClosePath(ctx)
end

-- 单个星星：未得=暗底描边；已得=填色 + 缩放弹入（appear 0..1）。
local function DrawStar(ctx, cx, cy, size, filled, accent, appear)
    local on = filled and appear > 0
    local outer = size * (on and (1.35 - 0.35 * easeOut(appear)) or 1)
    if on then
        StarPath(ctx, cx, cy, outer, outer * 0.44, -math.pi / 2)
        nvgFillColor(ctx, rgba({ accent[1], accent[2], accent[3], math.floor(255 * math.min(1, appear * 1.4)) }))
        nvgFill(ctx)
        nvgStrokeColor(ctx, rgba({ C.text[1], C.text[2], C.text[3], math.floor(200 * appear) }))
        nvgStrokeWidth(ctx, 1.2)
        nvgStroke(ctx)
    else
        StarPath(ctx, cx, cy, outer, outer * 0.44, -math.pi / 2)
        nvgFillColor(ctx, rgba({ 22, 36, 56, 255 }))
        nvgFill(ctx)
        nvgStrokeColor(ctx, rgba({ C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 140 }))
        nvgStrokeWidth(ctx, 1.2)
        nvgStroke(ctx)
    end
end

-- ---- 过渡窗口可见性（渲染与命中同源裁决）------------------------------------
-- 模块级状态只有这两个；不放后端，避免顶到 200 local 上限。
local skip_ = false
local seenAnimAt_ = nil

---结算窗口是否应显示（过渡结束后为 true；无过渡数据时兜底为 true）。
---@param game table|nil
---@return boolean
function StageTransition.WindowVisible(game)
    local r = game and game.stageResult
    if not r or not r.animAt then return true end
    if seenAnimAt_ ~= r.animAt then
        seenAnimAt_ = r.animAt
        skip_ = false
    end
    if skip_ then return true end
    return ((game.elapsed or 0) - r.animAt) >= StageTransition.DURATION
end

---过渡是否正在进行（此期间结算按钮不可点）。
---@param game table|nil
---@return boolean
function StageTransition.IsActive(game)
    return not StageTransition.WindowVisible(game)
end

---跳过过渡（玩家点击时调用），立即显示结算窗口。
function StageTransition.Skip()
    skip_ = true
end

-- ---- 主绘制 -----------------------------------------------------------------
---@param ctx any
---@param game table 快照（需 stageResult/stage/elapsed/width/height）
function StageTransition.Draw(ctx, game)
    local r = game.stageResult
    if not r or not r.animAt then return end
    local t = (game.elapsed or 0) - r.animAt
    if t < 0 then t = 0 end
    if t > StageTransition.DURATION then return end

    local stars = math.min(3, math.max(1, math.floor(r.stars or 1)))
    local tier = TIERS[stars] or TIERS[1]
    local accent, glow = tier.accent, tier.glow
    local w = game.width or 540
    local h = game.height or 960
    local cx = w * 0.5
    local cy = h * 0.5 - 60

    nvgFontFace(ctx, "zpix")

    -- ① 暗化遮罩：0.14s 渐入，收尾 0.22s 淡出（与结算窗入场无缝衔接）。
    local bd = seg(t, 0, 0.14) * (1 - seg(t, StageTransition.DURATION - 0.22, StageTransition.DURATION))
    FillRect(ctx, 0, 0, w, h, { 4, 8, 16, math.floor(226 * bd) })

    -- ② 屏幕震动：按档位取幅值，0.5s 内衰减（仅冲击瞬间）。
    local shake = tier.shake * (1 - seg(t, 0, 0.5))
    local shakeOn = shake > 0.15
    if shakeOn then
        nvgSave(ctx)
        nvgTranslate(ctx, math.sin(t * 96) * shake, math.cos(t * 74) * shake * 0.6)
    end

    -- ③ 冲击环：两圈错开扩散，半径按档位。
    local p1 = seg(t, 0.02, 0.72)
    if p1 > 0 and p1 < 1 then
        nvgBeginPath(ctx)
        nvgCircle(ctx, cx, cy, tier.ringR * easeOut(p1))
        nvgStrokeColor(ctx, rgba({ accent[1], accent[2], accent[3], math.floor(200 * (1 - p1)) }))
        nvgStrokeWidth(ctx, 3 * (1 - p1) + 1)
        nvgStroke(ctx)
    end
    local p2 = seg(t, 0.16, 0.86)
    if p2 > 0 and p2 < 1 then
        nvgBeginPath(ctx)
        nvgCircle(ctx, cx, cy, tier.ringR * 0.62 * easeOut(p2))
        nvgStrokeColor(ctx, rgba({ glow[1], glow[2], glow[3], math.floor(150 * (1 - p2)) }))
        nvgStrokeWidth(ctx, 2 * (1 - p2) + 0.6)
        nvgStroke(ctx)
    end

    -- ④ 放射光线：数量/长度/转动按档位（3★ 最密最长）。
    local rp = seg(t, 0.0, 0.55)
    if rp > 0 then
        local rayIn = easeOut(rp)
        local rot = t * 0.35
        nvgStrokeColor(ctx, rgba({ accent[1], accent[2], accent[3], math.floor(180 * (1 - seg(t, 0.5, 1.0))) }))
        nvgStrokeWidth(ctx, 2)
        nvgBeginPath(ctx)
        for i = 0, tier.rays - 1 do
            local ang = rot + i * (math.pi * 2 / tier.rays)
            local r0 = tier.ringR * 0.72
            local r1 = r0 + tier.rayLen * rayIn
            nvgMoveTo(ctx, cx + math.cos(ang) * r0, cy + math.sin(ang) * r0)
            nvgLineTo(ctx, cx + math.cos(ang) * r1, cy + math.sin(ang) * r1)
        end
        nvgStroke(ctx)
    end

    -- ⑤ 中心辉光（径向渐变，档位越亮）。
    local gp = seg(t, 0.0, 0.35) * (1 - seg(t, 0.9, StageTransition.DURATION))
    if gp > 0 then
        local rad = 90 + 130 * easeOut(seg(t, 0.0, 0.9))
        nvgBeginPath(ctx)
        nvgCircle(ctx, cx, cy, rad)
        nvgFillPaint(ctx, nvgRadialGradient(ctx, cx, cy, 0, rad,
            rgba({ glow[1], glow[2], glow[3], math.floor(70 * gp) }),
            rgba({ glow[1], glow[2], glow[3], 0 })))
        nvgFill(ctx)
    end

    -- ⑥ 3★ 专属金色火花：确定性伪随机分布（不依赖 math.random，避免每帧抖动）。
    if tier.sparkle then
        local sp = seg(t, 0.1, 0.9)
        if sp > 0 and sp < 1 then
            for i = 1, 18 do
                local a = i * 2.399963          -- 黄金角，确定性散布
                local rr = 60 + (i * 37) % 150
                local px = cx + math.cos(a) * rr
                local py = cy + math.sin(a) * rr * 0.8
                local tw = 0.5 + 0.5 * math.sin(t * 9 + i)
                local sz = (1.4 + (i % 3)) * (0.6 + 0.4 * tw) * (1 - sp)
                FillRect(ctx, px - sz * 0.5, py - sz * 0.5, sz, sz,
                    { 255, 226, 150, math.floor(220 * tw * (1 - sp)) }, 0)
            end
        end
    end

    -- ⑦ 顶部小字「第 N 关告捷」
    local tp = seg(t, 0.05, 0.4)
    if tp > 0 then
        nvgFontSize(ctx, 20)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(ctx, rgba({ C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], math.floor(235 * tp) }))
        nvgText(ctx, cx, cy - 150, string.format("第 %d 关告捷", r.stage or game.stage or 1), nil)
    end

    -- ⑧ 奖励分数滚动：+N 分（缓出计数，2★/3★ 更亮）。
    local k = easeOut(seg(t, 0.12, COUNT_UP_END))
    local shown = math.floor((r.bonusScore or 0) * k + 0.5)
    local pop = 1 + 0.16 * math.max(0, 1 - seg(t, 0.12, 0.34))
    nvgSave(ctx)
    nvgTranslate(ctx, cx, cy)
    nvgScale(ctx, pop, pop)
    nvgTranslate(ctx, -cx, -cy)
    DrawNumber(ctx, shown, cx, cy - 46, 76, { accent[1], accent[2], accent[3], 255 })
    nvgFontSize(ctx, 20)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(ctx, rgba({ C.text[1], C.text[2], C.text[3], 230 }))
    nvgText(ctx, cx, cy + 40, "分", nil)
    nvgRestore(ctx)

    -- ⑨ 星级：逐颗弹入（0.82s 起，每颗 +0.13s），未得的随后补位。
    local starCell, starGap = 46, 22
    local totalW = 3 * starCell + 2 * starGap
    local sx0 = cx - totalW * 0.5
    for i = 1, 3 do
        local scx = sx0 + (i - 1) * (starCell + starGap) + starCell * 0.5
        local appear = seg(t, 0.80 + (i - 1) * 0.13, 1.02 + (i - 1) * 0.13)
        DrawStar(ctx, scx, cy + 108, 22, i <= stars, accent, appear)
    end

    -- ⑩ 评级字：星级弹完后淡入放大。
    local lp = seg(t, 1.02, 1.42)
    if lp > 0 then
        local lpPop = 1 + 0.12 * (1 - easeOut(lp))
        nvgSave(ctx)
        nvgTranslate(ctx, cx, cy + 158)
        nvgScale(ctx, lpPop, lpPop)
        nvgTranslate(ctx, -cx, -(cy + 158))
        nvgFontSize(ctx, 34)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(ctx, rgba({ accent[1], accent[2], accent[3], math.floor(255 * lp) }))
        nvgText(ctx, cx, cy + 158, r.rating or "", nil)
        nvgRestore(ctx)
    end

    -- ⑪ 零件奖励（较晚淡入，避免与分数抢焦点）。
    local pp = seg(t, 1.30, 1.70)
    if pp > 0 then
        nvgFontSize(ctx, 16)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(ctx, rgba({ C.warn[1], C.warn[2], C.warn[3], math.floor(235 * pp) }))
        nvgText(ctx, cx, cy + 208, string.format("零件 +%d", math.floor(r.bonusParts or 0)), nil)
    end

    -- ⑫ 横向扫描光带（自上而下，克制）。
    local scanY = (easeOut(seg(t, 0.0, 0.85)) * 1.1 - 0.05) * h
    FillRect(ctx, 0, scanY, w, 2, { accent[1], accent[2], accent[3], math.floor(70 * bd) })
    FillRect(ctx, 0, scanY - 8, w, 1, { glow[1], glow[2], glow[3], math.floor(30 * bd) })

    if shakeOn then nvgRestore(ctx) end

    -- ⑬ 四角取景折线（dark-tech 边框，与 StageIntro 同语言）。
    local fl = seg(t, 0.0, 0.3) * (1 - seg(t, StageTransition.DURATION - 0.2, StageTransition.DURATION))
    if fl > 0 then
        local m, cl = 26, 34
        local cc = { accent[1], accent[2], accent[3], math.floor(210 * fl) }
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, m, m + cl); nvgLineTo(ctx, m, m); nvgLineTo(ctx, m + cl, m)
        nvgMoveTo(ctx, w - m - cl, m); nvgLineTo(ctx, w - m, m); nvgLineTo(ctx, w - m, m + cl)
        nvgMoveTo(ctx, m, h - m - cl); nvgLineTo(ctx, m, h - m); nvgLineTo(ctx, m + cl, h - m)
        nvgMoveTo(ctx, w - m - cl, h - m); nvgLineTo(ctx, w - m, h - m); nvgLineTo(ctx, w - m, h - m - cl)
        nvgStrokeColor(ctx, rgba(cc))
        nvgStrokeWidth(ctx, 1.6)
        nvgStroke(ctx)
    end

    -- ⑭ 底部提示（过渡尾段）：告知即将进入结算。
    local hp = seg(t, 1.55, 1.9)
    if hp > 0 then
        nvgFontSize(ctx, 13)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(ctx, rgba({ C.dim[1], C.dim[2], C.dim[3], math.floor(200 * hp) }))
        nvgText(ctx, cx, h * 0.5 + 300, "点击跳过", nil)
    end
end

return StageTransition
