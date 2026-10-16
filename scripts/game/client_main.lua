-- game/client_main.lua
-- 瀹㈡埛绔帺娉曠紪鎺掞細妗ユ帴寮曟搸浜嬩欢銆佹牳蹇冪帺娉曘€佽〃鐜扮姸鎬佷笌鍙浛鎹㈡覆鏌撳悗绔€?
--
-- 鈿狅笍 寮曟搸閫氳繃鑴氭湰鍚嶈В鏋愪簨浠跺鐞嗗櫒锛屾墍浠?HandleUpdate / HandleRender / HandleMouse* /
--    HandleTouch* / HandleKey* 蹇呴』淇濇寔**鏂囦欢绾у叏灞€** function锛堜笉鑳藉姞 local锛夛紝
--    鍚﹀垯 SubscribeToEvent("Update", HandleUpdate) 浼氶潤榛樺け鏁堛€?
-- 鈿狅笍 鏈枃浠朵笉鍋氳仈鏈烘潈濞侊細鎴樻枟銆佹帓琛屾銆佸吇鎴愬瓨妗ｉ兘鍦ㄥ鎴风锛坈lientCloud + 鏈湴瀛樻。锛夛紱
--    鏈嶅姟绔彧绠?IAP 鍙戣揣涓庢蔼閲戜唬甯佷綑棰濓紙瑙?network/Server.lua锛夈€?

local Game = require "Game"
local Presentation = require "Presentation"
local RenderBackend = require "Scene3DBackend"
local PlayerData = require "PlayerData"
local AdService = require "AdService"
local MetaCatalog = require "MetaCatalog"
local AircraftPixelData = require "AircraftPixelData"
local StageCatalog = require "StageCatalog"
local TalentCatalog = require "TalentCatalog"
local AchievementCatalog = require "AchievementCatalog"
local GameMode = require "GameMode"
local NetClient = require "network.Client"
local MetaUI = require "MetaUI"
local RechargeShop = require "ui.RechargeShop"
local StageSelect = require "ui.StageSelect"
local ItemShop = require "ui.ItemShop"
local TalentTree = require "ui.TalentTree"
local TestModePrompt = require "ui.TestModePrompt"
local Settings = require "ui.Settings"
local Achievements = require "ui.Achievements"
local AchievementSystem = require "AchievementSystem"
local StageTransition = require "ui.StageTransition"
local Shared = require "network.Shared"
local SysNotif = require "urhox-libs.System.SystemNotification"
local PerformanceProbe = require "PerformanceProbe"

local ClientMain = {}
-- 涓氬姟鎵嬪娍涓庡悗绔瑙変娇鐢ㄥ悓涓€涓绘寚閽堬紱0 鏄悎娉?TouchID銆?
ClientMain._pointer = { source = "", touchId = -1, state = "", epoch = 0, focused = true }
-- 璇锋眰妲借法 Stop/Start 淇濈暀鍒扮湡瀹炵粓鎬侊紝閬垮厤鏃у啓灏氭湭缁撴潫灏卞惎鍔ㄦ柊鍐欍€?
ClientMain._highScore = {
    active = false, lifetime = {}, request = nil, readRequest = nil,
    readReady = false, retained = 0,
}

-- 閽荤煶鍟嗗搧浠锋牸缂撳瓨锛歴ku -> 鍏冿紙鏉ヨ嚜 Shop.getProducts()锛岀绾?鏈紑閫氭椂涓虹┖锛?
---@type table<string, number>
local gemPrices_ = {}
local productsAvailable_ = false

local gameSnapshot = nil
local presentationSnapshot = nil
local lastSavedHighScore = 0
local reviveArmed = false
local doubleArmed = false
local restartArmed = false
local menuArmed = false
-- v0.13.4锛氳儨鍒╃粨绠楅〉鏉炬墜纭锛堥伩鍏嶈瑙︾洿鎺ヨ烦鍏筹級銆?
local stageWinArmed = nil
local metaPointerConsumed = false
-- v0.13.8锛氬ぉ璧嬫爲鎷栨嫿婊氬姩鏄惁宸茶捣鎵嬶紙Move/Up 杞彂缁?TalentTree.Scroll*锛夈€?
local talentScrollArmed = false
-- v0.13.13锛氶€夊叧鐣岄潰锛堟棤闄愮埇濉旓級鎷栨嫿婊氬姩鏄惁宸茶捣鎵嬨€?
local stageSelectScrollArmed = false
-- v0.13.56锛氱 1 鍏炽€屾祴璇曟ā寮忋€嶈闂‘璁ゅ悗锛岃杩涘叆鐨勭洰鏍囧叧鍗″彿銆?
local pendingTestStage_ = nil
-- 璁捐瀹藉害缂撳瓨锛堝ぉ璧嬫爲鍛戒腑/婊氬姩鐢紱Init 鏃剁敱 GetDesignSize 濉級銆?
local designWidth_ = 540
local CLOUD_HIGH_SCORE_KEY = "high_score"
local CLOUD_META_KEY = "player_meta"
local metaCloudSynced = false
local metaRevision = 0
local metaSaveInFlight = false
-- 鏈€楂樺垎浜戝啓鍚堝苟锛氬眬鍐呭彧绱寰呮彁浜ゅ€硷紝灞€鏈?/ 鍥炶彍鍗?/ 鍛ㄦ湡鍏滃簳鎵嶇湡姝ｅ啓涓€娆★紝
-- 閬垮厤銆屾瘡鍑荤涓€鍧楃爾鍒锋柊鏈€楂樺垎灏卞啓涓€娆′簯銆嶏紙浜戝啓閰嶉 300 娆?鍒嗛挓锛夈€?
local highScoreDirty = 0        -- 寰呮彁浜ょ殑鏈€楂樺垎锛? 琛ㄧず鏃犲緟鎻愪氦锛?
local highScoreCommitCooldown = 0  -- 璺濅笅娆″厑璁告彁浜ょ殑绉掓暟锛堝眬鍐呭懆鏈熷厹搴曪級
local HIGH_SCORE_COMMIT_INTERVAL = 15
-- 涓婁竴甯х殑 game.state锛氱敤浜庛€岃繘鍏ョ粨绠?鑿滃崟鎬佹椂鎻愪氦涓€娆°€嶏紙閬垮厤鎸佺画鎬佹瘡甯ф彁浜わ級銆?
---@type string|nil
local prevHighScoreState_ = nil
local RefreshMeta

local function HasClientCloud()
    return clientCloud ~= nil
end

local function RefreshSnapshots()
    gameSnapshot = Game.GetSnapshot()
    presentationSnapshot = Presentation.GetSnapshot()
end

local function GetScreenCoordinates(eventData)
    return eventData:GetInt("X"), eventData:GetInt("Y")
end

local function SaveHighScoreToCloud(score)
    local state = ClientMain._highScore
    local n = math.floor(tonumber(score) or 0)
    if not HasClientCloud() then
        PlayerData.SetHighScore(n)
        lastSavedHighScore = math.max(lastSavedHighScore, PlayerData.GetHighScore())
        highScoreDirty = 0
        return
    end
    if GameMode.IsOffline() or not state.active or state.request
        or state.readRequest or not state.readReady
        or n <= lastSavedHighScore then return end
    local request = { lifetime = state.lifetime, score = n, done = false }
    state.request = request
    Presentation.SetCloudStatus("syncing")
    local function finish(success, reason)
        if request.done then return end
        request.done = true
        if state.request == request then state.request = nil end
        -- 鏃т細璇濈粓鎬佷粎閲婃斁鏃ц姹傛Ы锛屼笉纭鏂颁細璇濆垎鏁般€佷笉姹℃煋鏂扮晫闈€?
        if not state.active or request.lifetime ~= state.lifetime then return end
        if success then
            lastSavedHighScore = math.max(lastSavedHighScore, request.score)
            if highScoreDirty <= lastSavedHighScore then highScoreDirty = 0 end
            Presentation.SetCloudStatus("ok")
            print("[Main] cloud high_score saved=" .. tostring(request.score))
        else
            highScoreDirty = math.max(highScoreDirty, request.score)
            Presentation.SetCloudStatus("unavailable")
            print("[Main] cloud save failed: " .. tostring(reason))
        end
        -- 寮傛鍥炶皟涓嶉€掑綊鍙戣姹傦紱涓嬩竴娆″彈鎺у懆鏈?鐘舵€佽竟娌垮啀鎻愪氦鏇撮珮鍊笺€?
        highScoreCommitCooldown = HIGH_SCORE_COMMIT_INTERVAL
    end
    local okCall, errCall = pcall(function()
        clientCloud:SetInt(CLOUD_HIGH_SCORE_KEY, n, {
            ok = function() finish(true) end,
            error = function(code, reason)
                finish(false, tostring(reason) .. " code=" .. tostring(code))
            end,
            timeout = function() finish(false, "timeout") end,
        })
    end)
    if not okCall and not request.done then
        -- 鎻愪氦鎶涢敊涔熷彲鑳藉凡鏈夎姹傚叆闃燂細淇濈暀璇锋眰妲斤紝涓嶈兘鍑紓甯稿啀鍙戦噸鍙犲啓銆?
        highScoreDirty = math.max(highScoreDirty, n)
        Presentation.SetCloudStatus("unavailable")
        print("[Main] cloud submission uncertain, retain request slot: " .. tostring(errCall))
    end
end

-- 璁板綍銆屽緟鎻愪氦鐨勬渶楂樺垎銆嶏細灞€鍐呮瘡娆″埛鏂板彧鏇存柊鍐呭瓨鍊硷紝涓嶇珛鍒诲啓浜戙€?
local function MarkHighScoreDirty(score)
    local n = math.floor(tonumber(score) or 0)
    if n > highScoreDirty and n > lastSavedHighScore then
        highScoreDirty = n
    end
end

-- 棣栨浜戣鎴愬姛鍓嶇姝㈣鐩栧啓锛涜鍙栧け璐ョ敱鍚屼竴 15 绉掕妭娴佺獥鍙ｉ噸璇汇€?
local function LoadHighScoreFromCloud()
    local state = ClientMain._highScore
    if not HasClientCloud() then
        local localScore = PlayerData.GetHighScore()
        state.readReady = true
        lastSavedHighScore = math.max(lastSavedHighScore, localScore)
        Game.ApplyCloudHighScore(localScore)
        RefreshSnapshots()
        return
    end
    if GameMode.IsOffline() or not state.active then
        Presentation.SetCloudStatus("unavailable")
        return
    end
    -- 璺ㄧ敓鍛藉懆鏈熸棫鍐欐湭缁撴潫鏃跺厛涓嶈锛岄伩鍏嶈鍒?H 鍚庢棫鍐?L 鎵嶈惤鍦般€?
    if state.request or state.readRequest then return end
    local request = { lifetime = state.lifetime, done = false }
    state.readRequest = request
    Presentation.SetCloudStatus("syncing")
    local function finish(success, iscores, reason)
        if request.done then return end
        request.done = true
        if state.readRequest == request then state.readRequest = nil end
        if not state.active or request.lifetime ~= state.lifetime then return end
        highScoreCommitCooldown = HIGH_SCORE_COMMIT_INTERVAL
        if not success then
            state.readReady = false
            Presentation.SetCloudStatus("unavailable")
            print("[Main] cloud high_score read failed; retain local score: " .. tostring(reason))
            return
        end
        local cloudScore = 0
        if iscores and iscores[CLOUD_HIGH_SCORE_KEY] ~= nil then
            cloudScore = math.floor(tonumber(iscores[CLOUD_HIGH_SCORE_KEY]) or 0)
        end
        lastSavedHighScore = math.max(lastSavedHighScore, cloudScore)
        Game.ApplyCloudHighScore(cloudScore)
        state.readReady = true
        Presentation.SetCloudStatus("ok")
        RefreshSnapshots()
        print("[Main] cloud high_score loaded=" .. tostring(cloudScore))
    end
    local okCall, errCall = pcall(function()
        clientCloud:Get(CLOUD_HIGH_SCORE_KEY, {
            ok = function(_, iscores) finish(true, iscores) end,
            error = function(code, reason)
                finish(false, nil, tostring(reason) .. " code=" .. tostring(code))
            end,
            timeout = function() finish(false, nil, "timeout") end,
        })
    end)
    if not okCall and not request.done then
        -- 鎶涢敊涓嶈瘉鏄庤姹傛湭鍏ラ槦锛涗繚鐣欒妲斤紝杩熷埌鐪熷疄缁堟€佷粛鍙敹灏俱€?
        Presentation.SetCloudStatus("unavailable")
        print("[Main] cloud read submission uncertain, retain request slot: " .. tostring(errCall))
    end
end

-- 鎻愪氦寰呭啓鐨勬渶楂樺垎锛堝眬鏈?/ 鍥炶彍鍗?/ 鍛ㄦ湡鍏滃簳璋冪敤锛夈€?
-- 鏃犺鏄惁鐪熸湁寰呮彁浜ゅ€奸兘閲嶇疆鍐峰嵈锛岄伩鍏嶈彍鍗曟€佹瘡甯ч噸璇曪紙閰嶉瓒呴檺鏃跺舰鎴愬啓椋庢毚锛夈€?
local function CommitHighScore()
    highScoreCommitCooldown = HIGH_SCORE_COMMIT_INTERVAL
    local state = ClientMain._highScore
    if GameMode.IsOffline() or not state.active or state.request or state.readRequest then return end
    if not state.readReady then
        LoadHighScoreFromCloud()
        return
    end
    if highScoreDirty <= lastSavedHighScore then
        highScoreDirty = 0
        return
    end
    SaveHighScoreToCloud(highScoreDirty)
end

-- v0.11.0 鍟嗕笟鍖栵細鐜╁鍏冩暟鎹紙闆朵欢/鍥鹃壌/绛惧埌/浠诲姟锛変簯鍚屾銆?
-- 浜戝彉閲忓彧鍦ㄧ紪鎺掑眰璇诲啓锛汸layerData 鍙礋璐ｇ紪瑙ｇ爜銆?
local function SavePlayerDataToCloud()
    if GameMode.IsOffline() or not HasClientCloud() then return end
    metaRevision = metaRevision + 1
    -- 鍒濇浜戞。璇诲彇灏氭湭瀹屾垚鏃朵粎璁拌剰锛涘厛鍐欎細鎶婂彟涓€鍙拌澶囩殑妗ｆ瑕嗙洊鎺夈€?
    if not metaCloudSynced or metaSaveInFlight then return end
    metaSaveInFlight = true
    local revision = metaRevision
    local payload = PlayerData.ExportForCloud()
    local okCall, errCall = pcall(function()
        clientCloud:Set(CLOUD_META_KEY, payload, {
            ok = function()
                metaSaveInFlight = false
                print("[Main] player meta saved to cloud")
                if metaRevision ~= revision and metaCloudSynced then SavePlayerDataToCloud() end
            end,
            error = function(code, reason)
                metaSaveInFlight = false
                print("[Main] meta cloud save failed: " .. tostring(reason) .. " code=" .. tostring(code))
            end,
            timeout = function()
                metaSaveInFlight = false
                print("[Main] meta cloud save timed out; local save retained")
            end,
        })
    end)
    if not okCall then
        metaSaveInFlight = false
        print("[Main] meta cloud save unavailable: " .. tostring(errCall))
    end
end

