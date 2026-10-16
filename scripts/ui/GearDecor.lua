-- ui/GearDecor.lua
-- 界面装饰：互相咬合、大小不一的动态小齿轮（NanoVG 纯绘制）。
-- 无自有 ctx/字体/图片/命中，不依赖任何项目模块；由宿主在界面背景绘制之后调用，
-- 画在屏幕四角留白带，alpha 克制、不抢正文（装饰母题，wash/dim 色系）。
--
-- 咬合约定：
--   · 卫星齿轮中心距 = 主齿顶半径 + 0.82×卫星齿根半径 → 主齿探入卫星齿谷，视觉咬合；
--   · 卫星角速度 = -(主齿数/卫星齿数)×主角速度（反向、齿数比锁速）；
--   · 卫星相位 = 主相位×(-n主/n卫) + π/n卫 → 接触点对齐齿谷（半齿错相）。

local M = {}

local TAU = math.pi * 2

-- 齿轮轮廓路径：n 个方形齿（折线逼近，像素风）+ 齿根圆。rot 为整体旋转角。
---@param ctx any
---@param cx number
---@param cy number
---@param R number 齿顶半径
---@param teeth integer 齿数
---@param rot number 旋转角（弧度）
---@param toothH number 齿高
local function GearPath(ctx, cx, cy, R, teeth, rot, toothH)
    local rootR = R - toothH
    local step = TAU / teeth
    local valley = step * 0.5 -- 齿与齿谷各占半个弧段
    nvgBeginPath(ctx)
    for k = 0, teeth - 1 do
        local a0 = rot + k * step
        local a1 = a0 + step
        local ta0 = a0 + valley * 0.5
        local ta1 = a1 - valley * 0.5
        nvgLineTo(ctx, cx + math.cos(a0) * rootR, cy + math.sin(a0) * rootR)
        nvgLineTo(ctx, cx + math.cos(ta0) * R, cy + math.sin(ta0) * R)
        nvgLineTo(ctx, cx + math.cos(ta1) * R, cy + math.sin(ta1) * R)
        nvgLineTo(ctx, cx + math.cos(a1) * rootR, cy + math.sin(a1) * rootR)
    end
    nvgClosePath(ctx)
end

-- 单齿轮：外齿轮廓 + 轮缘 + 中心孔 + 三个螺栓孔（小齿轮省略螺栓孔）。
---@param ctx any
---@param cx number
---@param cy number
---@param R number 齿顶半径（设计像素）
---@param teeth integer 齿数
---@param rot number 旋转角（弧度）
---@param rgb integer[] 颜色（r,g,b）
---@param alpha number 描边不透明度 0..255
function M.DrawGear(ctx, cx, cy, R, teeth, rot, rgb, alpha)
    if R < 2 then return end
    local a = math.max(0, math.min(255, alpha or 64))
    local toothH = math.max(1.5, R * 0.2)
    local rootR = R - toothH
    nvgSave(ctx)
    nvgShapeAntiAlias(ctx, 0)
    GearPath(ctx, cx, cy, R, teeth, rot, toothH)
    nvgFillColor(ctx, nvgRGBA(rgb[1], rgb[2], rgb[3], math.floor(a * 0.22)))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(rgb[1], rgb[2], rgb[3], math.floor(a)))
    nvgStrokeWidth(ctx, 1.2)
    nvgStroke(ctx)

    -- 轮缘内圈
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, rootR)
    nvgStrokeColor(ctx, nvgRGBA(rgb[1], rgb[2], rgb[3], math.floor(a * 0.7)))
    nvgStroke(ctx)

    -- 螺栓孔（随转动，加强"动态"读感）
    if R >= 11 then
        for k = 1, 3 do
            local ba = rot * 0.6 + k * TAU / 3
            nvgBeginPath(ctx)
            nvgCircle(ctx, cx + math.cos(ba) * rootR * 0.6,
                cy + math.sin(ba) * rootR * 0.6, math.max(1, R * 0.07))
            nvgFillColor(ctx, nvgRGBA(rgb[1], rgb[2], rgb[3], math.floor(a * 0.4)))
            nvgFill(ctx)
        end
    end

    -- 中心孔
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, math.max(1.5, R * 0.22))
    nvgFillColor(ctx, nvgRGBA(rgb[1], rgb[2], rgb[3], math.floor(a * 0.5)))
    nvgFill(ctx)
    nvgRestore(ctx)
end

-- 咬合齿轮簇：主齿轮 + 两个不同尺寸的卫星齿轮（反向锁速、齿谷对齐）。
---@param ctx any
---@param cx number 主齿轮圆心 x
---@param cy number 主齿轮圆心 y
---@param R number 主齿轮齿顶半径
---@param t number 动画时钟（秒）
---@param seed integer 确定性变体种子（决定卫星方位/齿数）
---@param a1 number 卫星 1 方位角（弧度，屏幕坐标，y 向下）
---@param a2 number 卫星 2 方位角
---@param rgb integer[] 主色
---@param rgb2 integer[] 卫星色
---@param alpha number 主齿轮描边不透明度
function M.Cluster(ctx, cx, cy, R, t, seed, a1, a2, rgb, rgb2, alpha)
    local n = 12 + (seed % 3) * 2 -- 主齿数 12/14/16
    local n1 = 9 - (seed % 3)     -- 卫星 1 齿数 7/8/9
    local n2 = 8 + (seed % 2) * 2 -- 卫星 2 齿数 8/10
    local r1 = R * 0.62
    local r2 = R * 0.42
    local speed = 0.32 + (seed % 5) * 0.05
    local rot = t * speed

    local d1 = R + r1 * 0.82
    local d2 = R + r2 * 0.82
    local rot1 = -rot * n / n1 + math.pi / n1
    local rot2 = -rot * n / n2 + math.pi / n2

    M.DrawGear(ctx, cx + math.cos(a1) * d1, cy + math.sin(a1) * d1,
        r1, n1, rot1, rgb2, alpha * 0.8)
    M.DrawGear(ctx, cx + math.cos(a2) * d2, cy + math.sin(a2) * d2,
        r2, n2, rot2, rgb2, alpha * 0.66)
    M.DrawGear(ctx, cx, cy, R, n, rot, rgb, alpha)
