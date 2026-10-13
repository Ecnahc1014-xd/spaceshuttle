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

local ClientMain = {}
-- 业务手势与后端视觉使用同一主指针；0 是合法 TouchID。
ClientMain._pointer = { source = "", touchId = -1, state = "", epoch = 0, focused = true }

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
-- v0.13.8：天赋树拖拽滚动是否已起手（Move/Up 转发给 TalentTree.Scroll*）。
local talentScrollArmed = false
-- v0.13.13：选关界面（无限爬塔）拖拽滚动是否已起手。
local stageSelectScrollArmed = false
-- v0.13.56：第 1 关「测试模式」询问确认后，要进入的目标关卡号。
local pendingTestStage_ = nil
-- 设计宽度缓存（天赋树命中/滚动用；Init 时由 GetDesignSize 填）。
local designWidth_ = 540
local CLOUD_HIGH_SCORE_KEY = "high_score"
local CLOUD_META_KEY = "player_meta"
local metaCloudSynced = false
local metaRevision = 0
local metaSaveInFlight = false
-- 最高分云写合并：局内只累计待提交值，局末 / 回菜单 / 周期兜底才真正写一次，
-- 避免「每击碎一块砖刷新最高分就写一次云」（云写配额 300 次/分钟）。
local highScoreDirty = 0        -- 待提交的最高分（0 表示无待提交）
local highScoreCommitCooldown = 0  -- 距下次允许提交的秒数（局内周期兜底）
local HIGH_SCORE_COMMIT_INTERVAL = 15
-- 上一帧的 game.state：用于「进入结算/菜单态时提交一次」（避免持续态每帧提交）。
---@type string|nil
local prevHighScoreState_ = nil
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
    Presentation.SetCloudStatus("syncing")
    local okCall = pcall(function()
        clientCloud:SetInt(CLOUD_HIGH_SCORE_KEY, n, {
            ok = function()
                -- 只有确认写入成功才抬高「已知云端最高分」，失败时保持原值以便重试。
                lastSavedHighScore = math.max(lastSavedHighScore, n)
                Presentation.SetCloudStatus("ok")
                print("[Main] cloud high_score saved=" .. tostring(n))
            end,
            error = function(code, reason)
                -- 写失败：重新标脏，等下一次提交重试（离线/配额超限不丢分）。
                if n > highScoreDirty then highScoreDirty = n end
                Presentation.SetCloudStatus("unavailable")
                print("[Main] cloud save failed: " .. tostring(reason) .. " code=" .. tostring(code))
            end,
        })
    end)
    if not okCall then
        if n > highScoreDirty then highScoreDirty = n end
        Presentation.SetCloudStatus("unavailable")
        print("[Main] clientCloud unavailable, keep local high score")
    end
end

-- 记录「待提交的最高分」：局内每次刷新只更新内存值，不立刻写云。
local function MarkHighScoreDirty(score)
    local n = math.floor(tonumber(score) or 0)
    if n > highScoreDirty and n > lastSavedHighScore then
        highScoreDirty = n
    end
end

-- 提交待写的最高分（局末 / 回菜单 / 周期兜底调用）。
-- 无论是否真有待提交值都重置冷却，避免菜单态每帧重试（配额超限时形成写风暴）。
local function CommitHighScore()
    highScoreCommitCooldown = HIGH_SCORE_COMMIT_INTERVAL
    if highScoreDirty <= lastSavedHighScore then
        highScoreDirty = 0
        return
    end
    local pending = highScoreDirty
    highScoreDirty = 0
    SaveHighScoreToCloud(pending)
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

-- 取消而非模拟松手：失焦/广告/模态不能误发射，也不能保留旧按压。
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

