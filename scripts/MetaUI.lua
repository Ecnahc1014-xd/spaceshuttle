-- MetaUI.lua
-- 元层界面（主菜单商业化区 + 各功能面板）的绘制与命中判定。
-- 与 Scene3DBackend 共用同一套 dark-tech 令牌与绘制原语（依赖注入，避免样式漂移）。
-- 只读 meta 状态与 MetaCatalog；所有状态变更由编排层（main.lua）执行。

local MetaCatalog = require "MetaCatalog"
local VehicleShowcase = require "ui.VehicleShowcase"
local ArtText = require "ui.ArtText"
-- v0.14.0：成就列表并入「战斗档案」屏——本模块直接调用它的 Draw/HitTest（不注册独立屏）。
local Achievements = require "ui.Achievements"

local MetaUI = {}
local showroom = { index = 1, screen = "", key = "default" }
-- 商店分页：车型 / 拖尾。拖尾有独立的预览下标（与车型下标互不干扰）。
local shopTab = "vehicle"
local trailIndex = 1
-- 商店拖尾预览与实机同步的「整体不透明度」——与 Renderer3D.TRAIL_OPACITY 同值
-- （项目契约：预览里看到的差异 = 实机差异）。1.0=原不透明，0.30=透明度 +70%。
local TRAIL_PREVIEW_OPACITY = 0.30

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
---@field piggyMode boolean 战斗档案是否已进入「存钱罐式」（满级后）
---@field piggyGear integer 存钱罐已累积的齿轮数
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
---@field stageStars table<integer, integer> 关卡号 -> 历史最佳星级
---@field maxStage integer 已解锁的最大关卡号
---@field stageTotal integer 关卡总数
---@field talents table<string, boolean> 已解锁的天赋节点
---@field totalStars integer 星级总和
---@field talentCount integer 已解锁节点数
---@field talentTotal integer 天赋节点总数
---@field talentMaxStage integer 天赋阶段总数
---@field talentStageCount integer 当前星级已开放的阶段数
---@field talentAffordable boolean 是否存在可负担且前置满足的节点
---@field skins table<string, boolean>
---@field selectedSkin string
---@field giftUsed table<string, integer>
---@field wheelReady boolean
---@field wheelPrize integer
---@field musicEnabled boolean 设置页：BGM 开关
---@field sfxEnabled boolean 设置页：音效开关
---@field passTab string|nil 战斗档案屏页签："pass"（档案）| "ach"（成就）
---@field achievements table[] 成就列表（id/title/desc/steps/icon/tone/progress/unlocked）
---@field achUnlocked integer
---@field achTotal integer
---@field achPage integer|nil
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
---@field hovering fun(rect:table):boolean v0.13.30c 指针是否悬停在该矩形内
---@field hoverGlow fun():number v0.13.30c 0..1 平滑悬停强度（全屏共享）
---@field anim fun():number 持续动画相位（秒）
---@field controlFx fun(rect:table, enabled:boolean):number, number 控件悬停与按压强度
---@field measure fun(ctx:any, s:string, size:number):number 设计空间实测文字宽度
---@field stage fun(ctx:any,r:table,phase:number) 绘制程序化技术展台
---@field button fun(ctx:any,r:table,color:table,glow:number)
---@field pixelScale (fun():number)|nil 设计单位对应物理像素倍率，包含 DPR
---@field fit fun(ctx:any,text:string,size:number,width:number,minimum:number):number, boolean

---@type MetaUiDeps
local D = nil

---@param deps MetaUiDeps
function MetaUI.Init(deps)
    D = deps
    showroom.screen = ""
    showroom.index = 1
end

-- 展示状态与玩家装备分离：浏览不会购买、换装或改写战斗快照。
function MetaUI.Update(dt, meta, gameState)
    local screen = meta and meta.screen or ""
    if screen ~= showroom.screen then
        showroom.screen = screen
        if screen == "shop" then
            for i, skin in ipairs(MetaCatalog.GetSkins()) do
                if skin.key == meta.selectedSkin then showroom.index = i; break end
            end
            for i, trail in ipairs(MetaCatalog.GetTrails()) do
                if trail.key == meta.selectedTrail then trailIndex = i; break end
            end
        end
    end
    local skin = MetaCatalog.GetSkins()[showroom.index] or MetaCatalog.GetSkins()[1]
    showroom.key = screen == "shop" and skin.key or (meta and meta.selectedSkin or "default")
    local visible = gameState == "menu" and not (meta and meta.supplyOpen)
        and (screen == "" or (screen == "shop" and shopTab == "vehicle"))
    local rect = MetaUI.GetVehicleStageRect(screen, 540)
    local pixelScale = D and D.pixelScale and D.pixelScale() or 1
    VehicleShowcase.Update(dt, visible, showroom.key, rect.w * pixelScale, rect.h * pixelScale)
    -- v0.13.74：天赋叶脉（3D 叶脉大场景）的 RT 渲染同样在更新阶段完成。
    local grove = D and D.talentGrove
    if grove and grove.Update then
        grove.Update(dt, screen == "talent", meta)
    end
end

function MetaUI.PreviewVehicle(index)
    if not MetaCatalog.GetSkins()[index] then return false end
    showroom.index = index
    return true
end

---@param index integer
---@return boolean
function MetaUI.PreviewTrail(index)
    if not MetaCatalog.GetTrails()[index] then return false end
    trailIndex = index
    return true
end

-- 商店分页切换（车型 / 拖尾）；切页只改浏览态，不动存档。
---@param tab string "vehicle" | "trail"
function MetaUI.SetShopTab(tab)
    shopTab = (tab == "trail") and "trail" or "vehicle"
end

---@return string
function MetaUI.GetShopTab()
    return shopTab
end

function MetaUI.Shutdown()
    VehicleShowcase.Shutdown()
    showroom.screen = ""
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

-- v0.13.54：给菜单/商店的小卡片补「无关紧要的纹路」——网格 + 四角折线 + 底边刻度
-- + 断线 + 角落取样点。全部低 alpha、贴边不穿正文；命中几何不受影响（只画）。
-- ⚠️ v0.13.57 削减：卡片是**每帧逐张重绘**的，原来双层网格 + 双四角 + 逐点刻度/点阵
-- 在一屏十几张卡上叠成上百条绘制命令，是「界面动画变卡」的来源之一。现各保留一层。
local function CardTrace(ctx, r, alpha)
    local C = Colors()
    local a = alpha or 14
    D.grid(ctx, r.x + 3, r.y + 3, r.w - 6, r.h - 6, 14, a)
    if r.w >= 84 and r.h >= 40 then
        D.corner(ctx, r.x + 3, r.y + 3, r.w - 6, r.h - 6,
            {C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], a + 30}, 9, 1)
    end
    if r.w >= 70 and r.h >= 30 then
        -- 底边长短刻度：给每张卡一条「仪器」读数沿。
        local count = math.max(5, math.floor((r.w - 20) / 16))
        local step = (r.w - 20) / count
        for i = 0, count do
            local long = (i % 4 == 0)
            D.rect(ctx, r.x + 10 + i * step, r.y + r.h - 8, 1, long and 4 or 2,
                {C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], a + 34}, 0)
        end
    end
    if r.w >= 60 then
        D.rule(ctx, r.x + 10, r.y + r.h - 12, math.max(16, r.w * 0.34), 3,
            {C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], a + 20})
    end
    if r.w >= 96 and r.h >= 52 then
        -- 角落取样十字。
        for _, p in ipairs({ { r.x + 11, r.y + 11 }, { r.x + r.w - 11, r.y + 11 } }) do
            D.rect(ctx, p[1] - 4, p[2], 9, 1, {C.ghost[1], C.ghost[2], C.ghost[3], a + 40}, 0)
            D.rect(ctx, p[1], p[2] - 4, 1, 9, {C.ghost[1], C.ghost[2], C.ghost[3], a + 40}, 0)
        end
    end
end