end

-- 屏幕四角齿轮装饰：每角一簇，主齿轮半出画面（"机构从边框后探出"），
-- 尺寸/齿数/转速随角标确定性变化；全部落在模态壳外留白带，不压正文。
---@param ctx any
---@param w number 设计宽度
---@param t number 动画时钟（秒）
---@param wash integer[] 主色（氛围青）
---@param dim integer[] 卫星色（暗蓝灰）
function M.Corners(ctx, w, t, wash, dim)
    -- 左下角（屏幕坐标 y 向下：内侧=右上方）
    M.Cluster(ctx, 0, 960, 17, t, 1, math.pi * 1.6, math.pi * 1.9, wash, dim, 60)
    -- 右下角（内侧=左上方）
    M.Cluster(ctx, w, 960, 20, t, 2, math.pi * 1.4, math.pi * 1.1, dim, wash, 58)
    -- 左上角（内侧=右下方）
    M.Cluster(ctx, 0, 0, 16, t, 3, math.pi * 0.1, math.pi * 0.4, dim, wash, 56)
    -- 右上角（内侧=左下方）
    M.Cluster(ctx, w, 0, 19, t, 4, math.pi * 0.9, math.pi * 0.6, wash, dim, 62)
end

-- 上下边缘中点齿轮（模态壳外留白带的中点，卫星朝屏幕内侧展开）。
---@param ctx any
---@param w number
---@param t number
---@param wash integer[]
---@param dim integer[]
function M.EdgePair(ctx, w, t, wash, dim)
    -- 顶部中点（内侧=下方）
    M.Cluster(ctx, w * 0.5, 0, 13, t, 8, math.pi * 0.35, math.pi * 0.65, dim, wash, 54)
    -- 底部中点（内侧=上方）
    M.Cluster(ctx, w * 0.5, 960, 14, t, 9, math.pi * 1.35, math.pi * 1.65, wash, dim, 56)
end

-- 战斗内模态窗（暂停/升级/胜负）：只画底部两角——顶部是 HUD 信息带不压齿轮。
---@param ctx any
---@param w number
---@param t number
---@param wash integer[]
---@param dim integer[]
function M.BattleCorners(ctx, w, t, wash, dim)
    M.Cluster(ctx, 0, 960, 17, t, 10, math.pi * 1.6, math.pi * 1.9, wash, dim, 58)
    M.Cluster(ctx, w, 960, 20, t, 11, math.pi * 1.4, math.pi * 1.1, dim, wash, 56)
end

-- 结算页顶部两簇（窗口上方 92..216 留白带，HUD 信息带之下；窗口起点 y=216）。
---@param ctx any
---@param w number
---@param t number
---@param wash integer[]
---@param dim integer[]
function M.TopBandPair(ctx, w, t, wash, dim)
    M.Cluster(ctx, 0, 140, 14, t, 14, math.pi * 0.1, math.pi * 0.4, wash, dim, 52)
    M.Cluster(ctx, w, 140, 15, t, 15, math.pi * 0.9, math.pi * 0.6, dim, wash, 50)
end

-- 战斗 HUD：左右墙体中段各一簇（错开高度、指向场内），极低透明度不抢焦点。
---@param ctx any
---@param w number
---@param t number
---@param wash integer[]
---@param dim integer[]
function M.HudSides(ctx, w, t, wash, dim)
    M.Cluster(ctx, 0, 330, 12, t, 16, math.pi * 0.15, math.pi * -0.15, wash, dim, 38)
    M.Cluster(ctx, w, 640, 13, t, 17, math.pi * 0.85, math.pi * 1.15, dim, wash, 36)
end

-- 首页菜单底部四分之一处两簇（菜单卡行之上、屏幕下缘留白带；中央是版本文字让开）。
---@param ctx any
---@param w number
---@param t number
---@param wash integer[]
---@param dim integer[]
function M.MenuCenterBottom(ctx, w, t, wash, dim)
    M.Cluster(ctx, w * 0.25, 960, 11, t, 12, math.pi * 1.35, math.pi * 1.65, wash, dim, 54)
    M.Cluster(ctx, w * 0.75, 960, 12, t, 13, math.pi * 1.35, math.pi * 1.65, dim, wash, 52)
end

-- 首页菜单专用：左上角被设置按钮占据，只画另外三角。
---@param ctx any
---@param w number
---@param t number
---@param wash integer[]
---@param dim integer[]
function M.MenuCorners(ctx, w, t, wash, dim)
    M.Cluster(ctx, 0, 960, 17, t, 5, math.pi * 1.6, math.pi * 1.9, wash, dim, 60)
    M.Cluster(ctx, w, 960, 20, t, 6, math.pi * 1.4, math.pi * 1.1, dim, wash, 58)
    M.Cluster(ctx, w, 0, 18, t, 7, math.pi * 0.9, math.pi * 0.6, wash, dim, 62)
end

return M
