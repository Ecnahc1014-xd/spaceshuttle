-- ui/StageSelect.lua
-- 閫夊叧鐣岄潰锛圢anoVG锛夈€倂0.13.14锛氭敼涓?*寮€蹇冩秷娑堜箰寮忚溈铚掕矾寰勫湴鍥?*銆?
--
-- 鐢ㄦ埛鍚﹀喅浜嗕笂涓€鐗堛€岀洿绾垮井鍋忕Щ鐨勭粏鎻忚竟鍦嗛挳銆嶏紝鍙傝€冨浘缁欑殑鏄秷娑堜箰鍏冲崱鍦板浘锛?
--   路 涓€鏉?*绮楀．鐨勮溈铚掕矾寰?*璐┛鍏ㄥ睆锛屽乏鍙虫潵鍥炴憜鍔紙鎸箙澶с€佸懆鏈熼暱锛岃倝鐪肩湅鍑?铔囧舰"锛夛紱
--   路 鍏冲崱鑺傜偣鏄?*澶у渾鏋滃喕閽?*锛氫寒鑹插鍦?+ 鍐呴儴浜姱 + 绮楁弿杈规暟瀛楋紝鍍忓彲鐐圭殑绯栨灉锛?
--   路 鑺傜偣**涓嬫柟涓夐鏄?*锛堝凡寰?瀹炲績浜槦锛屾湭寰?鏆楁槦锛夛紱
--   路 涓や晶绔栨帓**鍦嗗舰鍥炬爣鏍?*锛堝乏渚ч亾鍏疯喘涔般€佸彸渚ц楗?鏀堕泦锛夛紝鍥炬爣澶ц€屽渾锛?
--   路 绗?1 鍏冲湪鏈€涓嬫柟锛岃秺寰€涓婂叧鏁拌秺楂橈紝鍙竴鐩村線涓婄埇銆?
--
-- 鈿狅笍 UI 鏃犳薄鏌擄細娌跨敤娓告垙 dark-tech 浠ょ墝涓?NanoVG 鍘熻锛堜緷璧栨敞鍏ワ紝涓嶅紩鍏ユ帶浠舵爲锛夈€?
-- 鈿狅笍 鏈ā鍧楀彧鐢讳笌鍛戒腑锛涘紑鏌愬叧 / 涔伴亾鍏风敱缂栨帓灞傦紙client_main.lua锛夋墽琛屻€?

local StageCatalog = require "StageCatalog"
local ItemShop = require "ui.ItemShop"
local PlayerData = require "PlayerData"
local DigitFont = require "ui.DigitFont"
local ArtText = require "ui.ArtText"

local StageSelect = {}

---@type table|nil  涓?MetaUI.Init 鐩稿悓鐨勪緷璧栬〃锛圕 浠ょ墝 + 缁樺埗鍘熻锛?
local D = nil

---@param deps table
function StageSelect.Init(deps)
    D = deps
end

---@return table
local function Style()
    return D.C
end

---@param r table
---@param px number
---@param py number
---@return boolean
local function Inside(r, px, py)
    return px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
end

-- ============================================================================
-- 甯搁噺锛堣溈铚掕矾寰勫嚑浣曪級
-- ============================================================================

local NODE_R = 40            -- 鍏冲崱鏋滃喕閽崐寰勶紙姣斾笂涓€鐗堝ぇ锛屽儚鍙偣鐨勭硸鏋滐級
local ROW_STEP = 132         -- 鐩搁偦鍏冲崱鐨勭旱鍚戦棿璺濓紙澶熷ぇ鎵嶆樉鍑?璺?锛?
local SWAY_AMP = 96          -- 妯悜鎽嗗姩骞呭害锛堝ぇ鎸箙 = 鏄庢樉铔囧舰锛屼笉鍐?杞诲害"锛?
local SWAY_PERIOD = 3        -- 姣忓嚑鍏冲畬鎴愪竴娆″乏鍙虫潵鍥烇紙鍛ㄦ湡闀?= 澶?S 寮級
local SIDE_ICON_R = 26       -- 涓や晶鍦嗗舰鍥炬爣鍗婂緞

-- 璺緞閲囨牱瀵嗗害锛堣礉濉炲皵鍒嗘鏁帮級锛岃秺澶ц秺骞虫粦
local PATH_SEGMENTS = 14

-- ============================================================================
-- 婊氬姩鐘舵€侊紙鐢辩紪鎺掑眰杞彂 Scroll* 璋冪敤锛?
-- ============================================================================

local scrollY_ = 0
local dragging_ = false
local dragLastY_ = 0
local dragStartY_ = 0
local dragMoved_ = false
local lastMaxStage_ = 1

-- ============================================================================
-- 甯冨眬
-- ============================================================================

---@class StageSelectLayout
---@field content table 鍙鍐呭鍖猴紙鍚鍓級
---@field close table
---@field towerX number 璺緞涓績鍩哄噯 x
---@field nodeY table<integer, number> 姣忓叧鍦嗗績 y锛堝凡搴旂敤婊氬姩鍋忕Щ锛?
---@field itemRows table[] 宸︿晶閬撳叿璐拱琛屽嚑浣?
---@field contentH number 鍏ㄩ儴鍐呭楂樺害
---@field maxStage integer

