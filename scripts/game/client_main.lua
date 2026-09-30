-- game/client_main.lua
-- 客户端玩法编排：桥接引擎事件、核心玩法、表现状态与可替换渲染后端。
--
-- ⚠️ 引擎通过脚本名解析事件处理器，所以 HandleUpdate / HandleRender / HandleMouse* /
--    HandleTouch* / HandleKey* 必须保持**文件级全局** function（不能加 local），
--    否则 SubscribeToEvent("Update", HandleUpdate) 会静默失效。
-- ⚠️ 本文件不做联机权威：战斗、排行榜、养成存档都在客户端（clientCloud + 本地存档）；
--    服务端只管 IAP 发货与氪金代币余额（见 network/Server.lua）。

local Game = require "Game"
local Presentation = require "Presentation"
local RenderBackend = require "Scene3DBackend"
local PlayerData = require "PlayerData"
local AdService = require "AdService"
local MetaCatalog = require "MetaCatalog"
local AircraftPixelData = require "AircraftPixelData"
local StageCatalog = require "StageCatalog"
local TalentCatalog = require "TalentCatalog"
local GameMode = require "GameMode"
local NetClient = require "network.Client"
local MetaUI = require "MetaUI"
local RechargeShop = require "ui.RechargeShop"
local StageSelect = require "ui.StageSelect"
local TalentTree = require "ui.TalentTree"
local Shared = require "network.Shared"
local SysNotif = require "urhox-libs.System.SystemNotification"

local ClientMain = {}

-- 钻石商品价格缓存：sku -> 元（来自 Shop.getProducts()，离线/未开通时为空）
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
-- v0.13.4：胜利结算页松手确认（避免误触直接跳关）。
local stageWinArmed = nil
local metaPointerConsumed = false
local CLOUD_HIGH_SCORE_KEY = "high_score"
local CLOUD_META_KEY = "player_meta"
local metaCloudSynced = false
local metaRevision = 0
local metaSaveInFlight = false
local RefreshMeta

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
                Presentation.SetCloudStatus("unavailable")
                print("[Main] cloud save failed: " .. tostring(reason) .. " code=" .. tostring(code))
            end,
        })
    end)
    if not okCall then
        Presentation.SetCloudStatus("unavailable")
        print("[Main] clientCloud unavailable, keep local high score")
    end
end

local function LoadHighScoreFromCloud()
    if GameMode.IsOffline() then
        Presentation.SetCloudStatus("unavailable")
        print("[Main] offline: skip cloud high score")
        return
    end
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
                Presentation.SetCloudStatus("unavailable")
                print("[Main] cloud load failed: " .. tostring(reason) .. " code=" .. tostring(code))
            end,
        })
    end)
    if not okCall then
        Presentation.SetCloudStatus("unavailable")
        print("[Main] clientCloud unavailable at start")
    end
end

-- v0.11.0 商业化：玩家元数据（零件/图鉴/签到/任务）云同步。
-- 云变量只在编排层读写；PlayerData 只负责编解码。
local function SavePlayerDataToCloud()
    if GameMode.IsOffline() then return end
    metaRevision = metaRevision + 1
    -- 初次云档读取尚未完成时仅记脏；先写会把另一台设备的档案覆盖掉。
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
    if GameMode.IsOffline() then
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
                    local merged = PlayerData.ImportFromCloud(raw)
                    if merged then
                        PlayerData.Save()
                        RefreshSnapshots()
                        RefreshMeta()
                        metaCloudSynced = true
                        if metaRevision ~= requestRevision or PlayerData.ExportForCloud() ~= raw then
                            SavePlayerDataToCloud()
                        end
                        print("[Main] player meta merged from cloud")
                    end
                else
                    -- 云端尚无档案时把本地进度上传，避免换设备后找不到已有存档。
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
    -- 选关界面（v0.13.4）：星级 + 已解锁范围 + 关卡总数，供 StageSelect 只读渲染。
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
    giftUsed = {},
    wheelReady = false,
    wheelPrize = 0,
    toast = nil,
    -- 联机 / 氪金代币
    offline = false,
    productsAvailable = false,
    prices = {},
    rechargeToast = nil,
}

