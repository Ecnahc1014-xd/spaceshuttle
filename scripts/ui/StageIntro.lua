-- ui/StageIntro.lua
-- 杩涘叧杩囨浮 / 鍑嗗鍔ㄧ敾锛坴0.13.24锛夈€傜敤鎴疯姹傘€岃繘鍏ュ叧鍗＄殑杩囨浮鍜屽噯澶囧姩鐢汇€嶃€?
--
-- 瑙﹀彂锛欸ame 杩涘叆鍏冲崱鏃剁疆 `introTimer = INTRO_SECONDS`锛堥粯璁?3s锛夛紝鏈熼棿鐜╂硶鍐荤粨
-- 锛堝脊鐝?鏁屾満/娉㈡閮戒笉鎺ㄨ繘锛夛紝鏈ā鍧楄礋璐ｇ敾杩欐杩囨浮鐣岄潰锛?
--   鈶?鍏ㄥ睆鏆楀寲閬僵锛堟垬鍦哄湪鑳屽悗淇濈暀锛屽彧鏄帇鏆楋級锛?
--   鈶?涓ぎ澶у彿**鍍忕礌鏁板瓧璐村浘**鍏冲崱鍙凤紙DigitFont锛?銆屽叧鍗″噯澶囥€嶆爣棰橈紱
--   鈶?鐜舰/鏉″舰鍊掕鏃?+ 鏁板瓧璺崇锛?
--   鈶?涓€閬撴í鍚戞壂鎻忓厜甯?+ 杈规瑙掓爣锛坉ark-tech 鍏嬪埗瑁呴グ锛夈€?
--
-- 鈿狅笍 绾粯鍒舵ā鍧楋細鍙 game 蹇収锛坕ntroTimer/introTotal/stage锛夛紝涓嶅啓瑙勫垯灞傘€?
-- 鈿狅笍 涓?Scene3DBackend 鍒嗙锛岄伩鍏嶅悗鑰呮ā鍧楃骇 local 閫艰繎 200 涓婇檺锛坴0.13.18 鏁欒锛夈€?

local DigitFont = require "ui.DigitFont"

local StageIntro = {}

-- 鍐呯疆 dark-tech 浠ょ墝锛堜笌 Scene3DBackend.C 鍚屽€硷紱鏈ā鍧椾笉鍙嶅悜渚濊禆鍚庣锛夈€?
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

-- 澶у彿鍏冲崱鍙凤細浼樺厛鍍忕礌璐村浘锛圖igitFont锛夛紝缂哄浘鍥為€€ zpix 瀛椾綋銆?
local function DrawStageNumber(ctx, stage, cx, topY, h, color)
    if DigitFont.DrawNumber(ctx, stage, cx, topY, h, color) then return end
    nvgFontSize(ctx, h)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(ctx, rgba(color))
    nvgText(ctx, cx, topY, tostring(stage), nil)
end

