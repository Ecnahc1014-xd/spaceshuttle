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
---@field gems integer 氪金代币（钻石）余额，来自服务端权威
---@field highScore integer
---@field screen string|nil 当前打开的功能面板："tasks"|"codex"|"rank"|"shop"|"wheel"|"pass"|"recharge"
---@field supplyOpen boolean 每日补给弹窗是否显示
---@field supplyAvailable boolean
---@field supplyReward integer
---@field signInAvailable boolean
---@field signInStreak integer
---@field signInReward integer
---@field taskClaimable boolean
---@field tasks MetaTaskView[]
---@field codex table<string, boolean>
---@field aircraft table<string, table> 图鉴剪影（来自 AircraftPixelData，同一份网格）
---@field codexUnlocked integer
---@field codexTotal integer
---@field codexClaimable boolean
---@field passLevel integer
---@field passProgress integer
---@field passTarget integer
---@field passRewards table[]
---@field passClaimable boolean
---@field premiumPass boolean 付费档案轨（服务端权威标志）
---@field premiumPassCost integer 解锁付费轨所需钻石
---@field firstGiftAvailable boolean 首充礼包是否在限时窗内且未购买
---@field firstGiftSeconds number 首充限时窗剩余秒数
---@field firstGiftPrice number|nil 首充礼包平台价格（nil=未开通）
---@field firstGiftClaimed boolean
---@field signinRewards integer[]
---@field rankList table[]
---@field rankLoading boolean
---@field rankTotal integer
---@field myRank integer|nil 当前玩家全服名次，nil 表示未上榜或尚未加载
---@field myRankLoading boolean
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
---@field progress fun(ctx:any, x:number, y:number, w:number, ratio:number, color:table, height:number|nil)
---@field shell fun(ctx:any, x:number, y:number, w:number, h:number, titleH:number)
---@field corner fun(ctx:any, x:number, y:number, w:number, h:number, color:table, len:number, width:number)
---@field grid fun(ctx:any, x:number, y:number, w:number, h:number, step:number, alpha:number)
---@field rule fun(ctx:any, x:number, y:number, w:number, segments:number, color:table, active:number|nil)
---@field backdrop fun(ctx:any, x:number, y:number, w:number, h:number)
---@field wrap fun(ctx:any, s:string, size:number, maxW:number) 返回行数组
---@field icon fun(ctx:any, key:string, x:number, y:number, size:number, alpha:number|nil) 绘制 32×32 像素图标（可选资源，返回 false 表示未加载）

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
        border, labelColor, fill = C.ad, C.ad, C.card
    elseif kind == "disabled" then
        border, labelColor, fill = C.cyanDim, C.dim, C.widget
    elseif kind == "gold" then
        border, labelColor, fill = C.warn, C.warn, C.card
    elseif kind == "danger" then
        border, labelColor, fill = C.error, C.error, C.card
    else
        border, labelColor, fill = C.cyanDim, C.text, C.card
    end

    D.panel(ctx, r.x, r.y, r.w, r.h, fill, border, 6)
    if kind == "primary" then
        D.rect(ctx, r.x + 6, r.y + 2, math.max(0, r.w - 12), 1, {255, 255, 255, 90}, 0)
    else
        D.rect(ctx, r.x, r.y + 2, 3, math.max(0, r.h - 4), border, 1)
    end
    local cx = r.x + r.w * 0.5
    if sub ~= "" then
        D.text(ctx, cx, r.y + r.h * 0.5 - 18, label, 16, labelColor,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        D.text(ctx, cx, r.y + r.h * 0.5 + 5, sub, 13,
            kind == "primary" and C.ink or C.dim, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    else
        D.text(ctx, cx, r.y + r.h * 0.5 - 8, label, 16, labelColor,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
end

---@param ctx any
---@param x number
---@param y number
---@param w number
---@param ratio number
---@param color table
local function ProgressBar(ctx, x, y, w, ratio, color, height)
    local C = Colors()
    D.progress(ctx, x, y, w, ratio, color, height or 8)
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
    D.backdrop(ctx, 0, 0, w, h)
    local x, y = 18, 108
    local sw, sh = w - 36, 780
    D.shell(ctx, x, y, sw, sh, 48)
    D.rect(ctx, x, y + 48, 3, 22, C.cyan, 0)

    local headerIcon = {
        ["每日任务"] = "task",
        ["敌机图鉴"] = "codex",
        ["全服排行榜"] = "rank",
        ["车型商店"] = "shop",
        ["幸运转盘"] = "premium_wheel_medal",
        ["战斗档案"] = "premium_pass_crest",
    }
    local iconKey = headerIcon[title]
    local titleX = x + 16
    if iconKey and D.icon(ctx, iconKey, x + 12, y + 8, 32, 1) then
        titleX = x + 52
    end
    D.text(ctx, titleX, y + 10, title, 22, C.text)
    if subtitle ~= "" then
        D.rect(ctx, x + sw - 178, y + 14, 2, 18, C.warn, 0)
        D.text(ctx, x + sw - 58, y + 14, subtitle, 14, C.dim,
            NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    end
    local content, close = GetShellLayout(w)
    D.panel(ctx, close.x, close.y, close.w, close.h, C.card, C.cyanDim, 6)
    D.text(ctx, close.x + close.w * 0.5, close.y + 6, "×", 21, C.text,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    D.grid(ctx, x + 14, y + 56, sw - 28, 20, 12, 10)
    D.rule(ctx, x + 16, y + 54, sw - 32, 12, C.cyanDim, 4)
    return content, close
end

-- ============================================================================
-- v0.12.6 主菜单变现闭环三段式（用户拍板「闭环三段式」方案）：
--   图鉴展示条 → 钱包连接器（零件/钻石两端同框）→ 今日福利(免费领) → 养成收藏(花/付费)。
--   全部几何集中在 GetMenuBarLayout，绘制与命中共用同一来源，禁止第二套常量。
-- ============================================================================

---@class MetaBarLayout
---@field fleet table
---@field wallet table
---@field daily table[]
---@field grow table[]

local function GetMenuBarLayout()
    local bw, gap = 120, 8
    -- 行卡按数量水平居中（v0.12.7：签到并入充值后，今日福利只剩 3 卡）
    local function row(y, h, n)
        local total = n * bw + (n - 1) * gap
        local x0 = 18 + (504 - total) * 0.5
        local r = {}
        for i = 1, n do
            r[i] = { x = x0 + (i - 1) * (bw + gap), y = y, w = bw, h = h }
        end
        return r
    end
    return {
        fleet  = { x = 18, y = 390, w = 504, h = 92 },
        wallet = { x = 18, y = 496, w = 504, h = 56 },
        daily  = row(588, 92, 3),
        grow   = row(716, 92, 4),
    }
end

---@param ctx any
---@param w number
---@param meta MetaState
function MetaUI.DrawHomeFleet(ctx, w, meta)
    local C = Colors()
    local L = GetMenuBarLayout()
    local r = L.fleet
    D.panel(ctx, r.x, r.y, r.w, r.h, C.rail, C.cyanDim, 6)
    D.text(ctx, r.x + 14, r.y + 8, "敌机图鉴", 15, C.cyan)
    D.text(ctx, r.x + r.w - 14, r.y + 8,
        string.format("收录 %d/%d ›", meta.codexUnlocked or 0, meta.codexTotal or 0), 15, C.dim,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    local entries = MetaCatalog.GetCodex()
    local n = math.max(1, math.min(8, #entries))
    local slotW = (r.w - 24) / n
    for i = 1, n do
        local entry = entries[i]
        local owned = meta.codex and meta.codex[entry.key] == true
        local aircraft = meta.aircraft and meta.aircraft[entry.key]
        if aircraft then
            local gridW = aircraft.gridW or 1
            local gridH = aircraft.gridH or 1
            local scale = math.min(15, 40 / math.max(1, gridW), (r.h - 46) / math.max(1, gridH))
            local left = r.x + 12 + (i - 1) * slotW + (slotW - gridW * scale) * 0.5
            local top = r.y + 34 + ((r.h - 46) - gridH * scale) * 0.5
            for _, cell in ipairs(aircraft.rows or {}) do
                D.rect(ctx, left + (cell.col - 1) * scale, top + (cell.row - 1) * scale,
                    scale - 0.5, scale - 0.5, owned and C.cyan or C.widget, 0)
            end
        end
    end
end

---@return integer
local function CountClaimableTasks(tasks)
    local n = 0
    for _, t in ipairs(tasks or {}) do
        if t.claimable then n = n + 1 end
    end
    return n
end

-- 今日福利：全部「免费领取/看广告免费」——tone=free 青、tone=ad 绿（三色语义）。
-- v0.12.7：每日签到并入充值弹层（用户要求），菜单只剩 3 卡（水平居中见 GetMenuBarLayout）。
local function GetDailyDefs(meta)
    local taskCount = CountClaimableTasks(meta.tasks)
    return {
        { action = "supply", icon = "premium_supply_crate", label = "每日补给",
          sub = meta.supplyAvailable and "待领取" or "明日再来",
          hot = meta.supplyAvailable, tone = "free" },
        { action = "open_tasks", icon = "task", label = "每日任务",
          sub = taskCount > 0 and string.format("%d 项可领", taskCount) or "对战积累",
          hot = taskCount > 0, tone = "free" },
        { action = "open_wheel", icon = "premium_wheel_medal", label = "幸运转盘",
          sub = meta.wheelReady and "看广告免费" or "今日已抽取",
          hot = meta.wheelReady, tone = "ad" },
    }
end

-- 养成收藏：花零件/成长线/付费加速。v0.12.7：用户否决开局首充促销——
-- 菜单不再用金框「新手礼包」顶替图鉴位；首充只在玩家主动打开充值弹层时出现。
local function GetGrowDefs(meta)
    local passSub = meta.passClaimable and "有奖励可领"
        or ("Lv." .. tostring(meta.passLevel or 1) .. (meta.premiumPass and " · 奖励×2" or ""))
    return {
        { action = "open_shop", icon = "shop", label = "车型商店",
          sub = "零件换新车", hot = false, tone = "free" },
        { action = "open_pass", icon = "premium_pass_crest", label = "战斗档案",
          sub = passSub, hot = meta.passClaimable, tone = "free" },
        { action = "open_codex", icon = "codex", label = "敌机图鉴",
          sub = string.format("收录 %d/%d", meta.codexUnlocked or 0, meta.codexTotal or 0),
          hot = meta.codexClaimable, tone = "free" },
        { action = "open_rank", icon = "rank", label = "排行榜",
          sub = "全服最高分", hot = false, tone = "free" },
    }
end

---@param ctx any
---@param w number
---@param meta MetaState
function MetaUI.DrawMenuBar(ctx, w, meta)
    local C = Colors()
    local L = GetMenuBarLayout()

    MetaUI.DrawHomeFleet(ctx, w, meta)

    D.panel(ctx, L.wallet.x, L.wallet.y, L.wallet.w, L.wallet.h, C.rail, C.cyanDim, 6)
    D.rect(ctx, L.wallet.x, L.wallet.y, 3, L.wallet.h, C.cyan, 0)
    D.icon(ctx, "parts", L.wallet.x + 12, L.wallet.y + 12, 32)
    D.text(ctx, L.wallet.x + 52, L.wallet.y + 8, "零件", 13, C.dim)
    D.text(ctx, L.wallet.x + 52, L.wallet.y + 26, string.format("%d", meta.parts or 0), 23, C.text)
    D.rect(ctx, L.wallet.x + 184, L.wallet.y + 10, 1, L.wallet.h - 20,
        {C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 110}, 0)
    D.icon(ctx, "premium_energy_core", L.wallet.x + 194, L.wallet.y + 12, 32)
    D.text(ctx, L.wallet.x + 232, L.wallet.y + 8, "钻石", 13, C.dim)
    D.text(ctx, L.wallet.x + 232, L.wallet.y + 26,
        meta.offline and "—" or string.format("%d", meta.gems or 0), 23, C.warn)

    local wb = { x = L.wallet.x + L.wallet.w - 112, y = L.wallet.y + 9, w = 96, h = 38 }
    D.panel(ctx, wb.x, wb.y, wb.w, wb.h, C.warn, C.warn, 6)
    D.rect(ctx, wb.x + 6, wb.y + 3, wb.w - 12, 1, {255, 255, 255, 100}, 0)
    D.icon(ctx, "premium_energy_core", wb.x + 8, wb.y + 5, 28)
    D.text(ctx, wb.x + 64, wb.y + 11, "充值", 16, C.ink,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    local rows = {
        { label = "今日福利", rects = L.daily, defs = GetDailyDefs(meta) },
        { label = "养成收藏", rects = L.grow, defs = GetGrowDefs(meta) },
    }
    for _, rowDef in ipairs(rows) do
        D.text(ctx, 18, rowDef.rects[1].y - 14, rowDef.label, 15, C.cyanDim)
        D.rect(ctx, 112, rowDef.rects[1].y - 7, 36, 1, {C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 90}, 0)
        for i, def in ipairs(rowDef.defs) do
            local rr = rowDef.rects[i]
            local border = def.hot and (def.tone == "ad" and C.ad or (def.tone == "gold" and C.warn or C.cyan))
                or C.cyanDim
            D.panel(ctx, rr.x, rr.y, rr.w, rr.h, C.card, border, 6)
            D.rect(ctx, rr.x + 9, rr.y + 1, rr.w - 18, 1,
                {border[1], border[2], border[3], def.hot and 100 or 40}, 0)
            D.panel(ctx, rr.x + rr.w * 0.5 - 21, rr.y + 7, 42, 40, C.rail, border, 5)
            local drewIcon = D.icon(ctx, def.icon, rr.x + rr.w * 0.5 - 16, rr.y + 11, 32,
                def.hot and 1 or 0.82)
            D.text(ctx, rr.x + rr.w * 0.5, rr.y + (drewIcon and 51 or 18),
                def.label, 15, def.hot and C.text or C.dim,
                NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            local lines = D.wrap(ctx, def.sub, 12, rr.w - 10)
            D.text(ctx, rr.x + rr.w * 0.5, rr.y + 72, lines[1] or "", 12,
                def.tone == "ad" and C.ad or (def.tone == "gold" and C.warn or C.dim),
                NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            if def.hot then
                D.rect(ctx, rr.x + rr.w - 12, rr.y + 7, 5, 5, border, 3)
            end
        end
    end

    if meta.toast and meta.toast ~= "" then
        D.text(ctx, w * 0.5, 848, meta.toast, 16, C.warn,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
end

---@return string|nil action
function MetaUI.HitTestMenuBar(uiX, uiY, meta)
    local L = GetMenuBarLayout()
    if Inside(L.fleet, uiX, uiY) then return "open_codex" end
    if Inside(L.wallet, uiX, uiY) then return "open_recharge" end
    for i, def in ipairs(GetDailyDefs(meta)) do
        if Inside(L.daily[i], uiX, uiY) then return def.action end
    end
    for i, def in ipairs(GetGrowDefs(meta)) do
        if Inside(L.grow[i], uiX, uiY) then return def.action end
    end
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
    D.backdrop(ctx, 0, 0, w, 960)
    local x, y, sw, sh = 40, 284, w - 80, 372
    D.shell(ctx, x, y, sw, sh, 46)
    D.rect(ctx, x, y + 46, 3, 22, C.cyan, 0)
    D.icon(ctx, "premium_supply_crate", x + 14, y + 7, 32)
    D.text(ctx, x + 54, y + 10, "每日补给", 19, C.text)
    D.text(ctx, x + sw - 16, y + 14, "补给批次  /  01", 12, C.dim,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)

    local hero = {x=x+20,y=y+64,w=sw-40,h=150}
    D.panel(ctx, hero.x, hero.y, hero.w, hero.h, C.rail, C.cyanDim, 8)
    D.panel(ctx, hero.x + 20, hero.y + 31, 88, 88, C.panel, C.warnDim, 8)
    D.icon(ctx, "premium_supply_crate", hero.x + 48, hero.y + 59, 32, 1)
    D.text(ctx, hero.x + 128, hero.y + 23, "今日物资配额", 13, C.cyanDim)
    D.text(ctx, hero.x + 128, hero.y + 50,
        string.format("%d", meta.supplyReward or 0), 36, C.warn)
    D.text(ctx, hero.x + 128, hero.y + 94, "零件", 14, C.dim)
    D.progress(ctx, hero.x + 128, hero.y + 120, hero.w - 148, 1, C.warn, 7)
    D.text(ctx, x + 22, y + 232, "选择领取方式", 13, C.dim)
    D.rect(ctx, x + 128, y + 240, sw - 150, 1, {C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 75}, 0)
    D.grid(ctx, x + 16, y + sh - 72, sw - 32, 48, 12, 8)

    local claim, double = GetSupplyLayout(w)
    Button(ctx, claim, "直接领取", "零件 ×" .. tostring(meta.supplyReward or 0), "ghost")
    Button(ctx, double, "看广告 · 双倍补给",
        "共 " .. tostring((meta.supplyReward or 0) * 2) .. " 零件", "ad")
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
    local cw, ch, gap = 226, 146, 12
    local y0 = content.y + 16
    local rowsPerPage = 4
    local totalPages = math.max(1, math.ceil(#entries / (rowsPerPage * 2)))
    local page = math.max(1, math.min(totalPages, meta.codexPage or 1))
    D.text(ctx, content.x + content.w * 0.5, content.y + content.h - 22,
        string.format("第 %d/%d 页 · 点击下方切换", page, totalPages), 14, C.dim,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgSave(ctx)
    nvgIntersectScissor(ctx, content.x, content.y, content.w, content.h - 34)
    for i = (page - 1) * rowsPerPage * 2 + 1, math.min(#entries, page * rowsPerPage * 2) do
        local entry = entries[i]
        local index = i - (page - 1) * rowsPerPage * 2
        local col = (index - 1) % 2
        local row = math.floor((index - 1) / 2)
        local x = content.x + col * (cw + gap)
        local y = y0 + row * (ch + gap)
        local owned = meta.codex and meta.codex[entry.key] == true
        D.panel(ctx, x, y, cw, ch, C.card, owned and C.cyanDim or C.widget, 6)
        D.rect(ctx, x, y, 3, ch, owned and C.cyan or C.widget, 0)
        D.text(ctx, x + 14, y + 10, entry.name, 19, owned and C.text or C.dim)
        local aircraft = meta.aircraft and meta.aircraft[entry.key]
        if aircraft then
            local rows = aircraft.rows or {}
            local scale = math.min(5, 80 / math.max(1, aircraft.gridW), 52 / math.max(1, aircraft.gridH))
            local left = x + (cw - aircraft.gridW * scale) * 0.5
            for _, cell in ipairs(rows) do
                D.rect(ctx, left + (cell.col - 1) * scale, y + 37 + (cell.row - 1) * scale,
                    scale - 0.5, scale - 0.5, owned and C.cyan or C.dim, 0)
            end
        end
        local lines = D.wrap(ctx, entry.note, 14, cw - 28)
        for li = 1, math.min(2, #lines) do
            D.text(ctx, x + 14, y + 96 + (li - 1) * 17, lines[li], 14, C.dim)
        end
        D.text(ctx, x + 14, y + ch - 25, owned and "已收录" or "未收录", 14,
            owned and C.cyan or C.dim)
        D.text(ctx, x + cw - 14, y + ch - 26, string.format("+%d", entry.reward), 14,
            owned and C.warn or C.dim, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    end
    nvgRestore(ctx)
    return content, close
end

---@return string|nil action
local function HitTestCodex(uiX, uiY, w, meta)
    local content, close = GetShellLayout(w)
    if Inside(close, uiX, uiY) then return "close" end
    if meta and uiX >= content.x and uiX <= content.x + content.w
        and uiY >= content.y + content.h - 32 and uiY <= content.y + content.h then
        local totalPages = math.max(1, math.ceil(MetaCatalog.GetCodexTotal() / 8))
        if totalPages > 1 then return "codex_next_page" end
    end
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
    local rankFooterY = content.y + content.h - 66
    if #list == 0 then
        D.text(ctx, content.x + content.w * 0.5, content.y + 180, "暂无上榜记录", 20, C.text,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        D.text(ctx, content.x + content.w * 0.5, content.y + 214, "打出更高分就能上榜", 16, C.dim,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
    local rowH = 56
    nvgSave(ctx)
    nvgIntersectScissor(ctx, content.x, content.y, content.w, rankFooterY - content.y - 8)
    for i, item in ipairs(list) do
        local y = content.y + 14 + (i - 1) * (rowH + 4)
        if y + rowH > rankFooterY - 8 then break end
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
    nvgRestore(ctx)
    D.panel(ctx, content.x, rankFooterY, content.w, 56, C.rail, C.cyanDim, 6)
    local rankLabel = meta.myRankLoading and "我的排名 · 查询中"
        or (meta.myRank and string.format("我的排名 · 第 %d 名", meta.myRank) or "我的排名 · 暂未上榜")
    D.text(ctx, content.x + 18, rankFooterY + 16, rankLabel, 18, C.cyan)
    D.text(ctx, content.x + content.w - 16, rankFooterY + 18,
        string.format("最高分 %d", meta.highScore or 0), 16, C.dim,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    return content, close
end

---@return string|nil action
local function HitTestRank(uiX, uiY, w)
    local _, close = GetShellLayout(w)
    if Inside(close, uiX, uiY) then return "close" end
    return nil
end

-- ============================================================================
-- 商城面板（零件兑换车型 + 免费广告礼包；真实内购走钻石商店）
-- ============================================================================

local function GetShopLayout(w)
    local content, close = GetShellLayout(w)
    local rowH, rowStep = 72, 78
    local rowY = content.y + 35
    local giftTitleY = rowY + #MetaCatalog.GetSkins() * rowStep + 4
    return {
        content = content, close = close,
        titleY = content.y + 8,
        rowY = rowY,
        rowH = rowH,
        rowStep = rowStep,
        giftTitleY = giftTitleY,
        giftRowY = giftTitleY + 30,
    }
end

local function GetShopCarButton(layout, index)
    local r = {x = layout.content.x, y = layout.rowY + (index - 1) * layout.rowStep,
        w = layout.content.w, h = layout.rowH}
    return r, {x = r.x + r.w - 126, y = r.y + 12, w = 112, h = 48}
end

local function GetShopGiftButton(layout, index)
    local r = {x = layout.content.x, y = layout.giftRowY + (index - 1) * 68,
        w = layout.content.w, h = 60}
    return r, {x = r.x + r.w - 148, y = r.y + 6, w = 132, h = 48}
end

local function DrawCarSilhouette(ctx, r, skin, color)
    local cell = 7
    local x0 = r.x + 18
    local y0 = r.y + 15
    for row, pixels in ipairs(skin.silhouette) do
        for col = 1, #pixels do
            if pixels:sub(col, col) == "#" then
                D.rect(ctx, x0 + (col - 1) * cell, y0 + (row - 1) * cell,
                    cell - 1, cell - 1, color, 0)
            end
        end
    end
end

local function DrawShop(ctx, w, meta)
    local C = Colors()
    local content, close = Shell(ctx, w, 960, "车型商店",
        string.format("零件 %d", meta.parts or 0))
    local layout = GetShopLayout(w)
    nvgSave(ctx)
    nvgIntersectScissor(ctx, content.x, content.y, content.w, content.h)
    D.text(ctx, content.x + 4, layout.titleY, "选择车型 · 仅改变外形", 18, C.cyan)

    local skins = MetaCatalog.GetSkins()
    for i, skin in ipairs(skins) do
        local r, btn = GetShopCarButton(layout, i)
        local owned = skin.cost == 0 or (meta.skins and meta.skins[skin.key] == true)
        local selected = meta.selectedSkin == skin.key
        D.panel(ctx, r.x, r.y, r.w, r.h, C.card, selected and C.cyan or C.cyanDim, 6)
        D.panel(ctx, r.x + 9, r.y + 8, 76, 55, C.widget, C.cyanDim, 4)
        DrawCarSilhouette(ctx, r, skin, selected and C.cyan or C.text)
        D.text(ctx, r.x + 94, r.y + 8, skin.name, 18, C.text)
        D.text(ctx, r.x + 94, r.y + 34,
            selected and "当前使用" or (owned and "已拥有" or ("售价 " .. skin.cost .. " 零件")),
            15, selected and C.cyan or C.dim)
        if selected then
            Button(ctx, btn, "使用中", "", "disabled")
        elseif owned then
            Button(ctx, btn, "使用", "", "ghost")
        elseif (meta.parts or 0) >= skin.cost then
            Button(ctx, btn, "购买", tostring(skin.cost), "primary")
        else
            Button(ctx, btn, "零件不足", tostring(skin.cost), "disabled")
        end
    end

    D.text(ctx, content.x + 4, layout.giftTitleY, "免费补给", 18, C.cyan)
    local gifts = MetaCatalog.GetShopEntries()
    for i, gift in ipairs(gifts) do
        local r, btn = GetShopGiftButton(layout, i)
        local used = meta.giftUsed and meta.giftUsed[gift.key] or 0
        local limit = MetaCatalog.GetAdGiftDailyLimit(gift.key)
        D.panel(ctx, r.x, r.y, r.w, r.h, C.card, used < limit and C.ad or C.cyanDim, 6)
        D.text(ctx, r.x + 16, r.y + 8, gift.name, 18, used < limit and C.text or C.dim)
        D.text(ctx, r.x + 16, r.y + 32, gift.desc, 15, C.dim)
        if used < limit then
            Button(ctx, btn, "看广告", string.format("%d/%d", used, limit), "ad")
        else
            Button(ctx, btn, "今日已领", "", "disabled")
        end
    end
    nvgRestore(ctx)
    return content, close
end

---@return string|nil action
---@return integer|nil index
local function HitTestShop(uiX, uiY, w, meta)
    local layout = GetShopLayout(w)
    if Inside(layout.close, uiX, uiY) then return "close", nil end
    if not Inside(layout.content, uiX, uiY) then return nil, nil end
    local skins = MetaCatalog.GetSkins()
    for i, skin in ipairs(skins) do
        local _, btn = GetShopCarButton(layout, i)
        local owned = skin.cost == 0 or (meta.skins and meta.skins[skin.key] == true)
        if Inside(btn, uiX, uiY) and meta.selectedSkin ~= skin.key
            and (owned or (meta.parts or 0) >= skin.cost) then
            return "buy_skin", i
        end
    end
    local gifts = MetaCatalog.GetShopEntries()
    for i, gift in ipairs(gifts) do
        local _, btn = GetShopGiftButton(layout, i)
        local used = meta.giftUsed and meta.giftUsed[gift.key] or 0
        if used < MetaCatalog.GetAdGiftDailyLimit(gift.key)
            and Inside(btn, uiX, uiY) then return "ad_gift", i end
    end
    return nil, nil
end

-- ============================================================================
-- 战斗档案（累计击碎方块升级，逐级领取免费零件）
-- ============================================================================

local function GetPassRewardRect(content, index)
    return { x = content.x, y = content.y + 174 + (index - 1) * 92,
        w = content.w, h = 82 }
end

local function GetPassUnlockRect(content)
    return { x = content.x + content.w - 156, y = content.y + 110, w = 144, h = 42 }
end

local function DrawPass(ctx, w, meta)
    local C = Colors()
    local content, close = Shell(ctx, w, 960, "战斗档案",
        meta.premiumPass and "双轨奖励" or "精英档案")
    nvgSave(ctx)
    nvgIntersectScissor(ctx, content.x, content.y, content.w, content.h)

    local hero = {x=content.x, y=content.y+2, w=content.w, h=160}
    D.panel(ctx, hero.x, hero.y, hero.w, hero.h, C.rail,
        meta.premiumPass and C.warnDim or C.cyanDim, 8)
    D.icon(ctx, "premium_pass_crest", hero.x + 14, hero.y + 12, 32)
    D.text(ctx, hero.x + 56, hero.y + 10, "精英航空档案", 13, C.cyanDim)
    D.text(ctx, hero.x + 56, hero.y + 29,
        string.format("等级 %02d", meta.passLevel or 1), 27, C.text)
    D.text(ctx, hero.x + hero.w - 16, hero.y + 12, "本级奖励", 12, C.dim,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    local currentReward = 100 + (meta.passLevel or 1) * 100
    D.text(ctx, hero.x + hero.w - 16, hero.y + 31,
        "+" .. tostring(currentReward), 21, C.warn, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    D.text(ctx, hero.x + 16, hero.y + 72,
        string.format("击碎 %d / %d 块", meta.passProgress or 0, meta.passTarget or 1), 13, C.dim)
    ProgressBar(ctx, hero.x + 16, hero.y + 91, hero.w - 32,
        (meta.passProgress or 0) / math.max(1, meta.passTarget or 1), C.cyan, 9)
    if meta.premiumPass then
        D.text(ctx, hero.x + 16, hero.y + 116, "精英轨已启用", 13, C.warn)
        D.text(ctx, hero.x + 16, hero.y + 137, "每级零件奖励翻倍", 12, C.dim)
    else
        D.text(ctx, hero.x + 16, hero.y + 119, "免费轨 · 持续作战即可升级", 13, C.dim)
        local ur = GetPassUnlockRect(content)
        local affordable = (not meta.offline) and (meta.gems or 0) >= (meta.premiumPassCost or 100)
        local label = meta.offline and "需联网" or (affordable and
            string.format("%d 钻石解锁", meta.premiumPassCost or 100) or "钻石不足")
        Button(ctx, ur, label, "精英轨 · 奖励×2", affordable and "gold" or "disabled")
    end

    for i, item in ipairs(meta.passRewards or {}) do
        local r = GetPassRewardRect(content, i)
        local border = item.claimable and C.cyan or (item.unlocked and C.cyanDim or C.widget)
        D.panel(ctx, r.x, r.y, r.w, r.h, C.card, border, 7)
        if item.claimable then D.rect(ctx, r.x, r.y + 8, 3, r.h - 16, C.cyan, 0) end
        D.icon(ctx, "premium_energy_core", r.x + 13, r.y + 25, 32,
            item.unlocked and 1 or 0.38)
        D.text(ctx, r.x + 58, r.y + 10,
            string.format("里程碑  /  %02d", item.level), 13, C.dim)
        D.text(ctx, r.x + 58, r.y + 34,
            string.format("+%d 零件", item.reward), 18,
            item.claimable and C.warn or (item.unlocked and C.text or C.dim))
        if meta.premiumPass then
            D.text(ctx, r.x + 58, r.y + 60, "精英轨 ×2", 11, C.warn)
        else
            D.text(ctx, r.x + 58, r.y + 60, item.unlocked and "免费轨" or "继续战斗解锁", 11, C.dim)
        end
        local btn = { x = r.x + r.w - 136, y = r.y + 17, w = 120, h = 48 }
        local label = item.claimed and "已领取" or (item.claimable and "领取奖励" or "未解锁")
        Button(ctx, btn, label, "", item.claimable and "primary" or "disabled")
    end
    nvgRestore(ctx)
    return content, close
end

local function HitTestPass(uiX, uiY, w, meta)
    local content, close = GetShellLayout(w)
    if Inside(close, uiX, uiY) then return "close", nil end
    if not Inside(content, uiX, uiY) then return nil, nil end
    if not meta.premiumPass then
        local ur = GetPassUnlockRect(content)
        if Inside(ur, uiX, uiY)
            and not meta.offline
            and (meta.gems or 0) >= (meta.premiumPassCost or 100) then
            return "buy_premium_pass", nil
        end
    end
    for i, item in ipairs(meta.passRewards or {}) do
        local row = GetPassRewardRect(content, i)
        local r = { x = row.x + row.w - 136, y = row.y + 17, w = 120, h = 48 }
        if item.claimable and Inside(r, uiX, uiY) then return "claim_pass", item.level end
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
    local cx, cy, radius = w * 0.5, 406, 166
    return { x = cx - 120, y = 660, w = 240, h = 58 }, cx, cy, radius
end

---@param ctx any
---@param w number
---@param meta MetaState
---@return table content
---@return table close
local function DrawWheel(ctx, w, meta)
    local C = Colors()
    local content, close = Shell(ctx, w, 960, "幸运转盘", meta.wheelReady and "今日机会  /  01" or "今日机会已用")
    local spin, cx, cy, radius = GetWheelLayout(w)
    local prizes = MetaCatalog.GetWheelPrizes()
    local n = #prizes
    local step = math.pi * 2 / n
    local palette = { C.cyanDim, C.warn, C.cyan, C.warn, C.cyanDim, C.warn, C.cyan, C.warn }
    local ring = radius + 20

    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, ring + 10)
    nvgFillColor(ctx, nvgRGBA(C.panel[1], C.panel[2], C.panel[3], 255))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, ring + 9)
    nvgStrokeColor(ctx, nvgRGBA(C.warnDim[1], C.warnDim[2], C.warnDim[3], 230))
    nvgStrokeWidth(ctx, 2)
    nvgStroke(ctx)
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, ring)
    nvgStrokeColor(ctx, nvgRGBA(C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 200))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
    for i = 0, 23 do
        local a = math.pi * 2 * i / 24 - math.pi * 0.5
        local inner = ring + (i % 3 == 0 and 2 or 5)
        local outer = ring + 10
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, cx + math.cos(a) * inner, cy + math.sin(a) * inner)
        nvgLineTo(ctx, cx + math.cos(a) * outer, cy + math.sin(a) * outer)
        local tc = i % 3 == 0 and C.warn or C.cyanDim
        nvgStrokeColor(ctx, nvgRGBA(tc[1], tc[2], tc[3], i % 3 == 0 and 200 or 120))
        nvgStrokeWidth(ctx, i % 3 == 0 and 1.4 or 0.8)
        nvgStroke(ctx)
    end

    nvgSave(ctx)
    nvgIntersectScissor(ctx, content.x, content.y, content.w, content.h)
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, radius)
    nvgFillColor(ctx, nvgRGBA(C.card[1], C.card[2], C.card[3], 255))
    nvgFill(ctx)
    for i = 1, n do
        local a0 = (i - 1) * step - math.pi * 0.5
        local a1 = a0 + step
        local mid = (a0 + a1) * 0.5
        local col = palette[i] or C.cyanDim
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, cx, cy)
        nvgArc(ctx, cx, cy, radius, a0, a1, NVG_CW)
        nvgClosePath(ctx)
        nvgFillColor(ctx, nvgRGBA(col[1], col[2], col[3], 35))
        nvgFill(ctx)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, cx, cy)
        nvgLineTo(ctx, cx + math.cos(a0) * (radius - 3), cy + math.sin(a0) * (radius - 3))
        nvgStrokeColor(ctx, nvgRGBA(col[1], col[2], col[3], 160))
        nvgStrokeWidth(ctx, 1)
        nvgStroke(ctx)

        local tx = cx + math.cos(mid) * radius * 0.72
        local ty = cy + math.sin(mid) * radius * 0.72
        D.panel(ctx, tx - 25, ty - 13, 50, 26, C.panel, col, 5)
        D.text(ctx, tx, ty - 7, tostring(prizes[i]), 13,
            prizes[i] >= 480 and C.warn or C.text, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, 27)
    nvgFillColor(ctx, nvgRGBA(C.widget[1], C.widget[2], C.widget[3], 255))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, 27)
    nvgStrokeColor(ctx, nvgRGBA(C.warn[1], C.warn[2], C.warn[3], 230))
    nvgStrokeWidth(ctx, 2)
    nvgStroke(ctx)
    D.icon(ctx, "premium_wheel_medal", cx - 16, cy - 16, 32, 1)
    nvgRestore(ctx)

    -- 固定奖针朝下，不随机旋转；指向顶部扇区，奖额永远可读。
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, cx - 12, cy - radius - 16)
    nvgLineTo(ctx, cx + 12, cy - radius - 16)
    nvgLineTo(ctx, cx, cy - radius + 2)
    nvgClosePath(ctx)
    nvgFillColor(ctx, nvgRGBA(C.warn[1], C.warn[2], C.warn[3], 255))
    nvgFill(ctx)

    local label = meta.wheelReady and "看广告 · 免费抽取" or "今日抽取已完成"
    Button(ctx, spin, label,
        meta.wheelReady and "每日一次 · 八档零件奖励" or "明日再来", meta.wheelReady and "ad" or "disabled")
    if meta.wheelPrize and meta.wheelPrize > 0 then
        D.panel(ctx, cx - 158, spin.y - 52, 316, 40, C.rail, C.warnDim, 6)
        D.text(ctx, cx, spin.y - 42,
            string.format("今日获得  +%d 零件", meta.wheelPrize), 17, C.warn,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    else
        D.text(ctx, w * 0.5, spin.y - 34,
            "每次抽取必得至少 120 零件", 14, C.dim,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
    return content, close
end

---@return string|nil action
local function HitTestWheel(uiX, uiY, w, meta)
    local _, close = GetShellLayout(w)
    if Inside(close, uiX, uiY) then return "close" end
    local spin = GetWheelLayout(w)
    if meta.wheelReady and Inside(spin, uiX, uiY) then return "wheel_spin" end
    return nil
end

-- ============================================================================
-- 分发
-- ============================================================================

-- 插件式注册：额外面板（如充值弹层）由编排层注册，避免 meta-ui 反向依赖业务模块。
---@class MetaScreenPlugin
---@field draw fun(ctx:any, w:number, meta:MetaState)
---@field hit fun(uiX:number, uiY:number, w:number, meta:MetaState):(string|nil, integer|nil)

---@type table<string, MetaScreenPlugin>
local extraScreens_ = {}

---@param name string
---@param drawer fun(ctx:any, w:number, meta:MetaState)
---@param hitTester fun(uiX:number, uiY:number, w:number, meta:MetaState):(string|nil, integer|nil)
function MetaUI.RegisterScreen(name, drawer, hitTester)
    extraScreens_[name] = { draw = drawer, hit = hitTester }
end

---@return table 绘制依赖（供外部弹层复用同一套令牌）
function MetaUI.GetDeps()
    return D
end

---@param ctx any
---@param w number
---@param meta MetaState
function MetaUI.DrawScreen(ctx, w, meta)
    local screen = meta.screen
    local plugin = screen and extraScreens_[screen] or nil
    if plugin then
        plugin.draw(ctx, w, meta)
        return
    end
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
    elseif screen == "pass" then
        DrawPass(ctx, w, meta)
    end
end

---@return string|nil action
---@return integer|nil index
function MetaUI.HitTestScreen(uiX, uiY, w, meta)
    local screen = meta.screen
    local plugin = screen and extraScreens_[screen] or nil
    if plugin then
        return plugin.hit(uiX, uiY, w, meta)
    end
    if screen == "tasks" then
        return HitTestTasks(uiX, uiY, w, meta)
    elseif screen == "codex" then
        return HitTestCodex(uiX, uiY, w, meta)
    elseif screen == "rank" then
        return HitTestRank(uiX, uiY, w)
    elseif screen == "shop" then
        return HitTestShop(uiX, uiY, w, meta)
    elseif screen == "wheel" then
        return HitTestWheel(uiX, uiY, w, meta)
    elseif screen == "pass" then
        return HitTestPass(uiX, uiY, w, meta)
    end
    return nil, nil
end

return MetaUI