-- v0.11.0 商业化：所有激励视频统一走 AdService，保证一次性完成与防重复发奖。
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
    -- 成就面板（v0.13.62）：列表 + 已解锁数 + 翻页下标。
    achievements = {},
    achUnlocked = 0,
    achTotal = 0,
    achPage = 1,
    -- v0.14.0：战斗档案屏内的页签（"pass" 档案 / "ach" 成就）。
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
    -- 设置页开关（v0.13.60）：音乐 / 音效，供设置屏只读渲染。
    musicEnabled = true,
    sfxEnabled = true,
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

    -- v0.13.62：成就面板数据（本地权威）——列表 + 已解锁数，供 Achievements 面板只读渲染。
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

    -- 选关界面数据（v0.13.4）：逐关星级 + 已解锁范围。
    -- v0.13.13：关卡无限——只统计到「最高已解锁关」，列表随进度增长。
    local maxStage = PlayerData.GetMaxStage()
    local stageStars = {}
    for stage = 1, maxStage do
        stageStars[stage] = PlayerData.GetStageStars(stage)
    end
    metaState.stageStars = stageStars
    metaState.maxStage = maxStage
    metaState.stageTotal = StageCatalog.STAGE_SOFT_CAP
    -- 选关界面「局内道具」购买条：库存 / 单价 / 本局每样限用一次。
    metaState.itemStock = PlayerData.GetItemStock()
    metaState.itemPrices = ItemShop.PRICES
    -- 设置页开关（v0.13.60）：音乐 / 音效，供设置屏只读渲染。
    metaState.musicEnabled = PlayerData.IsMusicEnabled()
    metaState.sfxEnabled = PlayerData.IsSfxEnabled()

    -- 天赋树界面数据（v0.13.5）：已解锁节点 + 星级汇总。
    metaState.talents = PlayerData.GetTalents()
    metaState.totalStars = PlayerData.GetTotalStars()
    metaState.talentCount = PlayerData.TalentCount()
    metaState.talentTotal = #TalentCatalog.GetNodes()
    -- v0.13.56：第 1 关「测试模式」询问是否待决（渲染层据此画提示）。
    metaState.testMode = (pendingTestStage_ ~= nil)
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
        if #rewards >= 4 then break end
    end
    metaState.passRewards = rewards
    metaState.passClaimable = metaState.passLevel > claimed
    -- v0.14.x 存钱罐：档案领满 6 级后切换到「存钱罐式」。
    metaState.piggyMode = PlayerData.IsPiggyMode()
    metaState.piggyGear = PlayerData.GetGear()
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
    -- v0.13.13：选关界面是无限爬塔——打开时默认定位在「最新（最高已解锁）关」。
    if name == "stage_select" then
        StageSelect.FocusLatest(designWidth_, metaState.maxStage or 1)
    end
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
local function HandleShopTrail(index)
    local trails = MetaCatalog.GetTrails()
    local trail = trails[index]
    if not trail then return end
    if PlayerData.HasTrail(trail.key) then
        PlayerData.SelectTrail(trail.key)
        PersistMeta()
        SetMetaToast("已切换为 " .. trail.name)
        return
    end
    if not PlayerData.PurchaseTrail(trail.key, trail.cost) then
        SetMetaToast("零件不足，还差 " .. tostring(math.max(0, trail.cost - PlayerData.GetParts())))
        return
    end
    PersistMeta()
    SetMetaToast("已购买 " .. trail.name)
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
    -- 元层交互音效：购买/解锁/领取类给确认音，其余给轻点击音。
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
        -- 点圆形卡：TalentTree 内部已记录选中并弹浮窗，这里只需重绘（无副作用）。
        RefreshMeta()
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
            if index == 1 then
                -- v0.13.56：进入第 1 关前先询问是否测试后期关卡（每次都问）。
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
        -- v0.13.56：测试模式——解锁全部天赋树节点，直入后期关卡（默认第 20 关强度）。
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
        -- v0.13.56：正常开始——从第 1 关起步，不动天赋树。
        pendingTestStage_ = 1
        RefreshMeta()
        print("[Main] test mode OFF: start stage 1")
    elseif action == "test_mode_close" then
        -- 询问屏只能通过「是/否」离开；close 由 ESC 触发时视为「否」。
        metaState.screen = nil
        pendingTestStage_ = 1
        RefreshMeta()
    elseif action == "open_settings" then
        -- v0.13.59：主菜单左上角齿轮 → 设置屏。
        OpenMetaScreen("settings")
    elseif action == "toggle_music" then
        -- v0.13.60：音乐开关——写存档 + 立即作用到音频总控 + 刷新快照。
        local on = not PlayerData.IsMusicEnabled()
        PlayerData.SetMusicEnabled(on)
        RenderBackend.SetMusicEnabled(on)
        SavePlayerDataToCloud()
        SetMetaToast(on and "音乐已开启" or "音乐已关闭")
        RefreshMeta()
    elseif action == "toggle_sfx" then
        -- v0.13.60：音效开关——写存档 + 立即作用到音频总控 + 刷新快照。
        local on = not PlayerData.IsSfxEnabled()
        PlayerData.SetSfxEnabled(on)
        RenderBackend.SetSfxEnabled(on)
        SavePlayerDataToCloud()
        SetMetaToast(on and "音效已开启" or "音效已关闭")
        RefreshMeta()
    elseif action == "restore_purchase" then
        -- 危险操作：先开确认面板，输入正确确认码后才真正恢复购买。
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
        -- 取消确认面板：回设置屏（不执行任何危险操作）。
        OpenMetaScreen("settings")
    elseif action == "confirm_ok" then
        if not Settings.IsConfirmed() then
            SetMetaToast("确认码不正确")
            RefreshMeta()
        else
            local reason = Settings.GetConfirmReason()
            metaState.screen = nil
            if reason == "delete" then
                -- 清空存档：重置本地存档 + 云存档，回到出厂状态。
                PlayerData.ResetAll()
                PlayerData.Save()
                SavePlayerDataToCloud()
                Game.SetItemStock(PlayerData.GetItemStock())
                -- v0.13.60：清档后音乐/音效回到默认开，重新作用到音频总控。
                RenderBackend.SetMusicEnabled(PlayerData.IsMusicEnabled())
                RenderBackend.SetSfxEnabled(PlayerData.IsSfxEnabled())
                metaState.talents = PlayerData.GetTalents()
                metaState.gems = 0
                SetMetaToast("存档已清空")
                print("[Main] save wiped by player confirm")
            else
                -- 恢复购买：重新向服务端拉一次余额与已购内容（离线不可用）。
                if GameMode.IsOffline() then
                    SetMetaToast("需联网后可用")
                else
                    NetClient.RequestBalance()
                    SetMetaToast("正在恢复购买…")
                    print("[Main] restore purchase requested")
                end
            end
            RefreshMeta()
        end
    elseif action == "buy_item" and index then
        -- v0.13.13：花零件买局内道具（永久库存）。库存上限/零件不足都只给 toast。
        local def = StageSelect.ITEM_ORDER[index]
        if def then
            local affordable, atCap = ItemShop.CanBuy(def.key)
            if atCap then
                SetMetaToast("该道具已达库存上限")
            elseif not affordable then
                SetMetaToast(string.format("零件不足，还差 %d",
                    math.max(0, ItemShop.GetPrice(def.key) - PlayerData.GetParts())))
            else
                local stockBefore = PlayerData.GetItemCount(def.key)
                if ItemShop.Buy(def.key) then
                    Game.SetItemStock(PlayerData.GetItemStock())
                    SavePlayerDataToCloud()
                    SetMetaToast(string.format("已购买「%s」×1", def.name))
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
        -- v0.14.0：战斗档案屏切到「战斗档案」页签。
        metaState.passTab = "pass"
    elseif action == "ach_tab" then
        -- v0.14.0：战斗档案屏切到「成就」页签——打开前重算一次（折算最新统计 + 幂等外发）。
        AchievementSystem.Refresh()
        RefreshMeta()
        metaState.passTab = "ach"
        metaState.achPage = 1
    elseif action == "show_platform_achievements" then
        -- 跳平台原生成就页（能力不可用时提示）。
        if not AchievementSystem.ShowPlatformAchievements() then
            SetMetaToast("当前环境不支持平台成就页")
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
        -- v0.14.0：打开战斗档案屏默认落在「战斗档案」页签。
        metaState.passTab = "pass"
        OpenMetaScreen("pass")
    elseif action == "claim_pass" and index then
        local reward = PlayerData.ClaimPass(index, metaState.premiumPass and 2 or 1)
        if reward > 0 then
            PersistMeta()
            SetMetaToast(string.format("战斗档案 +%d 零件", reward))
        end
    elseif action == "claim_gear" then
        local gears = PlayerData.ClaimGear()
        if gears > 0 then
            PersistMeta()
            SetMetaToast(string.format("存钱罐 +%d 齿轮", gears))
        else
            SetMetaToast("存钱罐还是空的")
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
    elseif action == "preview_skin" and index then
        -- 展台浏览只改变预览车型，不购买、不装备、不写存档。
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
        -- v0.13.8：天赋树是可滚动面板——按下先交给它记录起点（内容区内），
        -- 但是否算「拖拽」要等抬手时才定（见 HandleMouseUp/TouchEnd 的 ScrollEnd）。
        -- ⚠️ 这里不能直接 return：否则点击永远走不到 HitTestMetaScreen，
        -- 卡片选不中、底部浮窗不弹（v0.13.13 修复）。
        -- v0.13.13：天赋树的「点卡片选卡」放在抬手时判定——
        -- 真拖拽过就吞掉抬手（只滚动不选卡），没拖拽过才当作点击。
        if metaState.screen == "talent" and TalentTree.ScrollBegin(uiX, uiY, designWidth_) then
            talentScrollArmed = true
            return true
        end
        -- v0.13.13：选关界面同样是可滚动爬塔——按下先记录起点，抬手时按「是否拖动过」分流。
        if metaState.screen == "stage_select" and StageSelect.ScrollBegin(uiX, uiY, designWidth_) then
            stageSelectScrollArmed = true
            return true
        end
        local action, index = RenderBackend.HitTestMetaScreen(uiX, uiY, metaState)
        if action then HandleMetaAction(action, index) end
        return true
    end
    -- v0.13.4：主菜单「开始战斗」CTA 打开选关界面（不再直接开局）。
    if gameSnapshot and RenderBackend.HitTestMenuCta(uiX, uiY, gameSnapshot) then
        HandleMetaAction("open_stage_select", nil)
        return true
    end
    -- v0.13.59：主菜单左上角齿轮 → 设置屏。
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

