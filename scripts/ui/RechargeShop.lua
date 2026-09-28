-- ui/RechargeShop.lua
-- 充值 / 钻石商店弹层（NanoVG）。
--
-- ⚠️ UI 无污染：本弹层沿用游戏自己的 dark-tech 令牌与 NanoVG 原语，
--    不引入 urhox-libs/UI 控件树、不改绘制坐标系。
-- ⚠️ 本模块只画与命中，不做任何网络/存档副作用；购买与兑换由编排层发起。

local Shared = require "network.Shared"

local RechargeShop = {}

-- 依赖注入：由 MetaUI 在 Init 后转发，保证与游戏 UI 同一套令牌/字体。
---@type table|nil
local D = nil

---@param deps table 与 MetaUI.Init 相同的依赖表
function RechargeShop.Init(deps)
    D = deps
end

---@return table
local function Style()
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

---@class RechargeLayout
---@field content table
---@field close table
---@field packs table[] 钻石礼包卡
---@field spends table[] 钻石兑换卡
---@field firstGift table|nil 首充礼包卡（限时窗内未购买时存在）
---@field retry table 重新拉取

---@param w number
---@param showFirstGift boolean|nil 限时窗内未首购时展示礼包行（Draw/HitTest 同参调用）
---@return RechargeLayout
local function GetLayout(w, showFirstGift)
    local x, y = 18, 108
    local sw, sh = w - 36, 780
    local content = { x = x + 14, y = y + 60, w = sw - 28, h = sh - 76 }
    local close = { x = x + sw - 46, y = y + 8, w = 36, h = 36 }
    -- 首充礼包占一行，展示时其余分区整体下移；Draw 与 HitTest 传同一个开关保证几何同源。
    local firstGift = nil
    local shift = 0
    if showFirstGift then
        firstGift = { x = content.x, y = content.y + 4, w = content.w, h = 58 }
        shift = 68
    end

    local colW = math.floor((content.w - 12) * 0.5)
    local packs = {}
    local packTop = content.y + 66 + shift
    for i = 1, 4 do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        packs[i] = {
            x = content.x + col * (colW + 12),
            y = packTop + row * 104,
            w = colW,
            h = 92,
        }
    end
    local spendTop = packTop + 2 * 104 + 44
    local spends = {}
    for i = 1, #Shared.GEM_SPENDS do
        spends[i] = {
            x = content.x,
            y = spendTop + (i - 1) * 76,
            w = content.w,
            h = 64,
        }
    end
    local retry = { x = content.x, y = content.y + content.h - 52, w = content.w, h = 44 }
    return { content = content, close = close, packs = packs, spends = spends,
        firstGift = firstGift, retry = retry }
end

-- ============================================================================
-- 绘制
-- ============================================================================

