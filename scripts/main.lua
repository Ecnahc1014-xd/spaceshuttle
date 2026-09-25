-- main.lua
-- 应用编排入口：桥接引擎事件、核心玩法、表现状态与可替换渲染后端。

local Game = require "Game"
local Presentation = require "Presentation"
local RenderBackend = require "Scene3DBackend"
local PlayerData = require "PlayerData"
local AdService = require "AdService"
local MetaCatalog = require "MetaCatalog"

local gameSnapshot = nil
local presentationSnapshot = nil
local lastSavedHighScore = 0
local reviveArmed = false
local doubleArmed = false
local restartArmed = false
local CLOUD_HIGH_SCORE_KEY = "high_score"
local CLOUD_META_KEY = "player_meta"
local metaCloudSynced = false

local function RefreshSnapshots()
    gameSnapshot = Game.GetSnapshot()
    presentationSnapshot = Presentation.GetSnapshot()
end

local function GetScreenCoordinates(eventData)
    return eventData:GetInt("X"), eventData:GetInt("Y")
end

local function SaveHighScoreToCloud(score)
    local n = math.floor(tonumber(score) or 0)
    if n <= lastSavedHighScore then return end
    lastSavedHighScore = n
    Presentation.SetCloudStatus("syncing")
    local okCall = pcall(function()
        clientCloud:SetInt(CLOUD_HIGH_SCORE_KEY, n, {
            ok = function()
                Presentation.SetCloudStatus("ok")
                print("[Main] cloud high_score saved=" .. tostring(n))
            end,
            error = function(code, reason)
                Presentation.SetCloudStatus("offline")
                print("[Main] cloud save failed: " .. tostring(reason) .. " code=" .. tostring(code))
            end,
        })
    end)
    if not okCall then
        Presentation.SetCloudStatus("offline")
        print("[Main] clientCloud unavailable, keep local high score")
    end
end

local function LoadHighScoreFromCloud()
    Presentation.SetCloudStatus("syncing")
    local okCall = pcall(function()
        clientCloud:Get(CLOUD_HIGH_SCORE_KEY, {
            ok = function(_, iscores)
                local cloudScore = 0
                if iscores and iscores[CLOUD_HIGH_SCORE_KEY] ~= nil then
                    cloudScore = math.floor(tonumber(iscores[CLOUD_HIGH_SCORE_KEY]) or 0)
                end
                lastSavedHighScore = math.max(lastSavedHighScore, cloudScore)
                Game.ApplyCloudHighScore(cloudScore)
                Presentation.SetCloudStatus("ok")
                RefreshSnapshots()
                print("[Main] cloud high_score loaded=" .. tostring(cloudScore))
            end,
            error = function(code, reason)
                Presentation.SetCloudStatus("offline")
                print("[Main] cloud load failed: " .. tostring(reason) .. " code=" .. tostring(code))
            end,
        })
    end)
    if not okCall then
        Presentation.SetCloudStatus("offline")
        print("[Main] clientCloud unavailable at start")
    end
end

-- v0.11.0 商业化：玩家元数据（零件/图鉴/签到/任务）云同步。
-- 云变量只在编排层读写；PlayerData 只负责编解码。
local function SavePlayerDataToCloud()
    local payload = PlayerData.ExportForCloud()
    pcall(function()
        clientCloud:Set(CLOUD_META_KEY, payload, {
            ok = function()
                metaCloudSynced = true
            end,
            error = function(code, reason)
                print("[Main] meta cloud save failed: " .. tostring(reason) .. " code=" .. tostring(code))
            end,
        })
    end)
end

local function LoadPlayerDataFromCloud()
    pcall(function()
        clientCloud:Get(CLOUD_META_KEY, {
            ok = function(values, _)
                local raw = nil
                if values then raw = values[CLOUD_META_KEY] end
                if type(raw) == "table" then raw = cjson.encode(raw) end
                if type(raw) == "string" and raw ~= "" then
                    PlayerData.ImportFromCloud(raw)
                    PlayerData.Save()
                    RefreshSnapshots()
                    print("[Main] player meta merged from cloud")
                end
                metaCloudSynced = true
            end,
            error = function(code, reason)
                print("[Main] meta cloud load failed: " .. tostring(reason) .. " code=" .. tostring(code))
            end,
        })
    end)
end

