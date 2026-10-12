-- ui/Settings.lua
-- 设置屏（元层模态屏）+ 危险操作二次确认面板（手机键盘输入确认码）。
--
-- 触发：主菜单左上角「齿轮」按钮 → 打开本屏（metaState.screen = "settings"）。
--   屏内两项：恢复购买 / 清空存档。
--   二者都是**危险操作**，必须先打开「确认面板」（screen = "reset_confirm"），
--   玩家用**手机键盘**（0-9 + * + #）输入文字提示里给出的确认码，输入正确才能执行。
--
-- ⚠️ UI 无污染：沿用游戏 dark-tech 令牌与 NanoVG 原语（依赖注入，不引入控件树）。
-- ⚠️ 本模块只画与命中；真正的恢复购买 / 清空存档由编排层（client_main）执行。

local Settings = {}

---@type table|nil 与 MetaUI.Init 相同的依赖表
local D = nil

---@param deps table
function Settings.Init(deps)
    D = deps
end

-- 危险操作的确认码（玩家在确认面板里用键盘逐位输入）。
Settings.RESTORE_CODE = "1234"
Settings.DELETE_CODE = "0000"

-- 当前确认面板的状态（模块级瞬时状态，同一时刻只开一个确认面板）。
---@type string|nil "restore" | "delete"
local confirmReason_ = nil
---@type string
local input_ = ""

-- 打开确认面板前由编排层调用：重置输入并记下原因。
---@param reason string "restore" | "delete"
function Settings.BeginConfirm(reason)
    confirmReason_ = reason
    input_ = ""
end

---@return string|nil
function Settings.GetConfirmReason()
    return confirmReason_
end

---@return string
local function ConfirmCode()
    return confirmReason_ == "delete" and Settings.DELETE_CODE or Settings.RESTORE_CODE
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

-- 面板加高以容纳「音乐/音效开关 + 两项危险操作 + 制作鸣谢 + 关闭按钮」。
-- ⚠️ 先加高容器再排各元素 y（AB-259），否则关闭按钮会压住鸣谢文字。
-- v0.13.60：600→640——用户报「制作鸣谢被挡住了」，实测关闭按钮顶边(716)距鸣谢末行(652)
-- 仅 46px，真机字体/缩放差异下仍可能压字；加高后间距 ~86px，稳妥。
local PANEL_H = 640

---@return table panel
local function GetSettingsPanel(w)
    return { x = 54, y = 180, w = w - 108, h = PANEL_H }
end

-- 行顺序：音乐 / 音效 / 恢复购买 / 清空存档。
---@return table music
---@return table sfx
---@return table restore
---@return table delete
local function GetSettingRows(w)
    local p = GetSettingsPanel(w)
    local bw = p.w - 48
    local y0 = p.y + 72
    local step = 72
    return { x = p.x + 24, y = y0,            w = bw, h = 60 },
           { x = p.x + 24, y = y0 + step,     w = bw, h = 60 },
           { x = p.x + 24, y = y0 + step * 2, w = bw, h = 60 },
           { x = p.x + 24, y = y0 + step * 3, w = bw, h = 60 }
end

---@return table close
local function GetSettingsClose(w)
    local p = GetSettingsPanel(w)
    return { x = p.x + p.w * 0.5 - 90, y = p.y + p.h - 64, w = 180, h = 48 }
end

-- 确认面板：标题 + 提示 + 输入显示 + 键盘(4×3) + 按钮。
---@return table panel
local function GetConfirmPanel(w)
    return { x = 46, y = 150, w = w - 92, h = 676 }
end

local KEY_COLS, KEY_ROWS, KEY_SZ, KEY_GAP = 3, 4, 68, 10

---@return table 键盘区域左上角
local function GetKeypadOrigin(w)
    local p = GetConfirmPanel(w)
    local totalW = KEY_COLS * KEY_SZ + (KEY_COLS - 1) * KEY_GAP
    return { x = p.x + (p.w - totalW) * 0.5, y = p.y + 258 }
end

---@param i integer 0..11
---@return table rect
local function GetKeyRect(w, i)
    local o = GetKeypadOrigin(w)
    local col = i % KEY_COLS
    local row = math.floor(i / KEY_COLS)
    return {
        x = o.x + col * (KEY_SZ + KEY_GAP),
        y = o.y + row * (KEY_SZ + KEY_GAP),
        w = KEY_SZ, h = KEY_SZ,
    }
