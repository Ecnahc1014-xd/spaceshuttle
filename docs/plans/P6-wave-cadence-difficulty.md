# P6 · 波次节奏与难度曲线模块开发计划书

> 版本：v0.9.0 规划 / 草稿 v1
> 模块方向：连续刷怪、波次间隔收紧、同屏上限、难度阶段、编队组成演化
> 目标读者：负责 `Game.lua` `UpdateWaveLogic` 与编队生成策略的开发者

---

## 一、模块目标

本模块负责「敌人什么时候来、来多少、多快」。v0.9.0 已实装幸存者式连续涌出：`interval = math.max(WAVE_INTERVAL_MIN, WAVE_INTERVAL - (wave-1)*0.35)`，受 `MAX_CONCURRENT=14` 同屏上限约束，升级期间（`pendingLevelUps>0`）暂停刷怪。本计划书规划**难度曲线的阶段化与可预测性**，让「压力随时间单调增强但有节奏呼吸感」，并固化「连续涌出、不离散清场」的契约。

核心不变量（CLAUDE.md 避雷清单）：
- 波次节奏契约：幸存者持续涌出，间隔随波次从 `WAVE_INTERVAL` 收紧到 `WAVE_INTERVAL_MIN`，受 `MAX_CONCURRENT` 同屏上限约束；**禁止恢复「清场才出下一波」的离散波次**。
- 幸存者核心契约：`pendingLevelUps>0` 时玩法暂停，升级由 `PickUpgrade` 恢复。
- 世界边界契约：`Game` 世界边界（0、DW、0 顶部）是权威碰撞来源，边界只当视觉是禁止的（与 P3 编队、P2 边缘协同）。

---

## 二、现状与节奏缺口

### 2.1 已达标项
- 连续 spawn（非离散波次）。
- 间隔随波次线性收紧 `(wave-1)*0.35`，封底 `WAVE_INTERVAL_MIN=2.8`。
- `MAX_CONCURRENT=14` 同屏上限。
- 升级期间不刷怪。

### 2.2 节奏缺口
1. **线性收紧无阶段**：`0.35` 是魔法数，压力单调加但无「喘息点」，长时间游玩疲劳；缺「阶段（phase）」概念（如每 5 波进入更密子阶段、每 10 波短暂缓和）。
2. **编队组成不变**：所有波次四类敌机均匀随机，缺「前期轻机为主、后期重机/密集阵为主」的演化，玩家无「难度换挡」感知。
3. **同屏上限静态**：`MAX_CONCURRENT` 固定 14，后期应随波次微增（仍受性能护栏，见 P9），否则 14 顶满后只是更快刷新而非更密。
4. **无「安全窗口」**：连续涌出下，玩家清完一波与下一波密集来袭之间无设计间隙，易在升级卡顿时连续掉血。
5. **间隔公式不可配置**：收紧步长/封底写在逻辑内，调参需改代码（归 P1 的 `BALANCE`，但本模块需预留读取位）。

---

## 三、架构切面

波次逻辑全在 `Game.lua` 的 `UpdateWaveLogic`（规则层）。本模块读取 P1 的 `BALANCE` 表字段、P3 的 `formation`/敌机类型元数据，输出 spawn 决策（仍写 `veggies`/敌机数组，属规则状态）。`Scene3DBackend` 只读快照绘制，不决定节奏（AB-027）。文件改动：`scripts/Game.lua`（主）、`scripts/AircraftPixelData.lua`（仅元数据读取，已由 P3 提供）。

---

## 四、具体任务清单

### T1：阶段化难度曲线
在 `BALANCE` 增加 `phaseLength`（默认 5）、`phaseTightenBonus`（每阶段额外收紧）、`breatherEvery`（默认 10 波触发一次间隔回弹）。`UpdateWaveLogic` 的 `interval` 改为：`base - (wave-1)*step - floor(wave/phaseLength)*phaseTightenBonus`，并在 `breather` 波把 `interval` 临时 +`breatherRelax`（如 +1.5s），形成「紧—紧—缓」呼吸。

