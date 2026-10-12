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

-- v0.13.60：失败（gameover）过渡——「防线崩溃」动态漫，用户要求「三到五秒、复杂一点」。
-- 与胜利的 2.15s 分开，给足 4.0s 让各段落依次展开（冲击闪 → 裂纹 → 碎片 → 断裂 → 战报）。
StageTransition.DEFEAT_DURATION = 4.0
local DEFEAT_DIGIT_END = 2.35   -- 分数滚动结束时刻

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

-- v0.13.60：本模块现在服务**两态**——胜利（stagewin，读 stageResult.animAt）与
-- 失败（gameover，读 defeatAt）。下面两个 helper 统一给出「本态过渡起点与时长」，
-- 让可见性/绘制/跳过共用同一套计时。
---@param game table|nil
---@return number|nil startAt 过渡起点（elapsed 基准）；无过渡数据时 nil
---@return number dur 该态的过渡时长
local function TransitionInfo(game)
    if not game then return nil, 0 end
    if game.state == "gameover" then
        if not game.defeatAt then return nil, 0 end
        return game.defeatAt, StageTransition.DEFEAT_DURATION
    end
    local r = game.stageResult
    if not r or not r.animAt then return nil, 0 end
    return r.animAt, StageTransition.DURATION
end

---结算窗口是否应显示（过渡结束后为 true；无过渡数据时兜底为 true）。
---@param game table|nil
---@return boolean
function StageTransition.WindowVisible(game)
    local startAt, dur = TransitionInfo(game)
    if not startAt then return true end
    if seenAnimAt_ ~= startAt then
        seenAnimAt_ = startAt
        skip_ = false
    end
    if skip_ then return true end
    return ((game.elapsed or 0) - startAt) >= dur
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

---当前过渡进度（秒）。非过渡期为 nil。供绘制与探针共用。
---@param game table|nil
---@return number|nil t
function StageTransition.Elapsed(game)
    local startAt, dur = TransitionInfo(game)
    if not startAt then return nil end
    local t = (game.elapsed or 0) - startAt
    if t < 0 then t = 0 end
    if t > dur then return nil end
    return t
end

-- ---- 主绘制 -----------------------------------------------------------------
---@param ctx any
---@param game table 快照（需 stageResult/stage/elapsed/width/height）
function StageTransition.Draw(ctx, game)
    if game.state == "gameover" then
        StageTransition.DrawDefeat(ctx, game)
        return
    end
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

-- ============================================================================
-- v0.13.60：失败过渡「防线崩溃」动态漫（4.0s，用户要求「三到五秒、复杂一点」）。
-- 与胜利的青/金区分：整体走**红/暗红/铁灰**色调，节奏更快更「重」。
-- 段落（按 t 秒）：
--   0.00-0.22 白色冲击闪 + 强震屏（防线被击穿的一瞬）
--   0.10-1.30 红色裂纹从中心向四周蔓裂（确定性折线）
--   0.30-1.90 砖块碎片自下飞散（物理感，带自转）
--   0.50-2.10 防线断裂：横向裂痕 + 红色警戒光带扫过
--   1.00-2.60 「防线失守」大字冲击入（缩放 + 双描边）
--   1.60-2.80 分数滚动（战报数字）
--   2.20-3.40 统计逐条淡入（到达关卡 / 击碎 / 强化 / 存活）
--   2.80-3.90 底部红色警戒扫描 + 提示
-- 全部用确定性伪随机（不依赖 math.random，重开/暂停不抖动）。
-- ============================================================================

-- 红色系令牌（失败语义）。
local DEFEAT_RED = { 236, 62, 58 }
local DEFEAT_DEEP = { 120, 22, 26 }
local DEFEAT_IRON = { 96, 104, 118 }

-- 确定性伪随机：返回 0..1，输入相同时恒定（避免每帧抖动）。
local function hash01(n)
    local v = math.sin(n * 12.9898 + 78.233) * 43758.5453
    return v - math.floor(v)
end

-- 从中心向外的折线裂纹：一条由若干段组成的抖动折线。
local function Crack(ctx, cx, cy, ang, len, jitter, segs, col, width)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, cx, cy)
    local x, y = cx, cy
    for i = 1, segs do
        local f = i / segs
        local j = (hash01(ang * 7.1 + i * 3.7) - 0.5) * jitter * f
        local a = ang + j * 0.02
        local r = len * f
        x = cx + math.cos(a) * r + j
        y = cy + math.sin(a) * r + j * 0.6
        nvgLineTo(ctx, x, y)
    end
    nvgStrokeColor(ctx, rgba(col))
    nvgStrokeWidth(ctx, width)
    nvgStroke(ctx)
end

