-- main.lua
-- 应用编排入口：桥接引擎事件、核心玩法、表现状态与可替换渲染后端。

local Game = require "Game"
local Presentation = require "Presentation"
local RenderBackend = require "Scene3DBackend"
local PlayerData = require "PlayerData"
local AdService = require "AdService"

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
    -- v0.11.0 商业化：结算页一出现就按 ×1 把本局零件入库（幂等，同帧只结算一次）。
    if snapshot.state == "gameover" then
        local granted = Game.SettleParts(1)
        if granted > 0 then
            PlayerData.AddParts(granted)
            PlayerData.AddDailyProgress("break_bricks", math.floor(snapshot.bricksBroken or 0))
            PlayerData.AddDailyProgress("reach_wave", math.floor(snapshot.wave or 1), true)
            PlayerData.AddDailyProgress("play_runs", 1)
            PlayerData.SetHighScore(math.floor(snapshot.highScore or 0))
            PlayerData.Save()
            SavePlayerDataToCloud()
            print("[Main] run settled, parts +" .. granted)
        end
    end
end

function HandleRender()
    if gameSnapshot and presentationSnapshot then
        RenderBackend.RenderOverlay(gameSnapshot, presentationSnapshot)
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
        if Game.IsPaused() then
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