---@param ctx any
---@param game table 蹇収锛堥渶 introTimer/introTotal/stage/width/height锛?
function StageIntro.Draw(ctx, game)
    local t = game.introTimer or 0
    if t <= 0 then return end
    -- 鏂囧瓧鐢ㄩ」鐩儚绱犲瓧浣擄紙涓?Scene3DBackend 鍚屽悕娉ㄥ唽锛涚己瀛椾綋鏃跺紩鎿庡洖閫€ sans锛夈€?
    nvgFontFace(ctx, "zpix")
    local total = game.introTotal or 3.0
    local w, h = game.width or 540, game.height or 960
    local cx = w * 0.5
    local p = 1 - math.min(1, t / total)   -- 0鈫? 杩涘害
    local remain = math.max(0, math.ceil(t))
    local tips = require "ui.GameplayTips"

    -- 鈶?鏆楀寲閬僵锛堟笎鍏ワ細寮€鍦?0.25s 鍐呭埌 0.82锛屾敹灏?0.35s 娣″嚭锛?
    local a = 1
    if t < 0.45 then a = math.max(0, t / 0.45) end
    FillRect(ctx, 0, 0, w, h, { 4, 8, 16, math.floor(210 * a) })

    -- 鈶?涓ぎ闈㈡澘锛氬叆鍦轰粠 0.92 寮规€ф斁澶?
    local pop = 1 + 0.08 * math.max(0, 1 - p / 0.18)
    local pw, ph = 360, 320
    local px, py = cx - pw * 0.5, h * 0.5 - ph * 0.5 - 40
    nvgSave(ctx)
    nvgTranslate(ctx, cx, py + ph * 0.5)
    nvgScale(ctx, pop, pop)
    nvgTranslate(ctx, -cx, -(py + ph * 0.5))

    FillRect(ctx, px, py, pw, ph, { 10, 16, 28, math.floor(232 * a) }, 8)
    StrokeRect(ctx, px, py, pw, ph, { C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], math.floor(200 * a) }, 8, 1.4)
    -- 鍥涜鎶樿
    local cl, cc = 18, { C.cyan[1], C.cyan[2], C.cyan[3], math.floor(220 * a) }
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, px, py + cl); nvgLineTo(ctx, px, py); nvgLineTo(ctx, px + cl, py)
    nvgMoveTo(ctx, px + pw - cl, py); nvgLineTo(ctx, px + pw, py); nvgLineTo(ctx, px + pw, py + cl)
    nvgMoveTo(ctx, px, py + ph - cl); nvgLineTo(ctx, px, py + ph); nvgLineTo(ctx, px + cl, py + ph)
    nvgMoveTo(ctx, px + pw - cl, py + ph); nvgLineTo(ctx, px + pw, py + ph); nvgLineTo(ctx, px + pw, py + ph - cl)
    nvgStrokeColor(ctx, rgba(cc)); nvgStrokeWidth(ctx, 1.6); nvgStroke(ctx)

    -- 鏍囬銆屽叧鍗″噯澶囥€?
    nvgFontSize(ctx, 18)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(ctx, rgba({ C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], math.floor(230 * a) }))
    nvgText(ctx, cx, py + 26, "鍏冲崱鍑嗗", nil)

    -- 鈶?澶у彿鍏冲崱鍙凤紙鍍忕礌璐村浘锛?
    local numColor = { C.text[1], C.text[2], C.text[3], math.floor(255 * a) }
    DrawStageNumber(ctx, game.stage or 1, cx, py + 78, 96, numColor)

    -- 鍦ㄥぇ鍙峰叧鍗″彿涓庡€掕鏃朵箣闂翠繚鐣欎竴鏉″彲璇荤殑浣滄垬鎻愮ず銆?
    local tipBoxX, tipBoxY, tipBoxW, tipBoxH = px + 26, py + 180, pw - 52, 32
    FillRect(ctx, tipBoxX, tipBoxY, tipBoxW, tipBoxH, { 14, 28, 42, math.floor(220 * a) }, 4)
    StrokeRect(ctx, tipBoxX, tipBoxY, tipBoxW, tipBoxH,
        { C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], math.floor(150 * a) }, 4, 1)
    nvgFontSize(ctx, 12)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(ctx, rgba({ C.text[1], C.text[2], C.text[3], math.floor(235 * a) }))
    nvgText(ctx, cx, tipBoxY + 9, tips.Get((game.stage or 1) + 1), nil)

    -- 鈶?鍊掕鏃舵潯 + 璺崇鏁板瓧
    local barW, barH = pw - 80, 10
    local bx, by = cx - barW * 0.5, py + 224
    FillRect(ctx, bx, by, barW, barH, { 4, 8, 16, math.floor(255 * a) }, 5)
    FillRect(ctx, bx, by, barW * p, barH, { C.cyan[1], C.cyan[2], C.cyan[3], math.floor(255 * a) }, 5)
    -- 璺崇锛氭瘡绉掍竴涓嬬殑鑴夊啿缂╂斁
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
    nvgText(ctx, cx, py + 292, "绉掑悗寮€鎴?, nil)

    nvgRestore(ctx)

    -- 鈶?妯悜鎵弿鍏夊甫锛堣嚜涓婅€屼笅鎵繃鏁村睆锛屽厠鍒讹級
    local scanY = (p * 1.15 - 0.05) * h
    FillRect(ctx, 0, scanY, w, 2, { C.cyan[1], C.cyan[2], C.cyan[3], math.floor(60 * a) })
    FillRect(ctx, 0, scanY - 8, w, 1, { C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], math.floor(28 * a) })
end

return StageIntro