---失败过渡绘制。t = elapsed - defeatAt，时长 DEFEAT_DURATION。
---@param ctx any
---@param game table
function StageTransition.DrawDefeat(ctx, game)
    local startAt = game.defeatAt
    if not startAt then return end
    local t = (game.elapsed or 0) - startAt
    if t < 0 then t = 0 end
    local DUR = StageTransition.DEFEAT_DURATION
    if t > DUR then return end

    local w = game.width or 540
    local h = game.height or 960
    local cx = w * 0.5
    local cy = h * 0.5 - 40
    nvgFontFace(ctx, "zpix")

    -- ① 暗化遮罩（红调）：0.12s 渐入，收尾 0.30s 淡出（衔接结算窗）。
    local bd = seg(t, 0, 0.12) * (1 - seg(t, DUR - 0.30, DUR))
    FillRect(ctx, 0, 0, w, h, { 8, 4, 8, math.floor(232 * bd) })

    -- ② 屏幕震动：0.5s 内快速衰减（失败更「重」，幅值比胜利大）。
    local shake = 8.5 * (1 - seg(t, 0, 0.5)) + 2.0 * (1 - seg(t, 1.0, 1.9))
    local shakeOn = shake > 0.2
    if shakeOn then
        nvgSave(ctx)
        nvgTranslate(ctx, math.sin(t * 132) * shake, math.cos(t * 97) * shake * 0.7)
    end

    -- ③ 白色冲击闪：极短（0.10s），只在击穿瞬间。
    local flash = 1 - seg(t, 0.0, 0.10)
    if flash > 0 then
        FillRect(ctx, 0, 0, w, h, { 255, 236, 236, math.floor(210 * flash) })
    end

    -- ④ 红色裂纹：从中心向四周蔓裂（10 条，确定性角度/长度）。
    local cp = seg(t, 0.10, 1.30)
    if cp > 0 and cp < 1 then
        local grow = easeOut(cp)
        local alpha = math.floor(230 * math.min(1, cp * 2) * (1 - seg(t, 1.05, 1.30)))
        for i = 1, 10 do
            local ang = (i - 1) * (math.pi * 2 / 10) + hash01(i) * 0.5
            local len = (150 + hash01(i * 2.3) * 130) * grow
            Crack(ctx, cx, cy, ang, len, 14, 7, { DEFEAT_RED[1], DEFEAT_RED[2], DEFEAT_RED[3], alpha }, 2.4)
        end
        -- 裂纹交汇处的白热核
        if cp < 0.6 then
            local kr = 26 * (1 - cp / 0.6)
            nvgBeginPath(ctx)
            nvgCircle(ctx, cx, cy, kr)
            nvgFillPaint(ctx, nvgRadialGradient(ctx, cx, cy, 0, kr,
                rgba({ 255, 220, 210, math.floor(200 * (1 - cp / 0.6)) }),
                rgba({ 255, 120, 90, 0 })))
            nvgFill(ctx)
        end
    end

    -- ⑤ 砖块碎片自下飞散（16 片，确定性初速/自转，带重力回落）。
    local fp = seg(t, 0.30, 1.90)
    if fp > 0 and fp < 1 then
        for i = 1, 16 do
            local a = hash01(i * 1.7) * math.pi * 2
            local spd = 90 + hash01(i * 3.1) * 190
            local life = fp
            local dx = math.cos(a) * spd * life * (0.6 + hash01(i * 5.3) * 0.8)
            local dy = math.sin(a) * spd * life * 0.5 - 150 * life + 220 * life * life  -- 上抛后落
            local px = cx + dx
            local py = cy + 40 + dy
            local rot = hash01(i * 7.9) * math.pi * 2 + life * (hash01(i * 2.7) - 0.5) * 12
            local sz = 7 + hash01(i * 4.1) * 9
            local fade = 1 - seg(t, 1.3, 1.90)
            nvgSave(ctx)
            nvgTranslate(ctx, px, py)
            nvgRotate(ctx, rot)
            nvgBeginPath(ctx)
            nvgRect(ctx, -sz * 0.5, -sz * 0.5, sz, sz)
            local tone = (i % 3 == 0) and DEFEAT_RED or DEFEAT_IRON
            nvgFillColor(ctx, rgba({ tone[1], tone[2], tone[3], math.floor(230 * fade) }))
            nvgFill(ctx)
            nvgRestore(ctx)
        end
    end

    -- ⑥ 防线断裂：横向裂痕从中间向两侧拉开 + 红色警戒光带扫过。
    local bp = seg(t, 0.50, 2.10)
    if bp > 0 and bp < 1 then
        local grow = easeOut(bp)
        local halfW = (w * 0.5) * grow
        local gap = 6 + 10 * grow
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, cx - halfW, cy + 92)
        nvgLineTo(ctx, cx - gap, cy + 92 + math.sin(t * 20) * 2)
        nvgMoveTo(ctx, cx + gap, cy + 92 + math.sin(t * 20 + 1) * 2)
        nvgLineTo(ctx, cx + halfW, cy + 92)
        nvgStrokeColor(ctx, rgba({ DEFEAT_RED[1], DEFEAT_RED[2], DEFEAT_RED[3], math.floor(240 * grow) }))
        nvgStrokeWidth(ctx, 3)
        nvgStroke(ctx)
        -- 警戒光带：自左向右扫过
        local scanX = (-0.2 + easeOut(seg(t, 0.6, 2.0)) * 1.4) * w
        FillRect(ctx, scanX, cy + 60, 60, 66,
            { DEFEAT_RED[1], DEFEAT_RED[2], DEFEAT_RED[3], math.floor(70 * (1 - seg(t, 1.7, 2.10))) }, 0)
    end

    -- ⑦ 「防线失守」大字：冲击入（从大缩到正常 + 双描边）。
    local tp = seg(t, 1.00, 2.60)
    if tp > 0 then
        local pop = 1 + 0.55 * (1 - easeOut(tp))
        local alpha = math.floor(255 * math.min(1, tp * 2))
        nvgSave(ctx)
        nvgTranslate(ctx, cx, cy - 96)
        nvgScale(ctx, pop, pop)
        nvgTranslate(ctx, -cx, -(cy - 96))
        nvgFontSize(ctx, 58)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        -- 外描边（深红）+ 内层（亮红）
        nvgFillColor(ctx, rgba({ DEFEAT_DEEP[1], DEFEAT_DEEP[2], DEFEAT_DEEP[3], alpha }))
        for _, o in ipairs({ {-2, 0}, {2, 0}, {0, -2}, {0, 2}, {-2, -2}, {2, 2}, {-2, 2}, {2, -2} }) do
            nvgText(ctx, cx + o[1], cy - 96 + o[2], "防线失守", nil)
        end
        nvgFillColor(ctx, rgba({ DEFEAT_RED[1], DEFEAT_RED[2], DEFEAT_RED[3], alpha }))
        nvgText(ctx, cx, cy - 96, "防线失守", nil)
        nvgRestore(ctx)
    end

    -- ⑧ 分数滚动（战报数字）：0.0 → 实际分数，1.60-2.35s 完成。
    local k = easeOut(seg(t, 1.60, DEFEAT_DIGIT_END))
    local shown = math.floor((game.score or 0) * k + 0.5)
    local dp = seg(t, 1.60, 2.00)
    if dp > 0 then
        DrawNumber(ctx, shown, cx, cy - 6, 74, { 255, 226, 224, math.floor(255 * dp) })
        nvgFontSize(ctx, 19)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(ctx, rgba({ C.dim[1], C.dim[2], C.dim[3], math.floor(230 * dp) }))
        nvgText(ctx, cx, cy + 78, "分", nil)
    end

    -- ⑨ 统计逐条淡入（到达关卡 / 击碎 / 强化 / 存活）。
    local rows = {
        string.format("到达第 %d 关", game.stage or 1),
        string.format("击碎 %d 块", game.bricksBroken or 0),
        string.format("强化 %d 次", #(game.upgradePicks or {})),
        string.format("存活 %.0f 秒", game.elapsed or 0),
    }
    for i = 1, #rows do
        local rp = seg(t, 2.20 + (i - 1) * 0.14, 2.70 + (i - 1) * 0.14)
        if rp > 0 then
            nvgFontSize(ctx, 16)
            nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            nvgFillColor(ctx, rgba({ C.text[1], C.text[2], C.text[3], math.floor(215 * rp) }))
            nvgText(ctx, cx, cy + 120 + (i - 1) * 26, rows[i], nil)
        end
    end

    -- ⑩ 底部红色警戒扫描线（2.80-3.90s，克制）。
    local sp = seg(t, 2.80, 3.90)
    if sp > 0 and sp < 1 then
        local sy = (easeOut(sp) * 1.15 - 0.05) * h
        FillRect(ctx, 0, sy, w, 2, { DEFEAT_RED[1], DEFEAT_RED[2], DEFEAT_RED[3], math.floor(120 * bd) })
    end

    -- ⑪ 四角取景折线（红调，与胜利同语言）。
    local fl = seg(t, 0.0, 0.30) * (1 - seg(t, DUR - 0.28, DUR))
    if fl > 0 then
        local m, cl = 26, 34
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, m, m + cl); nvgLineTo(ctx, m, m); nvgLineTo(ctx, m + cl, m)
        nvgMoveTo(ctx, w - m - cl, m); nvgLineTo(ctx, w - m, m); nvgLineTo(ctx, w - m, m + cl)
        nvgMoveTo(ctx, m, h - m - cl); nvgLineTo(ctx, m, h - m); nvgLineTo(ctx, m + cl, h - m)
        nvgMoveTo(ctx, w - m - cl, h - m); nvgLineTo(ctx, w - m, h - m); nvgLineTo(ctx, w - m, h - m - cl)
        nvgStrokeColor(ctx, rgba({ DEFEAT_RED[1], DEFEAT_RED[2], DEFEAT_RED[3], math.floor(190 * fl) }))
        nvgStrokeWidth(ctx, 1.6)
        nvgStroke(ctx)
    end

    if shakeOn then nvgRestore(ctx) end

    -- ⑫ 尾部提示（3.40s 起）。
    local hp = seg(t, 3.40, 3.80)
    if hp > 0 then
        nvgFontSize(ctx, 13)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(ctx, rgba({ C.dim[1], C.dim[2], C.dim[3], math.floor(200 * hp) }))
        nvgText(ctx, cx, h * 0.5 + 300, "点击跳过", nil)
    end
end

return StageTransition
