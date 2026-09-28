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
        -- 绿色＝看广告（免费获取），与青色主操作、金色稀有三分。
        border, labelColor, fill = C.ad, C.ad, C.card
    elseif kind == "disabled" then
        border, labelColor, fill = C.cyanDim, C.dim, C.widget
    elseif kind == "gold" then
        -- 金色＝钻石付费（与广告绿、免费青三分）。
        border, labelColor, fill = C.warn, C.warn, C.card
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
    local n = math.max(1, #entries)
    local slotW = (r.w - 24) / n
    for i, entry in ipairs(entries) do
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
        { action = "supply", icon = "supply", label = "每日补给",
          sub = meta.supplyAvailable and "待领取" or "明日再来",
          hot = meta.supplyAvailable, tone = "free" },
        { action = "open_tasks", icon = "task", label = "每日任务",
          sub = taskCount > 0 and string.format("%d 项可领", taskCount) or "对战积累",
          hot = taskCount > 0, tone = "free" },
        { action = "open_wheel", icon = "wheel", label = "幸运转盘",
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
        { action = "open_shop", icon = "shop", label = "涂装商城",
          sub = "零件换车漆", hot = false, tone = "free" },
        { action = "open_pass", icon = "pass", label = "战斗档案",
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

    -- ① 图鉴展示条（青色=已收录剪影，点击进图鉴）
    MetaUI.DrawHomeFleet(ctx, w, meta)

    -- ② 钱包连接器：左半零件（软货币）、右半钻石+充值（付费货币）。整条可点进充值。
    D.panel(ctx, L.wallet.x, L.wallet.y, L.wallet.w, L.wallet.h, C.rail, C.cyanDim, 6)
    D.rect(ctx, L.wallet.x, L.wallet.y, 3, L.wallet.h, C.cyan, 0)
    -- 左块：零件（软货币，对战/福利产出）
    D.icon(ctx, "parts", L.wallet.x + 16, L.wallet.y + 14, 28)
    D.text(ctx, L.wallet.x + 52, L.wallet.y + 8, "零件", 14, C.dim)
    D.text(ctx, L.wallet.x + 52, L.wallet.y + 26, string.format("%d", meta.parts or 0), 24, C.text)
    -- 中块：钻石（氪金代币，服务端权威）
    D.icon(ctx, "gem", L.wallet.x + 200, L.wallet.y + 14, 28)
    D.text(ctx, L.wallet.x + 236, L.wallet.y + 8, "钻石", 14, C.dim)
    D.text(ctx, L.wallet.x + 236, L.wallet.y + 26,
        meta.offline and "—" or string.format("%d", meta.gems or 0), 24, C.warn)
    -- 右块：明确的充值按钮（金色=付费；不再用误导性的「零件→钻石」箭头）
    local wb = { x = L.wallet.x + L.wallet.w - 112, y = L.wallet.y + 10, w = 96, h = 36 }
    D.rect(ctx, wb.x, wb.y, wb.w, wb.h, C.warn, 6)
    D.text(ctx, wb.x + wb.w * 0.5, wb.y + 8, "充值", 17, C.ink,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    -- ③ 今日福利（免费领零件）/ ④ 养成收藏（花零件与付费加速）。两行小标签区分语义。
    local rows = {
        { label = "今日福利", rects = L.daily, defs = GetDailyDefs(meta) },
        { label = "养成收藏", rects = L.grow,  defs = GetGrowDefs(meta) },
    }
    for _, rowDef in ipairs(rows) do
        D.text(ctx, 18, rowDef.rects[1].y - 14, rowDef.label, 15, C.cyanDim)
        for i, def in ipairs(rowDef.defs) do
            local rr = rowDef.rects[i]
            local border
            if def.hot then
                border = def.tone == "ad" and C.ad or (def.tone == "gold" and C.warn or C.cyan)
            else
                border = C.cyanDim
            end
            D.rect(ctx, rr.x, rr.y, rr.w, rr.h, C.card, 6)
            D.stroke(ctx, rr.x, rr.y, rr.w, rr.h, border, 6, def.hot and 1.6 or 1.1)
            local drewIcon = D.icon(ctx, def.icon, rr.x + rr.w * 0.5 - 14, rr.y + 12, 28,
                def.hot and 1 or 0.75)
            D.text(ctx, rr.x + rr.w * 0.5, drewIcon and (rr.y + 46) or (rr.y + 16),
                def.label, 16, def.hot and C.text or C.dim,
                NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            local lines = D.wrap(ctx, def.sub, 13, rr.w - 10)
            D.text(ctx, rr.x + rr.w * 0.5, rr.y + 68, lines[1] or "", 13,
                def.tone == "ad" and C.ad or (def.tone == "gold" and C.warn or C.dim),
                NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            if def.hot then
                D.rect(ctx, rr.x + rr.w - 12, rr.y + 8, 8, 8, border, 4)
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
    -- v0.12.6：菜单态不再绘制战斗 HUD，弹窗遮罩必须铺满整屏（旧值从 y=92 起）。
    D.backdrop(ctx, 0, 0, w, 960)
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
    local cw, ch, gap = 226, 146, 12
    local y0 = content.y + 16
    nvgSave(ctx)
    nvgIntersectScissor(ctx, content.x, content.y, content.w, content.h)
    for i, entry in ipairs(entries) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
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
-- 商城面板（零件车辆涂装 + 免费广告礼包；真实内购走钻石商店）
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
    nvgSave(ctx)
    nvgIntersectScissor(ctx, content.x, content.y, content.w, content.h)
    local y = content.y + 16
    D.text(ctx, content.x + 4, y, "车辆涂装", 18, C.cyan)
    y = y + 32

    local skins = MetaCatalog.GetSkins()
    local rowH = 70
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
    nvgRestore(ctx)
    return content, close
end

---@return string|nil action
---@return integer|nil index
local function HitTestShop(uiX, uiY, w, meta)
    local L, close = GetShellLayout(w)
    if Inside(close, uiX, uiY) then return "close", nil end
    if not Inside(L, uiX, uiY) then return nil, nil end
    local rowH = 70
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
-- 战斗档案（累计击碎方块升级，逐级领取免费零件）
-- ============================================================================

-- 档案奖励按已领取等级滑动；一屏最多五项，绘制/命中共用同一行几何。
local function GetPassRewardRect(content, index)
    return { x = content.x, y = content.y + 180 + (index - 1) * 84,
        w = content.w, h = 72 }
end

-- v0.12.5：付费档案轨不再占常驻大面板行（用户否决 v0.12.4 显示）。
-- v0.12.7：启动自动弹窗被用户否决删除后，付费轨解锁入口收回本面板内一个
-- 紧凑按钮（打开面板才可见，绝不自动弹），与「升级获得零件…」文案同行右侧。
local function GetPassUnlockRect(content)
    return { x = content.x + content.w - 152, y = content.y + 138, w = 140, h = 40 }
end

local function DrawPass(ctx, w, meta)
    local C = Colors()
    local content, close = Shell(ctx, w, 960, "战斗档案",
        meta.premiumPass and "双轨奖励" or "免费奖励")
    nvgSave(ctx)
    nvgIntersectScissor(ctx, content.x, content.y, content.w, content.h)
    D.icon(ctx, "pass", content.x + 16, content.y + 18, 32)
    D.text(ctx, content.x + 60, content.y + 14,
        string.format("等级 %d", meta.passLevel or 1), 26, C.text)
    D.text(ctx, content.x + 16, content.y + 68,
        string.format("累计击碎 %d / %d 块", meta.passProgress or 0, meta.passTarget or 1), 17, C.dim)
    ProgressBar(ctx, content.x + 16, content.y + 102, content.w - 32,
        (meta.passProgress or 0) / math.max(1, meta.passTarget or 1), C.cyan)
    D.text(ctx, content.x + 16, content.y + 148,
        meta.premiumPass and "已解锁付费轨 · 每级奖励 ×2"
            or "升级获得零件 · 已解锁等级可逐级领取", 16,
        meta.premiumPass and C.warn or C.dim)
    local rewards = meta.passRewards or {}
    for i, item in ipairs(rewards) do
        local r = GetPassRewardRect(content, i)
        D.panel(ctx, r.x, r.y, r.w, r.h, C.card, item.claimable and C.cyan or C.cyanDim, 6)
        D.icon(ctx, "record", r.x + 14, r.y + 20, 32, item.unlocked and 1 or 0.4)
        D.text(ctx, r.x + 60, r.y + 6, "档案等级 " .. tostring(item.level), 18, C.text)
        if meta.premiumPass then
            D.text(ctx, r.x + 60, r.y + 38,
                string.format("+%d 零件（%d ×2）", item.reward, item.baseReward or item.reward),
                17, C.warn)
        else
            D.text(ctx, r.x + 60, r.y + 38, "+" .. tostring(item.reward) .. " 零件", 17, C.warn)
        end
        local btn = { x = r.x + r.w - 136, y = r.y + 12, w = 120, h = 48 }
        Button(ctx, btn, item.claimed and "已领取" or (item.claimable and "领取" or "未解锁"), "",
            item.claimable and "primary" or "disabled")
    end
    -- v0.12.7：付费轨解锁入口（金色=钻石付费；仅未解锁时显示，绝不自动弹）
    if not meta.premiumPass then
        local ur = GetPassUnlockRect(content)
        local affordable = (not meta.offline) and (meta.gems or 0) >= (meta.premiumPassCost or 100)
        local label = "钻石不足"
        if meta.offline then label = "需联网"
        elseif affordable then label = string.format("%d 钻石解锁", meta.premiumPassCost or 100) end
        Button(ctx, ur, label, "", affordable and "gold" or "disabled")
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
        local r = { x = row.x + row.w - 136,
            y = row.y + 12, w = 120, h = 48 }
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
    D.text(ctx, w * 0.5, spin.y + spin.h + 48,
        "每日限抽一次 · 八档零件奖励", 15, C.dim,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    if meta.wheelPrize and meta.wheelPrize > 0 then
        D.text(ctx, w * 0.5, spin.y + spin.h + 14,
            string.format("恭喜获得 %d 零件", meta.wheelPrize), 18, C.warn,
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
        return HitTestCodex(uiX, uiY, w)
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
