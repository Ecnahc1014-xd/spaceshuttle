-- ui/GearDecor.lua
-- 鐣岄潰瑁呴グ锛氫簰鐩稿挰鍚堛€佸ぇ灏忎笉涓€鐨勫姩鎬佸皬榻胯疆锛圢anoVG 绾粯鍒讹級銆?
-- 鏃犺嚜鏈?ctx/瀛椾綋/鍥剧墖/鍛戒腑锛屼笉渚濊禆浠讳綍椤圭洰妯″潡锛涚敱瀹夸富鍦ㄧ晫闈㈣儗鏅粯鍒朵箣鍚庤皟鐢紝
-- 鐢诲湪灞忓箷鍥涜鐣欑櫧甯︼紝alpha 鍏嬪埗銆佷笉鎶㈡鏂囷紙瑁呴グ姣嶉锛寃ash/dim 鑹茬郴锛夈€?
--
-- 鍜悎绾﹀畾锛?
--   路 鍗槦榻胯疆涓績璺?= 涓婚娇椤跺崐寰?+ 0.82脳鍗槦榻挎牴鍗婂緞 鈫?涓婚娇鎺㈠叆鍗槦榻胯胺锛岃瑙夊挰鍚堬紱
--   路 鍗槦瑙掗€熷害 = -(涓婚娇鏁?鍗槦榻挎暟)脳涓昏閫熷害锛堝弽鍚戙€侀娇鏁版瘮閿侀€燂級锛?
--   路 鍗槦鐩镐綅 = 涓荤浉浣嵜?-n涓?n鍗? + 蟺/n鍗?鈫?鎺ヨЕ鐐瑰榻愰娇璋凤紙鍗婇娇閿欑浉锛夈€?

local M = {}

local TAU = math.pi * 2

-- 榻胯疆杞粨璺緞锛歯 涓柟褰㈤娇锛堟姌绾块€艰繎锛屽儚绱犻锛? 榻挎牴鍦嗐€俽ot 涓烘暣浣撴棆杞銆?
---@param ctx any
---@param cx number
---@param cy number
---@param R number 榻块《鍗婂緞
---@param teeth integer 榻挎暟
---@param rot number 鏃嬭浆瑙掞紙寮у害锛?
---@param toothH number 榻块珮
local function GearPath(ctx, cx, cy, R, teeth, rot, toothH)
    local rootR = R - toothH
    local step = TAU / teeth
    local valley = step * 0.5 -- 榻夸笌榻胯胺鍚勫崰鍗婁釜寮ф
    nvgBeginPath(ctx)
    for k = 0, teeth - 1 do
        local a0 = rot + k * step
        local a1 = a0 + step
        local ta0 = a0 + valley * 0.5
        local ta1 = a1 - valley * 0.5
        nvgLineTo(ctx, cx + math.cos(a0) * rootR, cy + math.sin(a0) * rootR)
        nvgLineTo(ctx, cx + math.cos(ta0) * R, cy + math.sin(ta0) * R)
        nvgLineTo(ctx, cx + math.cos(ta1) * R, cy + math.sin(ta1) * R)
        nvgLineTo(ctx, cx + math.cos(a1) * rootR, cy + math.sin(a1) * rootR)
    end
    nvgClosePath(ctx)
end

