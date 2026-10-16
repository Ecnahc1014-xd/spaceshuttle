-- Game.lua
-- 璐ц溅澶ф垬椋炴満鏍稿績鐜╂硶銆傚彧缁存姢瑙勫垯銆佺鎾炲拰鏉冨▉鐘舵€侊紝涓嶄緷璧栦换浣曟覆鏌?API銆?

local AircraftData = require "AircraftPixelData"
local StageCatalog = require "StageCatalog"
local TalentCatalog = require "TalentCatalog"
local EnchantCatalog = require "EnchantCatalog"

local Game = {}
-- 绌烘墜闀挎寜鍙缉鏀炬垬鏂楁ā鎷燂紝涓嶆敼鍙樿〃鐜版椂閽燂紱鏀惰〃閬垮厤澧炲姞涓诲潡 local 妲戒綅銆?
Game._holdSpeed = { down = false, active = false, time = 0, threshold = 0.35, epoch = 0 }
-- 鍙戝皠钃勫姏鐙珛浜庢媺閲?鍒濋€燂紝浣跨敤鍏佽杈撳叆鏃堕棿锛屼笉鍙楃┖鎵嬪€嶉€熸垨椤垮抚鍊嶇巼褰卞搷銆?
---@class LaunchChargeState
---@field time number
---@field total number
---@field x number
---@field y number
---@field uiX number|nil
---@field uiY number|nil
---@type LaunchChargeState
Game._launchCharge = { time = 0, total = 1.2, x = 0, y = 0, uiX = nil, uiY = nil }
function Game.ClearLaunchCharge()
    Game._launchCharge.time = 0
    Game._launchCharge.uiX, Game._launchCharge.uiY = nil, nil
end
-- v0.13.64锛氭嫋鎷借寖鍥存槸銆?D 璁捐绌洪棿閲屼竴涓洿寰勫渾銆嶇殑鎶曞奖锛岃€屼笉鏄?3D/鐜╂硶绌洪棿閲岀殑鍦嗐€?
--   杈撳叆鍦?*璁捐(UI)鍧愭爣**閲屾寜鍦嗛挸鍒讹紙鍗婂緞 MAX_PULL 璁捐鍍忕礌锛夛紝鍐嶉櫎浠ユ姇褰辩缉鏀炬崲绠楁垚鐜╂硶
--   浣嶇Щ鈥斺€斾簬鏄帺娉曞钩闈笂鐨勮寖鍥存槸涓€涓き鍦嗭紙= 灞忓箷鍦嗙殑鎶曞奖锛夛紝鎵嬫劅濮嬬粓鏄€屽睆骞曚笂鐨勫渾銆嶃€?
--   sx/sy 鐢辩紪鎺掑眰浠庡悗绔姇褰卞彇寰楋紱缂虹渷 1/1 鏃堕€€鍖栦负鐜╂硶绌洪棿鍦嗭紙鎺㈤拡/鏃犵浉鏈哄満鏅級銆?
--   uiX/uiY 璁板綍璁捐鍧愭爣鎸変笅鐐癸紝dist 璁板綍鏈抚閽冲埗鍚庣殑璁捐鍍忕礌鎷夎窛锛堜緵濞佸姏鏄犲皠锛夈€?
Game._pullSpace = { sx = 1, sy = 1, uiX = 0, uiY = 0, dist = 0, gnorm = 0 }
---@param sx number
---@param sy number
function Game.SetPullSpace(sx, sy)
    Game._pullSpace.sx = (sx and sx > 1e-6) and sx or 1
    Game._pullSpace.sy = (sy and sy > 1e-6) and sy or 1
end
-- v0.13.58锛氬眬鍐呴檮榄斿崱鐘舵€侊紙鏀惰繘涓€寮犺〃锛屼笉鏂板椤跺眰 local锛孉B-166锛夈€?
--   card    = 褰撳墠鎸佹湁鐨勯檮榄斿崱锛圗nchantDef锛夛紝nil 琛ㄧず绌烘墜
--   pending = 宸蹭娇鐢ㄤ絾褰撳墠娌℃湁寰呭彂杞︽椂锛岄『寤剁粰銆屼笅涓€涓澶囧彂灏勭殑杞︺€嶇殑闄勯瓟鍗?
--   lastWave= 鏈€杩戜竴娆″彂鏀鹃檮榄斿崱鏃剁殑娉㈠彿锛堢敤浜庛€屾瘡瀹屾垚涓€娉㈠彂涓€寮犮€嶅垽瀹氾級
Game._enchant = { card = nil, pending = nil, lastWave = 0 }
-- v0.13.65锛氬够褰变綋绱犲潡鈥斺€旂姸鎬佸叏閮ㄦ敹杩涗竴寮犺〃锛堥浂鏂板椤跺眰 local锛孉B-166锛夈€?
--   list       = 褰撳墠鍦ㄥ満骞诲奖鍧楁暟缁勶紙缁撴瀯瑙?SpawnPhantom锛氱煩褰?+ 琛€閲?+ 閫熷害锛?
--   guaranteed = 鏈叧鍓?5 娉㈢疮璁″凡鍙戝皠鏁帮紙鐢ㄤ簬銆屽墠 5 娉㈣嚦灏?10 鏋躲€嶄繚搴曪級
--   firedKeys  = 鏈叧宸插彂灏勮繃骞诲奖鐨勬満鍨嬮泦鍚堬紙淇濆簳鏃朵紭鍏堥€夊皻鏈彂灏勭殑鏈哄瀷锛?
Game._phantom = { list = {}, guaranteed = 0, firedKeys = {}, nextId = 1, guaranteeTimer = 0 }
-- v0.13.60锛氬け璐ョ粨绠楄繃娓★紙鏀惰繘涓€寮犺〃锛屼笉鏂板椤跺眰 local锛孉B-166锛夈€?
--   at     = 杩涘叆 gameover 鐨勬椂鍒伙紙elapsed锛夛紝杩囨浮鍔ㄧ敾鐨勮鏃跺熀鍑?
--   revive = 鏈眬鏄惁杩樿兘澶嶆椿锛堝喅瀹氬姩鐢婚噷鏄惁鍑虹幇銆屽彲澶嶆椿銆嶆彁绀猴級
Game._defeat = { at = nil, revive = false }
-- 涓よ疆寮€灞€閫夎溅鍊熺敤 levelup 杈撳叆/绐楀彛锛岃鏁扮嫭绔嬩簬缁忛獙鍗囩骇锛屼笉澧炲姞涓诲潡 local銆?
Game._opening = {
    active = false, round = 0, total = 2, selected = {}, phase = nil, timer = 0.0,
    durations = { briefing = 0.95, select = 0.32, between = 0.65, ready = 1.05 },
}

local DW = 540
local DH = 960
-- 椤堕儴鍙嶅脊杈圭晫锛堟父鎴忓潗鏍囷級銆傝皟鏁村巻鍙诧細鏈€鍒濅负 0锛堝睆骞曞唴鍗婄┖鍙嶅脊锛夛紝v0.10.8 鎶埌 -270锛堝畬鍏ㄥ嚭灞忥級锛?
-- v0.10.10 鍙栦袱鑰呭潎鍊?-135锛氭姇褰卞埌璁捐鍧愭爣绾?y鈮?05锛屾伆鍦?HUD 涓嬫柟锛岃浇鍏烽鍒版垬鍦洪《閮ㄦ墠鍙嶅脊銆?
-- 宸﹀彸杈圭晫浠嶆槸 0 / DW锛涜瑙夎竟妗嗗繀椤讳笌姝ゅ父閲忎竴鑷达紙瑙?Scene3DBackend.CreateWorldEdges锛夈€?
local TOP_BOUND_Y = -135
local BASE_BRICK_SIZE = 16
local SLING_X = 270
local SLING_Y = 850
-- v0.13.66锛氬睆骞曟嫋鎷藉渾鍗婂緞 = 鍘?150 璁捐鍍忕礌鐨?85%锛堝睆骞曚负鍑嗭級锛岀帺娉曠┖闂村悓姝ュ渾閽冲埗銆?
local MAX_PULL = 150 * 0.85
local DANGER_Y = 900
local BASE_HP = 100

-- 骞稿瓨鑰呭寲鍙傛暟
local BRICK_BASE_DAMAGE = 0.5      -- 姣忚鏂瑰潡瓒婅繃鐩爣绾挎椂鐨勫熀纭€浼ゅ锛岄€愯鍚戜笂鍙栨暣锛堟瘡琛屽疄闄呮墸 1锛?
local XP_PER_BRICK = 1             -- 鍑荤涓€涓柟鍧楄幏寰楃殑缁忛獙
local XP_PER_CLEAR = 8             -- 娓呮帀鏁存敮椋炶埞鐨勯澶栫粡楠?
-- v0.11.0 鍟嗕笟鍖栵細灞€鍐呫€岄浂浠躲€嶄骇鍑猴紙杞揣甯侊級锛岀粨绠楁椂鐢辩紪鎺掑眰鍐欏叆 PlayerData銆?
local PARTS_PER_BRICK = 1          -- 鍑荤涓€涓柟鍧?
local PARTS_PER_CLEAR = 10         -- 娓呮帀鏁存敮缂栭槦
local PARTS_PER_WAVE = 25          -- 姣忔帹杩涗竴娉?
local BASE_XP_TO_NEXT = 26         -- 绗竴娆″崌绾ф墍闇€缁忛獙锛堝崟鏋朵睛瀵熸満绾?50 鏍硷紝绾︿袱鏋跺崌涓€绾э級

-- 鏁板€煎钩琛¤〃锛圵O-01/P1锛夛細灞€鍐呬笉鍙彉鏁板€奸泦涓鐞嗭紝渚夸簬璋冨弬涓庣绾挎ā鎷熴€?
-- 鏃у父閲忓悕浠嶄綔涓烘湰琛ㄧ殑鍒濆鍖栨潵婧愶紝淇濇寔鍚戝悗鍙鍒悕銆?
local BALANCE = {
    baseHp = BASE_HP,
    brickBaseDamage = BRICK_BASE_DAMAGE,
    xpPerBrick = XP_PER_BRICK,
    xpPerClear = XP_PER_CLEAR,
    baseXpToNext = BASE_XP_TO_NEXT,
    xpToNextGrowth = 1.26,          -- WO-02/P1锛氭瘡绾х粡楠岄槇鍊兼寚鏁颁箻瀛?
    clearStreakBonusCap = 5,
    maxPull = MAX_PULL,
    -- v0.13.66锛氬弽寮圭鎾炵 = 寮圭彔鍗婂緞鐨?85%锛涗激瀹崇鎾烇紙鍛戒腑/鍦嗗煙/骞诲奖鍑荤锛変粛鐢ㄦ弧鍗婂緞銆?
    bounceBoxScale = 0.85,
    pullPositionScale = 0.6, -- 鍦嗗舰杈撳叆淇濈暀鍏ㄥ箙锛屽緟鍙戣溅杈嗕綅绉绘寜姣斾緥缂╃煭
    powerMin = 0.35,   -- 鏈€灏忚搫鍔涘垵閫熸瘮渚嬶紙杞绘嫋涔熸湁鍩虹灏勭▼锛?
    powerMax = 1.0,    -- 婊¤搫鍔涘垵閫熸瘮渚?
    -- 鎷栨嫿钃勫姏鏈熼棿鍏ㄥ眬鍑忛€?80%锛氱帺娉曟椂闂存斁鎱㈠埌 20%锛屾澗鎵?鍙栨秷绔嬪嵆鎭㈠銆?
    dragTimeScale = 0.2,
    -- 钃勫姏杈惧埌姝ゆ瘮渚嬪嵆瑙嗕负銆屽凡瀹屾垚銆嶏細鍙戝皠鏃剁珛鍒昏ˉ婊★紝浜彈婊¤搫浼ゅ涓庡叏鎭垎鍙戙€?
    chargeCompleteThreshold = 0.85,
}

local BALL_TYPES = {
    normal = {
        radius = 20, speed = 560, damage = 1,
        splitChance = 0.05, splitAngle = 18, splitSpread = 18,
        maxConcurrent = 15,       -- 寰呭彂 + 椋炶 + 鏈抚寰呭姞鍏ョ殑鍒嗚杞︽€讳笂闄愶紱搴撳瓨闃熷垪涓嶅崰鍚嶉
        bounceElasticity = 1.0,    -- WO-05/P4锛氬弽寮瑰脊鎬э紝1.0 涓烘爣鍑?
    },
    speed = {
        radius = 18, speed = 660, damage = 1,
        speedBoost = 1.06,
        -- v0.13.22锛?*鍘绘帀閫熷害涓婇檺**锛堝師 maxSpeed=900 灏侀《锛夆€斺€旈€熷害鏃犻檺澧為暱锛屼笉灏侀《銆?
        -- v0.13.23锛氬姞**杞€ч€掑噺**鈥斺€旈€熷害瓒婇珮锛屾瘡娆″姞閫熺殑鍊嶇巼瓒婃帴杩?1.0锛堜絾浠?>1锛屾案杩滃湪娑級锛?
        -- 閬垮厤鍚庢湡婊氶洩鐞冨け鎺э紱`speedBoostFloor` 鏄“鍑忎笅闄愶紙鍐嶅揩涔熻嚦灏戞寜杩欎釜鍊嶇巼娑級銆?
        speedBoostFloor = 1.012,
        speedSoftCap = 1400,       -- 杈惧埌姝ら€熷害鏃跺姞閫熷€嶇巼闄嶅埌涓嬮檺
        damageStep = 320,
        -- v0.13.22锛?*鍘绘帀浼ゅ灏侀《**锛堝師 maxDamage=2锛夆€斺€斾激瀹虫寜閫熷害鍒嗘。鏃犻檺澧為暱銆?
        redirectThrottle = 0.45,    -- 鑷姩杩藉嚮鐨勮妭娴侊紙绉掞級锛屽墛寮卞叾鎸佺画榛忕潃
        redirectMinSpeed = 120,     -- WO-05/P4锛氫綆浜庢閫熷害涓嶈Е鍙戣拷鍑伙紝娑堥櫎浣庨€熸姈鍔?
        bounceElasticity = 1.0,    -- 鍔犻€熷脊鏇?婊?
    },
    ice = {
        radius = 20, speed = 520, damage = 1,
        freezeDuration = 3.0,
        bounceElasticity = 1.0,
    },
    giant = {
        radius = 30, speed = 420, damage = 2,
        pierceAfterBounce = true,
        areaRadiusCells = 3.5,
        areaCooldown = 1.0,       -- 鑼冨洿浼ゅ鍐呯疆鍐峰嵈锛堢锛夛紝姣忚締宸ㄥ瀷杞︾嫭绔嬭鏃?
        bounceElasticity = 0.92,   -- WO-05/P4锛氬法鍨嬪脊鏇?娌?
    },
}
local BALL_ORDER = { "normal", "ice", "speed", "giant" }
-- v0.13.19锛氬垵濮嬭溅浠庡垎瑁傝溅鏀逛负**鍔犻€熻溅**锛堢敤鎴锋寚瀹氥€屽熀纭€鐨勮溅鏀逛负鍔犻€熻溅銆嶏級銆?
-- 鍏朵綑涓夎溅锛堝垎瑁?鍐板喕/宸ㄥ瀷锛変粛闈犲眬鍐呭崌绾у崱銆岃В閿伱椕楄溅銆嶈繘鍏ユ湰灞€闃熷垪銆?
local STARTING_BALL_TYPE = "speed"
-- 寮€灞€瑁呰浇鐨勮溅杈嗘€绘暟锛? 杈嗗緟鍙?+ ammoCapacity-1 杈嗗寮癸級銆?
-- v0.12.15锛氬紑灞€ 3 杈?鈫?1 杈嗭紙鍙湁寰呭彂锛屾病鏈夊寮癸級锛涖€屽脊鑽墿瀹广€嶉€氱敤鍗囩骇姣忕骇 +1锛堟渶澶氫笁绾э級銆?
-- 琛ュ脊鎸夈€屽洖鏀朵竴杈嗚ˉ涓€杈嗐€嶇淮鎸佽繖涓€婚噺锛堜富鐞冨洖鏀舵椂 EnqueueNextBall锛夈€?
local BASE_AMMO_TOTAL = 1
local ammoCapacity = BASE_AMMO_TOTAL
local unlockedBalls = { [STARTING_BALL_TYPE] = true }

-- P11 璇嶆潯绯荤粺锛堣鍒欏眰锛夛細寮圭彔鍙惡甯︾殑"璇嶆潯"淇グ锛屽奖鍝嶄激瀹?寮归亾/鍙嶉琛屼负銆?
-- 浠呴€氳繃 CreateMarble 鐨?words 琛ㄦ敞鍏ワ紱apply() 鍦ㄧ敓鎴愭椂鏀瑰啓 marble 瀛楁鎴栨寕杞借涓烘爣璁帮紝
-- 涓嶈Е纰颁换浣曟覆鏌?API銆傝瑙夎〃鐜帮紙璇嶆潯鐜粫鍏夈€佸紓甯告煋鑹诧級鎺ㄨ繜鍒?deferred.md D 鐢辫〃鐜板眰娑堣垂浜嬩欢銆?
local BALL_WORDS = {
    pierce = {  -- 璐┛锛氭湰娆￠琛岀殑棣栧潡鍛戒腑涓嶅弽寮癸紝鐩存帴绌胯繃缁х画椋炶
        name = "璐┛",
        apply = function(marble) marble.wordPierce = true end,
    },
    lifesteal = {  -- 鍚歌锛氭瘡娆″嚮纰庣爾鍧椾负鍩哄湴鍥炲灏戦噺鐢熷懡锛堟渶澶氬洖鍒颁笂闄愶級
        name = "鍚歌",
        value = 1,
        apply = function(marble, def) marble.wordLifesteal = def.value or 1 end,
    },
    chain = {  -- 杩為攣锛氬懡涓椂鍚戞渶杩戝彟涓€鐮栧潡杩藉姞涓€娆″皬鑼冨洿婧呭皠
        name = "杩為攣",
        radius = 1.6,
        apply = function(marble, def) marble.wordChain = def.radius or 1.6 end,
    },
    momentum = {  -- 鍔ㄩ噺锛氫激瀹抽殢褰撳墠閫熷害鎻愬崌锛堥珮閫熺悆鏇寸棝锛?
        name = "鍔ㄩ噺",
        apply = function(marble) marble.wordMomentum = true end,
    },
    heavy = {  -- 閲嶅脊锛氬弽寮瑰脊鎬ф洿浣庛€佸懡涓爾鍧楅澶栧帇鍒讹紙鍐荤粨绫讳技鍑忛€熺敱 ice 澶勭悊锛?
        name = "閲嶅脊",
        apply = function(marble) marble.wordHeavy = true end,
    },
}
local WORD_IDS = { "pierce", "lifesteal", "chain", "momentum", "heavy" }

-- 灞€鍐呭彲璋冭鍒欙紙鍙楀崌绾у奖鍝嶏級锛屽垵濮嬪€笺€傚繀椤诲湪浣跨敤瀹冪殑鍗囩骇闂寘涔嬪墠澹版槑銆?
local BALL_TUNING = {
    damageBonus = 0,
    giantArea = 0,
    splitBonus = 0,
    speedMul = 1.0,
    iceBonus = 0,
    -- 瓒婄嚎鏁翠綋浼ゅ鍑€鍔犳垚锛氬湪鈥滆秺绾胯鏁?脳 ceil(0.5)鈥濆悎璁″悗涓€娆℃€ч檮鍔狅紙鐜荤拑澶х偖 +1锛夈€?
    lineDamageBonus = 0,
    -- v0.13.28 閫氱敤鍗￠噸鍋氾細瑁呯敳寮哄寲鐨勭櫨鍒嗘瘮鍑忎激锛?..0.45锛岀粨绠楁椂鍥涜垗浜斿叆骞朵繚璇佹渶浣?1锛夈€?
    armorReduce = 0,
    -- v0.13.28 閫氱敤鍗￠噸鍋氾細瑁呯敳寮哄寲鐨勯浂浠朵骇鍑哄€嶇巼锛? + 0.08/绾э級銆?
    partsMul = 1.0,
    -- v0.13.28 閫氱敤鍗￠噸鍋氾細鐜荤拑宸ㄧ偖鐨勫彂灏勫垵閫熷€嶇巼锛? + 0.10/绾э級銆?
    launchSpeedMul = 1.0,
    -- v0.13.28 閫氱敤鍗￠噸鍋氾細绌跨敳寮瑰ご姣忓嚮纰庝竴鍧楃殑棰濆缁忛獙锛?1/绾э級銆?
    brickXpFlat = 0,
    xpMul = 1.0,
    -- v0.13.55 杞﹀瀷銆屼笓灞炲崱銆嶆満鍒剁淮搴︼紙涓庡熀纭€鍗″尯鍒嗭級锛?
    --   鍩虹鍗″彧缁欒杞︿富灞炴€х殑鎵撳簳鏁板€硷紝涓撳睘鍗℃敼鏈哄埗銆佷笉鏄洿澶х殑鏁板瓧銆?
    -- 鍒嗚锛氬崟娆″垎瑁備骇鍑虹殑寮圭彔鏁帮紙鍩虹 2 棰楋紱瑁傚彉鏍告瘡绾?+1锛夈€?
    splitCount = 2,
    -- 鍐板喕锛氬銆屽喕缁撲腑銆嶆晫鏈虹殑鍙楀嚮浼ゅ鍔犳垚锛?..0.9锛岄湝瑁傛秱灞傛瘡绾?+0.3锛夈€?
    iceShatter = 0,
    -- 鍔犻€燂細姣忔椋炶鐨勭┛閫忔鏁帮紙鍔ㄨ兘绌垮埡姣忕骇 +1锛夛紝绌块€忔椂涓嶅弽寮广€佽繛缁悆鍧椼€?
    speedPierce = 0,
    -- 宸ㄥ瀷锛氳寖鍥村嚮纰庣殑鏆村嚮鐜囷紙0..0.45锛屽啿鍑绘尝姣忕骇 +0.15锛夛紝鏆村嚮浼ゅ 脳2銆?
    giantCritChance = 0,
}

local gameState = "menu"
local score = 0
local highScore = 0
local baseHp = BASE_HP
local baseShield = 0               -- 灞€鍐呮姢鐩惧惛鏀跺€硷紙閬撳叿妲姐€屾姢鐩俱€嶆彁渚涳級
local ResetItems                   -- 鍓嶅悜澹版槑锛歊esetGame 閲岃璋冪敤锛涘悗瀹氫箟浼氶€€鍖栨垚鍏ㄥ眬鏌ユ壘
-- v0.13.13锛氬眬澶栭亾鍏峰簱瀛樻媺鍙栧嚱鏁帮紙缂栨帓灞傛敞鍐岋級銆傗殸锔?蹇呴』鍦?ResetGame 涔嬪墠澹版槑鈥斺€?
-- ResetGame 寮€灞€灏辫皟鐢ㄥ畠锛屽悗缃０鏄庝細閫€鍖栨垚鍏ㄥ眬 nil锛圓B-100 鍚屾棌锛夈€?
---@type fun(): table<string, integer>|nil
local itemStockProvider = nil
local wave = 1
local stage = 1
local stageWave = 1
local bossDefeated = false
---@type {stage:integer, stars:integer, rating:string, bonusScore:integer, bonusParts:integer, animAt:integer}|nil
local stageResult = nil   -- stagewin 鎬佸睍绀轰笌瀛樻。鐢紙鏄熺骇/璇勭骇/杩囨浮璧峰鏃跺埢锛?
local elapsed = 0
local waveCooldown = 0
-- v0.13.26锛氬悓娉㈤敊宄扮敓鎴愮姸鎬侊紙鍓╀綑鏋舵暟/涓嬫璁℃椂/鏈尝鏈哄瀷涓庣爾鍧楀弬鏁帮級銆?
-- 鈿狅笍 鏀惰繘涓€寮犺〃锛欸ame.lua 椤跺眰 local 宸查€艰繎 Lua 200 涓婇檺锛圓B-154 鍚屾棌锛夛紝绂佹鍐嶅姞鏁ｈ椤跺眰 local銆?
local pendingSpawn = { remaining = 0, timer = 0, key = nil, brickSize = 0, hp = 1, speed = 0, kind = nil, lane = 0, spawned = 0 }
local INTRO_SECONDS = 4.5
-- v0.13.24锛氳繘鍏冲噯澶囨湡锛堢锛夈€?0 鏃剁帺娉曞喕缁擄細涓嶆帹杩涘脊鐝?鏁屾満/娉㈡锛屽彧鏀捐琛ㄧ幇灞傚姩鐢汇€?
local introTimer = 0
-- 鏈眬鏄惁鎴愬姛鍙戝皠杩囧脊鐝犮€傜敤浜庛€屾柊鎵嬩笅鎷夋墜鍔挎彁绀恒€嶏細鐜╁杩樻病鍋氳繃浠讳綍鎿嶄綔鏃跺惊鐜挱鏀俱€?
local hasLaunched = false
---@type NextWavePlan|nil
local nextWavePlan = nil

-- 骞稿瓨鑰呮垚闀跨姸鎬?
local playerLevel = 1
local xp = 0
local xpToNext = BASE_XP_TO_NEXT
local pendingLevelUps = 0          -- 寰呭鐞嗙殑鍗囩骇娆℃暟锛堟殏鍋滈€夊己鍖栵級
local deferredXp = 0               -- 鍗囩骇瑙﹀彂鍚屽抚鍚庣画鍑荤缁忛獙鍘熷€硷紝瀹屾垚閫夊崱鍚庣粨绠?
---@type UpgradeDef[]|nil
local upgradeChoices = nil         -- 褰撳墠鍙€夌殑涓夊紶鍗囩骇鍊欓€?
local upgradePicks = {}            -- 宸查€夊己鍖栫殑绱鏁堟灉锛坕d 鍒楄〃锛屽彲閲嶅锛?
local upgradeStacks = {}           -- 宸查€夊己鍖栧悇 id 鐨勫眰鏁帮紙WO-09/P5 鍙犲姞涓婇檺鍒ゅ畾锛?
-- P11锛氬凡婵€娲昏瘝鏉★紙鏉ヨ嚜涓撳睘璇嶆潯鍗囩骇锛夛紝浣滀负鏂板脊鐝犵殑榛樿璇嶆潯绗€傝鍒欏眰鎸佹湁锛屾覆鏌撳眰鍙蹇収銆?
local activeWords = {}
local clearStreak = 0              -- 杩炵画娓呯┖椋炶埞鐨勮繛鍑伙紙缁忛獙鍔犳垚锛?
local bricksBroken = 0            -- 绱鍑荤鐮栧潡鏁帮紙WO-11/P8 gameover 鍥為【锛?
local previousHighScore = 0      -- 鏈眬寮€灞€鏃剁殑鏈€楂樼邯褰曪紙鏂扮邯褰曟彁绀轰粎涓庢鍩哄噯姣旇緝锛?

-- v0.11.0 鍟嗕笟鍖栵細灞€鍐呴浂浠朵骇鍑轰笌鍗囩骇闈㈡澘鍙樼幇鐘舵€侊紙鍧囦负鍗曞眬鐢熷懡鍛ㄦ湡锛夈€?
local partsEarned = 0              -- 鏈眬绱鑾峰緱鐨勩€岄浂浠躲€嶏紝缁撶畻鏃剁敱缂栨帓灞傚叆搴?
local runAircraft = {}             -- 鏈眬娓呮帀杩囩殑鏈哄瀷鍜屽敮涓€鍒楄〃锛堢粨绠楁椂瑙ｉ攣鍥鹃壌锛?
local partsSettled = false         -- 褰撳墠鎴樻枟闃舵闆朵欢鏄惁宸插叆搴?
local partsDoubled = false         -- 鏈眬鏄惁宸茬敤骞垮憡缈诲€嶏紙姣忓眬涓€娆★級
local lastSettledParts = 0         -- 鏈€杩戜竴娆＄粨绠楀疄闄呭叆搴撴暟
local settledParts = 0             -- 宸叉寜鍩虹鍊嶇巼鍏ュ簱鐨勭疮璁￠浂浠讹紙澶嶆椿鍚庡彧琛ュ閲忥級
-- 缁撶畻璐︽湰锛坴0.14.x 瀛橀挶缃愶級锛歜ricks=宸茶鍏ヨ法灞€缁熻鐨勫嚮纰庢暟锛況unCounted=鏈眬鏄惁宸茶瀹屾垚锛?
-- gear=鏈眬绱銆岄娇杞€嶏紙200 鍧?/ 100 榻胯疆锛岀簿鑻辨満姣忓潡鎸?2 鍊嶈锛夛紱gearSettled=宸插叆搴撻娇杞紙澶嶆椿鍚庡彧琛ュ閲忥級銆?
local settleBook = { bricks = 0, runCounted = false, gear = 0, gearSettled = 0 }
local upgradeRerollFreeUsed = 0    -- 鏈眬宸茬敤鍏嶈垂閲嶆娊娆℃暟锛堜笂闄?= 1 + 澶╄祴銆屽厤璐瑰埛鏂般€嶅姞鎴愶級
local heldUpgradeId = nil          -- 鏈眬淇濈暀鍒颁笅涓€娆″崌绾х殑鍊欓€夊崱 id锛堟渶澶氫竴寮狅級
local PANEL_CARD_COUNT = 3         -- 甯歌鍊欓€夋暟锛坴0.12.5 绮剧畝锛氶潰鏉夸笉鍐嶆湁瑙ｉ攣绗?4 寮狅級
-- 鏆傚仠琛ョ粰绔欙紙鐪嬪箍鍛婏紝鍗曞眬闄愰噺锛?
local pauseHealUsed = 0            -- 宸茬敤銆岄槻绾挎€ユ晳銆嶆鏁?
local pauseRareUsed = 0            -- 宸茬敤銆屼笅娆″己鍖栦繚搴曠█鏈夈€嶆鏁?
local pendingRareRoll = false      -- 涓嬫鎶藉崱寮哄埗绋€鏈夛紙鐢辨殏鍋滆ˉ缁欑珯璐拱锛?
-- v0.13.58锛氭殏鍋滆ˉ缁欑珯鐨勫父閲忔敹杩涗竴寮犺〃锛圙ame.lua 椤跺眰 local 閫艰繎 Lua 200 涓婇檺锛孉B-166锛夈€?
local PAUSE_SUPPLY = { healMax = 1, healAmount = 25, rareMax = 1 }
local EjectBrick
-- v0.13.58锛氶檮榄旀寕杞藉嚱鏁扳€斺€擟reateMarble锛堢害 500 琛岋級鍏堜簬鍏跺畾涔変娇鐢紝蹇呴』鍓嶅悜澹版槑锛圓B-100锛夈€?
local ApplyEnchantToMarble
local pauseOrbitalUsed = false
local pauseReloadUsed = false
local pausePartsBoostUsed = false
local partsBoostTime = 0

-- 骞稿瓨鑰呭崌绾у己鍖栨睜锛圵O-09/P5锛夛細
-- weight 鎶藉崱鏉冮噸锛況arity 绋€鏈夊害锛坈ommon/rare/epic锛夛紱maxStacks 鍙犲姞涓婇檺锛?
-- tradeoff 鏄惁鎶夋嫨鍨嬶紙apply 鍚屾椂鏀规璐燂級锛泇alue 鍗曟澧為噺锛堢敤浜庡崌绾у崱 delta 棰勮锛夈€?
-- apply(stacks) 鎺ユ敹褰撳墠宸查€夊眰鏁帮紝鏀寔杈归檯閫掑噺锛堝 damage 姣忓眰鐣ュ噺锛夈€?
-- apply() 鍙敼 BALL_TUNING / baseHp锛堣鍒欏眰锛夛紝UI 鍙 GetSnapshot().upgradeChoices銆?
-- detail 涓哄ぉ璧嬪崱璇︽儏鎻忚堪锛堣嚜鍔ㄦ崲琛屽睍绀猴級锛泇alue 鏄崟娆″閲忓窘鏍囷紱tradeoff=鎶夋嫨鍨嬮闄┿€?
---@class UpgradeDef
---@field id string
---@field name string
---@field desc string
---@field detail string
---@field weight number
---@field rarity string
---@field maxStacks integer
---@field tradeoff boolean
---@field value string
---@field kind string|nil
---@field ballType string|nil 浠呭搴旇溅鍨嬪彲鐢ㄧ殑寮哄寲
---@field unlockBallType string|nil 鏈В閿佹椂鎵嶈繘鍏ュ崱姹犵殑杞﹀瀷瑙ｉ攣鍗?
---@field requiresCard string|nil 闇€澶╄祴鏍戣В閿佺殑閫氱敤鍗?id锛坸p/ammo锛夛紱鏈В閿佷笉杩涘崱姹?
---@field kind string|nil "base"=杞﹁В閿佸嵆鍙娊鐨勫熀纭€鍗★紱鍏朵綑甯?ballType 鐨勪负銆屼笓灞炲崱銆嶏紝闇€ ballCard 鑺傜偣
---@field apply fun(stacks: integer)

local UnlockBallType -- 瑙ｉ攣鍗″厛浜庤ˉ寮瑰嚱鏁板０鏄庯紝搴旂敤鏃跺啀璋冪敤瑙勫垯灞傚嚱鏁?
local IncreaseAmmo   -- 銆屽脊鑽墿瀹广€嶅悓涓婏細鍗℃睜鍏堝畾涔夛紝apply 鏃跺啀璋冪敤瑙勫垯灞傚嚱鏁?
-- v0.13.28锛歳epair 鍗＄殑 apply 闂寘浼氳鐢熷懡涓婇檺锛涜鍑芥暟瀹氫箟鍦ㄥ崱姹犱箣鍚庯紝
-- 蹇呴』鍓嶅悜澹版槑锛屽惁鍒欓棴鍖呰В鏋愭垚鍏ㄥ眬 nil锛圓B-100 鍚屾棌锛夈€?
local GetMaxBaseHp

