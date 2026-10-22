-- ui/AdConfirm.lua
-- 「看广告」二次确认弹窗（v0.13.72）：**任何广告发起前都必须先过这一屏**。
-- 玩家第一下点击只打开本确认屏，看到奖励说明后再点「看广告」才真正拉起 SDK；
-- 关掉广告/取消都不扣任何次数，避免误触直接把玩家送进广告。
--
-- ⚠️ 纯绘制 + 命中模块，不依赖 MetaUI 控件树（战斗中/结算态都要能用）。
-- 状态由编排层持有（client_main 的 adConfirmPending），绘制由后端 overlay 末段调用。
local AdConfirm = {}

-- 与 StageIntro / Scene3DBackend 同值的 dark-tech 令牌（本模块不反向依赖后端）。
local C = {
    ink      = {5, 5, 7, 255},
    panel    = {14, 15, 19, 255},
    card     = {30, 31, 37, 255},
    rail     = {18, 19, 24, 255},
    cyan     = {226, 228, 232, 255},
    cyanDim  = {150, 152, 158, 220},
    text     = {242, 239, 234, 255},
    dim      = {148, 147, 145, 255},
    warn     = {243, 167, 62, 255},
    warnDim  = {158, 108, 42, 220},
    ad       = {46, 232, 107, 255},
}

---@param c table
---@param a integer|nil
local function rgba(c, a)
    return nvgRGBA(c[1], c[2], c[3], a or c[4] or 255)
end

-- ============================================================================
-- 布局（绘制与命中共用，禁止第二套常量）
-- ============================================================================

local CARD_W, CARD_H = 452, 268
local BTN_W, BTN_H, BTN_GAP = 196, 56, 16

---@param w number
---@return table card
---@return table yes
---@return table no
function AdConfirm.Layout(w)
    local card = { x = (w - CARD_W) * 0.5, y = 336, w = CARD_W, h = CARD_H }
    local bx = card.x + (CARD_W - BTN_W * 2 - BTN_GAP) * 0.5
    local by = card.y + CARD_H - BTN_H - 26
    return card,
        { x = bx, y = by, w = BTN_W, h = BTN_H },
        { x = bx + BTN_W + BTN_GAP, y = by, w = BTN_W, h = BTN_H }
end

---@param r table
---@param px number
---@param py number
---@return boolean
local function Inside(r, px, py)
    return px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
end

---@param uiX number
---@param uiY number
---@param w number
---@return string|nil "ad_confirm_yes" | "ad_confirm_no"
function AdConfirm.HitTest(uiX, uiY, w)
    local _, yes, no = AdConfirm.Layout(w)
    if Inside(no, uiX, uiY) then return "ad_confirm_no" end
    if Inside(yes, uiX, uiY) then return "ad_confirm_yes" end
    -- 点窗外等同取消（不进广告），但不穿透到下面的按钮。
    local card = AdConfirm.Layout(w)
    if not Inside(card, uiX, uiY) then return "ad_confirm_no" end
    return nil
end

-- ============================================================================
-- 绘制
-- ============================================================================

---@param ctx any
---@param x number
---@param y number
---@param w number
---@param h number
---@param fill table
---@param stroke table|nil
---@param r number
local function Panel(ctx, x, y, w, h, fill, stroke, r)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x, y, w, h, r or 8)
    nvgFillColor(ctx, rgba(fill))
    nvgFill(ctx)
    if stroke then
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, x + 0.5, y + 0.5, w - 1, h - 1, r or 8)
        nvgStrokeColor(ctx, rgba(stroke))
        nvgStrokeWidth(ctx, 1.4)
        nvgStroke(ctx)
    end
end

---@param ctx any
---@param x number
---@param y number
---@param text string
---@param size number
---@param color table
---@param align integer
local function Text(ctx, x, y, text, size, color, align)
    nvgFontSize(ctx, size)
    nvgTextAlign(ctx, align or (NVG_ALIGN_LEFT + NVG_ALIGN_TOP))
    nvgFillColor(ctx, rgba(color))
    nvgText(ctx, x, y, tostring(text))
end

--- 供后端 overlay 末段调用：state = { title, reward, hint }
---@param ctx any
---@param w number
---@param state table
function AdConfirm.Draw(ctx, w, state)
    if not state then return end
    local card, yes, no = AdConfirm.Layout(w)
    -- 全屏压暗（吃掉点击，防止误触到底下的补给/结算按钮）。
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, w, 960)
    nvgFillColor(ctx, nvgRGBA(0, 0, 0, 150))
    nvgFill(ctx)

    Panel(ctx, card.x, card.y, card.w, card.h, C.panel, C.warnDim, 12)
    Panel(ctx, card.x + 1, card.y + 1, card.w - 2, 44, C.rail, nil, 12)
    Text(ctx, card.x + 18, card.y + 12, "观看广告", 18, C.warn)
    Text(ctx, card.x + card.w - 18, card.y + 14, "不消耗任何次数", 13, C.dim,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)

    Text(ctx, card.x + 24, card.y + 66, state.title or "确认观看一段广告？", 20, C.text)
    Text(ctx, card.x + 24, card.y + 100, state.reward or "", 15, C.cyanDim)
    Text(ctx, card.x + 24, card.y + 132, state.hint or "完整观看才会发放奖励；中途关闭不会扣除次数。",
        12, C.dim)
    -- 分隔线
    nvgBeginPath(ctx)
    nvgRect(ctx, card.x + 24, card.y + 158, card.w - 48, 1)
    nvgFillColor(ctx, nvgRGBA(C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 90))
    nvgFill(ctx)

    -- 主按钮：看广告（绿=免费获取语义）
    Panel(ctx, yes.x, yes.y, yes.w, yes.h, C.card, C.ad, 9)
    Text(ctx, yes.x + yes.w * 0.5, yes.y + 15, "看广告", 20, C.ad,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    -- 次按钮：取消
    Panel(ctx, no.x, no.y, no.w, no.h, C.rail, C.cyanDim, 9)
    Text(ctx, no.x + no.w * 0.5, no.y + 15, "取消", 19, C.text,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
end

return AdConfirm