-- v0.11.0 商业化：所有激励视频统一走 AdService，保证一次性完成与防重复发奖。
---@param onReward fun()
local function ShowAd(onReward)
    local function fail(msg)
        Presentation.SetAdStatus(nil)
        Presentation.SetAdToast(msg)
        RefreshSnapshots()
    end
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
        Presentation.SetAdToast("本局已复活")
        return
    end
    ShowAd(function()
        if not Game.ReviveFromAd() then
            Presentation.SetAdToast("复活未能生效")
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
            Presentation.SetAdToast(string.format("双倍到账 +%d 零件", extra))
        end
    end)
end

-- ============================================================================
-- v0.11.0 商业化：元层界面（主菜单商业区 / 每日签到与补给 / 任务 / 图鉴 / 排行 / 商城 / 转盘）
-- 所有状态变更集中在此，MetaUI 只负责画。
-- ============================================================================

local META_TOAST_SECONDS = 2.4
local metaToastTimer = 0
local supplyPrompted = false

---@type MetaState
local metaState = {
    parts = 0,
    highScore = 0,
    screen = nil,
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
    rankList = {},
    rankLoading = false,
    rankTotal = 0,
    skins = {},
    selectedSkin = "default",
    giftUsed = {},
    wheelReady = false,
    wheelPrize = 0,
    toast = nil,
}

local function SetMetaToast(msg)
    metaState.toast = msg
    metaToastTimer = META_TOAST_SECONDS
end

local function RefreshMeta()
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
    metaState.codexUnlocked = PlayerData.CodexCount()
    metaState.codexTotal = MetaCatalog.GetCodexTotal()

    local skins = {}
    for _, skin in ipairs(MetaCatalog.GetSkins()) do
        if PlayerData.HasSkin(skin.key) then skins[skin.key] = true end
    end
    metaState.skins = skins
    metaState.selectedSkin = PlayerData.GetSelectedSkin()

    local giftUsed = {}
    for _, entry in ipairs(MetaCatalog.GetShopEntries()) do
        giftUsed[entry.key] = PlayerData.GetDailyCount("gift_" .. entry.key)
    end
    metaState.giftUsed = giftUsed
    metaState.wheelReady = PlayerData.GetDailyCount("wheel") == 0
end

-- 零件入账统一出口：写入 + 存档 + 云同步 + 刷新界面。
---@param amount integer
---@param label string|nil
local function GrantParts(amount, label)
    if amount <= 0 then return end
    PlayerData.AddParts(amount)
    PlayerData.Save()
    SavePlayerDataToCloud()
    RefreshMeta()
    if label then
        SetMetaToast(string.format("%s +%d 零件", label, amount))
    end
end

local function PersistMeta()
    PlayerData.Save()
    SavePlayerDataToCloud()
    RefreshMeta()
end

-- 全服排行榜：GetRankList 只返回 userId，昵称要再查一次 GetUserNickname。
local function FetchRankList()
    metaState.rankLoading = true
    metaState.rankList = {}
    pcall(function()
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
                        name = "玩家",
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
                SetMetaToast("排行榜暂不可用")
                print("[Main] rank list failed: " .. tostring(reason) .. " code=" .. tostring(code))
            end,
        })
        clientCloud:GetRankTotal(CLOUD_HIGH_SCORE_KEY, {
            ok = function(total)
                metaState.rankTotal = math.floor(total or 0)
            end,
        })
    end)
end

local function OpenMetaScreen(name)
    metaState.screen = name
    if name == "rank" then FetchRankList() end
    RefreshMeta()
end

local function HandleSignIn()
    if not PlayerData.CanSignIn() then
        SetMetaToast("今日已签到")
        return
    end
    local reward = PlayerData.SignIn()
    if reward > 0 then
        PersistMeta()
        SetMetaToast(string.format("签到成功 +%d 零件", reward))
    end
end

---@param mode string "claim" | "double"
local function HandleSupply(mode)
    if not metaState.supplyAvailable then
        metaState.supplyOpen = false
        SetMetaToast("今日补给已领取")
        return
    end
    if mode == "double" then
        ShowAd(function()
            PlayerData.AddDailyCount("supply", 1)
            metaState.supplyOpen = false
            GrantParts(metaState.supplyReward * 2, "每日补给 双倍")
        end)
        return
    end
    PlayerData.AddDailyCount("supply", 1)
    metaState.supplyOpen = false
    GrantParts(metaState.supplyReward, "每日补给")