-- v0.12.5：平台系统通知换皮（dark-tech 顶部通知条），不再允许默认白底弹窗直出。
-- ⚠️ 全局只有一个 handler 槽；大厅/游戏是两个 Runtime，切换后各自注册。
local function installSystemNotificationHandler()
    pcall(function()
        SysNotif.RegisterHandler(function(info)
            local ok, view = pcall(function() return SysNotif.Resolve(info) end)
            if not ok or type(view) ~= "table" then return false end
            local tone = view.kind == "error" and "error" or "warn"
            local message = view.message or ""
            if view.reason and view.reason ~= "" then
                message = message .. " 原因：" .. view.reason
            end
            RenderBackend.ShowSystemBanner({
                title = view.title or "连接提示",
                message = message,
                tone = tone,
                ttl = 15,
                -- 连接检查/重连类（error）只提示不劝退；被踢/弹窗类给退出出口。
                actionText = view.kind == "error" and nil or "退出",
                actionId = "banner_exit",
            })
            print("[Main] system notification banner: " .. tostring(view.id)
                .. " kind=" .. tostring(view.kind))
            return true
        end)
    end)
end

-- v0.12.7：删除「主菜单自动弹付费轨通知条 + 自动弹每日补给」两处启动打扰
-- （用户否决：开局首充弹窗）。付费轨解锁入口收回战斗档案面板与钻石兑换，
-- 玩家主动打开才见；后端 SystemBanner 通道保留，仅供平台 SystemNotification 换皮用。

-- 顶端通知条动作处理：真正的函数体在 HandleMetaAction 定义后赋值（同文件 local
-- 前向引用问题：upvalue 同一变量，运行时才取函数体，TryBannerAt 闭包引用不受影响）。
local onBannerAction = nil

-- 拉一次钻石商品列表（价格来自平台，离线/未开通时为空）。
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

    -- 选关界面数据（v0.13.4）：逐关星级 + 已解锁范围。
    local stageStars = {}
    for stage = 1, StageCatalog.STAGE_COUNT do
        stageStars[stage] = PlayerData.GetStageStars(stage)
    end
    metaState.stageStars = stageStars
    metaState.maxStage = PlayerData.GetMaxStage()
    metaState.stageTotal = StageCatalog.STAGE_COUNT

    -- 天赋树界面数据（v0.13.5）：已解锁节点 + 星级汇总。
    metaState.talents = PlayerData.GetTalents()
    metaState.totalStars = PlayerData.GetTotalStars()
    metaState.talentCount = PlayerData.TalentCount()
    metaState.talentTotal = #TalentCatalog.GetNodes()
    metaState.talentMaxStage = TalentCatalog.MAX_STAGE
    metaState.talentStageCount = TalentCatalog.GetUnlockedStageCount(metaState.totalStars)
    -- 是否有「当前可负担且前置满足」的节点（菜单红点）。
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
    -- 首充礼包：限时窗内且未购买（服务端权威已购标志 + 本地已补发标志都不再展示）。
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
        if #rewards >= 5 then break end
    end
    metaState.passRewards = rewards
    metaState.passClaimable = metaState.passLevel > claimed
    metaState.offline = GameMode.IsOffline()
    metaState.gems = GameMode.IsOffline() and metaState.gems or NetClient.GetGems()
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
    if GameMode.IsOffline() then
        metaState.rankLoading = false
        metaState.myRankLoading = false
        metaState.myRank = nil
        metaState.rankList = {}
        SetMetaToast("联网后可用排行榜")
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
    if not PlayerData.PurchaseSkin(skin.key, skin.cost) then
        SetMetaToast("零件不足，还差 " .. tostring(math.max(0, skin.cost - PlayerData.GetParts())))
        return
    end
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

