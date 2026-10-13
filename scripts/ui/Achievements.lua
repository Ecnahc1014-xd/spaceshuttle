-- ui/Achievements.lua
-- 成就列表（嵌入「战斗档案」屏的下半区；本地成就为权威，平台成就只做镜像）。
--
-- ⚠️ 本模块**不再**注册成独立元层屏——它被 MetaUI.DrawPass / HitTestPass 直接调用，
--    绘制/命中几何（页签、列表区、翻页）全部在 MetaUI 里保持同源。
--    本模块只负责「成就列表 + 翻页」这一块内容的绘制与命中。
--
-- 排序：**已解锁优先置顶**（未解锁按目录顺序跟随其后，稳定不跳变）。
-- 翻页：上下页按钮（不再靠点击文字区循环）。

local Achievements = {}

---@type table|nil 与 MetaUI.Init 相同的依赖表
local D = nil

---@param deps table
function Achievements.Init(deps)
    D = deps
end

---@return table
local function Colors()
    return D.C
end

---@param r table
---@param px number
---@param py number
---@return boolean
local function Inside(r, px, py)
    return px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
end

-- ============================================================================
-- 布局（纯几何，绘制与命中共用）
-- ============================================================================

local CARD_H = 92
local GAP = 8
local COLS = 2

-- 列表区（相对传入的 rect：MetaUI 传入的成就内容区）。
-- 顶部让出「总进度条」，底部让出「翻页行 + 查看平台成就按钮」。
local HEADER_H = 52
local FOOTER_H = 104

---@param rect table 内容区（x/y/w/h）
---@return table 列表裁剪区
local function GetListRect(rect)
    return { x = rect.x, y = rect.y + HEADER_H, w = rect.w, h = rect.h - HEADER_H - FOOTER_H }
end

---@return integer 单页可见卡片数
local function VisibleCount(rect)
    local list = GetListRect(rect)
    local rows = math.max(1, math.floor((list.h + GAP) / (CARD_H + GAP)))
    return rows * COLS
end

---@param rect table
---@param index integer 从 1 开始
---@return table
local function GetCardRect(rect, index)
    local list = GetListRect(rect)
    local bw = (list.w - GAP * (COLS - 1)) / COLS
    local col = (index - 1) % COLS
    local row = math.floor((index - 1) / COLS)
    return {
        x = list.x + col * (bw + GAP),
        y = list.y + row * (CARD_H + GAP),
        w = bw, h = CARD_H,
    }
end

---@param rect table
---@return table 顶部总进度条
local function GetHeaderRect(rect)
    return { x = rect.x, y = rect.y + 4, w = rect.w, h = 44 }
end

---@param rect table
---@return table prev
---@return table next
local function GetPagerRects(rect)
    local y = rect.y + rect.h - FOOTER_H + 12
    return { x = rect.x, y = y, w = 108, h = 36 },
           { x = rect.x + rect.w - 108, y = y, w = 108, h = 36 }
end

---@param rect table
---@return table 查看平台成就按钮
local function GetPlatformBtn(rect)
    return { x = rect.x + rect.w * 0.5 - 120, y = rect.y + rect.h - 46, w = 240, h = 40 }
end

---@param rect table
---@return integer
local function PageCount(rect, total)
    return math.max(1, math.ceil(total / VisibleCount(rect)))
end

-- ============================================================================
-- 排序：已解锁优先置顶（两趟收集，稳定不跳变）
-- ============================================================================