-- 鍗曢娇杞細澶栭娇杞粨 + 杞紭 + 涓績瀛?+ 涓変釜铻烘爴瀛旓紙灏忛娇杞渷鐣ヨ灪鏍撳瓟锛夈€?
---@param ctx any
---@param cx number
---@param cy number
---@param R number 榻块《鍗婂緞锛堣璁″儚绱狅級
---@param teeth integer 榻挎暟
---@param rot number 鏃嬭浆瑙掞紙寮у害锛?
---@param rgb integer[] 棰滆壊锛坮,g,b锛?
---@param alpha number 鎻忚竟涓嶉€忔槑搴?0..255
function M.DrawGear(ctx, cx, cy, R, teeth, rot, rgb, alpha)
    if R < 2 then return end
    local a = math.max(0, math.min(255, alpha or 120))
    local toothH = math.max(2.5, R * 0.244)
    local rootR = R - toothH
    nvgSave(ctx)
    nvgShapeAntiAlias(ctx, 0)
    GearPath(ctx, cx + 2, cy + 3, R + 1.5, teeth, rot, toothH + 0.5)
    nvgFillColor(ctx, nvgRGBA(2, 10, 18, math.floor(a * 0.72)))
    nvgFill(ctx)
    GearPath(ctx, cx, cy, R, teeth, rot, toothH)
    nvgFillColor(ctx, nvgRGBA(rgb[1], rgb[2], rgb[3], math.floor(a * 0.62)))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(rgb[1], rgb[2], rgb[3], math.floor(a)))
    nvgStrokeWidth(ctx, math.max(2.0, R * 0.075))
    nvgStroke(ctx)

    -- 杞紭鍐呭湀
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, rootR * 0.82)
    nvgStrokeColor(ctx, nvgRGBA(220, 250, 255, math.floor(a * 0.75)))
    nvgStrokeWidth(ctx, math.max(1.5, R * 0.055))
    nvgStroke(ctx)
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, rootR * 0.68)
    nvgStrokeColor(ctx, nvgRGBA(rgb[1], rgb[2], rgb[3], math.floor(a * 0.8)))
    nvgStrokeWidth(ctx, math.max(1.5, R * 0.06))
    nvgStroke(ctx)

    -- 铻烘爴瀛旓紙闅忚浆鍔紝鍔犲己"鍔ㄦ€?璇绘劅锛?
    if R >= 10 then
        for k = 0, math.min(5, teeth - 1) do
            local ba = rot + k * TAU / 6
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, cx + math.cos(ba) * R * 0.243, cy + math.sin(ba) * R * 0.243)
            nvgLineTo(ctx, cx + math.cos(ba) * R * 0.62, cy + math.sin(ba) * R * 0.62)
            nvgStrokeColor(ctx, nvgRGBA(rgb[1], rgb[2], rgb[3], math.floor(a * 0.72)))
            nvgStrokeWidth(ctx, math.max(2.0, R * 0.09))
            nvgStroke(ctx)
        end
        for k = 1, 6 do
            local ba = rot * 0.35 + k * TAU / 6
            nvgBeginPath(ctx)
            nvgCircle(ctx, cx + math.cos(ba) * rootR * 0.52,
                cy + math.sin(ba) * rootR * 0.52, math.max(1.5, R * 0.075))
            nvgFillColor(ctx, nvgRGBA(3, 14, 24, math.floor(a * 0.9)))
            nvgFill(ctx)
            nvgStrokeColor(ctx, nvgRGBA(220, 250, 255, math.floor(a * 0.58)))
            nvgStrokeWidth(ctx, 1.0)
            nvgStroke(ctx)
        end
    end

    -- 涓績瀛?
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, math.max(2.5, R * 0.243))
    nvgFillColor(ctx, nvgRGBA(2, 10, 18, math.floor(a * 0.95)))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(220, 250, 255, math.floor(a * 0.95)))
    nvgStrokeWidth(ctx, math.max(1.5, R * 0.07))
    nvgStroke(ctx)
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, math.max(1.2, R * 0.09))
    nvgFillColor(ctx, nvgRGBA(rgb[1], rgb[2], rgb[3], math.floor(a * 0.9)))
    nvgFill(ctx)
    nvgRestore(ctx)
end

