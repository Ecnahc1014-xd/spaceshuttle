-- network/Client.lua
-- 客户端网络层：只做三件事——
--   ① 连上后上报 ready、拉一次氪金代币（钻石）余额；
--   ② 接收服务端推来的余额，转交给 UI；
--   ③ 把「花钻石」的请求转给服务端（扣款权威在服务端，客户端只申请）。
--
-- ⚠️ 这里不碰玩法、不碰排行榜、不碰成就：那些仍然走 clientCloud / 本地存档。
-- ⚠️ 离线（GameMode.IsOffline()）时全部短路，UI 只看最后一次已知余额。

local Shared = require("network.Shared")
local GameMode = require "GameMode"

local Client = {}

local GEMS = Shared.CURRENCY.GEMS

local gems_ = 0                 -- 最后一次从服务端同步到的钻石余额
local premiumPass_ = false      -- 服务端权威的付费档案轨标志
local firstGiftBought_ = false  -- 服务端权威的「新手礼包已购」标志
local ready_ = false            -- 是否已向服务端报到
local seq_ = 0
local spendPending_ = false
local spendElapsed_ = 0
local SPEND_TIMEOUT = 30
local balanceRetryElapsed_ = 0
local balanceRetryPending_ = false
local BALANCE_RETRY_INTERVAL = 3
---@type table<integer, fun(ok: boolean, reason: string)>
local spendWaiters_ = {}
---@type fun(gems: integer)|nil
local gemsListener_ = nil
---@type fun(total: integer, premium: boolean, firstGift: boolean)|nil
local purchasedPartsListener_ = nil
---@type fun(ok: boolean)|nil
local purchaseListener_ = nil

-- ============================================================================
-- 对外读取
-- ============================================================================

---@return integer
function Client.GetGems()
    return gems_
end

--- 服务端权威的付费档案轨标志（离线时保持最后一次已知值）。
---@return boolean
function Client.GetPremiumPass()
    return premiumPass_
end

--- 服务端权威的「新手礼包已购」标志。
---@return boolean
function Client.GetFirstGiftBought()
    return firstGiftBought_
end

---@return boolean
function Client.IsReady()
    return ready_
end

---@return boolean 网络能力是否可用（离线时为 false）
function Client.Available()
    return not GameMode.IsOffline()
end

-- 余额变化回调（UI 用）。传 nil 取消。
---@param fn fun(gems: integer)|nil
function Client.SetGemsListener(fn)
    gemsListener_ = fn
    if fn then fn(gems_) end
end

---@param fn fun(total: integer, premium: boolean)|nil
function Client.SetPurchasedPartsListener(fn)
    purchasedPartsListener_ = fn
end

---@param fn fun(ok: boolean)|nil
function Client.SetPurchaseListener(fn)
    purchaseListener_ = fn
end

-- ============================================================================
-- 工具
-- ============================================================================

---@return any|nil
local function ServerConnection()
    local ok, conn = pcall(function()
        return network:GetServerConnection()
    end)
    if ok and conn then return conn end
    return nil
end

---@param eventData any
---@return integer
local function ReadGems(eventData)
    local ok, value = pcall(function()
        return eventData:GetInt("gems")
    end)
    if ok and type(value) == "number" then return math.floor(value) end
    return 0
end

---@param gems integer
local function ApplyGems(gems)
    if gems == gems_ then return end
    gems_ = gems
    print("[Client] gems synced: " .. tostring(gems_))
    if gemsListener_ then gemsListener_(gems_) end
end

-- ============================================================================
-- 发送
-- ============================================================================

---@param eventType string
local function Send(eventType)
    local conn = ServerConnection()
    if not conn then
        if eventType == Shared.EVENTS.REQUEST_BALANCE then
            balanceRetryPending_ = true
            balanceRetryElapsed_ = 0
        end
        print("[Client] no server connection, defer " .. eventType)
        return false
    end
    conn:SendRemoteEvent(eventType, true)
    return true
end

-- 向服务端报到并拉一次余额。
function Client.RequestBalance()
    if not Client.Available() then return end
    balanceRetryPending_ = false
    balanceRetryElapsed_ = 0
    Send(Shared.EVENTS.REQUEST_BALANCE)
end

-- 花钻石：服务端权威扣款，成功后才由调用方发本地奖励。
---@param key string
---@param cb fun(ok: boolean, reason: string)|nil
function Client.SpendGems(key, cb)
    if not Client.Available() then
        if cb then cb(false, "offline") end
        return
    end
    if spendPending_ then
        if cb then cb(false, "pending") end
        return
    end
    local conn = ServerConnection()
    if not conn then
        if cb then cb(false, "no_connection") end
        return
    end
    seq_ = seq_ + 1
    local requestId = seq_
    spendWaiters_[requestId] = cb
    spendPending_ = true
    spendElapsed_ = 0
    local data = VariantMap()
    data["key"] = Variant(key)
    data["requestId"] = Variant(requestId)
    conn:SendRemoteEvent(Shared.EVENTS.GEM_SPEND, true, data)
end

