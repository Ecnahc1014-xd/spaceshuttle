-- ui/Achievements.lua
-- 成就面板（元层模态屏）。本地成就为权威；平台成就只做镜像（外发由 AchievementSystem 处理）。
--
-- ⚠️ 插件式注册（MetaUI.RegisterScreen("achievements", …)），复用元层窗口动画与命中逆变换，
--    后端零状态。只画与命中；数据由编排层 RefreshMeta 填进 metaState.achievements（只读）。
--
-- ⚠️ 布局：面板壳同 MetaUI.Shell（x18 y108 w504 h780，内容区 32..508 × 168..832）。
--    列表 2 列卡片 + 顶部总进度条 + 底部「查看平台成就」入口。

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

local CONTENT = { x = 32, y = 168, w = 476, h = 664 }
-- 卡高 92 / 2 列 × 5 行 = 10 张/页，把内容区填满（原 76/4 行下方留大片空白）。
local CARD_H = 92
local GAP = 8
local COLS = 2

---@return table 单卡矩形（index 从 1 开始）
local function GetCardRect(index)
    local bw = (CONTENT.w - GAP * (COLS - 1)) / COLS
    local col = (index - 1) % COLS
    local row = math.floor((index - 1) / COLS)
    return {
        x = CONTENT.x + col * (bw + GAP),
        y = CONTENT.y + 58 + row * (CARD_H + GAP),
        w = bw, h = CARD_H,
    }
end

---@return table 顶部总进度条区域
local function GetHeaderRect()
    return { x = CONTENT.x, y = CONTENT.y + 4, w = CONTENT.w, h = 46 }
end

---@return table 底部「查看平台成就」按钮
local function GetPlatformBtn()
    return { x = CONTENT.x + CONTENT.w * 0.5 - 120, y = CONTENT.y + CONTENT.h - 44, w = 240, h = 40 }
end

-- 可见卡片数 = 单屏能放几行（5 行 × 2 列 = 10），超出可翻页。
local VISIBLE = 10

---@return integer 总页数
local function PageCount(total)
    return math.max(1, math.ceil(total / VISIBLE))
end

-- ============================================================================
-- 绘制
-- ============================================================================

---@param ctx any
---@param w number
---@param meta MetaState
function Achievements.Draw(ctx, w, meta)
    local C = Colors()
    D.backdrop(ctx, 0, 0, w, 960)
    local x, y, sw, sh = 18, 108, w - 36, 780
    D.shell(ctx, x, y, sw, sh, 48)
    D.rect(ctx, x, y + 48, 3, 22, C.cyan, 0)
    local titleX = x + 16
    if D.icon(ctx, "premium_wheel_medal", x + 12, y + 8, 32, 1) then titleX = x + 52 end
    D.text(ctx, titleX, y + 8, "成就", 27, C.text)
    D.text(ctx, x + sw - 58, y + 14,
        string.format("%d / %d", meta.achUnlocked or 0, meta.achTotal or 0), 15, C.dim,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)

    local list = meta.achievements or {}
    local total = #list
    local pages = PageCount(total)
    local page = math.max(1, math.min(pages, meta.achPage or 1))

    -- 顶部总进度条：把「已解锁 N/M」做成一条价值锚定的进度。
    local hdr = GetHeaderRect()
    D.panel(ctx, hdr.x, hdr.y, hdr.w, hdr.h, C.rail, C.cyanDim, 6)
    D.rect(ctx, hdr.x + 2, hdr.y + 2, hdr.w - 4, math.floor(hdr.h * 0.44), {255, 255, 255, 16}, 4)
    D.text(ctx, hdr.x + 14, hdr.y + 8, "成就进度", 15, C.dim)
    D.text(ctx, hdr.x + hdr.w - 14, hdr.y + 7,
        string.format("%d / %d", meta.achUnlocked or 0, total), 17, C.cyan,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    local ratio = total > 0 and (meta.achUnlocked or 0) / total or 0
    D.progress(ctx, hdr.x + 14, hdr.y + 30, hdr.w - 28, ratio, C.cyan, 7)

    -- 卡片列表（当前页）。
    nvgSave(ctx)
    nvgIntersectScissor(ctx, CONTENT.x, CONTENT.y + 54, CONTENT.w, CONTENT.h - 104)
    for i = 1, VISIBLE do
        local idx = (page - 1) * VISIBLE + i
        local a = list[idx]
        if not a then break end
        local r = GetCardRect(i)
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

    -- 分页提示（多于 1 页时）。
    if pages > 1 then
        D.text(ctx, CONTENT.x + CONTENT.w * 0.5, CONTENT.y + CONTENT.h - 78,
            string.format("第 %d/%d 页 · 点击下方切换", page, pages), 13, C.dim,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end

    -- 底部：查看平台成就（平台能力；不可用时点后提示）。
    local btn = GetPlatformBtn()
    D.stroke(ctx, btn.x, btn.y, btn.w, btn.h, C.cyanDim, 6, 1)
    D.text(ctx, btn.x + btn.w * 0.5, btn.y + 10, "查看平台成就", 16, C.text,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
end

-- ============================================================================
-- 命中
-- ============================================================================

---@param uiX number
---@param uiY number
---@param w number
---@param meta MetaState
---@return string|nil action
---@return integer|nil index
function Achievements.HitTest(uiX, uiY, w, meta)
    -- 关闭按钮（与 MetaUI.GetShellLayout 的 close 同几何）。
    local close = { x = 18 + (w - 36) - 46, y = 108 + 8, w = 36, h = 36 }
    if Inside(close, uiX, uiY) then return "close", nil end
    if Inside(GetPlatformBtn(), uiX, uiY) then return "show_platform_achievements", nil end
    -- 点下方分页区：翻页（多于 1 页时）。
    local list = meta.achievements or {}
    local pages = PageCount(#list)
    if pages > 1 and uiY >= CONTENT.y + CONTENT.h - 84 and uiY <= CONTENT.y + CONTENT.h - 58 then
        return "ach_next_page", nil
    end
    return nil, nil
end

return Achievements
