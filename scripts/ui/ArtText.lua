-- ui/ArtText.lua
-- 金属艺术字共用模块。布局使用成品母版尺寸，不使用 DWP 占位纹理的尺寸。
-- 图片下载完成后才注册 NanoVG 句柄；未就绪/缺图时调用方回退 zpix。
-- 金属灰阶默认用白 tint 保留明暗，语义色由按钮底色和描边承载。

local ArtText = {}

---@class ArtTextSpec
---@field path string
---@field w integer
---@field h integer

-- 换素材时同步更新实测母版尺寸；起始战斗字标保留用户成品。
---@type table<string, ArtTextSpec>
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

---@class ArtTextAttempt
---@field attempts integer
---@field status string
---@field retryAt number
---@field cleanupImg integer|nil

---@type table<string, {img: integer, w: number, h: number}>
local images_ = {}
---@type table<string, ArtTextAttempt>
local attempts_ = {}
local loaded_ = false
---@type table
local lifetime_ = {}
---@type any|nil
local ownerCtx_ = nil
local clock_ = 0.0
local MAX_ATTEMPTS = 3
local RETRY_BASE_SECONDS = 0.5

---@param key string
---@param entry ArtTextAttempt
---@param reason string
local function FailAttempt(key, entry, reason)
    if entry.attempts >= MAX_ATTEMPTS then
        entry.status = "exhausted"
    else
        entry.status = "backoff"
        entry.retryAt = clock_ + RETRY_BASE_SECONDS * 2 ^ (entry.attempts - 1)
    end
    print("[ArtText] " .. entry.status .. ": " .. key .. " attempt="
        .. entry.attempts .. "/" .. MAX_ATTEMPTS .. " " .. reason)
end

---@param ctx any
---@param key string
---@param spec ArtTextSpec
---@param entry ArtTextAttempt
local function LoadImage(ctx, key, spec, entry)
    local ok, img = pcall(function()
        return nvgCreateImage(ctx, spec.path, NVG_IMAGE_NEAREST)
    end)
    if not ok or type(img) ~= "number" or img <= 0 then
        FailAttempt(key, entry, "registration unavailable")
        return
    end
    local sizeOk, iw, ih = pcall(nvgImageSize, ctx, img)
    -- 正数句柄或正数尺寸并不证明 DWP 真图就绪（可能仍是占位图）。
    if not sizeOk or iw ~= spec.w or ih ~= spec.h then
        local deleted = pcall(nvgDeleteImage, ctx, img)
        if not deleted then
            -- 无法确认候选句柄已释放，不再注册，避免有限重试也叠加泄漏。
            entry.status = "quarantined"
            entry.cleanupImg = img
            print("[ArtText] quarantined: " .. key .. " image cleanup unavailable")
            return
        end
        FailAttempt(key, entry, "size not ready actual=" .. tostring(iw)
            .. "x" .. tostring(ih) .. " expected=" .. spec.w .. "x" .. spec.h)
        return
    end
    images_[key] = { img = img, w = spec.w, h = spec.h }
    entry.status = "ready"
    print("[ArtText] ready: " .. key .. " " .. spec.w .. "x" .. spec.h)
end

---@param ctx any
---@param key string
---@param spec ArtTextSpec
---@param entry ArtTextAttempt
local function BeginAttempt(ctx, key, spec, entry)
    entry.attempts = entry.attempts + 1
    entry.status = "waiting"
    local lifetime = lifetime_
    local completed = false
    -- 官方异步接口等真实资源完成；一个请求只接收一次完成回调。
    if type(cache.GetResourceAsync) == "function" then
        local ok, err = pcall(function()
            cache:GetResourceAsync("Texture2D", spec.path, function(resource)
                if lifetime ~= lifetime_ or completed then return end
                completed = true
                if not resource then
                    FailAttempt(key, entry, "download unavailable")
                    return
                end
                local texture = resource --[[@as Texture2D]]
                local sizeOk, rw, rh = pcall(function()
                    return texture:GetWidth(), texture:GetHeight()
                end)
                if not sizeOk or rw ~= spec.w or rh ~= spec.h then
                    FailAttempt(key, entry, "resource size not ready actual="
                        .. tostring(rw) .. "x" .. tostring(rh))
                    return
                end
                LoadImage(ctx, key, spec, entry)
            end)
        end)
        if not ok and not completed then
            -- 抛错可能发生在已提交之后；没有取消/完成证据不能发第二个请求。
            -- 无回调也保持 waiting，不用反复超时重试制造重叠下载。
            entry.status = "quarantined"
            print("[ArtText] quarantined: " .. key .. " async unavailable " .. tostring(err))
        end
    else
        -- 没有异步资源扩展的运行时仍校验母版尺寸，不能接受占位尺寸。
        LoadImage(ctx, key, spec, entry)
    end
end

---@param ctx any
function ArtText.Ensure(ctx)
    if loaded_ or not ctx then return end
    loaded_ = true
    ownerCtx_ = ctx
    for key, spec in pairs(SPECS) do
        local entry = { attempts = 0, status = "idle", retryAt = 0.0 }
        attempts_[key] = entry
        BeginAttempt(ctx, key, spec, entry)
    end
end

-- 宿主 Update 每帧调用一次，使用 UI dt。Ensure/Draw 不推进时间或触发重试。
-- 每图最多三次总尝试，仅有明确完成的失败才按 0.5s/1s 退避恢复。
---@param dt number
function ArtText.Tick(dt)
    if not loaded_ or not ownerCtx_ then return end
    if type(dt) ~= "number" or dt ~= dt or dt <= 0 or dt == math.huge then return end
    clock_ = clock_ + dt
    for key, spec in pairs(SPECS) do
        local entry = attempts_[key]
        if entry and entry.status == "backoff" and clock_ >= entry.retryAt then
            BeginAttempt(ownerCtx_, key, spec, entry)
        end
    end
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
    if not it or ctx ~= ownerCtx_ then return false end
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
    if not it or ctx ~= ownerCtx_ then return false end
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
    if ctx and ctx == ownerCtx_ then
        for _, it in pairs(images_) do pcall(nvgDeleteImage, ctx, it.img) end
        for _, entry in pairs(attempts_) do
            if entry.cleanupImg then pcall(nvgDeleteImage, ctx, entry.cleanupImg) end
        end
    end
    images_ = {}
    attempts_ = {}
    ownerCtx_ = nil
    clock_ = 0.0
    loaded_ = false
end

return ArtText