---@param w number
---@param maxStage integer
---@return StageSelectLayout
local function GetLayout(w, maxStage)
    local x, y = 18, 108
    local sw, sh = w - 36, 780
    local content = { x = x + 12, y = y + 56, w = sw - 24, h = sh - 72 }
    local close = { x = x + sw - 46, y = y + 8, w = 36, h = 36 }

    local towerX = content.x + content.w * 0.5
    -- 绗?1 鍏冲湪鏈€涓嬫柟锛歯odeY(1) = 鍐呭鍖哄簳閮紱瓒婂線涓?y 瓒婂皬銆?
    local botPad = NODE_R + 30
    local topPad = NODE_R + 30
    local contentH = topPad + botPad + (maxStage - 1) * ROW_STEP
    -- 鈿狅笍 鍏冲崱鏁板皯鏃跺唴瀹圭煯浜庡彲瑙嗗尯锛氳创搴曚細璁╀笂鏂圭暀涓€澶х墖绌虹櫧锛?娌￠€傞厤"瑙傛劅锛夈€?
    -- 姝ゆ椂鎶婃暣搴у**鍨傜洿灞呬腑**锛岃璺緞钀藉湪瑙嗚涓績銆?
    local freeSpace = content.h - contentH
    local centerOffset = freeSpace > 0 and freeSpace * 0.5 or 0

    ---@type table<integer, number>
    local nodeY = {}
    for stage = 1, maxStage do
        nodeY[stage] = content.y + content.h - botPad - (stage - 1) * ROW_STEP
            + scrollY_ - centerOffset
    end

    -- 宸︿晶閬撳叿琛岋細闈犲乏杈圭紭绔栨帓锛堜笌璺緞涓嶉噸鍙狅細璺緞鎸箙 SWAY_AMP + NODE_R锛夈€?
    ---@type table[]
    local itemRows = {}
    local rowH = 104
    local gap = 12
    local railW = 84
    for i = 1, #StageSelect.ITEM_ORDER do
        itemRows[i] = {
            x = content.x + 4,
            y = content.y + 12 + (i - 1) * (rowH + gap),
            w = railW,
            h = rowH,
        }
    end

    return {
        content = content, close = close, towerX = towerX, nodeY = nodeY,
        itemRows = itemRows, contentH = contentH, maxStage = maxStage,
        botPad = botPad, centerOffset = centerOffset,
    }
end

-- 浠绘剰鍏冲彿鐨勫渾蹇?y锛堝惈婊氬姩涓庡眳涓亸绉伙級鈥斺€斾緵銆屾湭鏉ュ叧骞界伒鑺傜偣銆嶈繖绫?stage > maxStage 鐨勭粯鍒剁敤銆?
---@param L StageSelectLayout
---@param stage integer
---@return number
local function NodeYAt(L, stage)
    return L.content.y + L.content.h - L.botPad - (stage - 1) * ROW_STEP
        + scrollY_ - L.centerOffset
end

---@return number 婊氬姩涓婇檺锛? 琛ㄧず鍐呭涓嶉珮浜庡彲瑙嗗尯锛?
local function MaxScroll(L)
    return math.max(0, L.contentH - L.content.h)
end

local function ClampScroll(L)
    -- 濉斾粠涓嬪線涓婂欢浼革細鏇撮珮鍏宠闈犳鍋忕Щ绉诲叆鍙鍖猴紝涓嶈兘濂楁櫘閫氬垪琛ㄧ殑璐熷亸绉昏寖鍥淬€?
    scrollY_ = math.max(0, math.min(MaxScroll(L), scrollY_))
end

-- 鏌愬叧鐨勬í鍚戝亸绉伙細**澶ф尟骞呯‘瀹氭€ф寮?*锛堝啓姝诲湪浠ｇ爜閲岋紝闈為殢鏈猴級銆?
-- 鍛ㄦ湡 SWAY_PERIOD 鍏充竴娆℃潵鍥?鈫?褰㈡垚鏄庢樉鐨勫ぇ S 寮紝鑰屼笉鏄?杞诲井鎶栧姩"銆?
---@param stage integer
---@return number
local function StageSway(stage)
    return math.sin((stage - 1) / SWAY_PERIOD * math.pi * 2) * SWAY_AMP
end

---@param L StageSelectLayout
---@param stage integer
---@return number cx
---@return number cy
local function NodeCenter(L, stage)
    return L.towerX + StageSway(stage), L.nodeY[stage]
end

-- 鎶婅鍥炬粴鍔ㄥ埌銆屾渶鏂板凡瑙ｉ攣鍏炽€嶁€斺€旀墦寮€闈㈡澘鏃堕粯璁ゅ畾浣嶅埌瀹冦€?
---@param w number
---@param maxStage integer
function StageSelect.FocusLatest(w, maxStage)
    lastMaxStage_ = math.max(1, maxStage or 1)
    scrollY_ = 0
    local L = GetLayout(w, lastMaxStage_)
    -- 璁╂渶鏂板叧钀藉湪鍙鍖哄簳閮ㄥ亸涓婏紝闇插嚭涓嬫柟璺緞鐨?鏉ヨ矾"銆?
    local target = L.content.y + L.content.h - NODE_R - 110
    scrollY_ = target - L.nodeY[lastMaxStage_]
    ClampScroll(L)