-- v0.13.58：左上角附魔卡点击使用。返回 true 表示点击已被消费（不再穿透成拖拽起手）。
---@return boolean handled
local function TryUseEnchantAt(screenX, screenY)
    if not gameSnapshot or gameSnapshot.state ~= "playing" then return false end
    local uiX, uiY = RenderBackend.ScreenToUi(screenX, screenY)
    if not RenderBackend.HitTestEnchant(uiX, uiY, gameSnapshot) then return false end
    if not Game.HasEnchant() then return false end
    Game.UseEnchant()   -- 效果与反馈都由规则层事件驱动
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
    -- 过渡期吞掉点击；仅在跳过提示出现后允许跳过，不武装结算按钮。
    if StageTransition.IsActive(Game.GetSnapshot()) then
        reviveArmed, doubleArmed, restartArmed, menuArmed = false, false, false, false
        StageTransition.Skip(Game.GetSnapshot())
        return true
    end
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
    -- 与失败同门控：早期点击只消费，不跳过，也不武装隐藏按钮。
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
        -- v0.13.56：第 1 关「再战本关」同样先弹测试模式询问（每次都问）。
        -- ⚠️ 询问屏是「菜单态」屏，必须先回主菜单再开，否则 HandleUpdate 的
        --    待决跳关判定（要求 state==menu）永远不成立。
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

    graphics.windowTitle = "货车大战飞机"
    input.mouseVisible = true

    if not RenderBackend.Init() then return false end
    ClientMain._pointer.focused = true
    ClientMain.CancelInput()

    -- v0.12.5：平台通知换皮（v0.12.7：付费轨自动曝光已删，无需状态复位）。
    installSystemNotificationHandler()

    -- v0.11.0 联机：充值弹层复用游戏 UI 的令牌与原语（UI 无污染）。
    RechargeShop.Init(MetaUI.GetDeps())
    MetaUI.RegisterScreen("recharge", RechargeShop.Draw, RechargeShop.HitTest)
    -- v0.13.4：选关界面同样复用游戏令牌（插件式注册，不反向依赖渲染后端）。
    StageSelect.Init(MetaUI.GetDeps())
    MetaUI.RegisterScreen("stage_select", StageSelect.Draw, StageSelect.HitTest)
    -- v0.13.13：局内道具库存 provider——Game.ResetGame 每次开局自动拉取，
    -- 覆盖选关/下一关/再战/重开全部入口（无需逐个入口注入）。
    Game.SetItemStockProvider(PlayerData.GetItemStock)
    -- v0.13.5：天赋树界面同源注册。
    TalentTree.Init(MetaUI.GetDeps())
    MetaUI.RegisterScreen("talent", TalentTree.Draw, TalentTree.HitTest)
    -- v0.13.56：第 1 关「测试模式」询问屏同源注册（复用元层窗口动画与命中分发）。
    TestModePrompt.Init(MetaUI.GetDeps())
    MetaUI.RegisterScreen("test_mode", TestModePrompt.Draw, TestModePrompt.HitTest)
    -- v0.13.59：设置屏 + 危险操作确认面板（手机键盘输入确认码）同源注册。
    Settings.Init(MetaUI.GetDeps())
    MetaUI.RegisterScreen("settings", Settings.Draw, Settings.HitTest)
    MetaUI.RegisterScreen("reset_confirm", Settings.DrawConfirm, Settings.HitTestConfirm)
    -- v0.14.0：成就列表已并入「战斗档案」屏（MetaUI.DrawPass 直接调用），不再单独注册屏；
    -- 这里只注入依赖（本地成就为权威，平台成就只做镜像）。
    Achievements.Init(MetaUI.GetDeps())

    PlayerData.Load()
    -- v0.13.60：把存档里的音乐/音效开关作用到音频总控（AudioDirector 已在 Backend.Init 就绪）。
    RenderBackend.SetMusicEnabled(PlayerData.IsMusicEnabled())
    RenderBackend.SetSfxEnabled(PlayerData.IsSfxEnabled())
    -- 开局自动拥有初始车的「允许局内出场」节点（幂等；必须在 Load 之后）。
    PlayerData.EnsureAutoOwnedTalents(TalentCatalog.AUTO_OWNED)
    -- v0.13.62：成就全量重算（覆盖旧档/云合并后补算 + 补发平台外发；幂等）。
    AchievementSystem.Refresh()
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
    designWidth_ = width
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
    SubscribeToEvent("InputFocus", HandleInputFocus)

    print("[Main] rendering, ads and cloud save connected")
    started_ = true
    return true