function Client.Update(dt)
    if balanceRetryPending_ and Client.Available() then
        balanceRetryElapsed_ = balanceRetryElapsed_ + math.max(0, dt or 0)
        if balanceRetryElapsed_ >= BALANCE_RETRY_INTERVAL then
            Client.RequestBalance()
        end
    end
    if not spendPending_ or spendElapsed_ >= SPEND_TIMEOUT then return end
    spendElapsed_ = spendElapsed_ + dt
    if spendElapsed_ < SPEND_TIMEOUT then return end
    print("[Client] gem spend response timed out; outcome unknown, refresh balance")
    Client.RequestBalance()
    local waiter = spendWaiters_[seq_]
    spendWaiters_[seq_] = nil
    if waiter then waiter(false, "unknown") end
    -- 结果未知不能自动重发或开放再次兑换；只能等待本次结果或重新进游戏后对账。
end

-- ============================================================================
-- 充值（走 urhox-libs/Shop，商品与发货由服务端 / MCP 配置管理）
-- ============================================================================

---@return table|nil 商品列表；nil 表示 IAP 未开通或离线
function Client.GetProducts()
    if not Client.Available() then return nil end
    local ok, Shop = pcall(function()
        return require "urhox-libs/Shop"
    end)
    if not ok or not Shop or not Shop.getProducts then
        print("[Client] Shop module unavailable on this platform")
        return nil
    end
    local okCall, products = pcall(function()
        return Shop.getProducts()
    end)
    if not okCall then
        print("[Client] Shop.getProducts failed")
        return nil
    end
    return products --[[@as table|nil]]
end

---@param sku string
---@param cb fun(ok: boolean, reason: string)|nil
function Client.Purchase(sku, cb)
    if not Client.Available() then
        if cb then cb(false, "offline") end
        return
    end
    local ok, Shop = pcall(function()
        return require "urhox-libs/Shop"
    end)
    if not ok or not Shop or not Shop.purchase then
        if cb then cb(false, "platform_not_supported") end
        return
    end
    Shop.purchase(sku, function(result)
        -- result.ok == true 只代表支付弹窗已拉起，发货由服务端异步完成。
        local okPurchase = result and result.ok == true
        local reason = ""
        if not okPurchase and result then
            reason = tostring(result.error or result.message or "")
        end
        if purchaseListener_ then purchaseListener_(okPurchase) end
        if cb then cb(okPurchase, reason) end
    end)
end

-- ============================================================================
-- 事件
-- ============================================================================

---@param eventType string
---@param eventData any
function HandleIapBalanceSync(eventType, eventData)
    ApplyGems(ReadGems(eventData))
end

---@param eventType string
---@param eventData any
function HandleIapBalanceDirty(eventType, eventData)
    -- 服务端已发货：再拉一次最新余额。
    print("[Client] balance dirty, re-request")
    Client.RequestBalance()
end

function HandleIapPurchasedPartsSync(eventType, eventData)
    local okPre, premium = pcall(function() return eventData:GetInt("premium") end)
    premiumPass_ = okPre and premium == 1
    local okGift, gift = pcall(function() return eventData:GetInt("first_gift") end)
    firstGiftBought_ = okGift and gift == 1
    if purchasedPartsListener_ then
        purchasedPartsListener_(eventData:GetInt("total"), premiumPass_, firstGiftBought_)
    end
end

---@param eventType string
---@param eventData any
function HandleIapSpendResult(eventType, eventData)
    local requestId = eventData:GetInt("requestId")
    local success = eventData:GetInt("success") == 1
    local reason = eventData:GetString("reason")
    local waiter = spendWaiters_[requestId]
    spendWaiters_[requestId] = nil
    if requestId ~= seq_ or not spendPending_ then return end
    spendPending_ = false
    spendElapsed_ = 0
    if waiter then waiter(success, reason or "") end
end

-- ============================================================================
-- 生命周期
-- ============================================================================

function Client.Start()
    if GameMode.IsOffline() then
        print("[Client] offline mode, network layer idle")
        return
    end
    print("[Client] network layer starting")

    network:RegisterRemoteEvent(Shared.EVENTS.BALANCE_SYNC)
    network:RegisterRemoteEvent(Shared.EVENTS.BALANCE_DIRTY)
    network:RegisterRemoteEvent(Shared.EVENTS.SPEND_RESULT)
    network:RegisterRemoteEvent(Shared.EVENTS.PURCHASED_PARTS_SYNC)

    SubscribeToEvent(Shared.EVENTS.BALANCE_SYNC, HandleIapBalanceSync)
    SubscribeToEvent(Shared.EVENTS.BALANCE_DIRTY, HandleIapBalanceDirty)
    SubscribeToEvent(Shared.EVENTS.SPEND_RESULT, HandleIapSpendResult)
    SubscribeToEvent(Shared.EVENTS.PURCHASED_PARTS_SYNC, HandleIapPurchasedPartsSync)

    -- 报到：服务端收到后推一次余额。
    Client.RequestBalance()
    ready_ = true
end

function Client.Stop()
    print("[Client] network layer stopping")
    UnsubscribeFromEvent(Shared.EVENTS.BALANCE_SYNC)
    UnsubscribeFromEvent(Shared.EVENTS.BALANCE_DIRTY)
    UnsubscribeFromEvent(Shared.EVENTS.SPEND_RESULT)
    UnsubscribeFromEvent(Shared.EVENTS.PURCHASED_PARTS_SYNC)
    ready_ = false
    spendWaiters_ = {}
    spendPending_ = false
    spendElapsed_ = 0
    balanceRetryElapsed_ = 0
    balanceRetryPending_ = false
end

return Client