end

---@param index integer
local function HandleClaimTask(index)
    local view = metaState.tasks[index]
    if not view then return end
    local reward = PlayerData.ClaimDaily(view.id)
    if reward > 0 then
        PersistMeta()
        SetMetaToast(string.format("任务完成 +%d 零件", reward))
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
        SetMetaToast("已切换为 " .. skin.name)
        return
    end
    if not PlayerData.SpendParts(skin.cost) then
        SetMetaToast("零件不足，还差 " .. tostring(skin.cost - PlayerData.GetParts()))
        return
    end
    PlayerData.UnlockSkin(skin.key)
    PlayerData.SelectSkin(skin.key)
    PersistMeta()
    SetMetaToast("已购买 " .. skin.name)
end

---@param index integer
local function HandleAdGift(index)
    local gifts = MetaCatalog.GetShopEntries()
    local gift = gifts[index]
    if not gift then return end
    local key = "gift_" .. gift.key
    local limit = MetaCatalog.GetAdGiftDailyLimit(gift.key)
    if PlayerData.GetDailyCount(key) >= limit then
        SetMetaToast("今日已领取")
        return
    end
    ShowAd(function()
        PlayerData.AddDailyCount(key, 1)
        GrantParts(MetaCatalog.GetAdGiftReward(gift.key), gift.name)
    end)
end

local function HandleWheelSpin()
    if not metaState.wheelReady then
        SetMetaToast("今日已抽取")
        return
    end
    ShowAd(function()
        PlayerData.AddDailyCount("wheel", 1)
        local prize = MetaCatalog.RollWheelPrize()
        metaState.wheelPrize = prize
        GrantParts(prize, "转盘奖励")
    end)
end

local function HandleMetaAction(action, index)
    if action == "close" then
        metaState.screen = nil
        RefreshMeta()
    elseif action == "open_shop" then
        OpenMetaScreen("shop")
    elseif action == "open_codex" then
        OpenMetaScreen("codex")
    elseif action == "open_tasks" then
        OpenMetaScreen("tasks")
    elseif action == "open_rank" then
        OpenMetaScreen("rank")
    elseif action == "signin" then
        HandleSignIn()
    elseif action == "supply" then
        if metaState.supplyAvailable then
            metaState.supplyOpen = true
        else
            SetMetaToast("今日补给已领取")
        end
    elseif action == "supply_claim" then
        HandleSupply("claim")
    elseif action == "supply_double" then
        HandleSupply("double")
    elseif action == "claim" and index then
        HandleClaimTask(index)
    elseif action == "buy_skin" and index then
        HandleShopSkin(index)
    elseif action == "ad_gift" and index then
        HandleAdGift(index)
    elseif action == "wheel_spin" then
        HandleWheelSpin()
    end
end

---@return boolean
local function IsMetaCapturing()
    return metaState.screen ~= nil or metaState.supplyOpen
end

-- 元层优先消费输入：弹窗 > 面板 > 主菜单商业区。
-- 返回 true 表示本次输入已被元层处理，玩法层不得再响应。
---@return boolean handled
local function HandleMetaPointerDown(uiX, uiY)
    if metaState.supplyOpen then
        local action = RenderBackend.HitTestSupplyPopup(uiX, uiY, metaState)
        if action then HandleMetaAction(action, nil) end
        return true
    end
    if metaState.screen then
        local action, index = RenderBackend.HitTestMetaScreen(uiX, uiY, metaState)
        if action then HandleMetaAction(action, index) end
        return true
    end
    local action = RenderBackend.HitTestMenuBar(uiX, uiY, metaState)
    if action then
        HandleMetaAction(action, nil)
        return true
    end
    return false
end

-- 主菜单上的元层点击（鼠标/触摸共用）。返回 true 表示本次输入已被元层消费。
---@param screenX number
---@param screenY number
---@return boolean handled
local function TryMenuMetaAt(screenX, screenY)
    if not gameSnapshot or gameSnapshot.state ~= "menu" then return false end
    local uiX, uiY = RenderBackend.ScreenToUi(screenX, screenY)
    return HandleMetaPointerDown(uiX, uiY)
end

-- 松手时若元层面板仍开着，禁止穿透成「点击开始」。
---@return boolean
local function MenuMetaBlocksRelease()
    return gameSnapshot ~= nil and gameSnapshot.state == "menu" and IsMetaCapturing()
