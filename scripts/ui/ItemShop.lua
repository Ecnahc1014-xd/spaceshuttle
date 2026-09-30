-- ui/ItemShop.lua
-- 选关界面内的「局内道具」购买条（v0.13.13）。
--
-- 玩家花零件买永久库存；进局时由编排层把库存注入 Game.SetItemStock。
-- ⚠️ 每种道具**每局最多使用一次**——这条规则只在规则层（Game.CanUseItem /
--    itemUsedThisRun）与局内槽位的「变暗 + 角标」上表达，界面上不写文字说明。
--
-- 本模块只提供：价格表 + 购买动作（扣零件、加库存）。绘制与命中在 StageSelect 里。

local PlayerData = require "PlayerData"

local ItemShop = {}

-- 道具 key → 零件单价。key 与 Game.ITEM_DEFS 一致。
ItemShop.PRICES = {
    bomb = 120,
    freeze = 100,
    shield = 100,
}

-- 购买上限：库存再多也没意义（每局每样只能用 1 次），封顶避免囤积。
ItemShop.MAX_STOCK = 3

---@param key string
---@return integer
function ItemShop.GetPrice(key)
    return ItemShop.PRICES[key] or 0
end

---@param key string
---@return boolean affordable
---@return boolean atCap
function ItemShop.CanBuy(key)
    local price = ItemShop.GetPrice(key)
    if price <= 0 then return false, false end
    local atCap = PlayerData.GetItemCount(key) >= ItemShop.MAX_STOCK
    if atCap then return false, true end
    return PlayerData.GetParts() >= price, false
end

-- 扣零件 → 加库存。返回是否成功。
---@param key string
---@return boolean ok
function ItemShop.Buy(key)
    local price = ItemShop.GetPrice(key)
    if price <= 0 then return false end
    if PlayerData.GetItemCount(key) >= ItemShop.MAX_STOCK then return false end
    if not PlayerData.SpendParts(price) then return false end
    PlayerData.AddItem(key, 1)
    print("[ItemShop] bought " .. key .. " for " .. price
        .. " parts, stock=" .. tostring(PlayerData.GetItemCount(key)))
    return true
end

return ItemShop
