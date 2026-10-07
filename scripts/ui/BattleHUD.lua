-- BattleHUD.lua
-- 战斗仪表舱：基于 scaffold-2d 的组件树模式，嵌入既有 NanoVGRender。
-- UI.Label / UI.ProgressBar 负责读数；NanoVG 只画仪器外壳、刻度和扫描图形。
-- 不接管全局 UI root，不创建/销毁共享上下文，不订阅第二套输入或渲染事件。
local UI = require "urhox-libs/UI"
local BattleHUD = {}
local D = {}
---@type table<string, Panel>
local roots = {}
---@type table<string, Label>
local labels = {}
---@type table<string, ProgressBar>
local bars = {}
local state = { elapsed = nil, hp = 1, hpTrail = 1, damageHold = 0,
    score = 0, scorePop = 0, queue = {}, font = "zpix", ready = false }
local ammoIcons = { normal = "ammo_normal", ice = "ammo_ice", speed = "ammo_speed", giant = "ammo_giant" }

local function Alpha(color, a)
    return { color[1], color[2], color[3], math.floor(a) }
end

local function Rect(ctx, x, y, w, h, color, radius)
    D.rect(ctx, x, y, w, h, color, radius or 0)
end

local function Line(ctx, x1, y1, x2, y2, color, width)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x1, y1)
    nvgLineTo(ctx, x2, y2)
    nvgStrokeColor(ctx, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
    nvgStrokeWidth(ctx, width or 1)
    nvgStroke(ctx)
end

-- 宿主负责模式 A 的 DPR / CONTAIN；子树坐标始终是同一套 540×960 设计空间。
local function Root(name)
    if not roots[name] then
        roots[name] = UI.Panel { width = 540, height = 960, pointerEvents = "none",
            backgroundColor = { 0, 0, 0, 0 }, borderWidth = 0 }
        roots[name].absoluteLayout = { x = 0, y = 0, w = 540, h = 960 }
    end
    return roots[name]
end

-- 仅首次创建控件，后续复用；实测宽度自动降字号，数字不截断也不缩写。
local function Text(ctx, group, id, text, x, y, w, h, size, color, align)
    local key = group .. ":" .. id
    local label = labels[key]
    if not label then
        label = UI.Label { text = "", width = w, height = h, fontFamily = state.font,
            fontSize = size / UI.Theme.FontSize(1), textAlign = align or "left",
            verticalAlign = "middle", pointerEvents = "none", lineHeight = 1,
            backgroundColor = { 0, 0, 0, 0 }, borderWidth = 0 }
        Root(group):AddChild(label)
        labels[key] = label
    end
    local fit = size
    if label.battleText_ == text and label.battleSize_ == size and label.battleWidth_ == w then
        fit = label.battleFit_
    else
        nvgSave(ctx)
        nvgResetTransform(ctx)
        nvgFontFace(ctx, state.font)
        nvgFontSize(ctx, size)
        nvgTextLetterSpacing(ctx, 0)
        local advance = nvgTextBounds(ctx, 0, 0, text, nil)
        fit = advance > w and size * w / advance or size
        nvgRestore(ctx)
        label.battleText_, label.battleSize_, label.battleWidth_, label.battleFit_ = text, size, w, fit
    end
    label.absoluteLayout = { x = x, y = y, w = w, h = h }
    if label:GetText() ~= text then label:SetText(text) end
    local fontSize = fit / UI.Theme.FontSize(1)
    if label.props.fontSize ~= fontSize then label:SetFontSize(fontSize) end
    label:SetFontColor(color)
end

local function Bar(ctx, group, id, x, y, w, h, value, color)
    local key = group .. ":" .. id
    local bar = bars[key]
    if not bar then
        bar = UI.ProgressBar { width = w, height = h, value = 0, max = 1,
            showLabel = false, borderWidth = 0, borderRadius = 2,
            pointerEvents = "none", fillColor = color }
        Root(group):AddChild(bar)
        bars[key] = bar
    end
    bar.absoluteLayout = { x = x, y = y, w = w, h = h }
    bar:SetStyle({ fillColor = color })
    bar:SetValue(math.max(0, math.min(1, value)))
end

local function Render(group, ctx)
    -- 官方子树 API 不调用 BeginFrame/EndFrame，不扰动广告或大厅的全局 root。
    UI.RenderWidgetSubtree(Root(group), ctx)
end

-- 仪器边壳只有局部受光与短刻度；不在文字背后铺电路/网格。
local function Surface(ctx, x, y, w, h, accent, active)
    local C = D.C
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x, y, w, h, 5)
    nvgFillPaint(ctx, nvgLinearGradient(ctx, x, y, x, y + h,
        nvgRGBA(C.widget[1], C.widget[2], C.widget[3], 255),
        nvgRGBA(C.panel[1], C.panel[2], C.panel[3], 255)))
    nvgFill(ctx)
    D.stroke(ctx, x + 0.5, y + 0.5, w - 1, h - 1,
        active and Alpha(accent, 190) or Alpha(C.dim, 62), 5, 1)
    Line(ctx, x + 7, y + 1.5, x + w - 7, y + 1.5, Alpha(C.text, 40), 1)
    Line(ctx, x + 7, y + h - 2, x + w - 7, y + h - 2, Alpha(C.ink, 230), 1)