end

-- v0.11.0 商业化：暂停补给站的看广告按钮。返回 true 表示点击已被消费（不触发恢复）。
---@return boolean handled
local function TryPauseSupplyAt(screenX, screenY)
    if not Game.IsPaused() then return false end
    local uiX, uiY = RenderBackend.ScreenToUi(screenX, screenY)
    local kind = RenderBackend.HitTestPausePanel(uiX, uiY, Game.GetSnapshot())
    if kind == "pause_heal" then
        if not Game.CanPauseHeal() then
            Presentation.SetAdToast("防线已满或急救已用完")
            return true
        end
        ShowAd(function()
            if Game.PauseHeal() then
                Presentation.SetAdToast("防线 +25 血")
            end
        end)
        return true
    elseif kind == "pause_rare" then
        if not Game.CanPauseRarePick() then
            Presentation.SetAdToast("本局已购买稀有保底")
            return true
        end
        ShowAd(function()
            if Game.PauseRarePick() then
                Presentation.SetAdToast("下次强化面板必出稀有")
            end
        end)
        return true
    end
    return false
end

-- 升级面板点击命中（v0.11.0 商业化）。
-- 几何完全由 Scene3DBackend.HitTestUpgradePanel 提供，与绘制同源，禁止在此另写常量。
local function TryPickUpgradeAt(uiX, uiY)
    local snapshot = Game.GetSnapshot()
    local kind, index = RenderBackend.HitTestUpgradePanel(uiX, uiY, snapshot)
    if kind == "card" and index then
        Game.PickUpgrade(index)
        return true
    elseif kind == "boost" and index then
        if not Game.CanBoostUpgrade(index) then
            Presentation.SetAdToast("该卡已升格")
            return true
        end
        ShowAd(function()
            if Game.BoostUpgrade(index) then
                Presentation.SetAdToast("已升格：该卡生效 ×2")
            end
        end)
        return true
    elseif kind == "reroll_free" then
        if Game.CanFreeReroll() then
            Game.RerollUpgrades("free")
            Presentation.SetAdToast("已免费重抽")
        else
            Presentation.SetAdToast("本局免费重抽已用完")
        end
        return true
    elseif kind == "reroll_ad" then
        ShowAd(function()
            Game.RerollUpgrades("ad")
            Presentation.SetAdToast("已重抽")
        end)
        return true
    elseif kind == "fourth" then
        if Game.CanUnlockFourthChoice() then
            ShowAd(function()
                if Game.UnlockFourthChoice() then
                    Presentation.SetAdToast("已解锁第 4 张")
                end
            end)
        else
            Presentation.SetAdToast("第 4 张已解锁")
        end
        return true
    elseif kind == "extra_pick" then
        if Game.CanArmExtraPick() then
            ShowAd(function()
                if Game.ArmExtraPick() then
                    Presentation.SetAdToast("本次可多选一张")
                end
            end)
        else
            Presentation.SetAdToast("本次已启用额外选卡")
        end
        return true
    end
    return false
end

local function HandleGameOverPointerDown(uiX, uiY)
    local hit = RenderBackend.HitTestGameOverButton(uiX, uiY, Game.GetSnapshot())
    reviveArmed = (hit == "revive")
    doubleArmed = (hit == "double")
    restartArmed = (hit == "restart")
    return hit ~= nil
end

local function HandleGameOverPointerUp(uiX, uiY)
    local hit = RenderBackend.HitTestGameOverButton(uiX, uiY, Game.GetSnapshot())
    if reviveArmed and hit == "revive" then
        reviveArmed = false
        doubleArmed = false
        restartArmed = false
        ShowReviveAd()
        return true
    end
    if doubleArmed and hit == "double" then
        reviveArmed = false
        doubleArmed = false
        restartArmed = false
        if Game.CanDoubleSettle() then
            ShowDoublePartsAd()
        else
            Presentation.SetAdToast("本局零件已翻倍")
        end
        return true
    end
    if restartArmed and hit == "restart" then
        reviveArmed = false
        doubleArmed = false
        restartArmed = false
        Game.RestartFromOver()
        RefreshSnapshots()
        return true
    end
    reviveArmed = false
    doubleArmed = false
    restartArmed = false
    return false
end

