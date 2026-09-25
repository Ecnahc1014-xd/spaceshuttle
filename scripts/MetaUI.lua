-- MetaUI.lua
-- 元层界面（主菜单商业化区 + 各功能面板）的绘制与命中判定。
-- 与 Scene3DBackend 共用同一套 dark-tech 令牌与绘制原语（依赖注入，避免样式漂移）。
-- 只读 meta 状态与 MetaCatalog；所有状态变更由编排层（main.lua）执行。

local MetaCatalog = require "MetaCatalog"

local MetaUI = {}

-- 元层界面状态：由编排层（main.lua）组装，本模块只读。
---@class MetaTaskView
---@field id string
---@field name string
---@field target integer
---@field progress integer
---@field reward integer
---@field claimed boolean
---@field claimable boolean

---@class MetaState
---@field parts integer
---@field highScore integer
---@field screen string|nil 当前打开的功能面板："tasks"|"codex"|"rank"|"shop"|"wheel"
---@field supplyOpen boolean 每日补给弹窗是否显示
---@field supplyAvailable boolean
---@field supplyReward integer
---@field signInAvailable boolean
---@field signInStreak integer
---@field signInReward integer
---@field taskClaimable boolean
---@field tasks MetaTaskView[]
---@field codex table<string, boolean>
---@field codexUnlocked integer
---@field codexTotal integer
---@field codexClaimable boolean
---@field rankList table[]
---@field rankLoading boolean
---@field rankTotal integer
---@field skins table<string, boolean>
---@field selectedSkin string
---@field giftUsed table<string, integer>
---@field wheelReady boolean
---@field wheelPrize integer
---@field toast string|nil

-- ============================================================================
-- 依赖注入
-- ============================================================================

---@class MetaUiDeps
---@field C table 颜色令牌
---@field text fun(ctx:any, x:number, y:number, s:string, size:number, color:table, align:number|nil)
---@field rect fun(ctx:any, x:number, y:number, w:number, h:number, color:table, r:number|nil)
---@field stroke fun(ctx:any, x:number, y:number, w:number, h:number, color:table, r:number|nil, width:number|nil)
---@field panel fun(ctx:any, x:number, y:number, w:number, h:number, fill:table, border:table, r:number|nil)
---@field shell fun(ctx:any, x:number, y:number, w:number, h:number, titleH:number)
---@field corner fun(ctx:any, x:number, y:number, w:number, h:number, color:table, len:number, width:number)
---@field grid fun(ctx:any, x:number, y:number, w:number, h:number, step:number, alpha:number)
---@field rule fun(ctx:any, x:number, y:number, w:number, segments:number, color:table, active:number|nil)
---@field backdrop fun(ctx:any, x:number, y:number, w:number, h:number)
---@field wrap fun(ctx:any, s:string, size:number, maxW:number) 返回行数组

---@type MetaUiDeps
local D = nil

---@param deps MetaUiDeps
function MetaUI.Init(deps)
    D = deps
end

---@return table
local function Colors()
    return D.C
end

-- ============================================================================
-- 共用绘制原语
-- ============================================================================

---@param r table {x,y,w,h}
---@param px number
---@return boolean
local function Inside(r, px, py)
    return px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
end

