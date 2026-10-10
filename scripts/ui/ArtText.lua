-- ui/ArtText.lua
-- 艺术字标题（按钮 / 选项卡 / 分区标题）——AI 生成 + 0718-pixelimage-aigc 管线后处理的像素字标。
--
-- 为什么单独成模块：
--   ① `Scene3DBackend.lua` 顶层 local 已逼近 200 上限（AB-166），不能再往里塞图集句柄；
--   ② 字标要在后端（CTA / 暂停按钮）与 MetaUI（分区标题 / 商店分页标签）两处复用，
--      放独立模块只加一次 require，两边都拿得到；
--   ③ 句柄**懒加载**（首次 Draw 时才 nvgCreateImage）——与 `ui/DigitFont.lua` 同契约，
--      免去「后端暴露 vg」的访问器，也避免注入顺序问题（NanoVG 上下文是进程级单例，ctx 即 vg）。
--
-- 素材规格（走 0718 管线，见该 skill §5.1）：
--   · 母版高度 = 运行时显示高度（**1× 最近邻**，禁止非整数缩放，否则像素糊）；
--   · 宽度随字数浮动，逐图记录，绘制时居中（字标是「完整成品」不是 9-slice）；
--   · 两色母版：亮芯=白(255) + 近黑轮廓(16,19,31)。运行时用 `nvgImagePatternTinted`
--     **乘法染色**：乘 `C.ink` → 深字（配青/绿/金实心按钮）；乘 `C.cyan` → 青字（配深色底）。
--     一份素材同时适配「亮底深字」和「暗底亮字」，不必为每个语义各出一套图。
--
-- ⚠️ 全部为**可选资源**：任何一张加载失败只跳过该键，调用方回退到 zpix 文本绘制，
--    绝不让缺图影响启动或布局（同 v0.11.4 手势图 / v0.12.8 字标契约）。

local ArtText = {}

-- 键 → { path, h }。h = 母版高度 = 显示高度（1× 最近邻）。
local SPECS = {
    startbattle = { path = "image/ui_tt_startbattle.png", h = 44 },
    daily       = { path = "image/ui_tt_daily.png",       h = 26 },
    collect     = { path = "image/ui_tt_collect.png",     h = 26 },
    vehicle     = { path = "image/ui_tt_vehicle.png",     h = 20 },
    trail       = { path = "image/ui_tt_trail.png",       h = 20 },
    resume      = { path = "image/ui_tt_resume.png",      h = 30 },
    menu        = { path = "image/ui_tt_menu.png",        h = 30 },
    stage       = { path = "image/ui_tt_stage.png",       h = 30 },
}

---@type table<string, {img: integer, w: number, h: number}>
local images_ = {}
local loaded_ = false

local function SpecCount()
    local c = 0
    for _ in pairs(SPECS) do c = c + 1 end
    return c
end

local function LoadAll(ctx)
    loaded_ = true
    local n = 0
    for key, spec in pairs(SPECS) do
        local ok, img = pcall(function()
            return nvgCreateImage(ctx, spec.path, NVG_IMAGE_NEAREST)
        end)
        if ok and type(img) == "number" and img > 0 then
            -- 母版宽 = 高 × 内容纵横比；从图上读回真实宽高，避免手抄错。
            local iw, ih = nvgImageSize(ctx, img)
            if type(iw) == "number" and iw > 0 and type(ih) == "number" and ih > 0 then
                images_[key] = { img = img, w = iw, h = ih }
                n = n + 1
            end
        end
    end
    print("[ArtText] pixel titles loaded=" .. n .. "/" .. SpecCount())
end

-- 公开预加载入口：宿主（Backend.Init）在拿到 vg 后调用一次，
-- 让 Has/Width/Height 从启动起就可靠。⚠️ 必须显式调用——`Has()` 本身不触发加载，
-- 否则「Has() 判 false → 走 zpix 回退」会在首次 Draw 之前一直成立（表现为
-- 「有时是艺术字、有时是文字」的间歇性错误）。
---@param ctx any
function ArtText.Ensure(ctx)
    if not loaded_ then LoadAll(ctx) end
end

---@param key string
---@return boolean 该键是否有可用图集
function ArtText.Has(key)
    return images_[key] ~= nil
end

---@return number 母版宽度（设计像素）；无图返回 0
function ArtText.Width(key)
    local it = images_[key]
    return it and it.w or 0
end

---@return number 母版高度（设计像素）；无图返回 0
function ArtText.Height(key)
    local it = images_[key]
    return it and it.h or 0
end

-- 画一张字标：以 `cx` 水平居中、`topY` 为顶。tint 为 0..255 的 {r,g,b}（可带 a）。
-- 返回 true 表示画了；false 表示无图（调用方自行回退 zpix 文本）。
---@param ctx any
---@param key string
---@param cx number
---@param topY number
---@param tint integer[]|nil 染色（默认白）
---@param alpha number|nil 0..1
---@return boolean drawn
function ArtText.Draw(ctx, key, cx, topY, tint, alpha)
    ArtText.Ensure(ctx)
    local it = images_[key]
    if not it then return false end
    local a = alpha or 1
    local col = tint or { 255, 255, 255 }
    local cr, cg, cb = col[1] or 255, col[2] or 255, col[3] or 255
    local alpha255 = col[4] or 255
    local x = cx - it.w * 0.5
    nvgBeginPath(ctx)
    nvgRect(ctx, x, topY, it.w, it.h)
    nvgFillPaint(ctx, nvgImagePatternTinted(ctx, x, topY, it.w, it.h, 0, it.img,
        nvgRGBA(cr, cg, cb, math.floor(alpha255 * a))))
    nvgFill(ctx)
    return true
end

-- 在矩形内水平居中绘制（按钮 / 卡片内部用）。`centerY` 为期望的垂直中心。
---@param ctx any
---@param key string
---@param r table {x,y,w,h}
---@param tint integer[]|nil
---@param yOffset number|nil 相对垂直中心的微调
---@return boolean drawn
function ArtText.DrawCentered(ctx, key, r, tint, yOffset)
    ArtText.Ensure(ctx)
    local it = images_[key]
    if not it then return false end
    local topY = r.y + (r.h - it.h) * 0.5 + (yOffset or 0)
    return ArtText.Draw(ctx, key, r.x + r.w * 0.5, topY, tint, 1)
end

-- 仅供探针/验收：返回已加载的键数。
---@return integer
function ArtText.LoadedCount()
    local c = 0
    for _ in pairs(images_) do c = c + 1 end
    return c
end

-- 仅供探针：清空并允许重新加载（正常运行时不需要）。
function ArtText._Reset()
    images_ = {}
    loaded_ = false
end

return ArtText