function Start()
    graphics.windowTitle = "击碎，飞机大战"
    input.mouseVisible = true

    if not RenderBackend.Init("HandleRender") then return end

    PlayerData.Load()

    local width, height = RenderBackend.GetDesignSize()
    Game.Init({
        width = width, height = height, seed = os.time(),
        highScore = PlayerData.GetHighScore(),
    })
    Presentation.Init()
    RefreshSnapshots()
    RefreshMeta()
    LoadHighScoreFromCloud()
    LoadPlayerDataFromCloud()

    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("MouseButtonDown", "HandleMouseDown")
    SubscribeToEvent("MouseButtonUp", "HandleMouseUp")
    SubscribeToEvent("MouseMove", "HandleMouseMove")
    SubscribeToEvent("TouchBegin", "HandleTouchBegin")
    SubscribeToEvent("TouchMove", "HandleTouchMove")
    SubscribeToEvent("TouchEnd", "HandleTouchEnd")
    SubscribeToEvent("KeyDown", "HandleKeyDown")
    SubscribeToEvent("KeyUp", "HandleKeyUp")
    SubscribeToEvent("ScreenMode", "HandleScreenMode")

    print("[Main] rendering, ads and cloud save connected")
end

function Stop()
    RenderBackend.Shutdown()
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = math.min(eventData:GetFloat("TimeStep"), 0.05)
    AdService.Update(dt)
    local hitStop = Presentation.GetSnapshot().hitStop or 0
    local gameDt = dt
    if hitStop > 0 then gameDt = dt * 0.15 end
    Game.Update(gameDt)
    local snapshot = Game.GetSnapshot()
    Presentation.Update(dt, snapshot, Game.DrainEvents())
    gameSnapshot = snapshot
    presentationSnapshot = Presentation.GetSnapshot()
    RenderBackend.UpdateScene(gameSnapshot, presentationSnapshot)
    if snapshot.highScore and snapshot.highScore > lastSavedHighScore then
        SaveHighScoreToCloud(snapshot.highScore)
    end

    -- v0.11.0 商业化：元层提示计时与「回到主菜单自动弹每日补给」。
    if metaToastTimer > 0 then
        metaToastTimer = metaToastTimer - dt
        if metaToastTimer <= 0 then metaState.toast = nil end
    end
    if snapshot.state == "menu" then
        if not supplyPrompted and metaState.supplyAvailable then
            supplyPrompted = true
            metaState.supplyOpen = true
        end
    else
        -- 离开主菜单时收起所有元层界面，避免带着面板进局。
        metaState.screen = nil
        metaState.supplyOpen = false
    end

    -- v0.11.0 商业化：结算页一出现就按 ×1 把本局零件入库（幂等，同帧只结算一次）。
    if snapshot.state == "gameover" then
        local granted = Game.SettleParts(1)
        if granted > 0 then
            PlayerData.AddParts(granted)
            PlayerData.AddDailyProgress("break_bricks", math.floor(snapshot.bricksBroken or 0))
            PlayerData.AddDailyProgress("reach_wave", math.floor(snapshot.wave or 1), true)
            PlayerData.AddDailyProgress("play_runs", 1)
            PlayerData.SetHighScore(math.floor(snapshot.highScore or 0))
            -- 清掉过哪些机型就解锁哪些图鉴，首次收录额外发零件。
            local bonus = 0
            for _, key in ipairs(snapshot.runAircraft or {}) do
                if PlayerData.UnlockCodex(key) then
                    local entry = MetaCatalog.GetCodexEntry(key)
                    if entry then bonus = bonus + entry.reward end
                    print("[Main] codex unlocked: " .. key)
                end
            end
            if bonus > 0 then PlayerData.AddParts(bonus) end
            PlayerData.Save()
            SavePlayerDataToCloud()
            RefreshMeta()
            print("[Main] run settled, parts +" .. granted .. ", codex bonus +" .. bonus)
        end
    end
end

function HandleRender()
    if gameSnapshot and presentationSnapshot then
        RenderBackend.RenderOverlay(gameSnapshot, presentationSnapshot, metaState)
    end
end

function HandleScreenMode()
    RenderBackend.Resize()
end