end

-- ============================================================================
-- 缁樺埗鍘熻锛堝渾銆佸钩婊戣矾寰勶級
-- ============================================================================

---@param ctx any
---@param cx number
---@param cy number
---@param r number
---@param color integer[]
local function Circle(ctx, cx, cy, r, color)
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, r)
    nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
    nvgFill(ctx)
end

---@param ctx any
---@param cx number
---@param cy number
---@param r number
---@param color integer[]
---@param width number
local function CircleStroke(ctx, cx, cy, r, color, width)
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, r)
    nvgStrokeColor(ctx, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
    nvgStrokeWidth(ctx, width)
    nvgStroke(ctx)
end

-- ============================================================================
-- 鏄熷浘鍘熻锛坴0.13.59 椋庢牸閲嶅仛锛氬叚杈瑰舰鍏冲崱鑺墖 + 鏄熷骇杩炵嚎 + 鏄熺┖锛?
-- ============================================================================

-- 姝ｅ叚杈瑰舰璺緞锛堝皷瑙掓湞涓婁笅锛夈€傜粯鍒朵笌鍛戒腑鍏辩敤鍚屼竴褰㈢姸锛屼繚璇併€岀湅鐫€鑳界偣=鐐瑰緱鍒般€嶃€?
---@param ctx any
---@param cx number
---@param cy number
---@param r number
local function HexPath(ctx, cx, cy, r)
    nvgBeginPath(ctx)
    for i = 0, 5 do
        local a = math.pi / 3 * i - math.pi / 2
        local x, y = cx + math.cos(a) * r, cy + math.sin(a) * r
        if i == 0 then nvgMoveTo(ctx, x, y) else nvgLineTo(ctx, x, y) end
    end
    nvgClosePath(ctx)
end

---@param ctx any
---@param cx number
---@param cy number
---@param r number
---@param color integer[]
local function HexFill(ctx, cx, cy, r, color)
    HexPath(ctx, cx, cy, r)
    nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
    nvgFill(ctx)
end

---@param ctx any
---@param cx number
---@param cy number
---@param r number
---@param color integer[]
---@param width number
local function HexStroke(ctx, cx, cy, r, color, width)
    HexPath(ctx, cx, cy, r)
    nvgStrokeColor(ctx, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
    nvgStrokeWidth(ctx, width)
    nvgStroke(ctx)
end

-- 纭畾鎬ф槦绌猴紙鏃犻殢鏈虹姸鎬侊紱婊氬姩鏃舵暣浣撹宸紝钀ラ€犮€岃埅琛屻€嶆劅锛夈€傚悎骞舵垚鍗曚竴璺緞閬垮厤鍛戒护缂撳啿婧㈠嚭锛圓B-216锛夈€?
---@param ctx any
---@param area table {x,y,w,h}
local function DrawStarfield(ctx, area)
    local C = Style()
    nvgSave(ctx)
    nvgIntersectScissor(ctx, area.x, area.y, area.w, area.h)
    nvgBeginPath(ctx)
    for i = 0, 96 do
        local sx = area.x + ((i * 137 + 43) % math.max(1, math.floor(area.w)))
        local baseY = area.y + ((i * 89 + 17) % math.max(1, math.floor(area.h)))
        local sy = area.y + ((baseY - area.y + scrollY_ * 0.35) % math.max(1, math.floor(area.h)))
        nvgCircle(ctx, sx, sy, (i % 11 == 0) and 1.5 or 0.9)
    end
    nvgFillColor(ctx, nvgRGBA(C.text[1], C.text[2], C.text[3], 60))
    nvgFill(ctx)
    -- 灏戦噺浜槦
    nvgBeginPath(ctx)
    for i = 0, 11 do
        local sx = area.x + ((i * 271 + 97) % math.max(1, math.floor(area.w)))
        local sy = area.y + ((i * 173 + 61 - scrollY_ * 0.35) % math.max(1, math.floor(area.h)))
        nvgCircle(ctx, sx, sy, 1.8)
    end
    nvgFillColor(ctx, nvgRGBA(C.cyan[1], C.cyan[2], C.cyan[3], 90))
    nvgFill(ctx)
    nvgRestore(ctx)
end

-- 鍏冲崱鑺墖鐨勬按骞冲崐瀹斤紙鍛戒腑涓庤繛绾胯浣嶅叡鐢級銆?
local function NodeHalfW()
    return NODE_R * 0.87
end

-- 娌夸袱鑺傜偣鐨勮繛绾挎柟鍚戝悇鍐呯缉 `pad`锛屽緱鍒颁笉鍘嬩綇鑺墖鐨勭嚎娈电鐐广€?
---@param ax number
---@param ay number
---@param bx number
---@param by number
---@param pad number
---@return number x1
---@return number y1
---@return number x2
---@return number y2
local function LinkGaps(ax, ay, bx, by, pad)
    local dx, dy = bx - ax, by - ay
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1 then return ax, ay, bx, by end
    local ux, uy = dx / len, dy / len
    return ax + ux * pad, ay + uy * pad, bx - ux * pad, by - uy * pad
end

-- 涓よ妭鐐归棿鐨勬槦搴ц繛绾匡細澶栧彂鍏?+ 涓荤嚎 + 鑺嚎锛堜笁灞傚仛鍑恒€屾湁鑳介噺銆嶇殑瑙傛劅锛夈€?
---@param ctx any
---@param ax number
---@param ay number
---@param bx number
---@param by number
---@param color integer[]
---@param lit boolean
local function DrawLink(ctx, ax, ay, bx, by, color, lit)
    local C = Style()
    local pad = NodeHalfW() * 0.98
    local x1, y1, x2, y2 = LinkGaps(ax, ay, bx, by, pad)
    local glowA = lit and 70 or 26
    local mainA = lit and 200 or 70
    nvgBeginPath(ctx); nvgMoveTo(ctx, x1, y1); nvgLineTo(ctx, x2, y2)
    nvgStrokeColor(ctx, nvgRGBA(color[1], color[2], color[3], glowA))
    nvgStrokeWidth(ctx, lit and 7 or 5); nvgLineCap(ctx, NVG_ROUND); nvgStroke(ctx)
    nvgBeginPath(ctx); nvgMoveTo(ctx, x1, y1); nvgLineTo(ctx, x2, y2)
    nvgStrokeColor(ctx, nvgRGBA(color[1], color[2], color[3], mainA))
    nvgStrokeWidth(ctx, lit and 2.4 or 1.6); nvgStroke(ctx)
    nvgBeginPath(ctx); nvgMoveTo(ctx, x1, y1); nvgLineTo(ctx, x2, y2)
    nvgStrokeColor(ctx, nvgRGBA(C.text[1], C.text[2], C.text[3], lit and 90 or 28))
    nvgStrokeWidth(ctx, 0.9); nvgStroke(ctx)
end

-- ============================================================================
-- 瑁呴グ鎻掑浘锛堢‘瀹氭€ф寫閫夌殑浣庨€忔槑搴﹀儚绱犲潡锛?
-- ============================================================================

local DECOR = {
    { w = 5, h = 4, cells = { {0,1},{1,0},{1,1},{1,2},{2,0},{2,1},{2,2},{3,1},{4,1} } },
    { w = 5, h = 3, cells = { {0,0},{1,0},{2,0},{0,1},{1,1},{2,1},{3,1},{3,0},{4,1} } },
    { w = 5, h = 5, cells = { {2,0},{2,1},{0,2},{1,2},{2,2},{3,2},{4,2},{2,3},{2,4} } },
}

---@param ctx any
---@param x number
---@param y number
---@param scale number
---@param index integer
---@param alpha number
local function DrawDecor(ctx, x, y, scale, index, alpha)
    local C = Style()
    local d = DECOR[index]
    if not d then return end
    for i = 1, #d.cells do
        local c = d.cells[i]
        D.rect(ctx, x + c[1] * scale, y + c[2] * scale, scale - 1, scale - 1,
            { C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], alpha }, 0)
    end
end

-- ============================================================================
-- 鍏冲崱鑺傜偣锛堟灉鍐婚挳 + 绮楁暟瀛?+ 涓夐鏄燂級
-- ============================================================================

---@param ctx any
---@param cx number
---@param cy number
---@param stage integer
---@param unlocked boolean
---@param stars integer
---@param current boolean
local function DrawStageNode(ctx, cx, cy, stage, unlocked, stars, current)
    local C = Style()
    local r = NODE_R

    if not unlocked then
        -- 鏈В閿侊細鏆楄壊鍏竟褰?+ 绋嬪簭鍖栧皬閿?+ 鍘嬫殫鍏冲彿锛堣创鍥惧彔鑹茶〃杈撅紝涓嶅啓鏂囧瓧锛夈€?
        HexFill(ctx, cx, cy, r, { 16, 22, 34, 255 })
        HexStroke(ctx, cx, cy, r, { C.dim[1], C.dim[2], C.dim[3], 95 }, 1.4)
        D.rect(ctx, cx - 9, cy - 13, 18, 12, { 120, 138, 160, 235 }, 5)
        D.rect(ctx, cx - 5.5, cy - 9.5, 11, 8, { 16, 22, 34, 255 }, 4)
        D.rect(ctx, cx - 12, cy - 1, 24, 17, { 74, 88, 108, 235 }, 3)
        if not DigitFont.DrawNumber(ctx, stage, cx, cy - r + 20, 14, C.dim) then
            D.text(ctx, cx, cy - r + 22, tostring(stage), 13, C.dim,
                NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        end
        return
    end

    -- 宸茶В閿侊細浜壊鍏竟褰㈣姱鐗囷紙鏈夋槦=閲?/ 鏃犳槦=闈掞紝涓庛€岀█鏈?涓绘搷浣溿€嶈涔変竴鑷达級銆?
    local accent = stars > 0 and C.warn or C.cyan
    -- 澶栧彂鍏夛紙瀹芥弿杈逛綆 alpha锛屼笉濉厖浠ュ厤绯婁綇搴曞浘锛?
    HexStroke(ctx, cx, cy, r + 3.5, { accent[1], accent[2], accent[3], 60 }, 7)
    -- 搴曠洏 + 鍐呯幆锛堝帤搴︼級
    HexFill(ctx, cx, cy, r, { 26, 40, 62, 255 })
    HexStroke(ctx, cx, cy, r - 5, { accent[1], accent[2], accent[3], 105 }, 1)
    -- 褰撳墠鍏筹細鏁寸墖浜壊瀹炲績搴曪紙娣卞瓧锛夛紝鏄叏灞忔渶浜殑鐒︾偣
    if current then HexFill(ctx, cx, cy, r - 8, accent) end
    -- 涓荤幆
    HexStroke(ctx, cx, cy, r, accent, current and 3 or 2.2)
    -- 椤堕潰鍙楀厜锛堟部涓婂乏/涓婂彸涓ゆ潯杈圭敾涓€閬撲寒绾匡紝鍋氬嚭銆屾枩鍒囬噾灞炪€嶆劅锛?
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, cx - r * 0.5, cy - r * 0.866)
    nvgLineTo(ctx, cx, cy - r)
    nvgLineTo(ctx, cx + r * 0.5, cy - r * 0.866)
    nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, current and 120 or 70))
    nvgStrokeWidth(ctx, 1.2)
    nvgStroke(ctx)

    -- 鍏冲彿锛堣创鍥撅紱缂哄浘鍥為€€ zpix锛夈€傚綋鍓嶅叧娣卞瓧銆佸叾浣欎寒瀛椼€?
    local label = tostring(stage)
    local size = (#label >= 3) and 28 or 38
    local digitColor = current and C.ink or C.text
    if not DigitFont.DrawNumber(ctx, stage, cx, cy - size * 0.60, size, digitColor) then
        D.text(ctx, cx, cy - size * 0.58, label, size, digitColor,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end

    -- 褰撳墠鍏筹細闅忓叡浜浉浣嶈剦鍐蹭竴鍦堬紙浣庨鍔ㄦ€侊紝闈為殢鏈猴級銆?
    if current then
        local phase = (D.anim and D.anim() or 0)
        local pulse = 0.5 + 0.5 * math.sin(phase * math.pi * 0.8)
        HexStroke(ctx, cx, cy, r + 6 + pulse * 3,
            { accent[1], accent[2], accent[3], math.floor(120 * (1 - pulse)) }, 2)
    end

    -- 涓夋槦锛氱敾鍦ㄨ姱鐗?*涓嬫柟澶栦晶**锛岀敤鑿卞舰锛堜笌鍏竟褰?绉戞妧璇█涓€鑷达級锛屽疄蹇?宸插緱銆?
    local gap = 15
    local sy = cy + r + 13
    for i = 1, 3 do
        local on = i <= stars
        local sx = cx + (i - 2) * gap
        if on then
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, sx, sy - 5.5); nvgLineTo(ctx, sx + 5.5, sy)
            nvgLineTo(ctx, sx, sy + 5.5); nvgLineTo(ctx, sx - 5.5, sy)
            nvgClosePath(ctx)
            nvgFillColor(ctx, nvgRGBA(C.warn[1], C.warn[2], C.warn[3], 255))
            nvgFill(ctx)
        else
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, sx, sy - 5.5); nvgLineTo(ctx, sx + 5.5, sy)
            nvgLineTo(ctx, sx, sy + 5.5); nvgLineTo(ctx, sx - 5.5, sy)
            nvgClosePath(ctx)
            nvgStrokeColor(ctx, nvgRGBA(96, 112, 132, 200))
            nvgStrokeWidth(ctx, 1.2)
            nvgStroke(ctx)
        end
    end
