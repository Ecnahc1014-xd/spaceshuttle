-- main.lua
-- 应用编排入口：桥接引擎事件、核心玩法、表现状态与可替换渲染后端。

local Game = require "Game"
local Presentation = require "Presentation"
local RenderBackend = require "NanoVGBackend"

local gameSnapshot = nil
local presentationSnapshot = nil

local function RefreshSnapshots()
    gameSnapshot = Game.GetSnapshot()
    presentationSnapshot = Presentation.GetSnapshot()
end

local function ToGameCoordinates(eventData)
    local x = eventData:GetInt("X")
    local y = eventData:GetInt("Y")
    return RenderBackend.ScreenToGame(x, y)
end

function Start()
    graphics.windowTitle = "燃烧的蔬菜 - 弹珠砖块大战"
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
    Game.Update(dt)
    local snapshot = Game.GetSnapshot()
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
    local x, y = ToGameCoordinates(eventData)
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
    local x, y = ToGameCoordinates(eventData)
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
    end
end

function HandleKeyUp(eventType, eventData)
    local key = eventData:GetInt("Key")
    if key == KEY_SPACE or key == KEY_RETURN then
        Game.HandleAction("start", false)
    end
end