### T2：编队组成演化
`SpawnWave` 按 `wave` 选敌机类型权重：前期 `scout`/`striker` 权重高，后期 `bomber`/`interceptor` 升高（读取 `AircraftPixelData` 的 `densityTier` 作为权重锚）。`formation` 随波次从 `line` → `vee` → `wedge`（P3 元数据）。权重表写入 `BALANCE`，不写死逻辑。

### T3：动态同屏上限
`MAX_CONCURRENT` 改为 `BALANCE.maxConcurrent + floor(wave/8)`（每 8 波 +1，封顶由 P9 性能护栏约束，如 ≤22），让后期更密但受帧预算保护。

### T4：安全窗口（清场间隙）
当同屏敌机数降至 0 且距上次 spawn > `BALANCE.safeGap`（默认 1.2s）时，允许一次「奖励 XP 微滴」或不刷怪短窗口，给玩家喘息；仍保持连续涌出语义（不恢复离散波次）。

### T5：间隔公式配置化
把 `0.35`/`2.8`/`7.0` 全部迁入 `BALANCE`（由 P1 收敛），`UpdateWaveLogic` 只引用，无魔法数（与 P1 T1/T3 协同）。

### T6：节奏遥测（调试）
`GetSnapshot` 增加 `wave, spawnIntervalCurrent, concurrentCount`，供 HUD/调试显示当前节奏；不新增渲染计算。

---

## 五、风险与避雷

- **禁止离散波次回归**：T4 的「安全窗口」是「连续涌出中的短暂间隙」，不是「清完才能出下一波」；必须保持 `pendingLevelUps==0` 时持续 spawn（波次节奏契约）。
- **禁止改碰撞/边界**：节奏只改 spawn 时间与组成，不动 `DANGER_Y`、墙体几何、敌机 `alive` 判定（世界边界契约 / AB-024）。
- **性能护栏**：T3 动态上限必须 ≤ P9 约定的帧预算上限，防止同屏爆炸拖垮（P9 协同）。
- **PRNG 隔离**：spawn 随机用 `Game` Park-Miller（AB-002）。
- **Lua 作用域**：若 `BALANCE` 被 `UpdateWaveLogic` 闭包引用，确认声明顺序（v0.9.0 bug 修复经验）。

---

## 六、验收标准

1. 难度呈「紧—紧—缓」阶段呼吸，非纯线性疲劳（T1）。
2. 敌机组成随波次演化，重型/密集阵后期占比升（T2，P3 元数据协同）。
3. 同屏上限随波次微增但受性能封顶（T3，P9 护栏）。
4. 清场后有短喘息窗口，仍连续涌出（T4，波次节奏契约）。
5. 间隔公式无魔法数，全读 `BALANCE`（T5，P1 协同）。
6. 快照暴露节奏指标，LSP 0 Error + 官方构建通过，升级期间仍不刷怪（幸存者核心契约）。

---

## 七、后续迭代建议

- 与 P1（数值）协同：T1/T2/T3/T5 的曲线参数全部进 `BALANCE`，由 P1 统一管理档位。
- 与 P3（编队）协同：T2 的 `formation`/类型权重依赖 P3 的元数据字段名稳定。
- 与 P5（升级池）协同：T4 安全窗口与 P5 的「升级期间非阻塞」共享「既有编队继续、不新刷」语义。
- 与 P9（性能）协同：T3 动态上限需 P9 提供帧预算护栏数值。


## 八、实施里程碑排期

- **M1（阶段曲线，1 周期）**：完成 T1/T5，间隔公式迁 `BALANCE` + 阶段呼吸。Gate：无魔法数，紧—紧—缓。
- **M2（组成演化，1 周期）**：完成 T2，敌机类型/阵型随波次演化。Gate：后期重机占比升。
- **M3（动态上限，0.5 周期）**：完成 T3，`MAX_CONCURRENT` 随波次微增。Gate：≤ P9 护栏上限。
- **M4（安全窗口，0.5 周期）**：完成 T4，清场短喘息。Gate：仍连续涌出。

## 九、回滚与降级预案