---@param meta MetaState
---@return table[] 已解锁在前、未解锁在后
local function BuildList(meta)
    local src = meta.achievements or {}
    local unlocked, locked = {}, {}
    for _, a in ipairs(src) do
        if a.unlocked then unlocked[#unlocked + 1] = a else locked[#locked + 1] = a end
    end
    local out = {}
    for _, a in ipairs(unlocked) do out[#out + 1] = a end
    for _, a in ipairs(locked) do out[#out + 1] = a end
    return out
end

-- ============================================================================
-- 绘制
-- ============================================================================

---@param ctx any
---@param rect table 内容区（x/y/w/h，由 MetaUI 传入）
---@param meta MetaState
function Achievements.Draw(ctx, rect, meta)
    local C = Colors()
    local list = BuildList(meta)
    local total = #list
    local pages = PageCount(rect, total)
    local page = math.max(1, math.min(pages, meta.achPage or 1))

    -- 顶部总进度条：把「已解锁 N/M」做成一条价值锚定的进度。
    local hdr = GetHeaderRect(rect)
    D.panel(ctx, hdr.x, hdr.y, hdr.w, hdr.h, C.rail, C.cyanDim, 6)
    D.rect(ctx, hdr.x + 2, hdr.y + 2, hdr.w - 4, math.floor(hdr.h * 0.44), {255, 255, 255, 16}, 4)
    D.text(ctx, hdr.x + 14, hdr.y + 7, "成就进度", 15, C.dim)
    D.text(ctx, hdr.x + hdr.w - 14, hdr.y + 6,
        string.format("%d / %d", meta.achUnlocked or 0, total), 17, C.cyan,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    local ratio = total > 0 and (meta.achUnlocked or 0) / total or 0
    D.progress(ctx, hdr.x + 14, hdr.y + 28, hdr.w - 28, ratio, C.cyan, 7)

    -- 卡片列表（当前页）。
    local area = GetListRect(rect)
    nvgSave(ctx)
    nvgIntersectScissor(ctx, area.x, area.y, area.w, area.h)
    local perPage = VisibleCount(rect)
    for i = 1, perPage do
        local a = list[(page - 1) * perPage + i]
        if not a then break end
        local r = GetCardRect(rect, i)
        local tone = a.tone == "warn" and C.warn or (a.tone == "ad" and C.ad or C.cyan)
        local done = a.unlocked == true
        D.panel(ctx, r.x, r.y, r.w, r.h, done and C.widget or C.card,
            done and tone or {C.dim[1], C.dim[2], C.dim[3], 130}, 6)
        -- 内受光 / 内沉影 / 顶亮线（与其余卡片同厚度语言）。
        D.rect(ctx, r.x + 2, r.y + 2, r.w - 4, math.floor(r.h * 0.42),
            {255, 255, 255, done and 20 or 12}, 4)
        D.rect(ctx, r.x + 2, r.y + math.floor(r.h * 0.62), r.w - 4,
            r.h - math.floor(r.h * 0.62) - 2, {0, 0, 0, done and 40 or 28}, 4)
        D.rect(ctx, r.x + 4, r.y + 1, r.w - 8, 1, {C.dim[1], C.dim[2], C.dim[3], 70}, 0)
        -- 左侧识别条：达成=语义色亮，未达成=暗。
        D.rect(ctx, r.x + 2, r.y + 10, 3, r.h - 20, done and tone or C.rail, 1)
        -- 图标（缺图回退：程序化圆环 + 中心点）。
        local iconX, iconY = r.x + 10, r.y + 28
        if not D.icon(ctx, a.icon, iconX, iconY, 36, done and 1 or 0.4) then
            D.rect(ctx, iconX + 6, iconY + 6, 24, 24, done and tone or C.rail, 12)
        end
        D.text(ctx, r.x + 54, r.y + 12, a.title, 18, done and C.text or C.dim)
        D.text(ctx, r.x + 54, r.y + 38, a.desc, 13, C.dim)
        -- 底部进度：多步成就显示 N/M + 进度条；单步成就只显示状态。
        if a.steps > 1 and not done then
            local pr = math.min(1, (a.progress or 0) / a.steps)
            D.text(ctx, r.x + 54, r.y + 62,
                string.format("%d / %d", math.min(a.progress or 0, a.steps), a.steps), 12, C.dim)
            D.progress(ctx, r.x + 54, r.y + 80, r.w - 68, pr, tone, 4)
        else
            D.text(ctx, r.x + 54, r.y + 64, done and "已达成" or "未达成", 14,
                done and tone or C.dim)
        end
        if done then
            D.text(ctx, r.x + r.w - 12, r.y + 10, "✓", 20, tone,
                NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
        end
    end
    nvgRestore(ctx)

    -- 翻页行：上一页 / 页码 / 下一页。
    local prev, next_ = GetPagerRects(rect)
    local prevOn = page > 1
    local nextOn = page < pages
    D.stroke(ctx, prev.x, prev.y, prev.w, prev.h,
        prevOn and C.cyanDim or {C.dim[1], C.dim[2], C.dim[3], 90}, 6, 1)
    D.text(ctx, prev.x + prev.w * 0.5, prev.y + 10, "‹ 上一页", 15,
        prevOn and C.text or C.dim, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    D.stroke(ctx, next_.x, next_.y, next_.w, next_.h,
        nextOn and C.cyanDim or {C.dim[1], C.dim[2], C.dim[3], 90}, 6, 1)
    D.text(ctx, next_.x + next_.w * 0.5, next_.y + 10, "下一页 ›", 15,
        nextOn and C.text or C.dim, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    D.text(ctx, rect.x + rect.w * 0.5, prev.y + 10,
        string.format("%d / %d 页", page, pages), 14, C.dim,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    -- 底部：查看平台成就（平台能力；不可用时点后提示）。
    local btn = GetPlatformBtn(rect)
    D.stroke(ctx, btn.x, btn.y, btn.w, btn.h, C.cyanDim, 6, 1)
    D.text(ctx, btn.x + btn.w * 0.5, btn.y + 10, "查看平台成就", 16, C.text,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
end

-- ============================================================================
-- 命中
-- ============================================================================

---@param uiX number
---@param uiY number
---@param rect table 内容区（与 Draw 同一几何）
---@param meta MetaState
---@return string|nil action
---@return integer|nil index
function Achievements.HitTest(uiX, uiY, rect, meta)
    if not Inside(rect, uiX, uiY) then return nil, nil end
    local list = BuildList(meta)
    local pages = PageCount(rect, #list)
    local page = math.max(1, math.min(pages, meta.achPage or 1))
    local prev, next_ = GetPagerRects(rect)
    if page > 1 and Inside(prev, uiX, uiY) then return "ach_prev_page", nil end
    if page < pages and Inside(next_, uiX, uiY) then return "ach_next_page", nil end
    if Inside(GetPlatformBtn(rect), uiX, uiY) then return "show_platform_achievements", nil end
    return nil, nil
end

return Achievements
