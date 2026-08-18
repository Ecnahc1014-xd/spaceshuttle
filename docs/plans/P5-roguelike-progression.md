# P5 · 肉鸽成长与升级池模块开发计划书

> 版本：v0.9.0 规划 / 草稿 v1
> 模块方向：经验系统、等级、三选一升级池、局内强化、成长曲线
> 目标读者：负责 `Game.lua` 幸存者成长链路与 UI 升级卡片的开发者

---

## 一、模块目标

本模块是「肉鸽幸存者化」的核心循环中枢。v0.9.0 已实装：击碎砖块 +1 XP、清编队 +8 XP（含连击加成）、跨级累计 `pendingLevelUps` 并冻结经验、升级时 `RollUpgradeChoices` 从 `UPGRADE_POOL` 抽 3 项、`apply()` 只改 `BALL_TUNING`/`baseHp`、`Game.PickUpgrade(i)` 恢复 `playing`、UI 三选一卡片通过 `GetSnapshot().upgradeChoices` 暴露。本计划书规划**成长系统的深度与可扩展性**，并固化「升级效果只改规则变量、不进渲染层」的硬约束（AB-027）。

核心不变量（CLAUDE.md 避雷清单）：
- 幸存者核心契约：`Game` 用 `gameState="levelup"/"paused"` 暂停玩法，升级由 `Game.PickUpgrade(i)` 恢复 `playing`，**禁止在规则层直接调用渲染或输入 API**。
- 经验与升级契约：升级池 `apply()` 只修改 `BALL_TUNING`/`baseHp` 等规则变量，必须通过 `GetSnapshot().upgradeChoices` 暴露给 UI 三选一，**禁止硬编码升级效果到渲染层**。
- 波次节奏契约（P6 协同）：`pendingLevelUps>0` 时暂停刷怪，禁止恢复「清场才出下一波」离散波次。

---

## 二、现状与系统深度缺口

### 2.1 已达标项
- `UPGRADE_POOL` 8 项：damage / giant / split / speed / ice / repair / armor / xp。
- `GainXp` 冻结机制 + `pendingLevelUps` 队列（一次升多级不丢）。
- `RollUpgradeChoices` 抽 3、去重、`PickUpgrade` 应用并出队。
- 快照暴露 `playerLevel, xp, xpToNext, pendingLevelUps, upgradeChoices, upgradePicks, clearStreak`。

### 2.2 深度缺口
1. **抽卡无权重/无保底**：`RollUpgradeChoices` 均匀随机，后期「xp/regen」类已无意义却仍占卡位；缺「已选过的稀有项降权、核心项保底」机制。
2. **升级项无等级上限与叠加衰减**：`damage` 可无限选，后期数值爆炸；缺「每项最高叠层数」与「边际递减」。
3. **缺少「负面/抉择」维度**：纯正向三选一缺乏肉鸽的「取舍张力」，可加入「高风险高回报」或「条件强化」（如「下次清编队 XP 翻倍但 brickDmg +1」）。
4. **升级与波次强耦合**：升级时完全停刷，长时间升级卡顿感（P6 协同：应允许升级期间已有编队继续但不再新刷）。
5. **升级效果不可观测**：UI 卡片只显示名称/描述，缺「当前数值 → 升级后数值」的预览差值。

---

## 三、架构切面

成长链路全在 `Game.lua` 规则层。`UPGRADE_POOL` 每项 `apply()` 只写 `BALL_TUNING`/`baseHp`/`playerLevel` 等规则变量。`RollUpgradeChoices` 在被 `GainXp` 触发时运行（仍属规则层）。UI（`Scene3DBackend.DrawLevelUp`）只读 `upgradeChoices`，点击经 `main.lua` 调 `Game.PickUpgrade`。本模块**不新增渲染 API 调用**（AB-027）。

文件改动：`scripts/Game.lua`（主，UPGRADE_POOL/RollUpgradeChoices/GainXp/GetSnapshot）、`scripts/Scene3DBackend.lua`（卡片预览差值，最小只读）、`scripts/main.lua`（点击映射，最小）。

---

## 四、具体任务清单

### T1：抽卡权重与保底
`UPGRADE_POOL` 每项加 `weight`（默认 1）与 `rarity`（`common`/`rare`/`epic`）。`RollUpgradeChoices` 按权重抽 3 项；若连续 N 次未出 `rare+`，第 N+1 次强制保底至少 1 个 `rare`。`repair`/`xp` 类后期 `weight` 随 `playerLevel` 衰减（避免意义耗尽项占卡）。

### T2：叠加上限与边际递减
每项加 `maxStacks`（如 damage=8、giant=3、split=5）。`apply()` 检查 `upgradePicks[id]` 达上限则不再出现在候选；数值增量改为 `base * (1 - 0.08*stacks)` 的边际递减，防止后期爆炸（数值细节归 P1 的 `BALANCE` 管理）。