---@param ctx any
---@param x number
---@param y number
---@param w number
---@param label string
---@param artKey string|nil 有对应艺术字时用图，否则用 zpix 文本
-- 标题左竖标与断续刻度统一分区语言，正文区域保持干净。
local function SectionHeader(ctx, x, y, w, label, artKey)
    local C = Colors()
    local phase = D.anim()
    local pulse = 0.72 + 0.28 * math.sin(phase * math.pi * 0.5)
    -- 呼吸辉光：让竖标从「一根线」变成有光晕的识别点。
    nvgBeginPath(ctx)
    nvgRect(ctx, x - 4, y - 2, 12, 20)
    nvgFillPaint(ctx, nvgRadialGradient(ctx, x + 1.5, y + 10, 1, 13,
        nvgRGBA(C.cyan[1], C.cyan[2], C.cyan[3], math.floor(70 * pulse)),
        nvgRGBA(C.cyan[1], C.cyan[2], C.cyan[3], 0)))
    nvgFill(ctx)
    D.rect(ctx, x, y + 2, 3, 16,
        {C.cyan[1], C.cyan[2], C.cyan[3], math.floor(225 * pulse)}, 1)
    -- v0.13.58：分区标题优先用 AI 像素艺术字（深底亮字 → tint C.text）；
    -- 无图回退 zpix 文本，并用**同一 measure 分支**算右侧断线起点（两者宽度一致）。
    local titleW
    if artKey and ArtText.Has(artKey) then
        local ah = ArtText.Height(artKey)
        ArtText.Draw(ctx, artKey, x + 9 + ArtText.Width(artKey) * 0.5, y + (16 - ah) * 0.5 + 1, C.text)
        titleW = ArtText.Width(artKey)
    else
        D.text(ctx, x + 9, y, label, 17, C.text)
        titleW = D.measure(ctx, label, 17)
    end
    local lx = x + 9 + titleW + 14
    local remain = math.max(0, x + w - lx)
    if remain >= 20 then
        D.rule(ctx, lx, y + 10, remain, 8, {C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 130})
        -- 流动段只走标题右方空白，不经过文字。
        local length = math.min(24, remain * 0.25)
        local scanX = lx + (phase % 6) / 6 * (remain - length)
        nvgBeginPath(ctx)
        nvgRect(ctx, scanX, y + 9, length, 2)
        nvgFillPaint(ctx, nvgLinearGradient(ctx, scanX, y, scanX + length, y,
            nvgRGBA(C.cyan[1], C.cyan[2], C.cyan[3], 0),
            nvgRGBA(C.cyan[1], C.cyan[2], C.cyan[3], 215)))
        nvgFill(ctx)
    end
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
        border, labelColor, fill = C.ad, C.ink, C.card
    elseif kind == "disabled" then
        border, labelColor, fill = C.cyanDim, C.dim, C.widget
    elseif kind == "gold" then
        border, labelColor, fill = C.warn, C.warn, C.card
    elseif kind == "danger" then
        border, labelColor, fill = C.error, C.error, C.card
    else
        border, labelColor, fill = C.cyanDim, C.text, C.card
    end

    local glow, press = D.controlFx(r, kind ~= "disabled")
    nvgSave(ctx)
    nvgTranslate(ctx, 0, press * 2)
    D.panel(ctx, r.x, r.y, r.w, r.h, fill, border, 6)
    if kind == "primary" or kind == "ad" then
        D.button(ctx, r, kind == "primary" and C.cyan or C.ad, glow)
    elseif kind == "gold" or kind == "danger" then
        D.rect(ctx, r.x + 1, r.y + 9, 2, r.h - 18, border, 1)
    end
    -- 每个可操作控件独立缓动；禁用控件与展示底板不会继承悬停。
    if glow > 0.01 then
        local g = glow
        local hc = (kind == "primary" and C.cyan) or (kind == "ad" and C.ad)
            or (kind == "gold" and C.warn) or (kind == "danger" and C.error) or C.cyan
        if kind ~= "primary" and kind ~= "ad" then
            nvgBeginPath(ctx)
            nvgRect(ctx, r.x - 6, r.y - 6, r.w + 12, r.h + 12)
            nvgFillPaint(ctx, nvgBoxGradient(ctx, r.x, r.y, r.w, r.h, 6, 6,
                nvgRGBA(hc[1], hc[2], hc[3], math.floor(85 * g)),
                nvgRGBA(hc[1], hc[2], hc[3], 0)))
            nvgFill(ctx)
            D.rect(ctx, r.x + 2, r.y + 2, r.w - 4, r.h - 4,
                {hc[1], hc[2], hc[3], math.floor(28 * g)}, 4)
            D.stroke(ctx, r.x, r.y, r.w, r.h,
                {hc[1], hc[2], hc[3], math.floor(230 * g)}, 6, 1)
        end
        D.corner(ctx, r.x + 2, r.y + 2, r.w - 4, r.h - 4,
            {C.text[1], C.text[2], C.text[3], math.floor(210 * g)}, 7, 1)
    end
    local cx = r.x + r.w * 0.5
    if sub ~= "" then
        D.text(ctx, cx, r.y + r.h * 0.5 - 18, label, D.fit(ctx, label, 17, r.w - 14, 15), labelColor,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        D.text(ctx, cx, r.y + r.h * 0.5 + 2, sub, D.fit(ctx, sub, 15, r.w - 14, 15),
            (kind == "primary" or kind == "ad") and C.ink or C.dim, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    else
        D.text(ctx, cx, r.y + r.h * 0.5 - 11, label, D.fit(ctx, label, 17, r.w - 14, 15), labelColor,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
    nvgRestore(ctx)
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
-- v0.13.61：底部让出 34px 给「状态条」——把钱包余额与社交锚点常驻到每一屏（最商业化的一条）。
local SHELL_BAR_H = 34

---@param w number
---@return table content
---@return table close
---@return table statusBar
local function GetShellLayout(w)
    local x, y = 18, 108
    local sw, sh = w - 36, 780
    local content = { x = x + 14, y = y + 60, w = sw - 28, h = sh - 76 - SHELL_BAR_H - 6 }
    return content,
           { x = x + sw - 46, y = y + 8, w = 36, h = 36 },
           { x = content.x, y = content.y + content.h + 6, w = content.w, h = SHELL_BAR_H }
end

-- 底栏状态条：常驻「零件 · 钻石 · 最远关卡 · 全服名次」——每次打开面板都看到持有量与排名，
-- 是商业化 UI 最强的价值锚点（钱包可见 + 社交证明）。全部读真实 meta 字段，无字段则降级。
---@param ctx any
---@param bar table
---@param meta MetaState
local function ShellStatusBar(ctx, bar, meta)
    local C = Colors()
    D.panel(ctx, bar.x, bar.y, bar.w, bar.h, C.rail, C.cyanDim, 6)
    D.rect(ctx, bar.x + 2, bar.y + 2, bar.w - 4, math.floor(bar.h * 0.44),
        {255, 255, 255, 16}, 4)
    D.rect(ctx, bar.x + 4, bar.y + 1, bar.w - 8, 1, {C.dim[1], C.dim[2], C.dim[3], 70}, 0)
    local cy = bar.y + math.floor(bar.h * 0.5) - 9
    D.icon(ctx, "parts", bar.x + 8, cy - 3, 24, 1)
    D.text(ctx, bar.x + 36, cy, tostring(meta.parts or 0), 16, C.text)
    local gemX = bar.x + 118
    D.rect(ctx, gemX - 10, bar.y + 6, 1, bar.h - 12, {C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 110}, 0)
    D.icon(ctx, "gem", gemX, cy - 3, 24, 1)
    D.text(ctx, gemX + 28, cy, tostring(meta.gems or 0), 16, C.warn)
    -- 中段：最远关卡（进度锚点）。
    D.text(ctx, bar.x + bar.w * 0.62, cy, string.format("最远第 %d 关", meta.maxStage or 1),
        15, C.dim, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    -- 右段：全服名次（社交证明）优先，离线/未上榜降级为最高分。
    local rightText, rightColor
    if meta.myRank and (meta.rankTotal or 0) > 0 then
        rightText = string.format("全服第 %d 名", meta.myRank)
        rightColor = C.cyan
    else
        rightText = string.format("最高分 %d", meta.highScore or 0)
        rightColor = C.dim
    end
    D.text(ctx, bar.x + bar.w - 14, cy, rightText, 15, rightColor,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
end

-- 面板壳：整页覆盖 + 标题栏 + 右上关闭 + 底部状态条。返回内容区 {x,y,w,h}。
---@param ctx any
---@param w number
---@param h number
---@param title string
---@param subtitle string
---@param meta MetaState|nil 有则画底部状态条（钱包/进度/排名）
---@return table content
---@return table close
local function Shell(ctx, w, h, title, subtitle, meta)
    local C = Colors()
    D.backdrop(ctx, 0, 0, w, h)
    local x, y = 18, 108
    local sw, sh = w - 36, 780
    D.shell(ctx, x, y, sw, sh, 48)
    local headerIcon = {
        ["每日任务"] = "task",
        ["敌机图鉴"] = "codex",
        ["全服排行榜"] = "rank",
        ["皮肤商店"] = "shop",
        ["幸运转盘"] = "premium_wheel_medal",
        ["战斗档案"] = "premium_pass_crest",
    }
    local iconKey = headerIcon[title]
    local titleX = x + 16
    if iconKey and D.icon(ctx, iconKey, x + 12, y + 8, 32, 1) then
        titleX = x + 52
    end
    D.text(ctx, titleX, y + 8, title, 28, C.text)
    if subtitle ~= "" then
        D.rect(ctx, x + sw - 178, y + 14, 2, 18, C.warn, 0)
        D.text(ctx, x + sw - 58, y + 14, subtitle, 15, C.dim,
            NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    end
    local content, close, statusBar = GetShellLayout(w)
    D.panel(ctx, close.x, close.y, close.w, close.h, C.card, C.cyanDim, 6)
    D.text(ctx, close.x + close.w * 0.5, close.y + 6, "×", 21, C.text,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    if meta then ShellStatusBar(ctx, statusBar, meta) end
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
    local gap = 8
    -- 行卡按数量水平居中，并自适应卡宽（grow 行现为 5 卡，120 宽会溢出 504）。
    local function row(y, h, n)
        local bw = math.min(120, math.floor((504 - (n - 1) * gap) / n))
        local total = n * bw + (n - 1) * gap
        local x0 = 18 + (504 - total) * 0.5
        local r = {}
        for i = 1, n do
            r[i] = { x = x0 + (i - 1) * (bw + gap), y = y, w = bw, h = h }
        end
        return r
    end
    -- 首页主视觉之后按天赋/钱包/福利/收藏收束，底部保留版本说明。
    return {
        fleet  = { x = 18, y = 532, w = 504, h = 84 },
        wallet = { x = 18, y = 632, w = 504, h = 62 },
        daily  = row(732, 80, 3),
        grow   = row(842, 80, 4),
    }
end

-- v0.13.8：天赋树大面板改为**明确可点入**的入口——左侧大图标 + 标题/副标题 +
-- 解锁进度条 + 右侧「进入 ›」胶囊按钮；有可解锁节点时整框青色高亮 + 红点，无则压暗。
---@param ctx any
---@param w number
---@param meta MetaState
function MetaUI.DrawHomeFleet(ctx, w, meta)
    local C = Colors()
    local r = GetMenuBarLayout().fleet
    local owned, total = meta.talentCount or 0, meta.talentTotal or 42
    local hot = meta.talentAffordable == true
    local glow = D.controlFx(r, true)
    D.panel(ctx, r.x, r.y, r.w, r.h, C.card, {120, 148, 162, 65}, 8)
    -- 天赋入口大卡：内受光 / 内沉影 + 左侧竖标发光，做成一个明确的「可进入」载体。
    D.rect(ctx, r.x + 2, r.y + 2, r.w - 4, math.floor(r.h * 0.42), {255, 255, 255, 18}, 6)
    D.rect(ctx, r.x + 2, r.y + math.floor(r.h * 0.6), r.w - 4,
        r.h - math.floor(r.h * 0.6) - 2, {0, 0, 0, 42}, 6)
    D.rect(ctx, r.x + 1, r.y + 20, 2, r.h - 40, hot and C.cyan or C.dim, 1)
    -- v0.13.54：天赋入口大卡补纹路（网格 + 半调 + 四角折线 + 底边刻度）。
    CardTrace(ctx, r, 12)
    if hot then
        nvgBeginPath(ctx)
        nvgRect(ctx, r.x - 6, r.y + 14, 16, r.h - 28)
        nvgFillPaint(ctx, nvgRadialGradient(ctx, r.x + 2, r.y + r.h * 0.5, 1, 22,
            nvgRGBA(C.cyan[1], C.cyan[2], C.cyan[3], 78),
            nvgRGBA(C.cyan[1], C.cyan[2], C.cyan[3], 0)))
        nvgFill(ctx)
    end
    D.icon(ctx, "premium_energy_core", r.x + 16, r.y + 23, 32, 1)
    D.text(ctx, r.x + 62, r.y + 10, "天赋树", 28, C.text)
    D.text(ctx, r.x + 62, r.y + 43,
        string.format("%d/%d 节点  ·  ★ %d", owned, total, meta.totalStars or 0), 15, C.dim)
    D.progress(ctx, r.x + 62, r.y + 68, r.w - 196, total > 0 and owned / total or 0, C.cyan, 4)
    local cta = { x = r.x + r.w - 114, y = r.y + 20, w = 98, h = 44 }
    Button(ctx, cta, "进入 ›", "", "primary")
    if hot then D.rect(ctx, r.x + r.w - 12, r.y + 9, 6, 6, C.warn, 3) end
    if glow > 0.01 then
        D.stroke(ctx, r.x, r.y, r.w, r.h, {C.cyan[1], C.cyan[2], C.cyan[3], math.floor(glow * 180)}, 8, 1.4)
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
-- v0.12.7：每日签到并入钻石商店弹层（用户要求），菜单只剩 3 卡（水平居中见 GetMenuBarLayout）。
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
-- 菜单不再用金框「新手礼包」顶替图鉴位；首充只在玩家主动打开钻石商店时出现。
local function GetGrowDefs(meta)
    -- v0.14.0：战斗档案屏含成就页签——副标题补一个成就进度锚点（有可领奖励时优先提示）。
    local achSub = string.format("成就 %d/%d", meta.achUnlocked or 0, meta.achTotal or 0)
    local passSub = meta.piggyMode and string.format("存钱罐 %d 齿轮", meta.piggyGear or 0)
        or (meta.passClaimable and "有奖励可领"
        or (meta.premiumPass and "双倍奖励" or achSub))
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

-- 展台仅承载真实车辆；程序化支架与刻度共用技术舱语言，无隐式购买操作。
local function DrawVehicleStage(ctx, r, home)
    local C = Colors()
    nvgSave(ctx)
    nvgIntersectScissor(ctx, r.x, r.y, r.w, r.h)
    D.stage(ctx, r, D.anim())
    if not VehicleShowcase.Draw(ctx, r.x, r.y, r.w, r.h) then
        D.text(ctx, r.x + r.w * 0.5, r.y + r.h * 0.4, "实车预览暂不可用", 17, C.dim,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
    nvgRestore(ctx)
end

function MetaUI.DrawHomeVehicle(ctx, w, meta)
    local C = Colors()
    local skin = MetaCatalog.GetSkin(meta and meta.selectedSkin or "default") or MetaCatalog.GetSkins()[1]
    DrawVehicleStage(ctx, MetaUI.GetVehicleStageRect("", w), true)
    D.text(ctx, 34, 198, "当前车型", 15, C.dim)
    D.text(ctx, w - 34, 195, skin.name, 22, C.text, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    D.text(ctx, w * 0.5, 399, skin.desc, 15, C.text, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
end

-- 极长余额保留完整数字；最低字号仍超宽时分两行，不截断或隐去数位。
local function DrawWalletValue(ctx, x, y, value, width, color)
    local text = tostring(value)
    local size, fits = D.fit(ctx, text, 23, width, 15)
    if fits then
        D.text(ctx, x, y, text, size, color)
    else
        local midpoint = math.ceil(#text / 2)
        D.text(ctx, x, y - 3, text:sub(1, midpoint), 15, color)
        D.text(ctx, x, y + 14, text:sub(midpoint + 1), 15, color)
    end
end

---@param ctx any
---@param w number
---@param meta MetaState
function MetaUI.DrawMenuBar(ctx, w, meta)
    local C = Colors()
    local L = GetMenuBarLayout()

    MetaUI.DrawHomeFleet(ctx, w, meta)

    local walletGlow, walletPress = D.controlFx(L.wallet, true)
    nvgSave(ctx)
    nvgTranslate(ctx, 0, walletPress * 2)
    D.panel(ctx, L.wallet.x, L.wallet.y, L.wallet.w, L.wallet.h, C.rail, C.cyanDim, 6)
    -- 钱包条内受光 + 内沉影，让整条有舱板厚度。
    D.rect(ctx, L.wallet.x + 2, L.wallet.y + 2, L.wallet.w - 4,
        math.floor(L.wallet.h * 0.44), {255, 255, 255, 18}, 4)
    D.rect(ctx, L.wallet.x + 2, L.wallet.y + math.floor(L.wallet.h * 0.6), L.wallet.w - 4,
        L.wallet.h - math.floor(L.wallet.h * 0.6) - 2, {0, 0, 0, 40}, 4)
    -- v0.13.54：钱包条补纹路（网格 + 底边刻度 + 断线 + 角落取样点）。
    CardTrace(ctx, L.wallet, 11)
    if walletGlow > 0.01 then
        D.stroke(ctx, L.wallet.x, L.wallet.y, L.wallet.w, L.wallet.h,
            {C.cyan[1], C.cyan[2], C.cyan[3], math.floor(walletGlow * 190)}, 6, 1.5)
    end

    D.icon(ctx, "parts", L.wallet.x + 12, L.wallet.y + 15, 32)
    D.text(ctx, L.wallet.x + 52, L.wallet.y + 8, "零件", 15, C.dim)
    DrawWalletValue(ctx, L.wallet.x + 52, L.wallet.y + 29,
        meta.parts or 0, 125, C.text)
    D.rect(ctx, L.wallet.x + 184, L.wallet.y + 12, 1, L.wallet.h - 24,
        {C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 110}, 0)
    -- v0.13.17：钻石用 gem 图标（此前 gem 已加载却从未绘制）；premium_energy_core 留给钻石商店入口。
    D.icon(ctx, "gem", L.wallet.x + 194, L.wallet.y + 15, 32)
    D.text(ctx, L.wallet.x + 232, L.wallet.y + 8, "钻石", 15, C.dim)
    DrawWalletValue(ctx, L.wallet.x + 232, L.wallet.y + 29,
        meta.offline and "—" or (meta.gems or 0), 137, C.warn)

    -- v0.13.44：入口措辞由「充值」改为「钻石商店」——玩家侧不出现直白的充值字样，
    -- 统一按游戏内商店表述（用户要求）。宽度让给 4 字标题，字号降到 15 保证不挤出按钮。
    local wb = { x = L.wallet.x + L.wallet.w - 112, y = L.wallet.y + 12, w = 104, h = 38 }
    -- v0.13.53：付费入口用完整按钮工艺 + **常驻暖金辉光**（用户「太冷酷，消失消费欲望」）。
    -- 此前只用平铺 D.panel，是首页唯一的暖色却被画得最平——现在它是全屏最亮最暖的一点。
    D.button(ctx, wb, C.warn, 0.62)
    D.icon(ctx, "gem", wb.x + 5, wb.y + 3, 32)
    D.text(ctx, wb.x + 68, wb.y + 11, "钻石商店", 15, C.ink,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgRestore(ctx)

    local rows = {
        { label = "今日福利", art = "daily", rects = L.daily, defs = GetDailyDefs(meta) },
        { label = "养成收藏", art = "collect", rects = L.grow, defs = GetGrowDefs(meta) },
    }
    for _, rowDef in ipairs(rows) do
        SectionHeader(ctx, 18, rowDef.rects[1].y - 27, 504, rowDef.label, rowDef.art)
        for i, def in ipairs(rowDef.defs) do
            local rr = rowDef.rects[i]
            local accent = def.tone == "ad" and C.ad or C.cyan
            local glow, press = D.controlFx(rr, true)
            D.panel(ctx, rr.x, rr.y, rr.w, rr.h, C.card, C.cyanDim, 4)
            -- 卡面内受光 / 内沉影：让每张福利/收藏卡有独立厚度，不靠阴影堆叠。
            D.rect(ctx, rr.x + 2, rr.y + 2, rr.w - 4, math.floor(rr.h * 0.4),
                {255, 255, 255, 16}, 3)
            D.rect(ctx, rr.x + 2, rr.y + math.floor(rr.h * 0.62), rr.w - 4,
                rr.h - math.floor(rr.h * 0.62) - 2, {0, 0, 0, 34}, 3)
            D.rect(ctx, rr.x + 2, rr.y + 1, rr.w - 4, 1, {C.dim[1], C.dim[2], C.dim[3], 70}, 0)
            D.corner(ctx, rr.x + 2, rr.y + 2, rr.w - 4, rr.h - 4,
                {C.dim[1], C.dim[2], C.dim[3], 105}, 6, 1)
            -- v0.13.54：卡面补极淡网格纹路（无关紧要，只做密度）。
            CardTrace(ctx, rr, 11)
            if glow > 0.01 then
                D.rect(ctx, rr.x + 3, rr.y + 3, rr.w - 6, rr.h - 6,
                    {accent[1], accent[2], accent[3], math.floor(30 * glow)}, 4)
                D.stroke(ctx, rr.x, rr.y, rr.w, rr.h,
                    {accent[1], accent[2], accent[3], math.floor(200 * glow)}, 4, 1)
            end
            if i > 1 then
                D.rect(ctx, rr.x - 4, rr.y + 16, 1, rr.h - 32, C.rail, 0)
            end
            D.icon(ctx, def.icon, rr.x + rr.w * 0.5 - 16, rr.y + 5 + press * 2, 32,
                def.hot and 1 or 0.85)
            D.text(ctx, rr.x + rr.w * 0.5, rr.y + 39 + press * 2, def.label, 17, C.text,
                NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            local subSize = D.fit(ctx, def.sub, 15, rr.w - 10, 15)
            D.text(ctx, rr.x + rr.w * 0.5, rr.y + 60, def.sub, subSize,
                def.tone == "ad" and C.ad or C.dim, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            if def.hot then D.rect(ctx, rr.x + rr.w - 14, rr.y + 9, 5, 5, accent, 3) end
        end
    end

    if meta.toast and meta.toast ~= "" then
        D.text(ctx, w * 0.5, 510, meta.toast, 16, C.warn,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
end

---@return string|nil action
function MetaUI.HitTestMenuBar(uiX, uiY, meta)
    local L = GetMenuBarLayout()
    if Inside(L.fleet, uiX, uiY) then return "open_talent" end
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

local DrawTaskExtras = nil   -- 前向声明：DrawTasks 调用点在定义之前（AB-100 同族）

local function DrawTasks(ctx, w, meta)
    local C = Colors()
    local content, close = Shell(ctx, w, 960, "每日任务", "", meta)
    local tasks = meta.tasks or {}
    local rowH, gap = 108, 12
    local y = content.y + 16
    -- v0.13.46：补分区标题（与主菜单/商店/战斗档案同语言），提示行与任务行整体下移让位。
    SectionHeader(ctx, content.x + 4, content.y + 14, content.w - 8, "今日任务")
    D.text(ctx, content.x + 4, y + 26, "完成每日任务，领取零件", 16, C.dim)
    y = y + 54
    for i, task in ipairs(tasks) do
        local r = { x = content.x, y = y + (i - 1) * (rowH + gap), w = content.w, h = rowH }
        D.panel(ctx, r.x, r.y, r.w, r.h, C.card, task.claimable and C.warn or C.cyanDim, 6)
        -- 任务行内受光 / 内沉影，可领取时左缘金色识别条。
        D.rect(ctx, r.x + 2, r.y + 2, r.w - 4, math.floor(r.h * 0.42), {255, 255, 255, 16}, 4)
        D.rect(ctx, r.x + 2, r.y + math.floor(r.h * 0.6), r.w - 4,
            r.h - math.floor(r.h * 0.6) - 2, {0, 0, 0, 36}, 4)
        D.rect(ctx, r.x + 3, r.y + 12, 3, r.h - 24,
            task.claimable and C.warn or {120, 148, 162, 110}, 1)
        -- v0.13.54：任务行补极淡纹路（网格 + 四角折线）。
        CardTrace(ctx, r, 10)
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

    -- v0.13.61：任务行下方原本大片留白——补「价值锚点」三段（全部读真实 tasks 数据，
    -- 无数据则整块隐藏，不造假数）：①本屏可赚总览 ②下一目标进度 ③领取里程碑阶梯。
    DrawTaskExtras(ctx, content, meta, y + #tasks * (rowH + gap))
    return content, close
end

-- 任务面板下半屏的价值锚点模块（商业化：价值锚定 + 进度目标 + 成就阶梯）。
-- 聚合读数全部来自 meta.tasks 真实字段；无任务则整块不画。
---@param ctx any
---@param content table
---@param meta MetaState
---@param topY number 任务行下方的起始 y
DrawTaskExtras = function(ctx, content, meta, topY)
    local C = Colors()
    local tasks = meta.tasks or {}
    if #tasks == 0 then return end
    local claimed, claimable, totalReward = 0, 0, 0
    for _, t in ipairs(tasks) do
        if t.claimed then claimed = claimed + 1 end
        if t.claimable then claimable = claimable + 1 end
        totalReward = totalReward + (t.reward or 0)
    end
    -- ⚠️ 三段必须整体落在内容区内（Shell 底部让出状态条后内容高 664）——起始 y 与
    -- 各段高度都收紧，保证「总览 + 下一目标 + 里程碑」三段底边 < content 底。
    local y = math.max(topY + 6, content.y + 424)

    -- ① 任务总览条：把散落的奖励聚成「这一屏能拿多少」——价值锚定。
    local sum = { x = content.x, y = y, w = content.w, h = 68 }
    D.panel(ctx, sum.x, sum.y, sum.w, sum.h, C.rail, C.cyanDim, 6)
    D.rect(ctx, sum.x + 2, sum.y + 2, sum.w - 4, math.floor(sum.h * 0.42), {255, 255, 255, 18}, 4)
    D.rect(ctx, sum.x + 2, sum.y + math.floor(sum.h * 0.6), sum.w - 4,
        sum.h - math.floor(sum.h * 0.6) - 2, {0, 0, 0, 40}, 4)
    D.rect(ctx, sum.x + 4, sum.y + 1, sum.w - 8, 1, {C.dim[1], C.dim[2], C.dim[3], 70}, 0)
    local cellW = sum.w / 3
    local stats = {
        { string.format("%d / %d", claimed, #tasks), "已领取", C.cyan },
        { string.format("%d", claimable), "可领取", claimable > 0 and C.warn or C.dim },
        { string.format("%d", totalReward), "零件总额", C.text },
    }
    for i, st in ipairs(stats) do
        local cx = sum.x + cellW * (i - 0.5)
        D.text(ctx, cx, sum.y + 8, st[1], 23, st[3], NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        D.text(ctx, cx, sum.y + 42, st[2], 14, C.dim, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        if i < 3 then
            D.rect(ctx, sum.x + cellW * i, sum.y + 12, 1, sum.h - 24,
                {C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 90}, 0)
        end
    end

    -- ② 下一目标卡：挑最接近完成（进度比最高、未领）的一条，给「再打一点就拿到」。
    local best, bestRatio = nil, -1
    for _, t in ipairs(tasks) do
        if not t.claimed then
            local ratio = (t.progress or 0) / math.max(1, t.target or 1)
            if t.claimable then ratio = 2 end
            if ratio > bestRatio then best, bestRatio = t, ratio end
        end
    end
    if best then
        local g = { x = content.x, y = sum.y + sum.h + 8, w = content.w, h = 86 }
        D.panel(ctx, g.x, g.y, g.w, g.h, C.card, C.cyanDim, 6)
        D.rect(ctx, g.x + 2, g.y + 2, g.w - 4, math.floor(g.h * 0.42), {255, 255, 255, 16}, 4)
        D.rect(ctx, g.x + 2, g.y + math.floor(g.h * 0.62), g.w - 4,
            g.h - math.floor(g.h * 0.62) - 2, {0, 0, 0, 34}, 4)
        D.rect(ctx, g.x + 3, g.y + 12, 3, g.h - 24, best.claimable and C.warn or C.cyan, 1)
        SectionHeader(ctx, g.x + 14, g.y + 8, g.w - 28, "下一目标")
        D.text(ctx, g.x + 16, g.y + 34, best.name, 17, C.text)
        local prog, tgt = best.progress or 0, math.max(1, best.target or 1)
        D.text(ctx, g.x + g.w - 16, g.y + 34,
            string.format("%d / %d", math.min(prog, tgt), tgt), 15,
            best.claimable and C.warn or C.dim, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
        ProgressBar(ctx, g.x + 16, g.y + 60, g.w - 32, math.min(1, prog / tgt),
            best.claimable and C.warn or C.cyan, 9)
    end

    -- ③ 领取里程碑阶梯：3 档（领 1 / 领 2 / 领 3 项），已过档打勾——成就阶梯。
    local ms = { x = content.x, y = (best and (sum.y + sum.h + 102) or (sum.y + sum.h + 8)), w = content.w, h = 46 }
    if ms.y + ms.h <= content.y + content.h then
        D.panel(ctx, ms.x, ms.y, ms.w, ms.h, C.rail, C.cyanDim, 6)
        D.rect(ctx, ms.x + 2, ms.y + 2, ms.w - 4, math.floor(ms.h * 0.42), {255, 255, 255, 14}, 4)
        local tiers = { 1, 2, 3 }
        local cw = ms.w / #tiers
        for i, need in ipairs(tiers) do
            local cx = ms.x + cw * (i - 0.5)
            local done = claimed >= need
            local tone = done and C.cyan or { C.dim[1], C.dim[2], C.dim[3], 200 }
            nvgBeginPath(ctx)
            nvgCircle(ctx, cx - 26, ms.y + ms.h * 0.5, 9)
            nvgStrokeColor(ctx, nvgRGBA(tone[1], tone[2], tone[3], done and 230 or 130))
            nvgStrokeWidth(ctx, done and 2 or 1)
            nvgStroke(ctx)
            if done then
                D.text(ctx, cx - 26, ms.y + ms.h * 0.5 - 8, "✓", 15, C.cyan,
                    NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            end
            D.text(ctx, cx - 10, ms.y + ms.h * 0.5 - 9,
                string.format("领取 %d 项", need), 15, done and C.text or C.dim)
        end
    end
end

---@return string|nil action
---@return integer|nil index
local function HitTestTasks(uiX, uiY, w, meta)
    local L, close = GetShellLayout(w)
    if Inside(close, uiX, uiY) then return "close", nil end
    local tasks = meta.tasks or {}
    local rowH, gap = 108, 12
    -- v0.13.46：与 DrawTasks 同步下移 22px（分区标题让位），两处必须一致。
    local y = L.y + 70
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
        string.format("%d / %d", meta.codexUnlocked or 0, meta.codexTotal or 0), meta)
    local entries = MetaCatalog.GetCodex()
    -- v0.13.61：Shell 底部新增状态条，内容区矮 40px——压缩行距（gap 12→9）与起点，
    -- 4 行卡仍落在 scissor 可视区内（卡内文本用 ch 锚底，故不改卡高）。
    local cw, ch, gap = 226, 146, 9
    local y0 = content.y + 10
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
        D.panel(ctx, x, y, cw, ch, C.card, owned and C.cyanDim or {C.dim[1], C.dim[2], C.dim[3], 130}, 6)
        D.rect(ctx, x, y, 3, ch, owned and C.cyan or C.widget, 0)
        -- v0.13.46：补内受光 / 内沉影 / 顶亮线，与商店浏览卡同一套厚度语言（只加不减）。
        D.rect(ctx, x + 2, y + 2, cw - 4, math.floor(ch * 0.42),
            {255, 255, 255, owned and 20 or 12}, 4)
        D.rect(ctx, x + 2, y + math.floor(ch * 0.62), cw - 4,
            ch - math.floor(ch * 0.62) - 2, {0, 0, 0, owned and 40 or 28}, 4)
        D.rect(ctx, x + 4, y + 1, cw - 8, 1, {C.dim[1], C.dim[2], C.dim[3], 70}, 0)
        -- v0.13.54：图鉴卡补极淡纹路（网格 + 四角折线）。
        CardTrace(ctx, { x = x, y = y, w = cw, h = ch }, owned and 13 or 9)
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
        local lines = D.wrap(ctx, entry.note, 13, cw - 28)
        for li = 1, math.min(2, #lines) do
            D.text(ctx, x + 14, y + 90 + (li - 1) * 15, lines[li], 13, C.dim)
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
        meta.rankTotal and ("共 " .. tostring(meta.rankTotal) .. " 人") or "", meta)
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
        -- v0.13.46：补内受光 / 内沉影 / 顶亮线（列表行厚度，只加不减）。
        D.rect(ctx, r.x + 2, r.y + 2, r.w - 4, math.floor(r.h * 0.42),
            {255, 255, 255, mine and 22 or 12}, 4)
        D.rect(ctx, r.x + 2, r.y + math.floor(r.h * 0.6), r.w - 4,
            r.h - math.floor(r.h * 0.6) - 2, {0, 0, 0, mine and 42 or 30}, 4)
        D.rect(ctx, r.x + 4, r.y + 1, r.w - 8, 1, {C.dim[1], C.dim[2], C.dim[3], 70}, 0)
        -- v0.13.54：排行行补极淡纹路（网格 + 四角折线）。
        CardTrace(ctx, r, mine and 12 or 9)
        if mine then D.rect(ctx, r.x + 3, r.y + 10, 3, r.h - 20, C.cyan, 1) end
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
    -- v0.13.46：页脚条补内受光 / 内沉影，与列表行同厚度（只加不减）。
    D.rect(ctx, content.x + 2, rankFooterY + 2, content.w - 4, math.floor(56 * 0.42),
        {255, 255, 255, 18}, 4)
    D.rect(ctx, content.x + 2, rankFooterY + math.floor(56 * 0.6), content.w - 4,
        56 - math.floor(56 * 0.6) - 2, {0, 0, 0, 40}, 4)
    -- v0.13.54：页脚条补极淡纹路。
    CardTrace(ctx, { x = content.x, y = rankFooterY, w = content.w, h = 56 }, 10)
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

-- Update 的物理尺寸预算与两处实际 Draw 共用几何，不在绘制帧内分配 RT。
function MetaUI.GetVehicleStageRect(screen, w)
    if screen == "shop" then
        local content = GetShellLayout(w)
        return {x = content.x, y = content.y + 56, w = content.w, h = 216}
    end
    return {x = 18, y = 180, w = w - 36, h = 238}
end

local function GetShopLayout(w)
    local content, close = GetShellLayout(w)
    -- 顶行：左侧紧凑分页标签 + 右侧当前项名称/序号（两者同行不重叠）。
    -- v0.13.61：Shell 底部新增 34px 状态条，内容区矮了 40px——商店整体压缩让位，
    -- 保证两行免费补给（giftRowY + 2×56）仍落在 content 底之内。
    return {
        content = content, close = close, titleY = content.y + 8,
        stage = MetaUI.GetVehicleStageRect("shop", w),
        rowY = content.y + 300, rowH = 68, rowStep = 74,
        purchase = {x = content.x + content.w - 182, y = content.y + 452, w = 180, h = 50},
        giftTitleY = content.y + 512, giftRowY = content.y + 538,
    }
end

-- 六个浏览位与独立购买区；浏览位永远不扣款。
local function GetShopCarButton(layout, index)
    local gap = 8
    local bw = (layout.content.w - gap * 2) / 3
    local col, row = (index - 1) % 3, math.floor((index - 1) / 3)
    return {x = layout.content.x + col * (bw + gap), y = layout.rowY + row * layout.rowStep,
        w = bw, h = layout.rowH}, layout.purchase
end

local function GetShopGiftButton(layout, index)
    local r = {x = layout.content.x, y = layout.giftRowY + (index - 1) * 56,
        w = layout.content.w, h = 56}
    return r, {x = r.x + r.w - 146, y = r.y + 4, w = 132, h = 48}
end

-- 商店顶部两个紧凑分页按钮（车型 / 拖尾），靠左；右侧留白给当前项名称。
local function GetShopTabs(layout)
    local gap = 8
    local bw = 116
    local y = layout.content.y + 6
    return {x = layout.content.x, y = y, w = bw, h = 32},
           {x = layout.content.x + bw + gap, y = y, w = bw, h = 32}
end

-- 粒子系拖尾的 2D 预览：与 3D `SyncTrailParticles` **同一套参数**（emit/pSize/pDrift/
-- pLife），确定性散布（非 math.random），读起来是「一团离散光尘/光片」而非光带。
-- 颜色与 3D 纹理烘焙色对应：彗星暖金、流光青白。
local function DrawTrailParticlePreview(ctx, r, style, base, phase)
    local C = Colors()
    local cx, cy = r.x + r.w * 0.5, r.y + r.h * 0.5
    local x0, x1 = cx + r.w * 0.42, cx - r.w * 0.42   -- x0=车尾(亮), x1=尾端
    local baseHalf = 13
    local emit = style.emit or 60
    local spread = style.emitSpread or 0.3
    local pSize = style.pSize or 1.2
    local pGrow = style.pGrow or 0.4
    local pJitter = style.pJitter or 0.3
    local pDrift = style.pDrift or 0.5
    local pLife = style.pLife or 0.42
    -- 沿预览条长按 emit 撒点；相位随时间滚动 → 光尘在「往后飘」。
    local span = math.abs(x0 - x1)
    local count = math.min(150, math.floor(span / 7 * (emit / 60) * 2.4))
    local function hash(n)
        local s = math.sin(n * 12.9898 + 78.233) * 43758.5453
        return s - math.floor(s)
    end
    for i = 1, count do
        local f = hash(i)
        local g = hash(i + 101.7)
        local h = hash(i + 311.3)
        -- t：1=车尾(新)，0=尾端(旧)。相位滚动让「新点」持续从车尾冒出。
        local t = ((f + phase * 0.10) % 1.0)
        local xa = x0 + (x1 - x0) * (1 - t)
        local age = (1 - t) * pLife
        local lifeT = math.max(0, 1 - age / pLife)
        local half = baseHalf
        -- 与 3D 同式：发射散布 + 抖动，沿寿命横向漂移。
        local offY = (g - 0.5) * 2 * spread * half + (h - 0.5) * 2 * pJitter * half
        local driftY = offY * 0.35 + (g - 0.5) * pDrift * age * half * 2.2
        local grow = 1 + pGrow * (1 - lifeT)
        local shrink = lifeT < 0.3 and (lifeT / 0.3) or 1
        local sz = math.max(1.2, pSize * half * 0.42 * (0.7 + 0.6 * g) * grow * shrink)
        local alpha = math.floor((40 + 190 * lifeT * lifeT) * TRAIL_PREVIEW_OPACITY)
        local mul = 0.72 + 0.5 * lifeT
        D.rect(ctx, xa - sz * 0.5, cy + driftY - sz * 0.5, sz, sz,
            {math.min(255, math.floor(base[1] * mul * 255)),
             math.min(255, math.floor(base[2] * mul * 255)),
             math.min(255, math.floor(base[3] * mul * 255)), alpha}, sz * 0.5)
    end
    -- 头端一颗灼核（彗星）/ 亮片（流光）：标示「贴车端」。
    local coreR = baseHalf * (style.particle == 1 and pSize * 0.55 or 4)
    D.rect(ctx, x0 - coreR, cy - coreR, coreR * 2, coreR * 2,
        {math.min(255, math.floor(base[1] * 255)), math.min(255, math.floor(base[2] * 255)),
         math.min(255, math.floor(base[3] * 255)), math.floor(210 * TRAIL_PREVIEW_OPACITY)}, coreR)
    D.text(ctx, r.x + r.w * 0.5, r.y + 10, "尾迹预览", 15, C.dim,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
end

-- 拖尾 2D 预览：与 3D 光带**同一套样式参数与同一套机制轴**（taper/bulge/hue/waver/flicker/
-- pulse/双轨收拢/层叠），保证预览里看到的差异就是实机差异。⚠️ D.rect 颜色是 0..255，样式色是 0..1。
-- 宽度同样锚定**车体真实半宽**（3D 的 vHalf），预览用 baseHalf 表示车体半宽。
local function DrawTrailPreview(ctx, r, trailKey)
    local C = Colors()
    local style = MetaCatalog.GetTrailStyleParams(MetaCatalog.GetTrailStyle(trailKey))
    local base = {0.30, 0.90, 1.00}
    if style.warm == 1 then base = {1.00, 0.58, 0.18} end
    local phase = D.anim and D.anim() or 0
    -- v0.13.58：彗星/流光是**粒子系**，2D 预览走离散光尘（与光带预览完全不同的形态）。
    if style.particle == 1 then
        DrawTrailParticlePreview(ctx, r, style, base, phase)
        return
    end
    local taper = style.taper or 1.0
    local bulge = style.bulge or 0.0
    local hue = style.hue or 0.0
    local pulse = style.pulse or 0.0
    local waver = style.waver or 0.0
    local waverLen = style.waverLen or 0.9
    local waverDrift = style.waverDrift or 0.0
    local flicker = style.flicker or 0.0
    local flickerFreq = style.flickerFreq or 0.0
    local railSpread = style.railSpread or 1.35
    local railTaper = style.railTaper or 1.0
    local glow = style.glow or 0.0
    local core = style.core or 0.0
    local twist = style.twist or 0.0
    local cx, cy = r.x + r.w * 0.5, r.y + r.h * 0.5
    local x0, x1 = cx + r.w * 0.42, cx - r.w * 0.42   -- x0=车尾, x1=尾端
    local baseHalf = 13                                 -- 车体真实半宽的屏幕代表
    local twin = style.twin == 1
    local railHalf = baseHalf * 0.32
    local segs = 40
    local phase0 = phase * waverDrift
    local function rgba(f, t, alpha, mul)
        mul = mul or 1
        local rr, gg, bb = base[1] * f * mul, base[2] * f * mul, base[3] * f * mul
        if hue > 0 then
            local k = (1 - t) * hue
            rr, gg, bb = rr + 0.55 * k, gg * (1 - 0.35 * k), bb + 0.35 * k
        end
        return {math.min(255, math.floor(rr * 255)), math.min(255, math.floor(gg * 255)),
            math.min(255, math.floor(bb * 255)), alpha}
    end
    for i = 1, segs - 1 do
        local t0 = (i - 1) / (segs - 1)
        local t1 = i / (segs - 1)
        -- x0(右=车尾) → x1(左=尾端)，宽度必须取正值。
        local xa = x0 + (x1 - x0) * t0
        local xb = x0 + (x1 - x0) * t1
        local rx, rw = math.min(xa, xb), math.abs(xb - xa)
        -- t：1=车尾(宽亮端)，0=尾端（同 3D 头亮尾暗）。
        local t = 1 - (t0 + t1) * 0.5
        local half = (style.tailW + (style.headW - style.tailW) * (t ^ taper)) * baseHalf
        if bulge > 0 then half = half * (1 + bulge * t * t) end
        -- 沿弧长取相位（与 3D 同式）：波动 + 明暗噪声都**非周期、不随时间跳**。
        local along = (t0 + t1) * 0.5 * 3.0
        local ns = flicker > 0 and flicker * math.sin(along * flickerFreq + 0.5) or 0
        local f = (style.base + (1 - style.base) * t) * style.bright * math.max(0, 1 + ns)
        if pulse > 0 then
            f = f * (1 - pulse + pulse * (0.5 + 0.5 * math.sin(phase * 3.4 + t * 2.2)))
        end
        f = math.min(1, f)
        -- 中线波动：沿长度正弦（**非直线**），幅度随离车距离增大（尾端更飘）；与 3D 同式。
        local wob = 0
        if waver > 0 then
            wob = baseHalf * waver * (1 - t) * math.sin(along / waverLen + phase0)
        end
        -- 扭转在 2D 里的投影：截面转出画面 → 中线随弧长上下摆（车头 0）。
        local yc = cy + wob + twist * 5.0 * (1 - t) * math.sin(twist * (i - 1) * 2.2 + phase * 0.8)
        -- ① 外层柔光：宽而暗，垫在主体下（不超车体半宽）。
        if glow > 1.0 then
            local gA = math.floor((60 + 70 * f) * math.max(0.05, 0.34 + ns * 0.4) / 0.34
                * TRAIL_PREVIEW_OPACITY)
            local gw = math.min(half * glow, baseHalf)
            if twin then
                local spread = baseHalf * railSpread * (t ^ railTaper)
                D.rect(ctx, rx, yc - spread - gw, rw, gw * 2, rgba(f, t, gA, 0.42), 0)
                D.rect(ctx, rx, yc + spread - gw, rw, gw * 2, rgba(f, t, gA, 0.42), 0)
            else
                D.rect(ctx, rx, yc - gw, rw, gw * 2, rgba(f, t, gA, 0.42), 0)
            end
        end
        -- ② 主体 + ③ 高亮芯。
        local alpha = math.floor((90 + 165 * f) * TRAIL_PREVIEW_OPACITY)
        if twin then
            local spread = baseHalf * railSpread * (t ^ railTaper)
            D.rect(ctx, rx, yc - spread - railHalf, rw, railHalf * 2, rgba(f, t, alpha), 0)
            D.rect(ctx, rx, yc + spread - railHalf, rw, railHalf * 2, rgba(f, t, alpha), 0)
            if core > 0 then
                D.rect(ctx, rx, yc - spread - railHalf * 0.42, rw, railHalf * 0.84,
                    rgba(f, t, math.min(255, alpha + 40), 1.0 + core * 0.35), 0)
                D.rect(ctx, rx, yc + spread - railHalf * 0.42, rw, railHalf * 0.84,
                    rgba(f, t, math.min(255, alpha + 40), 1.0 + core * 0.35), 0)
            end
        else
            D.rect(ctx, rx, yc - half, rw, half * 2, rgba(f, t, alpha), 0)
            if core > 0 then
                D.rect(ctx, rx, yc - half * 0.40, rw, half * 0.80,
                    rgba(f, t, math.min(255, alpha + 40), 1.0 + core * 0.35), 0)
            end
        end
    end
    D.text(ctx, r.x + r.w * 0.5, r.y + 10, "尾迹预览", 15, C.dim,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
end

-- 分页标签（车型 / 拖尾）：绘制与命中同源。
local function DrawShopTabs(ctx, layout)
    local C = Colors()
    local vehicleTab, trailTab = GetShopTabs(layout)
    local function tab(r, label, artKey, active)
        local glow, press = D.controlFx(r, true)
        D.panel(ctx, r.x, r.y, r.w, r.h, active and C.rail or C.card,
            active and C.warnDim or {C.dim[1], C.dim[2], C.dim[3], 80}, 6)
        -- 标签内受光 / 内沉影：激活态更亮，未激活仍保留厚度。（v0.13.53 转暖金）
        D.rect(ctx, r.x + 2, r.y + 2, r.w - 4, math.floor(r.h * 0.44),
            {255, 240, 205, active and 28 or 14}, 4)
        D.rect(ctx, r.x + 2, r.y + math.floor(r.h * 0.6), r.w - 4,
            r.h - math.floor(r.h * 0.6) - 2, {0, 0, 0, active and 46 or 32}, 4)
        if active then D.rect(ctx, r.x + 8, r.y + r.h - 3, r.w - 16, 2, C.warn, 0) end
        -- v0.13.54：分页标签补极淡网格纹路。
        CardTrace(ctx, r, active and 13 or 9)
        if glow > 0.01 then
            D.stroke(ctx, r.x, r.y, r.w, r.h,
                {C.warn[1], C.warn[2], C.warn[3], math.floor(glow * 200)}, 6, 1.4)
        end
        -- v0.13.58：标签文案改用 AI 像素艺术字。⚠️ 金属立体字**不能用非白 tint**
        -- （金/暗灰都会把金属灰压塌、丢倒角，同 CTA）——统一用**白 tint**；
        -- 用户要求「更白更浅」→ 白 tint + 激活满 alpha、未激活降 alpha（读起来浅灰）。
        local tint = {255, 255, 255, active and 255 or 190}
        if not (artKey and ArtText.Has(artKey)
            and ArtText.DrawCentered(ctx, artKey, r, tint, press * 2 + 1, 1)) then
            D.text(ctx, r.x + r.w * 0.5, r.y + 8 + press * 2, label, 17,
                active and C.text or C.dim, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        end
    end
    tab(vehicleTab, "车型外观", "vehicle", shopTab == "vehicle")
    tab(trailTab, "拖尾样式", "trail", shopTab == "trail")
end

-- 六格浏览卡（车型/拖尾共用几何）：画一个卡、返回其命中矩形。
local function DrawShopCard(ctx, layout, index, activeIndex, name, owned, equipped, cost)
    local C = Colors()
    local r = GetShopCarButton(layout, index)
    local active = index == activeIndex
    local glow, press = D.controlFx(r, true)
    -- v0.13.53：商店是「收藏/稀有」语义 → 走暖金系，与冷色战斗 UI 区分（提消费欲望）。
    D.panel(ctx, r.x, r.y, r.w, r.h, active and C.rail or C.card,
        active and C.warn or {C.dim[1], C.dim[2], C.dim[3], 90}, 5)
    -- 浏览卡内受光 / 内沉影 + 左识别标记，选中态加金左标。
    D.rect(ctx, r.x + 2, r.y + 2, r.w - 4, math.floor(r.h * 0.44),
        {255, 240, 205, active and 26 or 14}, 4)
    D.rect(ctx, r.x + 2, r.y + math.floor(r.h * 0.6), r.w - 4,
        r.h - math.floor(r.h * 0.6) - 2, {0, 0, 0, active and 44 or 30}, 4)
    D.rect(ctx, r.x + 2, r.y + 1, r.w - 4, 1, {C.warn[1], C.warn[2], C.warn[3], 80}, 0)
    D.rect(ctx, r.x + 3, r.y + 8, 3, r.h - 16,
        active and C.warn or {C.dim[1], C.dim[2], C.dim[3], 120}, 1)
    -- v0.13.54：浏览卡补极淡纹路（网格 + 四角折线），与其余面板同密度语言。
    CardTrace(ctx, r, active and 14 or 10)
    if active then D.rect(ctx, r.x + 4, r.y + r.h - 3, r.w - 8, 2, C.warn, 0) end
    if glow > 0.01 then
        D.stroke(ctx, r.x, r.y, r.w, r.h,
            {C.warn[1], C.warn[2], C.warn[3], math.floor(glow * 200)}, 5, 1.4)
    end
    D.text(ctx, r.x + 12, r.y + 12 + press * 2, name, 18, C.text)
    D.text(ctx, r.x + 12, r.y + 45,
        equipped and "使用中" or (owned and "已拥有" or tostring(cost) .. " 零件"),
        15, owned and C.warn or C.dim)
    return r
end

-- 购买/装备区（车型/拖尾共用）：画价格、余额与按钮。
local function DrawShopPurchase(ctx, layout, equipped, owned, cost, parts, ownedNote, equipLabel, buyLabel)
    local C = Colors()
    local content = layout.content
    local buyY = layout.purchase.y
    D.panel(ctx, content.x, buyY - 7, content.w, 66, C.rail, C.warnDim, 6)
    -- v0.13.53：购买区走暖金（获取/花费语义），与商店卡同一条暖路径。
    D.rect(ctx, content.x + 2, buyY - 5, content.w - 4, math.floor(66 * 0.42),
        {255, 240, 205, 20}, 4)
    D.rect(ctx, content.x + 2, buyY - 7 + math.floor(66 * 0.6), content.w - 4,
        66 - math.floor(66 * 0.6) - 2, {0, 0, 0, 38}, 4)
    -- v0.13.54：购买区补极淡纹路。
    CardTrace(ctx, { x = content.x, y = buyY - 7, w = content.w, h = 66 }, 11)
    D.icon(ctx, "parts", content.x + 4, buyY + 10, 32, 1)
    D.text(ctx, content.x + 46, buyY + 2, equipped and "当前使用" or (owned and "已拥有" or tostring(cost)),
        28, equipped and C.cyan or C.warn)
    local balanceText = owned and ownedNote or string.format("持有 %d 零件", parts or 0)
    local balanceWidth = layout.purchase.x - content.x - 54
    local balanceSize, balanceFits = D.fit(ctx, balanceText, 15, balanceWidth, 15)
    if not balanceFits then
        -- 货币单位已有零件图标指示，饱和时移除重复单位，完整余额仍保留。
        balanceText = "持有 " .. tostring(parts or 0)
        balanceSize = D.fit(ctx, balanceText, 15, balanceWidth, 15)
    end
    D.text(ctx, content.x + 46, buyY + 36, balanceText, balanceSize, C.dim)
    local kind = (equipped or (not owned and (parts or 0) < cost)) and "disabled" or "primary"
    local label = equipped and "使用中" or (owned and equipLabel or ((parts or 0) >= cost and buyLabel or "零件不足"))
    Button(ctx, layout.purchase, label, "", kind)
end

-- v0.13.78：页签切换过渡（商店 车型↔拖尾 / 档案 档案↔成就）共用的相位状态。
-- key 区分不同页签组，方向按切换顺序给，内容淡入 + 横向滑入，页签本身不动。
local tabPhaseSeen = {}
local tabPhaseAt = {}
local tabPhaseDir = {}

---@param anim number|nil
---@param key string
---@param value string
---@return number phase 0..1, integer dir
local function TabPhase(anim, key, value)
    if anim == nil then return 1, 1 end
    local seen = tabPhaseSeen[key]
    if seen ~= value then
        local order = { vehicle = 1, trail = 2, pass = 1, ach = 2 }
        local a = order[seen] or 0
        local b = order[value] or 0
        tabPhaseDir[key] = (b >= a) and 1 or -1
        tabPhaseSeen[key], tabPhaseAt[key] = value, anim
    end
    local phase = math.min(1, math.max(0, (anim - (tabPhaseAt[key] or anim)) / 0.22))
    return phase, tabPhaseDir[key] or 1
end

local function DrawShop(ctx, w, meta)
    local C = Colors()
    local content, close = Shell(ctx, w, 960, "皮肤商店", "外观 · 不改变属性", meta)
    local layout = GetShopLayout(w)
    nvgSave(ctx)
    nvgIntersectScissor(ctx, content.x, content.y, content.w, content.h)
    DrawShopTabs(ctx, layout)
    -- 分页内容淡入 + 横向滑入（页签本身不动，保持定位稳定）
    local anim = D and D.anim and D.anim() or nil
    local phase, dir = TabPhase(anim, "shop", shopTab)
    local ease = 1 - (1 - phase) * (1 - phase) * (1 - phase)
    nvgSave(ctx)
    if ease < 1 then
        nvgGlobalAlpha(ctx, 0.25 + 0.75 * ease)
        nvgTranslate(ctx, dir * (1 - ease) * 18, 0)
    end
    if shopTab == "trail" then
        local trails = MetaCatalog.GetTrails()
        local trail = trails[trailIndex]
        local owned = trail.cost == 0 or (meta.trails and meta.trails[trail.key] == true)
        local equipped = meta.selectedTrail == trail.key
        D.text(ctx, content.x + content.w - 4, layout.titleY + 4, trail.name, 26, C.text,
            NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
        D.text(ctx, content.x + content.w - 4, layout.titleY + 34,
            string.format("%02d / %02d", trailIndex, #trails), 15, C.dim,
            NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
        D.panel(ctx, layout.stage.x, layout.stage.y, layout.stage.w, layout.stage.h,
            C.panel, C.cyanDim, 8)
        DrawTrailPreview(ctx, layout.stage, trail.key)
        D.text(ctx, content.x + content.w * 0.5, content.y + 282, trail.desc, 18, C.text,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        D.text(ctx, content.x + content.w * 0.5, content.y + 307, "拖尾样式 · 不改变战斗属性", 15, C.dim,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        for i, entry in ipairs(trails) do
            local has = entry.cost == 0 or (meta.trails and meta.trails[entry.key] == true)
            DrawShopCard(ctx, layout, i, trailIndex, entry.name, has,
                meta.selectedTrail == entry.key, entry.cost)
        end
        DrawShopPurchase(ctx, layout, equipped, owned, trail.cost, meta.parts,
            "已纳入拖尾收藏", "装备此样式", "解锁样式")
    else
        local skins = MetaCatalog.GetSkins()
        local skin = skins[showroom.index]
        local owned = skin.cost == 0 or (meta.skins and meta.skins[skin.key] == true)
        local equipped = meta.selectedSkin == skin.key
        D.text(ctx, content.x + content.w - 4, layout.titleY + 4, skin.name, 26, C.text,
            NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
        D.text(ctx, content.x + content.w - 4, layout.titleY + 34,
            string.format("%02d / %02d", showroom.index, #skins), 15, C.dim,
            NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
        DrawVehicleStage(ctx, layout.stage)
        D.text(ctx, content.x + content.w * 0.5, content.y + 282, skin.desc, 18, C.text,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        D.text(ctx, content.x + content.w * 0.5, content.y + 307, "车型外观 · 不改变战斗属性", 15, C.dim,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        for i, entry in ipairs(skins) do
            local has = entry.cost == 0 or (meta.skins and meta.skins[entry.key] == true)
            DrawShopCard(ctx, layout, i, showroom.index, entry.name, has,
                meta.selectedSkin == entry.key, entry.cost)
        end
        DrawShopPurchase(ctx, layout, equipped, owned, skin.cost, meta.parts,
            "已纳入车型收藏", "装备此车", "解锁车型")
        SectionHeader(ctx, content.x + 4, layout.giftTitleY, content.w - 8, "免费补给")
        for i, gift in ipairs(MetaCatalog.GetShopEntries()) do
            local r, btn = GetShopGiftButton(layout, i)
            local used = meta.giftUsed and meta.giftUsed[gift.key] or 0
            local limit = MetaCatalog.GetAdGiftDailyLimit(gift.key)
            D.text(ctx, r.x + 4, r.y + 3, gift.name, 18, C.text)
            D.text(ctx, r.x + 4, r.y + 29, gift.desc, 15, C.dim)
            Button(ctx, btn, used < limit and "看广告" or "今日已领",
                used < limit and string.format("%d/%d", used, limit) or "", used < limit and "ad" or "disabled")
        end
    end
    nvgGlobalAlpha(ctx, 1.0)
    nvgRestore(ctx) -- 分页过渡层
    nvgRestore(ctx) -- 内容裁切层
    return content, close
end

---@return string|nil action
---@return integer|nil index
local function HitTestShop(uiX, uiY, w, meta)
    local layout = GetShopLayout(w)
    if Inside(layout.close, uiX, uiY) then return "close", nil end
    if not Inside(layout.content, uiX, uiY) then return nil, nil end
    local vehicleTab, trailTab = GetShopTabs(layout)
    if Inside(vehicleTab, uiX, uiY) then return "shop_tab", nil end
    if Inside(trailTab, uiX, uiY) then return "shop_tab", nil end
    if shopTab == "trail" then
        local trails = MetaCatalog.GetTrails()
        for i in ipairs(trails) do
            local r = GetShopCarButton(layout, i)
            if Inside(r, uiX, uiY) then return "preview_trail", i end
        end
        local trail = trails[trailIndex]
        local owned = trail.cost == 0 or (meta.trails and meta.trails[trail.key] == true)
        if Inside(layout.purchase, uiX, uiY) and meta.selectedTrail ~= trail.key
            and (owned or (meta.parts or 0) >= trail.cost) then return "buy_trail", trailIndex end
        return nil, nil
    end
    local skins = MetaCatalog.GetSkins()
    for i in ipairs(skins) do
        local r = GetShopCarButton(layout, i)
        if Inside(r, uiX, uiY) then return "preview_skin", i end
    end
    local skin = skins[showroom.index]
    local owned = skin.cost == 0 or (meta.skins and meta.skins[skin.key] == true)
    if Inside(layout.purchase, uiX, uiY) and meta.selectedSkin ~= skin.key
        and (owned or (meta.parts or 0) >= skin.cost) then return "buy_skin", showroom.index end
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

-- v0.13.45：里程碑行整体下移 22px，为上方新增的分区标题让出位置。
-- 本函数是绘制与命中（HitTestPass）的共同来源，改这里两处自动同步。
local function GetPassRewardRect(content, index)
    return { x = content.x, y = content.y + 196 + (index - 1) * 92,
        w = content.w, h = 82 }
end

local function GetPassUnlockRect(content)
    return { x = content.x + content.w - 156, y = content.y + 110, w = 144, h = 42 }
end

-- v0.14.0：战斗档案屏顶部两个页签——「战斗档案」/「成就」。
-- 返回页签带（含整条底衬）与两枚页签矩形，绘制与命中同源。
---@param content table
---@return table tabPass
---@return table tabAch
local function GetPassTabs(content)
    local w = math.floor((content.w - 8) / 2)
    local y = content.y + 2
    return { x = content.x, y = y, w = w, h = 40 },
           { x = content.x + w + 8, y = y, w = w, h = 40 }
end

-- 页签下方的实际内容区（档案/成就共用）。
---@param content table
---@return table
local function GetPassBody(content)
    return { x = content.x, y = content.y + 50, w = content.w, h = content.h - 50 }
end

local function DrawPass(ctx, w, meta)
    local C = Colors()
    local content, close = Shell(ctx, w, 960, "战斗档案",
        meta.piggyMode and "存钱罐" or (meta.premiumPass and "双轨奖励" or "精英档案"), meta)

    -- v0.14.0：成就并入战斗档案——顶部两个页签，切换内容。
    local tabPass, tabAch = GetPassTabs(content)
    local achTab = (meta.passTab == "ach")
    local function Tab(rect, label, active)
        D.panel(ctx, rect.x, rect.y, rect.w, rect.h, active and C.widget or C.rail,
            active and C.cyan or C.cyanDim, 6)
        D.rect(ctx, rect.x + 2, rect.y + 2, rect.w - 4, math.floor(rect.h * 0.42),
            {255, 255, 255, active and 20 or 10}, 4)
        if active then D.rect(ctx, rect.x + 10, rect.y + rect.h - 4, rect.w - 20, 3, C.cyan, 1) end
        D.text(ctx, rect.x + rect.w * 0.5, rect.y + 11, label, 16,
            active and C.text or C.dim, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end
    Tab(tabPass, "战斗档案", not achTab)
    Tab(tabAch, string.format("成就 %d/%d", meta.achUnlocked or 0, meta.achTotal or 0), achTab)

    -- v0.13.78：档案↔成就页签切换过渡（内容淡入 + 横向滑入，页签不动）
    local passAnim = D and D.anim and D.anim() or nil
    local passPhase, passDir = TabPhase(passAnim, "pass", achTab and "ach" or "pass")
    local passEase = 1 - (1 - passPhase) * (1 - passPhase) * (1 - passPhase)

    local body = GetPassBody(content)
    if achTab then
        nvgSave(ctx)
        if passEase < 1 then
            nvgGlobalAlpha(ctx, 0.25 + 0.75 * passEase)
            nvgTranslate(ctx, passDir * (1 - passEase) * 18, 0)
        end
        Achievements.Draw(ctx, body, meta)
        nvgGlobalAlpha(ctx, 1.0)
        nvgRestore(ctx)
        return content, close
    end

    nvgSave(ctx)
    if passEase < 1 then
        nvgGlobalAlpha(ctx, 0.25 + 0.75 * passEase)
        nvgTranslate(ctx, passDir * (1 - passEase) * 18, 0)
    end
    nvgIntersectScissor(ctx, body.x, body.y, body.w, body.h)

    -- v0.14.x 存钱罐式：档案领满 6 级后改为无限积累、随时领取的存钱罐。
    if meta.piggyMode then
        local gear = meta.piggyGear or 0
        local hero = {x=body.x, y=body.y + 2, w=body.w, h=190}
        D.panel(ctx, hero.x, hero.y, hero.w, hero.h, C.rail,
            meta.premiumPass and C.warnDim or C.cyanDim, 8)
        D.icon(ctx, "premium_pass_crest", hero.x + 14, hero.y + 12, 32)
        D.text(ctx, hero.x + 56, hero.y + 10, "战斗存钱罐", 13, C.cyanDim)
        D.text(ctx, hero.x + 56, hero.y + 29,
            string.format("%d", gear), 34, C.text)
        D.text(ctx, hero.x + 56, hero.y + 72, "齿轮", 15, C.dim)
        D.text(ctx, hero.x + hero.w - 16, hero.y + 12, "可领取", 12, C.dim,
            NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
        D.text(ctx, hero.x + hero.w - 16, hero.y + 31,
            "+" .. tostring(gear), 23, C.warn, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
        D.text(ctx, hero.x + 16, hero.y + 100,
            "每击碎 200 块存 100 齿轮 · 精英积累 ×2", 13, C.dim)
        D.text(ctx, hero.x + 16, hero.y + 120,
            "随时领取 · 无限积累", 13, C.dim)
        local cr = { x = hero.x + 16, y = hero.y + 144, w = hero.w - 32, h = 38 }
        local label = gear > 0 and string.format("领取 %d 齿轮", gear) or "存钱罐空空"
        Button(ctx, cr, label, "折算零件", gear > 0 and "primary" or "disabled")
        nvgRestore(ctx)
        return content, close
    end

    local hero = {x=body.x, y=body.y+2, w=body.w, h=160}
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
        local ur = GetPassUnlockRect(body)
        local affordable = (not meta.offline) and (meta.gems or 0) >= (meta.premiumPassCost or 100)
        local label = meta.offline and "需联网" or (affordable and
            string.format("%d 钻石解锁", meta.premiumPassCost or 100) or "钻石不足")
        Button(ctx, ur, label, "精英轨 · 奖励×2", affordable and "gold" or "disabled")
    end

    -- v0.13.45：补分区标题，与主菜单/钻石商店同语言（青色＝免费产出语义）。
    SectionHeader(ctx, body.x + 4, body.y + 172, body.w - 8, "里程碑奖励")
    for i, item in ipairs(meta.passRewards or {}) do
        local r = GetPassRewardRect(body, i)
        local border = item.claimable and C.cyan or (item.unlocked and C.cyanDim or {C.dim[1], C.dim[2], C.dim[3], 130})
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
    nvgGlobalAlpha(ctx, 1.0)
    nvgRestore(ctx) -- 页签过渡层
    nvgRestore(ctx) -- 内容裁切层
    return content, close
end

local function HitTestPass(uiX, uiY, w, meta)
    local content, close = GetShellLayout(w)
    if Inside(close, uiX, uiY) then return "close", nil end
    if not Inside(content, uiX, uiY) then return nil, nil end

    -- v0.14.0：顶部两个页签（战斗档案 / 成就）——切换内容。
    local tabPass, tabAch = GetPassTabs(content)
    if Inside(tabPass, uiX, uiY) then return "pass_tab", nil end
    if Inside(tabAch, uiX, uiY) then return "ach_tab", nil end

    local body = GetPassBody(content)
    -- 成就页：命中交给 Achievements（列表区在其自身几何内，翻页/平台按钮同源）。
    if meta.passTab == "ach" then
        return Achievements.HitTest(uiX, uiY, body, meta)
    end
    if not Inside(body, uiX, uiY) then return nil, nil end

    -- v0.14.x 存钱罐式：命中唯一的「领取」按钮（几何与 DrawPass 的 cr 同源）。
    if meta.piggyMode then
        local heroY = body.y + 2
        local cr = { x = body.x + 16, y = heroY + 144, w = body.w - 32, h = 38 }
        if (meta.piggyGear or 0) > 0 and Inside(cr, uiX, uiY) then return "claim_gear", nil end
        return nil, nil
    end
    if not meta.premiumPass then
        local ur = GetPassUnlockRect(body)
        if Inside(ur, uiX, uiY)
            and not meta.offline
            and (meta.gems or 0) >= (meta.premiumPassCost or 100) then
            return "buy_premium_pass", nil
        end
    end
    for i, item in ipairs(meta.passRewards or {}) do
        local row = GetPassRewardRect(body, i)
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
    local content, close = Shell(ctx, w, 960, "幸运转盘", meta.wheelReady and "今日机会  /  01" or "今日机会已用", meta)
    local spin, cx, cy, radius = GetWheelLayout(w)
    -- v0.13.46：补分区标题（盘面上方留白充足，不与外环刻度相碰）。
    SectionHeader(ctx, content.x + 4, content.y + 8, content.w - 8, "转盘奖池")
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
    -- 环形刻度：长短两档各合并成一条路径（逐段各起路径是 O(n) 命令数）。
    for pass = 0, 1 do
        nvgBeginPath(ctx)
        local any = false
        for i = 0, 23 do
            local long = (i % 3 == 0)
            if (pass == 0) == long then
                any = true
                local a = math.pi * 2 * i / 24 - math.pi * 0.5
                local inner = ring + (long and 2 or 5)
                local outer = ring + 10
                nvgMoveTo(ctx, cx + math.cos(a) * inner, cy + math.sin(a) * inner)
                nvgLineTo(ctx, cx + math.cos(a) * outer, cy + math.sin(a) * outer)
            end
        end
        if any then
            local tc = pass == 0 and C.warn or C.cyanDim
            nvgStrokeColor(ctx, nvgRGBA(tc[1], tc[2], tc[3], pass == 0 and 200 or 120))
            nvgStrokeWidth(ctx, pass == 0 and 1.4 or 0.8)
            nvgStroke(ctx)
        end
    end
    -- v0.13.54：盘面外圈补「无关紧要的纹路」——虚线环 + 点阵环，纯装饰不承载读数。
    nvgBeginPath(ctx)
    for i = 0, 47 do
        local a0 = math.pi * 2 * i / 48
        local a1 = a0 + math.pi * 2 / 48 * 0.5
        nvgArc(ctx, cx, cy, ring + 15, a0, a1, NVG_CW)
    end
    nvgStrokeColor(ctx, nvgRGBA(C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 70))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
    nvgFillColor(ctx, nvgRGBA(C.cyanDim[1], C.cyanDim[2], C.cyanDim[3], 55))
    -- 点阵环：合并成单一路径（逐点各起路径会撑爆单帧命令缓冲，见 AB-216）。
    nvgBeginPath(ctx)
    for i = 0, 35 do
        local a = math.pi * 2 * i / 36
        nvgCircle(ctx, cx + math.cos(a) * (ring + 21), cy + math.sin(a) * (ring + 21), 1)
    end
    nvgFill(ctx)

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
        -- v0.13.46：中奖条补内受光 / 内沉影（只加不减）。
        D.rect(ctx, cx - 156, spin.y - 50, 312, math.floor(40 * 0.42), {255, 255, 255, 20}, 4)
        D.rect(ctx, cx - 156, spin.y - 52 + math.floor(40 * 0.6), 312,
            40 - math.floor(40 * 0.6) - 2, {0, 0, 0, 40}, 4)
        D.text(ctx, cx, spin.y - 42,
            string.format("今日获得  +%d 零件", meta.wheelPrize), 17, C.warn,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    else
        D.text(ctx, w * 0.5, spin.y - 34,
            "每次抽取必得至少 120 零件", 14, C.dim,
            NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    end

    -- v0.13.61：转盘按钮下方原本留白 ~114px——补「奖池一览条」（价值锚定：把最大可得值
    -- 亮出来）+「本次/上次获得卡」，全部读 MetaCatalog 奖池与 meta.wheelPrize 真实数据。
    local poolY = spin.y + spin.h + 12
    if poolY + 44 <= content.y + content.h then
        local pool = { x = content.x, y = poolY, w = content.w, h = 44 }
        D.panel(ctx, pool.x, pool.y, pool.w, pool.h, C.rail, C.cyanDim, 6)
        D.rect(ctx, pool.x + 2, pool.y + 2, pool.w - 4, math.floor(pool.h * 0.42),
            {255, 255, 255, 14}, 4)
        D.text(ctx, pool.x + 12, pool.y + 12, "奖池", 14, C.dim)
        -- 8 档奖品小格，最高档（800）金色高亮放大——价值锚点。
        local maxPrize = 0
        for _, pz in ipairs(prizes) do if pz > maxPrize then maxPrize = pz end end
        local cellW = (pool.w - 66) / n
        for i, pz in ipairs(prizes) do
            local gx = pool.x + 56 + (i - 1) * cellW
            local top = pz == maxPrize
            D.rect(ctx, gx, pool.y + 8, cellW - 5, pool.h - 16,
                top and C.warnDim or C.widget, 4)
            D.text(ctx, gx + (cellW - 5) * 0.5, pool.y + 15, tostring(pz),
                top and 15 or 13, top and C.warn or C.text,
                NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        end
    end
    local lastY = poolY + 52
    if meta.wheelPrize and meta.wheelPrize > 0 and lastY + 40 <= content.y + content.h then
        local last = { x = content.x, y = lastY, w = content.w, h = 40 }
        D.panel(ctx, last.x, last.y, last.w, last.h, C.card, C.warnDim, 6)
        D.rect(ctx, last.x + 2, last.y + 2, last.w - 4, math.floor(last.h * 0.42),
            {255, 255, 255, 16}, 4)
        D.icon(ctx, "premium_wheel_medal", last.x + 10, last.y + 4, 32, 1)
        D.text(ctx, last.x + 52, last.y + 11, "上次抽到", 15, C.dim)
        D.text(ctx, last.x + last.w - 16, last.y + 8,
            string.format("+%d 零件", meta.wheelPrize), 20, C.warn,
            NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
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

-- 插件式注册：额外面板（如钻石商店弹层）由编排层注册，避免 meta-ui 反向依赖业务模块。
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
