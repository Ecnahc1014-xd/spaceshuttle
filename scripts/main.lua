-- main.lua
-- 燃烧的蔬菜 - 弹珠砖块大战入口
-- 9:16 竖屏 / 纯 NanoVG 几何块渲染 / Zpix 像素字体

local Game = require "Game"
local Renderer = require "Renderer"

-- ============================================================================
-- 分辨率适配（模式 A：设计分辨率 + letterbox）
-- ============================================================================

local vg_ = nil

local DESIGN_W = 540
local DESIGN_H = 960

local physW_, physH_ = 0, 0
local dpr_ = 1
local logicalW_, logicalH_ = 0, 0
local scale_ = 1
local screenDesignW_, screenDesignH_ = 0, 0
local offsetX_, offsetY_ = 0, 0

local function UpdateScreenMetrics()
    physW_ = graphics:GetWidth()
    physH_ = graphics:GetHeight()
    dpr_ = graphics:GetDPR()
    logicalW_ = physW_ / dpr_
    logicalH_ = physH_ / dpr_

    scale_ = math.min(logicalW_ / DESIGN_W, logicalH_ / DESIGN_H)
    screenDesignW_ = logicalW_ / scale_
    screenDesignH_ = logicalH_ / scale_
    offsetX_ = (screenDesignW_ - DESIGN_W) * 0.5
    offsetY_ = (screenDesignH_ - DESIGN_H) * 0.5
end

-- 物理像素 -> 设计坐标
local function ScreenToDesign(sx, sy)
    local lx = sx / dpr_
    local ly = sy / dpr_
    return lx / scale_ - offsetX_, ly / scale_ - offsetY_
end

-- ============================================================================
-- 生命周期
-- ============================================================================

function Start()
    graphics.windowTitle = "燃烧的蔬菜 - 弹珠砖块大战"

    vg_ = nvgCreate(1)
    if vg_ == nil then
        print("ERROR: Failed to create NanoVG context")
        return
    end

    local fontId = nvgCreateFont(vg_, "zpix", "Fonts/Zpix.ttf")
    if fontId == -1 then
        print("ERROR: Failed to load Zpix font from Fonts/Zpix.ttf")
        return
    end
    print("Zpix font loaded, id=" .. tostring(fontId))

    UpdateScreenMetrics()
    Game.Init(DESIGN_W, DESIGN_H)

    SubscribeToEvent(vg_, "NanoVGRender", "HandleRender")
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

    input.mouseVisible = true

    -- 初始化随机种子
    math.randomseed(os.time())
    math.random()
    math.random()
    math.random()

    print("=== 燃烧的蔬菜 启动成功 ===")
end

function Stop()
    if vg_ ~= nil then
        nvgDelete(vg_)
        vg_ = nil
    end
end

-- ============================================================================
-- 事件处理
-- ============================================================================

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData:GetFloat("TimeStep")
    -- 限制 dt 防止卡顿后大跳
    if dt > 0.05 then dt = 0.05 end
    Game.Update(dt)
end

function HandleRender(eventType, eventData)
    if vg_ == nil then return end

    nvgBeginFrame(vg_, logicalW_, logicalH_, dpr_)
    nvgScale(vg_, scale_, scale_)

    -- 黑边背景（屏幕设计空间）
    nvgBeginPath(vg_)
    nvgRect(vg_, 0, 0, screenDesignW_, screenDesignH_)
    nvgFillColor(vg_, nvgRGBA(0, 0, 0, 255))
    nvgFill(vg_)

    -- 进入设计坐标系
    nvgTranslate(vg_, offsetX_, offsetY_)

    -- 裁剪到游戏设计区域
    nvgSave(vg_)
    nvgIntersectScissor(vg_, 0, 0, DESIGN_W, DESIGN_H)
    local state = Game.GetState()
    Renderer.Render(vg_, state)
    nvgRestore(vg_)

    nvgEndFrame(vg_)
end

function HandleScreenMode()
    UpdateScreenMetrics()
end

-- 鼠标
function HandleMouseDown(eventType, eventData)
    local x = eventData:GetInt("X")
    local y = eventData:GetInt("Y")
    local button = eventData:GetInt("Button")
    if button == MOUSEB_LEFT then
        local dx, dy = ScreenToDesign(x, y)
        Game.PointerDown(dx, dy)
    end
end

function HandleMouseUp(eventType, eventData)
    local x = eventData:GetInt("X")
    local y = eventData:GetInt("Y")
    local button = eventData:GetInt("Button")
    if button == MOUSEB_LEFT then
        local dx, dy = ScreenToDesign(x, y)
        Game.PointerUp(dx, dy)
    end
end

function HandleMouseMove(eventType, eventData)
    local x = eventData:GetInt("X")
    local y = eventData:GetInt("Y")
    local dx, dy = ScreenToDesign(x, y)
    Game.PointerMove(dx, dy)
end

-- 触摸
function HandleTouchBegin(eventType, eventData)
    local x = eventData:GetInt("X")
    local y = eventData:GetInt("Y")
    local dx, dy = ScreenToDesign(x, y)
    Game.PointerDown(dx, dy)
end

function HandleTouchMove(eventType, eventData)
    local x = eventData:GetInt("X")
    local y = eventData:GetInt("Y")
    local dx, dy = ScreenToDesign(x, y)
    Game.PointerMove(dx, dy)
end

function HandleTouchEnd(eventType, eventData)
    local x = eventData:GetInt("X")
    local y = eventData:GetInt("Y")
    local dx, dy = ScreenToDesign(x, y)
    Game.PointerUp(dx, dy)
end

-- 键盘
function HandleKeyDown(eventType, eventData)
    local key = eventData:GetInt("Key")
    if key == KEY_ESCAPE then
        -- 引擎默认行为
        return
    end
    Game.KeyDown(key)
end

function HandleKeyUp(eventType, eventData)
    local key = eventData:GetInt("Key")
    Game.KeyUp(key)
end
