-- network/Server.lua
-- headless 服务端：**只负责 IAP 发货与氪金代币（钻石）余额**。
--
-- ⚠️ 本文件运行在服务端，禁止 require 任何渲染 / HUD / 商店 UI / 玩法模块。
-- ⚠️ 本作是「单机间接联机」：服务端不跑战斗、不做场景复制、不模拟敌人。
--    战斗、排行榜、养成存档仍然由客户端（clientCloud + 本地玩法）负责。
--
-- 服务端权威数据：serverCloud.money 里的 gems 与已兑换零件累计额。

local Shared = require("network.Shared")

local Server = {}

local GEMS = Shared.CURRENCY.GEMS
local PURCHASED_PARTS = Shared.CURRENCY.PURCHASED_PARTS
local PREMIUM_PASS = Shared.CURRENCY.PREMIUM_PASS
local FIRST_GIFT = Shared.CURRENCY.FIRST_GIFT

-- 服务端专属全局：由 C++ 侧在服务端脚本环境注入，客户端不存在。
-- 通过 _G 取用，避免「客户端也会打包本文件」时的静态检查报未定义全局。
---@return table|nil
local function ServerShop()
    local g = _G --[[@as table]]
    return g.Shop
end

---@return integer
local function MaxPlayers()
    local g = _G --[[@as table]]
    return math.floor(tonumber(g.SERVER_MAX_PLAYERS) or 0)
end

---@return integer
local function RegisteredPlayers()
    local g = _G --[[@as table]]
    return math.floor(tonumber(g.SERVER_REGISTERED_PLAYERS) or 0)
end

---@return integer
local function TickRate()
    local g = _G --[[@as table]]
    return math.floor(tonumber(g.SERVER_TICK_RATE) or 0)
end

-- ============================================================================
-- 工具
-- ============================================================================

-- 从事件里取发送者连接（Connection 是引用计数对象，取出后即可安全持有）。
---@param eventData any
---@return any|nil
local function SenderConnection(eventData)
    local ok, conn = pcall(function()
        return eventData["Connection"]:GetPtr("Connection")
    end)
    if ok and conn then return conn end
    return nil
end

---@param conn any
---@param gems integer
local function PushBalance(conn, gems)
    if not conn or not conn:IsConnected() then return end
    local data = VariantMap()
    data["gems"] = Variant(math.floor(gems))
    conn:SendRemoteEvent(Shared.EVENTS.BALANCE_SYNC, true, data)
end

-- 余额查询失败时不推送伪造的零余额；客户端保留上一次已知值。
---@param userId number
---@param conn any|nil
local function QueryAndPushBalance(userId, conn)
    serverCloud.money:Get(userId, {
        ok = function(moneys)
            local gems = 0
            local purchasedParts = 0
            local premiumPass = 0
            local firstGift = 0
            if moneys then
                gems = moneys[GEMS] or 0
                purchasedParts = moneys[PURCHASED_PARTS] or 0
                premiumPass = moneys[PREMIUM_PASS] or 0
                firstGift = moneys[FIRST_GIFT] or 0
            end
            print("[Server] balance userId=" .. tostring(userId) .. " gems=" .. tostring(gems)
                .. " purchased_parts=" .. tostring(purchasedParts)
                .. " premium_pass=" .. tostring(premiumPass)
                .. " first_gift=" .. tostring(firstGift))
            PushBalance(conn, gems)
            if conn and conn:IsConnected() then
                local data = VariantMap()
                data["total"] = Variant(math.floor(purchasedParts))
                data["premium"] = Variant(premiumPass >= 1 and 1 or 0)
                data["first_gift"] = Variant(firstGift >= 1 and 1 or 0)
                conn:SendRemoteEvent(Shared.EVENTS.PURCHASED_PARTS_SYNC, true, data)
            end
        end,
        error = function(code, reason)
            print("[Server] balance query failed userId=" .. tostring(userId)
                .. " code=" .. tostring(code) .. " reason=" .. tostring(reason))
        end,
    })
end

-- ============================================================================
-- IAP 发货
-- ============================================================================

---@param ctx table Shop.onDeliver 上下文
local function Deliver(ctx)
    -- ctx 在回调返回后可能被回收，先把需要的字段取出来。
    local orderId = ctx.orderId
    local userId = ctx.userId
    local conn = ctx.conn
    local productJson = ctx.productJson

    local okDecode, product = pcall(cjson.decode, productJson or "")
    if not okDecode then
        print("[Server] delivery decode failed, orderId=" .. tostring(orderId))
        return
    end

    local deliveryTable = product --[[@as table]]
    local items = deliveryTable.delivery or {}
    print("[Server] deliver orderId=" .. tostring(orderId)
        .. " userId=" .. tostring(userId) .. " product=" .. tostring(ctx.productId))

    -- 必须走 serverCloud 事务 + orderId，保证幂等、不重复到账、离线也补发。
    local batch = serverCloud:BatchCommit("IAP 发货: " .. tostring(ctx.productId))
    for _, item in ipairs(items) do
        local entry = item --[[@as table]]
        if entry.key and entry.amount then
            batch:MoneyAdd(userId, entry.key, entry.amount)
        end
    end

    batch:Commit({ orderId = orderId }, {
        ok = function()
            print("[Server] delivery ok orderId=" .. tostring(orderId))
            -- 通知该客户端刷新余额；玩家已离线时 conn 为 nil，跳过推送即可，
            -- 下次连上会通过 IAPClientReady 拉到最新余额。
            if conn and conn:IsConnected() then
                local data = VariantMap()
                data["reason"] = Variant("deliver")
                conn:SendRemoteEvent(Shared.EVENTS.BALANCE_DIRTY, true, data)
            end
        end,
        err = function(code, msg)
            -- 失败时订单仍是待发货状态，下次登录会再触发 onDeliver 自动补发。
            print("[Server] delivery failed orderId=" .. tostring(orderId)
                .. " code=" .. tostring(code) .. " msg=" .. tostring(msg))
        end,
    })
