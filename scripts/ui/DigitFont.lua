-- ui/DigitFont.lua
-- 关卡号像素数字贴图（v0.13.24）。用户要求：选关界面的关卡数字不要用字体渲染，
-- 改用**AI 生成的像素数字贴图**。
--
-- 规格（0718-pixelimage-aigc 管线）：母版 24×32、字形统一高 26、白+轮廓两色、
-- 透明背景、10 张（0-9）。因为只有「白+近黑轮廓」两色，运行时用
-- `nvgImagePatternTinted` 乘法叠色即可染成任意状态色（青=当前关 / 白=普通 /
-- 压暗=未解锁），无需为每个状态出图。
--
-- ⚠️ 本模块自持图片句柄（Init 时注入 vg 并加载一次），StageSelect 与
--    Scene3DBackend 共用同一份，避免各自 nvgCreateImage 重复加载。
-- ⚠️ 图片是**可选资源**：缺图时 DrawNumber 返回 false，调用方回退到字体绘制，
--    绝不让缺图影响启动。

local DigitFont = {}

---@type table<integer, integer>
local digitImages_ = {}
-- 每张数字母版的「可见字形宽度」由后处理决定，逐字固定（同高 26）。
-- 用于多位数排版：宽度按各自字形宽累加，避免等宽留白导致「11」中间空一条。
local DIGIT_W = { 18, 16, 20, 21, 19, 19, 18, 21, 18, 20 }
local GLYPH_H = 26
local MASTER_W = 24
local MASTER_H = 32

local DIGIT_PATH = "image/ui_digit_%d.png"

-- 懒加载：首次绘制时用当帧 ctx 创建图片句柄（NanoVG 上下文是进程级单例，
-- ctx 即 vg），避免模块需要外部注入 vg。只加载一次。
local ensureDone_ = false
local function Ensure(ctx)
    if ensureDone_ then return end
    ensureDone_ = true
    local loaded = 0
    for d = 0, 9 do
        local ok, img = pcall(function()
            return nvgCreateImage(ctx, string.format(DIGIT_PATH, d), NVG_IMAGE_NEAREST)
        end)
        if ok and type(img) == "number" and img > 0 then
            digitImages_[d] = img
            loaded = loaded + 1
        end
    end
    print("[DigitFont] pixel digits loaded=" .. loaded .. "/10")
end

---@return boolean 是否可用（全部 10 张都加载成功才算）
function DigitFont.Ready()
    for d = 0, 9 do
        if not digitImages_[d] then return false end
    end
    return true
end

-- 单个数字的显示宽高（按字形高 h 等比）。母版字形高 26 → 缩放系数 h/26。
local function GlyphSize(d, h)
    local s = h / GLYPH_H
    return DIGIT_W[d + 1] * s, h
end

---@param value integer|number
---@param h number 字形显示高度（px）
---@return number 整串数字的显示宽度
function DigitFont.Measure(value, h)
    local s = tostring(math.floor(tonumber(value) or 0))
    local total = 0
    for i = 1, #s do
        local d = tonumber(s:sub(i, i)) or 0
        total = total + GlyphSize(d, h)
    end
    return total
end

---@param ctx any
---@param value integer|number
---@param cx number 整串水平中心
---@param topY number 字形顶部 y
---@param h number 字形显示高度
---@param color table {r,g,b,a} 叠色（白=原色；青=当前关；低亮度=压暗）
---@return boolean drawn 是否用贴图绘制（false 表示调用方需回退字体）
function DigitFont.DrawNumber(ctx, value, cx, topY, h, color)
    Ensure(ctx)
    if not DigitFont.Ready() then return false end
    local s = tostring(math.floor(tonumber(value) or 0))
    local total = DigitFont.Measure(value, h)
    local x = cx - total * 0.5
    local sScale = h / GLYPH_H
    local drawW = MASTER_W * sScale
    local drawH = MASTER_H * sScale
    local offsetY = topY - 2 * sScale   -- 母版内字形顶对齐 y=2
    local tint = nvgRGBA(color[1], color[2], color[3], color[4] or 255)
    for i = 1, #s do
        local d = tonumber(s:sub(i, i)) or 0
        local img = digitImages_[d]
        local gw = GlyphSize(d, h)
        -- 每个字形：以母版整宽绘制（含透明边），但按字形宽前进，保证字距紧凑
        nvgBeginPath(ctx)
        nvgRect(ctx, x - (drawW - gw) * 0.5, offsetY, drawW, drawH)
        nvgFillPaint(ctx, nvgImagePatternTinted(ctx,
            x - (drawW - gw) * 0.5, offsetY, drawW, drawH, 0, img, tint))
        nvgFill(ctx)
        x = x + gw
    end
    return true
end

return DigitFont