-- 鍜悎榻胯疆绨囷細涓婚娇杞?+ 涓や釜涓嶅悓灏哄鐨勫崼鏄熼娇杞紙鍙嶅悜閿侀€熴€侀娇璋峰榻愶級銆?
---@param ctx any
---@param cx number 涓婚娇杞渾蹇?x
---@param cy number 涓婚娇杞渾蹇?y
---@param R number 涓婚娇杞娇椤跺崐寰?
---@param t number 鍔ㄧ敾鏃堕挓锛堢锛?
---@param seed integer 纭畾鎬у彉浣撶瀛愶紙鍐冲畾鍗槦鏂逛綅/榻挎暟锛?
---@param a1 number 鍗槦 1 鏂逛綅瑙掞紙寮у害锛屽睆骞曞潗鏍囷紝y 鍚戜笅锛?
---@param a2 number 鍗槦 2 鏂逛綅瑙?
---@param rgb integer[] 涓昏壊
---@param rgb2 integer[] 鍗槦鑹?
---@param alpha number 涓婚娇杞弿杈逛笉閫忔槑搴?
function M.Cluster(ctx, cx, cy, R, t, seed, a1, a2, rgb, rgb2, alpha)
    local n = 12 + (seed % 3) * 2 -- 涓婚娇鏁?12/14/16
    local n1 = 9 - (seed % 3)     -- 鍗槦 1 榻挎暟 7/8/9
    local n2 = 8 + (seed % 2) * 2 -- 鍗槦 2 榻挎暟 8/10
    local r1 = R * 0.62
    local r2 = R * 0.42
    local speed = 0.32 + (seed % 5) * 0.05
    local rot = t * speed

    local d1 = R + r1 * 0.82
    local d2 = R + r2 * 0.82
    local rot1 = -rot * n / n1 + math.pi / n1
    local rot2 = -rot * n / n2 + math.pi / n2

    M.DrawGear(ctx, cx + math.cos(a1) * d1, cy + math.sin(a1) * d1,
        r1, n1, rot1, rgb2, alpha * 0.8)
    M.DrawGear(ctx, cx + math.cos(a2) * d2, cy + math.sin(a2) * d2,
        r2, n2, rot2, rgb2, alpha * 0.66)
    M.DrawGear(ctx, cx, cy, R, n, rot, rgb, alpha)
end

-- 灞忓箷鍥涜榻胯疆瑁呴グ锛氭瘡瑙掍竴绨囷紝涓婚娇杞崐鍑虹敾闈紙"鏈烘瀯浠庤竟妗嗗悗鎺㈠嚭"锛夛紝
-- 灏哄/榻挎暟/杞€熼殢瑙掓爣纭畾鎬у彉鍖栵紱鍏ㄩ儴钀藉湪妯℃€佸３澶栫暀鐧藉甫锛屼笉鍘嬫鏂囥€?
---@param ctx any
---@param w number 璁捐瀹藉害
---@param t number 鍔ㄧ敾鏃堕挓锛堢锛?
---@param wash integer[] 涓昏壊锛堟皼鍥撮潚锛?
---@param dim integer[] 鍗槦鑹诧紙鏆楄摑鐏帮級
function M.Corners(ctx, w, t, wash, dim)
    -- 宸︿笅瑙掞紙灞忓箷鍧愭爣 y 鍚戜笅锛氬唴渚?鍙充笂鏂癸級
    M.Cluster(ctx, 0, 960, 17, t, 1, math.pi * 1.6, math.pi * 1.9, wash, dim, 60)
    -- 鍙充笅瑙掞紙鍐呬晶=宸︿笂鏂癸級
    M.Cluster(ctx, w, 960, 20, t, 2, math.pi * 1.4, math.pi * 1.1, dim, wash, 58)
    -- 宸︿笂瑙掞紙鍐呬晶=鍙充笅鏂癸級
    M.Cluster(ctx, 0, 0, 16, t, 3, math.pi * 0.1, math.pi * 0.4, dim, wash, 56)
    -- 鍙充笂瑙掞紙鍐呬晶=宸︿笅鏂癸級
    M.Cluster(ctx, w, 0, 19, t, 4, math.pi * 0.9, math.pi * 0.6, wash, dim, 62)
end

-- 涓婁笅杈圭紭涓偣榻胯疆锛堟ā鎬佸３澶栫暀鐧藉甫鐨勪腑鐐癸紝鍗槦鏈濆睆骞曞唴渚у睍寮€锛夈€?
---@param ctx any
---@param w number
---@param t number
---@param wash integer[]
---@param dim integer[]
function M.EdgePair(ctx, w, t, wash, dim)
    -- 椤堕儴涓偣锛堝唴渚?涓嬫柟锛?
    M.Cluster(ctx, w * 0.5, 0, 13, t, 8, math.pi * 0.35, math.pi * 0.65, dim, wash, 54)
    -- 搴曢儴涓偣锛堝唴渚?涓婃柟锛?
    M.Cluster(ctx, w * 0.5, 960, 14, t, 9, math.pi * 1.35, math.pi * 1.65, wash, dim, 56)
