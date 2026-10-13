-- ui/ArtText.lua
-- 金属艺术字共用模块。布局使用成品母版尺寸，不使用 DWP 占位纹理的尺寸。
-- 图片下载完成后才注册 NanoVG 句柄；未就绪/缺图时调用方回退 zpix。
-- 金属灰阶默认用白 tint 保留明暗，语义色由按钮底色和描边承载。

local ArtText = {}

-- 换素材时同步更新实测母版尺寸；起始战斗字标保留用户成品。
local SPECS = {
    startbattle = { path = "image/ui_tt_startbattle.png", w = 407, h = 128 },
    daily       = { path = "image/ui_tt_daily.png",       w = 88, h = 26 },
    collect     = { path = "image/ui_tt_collect.png",     w = 77, h = 26 },
    vehicle     = { path = "image/ui_tt_vehicle.png",     w = 71, h = 20 },
    trail       = { path = "image/ui_tt_trail.png",       w = 82, h = 20 },
    resume      = { path = "image/ui_tt_resume.png",      w = 87, h = 30 },
    menu        = { path = "image/ui_tt_menu.png",        w = 128, h = 30 },
    stage       = { path = "image/ui_tt_stage.png",       w = 99, h = 30 },
}

---@type table<string, {img: integer, w: number, h: number}>
local images_ = {}
local loaded_ = false
local lifetime_ = {}

local function LoadImage(ctx, key, spec)
    local ok, img = pcall(function()
        return nvgCreateImage(ctx, spec.path, NVG_IMAGE_NEAREST)
    end)
    if not ok or type(img) ~= "number" or img <= 0 then
        print("[ArtText] unavailable: " .. key)
        return
    end
    local iw, ih = nvgImageSize(ctx, img)
    -- 正数句柄或正数尺寸并不证明 DWP 真图就绪（可能仍是占位图）。
    if iw ~= spec.w or ih ~= spec.h then
        nvgDeleteImage(ctx, img)
        print("[ArtText] size not ready: " .. key .. " actual=" .. tostring(iw)
            .. "x" .. tostring(ih) .. " expected=" .. spec.w .. "x" .. spec.h)
        return
    end
    images_[key] = { img = img, w = spec.w, h = spec.h }
    print("[ArtText] ready: " .. key .. " " .. spec.w .. "x" .. spec.h)
end

local function LoadAll(ctx)
    loaded_ = true
    local lifetime = lifetime_
    for key, spec in pairs(SPECS) do
        -- 官方异步接口等真实资源完成，不轮询下载、不每帧重建图片。
        if type(cache.GetResourceAsync) == "function" then
            local ok, err = pcall(function()
                cache:GetResourceAsync("Texture2D", spec.path, function(resource)
                    if lifetime ~= lifetime_ then return end
                    if resource then
                        LoadImage(ctx, key, spec)
                    else
                        print("[ArtText] download unavailable: " .. key)
                    end
                end)
            end)
            if not ok then print("[ArtText] async unavailable: " .. key .. " " .. tostring(err)) end
        else
            -- 没有异步资源扩展的运行时仍校验母版尺寸，不能接受占位尺寸。
            LoadImage(ctx, key, spec)
        end
    end
end

---@param ctx any
function ArtText.Ensure(ctx)
    if not loaded_ then LoadAll(ctx) end
end

---@param key string
---@return boolean
function ArtText.Has(key)
    return images_[key] ~= nil
end

---@param key string
---@return number
function ArtText.Width(key)
    local spec = SPECS[key]
    return spec and spec.w or 0
end

---@param key string
---@return number
function ArtText.Height(key)
    local spec = SPECS[key]
    return spec and spec.h or 0
end

-- 横向拉伸只改变绘制矩形，绝不修改素材像素。
---@param ctx any
---@param key string
---@param cx number
---@param topY number
---@param tint integer[]|nil
---@param alpha number|nil
---@param scale number|nil
---@param stretchX number|nil
---@return boolean drawn
function ArtText.Draw(ctx, key, cx, topY, tint, alpha, scale, stretchX)
    ArtText.Ensure(ctx)
    local it = images_[key]
    if not it then return false end
    local a = alpha or 1
    local s = scale or 1
    local sx = stretchX or 1
    local col = tint or { 255, 255, 255 }
    local cr, cg, cb = col[1] or 255, col[2] or 255, col[3] or 255
    local alpha255 = col[4] or 255
    local w, h = it.w * s * sx, it.h * s
    local x = cx - w * 0.5
    nvgBeginPath(ctx)
    nvgRect(ctx, x, topY, w, h)
    nvgFillPaint(ctx, nvgImagePatternTinted(ctx, x, topY, w, h, 0, it.img,
        nvgRGBA(cr, cg, cb, math.floor(alpha255 * a))))
    nvgFill(ctx)
    return true
end

---@param ctx any
---@param key string
---@param r table
---@param tint integer[]|nil
---@param yOffset number|nil
---@param scale number|nil
---@param stretchX number|nil
---@return boolean drawn
function ArtText.DrawCentered(ctx, key, r, tint, yOffset, scale, stretchX)
    ArtText.Ensure(ctx)
    local it = images_[key]
    if not it then return false end
    local s = scale or 1
    local h = it.h * s
    local topY = r.y + (r.h - h) * 0.5 + (yOffset or 0)
    return ArtText.Draw(ctx, key, r.x + r.w * 0.5, topY, tint, 1, s, stretchX)
end

---@param key string
---@param targetH number
---@return number scale, number w, number h
function ArtText.FitHeight(key, targetH)
    local spec = SPECS[key]
    if not spec then return 1, 0, 0 end
    local s = targetH / spec.h
    return s, spec.w * s, spec.h * s
end

---@param key string
---@param targetW number
---@param scale number
---@return number stretchX
function ArtText.FitWidth(key, targetW, scale)
    local spec = SPECS[key]
    if not spec then return 1 end
    local baseW = spec.w * (scale or 1)
    if baseW <= 0 then return 1 end
    return targetW / baseW
end

---@return integer
function ArtText.LoadedCount()
    local c = 0
    for _ in pairs(images_) do c = c + 1 end
    return c
end

-- 宿主删除 ctx 前调用；使迟到下载回调失效，避免句柄跨 ctx 复用。
---@param ctx any|nil
function ArtText._Reset(ctx)
    lifetime_ = {}
    if ctx then
        for _, it in pairs(images_) do nvgDeleteImage(ctx, it.img) end
    end
    images_ = {}
    loaded_ = false
end

return ArtText