end

-- ============================================================================
-- 远程事件
-- ============================================================================

---@param eventType string
---@param eventData any
function HandleIapClientReady(eventType, eventData)
    local conn = SenderConnection(eventData)
    if not conn then return end
    local identity = conn.identity
    if not identity or not identity["user_id"] then
        print("[Server] client ready without identity, skip")
        return
    end
    local userId = identity["user_id"]:GetInt64()
    QueryAndPushBalance(userId, conn)
end

-- 客户端请求扣钻石（氪金代币的唯一权威扣款点）。
---@param eventType string
---@param eventData any
function HandleIapGemSpend(eventType, eventData)
    local conn = SenderConnection(eventData)
    if not conn then return end
    local identity = conn.identity
    if not identity or not identity["user_id"] then return end
    local userId = identity["user_id"]:GetInt64()

    local key = eventData:GetString("key")
    local requestId = eventData:GetInt("requestId")
    local def = Shared.GetGemSpend(key)

    local function reply(success, reason, cost)
        if not conn or not conn:IsConnected() then return end
        local data = VariantMap()
        data["key"] = Variant(key)
        data["requestId"] = Variant(requestId)
        data["success"] = Variant(success and 1 or 0)
        data["reason"] = Variant(reason or "")
        data["cost"] = Variant(cost or 0)
        conn:SendRemoteEvent(Shared.EVENTS.SPEND_RESULT, true, data)
    end

    if not def then
        reply(false, "unknown_sku", 0)
        return
    end

    -- 一次性商品（如付费档案轨）：已持有标志时直接拒绝，避免重复扣钻。
    if def.grantCurrency == PREMIUM_PASS then
        serverCloud.money:Get(userId, {
            ok = function(moneys)
                if moneys and (moneys[PREMIUM_PASS] or 0) >= 1 then
                    reply(false, "already_owned", def.cost)
                    QueryAndPushBalance(userId, conn)
                    return
                end
                local batch = serverCloud:BatchCommit("钻石兑换: " .. def.key)
                batch:MoneyCost(userId, GEMS, def.cost)
                batch:MoneyAdd(userId, PREMIUM_PASS, 1)
                batch:Commit({
                    ok = function()
                        print("[Server] premium pass unlocked userId=" .. tostring(userId))
                        reply(true, "", def.cost)
                        QueryAndPushBalance(userId, conn)
                    end,
                    error = function(code, reason)
                        print("[Server] premium pass spend failed code=" .. tostring(code)
                            .. " reason=" .. tostring(reason))
                        reply(false, "failed", def.cost)
                        QueryAndPushBalance(userId, conn)
                    end,
                })
            end,
            error = function(code, reason)
                print("[Server] premium pass precheck failed code=" .. tostring(code)
                    .. " reason=" .. tostring(reason))
                reply(false, "failed", def.cost)
            end,
        })
        return
    end

    local batch = serverCloud:BatchCommit("钻石兑换: " .. def.key)
    batch:MoneyCost(userId, GEMS, def.cost)
    batch:MoneyAdd(userId, PURCHASED_PARTS, def.grantAmount)
    batch:Commit({
        ok = function()
            print("[Server] gem spend ok userId=" .. tostring(userId)
                .. " key=" .. key .. " cost=" .. tostring(def.cost))
            reply(true, "", def.cost)
            QueryAndPushBalance(userId, conn)
        end,
        error = function(code, reason)
            print("[Server] gem spend failed userId=" .. tostring(userId)
                .. " key=" .. key .. " code=" .. tostring(code) .. " reason=" .. tostring(reason))
            reply(false, "failed", def.cost)
            QueryAndPushBalance(userId, conn)
        end,
    })
end

-- ============================================================================
-- 生命周期
-- ============================================================================

function Server.Start()
    print("[Server] single-player-adjacent authority server booting")
    print("  max players: " .. tostring(MaxPlayers())
        .. ", registered: " .. tostring(RegisteredPlayers())
        .. ", tick: " .. tostring(TickRate()))
    print("[Server] role: IAP delivery + gems balance only (no combat simulation)")

    network:RegisterRemoteEvent(Shared.EVENTS.CLIENT_READY)
    network:RegisterRemoteEvent(Shared.EVENTS.REQUEST_BALANCE)
    network:RegisterRemoteEvent(Shared.EVENTS.GEM_SPEND)
    network:RegisterRemoteEvent(Shared.EVENTS.PURCHASED_PARTS_SYNC)

    SubscribeToEvent(Shared.EVENTS.CLIENT_READY, HandleIapClientReady)
    SubscribeToEvent(Shared.EVENTS.REQUEST_BALANCE, HandleIapClientReady)
    SubscribeToEvent(Shared.EVENTS.GEM_SPEND, HandleIapGemSpend)

    -- 发货入口：幂等、离线补发都由 orderId + serverCloud 事务保证。
    local shop = ServerShop()
    if shop and shop.onDeliver then
        shop.onDeliver(Deliver)
        print("[Server] Shop.onDeliver registered")
    else
        print("[Server] WARNING: Shop global unavailable, IAP delivery disabled")
    end
end

function Server.Stop()
    print("[Server] stop")
end

return Server
