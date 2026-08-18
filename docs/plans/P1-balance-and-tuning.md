# P1 · 平衡性与数值调优模块开发计划书

> 版本：v0.9.0 规划 / 草稿 v1
> 模块方向：数值系统、平衡曲线、伤害/经验/生命调参
> 目标读者：负责「太空飞机弹珠」规则层与数值演化的开发者

---

## 一、模块目标

本模块负责游戏全部「可演化数值」的集中管理、可读性、可调试性与平衡演化能力。当前 v0.9.0 已把基础数值零散落在 `Game.lua` 的常量区与 `BALL_TUNING` 表中，幸存者化改造后新增了 `BASE_HP=100`、`BRICK_BASE_DAMAGE=3`、`XP_PER_BRICK=1`、`XP_PER_CLEAR=8`、`WAVE_INTERVAL=7.0` 等常量，但存在以下问题：

1. 数值来源分散，既有全局常量（`BASE_HP`、`BRICK_BASE_DAMAGE`），又有 `BALL_TUNING` 表（跨升级可改），还有写死在技能函数里的经验值（`XP_PER_CLEAR + math.min(clearStreak-1, 5)`），修改一项平衡要让维护者跨 3 个位置。
2. 缺少「难度曲线」的单一权威公式。波次间隔收紧写在 `UpdateWaveLogic` 的 `interval = math.max(WAVE_INTERVAL_MIN, WAVE_INTERVAL - (wave-1)*0.35)`，0.35 是魔法数；经验阈值 `BASE_XP_TO_NEXT=12` 是固定值，没有随等级增长的曲线，导致中后期升级节奏不可控。
3. 缺少离线数值模拟能力。当前无法在 headless 下用一段脚本快速「跑 10 分钟模拟」观察基地存活时间、平均升级频率，只能靠人工 Preview 试玩。

本模块的交付目标是：**建立一套「数值即数据、曲线即公式、平衡可离线模拟」的规则层数值子系统的落地方案**，在不破坏「Game 为权威规则层、不含渲染 API」契约（见避雷清单 AB-027）的前提下，让数值演化有章法。

---

## 二、现状与问题详析

### 2.1 现有数值面

当前代码中与数值相关的实体可归为四类：

- **静态常量（不可在局内修改）**：`BASE_HP`、`BRICK_BASE_DAMAGE`、`XP_PER_BRICK`、`XP_PER_CLEAR`、`BASE_XP_TO_NEXT`、`WAVE_INTERVAL`、`WAVE_INTERVAL_MIN`、`MAX_CONCURRENT`，以及 `DANGER_Y`（玩法几何边界，本模块不改动，归渲染/几何契约）。
- **局内可调量表 `BALL_TUNING`**：`damageBonus`、`giantArea`、`splitBonus`、`speedMul`、`iceBonus`、`brickDmg`、`xpMul`。这些由升级池 `apply()` 修改，是「成长」的落点。
- **技能基线 `BALL_TYPES`**：每种弹珠的 `radius`、`speed`、`damage`、`speedBoost`、`maxSpeed`、`damageStep`、`maxDamage`、`redirectThrottle`、`freezeDuration`、`areaRadiusCells` 等。加速弹已按削弱契约收紧到 `speedBoost=1.06, maxSpeed=900, damageStep=320, maxDamage=2, redirectThrottle=0.45`。
- **写死在逻辑中的魔法数**：清编队连击加成 `math.min(clearStreak-1, 5)`、波次收紧步长 `0.35`、升级阈值固定 `12`。

### 2.2 痛点

- **平衡不可预测**：设计者想「让 3 分钟时压力陡增」，必须同时改 `WAVE_INTERVAL_MIN`、`MAX_CONCURRENT` 和 0.35 三个数，且无文档说明三者关系。
- **经验曲线扁平**：`BASE_XP_TO_NEXT=12` 固定，前期 12 砖升级，后期仍是 12 砖，失去「升级变慢」的肉鸽正反馈衰减感。
- **难以做 A/B 与数值回归**：没有统一的 `Tuning` 表，无法在构建期或 headless 下加载不同数值档位做对照。

---

## 三、架构切面（不破坏现有契约）

依据避雷清单 AB-027（幸存者化分层）：所有平衡规则必须留在权威 `Game` 层，升级只改 `BALL_TUNING` 并通过 `GetSnapshot().upgradeChoices` 暴露 UI。本模块**不引入渲染层数值**，只做：

1. 把「静态常量 + 写死魔法数」收敛进一张 `BALANCE` 表，与 `BALL_TUNING` 分离（前者局内不可变，后者局内可变）。
2. 把「难度曲线」提炼为可配置公式函数，放在 `Game.lua` 内的 `local` 函数，不污染全局。
3. 提供 `Game.DebugSimulate(seconds)` 一类 `local` 接口（或在独立调试脚本调用 `Game` 内部状态），用于离线数值模拟——但**不**作为正式入口暴露给 `main.lua` 渲染循环。

