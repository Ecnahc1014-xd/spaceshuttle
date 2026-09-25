-- network/Shared.lua
-- 客户端与服务端共用的协议：远程事件名、货币 key、钻石消费点。
-- ⚠️ 两端必须 require 同一份，禁止各自硬编码字符串。

local Shared = {}

-- ============================================================================
-- 远程事件
-- ============================================================================

Shared.EVENTS = {
    -- C→S：连上后登记，服推一次余额
    CLIENT_READY    = "IAPClientReady",
    -- C→S：进商店/进游戏再拉一次
    REQUEST_BALANCE = "IAPRequestBalance",
    -- S→C：{ gems: number }
    BALANCE_SYNC    = "IAPBalanceSync",
    -- S→C：发货成功，客户端再请求一次
    BALANCE_DIRTY   = "IAPBalanceDirty",
    -- C→S：请求扣钻石（服务端权威）
    GEM_SPEND       = "IAPGemSpend",
    -- S→C：扣款结果
    SPEND_RESULT    = "IAPGemSpendResult",
}

-- ============================================================================
-- 货币
-- ============================================================================

Shared.CURRENCY = {
    -- 氪金代币：唯一由服务端权威持有的货币（serverCloud.money）
    GEMS = "gems",
}

-- ============================================================================
-- 钻石消费点
-- 服务端按同一份价格表校验，客户端只用于展示。
-- ============================================================================

---@class GemSpendDef
---@field key string
---@field name string
---@field cost integer 钻石价格
---@field grantKey string 发往本地的软货币（parts）
---@field grantAmount integer

---@type GemSpendDef[]
Shared.GEM_SPENDS = {
    { key = "parts_500",  name = "500 零件",  cost = 20, grantKey = "parts", grantAmount = 500 },
    { key = "parts_1500", name = "1500 零件", cost = 50, grantKey = "parts", grantAmount = 1500 },
}

---@param key string
---@return GemSpendDef|nil
function Shared.GetGemSpend(key)
    for _, def in ipairs(Shared.GEM_SPENDS) do
        if def.key == key then return def end
    end
    return nil
end

-- ============================================================================
-- 商品（本地兜底目录）
-- 真实商品列表以 maker_iap_shop.json 为准（Shop.getProducts()）；
-- 这里只用于「商店入口是否展示」「离线文案」等不需要联网的场景。
-- ⚠️ sku_id 必须与 iap:create_sandbox_product 的 merchant_sku_id 完全一致。
-- ============================================================================

---@class GemPackDef
---@field sku string
---@field name string
---@field gems integer

---@type GemPackDef[]
Shared.GEM_PACKS = {
    { sku = "gem_pack_60",   name = "钻石 ×60",   gems = 60 },
    { sku = "gem_pack_180",  name = "钻石 ×180",  gems = 180 },
    { sku = "gem_pack_480",  name = "钻石 ×480",  gems = 480 },
    { sku = "gem_pack_1280", name = "钻石 ×1280", gems = 1280 },
}

-- ============================================================================
-- 大厅
-- ============================================================================

Shared.LOBBY = {
    MATCH_TIMEOUT_SEC = 5,   -- 超时即降级本地玩
}

return Shared
