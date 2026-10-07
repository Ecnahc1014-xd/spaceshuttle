-- PremiumSurface.lua
-- 商业界面的共享字体和表面工艺，沿用现有 NanoVG 宿主，不创建渲染上下文。
local Surface = {}
local state = { regular = -1, bold = -1, context = nil, images = {} }

function Surface.Init(ctx)
    state.context = ctx
    state.regular = nvgCreateFont(ctx, "premium-body", "Fonts/MiSans-Regular.ttf")
    state.bold = nvgCreateFont(ctx, "premium-title", "Fonts/MiSans-Bold.ttf")
    state.images = {}
    for key, path in pairs({
        hangar = "image/premium_hangar_plate_20261007104817.png",
        showroom = "image/premium_showroom_plate_20261007104826.png",
    }) do
        local ok, image = pcall(nvgCreateImage, ctx, path, 0)
        if ok and image > 0 then state.images[key] = image end
    end
    print("[PremiumSurface] fonts regular=" .. tostring(state.regular) .. " bold=" .. tostring(state.bold))
end

function Surface.Shutdown()
    if state.context then
        for _, image in pairs(state.images) do nvgDeleteImage(state.context, image) end
    end
    state.images = {}
    state.regular, state.bold, state.context = -1, -1, nil
end

function Surface.UseFont(ctx, size)
    if size >= 22 and state.bold >= 0 then
        nvgFontFace(ctx, "premium-title")
    elseif state.regular >= 0 then
        nvgFontFace(ctx, "premium-body")
    else
        nvgFontFace(ctx, "zpix")
    end
end

-- 以明度、投影和一条受光边区分层级，强调色只留给确实强调的面板。
function Surface.Panel(ctx, x, y, w, h, fill, border, radius, emphasis)
    local r, a = radius or 6, fill[4] or 255
    nvgSave(ctx)
    if r > 0 and h > 48 then
        nvgBeginPath(ctx)
        nvgRect(ctx, x - 12, y - 8, w + 24, h + 24)
        nvgFillPaint(ctx, nvgBoxGradient(ctx, x, y + 4, w, h, r, 12,
            nvgRGBA(0, 0, 0, 110), nvgRGBA(0, 0, 0, 0)))
        nvgFill(ctx)
    end
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x, y, w, h, r)
    nvgFillPaint(ctx, nvgLinearGradient(ctx, x, y, x + w * 0.15, y + h,
        nvgRGBA(math.min(255, fill[1] + 14), math.min(255, fill[2] + 15), math.min(255, fill[3] + 17), a),
        nvgRGBA(math.max(0, fill[1] - 3), math.max(0, fill[2] - 3), math.max(0, fill[3] - 3), a)))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x + 0.5, y + 0.5, w - 1, h - 1, r)
    nvgStrokeColor(ctx, emphasis and nvgRGBA(border[1], border[2], border[3], math.min(180, border[4] or 180))
        or nvgRGBA(114, 144, 163, 58))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x + r + 3, y + 1.5)
    nvgLineTo(ctx, x + w - r - 3, y + 1.5)
    nvgStrokeColor(ctx, nvgRGBA(216, 235, 244, emphasis and 68 or 36))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
    nvgRestore(ctx)
end

-- 统一主操作；磨砂色面与窄边，不用多层果冻高光抢走商品焦点。
function Surface.Button(ctx, r, color, glow, phase)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, r.x, r.y + 3, r.w, r.h, 6)
    nvgFillColor(ctx, nvgRGBA(1, 6, 12, 150))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, r.x, r.y, r.w, r.h, 6)
    nvgFillPaint(ctx, nvgLinearGradient(ctx, r.x, r.y, r.x + r.w * 0.4, r.y + r.h,
        nvgRGBA(math.min(255, color[1] + 20), math.min(255, color[2] + 12), math.min(255, color[3] + 14), 255),
        nvgRGBA(math.floor(color[1] * 0.65), math.floor(color[2] * 0.75), math.floor(color[3] * 0.78), 255)))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, r.x + 0.5, r.y + 0.5, r.w - 1, r.h - 1, 6)
    nvgStrokeColor(ctx, nvgRGBA(220, 255, 252, math.floor(72 + (glow or 0) * 140)))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
    if phase then
        nvgSave(ctx)
        nvgIntersectScissor(ctx, r.x + 7, r.y + r.h - 3, r.w - 14, 2)
        local x = r.x - 48 + ((phase % 6) / 6) * (r.w + 96)
        nvgBeginPath(ctx)
        nvgRect(ctx, x, r.y + r.h - 3, 48, 1)
        nvgFillPaint(ctx, nvgLinearGradient(ctx, x, r.y, x + 48, r.y,
            nvgRGBA(238, 255, 252, 0), nvgRGBA(238, 255, 252, 120)))
        nvgFill(ctx)
        nvgRestore(ctx)
    end
end

function Surface.FitText(ctx, text, size, width, minimum)
    nvgSave(ctx)
    nvgResetTransform(ctx)
    local fitted = size
    while true do
        Surface.UseFont(ctx, fitted)
        nvgFontSize(ctx, fitted)
        local advance = nvgTextBounds(ctx, 0, 0, text, nil)
        if advance <= width or fitted <= (minimum or 15) then
            nvgRestore(ctx)
            return fitted, advance <= width
        end
        fitted = fitted - 1
    end
end

-- 环境插画不是像素图标，按原始纵横比绘制并交给宿主控制阅读遮罩。
function Surface.Environment(ctx, key, r, alpha)
    local image = state.images[key]
    if not image then return false end
    nvgSave(ctx)
    nvgIntersectScissor(ctx, r.x, r.y, r.w, r.h)
    nvgBeginPath(ctx)
    nvgRect(ctx, r.x, r.y, r.w, r.h)
    local aspect = key == "hangar" and (9 / 16) or (16 / 9)
    local dw = math.max(r.w, r.h * aspect)
    local dh = dw / aspect
    local dx, dy = r.x + (r.w - dw) * 0.5, r.y + (r.h - dh) * 0.5
    nvgFillPaint(ctx, nvgImagePattern(ctx, dx, dy, dw, dh, 0, image, alpha or 1))
    nvgFill(ctx)
    nvgRestore(ctx)
    return true
end

return Surface
