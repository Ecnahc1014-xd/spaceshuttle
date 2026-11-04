-- 发射方式选择：沿用 BattleHUD 的组件子树与宿主设计坐标，不注册第二套事件。
local UI = require "urhox-libs/UI"
local LaunchMode = {}
local D = {}
---@type Panel?
local root = nil
---@type table<string, Label>
local labels = {}

function LaunchMode.Shutdown()
    if root then root:Destroy() end
    root, labels = nil, {}
end

function LaunchMode.Init(deps)
    LaunchMode.Shutdown()
    D = deps
end

local function Text(id, text, x, y, w, h, size, color)
    if not root then
        root = UI.Panel { width = 540, height = 960, pointerEvents = "none",
            backgroundColor = {0, 0, 0, 0}, borderWidth = 0 }
        root.absoluteLayout = { x = 0, y = 0, w = 540, h = 960 }
    end
    local label = labels[id]
    if not label then
        label = UI.Label { text = text, fontFamily = "zpix",
            fontSize = size / UI.Theme.FontSize(1), lineHeight = 1,
            pointerEvents = "none", backgroundColor = {0, 0, 0, 0}, borderWidth = 0 }
        labels[id] = label
        root:AddChild(label)
    end
    label.absoluteLayout = { x = x, y = y, w = w, h = h }
    label:SetText(text)
    label:SetFontColor(color)
end

function LaunchMode.Layout(w)
    return { x = 48, y = 318, w = w - 96, h = 124 },
        { x = 48, y = 462, w = w - 96, h = 124 },
        { x = 180, y = 666, w = w - 360, h = 48 }
end

function LaunchMode.Draw(ctx, w, meta)
    local C = D.C
    D.backdrop(ctx, 0, 0, w, 960)
    D.shell(ctx, 30, 218, w - 60, 526, 48)
    Text("title", "选择发射方式", 50, 230, w - 100, 36, 27, C.text)
    Text("intro", "两种方式均可长按蓄力，松手发射", 50, 282, w - 100, 26, 17, C.dim)
    local direct, reverse, close = LaunchMode.Layout(w)
    for i, option in ipairs({
        { mode = "direct", rect = direct, title = "点击松手发射",
            help = "按住目标位置瞄准，松手向该处发射", caution = "容易上手，但手指会遮挡视野" },
        { mode = "reverse", rect = reverse, title = "反向拖动发射",
            help = "向目标的反方向拖动，松手发射", caution = "视野更开阔，但较难上手，需要适应" },
    }) do
        local r = option.rect
        local selected = meta.launchModeChosen and meta.launchMode == option.mode
        local glow = D.controlFx(r, true)
        D.panel(ctx, r.x, r.y, r.w, r.h, C.card,
            (selected or glow > 0.01) and C.cyan or C.rail, 8)
        local id = tostring(i)
        Text(id .. "title", option.title, r.x + 18, r.y + 14, r.w - 100, 30, 23, C.text)
        Text(id .. "selected", selected and "当前" or "选择", r.x + r.w - 64, r.y + 18, 50, 24, 16, C.cyan)
        Text(id .. "help", option.help, r.x + 18, r.y + 55, r.w - 36, 24, 16, C.dim)
        Text(id .. "caution", option.caution, r.x + 18, r.y + 88, r.w - 36, 24, 16, C.warn)
    end
    Text("footer", "以后可在设置或暂停菜单中随时调整", 50, 610, w - 100, 26, 17, C.dim)
    if meta.launchModeChosen then
        D.panel(ctx, close.x, close.y, close.w, close.h, C.card, C.cyanDim, 6)
    end
    Text("close", meta.launchModeChosen and "返回" or "请选择一种方式继续",
        meta.launchModeChosen and close.x + 62 or 158, 676, 260, 30, 18, C.text)
    UI.RenderWidgetSubtree(root, ctx)
end

function LaunchMode.HitTest(x, y, w, meta)
    local direct, reverse, close = LaunchMode.Layout(w)
    local function inside(r)
        return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
    end
    if inside(direct) then return "launch_mode_direct" end
    if inside(reverse) then return "launch_mode_reverse" end
    if meta.launchModeChosen and inside(close) then return "launch_mode_close" end
end

return LaunchMode