T4「安全窗口」是连续涌出中的间隙，绝非「清完才出下一波」；若被误解为离散波次，立即删 T4 的间隔时间窗逻辑、保留持续 spawn（波次节奏契约）。T3 动态上限若超 P9 帧预算：回退为固定 `BALANCE.maxConcurrent=14`。间隔公式回滚即把 `0.35/2.8/7.0` 写回（T5 反向），但优先保留 `BALANCE` 引用以便 P1 统一管理。

## 十、关键伪代码参考

```lua
-- Game.UpdateWaveLogic（规则层）
local interval = BALANCE.waveInterval
  - (wave-1) * BALANCE.waveTightenStep
  - math.floor(wave / BALANCE.phaseLength) * BALANCE.phaseTightenBonus
if wave % BALANCE.breatherEvery == 0 then interval = interval + BALANCE.breatherRelax end
interval = math.max(BALANCE.waveIntervalMin, interval)
if pendingLevelUps <= 0 and #veggies < currentMaxConcurrent() then spawnTimer = spawnTimer + dt; if spawnTimer >= interval then SpawnWave(); spawnTimer = 0 end end
```
`pendingLevelUps>0` 暂停刷怪（幸存者核心契约），既有编队仍 `enemy.y += vy` 继续下移（与 P5 T4 非阻塞升级协同）。


## 附录 A · 跨模块接口契约

- `Game`（波次）→ `Game`（编队）：读取 P3 `formation`/类型权重排阵，不改 `alive` 判定。
- `Game` → P1：间隔/上限参数读 `BALANCE`，禁止本地魔法数。
- `Game` → P5：`pendingLevelUps>0` 跳过 spawn，既有编队继续下移。
- `Game` → P9：动态同屏上限 ≤ P9 帧预算护栏。
- `Game` → P8：快照暴露 `wave`/`concurrentCount` 供 HUD。

## 附录 B · 验收用例清单

| 用例 | 步骤 | 期望 |
|------|------|------|
| 阶段呼吸 | 跑 20 波 | 紧—紧—缓，非纯线性 |
| 组成演化 | 后期波 | 重机/密集阵占比升 |
| 动态上限 | 第 16 波 | 同屏 ≤22 护栏 |
| 安全窗口 | 清场后 | 短喘息、仍连续涌出 |
| 配置化 | 查 BALANCE | 无 0.35/2.8/7.0 魔法数 |

## 附录 C · 风险检查表

- [ ] 未恢复「清完才出下一波」离散波次
- [ ] 节奏只改 spawn，未动 DANGER_Y/边界
- [ ] 动态上限受 P9 护栏
- [ ] PRNG 用 Park-Miller（AB-002）
- [ ] BALANCE 声明在 UpdateWaveLogic 闭包之上


## 十一、设计哲学与反模式

难度曲线的第一性原理是「压力单调增强但带呼吸节奏，让玩家在紧绷与喘息间形成心流」。反模式有二：其一是线性无限收紧，导致中后期只有疲劳没有策略窗口；其二是离散波次（清完才出下一波），破坏幸存者「持续涌出」的核心契约（波次节奏契约明确禁止）。本模块以「阶段呼吸 + 组成演化 + 动态上限 + 安全窗口」实现有结构的难度：阶段制造张弛，组成制造新鲜感，动态上限制造密度增长，安全窗口制造操作余量。必须强调：安全窗口是连续涌出中的间隙，绝不是离散波次回归——这是 v0.9.0 已确立且不可动摇的边界。所有节奏参数迁入 `BALANCE`，由 P1 统一管理，避免魔法数污染逻辑。


## 十二、协作依赖图

`P6 波次` 是压力来源，上游依赖 `P1 数值`（间隔/上限读 BALANCE）、`P3 编队`（formation/类型权重元数据）、`P5 成长`（pendingLevelUps 守卫）；下游影响 `P8 UI`（HUD 节奏指标快照）、`P9 性能`（动态同屏上限 ≤ 帧预算护栏）、`P2 渲染`（同屏密度决定体素重建压力）。改动波次逻辑时，须确认：①`P1` 字段名稳定，不回退魔法数；②`P9` 护栏数值与动态上限对齐，防同屏爆炸；③`P5` 非阻塞升级语义保留（既有编队继续）。波次节奏契约（连续涌出）是最高优先级边界，任何「喘息窗口」实现不得退化为离散波次。