-- v0.13.5 澶╄祴鏍戞淳鐢熺姸鎬侊細蹇呴』鍦?UPGRADE_POOL 涔嬪墠澹版槑鈥斺€攔epair 鍗＄殑 apply 闂寘浼氳琛€閲忓姞鎴愩€?
---@type table<string, boolean>
local talentOwned = {}
local talentMaxHpBonus = 0     -- 宸茶В閿佽妭鐐规暟 脳 姣忚妭鐐硅閲忓姞鎴?
local talentPartsPct = 0       -- 缁撶畻闆朵欢鐧惧垎姣斿姞鎴愶紙鏉ヨ嚜閫氱敤绾胯矾闈炲崱鑺傜偣锛?
local talentBallStats = {}     -- 杞︾嚎璺暟鍊煎寮猴細ballType -> {stat, value, mul}
local talentUnlockedCards = {} -- 澶╄祴瑙ｉ攣鐨勯€氱敤鍗?id 闆嗗悎锛坸p / ammo锛?
local talentUnlockedBalls = {} -- 澶╄祴瑙ｉ攣鐨勮溅锛堝眬鍐呭嚭鍦鸿祫鏍硷級
-- v0.13.16锛氬ぉ璧嬭В閿佺殑銆屼笓灞炲崱銆嶈祫鏍硷紙ballCard 鑺傜偣锛屾寜杞﹀瀷锛夈€?
-- 鈿狅笍 涔嬪墠杩欎釜鑺傜偣鍙瓨鍦ㄤ簬鐩綍閲屻€佽鍒欏眰浠庢湭娑堣垂 鈫?涓撳睘鍗″彧瑕佽溅瑙ｉ攣灏辫兘鎶斤紝
-- 澶╄祴鏍戠殑銆岃В閿佷笓灞炲崱銆嶈妭鐐规槸瑁呴グ銆傜幇鍦ㄤ笓灞炲崱蹇呴』**鍏堣В閿佽鑺傜偣**鎵嶈繘姹犮€?
local talentUnlockedBallCards = {}
-- v0.13.15锛氭垚闀跨嚎澶╄祴鈥斺€旀毚鍑荤巼锛?..1锛変笌鍩虹鏀诲嚮鍔犳垚銆?
local talentCritChance = 0
local talentAtkBonus = 0
-- v0.13.64锛氶€氱敤鍗＄嚎銆屽厤璐瑰埛鏂?+1銆嶈妭鐐光€斺€旀瘡瑙ｉ攣涓€涓紝姣忓眬鍏嶈垂閲嶆娊娆℃暟 +1銆?
local talentRerollBonus = 0
-- 鈿狅笍 鏈枃浠堕《灞?local 宸?199/200锛圓B-166 纭笂闄愶級锛屽厤璐归噸鎶芥€绘暟璧?Game 琛ㄥ瓧娈?
-- 锛堣〃瀛楁涓嶅崰椤跺眰 local 妲斤紱璋冪敤鐐瑰湪鍑芥暟浣撳唴锛岃繍琛屾湡瑙ｆ瀽锛屾棤鍓嶅悜寮曠敤闂锛夈€?
---@type fun(): table<string, boolean>|nil
local talentProvider = nil     -- 缂栨帓灞傛敞鍏ワ紱ResetGame 鏃舵媺鍙栨渶鏂拌В閿侀泦鍚?

---@type UpgradeDef[]
local UPGRADE_POOL = {
    -- v0.13.28 閫氱敤鍗￠噸鍋氾紙鐢ㄦ埛鐐瑰悕銆屽父椹婚€氱敤鍗″湪鍏? 姣棤甯姪銆嶏級锛?
    -- 鏃?damage銆屼激瀹?+1銆嶅湪鍏?~3锛堢爾鍧?1 琛€锛夋槸绾孩鍑恒€乺epair/armor 鍦ㄥ嚑涔庝笉鎺夎鐨勫墠鏈熺┖杞€?
    -- 鍥涘紶鍗℃敼涓烘寕鍦?*浣庨毦搴︿篃鐪熷疄瀛樺湪鐨勫彉閲?*涓婏細缁忛獙 / 鐢熷懡涓婇檺 / 闆朵欢浜у嚭 / 鍙戝皠鍒濋€熴€?
    { id = "damage", name = "绌跨敳寮瑰ご", desc = "鎵€鏈夊脊鐝犱激瀹?+1锛屽嚮纰庨澶?+1 缁忛獙",
      detail = "寮圭彔浼ゅ +1锛屾瘡鍑荤涓€鍧楀 +1 缁忛獙銆?,
      weight = 1, rarity = "common", maxStacks = 8, tradeoff = false, value = "+1 浼ゅ / +1 缁忛獙",
      apply = function(stacks)
          BALL_TUNING.damageBonus = BALL_TUNING.damageBonus + 1
          BALL_TUNING.brickXpFlat = BALL_TUNING.brickXpFlat + 1
      end },
    -- v0.13.55 杞﹀瀷銆屼笓灞炲崱銆? 鏀规満鍒讹紱瀵瑰簲鐨勩€屽熀纭€鍗°€嶏紙base_*锛岃涓嬫柟锛夊彧缁欎富灞炴€ф墦搴曟暟鍊笺€?
    -- 鏃х増涓撳睘鍗′笌鍩虹鍗￠兘鍙敼鍚屼竴涓?BALL_TUNING 瀛楁銆佸彧鏄暟瀛楁洿澶?鈫?鍥涙潯鍏紡鍚勫啓涓ら亶銆?
    { id = "giant", name = "鍐插嚮娉?, desc = "鑼冨洿鍑荤 15% 姒傜巼閫犳垚鍙屽€嶄激瀹?,
      detail = "鑼冨洿鍑荤 15% 姒傜巼鍙屽€嶄激瀹炽€?,
      weight = 0.6, rarity = "rare", maxStacks = 3, tradeoff = false, value = "+15% 鑼冨洿鏆村嚮", ballType = "giant",
      apply = function(stacks) BALL_TUNING.giantCritChance = BALL_TUNING.giantCritChance + 0.15 end },
    { id = "split", name = "瑁傚彉鏍?, desc = "鍒嗚鏃堕澶栦骇鍑?1 棰楀皬寮?,
      detail = "姣忔鍒嗚澶氫骇 1 棰楀皬寮广€?,
      weight = 0.6, rarity = "rare", maxStacks = 2, tradeoff = false, value = "+1 鍒嗚鏁?, ballType = "normal",
      apply = function(stacks) BALL_TUNING.splitCount = BALL_TUNING.splitCount + 1 end },
    { id = "speed", name = "鍔ㄨ兘绌垮埡", desc = "椋炶涓彲绌块€?1 鍧椾笉鍙嶅脊",
      detail = "椋炶涓┛閫?1 鍧楃户缁銆?,
      weight = 0.6, rarity = "rare", maxStacks = 3, tradeoff = false, value = "绌块€?+1 鍧?, ballType = "speed",
      apply = function(stacks) BALL_TUNING.speedPierce = BALL_TUNING.speedPierce + 1 end },
    { id = "ice", name = "闇滆娑傚眰", desc = "鍐荤粨涓殑鏁屾満鍙楀嚮浼ゅ +30%",
      detail = "鍐荤粨涓殑鏁屾満鍙楀嚮 +30%銆?,
      weight = 0.6, rarity = "rare", maxStacks = 3, tradeoff = false, value = "+30% 纰庡啺浼ゅ", ballType = "ice",
      apply = function(stacks) BALL_TUNING.iceShatter = BALL_TUNING.iceShatter + 0.30 end },
    -- v0.13.28锛氭敼涓恒€岀敓鍛戒笂闄?+12 涓旂珛鍗冲洖 12銆嶁€斺€斾綆闅惧害涓嶆帀琛€鏃朵篃鏈?*姘镐箙**鏀剁泭锛堜笉鍐嶆槸绌鸿繃涓€杞級銆?
    { id = "repair", name = "鍓嶇嚎缁翠慨", desc = "鐢熷懡涓婇檺 +12锛屽苟绔嬪嵆鍥炲 12",
      detail = "鐢熷懡涓婇檺姘镐箙 +12锛岀珛鍒诲洖 12 鐐广€?,
      weight = 1, rarity = "common", maxStacks = 99, tradeoff = false, value = "+12 涓婇檺 / +12 鐢熷懡",
      apply = function(stacks)
          BALL_TUNING.maxHpBonus = BALL_TUNING.maxHpBonus + 12
          baseHp = math.min(GetMaxBaseHp(), baseHp + 12)
      end },
    -- v0.13.28锛氭敼涓恒€岀櫨鍒嗘瘮鍑忎激 + 闆朵欢浜у嚭 +8%/绾с€嶁€斺€斿叧1 鍗曡瓒婄嚎浼ゅ琚挸鎴?1锛屾棫 -1 鍑忎激瀹屽叏鏃犳晥锛?
    -- 鐧惧垎姣斿噺浼ゅ湪鍗曡涔熶細鐢熸晥锛屼笖闆朵欢鍔犳垚涓庨毦搴︽棤鍏炽€佺涓€鍏冲氨鐪嬪緱瑙併€?
    { id = "armor", name = "瑁呯敳寮哄寲", desc = "闃茬嚎鍙楀垱 -20%锛岄浂浠朵骇鍑?+8%",
      detail = "姣忔鍙楀垱灏?20%锛岄浂浠?+8%銆?,
      weight = 1, rarity = "common", maxStacks = 3, tradeoff = false, value = "-20% 鍙楀垱 / +8% 闆朵欢",
      apply = function(stacks)
          BALL_TUNING.armorReduce = BALL_TUNING.armorReduce + 0.20
          BALL_TUNING.partsMul = BALL_TUNING.partsMul + 0.08
      end },
    { id = "xp", name = "鏁版嵁鍥炴敹", desc = "缁忛獙鑾峰彇 +20%",
      detail = "缁忛獙 +20%锛屽崌绾ф洿蹇€?,
      weight = 1, rarity = "common", maxStacks = 5, tradeoff = false, value = "+20% 缁忛獙",
      requiresCard = "xp",
      apply = function(stacks) BALL_TUNING.xpMul = BALL_TUNING.xpMul + 0.2 end },
    -- WO-09/P5 鎶夋嫨鍨嬶細鍚屾椂鏀规璐熻鍒欏彉閲忥紝楂橀闄╅珮鍥炴姤锛堜粛鍙敼 BALL_TUNING/baseHp锛夈€?
    -- v0.13.28锛氫激瀹?+2鈫?3锛屽苟杩藉姞銆屽彂灏勫垵閫?+10%/绾с€嶁€斺€斾綆闅惧害鐮栧潡 1 琛€鏃讹紝浼ゅ婧㈠嚭浣?*寮归€?*绔嬪埢鏈夋劅銆?
    { id = "glass_cannon", name = "鐜荤拑宸ㄧ偖", desc = "浼ゅ +3銆佸脊閫?+10%锛屼絾瓒婄嚎浼ゅ +1",
      detail = "浼ゅ +3銆佸脊閫?+10%锛屼絾琚挒澶氭帀 1 鐐广€?,
      weight = 0.6, rarity = "rare", maxStacks = 3, tradeoff = true, value = "浼ゅ+3 / 寮归€?10% / 鍙楀垱+1",
      apply = function(stacks)
          BALL_TUNING.damageBonus = BALL_TUNING.damageBonus + 3
          BALL_TUNING.launchSpeedMul = BALL_TUNING.launchSpeedMul * 1.10
          BALL_TUNING.lineDamageBonus = BALL_TUNING.lineDamageBonus + 1
      end },
    { id = "overclock", name = "瓒呰浇鏍稿績", desc = "鍔犻€熻溅鍔犻€熷害 +15%锛屽熀鍦?-8",
      detail = "鍔犻€熻溅鍔犻€熸洿蹇紝浣?-8 鐢熷懡銆?,
      weight = 0.6, rarity = "rare", maxStacks = 3, tradeoff = true, value = "鍔犻€熷害+15% / 鐢熷懡-8", ballType = "speed",
      apply = function(stacks)
          BALL_TUNING.speedMul = BALL_TUNING.speedMul * 1.15
          baseHp = math.max(1, baseHp - 8)
      end },
    -- v0.13.19锛氬洓杞﹂兘鑳介潬灞€鍐呭崱瑙ｉ攣銆傚垵濮嬭溅鏄姞閫熻溅锛堣 STARTING_BALL_TYPE锛夛紝
    -- 鎵€浠ャ€岃В閿佸垎瑁傝溅銆嶄篃杩涙睜锛涘姞閫熻溅鑷繁宸茶В閿侊紝鍏惰В閿佸崱鐢?unlockBallType 闂ㄦ帶鑷姩閫€姹犮€?
    { id = "unlock_normal", name = "瑙ｉ攣鍒嗚杞?, desc = "鍒嗚杞﹀姞鍏ユ湰灞€寮硅嵂闃熷垪",
      detail = "瑙ｉ攣鍒嗚杞︼紝鍛戒腑鍚庡垎瑁傚皬寮广€?,
      weight = 1.4, rarity = "common", maxStacks = 1, tradeoff = false, value = "鍒嗚杞﹀叆闃?,
      kind = "unlock", unlockBallType = "normal",
      apply = function(stacks) UnlockBallType("normal") end },
    { id = "unlock_ice", name = "瑙ｉ攣鍐板喕杞?, desc = "鍐板喕杞﹀姞鍏ユ湰灞€寮硅嵂闃熷垪",
      detail = "瑙ｉ攣鍐板喕杞︼紝鍛戒腑鍙喕缁撴晫鏈恒€?,
      weight = 1.4, rarity = "common", maxStacks = 1, tradeoff = false, value = "鍐板喕杞﹀叆闃?,
      kind = "unlock", unlockBallType = "ice",
      apply = function(stacks) UnlockBallType("ice") end },
    { id = "unlock_speed", name = "瑙ｉ攣鍔犻€熻溅", desc = "鍔犻€熻溅鍔犲叆鏈眬寮硅嵂闃熷垪",
      detail = "瑙ｉ攣鍔犻€熻溅锛屽弽寮瑰悗瓒婅窇瓒婂揩銆?,
      weight = 1.4, rarity = "common", maxStacks = 1, tradeoff = false, value = "鍔犻€熻溅鍏ラ槦",
      kind = "unlock", unlockBallType = "speed",
      apply = function(stacks) UnlockBallType("speed") end },
    { id = "unlock_giant", name = "瑙ｉ攣宸ㄥ瀷杞?, desc = "宸ㄥ瀷杞﹀姞鍏ユ湰灞€寮硅嵂闃熷垪",
      detail = "瑙ｉ攣宸ㄥ瀷杞︼紝鍙嶅脊鍚庤寖鍥村嚮纰庛€?,
      weight = 1.4, rarity = "common", maxStacks = 1, tradeoff = false, value = "宸ㄥ瀷杞﹀叆闃?,
      kind = "unlock", unlockBallType = "giant",
      apply = function(stacks) UnlockBallType("giant") end },
    -- 閫氱敤寮硅嵂鍗★細闇€澶╄祴鏍戣В閿侊紙3 闃堕€氱敤鍗¤妭鐐癸級鍚庢墠浼氳繘鍏ュ崱姹犮€?
    { id = "ammo", name = "寮硅嵂鎵╁", desc = "鏈眬寮硅嵂鏁伴噺 +1",
      detail = "鏈眬寮硅嵂鏁伴噺 +1銆?,
      weight = 1, rarity = "common", maxStacks = 3, tradeoff = false, value = "+1 寮硅嵂",
      requiresCard = "ammo",
      apply = function(stacks) IncreaseAmmo() end },
    -- v0.13.5 鍩虹澶╄祴姹犻噸鏋勶細鍥涜溅鍚勮ˉ涓€寮犮€屽熀纭€鏁板€笺€嶅崱锛堜笉渚濊禆瑙ｉ攣鍗★紝杞﹁В閿佸嵆鍙娊锛夈€?
    -- v0.13.55锛氬熀纭€鍗?= 璇ヨ溅涓诲睘鎬х殑**鎵撳簳鏁板€?*锛堝父鍑恒€佸彲鍙犻珮锛夛紝鏈哄埗宸紓浜ょ粰涓婇潰鐨勪笓灞炲崱銆?
    { id = "base_split", name = "鍒嗚澧炲箙", desc = "鍒嗚杞﹀垎瑁傛鐜?+2%",
      detail = "鍒嗚灏忚溅姒傜巼 +2%銆?,
      weight = 1, rarity = "common", maxStacks = 5, tradeoff = false, value = "+2% 姒傜巼",
      ballType = "normal", kind = "base",
      apply = function(stacks) BALL_TUNING.splitBonus = BALL_TUNING.splitBonus + 0.02 end },
    { id = "base_ice", name = "瀵掕兘鎵╂暎", desc = "鍐板喕鏃堕暱 +0.5 绉?,
      detail = "鍐板喕鏃堕棿 +0.5 绉掋€?,
      weight = 1, rarity = "common", maxStacks = 5, tradeoff = false, value = "+0.5 绉?,
      ballType = "ice", kind = "base",
      apply = function(stacks) BALL_TUNING.iceBonus = BALL_TUNING.iceBonus + 0.5 end },
    { id = "base_speed", name = "寮曟搸璋冩牎", desc = "鍔犻€熻溅鍔犻€熷害 +4%",
      detail = "鍔犻€熻溅鍔犻€熸洿蹇€?,
      weight = 1, rarity = "common", maxStacks = 5, tradeoff = false, value = "+4% 鍔犻€熷害",
      ballType = "speed", kind = "base",
      apply = function(stacks) BALL_TUNING.speedMul = BALL_TUNING.speedMul * 1.04 end },
    { id = "base_giant", name = "寮逛綋澧為噸", desc = "宸ㄥ瀷杞﹁疮绌胯寖鍥?+0.5 鏍?,
      detail = "宸ㄥ瀷杞︾垎鐐歌寖鍥?+0.5 鏍笺€?,
      weight = 1, rarity = "common", maxStacks = 5, tradeoff = false, value = "+0.5 鏍?,
      ballType = "giant", kind = "base",
      apply = function(stacks) BALL_TUNING.giantArea = BALL_TUNING.giantArea + 0.5 end },
    -- 閫氱敤鍗★紙鏃犺溅鍨嬶級锛氬叏閮ㄩ渶澶╄祴鏍戣В閿佸搴旇妭鐐规墠杩涘眬鍐呭崱姹犮€?
    -- v0.13.21锛氳瘝鏉″崱褰掑叆閫氱敤鍗♀€斺€旀鍓嶅畠浠棤浠讳綍闂ㄦ帶銆佸紑灞€甯搁┗锛堢敤鎴风偣鍚嶏級銆?
    { id = "word_pierce", name = "璐┛寮硅姱", desc = "寮圭彔闄勫甫璐┛鏁堟灉",
      detail = "寮圭彔绌块€忕涓€鍧楃户缁銆?,
      weight = 0.5, rarity = "rare", maxStacks = 1, tradeoff = false, value = "璐┛",
      kind = "word", requiresCard = "word_pierce",
      apply = function(stacks) activeWords.pierce = true end },
    { id = "word_chain", name = "杩為攣寮?, desc = "寮圭彔闄勫甫杩為攣婧呭皠",
      detail = "鍛戒腑鍚庢簠灏勫埌鏈€杩戝彟涓€鍧椼€?,
      weight = 0.5, rarity = "rare", maxStacks = 1, tradeoff = false, value = "杩為攣",
      kind = "word", requiresCard = "word_chain",
      apply = function(stacks) activeWords.chain = true end },
    { id = "word_momentum", name = "鍔ㄩ噺鍔犻€?, desc = "寮圭彔瓒婂揩浼ゅ瓒婇珮",
      detail = "寮圭彔瓒婂揩锛屼激瀹宠秺楂樸€?,
      weight = 0.5, rarity = "rare", maxStacks = 1, tradeoff = false, value = "鍔ㄩ噺",
      kind = "word", requiresCard = "word_momentum",
      apply = function(stacks) activeWords.momentum = true end },
}

local veggies = {}
local marbles = {}
local ballQueue = {}
local activeBall = nil
local ballCycleIndex = 0
local aiming = false
local aimX = SLING_X
local aimY = SLING_Y
-- v0.10.24 閬楃暀锛氳彍鍗?缁撶畻鏉炬墜纭鐨勬瑁呮爣蹇椼€倂0.13.4 璧疯彍鍗曚笉鍐嶇洿鎺ュ紑灞€
-- 锛堟敼璧伴€夊叧鐣岄潰锛夛紝姝ゅ浠呬綔姝讳骸鐬棿闃茶瑙︾殑澶嶄綅瀹堝崼銆?
local startArmed = false
-- v0.10.32锛氭瘡灞€涓€娆″箍鍛婂娲伙紱缁撶畻椤垫寜閽敱缂栨帓灞傛秷璐瑰嚑浣曘€?
local reviveUsed = false
local REVIVE_HP = 50

local pendingEvents = {}
local nextEnemyId = 1
local nextMarbleId = 1
local randomState = 1

-- WO-16/P9锛氬揩鐓х紦鍐插鐢紝閬垮厤姣忓抚鏋勯€犳柊 table 瑙﹀彂 GC 鎶栧姩銆?
-- 娓叉煋/琛ㄧ幇灞傚彧璇绘琛紝涓嶅緱缂撳瓨寮曠敤瓒婅繃鏈抚銆?
local snapshotBuffer_ = nil

local ResetGame
local SpawnWave
local UpdateMarbles
local UpdateEnemies
local UpdateReload
local UpdateWaveLogic
local GainXp
local RollUpgradeChoices
local PlanWave
local EnsureNextWavePlan
-- v0.13.26锛氬悓娉㈤敊宄扮敓鎴?/ 绮捐嫳鎶よ埅寤惰繜閲婃斁锛圓B-100 鍓嶅悜寮曠敤锛氬０鏄庡厛浜庝娇鐢ㄧ偣锛夈€?
local ReleaseEscortVolley
local SpawnNextNormalEnemy

local function Emit(eventType, data)
    data = data or {}
    data.type = eventType
    table.insert(pendingEvents, data)
end

local function SetRandomSeed(seed)
    randomState = math.floor(tonumber(seed) or 1) % 2147483647
    if randomState <= 0 then randomState = 1 end
end

local function Random()
    randomState = (randomState * 16807) % 2147483647
    return (randomState - 1) / 2147483646
end

local function RandomInt(minValue, maxValue)
    return minValue + math.floor(Random() * (maxValue - minValue + 1))
end

local function GetBrickSize(waveNum)
    local currentStageWave = StageCatalog.GetStageWave(waveNum)
    if currentStageWave <= 2 then return 14 end
    if currentStageWave <= 4 then return 15 end
    return BASE_BRICK_SIZE
end

local function GetWaveParams(waveNum)
    local currentStage = StageCatalog.GetStage(waveNum)
    local currentStageWave = StageCatalog.GetStageWave(waveNum)
    return StageCatalog.GetNormalCount(currentStage, currentStageWave),
        StageCatalog.GetBaseSpeed(currentStage, currentStageWave),
        StageCatalog.GetBrickHp(currentStage, "normal")
end

-- 鍙寜瀛樻椿瀹炰緥璁＄畻鍚嶉锛屼笉鎸佹湁璺ㄥ抚璁℃暟鍣紱鍚屽抚棰勭敓鎴愪篃绔嬪嵆鍗犻绠椼€?
-- 搴撳瓨闃熷垪鍙湁杞﹀瀷閿紝灏氭湭鐢熸垚杞﹁締锛屼笉璁″叆鍚屾椂瀛樺湪鏁伴噺銆?
---@param pendingMarbles table[]|nil
---@return integer
function Game._NormalMarbleSlots(pendingMarbles)
    local count = 0
    if activeBall and activeBall.alive and activeBall.ballType == "normal" then
        count = count + 1
    end
    for _, marble in ipairs(marbles) do
        if marble.alive and marble.ballType == "normal" then count = count + 1 end
    end
    for _, marble in ipairs(pendingMarbles or {}) do
        if marble.alive and marble.ballType == "normal" then count = count + 1 end
    end
    return math.max(0, BALL_TYPES.normal.maxConcurrent - count)
end

local function CreateMarble(ballType, words)
    local def = BALL_TYPES[ballType]
    local marble = {
        id = nextMarbleId,
        x = SLING_X, y = SLING_Y,
        vx = 0, vy = 0,
        radius = def.radius,
        speed = def.speed,
        ballType = ballType,
        onSling = true,
        alive = true,
        bounceCount = 0,
        isPrimary = true,
        generation = 0,
        flightTime = 0,
        ignoredBrick = nil,
        giantPiercing = false,
        giantPiercePending = false, -- 鍐峰嵈涓彧淇濈暀鍙嶅脊璧勬牸锛屼笉浠ｈ〃宸茬粡鍙互璐┛
        giantAreaCooldown = 0,
        chargeBoosted = false,
        -- v0.13.64锛氭嫋灏鹃殢瀛樺湪鏃堕棿鍙樼煭鐢ㄧ殑銆岃瑙夊勾榫勩€嶏紱鍒嗚瀛愯溅缁ф壙姣嶈溅褰撳墠鍊硷紙缁ф壙闀垮害锛夈€?
        trailAge = 0,
        -- v0.13.55 鍔ㄨ兘绌垮埡锛氭湰寮瑰墿浣欑┛閫忔鏁帮紙姣忔绌块€忎笉鍙嶅脊銆佺洿鎺ュ悆涓嬪潡锛夈€?
        pierceLeft = BALL_TUNING.speedPierce,
        words = {},    -- P11锛氳瘝鏉′慨楗版寕杞借〃锛堣涓烘爣璁帮級锛岀┖琛ㄨ〃绀烘棤璇嶆潯
    }
    -- P11锛氭敞鍏ヨ瘝鏉★紙鏉ヨ嚜鍗囩骇鎴?Boss 鎺堜簣锛夛紝閫愪釜璋冪敤 apply() 鏀瑰啓 marble 琛屼负銆?
    if words then
        for _, wordId in ipairs(words) do
            local wordDef = BALL_WORDS[wordId]
            if wordDef then
                wordDef.apply(marble, wordDef)
                marble.words[wordId] = true
            end
        end
    end
    nextMarbleId = nextMarbleId + 1
    -- v0.13.58锛氫紭鍏堟秷璐广€岄『寤躲€嶇殑闄勯瓟鍗★紙浣跨敤闄勯瓟鍗℃椂娌℃湁寰呭彂杞?鈫?鎸傜粰涓嬩竴涓澶囧彂灏勭殑杞︼級銆?
    if Game._enchant.pending then
        local pendingCard = Game._enchant.pending
        Game._enchant.pending = nil
        ApplyEnchantToMarble(marble, pendingCard)
    end
    return marble
end

local function NextBallType()
    -- 鍥哄畾椤哄簭杞崲锛屼絾鍙骇鍑烘湰灞€宸茶В閿佺殑杞﹀瀷锛涘嵆浣夸粎鏈夊垵濮嬭溅涔熷缁堝彲琛ュ脊銆?
    for _ = 1, #BALL_ORDER do
        ballCycleIndex = ballCycleIndex % #BALL_ORDER + 1
        local ballType = BALL_ORDER[ballCycleIndex]
        if unlockedBalls[ballType] then return ballType end
    end
    return STARTING_BALL_TYPE
end

local function EnqueueNextBall()
    table.insert(ballQueue, NextBallType())
end

