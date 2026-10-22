# 货车大战飞机：Client 与 Server 混用实现方法

## 1. 总体分工

| 数据 | 运行时内存 | 本地存档 | clientCloud | serverCloud / Server |
|---|---:|---:|---:|---:|
| 战斗中的球、敌人、波次 | ✅ | 结束时可记录结果 | ❌ | ❌ |
| 零件、皮肤、关卡、任务、成就 | 使用中 | ✅ 主存储 | ✅ 跨设备备份 | ❌ |
| 最高分 | 使用中 | ✅ | ✅ 排行榜/备份 | ❌ |
| 钻石 | 显示缓存 | ❌ | ❌ | ✅ 唯一权威 |
| 支付发货、购买幂等 | ❌ | ❌ | ❌ | ✅ |

## 2. 入口和运行模式

`scripts/main.lua` 使用 `IsServerMode()` 分流：

```lua
function Start()
    if IsServerMode() then
        Module = require "network.Server"
    else
        Module = require "game.client_main"
    end
    Module.Start()
end
```

- **client**：运行玩法、UI、输入、本地存档、`clientCloud` 和钻石网络客户端。
- **server**：不加载玩法和 UI，只运行 `network/Server.lua`，处理支付发货、钻石余额和钻石消费。
- `.project/settings.json` 中 `multiplayer.enabled = true`，客户端由 `lobby_runtime.lua` 负责匹配；匹配失败后继续本地玩法。

## 3. Client 侧实现

### 3.1 本地存档

`scripts/PlayerData.lua` 负责普通玩家进度：

```lua
PlayerData.Load()
PlayerData.Save()
local payload = PlayerData.ExportForCloud()
PlayerData.ImportFromCloud(payload)
```

每次成功保存都会写入递增的 `updatedAt`，用于比较本地档案和服务端云档的新旧。

### 3.2 普通数据与 `clientCloud`

`scripts/game/client_main.lua` 启动后读取 `clientCloud` 的 `player_meta`。

同步策略：

1. 服务端云档 `updatedAt` 大于本地：导入服务端档案并保存本地。
2. 本地时间较新或相同：保留本地，并上传 `clientCloud:Set("player_meta", payload)`。
3. 云端没有档案：上传本地档案。
4. 同步失败：继续使用本地档案，不弹窗、不暂停游戏。

最高分可使用 `clientCloud:SetInt("high_score", score)` 和 `Get`，读取失败时保留本地最高分。

### 3.3 钻石只走 Server

客户端不直接修改钻石。`scripts/network/Client.lua` 只发送请求：

```lua
Client.RequestBalance()
Client.SpendGems(key, cb)
Client.Purchase(sku, cb)
```

客户端只缓存最近一次服务端推送的余额。断线时普通数据继续使用本地存档，钻石余额请求后台每 3 秒重试；不弹重连界面，不暂停、重启或切换游戏进程。钻石扣除不会自动重复发送，超时按未知结果处理，等待下一次余额查询对账。

## 4. Server 侧实现

`scripts/network/Server.lua` 只处理服务端权威业务。

### 4.1 读取和推送钻石

```lua
serverCloud.money:Get(userId, {
    ok = function(moneys)
        PushBalance(conn, moneys.gems or 0)
    end,
})
```

Server 查询 `serverCloud.money` 后推送 `IAPBalanceSync`、`IAPPurchasedPartsSync`。

### 4.2 钻石消费事务

客户端发送 `IAPGemSpend`，Server 校验商品 key 后使用原子事务：

```lua
local batch = serverCloud:BatchCommit("钻石兑换: " .. def.key)
batch:MoneyCost(userId, GEMS, def.cost)
batch:MoneyAdd(userId, PURCHASED_PARTS, def.grantAmount)
batch:Commit({
    ok = function() ... end,
    error = function(code, reason) ... end,
})
```

成功后 Server 返回 `IAPGemSpendResult` 并推送新余额。

### 4.3 支付发货

`Shop.onDeliver` 使用订单号和 `serverCloud:BatchCommit()` 发货。玩家离线时订单仍可补发；下次连接由客户端再次请求余额和购买累计值。

## 5. 完整流程

```text
启动
  -> client 加载 PlayerData 本地档案
  -> 读取 clientCloud.player_meta
  -> 比较 updatedAt，较新者合并，较旧者被覆盖备份
  -> Client.RequestBalance()
  -> Server 查询 serverCloud.money
  -> 推送 gems / purchased_parts / premium 标志

游戏中获得零件
  -> 修改内存 PlayerData
  -> PlayerData.Save() 写本地
  -> 后台 clientCloud.Set() 备份

购买/钻石兑换
  -> client 发起请求
  -> serverCloud 原子扣钻并发放结果
  -> Server 推送结果和新余额
  -> client 根据服务端累计值补领本地奖励
```

## 6. 边界规则

1. 客户端不能直接增加或扣除钻石。
2. 旧的 `clientCloud` 数据不能无条件覆盖本地存档。
3. 战斗临时状态不写入 Server；本项目 Server 不运行战斗模拟。
4. 普通数据同步失败时继续本地运行。
5. 必须重连时只后台自动尝试，不显示打断玩家的界面。
6. `serverCloud` 只在 Server 运行；`clientCloud` 只在 Client 运行。

## 7. 关键文件

- `scripts/main.lua`：client/server 入口分流。
- `scripts/game/client_main.lua`：客户端玩法、普通云存档、钻石 UI 编排。
- `scripts/PlayerData.lua`：本地存档、`updatedAt`、云档编解码。
- `scripts/network/Client.lua`：客户端钻石协议和后台余额重试。
- `scripts/network/Server.lua`：服务端余额、支付、钻石消费事务。
- `scripts/network/Shared.lua`：双方共用的远程事件和商品定义。
- `scripts/lobby_runtime.lua`：匹配、连接失败后的本地降级。