end

local function Corner(ctx, x, y, w, h, color)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x, y + 6); nvgLineTo(ctx, x, y); nvgLineTo(ctx, x + 6, y)
    nvgMoveTo(ctx, x + w - 6, y); nvgLineTo(ctx, x + w, y); nvgLineTo(ctx, x + w, y + 6)
    nvgMoveTo(ctx, x, y + h - 6); nvgLineTo(ctx, x, y + h); nvgLineTo(ctx, x + 6, y + h)
    nvgMoveTo(ctx, x + w - 6, y + h); nvgLineTo(ctx, x + w, y + h); nvgLineTo(ctx, x + w, y + h - 6)
    nvgStrokeColor(ctx, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
    nvgStrokeWidth(ctx, 1.3); nvgStroke(ctx)
end

function BattleHUD.Init(ctx, deps)
    BattleHUD.Shutdown()
    D = deps
    -- 像素字体由宿主一次注册；组件读数与菜单/模态保持同一种字体身份。
    state.font = "zpix"
    state.ready = true
    print("[BattleHUD] 组件仪表舱就绪，字体=" .. state.font .. "，共享宿主渲染/输入")
end

function BattleHUD.Shutdown()
    for _, root in pairs(roots) do root:Destroy() end
    roots, labels, bars = {}, {}, {}
    state.elapsed, state.ready = nil, false
    state.hp, state.hpTrail, state.damageHold = 1, 1, 0
    state.score, state.scorePop = 0, 0
end

-- 只有表现值缓动；数值标签永远读权威快照。菜单/重开清掉上一局掉血滞后段。
function BattleHUD.Update(game, dt)
    if not state.ready then return end
    local hp = math.max(0, math.min(1, (game.baseHp or 0) / math.max(1, game.maxBaseHp or 100)))
    local score = math.floor(game.score or 0)
    if state.elapsed == nil or game.elapsed < state.elapsed or game.state == "menu" then
        state.hp, state.hpTrail = hp, hp
        state.damageHold, state.scorePop = 0, 0
    else
        if hp < state.hp then state.damageHold = 0.32 end
        if hp >= state.hpTrail then state.hpTrail = hp end
        state.damageHold = math.max(0, state.damageHold - dt)
        if state.damageHold == 0 then
            state.hpTrail = math.max(hp, state.hpTrail - dt * 0.55)
        end
        if score > state.score then state.scorePop = 1 end
        state.scorePop = math.max(0, state.scorePop - dt * 3)
    end
    state.hp, state.score, state.elapsed = hp, score, game.elapsed
end

function BattleHUD.DrawHud(ctx, game, presentation, pauseRect)
    local C = D.C
    local phase = D.anim()
    local hpColor = state.hp > 0.35 and C.cyan or C.error
    local dim = C.dim
    -- 三块仪器独立分区，HUD 总高仍是92。底部经验带只占左栏。
    Rect(ctx, 0, 0, 540, 92, C.panel)
    Surface(ctx, 8, 3, 148, 84, C.cyan, false)
    Surface(ctx, 164, 3, 210, 84, C.cyan, false)
    Surface(ctx, 382, 3, 150, 84, hpColor, false)
    Line(ctx, 8, 91, 532, 91, Alpha(C.dim, 90))
    Line(ctx, 164, 91, 374, 91, Alpha(C.cyan, 120))
    local scoreSize = 28 + state.scorePop * 1.5
    Text(ctx, "hud", "score-label", "本局得分", 18, 5, 110, 20, 15, dim)
    Text(ctx, "hud", "score", tostring(math.floor(game.score or 0)), 18, 24, 128, 29, scoreSize, C.text)
    Text(ctx, "hud", "record-label", "最高", 18, 53, 32, 19, 15, dim)
    Text(ctx, "hud", "record", tostring(math.floor(game.highScore or 0)), 52, 53, 94, 19, 15, dim, "right")
    Text(ctx, "hud", "level", "Lv." .. tostring(math.floor(game.playerLevel or 1)), 18, 71, 56, 16, 15, C.text)
    Bar(ctx, "hud", "xp", 77, 77, 69, 5,
        (game.xp or 0) / math.max(1, game.xpToNext or 1), C.cyan)
    local cloud = presentation.cloudStatus
    Rect(ctx, 140, 12, 4, 4, cloud == "ok" and C.cyan or (cloud == "unavailable" and C.warn or C.dim), 2)
    Text(ctx, "hud", "stage", "第 " .. tostring(math.floor(game.stage or 1)) .. " 关", 176, 5, 140, 20, 15, dim)
    Text(ctx, "hud", "wave", tostring(math.floor(game.stageWave or game.wave or 1)) .. " / " .. tostring(math.floor(game.wavesPerStage or 10)),
        176, 25, 184, 29, 29, C.text, "center")
    Text(ctx, "hud", "enemies", "敌机 " .. tostring(math.floor(game.concurrentCount or 0)), 176, 58, 82, 20, 15, dim)
    local combo = math.floor(game.clearStreak or 0)
    Text(ctx, "hud", "combo", "连击 ×" .. tostring(combo), 264, 58, 96, 20, 15, combo >= 2 and C.warn or dim, "right")
    for i = 1, 10 do
        local done = i <= (game.stageWave or 1)
        Rect(ctx, 178 + (i - 1) * 18, 82, 13, 2, done and Alpha(C.cyan, 210) or Alpha(C.dim, 45))
    end
    Text(ctx, "hud", "hp-label", "基地耐久", 392, 5, 100, 20, 15, dim)
    Text(ctx, "hud", "hp", tostring(math.floor(game.baseHp or 0)) .. " / " .. tostring(math.floor(game.maxBaseHp or 100)),
        392, 26, 98, 25, 21, state.hp > 0.35 and C.text or C.error)
    Bar(ctx, "hud", "hp", 392, 55, 128, 8, state.hp, hpColor)
    Text(ctx, "hud", "parts-label", "零件", 392, 67, 32, 18, 15, C.warn)
    Text(ctx, "hud", "parts", tostring(math.floor(game.runParts or 0)), 426, 67, 94, 18, 15, C.warn, "right")
    Text(ctx, "hud", "boost", (game.partsBoostTime or 0) > 0 and "×2" or "", 492, 40, 28, 14, 15, C.ad, "right")
    Render("hud", ctx)
    -- 掉血段在真实生命条尾端短暂保留，绝不改生命读数。
    if state.hpTrail > state.hp + 0.002 then
        Rect(ctx, 392 + state.hp * 128, 55, (state.hpTrail - state.hp) * 128, 8, Alpha(C.warn, 180), 0)
    end
    if state.hp <= 0.35 then
        Line(ctx, 383, 85, 531, 85, Alpha(C.error, 100 + 90 * (0.5 + 0.5 * math.sin(phase * 6))), 2)
    end
    if game.state == "playing" then
        local glow, press = D.controlFx(pauseRect, true)
        Surface(ctx, pauseRect.x, pauseRect.y + press, pauseRect.w, pauseRect.h, C.cyan, glow > 0.1)
        local c = glow > 0.1 and C.cyan or C.text
        Rect(ctx, pauseRect.x + 8, pauseRect.y + 7 + press, 4, 14, c, 1)
        Rect(ctx, pauseRect.x + 16, pauseRect.y + 7 + press, 4, 14, c, 1)
    end
end

function BattleHUD.DrawAmmo(ctx, game, presentation)
    local C = D.C
    local counts = state.queue
    for key in pairs(counts) do counts[key] = nil end
    for _, kind in ipairs(game.ballQueue or {}) do counts[kind] = (counts[kind] or 0) + 1 end
    if game.activeBall then
        local kind = game.activeBall.ballType
        counts[kind] = (counts[kind] or 0) + 1
    end
    Rect(ctx, 0, 866, 540, 94, C.panel)
    Line(ctx, 0, 866, 540, 866, Alpha(C.dim, 95))
    -- 左右各一组，中央168宽只留给预告；不再用跨中区长说明与预告抢位置。
    local activeName = game.activeBall and D.slotNames[game.activeBall.ballType]
    Text(ctx, "dock", "title", activeName and (activeName .. " · 待发") or "弹药舱", 12, 866, 160, 23, 15, activeName and C.text or C.dim)
    Text(ctx, "dock", "hint", game.activeBall and "拖拽发射" or "等待回收", 384, 866, 144, 23, 15, C.dim, "right")
    for i, kind in ipairs(D.slotTypes) do
        local x = (i <= 2 and 10 or 396) + ((i - 1) % 2) * 70
        local color = D.slotColors[kind]
        local unlocked = game.unlockedBalls and game.unlockedBalls[kind] == true
        local selected = unlocked and game.activeBall and game.activeBall.ballType == kind
        Surface(ctx, x, 892, 64, 64, color, selected == true)
        Corner(ctx, x + 3, 895, 58, 58, Alpha(unlocked and color or C.dim, selected and 200 or 65))
        if selected then
            Rect(ctx, x + 4, 895, 2, 55, color, 1)
            local head = (D.anim() % 2.8) / 2.8
            -- 流动只走上边缘，不穿图标/名称；弹药槽是展示不是切换按钮。
            Line(ctx, x + 8, 893, x + 8 + head * 47, 893, Alpha(color, 220), 1.5)
        end
        Text(ctx, "dock", "index" .. i, tostring(i), x + 7, 895, 10, 15, 15, C.dim)
        Text(ctx, "dock", "count" .. i, unlocked and ("×" .. tostring(counts[kind] or 0)) or "锁",
            x + 28, 895, 29, 15, 15, unlocked and color or C.dim, "right")
        D.icon(ctx, ammoIcons[kind], x + 16, 909, 32, selected and 1 or (unlocked and 0.8 or 0.25))
        Text(ctx, "dock", "name" .. i, D.slotNames[kind], x + 4, 940, 56, 16, 15, unlocked and C.text or C.dim, "center")
    end
    Render("dock", ctx)
    -- 待发状态独立色签，不压图标与库存；保留主球回库的0.3秒边缘反馈。
    for i, kind in ipairs(D.slotTypes) do
        if game.activeBall and game.activeBall.ballType == kind then
            local x = (i <= 2 and 10 or 396) + ((i - 1) % 2) * 70
            Line(ctx, x + 9, 955, x + 55, 955, D.slotColors[kind], 2)
        end
    end
    local reload = math.max(0, math.min(1, (presentation.reloadFlash or 0) / 0.3))
    if reload > 0 then
        Line(ctx, 540 * (1 - reload), 866, 540, 866, Alpha(C.cyan, 210 * reload), 2)
    end
end

function BattleHUD.DrawPreview(ctx, game, preview, label)
    local plan = game.nextWave
    if not plan then return end
    local C = D.C
    local kind = plan.kind or "normal"
    local accent = kind == "boss" and C.error or (kind == "elite" and C.warn or C.cyan)
    local eta = math.max(0, math.ceil(game.waveCooldown or 0))
    Surface(ctx, 186, 870, 168, 86, accent, false)
    Text(ctx, "preview", "title", kind == "boss" and "首领预警" or (kind == "elite" and "精英预警" or "下一波"),
        194, 872, 100, 20, 15, accent)
    Text(ctx, "preview", "eta", tostring(eta) .. "秒", 294, 872, 52, 20, 15, C.text, "right")
    -- 扫描内胆和像素剪影使用规则预抽计划；扫描线仅在图形区，不扫文字。
    Rect(ctx, 194, 896, 152, 27, C.ink, 3)
    Corner(ctx, 199, 898, 142, 23, Alpha(accent, 70))
    if preview and preview.cells then
        local cell = math.max(1, math.floor(math.min(100 / preview.gridW, 23 / preview.gridH)))
        local ax = 270 - preview.gridW * cell * 0.5
        local ay = 909.5 - preview.gridH * cell * 0.5
        for _, p in ipairs(preview.cells) do
            Rect(ctx, ax + (p.col - 1) * cell, ay + (p.row - 1) * cell,
                cell - 0.3, cell - 0.3, { p.r, p.g, p.b, 255 })
        end
        local scanX = 200 + (D.anim() % 3.4) / 3.4 * 140
        Line(ctx, scanX, 899, scanX, 920, Alpha(accent, 90))
    end
    Text(ctx, "preview", "name", label, 194, 924, 99, 17, 15, C.text)
    Text(ctx, "preview", "count", kind == "boss" and "首领" or (kind == "elite" and "精英" or tostring(math.floor(plan.count or 0)) .. "架"),
        299, 924, 47, 17, 15, accent, "right")
    Text(ctx, "preview", "note", "自远方飞入", 194, 941, 152, 15, 15, C.dim, "center")
    Render("preview", ctx)
end

function BattleHUD.DrawItems(ctx, game, tab, slots, open)
    local C = D.C
    local total, grantable = 0, false
    for _, item in ipairs(game.items or {}) do
        if (item.charges or 0) > 0 then total = total + 1 end
        if item.canGrant then grantable = true end
    end
    local glow, press = D.controlFx(tab, true)
    Surface(ctx, tab.x, tab.y + press, tab.w, tab.h, C.cyan, glow > 0.1 or open)
    Text(ctx, "items", "toggle", open and "收起" or "道具", tab.x + 2, tab.y + 6, tab.w - 4, 24, 15,
        glow > 0.1 and C.cyan or C.text, "center")
    Text(ctx, "items", "badge", not open and total > 0 and tostring(total) or "",
        tab.x + tab.w - 14, tab.y, 14, 16, 15, C.ink, "center")
    if not open and total > 0 then Rect(ctx, tab.x + tab.w - 14, tab.y, 14, 16, C.cyan, 6) end
    if not open and total == 0 and grantable then Rect(ctx, tab.x + tab.w - 6, tab.y + 3, 5, 5, C.ad, 2) end
    for i, r in ipairs(slots) do
        local item = game.items and game.items[i]
        local nameLabel = labels["items:name" .. i]
        local countLabel = labels["items:count" .. i]
        if not open or not item then
            if nameLabel then nameLabel:SetVisible(false) end
            if countLabel then countLabel:SetVisible(false) end
        else
            local owned = (item.charges or 0) > 0
            local usable = owned and not item.usedThisRun
            local actionable = usable or (not owned and item.canGrant)
            local col = owned and (item.color or C.cyan) or (item.canGrant and C.ad or C.dim)
            local g, p = D.controlFx(r, actionable == true)
            Surface(ctx, r.x, r.y + p, r.w, r.h, col, g > 0.1 or usable == true)
            D.icon(ctx, item.key, r.x + 10, r.y + 3 + p, 32, usable and 1 or (owned and 0.42 or 0.25))
            Text(ctx, "items", "name" .. i, item.name or "", r.x + 2, r.y + 36, 32, 14, 15, owned and C.text or C.dim)
            Text(ctx, "items", "count" .. i, owned and ("×" .. tostring(math.floor(item.charges or 0))) or "",
                r.x + 34, r.y + 36, 16, 14, 15, col, "right")
            labels["items:name" .. i]:SetVisible(true)
            labels["items:count" .. i]:SetVisible(true)
            if not owned and item.canGrant then Rect(ctx, r.x + r.w - 8, r.y + 3, 5, 5, C.ad, 2) end
        end
    end
    Render("items", ctx)
end

function BattleHUD.DrawBoss(ctx, game, boss)
    local C = D.C
    local phase = math.max(1, math.min(3, boss.bossPhase or 1))
    local accent = phase == 2 and C.warn or C.error
    -- 240×66警报条，仍位于HUD下方中央，不与右上道具入口重叠。
    Surface(ctx, 150, 100, 240, 66, accent, false)
    Rect(ctx, 153, 108, 2, 49, accent, 1)
    Text(ctx, "boss", "title", "首领阶段", 162, 103, 110, 23, 16, C.text)
    Text(ctx, "boss", "phase", tostring(phase) .. " / 3", 286, 103, 90, 23, 16, accent, "right")
    for i = 1, 3 do
        Rect(ctx, 162 + (i - 1) * 73, 132, 66, 5, i <= phase and accent or Alpha(C.dim, 50), 1)
    end
    Text(ctx, "boss", "status", phase == 2 and "虚弱中 · 伤害 ×1.5" or "击碎装甲推进阶段",
        162, 142, 214, 20, 15, phase == 2 and C.warn or C.dim, "center")
    Render("boss", ctx)
end

return BattleHUD