local function LoadPlayerDataFromCloud()
    if GameMode.IsOffline() or not HasClientCloud() then
        metaCloudSynced = not GameMode.IsOffline()
        print("[Main] offline: skip cloud player data")
        return
    end
    local requestRevision = metaRevision
    pcall(function()
        clientCloud:Get(CLOUD_META_KEY, {
            ok = function(values, _)
                local raw = nil
                if values then raw = values[CLOUD_META_KEY] end
                if type(raw) == "table" then raw = cjson.encode(raw) end
                if type(raw) == "string" and raw ~= "" then
                    local cloudUpdatedAt = 0
                    local decodeOk, cloudData = pcall(cjson.decode, raw)
                    if decodeOk and type(cloudData) == "table" then
                        cloudUpdatedAt = math.floor(tonumber(cloudData.updatedAt) or 0)
                    end
                    local localUpdatedAt = PlayerData.GetUpdatedAt()
                    local merged = cloudUpdatedAt > localUpdatedAt
                        and PlayerData.ImportFromCloud(raw)
                    if merged then
                        PlayerData.Save()
                        RefreshSnapshots()
                        RefreshMeta()
                        print("[Main] newer server save merged")
                    end
                    metaCloudSynced = true
                    if not merged or metaRevision ~= requestRevision then
                        SavePlayerDataToCloud()
                    end
                else
                    -- 浜戠灏氭棤妗ｆ鏃舵妸鏈湴杩涘害涓婁紶锛岄伩鍏嶆崲璁惧鍚庢壘涓嶅埌宸叉湁瀛樻。銆?
                    metaCloudSynced = true
                    SavePlayerDataToCloud()
                end
                if not GameMode.IsOffline() then NetClient.RequestBalance() end
            end,
            error = function(code, reason)
                print("[Main] meta cloud load failed: " .. tostring(reason) .. " code=" .. tostring(code))
            end,
        })
    end)
end

-- 鍙栨秷鑰岄潪妯℃嫙鏉炬墜锛氬け鐒?骞垮憡/妯℃€佷笉鑳借鍙戝皠锛屼篃涓嶈兘淇濈暀鏃ф寜鍘嬨€?
function ClientMain.CancelInput()
    ClientMain._pointer.source = ""
    ClientMain._pointer.touchId = -1
    Game.CancelPointer()
    RenderBackend.ClearPointer()
    if talentScrollArmed then TalentTree.ScrollEnd() end
    if stageSelectScrollArmed then StageSelect.ScrollEnd() end
    talentScrollArmed = false
    stageSelectScrollArmed = false
    metaPointerConsumed = false
    reviveArmed, doubleArmed, restartArmed, menuArmed = false, false, false, false
    stageWinArmed = nil
end

function ClientMain.ValidatePointer()
    if ClientMain._pointer.source == "" then return end
    local snapshot = Game.GetSnapshot()
    if not ClientMain._pointer.focused or AdService.IsInFlight()
        or snapshot.state ~= ClientMain._pointer.state
        or snapshot.pointerEpoch ~= ClientMain._pointer.epoch then
        ClientMain.CancelInput()
    end
end

---@param source string
---@param touchId integer|nil
---@return boolean
function ClientMain.ClaimPointer(source, touchId)
    ClientMain.ValidatePointer()
    if not ClientMain._pointer.focused or AdService.IsInFlight()
        or ClientMain._pointer.source ~= "" then return false end
    local snapshot = Game.GetSnapshot()
    ClientMain._pointer.source = source
    ClientMain._pointer.touchId = touchId or -1
    ClientMain._pointer.state = snapshot.state
    ClientMain._pointer.epoch = snapshot.pointerEpoch
    return true
end

---@param source string
---@param touchId integer|nil
---@return boolean
function ClientMain.OwnsPointer(source, touchId)
    ClientMain.ValidatePointer()
    return ClientMain._pointer.source == source
        and (source == "mouse" or ClientMain._pointer.touchId == touchId)
end

-- v0.11.0 鍟嗕笟鍖栵細鎵€鏈夋縺鍔辫棰戠粺涓€璧?AdService锛屼繚璇佷竴娆℃€у畬鎴愪笌闃查噸澶嶅彂濂栥€?
---@param onReward fun()
local function ShowAd(onReward)
    local function fail(msg)
        Presentation.SetAdStatus(nil)
        Presentation.SetAdToast(msg)
        RefreshSnapshots()
    end
    ClientMain.CancelInput()
    Presentation.SetAdStatus("loading")
    AdService.Show({
        onReward = function()
            Presentation.SetAdStatus(nil)
            Presentation.SetAdToast(nil)
            onReward()
            RefreshSnapshots()
        end,
        onFail = fail,
        onBusy = fail,
    })
end