UnlockBallType = function(ballType)
    if not BALL_TYPES[ballType] or unlockedBalls[ballType] then return end
    unlockedBalls[ballType] = true
    -- 鎶婃柊杞︽斁杩涗笅涓€鍙戞Ы浣嶏紝涓嶆浛鎹㈠緟鍙戣溅锛屼篃涓嶄慨鏀瑰凡鍦ㄩ琛屼腑鐨勮溅杈嗐€?
    table.insert(ballQueue, 1, ballType)
    print("[Game] ball unlocked: " .. ballType .. ", queued=" .. #ballQueue)
end

-- 銆屽脊鑽墿瀹广€嶏細鏈眬寮硅嵂鎬婚噺 +1锛屽苟绔嬪埢琛ヤ竴杈嗚繘澶囧脊闃熷垪锛?
-- 涔嬪悗涓荤悆鍥炴敹浠嶆寜銆屽洖鏀朵竴杈嗚ˉ涓€杈嗐€嶇淮鎸佹柊鎬婚噺銆?
IncreaseAmmo = function()
    ammoCapacity = ammoCapacity + 1
    EnqueueNextBall()
    print("[Game] ammo capacity -> " .. ammoCapacity)
end

-- P11锛氭妸 activeWords 瑙勫垯琛ㄥ睍寮€涓烘湁搴忚瘝鏉?id 鍒楄〃锛屼緵 CreateMarble 娉ㄥ叆銆?
local function CollectActiveWords()
    local list = {}
    for _, id in ipairs(WORD_IDS) do
        if activeWords[id] then list[#list + 1] = id end
    end
    return list
end

local function LoadBalls()
    ballQueue = {}
    ballCycleIndex = 0
    -- 鍏堟斁 1 杈嗗緟鍙戯紝鍐嶆帓鍏?ammoCapacity-1 杈嗗寮癸紙銆屽脊鑽墿瀹广€嶅崌绾т細鎻愰珮鎬婚噺锛夈€?
    activeBall = CreateMarble(NextBallType(), CollectActiveWords())
    for _ = 1, ammoCapacity - 1 do EnqueueNextBall() end
end

local function CanOfferUpgrade(u)
    -- v0.13.16锛氬甫 ballType 涓旈潪 base 鐨勫崱鏄€屼笓灞炲崱銆嶁€斺€斿繀椤诲ぉ璧嬫爲瑙ｉ攣浜?
    -- 璇ヨ溅鍨嬬殑銆屼笓灞炲崱銆嶈妭鐐规墠杩涙睜锛坆ase 鍗″彧闇€杞﹁В閿侊級銆?
    local ballOk = (not u.ballType) or unlockedBalls[u.ballType] == true
    if ballOk and u.ballType and u.kind ~= "base" then
        ballOk = talentUnlockedBallCards[u.ballType] == true
    end
    -- v0.13.20锛氬眬鍐呫€岃В閿伱椕楄溅銆嶅崱**蹇呴』澶╄祴鏍戝厛瑙ｉ攣璇ヨ溅**鎵嶈繘姹狅紙鐢ㄦ埛婢勬竻锛夈€?
    -- 鍗筹細澶╄祴鏍戣В閿佽溅 鈮?寮€灞€鑳界敤璇ヨ溅锛岃€屾槸銆屽眬鍐呮墠浼氬嚭鐜拌繖寮犺В閿佸崱銆嶏紱
    -- 鏈湪澶╄祴鏍戣В閿佺殑杞︼紝灞€鍐呮棦涓嶅嚭瀹冪殑瑙ｉ攣鍗°€佷篃涓嶅嚭瀹冪殑 base/涓撳睘鍗°€?
    if ballOk and u.unlockBallType then
        ballOk = talentUnlockedBalls[u.unlockBallType] == true
    end
    return ballOk
        and (not u.unlockBallType or unlockedBalls[u.unlockBallType] ~= true)
        and (not u.requiresCard or talentUnlockedCards[u.requiresCard] == true)
        and (upgradeStacks[u.id] or 0) < u.maxStacks
end

-- v0.13.5锛氱紪鎺掑眰寮€灞€鍓嶆敞鍏ュぉ璧嬫爲瑙ｉ攣闆嗗悎锛涙妸鑺傜偣 id 姹囨€绘垚瑙勫垯灞傚彲鐢ㄧ殑鍔犳垚銆?
-- 骞傜瓑锛氬彲澶氭璋冪敤锛堟瘡娆￠噸绠楁淳鐢熷€硷級銆傚紑灞€鍓嶈皟鐢ㄤ竴娆″嵆鍙€?
---@param owned table<string, boolean>|nil
function Game.SetTalents(owned)
    talentOwned = {}
    talentMaxHpBonus = 0
    talentPartsPct = 0
    talentBallStats = {}
    talentUnlockedCards = {}
    talentUnlockedBalls = {}
    talentUnlockedBallCards = {}
    talentCritChance = 0
    talentAtkBonus = 0
    talentRerollBonus = 0
    if type(owned) ~= "table" then return end
    local count = 0
    for id, v in pairs(owned) do
        if v then
            talentOwned[id] = true
            local node = TalentCatalog.GetNode(id)
            if node then
                count = count + 1
                if node.kind == "cardUnlock" then
                    talentUnlockedCards[node.cardId] = true
                elseif node.kind == "ballUnlock" then
                    talentUnlockedBalls[node.ballType] = true
                elseif node.kind == "ballCard" then
                    -- 涓撳睘鍗¤祫鏍硷紙鎸夎溅鍨嬶級锛氭湭瑙ｉ攣璇ヨ妭鐐瑰垯涓撳睘鍗′笉杩涙睜銆?
                    talentUnlockedBallCards[node.ballType] = true
                elseif node.kind == "partsPct" then
                    talentPartsPct = talentPartsPct + (node.value or 0)
                elseif node.kind == "rerollPlus" then
                    -- v0.13.64锛氭瘡灞€鍏嶈垂閲嶆娊娆℃暟 +N锛堝彲鍙犲姞锛夈€?
                    talentRerollBonus = talentRerollBonus + (node.value or 0)
                elseif node.kind == "stat" then
                    if node.stat == "critChance" then
                        -- 鎴愰暱绾匡細鏆村嚮鐜囩疮鍔狅紱姣?3 闃惰繕棰濆缁欏熀纭€鏀诲嚮銆?
                        talentCritChance = talentCritChance + (node.value or 0)
                        talentAtkBonus = talentAtkBonus + (node.atkBonus or 0)
                    else
                        local acc = talentBallStats[node.ballType]
                        if not acc then
                            acc = { stat = node.stat, mul = node.mul == true, add = 0, factor = 1.0 }
                            talentBallStats[node.ballType] = acc
                        end
                        if node.mul then acc.factor = acc.factor * (node.value or 1.0)
                        else acc.add = acc.add + (node.value or 0) end
                    end
                end
            end
        end
    end
    talentMaxHpBonus = count * TalentCatalog.MAX_HP_PER_NODE
    local cardCount, ballCount = 0, 0
    for _ in pairs(talentUnlockedCards) do cardCount = cardCount + 1 end
    for _ in pairs(talentUnlockedBalls) do ballCount = ballCount + 1 end
    print(string.format("[Game] talents applied: nodes=%d hpBonus=%d partsPct=%d%% cards=%d balls=%d",
        count, talentMaxHpBonus, talentPartsPct, cardCount, ballCount))
end

-- 鏈眬鍩哄湴鐢熷懡涓婇檺 = 鍩虹 + 澶╄祴琛€閲忓姞鎴?+ 灞€鍐呫€屽墠绾跨淮淇€嶇殑姘镐箙涓婇檺鍔犳垚銆?
GetMaxBaseHp = function()
    return BASE_HP + talentMaxHpBonus + BALL_TUNING.maxHpBonus
end

-- 渚涚晫闈㈣鍙栵細褰撳墠娉ㄥ叆澶╄祴娲剧敓鍑虹殑鍔犳垚鎽樿锛堝彧璇伙級銆?
---@return {hpBonus:integer, partsPct:integer, nodeCount:integer}
function Game.GetTalentBonuses()
    local n = 0
    for _ in pairs(talentOwned) do n = n + 1 end
    return {
        hpBonus = talentMaxHpBonus, partsPct = talentPartsPct, nodeCount = n,
        critChance = talentCritChance, atkBonus = talentAtkBonus,
    }
end

-- v0.13.5锛氱紪鎺掑眰娉ㄥ唽涓€娆″ぉ璧嬫彁渚涜€咃紱姣忔 ResetGame锛堝惈閫夊叧/涓嬩竴鍏?閲嶅紑锛夎嚜鍔ㄩ噸鏂版媺鍙栵紝
-- 閬垮厤鍦ㄥ涓紑灞€鍏ュ彛鍚勫啓涓€娆℃敞鍏ャ€?
---@param provider fun(): table<string, boolean>
function Game.SetTalentProvider(provider)
    talentProvider = provider
end

-- 鍙彇娑堝€嶉€燂紝涓嶇Щ鍔ㄥ緟鍙戣溅锛涚湡瀹炲彂灏勫繀椤讳繚鐣欐媺寮撳悗鐨勫嚭鐢熺偣銆?
function Game.CancelHoldSpeed()
    if Game._holdSpeed.active then print("[Game] hold speed -> 1x") end
    Game._holdSpeed.down = false
    Game._holdSpeed.active = false
    Game._holdSpeed.time = 0
    Game._holdSpeed.epoch = Game._holdSpeed.epoch + 1
end

function Game.CancelPointer()
    Game.CancelHoldSpeed()
    Game.ClearLaunchCharge()
    aiming = false
    startArmed = false
    if activeBall then
        activeBall.x = SLING_X
        activeBall.y = SLING_Y
    end
end

function Game.CanHoldSpeed()
    return gameState == "playing" and introTimer <= 0 and not aiming and activeBall == nil
end

-- startStage锛氶€夊叧鐣岄潰鎸戦€夌殑鍏冲崱锛坴0.13.4锛夈€傞粯璁?1锛泈ave 鎹㈢畻涓哄叏灞€绱娉㈠彿锛?
-- 浣挎瘡鏃ヤ换鍔°€屾姷杈剧 N 娉€嶅湪鍚庢湡鍏冲崱浠嶆寜鐪熷疄杩涘害璁￠噺銆?
ResetGame = function(startStage)
    Game.CancelPointer()
    startStage = math.max(1, math.floor(tonumber(startStage) or 1))
    -- v0.13.5锛氭瘡娆″紑灞€閲嶆柊鎷夊彇澶╄祴瑙ｉ攣闆嗗悎锛屾淳鐢熷姞鎴愬湪鏈眬鐢熸晥銆?
    if talentProvider then Game.SetTalents(talentProvider()) end
    score = 0
    -- v0.13.28锛氬眬鍐呴€氱敤鍗″瓧娈靛繀椤诲湪 baseHp 涔嬪墠澶嶄綅鈥斺€斻€屽墠绾跨淮淇€嶇殑姘镐箙涓婇檺鍔犳垚
    -- 鍐欏湪 BALL_TUNING.maxHpBonus 閲岋紝鑻ユ櫄浜?GetMaxBaseHp 澶嶄綅锛屼細鎶婁笂涓€灞€鐨勪笂闄愬甫杩涙柊灞€銆?
    BALL_TUNING.armorReduce = 0
    BALL_TUNING.partsMul = 1.0
    BALL_TUNING.launchSpeedMul = 1.0
    BALL_TUNING.brickXpFlat = 0
    BALL_TUNING.maxHpBonus = 0
    baseHp = GetMaxBaseHp()
    stage = startStage
    stageWave = 1
    wave = (startStage - 1) * StageCatalog.WAVES_PER_STAGE + 1
    -- v0.13.46锛氳繘鍏ュ叧鍗℃椂鐢熸垚鏈叧闅忔満甯冨眬锛堢簿鑻辨尝浣?/ 绮捐嫳涓?Boss 鏈哄瀷 / 鍏冲崱鐗规€э級銆?
    -- 閫夊叧銆佷笅涓€鍏炽€佸啀鎴樸€侀噸寮€閮戒細閲嶆幏鈥斺€斿悓涓€鍏虫瘡娆¤繘鍏ラ兘鍙兘涓嶅悓銆?
    StageCatalog.BeginStage(startStage, os.time())
    bossDefeated = false
    stageResult = nil
    Game._defeat.at = nil
    Game._defeat.revive = false
    Game._opening.active = false
    Game._opening.round = 0
    Game._opening.selected = {}
    Game._opening.phase = nil
    Game._opening.timer = 0
    elapsed = 0
    veggies = {}
    marbles = {}
    Game.ClearLaunchCharge()
    aiming = false
    hasLaunched = false
    startArmed = false
    reviveUsed = false
    -- v0.11.0 鍟嗕笟鍖栵細灞€鍐呴浂浠朵笌鍗囩骇闈㈡澘鍙樼幇鐘舵€佸浣?
    partsEarned = 0
    partsSettled = false
    partsDoubled = false
    lastSettledParts = 0
    settledParts = 0
    settleBook.bricks = 0
    settleBook.runCounted = false
    settleBook.gear = 0
    settleBook.gearSettled = 0
    runAircraft = {}
    baseShield = 0
    -- v0.13.13锛氬紑灞€鑷姩鎷夊彇灞€澶栭亾鍏峰簱瀛橈紙瑕嗙洊閫夊叧/涓嬩竴鍏?鍐嶆垬/閲嶅紑鍏ㄩ儴鍏ュ彛锛夈€?
    if itemStockProvider then
        local ok, stock = pcall(itemStockProvider)
        if ok and type(stock) == "table" then Game.SetItemStock(stock) end
    end
    ResetItems()
    upgradeRerollFreeUsed = 0
    heldUpgradeId = nil
    pauseHealUsed = 0
    pauseRareUsed = 0
    pendingRareRoll = false
    -- v0.13.58锛氶檮榄斿崱鐘舵€佸浣嶏紙寮€灞€绌烘墜锛沴astWave 璁板綍褰撳墠娉紝浣挎湰娉㈠畬鎴愭椂鍙戞斁绗竴寮狅級銆?
    Game._enchant.card = nil
    Game._enchant.pending = nil
    Game._enchant.lastWave = wave
    pauseOrbitalUsed = false
    pauseReloadUsed = false
    pausePartsBoostUsed = false
    partsBoostTime = 0
    aimX = SLING_X
    aimY = SLING_Y
    waveCooldown = 3.2    -- 寮€灞€鐭殏鍠樻伅锛涘悗缁寜鍏冲崱鑺傚鍒锋柊
    introTimer = 0
    nextWavePlan = nil
    -- v0.13.26锛氬浣嶅悓娉㈤敊宄扮敓鎴愮姸鎬併€?
    pendingSpawn.remaining = 0
    pendingSpawn.timer = 0
    pendingSpawn.kind = nil
    pendingSpawn.lane = 0
    pendingSpawn.spawned = 0
    nextEnemyId = 1
    nextMarbleId = 1
    -- 骞稿瓨鑰呮垚闀跨姸鎬佸浣?
    playerLevel = 1
    xp = 0
    xpToNext = BALANCE.baseXpToNext
    pendingLevelUps = 0
    deferredXp = 0
    upgradeChoices = nil
    upgradePicks = {}
    upgradeStacks = {}
    unlockedBalls = { [STARTING_BALL_TYPE] = true }
    -- v0.13.20锛氬ぉ璧嬫爲鐨勩€岃В閿佽溅銆嶈妭鐐?*涓嶅啀**璁╄溅寮€灞€鍗冲彲鐢紙鐢ㄦ埛婢勬竻锛夆€斺€?
    -- 瀹冨彧鍐冲畾銆屽眬鍐呴偅寮犮€庤В閿伱椕楄溅銆忓崱鏄惁杩涙睜銆嶃€傚紑灞€鑷甫鐨勬案杩滃彧鏈?STARTING_BALL_TYPE銆?
    ammoCapacity = BASE_AMMO_TOTAL
    activeWords = {}    -- P11锛氳瘝鏉￠噸缃?
    clearStreak = 0
    bricksBroken = 0
    -- v0.13.65锛氬够褰变綋绱犲潡闅忓叧鍗￠噸寮€娓呯┖锛堝湪鍦哄潡銆佹湰鍏充繚搴曡鏁般€佸凡鍙戝皠鏈哄瀷闆嗗悎鍏ㄩ儴澶嶄綅锛夈€?
    Game._phantom.list = {}
    Game._phantom.guaranteed = 0
    Game._phantom.firedKeys = {}
    Game._phantom.guaranteeTimer = 0
    BALL_TUNING.damageBonus = 0
    BALL_TUNING.giantArea = 0
    BALL_TUNING.splitBonus = 0
    BALL_TUNING.speedMul = 1.0
    BALL_TUNING.iceBonus = 0
    BALL_TUNING.lineDamageBonus = 0
    BALL_TUNING.xpMul = 1.0
    -- v0.13.55 涓撳睘鍗℃満鍒跺瓧娈靛浣嶏紙蹇呴』鍦?LoadBalls 涔嬪墠鈥斺€斿畠璇?splitCount 绛夛級銆?
    BALL_TUNING.splitCount = 2
    BALL_TUNING.iceShatter = 0
    BALL_TUNING.speedPierce = 0
    BALL_TUNING.giantCritChance = 0
    -- v0.13.5锛氬彔鍔犲ぉ璧嬫爲鐨勮溅绾胯矾鏁板€煎寮猴紙鍔犳硶鍏堛€佷箻娉曞悗锛岄噺绾у彲鎺э級銆?
    for _, acc in pairs(talentBallStats) do
        if acc.stat == "splitBonus" then
            BALL_TUNING.splitBonus = BALL_TUNING.splitBonus + acc.add
        elseif acc.stat == "giantArea" then
            BALL_TUNING.giantArea = BALL_TUNING.giantArea + acc.add
        elseif acc.stat == "iceBonus" then
            BALL_TUNING.iceBonus = BALL_TUNING.iceBonus + acc.add
        elseif acc.stat == "speedMul" then
            BALL_TUNING.speedMul = BALL_TUNING.speedMul * acc.factor
        end
    end
    LoadBalls()
    Emit("game_reset")
end

-- 浠庨€夊叧鐣岄潰杩涘叆鏌愬叧銆俿tageNum 缂虹渷涓?1銆?
local function StartGameAt(stageNum)
    previousHighScore = highScore
    ResetGame(stageNum)
    -- 鍏堥€変袱杈嗕笉鍚岃溅鍨嬶紝閫夊畬鎵嶈濉苟鍚姩鍘熶笁绉掑噯澶囨湡锛涗笉鍐嶅浐瀹氶€佸姞閫熻溅銆?
    activeBall = nil
    ballQueue = {}
    unlockedBalls = {}
    Game._opening.active = true
    Game._opening.round = 1
    Game._opening.phase = "briefing"
    Game._opening.timer = Game._opening.durations.briefing
    gameState = "levelup"
    RollUpgradeChoices({})
    print("[Game] opening briefing stage=" .. stage .. " round=1/2")
end

local function StartGame()
    StartGameAt(1)
end

local function GetAircraftSize(aircraftKey, brickSize)
    local data = AircraftData[aircraftKey]
    return data.gridW * brickSize, data.gridH * brickSize
end

-- 缂栭槦闂磋窛涓庡叏鍦?AABB 闃查噸鍙狅細鐢熸垚鍊欓€夊拰閫愬抚鍒嗙鍏辩敤鍚屼竴濂楀垽瀹氾紝
-- 蹇呴』瀵光€滄湰鎵规宸叉斁缃?+ 鍦轰笂浠嶅瓨娲烩€濈殑鎵€鏈夐鏈虹敓鏁堬紝绂佹鍙鏌ュ叾涓竴杈广€?
local ENEMY_SPACING = 8

local function EnemyAABB(enemy)
    return enemy.x, enemy.y,
        enemy.gridW * enemy.brickSize, enemy.gridH * enemy.brickSize
end

local function RectsOverlap(x, y, w, h, ox, oy, ow, oh, gap)
    gap = gap or ENEMY_SPACING
    return x < ox + ow + gap and x + w + gap > ox
        and y < oy + oh + gap and y + h + gap > oy
end

-- 鍊欓€夌煩褰㈡槸鍚︿笌鏈壒娆?placed 鎴栧満涓婂瓨娲婚鏈猴紙ignore 鍙帓闄よ嚜韬級閲嶅彔銆?
-- gap 鐪佺暐鏃剁敤 ENEMY_SPACING锛堟棦鏈夎涓猴級锛涘悓娉㈤敊宄扮敓鎴愪紶 brickSize 浠ュ己鍒躲€岃嚦灏戦殧 1 鏍笺€嶃€?
local function FleetPositionOccupied(x, y, w, h, placed, ignore, gap)
    for _, item in ipairs(placed) do
        if RectsOverlap(x, y, w, h, item.x, item.y, item.w, item.h, gap) then
            return true
        end
    end
    for _, other in ipairs(veggies) do
        if other ~= ignore and not other.dead then
            local ow, oh = other.gridW * other.brickSize, other.gridH * other.brickSize
            if RectsOverlap(x, y, w, h, other.x, other.y, ow, oh, gap) then
                return true
            end
        end
    end
    return false
end

-- 鏅€氭満鎸夊叧鍐呮尝娆′緷娆′粠鍘熸湁鏈哄瀷涓€夋嫨锛涚壒娈婃満涓嶆贩鍏ユ櫘閫氶殢鏈烘睜銆?
local WAVE_ROSTER = {
    { key = "scout",       minWave = 1 },
    { key = "dart",        minWave = 2 },
    { key = "striker",     minWave = 3 },
    { key = "hive",        minWave = 4 },
    { key = "manta",       minWave = 5 },
    { key = "bomber",      minWave = 7 },
    { key = "cruiser",     minWave = 8 },
    { key = "interceptor", minWave = 9 },
}

-- 鍙敤鏈哄瀷姹犳寜銆岀疮璁￠毦搴︺€嶈В閿侊紝鏈哄瀷绉嶇被闅?*鍏冲崱鍙?*閫愭澧炲鈥斺€斿叧鍗¤秺楂樿秺涓板瘜澶氬厓銆?
-- v0.13.58锛氬厛淇€屾瘡鍏冲紑灞€閮戒竴鏍枫€嶏紙瑙ｉ攣杩涘害涓嶅啀姣忓叧褰掗浂锛夈€?
-- v0.13.59锛氬啀淇€屽叧鍗′箣闂翠笉閫掕繘銆嶁€斺€旀棫杩涘害 `(鍏冲崱-1)+鍏冲唴娉㈡` 璁?*绗?1 鍏崇 10 娉㈠氨瑙ｉ攣鍏ㄩ儴 8 绉?*锛?
--   鐜╁涓€鍏冲唴灏辩湅閬嶆墍鏈夋満鍨嬶紝鍚庣画鍏冲崱姣棤鏂版剰銆傜幇鏀炬參**鍏冲唴**瑙ｉ攣锛堟瘡 3 娉㈡墠 +1 妗ｏ級锛?
--   璁╂満鍨嬫睜涓昏鐢?*鍏冲崱鍙?*椹卞姩锛氬叧1 寮€灞€ 1 绉嶃€佸叧2 寮€灞€ 2 绉嶁€﹀叧 6+ 寮€灞€鍗冲叏鏈哄瀷锛?
--   涓旀瘡鍏冲叧鍐呬粛缂撴參鏀惧锛堟湰鍏冲彲鐢ㄦ満鍨嬮殢娉㈡灏忓箙澧炲姞锛夈€傚叧鍗¤秺楂橈紝鏈叧鍑虹幇鐨勬満鍨嬭秺澶氥€?
local function GetAvailableTypes(waveNum)
    local keys = {}
    local progress = (StageCatalog.GetStage(waveNum) - 1)
        + math.floor((StageCatalog.GetStageWave(waveNum) - 1) / 3) + 1
    for _, entry in ipairs(WAVE_ROSTER) do
        if progress >= entry.minWave and AircraftData[entry.key] then
            table.insert(keys, entry.key)
        end
    end
    return keys
end

-- 鍙璇婃柇锛堣〃瀛楁璧嬪€硷紝涓嶅崰椤跺眰 local 妲戒綅锛夛細杩斿洖鏌愮疮璁℃尝鍙峰彲鐢ㄧ殑鏅€氭満鍨嬫睜锛?
-- 渚涙帰閽堥獙璇併€屾満鍨嬬绫婚殢鍏冲崱鍙烽€掕繘銆嶃€傛父鎴忛€昏緫涓嶆秷璐广€?
function Game.DebugAvailableTypes(waveNum)
    return GetAvailableTypes(waveNum)
end

---@param aircraftKey string
---@param x number
---@param y number
---@param brickSize number
---@param brickHp integer
---@param baseSpeed number
---@param opts {swayAmp:number?, swayFreq:number?, phase:number?}?
local function CreateEnemy(aircraftKey, x, y, brickSize, brickHp, baseSpeed, opts)
    local data = AircraftData[aircraftKey]
    if not data then
        print("[Game] ERROR: no aircraft data for " .. tostring(aircraftKey))
        return nil
    end

    -- A3锛氳涓哄垎鍖栤€斺€旇鍙栬鍨嬫€ф牸鍙傛暟锛屼娇涓嶅悓椋炴満妯憜/鑺傚/涓嬪帇鎰熷悇寮傘€?
    -- 鍚屾尝闃靛瀷鍙攣瀹?sway锛岄伩鍏嶅悇鑷贡鎽嗘妸闃靛瀷鎷嗘暎銆?
    local beh = AircraftData.behavior and AircraftData.behavior[aircraftKey]
        or { swayAmp = 18, swayFreq = 0.4, descentMul = 1.0, agility = 0.8 }
    local swayAmp = beh.swayAmp + Random() * beh.swayAmp * 0.3
    local swayFreq = beh.swayFreq * (0.85 + Random() * 0.3)
    local descent = beh.descentMul
    local spawnPhase = 0
    if opts then
        if opts.swayAmp ~= nil then swayAmp = opts.swayAmp end
        if opts.swayFreq ~= nil then swayFreq = opts.swayFreq end
        if opts.phase ~= nil then spawnPhase = opts.phase end
    end

    local bricks = {}
    for entry in (data.data .. ";"):gmatch("(.-);") do
        local col, row, er, eg, eb = entry:match("(%d+),(%d+),(%d+),(%d+),(%d+)")
        if col then
            -- v0.13.65锛氭爣璁般€屽紩鎿庣伅銆嶄綋绱狅紙bitmapToData 鐢?110,46,40 琛ㄧず E锛孋lassifySlot 褰?engine锛夈€?
            -- 骞诲奖浣撶礌鍧楀彧鑳界敱**鏈鐮村潖鐨?*寮曟搸鐏潡鍙戝皠銆?
            local isEngine = (er == "110" and eg == "46" and eb == "40")
            table.insert(bricks, {
                col = tonumber(col), row = tonumber(row),
                hp = brickHp, maxHp = brickHp, alive = true,
                ejected = false,
                isEngine = isEngine,
            })
        end
    end

    local enemy = {
        id = nextEnemyId,
        aircraftKey = aircraftKey,
        gridW = data.gridW,
        gridH = data.gridH,
        brickSize = brickSize,
        x = x, y = y, baseX = x,
        -- v0.10.27锛氬叏灞€涓嬭惤 0.25鈫?.42锛岄娉㈠叆鍦轰笉鍐嶈创鐫€灞忛《锠曞姩銆?
        vy = baseSpeed * data.speedMul * 0.42 * descent,
        normalVy = baseSpeed * 0.42,
        swayAmp = swayAmp,
        swayFreq = swayFreq,
        agility = beh.agility,    -- A3锛氳妭濂?鍙嶅簲璐ㄦ劅鏍囪锛堟覆鏌撳眰鍙锛?
        -- 榛樿 phase=0锛氶甯т綅缃嵆 baseX銆傞樀鍨嬪彲浼犲叆缁熶竴鐩镐綅锛屼繚璇佸悓娉竴璧锋憜銆?
        phase = spawnPhase,
        bricks = bricks,
        dead = false,
        breached = false,
        frozen = 0,
        freezeRatio = 0,    -- WO-13/P2锛氭覆鏌撳眰鍙鍐荤粨姣斾緥锛?..1锛夛紝鍒濆鍖栦负闆?
    }
    nextEnemyId = nextEnemyId + 1
    return enemy
end

-- v0.10.28锛?bit 琛楁満闃靛瀷銆傚悓娉㈠悓鏈恒€佹暣闃熼攣瀹氭í鎽嗭紝閬垮厤闅忔満鏁ｇ偣鎶婂壀褰辨媶鏁ｃ€?
local FORMATION_CYCLE = { "line", "vee", "grid", "swarm", "wedge", "stream" }

local function PickWaveAircraft(pool)
    if #pool == 1 then return pool[1] end
    -- 鏂拌В閿佹満鍨嬬暐浼樺厛闇茶劯锛屽叾浣欏湪宸茶В閿佹睜鍐呭潎鍖€鎶姐€?
    -- v0.13.58锛氬亸缃?0.6鈫?.3鈥斺€旀満鍨嬫睜闅忓叧鍗″彉澶у悗锛岃繃楂樺亸缃細璁╂瘡娉㈣繃搴﹀亸鍚戝崟涓€鏈哄瀷銆?
    -- 鍓婂急鏈凡瑙ｉ攣鏈哄瀷鐨勫鏍锋€э紙鐢ㄦ埛鎶ャ€屾晫鏈虹被鍨嬪お鏃犺亰銆嶏級銆?
    if Random() < 0.3 then return pool[#pool] end
    return pool[RandomInt(1, #pool)]
end

---@class NextWavePlan
---@field wave integer
---@field stage integer
---@field stageWave integer
---@field kind string
---@field aircraftKey string
---@field count integer
---@field formation string
---@field isBoss boolean
---@field escortKey string|nil
---@field escortCount integer|nil

local function PickFormation(waveNum, count, aircraftKey)
    if aircraftKey == "hive" then return "swarm" end
    if count <= 1 then return "line" end
    local kind = FORMATION_CYCLE[((waveNum - 1) % #FORMATION_CYCLE) + 1]
    -- 瀹芥満妯帓濉炰笉涓?540 瀹斤紝3 鏈烘敼 2+1 缃戞牸锛岄伩鍏嶉€€鍖栨垚绾靛垪銆?
    if (aircraftKey == "manta" or aircraftKey == "cruiser" or aircraftKey == "bomber")
        and count >= 3 then
        return "grid"
    end
    local shipWidth = AircraftData[aircraftKey].gridW * GetBrickSize(waveNum)
    if count * shipWidth + (count - 1) * ENEMY_SPACING > DW - 40 then
        return "grid"
    end
    if kind == "grid" and count <= 2 then return "line" end
    return kind
end

---@param waveNum integer
---@return NextWavePlan
PlanWave = function(waveNum)
    local currentStage = StageCatalog.GetStage(waveNum)
    local currentStageWave = StageCatalog.GetStageWave(waveNum)
    local kind = StageCatalog.GetKind(currentStage, currentStageWave)
    if kind ~= "normal" then
        local escortPool = GetAvailableTypes(waveNum)
        return {
            wave = waveNum, stage = currentStage, stageWave = currentStageWave,
            kind = kind,
            aircraftKey = StageCatalog.GetSpecialKey(currentStage, currentStageWave),
            count = 1, formation = "line", isBoss = kind == "boss",
            escortKey = kind == "elite" and PickWaveAircraft(escortPool) or nil,
            escortCount = kind == "elite" and StageCatalog.GetEscortCount(currentStage) or 0,
        }
    end
    local pool = GetAvailableTypes(waveNum)
    local count = GetWaveParams(waveNum)
    local key = (#pool > 0) and PickWaveAircraft(pool) or "scout"
    return {
        wave = waveNum, stage = currentStage, stageWave = currentStageWave,
        kind = kind,
        aircraftKey = key,
        count = count,
        formation = PickFormation(waveNum, count, key),
        isBoss = false,
    }
end

---@return NextWavePlan|nil
EnsureNextWavePlan = function()
    if stageWave >= StageCatalog.WAVES_PER_STAGE then return nil end
    local upcoming = wave + 1
    if not nextWavePlan or nextWavePlan.wave ~= upcoming then
        nextWavePlan = PlanWave(upcoming)
    end
    return nextWavePlan
end

-- 绮捐嫳/棣栭鍗曟満浠庡睆澶栬繘鍏ワ細鍗充娇鏁伴噺澧炲姞锛岀壒娈婄洰鏍囦篃濮嬬粓鍗犱竴涓満缇ゅ悕棰濄€?
-- v0.13.26锛氱壒娈婃満鐢?brickSize 浣滈棿璺濇煡鎵剧┖浣嶏紝淇濊瘉銆岃嚦灏戦殧 1 鏍笺€嶏紱
-- 涓斾竴鏃︽湰娉㈡湁鏁屾満鍦ㄥ満锛屾敼鐢ㄣ€屼粠鏇磋繙澶勭敓鎴愩€嶈€岄潪涓婃姮鈥斺€旈伩鍏嶃€孊oss 宸插埌鍦哄張鐬Щ鍒板ご椤躲€嶃€?
local function SpawnSpecialEnemy(plan)
    local key = plan.aircraftKey
    if not AircraftData[key] then
        print("[Game] ERROR: missing special aircraft " .. tostring(key))
        return nil
    end
    local brickSize = GetBrickSize(wave)
    local shipW, shipH = GetAircraftSize(key, brickSize)
    local x = DW * 0.5 - shipW * 0.5
    local y = -102 - shipH - 24
    -- 涓庡湪鍦烘晫鏈鸿嚦灏戦殧 1 鏍硷紙brickSize锛夛細鏈変汉鍗犱綅灏卞線鏇磋繙澶勬尓锛屼繚璇併€屼换鎰忎袱鏋跺垵濮嬧墺1鏍笺€嶃€?
    -- 鐗规畩鏈烘槸鏂扮敓鎴愮殑锛堝皻鏈彲瑙侊級锛屽線灞忓鏇磋繙澶勬斁涓嶄細閫犳垚銆岀灛绉汇€嶃€?
    local guard = 0
    while FleetPositionOccupied(x, y, shipW, shipH, {}, nil, brickSize) and guard < 200 do
        y = y - brickSize
        guard = guard + 1
    end
    local baseSpeed = StageCatalog.GetBaseSpeed(stage, stageWave)
    local enemy = CreateEnemy(key, x, y, brickSize,
        StageCatalog.GetBrickHp(stage, plan.kind), baseSpeed)
    if not enemy then return nil end
    enemy.isElite = plan.kind == "elite"
    enemy.isBoss = plan.kind == "boss"
    enemy.stage = stage
    if enemy.isBoss then
        enemy.bossPhase = 1
        enemy.vulnerable = false
        enemy.summonTimer = StageCatalog.GetBossSummonInterval(stage)
        enemy.summonCount = 0
        Emit("boss_spawn", {enemyId = enemy.id, wave = wave, stage = stage, aircraftKey = key})
    end
    veggies[#veggies + 1] = enemy
    return enemy
end

-- v0.13.26锛氭湰娉㈡晫鏈洪€愭灦鏀惧嚭鐨勬椂闂撮棿闅斻€備笅闄愭寜銆屼竴鏋跺湪闂撮殧鍐呬笅钀?鈮?1 鏍?+ 浣欓噺銆嶅姩鎬佹姮楂橈紝
-- 淇濊瘉浠绘剰涓ゆ灦鍒濆浣嶇疆鑷冲皯闅斾竴涓牸瀛愶紙鐢ㄦ埛瑕佹眰锛夛紱涓婇檺鐢?StageCatalog 鐨勯€愬叧鏀剁揣鏇茬嚎缁欏嚭銆?
-- 鈿狅笍 涓嬭惤閫熷害鎸?*鏈€鎱㈡満鍨?*淇濆畧鍙栧€硷紙鍩哄噯 脳 0.42 脳 鏈€鎱?descentMul锛夛細闂撮殧澶煭鏃舵渶鎱㈤偅鏋?
-- 鏉ヤ笉鍙婃媺寮€锛屽氨浼氫笌鍚庝竴鏋舵尋鍦ㄥ悓涓€涓牸瀛愬甫鍐呫€傜敤鍩哄噯閫熷害浼扮畻浼氬湪楂樺叧鍗℃紡鎺夎繖涓笅鐣屻€?
local SLOWEST_DESCENT_MUL = 0.66
local function CurrentSpawnInterval()
    local base = StageCatalog.GetSpawnInterval(stage)
    local descent = StageCatalog.GetBaseSpeed(stage, stageWave) * 0.42 * SLOWEST_DESCENT_MUL
    local minInterval = (pendingSpawn.brickSize + 6) / math.max(1, descent)
    return math.max(base, minInterval)
end

-- v0.13.26锛氫粠灞忓箷涓婃部涔嬪鏀惧嚭鏈尝涓€鏋舵晫鏈恒€傚睆骞曟槸淇 3D锛屾晫鏈哄湪灞忓箷澶栫敓鎴愬悗
-- 涓嬭惤涓€娈垫墠杩涚敾闈⑩€斺€旀墍浠ャ€屽垰鐢熸垚鏃剁湅涓嶈銆嶆槸棰勬湡锛屼笉鏄病鍒峰嚭鏉ャ€?
SpawnNextNormalEnemy = function()
    if pendingSpawn.remaining <= 0 then return end
    -- 婊″満锛氭湰鏋舵帹杩燂紝绛夋湁绌轰綅鍐嶆斁锛堜笉鑳藉己琛岃惤浣嶏紝鍚﹀垯涓ゆ灦浼氬彔鍦ㄤ竴璧凤級銆?
    if #veggies >= StageCatalog.MAX_FLEET then
        pendingSpawn.timer = 0.5
        return
    end
    -- v0.13.57锛氬睆骞曞锛堝皻鏈繘鍏ュ彲瑙佹垬鍦猴紝搴曡竟浠嶅湪 -102 涔嬩笂锛夌殑鏁屾満杈惧埌涓婇檺鏃讹紝
    -- **鏆傚仠鐢熸垚闃熷垪**鈥斺€旂瓑灞忓鏈轰笅钀借繘鍦哄悗鍐嶆斁涓嬩竴鏋讹紝閬垮厤涓€娉㈠鏋跺叏鍫嗗湪灞忓箷涓婃部涔嬪銆?
    -- 鈿狅笍 杩欓噷鍙暟**鍦ㄥ満**灞忓鏈猴紙閫愭灦鏀惧嚭涓€鏋躲€佸仠涓€娆★級锛涘緟鏀炬灦鏁扮敱娉㈡鍚姩闂ㄦ帶缁熶竴鑰冭檻
    --    锛堣 UpdateWaveLogic锛夛紝鍚﹀垯鎶?remaining 涔熺畻杩涙潵浼氳鏁存尝涓€寮€濮嬪氨琚案涔呮帹杩燂紙姝婚攣锛夈€?
    -- 璁℃暟鍐呰仈鍦ㄥ嚱鏁板唴锛堜笉鏂板椤跺眰 local锛孏ame.lua 宸查€艰繎 Lua 200 涓婇檺锛孉B-166锛夈€?
    local offscreen = 0
    for i = 1, #veggies do
        local e = veggies[i]
        if not e.dead then
            local _, ey, _, eh = EnemyAABB(e)
            if ey + eh < -102 then offscreen = offscreen + 1 end
        end
    end
    if offscreen >= StageCatalog.MAX_OFFSCREEN then
        pendingSpawn.timer = 0.3
        return
    end
    local key = pendingSpawn.key
    if not AircraftData[key] then
        pendingSpawn.remaining = 0
        pendingSpawn.kind = nil
        return
    end
    local brickSize = pendingSpawn.brickSize
    local shipW, shipH = GetAircraftSize(key, brickSize)
    -- v0.13.27锛氭í鍚戝垎閬撯€斺€旈€愭灦杞崲涓嶅悓 x锛堢‘瀹氭€э紝闈為殢鏈猴級锛岄伩鍏嶆暣娉㈤兘鍙犲湪姝ｄ腑涓€鏉＄珫绾夸笂銆?
    -- 杞﹂亾鏁扮敤鍑芥暟鍐呭眬閮ㄩ噺锛屼笉鏂板椤跺眰 local锛圙ame.lua 宸查€艰繎 Lua 200 涓婇檺锛夈€?
    local laneCount = StageCatalog.SPAWN_LANE_COUNT
    local margin = 20
    local maxX = math.max(margin, DW - margin - shipW)
    local lane = pendingSpawn.lane % laneCount
    pendingSpawn.lane = lane + 1
    local x = margin + (maxX - margin) * (lane / (laneCount - 1))
    local y = -102 - shipH - 24
    -- 涓庡湪鍦烘晫鏈猴紙鍚湰娉㈠墠鍑犳灦锛夎嚦灏戦殧 1 鏍硷細浠嶅湪灞忓鏃跺啀寰€鍓嶆斁锛屼笉涓嬭惤鐬Щ銆?
    local guard = 0
    while FleetPositionOccupied(x, y, shipW, shipH, {}, nil, brickSize) and guard < 200 do
        y = y - brickSize
        guard = guard + 1
    end
    if FleetPositionOccupied(x, y, shipW, shipH, {}, nil, brickSize) then
        -- 灞忓绌洪棿涔熸壘涓嶅埌绌轰綅锛堟瀬绔嫢鎸わ級锛氭帹杩熸湰鏋讹紝缁濅笉鍙犳斁銆?
        pendingSpawn.timer = 1.0
        return
    end
    -- v0.13.51锛氭湰鍏冲唴鎸?*鍑哄満搴忓彿**缁欐櫘閫氭晫鏈鸿閲忓皝椤讹紙绗?鏋垛墹1琛€銆佺2鏋垛墹3琛€銆佺3鏋垛墹5琛€鈥︼級锛?
    -- 璁╁叧鍗″墠娈电敱寮卞埌寮哄钩婊戦€掕繘锛涘彧灏侀《涓嶆姮鍗囷紙鏇茬嚎鏇翠綆鏃朵繚鎸佹洸绾垮€硷級銆?
    -- 鈿狅笍 鐢?`pendingSpawn.spawned`锛堟湰鍏冲凡鏀惧嚭璁℃暟锛夎€屼笉鏄€屽満涓婃棤鏁屾満銆嶁€斺€斿惁鍒欓鏈鸿鎵撴帀鍚庯紝
    -- 鍚屾尝绗簩鏋朵細琚鍒ゆ垚绗竴涓紙AB-204锛夈€傛湰鍏崇涓€娉㈠紑娉㈡椂澶嶄綅銆?
    local firstShipHp = pendingSpawn.hp
    if wave == (stage - 1) * StageCatalog.WAVES_PER_STAGE + 1 then
        local cap = StageCatalog.GetFirstShipHpCap(pendingSpawn.spawned + 1)
        if firstShipHp > cap then firstShipHp = cap end
    end
    local enemy = CreateEnemy(key, x, y, brickSize, firstShipHp, pendingSpawn.speed, {
        swayAmp = 6, swayFreq = 0.22, phase = 0,
    })
    if enemy then
        pendingSpawn.spawned = pendingSpawn.spawned + 1
        enemy.formation = "stream"
        veggies[#veggies + 1] = enemy
        pendingSpawn.remaining = pendingSpawn.remaining - 1
    end
    if pendingSpawn.remaining > 0 then
        pendingSpawn.timer = CurrentSpawnInterval()
    else
        if pendingSpawn.kind == "normal" then
            Emit("wave_started", {wave = wave, stage = stage, stageWave = stageWave,
                kind = "normal", formation = "stream", aircraftKey = key})
            print("[Game] stage " .. stage .. " wave " .. stageWave .. " stream released: " .. key)
        end
        pendingSpawn.kind = nil
    end
end

-- v0.13.26锛氱簿鑻辨姢鑸篃鏀逛负涓€鏋舵帴涓€鏋堕鍏ワ紙涓庢櫘閫氭尝鍏辩敤鍚屼竴濂楅敊宄版満鍒讹級銆?
ReleaseEscortVolley = function(plan)
    local count = math.min(plan.escortCount or 0, math.max(0, StageCatalog.MAX_FLEET - #veggies - 1))
    if count <= 0 then return end
    local key = plan.escortKey
    if not AircraftData[key] then return end
    pendingSpawn.key = key
    pendingSpawn.kind = "escort"
    pendingSpawn.brickSize = GetBrickSize(wave)
    pendingSpawn.hp = StageCatalog.GetBrickHp(stage, "normal")
    pendingSpawn.speed = StageCatalog.GetBaseSpeed(stage, stageWave)
    pendingSpawn.remaining = count
    pendingSpawn.timer = 0
end

SpawnWave = function(availableSlots)
    -- 涓嬩竴娉㈤鍛娿€佸疄闄呯紪闃熷拰鐗规畩鐩爣鍚嶇О蹇呴』娑堣垂鍚屼竴浠介鎶借鍒掋€?
    local plan = nextWavePlan
    if not plan or plan.wave ~= wave then plan = PlanWave(wave) end
    nextWavePlan = nil

    if plan.kind == "elite" then
        local enemy = SpawnSpecialEnemy(plan)
        if enemy then
            ReleaseEscortVolley(plan)
            Emit("wave_started", {wave = wave, stage = stage, stageWave = stageWave,
                kind = "elite", aircraftKey = plan.aircraftKey, isBoss = false})
            print("[Game] stage " .. stage .. " wave " .. stageWave .. " elite spawned: "
                .. plan.aircraftKey)
        end
        return
    end

    if plan.kind == "boss" then
        -- v0.13.26锛欱oss 涓嶅啀鍐荤粨鏈尝锛涗粠灞忓箷澶栬緝杩滃椋炲叆锛圫pawnSpecialEnemy 澶勭悊閬胯锛夛紝
        -- 涓嶆妸宸插湪鍦虹殑鏁屾満椤跺埌澶╀笂锛屼篃涓嶅仛鐬Щ銆?
        local enemy = SpawnSpecialEnemy(plan)
        if enemy then
            Emit("wave_started", {wave = wave, stage = stage, stageWave = stageWave,
                kind = "boss", aircraftKey = plan.aircraftKey, isBoss = true})
            print("[Game] stage " .. stage .. " wave " .. stageWave .. " boss spawned: "
                .. plan.aircraftKey)
        end
        return
    end

    -- 鏅€氭尝锛氱櫥璁版湰娉㈠弬鏁帮紝鐢?SpawnNextNormalEnemy 鎸夐敊宄伴棿闅旈€愭灦鏀惧嚭锛堢涓€鏋剁珛鍗冲叆鍦猴級銆?
    local count, baseSpeed, brickHp = GetWaveParams(wave)
    count = math.min(count, availableSlots or count)
    local aircraftKey = plan.aircraftKey
    if not AircraftData[aircraftKey] then
        print("[Game] WARNING: empty aircraft pool")
        return
    end
    pendingSpawn.key = aircraftKey
    pendingSpawn.kind = "normal"
    pendingSpawn.brickSize = GetBrickSize(wave)
    pendingSpawn.hp = brickHp
    pendingSpawn.speed = baseSpeed
    pendingSpawn.remaining = count
    pendingSpawn.timer = 0
    -- v0.13.61锛氳捣濮嬭溅閬撴幒鍏?*鍏冲崱鍙?*锛堜笉鍐嶇敤绱 wave锛夆€斺€旀瘡鍏抽娉㈡亽涓?
    -- `(鍏冲崱-1) % 5`锛岄€愬叧杞崲锛涘惁鍒?`(10k)%5==0` 浼氳姣忓叧绗竴鏋舵案杩滆创鏈€宸︼紙鐢ㄦ埛鐐瑰悕锛夈€?
    pendingSpawn.lane = (stage - 1 + stageWave - 1) % StageCatalog.SPAWN_LANE_COUNT
    -- v0.13.51锛氬嚭鍦哄簭鍙疯鏁伴殢姣忔尝寮€娉㈠浣嶁€斺€斿畠鍙湪鏈叧绗竴娉㈢敓鏁堬紙琛€閲忓皝椤跺垽瀹氬甫 wave 绾︽潫锛夛紝
    -- 澶嶄綅淇濊瘉绗竴娉粠銆岀 1 鏋躲€嶉噸鏂拌鏁般€?
    pendingSpawn.spawned = 0
    SpawnNextNormalEnemy()
end

-- 纰版挒鍖哄煙璁捐锛氬渾褰㈠脊鐝犲鍗曚釜鏂瑰舰鐮栧潡銆?
--
--        鍦嗗績 (cx, cy)
--             o
--          .-' '-.
--       +----------+  <- 鐮栧潡 AABB (rx, ry, rw, rh)
--       |          |
--       +----------+
--
-- 鐩殑锛氬渾涓?AABB 閲嶅彔鏃讹紝鎸夊綊涓€鍖栫┛閫忚緝澶х殑杞村弽灏勯€熷害骞舵帹鍑鸿〃闈€?
-- 杈圭晫锛氱浉鍒囦笉绠楀懡涓紱鎺ㄥ嚭 0.5 璁捐鍗曚綅閬垮厤閲嶅鍗＄銆?
-- 鍏堜互鏈瓙姝ョ殑绾挎鍖呭洿鐩掔矖绛涙暣鏋?鍗曟牸锛岃鐩栨摝杈瑰拰楂橀€熺┛瓒娿€?
-- v0.10.27锛氶珮閫熺悆闄ゅ垎瀛愭杩涳紝杩樺鏈抚浣嶇Щ鍋氱嚎娈?AABB 鎵帬锛岄伩鍏嶆摝杈?瀵硅绌挎牸涓㈠け纰版挒銆?
local function SegmentNearRect(x0, y0, x1, y1, rx, ry, rw, rh, radius)
    return math.max(x0, x1) + radius >= rx
        and math.min(x0, x1) - radius <= rx + rw
        and math.max(y0, y1) + radius >= ry
        and math.min(y0, y1) - radius <= ry + rh
end

local function IntersectsBrick(marble, rx, ry, rw, rh)
    local closestX = math.max(rx, math.min(marble.x, rx + rw))
    local closestY = math.max(ry, math.min(marble.y, ry + rh))
    local dx = marble.x - closestX
    local dy = marble.y - closestY
    return dx * dx + dy * dy < marble.radius * marble.radius
end

-- 鍦嗘部 (px,py)鈫?cx,cy) 鎵繃鑶ㄨ儉鍚庣殑鐮栧潡 AABB銆傜敤浜庢湰甯т綅绉绘紡妫€銆?
local function SweptHitsBrick(px, py, cx, cy, radius, rx, ry, rw, rh)
    local minX = rx - radius
    local minY = ry - radius
    local maxX = rx + rw + radius
    local maxY = ry + rh + radius
    if cx >= minX and cx <= maxX and cy >= minY and cy <= maxY then
        return true
    end
    local dx = cx - px
    local dy = cy - py
    local steps = 1
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist > radius * 0.5 then
        steps = math.max(2, math.ceil(dist / math.max(4, radius * 0.45)))
    end
    for s = 1, steps do
        local t = s / steps
        local x = px + dx * t
        local y = py + dy * t
        if x >= minX and x <= maxX and y >= minY and y <= maxY then
            return true
        end
    end
    return false
end

local function CollideBrick(marble, rx, ry, rw, rh)
    -- v0.13.66锛氬弽寮圭鎾炵 = 85% 鍗婂緞锛涗激瀹冲湀锛堟弧鍗婂緞锛夌敱璋冪敤鏂圭粨绠椼€?
    -- 鍙繘浼ゅ鍦堛€佹湭杩涘弽寮圭鐨勬摝杈瑰懡涓笉鍙嶅脊锛岃溅杈嗙户缁琛屻€?
    local br = marble.radius * BALANCE.bounceBoxScale
    local closestX = math.max(rx, math.min(marble.x, rx + rw))
    local closestY = math.max(ry, math.min(marble.y, ry + rh))
    local dx = marble.x - closestX
    local dy = marble.y - closestY
    if dx * dx + dy * dy >= br * br then return false end

    local centerX = rx + rw * 0.5
    local centerY = ry + rh * 0.5
    local overlapX = math.abs(marble.x - centerX) / (rw * 0.5 + br)
    local overlapY = math.abs(marble.y - centerY) / (rh * 0.5 + br)

    if overlapX >= overlapY then
        marble.vx = -marble.vx
        if marble.x >= centerX then marble.x = rx + rw + br + 0.5
        else marble.x = rx - br - 0.5 end
    else
        marble.vy = -marble.vy
        if marble.y >= centerY then marble.y = ry + rh + br + 0.5
        else marble.y = ry - br - 0.5 end
    end
    return true
end

-- 鍙戝皠鍗曚釜鏂瑰潡鐨勭瑁傝瑙変簨浠讹紙鐏姳 + 鐙珛椋炴暎绠变綋锛夈€備笉淇敼瀛樻椿鐘舵€侊紝鐢辫皟鐢ㄦ柟璐熻矗銆?
-- scoreValue 涓烘湰娆″嚮纰庣殑鐪熷疄寰楀垎锛涜秺绾跨瑁傦紙鎯╃綒锛変笉浼狅紝琛ㄧ幇灞傛嵁姝や笉椋樺垎鏁般€?
local function EmitBrickShatterFx(enemy, brick, x, y, scoreValue)
    local angle = Random() * math.pi * 2
    -- v0.10.23锛氶檷浣庨鏁ｉ€熷害/涓婃姏锛岄伩鍏嶇鐗囬鍒板睆椤堕暱鏈熷爢绉€佷笌鏂板皬绮掑瓙鎶㈡垙銆?
    local speed = 120 + Random() * 150
    local lift = 80 + Random() * 90
    Emit("brick_hit", {
        enemyId = enemy.id, aircraftKey = enemy.aircraftKey,
        col = brick.col, row = brick.row, x = x, y = y,
        destroyed = true, score = scoreValue or 0,
    })
    Emit("brick_ejected", {
        enemyId = enemy.id, aircraftKey = enemy.aircraftKey,
        col = brick.col, row = brick.row, x = x, y = y,
        vx = math.cos(angle) * speed,
        vy = math.sin(angle) * speed - lift,
        rotation = Random() * math.pi * 2,
        angularVelocity = (Random() * 2 - 1) * 13,
        pitch = (Random() * 2 - 1) * 0.9,
        roll = (Random() * 2 - 1) * 0.9,
        axisPitchSpeed = (Random() * 2 - 1) * 8,
        axisRollSpeed = (Random() * 2 - 1) * 8,
        lifetime = 0.7 + Random() * 0.4,
        brickSize = enemy.brickSize,
        style = enemy.aircraftKey,
    })
end

EjectBrick = function(enemy, brick)
    if brick.ejected or not brick.alive then return false end
    local data = AircraftData[enemy.aircraftKey]
    local x = enemy.x + (brick.col - 0.5) * enemy.brickSize
    local y = enemy.y + (brick.row - 0.5) * enemy.brickSize
    brick.alive = false
    brick.ejected = true
    score = score + data.score
    bricksBroken = bricksBroken + 1
    -- v0.14.x 瀛橀挶缃愶細姣忓嚮纰?1 鍧楃疮绉?1 鐐硅繘搴︼紱绮捐嫳鏈烘瘡鍧楁寜 2 鍊嶈锛?> 绮捐嫳 100 榻胯疆 / 100 鍧楋級銆?
    settleBook.gear = settleBook.gear + (enemy.isElite and 2 or 1)
    -- v0.13.28锛氥€岃鐢插己鍖栥€嶇殑闆朵欢浜у嚭鍊嶇巼鍦ㄤ骇鍑虹偣缁熶竴缁撶畻锛堝嚮纰?娓呮満/杩囨尝/缁撶畻鍚屾簮锛夈€?
    partsEarned = partsEarned + PARTS_PER_BRICK * (partsBoostTime > 0 and 2 or 1) * BALL_TUNING.partsMul
    -- v0.13.28锛氥€岀┛鐢插脊澶淬€嶆瘡绾ч澶?+1 缁忛獙锛屼綆闅惧害涔熻兘绔嬪埢鍔犻€熷崌绾с€?
    GainXp(XP_PER_BRICK + BALL_TUNING.brickXpFlat)
    EmitBrickShatterFx(enemy, brick, x, y, data.score)
    -- 鏈€鍚庡瓨娲绘牸娑堝け鍗冲彂甯冨畬鏁村嚮姣佷簨瀹烇紱濂栧姳浠嶇暀鍦?UpdateEnemies锛屼笉鑳藉洜鍗囩骇鎻愬墠缁撶畻銆?
    if not enemy.breached then
        local fullyDestroyed = true
        for _, remaining in ipairs(enemy.bricks) do
            if remaining.alive then fullyDestroyed = false; break end
        end
        if fullyDestroyed then
            local width = enemy.gridW * enemy.brickSize
            local height = enemy.gridH * enemy.brickSize
            Emit("enemy_destroyed", {
                enemyId = enemy.id,
                x = enemy.x + width * 0.5, y = enemy.y + height * 0.5,
                width = width, height = height,
            })
        end
    end
    return true
end

-- 瓒婄嚎纰庤锛氳琛屾柟鍧楄劚绂荤紪闃熷苟鎾斁鐩稿悓椋炴暎瑙嗚锛屼絾涓嶅姞鍒嗐€佷笉缁欑粡楠?
-- 锛堝畠鏄€滅獊鐮撮槻绾库€濈殑鎯╃綒锛屼笉鏄鐜╁鍑荤锛夈€?
local function ShatterBreachedBrick(enemy, brick)
    if brick.ejected or not brick.alive then return end
    local x = enemy.x + (brick.col - 0.5) * enemy.brickSize
    local y = enemy.y + (brick.row - 0.5) * enemy.brickSize
    brick.alive = false
    brick.ejected = true
    EmitBrickShatterFx(enemy, brick, x, y)
end

local function DamageBrick(enemy, brick, damage)
    if brick.ejected or not brick.alive then return end
    if enemy.isBoss and enemy.vulnerable then
        damage = (damage or 1) * 1.5
    end
    -- v0.13.55銆岄湝瑁傛秱灞傘€嶏細鍐荤粨涓殑鏁屾満鍙楀嚮鏇寸棝锛堣剢鍖栫鍐帮級銆?
    if enemy.frozen and enemy.frozen > 0 and BALL_TUNING.iceShatter > 0 then
        damage = (damage or 1) * (1 + BALL_TUNING.iceShatter)
    end
    brick.hp = brick.hp - (damage or 1)
    if brick.hp <= 0 then
        EjectBrick(enemy, brick)
    else
        -- 瑁呯敳鍛戒腑涓嶈劚钀斤紱瀹為檯鑰愪箙鐢辨瘡涓夊叧澧為暱涓€娆＄殑 brick.hp 鍐冲畾銆?
        Emit("brick_hit", {enemyId = enemy.id, aircraftKey = enemy.aircraftKey,
            col = brick.col, row = brick.row,
            x = enemy.x + (brick.col - 0.5) * enemy.brickSize,
            y = enemy.y + (brick.row - 0.5) * enemy.brickSize,
            destroyed = false, score = 0})
    end
end

-- P11 浜斿紓甯稿弽搴旂郴缁燂紙瑙勫垯灞傦級锛氱爾鍧楀彲鎼哄甫 burn/shock/corrode/freeze/volatile 浜旂寮傚父鐘舵€侊紝
-- 鐢卞懡涓脊鐝犵殑璇嶆潯鎴栫被鍨嬫柦鍔狅紱鐘舵€侀棿瀛樺湪鍙嶅簲锛堝喕缁?鐏肩儳=铻嶇┛銆佺數鍑?鍐荤粨=纰庤锛夐澶栫粨绠椼€?
-- 浠呰褰曡鏃朵笌浼ゅ锛岃瑙夋煋鑹茬敱琛ㄧ幇灞傛帹杩熸秷璐?status 浜嬩欢銆?
local STATUS_BITS = {burn = 1, shock = 2, corrode = 4, freeze = 8, volatile = 16}
local STATUS_ORDER = {"burn", "shock", "corrode", "freeze", "volatile"}

local function ApplyBrickStatus(brick, status, duration, power)
    brick.status = brick.status or {}
    brick.statusMask = brick.statusMask or 0
    local bit = STATUS_BITS[status]
    if bit then brick.statusMask = brick.statusMask | bit end
    local cur = brick.status[status] or {time = 0, power = 0}
    cur.time = math.max(cur.time, duration)
    cur.power = math.max(cur.power, power or 1)
    brick.status[status] = cur
end

local function TickBrickStatus(enemy, brick, dt)
    if not brick.status then return end
    local x = enemy.x + (brick.col - 0.5) * enemy.brickSize
    local y = enemy.y + (brick.row - 0.5) * enemy.brickSize
    local hasFreeze = (brick.status.freeze and brick.status.freeze.time > 0)
    local hasBurn = (brick.status.burn and brick.status.burn.time > 0)
    -- 鍙嶅簲锛氬喕缁?+ 鐏肩儳 = 铻嶇┛锛屾瘡甯ц拷鍔犱激瀹冲苟鍔犻€熷喕缁撴秷閫€銆?
    if hasFreeze and hasBurn then
        brick.hp = brick.hp - (0.6 + brick.status.burn.power) * dt
        brick.status.freeze.time = brick.status.freeze.time - dt * 2
        if brick.hp <= 0 and brick.alive then
            EjectBrick(enemy, brick)
            Emit("status_reaction", {enemyId = enemy.id, kind = "melt", x = x, y = y})
        end
    elseif hasBurn then
        brick.hp = brick.hp - (0.35 + brick.status.burn.power) * dt
        if brick.hp <= 0 and brick.alive then
            EjectBrick(enemy, brick)
        end
    end
    -- 鑵愯殌锛氭寔缁墛鍑忚鐮栧潡鏈夋晥鎶ょ敳锛堣繖閲岀洿鎺ユ崲绠椾负姣忕灏忎激瀹筹級銆?
    if brick.status.corrode and brick.status.corrode.time > 0 then
        brick.hp = brick.hp - 0.25 * dt
        if brick.hp <= 0 and brick.alive then
            EjectBrick(enemy, brick)
        end
    end
    -- 鏄撴毚锛氬缁堟椂寮曠垎閭绘牸锛坴olatile锛夛紝棰濆鑼冨洿浼ゅ鐢?base_hit 椋庢牸浜嬩欢骞挎挱銆?
    local volatile = brick.status.volatile
    if volatile and volatile.time > 0 and not brick.alive and not volatile.detonated then
        volatile.detonated = true
        local radius = enemy.brickSize * (volatile.power or 1.5)
        local radiusSq = radius * radius
        for _, other in ipairs(enemy.bricks) do
            if other.alive and other ~= brick then
                local ox = enemy.x + (other.col - 0.5) * enemy.brickSize
                local oy = enemy.y + (other.row - 0.5) * enemy.brickSize
                local dx = ox - x; local dy = oy - y
                if dx * dx + dy * dy <= radiusSq then
                    DamageBrick(enemy, other, 1)
                end
            end
        end
        Emit("status_reaction", {enemyId = enemy.id, kind = "volatile", x = x, y = y})
    end
    for _, status in ipairs(STATUS_ORDER) do
        local s = brick.status[status]
        if s and s.time > 0 then s.time = s.time - dt end
    end
end

local function IsEnemyCleared(enemy)
    for _, brick in ipairs(enemy.bricks) do
        if brick.alive then return false end
    end
    return true
end

-- 骞稿瓨鑰呭崌绾э細鑾峰緱缁忛獙锛岃法绾ф椂绱寰呭鐞嗙殑鍗囩骇閫夋嫨銆?
GainXp = function(amount)
    if pendingLevelUps > 0 then
        deferredXp = deferredXp + amount
        return
    end
    xp = xp + amount * BALL_TUNING.xpMul
    while xp >= xpToNext do
        xp = xp - xpToNext
        playerLevel = playerLevel + 1
        xpToNext = math.floor(BALANCE.baseXpToNext * BALANCE.xpToNextGrowth ^ (playerLevel - 1))
        pendingLevelUps = pendingLevelUps + 1
    end
    if pendingLevelUps > 0 then
        -- v0.10.24锛氫笌 Pause 涓€鑷达紝杩涘叆鍗囩骇闈㈡澘鏃跺彇娑堣繘琛屼腑鐨勬嫋鎷藉苟璁╁緟鍙戣溅褰掍綅锛?
        -- 闃叉閫夊畬寮哄寲鍥炲埌 playing 鍚庢畫鐣欐棫 aiming/grabStart銆?
        Game.ClearLaunchCharge()
        aiming = false
        if activeBall then
            activeBall.x = SLING_X
            activeBall.y = SLING_Y
        end
        gameState = "levelup"
        Game.CancelHoldSpeed()
        RollUpgradeChoices({})
        Emit("level_up", {level = playerLevel})
        print("[Game] level up -> " .. playerLevel .. ", waiting for upgrade pick")
    end
end

---@class RollUpgradeOpts
---@field count integer|nil 鍊欓€夊崱鏁伴噺锛堢己鐪?3锛?
---@field forceRare boolean|nil 骞垮憡銆屽崱姹犲崌鏍笺€嶏細浼樺厛鎶界█鏈夊崱

---@param opts RollUpgradeOpts|nil
RollUpgradeChoices = function(opts)
    if Game._opening.active then
        -- 涓撶敤姹犲彧鍙栧洓寮犳棦鏈夎В閿佸崱锛涙棫妗ｄ篃鑳介€夎溅锛屼笉浼€犳案涔呭ぉ璧嬫垨鐢熷懡鍔犳垚銆?
        -- 绗竴杞洓绉嶅彇涓夛紝绗簩杞墿浣欎笁绉嶅叏閮ㄥ睍绀猴紱鏃犻噸澶?鍗犱綅/閲嶆娊淇濆簳鍓綔鐢ㄣ€?
        local available = {}
        for _, u in ipairs(UPGRADE_POOL) do
            if u.unlockBallType and not unlockedBalls[u.unlockBallType] then
                available[#available + 1] = u
            end
        end
        upgradeChoices = {}
        for _ = 1, math.min(PANEL_CARD_COUNT, #available) do
            local index = RandomInt(1, #available)
            upgradeChoices[#upgradeChoices + 1] = table.remove(available, index)
        end
        print("[Game] opening candidates round=" .. Game._opening.round .. " count=" .. #upgradeChoices)
        return
    end
    -- WO-09/P5锛氬姞鏉冩娊鍗?+ 鍙犲姞涓婇檺 + 绋€鏈変繚搴?+ 鍚屾鍊欓€夊幓閲嶃€?
    -- v0.11.0锛氭敮鎸佽嚜瀹氫箟鍊欓€夋暟涓庡箍鍛娿€屽崱姹犲崌鏍笺€嶇殑绋€鏈変繚搴曘€?
    opts = opts or {}
    local cardCount = math.max(1, math.floor(opts.count or PANEL_CARD_COUNT))
    local forceRare = opts.forceRare == true
    -- 鏆傚仠琛ョ粰绔欎拱鐨勩€屼繚搴曠█鏈夈€嶄竴娆℃€х敓鏁堝悗鍗虫竻绌恒€?
    if pendingRareRoll then
        forceRare = true
        pendingRareRoll = false
    end
    upgradeChoices = {}
    local sinceRare = 0
    local forcedRareDone = false
    local chosenThisRoll = {}
    if heldUpgradeId then
        for _, u in ipairs(UPGRADE_POOL) do
            if u.id == heldUpgradeId and CanOfferUpgrade(u) then
                upgradeChoices[1] = u
                chosenThisRoll[u.id] = true
                if u.rarity ~= "common" then forcedRareDone = true end
                break
            end
        end
        if upgradeChoices[1] == nil then heldUpgradeId = nil end
    end

    ---@param avail {u: UpgradeDef, w: number}[]
    ---@param rareOnly boolean
    ---@return UpgradeDef|nil
    local function PickWeighted(avail, rareOnly)
        local total = 0
        for _, candidate in ipairs(avail) do
            if not rareOnly or candidate.u.rarity ~= "common" then
                total = total + candidate.w
            end
        end
        if total <= 0 then return nil end
        local roll = Random() * total
        for _, candidate in ipairs(avail) do
            if not rareOnly or candidate.u.rarity ~= "common" then
                roll = roll - candidate.w
                if roll <= 0 then return candidate.u end
            end
        end
        for _, candidate in ipairs(avail) do
            if not rareOnly or candidate.u.rarity ~= "common" then
                return candidate.u
            end
        end
        return nil
    end

    for _ = #upgradeChoices + 1, cardCount do
        local avail = {}
        for _, u in ipairs(UPGRADE_POOL) do
            local stacks = upgradeStacks[u.id] or 0
            if CanOfferUpgrade(u) and not chosenThisRoll[u.id] then
                local w = u.weight
                -- v0.13.28锛氥€屽墠绾跨淮淇€嶇幇鍦ㄧ粰姘镐箙鐢熷懡涓婇檺锛屼笉鍐嶉殢鍙犲眰璐€硷紝鍙湪寰堥珮灞傛暟杞诲井闄嶆潈銆?
                if u.id == "repair" and stacks >= 8 then w = w * 0.6 end
                if u.id == "xp" and stacks >= 4 then w = w * 0.5 end
                avail[#avail + 1] = {u = u, w = w}
            end
        end
        if #avail == 0 then break end

        local picked
        -- 銆屽崱姹犲崌鏍笺€嶏細鏈棣栧紶寮哄埗绋€鏈夛紙璇ユ爣蹇楀彧鐢熸晥涓€娆★紝涓嶄緷璧?sinceRare锛夈€?
        if forceRare and not forcedRareDone then
            picked = PickWeighted(avail, true)
            if picked then forcedRareDone = true end
        end
        -- 甯歌绋€鏈変繚搴曪細杩炵画 6 寮犳櫘閫氬悗寮哄埗鍑虹█鏈夈€?
        if not picked and sinceRare >= 6 then
            picked = PickWeighted(avail, true)
        end
        if not picked then
            picked = PickWeighted(avail, false)
        end
        if not picked then break end

        if picked.rarity ~= "common" then
            sinceRare = 0
        else
            sinceRare = sinceRare + 1
        end
        chosenThisRoll[picked.id] = true
        upgradeChoices[#upgradeChoices + 1] = picked
    end

    -- 鎶藉崱鍊欓€変笉瓒虫椂浠嶅繀椤绘彁渚涘彲鐐瑰嚮鐨勫畬鏁村€欓€夛紝绂佹杩涘叆涓嶅彲鎭㈠鐨勭┖鍗囩骇鎬併€?
    if #upgradeChoices < cardCount then
        for _, u in ipairs(UPGRADE_POOL) do
            if #upgradeChoices >= cardCount then break end
            local duplicate = false
            for _, picked in ipairs(upgradeChoices) do
                if picked.id == u.id then duplicate = true; break end
            end
            if not duplicate and CanOfferUpgrade(u) then
                upgradeChoices[#upgradeChoices + 1] = u
            end
        end
    end
end

-- 鐢卞閮?UI 璋冪敤锛氶€夋嫨绗?index锛?-based锛夐」寮哄寲锛屾仮澶?playing銆?
-- v0.12.5 绮剧畝锛氶潰鏉垮箍鍛婅Е鐐规敹鏁涗负銆屽厤璐归噸鎶?+ 鐪嬪箍鍛婇噸鎶姐€嶏紝
-- 鍒犻櫎绗?4 寮犺В閿?/ 鍗曞崱鍗囨牸 / 棰濆鍐嶉€?/ 閫夊崱鍊掕鏃讹紙瑙︾偣杩囧瘑鎷涜嚧鍙嶆劅锛夈€?
---@param index integer
---@return boolean picked
function Game.PickUpgrade(index)
    if gameState ~= "levelup" or not upgradeChoices then return false end
    local choice = upgradeChoices[index]
    if Game._opening.active then
        if Game._opening.phase ~= "select" or Game._opening.timer > 0 then return false end
        if not choice or not choice.unlockBallType or unlockedBalls[choice.unlockBallType] then return false end
        local opening = Game._opening
        unlockedBalls[choice.unlockBallType] = true
        opening.selected[#opening.selected + 1] = choice.unlockBallType
        upgradeChoices = nil
        Emit("upgrade_picked", { id = choice.id, name = choice.name, stacks = 1 })
        print("[Game] opening picked round=" .. opening.round .. " vehicle=" .. choice.unlockBallType)
        -- 闃舵纭涓嶅啓缁忛獙鍗囩骇璐︽湰锛屾棦鏈夐€変腑闊虫晥/鍙嶉浠嶄繚鐣欍€?
        opening.phase = #opening.selected < opening.total and "between" or "ready"
        opening.timer = opening.durations[opening.phase]
        return true
    end
    if not choice or not CanOfferUpgrade(choice) then return false end

    local stacks = upgradeStacks[choice.id] or 0
    local times = math.min(choice.maxStacks - stacks, 1)
    if times <= 0 then return false end
    for _ = 1, times do
        choice.apply(stacks)   -- 浼犲叆褰撳墠灞傛暟锛屾敮鎸佽竟闄呴€掑噺
        stacks = stacks + 1
    end
    upgradeStacks[choice.id] = stacks
    if heldUpgradeId == choice.id then heldUpgradeId = nil end
    table.insert(upgradePicks, choice.id)
    Emit("upgrade_picked", {
        id = choice.id, name = choice.name, stacks = stacks,
    })
    print("[Game] upgrade picked: " .. choice.name .. " (stacks=" .. stacks .. ")")

    pendingLevelUps = pendingLevelUps - 1
    upgradeChoices = nil
    if pendingLevelUps > 0 then
        RollUpgradeChoices({})
        Emit("level_up", {level = playerLevel})
    else
        gameState = "playing"
        if deferredXp > 0 then
            local bufferedXp = deferredXp
            deferredXp = 0
            GainXp(bufferedXp)
        end
    end
    return true
end

function Game.GetUpgradeChoices()
    if gameState ~= "levelup" then return nil end
    local current = upgradeChoices
    if not current then return nil end
    local list = {}
    -- WO-10/P5锛氬崌绾у崱 delta 棰勮瀛楁锛孶I 鍙灞曠ず锛屼笉鍦ㄦ鍋氳鍒欒绠椼€?
    for _, c in ipairs(current) do
        table.insert(list, {
            id = c.id, name = c.name, desc = c.desc, detail = c.detail,
            value = c.value, rarity = c.rarity, kind = c.kind or "buff",
            ballType = c.ballType, unlockBallType = c.unlockBallType,
            stacks = upgradeStacks[c.id] or 0, maxStacks = c.maxStacks,
            tradeoff = c.tradeoff,
            held = heldUpgradeId == c.id,
            opening = Game._opening.active,
        })
    end
    return list
end

-- ============================================================================
-- v0.11.0 鍟嗕笟鍖栵細鍗囩骇闈㈡澘鍙樼幇鎺ュ彛銆?
-- 瑙勫垯灞傚彧鍥炵瓟銆岃兘涓嶈兘鍋氥€嶄笌銆屽仛浜嗕粈涔堛€嶏紝鏄惁鎾斁骞垮憡鐢辩紪鎺掑眰锛坢ain.lua锛夊喅瀹氥€?
-- ============================================================================

-- v0.13.64锛氭湰灞€鍏嶈垂閲嶆娊鎬绘鏁帮紙鍩虹 1 娆?+ 澶╄祴銆屽厤璐瑰埛鏂般€嶅姞鎴愶級銆?
-- 鎸?Game 琛紙涓嶅崰椤跺眰 local 妲斤紝鏈枃浠跺凡 199/200锛夈€?
---@return integer
function Game.GetFreeRerollTotal()
    return 1 + talentRerollBonus
end

---@return boolean
function Game.CanFreeReroll()
    return gameState == "levelup" and not Game._opening.active
        and upgradeRerollFreeUsed < Game.GetFreeRerollTotal()
end

---@return boolean
function Game.CanReroll()
    return gameState == "levelup" and not Game._opening.active and upgradeChoices ~= nil
end

-- 閿佷綇涓€寮犲凡鏈夊€欓€夊崱锛屼笅涓€娆″崌绾э紙鎴栨湰娆￠噸鎶斤級鍥哄畾淇濈暀鍦ㄩ浣嶏紱鍐嶆鐐瑰嚮瑙ｉ櫎銆?
---@param index integer
---@return boolean ok
function Game.ToggleHeldUpgrade(index)
    if gameState ~= "levelup" or Game._opening.active or not upgradeChoices then return false end
    local choice = upgradeChoices[index]
    if not choice then return false end
    heldUpgradeId = (heldUpgradeId == choice.id) and nil or choice.id
    Emit("upgrade_hold", {id = choice.id, held = heldUpgradeId == choice.id})
    print("[Game] upgrade hold " .. choice.id .. "=" .. tostring(heldUpgradeId == choice.id))
    return true
end

---@param mode string "free" | "ad_rare"
---@return boolean ok
function Game.RerollUpgrades(mode)
    if gameState ~= "levelup" or Game._opening.active or not upgradeChoices then return false end
    if mode == "free" then
        if upgradeRerollFreeUsed >= Game.GetFreeRerollTotal() then return false end
        upgradeRerollFreeUsed = upgradeRerollFreeUsed + 1
    end
    RollUpgradeChoices({ forceRare = (mode == "ad_rare") })
    Emit("upgrade_reroll", {mode = mode})
    print("[Game] upgrade reroll mode=" .. mode)
    return true
end

-- ============================================================================
-- 鏆傚仠琛ョ粰绔欙紙鐪嬪箍鍛婏紝鍗曞眬闄愰噺锛夈€傝鍒欏眰鍙垽瀹氥€岃兘涓嶈兘鐢ㄣ€嶏紝骞垮憡鐢辩紪鎺掑眰鎾€?
-- ============================================================================

---@return boolean
function Game.CanPauseHeal()
    return gameState == "paused" and pauseHealUsed < PAUSE_SUPPLY.healMax and baseHp < GetMaxBaseHp()
end

---@return integer 鍓╀綑鍙敤娆℃暟
function Game.GetPauseHealLeft()
    return math.max(0, PAUSE_SUPPLY.healMax - pauseHealUsed)
end

---@return boolean ok
function Game.PauseHeal()
    if not Game.CanPauseHeal() then return false end
    pauseHealUsed = pauseHealUsed + 1
    baseHp = math.min(GetMaxBaseHp(), baseHp + PAUSE_SUPPLY.healAmount)
    Emit("base_healed", {amount = PAUSE_SUPPLY.healAmount, hp = baseHp})
    print("[Game] pause supply: base healed to " .. baseHp)
    return true
end

---@return boolean
function Game.CanPauseRarePick()
    return gameState == "paused" and pauseRareUsed < PAUSE_SUPPLY.rareMax
end

---@return integer
function Game.GetPauseRareLeft()
    return math.max(0, PAUSE_SUPPLY.rareMax - pauseRareUsed)
end

-- 涔般€屼笅涓€涓己鍖栭潰鏉夸繚搴曞嚭绋€鏈夈€嶃€?
---@return boolean ok
function Game.PauseRarePick()
    if not Game.CanPauseRarePick() then return false end
    pauseRareUsed = pauseRareUsed + 1
    pendingRareRoll = true
    Emit("rare_roll_armed", {})
    print("[Game] pause supply: next upgrade roll guaranteed rare")
    return true
end

function Game.CanPauseOrbital()
    if gameState ~= "paused" or pauseOrbitalUsed then return false end
    for _, enemy in ipairs(veggies) do
        if enemy.isBoss and not enemy.dead then return true end
    end
    return false
end

function Game.PauseOrbital()
    if not Game.CanPauseOrbital() then return false end
    pauseOrbitalUsed = true
    local destroyed = 0
    for _, enemy in ipairs(veggies) do
        if enemy.isBoss and not enemy.dead then
            for _, brick in ipairs(enemy.bricks) do
                if brick.alive and (brick.col + brick.row) % 4 == 0 then
                    if EjectBrick(enemy, brick) then destroyed = destroyed + 1 end
                end
            end
        end
    end
    Emit("orbital_strike", {count = destroyed})
    print("[Game] orbital strike destroyed=" .. destroyed)
    return true
end

function Game.CanPauseReload()
    return gameState == "paused" and not pauseReloadUsed
end

function Game.PauseReload()
    if not Game.CanPauseReload() then return false end
    pauseReloadUsed = true
    -- v0.13.19锛氬厹搴曠敤鍒濆杞︾被鍨嬶紙鍔犻€熻溅锛夛紝涓嶅啀鍐欐鍒嗚杞︺€?
    local nextType = ballQueue[1] or (activeBall and activeBall.ballType) or STARTING_BALL_TYPE
    table.insert(ballQueue, 1, nextType)
    if not activeBall and (nextType ~= "normal" or Game._NormalMarbleSlots() > 0) then
        activeBall = CreateMarble(table.remove(ballQueue, 1), CollectActiveWords())
    end
    Emit("marble_reloaded", {ballType = nextType})
    print("[Game] reserve ammo +1: " .. nextType)
    return true
end

function Game.CanPausePartsBoost()
    return gameState == "paused" and not pausePartsBoostUsed
end

function Game.PausePartsBoost()
    if not Game.CanPausePartsBoost() then return false end
    pausePartsBoostUsed = true
    partsBoostTime = 45
    Emit("parts_boost", {duration = 45})
    print("[Game] parts x2 for 45 seconds")
    return true
end

-- ============================================================================
-- 灞€鍐呴亾鍏锋Ы锛坴0.11.0 鍟嗕笟鍖?P4锛夈€?
-- 涓夋牸锛氱偢寮?/ 鍐板喕 / 鎶ょ浘銆傛瘡鏍煎崟灞€鍙敤骞垮憡鑾峰彇 1 娆★紝鑾峰彇鍚庣偣涓€涓嬬珛鍗崇敓鏁堛€?
-- 瑙勫垯灞傚彧绠°€岃兘涓嶈兘鎷?/ 鎷垮埌娌?/ 鐢ㄤ簡浠€涔堟晥鏋溿€嶏紝骞垮憡鎾斁鐢辩紪鎺掑眰鍐冲畾銆?
-- ============================================================================

---@class ItemDef
---@field key string
---@field name string
---@field color integer[] 妲戒綅涓昏壊锛圲I 鍙锛?

---@type ItemDef[]
local ITEM_DEFS = {
    { key = "bomb",   name = "鐐稿脊", color = {196, 120, 255} },
    { key = "freeze", name = "鍐板喕", color = {120, 216, 255} },
    { key = "shield", name = "鎶ょ浘", color = {90, 200, 255} },
}
local ITEM_BY_KEY = {}
for i = 1, #ITEM_DEFS do ITEM_BY_KEY[ITEM_DEFS[i].key] = ITEM_DEFS[i] end

---@type table<string, integer>
local itemCharges = { bomb = 0, freeze = 0, shield = 0 }  -- 妲戒綅瀛橀噺
---@type table<string, boolean>
local itemGranted = {}                                     -- 鏈眬鏄惁宸茬敤骞垮憡棰嗚繃
-- v0.13.13锛氬眬澶栦拱鏉ョ殑姘镐箙搴撳瓨锛堥€夊叧鐣岄潰鑺遍浂浠惰喘涔帮級锛岃繘灞€鏃舵敞鍏ャ€?
-- 瑙勫垯锛?*姣忕閬撳叿姣忓眬鏈€澶氫娇鐢ㄤ竴娆?*锛堢敤鎴疯姹傦紝涓嶅湪 UI 閲屽啓鏄庯紝闈犵簿鐏垫槑鏆?瑙掓爣琛ㄨ揪锛夈€?
---@type table<string, integer>
local itemStock = { bomb = 0, freeze = 0, shield = 0 }
---@type table<string, boolean>
local itemUsedThisRun = {}                                 -- 鏈眬璇ラ亾鍏锋槸鍚﹀凡鐢ㄨ繃
local FREEZE_SECONDS = 6.0                                 -- 鍐板喕鎸佺画锛坴0.13.58锛? 鈫?6锛屽姞寮猴級
local SHIELD_POINTS = 60                                   -- 鎶ょ浘鍚告敹閲忥紙v0.13.58锛?0 鈫?60锛屽姞寮猴級

ResetItems = function()
    itemCharges = { bomb = 0, freeze = 0, shield = 0 }
    itemGranted = {}
    itemUsedThisRun = {}
    -- 鎶婃案涔呭簱瀛樻敞鍏ユ湰灞€妲戒綅锛堟瘡鏍?1 涓紱鏈眬闄愮敤涓€娆＄敱 itemUsedThisRun 鍏滃簳锛夈€?
    for i = 1, #ITEM_DEFS do
        local key = ITEM_DEFS[i].key
        if (itemStock[key] or 0) > 0 then
            itemCharges[key] = 1
        end
    end
end

-- 灞€澶栧簱瀛樼敱缂栨帓灞傚湪寮€灞€鍓嶆敞鍏ワ紙PlayerData 鈫?Game锛夈€?
---@param stock table<string, integer>
function Game.SetItemStock(stock)
    itemStock = { bomb = 0, freeze = 0, shield = 0 }
    for i = 1, #ITEM_DEFS do
        local key = ITEM_DEFS[i].key
        itemStock[key] = math.max(0, math.floor((stock and stock[key]) or 0))
    end
end

-- v0.13.13锛氬簱瀛?provider鈥斺€擱esetGame 姣忔寮€灞€鑷姩鎷夊彇锛?
-- 瑕嗙洊銆岄€夊叧 / 涓嬩竴鍏?/ 鍐嶆垬 / 閲嶅紑銆嶅叏閮ㄥ叆鍙ｏ紝閬垮厤閫愪釜鍏ュ彛鎵嬪姩娉ㄥ叆婕忔帀銆?
---@param fn fun(): table<string, integer>
function Game.SetItemStockProvider(fn)
    itemStockProvider = fn
end

---@return table<string, integer>
function Game.GetItemStock()
    return itemStock
end

---@param key string
---@return boolean
function Game.CanGrantItem(key)
    if gameState ~= "playing" then return false end
    if not ITEM_BY_KEY[key] then return false end
    return itemGranted[key] ~= true
end

---@param key string
---@return integer
function Game.GetItemCharges(key)
    return itemCharges[key] or 0
end

-- 骞垮憡鐪嬪畬鍚庡彂鏀惧埌妲戒綅銆?
---@param key string
---@return boolean ok
function Game.GrantItem(key)
    if not Game.CanGrantItem(key) then return false end
    itemGranted[key] = true
    itemCharges[key] = (itemCharges[key] or 0) + 1
    Emit("item_granted", {key = key})
    print("[Game] item granted: " .. key)
    return true
end

---@param key string
---@return boolean
function Game.CanUseItem(key)
    if gameState ~= "playing" then return false end
    -- v0.13.13锛氭瘡绉嶉亾鍏锋瘡灞€鏈€澶氫娇鐢ㄤ竴娆★紙鏃犺搴撳瓨澶氬皯锛夈€?
    if itemUsedThisRun[key] then return false end
    return (itemCharges[key] or 0) > 0
end

-- 绔嬪嵆鐢熸晥銆傜偢寮?鍏ㄥ満姣忔満鐐告帀鏁版牸锛涘啺鍐?鍏ㄥ満鍐荤粨锛涙姢鐩?闃茬嚎鑾峰緱鍚告敹鍊笺€?
---@param key string
---@return boolean ok
function Game.UseItem(key)
    if not Game.CanUseItem(key) then return false end
    itemCharges[key] = itemCharges[key] - 1
    itemUsedThisRun[key] = true

    if key == "bomb" then
        local popped = 0
        for _, enemy in ipairs(veggies) do
            if not enemy.dead then
                local live = {}
                for _, brick in ipairs(enemy.bricks) do
                    if brick.alive then live[#live + 1] = brick end
                end
                -- v0.13.58锛氱偢寮瑰姞寮衡€斺€旀瘡鏈虹偢鎺夈€屽瓨娲绘牸鏁扮殑涓€鍗婏紙鍚戜笂鍙栨暣锛夈€嶏紝
                -- 鏈€澶?12 鏍硷紙鍘熶负鍥哄畾 4 鏍硷級銆傛墦婊＄紪闃熸椂鏄庢樉娓呭満锛屼絾浠嶉潪涓€閿叏娓呫€?
                local take = math.min(12, math.ceil(#live * 0.5))
                for _ = 1, take do
                    local idx = RandomInt(1, #live)
                    local brick = table.remove(live, idx)
                    if EjectBrick(enemy, brick) then popped = popped + 1 end
                end
            end
        end
        Emit("item_used", {key = key, count = popped})
        print("[Game] bomb used, bricks=" .. popped)
        return true
    end

    if key == "freeze" then
        for _, enemy in ipairs(veggies) do
            if not enemy.dead then
                enemy.frozen = FREEZE_SECONDS
                enemy.freezeRatio = 1
            end
        end
        Emit("item_used", {key = key, duration = FREEZE_SECONDS})
        print("[Game] freeze used for " .. FREEZE_SECONDS .. "s")
        return true
    end

    if key == "shield" then
        baseShield = baseShield + SHIELD_POINTS
        Emit("item_used", {key = key, amount = SHIELD_POINTS})
        print("[Game] shield used, shield=" .. baseShield)
        return true
    end

    return false
end

---@return ItemDef[]
function Game.GetItemDefs()
    return ITEM_DEFS
end

-- ============================================================================
-- 灞€鍐呴檮榄斿崱锛坴0.13.58锛夈€?
-- 姣忓畬鎴愪竴娉㈣幏寰?鏇存崲涓€寮犻檮榄斿崱锛屾樉绀哄湪宸︿笂瑙掞紙涓庡彸涓婇亾鍏风珫鍒楀绉帮級銆?
-- 浣跨敤鍚庡崱鐗囨秷澶憋紝鏁堟灉浣滅敤鍦?*棰勫鍙戝皠鐨勮溅**涓婏紱鑻ュ綋鍓嶆病鏈夊緟鍙戣溅锛堢悆鍦ㄩ/琛ュ脊涓級锛?
-- 鍒欓『寤剁粰銆屼笅涓€涓澶囧彂灏勭殑杞︺€嶃€傜█鏈夊害钃?绱?榛勶紝娉㈡瓒婇珮瓒婂鏄撳嚭楂樼█鏈夊害銆?
-- 瑙勫垯灞傚彧鍒ゅ畾銆岃兘涓嶈兘鐢?/ 鐢ㄤ簡浠€涔堟晥鏋溿€嶏紝缁樺埗涓庡懡涓湪 UI 灞傘€?
-- ============================================================================

-- 鎶婇檮榄斿崱鎸傚埌涓€棰楀脊鐝犱笂锛堟敼鍐欒涓哄瓧娈碉紱涓嶆敼寮圭瀹氫箟锛岀姝㈢‖缂栫爜鍒版覆鏌撳眰锛夈€?
---@param marble table
---@param card EnchantDef|nil
ApplyEnchantToMarble = function(marble, card)
    if not marble or not card then return end
    marble.enchant = card
    if card.pierce then marble.enchantPierce = card.pierce end
    Emit("enchant_applied", {
        id = marble.id, cardId = card.id, name = card.name, rarity = card.rarity,
    })
end

-- 褰撳墠鏄惁鏈夐檮榄斿崱鍦ㄦ墜銆?
---@return boolean
function Game.HasEnchant()
    return Game._enchant.card ~= nil
end

-- 鑳戒笉鑳戒娇鐢ㄩ檮榄斿崱锛氬彧鍦ㄦ垬鏂椾腑銆佷笖鎵嬩笂鏈夊崱鏃跺彲鐢ㄣ€?
---@return boolean
function Game.CanUseEnchant()
    return gameState == "playing" and Game._enchant.card ~= nil
end

-- 浣跨敤闄勯瓟鍗°€傛湁棰勫鍙戝皠鐨勮溅 鈫?绔嬪嵆鐢熸晥锛涘惁鍒欓『寤剁粰涓嬩竴涓澶囧彂灏勭殑杞︺€?
-- 鏃犺绔嬪嵆鐢熸晥杩樻槸椤哄欢锛屽崱鐗囬兘浼氫粠鎵嬩笂娑堝け锛堢敤鎺夊嵆娑堣€楋級銆?
---@return boolean ok
function Game.UseEnchant()
    if not Game.CanUseEnchant() then return false end
    local card = Game._enchant.card
    Game._enchant.card = nil
    if activeBall then
        ApplyEnchantToMarble(activeBall, card)
        print("[Game] enchant applied immediately: " .. card.id)
    else
        Game._enchant.pending = card
        Emit("enchant_armed", {cardId = card.id, name = card.name, rarity = card.rarity})
        print("[Game] enchant deferred to next vehicle: " .. card.id)
    end
    return true
end

-- 鏂颁竴娉㈠畬鎴愭椂鍙戞斁/鏇存崲涓€寮犻檮榄斿崱銆傜敱 UpdateWaveLogic 鍦ㄦ尝娆℃帹杩涘璋冪敤涓€娆°€?
local function GrantEnchant()
    local card = EnchantCatalog.Roll(wave, Random)
    Game._enchant.card = card
    Emit("enchant_granted", {
        cardId = card.id, name = card.name, rarity = card.rarity, wave = wave,
    })
    print("[Game] enchant granted at wave " .. wave .. ": " .. card.id .. " (" .. card.rarity .. ")")
end

-- 璇诲彇褰撳墠闄勯瓟鐘舵€侊紙渚涙覆鏌撳眰鍙灞曠ず锛夈€?
---@return {card: EnchantDef|nil, pending: EnchantDef|nil}
function Game.GetEnchantState()
    return { card = Game._enchant.card, pending = Game._enchant.pending }
end

local function RotateVelocity(vx, vy, degrees)
    local radians = math.rad(degrees)
    local c = math.cos(radians)
    local s = math.sin(radians)
    return vx * c - vy * s, vx * s + vy * c
end

local function CreateSplitMarble(source, angle, originBrick)
    local vx, vy = RotateVelocity(source.vx, source.vy, angle)
    local marble = {
        id = nextMarbleId,
        x = source.x, y = source.y,
        vx = vx, vy = vy,
        radius = source.radius,
        speed = source.speed,
        ballType = "normal",
        onSling = false,
        alive = true,
        bounceCount = source.bounceCount,
        isPrimary = false,
        generation = source.generation + 1,
        flightTime = 0,
        -- 鍒嗚缁ф壙姣嶈溅褰撳墠鎷栧熬骞撮緞锛堛€屽垎瑁傝涓虹户鎵块暱搴︺€嶏級锛氭柊瀛愯溅涓嶄粠 0 閲嶆柊璁℃椂銆?
        trailAge = source.trailAge or 0,
        ignoredBrick = originBrick,
        giantPiercing = false,
    }
    -- v0.13.58锛氬垎瑁傚瓙杞︾户鎵挎瘝杞︾殑闄勯瓟锛堝惁鍒欍€岃鍙?鍚歌/杩借釜銆嶇瓑鍗″湪鍒嗚鍚庡嵆澶辨晥锛夈€?
    -- 鈿狅笍 浣嗘爣璁颁负瀛愯溅鈥斺€斿懡涓椂涓嶅啀瑙﹀彂銆岃鍙樸€嶇殑 splitOnHit锛屽惁鍒欏瓙杞﹀啀鍒嗚浼氭棤闄愰€掑綊
    --    锛堣櫧琚?maxConcurrent=15 鍏滀綇锛屼絾浼氳灞忎笂姘镐箙濉炴弧 15 棰楋級銆?
    marble.enchant = source.enchant
    marble.enchantPierce = source.enchantPierce
    marble.enchantIsChild = true
    -- 鍚屾鍙戝皠鐨勫垎瑁?闄勯瓟杩藉姞瀛愯溅缁ф壙璧勬牸锛屼笉绱箻锛涘洖鏀跺悗鐨勬柊寰呭彂杞﹂粯璁?false銆?
    marble.chargeBoosted = source.chargeBoosted == true
    nextMarbleId = nextMarbleId + 1
    return marble
end

local function TrySplitNormal(marble, originBrick, pendingMarbles)
    local def = BALL_TYPES.normal
    if Random() >= def.splitChance + BALL_TUNING.splitBonus then return end

    -- v0.13.55銆岃鍙樻牳銆嶏細鍒嗚鏁伴噺鐢?splitCount 鍐冲畾锛堝熀纭€ 2 棰楋紝涓撳睘鍗℃瘡绾?+1锛夈€?
    -- 棰勭畻鍚屾椂鎵ｉ櫎姣嶅脊銆佸緟鍙戣溅鍜屾湰甯у緟鍔犲叆鐨勫瓙寮癸紱涓嶈冻鏃跺彧鐢熸垚鍓╀綑鍚嶉銆?
    local count = math.min(math.max(2, math.floor(BALL_TUNING.splitCount or 2)),
        Game._NormalMarbleSlots(pendingMarbles))
    if count <= 0 then return end
    -- 浠ユ瘝寮归€熷害鏂瑰悜涓轰腑蹇冮摵寮€锛涘彧鍓╀竴涓悕棰濇椂灞呬腑锛岄伩鍏嶆亽鍚戝乏鍋忋€?
    -- v0.13.58锛氭瘡棰楀瓙杞﹀湪鍩哄噯瑙掍笂鍙?卤5掳 闅忔満鍋忕Щ鈥斺€斾腑闂寸殑锛堝熀鍑?0掳锛変笉鍐嶆案杩滆蛋姝ｅ墠鏂癸紝
    -- 鏁翠釜鎵囧舰涔熺暐寰殢鏈哄寲锛岃鎰熸洿鑷劧銆傚亸绉讳笂闄愬浐瀹?5掳锛屼笉鏀瑰彉鍒嗚鏁伴噺涓庨摵寮€瀹藉害銆?
    local spread = def.splitSpread or 18
    for i = 1, count do
        local angle = count == 1 and 0 or -spread + (2 * spread) * (i - 1) / (count - 1)
        angle = angle + (Random() * 10 - 5)
        table.insert(pendingMarbles,
            CreateSplitMarble(marble, angle, originBrick))
    end
    Emit("normal_split", {
        x = marble.x, y = marble.y,
        generation = marble.generation + 1,
        count = count,
    })
    print("[Game] normal marble split, generation=" .. (marble.generation + 1) .. " count=" .. count)
end

local function FindNearestBrick(originEnemy, originBrick, originX, originY)
    local nearest = nil
    local nearestDistanceSq = math.huge
    -- 纰版挒鍖哄彧閬嶅巻浠嶅湪缂栭槦涓殑 alive 鏂瑰潡锛沞jected 鏂瑰潡涓嶄細鍐嶆鍛戒腑銆?
    for _, enemy in ipairs(veggies) do
        if not enemy.dead then
            for _, brick in ipairs(enemy.bricks) do
                if brick.alive and not brick.ejected and not (enemy == originEnemy and brick == originBrick) then
                    local x = enemy.x + (brick.col - 0.5) * enemy.brickSize
                    local y = enemy.y + (brick.row - 0.5) * enemy.brickSize
                    local dx = x - originX
                    local dy = y - originY
                    local distanceSq = dx * dx + dy * dy
                    if distanceSq < nearestDistanceSq then
                        nearestDistanceSq = distanceSq
                        nearest = {x = x, y = y}
                    end
                end
            end
        end
    end
    return nearest
end

local function BoostSpeedMarble(marble)
    local def = BALL_TYPES.speed
    if marble.ballType ~= "speed" then return end

    -- v0.13.22锛氫笉鍐嶆湁閫熷害涓婇檺锛堝師 effMax = maxSpeed * speedMul锛夈€?
    -- v0.13.23锛氬姞閫熷€嶇巼闅忓綋鍓嶉€熷害**杞€ч€掑噺**鈥斺€斾粠**鍒濆閫熷害**璧风畻锛屽埌 speedSoftCap 鏃堕檷鍒颁笅闄愶紝
    -- 涔嬪悗鎭掑畾鎸変笅闄愮ǔ姝ュ闀匡紙浠嶄弗鏍?>1锛岄€熷害姘歌繙鍦ㄦ定銆佹棤纭笂闄愶級銆?
    -- 渚嬶細鍒濋€?660 鏃?脳1.06锛堜笉鍚冭“鍑忥級锛?400 鍙婁互涓婃亽 脳1.012銆?
    local boost = def.speedBoost
    local softCap = def.speedSoftCap
    if softCap and softCap > def.speed then
        local t = math.min(1, math.max(0, (marble.speed - def.speed) / (softCap - def.speed)))
        boost = def.speedBoost + (def.speedBoostFloor - def.speedBoost) * t
    end
    -- speedMul锛堝ぉ璧?鍗★級浣滀负銆屽姞閫熷害鍔犳垚銆嶅彔鍔犲湪鍊嶇巼涓娿€?
    local gain = boost + (BALL_TUNING.speedMul - 1.0) * 0.1
    marble.speed = marble.speed * gain
    local velocityLength = math.sqrt(marble.vx * marble.vx + marble.vy * marble.vy)
    if velocityLength > 0.001 then
        marble.vx = marble.vx / velocityLength * marble.speed
        marble.vy = marble.vy / velocityLength * marble.speed
    end
end

-- v0.13.15锛氬ぉ璧嬨€屽熀纭€鏀诲嚮 +N銆嶇洿鎺ュ苟鍏ヤ激瀹冲姞鎴愶紙瀵规墍鏈夊脊绉嶇敓鏁堬級銆?
local function TalentDamageBonus()
    return talentAtkBonus
end

-- 鏆村嚮鍒ゅ畾锛氭寜澶╄祴鏆村嚮鐜囨幏涓€娆★紱鍛戒腑鍒欎激瀹?脳TalentCatalog.CRIT_MULT銆?
-- 鈿狅笍 GetMarbleDamage 浼氬湪瀛愭杩涢噷琚娆¤皟鐢紝浣嗘瘡娆¤皟鐢ㄩ兘瀵瑰簲銆屼竴娆″懡涓粨绠椼€嶏紝
-- 涓斿悓涓€甯у悓涓€鐮栧潡宸茬敱 frameHitBricks 鍘婚噸锛屽洜姝や笉浼氶噸澶嶆幏銆?
---@param base number
---@param marble table|nil 鐢ㄤ簬缁欒〃鐜板眰鎻愪緵椋樺瓧鍧愭爣
---@return number damage
local function ApplyCrit(base, marble)
    if talentCritChance <= 0 then return base end
    if Random() >= talentCritChance then return base end
    if marble then
        Emit("crit_hit", { x = marble.x, y = marble.y, damage = base * TalentCatalog.CRIT_MULT })
    end
    return base * TalentCatalog.CRIT_MULT
end

local function GetMarbleDamage(marble, def)
    local base
    if marble.ballType ~= "speed" then
        base = def.damage + BALL_TUNING.damageBonus + TalentDamageBonus()
    else
        -- v0.13.22锛氬姞閫熻溅浼ゅ鎸夐€熷害鍒嗘。**鏃犻檺澧為暱**锛堝師 min(maxDamage, ...) 灏侀《宸插幓锛夈€?
        local bonus = math.floor(math.max(0, marble.speed - def.speed) / def.damageStep)
        base = def.damage + bonus + BALL_TUNING.damageBonus + TalentDamageBonus()
    end
    -- v0.13.58锛氶檮榄斻€岄噸鍑汇€嶁€斺€旂洿鎺ユ斁澶ф湰娆″脊鐝犵殑鍩虹浼ゅ銆?
    if marble.enchant and marble.enchant.damageMul then
        base = base * marble.enchant.damageMul
    end
    -- 浠呭寮烘湰娆¤溅杈嗕激瀹筹紱鍦嗗煙/杩為攣/鐖嗙偢閮戒粠姝ゅ叆鍙ｅ彇鍊硷紝涓嶅湪 DamageBrick 鍐嶄箻銆?
    if marble.chargeBoosted then base = base * 1.5 end
    -- 鏆村嚮鍙奖鍝嶆湰娆＄粨绠楋紝涓嶆敼寮圭彔鐘舵€侊紱琛ㄧ幇灞傛秷璐?crit_hit 鍑洪瀛椼€?
    return ApplyCrit(base, marble)
end

local function RedirectSpeedMarble(marble, originEnemy, originBrick)
    -- 鍓婂急锛氬彈 redirectThrottle 鑺傛祦锛岄伩鍏嶆瘡娆″懡涓兘榛忕潃杩借釜銆?
    -- WO-05/P4锛氫綆浜?redirectMinSpeed 涓嶈拷鍑伙紝娑堥櫎浣庨€熸杞ㄨ抗鎶栧姩銆?
    if marble.speed < (BALL_TYPES.speed.redirectMinSpeed or 0) then return end
    local target = FindNearestBrick(originEnemy, originBrick, marble.x, marble.y)
    if not target then return end
    if (marble.redirectCooldown or 0) > 0 then return end
    marble.redirectCooldown = BALL_TYPES.speed.redirectThrottle

    local dx = target.x - marble.x
    local dy = target.y - marble.y
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance < 0.001 then return end

    marble.vx = dx / distance * marble.speed
    marble.vy = dy / distance * marble.speed
    Emit("speed_dash", {
        x = marble.x, y = marble.y,
        targetX = target.x, targetY = target.y,
        damage = GetMarbleDamage(marble, BALL_TYPES.speed),
    })
end

local function ArmGiantPiercing(marble)
    local def = BALL_TYPES.giant
    if marble.ballType ~= "giant" or not def.pierceAfterBounce or marble.giantPiercing then
        return
    end
    if (marble.giantAreaCooldown or 0) > 0 then
        marble.giantPiercePending = true
        return
    end
    marble.giantPiercePending = false
    marble.giantPiercing = true
    -- 鍙湁鍐峰嵈缁撴潫鎵嶅彂甯冨氨缁紝琛ㄧ幇灞傛嵁姝ゆ彁绀恒€屽彲浠ヨ疮绌裤€嶃€?
    Emit("giant_pierce_armed", {id = marble.id, x = marble.x, y = marble.y})
    print("[Game] giant marble circular piercing ready id=" .. tostring(marble.id))
end

-- 宸ㄥ瀷寮硅疮绌夸激瀹冲尯锛氫互鍛戒腑鐮栧潡涓績涓哄渾蹇冿紝鐩村緞 7 涓晫鏂瑰崟鍏冩牸銆?
--
--          o o o
--        o o o o o
--      o o o X o o o    X = 鍛戒腑鏍?
--        o o o o o       鍗婂緞 = 3.5 脳 鍛戒腑鏁屼汉鐨勫崟鏍煎昂瀵?
--          o o o
--
-- 鍦嗗舰杈圭紭鎸夌爾鍧椾腑蹇冨垽鏂紱璺ㄦ晫浜轰絾浠嶅湪鍦嗗唴鐨勫崟鍏冩牸涔熶細鍙楀埌浼ゅ銆?
local function DamageGiantArea(originEnemy, originBrick, damage, frameHitBricks)
    local centerX = originEnemy.x + (originBrick.col - 0.5) * originEnemy.brickSize
    local centerY = originEnemy.y + (originBrick.row - 0.5) * originEnemy.brickSize
    local radius = originEnemy.brickSize * (BALL_TYPES.giant.areaRadiusCells + BALL_TUNING.giantArea)
    local radiusSq = radius * radius
    local hitCount = 0

    for _, enemy in ipairs(veggies) do
        if not enemy.dead then
            for _, brick in ipairs(enemy.bricks) do
                if brick.alive and not brick.ejected and not frameHitBricks[brick] then
                    local x = enemy.x + (brick.col - 0.5) * enemy.brickSize
                    local y = enemy.y + (brick.row - 0.5) * enemy.brickSize
                    local dx = x - centerX
                    local dy = y - centerY
                    if dx * dx + dy * dy <= radiusSq then
                        frameHitBricks[brick] = true
                        -- v0.13.55銆屽啿鍑绘尝銆嶏細鑼冨洿鍑荤鎸夋鐜囨毚鍑伙紙鍙屽€嶄激瀹筹級锛屽鐢ㄦ毚鍑婚瀛椼€?
                        local cellDamage = damage
                        if BALL_TUNING.giantCritChance > 0 and Random() < BALL_TUNING.giantCritChance then
                            cellDamage = damage * 2
                            Emit("crit_hit", { x = x, y = y, damage = cellDamage })
                        end
                        DamageBrick(enemy, brick, cellDamage)
                        hitCount = hitCount + 1
                    end
                end
            end
        end
    end

    Emit("giant_area_hit", {
        x = centerX, y = centerY,
        radius = radius, hitCount = hitCount,
    })
end

local function LaunchMarble(dx, dy, power)
    if not activeBall then return end
    local length = math.sqrt(dx * dx + dy * dy)
    if length < 1 then return end
    Game.CancelHoldSpeed()

    local def = BALL_TYPES[activeBall.ballType]
    -- WO-08/P7锛歱ower 涓哄綊涓€鍖栬搫鍔?(0..1)锛屾槧灏勫埌 [powerMin, powerMax] 鍒濋€熸瘮渚嬨€?
    local powerRatio = math.max(0, math.min(1, power or 0))
    local speedScale = BALANCE.powerMin + (BALANCE.powerMax - BALANCE.powerMin) * powerRatio
    -- v0.13.28锛氥€岀幓鐠冨法鐐€嶇殑鍙戝皠鍒濋€熷€嶇巼鈥斺€斾綆闅惧害鐮栧潡 1 琛€鏃朵激瀹虫槸婧㈠嚭锛屼絾鏇村揩鐨勫脊閬撶珛鍒绘湁鎰熴€?
    local speed = def.speed * speedScale * BALL_TUNING.launchSpeedMul
    -- v0.13.64锛氳搫鍔涘凡杈?85% 鏃跺彂灏?鈫?绔嬪埢琛ユ弧锛屼韩鍙楁弧钃勪激瀹充笌鍏ㄦ伅鐖嗗彂锛堜笉蹇呯瓑鍒?100%锛夈€?
    local charge = Game._launchCharge
    if charge.total > 0 and charge.time / charge.total >= BALANCE.chargeCompleteThreshold then
        charge.time = charge.total
    end
    activeBall.chargeBoosted = charge.time >= charge.total
    activeBall.vx = -dx / length * speed
    activeBall.vy = -dy / length * speed
    activeBall.speed = speed
    activeBall.onSling = false
    activeBall.flightTime = 0
    hasLaunched = true
    table.insert(marbles, activeBall)
    Emit("marble_launched", {
        id = activeBall.id,
        ballType = activeBall.ballType,
        x = activeBall.x,
        y = activeBall.y,
        chargeBoosted = activeBall.chargeBoosted,
        chargeProgress = Game._launchCharge.time / Game._launchCharge.total,
        chargeX = Game._launchCharge.x, chargeY = Game._launchCharge.y,
        chargeUiX = Game._launchCharge.uiX, chargeUiY = Game._launchCharge.uiY,
        -- 鍙戝皠鐬棿鐨勮溅杈嗘潈濞佷綅缃細閲婃斁鍥炲０鐨勫湀蹇冧笌钃勫姏鍦堣繛缁紙鍚屼竴杞﹁締鍧愭爣锛夈€?
        carX = activeBall.x, carY = activeBall.y,
    })
    print("[Game] launch charge id=" .. activeBall.id .. " boosted=" .. tostring(activeBall.chargeBoosted))
    -- v0.13.58锛氶檮榄斻€屼笁杩炪€嶁€斺€斿彂灏勬椂棰濆鎵囧舰灏勫嚭鍚屽瀷杞︺€?
    -- v0.13.64锛氬壇瀛愬脊**瑙嗕负鍒嗚寮?*锛坕sPrimary=false锛岀伆鏆楁覆鏌擄級浣?*鍔熻兘涓庝富寮圭浉鍚?*鈥斺€?
    -- 缁ф壙璇嶆潯锛坵ords锛夈€侀檮榄斻€佺┛閫忔鏁颁笌鎷栧熬骞撮緞锛涙竻闄?enchantIsChild锛屼娇瀹冧滑涓庝富寮逛竴鏍?
    -- 鍙Е鍙戣鍙樼瓑鍛戒腑鏁堟灉锛堟暟閲忕敱 maxConcurrent 涓婇檺鍏滃簳锛屼笉浼氭棤闄愰€掑綊锛夈€?
    local triple = activeBall.enchant and activeBall.enchant.tripleShot or 0
    for k = 1, triple do
        local sign = (k % 2 == 1) and 1 or -1
        local spread = 16 * math.ceil(k / 2) * sign
        local baseAngle = math.atan(-dy, -dx)
        local a = baseAngle + math.rad(spread)
        local extra = CreateSplitMarble(activeBall, 0, nil)
        extra.ballType = activeBall.ballType
        extra.radius = activeBall.radius
        extra.speed = speed
        extra.vx = math.cos(a) * speed
        extra.vy = math.sin(a) * speed
        extra.isPrimary = false
        extra.enchant = activeBall.enchant
        extra.enchantPierce = activeBall.enchantPierce
        extra.enchantIsChild = nil
        local words = {}
        for id in pairs(activeBall.words or {}) do words[id] = true end
        extra.words = words
        table.insert(marbles, extra)
    end
    if triple > 0 then
        Emit("enchant_triple", { x = activeBall.x, y = activeBall.y, count = triple })
    end
    activeBall = nil
end

local function QueueNextBall()
    if #ballQueue > 0 then
        -- 婊￠鏃朵繚鎸侀槦棣栦笌搴撳瓨锛岀瓑宸叉湁鍒嗚杞﹀洖鏀跺悗鍐嶈濉紝涓嶇粫杩囧悓灞忎笂闄愩€?
        if ballQueue[1] == "normal" and Game._NormalMarbleSlots() <= 0 then return end
        activeBall = CreateMarble(table.remove(ballQueue, 1), CollectActiveWords())
    end
end

local function UpdateAiming()
    if aiming and activeBall then
        activeBall.x = SLING_X + (aimX - SLING_X) * BALANCE.pullPositionScale
        activeBall.y = SLING_Y + (aimY - SLING_Y) * BALANCE.pullPositionScale
    elseif activeBall and activeBall.onSling then
        activeBall.x = SLING_X
        activeBall.y = SLING_Y
    end
end

-- 鍏佽寮圭彔鍦ㄥ満涓婃寔缁彂鎸ヤ綔鐢紝浣嗙函姘村钩鍙戝皠鍙兘姘镐笉瓒婅繃鍥炴敹绾匡紱
-- 鏋佺闀块琛屽厹搴曞洖鏀堕伩鍏嶆棤鐣岀疮绉紝涓嶆敼鍙樺垎瑁傛鐜囨垨姝ｅ父杞ㄨ抗銆?
local MAX_MARBLE_FLIGHT_TIME = 60

UpdateMarbles = function(dt)
    local pendingMarbles = {}
    for i = #marbles, 1, -1 do
        local marble = marbles[i]
        local def = BALL_TYPES[marble.ballType]
        -- v0.10.28锛氭寜鏈抚浣嶇Щ鑷€傚簲瀛愭杩涳紝楂橀€熷脊涓嶅啀鎵撶┛钖勬牸銆?
        local move = math.sqrt(marble.vx * marble.vx + marble.vy * marble.vy) * dt
        -- 鍊嶉€熸渶澶氭妸瀹㈡埛绔?.05绉掓ā鎷熸墿涓?.1绉掞紝纰版挒棰勭畻鍚屾缈诲€嶃€?
        -- 涓嶉噸澶嶆暣涓鍒欏抚锛氬悓杞﹀悓鐮栧幓閲嶄笌瓒婄嚎鎸夎鑱氬悎浠嶅彧缁撶畻涓€娆°€?
        local stepScale = math.max(1, math.ceil(dt / 0.05 - 1e-9))
        local steps = math.max(6 * stepScale, math.min(16 * stepScale, math.ceil(move / math.max(4, marble.radius * 0.32))))
        local subDt = dt / steps
        local frameHitBricks = {}
        marble.flightTime = (marble.flightTime or 0) + dt
        -- 鎷栧熬瑙嗚骞撮緞锛氶殢瀛樺湪鏃堕棿澧為暱锛堝垎瑁傚瓙杞︾户鎵挎瘝杞﹀綋鍓嶅€硷紝鏁呴暱搴︿細寤剁画锛夈€?
        marble.trailAge = (marble.trailAge or 0) + dt

        for _ = 1, steps do
            if not marble.alive then break end

            if marble.redirectCooldown and marble.redirectCooldown > 0 then
                marble.redirectCooldown = marble.redirectCooldown - subDt
            end
            -- 鍐峰嵈鍙殢鐜╂硶瀛愭鎺ㄨ繘锛涙殏鍋溿€佸崌绾т笌骞垮憡鍐荤粨鏃朵笉娑堣€椼€?
            if (marble.giantAreaCooldown or 0) > 0 then
                local remaining = marble.giantAreaCooldown - subDt
                -- 娑堥櫎绱娴偣灏炬暟锛岀‘淇濇弧 1 绉掍笉澶氱瓑涓€涓瓙姝ャ€?
                marble.giantAreaCooldown = remaining > 1e-9 and remaining or 0
                if marble.giantAreaCooldown == 0 and marble.giantPiercePending then
                    ArmGiantPiercing(marble)
                end
            end

            local prevX = marble.x
            local prevY = marble.y
            marble.x = marble.x + marble.vx * subDt
            marble.y = marble.y + marble.vy * subDt

            -- WO-05/P4锛氬弽寮瑰脊鎬х敱 ballType 鍐冲畾锛堝法鍨嬫洿娌夈€佸姞閫熸洿婊戯級锛岄粯璁?1.0銆?
            -- v0.13.64锛氭瘡娆℃挒澧欏彂涓€涓洖寮逛簨浠讹紙甯﹀唴娉曠嚎锛夛紝琛ㄧ幇灞傛嵁姝ゆ挱鏀惧洖寮圭壒鏁堛€?
            -- v0.13.66锛氭挒澧欏弽寮圭 = 85% 鍗婂緞锛堜激瀹崇鎾炶寖鍥翠笉鍙橈級銆?
            local elastic = def.bounceElasticity or 1.0
            local bounceR = marble.radius * BALANCE.bounceBoxScale
            if marble.x - bounceR < 0 then
                marble.x = bounceR
                marble.vx = math.abs(marble.vx) * elastic
                marble.bounceCount = marble.bounceCount + 1
                BoostSpeedMarble(marble)
                ArmGiantPiercing(marble)
                -- v0.13.66锛氬洖寮圭壒鏁堝湪澧欓潰鎺ヨЕ鐐瑰彂锛坸=0锛夛紝涓嶅啀鐢ㄨ溅杈嗗渾蹇冿紙鍚﹀垯鏁堟灉鎮湪澧欏悗灞忓箷鍐呬晶锛夈€?
                Emit("marble_bounce", {id = marble.id, x = 0, y = marble.y,
                    ballType = marble.ballType, nx = 1, ny = 0})
            elseif marble.x + bounceR > DW then
                marble.x = DW - bounceR
                marble.vx = -math.abs(marble.vx) * elastic
                marble.bounceCount = marble.bounceCount + 1
                BoostSpeedMarble(marble)
                ArmGiantPiercing(marble)
                Emit("marble_bounce", {id = marble.id, x = DW, y = marble.y,
                    ballType = marble.ballType, nx = -1, ny = 0})
            end
            if marble.y - bounceR < TOP_BOUND_Y then
                marble.y = TOP_BOUND_Y + bounceR
                marble.vy = math.abs(marble.vy) * elastic
                marble.bounceCount = marble.bounceCount + 1
                BoostSpeedMarble(marble)
                ArmGiantPiercing(marble)
                Emit("marble_bounce", {id = marble.id, x = marble.x, y = TOP_BOUND_Y,
                    ballType = marble.ballType, nx = 0, ny = 1})
            end

            -- v0.10.28锛氬厛鏀堕泦鏈鎵€鏈夐噸鍙犳牸锛屽啀鎵撴渶杩戠殑涓€鏍笺€?
            -- 鏃ч€昏緫鎸?bricks 鏁扮粍椤哄簭鍛戒腑绗竴鏍煎氨 break锛屼細婕忔帀鐪熸纰板埌鐨勬牸锛?
            -- 琛ㄧ幇涓衡€滅悆绌胯繃鏈虹考/搴ц埍鏃犵鎾炪€佺瑁備笉瀹屾暣鈥濄€?
            if marble.ignoredBrick then
                local ib = marble.ignoredBrick
                local found = false
                for _, enemy in ipairs(veggies) do
                    if not enemy.dead then
                        for _, brick in ipairs(enemy.bricks) do
                            if brick == ib then
                                found = true
                                local irx = enemy.x + (brick.col - 1) * enemy.brickSize + 1
                                local iry = enemy.y + (brick.row - 1) * enemy.brickSize + 1
                                if not IntersectsBrick(marble, irx, iry,
                                    enemy.brickSize - 2, enemy.brickSize - 2) then
                                    marble.ignoredBrick = nil
                                end
                                break
                            end
                        end
                    end
                    if found then break end
                end
                if not found then marble.ignoredBrick = nil end
            end

            local best = nil
            local bestDist = 1e12
            for _, enemy in ipairs(veggies) do
                if not enemy.dead
                    and SegmentNearRect(prevX, prevY, marble.x, marble.y,
                        enemy.x, enemy.y,
                        enemy.gridW * enemy.brickSize, enemy.gridH * enemy.brickSize,
                        marble.radius) then
                    for _, brick in ipairs(enemy.bricks) do
                        if brick ~= marble.ignoredBrick
                            and brick.alive and not brick.ejected
                            and not frameHitBricks[brick] then
                            local rx = enemy.x + (brick.col - 1) * enemy.brickSize + 1
                            local ry = enemy.y + (brick.row - 1) * enemy.brickSize + 1
                            local rw = enemy.brickSize - 2
                            local rh = enemy.brickSize - 2
                            if SegmentNearRect(prevX, prevY, marble.x, marble.y,
                                rx, ry, rw, rh, marble.radius) then
                                local overlap = IntersectsBrick(marble, rx, ry, rw, rh)
                                    or SweptHitsBrick(prevX, prevY, marble.x, marble.y,
                                        marble.radius, rx, ry, rw, rh)
                                if overlap then
                                    local cx = rx + rw * 0.5
                                    local cy = ry + rh * 0.5
                                    local dx = marble.x - cx
                                    local dy = marble.y - cy
                                    local dist = dx * dx + dy * dy
                                    if dist < bestDist then
                                        bestDist = dist
                                        best = {
                                            enemy = enemy, brick = brick,
                                            rx = rx, ry = ry, rw = rw, rh = rh,
                                        }
                                    end
                                end
                            end
                        end
                    end
                end
            end

            if best then
                local enemy = best.enemy
                local brick = best.brick
                if marble.giantPiercing and (marble.giantAreaCooldown or 0) <= 0 then
                    -- 浠呭疄闄呭渾鍩熷懡涓惎鍔ㄥ喎鍗达紝鍏堢疆浣嶉槻鍚屽抚杩炵画瑙﹀彂锛?
                    -- 鍐峰嵈鏈熼棿璧版櫘閫氱鎾烇紝淇濈暀鍙嶅脊姝﹁浣嗕笉鎻愬墠閲婃斁鍦嗗煙銆?
                    marble.giantAreaCooldown = def.areaCooldown
                    DamageGiantArea(enemy, brick,
                        GetMarbleDamage(marble, def), frameHitBricks)
                    Emit("giant_pierce_consumed", {id = marble.id, x = marble.x, y = marble.y})
                    marble.giantPiercing = false
                else
                    -- v0.13.55銆屽姩鑳界┛鍒恒€嶏細鍔犻€熻溅甯︾┛閫忔鏁版椂涓嶅弽寮癸紝鐩存帴鍚冧笅杩欎竴鍧楀苟缁х画椋炶銆?
                    -- 浣嶇疆娌块€熷害鏂瑰悜鍓嶆帹绾?0.75 鏍硷紝閬垮厤涓嬩竴甯т粛鍗″湪鍚屼竴鐮栧唴閲嶅缁撶畻銆?
                    local pierced = false
                    if marble.ballType == "speed" and (marble.pierceLeft or 0) > 0 then
                        marble.pierceLeft = marble.pierceLeft - 1
                        marble.ignoredBrick = brick
                        frameHitBricks[brick] = true
                        DamageBrick(enemy, brick, GetMarbleDamage(marble, def))
                        local vlen = math.sqrt(marble.vx * marble.vx + marble.vy * marble.vy)
                        if vlen > 0.001 then
                            local push = enemy.brickSize * 0.75
                            marble.x = marble.x + marble.vx / vlen * push
                            marble.y = marble.y + marble.vy / vlen * push
                        end
                        pierced = true
                        Emit("speed_pierce", { id = marble.id, x = marble.x, y = marble.y,
                            remaining = marble.pierceLeft })
                    end
                    -- v0.13.58锛氶檮榄斻€岀┛閫忋€嶁€斺€斾换鎰忚溅鍨嬮兘鑳藉甫绌块€忔鏁帮紝涓嶅弽寮广€佽繛缁悆鍧椼€?
                    if not pierced and (marble.enchantPierce or 0) > 0 then
                        marble.enchantPierce = marble.enchantPierce - 1
                        marble.ignoredBrick = brick
                        frameHitBricks[brick] = true
                        DamageBrick(enemy, brick, GetMarbleDamage(marble, def))
                        local vlen = math.sqrt(marble.vx * marble.vx + marble.vy * marble.vy)
                        if vlen > 0.001 then
                            local push = enemy.brickSize * 0.75
                            marble.x = marble.x + marble.vx / vlen * push
                            marble.y = marble.y + marble.vy / vlen * push
                        end
                        pierced = true
                        Emit("enchant_pierce", { id = marble.id, x = marble.x, y = marble.y,
                            remaining = marble.enchantPierce })
                    end
                    if not pierced then
                        -- v0.13.66锛氫激瀹冲厛缁撶畻锛堟弧鍗婂緞浼ゅ鍦堜笉鍙橈級锛屽弽寮圭敤 85% 纰版挒绠憋紱
                        -- 鍙繘浼ゅ鍦堢殑鎿﹁竟鍛戒腑涓嶅弽寮癸紝杞﹁締淇濇寔鏈瓙姝ヤ綅绉荤户缁琛屻€?
                        frameHitBricks[brick] = true
                        DamageBrick(enemy, brick, GetMarbleDamage(marble, def))
                        local resolved = CollideBrick(marble, best.rx, best.ry, best.rw, best.rh)
                        if not resolved then
                            -- 鎵帬鍛戒腑鐨勭爾锛屽瓙姝ョ粓鐐瑰彲鑳藉凡瓒婅繃鍙嶅脊绠憋細鍥炲埌璧风偣閲嶈瘯涓€娆★紝
                            -- 浠嶄笉鍛戒腑鍒欐寜鎿﹁竟澶勭悊锛屾仮澶嶆湰瀛愭浣嶇Щ銆?
                            marble.x = prevX
                            marble.y = prevY
                            resolved = CollideBrick(marble, best.rx, best.ry, best.rw, best.rh)
                            if not resolved then
                                marble.x = prevX + marble.vx * subDt
                                marble.y = prevY + marble.vy * subDt
                            end
                        end
                    end
                end

                if marble.ballType == "speed" then
                    BoostSpeedMarble(marble)
                end
                if def.freezeDuration then enemy.frozen = def.freezeDuration + BALL_TUNING.iceBonus end

                if marble.words and marble.words.pierce then
                    ApplyBrickStatus(brick, "shock", 1.2, 1)
                end
                if marble.words and marble.words.chain then
                    ApplyBrickStatus(brick, "corrode", 2.0, 1)
                end
                if marble.words and marble.words.momentum then
                    ApplyBrickStatus(brick, "burn", 1.5, 1)
                end
                if marble.ballType == "giant" then
                    ApplyBrickStatus(brick, "volatile", 1.5, 1.5)
                end
                if def.freezeDuration then
                    ApplyBrickStatus(brick, "freeze",
                        def.freezeDuration + BALL_TUNING.iceBonus, 1)
                end

                if marble.ballType == "normal" then
                    TrySplitNormal(marble, brick, pendingMarbles)
                elseif marble.ballType == "speed" then
                    RedirectSpeedMarble(marble, enemy, brick)
                elseif marble.ballType == "giant" and not marble.giantPiercing then
                    ArmGiantPiercing(marble)
                end

                -- v0.13.58锛氶檮榄斿崱鍛戒腑鏁堟灉锛堝叏閮ㄨ惤鍦ㄦ満鍒朵笂锛屼笌璇嶆潯/寮圭鏁堟灉鐩镐簰鐙珛锛夈€?
                local enchant = marble.enchant
                if enchant then
                    if enchant.healPerHit and baseHp < GetMaxBaseHp() then
                        baseHp = math.min(GetMaxBaseHp(), baseHp + enchant.healPerHit)
                        Emit("enchant_lifesteal", { x = marble.x, y = marble.y,
                            amount = enchant.healPerHit })
                    end
                    if enchant.freezeAll and not marble.enchantFrozen then
                        marble.enchantFrozen = true
                        for _, other in ipairs(veggies) do
                            if not other.dead then
                                other.frozen = enchant.freezeAll
                                other.freezeRatio = 1
                            end
                        end
                    end
                    if enchant.chain then
                        -- v0.13.58锛氳繛閿佲€斺€斿懡涓椂瀵规渶杩戠殑鍙︿竴鍧?*閫犳垚鐪熷疄浼ゅ**锛堟鍓嶅彧鍙戜簨浠舵棤浼ゅ锛屾槸 bug锛夈€?
                        local target = FindNearestBrick(enemy, brick, marble.x, marble.y)
                        if target then
                            local mul = enchant.chainDamage or 1.5
                            local dmg = GetMarbleDamage(marble, def) * mul
                            -- 鎵惧埌璇ョ洰鏍囧搴旂殑鐮栧潡骞剁粨绠楋紙婧呭皠鍚屾椂缁欎竴灏忕墖鍛ㄥ洿鍔犳垚锛夈€?
                            local splash = enemy.brickSize * 1.2
                            for _, other in ipairs(veggies) do
                                if not other.dead then
                                    for _, otherBrick in ipairs(other.bricks) do
                                        if otherBrick.alive and not otherBrick.ejected
                                            and otherBrick ~= brick and not frameHitBricks[otherBrick] then
                                            local bx = other.x + (otherBrick.col - 0.5) * other.brickSize
                                            local by = other.y + (otherBrick.row - 0.5) * other.brickSize
                                            local ddx, ddy = bx - target.x, by - target.y
                                            if ddx * ddx + ddy * ddy <= splash * splash then
                                                frameHitBricks[otherBrick] = true
                                                DamageBrick(other, otherBrick, dmg)
                                            end
                                        end
                                    end
                                end
                            end
                            Emit("enchant_chain", { x = marble.x, y = marble.y,
                                targetX = target.x, targetY = target.y, damage = dmg })
                        end
                    end
                    if enchant.explodeRadius then
                        local radius = enemy.brickSize * enchant.explodeRadius
                        local radiusSq = radius * radius
                        local cx = enemy.x + (brick.col - 0.5) * enemy.brickSize
                        local cy = enemy.y + (brick.row - 0.5) * enemy.brickSize
                        local emul = enchant.explodeMul or 1.2
                        for _, other in ipairs(veggies) do
                            if not other.dead then
                                for _, otherBrick in ipairs(other.bricks) do
                                    if otherBrick.alive and not otherBrick.ejected
                                        and otherBrick ~= brick and not frameHitBricks[otherBrick] then
                                        local bx = other.x + (otherBrick.col - 0.5) * other.brickSize
                                        local by = other.y + (otherBrick.row - 0.5) * other.brickSize
                                        local ddx, ddy = bx - cx, by - cy
                                        if ddx * ddx + ddy * ddy <= radiusSq then
                                            frameHitBricks[otherBrick] = true
                                            DamageBrick(other, otherBrick,
                                                GetMarbleDamage(marble, def) * emul)
                                        end
                                    end
                                end
                            end
                        end
                        Emit("enchant_explode", { x = cx, y = cy, radius = radius })
                    end
                    if enchant.splitOnHit and not marble.enchantIsChild then
                        local room = Game._NormalMarbleSlots(pendingMarbles)
                        for _ = 1, math.min(enchant.splitOnHit, room) do
                            local angle = -18 + Random() * 36
                            table.insert(pendingMarbles, CreateSplitMarble(marble, angle, brick))
                        end
                        Emit("enchant_split", { x = marble.x, y = marble.y })
                    end
                    if enchant.homing then
                        local target = FindNearestBrick(enemy, brick, marble.x, marble.y)
                        if target then
                            local dx, dy = target.x - marble.x, target.y - marble.y
                            local d = math.sqrt(dx * dx + dy * dy)
                            if d > 0.001 then
                                local sp = math.sqrt(marble.vx * marble.vx + marble.vy * marble.vy)
                                marble.vx = dx / d * sp
                                marble.vy = dy / d * sp
                                Emit("enchant_homing", { x = marble.x, y = marble.y,
                                    targetX = target.x, targetY = target.y })
                            end
                        end
                    end
                end
            end

            -- 鍥炴敹绾垮湪闃茬嚎 DANGER_Y锛堣溅鍥炶惤杩涘叆搴曢儴 Dock 瀹夊叏灞傚嵆鍥炲簱琛ュ脊锛夈€?
            -- 蹇呴』鍚屾椂婊¤冻 vy>0锛堟鍦ㄥ悜涓嬭繍鍔級锛氬脊寮撳悜涓嬫媺銆佸悜涓婂彂灏勬椂鍑虹敓鐐瑰彲鑳藉氨鍦?
            -- DANGER_Y 涔嬩笅锛堝緟鍙戜綅 y鈮?50銆佹媺婊″彲鍒?940锛屽法鍨嬭溅鍗婂緞 30锛夛紝鑻ユ棤姝ゆ潯浠?
            -- 鐞冧竴鍙戝皠杩樻病寰€涓婅蛋灏辫鍒ゅ洖鏀讹紝琛ㄧ幇涓衡€滃皠涓嶅嚭鍘烩€濄€?
            if marble.vy > 0 and marble.y - marble.radius > DANGER_Y then
                marble.alive = false
                break
            end
        end

        if marble.alive and marble.flightTime >= MAX_MARBLE_FLIGHT_TIME then
            marble.alive = false
            print("[Game][perf] expired marble id=" .. tostring(marble.id)
                .. " flight=" .. string.format("%." .. "1f", marble.flightTime))
        end

        if not marble.alive then
            table.remove(marbles, i)
            if marble.isPrimary then
                EnqueueNextBall()
                -- v0.10.24锛氫富鐞冨洖搴撹ˉ寮癸紝缁欒〃鐜板眰涓€涓交閲忓弽棣堜簨浠躲€?
                Emit("marble_reloaded", {ballType = activeBall and activeBall.ballType or "normal"})
            end
            Emit("marble_removed", {id = marble.id, isPrimary = marble.isPrimary == true})
        end
    end

    for _, marble in ipairs(pendingMarbles) do
        table.insert(marbles, marble)
        Emit("marble_split_spawned", {
            id = marble.id,
            generation = marble.generation,
        })
    end
end

-- 閫愬抚鍏ㄦ満缇ら槻閲嶅彔锛氭憜鍔?涓嬬Щ瀹屾垚鍚庡鎵€鏈夊瓨娲婚鏈哄仛澶氳疆 AABB 杩唬姹傝В銆?
-- 姘村钩绌块€忥細涓ゆ灦瀵圭О璁╀綅锛堥《鍒版垬鍦鸿竟鐣岀殑涓€渚т笉鍔紝鍏ㄩ噺鎺ㄧ粰鍙︿竴渚э級锛?
-- 鍨傜洿绌块€忥細鍙妸鏇撮潬涓婄殑椋炴満鏁翠綋鎶珮锛坹 鍑忓皬锛夛紝缁濅笉鍚戜笅鎸ゅ帇瀵艰嚧鎻愬墠瓒婄嚎鎵ｈ銆?
-- 澶氳疆杩唬鐢ㄤ簬娑堣В A 鎺ㄥ紑 B銆丅 鍙堟挒涓?C 鐨勯摼寮忕┛鎻掞紱鏈€鍚庣粺涓€閽冲埗宸﹀彸杈圭晫骞跺洖鍐?baseX銆?
local FLEET_SOLVE_ITERATIONS = 8
local FLEET_SIDE_MARGIN = 10

local function ClampEnemyX(enemy, width)
    if enemy.x < FLEET_SIDE_MARGIN then
        enemy.x = FLEET_SIDE_MARGIN
    elseif enemy.x + width > DW - FLEET_SIDE_MARGIN then
        enemy.x = DW - FLEET_SIDE_MARGIN - width
    end
end

local function ResolveFleetOverlaps()
    local count = #veggies
    if count < 2 then
        for i = 1, count do
            local a = veggies[i]
            if not a.dead then
                ClampEnemyX(a, a.gridW * a.brickSize)
                a.baseX = a.x - (a.drift or math.sin(a.phase) * a.swayAmp)
            end
        end
        return
    end

    for _ = 1, FLEET_SOLVE_ITERATIONS do
        for i = 1, count do ClampEnemyX(veggies[i], veggies[i].gridW * veggies[i].brickSize) end
        for i = 1, count - 1 do
            local a = veggies[i]
            if not a.dead then
                local ax, ay, aw, ah = EnemyAABB(a)
                for j = i + 1, count do
                    local b = veggies[j]
                    if not b.dead then
                        local bx, by, bw, bh = EnemyAABB(b)
                        -- 绾靛悜宸茬敱鐢熸垚鎺掑簭淇濊瘉鑷冲皯闂撮殧 ENEMY_SPACING锛涘彧鍦ㄧ旱鍚戠湡姝ｉ噸鍙犳椂
                        -- 鎵嶅厑璁告í鍚戣浣嶏紝閬垮厤涓寸晫娴偣锛坥verlapY鈮?锛夎鍒ゆ妸鏂版満鐬棿妯帹锛堚€滃洖鎾も€濓級銆?
                        local overlapX = math.min(ax + aw + ENEMY_SPACING, bx + bw + ENEMY_SPACING)
                            - math.max(ax - ENEMY_SPACING, bx - ENEMY_SPACING)
                        local overlapY = math.min(ay + ah + ENEMY_SPACING, by + bh + ENEMY_SPACING)
                            - math.max(ay - ENEMY_SPACING, by - ENEMY_SPACING)
                        if overlapX > 1.0 and overlapY > 1.0 then
                            -- 鍙鏈変竴鏂硅繕鍦ㄥ彲瑙佹垬鍦洪《锛?102锛変箣涓婏紝浼樺厛绾靛悜鎶婇潬涓婄殑缁х画鎶珮锛?
                            -- 閬垮厤鏂版満杩涘満鏃惰瀵圭О妯帹閫犳垚鈥滅獊鐒舵í鍚戝洖鎾も€濄€?
                            local aOffscreen = ay + ah < -102
                            local bOffscreen = by + bh < -102
                            if aOffscreen or bOffscreen then
                                if ay <= by then
                                    a.y = by - ah - ENEMY_SPACING
                                else
                                    b.y = ay - bh - ENEMY_SPACING
                                end
                            elseif overlapX <= overlapY then
                                local aBlocked = ax <= FLEET_SIDE_MARGIN + 0.01
                                local bBlocked = bx + bw >= DW - FLEET_SIDE_MARGIN - 0.01
                                if aBlocked and not bBlocked then
                                    b.x = b.x + overlapX
                                elseif bBlocked and not aBlocked then
                                    a.x = a.x - overlapX
                                else
                                    a.x = a.x - overlapX * 0.5
                                    b.x = b.x + overlapX * 0.5
                                end
                            elseif ay <= by then
                                a.y = by - ah - ENEMY_SPACING
                            else
                                b.y = ay - bh - ENEMY_SPACING
                            end
                        end
                        ax, ay, aw, ah = EnemyAABB(a)
                    end
                end
            end
        end
    end

    for i = 1, count do
        local enemy = veggies[i]
        if not enemy.dead then
            ClampEnemyX(enemy, enemy.gridW * enemy.brickSize)
            -- 鍒嗙鍚庣殑瀹為檯 x 鍥炲啓涓烘憜鍔ㄤ腑蹇冿紝閬垮厤涓嬩竴甯?sin(phase) 鍙樺寲鍙堟妸椋炴満鎷夊洖閲嶅彔浣嶃€?
            enemy.baseX = enemy.x - (enemy.drift or math.sin(enemy.phase) * enemy.swayAmp)
        end
    end
end

local function SummonBossEscort(boss)
    local def = AircraftData[boss.aircraftKey]
    local key = def and def.summonKey or "scout"
    local data = AircraftData[key]
    if not data then return false end
    local brickSize = GetBrickSize(wave)
    local shipW, shipH = GetAircraftSize(key, brickSize)
    local side = (boss.summonCount % 2 == 0) and -1 or 1
    local x = math.max(10, math.min(DW - shipW - 10,
        boss.x + boss.gridW * boss.brickSize * 0.5 + side * (boss.gridW * boss.brickSize * 0.5 + shipW * 0.6)
            - shipW * 0.5))
    local y = math.min(-102 - shipH - 24, boss.y - shipH - 16)
    local attempts = 0
    while FleetPositionOccupied(x, y, shipW, shipH, {}) and attempts < 50 do
        y = y - shipH - ENEMY_SPACING
        attempts = attempts + 1
    end
    if attempts >= 50 then return false end
    local enemy = CreateEnemy(key, x, y, brickSize,
        StageCatalog.GetBrickHp(stage, "normal"),
        StageCatalog.GetBaseSpeed(stage, stageWave), {phase = 0})
    if not enemy then return false end
    enemy.summonedBy = boss.id
    veggies[#veggies + 1] = enemy
    boss.summonCount = boss.summonCount + 1
    Emit("boss_summoned", {enemyId = boss.id, summonedId = enemy.id,
        aircraftKey = key, count = boss.summonCount})
    print("[Game] boss " .. boss.aircraftKey .. " summoned " .. key
        .. " " .. boss.summonCount .. "/" .. StageCatalog.GetBossSummonLimit(stage))
    return true
end

-- v0.13.65锛氬够褰变綋绱犲潡銆傚叏閮ㄥ疄鐜颁负 Game._phantom 鐨勮〃瀛楁锛?*闆舵柊澧為《灞?local**锛孉B-166锛夛紝
-- 涓旀寕琛ㄥ畾涔夊湪瀹冨紩鐢ㄥ埌鐨勬枃浠?local锛圕ollideBrick / GetMarbleDamage / Emit / SegmentNearRect 绛夛級涔嬪悗锛?
-- 閬垮厤銆屽厛鐢ㄥ悗澹版槑銆嶈В鏋愭垚鍏ㄥ眬 nil锛圓B-100 鍚屾棌锛夈€?
-- 杩斿洖璇ユ満**绗竴涓瓨娲讳笖鏈脊鍑虹殑寮曟搸鐏潡**锛堝够褰卞彧鑳戒粠鍏夋簮鍧楀彂灏勶紱琚墦鎺夊氨娌℃湁浜嗭級銆?
Game._phantom.FindEngineBrick = function(enemy)
    for _, brick in ipairs(enemy.bricks) do
        if brick.alive and not brick.ejected and brick.isEngine then return brick end
    end
    return nil
end

-- 浠庢簮鏁屾満鐨勫紩鎿庣伅鍧楀彂灏勪竴鏋氬够褰卞潡锛氱户鎵胯鐏潡**鍓╀綑琛€閲忎竴鍗婏紙鑷冲皯 1锛?*锛?
-- 閫熷害 = 褰撳墠鍏冲崱鍩哄噯閫熷害 脳 0.42 脳 PHANTOM_SPEED_MUL锛堝熀鍑嗛€熷害宸插惈娉㈡缂撳叆锛夈€?
Game._phantom.Spawn = function(enemy, brick)
    -- 鍚屽睆涓婇檺锛氬够褰卞潡鏄珮閫熸姇灏勭墿锛岃繃澶氫細鍒峰睆骞跺帇鐪熸満甯х巼锛堟瘡娆′竴涓?3D 鐩掑瓙锛夈€?
    if #Game._phantom.list >= 8 then return false end
    local bs = enemy.brickSize
    local hp = math.max(1, math.floor(brick.hp / 2))
    local w = bs * 0.9
    local h = bs * 0.9
    local cx = enemy.x + (brick.col - 0.5) * bs
    local cy = enemy.y + (brick.row - 0.5) * bs
    local vy = StageCatalog.GetBaseSpeed(stage, stageWave) * 0.42 * StageCatalog.PHANTOM_SPEED_MUL
    local p = {
        id = Game._phantom.nextId,
        x = cx - w * 0.5, y = cy - h * 0.5, w = w, h = h,
        vy = vy,
        hp = hp, maxHp = hp,
        alive = true,
        sourceKey = enemy.aircraftKey,
        tag = "phantom",
    }
    Game._phantom.nextId = Game._phantom.nextId + 1
    Game._phantom.list[#Game._phantom.list + 1] = p
    Emit("phantom_fired", {id = p.id, x = cx, y = cy, aircraftKey = enemy.aircraftKey, hp = hp})
    return true
end

-- 閫愬抚鎺ㄨ繘骞诲奖鍧楋細涓嬬Щ 鈫?琚脊鐝犲嚮纰?鈫?瓒婄嚎鎵ｅ熀鍦拌銆?
Game._phantom.Update = function(dt)
    local list = Game._phantom.list
    for i = #list, 1, -1 do
        local p = list[i]
        if not p.alive then
            table.remove(list, i)
        else
            p.y = p.y + p.vy * dt
            -- 琚脊鐝犲嚮纰庯紙骞诲奖鍧楀彲琚嚮钀斤紱绌胯繃鍏朵粬鏁屾満涓嶅彈褰卞搷鈥斺€斿畠涓嶅湪 veggies 閲岋級銆?
            for _, marble in ipairs(marbles) do
                if marble.alive then
                    local prevX = marble.x - marble.vx * dt
                    local prevY = marble.y - marble.vy * dt
                    if SegmentNearRect(prevX, prevY, marble.x, marble.y,
                        p.x, p.y, p.w, p.h, marble.radius) then
                        local overlap = IntersectsBrick(marble, p.x, p.y, p.w, p.h)
                            or SweptHitsBrick(prevX, prevY, marble.x, marble.y,
                                marble.radius, p.x, p.y, p.w, p.h)
                        if overlap then
                            local def = BALL_TYPES[marble.ballType]
                            p.hp = p.hp - GetMarbleDamage(marble, def)
                            CollideBrick(marble, p.x, p.y, p.w, p.h)
                            if p.hp <= 0 then
                                p.alive = false
                                Emit("phantom_destroyed", {id = p.id, x = p.x + p.w * 0.5,
                                    y = p.y + p.h * 0.5, aircraftKey = p.sourceKey})
                            end
                            break
                        end
                    end
                end
            end
            -- 瓒婅繃闃茬嚎锛氭寜鏅€氳秺绾匡紙1 琛?= 1 浼わ級鎵ｅ熀鍦拌锛岃鐢插噺浼や笌鎶ょ浘鐓у父鐢熸晥銆?
            if p.alive and p.y + p.h >= DANGER_Y then
                p.alive = false
                local dmg = math.max(1, math.floor(BRICK_BASE_DAMAGE + BALL_TUNING.lineDamageBonus + 0.5))
                if BALL_TUNING.armorReduce > 0 then
                    dmg = math.max(1, math.floor(dmg * (1 - BALL_TUNING.armorReduce) + 0.5))
                end
                if baseShield > 0 then
                    local absorbed = math.min(baseShield, dmg)
                    baseShield = baseShield - absorbed
                    dmg = dmg - absorbed
                end
                Emit("phantom_breached", {id = p.id, x = p.x + p.w * 0.5, y = DANGER_Y})
                if dmg > 0 then
                    baseHp = baseHp - dmg
                    Emit("base_hit", {x = p.x + p.w * 0.5, y = DANGER_Y, brick = true,
                        damage = dmg, rows = 1})
                end
                if baseHp <= 0 and gameState == "playing" then
                    baseHp = 0
                    gameState = "gameover"
                    Game.CancelHoldSpeed()
                    Game.ClearLaunchCharge()
                    aiming = false
                    startArmed = false
                    if score > highScore then highScore = score end
                    Game._defeat.at = elapsed
                    Game._defeat.revive = not reviveUsed
                    Emit("game_over", {score = score, highScore = highScore, wave = wave,
                        canRevive = not reviveUsed})
                end
            end
        end
    end
end

-- 姣忓抚鐨勫够褰卞彂灏勫垽瀹氾紙鏅€氭満鍨嬶紝鎸夐鐜囩郴鏁?+ 闅惧害姒傜巼闅忔満锛夈€?
--   - 鍙湁 PHANTOM_KEYS 鍒楀嚭鐨勬満鍨嬫湁璇ヨ涓猴紙鐢ㄦ埛锛氥€屼笉鏄墍鏈夌绫婚兘鏈夈€嶏級銆?
--   - 姣忔妫€鏌ョ殑瑙﹀彂姒傜巼 = 璇ユ満鍨?prob 脳 鍏冲崱闅惧害绯绘暟锛堝叧1 0.6 鈫?鍏?0+ 1.5锛夈€?
--   - 妫€鏌ラ棿闅?= 璇ユ満鍨?interval / fireMul锛坒ireMul 瓒婂ぇ妫€鏌ヨ秺棰戠箒锛夈€?
--   - 銆屾湰鍏冲墠 5 娉㈣嚦灏?10 鏋躲€嶏細绱鏈揪 10 涓斾粛鍦ㄥ墠 5 娉㈡椂锛屾瘡 1.2s 寮哄埗鎸戜竴鏋舵湭鍙戝皠杩囩殑鏈哄瀷鍙戝皠銆?
Game._phantom.TryFire = function(dt)
    local ph = Game._phantom
    local diff = StageCatalog.GetPhantomDifficulty(stage)
    -- 鏅€氶殢鏈哄彂灏勶細閫愭満鎸夊悇鑷?interval 妫€鏌ワ紝姒傜巼 = prob 脳 闅惧害绯绘暟銆?
    for _, enemy in ipairs(veggies) do
        if not enemy.dead and not enemy.breached and not enemy.isElite and not enemy.isBoss then
            local cfg = StageCatalog.PHANTOM_KEYS[enemy.aircraftKey]
            if cfg then
                local interval = cfg.interval / math.max(0.2, cfg.fireMul)
                -- 棣栨妫€鏌ョ粰涓€涓殢鏈虹浉浣嶏紝閬垮厤鍚屾尝鎵€鏈夋晫鏈哄湪鍚屼竴甯ч綈灏勩€?
                local t = enemy.phantomTimer
                if t == nil then t = Random() * interval end
                t = t - dt
                if t <= 0 then
                    enemy.phantomTimer = interval
                    if Random() < cfg.prob * diff then
                        local brick = ph.FindEngineBrick(enemy)
                        if brick then
                            if ph.Spawn(enemy, brick) then
                                ph.guaranteed = ph.guaranteed + 1
                            end
                            ph.firedKeys[enemy.aircraftKey] = true
                        end
                    end
                else
                    enemy.phantomTimer = t
                end
            end
        end
    end
    -- 銆屾湰鍏冲墠 5 娉㈣嚦灏?10 鏋躲€嶄繚搴曪細绱涓嶈冻 10 涓斾粛鍦ㄥ墠 5 娉㈡椂锛屾瘡 1.1s 鎸戜竴鏋?
    -- **灏氭湭鍙戝皠杩?*鐨勫彲鍙戝皠鏈哄瀷寮哄埗鍙戜竴鏋氾紙浼樺厛鏂版満鍨嬶紝閬垮厤鎬婚潬鍚屼竴鏋跺噾鏁帮級銆?
    if stageWave <= 5 and ph.guaranteed < 10 then
        ph.guaranteeTimer = ph.guaranteeTimer + dt
        if ph.guaranteeTimer >= 1.1 then
            ph.guaranteeTimer = 0
            local pick = nil
            for _, enemy in ipairs(veggies) do
                if not enemy.dead and not enemy.breached and not enemy.isElite and not enemy.isBoss
                    and StageCatalog.PHANTOM_KEYS[enemy.aircraftKey]
                    and not ph.firedKeys[enemy.aircraftKey] then
                    pick = enemy
                    break
                end
            end
            if not pick then
                for _, enemy in ipairs(veggies) do
                    if not enemy.dead and not enemy.breached and not enemy.isElite and not enemy.isBoss
                        and StageCatalog.PHANTOM_KEYS[enemy.aircraftKey] then
                        pick = enemy
                        break
                    end
                end
            end
            if pick then
                local brick = ph.FindEngineBrick(pick)
                if brick then
                    if ph.Spawn(pick, brick) then
                        ph.guaranteed = ph.guaranteed + 1
                    end
                    ph.firedKeys[pick.aircraftKey] = true
                end
            end
        end
    end
end

UpdateEnemies = function(dt)
    -- 鍏堢敤鍥哄畾闀垮害閬嶅巻鏈抚宸叉湁缂栭槦锛屽彫鍞ゆ満寤跺悗涓€甯ц繘鍏ユ洿鏂般€?
    local existingCount = #veggies
    for i = existingCount, 1, -1 do
        if gameState == "gameover" then break end
        local enemy = veggies[i]
        local width = enemy.gridW * enemy.brickSize
        local height = enemy.gridH * enemy.brickSize
        local speedMultiplier = 1

        if enemy.frozen > 0 then
            enemy.frozen = math.max(0, enemy.frozen - dt)
            speedMultiplier = 0.3
        end

        -- WO-13/P2锛氭毚闇插喕缁撴瘮渚嬬粰娓叉煋灞傦紝鐢ㄤ簬椤剁偣鑹插喎鑹插亸绉讳笌姝ｉ潰闇滃喕楂樺厜銆?
        -- 鍩哄噯涓哄啺寮瑰喕缁撴椂闀?+ 娣卞瘨娑傚眰鍔犳垚锛屾覆鏌撳眰鍙姝ゅ€硷紝涓嶅緱鍙嶅悜淇敼鏉冨▉鐘舵€併€?
        local freezeRef = BALL_TYPES.ice.freezeDuration + BALL_TUNING.iceBonus
        enemy.freezeRatio = enemy.frozen > 0
            and math.max(0, math.min(1, enemy.frozen / freezeRef))
            or 0

        -- P11锛氬紓甯哥姸鎬侀€愬抚缁撶畻锛圖oT/鍙嶅簲/鏄撴毚锛夛紝浠呭湪鐮栧潡瀛樻椿鏃舵帹杩涖€?
        for _, brick in ipairs(enemy.bricks) do
            if brick.alive and brick.status then
                TickBrickStatus(enemy, brick, dt)
            end
        end

        if enemy.isBoss then
            local aliveCount = 0
            for _, brick in ipairs(enemy.bricks) do
                if brick.alive then aliveCount = aliveCount + 1 end
            end
            local ratio = aliveCount / math.max(1, #enemy.bricks)
            local newPhase = ratio > 0.66 and 1 or (ratio > 0.33 and 2 or 3)
            if newPhase ~= enemy.bossPhase then
                enemy.bossPhase = newPhase
                enemy.vulnerable = (newPhase == 2)
                Emit("boss_phase", {enemyId = enemy.id, phase = newPhase, vulnerable = enemy.vulnerable})
            end
            -- 鍙敜鍚嶉鍖呭惈鏅€氭尝浣欑暀缂栭槦锛岀‖涓婇檺閬垮厤鍚庢湡鎵嬫満琚満缇ゅ帇鍨€?
            enemy.summonTimer = enemy.summonTimer - dt
            if enemy.summonTimer <= 0 then
                enemy.summonTimer = StageCatalog.GetBossSummonInterval(stage)
                if aliveCount > 0 and #veggies < StageCatalog.MAX_FLEET
                    and enemy.summonCount < StageCatalog.GetBossSummonLimit(stage) then
                    SummonBossEscort(enemy)
                end
            end
        end

        enemy.phase = enemy.phase + dt * enemy.swayFreq
        local drift = math.sin(enemy.phase) * enemy.swayAmp
        if enemy.isElite then
            local beh = AircraftData.behavior[enemy.aircraftKey]
            local dodge = beh.dodge or {}
            local t = enemy.phase
            -- 鍙岄娉笌鏂规尝/鎶樿繑缁勫悎锛屼綅缃繛缁紱浠呭湪姘村钩鏂瑰悜鍋氫笉绋冲畾婕傜Щ銆?
            if dodge.kind == "zigzag" then
                drift = drift + (2 / math.pi) * (dodge.amp or 12)
                    * math.asin(math.sin(t * (dodge.freq or 2)))
            elseif dodge.kind == "lurch" then
                drift = drift + (dodge.amp or 12) * math.sin(t * (dodge.freq or 2)) ^ 3
            elseif dodge.kind == "orbit" then
                drift = drift + (dodge.amp or 12) * math.sin(t * (dodge.freq or 2))
                    * math.cos(t * 0.4)
            else
                drift = drift + (dodge.amp or 12) * math.sin(t * (dodge.freq or 2))
            end
            -- 绾靛悜鐬椂閫熷害 0.75锝?.05 脳 鏅€氭満锛涘潎鍊间笉瓒呰繃 1.1 鍊嶃€?
            enemy.y = enemy.y + math.min(enemy.normalVy * 1.1,
                enemy.vy * (0.90 + 0.15 * math.sin(t * 1.9))) * speedMultiplier * dt
        else
            enemy.y = enemy.y + enemy.vy * speedMultiplier * dt
        end
        enemy.x = enemy.baseX + drift
        enemy.drift = drift
        if enemy.x < 10 then
            enemy.baseX = 10 + (enemy.baseX - enemy.x)
            enemy.x = 10
        elseif enemy.x + width > DW - 10 then
            enemy.baseX = DW - 10 - width - ((enemy.x + width) - (DW - 10))
            enemy.x = DW - 10 - width
        end
    end

    -- 鎵€鏈夌紪闃熸湰甯ф憜鍔?涓嬬Щ瀹屾垚鍚庣粺涓€鍋氬杞?AABB 鍒嗙锛岄伩鍏嶉€愭満鍗曡疆姹傝В婕忓垽銆?
    ResolveFleetOverlaps()

    -- 绗簩瓒燂細鍦ㄦ渶缁堜綅缃笂鍋氳秺绾垮垽瀹氾紙鎸夎锛夈€佺瑁傘€佹竻绌轰笌绉婚櫎銆?
    -- 鏈抚鎵€鏈夎秺绾胯鍏堟敹闆嗗苟閫愬潡纰庤锛屾墸琛€鍦ㄦ暣浣撳悎璁″悗鍙粨绠椾竴娆°€?
    local breachedRows = {}
    for i = #veggies, 1, -1 do
        if gameState == "gameover" then break end
        local enemy = veggies[i]

        -- 瓒婄嚎鍒ゅ畾鎸夆€滆鈥濆垎缁勶細鍚屼竴鏋堕鏈洪噷瓒婅繃鐩爣绾跨殑鏂瑰潡鎸?brick.row 褰掔粍銆?
        local rows = {}
        for _, brick in ipairs(enemy.bricks) do
            if brick.alive then
                local brickBottom = enemy.y + brick.row * enemy.brickSize
                if brickBottom > DANGER_Y then
                    local list = rows[brick.row]
                    if not list then list = {}; rows[brick.row] = list end
                    list[#list + 1] = brick
                end
            end
        end

        local bossBreachedThisFrame = false
        for row, list in pairs(rows) do
            -- 璇ヨ鏂瑰潡鍏ㄩ儴纰庤锛堢嫭绔嬮鏁ｇ浣擄級锛岃瑙夊弽棣堝彇璇ヨ涓績銆?
            local sumX = 0
            enemy.breached = true
            if enemy.isBoss then bossBreachedThisFrame = true end
            for _, brick in ipairs(list) do
                ShatterBreachedBrick(enemy, brick)
                sumX = sumX + enemy.x + (brick.col - 0.5) * enemy.brickSize
            end
            local rowCenterX = sumX / #list
            local rowY = enemy.y + (row - 0.5) * enemy.brickSize
            breachedRows[#breachedRows + 1] = {x = rowCenterX, y = DANGER_Y, rowY = rowY}
        end
        if bossBreachedThisFrame and IsEnemyCleared(enemy) then
            enemy.escaped = true
        end
    end

    -- 姣忚鍩虹浼ゅ 0.5 鍚戜笂鍙栨暣锛?姣忚 1锛夛紱鍔犳垚鍙湪鏁翠綋鍚堣鍚庨檮鍔犱竴娆★紝鏈€缁堜笉浣庝簬 1銆?
    if #breachedRows > 0 and gameState ~= "gameover" then
        local baseDamage = math.ceil(#breachedRows * BRICK_BASE_DAMAGE)
        -- v0.13.28锛氥€岃鐢插己鍖栥€嶇敱鍥哄畾 -1 鏀逛负**鐧惧垎姣斿噺浼?*鈥斺€旀棫 -1 鍦ㄥ崟琛岃秺绾匡紙浼ゅ琚挸鎴?1锛夋椂瀹屽叏鏃犳晥锛?
        -- 鐧惧垎姣斿鍗曡涔熺敓鏁堬紙1 琛?脳 20% 鍥涜垗浜斿叆涓?0锛屾晠鍐嶇敤 max(1,鈥? 淇濅綇涓嬮檺 1锛屼笉澶氬噺锛夈€?
        local mitigated = baseDamage + BALL_TUNING.lineDamageBonus
        if BALL_TUNING.armorReduce > 0 then
            mitigated = math.floor(mitigated * (1 - BALL_TUNING.armorReduce) + 0.5)
        end
        local totalDamage = math.max(1, mitigated)
        -- 鎶ょ浘浼樺厛鍚告敹锛屽惛瀹岃繕鏈夊墿鎵嶆墸琛€銆?
        if baseShield > 0 then
            local absorbed = math.min(baseShield, totalDamage)
            baseShield = baseShield - absorbed
            totalDamage = totalDamage - absorbed
        end
        if totalDamage > 0 then baseHp = baseHp - totalDamage end
        -- 闃茬嚎鍙嶉锛氫竴鏉¤仛鍚堜簨浠讹紙闇囧睆/鍐插嚮娉?椋樺瓧锛夛紝纰庤鏂瑰潡鐨勯绠辩敱鍚勮嚜浜嬩欢鍛堢幇銆?
        local focus = breachedRows[1]
        Emit("base_hit", {x = focus.x, y = DANGER_Y, brick = true, damage = totalDamage, rows = #breachedRows})
        if baseHp <= 0 then
            baseHp = 0
            gameState = "gameover"
            Game.CancelHoldSpeed()
            Game.ClearLaunchCharge()
            aiming = false
            startArmed = false
            if score > highScore then highScore = score end
            -- v0.13.60锛氳褰曞け璐ユ椂鍒伙紙杩囨浮鍔ㄧ敾璁℃椂鍩哄噯锛変笌澶嶆椿璧勬牸銆?
            Game._defeat.at = elapsed
            Game._defeat.revive = not reviveUsed
            Emit("game_over", {
                score = score, highScore = highScore, wave = wave,
                canRevive = not reviveUsed,
            })
            print("[Game] game over, score=" .. score .. ", wave=" .. wave
                .. ", canRevive=" .. tostring(not reviveUsed))
        end
    end

    -- 娓呯┖涓庣Щ闄わ細瓒婄嚎纰庤鍚庢暣鏋堕鏈虹殑鐮栧潡閮芥病浜嗗垯瑙嗕负琚獊鐮存竻绌猴紙涓嶅姞鍒嗭級銆?
    for i = #veggies, 1, -1 do
        local enemy = veggies[i]
        local width = enemy.gridW * enemy.brickSize
        local height = enemy.gridH * enemy.brickSize
        if not enemy.dead and IsEnemyCleared(enemy) then
            enemy.dead = true
            -- Boss 浠嶅彲鍦ㄥ彈鍒伴儴鍒嗚秺绾夸激瀹冲悗琚嚮璐ワ紱鍙湁鏈€鍚庡瓨娲绘牸瓒婄嚎鎵嶇畻閫冭劚銆?
            if enemy.isBoss and not enemy.escaped then
                bossDefeated = true
                Emit("boss_defeated", {enemyId = enemy.id, stage = stage, aircraftKey = enemy.aircraftKey})
            end
            if not enemy.breached or (enemy.isBoss and bossDefeated) then
                score = score + 50
                partsEarned = partsEarned + PARTS_PER_CLEAR * (partsBoostTime > 0 and 2 or 1) * BALL_TUNING.partsMul
                runAircraft[enemy.aircraftKey] = true
                clearStreak = clearStreak + 1
                -- 杩炵画娓呯┖鐨勮繛鍑荤粡楠屽姞鎴愶紝榧撳姳杩炵画鍘嬪埗銆?
                local bonus = math.min(clearStreak - 1, BALANCE.clearStreakBonusCap)
                GainXp(XP_PER_CLEAR + bonus)
                Emit("enemy_cleared", {
                    enemyId = enemy.id,
                    x = enemy.x + width * 0.5,
                    y = enemy.y + height * 0.5,
                    streak = clearStreak,
                    width = width, height = height,
                    -- 鍙弿杩版秷鐏簨瀹烇細瓒婄嚎鎹熷け杩囨満浣撶殑鍑昏触涓嶆槸瀹屾暣鍑绘瘉銆?
                    fullDestroyed = not enemy.breached,
                })
            end
        end

        if enemy.dead then table.remove(veggies, i) end
    end
end

UpdateReload = function()
    if not activeBall and #ballQueue > 0 then QueueNextBall() end
end

-- 閫氬叧璇勭骇锛坴0.13.4锛夛細鍓╀綑闃茬嚎琛€閲忓喅瀹氭槦绾э紱棰濆鍒嗘暟涓庨浂浠跺鍔辫繘缁撶畻銆?
-- 涓€鏄?闄╄儨锛?40%锛夈€佷袱鏄?浼樿壇锛?0~74%锛夈€佷笁鏄?瀹岀編锛?=75%锛夈€?
local function ComputeStageResult()
    local ratio = baseHp / GetMaxBaseHp()
    local stars, rating
    if ratio >= 0.75 then stars, rating = 3, "瀹岀編"
    elseif ratio >= 0.40 then stars, rating = 2, "浼樿壇"
    else stars, rating = 1, "闄╄儨" end
    return {
        stage = stage,
        stars = stars,
        rating = rating,
        bonusScore = 200 * stars,
        bonusParts = 50 * stars,
        -- v0.13.57锛氱粨绠楄繃娓″姩鐢荤殑璧峰鏃跺埢锛堣〃鐜板眰鎹绠楄繃娓¤繘搴︼級銆?
        -- 鐢ㄥ叏灞€ elapsed 鑰岄潪鏂板鍙橀噺锛岄伩鍏?Game 椤跺眰 local 瓒呴檺锛圓B-166锛夈€?
        animAt = elapsed,
    }
end

UpdateWaveLogic = function(dt)
    if gameState ~= "playing" or pendingLevelUps > 0 then return end

    if stageWave == StageCatalog.WAVES_PER_STAGE then
        local bossStillAlive = false
        for _, enemy in ipairs(veggies) do
            if enemy.isBoss and not enemy.dead and not IsEnemyCleared(enemy) then
                bossStillAlive = true
                break
            end
        end
        -- 棣栭閫冭劚鍙寜鐜版湁瓒婄嚎瑙勫垯鎵ｈ锛屼笉瓒充互缁撴潫鏈眬鏃堕噸鏂版淳鍑哄悓涓€棣栭銆?
        if not bossDefeated and not bossStillAlive then
            if baseHp <= 0 then return end
            nextWavePlan = PlanWave(wave)
            SpawnWave(StageCatalog.MAX_FLEET - #veggies)
            return
        end
        -- v0.13.4锛氶棰嗗嚮璐ュ嵆**缁撴潫鏈叧骞惰繘鍏ヨ儨鍒╃粨绠楁€?*锛堜笉鍐嶈嚜鍔ㄨ繘涓嬩竴鍏筹級銆?
        -- 娈嬩綑鎶よ埅涓庡彫鍞ゆ満閫€鍦猴紱鏄熺骇鐢卞墿浣欓槻绾胯閲忓喅瀹氾紝鐜╁鐪嬪畬缁撶畻鍚庢墜鍔ㄨ繘鍏炽€?
        if bossDefeated then
            stageResult = ComputeStageResult()
            score = score + stageResult.bonusScore
            partsEarned = partsEarned + stageResult.bonusParts * (partsBoostTime > 0 and 2 or 1) * BALL_TUNING.partsMul
            if score > highScore then highScore = score end
            nextWavePlan = nil
            Game.ClearLaunchCharge()
            aiming = false
            if activeBall then activeBall.x, activeBall.y = SLING_X, SLING_Y end
            for i = #veggies, 1, -1 do
                local enemy = veggies[i]
                Emit("enemy_withdrawn", {enemyId = enemy.id, aircraftKey = enemy.aircraftKey})
                table.remove(veggies, i)
            end
            gameState = "stagewin"
            Game.CancelHoldSpeed()
            Emit("stage_cleared", {
                stage = stage, wave = wave,
                stars = stageResult.stars, rating = stageResult.rating,
                bonusScore = stageResult.bonusScore, bonusParts = stageResult.bonusParts,
                baseHp = baseHp, maxBaseHp = GetMaxBaseHp(),
            })
            print("[Game] stage " .. stage .. " cleared: " .. stageResult.rating
                .. " " .. stageResult.stars .. "鏄?)
        end
        return
    end

    EnsureNextWavePlan()
    waveCooldown = waveCooldown - dt
    if waveCooldown > 0 then return end

    local plan = nextWavePlan
    local requiredSlots = plan and (1 + (plan.escortCount or 0)) or 1
    local availableSlots = StageCatalog.MAX_FLEET - #veggies
    if availableSlots < requiredSlots then
        waveCooldown = 1
        return
    end
    -- v0.13.57锛氬睆骞曞鏁屾満宸茶揪涓婇檺鏃?*涓嶅紑鏂颁竴娉?*鈥斺€旂簿鑻?鎶よ埅/棣栭涓嶈蛋 pendingSpawn 闃熷垪锛?
    -- 鑻ヤ笉鍦ㄦ鎷︽埅锛屽畠浠細鍦ㄩ槦鍒楀凡鍫嗘弧灞忓鏃跺啀鍙犱竴鏋讹紝鎶婂睆澶栨暟椤跺埌涓婇檺涔嬩笂銆?
    -- 鈿狅笍 鍙ｅ緞 = 灞忓**鍦ㄥ満**鏁?+ 鏈尝**寰呮斁**鏁帮細寰呮斁鐨勬櫘閫氭満灏嗘潵涔熶細鐢熸垚鍦ㄥ睆澶栵紝
    --    鍙暟鍦ㄥ満浼氳銆屽睆澶? + 闃熷垪杩樻湁1鏋躲€嶆斁琛岀簿鑻辨尝鍚庣珛鍒婚《鍒颁笂闄愪箣涓婏紙鏈壒韪╁埌锛夈€?
    -- 璁℃暟鍐呰仈锛堜笉鏂板椤跺眰 local锛孉B-166锛夛紝涓?SpawnNextNormalEnemy 鍚屽彛寰勩€?
    local offscreen = 0
    for i = 1, #veggies do
        local e = veggies[i]
        if not e.dead and e.y + e.gridH * e.brickSize < -102 then offscreen = offscreen + 1 end
    end
    if offscreen + pendingSpawn.remaining >= StageCatalog.MAX_OFFSCREEN then
        waveCooldown = 1
        return
    end

    stageWave = stageWave + 1
    wave = wave + 1
    partsEarned = partsEarned + PARTS_PER_WAVE * (partsBoostTime > 0 and 2 or 1) * BALL_TUNING.partsMul
    SpawnWave(availableSlots)
    waveCooldown = StageCatalog.GetInterval(stage, stageWave)
    EnsureNextWavePlan()
    -- v0.13.58锛氭瘡瀹屾垚涓€娉㈠彂鏀?鏇存崲涓€寮犻檮榄斿崱锛堥珮娉㈡鏇村鏄撳嚭楂樼█鏈夊害锛夈€?
    -- 鏀惧湪娉㈡鐪熸鎺ㄨ繘澶勶紙stageWave 宸?+1锛夛紝涓嶅湪 Boss 閲嶆淳/寮€娉㈠け璐ヨ矾寰勮Е鍙戙€?
    GrantEnchant()
end

-- v0.10.15锛氬叏灞忚捣鎵嬬殑鐩稿鎷栨嫿銆俻ull 涓烘墜鎸囩浉瀵规寜涓嬬偣鐨勪綅绉伙紙涓嶅啀鐩稿鍥哄畾寮瑰紦鐐癸級锛?
-- 杞﹁締瑙嗚閿氬畾 SLING 闄勮繎锛屾墜鎸囧湪灞忓箷浠绘剰浣嶇疆璧锋墜閮戒笉浼氶伄鎸¤溅杈嗐€?
-- v0.13.64锛氶挸鍒舵敼鍦?*璁捐(UI)鍧愭爣**閲屽仛锛堣 PullToGameplay锛夛紝鏁呮棫 ClampPull 宸茬Щ闄ゃ€?

function Game.Init(config)
    config = config or {}
    DW = config.width or DW
    DH = config.height or DH
    SetRandomSeed(config.seed or 1)
    pendingEvents = {}
    highScore = math.max(0, math.floor(tonumber(config.highScore) or 0))
    previousHighScore = highScore
    ResetGame()
    pendingEvents = {}
    gameState = "menu"
    print("[Game] core initialized at " .. DW .. "x" .. DH
        .. " highScore=" .. tostring(highScore))
end

---@param dt number 瑙勫垯鏃堕棿锛堝凡鍙犲姞椤垮抚锛?
---@param inputDt number|nil 鍘熷杈撳叆鏃堕棿锛涗笉浼犳椂浣跨敤 dt
function Game.Update(dt, inputDt)
    elapsed = elapsed + dt
    if gameState ~= "playing" then
        Game.ClearLaunchCharge()
        if Game._holdSpeed.down or Game._holdSpeed.active then Game.CancelHoldSpeed() end
        if gameState == "levelup" and Game._opening.active then
            local opening = Game._opening
            opening.timer = math.max(0, opening.timer - math.min(0.05, math.max(0, dt)))
            if opening.timer < 1e-9 then opening.timer = 0 end
            if opening.timer == 0 and opening.phase ~= "select" then
                if opening.phase == "ready" then
                    opening.active = false
                    opening.phase = nil
                    -- 棣栭€夊緟鍙戙€佹閫夊寮癸紱纭瀹屾垚鍚庢墠寮€濮嬪畬鏁翠笁绉掑噯澶囨湡銆?
                    activeBall = CreateMarble(opening.selected[1], CollectActiveWords())
                    ballQueue = { opening.selected[2] }
                    for i, ballType in ipairs(BALL_ORDER) do
                        if ballType == opening.selected[2] then ballCycleIndex = i; break end
                    end
                    gameState = "playing"
                    introTimer = INTRO_SECONDS
                    EnsureNextWavePlan()
                    print("[Game] opening complete ready=" .. opening.selected[1]
                        .. " spare=" .. opening.selected[2])
                else
                    if opening.phase == "between" then
                        opening.round = opening.round + 1
                        RollUpgradeChoices({})
                    end
                    opening.phase = "select"
                    opening.timer = opening.durations.select
                    print("[Game] opening selection round=" .. opening.round .. "/2")
                end
            end
        end
        -- 闈炴垬鏂楁€佸彧鎺ㄨ繘寮€灞€娴佺▼涓庢椂閽燂紱鍒囧叆 playing 鐨勬湰甯т篃涓嶆秷鑰?intro銆?
        return
    end

    -- v0.13.24锛氳繘鍏冲噯澶囨湡鍐呭喕缁撶帺娉曪紙鍙帹杩涜鏃跺櫒锛夛紝鍔ㄧ敾鏀捐缁欒〃鐜板眰銆?
    if introTimer > 0 then
        if Game._holdSpeed.down or Game._holdSpeed.active then Game.CancelHoldSpeed() end
        introTimer = math.max(0, introTimer - dt)
        if introTimer > 0 then return end
        SpawnWave()
        waveCooldown = StageCatalog.GetInterval(stage, stageWave)
    end

    if Game._holdSpeed.down and not Game._holdSpeed.active then
        if not Game.CanHoldSpeed() then
            Game.CancelHoldSpeed()
        else
            Game._holdSpeed.time = Game._holdSpeed.time + math.max(0, inputDt or dt)
            if Game._holdSpeed.time + 1e-9 >= Game._holdSpeed.threshold then
                Game._holdSpeed.active = true
                print("[Game] empty-hand hold -> 2x")
            end
        end
    end
    if aiming and activeBall then
        local c = Game._launchCharge
        local before = c.time
        c.time = math.min(c.total, c.time + math.min(0.05, math.max(0, inputDt or dt)))
        if c.total - c.time <= 1e-9 then c.time = c.total end
        if before < c.total and c.time == c.total then print("[Game] launch charge ready") end
    else
        Game.ClearLaunchCharge()
    end
    -- elapsed銆佸噯澶囧姩鐢诲彧鎺ㄨ繘鍘熷瑙勫垯鏃堕棿锛涘叾浣欐垬鏂楄鏃剁粺涓€浣跨敤妯℃嫙鏃堕棿銆?
    -- 宸插紑鍚悗涓嶅洜琛ヨ溅閫€鍑猴紝鍙敱鏉炬墜銆佺湡瀹炲彂灏勬垨鐢熷懡鍛ㄦ湡鍙栨秷銆?
    -- 鎷栨嫿钃勫姏鏃跺叏灞€鍑忛€燂紙BALANCE.dragTimeScale锛夛紝鏉炬墜鍗虫仮澶嶏紱涓庣┖鎵?2 鍊嶉€熶簰鏂ワ紙钃勫姏鏃跺繀鏈夎溅锛屼笉鍏卞瓨锛夈€?
    local dragSlow = (aiming and activeBall) and BALANCE.dragTimeScale or 1
    dt = dt * (Game._holdSpeed.active and 2 or 1) * dragSlow
    UpdateAiming()
    partsBoostTime = math.max(0, partsBoostTime - dt)
    UpdateMarbles(dt)
    if gameState ~= "playing" then return end
    UpdateEnemies(dt)
    if gameState ~= "playing" then return end
    -- v0.13.65锛氬够褰变綋绱犲潡鈥斺€斿厛鍒ゅ畾鍙戝皠锛屽啀鎺ㄨ繘鍦ㄥ満骞诲奖锛堜笅绉?琚嚮纰?瓒婄嚎鎵ｈ锛夈€?
    Game._phantom.TryFire(dt)
    Game._phantom.Update(dt)
    if gameState ~= "playing" then return end
    -- v0.13.26锛氬悓娉㈤敊宄扮敓鎴愨€斺€旀湰娉㈣繕娌℃斁瀹屾椂鎸夐棿闅旈€愭灦鏀惧嚭锛堢簿鑻辨姢鑸悓鏈哄埗锛夈€?
    if pendingSpawn.remaining > 0 then
        pendingSpawn.timer = pendingSpawn.timer - dt
        if pendingSpawn.timer <= 0 then
            SpawnNextNormalEnemy()
            if gameState ~= "playing" then return end
        end
    end
    UpdateReload()
    UpdateWaveLogic(dt)
end

function Game.IsLevelUp()
    return gameState == "levelup"
end

function Game.PointerDown(px, py, uiX, uiY)
    if gameState == "menu" then return end
    if gameState == "gameover" or gameState == "stagewin" then return end
    startArmed = false
    if gameState == "paused" then
        Game.Resume()
        return
    end
    if gameState ~= "playing" or aiming then return end
    if not activeBall then
        if Game.CanHoldSpeed() then
            Game._holdSpeed.down = true
            Game._holdSpeed.time = 0
        end
        return
    end
    if introTimer > 0 then return end

    -- v0.13.64锛氭媺寮撳湪**璁捐(UI)鍧愭爣**閲岄挸鍒讹紙灞忓箷涓婄殑鍦嗭級锛屾寜涓嬬偣涔熻璁捐鍧愭爣銆?
    Game.ClearLaunchCharge()
    Game._launchCharge.x, Game._launchCharge.y = px, py
    Game._launchCharge.uiX, Game._launchCharge.uiY = uiX, uiY
    aiming = true
    local pull = Game._pullSpace
    pull.uiX = uiX or px
    pull.uiY = uiY or py
    pull.dist = 0
    pull.gnorm = 0
    aimX = SLING_X
    aimY = SLING_Y
    print("[Game] launch charge started")
end

-- v0.13.66锛氭嫋鎷借寖鍥?=銆屽睆骞曟鍦嗭紙鍗婂緞 MAX_PULL锛? 鐜╂硶绌洪棿鍚屾鍦嗐€嶃€?
--   鈶犺璁″潗鏍囨眰浣嶇Щ锛屾寜 MAX_PULL 鍦嗛挸鍒讹紙灞忓箷涓哄噯锛氬崐寰?85%脳150 璁捐鍍忕礌锛夛紱
--   鈶￠櫎浠ユ姇褰辩缉鏀?sx/sy 寰楃帺娉曚綅绉诲悗锛屽啀鎸夌煭杞村崐寰勫渾閽冲埗锛堥暱杞寸缉鍒扮煭杞达紝
--     鐜╂硶绌洪棿涓嶅啀鏄>楂樼殑妞渾锛夛紱
--   鈶㈣繑鍥炵帺娉?dx/dy銆佽璁″儚绱犳媺璺?dist锛堟鍖哄垽瀹氾級涓庡綊涓€鍖栬搫鍔?gnorm
--     锛?鐜╂硶鎷夎窛/鍦嗗崐寰勶紝鏂瑰悜鏃犲叧銆佹弧鎷夋亽 1锛屼緵濞佸姏/鐬勫噯浜害鏄犲皠锛夈€?
---@param uiX number
---@param uiY number
---@return number dx
---@return number dy
---@return number dist
local function PullToGameplay(uiX, uiY)
    local pull = Game._pullSpace
    local udx = (uiX or pull.uiX) - pull.uiX
    local udy = (uiY or pull.uiY) - pull.uiY
    local dist = math.sqrt(udx * udx + udy * udy)
    if dist > MAX_PULL then
        udx = udx / dist * MAX_PULL
        udy = udy / dist * MAX_PULL
        dist = MAX_PULL
    end
    local dx = udx / pull.sx
    local dy = udy / pull.sy
    -- 鐜╂硶鍦嗗崐寰?= 鐭酱锛堢缉鏀捐緝澶х殑涓€杞村搴旇緝鐭殑鐜╂硶鑼冨洿锛?
    local rShort = MAX_PULL / math.max(pull.sx, pull.sy)
    local gdist = math.sqrt(dx * dx + dy * dy)
    if gdist > rShort then
        dx = dx / gdist * rShort
        dy = dy / gdist * rShort
        gdist = rShort
    end
    pull.dist = dist
    pull.gnorm = rShort > 1e-6 and gdist / rShort or 0
    return dx, dy, dist
end

function Game.PointerMove(px, py, uiX, uiY)
    if not aiming or gameState ~= "playing" then return end
    Game._launchCharge.x, Game._launchCharge.y = px, py
    Game._launchCharge.uiX, Game._launchCharge.uiY = uiX, uiY
    local dx, dy = PullToGameplay(uiX, uiY)
    aimX = SLING_X + dx
    aimY = SLING_Y + dy
    UpdateAiming()
end

function Game.PointerUp(px, py, uiX, uiY)
    -- 鍙彇娑堢┖鎵嬪€嶉€燂紱鏈彂钃勫姏椤讳繚鐣欏埌 LaunchMarble 閿佸畾璧勬牸涔嬪悗銆?
    Game.CancelHoldSpeed()
    if gameState ~= "playing" or not aiming then
        Game.ClearLaunchCharge()
        return
    end
    startArmed = false
    Game._launchCharge.x, Game._launchCharge.y = px, py
    Game._launchCharge.uiX, Game._launchCharge.uiY = uiX, uiY
    local dx, dy, distance = PullToGameplay(uiX, uiY)
    aimX = SLING_X + dx
    aimY = SLING_Y + dy
    UpdateAiming()
    aiming = false
    -- 姝诲尯鎸?*璁捐鍍忕礌**鍒ゅ畾锛?5 璁捐鍍忕礌锛夛紝涓庢姇褰辩缉鏀炬棤鍏筹紝淇濊瘉鎵嬫劅涓€鑷淬€?
    if distance <= 15 then
        if activeBall then activeBall.x, activeBall.y = SLING_X, SLING_Y end
        Game.ClearLaunchCharge()
        return
    end
    -- v0.13.66锛氬▉鍔涚敤鏂瑰悜鏃犲叧鐨勭帺娉曞綊涓€鍖栨媺璺濓紙婊℃媺鎭?1锛夛紝涓嶅啀鎸夎璁″儚绱犺窛绂汇€?
    if activeBall then LaunchMarble(dx, dy, Game._pullSpace.gnorm or 0) end
    Game.ClearLaunchCharge()
end

function Game.HandleAction(action, pressed)
    if not pressed then return end
    if action == "start" and gameState == "menu" then
        StartGame()
    elseif action == "restart" and gameState == "gameover" then
        StartGameAt(stage)
    end
end

-- 閫夊叧鐣岄潰纭鍚庣敱缂栨帓灞傜洿鎺ヨ皟鐢紱stageNumber 宸叉寜瑙ｉ攣杩涘害鏍￠獙銆?
function Game.StartStageAt(stageNumber)
    if gameState ~= "menu" then return false end
    StartGameAt(math.max(1, math.floor(tonumber(stageNumber) or 1)))
    return true
end

-- 鑳滃埄缁撶畻椤点€屽啀鎴樻湰鍏炽€嶏細閲嶅紑褰撳墠鍏筹紙淇濈暀宸茶В閿佽繘搴︼紝鎴愰暱閲嶇疆锛夈€?
function Game.RetryStage()
    if gameState ~= "stagewin" or not stageResult then return false end
    StartGameAt(stageResult.stage)
    return true
end

-- 鑳滃埄缁撶畻椤点€屼笅涓€鍏炽€嶏細浠呭綋涓嬩竴鍏冲瓨鍦ㄦ椂鏈夋晥銆?
function Game.NextStage()
    if gameState ~= "stagewin" or not stageResult then return false end
    local nextStage = stageResult.stage + 1
    -- v0.13.13锛氬叧鍗℃棤闄愶紝銆屼笅涓€鍏炽€嶆案杩滃彲鐢ㄣ€?
    StartGameAt(nextStage)
    return true
end

function Game.IsGameOver()
    return gameState == "gameover"
end

function Game.IsStageWin()
    return gameState == "stagewin"
end

function Game.CanRevive()
    return gameState == "gameover" and not reviveUsed
end

-- 婵€鍔辫棰戠湅瀹屽悗鐢辩紪鎺掑眰璋冪敤锛氬洖 50 琛€銆佹妸浠嶅瓨娲荤殑缂栭槦鎶洖灞忓锛岀户缁湰灞€銆?
function Game.ReviveFromAd()
    if gameState ~= "gameover" or reviveUsed then return false end
    reviveUsed = true
    Game.CancelPointer()
    baseHp = REVIVE_HP
    aiming = false
    startArmed = false
    local spawnY = -102
    local bossAlive = false
    for _, enemy in ipairs(veggies) do
        if enemy.isBoss and not enemy.dead and not IsEnemyCleared(enemy) then
            bossAlive = true
        end
        if not enemy.dead then
            local height = enemy.gridH * enemy.brickSize
            enemy.y = spawnY - height - 24
        end
    end
    gameState = "playing"
    -- 棣栭鍦ㄨ秺绾垮鑷寸敓鍛藉綊闆剁殑甯ф秷澶辨椂锛屽娲诲悗琛ラ綈褰撳墠鍗佹尝鐨勭洰鏍囥€?
    if stageWave == StageCatalog.WAVES_PER_STAGE and not bossDefeated and not bossAlive then
        for i = #veggies, 1, -1 do
            if veggies[i].isBoss then table.remove(veggies, i) end
        end
        nextWavePlan = PlanWave(wave)
        SpawnWave(StageCatalog.MAX_FLEET - #veggies)
    end
    -- 淇濈暀鏈眬宸茬粨绠楀熀绾匡紱澶嶆椿鍚庡啀娆℃浜″彧鍏ュ簱鏂板闆朵欢銆?
    partsSettled = false
    lastSettledParts = 0
    Emit("base_revived", {hp = baseHp})
    print("[Game] revived from ad, hp=" .. tostring(baseHp))
    return true
end

function Game.RestartFromOver()
    if gameState ~= "gameover" then return end
    StartGame()
end

-- ============================================================================
-- v0.11.0 鍟嗕笟鍖栵細灞€鍐呴浂浠剁粨绠椼€?
-- 缁撶畻椤典竴鍑虹幇灏辩敱缂栨帓灞傛寜 脳1 鍏ュ簱锛涖€岀湅骞垮憡鍙屽€嶃€嶅啀琛ュ彂绛夐闆朵欢銆?
-- ============================================================================

---@return integer 褰撳墠闃舵寰呯粨绠楁垨宸茬粨绠楃殑闆朵欢
function Game.GetRunParts()
    if partsSettled then return lastSettledParts end
    -- v0.13.28锛歱artsEarned 鍙兘鍥犮€岃鐢插己鍖栥€嶇殑 partsMul 鑰屾槸娴偣锛涘睍绀?鍏ュ簱涓€寰嬪彇鏁淬€?
    return math.floor(math.max(0, partsEarned - settledParts))
end

-- 璺ㄥ眬缁熻鍙澧為噺锛涘娲诲悗鍐嶆姝讳骸涓嶉噸澶嶈銆屽畬鎴愪竴灞€銆嶄笌鏃х爾鍧椼€?
-- 鑳滃埄缁撶畻锛坰tagewin锛夊悓鏍峰叆搴撻浂浠朵笌缁熻銆?
function Game.TakeSettlementStats()
    if (gameState ~= "gameover" and gameState ~= "stagewin") or partsSettled then return 0, false, 0 end
    local delta = math.max(0, bricksBroken - settleBook.bricks)
    settleBook.bricks = bricksBroken
    local firstFinish = not settleBook.runCounted
    settleBook.runCounted = true
    -- v0.14.x 瀛橀挶缃愶細鍙洖浼犳湰灞€鏂板榻胯疆锛堝娲诲悗鍐嶆缁撶畻涓嶉噸澶嶈鏃у€硷級銆?
    local gearDelta = math.max(0, settleBook.gear - settleBook.gearSettled)
    settleBook.gearSettled = settleBook.gear
    return delta, firstFinish, gearDelta
end

---@param multiplier integer
---@return integer granted 鏈鍏ュ簱鐨勬柊澧為浂浠讹紙0 琛ㄧず娌℃湁鏂板锛?
function Game.SettleParts(multiplier)
    if partsSettled then return 0 end
    partsSettled = true
    -- v0.13.28锛氬厛鍙栨暣鍒版暣鏁板啀绠楃櫨鍒嗘瘮鍔犳垚锛岄伩鍏?partsMul 鐨勬诞鐐规笚杩涘叆搴撳€笺€?
    local delta = math.floor(math.max(0, partsEarned - settledParts))
    settledParts = partsEarned
    -- v0.13.5锛氬ぉ璧嬫爲閫氱敤绾胯矾鐨勭粨绠楅浂浠剁櫨鍒嗘瘮鍔犳垚锛堝湪骞垮憡鍊嶆暟鍓嶅彔鍔狅級銆?
    local pctBonus = math.floor(delta * talentPartsPct / 100 + 0.5)
    delta = delta + pctBonus
    lastSettledParts = delta * math.max(1, math.floor(multiplier or 1))
    if multiplier and multiplier > 1 then partsDoubled = true end
    print("[Game] parts settled: +" .. lastSettledParts .. " (pctBonus=" .. pctBonus .. ")")
    return lastSettledParts
end

---@return boolean
function Game.CanDoubleSettle()
    return partsSettled and not partsDoubled and lastSettledParts > 0
end

---@return integer extra 骞垮憡鍙屽€嶈ˉ鍙戠殑闆朵欢鏁帮紙0 琛ㄧず涓嶅彲鐢級
function Game.DoubleSettlement()
    if not Game.CanDoubleSettle() then return 0 end
    partsDoubled = true
    Emit("settle_doubled", {amount = lastSettledParts})
    print("[Game] settlement doubled: +" .. lastSettledParts)
    return lastSettledParts
end

function Game.ApplyCloudHighScore(value)
    local n = math.max(0, math.floor(tonumber(value) or 0))
    if n > highScore then
        highScore = n
        print("[Game] cloud highScore applied=" .. tostring(highScore))
    end
    return highScore
end

function Game.Pause()
    if gameState == "playing" then
        Game.CancelPointer()
        -- v0.10.24锛氭殏鍋滄椂鍙栨秷杩涜涓殑鎷栨嫿骞惰寰呭彂杞﹀綊浣嶏紝
        -- 閬垮厤鎭㈠鐬棿甯︾潃鏃ц搫鍔?娈嬬暀 aiming 鐘舵€併€?
        Game.ClearLaunchCharge()
        aiming = false
        if activeBall then
            activeBall.x = SLING_X
            activeBall.y = SLING_Y
        end
        gameState = "paused"
        Emit("game_paused")
    end
end

function Game.Resume()
    if gameState == "paused" then
        gameState = "playing"
        Emit("game_resumed")
    end
end

function Game.IsPaused()
    return gameState == "paused"
end

-- v0.12.5锛氫富鍔ㄥ洖涓昏彍鍗曪紙鏆傚仠椤点€岃繑鍥炰富鑿滃崟銆? 缁撶畻椤点€屽洖涓昏彍鍗曘€嶅嚭鍙ｏ級銆?
-- 鍗囩骇鎬佸繀椤诲厛閫夊畬鍗★紙闈㈡澘鏄己鍒朵笁閫変竴锛夛紝涓嶈蛋杩欓噷銆?
function Game.GoToMenu()
    if gameState == "playing" or gameState == "paused" or gameState == "gameover"
        or gameState == "stagewin" then
        Game.CancelPointer()
        gameState = "menu"
        Emit("game_reset")
        print("[Game] returned to menu")
        return true
    end
    return false
end

-- 浠呬緵鎺㈤拡/楠屾敹锛氱洿鎺ヨ繘鍏ュけ璐ョ粨绠楋紙澶嶅埢鐪熷疄 gameover 鍒嗘敮鐨勭姸鎬佽缃?+ 浜嬩欢锛夈€?
function Game.DebugForceGameOver()
    if gameState ~= "playing" then return false end
    baseHp = 0
    gameState = "gameover"
    Game.CancelHoldSpeed()
    Game.ClearLaunchCharge()
    aiming = false
    startArmed = false
    if score > highScore then highScore = score end
    Game._defeat.at = elapsed
    Game._defeat.revive = not reviveUsed
    Emit("game_over", {
        score = score, highScore = highScore, wave = wave,
        canRevive = not reviveUsed,
    })
    return true
end

-- 浠呬緵鎺㈤拡/楠屾敹锛氭瀯閫犱竴娆＄湡瀹炶儨鍒╃粨绠楋紙璧板悓涓€鏉?stagewin 閫昏緫锛屽惈 stageResult锛夈€?
function Game.DebugForceStageWin()
    if gameState ~= "playing" then return false end
    stageResult = ComputeStageResult()
    score = score + stageResult.bonusScore
    partsEarned = partsEarned + stageResult.bonusParts
    if score > highScore then highScore = score end
    gameState = "stagewin"
    return true
end

function Game.DrainEvents()
    local events = pendingEvents
    pendingEvents = {}
    return events
end

-- v0.10.19锛氱瀯鍑嗙洿绾裤€備粎鍦ㄦ嫋鎷借搫鍔涜秴杩?15px 姝诲尯鏃惰繑鍥炶捣鐐?鍒版渶杩戠帺娉曡竟鐣岀殑缁堢偣锛?
-- 鏂瑰悜涓?LaunchMarble 瀹屽叏涓€鑷达紙-pull 褰掍竴鍖栵級銆傚彧绠椾竴鏉＄洿绾匡紝涓嶅仛鍙嶅脊棰勬祴銆?
local AIM_DEAD_ZONE = 15
local function ComputeAimLine()
    if not (aiming and activeBall) then return nil end
    local pullX = aimX - SLING_X
    local pullY = aimY - SLING_Y
    local length = math.sqrt(pullX * pullX + pullY * pullY)
    if length <= 1e-4 then return nil end
    -- v0.13.66锛氭鍖轰粛鎸夎璁″儚绱犲垽瀹氾紱鐬勫噯浜害鐢ㄦ柟鍚戞棤鍏崇殑鐜╂硶褰掍竴鍖栨媺璺濄€?
    local uiDist = Game._pullSpace.dist or 0
    if uiDist <= AIM_DEAD_ZONE then return nil end
    local dirX = -pullX / length
    local dirY = -pullY / length
    -- v0.13.66锛氱瀯鍑嗛娴嬪弽寮圭敤 85% 鍙嶅脊纰版挒绠憋紝涓庤鍒欏眰鎾炲鍒ゅ畾涓€鑷淬€?
    local radius = (activeBall.radius or 0) * BALANCE.bounceBoxScale
    local x0, y0 = activeBall.x, activeBall.y

    -- 姹傚皠绾夸笌宸?鍙?椤朵笁杈圭殑鏈€杩戞鍙傛暟 t锛堝彂灏勫悜涓婏紝搴曡竟涓嶅弬涓庯級銆?
    local t = math.huge
    if dirX < -0.0001 then
        t = math.min(t, (radius - x0) / dirX)
    elseif dirX > 0.0001 then
        t = math.min(t, (DW - radius - x0) / dirX)
    end
    if dirY < -0.0001 then
        t = math.min(t, (TOP_BOUND_Y + radius - y0) / dirY)
    end
    if t == math.huge or t <= 0 then return nil end
    -- v0.10.23锛氳緭鍑哄綊涓€鍖栬搫鍔?(姝诲尯鈫掓弧鎷?鏄犲皠鍒?0..1)锛屼緵娓叉煋灞傚仛寮辨媺娓愭樉銆?
    -- v0.13.66锛氭敼鐢ㄧ帺娉曞綊涓€鍖栨媺璺濓紙婊℃媺鎭?1锛夛紝姝诲尯涔嬩笂浠?gnorm 璧锋笎鏄俱€?
    local power01 = math.max(0, math.min(1, Game._pullSpace.gnorm or 0))
    return {
        x1 = x0, y1 = y0,
        x2 = x0 + dirX * t, y2 = y0 + dirY * t,
        power = power01,
    }
end

function Game.GetSnapshot()
    -- WO-16/P9锛氬鐢ㄥ父椹荤紦鍐诧紝浠呮瘡甯ц鐩栧瓧娈点€傜瀯鍑嗙姸鎬佸彧渚涙嫋鎷藉彂灏勶紝涓嶅啀鐢熸垚棰勭瀯杞ㄨ抗銆?
    local s = snapshotBuffer_ or {}
    snapshotBuffer_ = s
    s.state = gameState
    s.score = score
    s.highScore = highScore
    s.newRecord = (gameState == "gameover" or gameState == "stagewin")
        and score > previousHighScore and score > 0
    s.baseHp = baseHp
    s.maxBaseHp = GetMaxBaseHp()
    s.talentHpBonus = talentMaxHpBonus
    s.talentPartsPct = talentPartsPct
    -- v0.13.15锛氭垚闀跨嚎澶╄祴璇绘暟锛堜緵 UI 鏄剧ず鏆村嚮鐜?鍩虹鏀诲嚮锛夈€?
    s.talentCritChance = talentCritChance
    s.talentAtkBonus = talentAtkBonus
    s.talentHpPerNode = TalentCatalog.MAX_HP_PER_NODE
    s.wave = wave
    s.stage = stage
    s.stageWave = stageWave
    s.wavesPerStage = StageCatalog.WAVES_PER_STAGE
    s.stageSubtitle = StageCatalog.GetLayoutSubtitle(stage)
    s.stageResult = stageResult
    -- v0.13.62锛氭湰灞€鏄惁鍑昏触杩囬棰嗭紙鎴愬氨銆屾柀棣栬鍔ㄣ€嶇敤锛涘彧鍦?ResetGame 澶嶄綅锛夈€?
    s.bossDefeated = bossDefeated
    -- v0.13.60锛氬け璐ヨ繃娓★紙gameover 鍔ㄧ敾鐨勮鏃跺熀鍑?+ 鏄惁鍙娲伙級銆?
    s.defeatAt = Game._defeat.at
    s.defeatRevive = Game._defeat.revive
    -- v0.13.13锛氬叧鍗℃棤闄愨€斺€旀案杩滄湁涓嬩竴鍏筹紱stageTotal 鍙槸銆岄毦搴﹀皝椤跺弬鑰冨叧鏁般€嶃€?
    s.stageHasNext = (gameState == "stagewin" and stageResult ~= nil) or false
    s.stageTotal = StageCatalog.STAGE_SOFT_CAP
    s.elapsed = elapsed
    -- 琛ㄧ幇灞傜粺涓€鏃堕挓鍊嶇巼锛氭嫋鎷借搫鍔涗紭鍏堬紙鍏ㄥ眬鍑忛€燂級锛屽惁鍒欑┖鎵嬮暱鎸?2 鍊嶉€熴€?
    -- 鍚勭壒鏁堟ā鍧楋紙娉㈠３/闄勯瓟鐞冿級鍙箻涓€娆★紝鏆傚仠/骞垮憡鐢?allowedDt=0 鍐荤粨銆?
    s.timeScale = gameState == "playing"
        and ((aiming and activeBall) and BALANCE.dragTimeScale
            or (Game._holdSpeed.active and 2 or 1))
        or 1
    s.canHoldSpeed = Game.CanHoldSpeed()
    s.holdSpeedPending = Game._holdSpeed.down and not Game._holdSpeed.active
    s.pointerEpoch = Game._holdSpeed.epoch
    s.chargeActive = gameState == "playing" and aiming and activeBall ~= nil
    s.chargeProgress = s.chargeActive and Game._launchCharge.time / Game._launchCharge.total or 0
    -- 钃勫姏杈惧埌瀹屾垚闃堝€硷紙85%锛夊嵆瑙嗕綔銆屾弧钃勩€嶏細琛ㄧ幇灞傛嵁姝ゆ彁鍓嶇垎鍙戝叏鎭紙涓嶅繀绛?100%锛夈€?
    s.chargeReady = s.chargeActive and s.chargeProgress >= BALANCE.chargeCompleteThreshold
    s.chargeX, s.chargeY = Game._launchCharge.x, Game._launchCharge.y
    s.chargeUiX, s.chargeUiY = Game._launchCharge.uiX, Game._launchCharge.uiY
    -- 闈掑湀鍦嗗績閿氬畾寰呭彂杞︽潈濞佷綅缃紙鐜╂硶鍧愭爣锛夛紱琛ㄧ幇灞傜敤鍚屼竴鐜╂硶鎶曞奖鍗冲緱杞﹁締灞忓箷涓績锛?
    -- 涓嶅啀閿氭寚閽堛€傛棤钃勫姏鏃剁疆 nil锛岀敱琛ㄧ幇灞傚洖閫€鏃ф寚閽堣矾寰勩€?
    s.chargeCarX = s.chargeActive and activeBall.x or nil
    s.chargeCarY = s.chargeActive and activeBall.y or nil
    s.playerLevel = playerLevel
    s.xp = xp
    s.xpToNext = xpToNext
    s.pendingLevelUps = pendingLevelUps
    s.upgradePicks = upgradePicks
    s.clearStreak = clearStreak
    s.bricksBroken = bricksBroken
    -- v0.14.x 瀛橀挶缃愶細鏈眬绱榻胯疆锛?00 鍧?100 榻胯疆锛岀簿鑻辨満姣忓潡 2 鍊嶏級锛涘彧璇绘爣閲忋€?
    s.gear = settleBook.gear
    s.concurrentCount = #veggies    -- WO-12/P6锛氬綋鍓嶅悓灞忕紪闃熸暟锛圚UD 鎸囨爣锛?
    -- 褰撳墠鍏冲崱鏍煎瓙灏哄锛?4/15/16锛夛細鏉冨▉鍊硷紝渚涜〃鐜板眰鎸夈€屾牸銆嶅亸绉伙紝娉㈤棿闅欐棤鏁屾満鏃朵篃鍙敤銆?
    s.brickSize = GetBrickSize(wave)
    s.brickDmg = math.max(1, math.ceil(BRICK_BASE_DAMAGE) + BALL_TUNING.lineDamageBonus)
    -- v0.13.28锛氬眬鍐呴€氱敤鍗＄殑娲剧敓璇绘暟锛堝彧璇绘爣閲忥紝渚?UI 涓庢牎楠岋紱涓嶆柊寤?table 浠ュ厤姣忓抚 GC锛夈€?
    s.brickXpFlat = BALL_TUNING.brickXpFlat
    s.partsMul = BALL_TUNING.partsMul
    s.armorReduce = BALL_TUNING.armorReduce
    s.launchSpeedMul = BALL_TUNING.launchSpeedMul
    -- P11锛氬凡婵€娲昏瘝鏉★紙鍙鍒楄〃锛屼緵 HUD 灞曠ず锛屼笉鍙嶅悜鍐欒鍒欙級銆?
    local words = {}
    for _, id in ipairs(WORD_IDS) do
        if activeWords[id] then words[#words + 1] = id end
    end
    s.activeWords = words
    s.upgradeChoices = Game.GetUpgradeChoices()
    s.openingSelection = Game._opening.active
    s.openingRound = Game._opening.round
    s.openingTotal = Game._opening.total
    s.openingFirstVehicle = Game._opening.selected[1]
    s.openingSecondVehicle = Game._opening.selected[2]
    s.openingPhase = Game._opening.phase
    s.openingTimer = Game._opening.timer
    s.openingPhaseTotal = Game._opening.durations[Game._opening.phase] or 0
    s.veggies = veggies
    -- v0.13.65锛氬湪鍦哄够褰变綋绱犲潡锛堝彧璇伙紱娓叉煋灞傜敾鎴愰珮浜柟鍧楋級銆傚師濮嬪紩鐢紝涓嶅仛娣辨嫹璐濄€?
    s.phantoms = Game._phantom.list
    s.marbles = marbles
    s.aiming = aiming
    -- v0.11.4锛氭柊鎵嬩笅鎷夋彁绀哄彧鍦ㄣ€屾湰灞€杩樻病鍙戝皠杩囥€佷篃娌℃鍦ㄦ嫋鎷姐€嶆椂鏄剧ず銆?
    s.showPullHint = (gameState == "playing") and (not hasLaunched) and (not aiming)
    s.aimX = aimX
    s.aimY = aimY
    s.slingX = SLING_X
    s.slingY = SLING_Y
    s.maxPull = MAX_PULL
    s.activeBall = activeBall
    -- v0.10.19锛氭嫋鎷借搫鍔涜秴杩囨鍖烘椂杈撳嚭涓€鏉＄洿鐬勭嚎锛堣鍒欏眰绠楀埌鏈€杩戠帺娉曡竟鐣岀殑浜ょ偣锛夛紝
    -- 3D 鍚庣鍙礋璐ｇ敾锛屼笉鍋氬弽寮归娴嬨€?
    s.aimLine = ComputeAimLine()
    s.ballQueue = ballQueue
    s.ballOrder = BALL_ORDER
    s.unlockedBalls = unlockedBalls
    -- v0.12.15锛氭湰灞€寮硅嵂鎬婚噺锛? 杈嗗緟鍙?+ 澶囧脊锛夛紝渚涖€屽脊鑽墿瀹广€嶅睍绀轰笌鏍￠獙銆?
    s.ammoCapacity = ammoCapacity
    s.width = DW
    s.height = DH
    s.dangerY = DANGER_Y
    s.topBound = TOP_BOUND_Y
    -- v0.10.31锛氫笅涓€娉㈤鍛婂彧璇昏鍒掞紝娓叉煋灞傜敾灏忓浘锛屼笉鍙嶅悜鍐欒鍒欍€?
    s.nextWave = (gameState == "playing") and nextWavePlan or nil
    s.waveCooldown = waveCooldown
    -- v0.13.24锛氳繘鍏冲噯澶囨湡鍓╀綑绉掓暟锛堟覆鏌撳眰鐢昏繃娓?鍑嗗鐣岄潰锛?0 = 鏈紑鎴橈級
    s.introTimer = introTimer
    s.introTotal = INTRO_SECONDS
    s.canRevive = (gameState == "gameover") and not reviveUsed
    s.reviveUsed = reviveUsed
    -- v0.11.0 鍟嗕笟鍖栵細灞€鍐呴浂浠朵笌鍗囩骇闈㈡澘鍙樼幇鐘舵€侊紙娓叉煋灞傚彧璇伙級銆?
    s.partsEarned = math.floor(partsEarned)
    local aircraftList = {}
    for key in pairs(runAircraft) do aircraftList[#aircraftList + 1] = key end
    s.runAircraft = aircraftList
    s.runParts = Game.GetRunParts()
    s.partsSettled = partsSettled
    s.partsDoubled = partsDoubled
    s.canDoubleSettle = Game.CanDoubleSettle()
    s.rerollFreeAvailable = Game.CanFreeReroll()
    -- v0.13.64锛氬厤璐归噸鎶界殑銆屽墿浣?/ 鎬绘暟銆嶏紝渚涘崌绾ч潰鏉挎樉绀?N/M锛堝ぉ璧嬪彲鎻愬崌涓婇檺锛夈€?
    s.rerollFreeLeft = math.max(0, Game.GetFreeRerollTotal() - upgradeRerollFreeUsed)
    s.rerollFreeTotal = Game.GetFreeRerollTotal()
    -- 鏆傚仠琛ョ粰绔欙紙鍙锛屼緵鏆傚仠闈㈡澘鐢绘寜閽級
    s.canPauseHeal = Game.CanPauseHeal()
    s.pauseHealLeft = Game.GetPauseHealLeft()
    s.canPauseRarePick = Game.CanPauseRarePick()
    s.pauseRareLeft = Game.GetPauseRareLeft()
    s.canPauseOrbital = Game.CanPauseOrbital()
    s.canPauseReload = Game.CanPauseReload()
    s.canPausePartsBoost = Game.CanPausePartsBoost()
    s.partsBoostTime = partsBoostTime
    -- 灞€鍐呴亾鍏锋Ы锛堟覆鏌撳眰鍙锛夛細姣忔牸 {key,name,color,charges,canGrant,usedThisRun}
    -- usedThisRun 渚涙覆鏌撳眰鐢ㄣ€岀簿鐏靛彉鏆?+ 瑙掓爣銆嶈〃杈俱€屾湰灞€宸茬敤杩囥€嶏紝涓嶅啓鏂囧瓧銆?
    local items = {}
    for i = 1, #ITEM_DEFS do
        local def = ITEM_DEFS[i]
        items[i] = {
            key = def.key, name = def.name, color = def.color,
            charges = itemCharges[def.key] or 0,
            canGrant = Game.CanGrantItem(def.key),
            usedThisRun = itemUsedThisRun[def.key] == true,
        }
    end
    s.items = items
    s.baseShield = baseShield
    -- v0.13.58锛氶檮榄斿崱鍙蹇収锛堝乏涓婅灞曠ず锛夈€俢ard=鍦ㄦ墜锛宲ending=宸查『寤剁粰涓嬩竴杈嗗緟鍙戣溅銆?
    -- 鍙湪鏈夊崱/鏈夐『寤舵椂鏂板缓灏忚〃锛岄伩鍏嶆瘡甯?GC锛堟棤鍗℃椂缃?nil锛夈€?
    local ecard, epend = Game._enchant.card, Game._enchant.pending
    s.enchantCard = ecard and {
        id = ecard.id, name = ecard.name, rarity = ecard.rarity, desc = ecard.desc,
    } or nil
    s.enchantPending = epend and { id = epend.id, name = epend.name, rarity = epend.rarity } or nil
    return s
end

return Game