---@param ctx any
---@param w number
---@param meta MetaState
function RechargeShop.Draw(ctx, w, meta)
    local C = Style()
    local showGift = meta.firstGiftAvailable == true
    local L = GetLayout(w, showGift)

    D.backdrop(ctx, 0, 92, w, 960 - 92)
    D.shell(ctx, 18, 108, w - 36, 780, 48)
    D.rect(ctx, 18, 156, 3, 22, C.warn, 0)
    D.text(ctx, 34, 118, "钻石商店", 22, C.warn)
    D.text(ctx, L.content.x + L.content.w - 44, 122,
        string.format("余额 %d", meta.gems or 0), 15, C.warn,
        NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    D.stroke(ctx, L.close.x, L.close.y, L.close.w, L.close.h, C.cyanDim, 6, 1.2)
    D.text(ctx, L.close.x + L.close.w * 0.5, L.close.y + 7, "X", 20, C.dim,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    D.grid(ctx, 32, 164, w - 64, 20, 12, 14)

    -- 首充新手礼包（限时窗内未首购展示；金色＝钻石付费系）
    if showGift then
        local r = L.firstGift
        D.panel(ctx, r.x, r.y, r.w, r.h, C.card, C.warnDim, 6)
        D.rect(ctx, r.x, r.y, 3, r.h, C.warn, 0)
        D.text(ctx, r.x + 16, r.y + 8, "限时新手礼包", 19, C.warn)
        D.text(ctx, r.x + 16, r.y + 33,
            string.format("高级零件×%d 稀有皮肤×1 钻石×%d",
                Shared.FIRST_GIFT.parts, Shared.FIRST_GIFT.bonusGems), 14, C.dim)
        local secs = math.max(0, math.floor(meta.firstGiftSeconds or 0))
        D.text(ctx, r.x + r.w - 150, r.y + 8,
            string.format("限时 %02d:%02d:%02d", secs // 3600, (secs % 3600) // 60, secs % 60),
            15, C.warn, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
        local price = meta.firstGiftPrice
        local btn = { x = r.x + r.w - 128, y = r.y + 26, w = 112, h = 26 }
        if price ~= nil then
            D.rect(ctx, btn.x, btn.y, btn.w, btn.h, C.warn, 6)
            D.text(ctx, btn.x + btn.w * 0.5, btn.y + 4, "¥" .. tostring(price) .. " 立即购买", 15,
                C.ink, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        else
            D.rect(ctx, btn.x, btn.y, btn.w, btn.h, C.widget, 6)
            D.text(ctx, btn.x + btn.w * 0.5, btn.y + 4,
                meta.offline and "需联网" or "暂未开通", 14, C.dim,
                NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        end
    end

    D.text(ctx, L.content.x + 4, L.packs[1].y - 20, "钻石礼包", 18, C.warn)
    if meta.offline then
        D.text(ctx, L.content.x + L.content.w, L.packs[1].y - 16, "需联网", 15, C.dim,
            NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    elseif not meta.productsAvailable then
        D.text(ctx, L.content.x + L.content.w, L.packs[1].y - 16, "内购未开通", 15, C.dim,
            NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    end

    for i = 1, #L.packs do
        local r = L.packs[i]
        local def = Shared.GEM_PACKS[i]
        D.panel(ctx, r.x, r.y, r.w, r.h, C.card, C.warnDim, 6)
        D.text(ctx, r.x + 14, r.y + 12, def.name, 20, C.text)
        local price = meta.prices and meta.prices[def.sku]
        local canBuy = (not meta.offline) and meta.productsAvailable and price ~= nil
        D.text(ctx, r.x + 14, r.y + 44,
            meta.offline and "需联网" or (canBuy and ("¥" .. tostring(price)) or "暂未开通"),
            17, canBuy and C.warn or C.dim)
        local btn = { x = r.x + r.w - 92, y = r.y + r.h - 44, w = 78, h = 32 }
        if canBuy then
            D.rect(ctx, btn.x, btn.y, btn.w, btn.h, C.warn, 6)
            D.text(ctx, btn.x + btn.w * 0.5, btn.y + 7, "购买", 16, C.ink,
                NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        else
            D.rect(ctx, btn.x, btn.y, btn.w, btn.h, C.widget, 6)
            D.stroke(ctx, btn.x, btn.y, btn.w, btn.h, C.cyanDim, 6, 1)
            D.text(ctx, btn.x + btn.w * 0.5, btn.y + 7, "不可用", 15, C.dim,
                NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        end
    end

    D.text(ctx, L.content.x + 4, L.spends[1].y - 34, "钻石兑换", 18, C.warn)
    for i, r in ipairs(L.spends) do
        local def = Shared.GEM_SPENDS[i]
        local affordable = (not meta.offline) and (meta.gems or 0) >= def.cost
        D.panel(ctx, r.x, r.y, r.w, r.h, C.card, affordable and C.cyanDim or C.widget, 6)
        D.text(ctx, r.x + 16, r.y + 10, def.name, 18,
            affordable and C.text or C.dim)
        D.text(ctx, r.x + 16, r.y + 36,
            meta.offline and "需联网" or string.format("消耗 %d 钻石", def.cost), 15, C.dim)
        local btn = { x = r.x + r.w - 132, y = r.y + 12, w = 116, h = 40 }
        if meta.offline then
            D.rect(ctx, btn.x, btn.y, btn.w, btn.h, C.widget, 6)
            D.stroke(ctx, btn.x, btn.y, btn.w, btn.h, C.cyanDim, 6, 1)
            D.text(ctx, btn.x + btn.w * 0.5, btn.y + 10, "需联网", 16, C.dim,
                NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        elseif affordable then
            D.rect(ctx, btn.x, btn.y, btn.w, btn.h, C.cyan, 6)
            D.text(ctx, btn.x + btn.w * 0.5, btn.y + 10, "兑换", 17, C.ink,
                NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        else
            D.rect(ctx, btn.x, btn.y, btn.w, btn.h, C.widget, 6)
            D.stroke(ctx, btn.x, btn.y, btn.w, btn.h, C.cyanDim, 6, 1)
            D.text(ctx, btn.x + btn.w * 0.5, btn.y + 10, "钻石不足", 15, C.dim,
                NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        end
    end

    local tip = meta.rechargeToast or "钻石由服务端权威记账，卸载重装不丢失"
    D.text(ctx, L.content.x + L.content.w * 0.5, L.retry.y - 22, tip, 14, C.dim,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    D.stroke(ctx, L.retry.x, L.retry.y, L.retry.w, L.retry.h, C.cyanDim, 6, 1)
    D.text(ctx, L.retry.x + L.retry.w * 0.5, L.retry.y + 11,
        meta.offline and "重试联机" or "刷新余额与商品", 16, C.text,
        NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
end

-- ============================================================================
-- 命中
-- ============================================================================

---@return string|nil action "close" | "buy" | "spend" | "retry" | "buy_first_gift"
---@return integer|nil index
function RechargeShop.HitTest(uiX, uiY, w, meta)
    local L = GetLayout(w, meta.firstGiftAvailable == true)
    if Inside(L.close, uiX, uiY) then return "close", nil end
    if Inside(L.retry, uiX, uiY) then return "retry", nil end
    if L.firstGift and meta.firstGiftPrice ~= nil then
        local r = L.firstGift
        local btn = { x = r.x + r.w - 128, y = r.y + 26, w = 112, h = 26 }
        if Inside(btn, uiX, uiY) then return "buy_first_gift", nil end
    end
    for i = 1, #L.packs do
        local r = L.packs[i]
        local btn = { x = r.x + r.w - 92, y = r.y + r.h - 44, w = 78, h = 32 }
        local def = Shared.GEM_PACKS[i]
        if Inside(btn, uiX, uiY) and not meta.offline
            and meta.productsAvailable and meta.prices and meta.prices[def.sku] then
            return "buy", i
        end
    end
    for i, r in ipairs(L.spends) do
        local btn = { x = r.x + r.w - 132, y = r.y + 12, w = 116, h = 40 }
        if Inside(btn, uiX, uiY) and not meta.offline
            and (meta.gems or 0) >= Shared.GEM_SPENDS[i].cost then
            return "spend", i
        end
    end
    if Inside(L.content, uiX, uiY) then return nil, nil end
    return "close", nil
end

return RechargeShop