---@param ctx any
---@param r table
---@param label string
---@param sub string
---@param kind string "primary" | "ad" | "ghost" | "disabled" | "danger"
local function Button(ctx, r, label, sub, kind)
    local C = Colors()
    local border, labelColor, fill
    if kind == "primary" then
        border, labelColor, fill = C.cyan, C.ink, C.cyan
    elseif kind == "ad" then
        -- 绿色＝看广告（免费获取），与青色主操作、金色稀有三分。
        border, labelColor, fill = C.ad, C.ad, C.card
    elseif kind == "disabled" then
        border, labelColor, fill = C.cyanDim, C.dim, C.widget
    elseif kind == "danger" then
        border, labelColor, fill = C.error, C.error, C.card
    else
        border, labelColor, fill = C.cyanDim, C.text, C.card
    end
    D.rect(ctx, r.x, r.y, r.w, r.h, fill, 6)
    if kind ~= "primary" then
        D.stroke(ctx, r.x, r.y, r.w, r.h, border, 6, 1.4)
    end
    local cx = r.x + r.w * 0.5
    if sub ~= "" then
        D.text(ctx, cx, r.y + r.h * 0.5 - 20, label, 17, labelColor,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        D.text(ctx, cx, r.y + r.h * 0.5 + 4, sub, 14,
            kind == "primary" and C.ink or C.dim, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    else
        D.text(ctx, cx, r.y + r.h * 0.5 - 9, label, 17, labelColor,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
end

---@param ctx any
---@param x number
---@param y number
---@param w number
---@param ratio number
---@param color table
local function ProgressBar(ctx, x, y, w, ratio, color)
    local C = Colors()
    local h = 8
    D.rect(ctx, x, y, w, h, C.widget, 4)
    local fill = math.max(0, math.min(1, ratio)) * w
    if fill > 0 then D.rect(ctx, x, y, fill, h, color, 4) end
end

-- 面板壳的纯几何（不含绘制）：命中判定与绘制共用，禁止两处各写一套。
---@param w number
---@return table content
---@return table close
local function GetShellLayout(w)
    local x, y = 18, 108
    local sw, sh = w - 36, 780
    return { x = x + 14, y = y + 60, w = sw - 28, h = sh - 76 },
           { x = x + sw - 46, y = y + 8, w = 36, h = 36 }
end

-- 面板壳：整页覆盖 + 标题栏 + 右上关闭。返回内容区 {x,y,w,h}。
---@param ctx any
---@param w number
---@param h number
---@param title string
---@param subtitle string
---@return table content
---@return table close
local function Shell(ctx, w, h, title, subtitle)
    local C = Colors()
    D.backdrop(ctx, 0, 92, w, h - 92)
    local x, y = 18, 108
    local sw, sh = w - 36, 780
    D.shell(ctx, x, y, sw, sh, 48)  -- 几何与 GetShellLayout 必须一致
    D.rect(ctx, x, y + 48, 3, 22, C.cyan, 0)
    D.text(ctx, x + 16, y + 10, title, 22, C.cyan)
    if subtitle ~= "" then
        D.text(ctx, x + sw - 58, y + 14, subtitle, 15, C.dim,
            NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    end
    local content, close = GetShellLayout(w)
    D.stroke(ctx, close.x, close.y, close.w, close.h, C.cyanDim, 6, 1.2)
    D.text(ctx, close.x + close.w * 0.5, close.y + 7, "X", 20, C.dim,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    D.grid(ctx, x + 14, y + 56, sw - 28, 20, 12, 14)
    return content, close
end

-- ============================================================================
-- 主菜单商业化区（货币栏 + 四入口 + 签到 / 每日补给）
-- ============================================================================

---@class MetaBarLayout
---@field wallet table
---@field entries table[]
---@field signin table
---@field supply table

---@return MetaBarLayout
local function GetMenuBarLayout()
    local wallet = { x = 18, y = 660, w = 504, h = 48 }
    local entries = {}
    local bw, gap = 120, 8
    for i = 1, 4 do
        entries[i] = { x = 18 + (i - 1) * (bw + gap), y = 716, w = bw, h = 54 }
    end
    local signin = { x = 18, y = 778, w = 248, h = 64 }
    local supply = { x = 274, y = 778, w = 248, h = 64 }
    return { wallet = wallet, entries = entries, signin = signin, supply = supply }
end

local ENTRY_DEFS = {
    { action = "open_shop",  label = "商城" },
    { action = "open_codex", label = "图鉴" },
    { action = "open_tasks", label = "任务" },
    { action = "open_rank",  label = "排行" },
}

---@param ctx any
---@param w number
---@param meta MetaState
function MetaUI.DrawMenuBar(ctx, w, meta)
    local C = Colors()
    local L = GetMenuBarLayout()

    -- 货币栏：只放软货币「零件」，右侧显示图鉴收集进度。
    D.panel(ctx, L.wallet.x, L.wallet.y, L.wallet.w, L.wallet.h, C.rail, C.cyanDim, 6)
    D.rect(ctx, L.wallet.x, L.wallet.y, 3, L.wallet.h, C.cyan, 0)
    D.text(ctx, L.wallet.x + 16, L.wallet.y + 6, "零件", 15, C.dim)
    D.text(ctx, L.wallet.x + 16, L.wallet.y + 22, string.format("%d", meta.parts or 0), 24, C.warn)
    D.text(ctx, L.wallet.x + L.wallet.w - 16, L.wallet.y + 8,
        string.format("图鉴 %d/%d", meta.codexUnlocked or 0, meta.codexTotal or 0), 15, C.dim,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    D.text(ctx, L.wallet.x + L.wallet.w - 16, L.wallet.y + 28,
        string.format("最高分 %d", meta.highScore or 0), 15, C.dim,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)

    -- 四个入口：任务带红点。
    for i, def in ipairs(ENTRY_DEFS) do
        local r = L.entries[i]
        local hot = (def.action == "open_tasks" and meta.taskClaimable)
            or (def.action == "open_codex" and meta.codexClaimable)
        D.rect(ctx, r.x, r.y, r.w, r.h, C.card, 6)
        D.stroke(ctx, r.x, r.y, r.w, r.h, hot and C.warn or C.cyanDim, 6, hot and 1.6 or 1.2)
        D.text(ctx, r.x + r.w * 0.5, r.y + r.h * 0.5 - 9, def.label, 18,
            hot and C.warn or C.text, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        if hot then
            D.rect(ctx, r.x + r.w - 14, r.y + 6, 8, 8, C.warn, 4)
        end
    end

    -- 每日签到（免费领取 → 青色，不用金色）
    local s = L.signin
    if meta.signInAvailable then
        D.rect(ctx, s.x, s.y, s.w, s.h, C.card, 6)
        D.stroke(ctx, s.x, s.y, s.w, s.h, C.cyan, 6, 1.5)
        D.text(ctx, s.x + 14, s.y + 10, "每日签到", 17, C.cyan)
        D.text(ctx, s.x + 14, s.y + 36,
            string.format("第 %d 天 · +%d 零件", meta.signInStreak or 1, meta.signInReward or 0),
            15, C.dim)
    else
        D.rect(ctx, s.x, s.y, s.w, s.h, C.widget, 6)
        D.stroke(ctx, s.x, s.y, s.w, s.h, C.cyanDim, 6, 1)
        D.text(ctx, s.x + 14, s.y + 10, "每日签到", 17, C.dim)
        D.text(ctx, s.x + 14, s.y + 36,
            string.format("已连续 %d 天", meta.signInStreak or 0), 15, C.dim)
    end

    -- 每日补给
    local p = L.supply
    if meta.supplyAvailable then
        D.rect(ctx, p.x, p.y, p.w, p.h, C.card, 6)
        D.stroke(ctx, p.x, p.y, p.w, p.h, C.cyan, 6, 1.5)
        D.text(ctx, p.x + 14, p.y + 10, "每日补给", 17, C.cyan)
        D.text(ctx, p.x + 14, p.y + 36, "待领取", 15, C.dim)
    else
        D.rect(ctx, p.x, p.y, p.w, p.h, C.widget, 6)
        D.stroke(ctx, p.x, p.y, p.w, p.h, C.cyanDim, 6, 1)
        D.text(ctx, p.x + 14, p.y + 10, "每日补给", 17, C.dim)
        D.text(ctx, p.x + 14, p.y + 36, "明日再来", 15, C.dim)
    end

    if meta.toast and meta.toast ~= "" then
        D.text(ctx, w * 0.5, 862, meta.toast, 16, C.warn,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
end

---@return string|nil action
function MetaUI.HitTestMenuBar(uiX, uiY, meta)
    local L = GetMenuBarLayout()
    for i, def in ipairs(ENTRY_DEFS) do
        if Inside(L.entries[i], uiX, uiY) then return def.action end
    end
    if Inside(L.signin, uiX, uiY) then return "signin" end
    if Inside(L.supply, uiX, uiY) then return "supply" end
    return nil
end

-- ============================================================================
-- 每日补给弹窗
-- ============================================================================

---@return table claim
---@return table double
local function GetSupplyLayout(w)
    local bw, gap = 216, 12
    local x = (w - bw * 2 - gap) * 0.5
    return { x = x, y = 560, w = bw, h = 52 },
           { x = x + bw + gap, y = 560, w = bw, h = 52 }
end

---@param ctx any
---@param w number
---@param meta MetaState
function MetaUI.DrawSupplyPopup(ctx, w, meta)
    local C = Colors()
    D.backdrop(ctx, 0, 92, w, 960 - 92)
    local x, y, sw, sh = 40, 300, w - 80, 340
    D.shell(ctx, x, y, sw, sh, 44)
    D.rect(ctx, x, y + 44, 3, 20, C.cyan, 0)
    D.text(ctx, x + 16, y + 10, "每日补给", 20, C.cyan)

    D.text(ctx, w * 0.5, y + 74, "今日补给已就绪", 26, C.text,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    D.text(ctx, w * 0.5, y + 116, string.format("零件 ×%d", meta.supplyReward or 0), 34, C.warn,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    D.text(ctx, w * 0.5, y + 166, "看广告可再翻一倍", 16, C.dim,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    D.grid(ctx, x + 20, y + 200, sw - 40, 40, 12, 14)

    local claim, double = GetSupplyLayout(w)
    Button(ctx, claim, "直接领取", "", "ghost")
    Button(ctx, double, "看广告 双倍", string.format("共 %d", (meta.supplyReward or 0) * 2), "ad")
end

---@return string|nil action
function MetaUI.HitTestSupplyPopup(uiX, uiY, w)
    if uiX < 0 or uiX > w or uiY < 0 or uiY > 960 then return nil end
    local claim, double = GetSupplyLayout(w)
    if Inside(double, uiX, uiY) then return "supply_double" end
    if Inside(claim, uiX, uiY) then return "supply_claim" end
    -- 点窗外也算领取（直接领，不倒扣）
    return "supply_claim"
end

-- ============================================================================
-- 任务面板
-- ============================================================================

---@param ctx any
---@param w number
---@param meta MetaState
---@return table content
---@return table close
local function DrawTasks(ctx, w, meta)
    local C = Colors()
    local content, close = Shell(ctx, w, 960, "每日任务", "")
    local tasks = meta.tasks or {}
    local rowH, gap = 108, 12
    local y = content.y + 16
    D.text(ctx, content.x + 4, y, "完成每日任务，领取零件", 16, C.dim)
    y = y + 32
    for i, task in ipairs(tasks) do
        local r = { x = content.x, y = y + (i - 1) * (rowH + gap), w = content.w, h = rowH }
        D.panel(ctx, r.x, r.y, r.w, r.h, C.card, task.claimable and C.warn or C.cyanDim, 6)
        D.text(ctx, r.x + 16, r.y + 12, task.name, 18, C.text)
        D.text(ctx, r.x + 16, r.y + 40,
            string.format("进度 %d / %d", task.progress, task.target), 15, C.dim)
        ProgressBar(ctx, r.x + 16, r.y + 66, r.w - 180, task.progress / math.max(1, task.target),
            task.claimable and C.warn or C.cyan)
        local btn = { x = r.x + r.w - 148, y = r.y + 24, w = 132, h = 60 }
        if task.claimed then
            Button(ctx, btn, "已领取", "", "disabled")
        elseif task.claimable then
            -- 任务领取是免费产出，用青色主操作而不是绿色广告色。
            Button(ctx, btn, "领取", string.format("+%d", task.reward), "primary")
        else
            Button(ctx, btn, string.format("+%d", task.reward), "进行中", "disabled")
        end
    end
    return content, close
end

---@return string|nil action
---@return integer|nil index
local function HitTestTasks(uiX, uiY, w, meta)
    local L, close = GetShellLayout(w)
    if Inside(close, uiX, uiY) then return "close", nil end
    local tasks = meta.tasks or {}
    local rowH, gap = 108, 12
    local y = L.y + 48
    for i = 1, #tasks do
        local r = { x = L.x, y = y + (i - 1) * (rowH + gap), w = L.w, h = rowH }
        local btn = { x = r.x + r.w - 148, y = r.y + 24, w = 132, h = 60 }
        if Inside(btn, uiX, uiY) then return "claim", i end
    end
    return nil, nil
end

-- ============================================================================
-- 图鉴面板
-- ============================================================================

---@param ctx any
---@param w number
---@param meta MetaState
---@return table content
---@return table close
local function DrawCodex(ctx, w, meta)
    local C = Colors()
    local content, close = Shell(ctx, w, 960, "敌机图鉴",
        string.format("%d / %d", meta.codexUnlocked or 0, meta.codexTotal or 0))
    local entries = MetaCatalog.GetCodex()
    local cw, ch, gap = 240, 128, 12
    local y0 = content.y + 16
    for i, entry in ipairs(entries) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local x = content.x + col * (cw + gap)
        local y = y0 + row * (ch + gap)
        local owned = meta.codex and meta.codex[entry.key] == true
        D.panel(ctx, x, y, cw, ch, C.card, owned and C.cyanDim or C.widget, 6)
        D.rect(ctx, x, y, 3, ch, owned and C.cyan or C.widget, 0)
        D.text(ctx, x + 14, y + 10, entry.name, 19, owned and C.text or C.dim)
        local lines = D.wrap(ctx, entry.note, 14, cw - 28)
        for li = 1, math.min(2, #lines) do
            D.text(ctx, x + 14, y + 38 + (li - 1) * 20, lines[li], 14, C.dim)
        end
        D.text(ctx, x + 14, y + ch - 26, owned and "已收录" or "未收录", 14,
            owned and C.cyan or C.dim)
        D.text(ctx, x + cw - 14, y + ch - 26, string.format("+%d", entry.reward), 14,
            owned and C.warn or C.dim, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    end
    return content, close
end

---@return string|nil action
local function HitTestCodex(uiX, uiY, w)
    local _, close = GetShellLayout(w)
    if Inside(close, uiX, uiY) then return "close" end
    return nil
end

-- ============================================================================
-- 排行榜面板（全服，clientCloud）
-- ============================================================================

---@param ctx any
---@param w number
---@param meta MetaState
---@return table content
---@return table close
local function DrawRank(ctx, w, meta)
    local C = Colors()
    local content, close = Shell(ctx, w, 960, "全服排行榜",
        meta.rankTotal and ("共 " .. tostring(meta.rankTotal) .. " 人") or "")
    local list = meta.rankList or {}
    if meta.rankLoading then
        D.text(ctx, content.x + content.w * 0.5, content.y + 200, "排行榜加载中…", 18, C.dim,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        return content, close
    end
    if #list == 0 then
        D.text(ctx, content.x + content.w * 0.5, content.y + 180, "暂无上榜记录", 20, C.text,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        D.text(ctx, content.x + content.w * 0.5, content.y + 214, "打出更高分就能上榜", 16, C.dim,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        return content, close
    end
    local rowH = 56
    for i, item in ipairs(list) do
        local y = content.y + 14 + (i - 1) * (rowH + 4)
        local r = { x = content.x, y = y, w = content.w, h = rowH }
        local mine = item.isMe == true
        D.panel(ctx, r.x, r.y, r.w, r.h, mine and C.widget or C.card,
            mine and C.cyan or C.cyanDim, 6)
        local medal = C.dim
        if item.rank == 1 then medal = C.warn
        elseif item.rank <= 3 then medal = C.cyan end
        D.text(ctx, r.x + 18, r.y + 16, string.format("%d", item.rank), 22, medal)
        D.text(ctx, r.x + 72, r.y + 18, item.name or "玩家", 18, mine and C.cyan or C.text)
        D.text(ctx, r.x + r.w - 18, r.y + 16, string.format("%d", item.score or 0), 20,
            mine and C.cyan or C.text, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    end
    return content, close
end

---@return string|nil action
local function HitTestRank(uiX, uiY, w)
    local _, close = GetShellLayout(w)
    if Inside(close, uiX, uiY) then return "close" end
    return nil
end

-- ============================================================================
-- 商城面板（只卖软货币零件；无内购）
-- ============================================================================

---@param ctx any
---@param w number
---@param meta MetaState
---@return table content
---@return table close
local function DrawShop(ctx, w, meta)
    local C = Colors()
    local content, close = Shell(ctx, w, 960, "商城",
        string.format("零件 %d", meta.parts or 0))
    local y = content.y + 16
    D.text(ctx, content.x + 4, y, "车辆涂装", 18, C.cyan)
    y = y + 32

    local skins = MetaCatalog.GetSkins()
    local rowH = 74
    for i, skin in ipairs(skins) do
        local r = { x = content.x, y = y + (i - 1) * (rowH + 8), w = content.w, h = rowH }
        local owned = skin.cost == 0 or (meta.skins and meta.skins[skin.key] == true)
        local selected = meta.selectedSkin == skin.key
        D.panel(ctx, r.x, r.y, r.w, r.h, C.card, selected and C.cyan or C.cyanDim, 6)
        -- 色卡
        D.rect(ctx, r.x + 14, r.y + 14, 30, 46, { skin.paint[1], skin.paint[2], skin.paint[3], 255 }, 4)
        D.rect(ctx, r.x + 48, r.y + 14, 14, 46, { skin.panel[1], skin.panel[2], skin.panel[3], 255 }, 4)
        D.text(ctx, r.x + 76, r.y + 14, skin.name, 18, C.text)
        D.text(ctx, r.x + 76, r.y + 40,
            owned and (selected and "当前使用" or "已拥有") or string.format("售价 %d 零件", skin.cost),
            15, selected and C.cyan or C.dim)
        local btn = { x = r.x + r.w - 148, y = r.y + 13, w = 132, h = 48 }
        if selected then
            Button(ctx, btn, "使用中", "", "disabled")
        elseif owned then
            Button(ctx, btn, "使用", "", "ghost")
        elseif (meta.parts or 0) >= skin.cost then
            Button(ctx, btn, "购买", string.format("%d", skin.cost), "primary")
        else
            Button(ctx, btn, "零件不足", string.format("%d", skin.cost), "disabled")
        end
    end
    y = y + #skins * (rowH + 8) + 12

    D.text(ctx, content.x + 4, y, "免费补给", 18, C.cyan)
    y = y + 30
    local gifts = MetaCatalog.GetShopEntries()
    for i, gift in ipairs(gifts) do
        local r = { x = content.x, y = y + (i - 1) * 68, w = content.w, h = 60 }
        local used = meta.giftUsed and meta.giftUsed[gift.key] or 0
        local limit = MetaCatalog.GetAdGiftDailyLimit(gift.key)
        D.panel(ctx, r.x, r.y, r.w, r.h, C.card, used < limit and C.ad or C.cyanDim, 6)
        D.text(ctx, r.x + 16, r.y + 8, gift.name, 18, used < limit and C.text or C.dim)
        D.text(ctx, r.x + 16, r.y + 32, gift.desc, 15, C.dim)
        local btn = { x = r.x + r.w - 148, y = r.y + 6, w = 132, h = 48 }
        if used < limit then
            Button(ctx, btn, "看广告", string.format("%d/%d", used, limit), "ad")
        else
            Button(ctx, btn, "今日已领", "", "disabled")
        end
    end
    return content, close
end

---@return string|nil action
---@return integer|nil index
local function HitTestShop(uiX, uiY, w, meta)
    local L, close = GetShellLayout(w)
    if Inside(close, uiX, uiY) then return "close", nil end
    local rowH = 74
    local y = L.y + 48
    local skins = MetaCatalog.GetSkins()
    for i = 1, #skins do
        local r = { x = L.x, y = y + (i - 1) * (rowH + 8), w = L.w, h = rowH }
        local btn = { x = r.x + r.w - 148, y = r.y + 13, w = 132, h = 48 }
        if Inside(btn, uiX, uiY) then return "buy_skin", i end
    end
    y = y + #skins * (rowH + 8) + 42
    local gifts = MetaCatalog.GetShopEntries()
    for i = 1, #gifts do
        local r = { x = L.x, y = y + (i - 1) * 68, w = L.w, h = 60 }
        local btn = { x = r.x + r.w - 148, y = r.y + 6, w = 132, h = 48 }
        if Inside(btn, uiX, uiY) then return "ad_gift", i end
    end
    return nil, nil
end

-- ============================================================================
-- 幸运转盘
-- ============================================================================

---@return table spin
---@return number cx
---@return number cy
---@return number radius
local function GetWheelLayout(w)
    local cx, cy, radius = w * 0.5, 420, 150
    return { x = cx - 120, y = 660, w = 240, h = 58 }, cx, cy, radius
end

---@param ctx any
---@param w number
---@param meta MetaState
---@return table content
---@return table close
local function DrawWheel(ctx, w, meta)
    local C = Colors()
    local content, close = Shell(ctx, w, 960, "幸运转盘", "每日一次")
    local spin, cx, cy, radius = GetWheelLayout(w)
    local prizes = MetaCatalog.GetWheelPrizes()
    local n = #prizes
    local step = math.pi * 2 / n
    local palette = { C.cyanDim, C.warn, C.cyan, C.warn, C.cyanDim, C.warn, C.cyan, C.warn }

    nvgSave(ctx)
    for i = 1, n do
        local a0 = (i - 1) * step - math.pi * 0.5
        local a1 = a0 + step
        local col = palette[i] or C.cyanDim
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, cx, cy)
        nvgArc(ctx, cx, cy, radius, a0, a1, NVG_CW)
        nvgClosePath(ctx)
        nvgFillColor(ctx, nvgRGBA(col[1], col[2], col[3], 46))
        nvgFill(ctx)
        nvgStrokeColor(ctx, nvgRGBA(col[1], col[2], col[3], 170))
        nvgStrokeWidth(ctx, 1)
        nvgStroke(ctx)
        -- 扇区金额
        local mid = (a0 + a1) * 0.5
        local tx = cx + math.cos(mid) * radius * 0.72
        local ty = cy + math.sin(mid) * radius * 0.72
        D.text(ctx, tx, ty - 8, tostring(prizes[i]), 16, col,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
    nvgRestore(ctx)
    D.stroke(ctx, cx - radius, cy - radius, radius * 2, radius * 2, C.cyanDim, radius, 2)

    local label = meta.wheelReady and "看广告 免费抽一次" or "今日已抽取"
    Button(ctx, spin, label,
        meta.wheelReady and "必得 120 零件以上" or "明日再来", meta.wheelReady and "ad" or "disabled")
    if meta.wheelPrize and meta.wheelPrize > 0 then
        D.text(ctx, w * 0.5, spin.y + spin.h + 14,
            string.format("恭喜获得 %d 零件", meta.wheelPrize), 18, C.warn,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
    return content, close
end

---@return string|nil action
local function HitTestWheel(uiX, uiY, w)
    local _, close = GetShellLayout(w)
    if Inside(close, uiX, uiY) then return "close" end
    local spin = GetWheelLayout(w)
    if Inside(spin, uiX, uiY) then return "wheel_spin" end
    return nil
end

-- ============================================================================
-- 分发
-- ============================================================================

---@param ctx any
---@param w number
---@param meta MetaState
function MetaUI.DrawScreen(ctx, w, meta)
    local screen = meta.screen
    if screen == "tasks" then
        DrawTasks(ctx, w, meta)
    elseif screen == "codex" then
        DrawCodex(ctx, w, meta)
    elseif screen == "rank" then
        DrawRank(ctx, w, meta)
    elseif screen == "shop" then
        DrawShop(ctx, w, meta)
    elseif screen == "wheel" then
        DrawWheel(ctx, w, meta)
    end
end

---@return string|nil action
---@return integer|nil index
function MetaUI.HitTestScreen(uiX, uiY, w, meta)
    local screen = meta.screen
    if screen == "tasks" then
        return HitTestTasks(uiX, uiY, w, meta)
    elseif screen == "codex" then
        return HitTestCodex(uiX, uiY, w)
    elseif screen == "rank" then
        return HitTestRank(uiX, uiY, w)
    elseif screen == "shop" then
        return HitTestShop(uiX, uiY, w, meta)
    elseif screen == "wheel" then
        return HitTestWheel(uiX, uiY, w)
    end
    return nil, nil
end

return MetaUI