local function ShowReviveAd()
    if not Game.CanRevive() then
        Presentation.SetAdToast("鏈眬宸插娲?)
        return
    end
    ShowAd(function()
        if not Game.ReviveFromAd() then
            Presentation.SetAdToast("澶嶆椿鏈兘鐢熸晥")
        end
    end)
end

local function ShowDoublePartsAd()
    ShowAd(function()
        local extra = Game.DoubleSettlement()
        if extra > 0 then
            PlayerData.AddParts(extra)
            PlayerData.Save()
            SavePlayerDataToCloud()
            Presentation.SetAdToast(string.format("鍙屽€嶅埌璐?+%d 闆朵欢", extra))
        end
    end)
end

-- ============================================================================
-- v0.11.0 鍟嗕笟鍖栵細鍏冨眰鐣岄潰锛堜富鑿滃崟鍟嗕笟鍖?/ 姣忔棩绛惧埌涓庤ˉ缁?/ 浠诲姟 / 鍥鹃壌 / 鎺掕 / 鍟嗗煄 / 杞洏锛?
-- 鎵€鏈夌姸鎬佸彉鏇撮泦涓湪姝わ紝MetaUI 鍙礋璐ｇ敾銆?
-- ============================================================================

local META_TOAST_SECONDS = 2.4
local metaToastTimer = 0
local metaDate = ""
local aircraftSilhouettes = {}
for _, entry in ipairs(MetaCatalog.GetCodex()) do
    local model = AircraftPixelData[entry.key]
    if model then
        local rows = {}
        for col, row in model.data:gmatch("(%d+),(%d+),%d+,%d+,%d+;") do
            rows[#rows + 1] = { col = tonumber(col), row = tonumber(row) }
        end
        aircraftSilhouettes[entry.key] = { rows = rows, gridW = model.gridW, gridH = model.gridH }
    end
end

---@type MetaState
local metaState = {
    parts = 0,
    gems = 0,
    highScore = 0,
    screen = nil,
    stageSelectLoading = false,
    stageSelectLoadingTimer = 0,
    -- 閫夊叧鐣岄潰锛坴0.13.4锛夛細鏄熺骇 + 宸茶В閿佽寖鍥?+ 鍏冲崱鎬绘暟锛屼緵 StageSelect 鍙娓叉煋銆?
    stageStars = {},
    maxStage = 1,
    stageTotal = 0,
    supplyOpen = false,
    supplyAvailable = false,
    supplyReward = 0,
    signInAvailable = false,
    signInStreak = 0,
    signInReward = 0,
    taskClaimable = false,
    tasks = {},
    codex = {},
    codexUnlocked = 0,
    codexTotal = 0,
    codexClaimable = false,
    -- 鎴愬氨闈㈡澘锛坴0.13.62锛夛細鍒楄〃 + 宸茶В閿佹暟 + 缈婚〉涓嬫爣銆?
    achievements = {},
    achUnlocked = 0,
    achTotal = 0,
    achPage = 1,
    -- v0.14.0锛氭垬鏂楁。妗堝睆鍐呯殑椤电锛?pass" 妗ｆ / "ach" 鎴愬氨锛夈€?
    passTab = "pass",
    rankList = {},
    rankLoading = false,
    rankTotal = 0,
    myRank = nil,
    myRankLoading = false,
    premiumPass = false,
    premiumPassCost = (Shared.GetGemSpend("pass_premium") or {}).cost or 100,
    firstGiftAvailable = false,
    firstGiftSeconds = 0,
    firstGiftPrice = nil,
    skins = {},
    selectedSkin = "default",
    trails = {},
    selectedTrail = "classic",
    giftUsed = {},
    wheelReady = false,
    wheelPrize = 0,
    -- 璁剧疆椤靛紑鍏筹紙v0.13.60锛夛細闊充箰 / 闊虫晥锛屼緵璁剧疆灞忓彧璇绘覆鏌撱€?
    musicEnabled = true,
    sfxEnabled = true,
    toast = nil,
    -- 鑱旀満 / 姘噾浠ｅ竵
    offline = false,
    productsAvailable = false,
    prices = {},
    rechargeToast = nil,
}

-- v0.12.5锛氬钩鍙扮郴缁熼€氱煡鎹㈢毊锛坉ark-tech 椤堕儴閫氱煡鏉★級锛屼笉鍐嶅厑璁搁粯璁ょ櫧搴曞脊绐楃洿鍑恒€?
-- 鈿狅笍 鍏ㄥ眬鍙湁涓€涓?handler 妲斤紱澶у巺/娓告垙鏄袱涓?Runtime锛屽垏鎹㈠悗鍚勮嚜娉ㄥ唽銆?
local function installSystemNotificationHandler()
    pcall(function()
        SysNotif.RegisterHandler(function(info)
            local ok, view = pcall(function() return SysNotif.Resolve(info) end)
            if not ok or type(view) ~= "table" then return false end
            if info.id == SysNotif.Id.DisconnectChecking
                or info.id == SysNotif.Id.Reconnecting
                or info.id == SysNotif.Id.ConnectFailedRetry
                or info.id == SysNotif.Id.ConnectInitiateFailed then
                print("[Main] silent network retry: " .. tostring(info.id))
                return true
            end
            local tone = view.kind == "error" and "error" or "warn"
            local message = view.message or ""
            if view.reason and view.reason ~= "" then
                message = message .. " 鍘熷洜锛? .. view.reason
            end
            RenderBackend.ShowSystemBanner({
                title = view.title or "杩炴帴鎻愮ず",
                message = message,
                tone = tone,
                ttl = 15,
                -- 杩炴帴妫€鏌?閲嶈繛绫伙紙error锛夊彧鎻愮ず涓嶅姖閫€锛涜韪?寮圭獥绫荤粰閫€鍑哄嚭鍙ｃ€?
                actionText = view.kind == "error" and nil or "閫€鍑?,
                actionId = "banner_exit",
            })
            print("[Main] system notification banner: " .. tostring(view.id)
                .. " kind=" .. tostring(view.kind))
            return true
        end)
    end)
end

-- v0.12.7锛氬垹闄ゃ€屼富鑿滃崟鑷姩寮逛粯璐硅建閫氱煡鏉?+ 鑷姩寮规瘡鏃ヨˉ缁欍€嶄袱澶勫惎鍔ㄦ墦鎵?
-- 锛堢敤鎴峰惁鍐筹細寮€灞€棣栧厖寮圭獥锛夈€備粯璐硅建瑙ｉ攣鍏ュ彛鏀跺洖鎴樻枟妗ｆ闈㈡澘涓庨捇鐭冲厬鎹紝
-- 鐜╁涓诲姩鎵撳紑鎵嶈锛涘悗绔?SystemBanner 閫氶亾淇濈暀锛屼粎渚涘钩鍙?SystemNotification 鎹㈢毊鐢ㄣ€?

-- 椤剁閫氱煡鏉″姩浣滃鐞嗭細鐪熸鐨勫嚱鏁颁綋鍦?HandleMetaAction 瀹氫箟鍚庤祴鍊硷紙鍚屾枃浠?local
-- 鍓嶅悜寮曠敤闂锛歶pvalue 鍚屼竴鍙橀噺锛岃繍琛屾椂鎵嶅彇鍑芥暟浣擄紝TryBannerAt 闂寘寮曠敤涓嶅彈褰卞搷锛夈€?
local onBannerAction = nil

-- 鎷変竴娆￠捇鐭冲晢鍝佸垪琛紙浠锋牸鏉ヨ嚜骞冲彴锛岀绾?鏈紑閫氭椂涓虹┖锛夈€?
local function RefreshGemProducts()
    if GameMode.IsOffline() then
        gemPrices_ = {}
        productsAvailable_ = false
    else
        local products = NetClient.GetProducts()
        local prices = {}
        if products then
            for i = 1, #products do
                local item = products[i]
                if item.sku_id and item.price then
                    prices[item.sku_id] = item.price
                end
            end
            productsAvailable_ = true
        else
            productsAvailable_ = false
        end
        gemPrices_ = prices
    end
    metaState.productsAvailable = productsAvailable_
    metaState.prices = gemPrices_
    print("[Main] gem products available=" .. tostring(productsAvailable_))
end

local function SetMetaToast(msg)
    metaState.toast = msg
    metaToastTimer = META_TOAST_SECONDS
end

RefreshMeta = function()
    local tasks = {}
    local anyClaimable = false
    for _, def in ipairs(PlayerData.GetDailyTasks()) do
        local raw = PlayerData.GetDailyProgress(def.id)
        local claimable = PlayerData.CanClaimDaily(def.id)
        if claimable then anyClaimable = true end
        tasks[#tasks + 1] = {
            id = def.id,
            name = def.name,
            target = def.target,
            progress = math.min(math.floor(raw), def.target),
            reward = def.reward,
            claimed = PlayerData.IsDailyClaimed(def.id),
            claimable = claimable,
        }
    end
    metaState.tasks = tasks
    metaState.taskClaimable = anyClaimable
    metaState.parts = PlayerData.GetParts()
    metaState.highScore = PlayerData.GetHighScore()
    metaState.signInAvailable = PlayerData.CanSignIn()
    local reward, streak = PlayerData.GetSignInPreview()
    metaState.signInReward = reward
    metaState.signInStreak = streak
    metaState.supplyAvailable = PlayerData.GetDailyCount("supply") == 0
    metaState.supplyReward = MetaCatalog.GetDailySupplyBase()

    local codexMap = {}
    for _, entry in ipairs(MetaCatalog.GetCodex()) do
        if PlayerData.IsCodexUnlocked(entry.key) then codexMap[entry.key] = true end
    end
    metaState.codex = codexMap
    metaState.aircraft = aircraftSilhouettes
    metaState.codexUnlocked = PlayerData.CodexCount()
    metaState.codexTotal = MetaCatalog.GetCodexTotal()

    -- v0.13.62锛氭垚灏遍潰鏉挎暟鎹紙鏈湴鏉冨▉锛夆€斺€斿垪琛?+ 宸茶В閿佹暟锛屼緵 Achievements 闈㈡澘鍙娓叉煋銆?
    local achList = {}
    local achUnlockedCount = 0
    for _, def in ipairs(AchievementCatalog.GetAll()) do
        local unlocked = PlayerData.IsAchievementUnlocked(def.id)
        if unlocked then achUnlockedCount = achUnlockedCount + 1 end
        achList[#achList + 1] = {
            id = def.id, title = def.title, desc = def.desc, steps = def.steps,
            icon = def.icon, tone = def.tone,
            progress = PlayerData.GetAchievementProgress(def.id),
            unlocked = unlocked,
        }
    end
    metaState.achievements = achList
    metaState.achUnlocked = achUnlockedCount
    metaState.achTotal = #achList

    -- 閫夊叧鐣岄潰鏁版嵁锛坴0.13.4锛夛細閫愬叧鏄熺骇 + 宸茶В閿佽寖鍥淬€?
    -- v0.13.13锛氬叧鍗℃棤闄愨€斺€斿彧缁熻鍒般€屾渶楂樺凡瑙ｉ攣鍏炽€嶏紝鍒楄〃闅忚繘搴﹀闀裤€?
    local maxStage = PlayerData.GetMaxStage()
    local stageStars = {}
    for stage = 1, maxStage do
        stageStars[stage] = PlayerData.GetStageStars(stage)
    end
    metaState.stageStars = stageStars
    metaState.maxStage = maxStage
    metaState.stageTotal = StageCatalog.STAGE_SOFT_CAP
    -- 閫夊叧鐣岄潰銆屽眬鍐呴亾鍏枫€嶈喘涔版潯锛氬簱瀛?/ 鍗曚环 / 鏈眬姣忔牱闄愮敤涓€娆°€?
    metaState.itemStock = PlayerData.GetItemStock()
    metaState.itemPrices = ItemShop.PRICES
    -- 璁剧疆椤靛紑鍏筹紙v0.13.60锛夛細闊充箰 / 闊虫晥锛屼緵璁剧疆灞忓彧璇绘覆鏌撱€?
    metaState.musicEnabled = PlayerData.IsMusicEnabled()
    metaState.sfxEnabled = PlayerData.IsSfxEnabled()

    -- 澶╄祴鏍戠晫闈㈡暟鎹紙v0.13.5锛夛細宸茶В閿佽妭鐐?+ 鏄熺骇姹囨€汇€?
    metaState.talents = PlayerData.GetTalents()
    metaState.totalStars = PlayerData.GetTotalStars()
    metaState.talentCount = PlayerData.TalentCount()
    metaState.talentTotal = #TalentCatalog.GetNodes()
    -- v0.13.56锛氱 1 鍏炽€屾祴璇曟ā寮忋€嶈闂槸鍚﹀緟鍐筹紙娓叉煋灞傛嵁姝ょ敾鎻愮ず锛夈€?
    metaState.testMode = (pendingTestStage_ ~= nil)
    metaState.talentMaxStage = TalentCatalog.MAX_STAGE
    metaState.talentStageCount = TalentCatalog.GetUnlockedStageCount(metaState.totalStars)
    -- 鏄惁鏈夈€屽綋鍓嶅彲璐熸媴涓斿墠缃弧瓒炽€嶇殑鑺傜偣锛堣彍鍗曠孩鐐癸級銆?
    do
        local owned = metaState.talents
        local parts = metaState.parts
        local stars = metaState.totalStars
        local affordable = false
        for _, node in ipairs(TalentCatalog.GetNodes()) do
            if not owned[node.id] and TalentCatalog.IsPrereqMet(node, owned, stars)
                and parts >= node.cost then
                affordable = true
                break
            end
        end
        metaState.talentAffordable = affordable
    end

    local skins = {}
    for _, skin in ipairs(MetaCatalog.GetSkins()) do
        if PlayerData.HasSkin(skin.key) then skins[skin.key] = true end
    end
    metaState.skins = skins
    metaState.selectedSkin = PlayerData.GetSelectedSkin()

    local trails = {}
    for _, trail in ipairs(MetaCatalog.GetTrails()) do
        if PlayerData.HasTrail(trail.key) then trails[trail.key] = true end
    end
    metaState.trails = trails
    metaState.selectedTrail = PlayerData.GetSelectedTrail()

    local giftUsed = {}
    for _, entry in ipairs(MetaCatalog.GetShopEntries()) do
        giftUsed[entry.key] = PlayerData.GetDailyCount("gift_" .. entry.key)
    end
    metaState.giftUsed = giftUsed
    metaState.wheelReady = PlayerData.GetDailyCount("wheel") == 0
    metaState.passLevel = PlayerData.GetPassLevel()
    metaState.passProgress, metaState.passTarget = PlayerData.GetPassProgress()
    local rewards = {}
    local claimed = PlayerData.GetPassClaimed()
    metaState.premiumPass = (not GameMode.IsOffline()) and NetClient.GetPremiumPass() or false
    -- 棣栧厖绀煎寘锛氶檺鏃剁獥鍐呬笖鏈喘涔帮紙鏈嶅姟绔潈濞佸凡璐爣蹇?+ 鏈湴宸茶ˉ鍙戞爣蹇楅兘涓嶅啀灞曠ず锛夈€?
    local giftOpen = (not PlayerData.IsFirstGiftClaimed())
        and (not GameMode.IsOffline()) and (not NetClient.GetFirstGiftBought())
    metaState.firstGiftAvailable = giftOpen
        and PlayerData.GetFirstGiftWindow(Shared.FIRST_GIFT.windowSeconds) > 0
    metaState.firstGiftSeconds = metaState.firstGiftAvailable
        and PlayerData.GetFirstGiftWindow(Shared.FIRST_GIFT.windowSeconds) or 0
    metaState.firstGiftPrice = productsAvailable_ and (gemPrices_[Shared.FIRST_GIFT.sku] or nil) or nil
    local passMul = metaState.premiumPass and 2 or 1
    for level = math.max(1, claimed), math.min(6, math.max(claimed + 3, metaState.passLevel)) do
        rewards[#rewards + 1] = {
            level = level,
            reward = (100 + level * 100) * passMul,
            baseReward = 100 + level * 100,
            unlocked = level <= metaState.passLevel,
            claimed = level <= claimed,
            claimable = level == claimed + 1 and level <= metaState.passLevel,
        }
        if #rewards >= 4 then break end
    end
    metaState.passRewards = rewards
    metaState.passClaimable = metaState.passLevel > claimed
    -- v0.14.x 瀛橀挶缃愶細妗ｆ棰嗘弧 6 绾у悗鍒囨崲鍒般€屽瓨閽辩綈寮忋€嶃€?
    metaState.piggyMode = PlayerData.IsPiggyMode()
    metaState.piggyGear = PlayerData.GetGear()
    metaState.offline = GameMode.IsOffline()
    metaState.gems = GameMode.IsOffline() and metaState.gems or NetClient.GetGems()
end

-- 闆朵欢鍏ヨ处缁熶竴鍑哄彛锛氬啓鍏?+ 瀛樻。 + 浜戝悓姝?+ 鍒锋柊鐣岄潰銆?
---@param amount integer
---@param label string|nil
local function GrantParts(amount, label)
    if amount <= 0 then return end
    PlayerData.AddParts(amount)
    PlayerData.Save()
    SavePlayerDataToCloud()
    RefreshMeta()
    if label then
        SetMetaToast(string.format("%s +%d 闆朵欢", label, amount))
    end
end

local function PersistMeta()
    PlayerData.Save()
    SavePlayerDataToCloud()
    RefreshMeta()
end

-- 鍏ㄦ湇鎺掕姒滐細GetRankList 鍙繑鍥?userId锛屾樀绉拌鍐嶆煡涓€娆?GetUserNickname銆?
local function FetchRankList()
    if GameMode.IsOffline() then
        metaState.rankLoading = false
        metaState.myRankLoading = false
        metaState.myRank = nil
        metaState.rankList = {}
        SetMetaToast("鑱旂綉鍚庡彲鐢ㄦ帓琛屾")
        return
    end
    metaState.rankLoading = true
    metaState.rankList = {}
    metaState.myRank = nil
    metaState.myRankLoading = true
    local okRankCall, rankErr = pcall(function()
        clientCloud:GetUserRank(clientCloud.userId, CLOUD_HIGH_SCORE_KEY, {
            ok = function(rank)
                metaState.myRank = rank and math.floor(rank) or nil
                metaState.myRankLoading = false
            end,
            error = function(code, reason)
                metaState.myRankLoading = false
                print("[Main] own rank failed: " .. tostring(reason) .. " code=" .. tostring(code))
            end,
        })
    end)
    if not okRankCall then
        metaState.myRankLoading = false
        print("[Main] own rank unavailable: " .. tostring(rankErr))
    end
    local okListCall, listErr = pcall(function()
        clientCloud:GetRankList(CLOUD_HIGH_SCORE_KEY, 0, 10, {
            ok = function(rankList)
                local list = {}
                local myId = tostring(clientCloud.userId)
                local items = rankList or {}
                for i = 1, #items do
                    local item = items[i]
                    local iscore = item.iscore
                    local value = 0
                    if iscore then value = iscore[CLOUD_HIGH_SCORE_KEY] or 0 end
                    list[#list + 1] = {
                        rank = i,
                        name = "鐜╁",
                        score = math.floor(value),
                        userId = item.userId,
                        isMe = tostring(item.userId) == myId,
                    }
                end
                metaState.rankList = list
                metaState.rankLoading = false
                local ids = {}
                for _, row in ipairs(list) do ids[#ids + 1] = row.userId end
                if #ids > 0 then
                    GetUserNickname({
                        userIds = ids,
                        onSuccess = function(nicknames)
                            local infos = nicknames or {}
                            for i = 1, #infos do
                                local info = infos[i]
                                local name = info.nickname
                                if type(name) == "string" and name ~= "" then
                                    for _, row in ipairs(metaState.rankList) do
                                        if tostring(row.userId) == tostring(info.userId) then
                                            row.name = name
                                        end
                                    end
                                end
                            end
                        end,
                    })
                end
            end,
            error = function(code, reason)
                metaState.rankLoading = false
                metaState.rankList = {}
                SetMetaToast("鎺掕姒滄殏涓嶅彲鐢?)
                print("[Main] rank list failed: " .. tostring(reason) .. " code=" .. tostring(code))
            end,
        })
    end)
    if not okListCall then
        metaState.rankLoading = false
        print("[Main] rank list unavailable: " .. tostring(listErr))
    end
    local okTotalCall, totalErr = pcall(function()
        clientCloud:GetRankTotal(CLOUD_HIGH_SCORE_KEY, {
            ok = function(total)
                metaState.rankTotal = math.floor(total or 0)
            end,
        })
    end)
    if not okTotalCall then
        print("[Main] rank total unavailable: " .. tostring(totalErr))
    end
end

local function OpenMetaScreen(name)
    metaState.screen = name
    if name == "stage_select" then
        metaState.stageSelectLoading = true
        metaState.stageSelectLoadingTimer = 1.35
    else
        metaState.stageSelectLoading = false
        metaState.stageSelectLoadingTimer = 0
    end
    if name == "rank" then FetchRankList() end
    RefreshMeta()
    -- v0.13.13锛氶€夊叧鐣岄潰鏄棤闄愮埇濉斺€斺€旀墦寮€鏃堕粯璁ゅ畾浣嶅湪銆屾渶鏂帮紙鏈€楂樺凡瑙ｉ攣锛夊叧銆嶃€?
    if name == "stage_select" then
        StageSelect.FocusLatest(designWidth_, metaState.maxStage or 1)
    end
end

local function HandleSignIn()
    if not PlayerData.CanSignIn() then
        SetMetaToast("浠婃棩宸茬鍒?)
        return
    end
    local reward = PlayerData.SignIn()
    if reward > 0 then
        PersistMeta()
        SetMetaToast(string.format("绛惧埌鎴愬姛 +%d 闆朵欢", reward))
    end
end

---@param mode string "claim" | "double"
local function HandleSupply(mode)
    if not metaState.supplyAvailable then
        metaState.supplyOpen = false
        SetMetaToast("浠婃棩琛ョ粰宸查鍙?)
        return
    end
    if mode == "double" then
        ShowAd(function()
            PlayerData.AddDailyCount("supply", 1)
            metaState.supplyOpen = false
            GrantParts(metaState.supplyReward * 2, "姣忔棩琛ョ粰 鍙屽€?)
        end)
        return
    end
    PlayerData.AddDailyCount("supply", 1)
    metaState.supplyOpen = false
    GrantParts(metaState.supplyReward, "姣忔棩琛ョ粰")
end

---@param index integer
local function HandleClaimTask(index)
    local view = metaState.tasks[index]
    if not view then return end
    local reward = PlayerData.ClaimDaily(view.id)
    if reward > 0 then
        PersistMeta()
        SetMetaToast(string.format("浠诲姟瀹屾垚 +%d 闆朵欢", reward))
    end
end

---@param index integer
local function HandleShopSkin(index)
    local skins = MetaCatalog.GetSkins()
    local skin = skins[index]
    if not skin then return end
    if PlayerData.HasSkin(skin.key) then
        PlayerData.SelectSkin(skin.key)
        PersistMeta()
        SetMetaToast("宸插垏鎹负 " .. skin.name)
        return
    end
    if not PlayerData.PurchaseSkin(skin.key, skin.cost) then
        SetMetaToast("闆朵欢涓嶈冻锛岃繕宸?" .. tostring(math.max(0, skin.cost - PlayerData.GetParts())))
        return
    end
    PersistMeta()
    SetMetaToast("宸茶喘涔?" .. skin.name)
end

---@param index integer
local function HandleShopTrail(index)
    local trails = MetaCatalog.GetTrails()
    local trail = trails[index]
    if not trail then return end
    if PlayerData.HasTrail(trail.key) then
        PlayerData.SelectTrail(trail.key)
        PersistMeta()
        SetMetaToast("宸插垏鎹负 " .. trail.name)
        return
    end
    if not PlayerData.PurchaseTrail(trail.key, trail.cost) then
        SetMetaToast("闆朵欢涓嶈冻锛岃繕宸?" .. tostring(math.max(0, trail.cost - PlayerData.GetParts())))
        return
    end
    PersistMeta()
    SetMetaToast("宸茶喘涔?" .. trail.name)
end

---@param index integer
local function HandleAdGift(index)
    local gifts = MetaCatalog.GetShopEntries()
    local gift = gifts[index]
    if not gift then return end
    local key = "gift_" .. gift.key
    local limit = MetaCatalog.GetAdGiftDailyLimit(gift.key)
    if PlayerData.GetDailyCount(key) >= limit then
        SetMetaToast("浠婃棩宸查鍙?)
        return
    end
    ShowAd(function()
        PlayerData.AddDailyCount(key, 1)
        GrantParts(MetaCatalog.GetAdGiftReward(gift.key), gift.name)
    end)
end

local function HandleWheelSpin()
    if not metaState.wheelReady then
        SetMetaToast("浠婃棩宸叉娊鍙?)
        return
    end
    ShowAd(function()
        PlayerData.AddDailyCount("wheel", 1)
        local prize = MetaCatalog.RollWheelPrize()
        metaState.wheelPrize = prize
        GrantParts(prize, "杞洏濂栧姳")
    end)
end

-- 閽荤煶鍏戞崲锛氭湇鍔＄浜嬪姟鍘熷瓙鎵ｉ捇骞惰褰曠疮璁￠浂浠讹紱瀹㈡埛绔寜鏉冨▉绱棰濊ˉ棰嗐€?
---@param index integer
local function HandleGemSpend(index)
    local def = Shared.GEM_SPENDS[index]
    if not def then return end
    if GameMode.IsOffline() then
        metaState.rechargeToast = "闇€鑱旂綉鍚庡彲鐢?
        return
    end
    -- 涓嬩竴娆℃垚鍔熺殑浣欓璇锋眰浼氭帹閫佹潈濞佺疮璁￠骞惰ˉ棰嗭紱姣忔杩涘晢搴椾篃浼氶噸鏂版媺鍙栥€?
    metaState.rechargeToast = "鎵ｆ涓€?
    NetClient.SpendGems(def.key, function(ok, reason)
        if ok then
            -- 绛夊緟鏈嶅姟绔悓姝ョ疮璁￠鍐嶈ˉ棰嗭紝涓嶄粠鍗曟鎴愬姛鍥炶皟鐩存帴鍏ヨ处銆?
            NetClient.RequestBalance()
            metaState.rechargeToast = "鍏戞崲鎴愬姛锛岄浂浠跺悓姝ヤ腑鈥?
        elseif reason == "pending" then
            metaState.rechargeToast = "涓婁竴绗斿厬鎹㈠皻鏈‘璁わ紝璇峰嬁閲嶅鐐瑰嚮"
        elseif reason == "unknown" then
            metaState.rechargeToast = "缁撴灉寰呯‘璁わ紝璇烽噸鏂拌繘鍏ユ父鎴忓璐︼紝鍕块噸澶嶅厬鎹?
        elseif reason == "insufficient" then
            metaState.rechargeToast = "閽荤煶涓嶈冻"
        else
            metaState.rechargeToast = "鎵ｆ澶辫触锛岃閲嶈瘯"
        end
        RefreshMeta()
    end)
end

---@param index integer
local function HandleGemPurchase(index)
    local pack = Shared.GEM_PACKS[index]
    if not pack then return end
    if GameMode.IsOffline() then
        metaState.rechargeToast = "闇€鑱旂綉鍚庡彲鐢?
        return
    end
    if not productsAvailable_ then
        metaState.rechargeToast = "鍐呰喘鏈紑閫氭垨鏆傛棤鍟嗗搧"
        return
    end
    metaState.rechargeToast = "姝ｅ湪鎷夎捣鏀粯鈥?
    NetClient.Purchase(pack.sku, function(ok, reason)
        if ok then
            -- 鍙槸寮圭獥宸叉媺璧凤紱鍙戣揣鐢辨湇鍔＄寮傛瀹屾垚锛屽埌璐﹀悗浼氭帹浣欓銆?
            metaState.rechargeToast = "鏀粯瀹屾垚鍚庨捇鐭宠嚜鍔ㄥ埌璐?
        else
            metaState.rechargeToast = "璐拱澶辫触锛? .. tostring(reason)
        end
        RefreshMeta()
    end)
end

---@param action string|nil
---@param index integer|nil
---@return boolean handled
local function HandleRechargeAction(action, index)
    if action == "open_recharge" then
        OpenMetaScreen("recharge")
        RefreshGemProducts()
        NetClient.RequestBalance()
        return true
    elseif action == "buy" and index then
        HandleGemPurchase(index)
        return true
    elseif action == "buy_first_gift" then
        if GameMode.IsOffline() then
            metaState.rechargeToast = "闇€鑱旂綉鍚庡彲鐢?
        elseif not productsAvailable_ then
            metaState.rechargeToast = "鍐呰喘鏈紑閫氭垨鏆傛棤鍟嗗搧"
        else
            metaState.rechargeToast = "姝ｅ湪鎷夎捣鏀粯鈥?
            NetClient.Purchase(Shared.FIRST_GIFT.sku, function(ok, reason)
                if ok then
                    -- 鍙戣揣鐢辨湇鍔＄寮傛瀹屾垚锛涢捇鐭?绀煎寘鏍囧織鍒拌处鍚庢帹閫佸埛鏂板睍绀恒€?
                    metaState.rechargeToast = "鏀粯瀹屾垚鍚庣ぜ鍖呰嚜鍔ㄥ埌璐?
                else
                    metaState.rechargeToast = "璐拱澶辫触锛? .. tostring(reason)
                end
                RefreshMeta()
            end)
        end
        return true
    elseif action == "spend" and index then
        HandleGemSpend(index)
        return true
    elseif action == "retry" then
        NetClient.RequestBalance()
        RefreshGemProducts()
        metaState.rechargeToast = GameMode.IsOffline() and "浠嶅浜庣绾挎ā寮? or "宸插埛鏂?
        return true
    end
    return false
end

local function HandleMetaAction(action, index)
    if HandleRechargeAction(action, index) then return end
    -- 鍏冨眰浜や簰闊虫晥锛氳喘涔?瑙ｉ攣/棰嗗彇绫荤粰纭闊筹紝鍏朵綑缁欒交鐐瑰嚮闊炽€?
    if action == "buy" or action == "spend" or action == "buy_first_gift"
        or action == "unlock_talent" or action == "signin" or action == "claim"
        or action == "buy_premium_pass" then
        RenderBackend.PlayUiSfx("confirm")
    else
        RenderBackend.PlayUiSfx("click")
    end
    if action == "close" then
        metaState.screen = nil
        RefreshMeta()
    elseif action == "open_stage_select" then
        OpenMetaScreen("stage_select")
    elseif action == "open_talent" then
        TalentTree.SetSelected(nil)
        OpenMetaScreen("talent")
    elseif action == "select_talent" then
        -- 鐐瑰渾褰㈠崱锛歍alentTree 鍐呴儴宸茶褰曢€変腑骞跺脊娴獥锛岃繖閲屽彧闇€閲嶇粯锛堟棤鍓綔鐢級銆?
        RefreshMeta()
    elseif action == "unlock_talent" and index then
        -- 澶╄祴鏍戣妭鐐硅В閿侊細TalentCatalog 鏍￠獙鍓嶇疆/鏄熺骇/闆朵欢锛孭layerData 钀界洏銆?
        local nodeId = index
        local node = TalentCatalog.GetNode(nodeId)
        if node then
            local owned = PlayerData.GetTalents()
            local ok, reason = TalentCatalog.CanUnlock(nodeId, owned,
                PlayerData.GetTotalStars(), PlayerData.GetParts())
            if ok then
                if PlayerData.UnlockTalent(nodeId, node.cost) then
                    PlayerData.Save()
                    SavePlayerDataToCloud()
                    SetMetaToast(string.format("宸茶В閿併€?s銆?, node.name))
                    print("[Main] talent unlocked: " .. nodeId)
                end
            else
                local msg = (reason == "stars" and "鏄熺骇涓嶈冻锛屽皻鏈紑鏀捐闃舵")
                    or (reason == "prereq" and "闇€鍏堣В閿佸悓涓€绾胯矾鐨勪笂涓€闃舵")
                    or (reason == "parts" and "闆朵欢涓嶈冻")
                    or (reason == "owned" and "宸茶В閿?)
                    or "鏃犳硶瑙ｉ攣"
                SetMetaToast(msg)
            end
            RefreshMeta()
        end
    elseif action == "play_stage" and index then
        -- 閫夊叧鐣岄潰鐐规煇鍏筹細瑙ｉ攣鏍￠獙锛圫tageSelect 鍛戒腑宸茶繃婊わ紝杩欓噷鍏滃簳锛夛紝鍏抽潰鏉垮悗寮€璇ュ叧銆?
        if PlayerData.IsStageUnlocked(index) then
            if index == 1 then
                -- v0.13.56锛氳繘鍏ョ 1 鍏冲墠鍏堣闂槸鍚︽祴璇曞悗鏈熷叧鍗★紙姣忔閮介棶锛夈€?
                OpenMetaScreen("test_mode")
                print("[Main] stage 1 -> ask test mode")
            else
                metaState.screen = nil
                Game.StartStageAt(index)
                RefreshSnapshots()
                print("[Main] start stage from select: " .. tostring(index))
            end
        end
    elseif action == "test_mode_yes" then
        -- v0.13.56锛氭祴璇曟ā寮忊€斺€旇В閿佸叏閮ㄥぉ璧嬫爲鑺傜偣锛岀洿鍏ュ悗鏈熷叧鍗★紙榛樿绗?20 鍏冲己搴︼級銆?
        local ids = {}
        for _, node in ipairs(TalentCatalog.GetNodes()) do ids[#ids + 1] = node.id end
        PlayerData.EnsureAutoOwnedTalents(ids)
        metaState.talents = PlayerData.GetTalents()
        PersistMeta()
        pendingTestStage_ = TestModePrompt.TARGET_STAGE
        print(string.format("[Main] test mode ON: unlocked %d talent nodes -> stage %d",
            #ids, pendingTestStage_))
        RefreshMeta()
    elseif action == "test_mode_no" then
        -- v0.13.56锛氭甯稿紑濮嬧€斺€斾粠绗?1 鍏宠捣姝ワ紝涓嶅姩澶╄祴鏍戙€?
        pendingTestStage_ = 1
        RefreshMeta()
        print("[Main] test mode OFF: start stage 1")
    elseif action == "test_mode_close" then
        -- 璇㈤棶灞忓彧鑳介€氳繃銆屾槸/鍚︺€嶇寮€锛沜lose 鐢?ESC 瑙﹀彂鏃惰涓恒€屽惁銆嶃€?
        metaState.screen = nil
        pendingTestStage_ = 1
        RefreshMeta()
    elseif action == "open_settings" then
        -- v0.13.59锛氫富鑿滃崟宸︿笂瑙掗娇杞?鈫?璁剧疆灞忋€?
        OpenMetaScreen("settings")
    elseif action == "toggle_music" then
        -- v0.13.60锛氶煶涔愬紑鍏斥€斺€斿啓瀛樻。 + 绔嬪嵆浣滅敤鍒伴煶棰戞€绘帶 + 鍒锋柊蹇収銆?
        local on = not PlayerData.IsMusicEnabled()
        PlayerData.SetMusicEnabled(on)
        RenderBackend.SetMusicEnabled(on)
        SavePlayerDataToCloud()
        SetMetaToast(on and "闊充箰宸插紑鍚? or "闊充箰宸插叧闂?)
        RefreshMeta()
    elseif action == "toggle_sfx" then
        -- v0.13.60锛氶煶鏁堝紑鍏斥€斺€斿啓瀛樻。 + 绔嬪嵆浣滅敤鍒伴煶棰戞€绘帶 + 鍒锋柊蹇収銆?
        local on = not PlayerData.IsSfxEnabled()
        PlayerData.SetSfxEnabled(on)
        RenderBackend.SetSfxEnabled(on)
        SavePlayerDataToCloud()
        SetMetaToast(on and "闊虫晥宸插紑鍚? or "闊虫晥宸插叧闂?)
        RefreshMeta()
    elseif action == "restore_purchase" then
        -- 鍗遍櫓鎿嶄綔锛氬厛寮€纭闈㈡澘锛岃緭鍏ユ纭‘璁ょ爜鍚庢墠鐪熸鎭㈠璐拱銆?
        Settings.BeginConfirm("restore")
        OpenMetaScreen("reset_confirm")
    elseif action == "reset_save" then
        Settings.BeginConfirm("delete")
        OpenMetaScreen("reset_confirm")
    elseif action == "confirm_key" and index then
        local ch = Settings.KeyCharAt(index)
        if ch then Settings.PushChar(ch) end
        RefreshMeta()
    elseif action == "confirm_backspace" then
        Settings.Backspace()
        RefreshMeta()
    elseif action == "confirm_cancel" then
        -- 鍙栨秷纭闈㈡澘锛氬洖璁剧疆灞忥紙涓嶆墽琛屼换浣曞嵄闄╂搷浣滐級銆?
        OpenMetaScreen("settings")
    elseif action == "confirm_ok" then
        if not Settings.IsConfirmed() then
            SetMetaToast("纭鐮佷笉姝ｇ‘")
            RefreshMeta()
        else
            local reason = Settings.GetConfirmReason()
            metaState.screen = nil
            if reason == "delete" then
                -- 娓呯┖瀛樻。锛氶噸缃湰鍦板瓨妗?+ 浜戝瓨妗ｏ紝鍥炲埌鍑哄巶鐘舵€併€?
                PlayerData.ResetAll()
                PlayerData.Save()
                SavePlayerDataToCloud()
                Game.SetItemStock(PlayerData.GetItemStock())
                -- v0.13.60锛氭竻妗ｅ悗闊充箰/闊虫晥鍥炲埌榛樿寮€锛岄噸鏂颁綔鐢ㄥ埌闊抽鎬绘帶銆?
                RenderBackend.SetMusicEnabled(PlayerData.IsMusicEnabled())
                RenderBackend.SetSfxEnabled(PlayerData.IsSfxEnabled())
                metaState.talents = PlayerData.GetTalents()
                metaState.gems = 0
                SetMetaToast("瀛樻。宸叉竻绌?)
                print("[Main] save wiped by player confirm")
            else
                -- 鎭㈠璐拱锛氶噸鏂板悜鏈嶅姟绔媺涓€娆′綑棰濅笌宸茶喘鍐呭锛堢绾夸笉鍙敤锛夈€?
                if GameMode.IsOffline() then
                    SetMetaToast("闇€鑱旂綉鍚庡彲鐢?)
                else
                    NetClient.RequestBalance()
                    SetMetaToast("姝ｅ湪鎭㈠璐拱鈥?)
                    print("[Main] restore purchase requested")
                end
            end
            RefreshMeta()
        end
    elseif action == "buy_item" and index then
        -- v0.13.13锛氳姳闆朵欢涔板眬鍐呴亾鍏凤紙姘镐箙搴撳瓨锛夈€傚簱瀛樹笂闄?闆朵欢涓嶈冻閮藉彧缁?toast銆?
        local def = StageSelect.ITEM_ORDER[index]
        if def then
            local affordable, atCap = ItemShop.CanBuy(def.key)
            if atCap then
                SetMetaToast("璇ラ亾鍏峰凡杈惧簱瀛樹笂闄?)
            elseif not affordable then
                SetMetaToast(string.format("闆朵欢涓嶈冻锛岃繕宸?%d",
                    math.max(0, ItemShop.GetPrice(def.key) - PlayerData.GetParts())))
            else
                local stockBefore = PlayerData.GetItemCount(def.key)
                if ItemShop.Buy(def.key) then
                    Game.SetItemStock(PlayerData.GetItemStock())
                    SavePlayerDataToCloud()
                    SetMetaToast(string.format("宸茶喘涔般€?s銆嵜?", def.name))
                    print("[Main] item bought: " .. def.key
                        .. " stock " .. stockBefore .. " -> " .. PlayerData.GetItemCount(def.key))
                end
            end
            RefreshMeta()
        end
    elseif action == "open_shop" then
        OpenMetaScreen("shop")
    elseif action == "open_codex" then
        metaState.codexPage = 1
        OpenMetaScreen("codex")
    elseif action == "codex_next_page" then
        metaState.codexPage = (metaState.codexPage or 1) % math.max(1,
            math.ceil(MetaCatalog.GetCodexTotal() / 8)) + 1
    elseif action == "open_tasks" then
        OpenMetaScreen("tasks")
    elseif action == "open_rank" then
        OpenMetaScreen("rank")
    elseif action == "pass_tab" then
        -- v0.14.0锛氭垬鏂楁。妗堝睆鍒囧埌銆屾垬鏂楁。妗堛€嶉〉绛俱€?
        metaState.passTab = "pass"
    elseif action == "ach_tab" then
        -- v0.14.0锛氭垬鏂楁。妗堝睆鍒囧埌銆屾垚灏便€嶉〉绛锯€斺€旀墦寮€鍓嶉噸绠椾竴娆★紙鎶樼畻鏈€鏂扮粺璁?+ 骞傜瓑澶栧彂锛夈€?
        AchievementSystem.Refresh()
        RefreshMeta()
        metaState.passTab = "ach"
        metaState.achPage = 1
    elseif action == "show_platform_achievements" then
        -- 璺冲钩鍙板師鐢熸垚灏遍〉锛堣兘鍔涗笉鍙敤鏃舵彁绀猴級銆?
        if not AchievementSystem.ShowPlatformAchievements() then
            SetMetaToast("褰撳墠鐜涓嶆敮鎸佸钩鍙版垚灏遍〉")
        end
    elseif action == "ach_prev_page" then
        metaState.achPage = math.max(1, (metaState.achPage or 1) - 1)
    elseif action == "ach_next_page" then
        local total = metaState.achTotal or 0
        local pages = math.max(1, math.ceil(total / 10))
        metaState.achPage = math.min(pages, (metaState.achPage or 1) + 1)
    elseif action == "open_wheel" then
        OpenMetaScreen("wheel")
    elseif action == "open_pass" then
        -- v0.14.0锛氭墦寮€鎴樻枟妗ｆ灞忛粯璁よ惤鍦ㄣ€屾垬鏂楁。妗堛€嶉〉绛俱€?
        metaState.passTab = "pass"
        OpenMetaScreen("pass")
    elseif action == "claim_pass" and index then
        local reward = PlayerData.ClaimPass(index, metaState.premiumPass and 2 or 1)
        if reward > 0 then
            PersistMeta()
            SetMetaToast(string.format("鎴樻枟妗ｆ +%d 闆朵欢", reward))
        end
    elseif action == "claim_gear" then
        local gears = PlayerData.ClaimGear()
        if gears > 0 then
            PersistMeta()
            SetMetaToast(string.format("瀛橀挶缃?+%d 榻胯疆", gears))
        else
            SetMetaToast("瀛橀挶缃愯繕鏄┖鐨?)
        end
    elseif action == "buy_premium_pass" then
        if GameMode.IsOffline() then
            SetMetaToast("闇€鑱旂綉鍚庡彲鐢?)
        else
            SetMetaToast("鎵ｆ涓€?)
            NetClient.SpendGems("pass_premium", function(ok, reason)
                if ok then
                    NetClient.RequestBalance()
                    SetMetaToast("浠樿垂妗ｆ杞ㄥ凡瑙ｉ攣")
                elseif reason == "pending" then
                    SetMetaToast("涓婁竴绗斿厬鎹㈠皻鏈‘璁わ紝璇风◢鍊?)
                elseif reason == "unknown" then
                    SetMetaToast("缁撴灉寰呯‘璁わ紝璇烽噸鏂拌繘鍏ユ父鎴忓璐?)
                elseif reason == "already_owned" then
                    SetMetaToast("浠樿垂妗ｆ杞ㄥ凡瑙ｉ攣")
                else
                    SetMetaToast("鎵ｆ澶辫触锛岃閲嶈瘯")
                end
                RefreshMeta()
            end)
        end
    elseif action == "signin" then
        HandleSignIn()
    elseif action == "supply" then
        if metaState.supplyAvailable then
            metaState.supplyOpen = true
        else
            SetMetaToast("浠婃棩琛ョ粰宸查鍙?)
        end
    elseif action == "supply_claim" then
        HandleSupply("claim")
    elseif action == "supply_double" then
        HandleSupply("double")
    elseif action == "claim" and index then
        HandleClaimTask(index)
    elseif action == "preview_skin" and index then
        -- 灞曞彴娴忚鍙敼鍙橀瑙堣溅鍨嬶紝涓嶈喘涔般€佷笉瑁呭銆佷笉鍐欏瓨妗ｃ€?
        MetaUI.PreviewVehicle(index)
    elseif action == "buy_skin" and index then
        HandleShopSkin(index)
    elseif action == "shop_tab" then
        MetaUI.SetShopTab(MetaUI.GetShopTab() == "trail" and "vehicle" or "trail")
    elseif action == "preview_trail" and index then
        MetaUI.PreviewTrail(index)
    elseif action == "buy_trail" and index then
        HandleShopTrail(index)
    elseif action == "ad_gift" and index then
        HandleAdGift(index)
    elseif action == "wheel_spin" then
        HandleWheelSpin()
    end
end

-- v0.12.5锛氶《绔€氱煡鏉″姩浣滃鐞嗭紙鍦ㄦ璧嬪€硷紝鍑芥暟浣撳紩鐢?HandleMetaAction锛夈€?
onBannerAction = function(actionId)
    if actionId == "buy_premium_pass" then
        -- 鎵ｆ璧版湇鍔＄寮傛鍥炶皟锛岀粨鏋滅敱 metaToast 鍛堢幇锛涢€氱煡鏉″厛鏀惰捣閬垮厤閲嶅鐐瑰嚮銆?
        RenderBackend.DismissSystemBanner()
        HandleMetaAction("buy_premium_pass", nil)
    elseif actionId == "open_recharge" then
        HandleMetaAction("open_recharge", nil)
        RenderBackend.DismissSystemBanner()
    elseif actionId == "banner_exit" then
        engine:Exit()
    end
end

---@return boolean
local function IsMetaCapturing()
    return metaState.screen ~= nil or metaState.supplyOpen
end

-- 鍏冨眰浼樺厛娑堣垂杈撳叆锛氬脊绐?> 闈㈡澘 > 涓昏彍鍗曞晢涓氬尯銆?
-- 杩斿洖 true 琛ㄧず鏈杈撳叆宸茶鍏冨眰澶勭悊锛岀帺娉曞眰涓嶅緱鍐嶅搷搴斻€?
---@return boolean handled
local function HandleMetaPointerDown(uiX, uiY)
    if metaState.supplyOpen then
        local action = RenderBackend.HitTestSupplyPopup(uiX, uiY, metaState)
        if action then HandleMetaAction(action, nil) end
        return true
    end
    if metaState.screen then
        -- v0.13.8锛氬ぉ璧嬫爲鏄彲婊氬姩闈㈡澘鈥斺€旀寜涓嬪厛浜ょ粰瀹冭褰曡捣鐐癸紙鍐呭鍖哄唴锛夛紝
        -- 浣嗘槸鍚︾畻銆屾嫋鎷姐€嶈绛夋姮鎵嬫椂鎵嶅畾锛堣 HandleMouseUp/TouchEnd 鐨?ScrollEnd锛夈€?
        -- 鈿狅笍 杩欓噷涓嶈兘鐩存帴 return锛氬惁鍒欑偣鍑绘案杩滆蛋涓嶅埌 HitTestMetaScreen锛?
        -- 鍗＄墖閫変笉涓€佸簳閮ㄦ诞绐椾笉寮癸紙v0.13.13 淇锛夈€?
        -- v0.13.13锛氬ぉ璧嬫爲鐨勩€岀偣鍗＄墖閫夊崱銆嶆斁鍦ㄦ姮鎵嬫椂鍒ゅ畾鈥斺€?
        -- 鐪熸嫋鎷借繃灏卞悶鎺夋姮鎵嬶紙鍙粴鍔ㄤ笉閫夊崱锛夛紝娌℃嫋鎷借繃鎵嶅綋浣滅偣鍑汇€?
        if metaState.screen == "talent" and TalentTree.ScrollBegin(uiX, uiY, designWidth_) then
            talentScrollArmed = true
            return true
        end
        -- v0.13.13锛氶€夊叧鐣岄潰鍚屾牱鏄彲婊氬姩鐖鈥斺€旀寜涓嬪厛璁板綍璧风偣锛屾姮鎵嬫椂鎸夈€屾槸鍚︽嫋鍔ㄨ繃銆嶅垎娴併€?
        if metaState.screen == "stage_select" and StageSelect.ScrollBegin(uiX, uiY, designWidth_) then
            stageSelectScrollArmed = true
            return true
        end
        local action, index = RenderBackend.HitTestMetaScreen(uiX, uiY, metaState)
        if action then HandleMetaAction(action, index) end
        return true
    end
    -- v0.13.4锛氫富鑿滃崟銆屽紑濮嬫垬鏂椼€岰TA 鎵撳紑閫夊叧鐣岄潰锛堜笉鍐嶇洿鎺ュ紑灞€锛夈€?
    if gameSnapshot and RenderBackend.HitTestMenuCta(uiX, uiY, gameSnapshot) then
        HandleMetaAction("open_stage_select", nil)
        return true
    end
    -- v0.13.59锛氫富鑿滃崟宸︿笂瑙掗娇杞?鈫?璁剧疆灞忋€?
    if gameSnapshot and RenderBackend.HitTestMenuGear(uiX, uiY, gameSnapshot) then
        HandleMetaAction("open_settings", nil)
        return true
    end
    local action = RenderBackend.HitTestMenuBar(uiX, uiY, metaState)
    if action then
        HandleMetaAction(action, nil)
        return true
    end
    return false
end

local function HandleMetaPointerClick(uiX, uiY)
    if not metaState.screen then return end
    local action, index = RenderBackend.HitTestMetaScreen(uiX, uiY, metaState)
    if action then HandleMetaAction(action, index) end
end

-- 涓昏彍鍗曚笂鐨勫厓灞傜偣鍑伙紙榧犳爣/瑙︽懜鍏辩敤锛夈€傝繑鍥?true 琛ㄧず鏈杈撳叆宸茶鍏冨眰娑堣垂銆?
---@param screenX number
---@param screenY number
---@return boolean handled
local function TryMenuMetaAt(screenX, screenY)
    if not gameSnapshot or gameSnapshot.state ~= "menu" then return false end
    local uiX, uiY = RenderBackend.ScreenToUi(screenX, screenY)
    return HandleMetaPointerDown(uiX, uiY)
end

-- 鏉炬墜鏃惰嫢鍏冨眰闈㈡澘浠嶅紑鐫€锛岀姝㈢┛閫忔垚銆岀偣鍑诲紑濮嬨€嶃€?
---@return boolean
local function MenuMetaBlocksRelease()
    return gameSnapshot ~= nil and gameSnapshot.state == "menu" and IsMetaCapturing()
end

-- v0.12.5锛欻UD 鍙充笂瑙掓殏鍋滄寜閽紙绉诲姩绔敮涓€鏆傚仠鍏ュ彛锛夈€傝繑鍥?true 琛ㄧず宸叉秷璐广€?
---@return boolean handled
local function TryHudPauseAt(screenX, screenY)
    if not gameSnapshot or gameSnapshot.state ~= "playing" then return false end
    local uiX, uiY = RenderBackend.ScreenToUi(screenX, screenY)
    if not RenderBackend.HitTestHudPause(uiX, uiY, gameSnapshot) then return false end
    Game.Pause()
    RefreshSnapshots()
    return true
end

-- v0.12.5锛氬眬鍐呴亾鍏峰彸涓婅绔栧垪銆傛敹璧锋€佺偣鏍囩灞曞紑锛涘睍寮€鎬佺偣妲戒綅鐢ㄩ亾鍏锋垨鐪嬪箍鍛婇鍙栥€?
-- 杩斿洖 true 琛ㄧず鐐瑰嚮宸茶娑堣垂锛堜笉鍐嶇┛閫忔垚鎷栨嫿璧锋墜锛夈€?
---@return boolean handled
local function TryUseItemAt(screenX, screenY)
    if not gameSnapshot or gameSnapshot.state ~= "playing" then return false end
    local uiX, uiY = RenderBackend.ScreenToUi(screenX, screenY)
    local kind, index = RenderBackend.HitTestItemSlot(uiX, uiY, gameSnapshot)
    if not kind then return false end

    if kind == "toggle" then
        RenderBackend.ToggleItemPanel()
        return true
    end

    local item = gameSnapshot.items and gameSnapshot.items[index]
    if not item then return false end

    if (item.charges or 0) > 0 then
        Game.UseItem(item.key)   -- 鏁堟灉涓庨瀛楅兘鐢辫鍒欏眰浜嬩欢椹卞姩
        return true
    end
    if item.canGrant then
        ShowAd(function()
            if Game.GrantItem(item.key) then
                print("[Main] item granted via ad: " .. item.key)
                -- 鍙戞斁鎴愬姛鍚庝繚鎸佸睍寮€锛岃鐜╁鐪嬪埌鏂板叆鎵嬬殑閬撳叿
                RenderBackend.SetItemPanelOpen(true)
            end
        end)
        return true
    end
    Presentation.SetAdToast(item.name .. " 鏈眬宸查鍙?)
    return true
end

-- v0.13.58锛氬乏涓婅闄勯瓟鍗＄偣鍑讳娇鐢ㄣ€傝繑鍥?true 琛ㄧず鐐瑰嚮宸茶娑堣垂锛堜笉鍐嶇┛閫忔垚鎷栨嫿璧锋墜锛夈€?
---@return boolean handled
local function TryUseEnchantAt(screenX, screenY)
    if not gameSnapshot or gameSnapshot.state ~= "playing" then return false end
    local uiX, uiY = RenderBackend.ScreenToUi(screenX, screenY)
    if not RenderBackend.HitTestEnchant(uiX, uiY, gameSnapshot) then return false end
    if not Game.HasEnchant() then return false end
    Game.UseEnchant()   -- 鏁堟灉涓庡弽棣堥兘鐢辫鍒欏眰浜嬩欢椹卞姩
    return true
end

-- v0.11.0 鍟嗕笟鍖栵細鏆傚仠琛ョ粰绔欑殑鐪嬪箍鍛婃寜閽€傝繑鍥?true 琛ㄧず鐐瑰嚮宸茶娑堣垂锛堜笉瑙﹀彂鎭㈠锛夈€?
---@return boolean handled
local function TryPauseSupplyAt(screenX, screenY)
    if not Game.IsPaused() then return false end
    local uiX, uiY = RenderBackend.ScreenToUi(screenX, screenY)
    local kind = RenderBackend.HitTestPausePanel(uiX, uiY, Game.GetSnapshot())
    if kind == "pause_heal" then
        if not Game.CanPauseHeal() then
            Presentation.SetAdToast("闃茬嚎宸叉弧鎴栨€ユ晳宸茬敤瀹?)
            return true
        end
        ShowAd(function()
            if Game.PauseHeal() then
                Presentation.SetAdToast("闃茬嚎 +25 琛€")
            end
        end)
        return true
    elseif kind == "pause_rare" then
        if not Game.CanPauseRarePick() then
            Presentation.SetAdToast("鏈眬宸茶喘涔扮█鏈変繚搴?)
            return true
        end
        ShowAd(function()
            if Game.PauseRarePick() then
                Presentation.SetAdToast("涓嬫寮哄寲闈㈡澘蹇呭嚭绋€鏈?)
            end
        end)
        return true
    elseif kind == "pause_orbital" then
        if not Game.CanPauseOrbital() then
            Presentation.SetAdToast("鍙湪棣栭鍦ㄥ満涓旀湰灞€鏈敮鎻存椂鍙敤")
            return true
        end
        ShowAd(function()
            if Game.PauseOrbital() then Presentation.SetAdToast("杞ㄩ亾鏀彺宸茶桨鍑婚棰?) end
        end)
        return true
    elseif kind == "pause_reload" then
        if not Game.CanPauseReload() then
            Presentation.SetAdToast("鏈眬寮硅嵂琛ョ粰宸查鍙?)
            return true
        end
        ShowAd(function()
            if Game.PauseReload() then Presentation.SetAdToast("宸茶ˉ鍏呬竴杈嗛噸鍗?) end
        end)
        return true
    elseif kind == "pause_parts_boost" then
        if not Game.CanPausePartsBoost() then
            Presentation.SetAdToast("鏈眬闆朵欢鍔犲€嶅凡棰嗗彇")
            return true
        end
        ShowAd(function()
            if Game.PausePartsBoost() then Presentation.SetAdToast("闆朵欢 脳2 鐢熸晥 45 绉?) end
        end)
        return true
    elseif kind == "pause_resume" then
        Game.Resume()
        RefreshSnapshots()
        return true
    elseif kind == "pause_menu" then
        Game.GoToMenu()
        RefreshSnapshots()
        return true
    end
    return false
end

-- 鍗囩骇闈㈡澘鐐瑰嚮鍛戒腑锛坴0.12.5 绮剧畝锛氬彧鏈夐€夊崱 / 閿佸畾 / 鍏嶈垂閲嶆娊 / 鐪嬪箍鍛婇噸鎶斤級銆?
-- 鍑犱綍瀹屽叏鐢?Scene3DBackend.HitTestUpgradePanel 鎻愪緵锛屼笌缁樺埗鍚屾簮锛岀姝㈠湪姝ゅ彟鍐欏父閲忋€?
local function TryPickUpgradeAt(uiX, uiY)
    local snapshot = Game.GetSnapshot()
    local kind, index = RenderBackend.HitTestUpgradePanel(uiX, uiY, snapshot)
    if kind == "card" and index then
        Game.PickUpgrade(index)
        return true
    elseif kind == "hold" and index then
        if Game.ToggleHeldUpgrade(index) then
            Presentation.SetAdToast("宸插垏鎹繚鐣欏崱锛屼笅涓€娆″崌绾т紭鍏堝嚭鐜?)
        end
        return true
    elseif kind == "reroll_free" then
        if Game.CanFreeReroll() then
            Game.RerollUpgrades("free")
            Presentation.SetAdToast("宸插厤璐归噸鎶?)
        else
            Presentation.SetAdToast("鏈眬鍏嶈垂閲嶆娊宸茬敤瀹?)
        end
        return true
    elseif kind == "reroll_ad" then
        ShowAd(function()
            if Game.RerollUpgrades("ad_rare") then
                Presentation.SetAdToast("宸查噸鎶斤紝鏈蹇呮湁绋€鏈夊己鍖?)
            end
        end)
        return true
    end
    return false
end

local function HandleGameOverPointerDown(uiX, uiY)
    -- 杩囨浮鏈熷悶鎺夌偣鍑伙紱浠呭湪璺宠繃鎻愮ず鍑虹幇鍚庡厑璁歌烦杩囷紝涓嶆瑁呯粨绠楁寜閽€?
    if StageTransition.IsActive(Game.GetSnapshot()) then
        reviveArmed, doubleArmed, restartArmed, menuArmed = false, false, false, false
        StageTransition.Skip(Game.GetSnapshot())
        return true
    end
    local hit = RenderBackend.HitTestGameOverButton(uiX, uiY, Game.GetSnapshot())
    reviveArmed = (hit == "revive")
    doubleArmed = (hit == "double")
    restartArmed = (hit == "restart")
    -- v0.12.5锛氱粨绠楅〉銆屽洖涓昏彍鍗曘€嶅嚭鍙ｏ紙鍚屾牱鏉炬墜纭锛岄槻姝讳骸鐬棿璇Е锛?
    menuArmed = (hit == "menu")
    return hit ~= nil
end

local function HandleGameOverPointerUp(uiX, uiY)
    local hit = RenderBackend.HitTestGameOverButton(uiX, uiY, Game.GetSnapshot())
    if reviveArmed and hit == "revive" then
        reviveArmed = false
        doubleArmed = false
        restartArmed = false
        menuArmed = false
        ShowReviveAd()
        return true
    end
    if doubleArmed and hit == "double" then
        reviveArmed = false
        doubleArmed = false
        restartArmed = false
        menuArmed = false
        if Game.CanDoubleSettle() then
            ShowDoublePartsAd()
        else
            Presentation.SetAdToast("鏈眬闆朵欢宸茬炕鍊?)
        end
        return true
    end
    if restartArmed and hit == "restart" then
        reviveArmed = false
        doubleArmed = false
        restartArmed = false
        menuArmed = false
        Game.RestartFromOver()
        RefreshSnapshots()
        return true
    end
    if menuArmed and hit == "menu" then
        reviveArmed = false
        doubleArmed = false
        restartArmed = false
        menuArmed = false
        Game.GoToMenu()
        RefreshSnapshots()
        return true
    end
    reviveArmed = false
    doubleArmed = false
    restartArmed = false
    menuArmed = false
    return false
end

-- v0.13.4锛氳儨鍒╃粨绠楅〉锛坰tagewin锛夋澗鎵嬬‘璁ゃ€侱own 鍙瑁呭懡涓殑鎸夐挳锛孶p 鏃舵墠鐪熸璺冲叧/閲嶅紑/鍥炶彍鍗曘€?
local function HandleStageWinPointerDown(uiX, uiY)
    -- 涓庡け璐ュ悓闂ㄦ帶锛氭棭鏈熺偣鍑诲彧娑堣垂锛屼笉璺宠繃锛屼篃涓嶆瑁呴殣钘忔寜閽€?
    if StageTransition.IsActive(Game.GetSnapshot()) then
        stageWinArmed = nil
        StageTransition.Skip(Game.GetSnapshot())
        return true
    end
    local hit = RenderBackend.HitTestStageWinButton(uiX, uiY, Game.GetSnapshot())
    stageWinArmed = hit
    return hit ~= nil
end

local function HandleStageWinPointerUp(uiX, uiY)
    local hit = RenderBackend.HitTestStageWinButton(uiX, uiY, Game.GetSnapshot())
    local armed = stageWinArmed
    stageWinArmed = nil
    if not armed or armed ~= hit then return armed ~= nil end
    if armed == "next" then
        Game.NextStage()
    elseif armed == "retry" then
        -- v0.13.56锛氱 1 鍏炽€屽啀鎴樻湰鍏炽€嶅悓鏍峰厛寮规祴璇曟ā寮忚闂紙姣忔閮介棶锛夈€?
        -- 鈿狅笍 璇㈤棶灞忔槸銆岃彍鍗曟€併€嶅睆锛屽繀椤诲厛鍥炰富鑿滃崟鍐嶅紑锛屽惁鍒?HandleUpdate 鐨?
        --    寰呭喅璺冲叧鍒ゅ畾锛堣姹?state==menu锛夋案杩滀笉鎴愮珛銆?
        if Game.GetSnapshot().stageResult and Game.GetSnapshot().stageResult.stage == 1 then
            Game.GoToMenu()
            OpenMetaScreen("test_mode")
            RefreshSnapshots()
            print("[Main] stage 1 retry -> ask test mode")
        else
            Game.RetryStage()
        end
    elseif armed == "menu" then
        Game.GoToMenu()
    end
    RefreshSnapshots()
    return true
end

local started_ = false

-- 绂荤嚎闄嶇骇锛氫簯鑳藉姏锛堜簯瀛樻。/鎺掕姒?浣欓锛夊湪鍗曟満璺緞涓婂叏閮ㄧ煭璺紝鍙鏈湴銆?
---@param opts table|nil { offline = boolean }
function ClientMain.Start(opts)
    -- 鑷缓澶у巺浜旂瓒呮椂鍏堟湰鍦板惎鍔ㄤ簡娓告垙锛涜嫢寮曟搸闅忓悗浠嶅畬鎴愯剼鏈垏鎹㈠啀璋冧竴娆?Start锛?
    -- 閲嶅璁㈤槄浼氳 Game.Update 姣忓抚璺戜袱閬嶃€傛澶勫箓绛変繚鎶わ紝淇濇寔宸茶繍琛岀殑鏈湴灞€涓嶅彉銆?
    if started_ then
        print("[ClientMain] already started, ignore duplicate entry")
        return true
    end
    opts = opts or {}
    if opts.offline ~= nil then
        GameMode.SetOffline(opts.offline == true)
    end

    graphics.windowTitle = "璐ц溅澶ф垬椋炴満"
    input.mouseVisible = true

    if not RenderBackend.Init() then return false end
    PerformanceProbe.SetProvider(function()
        local snapshot = Game.GetSnapshot()
        return {
            state = snapshot and snapshot.state or "unknown",
            wave = snapshot and snapshot.wave or 0,
            enemies = snapshot and #(snapshot.veggies or {}) or 0,
            screen = tostring(graphics:GetWidth()) .. "x" .. tostring(graphics:GetHeight()),
            dpr = graphics:GetDPR(),
        }
    end)
    PerformanceProbe.Start({ reportInterval = 5.0, enabled = true })
    ClientMain._pointer.focused = true
    ClientMain.CancelInput()

    -- v0.12.5锛氬钩鍙伴€氱煡鎹㈢毊锛坴0.12.7锛氫粯璐硅建鑷姩鏇濆厜宸插垹锛屾棤闇€鐘舵€佸浣嶏級銆?
    installSystemNotificationHandler()

    -- v0.11.0 鑱旀満锛氬厖鍊煎脊灞傚鐢ㄦ父鎴?UI 鐨勪护鐗屼笌鍘熻锛圲I 鏃犳薄鏌擄級銆?
    RechargeShop.Init(MetaUI.GetDeps())
    MetaUI.RegisterScreen("recharge", RechargeShop.Draw, RechargeShop.HitTest)
    -- v0.13.4锛氶€夊叧鐣岄潰鍚屾牱澶嶇敤娓告垙浠ょ墝锛堟彃浠跺紡娉ㄥ唽锛屼笉鍙嶅悜渚濊禆娓叉煋鍚庣锛夈€?
    StageSelect.Init(MetaUI.GetDeps())
    MetaUI.RegisterScreen("stage_select", StageSelect.Draw, StageSelect.HitTest)
    -- v0.13.13锛氬眬鍐呴亾鍏峰簱瀛?provider鈥斺€擥ame.ResetGame 姣忔寮€灞€鑷姩鎷夊彇锛?
    -- 瑕嗙洊閫夊叧/涓嬩竴鍏?鍐嶆垬/閲嶅紑鍏ㄩ儴鍏ュ彛锛堟棤闇€閫愪釜鍏ュ彛娉ㄥ叆锛夈€?
    Game.SetItemStockProvider(PlayerData.GetItemStock)
    -- v0.13.5锛氬ぉ璧嬫爲鐣岄潰鍚屾簮娉ㄥ唽銆?
    TalentTree.Init(MetaUI.GetDeps())
    MetaUI.RegisterScreen("talent", TalentTree.Draw, TalentTree.HitTest)
    -- v0.13.56锛氱 1 鍏炽€屾祴璇曟ā寮忋€嶈闂睆鍚屾簮娉ㄥ唽锛堝鐢ㄥ厓灞傜獥鍙ｅ姩鐢讳笌鍛戒腑鍒嗗彂锛夈€?
    TestModePrompt.Init(MetaUI.GetDeps())
    MetaUI.RegisterScreen("test_mode", TestModePrompt.Draw, TestModePrompt.HitTest)
    -- v0.13.59锛氳缃睆 + 鍗遍櫓鎿嶄綔纭闈㈡澘锛堟墜鏈洪敭鐩樿緭鍏ョ‘璁ょ爜锛夊悓婧愭敞鍐屻€?
    Settings.Init(MetaUI.GetDeps())
    MetaUI.RegisterScreen("settings", Settings.Draw, Settings.HitTest)
    MetaUI.RegisterScreen("reset_confirm", Settings.DrawConfirm, Settings.HitTestConfirm)
    -- v0.14.0锛氭垚灏卞垪琛ㄥ凡骞跺叆銆屾垬鏂楁。妗堛€嶅睆锛圡etaUI.DrawPass 鐩存帴璋冪敤锛夛紝涓嶅啀鍗曠嫭娉ㄥ唽灞忥紱
    -- 杩欓噷鍙敞鍏ヤ緷璧栵紙鏈湴鎴愬氨涓烘潈濞侊紝骞冲彴鎴愬氨鍙仛闀滃儚锛夈€?
    Achievements.Init(MetaUI.GetDeps())

    PlayerData.Load()
    -- v0.13.60锛氭妸瀛樻。閲岀殑闊充箰/闊虫晥寮€鍏充綔鐢ㄥ埌闊抽鎬绘帶锛圓udioDirector 宸插湪 Backend.Init 灏辩华锛夈€?
    RenderBackend.SetMusicEnabled(PlayerData.IsMusicEnabled())
    RenderBackend.SetSfxEnabled(PlayerData.IsSfxEnabled())
    -- 寮€灞€鑷姩鎷ユ湁鍒濆杞︾殑銆屽厑璁稿眬鍐呭嚭鍦恒€嶈妭鐐癸紙骞傜瓑锛涘繀椤诲湪 Load 涔嬪悗锛夈€?
    PlayerData.EnsureAutoOwnedTalents(TalentCatalog.AUTO_OWNED)
    -- 鎴愬氨閲嶇畻鏀惧湪缃戠粶闄嶇骇鍒ゅ畾涔嬪悗锛岀绾垮惎鍔ㄤ笉鍚戝钩鍙板鍙戙€?
    -- v0.13.5锛氬ぉ璧嬫彁渚涜€呪€斺€旀瘡娆″紑灞€锛堥€夊叧/涓嬩竴鍏?閲嶅紑锛塆ame 鑷姩鎷夊彇鏈€鏂拌В閿侀泦鍚堛€?
    Game.SetTalentProvider(function() return PlayerData.GetTalents() end)
    metaDate = os.date("%Y-%m-%d")
    -- 鈿狅笍 鍏ㄧ▼ pcall锛氳仈鏈哄眰浠讳綍寮傚父閮戒笉鍏佽涓柇娓告垙鍚姩
    --    锛堟浘缁忓洜涓?NetClient.Start 涓?nil锛屽湪杩欓噷鎶涘嚭锛屽鑷村悗闈㈢殑浜嬩欢璁㈤槄鍏ㄩ儴娌℃墽琛岋紝
    --     鐪熸満琛ㄧ幇涓恒€?D 姝ｅ父浣?2D 鐣岄潰鍏ㄦ病銆嶏級銆?
    -- 绂荤嚎闄嶇骇鏃舵暣灞備笉鍔犺浇锛涘湪绾胯矾寰勬墠鍚敤浣欓鍚屾銆?
    -- 鈿狅笍 鍏ㄧ▼ pcall锛氳仈鏈哄眰浠讳綍寮傚父閮戒笉鍏佽涓柇娓告垙鍚姩锛堝惁鍒欏悗缁簨浠惰闃呭叏涓嶆墽琛岋紝
    --    鐪熸満琛ㄧ幇涓恒€?D 姝ｅ父浣?2D 鐣岄潰鍏ㄦ病銆嶏級銆?
    if GameMode.IsOffline() then
        print("[ClientMain] offline mode: network layer not started")
    else
        local okNet, errNet = pcall(function()
            NetClient.SetGemsListener(function(gems)
                metaState.gems = gems
            end)
            NetClient.SetPurchasedPartsListener(function(total, _, firstGift)
                local granted = PlayerData.ClaimPurchasedParts(total)
                if granted > 0 then
                    SavePlayerDataToCloud()
                    metaState.rechargeToast = string.format("鍏戞崲闆朵欢鍒拌处 +%d", granted)
                    print("[Main] purchased parts recovered +" .. granted .. " total=" .. total)
                end
                -- 棣栧厖绀煎寘鍙戣揣锛氭湇鍔＄鏍囧織涓虹湡涓旀湰鍦版湭琛ュ彂鏃讹紝鍙戜竴娆¤溅鍨嬩笌闆朵欢銆?
                if firstGift and not PlayerData.IsFirstGiftClaimed() then
                    PlayerData.AddParts(Shared.FIRST_GIFT.parts)
                    PlayerData.UnlockSkin(Shared.FIRST_GIFT.skin)
                    PlayerData.MarkFirstGiftClaimed()
                    SavePlayerDataToCloud()
                    metaState.rechargeToast = "鏂版墜绀煎寘宸插埌璐?
                    print("[Main] first gift delivered: parts+" .. Shared.FIRST_GIFT.parts
                        .. " skin=" .. Shared.FIRST_GIFT.skin)
                end
                -- 姣忔鏉冨▉鎺ㄩ€侀兘鍒锋柊浠樿垂杞?棣栧厖鏍囧織锛堟湇鍔＄闅忓悓涓€浜嬩欢甯?premium/first_gift锛夈€?
                RefreshMeta()
            end)
            NetClient.Start()
        end)
        if not okNet then
            print("[ClientMain] network layer failed, degrade to offline: " .. tostring(errNet))
            GameMode.SetOffline(true)
        end
    end

    AchievementSystem.Init()
    AchievementSystem.Refresh()
    local width, height = RenderBackend.GetDesignSize()
    designWidth_ = width
    local highScoreState = ClientMain._highScore
    local initialHighScore = math.max(math.floor(PlayerData.GetHighScore()), highScoreState.retained,
        highScoreState.request and highScoreState.request.score or 0)
    Game.Init({
        width = width, height = height, seed = os.time(),
        highScore = initialHighScore,
    })
    Presentation.Init()
    highScoreState.lifetime = {}
    highScoreState.active = true
    highScoreState.readReady = false
    lastSavedHighScore = 0
    highScoreDirty = initialHighScore
    highScoreCommitCooldown = HIGH_SCORE_COMMIT_INTERVAL
    prevHighScoreState_ = nil
    RefreshSnapshots()
    RefreshMeta()
    LoadHighScoreFromCloud()
    LoadPlayerDataFromCloud()

    SubscribeToEvent("Update", HandleUpdate)
    SubscribeToEvent("MouseButtonDown", HandleMouseDown)
    SubscribeToEvent("MouseButtonUp", HandleMouseUp)
    SubscribeToEvent("MouseMove", HandleMouseMove)
    SubscribeToEvent("TouchBegin", HandleTouchBegin)
    SubscribeToEvent("TouchMove", HandleTouchMove)
    SubscribeToEvent("TouchEnd", HandleTouchEnd)
    SubscribeToEvent("KeyDown", HandleKeyDown)
    SubscribeToEvent("KeyUp", HandleKeyUp)
    SubscribeToEvent("ScreenMode", HandleScreenMode)
    SubscribeToEvent("InputFocus", HandleInputFocus)

    print("[Main] rendering, ads and cloud save connected")
    started_ = true
    return true
end

function ClientMain.Stop()
    local highScoreState = ClientMain._highScore
    if highScoreState.active then
        -- 鍋滄鍓嶄繚鍏ㄥ凡浜х敓鐨勫垎鏁帮紱鏈湴鍐欏け璐ヤ篃涓嶈兘涓㈡帀鍚?Lua 鐢熷懡鍛ㄦ湡鐨勫緟鍐欏€笺€?
        highScoreState.retained = math.max(highScoreState.retained, highScoreDirty,
            math.floor(Game.GetSnapshot().highScore or 0),
            highScoreState.request and highScoreState.request.score or 0)
        local ok, err = pcall(PlayerData.SetHighScore, highScoreState.retained)
        if not ok then print("[Main] local high_score save failed; retained in memory: " .. tostring(err)) end
    end
    AchievementSystem.Shutdown()
    PerformanceProbe.Stop()
    highScoreState.active = false
    highScoreState.readReady = false
    highScoreState.lifetime = {}
    ClientMain.CancelInput()
    ClientMain._pointer.focused = false
    UnsubscribeFromEvent("InputFocus")
    started_ = false
    pcall(SysNotif.UnregisterHandler)
    if not GameMode.IsOffline() then
        NetClient.Stop()
    end
    RenderBackend.Shutdown()
end

---@return boolean
function ClientMain.IsOffline()
    return GameMode.IsOffline()
end

-- v0.13.8锛氫粎渚涙湰鍦扮灞忔帰閽?楠屾敹浣跨敤鐨勭獎鎺ュ彛鈥斺€旂洿鎺ユ墦寮€鏌愪釜鍏冨眰鐣岄潰锛?
-- 涓嶆敼鍙樹换浣曟父鎴忛€昏緫锛堟甯告父鐜╄矾寰勪粛璧拌緭鍏?鈫?HandleMetaAction锛夈€?
---@param name string|nil
function ClientMain.DebugOpenScreen(name)
    metaState.screen = name
    if name == "stage_select" then
        metaState.stageSelectLoading = true
        metaState.stageSelectLoadingTimer = 1.35
    else
        metaState.stageSelectLoading = false
        metaState.stageSelectLoadingTimer = 0
    end
    RefreshMeta()
    RefreshSnapshots()
    -- 涓?OpenMetaScreen 淇濇寔涓€鑷达細鎵撳紑閫夊叧鍗冲畾浣嶅埌鏈€鏂板叧锛堟棤闄愮埇濉旓級銆?
    if name == "stage_select" then
        StageSelect.FocusLatest(designWidth_, metaState.maxStage or 1)
    end
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local inputDt = math.max(0, eventData:GetFloat("TimeStep"))
    local dt = math.min(inputDt, 0.05)
    PerformanceProbe.BeginFrame(inputDt)
    if metaState.stageSelectLoading then
        metaState.stageSelectLoadingTimer = metaState.stageSelectLoadingTimer - dt
        if metaState.stageSelectLoadingTimer <= 0 then
            metaState.stageSelectLoadingTimer = 0
            metaState.stageSelectLoading = false
        end
    end
    AdService.Update(dt)
    AchievementSystem.Update(dt)
    if not GameMode.IsOffline() then NetClient.Update(dt) end
    -- v0.13.56锛氱 1 鍏炽€屾祴璇曟ā寮忋€嶈闂‘璁ゅ悗锛屽湪鑿滃崟鎬佽繘鍏ョ洰鏍囧叧銆?
    -- 鏀惧湪鐜╂硶鏇存柊涔嬪墠锛屼繚璇佹湰甯у氨鍒囧埌鐩爣鍏筹紝涓嶉棯涓€甯ц彍鍗曘€?
    if pendingTestStage_ and Game.GetSnapshot().state == "menu" then
        local target = pendingTestStage_
        pendingTestStage_ = nil
        metaState.screen = nil
        metaState.testMode = false
        Game.StartStageAt(target)
        RefreshSnapshots()
        print("[Main] enter stage " .. tostring(target) .. " after test mode prompt")
    end
    local hitStop = Presentation.GetSnapshot().hitStop or 0
    local gameDt = dt
    if hitStop > 0 then gameDt = dt * 0.15 end
    -- v0.12.5锛氭縺鍔辫棰戝湪閫旀椂鍐荤粨鐜╂硶鎺ㄨ繘锛堟祻瑙堝櫒 embed 瑕嗙洊鏃舵父鎴忓惊鐜粛鍦ㄨ窇锛?
    -- 骞垮憡鍥炴潵鏁屼汉宸插帇鍒伴槻绾匡級銆傝〃鐜板眰鐓у父琛板噺锛屽揩鐓т笉鍙?= 鐢婚潰闈欐銆?
    -- 缁撶畻/鍗囩骇/鏆傚仠鎬佺殑骞垮憡鏈氨涓嶆帹杩涚帺娉曪紝鏃犻渶閲嶅澶勭悊銆?
    ClientMain.ValidatePointer()
    local adInFlight = AdService.IsInFlight()
    if adInFlight and (ClientMain._pointer.source ~= "" or Game.GetSnapshot().timeScale == 2
        or Game.GetSnapshot().holdSpeedPending or Game.GetSnapshot().aiming) then
        ClientMain.CancelInput()
    end
    local adFreeze = adInFlight
        and gameSnapshot ~= nil and gameSnapshot.state == "playing"
    -- v0.13.64锛氭嫋鎷借寖鍥存槸銆岃璁＄┖闂村渾銆嶇殑鎶曞奖鈥斺€旀瘡甯ф妸褰撳墠鎶曞奖缂╂斁鍠傜粰瑙勫垯灞傦紝
    -- 浣胯緭鍏ュ湪璁捐鍧愭爣閲屾寜鍦嗛挸鍒躲€佸啀鎹㈢畻鎴愮帺娉曚綅绉伙紙灞忓箷涓婄殑鑼冨洿濮嬬粓鏄渾锛夈€?
    do
        local _, _, psx, psy = RenderBackend.GetProjection()
        Game.SetPullSpace(psx, psy)
    end
    if not adFreeze then
        PerformanceProbe.BeginPhase("game")
        Game.Update(gameDt, inputDt)
        PerformanceProbe.EndPhase("game")
    end
    ClientMain.ValidatePointer()
    local snapshot = Game.GetSnapshot()
    local frameEvents = Game.DrainEvents()
    PerformanceProbe.BeginPhase("presentation")
    Presentation.Update(dt, snapshot, frameEvents)
    PerformanceProbe.EndPhase("presentation")
    -- 闊抽鎬绘帶娑堣垂鍚屼竴浠介鍩熶簨浠讹紙鍙锛夛紝骞舵寜鍏剁姸鎬佹満鍒囨崲 8bit BGM銆?
    RenderBackend.TickAudio(dt, snapshot, frameEvents)
    gameSnapshot = snapshot
    presentationSnapshot = Presentation.GetSnapshot()
    PerformanceProbe.BeginPhase("render")
    RenderBackend.UpdateScene(gameSnapshot, presentationSnapshot, metaState, adFreeze and 0 or gameDt, dt)
    PerformanceProbe.EndPhase("render")
    PerformanceProbe.EndFrame(inputDt)
    -- 鏈€楂樺垎浜戝啓鍚堝苟锛氬眬鍐呭彧绱寰呮彁浜ゅ€硷紱灞€鏈紙缁撶畻锛夈€佸洖鑿滃崟銆佷互鍙婃瘡
    -- HIGH_SCORE_COMMIT_INTERVAL 绉掔殑鍏滃簳鎵嶇湡姝ｅ啓涓€娆′簯锛堥厤棰?300 娆?鍒嗛挓锛夈€?
    -- 鈿狅笍 缁撶畻/鑿滃崟鏄€屾寔缁€併€嶁€斺€斿彧鍦?*杩涘叆**杩欎簺鎬佺殑閭ｄ竴甯ф彁浜や竴娆★紝涓嶈兘姣忓抚鎻愪氦锛?
    --    鍚﹀垯鍐欏け璐ワ紙error 鍥炶皟浼氶噸鏂版爣鑴忥級浼氭瘡甯ч噸璇曪紝褰㈡垚杩滆秴閰嶉鐨勫啓椋庢毚銆?
    if not GameMode.IsOffline() then
        if snapshot.highScore and snapshot.highScore > lastSavedHighScore then
            MarkHighScoreDirty(snapshot.highScore)
        end
        highScoreCommitCooldown = highScoreCommitCooldown - dt
        local state = snapshot.state
        local enteredEndState = state ~= prevHighScoreState_
            and (state == "gameover" or state == "stagewin" or state == "menu")
        prevHighScoreState_ = state
        -- 浜戣灏氭湭鎴愬姛鏃讹紝鐘舵€佽竟娌夸笉鑳界粫杩囧け璐ュ悗鐨?15 绉掗€€閬裤€?
        if highScoreCommitCooldown <= 0 or (enteredEndState and ClientMain._highScore.readReady) then
            CommitHighScore()
        end
    end

    -- 璺ㄥ崍澶滄椂鍚屾鍒锋柊鑿滃崟涓婄殑绛惧埌/浠诲姟/琛ョ粰/杞洏鐘舵€併€?
    local today = os.date("%Y-%m-%d")
    if today ~= metaDate then
        metaDate = today
        PlayerData.RollDaily()
        PlayerData.Save()
        SavePlayerDataToCloud()
        RefreshMeta()
        print("[Main] daily state refreshed: " .. today)
    end
    -- v0.11.0 鍟嗕笟鍖栵細鍏冨眰鎻愮ず璁℃椂涓庛€屽洖鍒颁富鑿滃崟鑷姩寮规瘡鏃ヨˉ缁欍€嶃€?
    if metaToastTimer > 0 then
        metaToastTimer = metaToastTimer - dt
        if metaToastTimer <= 0 then metaState.toast = nil end
    end
    if snapshot.state ~= "menu" then
        -- 绂诲紑涓昏彍鍗曟椂鏀惰捣鎵€鏈夊厓灞傜晫闈紝閬垮厤甯︾潃闈㈡澘杩涘眬銆?
        metaState.screen = nil
        metaState.supplyOpen = false
    end

    -- v0.11.0 鍟嗕笟鍖栵細缁撶畻椤典竴鍑虹幇灏辨寜 脳1 鎶婃湰灞€闆朵欢鍏ュ簱锛堝箓绛夛紝鍚屽抚鍙粨绠椾竴娆★級銆?
    -- v0.13.4锛氳儨鍒╃粨绠楋紙stagewin锛夊悓鏍峰叆搴擄紝骞惰褰曡鍏虫槦绾?+ 瑙ｉ攣涓嬩竴鍏炽€?
    if (snapshot.state == "gameover" or snapshot.state == "stagewin") and not snapshot.partsSettled then
        local newBricks, firstFinish, newGear = Game.TakeSettlementStats()
        local granted = Game.SettleParts(1)
        if granted > 0 then PlayerData.AddParts(granted) end
        if newGear > 0 then PlayerData.AddGear(newGear) end
        if newBricks > 0 then
            PlayerData.AddDailyProgress("break_bricks", newBricks)
            PlayerData.AddStat("bricksTotal", newBricks)
        end
        PlayerData.AddDailyProgress("reach_wave", math.floor(snapshot.wave or 1), true)
        if firstFinish then PlayerData.AddDailyProgress("play_runs", 1) end
        -- v0.13.62锛氭垚灏辩粺璁¤鏁板櫒锛堟湰鍦版潈濞侊級鈥斺€旀瘡灞€瀹屾垚 +1銆侀€氬叧 +1銆佸嚮璐ラ棰?+1銆?
        if firstFinish then PlayerData.AddStat("runsTotal", 1) end
        if snapshot.state == "stagewin" then PlayerData.AddStat("stageWins", 1) end
        if snapshot.bossDefeated then PlayerData.AddStat("bossKills", 1) end
        PlayerData.SetHighScore(math.floor(snapshot.highScore or 0))
        if snapshot.state == "stagewin" and snapshot.stageResult then
            PlayerData.RecordStageResult(snapshot.stageResult.stage, snapshot.stageResult.stars)
        end
        local bonus = 0
        for _, key in ipairs(snapshot.runAircraft or {}) do
            if PlayerData.UnlockCodex(key) then
                local entry = MetaCatalog.GetCodexEntry(key)
                if entry then bonus = bonus + entry.reward end
                print("[Main] codex unlocked: " .. key)
            end
        end
        if bonus > 0 then PlayerData.AddParts(bonus) end
        -- v0.13.62锛氱粨绠楀悗閲嶇畻鎴愬氨锛堟墍鏈夌粺璁″凡鏇存柊锛夛紝骞舵妸鏂拌В閿佸鍙戝钩鍙帮紙骞傜瓑锛夈€?
        local newAch = AchievementSystem.Refresh()
        -- 鐢?SetMetaToast 鑰岄潪鐩存帴璧?toast锛氬悗鑰呬笉閲嶇疆 metaToastTimer锛屾彁绀轰細姘镐箙鐣欏湪灞忎笂銆?
        if newAch > 0 then SetMetaToast(string.format("瑙ｉ攣 %d 涓垚灏憋紒", newAch)) end
        PlayerData.Save()
        SavePlayerDataToCloud()
        RefreshMeta()
        print("[Main] run settled, parts +" .. granted .. ", codex bonus +" .. bonus)
    end
end

function HandleScreenMode()
    RenderBackend.Resize()
end

---@param eventType string
---@param eventData InputFocusEventData
function HandleInputFocus(eventType, eventData)
    ClientMain._pointer.focused = eventData:GetBool("Focus") and not eventData:GetBool("Minimized")
    if not ClientMain._pointer.focused then ClientMain.CancelInput() end
end

-- v0.12.5锛氶《绔€氱煡鏉′紭鍏堟秷璐圭偣鍑伙紙浠绘剰鐘舵€侀兘鍦ㄦ渶涓婂眰锛夈€?
---@return boolean consumed
local function TryBannerAt(screenX, screenY)
    if not RenderBackend.HasSystemBanner() then return false end
    local uiX, uiY = RenderBackend.ScreenToUi(screenX, screenY)
    local action = RenderBackend.HitTestSystemBanner(uiX, uiY)
    if not action then return false end
    if action ~= "__close__" then
        onBannerAction(action)
    end
    return true
end

function HandleMouseDown(eventType, eventData)
    if eventData:GetInt("Button") ~= MOUSEB_LEFT then return end
    local screenX, screenY = GetScreenCoordinates(eventData)
    if not RenderBackend.IsInsideGameCanvas(screenX, screenY) then return end
    if not ClientMain.ClaimPointer("mouse") then return end
    local pointerX, pointerY = RenderBackend.ScreenToUi(screenX, screenY)
    RenderBackend.SetPointer(pointerX, pointerY)
    RenderBackend.SetPointerPressed(true)
    -- v0.12.5锛氶《閮ㄩ€氱煡鏉℃案杩滄渶鍏堝悆鐐瑰嚮锛堣鐩?HUD 涓嬫部锛屽彲鑳戒笌浠讳綍妯℃€侀噸鍙狅級銆?
    if TryBannerAt(screenX, screenY) then
        metaPointerConsumed = true
        return
    end
    if Game.IsGameOver() then
        local uiX, uiY = RenderBackend.ScreenToUi(screenX, screenY)
        HandleGameOverPointerDown(uiX, uiY)
        return
    end
    if Game.IsStageWin() then
        local uiX, uiY = RenderBackend.ScreenToUi(screenX, screenY)
        HandleStageWinPointerDown(uiX, uiY)
        return
    end
    local x, y = RenderBackend.ScreenToGame(screenX, screenY)
    if Game.IsLevelUp() then
        local uiX, uiY = RenderBackend.ScreenToUi(screenX, screenY)
        -- v0.10.24锛氱偣鍦ㄥ崱鐗囧涓嶅叧闂潰鏉夸篃涓嶇┛閫忥紝杞昏剦鍐叉彁绀哄繀椤讳笁閫変竴銆?
        if not TryPickUpgradeAt(uiX, uiY) then
            Presentation.PulseUpgradeHint()
        end
        return
    end
    -- v0.11.0 鍟嗕笟鍖栵細鏆傚仠琛ョ粰绔欐寜閽紭鍏堜簬銆岀偣浠绘剰澶勬仮澶嶃€嶃€?
    -- v0.12.5锛欻UD 鏆傚仠鎸夐挳涓庨亾鍏风珫鍒椾紭鍏堜簬鎷栨嫿璧锋墜銆?
    if TryHudPauseAt(screenX, screenY) then
        metaPointerConsumed = true
        return
    end
    if TryUseEnchantAt(screenX, screenY) then
        metaPointerConsumed = true
        return
    end
    if TryUseItemAt(screenX, screenY) then
        metaPointerConsumed = true
        return
    end
    if TryPauseSupplyAt(screenX, screenY) then
        metaPointerConsumed = true
        return
    end
    -- v0.11.0 鍟嗕笟鍖栵細涓昏彍鍗曞晢涓氬尯/鍔熻兘闈㈡澘浼樺厛娑堣垂鐐瑰嚮銆?
    if TryMenuMetaAt(screenX, screenY) then
        metaPointerConsumed = true
        return
    end
    metaPointerConsumed = false
    Game.PointerDown(x, y, pointerX, pointerY)
end

function HandleMouseUp(eventType, eventData)
    if eventData:GetInt("Button") ~= MOUSEB_LEFT then return end
    if not ClientMain.OwnsPointer("mouse") then return end
    ClientMain._pointer.source = ""
    Game.CancelHoldSpeed()
    -- 鎵€鏈変笟鍔℃彁鍓嶈繑鍥炲墠閲婃斁宸﹂敭鎸夊帇锛涘叾浠栭紶鏍囨寜閽笉褰卞搷瀹冦€?
    RenderBackend.SetPointerPressed(false)
    if talentScrollArmed then
        local moved = TalentTree.ScrollEnd()
        talentScrollArmed = false
        metaPointerConsumed = false
        if moved then return end
        local screenX, screenY = GetScreenCoordinates(eventData)
        local uiX, uiY = RenderBackend.ScreenToUi(screenX, screenY)
        HandleMetaPointerClick(uiX, uiY)
        return
    end
    if stageSelectScrollArmed then
        local moved = StageSelect.ScrollEnd()
        stageSelectScrollArmed = false
        metaPointerConsumed = false
        if moved then return end
        local screenX, screenY = GetScreenCoordinates(eventData)
        local uiX, uiY = RenderBackend.ScreenToUi(screenX, screenY)
        HandleMetaPointerClick(uiX, uiY)
        return
    end
    if Game.IsGameOver() then
        local screenX, screenY = GetScreenCoordinates(eventData)
        local uiX, uiY = RenderBackend.ScreenToUi(screenX, screenY)
        HandleGameOverPointerUp(uiX, uiY)
        return
    end
    if Game.IsStageWin() then
        local screenX, screenY = GetScreenCoordinates(eventData)
        local uiX, uiY = RenderBackend.ScreenToUi(screenX, screenY)
        HandleStageWinPointerUp(uiX, uiY)
        return
    end
    if Game.IsLevelUp() then return end
    local screenX, screenY = GetScreenCoordinates(eventData)
    if metaPointerConsumed then
        metaPointerConsumed = false
        return
    end
    if MenuMetaBlocksRelease() then return end
    local x, y = RenderBackend.ScreenToGame(screenX, screenY)
    local uiX, uiY = RenderBackend.ScreenToUi(screenX, screenY)
    Game.PointerUp(x, y, uiX, uiY)
end

function HandleMouseMove(eventType, eventData)
    ClientMain.ValidatePointer()
    if not ClientMain._pointer.focused or AdService.IsInFlight()
        or ClientMain._pointer.source == "touch" then return end
    -- v0.13.30c锛氬厛鍠傛寚閽堜綅缃粰鍚庣锛堟偓鍋滃彂鍏夌敤锛夛紝浠讳綍妯℃€佷笅閮借鏇存柊鈥斺€?
    -- 鎮仠鏄€屽叏灞€浜や簰鍙嶉銆嶏紝涓嶈琚嫋鎷?妯℃€佸垎鏀彁鍓?return 鎺夈€?
    local sx, sy = GetScreenCoordinates(eventData)
    local hx, hy = RenderBackend.ScreenToUi(sx, sy)
    RenderBackend.SetPointer(hx, hy)
    if not ClientMain.OwnsPointer("mouse") then return end
    -- v0.13.8锛氬ぉ璧嬫爲鎷栨嫿婊氬姩浼樺厛浜庝竴鍒囷紙鍏冨眰闈㈡澘鎵撳紑鏃?IsMetaCapturing 浼氭嫤涓嬪悗缁級銆?
    if talentScrollArmed then
        local _, uiY = RenderBackend.ScreenToUi(sx, sy)
        TalentTree.ScrollMove(uiY, designWidth_)
        return
    end
    if stageSelectScrollArmed then
        local _, uiY = RenderBackend.ScreenToUi(sx, sy)
        StageSelect.ScrollMove(uiY, designWidth_)
        return
    end
    if Game.IsLevelUp() or Game.IsGameOver() or Game.IsStageWin()
        or IsMetaCapturing() or metaPointerConsumed then return end
    local x, y = RenderBackend.ScreenToGame(sx, sy)
    Game.PointerMove(x, y, hx, hy)
end

function HandleTouchBegin(eventType, eventData)
    local screenX, screenY = GetScreenCoordinates(eventData)
    if not RenderBackend.IsInsideGameCanvas(screenX, screenY) then return end
    local touchId = eventData:GetInt("TouchID")
    if not ClientMain.ClaimPointer("touch", touchId) then return end
    local pointerX, pointerY = RenderBackend.ScreenToUi(screenX, screenY)
    if not RenderBackend.BeginTouchPointer(touchId, pointerX, pointerY) then
        ClientMain.CancelInput()
        return
    end
    -- v0.12.5锛氶《閮ㄩ€氱煡鏉℃案杩滄渶鍏堝悆瑙︽懜銆?
    if TryBannerAt(screenX, screenY) then
        metaPointerConsumed = true
        return
    end
    if Game.IsGameOver() then
        local uiX, uiY = RenderBackend.ScreenToUi(screenX, screenY)
        HandleGameOverPointerDown(uiX, uiY)
        return
    end
    if Game.IsStageWin() then
        local uiX, uiY = RenderBackend.ScreenToUi(screenX, screenY)
        HandleStageWinPointerDown(uiX, uiY)
        return
    end
    local x, y = RenderBackend.ScreenToGame(screenX, screenY)
    if Game.IsLevelUp() then
        local uiX, uiY = RenderBackend.ScreenToUi(screenX, screenY)
        if not TryPickUpgradeAt(uiX, uiY) then
            Presentation.PulseUpgradeHint()
        end
        return
    end
    -- v0.11.0 鍟嗕笟鍖栵細鏆傚仠琛ョ粰绔欐寜閽紭鍏堜簬銆岀偣浠绘剰澶勬仮澶嶃€嶃€?
    -- v0.12.5锛欻UD 鏆傚仠鎸夐挳涓庨亾鍏风珫鍒椾紭鍏堜簬鎷栨嫿璧锋墜銆?
    if TryHudPauseAt(screenX, screenY) then
        metaPointerConsumed = true
        return
    end
    if TryUseEnchantAt(screenX, screenY) then
        metaPointerConsumed = true
        return
    end
    if TryUseItemAt(screenX, screenY) then
        metaPointerConsumed = true
        return
    end
    if TryPauseSupplyAt(screenX, screenY) then
        metaPointerConsumed = true
        return
    end
    -- v0.11.0 鍟嗕笟鍖栵細涓昏彍鍗曞晢涓氬尯/鍔熻兘闈㈡澘浼樺厛娑堣垂瑙︽懜銆?
    if TryMenuMetaAt(screenX, screenY) then
        metaPointerConsumed = true
        return
    end
    metaPointerConsumed = false
    Game.PointerDown(x, y, pointerX, pointerY)
end

function HandleTouchMove(eventType, eventData)
    if not ClientMain.OwnsPointer("touch", eventData:GetInt("TouchID")) then return end
    -- 鍙Щ鍔ㄤ笟鍔′富瑙︾偣锛岄潪涓绘寚涔熶笉鑳芥敼鍙樻粴鍔ㄦ垨鐜╂硶杈撳叆銆?
    local tsx, tsy = GetScreenCoordinates(eventData)
    local thx, thy = RenderBackend.ScreenToUi(tsx, tsy)
    RenderBackend.MoveTouchPointer(eventData:GetInt("TouchID"), thx, thy)
    if talentScrollArmed then
        local _, uiY = RenderBackend.ScreenToUi(tsx, tsy)
        TalentTree.ScrollMove(uiY, designWidth_)
        return
    end
    if stageSelectScrollArmed then
        local _, uiY = RenderBackend.ScreenToUi(tsx, tsy)
        StageSelect.ScrollMove(uiY, designWidth_)
        return
    end
    if Game.IsLevelUp() or Game.IsGameOver() or Game.IsStageWin()
        or IsMetaCapturing() or metaPointerConsumed then return end
    local x, y = RenderBackend.ScreenToGame(tsx, tsy)
    Game.PointerMove(x, y, thx, thy)
end

function HandleTouchEnd(eventType, eventData)
    if not ClientMain.OwnsPointer("touch", eventData:GetInt("TouchID")) then return end
    ClientMain._pointer.source = ""
    Game.CancelHoldSpeed()
    -- 浠呬富瑙︾偣缁撴潫鏃舵竻鍙嶉锛岀敾甯冨鎴栫浜屾牴鎵嬫寚鐨勬姮璧蜂笉鑳藉彇娑堜富鎸囨寜鍘嬨€?
    RenderBackend.EndTouchPointer(eventData:GetInt("TouchID"))
    if talentScrollArmed then
        local moved = TalentTree.ScrollEnd()
        talentScrollArmed = false
        metaPointerConsumed = false
        if moved then return end
        local screenX, screenY = GetScreenCoordinates(eventData)
        local uiX, uiY = RenderBackend.ScreenToUi(screenX, screenY)
        HandleMetaPointerClick(uiX, uiY)
        return
    end
    if stageSelectScrollArmed then
        local moved = StageSelect.ScrollEnd()
        stageSelectScrollArmed = false
        metaPointerConsumed = false
        if moved then return end
        local screenX, screenY = GetScreenCoordinates(eventData)
        local uiX, uiY = RenderBackend.ScreenToUi(screenX, screenY)
        HandleMetaPointerClick(uiX, uiY)
        return
    end
    if Game.IsGameOver() then
        local screenX, screenY = GetScreenCoordinates(eventData)
        local uiX, uiY = RenderBackend.ScreenToUi(screenX, screenY)
        HandleGameOverPointerUp(uiX, uiY)
        return
    end
    if Game.IsStageWin() then
        local screenX, screenY = GetScreenCoordinates(eventData)
        local uiX, uiY = RenderBackend.ScreenToUi(screenX, screenY)
        HandleStageWinPointerUp(uiX, uiY)
        return
    end
    if Game.IsLevelUp() then return end
    local screenX, screenY = GetScreenCoordinates(eventData)
    if metaPointerConsumed then
        metaPointerConsumed = false
        return
    end
    if MenuMetaBlocksRelease() then return end
    local x, y = RenderBackend.ScreenToGame(screenX, screenY)
    local uiX, uiY = RenderBackend.ScreenToUi(screenX, screenY)
    Game.PointerUp(x, y, uiX, uiY)
end

function HandleKeyDown(eventType, eventData)
    if not ClientMain._pointer.focused or AdService.IsInFlight() then return end
    local key = eventData:GetInt("Key")
    if key == KEY_SPACE or key == KEY_RETURN then
        if Game.IsGameOver() then
            -- 閲嶅鎸夐敭涓庤繃娓℃湡鍥炶溅涓嶈兘鐩存帴閲嶅紑锛岃烦杩囪祫鏍间笌榧犳爣/瑙︽懜涓€鑷淬€?
            if StageTransition.IsActive(Game.GetSnapshot()) then
                if not eventData:GetBool("Repeat") then
                    StageTransition.Skip(Game.GetSnapshot())
                end
            elseif not eventData:GetBool("Repeat") then
                Game.RestartFromOver()
            end
        elseif Game.IsStageWin() then
            -- v0.13.4锛氳儨鍒╃粨绠楅〉瑕佹眰鏄惧紡鐐规寜閽紝鍥炶溅涓嶈嚜鍔ㄨ烦鍏?閲嶅紑銆?
        elseif gameSnapshot and gameSnapshot.state == "menu" then
            -- 涓昏彍鍗曞洖杞︿笌銆屽紑濮嬫垬鏂椼€岰TA 涓€鑷达細杩涢€夊叧鐣岄潰锛屼笉鍐嶇洿鎺ュ紑灞€銆?
            HandleMetaAction("open_stage_select", nil)
        else
            Game.HandleAction("start", true)
        end
    elseif key == KEY_P or key == KEY_ESCAPE then
        -- v0.11.0 鍟嗕笟鍖栵細ESC 鍏堝叧鍏冨眰闈㈡澘锛屽啀杞埌鏆傚仠銆?
        if metaState.screen then
            -- v0.13.56锛氭祴璇曟ā寮忚闂睆蹇呴』鏄惧紡閫夋嫨锛孍SC 绛夊悓銆屽惁 路 姝ｅ父寮€濮嬨€嶃€?
            if metaState.screen == "test_mode" then
                HandleMetaAction("test_mode_close", nil)
            else
                metaState.screen = nil
                RefreshMeta()
            end
        elseif metaState.supplyOpen then
            metaState.supplyOpen = false
        elseif Game.IsPaused() then
            Game.Resume()
        elseif not Game.IsLevelUp() and not Game.IsGameOver() and not Game.IsStageWin() then
            Game.Pause()
        end
    end
end

function HandleKeyUp(eventType, eventData)
    local key = eventData:GetInt("Key")
    if key == KEY_SPACE or key == KEY_RETURN then
        Game.HandleAction("start", false)
    end
end

return ClientMain