### T3：抉择型升级（高风险）
新增 2~3 项 `tradeoff` 类：如 `glass_cannon`（damage+2 但 brickDmg+1）、`overclock`（speedMul+0.15 但 baseHp-8）。`apply()` 同时改正向与负向规则变量，均在 `BALL_TUNING`/`baseHp`（仍属规则层，AB-027 允许改 baseHp）。

### T4：升级期间非阻塞
`pendingLevelUps>0` 时，玩法 tick 暂停（保持 v0.9.0 契约），但允许「已存在的编队继续下移并显示逼近危险线」作为背景压迫（仅视觉/规则可暂停判定，不刷新怪）。由 P6 的 `UpdateWaveLogic` 在 `pendingLevelUps>0` 跳过 spawn 但保留既有 `enemy.y += vy`。

### T5：卡片数值预览
`GetSnapshot().upgradeChoices` 每项附带 `delta` 文本（如 `伤害 1→2`），`Scene3DBackend.DrawLevelUp` 只读展示；不新增规则计算到渲染层。

### T6：升级音效/反馈钩子
`PickUpgrade` 成功时由 `Presentation` 维护 `upgradeApplied` 瞬时状态（复用 Emit 机制），供 P10 音效与 P2 特效消费；`Game` 不直调渲染。

---

## 五、风险与避雷

- **禁止渲染层硬编码成长**：任何 `damageBonus`/`brickDmg`/`baseHp` 的修改必须在 `Game`；`Scene3DBackend` 只读 `upgradeChoices`（AB-027 / 经验与升级契约）。
- **禁止规则层调渲染/输入**：`GainXp`/`PickUpgrade` 不得 `SubscribeToEvent` 渲染、`Emit` 到 UI 直绘；暂停/恢复仅靠 `gameState`（幸存者核心契约）。
- **波次协同**：T4 不得破坏「清场才出下一波」已否定的契约，仍连续涌出（波次节奏契约）。
- **Lua 作用域**：`UPGRADE_POOL` 闭包引用 `BALL_TUNING`/`baseHp`/`GainXp`/`RollUpgradeChoices` 必须声明在 pool 之上（v0.9.0 bug 修复经验），新增字段同理。
- **PRNG 隔离**：抽卡用 `Game` 既有 Park-Miller，不得 `math.random`（AB-002）。

---

## 六、验收标准

1. 抽卡体现权重与保底，后期无意义项降权（T1）。
2. 每项有叠加上限，连选不爆炸，数值边际递减（T2）。
3. 抉择型升级同时改正负规则变量，仍在 `BALL_TUNING`/`baseHp`（T3，AB-027）。
4. 升级期间既有编队继续逼近危险线，未新刷怪（T4，波次节奏契约）。
5. 卡片显示当前→升级后数值预览，渲染层无规则计算（T5）。
6. LSP 0 Error + 官方构建通过；`Game` 升级链路无渲染/输入 API 调用断言通过。

---

## 七、后续迭代建议

- 与 P1（数值）协同：T2 递减系数、T1 衰减曲线写入 `BALANCE`，由 P1 统一管理。
- 与 P6（波次）协同：T4 的非阻塞升级需 P6 的 spawn 守卫配合 `pendingLevelUps` 检查。
- 与 P8（UI）协同：T5 预览差值由 `Scene3DBackend.DrawLevelUp` 呈现，需遵守 UI 视觉契约（深紫/淡蓝工程风，AB-017）。
- 与 P10（音效）协同：T6 钩子驱动升级音效，触发在 `Presentation`。


## 八、实施里程碑排期

- **M1（权重保底，1 周期）**：完成 T1，抽卡按 `weight`/`rarity`，稀有保底。Gate：后期无意义项降权。
- **M2（叠加衰减，1 周期）**：完成 T2，`maxStacks` + 边际递减。Gate：连选不爆炸。
- **M3（抉择升级，1 周期）**：完成 T3，`tradeoff` 类同时改正负规则变量。Gate：仍在 `BALL_TUNING`/`baseHp`。
- **M4（预览与非阻塞，1 周期）**：完成 T4/T5，升级期间既有编队继续、卡片显 delta。Gate：未新刷怪，UI 无规则计算。

## 九、回滚与降级预案

若 `tradeoff` 负向过强导致劝退：调 `glass_cannon` 的 `brickDmg+1` 为 `+0.5`（规则变量，P1 收敛）。若保底破坏随机感：降保底触发回合 `N`。所有 `apply()` 必须只写 `BALL_TUNING`/`baseHp`/`playerLevel`，回滚即删该项；`RollUpgradeChoices` 回归均匀随机即可恢复 v0.9.0 行为。`GainXp`/`PickUpgrade` 不得新增渲染/输入调用（幸存者核心契约）。