文件改动范围：仅 `scripts/Game.lua`。不触及 `Renderer3D.lua` / `Scene3DBackend.lua` / `AircraftPixelData.lua`，符合「规则层纯净」。

---

## 四、具体任务清单（落地步骤）

### T1：建立 `BALANCE` 常量表（预计影响 40 行）
在 `Game.lua` 顶部常量区，将分散的 `BASE_HP`、`BRICK_BASE_DAMAGE`、`XP_PER_BRICK`、`XP_PER_CLEAR`、`BASE_XP_TO_NEXT`、`WAVE_INTERVAL`、`WAVE_INTERVAL_MIN`、`MAX_CONCURRENT` 收进：
```lua
local BALANCE = {
    baseHp = 100,
    brickBaseDamage = 3,
    xpPerBrick = 1,
    xpPerClear = 8,
    baseXpToNext = 12,
    xpToNextGrowth = 1.18,   -- 新增：每级经验阈值乘子
    waveInterval = 7.0,
    waveIntervalMin = 2.8,
    waveTightenStep = 0.35,
    maxConcurrent = 14,
    clearStreakBonusCap = 5,
}
```
保留原常量名作为 `BALANCE.xxx` 的别名或全局只读引用，避免一次性改动面过大；优先改为直接引用 `BALANCE`。

### T2：经验曲线公式化
新增 `local function XpToNext(level)`，返回 `math.floor(BALANCE.baseXpToNext * BALANCE.xpToNextGrowth^(level-1))`。`GainXp` 中升级时用动态阈值替代固定 `BASE_XP_TO_NEXT`。

### T3：波次收紧公式化
`UpdateWaveLogic` 改用 `BALANCE.waveInterval`、`BALANCE.waveIntervalMin`、`BALANCE.waveTightenStep`，并新增 `waveCap`（最高波次后保持最小间隔），避免无限收紧到负。

### T4：连击加成走 BALANCE
`Math.min(clearStreak-1, 5)` 改为 `math.min(clearStreak-1, BALANCE.clearStreakBonusCap)`。

### T5：离线数值模拟器（调试用）
在 `Game.lua` 末尾新增 `local function SimulateRun(seed, seconds)`：以固定 PRNG 种子驱动 `Update` 若干步，统计「基地存活时长、平均击碎砖块数、平均升级次数、到达波次」。仅在 `scripts/_balance_sim.lua` 调试脚本中 require 并调用，不参与正式构建入口（遵守规则 #0 中「临时文件」约定，调试完即删）。

### T6：数值档位配置（可选进阶）
提供 `BALANCE_PRESETS = { normal=..., hard=..., chill=... }`，`Game.StartGame(mode)` 可接收难度档；UI 不强制，但预留数据位。

---

## 五、风险与避雷

- **禁止把数值写进渲染层**：依据 AB-027，任何成长数值、`brickDmg`、暂停流程一律在 `Game` 层；`Scene3DBackend.lua` 只能读快照显示，不能算伤害。
- **禁止破坏 9:16 投影与碰撞契约**：本模块只动数字，不动 `DANGER_Y`、墙体几何、相机参数；`brickDmg` 改动只影响扣血，不影响方块碰撞拓扑（AB-024 体素采样一致性）。
- **PRNG 必须复用 Game 既有 Park-Miller**：模拟器不得引入 `math.random`，否则偏离正式玩法随机流（AB-002 随机流隔离）。
- **Lua 作用域陷阱**：若把 `BALANCE` 引用放进 `UPGRADE_POOL` 闭包，必须确认 `BALANCE` 声明在 `UPGRADE_POOL` 之上（参考 v0.9.0 已知 bug 修复经验）。

---

## 六、验收标准

1. `Game.lua` 中所有「局内不可变」数值均可经 `BALANCE` 表单点修改生效，无残留散落魔法数（T1–T4）。
2. 经验阈值随等级按 `xpToNextGrowth` 增长，第 5 级阈值明显高于第 1 级；波次间隔在 `waveIntervalMin` 处正确封底。
3. 离线模拟器能在 headless 下产出一份平衡报告（存活时长/升级频率统计），且不进入正式构建入口。
4. LSP 0 Error，官方构建通过，且 `BALL_TUNING` 升级链路无回归（选 upgrade 后伤害/范围变化与 v0.9.0 一致）。
5. 文档 `/workspace/docs/plans/P1` 记录最终 `BALANCE` 取值与每级经验阈值表，供后续调参复用。

---

## 七、后续迭代建议