end

-- 键盘字符（电话键盘顺序：1-9, *, 0, #）。
local KEY_CHARS = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#" }

-- 编排层命中 `confirm_key` 后，用 index(1..12) 取字符再 PushChar。
---@param i integer 1..12
---@return string|nil
function Settings.KeyCharAt(i)
    return KEY_CHARS[i]
end

---@return table backspace
---@return table ok
---@return table cancel
local function GetConfirmButtons(w)
    local p = GetConfirmPanel(w)
    local bw, gap = 128, 12
    local totalW = bw * 3 + gap * 2
    local x0 = p.x + (p.w - totalW) * 0.5
    local y = p.y + p.h - 72
    return { x = x0, y = y, w = bw, h = 52 },
           { x = x0 + bw + gap, y = y, w = bw, h = 52 },
           { x = x0 + (bw + gap) * 2, y = y, w = bw, h = 52 }
end

-- ============================================================================
-- 绘制辅助
-- ============================================================================

-- 通用按钮：D.panel 底 + 金属面 + 悬停/按压缓动（与 MetaUI.Button 同工艺）。
---@param ctx any
---@param r table
---@param label string
---@param color table
---@param primary boolean
---@param disabled boolean|nil
local function PromptButton(ctx, r, label, color, primary, disabled)
    local C = Colors()
    local glow, press = D.controlFx(r, not disabled)
    nvgSave(ctx)
    nvgTranslate(ctx, 0, press * 2)
    D.panel(ctx, r.x, r.y, r.w, r.h, C.card, disabled and C.widget or color, 6)
    if disabled then
        D.text(ctx, r.x + r.w * 0.5, r.y + r.h * 0.5 - 12, label, 20, C.dim,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    elseif primary then
        D.button(ctx, r, color, glow)
        D.text(ctx, r.x + r.w * 0.5, r.y + r.h * 0.5 - 12, label, 21, C.ink,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    else
        if glow > 0.01 then
            D.stroke(ctx, r.x, r.y, r.w, r.h,
                {color[1], color[2], color[3], math.floor(210 * glow)}, 6, 1.2)
        end
        D.text(ctx, r.x + r.w * 0.5, r.y + r.h * 0.5 - 12, label, 20, C.text,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
    nvgRestore(ctx)
end

-- 设置项行：图标 + 标题 + 说明 + 右侧箭头。
---@param ctx any
---@param r table
---@param iconKey string
---@param title string
---@param desc string
---@param tone table
local function SettingRow(ctx, r, iconKey, title, desc, tone)
    local C = Colors()
    local glow = D.controlFx(r, true)
    D.panel(ctx, r.x, r.y, r.w, r.h, C.card, glow > 0.01 and tone or C.rail, 8)
    D.rect(ctx, r.x + 1, r.y + 12, 3, r.h - 24, tone, 1)
    D.icon(ctx, iconKey, r.x + 16, r.y + r.h * 0.5 - 16, 32, 1)
    D.text(ctx, r.x + 60, r.y + 12, title, 20, C.text)
    D.text(ctx, r.x + 60, r.y + 40, desc, 14, C.dim)
    D.text(ctx, r.x + r.w - 22, r.y + r.h * 0.5 - 10, "›", 24, tone,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
end

-- 开关行：图标 + 标题 + 说明 + 右侧拨动开关（开=青、关=暗轨）。
---@param ctx any
---@param r table
---@param iconKey string
---@param title string
---@param desc string
---@param on boolean
local function ToggleRow(ctx, r, iconKey, title, desc, on)
    local C = Colors()
    local tone = on and C.cyan or C.rail
    local glow = D.controlFx(r, true)
    D.panel(ctx, r.x, r.y, r.w, r.h, C.card, glow > 0.01 and tone or C.rail, 8)
    D.rect(ctx, r.x + 1, r.y + 12, 3, r.h - 24, tone, 1)
    D.icon(ctx, iconKey, r.x + 16, r.y + r.h * 0.5 - 16, 32, 1)
    D.text(ctx, r.x + 60, r.y + 12, title, 20, C.text)
    D.text(ctx, r.x + 60, r.y + 40, desc, 14, C.dim)
    -- 拨动开关：轨道 + 滑块（开启时滑块靠右、青色发光）。
    local tw, th = 54, 28
    local tx = r.x + r.w - tw - 18
    local ty = r.y + (r.h - th) * 0.5
    D.rect(ctx, tx, ty, tw, th, on and C.cyanDim or C.widget, th * 0.5)
    local knobR = th * 0.5 - 3
    local knobX = on and (tx + tw - th * 0.5) or (tx + th * 0.5)
    if on then
        D.rect(ctx, knobX - knobR, ty + 3, knobR * 2, knobR * 2, C.cyan, knobR)
    else
        D.rect(ctx, knobX - knobR, ty + 3, knobR * 2, knobR * 2, C.dim, knobR)
    end
end

-- ============================================================================
-- 设置屏 绘制 / 命中
-- ============================================================================

---@param ctx any
---@param w number
---@param meta MetaState
function Settings.Draw(ctx, w, meta)
    local C = Colors()
    D.backdrop(ctx, 0, 0, w, 960)
    local p = GetSettingsPanel(w)
    D.shell(ctx, p.x, p.y, p.w, p.h, 48)
    D.rect(ctx, p.x, p.y + 48, 3, 22, C.cyan, 0)
    local titleX = p.x + 16
    if D.icon(ctx, "gear", p.x + 12, p.y + 8, 32, 1) then titleX = p.x + 52 end
    D.text(ctx, titleX, p.y + 8, "设置", 27, C.text)

    local music, sfx, restore, del = GetSettingRows(w)
    ToggleRow(ctx, music, "boost", "音乐", "背景音乐开关", meta.musicEnabled ~= false)
    ToggleRow(ctx, sfx, "premium_energy_core", "音效", "游戏音效开关", meta.sfxEnabled ~= false)
    SettingRow(ctx, restore, "gem", "恢复购买", "重新同步已购商品与内容", C.warn)
    SettingRow(ctx, del, "reroll", "清空存档", "重置全部进度、零件与解锁", C.error)

    D.text(ctx, p.x + 24, del.y + del.h + 14,
        "⚠️ 危险操作需在确认面板输入确认码。", 13, C.dim)

    -- v0.13.61：鸣谢区上方原本留白 ~90px——补「账号进度摘要卡」（商业化：把设置页也变成
    -- 战绩页，顺带暴露钱包持有量）。全部读真实 meta 字段。
    local sumY = del.y + del.h + 36
    local sum = { x = p.x + 24, y = sumY, w = p.w - 48, h = 68 }
    D.panel(ctx, sum.x, sum.y, sum.w, sum.h, C.rail, C.cyanDim, 6)
    D.rect(ctx, sum.x + 2, sum.y + 2, sum.w - 4, math.floor(sum.h * 0.42),
        {255, 255, 255, 16}, 4)
    D.rect(ctx, sum.x + 4, sum.y + 1, sum.w - 8, 1, {C.dim[1], C.dim[2], C.dim[3], 70}, 0)
    local cells = {
        { string.format("%d", meta.highScore or 0), "最高分", C.text },
        { string.format("第 %d 关", meta.maxStage or 1), "最远进度", C.cyan },
        { string.format("%d", meta.parts or 0), "零件", C.text },
        { string.format("%d", meta.gems or 0), "钻石", C.warn },
    }
    local cw = sum.w / #cells
    for i, cell in ipairs(cells) do
        local cx = sum.x + cw * (i - 0.5)
        D.text(ctx, cx, sum.y + 12, cell[1], 18, cell[3], NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        D.text(ctx, cx, sum.y + 40, cell[2], 13, C.dim, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        if i < #cells then
            D.rect(ctx, sum.x + cw * i, sum.y + 12, 1, sum.h - 24,
                {C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 90}, 0)
        end
    end

    -- 制作鸣谢（分区标题 + 三行）。
    local cy = sum.y + sum.h + 16
    D.text(ctx, p.x + 24, cy, "制作鸣谢", 16, C.cyan)
    D.rect(ctx, p.x + 24, cy + 22, p.w - 48, 1, C.rail, 0)
    local credits = {
        { "制作者", "薪主" },
        { "导入素材", "工作室出品" },
        { "特别鸣谢", "TapTap" },
    }
    for i, line in ipairs(credits) do
        local ly = cy + 32 + (i - 1) * 24
        D.text(ctx, p.x + 28, ly, line[1] .. "：", 15, C.dim)
        D.text(ctx, p.x + 118, ly, line[2], 15, C.text)
    end

    local close = GetSettingsClose(w)
    PromptButton(ctx, close, "关闭", C.cyan, false)
end

---@param uiX number
---@param uiY number
---@param w number
---@param meta table
---@return string|nil action
---@return integer|nil index
function Settings.HitTest(uiX, uiY, w, meta)
    local music, sfx, restore, del = GetSettingRows(w)
    if Inside(music, uiX, uiY) then return "toggle_music", nil end
    if Inside(sfx, uiX, uiY) then return "toggle_sfx", nil end
    if Inside(restore, uiX, uiY) then return "restore_purchase", nil end
    if Inside(del, uiX, uiY) then return "reset_save", nil end
    if Inside(GetSettingsClose(w), uiX, uiY) then return "close", nil end
    return nil, nil
end

-- ============================================================================
-- 确认面板 绘制 / 命中
-- ============================================================================

---@param ctx any
---@param w number
---@param meta MetaState
function Settings.DrawConfirm(ctx, w, meta)
    local C = Colors()
    local danger = confirmReason_ == "delete"
    local tone = danger and C.error or C.warn
    D.backdrop(ctx, 0, 0, w, 960)
    local p = GetConfirmPanel(w)
    D.shell(ctx, p.x, p.y, p.w, p.h, 48)
    D.rect(ctx, p.x, p.y + 48, 3, 22, tone, 0)
    D.text(ctx, p.x + 16, p.y + 8, danger and "确认清空存档" or "确认恢复购买", 25, tone)

    -- 文字提示：说明后果 + 给出确认码。
    local prompt = danger
        and "此操作将删除本机全部进度、零件、天赋与解锁，且不可恢复。"
        or "将从平台重新同步已购商品与内容。"
    for i, line in ipairs(D.wrap(ctx, prompt, 15, p.w - 48)) do
        D.text(ctx, p.x + 24, p.y + 62 + (i - 1) * 20, line, 15, C.text)
    end
    D.text(ctx, p.x + 24, p.y + 128, "请在下方键盘输入确认码：", 15, C.dim)
    -- 确认码本体（醒目：金色/红色大号）。
    local code = ConfirmCode()
    D.text(ctx, p.x + 24, p.y + 152, code, 30, tone)

    -- 输入显示：逐位显示已输入字符，未输入位显示下划线占位。
    local dispY = p.y + 210
    D.rect(ctx, p.x + 24, dispY, p.w - 48, 44, C.rail, 6)
    local shown = input_ == "" and "—" or input_
    D.text(ctx, p.x + p.w * 0.5, dispY + 8, shown, 26, C.text,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    -- 键盘
    for i = 0, KEY_COLS * KEY_ROWS - 1 do
        local kr = GetKeyRect(w, i)
        local ch = KEY_CHARS[i + 1]
        local glow = D.controlFx(kr, true)
        D.panel(ctx, kr.x, kr.y, kr.w, kr.h, C.card, glow > 0.01 and C.cyan or C.rail, 8)
        D.text(ctx, kr.x + kr.w * 0.5, kr.y + kr.h * 0.5 - 15, ch, 28, C.text,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end

    local back, ok, cancel = GetConfirmButtons(w)
    PromptButton(ctx, back, "删除", C.cyanDim, false)
    local ready = input_ == ConfirmCode()
    PromptButton(ctx, ok, "确认", tone, true, not ready)
    PromptButton(ctx, cancel, "取消", C.cyanDim, false)
end

---@param uiX number
---@param uiY number
---@param w number
---@param meta table
---@return string|nil action
---@return integer|nil index
function Settings.HitTestConfirm(uiX, uiY, w, meta)
    for i = 0, KEY_COLS * KEY_ROWS - 1 do
        if Inside(GetKeyRect(w, i), uiX, uiY) then
            return "confirm_key", i + 1
        end
    end
    local back, ok, cancel = GetConfirmButtons(w)
    if Inside(back, uiX, uiY) then return "confirm_backspace", nil end
    if Inside(ok, uiX, uiY) then return "confirm_ok", nil end
    if Inside(cancel, uiX, uiY) then return "confirm_cancel", nil end
    return nil, nil
end

-- 编排层调用：键盘/按钮动作作用到输入串。
---@param ch string
function Settings.PushChar(ch)
    if #input_ < 12 then input_ = input_ .. ch end
end

function Settings.Backspace()
    input_ = input_:sub(1, -2)
end

---@return boolean
function Settings.IsConfirmed()
    return input_ == ConfirmCode()
end

---@return string
function Settings.GetInput()
    return input_
end

return Settings