end

function ClientMain.Stop()
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

-- v0.13.8：仅供本地离屏探针/验收使用的窄接口——直接打开某个元层界面，
-- 不改变任何游戏逻辑（正常游玩路径仍走输入 → HandleMetaAction）。
---@param name string|nil
function ClientMain.DebugOpenScreen(name)
    metaState.screen = name
    RefreshMeta()
    RefreshSnapshots()
    -- 与 OpenMetaScreen 保持一致：打开选关即定位到最新关（无限爬塔）。
    if name == "stage_select" then
        StageSelect.FocusLatest(designWidth_, metaState.maxStage or 1)
    end
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local inputDt = math.max(0, eventData:GetFloat("TimeStep"))
    local dt = math.min(inputDt, 0.05)
    AdService.Update(dt)
    if not GameMode.IsOffline() then NetClient.Update(dt) end
    -- v0.13.56：第 1 关「测试模式」询问确认后，在菜单态进入目标关。
    -- 放在玩法更新之前，保证本帧就切到目标关，不闪一帧菜单。
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
    -- v0.12.5：激励视频在途时冻结玩法推进（浏览器 embed 覆盖时游戏循环仍在跑，
    -- 广告回来敌人已压到防线）。表现层照常衰减，快照不变 = 画面静止。
    -- 结算/升级/暂停态的广告本就不推进玩法，无需重复处理。
    ClientMain.ValidatePointer()
    local adInFlight = AdService.IsInFlight()
    if adInFlight and (ClientMain._pointer.source ~= "" or Game.GetSnapshot().timeScale == 2
        or Game.GetSnapshot().holdSpeedPending or Game.GetSnapshot().aiming) then
        ClientMain.CancelInput()
    end
    local adFreeze = adInFlight
        and gameSnapshot ~= nil and gameSnapshot.state == "playing"
    if not adFreeze then
        Game.Update(gameDt, inputDt)
    end
    ClientMain.ValidatePointer()
    local snapshot = Game.GetSnapshot()
    local frameEvents = Game.DrainEvents()
    Presentation.Update(dt, snapshot, frameEvents)
    -- 音频总控消费同一份领域事件（只读），并按其状态机切换 8bit BGM。
    RenderBackend.TickAudio(dt, snapshot, frameEvents)
    gameSnapshot = snapshot
    presentationSnapshot = Presentation.GetSnapshot()
    RenderBackend.UpdateScene(gameSnapshot, presentationSnapshot, metaState, adFreeze and 0 or gameDt)
    -- 最高分云写合并：局内只累计待提交值；局末（结算）、回菜单、以及每
    -- HIGH_SCORE_COMMIT_INTERVAL 秒的兜底才真正写一次云（配额 300 次/分钟）。
    -- ⚠️ 结算/菜单是「持续态」——只在**进入**这些态的那一帧提交一次，不能每帧提交，
    --    否则写失败（error 回调会重新标脏）会每帧重试，形成远超配额的写风暴。
    if not GameMode.IsOffline() then
        if snapshot.highScore and snapshot.highScore > lastSavedHighScore then
            MarkHighScoreDirty(snapshot.highScore)
        end
        highScoreCommitCooldown = highScoreCommitCooldown - dt
        local state = snapshot.state
        local enteredEndState = state ~= prevHighScoreState_
            and (state == "gameover" or state == "stagewin" or state == "menu")
        prevHighScoreState_ = state
        if enteredEndState or highScoreCommitCooldown <= 0 then
            CommitHighScore()
        end
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
        -- v0.13.62：成就统计计数器（本地权威）——每局完成 +1、通关 +1、击败首领 +1。
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
        -- v0.13.62：结算后重算成就（所有统计已更新），并把新解锁外发平台（幂等）。
        local newAch = AchievementSystem.Refresh()
        -- 用 SetMetaToast 而非直接赋 toast：后者不重置 metaToastTimer，提示会永久留在屏上。
        if newAch > 0 then SetMetaToast(string.format("解锁 %d 个成就！", newAch)) end
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
    if not ClientMain.ClaimPointer("mouse") then return end
    local pointerX, pointerY = RenderBackend.ScreenToUi(screenX, screenY)
    RenderBackend.SetPointer(pointerX, pointerY)
    RenderBackend.SetPointerPressed(true)
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
    -- v0.11.0 商业化：主菜单商业区/功能面板优先消费点击。
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
    -- 所有业务提前返回前释放左键按压；其他鼠标按钮不影响它。
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
    -- v0.13.30c：先喂指针位置给后端（悬停发光用），任何模态下都要更新——
    -- 悬停是「全局交互反馈」，不该被拖拽/模态分支提前 return 掉。
    local sx, sy = GetScreenCoordinates(eventData)
    local hx, hy = RenderBackend.ScreenToUi(sx, sy)
    RenderBackend.SetPointer(hx, hy)
    if not ClientMain.OwnsPointer("mouse") then return end
    -- v0.13.8：天赋树拖拽滚动优先于一切（元层面板打开时 IsMetaCapturing 会拦下后续）。
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
    -- v0.11.0 商业化：主菜单商业区/功能面板优先消费触摸。
    if TryMenuMetaAt(screenX, screenY) then
        metaPointerConsumed = true
        return
    end
    metaPointerConsumed = false
    Game.PointerDown(x, y, pointerX, pointerY)
end

function HandleTouchMove(eventType, eventData)
    if not ClientMain.OwnsPointer("touch", eventData:GetInt("TouchID")) then return end
    -- 只移动业务主触点，非主指也不能改变滚动或玩法输入。
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
    -- 仅主触点结束时清反馈，画布外或第二根手指的抬起不能取消主指按压。
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
            -- 重复按键与过渡期回车不能直接重开，跳过资格与鼠标/触摸一致。
            if StageTransition.IsActive(Game.GetSnapshot()) then
                if not eventData:GetBool("Repeat") then
                    StageTransition.Skip(Game.GetSnapshot())
                end
            elseif not eventData:GetBool("Repeat") then
                Game.RestartFromOver()
            end
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
            -- v0.13.56：测试模式询问屏必须显式选择，ESC 等同「否 · 正常开始」。
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