- 接入 `versions.md` 记录每次数值档位变更与对应「模拟器存活中位数」，形成数值演化基线。
- 若要做难度档，优先通过 `BALANCE_PRESETS` 而非改代码，降低回归风险。
- 本模块与 P5（肉鸽成长池）、P6（波次节奏）强耦合，改动前先同步这两份计划书的责任边界：`BALANCE` 管「数值」，P6 管「节奏触发逻辑」，P5 管「升级效果种类」。


## 八、实施里程碑排期

- **M1（数据收敛，1 个构建周期）**：完成 T1，把分散常量收进 `BALANCE` 表，保留旧名只读别名避免回归。Gate：全局搜索 `BASE_HP`/`BRICK_BASE_DAMAGE` 等旧名引用归零，全部走 `BALANCE`。
- **M2（曲线公式化，1 周期）**：完成 T2/T3/T4，经验阈值、波次间隔、连击加成改为公式。Gate：`xpToNextGrowth` 生效，第 5 级阈值明显高于第 1 级。
- **M3（离线模拟器，1 周期）**：完成 T5/T6，模拟器产出平衡报告并存 `logs/balance/`。Gate：headless 下能跑出存活中位数，不进入正式入口。
- **M4（档位预设，可选）**：完成 `BALANCE_PRESETS`。Gate：`Game.StartGame("hard")` 可读硬档数值。

## 九、回滚与降级预案

若 `BALANCE` 收敛引发回归：保留旧常量名作为 `BALANCE` 别名，回滚只需删别名层；`xpToNextGrowth` 若导致中后期升级过慢，临时设回 `1.0`（固定阈值）即可恢复 v0.9.0 行为。模拟器脚本属调试文件，删之不影响正式构建（遵守临时文件约定）。所有数值变更须在 `versions.md` 记一行，便于二分定位平衡退化。

## 十、关键伪代码参考

```lua
local BALANCE = {
  baseHp = 100, brickBaseDamage = 3, xpPerBrick = 1, xpPerClear = 8,
  baseXpToNext = 12, xpToNextGrowth = 1.18,
  waveInterval = 7.0, waveIntervalMin = 2.8, waveTightenStep = 0.35,
  maxConcurrent = 14, clearStreakBonusCap = 5,
}
local function XpToNext(level)
  return math.floor(BALANCE.baseXpToNext * BALANCE.xpToNextGrowth^(level-1))
end
```
上述片段即 T1/T2 落点：常量进表、阈值随等级指数增长。升级链路仍只改 `BALL_TUNING`，不触碰 `BALANCE`（局内不可变语义）。


## 附录 A · 跨模块接口契约

- `Game` → `Renderer3D`/`Scene3DBackend`：本模块只改 `Game` 内部 `BALANCE` 表，快照结构不变；UI 读取 `baseHp`/`xp` 不变。
- `BALANCE` → P6：波次间隔/上限字段由 P6 读取，字段名以本模块 `BALANCE.wave*` 为准，禁止 P6 另起常量。
- `BALANCE` → P5：升级边际递减系数若纳入 `BALANCE`，由 P5 `apply` 读取，禁止写回 `BALANCE`（局内不可变）。
- 调试模拟器：仅 `_balance_sim.lua` 调用 `Game` 内部 `SimulateRun`，不参与正式构建入口（临时文件约定）。

## 附录 B · 验收用例清单

| 用例 | 步骤 | 期望 |
|------|------|------|
| 常量收敛 | 全局搜旧名 | 仅 `BALANCE` 别名引用 |
| 经验曲线 | 升到第 5 级 | 阈值 > 第 1 级 1.8 倍 |
| 波次封底 | 跑 30 波 | 间隔不低于 `waveIntervalMin` |
| 模拟器 | headless 跑 600s | 产出存活中位数报告 |
| 回归 | 选 upgrade | 伤害/范围变化同 v0.9.0 |

## 附录 C · 风险检查表

- [ ] 无散落魔法数（interval/0.35/xp 阈值）
- [ ] `xpToNextGrowth` 生效且不过缓
- [ ] 模拟器未进入 `main.lua` 正式循环
- [ ] `BALANCE` 声明在引用它的闭包之上（Lua 作用域）
- [ ] PRNG 复用 Game 既有 Park-Miller（AB-002）


## 十一、设计哲学与反模式

数值系统的第一性原则是「可预测、可回溯、可对话」。可预测指设计者改一个数能预判玩家体感；可回溯指每次调参有记录，平衡退化能二分定位；可对话指数值与代码解耦，策划改表不碰逻辑。反模式有三：其一是把魔法数埋进逻辑分支（如 `0.35` 写在 `UpdateWaveLogic` 内），调参需读源码；其二是把成长数值硬编码进渲染层，导致升级效果在 UI 与 3D 不一致；其三是用 `math.random` 做玩法随机，破坏不同帧率下的随机流一致性（AB-002）。本模块以 `BALANCE` 表 + 公式函数 + 离线模拟器三件套正面回应这三类反模式，使「太空飞机弹珠」的数值演化具备长期可维护性。