end

-- ============================================================================
-- 涓や晶鍦嗗舰鍥炬爣鏍?
-- ============================================================================

---@param ctx any
---@param r table
---@param iconKey string
---@param label string
---@param value string
---@param valueColor integer[]
---@param badge string|nil
---@param badgeColor integer[]
---@param dimmed boolean
---@param ring integer[]
local function DrawRoundIcon(ctx, r, iconKey, label, value, valueColor,
    badge, badgeColor, dimmed, ring)
    local C = Style()
    local cx, cy = r.x + r.w * 0.5, r.y + SIDE_ICON_R
    local body = dimmed and { 16, 22, 34, 255 } or { 26, 40, 62, 255 }
    Circle(ctx, cx, cy, SIDE_ICON_R, body)
    CircleStroke(ctx, cx, cy, SIDE_ICON_R, ring, 2.5)
    local alpha = dimmed and 0.3 or 1
    if not D.icon(ctx, iconKey, cx - 14, cy - 14, 28, alpha) then
        Circle(ctx, cx, cy, 9, ring)
    end
    -- 瑙掓爣锛堝簱瀛?鏁伴噺锛夛紝鐢ㄦ暟瀛楄〃杈撅紝涓嶅啓璇存槑鏂囧瓧
    if badge then
        local bx, by = cx + SIDE_ICON_R - 6, cy - SIDE_ICON_R + 6
        Circle(ctx, bx, by, 11, badgeColor)
        D.text(ctx, bx, by - 7, badge, 13, C.ink, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
    D.text(ctx, cx, cy + SIDE_ICON_R + 3, label, 13,
        dimmed and C.dim or C.text, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    D.text(ctx, cx, cy + SIDE_ICON_R + 20, value, 14, valueColor,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
end

-- ============================================================================
-- 缁樺埗
-- ============================================================================

---@param ctx any
---@param w number
---@param meta table 闇€鍚?stageStars / maxStage / itemStock / itemPrices
function StageSelect.Draw(ctx, w, meta)
    local C = Style()
    local tips = require "ui.GameplayTips"
    local maxStage = math.max(1, meta.maxStage or 1)
    lastMaxStage_ = maxStage
    local L = GetLayout(w, maxStage)
    D.backdrop(ctx, 0, 0, w, 960)
    D.shell(ctx, 18, 108, w - 36, 780, 48)
    D.rect(ctx, 18, 156, 3, 22, C.cyan, 0)
    -- v0.13.58锛氶潰鏉夸富鏍囬鏀圭敤 AI 鍍忕礌鑹烘湳瀛楋紙娣卞簳浜瓧 鈫?tint C.text锛夛紱鏃犲浘鍥為€€ zpix銆?
    if not ArtText.Draw(ctx, "stage", 34 + ArtText.Width("stage") * 0.5, 116, C.text) then
        D.text(ctx, 34, 118, "閫夋嫨鍏冲崱", 22, C.text)
    end
    local totalStars = 0
    for stage = 1, maxStage do
        totalStars = totalStars + ((meta.stageStars and meta.stageStars[stage]) or 0)
    end
    D.text(ctx, L.content.x + L.content.w - 44, 122,
        string.format("鈽?%d", totalStars), 15, C.warn,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)

    -- 鍏抽棴鎸夐挳
    D.panel(ctx, L.close.x, L.close.y, L.close.w, L.close.h, C.card, C.cyanDim, 6)
    D.text(ctx, L.close.x + L.close.w * 0.5, L.close.y + 7, "X", 20, C.dim,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    -- ---- 濉旇韩锛堣鍓埌鍐呭鍖猴級----
    nvgSave(ctx)
    nvgIntersectScissor(ctx, L.content.x, L.content.y, L.content.w, L.content.h)

    -- 鏄熺┖搴曪紙婊氬姩瑙嗗樊锛夛紝浣滀负鏁寸墖鏄熷浘鐨勫熀搴с€?
    DrawStarfield(ctx, L.content)

    -- 浠櫒杈规锛氬洓瑙掓姌绾?+ 鏋佹贰缃戞牸 + 椤?搴曞埢搴﹀甫锛堜笌鍏朵綑闈㈡澘鍚岃瑷€锛屽彧鐢讳笉杩涘懡涓級銆?
    D.corner(ctx, L.content.x + 4, L.content.y + 4, L.content.w - 8, L.content.h - 8,
        {C.dim[1], C.dim[2], C.dim[3], 120}, 12, 1)
    D.grid(ctx, L.content.x + 6, L.content.y + 6, L.content.w - 12, L.content.h - 12,
        34, 7)
    D.rule(ctx, L.content.x + 12, L.content.y + 6, L.content.w - 24, 10,
        {C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 90})
    D.rule(ctx, L.content.x + 12, L.content.y + L.content.h - 6, L.content.w - 24, 10,
        {C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 90})

    -- 鏄熷骇杩炵嚎锛氱浉閭诲叧涔嬮棿涓€娈碉紱宸茶В閿佹浜潚銆佹湭瑙ｉ攣娈垫殫銆?
    for stage = 1, maxStage - 1 do
        local ax, ay = NodeCenter(L, stage)
        local bx, by = NodeCenter(L, stage + 1)
        DrawLink(ctx, ax, ay, bx, by, C.cyan, true)
    end
    -- 浠庡綋鍓嶆渶鏂板叧缁х画寰€鍓嶏紝寤朵几鍑洪€氬線銆屾湭鏉ュ叧銆嶇殑鏆楃嚎锛堢函瑁呴グ锛屼笉鍙備笌鍛戒腑锛夈€?
    local px, py = NodeCenter(L, maxStage)
    for k = 1, 5 do
        local nx = L.towerX + StageSway(maxStage + k)
        local ny = NodeYAt(L, maxStage + k)
        DrawLink(ctx, px, py, nx, ny, C.cyanDim, false)
        px, py = nx, ny
    end

    -- 娴佸姩鑳介噺鐐癸細娌挎暣鏉¤埅绾匡紙宸茶В閿佹 + 寤朵几娈碉級鎸夊叡浜浉浣嶅墠杩涳紙纭畾鎬э紝闈為殢鏈猴級銆?
    do
        local phase = (D.anim and D.anim() or 0)
        local fpts = {}
        for stage = 1, maxStage + 5 do
            fpts[#fpts + 1] = { x = L.towerX + StageSway(stage), y = NodeYAt(L, stage) }
        end
        local nseg = #fpts - 1
        if nseg >= 1 then
            for d = 0, 3 do
                local t = ((phase * 0.4) + d * 0.25) % 1
                local seg = math.min(nseg, math.floor(t * nseg) + 1)
                local lt = t * nseg - (seg - 1)
                local p1, p2 = fpts[seg], fpts[seg + 1]
                if p1 and p2 then
                    local fx = p1.x + (p2.x - p1.x) * lt
                    local fy = p1.y + (p2.y - p1.y) * lt
                    Circle(ctx, fx, fy, 6.4, { C.cyan[1], C.cyan[2], C.cyan[3], 60 })
                    Circle(ctx, fx, fy, 3.0, { C.text[1], C.text[2], C.text[3], 200 })
                end
            end
        end
    end

    -- 鏈潵鍏冲菇鐏靛叚杈瑰舰锛氳ˉ婊″唴瀹瑰尯銆佽銆岃埅绾胯繕寰堥暱銆嶅彲瑙侊紙鏋佷綆 alpha锛屼笉鍙備笌鍛戒腑锛夈€?
    for stage = maxStage + 1, maxStage + 6 do
        local cx = L.towerX + StageSway(stage)
        local cy = NodeYAt(L, stage)
        if cy > L.content.y - NODE_R and cy < L.content.y + L.content.h + NODE_R then
            HexFill(ctx, cx, cy, NODE_R, { 14, 22, 34, 110 })
            HexStroke(ctx, cx, cy, NODE_R, { C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 40 }, 1.4)
        end
    end

    -- 鍏冲崱鑺墖锛堜粠楂樺埌浣庣敾锛岄伩鍏嶉噸鍙犳椂浣庡叧鍘嬩綇楂樺叧锛?
    for stage = maxStage, 1, -1 do
        local cx, cy = NodeCenter(L, stage)
        if cy > L.content.y - NODE_R and cy < L.content.y + L.content.h + NODE_R then
            local stars = (meta.stageStars and meta.stageStars[stage]) or 0
            DrawStageNode(ctx, cx, cy, stage, true, stars, stage == maxStage)
        end
    end

    -- 鍙充晶瑁呴グ鎻掑浘锛堢‘瀹氭€ф寫閫夛級
    local seed = math.floor(scrollY_ / 110)
    for k = 0, 4 do
        local idx = (seed + k) % #DECOR + 1
        local dy = L.content.y + 60 + k * 150
        if dy < L.content.y + L.content.h - 60 then
            DrawDecor(ctx, L.content.x + L.content.w - 62, dy, 7, idx, 26 + (k % 2) * 14)
        end
    end

    nvgRestore(ctx)

    -- ---- 宸︿晶鏍忥細閬撳叿璐拱锛堝渾褰㈠浘鏍?+ 瑙掓爣搴撳瓨 + 浠锋牸锛?---
    local parts = PlayerData.GetParts()
    for i = 1, #StageSelect.ITEM_ORDER do
        local def = StageSelect.ITEM_ORDER[i]
        local r = L.itemRows[i]
        if r.y < L.content.y + L.content.h then
            local count = PlayerData.GetItemCount(def.key)
            local price = ItemShop.GetPrice(def.key)
            local atCap = count >= ItemShop.MAX_STOCK
            local affordable = (not atCap) and parts >= price
            local ring = atCap and C.widget or (affordable and C.cyan or C.cyanDim)
            DrawRoundIcon(ctx, r, def.icon, def.name, tostring(price),
                atCap and C.dim or (affordable and C.cyan or C.error),
                count > 0 and tostring(count) or nil,
                count > 0 and C.cyan or C.widget,
                count <= 0, ring)
        end
    end

    -- 鍏冲崱鍒楄〃搴曢儴甯搁┗鎻愮ず锛氬垪琛ㄥ姞杞界粨鏉熷悗浠嶄繚鐣欎竴鏉″彲杞崲鐨勭帺娉曚俊鎭€?
    local tipIndex = math.floor((D.anim and D.anim() or 0) / 4) % tips.Count() + 1
    local tipY = 898
    D.panel(ctx, 30, tipY, w - 60, 50, C.rail, C.cyanDim, 6)
    D.text(ctx, 46, tipY + 8, "浣滄垬鎻愮ず", 12, C.cyanDim)
    D.text(ctx, 46, tipY + 25, tips.Get(tipIndex), 13, C.text)

    -- 棣栨杩涘叆鍏冲崱鍒楄〃鏃舵樉绀虹煭鏆傜殑鑸嚎鍚屾鍔犺浇灞傦紝璁╂彁绀哄湪绛夊緟鏈熼棿涔熷彲璇汇€?
    if meta.stageSelectLoading then
        local loadT = math.max(0, math.min(1, (meta.stageSelectLoadingTimer or 0) / 1.35))
        D.rect(ctx, 0, 0, w, 960, { 4, 8, 16, 220 }, 0)
        local panelW, panelH = w - 96, 214
        local panelX, panelY = 48, 328
        D.panel(ctx, panelX, panelY, panelW, panelH, C.rail, C.cyanDim, 8)
        D.text(ctx, w * 0.5, panelY + 28, "鑸嚎鍚屾涓?, 22, C.cyan,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        D.text(ctx, w * 0.5, panelY + 67, "姝ｅ湪鏁寸悊鍏冲崱鑸嚎涓庤ˉ缁欎俊鎭?, 14, C.dim,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        D.text(ctx, panelX + 22, panelY + 112, "鎻愮ず", 13, C.cyanDim)
        D.text(ctx, panelX + 22, panelY + 137, tips.Get(tipIndex + 1), 15, C.text)
        D.progress(ctx, panelX + 22, panelY + 178, panelW - 44, 1 - loadT, C.cyan, 5)
    end
end

-- ============================================================================
-- 鍛戒腑锛氳繑鍥?(action, index)銆?
--   "play_stage" + 鍏冲彿 / "buy_item" + 閬撳叿搴忓彿 / "close"
-- ============================================================================

-- 閬撳叿 key 涓庡浘鏍?鍚嶇О锛堥『搴忓嵆宸︿晶鏍忎粠涓婂埌涓嬬殑椤哄簭锛夈€?
StageSelect.ITEM_ORDER = {
    { key = "bomb",   name = "鐐稿脊", color = { 196, 120, 255 }, icon = "bomb" },
    { key = "freeze", name = "鍐板喕", color = { 120, 216, 255 }, icon = "freeze" },
    { key = "shield", name = "鎶ょ浘", color = { 90, 200, 255 },  icon = "shield" },
}

---@param uiX number
---@param uiY number
---@param w number
---@param meta table
---@return string|nil action
---@return integer|nil index
function StageSelect.HitTest(uiX, uiY, w, meta)
    if meta.stageSelectLoading then return nil, nil end
    local maxStage = math.max(1, meta.maxStage or 1)
    local L = GetLayout(w, maxStage)
    if Inside(L.close, uiX, uiY) then return "close", nil end

    -- 閬撳叿锛氬懡涓暣鍧楃珫鏉★紙鍚浘鏍囦笌鏂囧瓧锛夛紝渚夸簬鐐规寜
    for i = 1, #StageSelect.ITEM_ORDER do
        if Inside(L.itemRows[i], uiX, uiY) then return "buy_item", i end
    end

    -- 鍏冲崱鑺墖锛氬叚杈瑰舰鍛戒腑锛堜笌缁樺埗鍚屽舰锛屼繚璇併€岀湅鐫€鑳界偣=鐐瑰緱鍒般€嶏級銆?
    -- 鍏竟褰紙灏栬鏈濅笂涓嬶級鐢ㄤ笁涓害鏉熷垽瀹氾細|dy| 鈮?r锛屼互鍙婁袱鏉℃枩杈?卤(dy路0.5 + |dx|路0.866) 鈮?r銆?
    local hr = NODE_R + 3
    for stage = maxStage, 1, -1 do
        local cy = L.nodeY[stage]
        if cy > L.content.y - NODE_R and cy < L.content.y + L.content.h + NODE_R then
            local cx = L.towerX + StageSway(stage)
            local dx, dy = math.abs(uiX - cx), math.abs(uiY - cy)
            if dy <= hr and (dy * 0.5 + dx * 0.866) <= hr then
                return "play_stage", stage
            end
        end
    end
    return nil, nil
end

-- ============================================================================
-- 婊氬姩锛堢敱缂栨帓灞備粠榧犳爣/瑙︽懜杞彂锛?
-- ============================================================================

---@param uiX number
---@param uiY number
---@param w number
---@return boolean armed
function StageSelect.ScrollBegin(uiX, uiY, w)
    local L = GetLayout(w, lastMaxStage_)
    if not Inside(L.content, uiX, uiY) then return false end
    dragging_ = true
    dragLastY_ = uiY
    dragStartY_ = uiY
    dragMoved_ = false
    return true
end

---@param uiY number
---@param w number
function StageSelect.ScrollMove(uiY, w)
    if not dragging_ then return end
    local delta = uiY - dragLastY_
    dragLastY_ = uiY
    if math.abs(uiY - dragStartY_) > 8 then dragMoved_ = true end
    scrollY_ = scrollY_ + delta
    ClampScroll(GetLayout(w, lastMaxStage_))
end

---@return boolean moved 鏄惁鐪熺殑鎷栧姩杩囷紙鎷栧姩杩囧垯鍚炴帀鏈鐐瑰嚮锛?
function StageSelect.ScrollEnd()
    if not dragging_ then return false end
    dragging_ = false
    return dragMoved_
end

---@return boolean
function StageSelect.IsDragging()
    return dragging_
end

return StageSelect