end

-- 鎴樻枟鍐呮ā鎬佺獥锛堟殏鍋?鍗囩骇/鑳滆礋锛夛細鍙敾搴曢儴涓よ鈥斺€旈《閮ㄦ槸 HUD 淇℃伅甯︿笉鍘嬮娇杞€?
---@param ctx any
---@param w number
---@param t number
---@param wash integer[]
---@param dim integer[]
function M.BattleCorners(ctx, w, t, wash, dim)
    M.Cluster(ctx, 0, 960, 17, t, 10, math.pi * 1.6, math.pi * 1.9, wash, dim, 58)
    M.Cluster(ctx, w, 960, 20, t, 11, math.pi * 1.4, math.pi * 1.1, dim, wash, 56)
end

-- 缁撶畻椤甸《閮ㄤ袱绨囷紙绐楀彛涓婃柟 92..216 鐣欑櫧甯︼紝HUD 淇℃伅甯︿箣涓嬶紱绐楀彛璧风偣 y=216锛夈€?
---@param ctx any
---@param w number
---@param t number
---@param wash integer[]
---@param dim integer[]
function M.TopBandPair(ctx, w, t, wash, dim)
    M.Cluster(ctx, 0, 140, 14, t, 14, math.pi * 0.1, math.pi * 0.4, wash, dim, 52)
    M.Cluster(ctx, w, 140, 15, t, 15, math.pi * 0.9, math.pi * 0.6, dim, wash, 50)
end

-- 鎴樻枟 HUD锛氬乏鍙冲浣撲腑娈靛悇涓€绨囷紙閿欏紑楂樺害銆佹寚鍚戝満鍐咃級锛屾瀬浣庨€忔槑搴︿笉鎶㈢劍鐐广€?
---@param ctx any
---@param w number
---@param t number
---@param wash integer[]
---@param dim integer[]
function M.HudSides(ctx, w, t, wash, dim)
    M.Cluster(ctx, 0, 330, 18, t, 16, math.pi * 0.15, math.pi * -0.15, wash, dim, 82)
    M.Cluster(ctx, w, 640, 20, t, 17, math.pi * 0.85, math.pi * 1.15, dim, wash, 78)
end

-- 棣栭〉鑿滃崟搴曢儴鍥涘垎涔嬩竴澶勪袱绨囷紙鑿滃崟鍗¤涔嬩笂銆佸睆骞曚笅缂樼暀鐧藉甫锛涗腑澶槸鐗堟湰鏂囧瓧璁╁紑锛夈€?
---@param ctx any
---@param w number
---@param t number
---@param wash integer[]
---@param dim integer[]
function M.MenuCenterBottom(ctx, w, t, wash, dim)
    M.Cluster(ctx, w * 0.25, 960, 18, t, 12, math.pi * 1.35, math.pi * 1.65, wash, dim, 112)
    M.Cluster(ctx, w * 0.75, 960, 20, t, 13, math.pi * 1.35, math.pi * 1.65, dim, wash, 108)
end

-- 棣栭〉鑿滃崟涓撶敤锛氬乏涓婅琚缃寜閽崰鎹紝鍙敾鍙﹀涓夎銆?
---@param ctx any
---@param w number
---@param t number
---@param wash integer[]
---@param dim integer[]
function M.MenuCorners(ctx, w, t, wash, dim)
    M.Cluster(ctx, 0, 960, 17, t, 5, math.pi * 1.6, math.pi * 1.9, wash, dim, 60)
    M.Cluster(ctx, w, 960, 20, t, 6, math.pi * 1.4, math.pi * 1.1, dim, wash, 58)
    M.Cluster(ctx, w, 0, 18, t, 7, math.pi * 0.9, math.pi * 0.6, wash, dim, 62)
end

return M