-- 钻石兑换：服务端事务原子扣钻并记录累计零件；客户端按权威累计额补领。
---@param index integer
local function HandleGemSpend(index)
    local def = Shared.GEM_SPENDS[index]
    if not def then return end
    if GameMode.IsOffline() then
        metaState.rechargeToast = "需联网后可用"
        return
    end
    -- 下一次成功的余额请求会推送权威累计额并补领；每次进商店也会重新拉取。
    metaState.rechargeToast = "扣款中…"
    NetClient.SpendGems(def.key, function(ok, reason)
        if ok then
            -- 等待服务端同步累计额再补领，不从单次成功回调直接入账。
            NetClient.RequestBalance()
            metaState.rechargeToast = "兑换成功，零件同步中…"
        elseif reason == "pending" then
            metaState.rechargeToast = "上一笔兑换尚未确认，请勿重复点击"
        elseif reason == "unknown" then
            metaState.rechargeToast = "结果待确认，请重新进入游戏对账，勿重复兑换"
        elseif reason == "insufficient" then
            metaState.rechargeToast = "钻石不足"
        else
            metaState.rechargeToast = "扣款失败，请重试"
        end
        RefreshMeta()
    end)
end

---@param index integer
local function HandleGemPurchase(index)
    local pack = Shared.GEM_PACKS[index]
    if not pack then return end
    if GameMode.IsOffline() then
        metaState.rechargeToast = "需联网后可用"
        return
    end
    if not productsAvailable_ then
        metaState.rechargeToast = "内购未开通或暂无商品"
        return
    end
    metaState.rechargeToast = "正在拉起支付…"
    NetClient.Purchase(pack.sku, function(ok, reason)
        if ok then
            -- 只是弹窗已拉起；发货由服务端异步完成，到账后会推余额。
            metaState.rechargeToast = "支付完成后钻石自动到账"
        else
            metaState.rechargeToast = "购买失败：" .. tostring(reason)
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
            metaState.rechargeToast = "需联网后可用"
        elseif not productsAvailable_ then
            metaState.rechargeToast = "内购未开通或暂无商品"
        else
            metaState.rechargeToast = "正在拉起支付…"
            NetClient.Purchase(Shared.FIRST_GIFT.sku, function(ok, reason)
                if ok then
                    -- 发货由服务端异步完成；钻石/礼包标志到账后推送刷新展示。
                    metaState.rechargeToast = "支付完成后礼包自动到账"
                else
                    metaState.rechargeToast = "购买失败：" .. tostring(reason)
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
        metaState.rechargeToast = GameMode.IsOffline() and "仍处于离线模式" or "已刷新"
        return true
    end
    return false
end

local function HandleMetaAction(action, index)
    if HandleRechargeAction(action, index) then return end
    if action == "close" then
        metaState.screen = nil
        RefreshMeta()
    elseif action == "open_stage_select" then
        OpenMetaScreen("stage_select")
    elseif action == "open_talent" then
        OpenMetaScreen("talent")
    elseif action == "unlock_talent" and index then
        -- 天赋树节点解锁：TalentCatalog 校验前置/星级/零件，PlayerData 落盘。
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
                    SetMetaToast(string.format("已解锁「%s」", node.name))
                    print("[Main] talent unlocked: " .. nodeId)
                end
            else
                local msg = (reason == "stars" and "星级不足，尚未开放该阶段")
                    or (reason == "prereq" and "需先解锁同一线路的上一阶段")
                    or (reason == "parts" and "零件不足")
                    or (reason == "owned" and "已解锁")
                    or "无法解锁"
                SetMetaToast(msg)
            end
            RefreshMeta()
        end
    elseif action == "play_stage" and index then
        -- 选关界面点某关：解锁校验（StageSelect 命中已过滤，这里兜底），关面板后开该关。
        if PlayerData.IsStageUnlocked(index) then
            metaState.screen = nil
            Game.StartStageAt(index)
            RefreshSnapshots()
            print("[Main] start stage from select: " .. tostring(index))
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
    elseif action == "open_wheel" then
        OpenMetaScreen("wheel")
    elseif action == "open_pass" then
        OpenMetaScreen("pass")
    elseif action == "claim_pass" and index then
        local reward = PlayerData.ClaimPass(index, metaState.premiumPass and 2 or 1)
        if reward > 0 then
            PersistMeta()
            SetMetaToast(string.format("战斗档案 +%d 零件", reward))
        end
    elseif action == "buy_premium_pass" then
        if GameMode.IsOffline() then
            SetMetaToast("需联网后可用")
        else
            SetMetaToast("扣款中…")
            NetClient.SpendGems("pass_premium", function(ok, reason)
                if ok then
                    NetClient.RequestBalance()
                    SetMetaToast("付费档案轨已解锁")
                elseif reason == "pending" then
                    SetMetaToast("上一笔兑换尚未确认，请稍候")
                elseif reason == "unknown" then
                    SetMetaToast("结果待确认，请重新进入游戏对账")
                elseif reason == "already_owned" then
                    SetMetaToast("付费档案轨已解锁")
                else
                    SetMetaToast("扣款失败，请重试")
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

-- v0.12.5：顶端通知条动作处理（在此赋值，函数体引用 HandleMetaAction）。
onBannerAction = function(actionId)
    if actionId == "buy_premium_pass" then
        -- 扣款走服务端异步回调，结果由 metaToast 呈现；通知条先收起避免重复点击。
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
    -- v0.13.4：主菜单「开始战斗」CTA 打开选关界面（不再直接开局）。
    if gameSnapshot and RenderBackend.HitTestMenuCta(uiX, uiY, gameSnapshot) then
        HandleMetaAction("open_stage_select", nil)
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

-- v0.12.5：HUD 右上角暂停按钮（移动端唯一暂停入口）。返回 true 表示已消费。
---@return boolean handled
local function TryHudPauseAt(screenX, screenY)
    if not gameSnapshot or gameSnapshot.state ~= "playing" then return false end
    local uiX, uiY = RenderBackend.ScreenToUi(screenX, screenY)
    if not RenderBackend.HitTestHudPause(uiX, uiY, gameSnapshot) then return false end
    Game.Pause()
    RefreshSnapshots()
    return true
end

-- v0.12.5：局内道具右上角竖列。收起态点标签展开；展开态点槽位用道具或看广告领取。
-- 返回 true 表示点击已被消费（不再穿透成拖拽起手）。
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
        Game.UseItem(item.key)   -- 效果与飘字都由规则层事件驱动
        return true
    end
    if item.canGrant then
        ShowAd(function()
            if Game.GrantItem(item.key) then
                print("[Main] item granted via ad: " .. item.key)
                -- 发放成功后保持展开，让玩家看到新入手的道具
                RenderBackend.SetItemPanelOpen(true)
            end
        end)
        return true
    end
    Presentation.SetAdToast(item.name .. " 本局已领取")
    return true
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
    elseif kind == "pause_orbital" then
        if not Game.CanPauseOrbital() then
            Presentation.SetAdToast("只在首领在场且本局未支援时可用")
            return true
        end
        ShowAd(function()
            if Game.PauseOrbital() then Presentation.SetAdToast("轨道支援已轰击首领") end
        end)
        return true
    elseif kind == "pause_reload" then
        if not Game.CanPauseReload() then
            Presentation.SetAdToast("本局弹药补给已领取")
            return true
        end
        ShowAd(function()
            if Game.PauseReload() then Presentation.SetAdToast("已补充一辆重卡") end
        end)
        return true
    elseif kind == "pause_parts_boost" then
        if not Game.CanPausePartsBoost() then
            Presentation.SetAdToast("本局零件加倍已领取")
            return true
        end
        ShowAd(function()
            if Game.PausePartsBoost() then Presentation.SetAdToast("零件 ×2 生效 45 秒") end
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

-- 升级面板点击命中（v0.12.5 精简：只有选卡 / 锁定 / 免费重抽 / 看广告重抽）。
-- 几何完全由 Scene3DBackend.HitTestUpgradePanel 提供，与绘制同源，禁止在此另写常量。
local function TryPickUpgradeAt(uiX, uiY)
    local snapshot = Game.GetSnapshot()
    local kind, index = RenderBackend.HitTestUpgradePanel(uiX, uiY, snapshot)
    if kind == "card" and index then
        Game.PickUpgrade(index)
        return true
    elseif kind == "hold" and index then
        if Game.ToggleHeldUpgrade(index) then
            Presentation.SetAdToast("已切换保留卡，下一次升级优先出现")
        end
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
            if Game.RerollUpgrades("ad_rare") then
                Presentation.SetAdToast("已重抽，本次必有稀有强化")
            end
        end)
        return true
    end
    return false
end

local function HandleGameOverPointerDown(uiX, uiY)
    local hit = RenderBackend.HitTestGameOverButton(uiX, uiY, Game.GetSnapshot())
    reviveArmed = (hit == "revive")
    doubleArmed = (hit == "double")
    restartArmed = (hit == "restart")
    -- v0.12.5：结算页「回主菜单」出口（同样松手确认，防死亡瞬间误触）
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
            Presentation.SetAdToast("本局零件已翻倍")
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

-- v0.13.4：胜利结算页（stagewin）松手确认。Down 只武装命中的按钮，Up 时才真正跳关/重开/回菜单。
local function HandleStageWinPointerDown(uiX, uiY)
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
        Game.RetryStage()
    elseif armed == "menu" then
        Game.GoToMenu()
    end
    RefreshSnapshots()
    return true
end

local started_ = false

-- 离线降级：云能力（云存档/排行榜/余额）在单机路径上全部短路，只读本地。
---@param opts table|nil { offline = boolean }
function ClientMain.Start(opts)
    -- 自建大厅五秒超时先本地启动了游戏；若引擎随后仍完成脚本切换再调一次 Start，
    -- 重复订阅会让 Game.Update 每帧跑两遍。此处幂等保护，保持已运行的本地局不变。
    if started_ then
        print("[ClientMain] already started, ignore duplicate entry")
        return true
    end
    opts = opts or {}
    if opts.offline ~= nil then
        GameMode.SetOffline(opts.offline == true)
    end

    graphics.windowTitle = "击碎，飞机大战"
    input.mouseVisible = true

    if not RenderBackend.Init() then return false end

    -- v0.12.5：平台通知换皮（v0.12.7：付费轨自动曝光已删，无需状态复位）。
    installSystemNotificationHandler()

    -- v0.11.0 联机：充值弹层复用游戏 UI 的令牌与原语（UI 无污染）。
    RechargeShop.Init(MetaUI.GetDeps())
    MetaUI.RegisterScreen("recharge", RechargeShop.Draw, RechargeShop.HitTest)
    -- v0.13.4：选关界面同样复用游戏令牌（插件式注册，不反向依赖渲染后端）。
    StageSelect.Init(MetaUI.GetDeps())
    MetaUI.RegisterScreen("stage_select", StageSelect.Draw, StageSelect.HitTest)
    -- v0.13.5：天赋树界面同源注册。
    TalentTree.Init(MetaUI.GetDeps())
    MetaUI.RegisterScreen("talent", TalentTree.Draw, TalentTree.HitTest)

    PlayerData.Load()
    -- 开局自动拥有初始分裂车的「允许局内出场」节点（幂等；必须在 Load 之后）。
    PlayerData.EnsureAutoOwnedTalents(TalentCatalog.AUTO_OWNED)
    -- v0.13.5：天赋提供者——每次开局（选关/下一关/重开）Game 自动拉取最新解锁集合。
    Game.SetTalentProvider(function() return PlayerData.GetTalents() end)
    metaDate = os.date("%Y-%m-%d")
    -- ⚠️ 全程 pcall：联机层任何异常都不允许中断游戏启动
    --    （曾经因为 NetClient.Start 为 nil，在这里抛出，导致后面的事件订阅全部没执行，
    --     真机表现为「3D 正常但 2D 界面全没」）。
    -- 离线降级时整层不加载；在线路径才启用余额同步。
    -- ⚠️ 全程 pcall：联机层任何异常都不允许中断游戏启动（否则后续事件订阅全不执行，
    --    真机表现为「3D 正常但 2D 界面全没」）。
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
                    metaState.rechargeToast = string.format("兑换零件到账 +%d", granted)
                    print("[Main] purchased parts recovered +" .. granted .. " total=" .. total)
                end
                -- 首充礼包发货：服务端标志为真且本地未补发时，发一次车型与零件。
                if firstGift and not PlayerData.IsFirstGiftClaimed() then
                    PlayerData.AddParts(Shared.FIRST_GIFT.parts)
                    PlayerData.UnlockSkin(Shared.FIRST_GIFT.skin)
                    PlayerData.MarkFirstGiftClaimed()
                    SavePlayerDataToCloud()
                    metaState.rechargeToast = "新手礼包已到账"
                    print("[Main] first gift delivered: parts+" .. Shared.FIRST_GIFT.parts
                        .. " skin=" .. Shared.FIRST_GIFT.skin)
                end
                -- 每次权威推送都刷新付费轨/首充标志（服务端随同一事件带 premium/first_gift）。
                RefreshMeta()
            end)
            NetClient.Start()
        end)
        if not okNet then
            print("[ClientMain] network layer failed, degrade to offline: " .. tostring(errNet))
            GameMode.SetOffline(true)
        end
    end

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

    print("[Main] rendering, ads and cloud save connected")
    started_ = true
    return true
end

function ClientMain.Stop()
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

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = math.min(eventData:GetFloat("TimeStep"), 0.05)
    AdService.Update(dt)
    if not GameMode.IsOffline() then NetClient.Update(dt) end
    local hitStop = Presentation.GetSnapshot().hitStop or 0
    local gameDt = dt
    if hitStop > 0 then gameDt = dt * 0.15 end
    -- v0.12.5：激励视频在途时冻结玩法推进（浏览器 embed 覆盖时游戏循环仍在跑，
    -- 广告回来敌人已压到防线）。表现层照常衰减，快照不变 = 画面静止。
    -- 结算/升级/暂停态的广告本就不推进玩法，无需重复处理。
    local adFreeze = AdService.IsInFlight()
        and gameSnapshot ~= nil and gameSnapshot.state == "playing"
    if not adFreeze then
        Game.Update(gameDt)
    end
    local snapshot = Game.GetSnapshot()
    Presentation.Update(dt, snapshot, Game.DrainEvents())
    gameSnapshot = snapshot
    presentationSnapshot = Presentation.GetSnapshot()
    RenderBackend.UpdateScene(gameSnapshot, presentationSnapshot, metaState)
    if not GameMode.IsOffline() and snapshot.highScore and snapshot.highScore > lastSavedHighScore then
        SaveHighScoreToCloud(snapshot.highScore)
    end

    -- 跨午夜时同步刷新菜单上的签到/任务/补给/转盘状态。
    local today = os.date("%Y-%m-%d")
    if today ~= metaDate then
        metaDate = today
        PlayerData.RollDaily()
        PlayerData.Save()
        SavePlayerDataToCloud()
        RefreshMeta()
        print("[Main] daily state refreshed: " .. today)
    end
    -- v0.11.0 商业化：元层提示计时与「回到主菜单自动弹每日补给」。
    if metaToastTimer > 0 then
        metaToastTimer = metaToastTimer - dt
        if metaToastTimer <= 0 then metaState.toast = nil end
    end
    if snapshot.state ~= "menu" then
        -- 离开主菜单时收起所有元层界面，避免带着面板进局。
        metaState.screen = nil
        metaState.supplyOpen = false
    end

    -- v0.11.0 商业化：结算页一出现就按 ×1 把本局零件入库（幂等，同帧只结算一次）。
    -- v0.13.4：胜利结算（stagewin）同样入库，并记录该关星级 + 解锁下一关。
    if (snapshot.state == "gameover" or snapshot.state == "stagewin") and not snapshot.partsSettled then
        local newBricks, firstFinish = Game.TakeSettlementStats()
        local granted = Game.SettleParts(1)
        if granted > 0 then PlayerData.AddParts(granted) end
        if newBricks > 0 then
            PlayerData.AddDailyProgress("break_bricks", newBricks)
            PlayerData.AddStat("bricksTotal", newBricks)
        end
        PlayerData.AddDailyProgress("reach_wave", math.floor(snapshot.wave or 1), true)
        if firstFinish then PlayerData.AddDailyProgress("play_runs", 1) end
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
        PlayerData.Save()
        SavePlayerDataToCloud()
        RefreshMeta()
        print("[Main] run settled, parts +" .. granted .. ", codex bonus +" .. bonus)
    end
end

function HandleScreenMode()
    RenderBackend.Resize()
end

-- v0.12.5：顶端通知条优先消费点击（任意状态都在最上层）。
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
    -- v0.12.5：顶部通知条永远最先吃点击（覆盖 HUD 下沿，可能与任何模态重叠）。
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
        -- v0.10.24：点在卡片外不关闭面板也不穿透，轻脉冲提示必须三选一。
        if not TryPickUpgradeAt(uiX, uiY) then
            Presentation.PulseUpgradeHint()
        end
        return
    end
    -- v0.11.0 商业化：暂停补给站按钮优先于「点任意处恢复」。
    -- v0.12.5：HUD 暂停按钮与道具竖列优先于拖拽起手。
    if TryHudPauseAt(screenX, screenY) then
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
    -- v0.11.0 商业化：主菜单商业区/功能面板优先消费点击。
    if TryMenuMetaAt(screenX, screenY) then
        metaPointerConsumed = true
        return
    end
    metaPointerConsumed = false
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
    if Game.IsStageWin() then
        local screenX, screenY = GetScreenCoordinates(eventData)
        local uiX, uiY = RenderBackend.ScreenToUi(screenX, screenY)
        HandleStageWinPointerUp(uiX, uiY)
        return
    end
    -- v0.10.24：升级态的按下已在 Down 分支消费，禁止其穿透成玩法 PointerUp。
    if Game.IsLevelUp() then return end
    local screenX, screenY = GetScreenCoordinates(eventData)
    if metaPointerConsumed then
        metaPointerConsumed = false
        return
    end
    if MenuMetaBlocksRelease() then return end
    local x, y = RenderBackend.ScreenToGame(screenX, screenY)
    Game.PointerUp(x, y)
end

function HandleMouseMove(eventType, eventData)
    if Game.IsLevelUp() or Game.IsGameOver() or Game.IsStageWin()
        or IsMetaCapturing() or metaPointerConsumed then return end
    local screenX, screenY = GetScreenCoordinates(eventData)
    local x, y = RenderBackend.ScreenToGame(screenX, screenY)
    Game.PointerMove(x, y)
end

function HandleTouchBegin(eventType, eventData)
    local screenX, screenY = GetScreenCoordinates(eventData)
    if not RenderBackend.IsInsideGameCanvas(screenX, screenY) then return end
    -- v0.12.5：顶部通知条永远最先吃触摸。
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
    -- v0.11.0 商业化：暂停补给站按钮优先于「点任意处恢复」。
    -- v0.12.5：HUD 暂停按钮与道具竖列优先于拖拽起手。
    if TryHudPauseAt(screenX, screenY) then
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
    -- v0.11.0 商业化：主菜单商业区/功能面板优先消费触摸。
    if TryMenuMetaAt(screenX, screenY) then
        metaPointerConsumed = true
        return
    end
    metaPointerConsumed = false
    Game.PointerDown(x, y)
end

function HandleTouchMove(eventType, eventData)
    if Game.IsLevelUp() or Game.IsGameOver() or Game.IsStageWin()
        or IsMetaCapturing() or metaPointerConsumed then return end
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
    Game.PointerUp(x, y)
end

function HandleKeyDown(eventType, eventData)
    local key = eventData:GetInt("Key")
    if key == KEY_SPACE or key == KEY_RETURN then
        if Game.IsGameOver() then
            Game.RestartFromOver()
        elseif Game.IsStageWin() then
            -- v0.13.4：胜利结算页要求显式点按钮，回车不自动跳关/重开。
        elseif gameSnapshot and gameSnapshot.state == "menu" then
            -- 主菜单回车与「开始战斗」CTA 一致：进选关界面，不再直接开局。
            HandleMetaAction("open_stage_select", nil)
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