function HandleMouseDown(eventType, eventData)
    if eventData:GetInt("Button") ~= MOUSEB_LEFT then return end
    local screenX, screenY = GetScreenCoordinates(eventData)
    if not RenderBackend.IsInsideGameCanvas(screenX, screenY) then return end
    if Game.IsGameOver() then
        local uiX, uiY = RenderBackend.ScreenToUi(screenX, screenY)
        HandleGameOverPointerDown(uiX, uiY)
        return
    end
    local x, y = RenderBackend.ScreenToGame(screenX, screenY)
    if Game.IsLevelUp() then
        local uiX, uiY = RenderBackend.ScreenToUi(screenX, screenY)
        -- v0.10.24：点在卡片外不关闭面板也不穿透，轻脉冲提示必须三选一。
        if not TryPickUpgradeAt(uiX, uiY) then
            Presentation.PulseUpgradeHint()
        end
        return
    end
    -- v0.11.0 商业化：暂停补给站按钮优先于「点任意处恢复」。
    if TryPauseSupplyAt(screenX, screenY) then return end
    -- v0.11.0 商业化：主菜单商业区/功能面板优先消费点击。
    if TryMenuMetaAt(screenX, screenY) then return end
    Game.PointerDown(x, y)
end

function HandleMouseUp(eventType, eventData)
    if eventData:GetInt("Button") ~= MOUSEB_LEFT then return end
    if Game.IsGameOver() then
        local screenX, screenY = GetScreenCoordinates(eventData)
        local uiX, uiY = RenderBackend.ScreenToUi(screenX, screenY)
        HandleGameOverPointerUp(uiX, uiY)
        return
    end
    -- v0.10.24：升级态的按下已在 Down 分支消费，禁止其穿透成玩法 PointerUp。
    if Game.IsLevelUp() then return end
    local screenX, screenY = GetScreenCoordinates(eventData)
    if MenuMetaBlocksRelease() then return end
    local x, y = RenderBackend.ScreenToGame(screenX, screenY)
    Game.PointerUp(x, y)
end

function HandleMouseMove(eventType, eventData)
    if Game.IsLevelUp() or Game.IsGameOver() then return end
    local screenX, screenY = GetScreenCoordinates(eventData)
    local x, y = RenderBackend.ScreenToGame(screenX, screenY)
    Game.PointerMove(x, y)
end

function HandleTouchBegin(eventType, eventData)
    local screenX, screenY = GetScreenCoordinates(eventData)
    if not RenderBackend.IsInsideGameCanvas(screenX, screenY) then return end
    if Game.IsGameOver() then
        local uiX, uiY = RenderBackend.ScreenToUi(screenX, screenY)
        HandleGameOverPointerDown(uiX, uiY)
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
    -- v0.11.0 商业化：暂停补给站按钮优先于「点任意处恢复」。
    if TryPauseSupplyAt(screenX, screenY) then return end
    -- v0.11.0 商业化：主菜单商业区/功能面板优先消费触摸。
    if TryMenuMetaAt(screenX, screenY) then return end
    Game.PointerDown(x, y)
end

function HandleTouchMove(eventType, eventData)
    if Game.IsLevelUp() or Game.IsGameOver() then return end
    local screenX, screenY = GetScreenCoordinates(eventData)
    local x, y = RenderBackend.ScreenToGame(screenX, screenY)
    Game.PointerMove(x, y)
end

function HandleTouchEnd(eventType, eventData)
    if Game.IsGameOver() then
        local screenX, screenY = GetScreenCoordinates(eventData)
        local uiX, uiY = RenderBackend.ScreenToUi(screenX, screenY)
        HandleGameOverPointerUp(uiX, uiY)
        return
    end
    if Game.IsLevelUp() then return end
    local screenX, screenY = GetScreenCoordinates(eventData)
    if MenuMetaBlocksRelease() then return end
    local x, y = RenderBackend.ScreenToGame(screenX, screenY)
    Game.PointerUp(x, y)
end

function HandleKeyDown(eventType, eventData)
    local key = eventData:GetInt("Key")
    if key == KEY_SPACE or key == KEY_RETURN then
        if Game.IsGameOver() then
            Game.RestartFromOver()
        else
            Game.HandleAction("start", true)
        end
    elseif key == KEY_P or key == KEY_ESCAPE then
        -- v0.11.0 商业化：ESC 先关元层面板，再轮到暂停。
        if metaState.screen then
            metaState.screen = nil
            RefreshMeta()
        elseif metaState.supplyOpen then
            metaState.supplyOpen = false
        elseif Game.IsPaused() then
            Game.Resume()
        elseif not Game.IsLevelUp() and not Game.IsGameOver() then
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
