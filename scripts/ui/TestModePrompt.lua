-- ui/TestModePrompt.lua
-- 第一关「测试模式」询问弹窗（元层模态屏）。
--
-- 触发：从选关界面点第 1 关时由编排层（client_main）打开本屏询问——
--   · 选「是」→ 解锁全部天赋树节点，并直接进入后期关卡（默认第 20 关强度）；
--   · 选「否」→ 照常从第 1 关开始。
-- 每次进入第 1 关都会重新询问（不做「只问一次」记忆）。
--
-- ⚠️ UI 无污染：沿用游戏自己的 dark-tech 令牌与 NanoVG 原语（依赖注入，不引入控件树）。
-- ⚠️ 本模块只画与命中；解锁天赋与开局由编排层执行。

local TestModePrompt = {}

-- 「是」进入的目标关卡（后期关卡强度）。改这里即可调整测试跳关目标。
TestModePrompt.TARGET_STAGE = 20

---@type table|nil 与 MetaUI.Init 相同的依赖表
local D = nil

---@param deps table
function TestModePrompt.Init(deps)
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

---@return table yes
---@return table no
local function GetButtons(w)
    local bw, gap = 196, 16
    local x0 = (w - bw * 2 - gap) * 0.5
    return { x = x0, y = 604, w = bw, h = 58 },
           { x = x0 + bw + gap, y = 604, w = bw, h = 58 }
end

-- 选项行：左侧竖标 + 标题 + 说明。
---@param ctx any
---@param x number
---@param y number
---@param w number
---@param title string
---@param desc string
---@param color table
local function OptionRow(ctx, x, y, w, title, desc, color)
    local C = Colors()
    D.rect(ctx, x, y + 2, 3, 30, color, 1)
    D.text(ctx, x + 14, y, title, 18, color)
    for i, line in ipairs(D.wrap(ctx, desc, 15, w - 20)) do
        D.text(ctx, x + 14, y + 26 + (i - 1) * 20, line, 15, C.dim)
    end
end

-- 按钮：与 MetaUI.Button 同一套工艺（D.panel 底 + Surface 金属面 + 悬停/按压缓动）。
---@param ctx any
---@param r table
---@param label string
---@param color table
---@param primary boolean
local function PromptButton(ctx, r, label, color, primary)
    local C = Colors()
    local glow, press = D.controlFx(r, true)
    nvgSave(ctx)
    nvgTranslate(ctx, 0, press * 2)
    if primary then
        D.panel(ctx, r.x, r.y, r.w, r.h, C.card, color, 6)
        D.button(ctx, r, color, glow)
        D.text(ctx, r.x + r.w * 0.5, r.y + r.h * 0.5 - 12, label, 21, C.ink,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    else
        D.panel(ctx, r.x, r.y, r.w, r.h, C.card, color, 6)
        if glow > 0.01 then
            nvgBeginPath(ctx)
            nvgRect(ctx, r.x - 6, r.y - 6, r.w + 12, r.h + 12)
            nvgFillPaint(ctx, nvgBoxGradient(ctx, r.x, r.y, r.w, r.h, 6, 6,
                nvgRGBA(color[1], color[2], color[3], math.floor(85 * glow)),
                nvgRGBA(color[1], color[2], color[3], 0)))
            nvgFill(ctx)
            D.stroke(ctx, r.x, r.y, r.w, r.h,
                {color[1], color[2], color[3], math.floor(230 * glow)}, 6, 1)
        end
        D.text(ctx, r.x + r.w * 0.5, r.y + r.h * 0.5 - 12, label, 20, C.text,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
    nvgRestore(ctx)
end

-- ============================================================================
-- 绘制
-- ============================================================================

---@param ctx any
---@param w number
---@param meta MetaState
function TestModePrompt.Draw(ctx, w, meta)
    local C = Colors()
    local total = meta.talentTotal or 42
    D.backdrop(ctx, 0, 0, w, 960)
    local x, y, sw, sh = 36, 248, w - 72, 462
    D.shell(ctx, x, y, sw, sh, 48)
    -- 标题栏：金色识别竖条 + 图标 + 标题（测试＝特殊/非正式语义）。
    D.rect(ctx, x, y + 48, 3, 22, C.warn, 0)
    local titleX = x + 16
    if D.icon(ctx, "talent_unlock", x + 12, y + 8, 32, 1) then titleX = x + 52 end
    D.text(ctx, titleX, y + 8, "测试模式", 27, C.warn)

    -- 询问
    D.text(ctx, x + 24, y + 78, "是否测试后期关卡？", 21, C.text)
    D.rule(ctx, x + 24, y + 112, sw - 48, 10,
        {C.warnDim[1], C.warnDim[2], C.warnDim[3], 130})

    -- 两个选项的说明
    OptionRow(ctx, x + 24, y + 132, sw - 48, "选择「是」",
        string.format("解锁全部天赋树（共 %d 个节点）", total), C.warn)
    OptionRow(ctx, x + 24, y + 194, sw - 48, "选择「否」",
        "从第 1 关正常开始", C.cyan)

    -- 补充说明
    D.text(ctx, x + 24, y + 262,
        string.format("选「是」将直接进入第 %d 关强度，天赋解锁立即生效。",
            TestModePrompt.TARGET_STAGE), 14, C.dim)
    D.text(ctx, x + 24, y + 284, "每次进入第 1 关都会重新询问。", 13, C.dim)

    -- 按钮
    local yes, no = GetButtons(w)
    PromptButton(ctx, yes, "是 · 测试", C.cyan, true)
    PromptButton(ctx, no, "否 · 正常开始", C.cyanDim, false)
end

-- ============================================================================
-- 命中
-- ============================================================================

---@param uiX number
---@param uiY number
---@param w number
---@param meta table
---@return string|nil action
---@return integer|nil index
function TestModePrompt.HitTest(uiX, uiY, w, meta)
    local yes, no = GetButtons(w)
    if Inside(yes, uiX, uiY) then return "test_mode_yes", nil end
    if Inside(no, uiX, uiY) then return "test_mode_no", nil end
    -- 必须显式选择：点窗外不关闭、不穿透（返回 nil 表示本次无动作）。
    return nil, nil
end

return TestModePrompt
