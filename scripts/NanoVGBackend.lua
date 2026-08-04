-- NanoVGBackend.lua
-- 当前 2D 渲染后端。封装 NanoVG 生命周期、分辨率适配与屏幕坐标转换。

local Renderer = require "Renderer"

local Backend = {}

local DESIGN_W = 540
local DESIGN_H = 960

local vg = nil
local physicalWidth = 0
local physicalHeight = 0
local dpr = 1
local logicalWidth = 0
local logicalHeight = 0
local scale = 1
local screenDesignWidth = 0
local screenDesignHeight = 0
local offsetX = 0
local offsetY = 0

local function UpdateScreenMetrics()
    physicalWidth = graphics:GetWidth()
    physicalHeight = graphics:GetHeight()
    dpr = graphics:GetDPR()
    logicalWidth = physicalWidth / dpr
    logicalHeight = physicalHeight / dpr

    scale = math.min(logicalWidth / DESIGN_W, logicalHeight / DESIGN_H)
    screenDesignWidth = logicalWidth / scale
    screenDesignHeight = logicalHeight / scale
    offsetX = (screenDesignWidth - DESIGN_W) * 0.5
    offsetY = (screenDesignHeight - DESIGN_H) * 0.5
end

function Backend.Init(renderHandlerName)
    vg = nvgCreate(1)
    if not vg then
        print("[NanoVGBackend] ERROR: failed to create NanoVG context")
        return false
    end

    local fontId = nvgCreateFont(vg, "zpix", "Fonts/Zpix.ttf")
    if fontId == -1 then
        print("[NanoVGBackend] ERROR: failed to load Fonts/Zpix.ttf")
        nvgDelete(vg)
        vg = nil
        return false
    end

    UpdateScreenMetrics()
    SubscribeToEvent(vg, "NanoVGRender", renderHandlerName)
    print("[NanoVGBackend] initialized, fontId=" .. tostring(fontId))
    return true
end

function Backend.Shutdown()
    if vg then
        nvgDelete(vg)
        vg = nil
    end
end

function Backend.Resize()
    UpdateScreenMetrics()
end

function Backend.ScreenToGame(screenX, screenY)
    local logicalX = screenX / dpr
    local logicalY = screenY / dpr
    return logicalX / scale - offsetX, logicalY / scale - offsetY
end

function Backend.Render(gameSnapshot, presentationSnapshot)
    if not vg then return end

    nvgBeginFrame(vg, logicalWidth, logicalHeight, dpr)
    nvgScale(vg, scale, scale)

    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenDesignWidth, screenDesignHeight)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 255))
    nvgFill(vg)

    nvgTranslate(vg, offsetX, offsetY)
    nvgSave(vg)
    nvgIntersectScissor(vg, 0, 0, DESIGN_W, DESIGN_H)
    Renderer.Render(vg, gameSnapshot, presentationSnapshot)
    nvgRestore(vg)

    nvgEndFrame(vg)
end

function Backend.GetDesignSize()
    return DESIGN_W, DESIGN_H
end

return Backend
