-- main.lua
-- 应用编排入口：桥接引擎事件、核心玩法、表现状态与可替换渲染后端。

local Game = require "Game"
local Presentation = require "Presentation"
local RenderBackend = require "Scene3DBackend"

local gameSnapshot = nil
local presentationSnapshot = nil

local function RefreshSnapshots()
    gameSnapshot = Game.GetSnapshot()
    presentationSnapshot = Presentation.GetSnapshot()
end

local function GetScreenCoordinates(eventData)
    return eventData:GetInt("X"), eventData:GetInt("Y")
end

local function ToGameCoordinates(eventData)
    local x, y = GetScreenCoordinates(eventData)
    return RenderBackend.ScreenToGame(x, y)
end

-- 升级面板点击命中：玩家在三选一卡片内点击即装备该强化。
local function TryPickUpgradeAt(gameX, gameY)
    local snapshot = Game.GetSnapshot()
    local choices = snapshot.upgradeChoices
    if not choices or #choices == 0 then return false end
    local cardW, cardH, gap = 156, 214, 8
    -- 与 Scene3DBackend.GetUpgradeCardLayout 保持同一设计坐标；触屏额外扩大命中区。
    local HIT_PAD = 14
    local totalW = #choices * cardW + (#choices - 1) * gap
    local startX = snapshot.width * 0.5 - totalW * 0.5 + cardW * 0.5
    local cy = 478
    for i = 1, #choices do
        local cx = startX + (i - 1) * (cardW + gap)
        if math.abs(gameX - cx) <= cardW * 0.5 + HIT_PAD
            and math.abs(gameY - cy) <= cardH * 0.5 + HIT_PAD then
            Game.PickUpgrade(i)
            return true
        end
    end
    return false
end

function Start()
    graphics.windowTitle = "太空飞机弹珠"
    input.mouseVisible = true

    if not RenderBackend.Init("HandleRender") then return end

    local width, height = RenderBackend.GetDesignSize()
    Game.Init({width = width, height = height, seed = os.time()})
    Presentation.Init()
    RefreshSnapshots()

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

    print("[Main] rendering and gameplay layers connected")
end

function Stop()
    RenderBackend.Shutdown()
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = math.min(eventData:GetFloat("TimeStep"), 0.05)
    local snapshot = Game.GetSnapshot()
    -- P12：命中顿帧——大命中期间对玩法 dt 打折，但表现层仍用真实 dt 推进震屏/闪光衰减。
    local hitStop = Presentation.GetSnapshot().hitStop or 0
    local gameDt = dt
    if hitStop > 0 then gameDt = dt * 0.15 end
    Game.Update(gameDt)
    Presentation.Update(dt, snapshot, Game.DrainEvents())
    gameSnapshot = snapshot
    presentationSnapshot = Presentation.GetSnapshot()
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
    local x, y = RenderBackend.ScreenToGame(screenX, screenY)
    if Game.IsLevelUp() then
        TryPickUpgradeAt(x, y)
        return
    end
    Game.PointerDown(x, y)
end

function HandleMouseUp(eventType, eventData)
    if eventData:GetInt("Button") ~= MOUSEB_LEFT then return end
    local x, y = ToGameCoordinates(eventData)
    Game.PointerUp(x, y)
end

function HandleMouseMove(eventType, eventData)
    local x, y = ToGameCoordinates(eventData)
    Game.PointerMove(x, y)
end

function HandleTouchBegin(eventType, eventData)
    local screenX, screenY = GetScreenCoordinates(eventData)
    if not RenderBackend.IsInsideGameCanvas(screenX, screenY) then return end
    local x, y = RenderBackend.ScreenToGame(screenX, screenY)
    if Game.IsLevelUp() then
        TryPickUpgradeAt(x, y)
        return
    end
    Game.PointerDown(x, y)
end

function HandleTouchMove(eventType, eventData)
    local x, y = ToGameCoordinates(eventData)
    Game.PointerMove(x, y)
end

function HandleTouchEnd(eventType, eventData)
    local x, y = ToGameCoordinates(eventData)
    Game.PointerUp(x, y)
end

function HandleKeyDown(eventType, eventData)
    local key = eventData:GetInt("Key")
    if key == KEY_SPACE or key == KEY_RETURN then
        Game.HandleAction("start", true)
    elseif key == KEY_P or key == KEY_ESCAPE then
        if Game.IsPaused() then
            Game.Resume()
        elseif not Game.IsLevelUp() then
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
