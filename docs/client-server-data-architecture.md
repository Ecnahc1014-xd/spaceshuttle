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

同步策略（**整档按 `updatedAt` 比较，不做逐字段取最大值**）：

1. 云端云档 `updatedAt` 更新（且本地无未同步改动）：**经济组整组替换为云档**，单调统计取较大值。
2. 本地时间较新、或本地有未同步改动（`dirty`）：保留本地经济组，只补齐云端独有的单调统计，然后回传。
3. 云端没有档案：上传本地档案。
4. 同步失败：继续使用本地档案，不弹窗、不暂停游戏；**后台每 5 秒重试，最多 12 次**。

#### 权威分工（四组）

| 组 | 字段 | 合并方式 | 理由 |
|---|---|---|---|
| 经济组 | `parts` `totalParts` `totalSpent` `talents` `skins` `trails` `shopBought` `codex` `passClaimed` `piggyBank` `piggyClaimed` `firstGiftClaimed` `itemStock` `signIn*` `daily*` | **整组 LWW** | 与零件发放/消费耦合。逐字段取 max 会造钱：两台设备各花 1000 解锁不同天赋，消费取 max=1000、解锁取并集=两个 → 付一份钱拿两份 |
| 单调统计 | `highScore` `stageStars` `maxStage` `stats.*` `achProgress` `achUnlocked` `achPushed` | 取较大值 / 并集 | 不产出货币，多拿只是进度 |
| 本机偏好 | `musicEnabled` `sfxEnabled` `selectedSkin` `selectedTrail` | 保留本机 | 设备级偏好，云覆盖会导致「换设备音量就变」 |
| 服务端镜像 | `purchasedPartsClaimed` `createdAt` | 只前进不回退 | 跟随 serverCloud 累计值单调前进 |

> ⚠️ 「皮肤/拖尾」的**解锁**属于经济组（LWW），而**当前选用**属于本机偏好（组 3）。
> 选用项若在合并后不再已解锁，会回落为 `default` / `classic`。

#### 旧档迁移

升级前写出的存档没有 `updatedAt`。首次与云端比对时走一次性兼容合并（各经济字段取对玩家更有利的一侧），保住老玩家数据后写入时间戳，此后全面转入 LWW。

#### 本地存档可靠性

- **原子写**：先写 `.tmp` → 校验存在 → 旧主档转 `.bak` → `.tmp` 改名为正式档；任一步失败都保留原主档，绝不产生半截 JSON。
- **损坏回退**：`Load()` 主档解码失败时自动回退 `.bak`，不会整档归零。
- **落盘时机**：`InputFocus` 失焦、退出、关键结算后均调用 `ClientMain.FlushSave()`。

最高分可使用 `clientCloud:SetInt("high_score", score)` 和 `Get`，读取失败时保留本地最高分。

### 3.3 钻石只走 Server

客户端不直接修改钻石。`scripts/network/Client.lua` 只发送请求：

```lua
Client.RequestBalance()
Client.SpendGems(key, cb)
Client.Purchase(sku, cb)
```

客户端只缓存最近一次服务端推送的余额。断线时普通数据继续使用本地存档，钻石余额请求后台每 3 秒重试；不弹重连界面，不暂停、重启或切换游戏进程。钻石扣除不会自动重复发送，超时按未知结果处理，等待下一次余额查询对账。

### 3.4 引擎 API 适配要点

以下三点已对着当前引擎（`.emmylua/` 类型定义）核对，写新代码时必须遵守：

| 项目 | 约束 |
|---|---|
| **回调字段名** | 所有云变量回调表只有 `ok` / `error` / `timeout` 三个字段（`ScoreEvents`）。写成 `err` 会让失败分支永不触发，异常彻底静默 |
| **`serverCloudCommit:Commit` 签名** | `Commit(events)` 只接受一个事件表参数，**没有 options 参数**。幂等由平台侧 `Shop.onDeliver` 保证，不要试图往 Commit 塞 `orderId` |
| **`File:WriteString` 会追加 `\x00`** | `WriteString` 是 Urho3D 的字符串序列化语义，落盘恒多 1 字节 NUL。存档用 `WriteTextExact`（`VectorBuffer:WriteUByte` 逐字节 → `File:Write`）精确写入，1KB 约 0.4ms。读回用 `File:ReadString` 即可（读到 NUL 停） |

> 实测环境：`UrhoXRuntime ... -tool_mode`，FileSystem 的 `Rename` / `Delete` / `FileExists` 在沙箱内均可用且行为符合预期（覆盖式 Rename 可用），原子写方案成立。

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
  -> PlayerData.Save() 原子写本地（.tmp -> .bak -> 主档）
  -> 后台 clientCloud.Set() 备份
  -> 成功后 MarkCloudSynced() 清脏标记并推进 updatedAt

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
