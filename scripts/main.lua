-- main.lua
-- 应用编排入口：桥接引擎事件、核心玩法、表现状态与可替换渲染后端。

local Game = require "Game"
local Presentation = require "Presentation"
local RenderBackend = require "Scene3DBackend"

local gameSnapshot = nil
local presentationSnapshot = nil
local lastSavedHighScore = 0
local adInFlight = false
local reviveArmed = false
local restartArmed = false
local CLOUD_HIGH_SCORE_KEY = "high_score"

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

local function ShowReviveAd()
    if adInFlight then return end
    if not Game.CanRevive() then
        Presentation.SetAdToast("本局已复活")
        return
    end

    adInFlight = true
    local completed = false
    local callbackFired = false
    Presentation.SetAdStatus("loading")

    local function finish(result)
        if completed then return end
        completed = true
        adInFlight = false
        Presentation.SetAdStatus(nil)
        if result and result.success == true then
            if Game.ReviveFromAd() then
                Presentation.SetAdToast(nil)
            else
                Presentation.SetAdToast("复活未能生效")
            end
            RefreshSnapshots()
            return
        end
        local msg = result and result.msg or "广告暂不可用"
        if msg == "embed manual close" then
            Presentation.SetAdToast("需完整观看才能复活")
        else
            Presentation.SetAdToast("广告未完成，请稍后重试")
        end
        print("[Main] revive ad failed: " .. tostring(msg))
        RefreshSnapshots()
    end

    local accepted = false
    local okCall, acceptedOrErr = pcall(function()
        return sdk:ShowRewardVideoAd(function(result)
            callbackFired = true
            finish(result)
        end)
    end)
    if okCall then
        accepted = acceptedOrErr
    else
        print("[Main] ShowRewardVideoAd error: " .. tostring(acceptedOrErr))
    end
    if accepted == false and not callbackFired then
        finish({ success = false, msg = "广告暂不可用，请稍后重试" })
    end
end

-- 升级面板点击命中：玩家在三选一卡片内点击即装备该强化。
local function TryPickUpgradeAt(uiX, uiY)
    local snapshot = Game.GetSnapshot()
    local choices = snapshot.upgradeChoices
    if not choices or #choices == 0 then return false end
    -- v0.10.17：与 Scene3DBackend:GetUpgradeCardLayout 的视觉几何保持一致。
    local cardW, cardH, gap = 168, 300, 8
    -- 这里接收 UI 画布坐标，不是玩法平面坐标。
    local HIT_PAD = 4
    local totalW = #choices * cardW + (#choices - 1) * gap
    local startX = snapshot.width * 0.5 - totalW * 0.5 + cardW * 0.5
    local cy = 530
    for i = 1, #choices do
        local cx = startX + (i - 1) * (cardW + gap)
        if math.abs(uiX - cx) <= cardW * 0.5 + HIT_PAD
            and math.abs(uiY - cy) <= cardH * 0.5 + HIT_PAD then
            Game.PickUpgrade(i)
            return true
        end
    end
    return false
end

local function HandleGameOverPointerDown(uiX, uiY)
    local hit = RenderBackend.HitTestGameOverButton(uiX, uiY, Game.GetSnapshot())
    reviveArmed = (hit == "revive")
    restartArmed = (hit == "restart")
    return hit ~= nil
end

local function HandleGameOverPointerUp(uiX, uiY)
    local hit = RenderBackend.HitTestGameOverButton(uiX, uiY, Game.GetSnapshot())
    if reviveArmed and hit == "revive" then
        reviveArmed = false
        restartArmed = false
        ShowReviveAd()
        return true
    end
    if restartArmed and hit == "restart" then
        reviveArmed = false
        restartArmed = false
        Game.RestartFromOver()
        RefreshSnapshots()
        return true
    end
    reviveArmed = false
    restartArmed = false
    return false
end

function Start()
    graphics.windowTitle = "击碎，飞机大战"
    input.mouseVisible = true

    if not RenderBackend.Init("HandleRender") then return end

    local width, height = RenderBackend.GetDesignSize()
    Game.Init({width = width, height = height, seed = os.time(), highScore = 0})
    Presentation.Init()
    RefreshSnapshots()
    LoadHighScoreFromCloud()

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
    local hitStop = Presentation.GetSnapshot().hitStop or 0
    local gameDt = dt
    if hitStop > 0 then gameDt = dt * 0.15 end
    Game.Update(gameDt)
    local snapshot = Game.GetSnapshot()
    Presentation.Update(dt, snapshot, Game.DrainEvents())
    gameSnapshot = snapshot
    presentationSnapshot = Presentation.GetSnapshot()
    if snapshot.highScore and snapshot.highScore > lastSavedHighScore then
        SaveHighScoreToCloud(snapshot.highScore)
    end
end

function HandleRender()
    if gameSnapshot and presentationSnapshot then
        RenderBackend.Render(gameSnapshot, presentationSnapshot)
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