## 十、关键伪代码参考

```lua
local UPGRADE_POOL = {
  damage = { weight=1, rarity="common", maxStacks=8,
    apply = function() BALL_TUNING.damageBonus = BALL_TUNING.damageBonus + 1 end },
  glass_cannon = { weight=0.6, rarity="rare", maxStacks=3, tradeoff=true,
    apply = function() BALL_TUNING.damageBonus = BALL_TUNING.damageBonus + 2; BASE_HP_CUR = BASE_HP_CUR - 8 end },
}
```
注意 `apply` 闭包引用的 `BALL_TUNING`/`BASE_HP_CUR` 必须声明在 `UPGRADE_POOL` 之上（v0.9.0 Lua 作用域 bug 修复经验），否则运行期解析为全局 nil。


## 附录 A · 跨模块接口契约

- `Game`（成长）→ `Scene3DBackend`：升级卡只读 `upgradeChoices`，含 `delta` 字段（本模块 T5 提供）。
- `Game` → P1：`apply` 边际递减系数若进 `BALANCE`，由 P1 管理，本模块只读。
- `Game` → P6：升级期间 `pendingLevelUps>0`，P6 spawn 守卫跳过（非阻塞升级协同）。
- `Game` → P10：`upgradeApplied` 钩子供音效，触发在 `Presentation`。

## 附录 B · 验收用例清单

| 用例 | 步骤 | 期望 |
|------|------|------|
| 抽卡权重 | 连抽 50 次 | 稀有保底触发、后期降权 |
| 叠加衰减 | 连选 damage | 达 maxStacks 消失、边际递减 |
| 抉择升级 | 选 glass_cannon | 正负同改、仍在 BALL_TUNING |
| 非阻塞 | 升级中 | 既有编队继续、不新刷 |
| 预览 | 升级卡 | 显 当前→升级后 差值 |

## 附录 C · 风险检查表

- [ ] `apply` 只写 `BALL_TUNING`/`baseHp`/`playerLevel`
- [ ] `GainXp`/`PickUpgrade` 无渲染/输入调用（幸存者核心契约）
- [ ] 波次仍连续涌出，未恢复离散波次
- [ ] `UPGRADE_POOL` 闭包声明顺序正确（v0.9.0 bug）
- [ ] 抽卡用 Park-Miller（AB-002）


## 十一、设计哲学与反模式

肉鸽成长的第一性原理是「每次升级都是一次有意义的抉择，而非数值通胀」。反模式有三：其一是纯正向三选一，缺少取舍张力，玩家永远选最大数；其二是无叠加上限，后期单属性爆炸导致其他系统失效；其三是升级效果散落在渲染/输入层，导致同一项强化在 UI 预览与 3D 实际不一致（违反 AB-027）。本模块以「权重保底 + 叠加上限 + 边际递减 + 抉择型负向」四支柱构建成长深度：保底解决稀有项可见性，上限解决膨胀，递减解决后期单调，抉择解决张力。关键纪律是 `apply()` 只写规则变量，UI 只展示 `delta`——规则与表现严格单向流动，这正是 v0.9.0 幸存者化分层契约（AB-027）在成长子系统的具象化。


## 十二、协作依赖图

`P5 成长` 处于幸存者循环中枢，上游依赖 `P1 数值`（衰减/权重参数进 BALANCE）、`P4 弹珠`（分裂/加速/巨型/冰冻的 BALL_TUNING 落点由本池改）、`P6 波次`（pendingLevelUps 守卫跳过 spawn）；下游供养 `P8 UI`（卡片 delta 快照）、`P10 音频`（upgradeApplied 钩子）、`P2 渲染`（升级扫光读 Presentation）。改动 `UPGRADE_POOL` 新增项时，须同步：①`P1` 若该项数值需档位管理则登 BALANCE；②`P8` 若需展示 delta 则扩快照字段；③`P10` 若需专属音则加 FEEDBACK_MAP 项。任何新增项的 `apply` 必须遵守「只写规则变量」红线，否则 AB-027 分层被破坏。

## 十三、落地优先级建议

若资源有限，优先做 T1（权重保底）与 T2（叠加衰减），二者以最小成本解决「抽卡无意义项占卡」与「后期数值爆炸」两大核心痛点；T3 抉择型升级建议在首轮调参稳定后再上，避免负向数值干扰平衡基线；T4 非阻塞升级与 T5 预览属于体验增强，可随后补齐。每完成一项须在 `versions.md` 记录数值变更，便于二分定位成长退化。
