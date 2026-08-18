# P4 · 弹珠技能与弹道物理模块开发计划书

> 版本：v0.9.0 规划 / 草稿 v1
> 模块方向：弹珠类型技能、反弹物理、分裂/贯穿/冰冻/加速机制、弹道预测
> 目标读者：负责 `Game.lua` 弹珠规则与 `Scene3DBackend.lua` 弹道轨迹绘制的开发者

---

## 一、模块目标

本模块负责「弹珠怎么飞、打中后发生什么」。v0.9.0 已确立四类弹珠权威契约：基础弹（每次直接命中独立 5% 概率生成两颗完整功能分裂弹）、加速弹（每次反弹/命中加速 15%，按速度最高增至 3 伤并自动追击最近砖块，已削弱到 `speedBoost=1.06`/`maxSpeed=900`/`damageStep=320`/`maxDamage=2`/`redirectThrottle=0.45`）、冰冻弹（冻结）、巨型弹（任意有效反弹只武装一次贯穿，命中造成直径 7 格圆形范围伤害）。本计划书规划**技能手感与弹道物理的下一阶段打磨**，并固化「技能契约不可被渲染层覆盖」的约束。

核心不变量（CLAUDE.md 避雷清单）：
- 弹珠技能契约（权威）：分裂/加速/巨型/冰冻的效果数值由 `Game` 规则层定义，渲染只反映状态。
- 加速弹削弱契约：不得恢复 `1.15/1250/3` 强成长与无节流黏着。
- 倾斜正交输入契约 + 瞄准轨迹契约：`Scene3DBackend` 的 `ScreenToGame()` 与瞄准轨迹必须用 `Camera:WorldToScreenPoint()` 标定的投影参数；轨迹首点必须是 `activeBall.x/y`，当前 8 单位步长、140 次采样、按权威半径处理左右/顶部反弹，禁止恢复缺首点的短 50 点预测。

---

## 二、现状与手感缺口

### 2.1 已达标项
- 基础弹分裂：命中 5% 概率两颗完整分裂弹，可继续分裂（链式）。
- 加速弹：削弱后成长可控，追击节流 0.45s。
- 巨型弹：单次贯穿武装 + 直径 7 格圆范围伤害。
- 冰冻弹：冻结时长 `freezeDuration + BALL_TUNING.iceBonus`。
- 弹道预测：首点锚定发射体、8 单位步长、140 采样、左右/顶反弹（v0.9.0 瞄准轨迹契约）。

### 2.2 手感缺口
1. **反弹物理同质**：所有弹珠反弹都用同一弹性系数，缺少「巨型弹更沉、加速弹更滑」的差异化手感；且反弹点未做「擦边容差」导致偶尔贴墙滑行消失。
2. **分裂弹初速方向**：当前分裂弹沿固定 ±角度生成，缺少「继承母弹速度 + 扩散角」的连贯感，高速下分裂弹易重叠。
3. **加速弹追击黏着感**：虽已节流，但 `redirectThrottle` 在低速段仍可能每帧轻推，导致轨迹抖动；需要「低于某速度阈值不追击」的下限。
4. **巨型弹贯穿视觉断点**：贯穿命中后圆范围伤害立即结算，但「贯穿弹是否继续飞」的规则未明确，玩家易误判。
5. **弹道预测未含弹珠尺寸**：预测线按点轨迹，未考虑当前 `marble.radius` 的视觉宽度，倾斜 46° 下预测线与实际碰撞边界有偏差（瞄准轨迹契约要求按权威半径处理）。

---

## 三、架构切面

弹珠规则全在 `Game.lua`（权威）。`Scene3DBackend` 只绘制轨迹与特效，读 `Game.GetSnapshot()` + `Presentation.GetSnapshot()`。本模块：
- 修改 `Game.lua` 的 `BALL_TYPES`、`TrySplitNormal`、`BoostSpeedMarble`、`RedirectSpeedMarble`、`DamageGiantArea`、`UpdateMarbles`（子步反弹/追击/节流）。
- 修改 `Scene3DBackend` 的 `DrawAimTrajectory` 以消费权威半径与反弹参数（只读）。
- 不引入渲染层数值（AB-027）。

文件改动：`scripts/Game.lua`（主）、`scripts/Scene3DBackend.lua`（轨迹绘制，最小）。

---

## 四、具体任务清单

### T1：反弹差异化与擦边容差
在 `BALL_TYPES` 增加 `bounceElasticity`（默认 1.0）与 `wallGrace`（擦边容差，单位米，默认 0.02）。`UpdateMarbles` 反弹时按 `bounceElasticity` 缩放法向速度；`wallGrace` 用于判定「贴墙但仍在场内」避免误销毁。巨型弹 `bounceElasticity=0.92`（更沉），加速弹 `1.0`（更滑）。规则数值，不进渲染层。

### T2：分裂弹连贯初速
`TrySplitNormal` 生成的分裂弹继承母弹速度向量，叠加 ±`splitSpread`（默认 18°）扩散角，并保留母弹 `ballType`。保证高速下两颗分裂弹不重叠、视觉连贯。分裂概率仍为 `0.05 + BALL_TUNING.splitBonus`（v0.9.0）。

### T3：加速弹追击下限
`RedirectSpeedMarble` 增加 `redirectMinSpeed` 阈值（默认 120）：当 `marble.speed < redirectMinSpeed` 不触发追击，消除低速抖动；`redirectCooldown` 仍按 `BALL_TYPES.speed.redirectThrottle=0.45` 节流（加速弹削弱契约保持）。

### T4：巨型弹贯穿语义明确
`DamageGiantArea` 命中后，巨型弹进入 `armed=false` 不再造成范围伤害，但**继续直线飞行**直到下次反弹重新武装一次（仍只一次，符合「任意有效反弹只武装一次贯穿」）。文档化此语义，避免误判为「命中即消失」。

### T5：弹道预测含权威半径
`DrawAimTrajectory` 在 8 单位步长采样时，把当前 `marble.radius * WORLD_SCALE` 作为预测线半宽（仍用 `WorldToScreenPoint` 标定后的投影），顶部/左右反弹按权威半径偏移，使预测线与实际碰撞边界在 46° 倾斜下一致（瞄准轨迹契约）。不改动采样数 140 与首点锚定。

### T6：反弹音效钩子（数据侧）
`Game` 在反弹/命中时由 `Presentation` 维护瞬时状态（不新增事件类型，复用现有 `bounce`/`hit` 语义），供 P10 音效消费；本模块只在 `Game` 确保 `Presentation` 能拿到反弹坐标（已有 `Emit` 机制）。

---

## 五、风险与避雷

- **加速弹削弱红线**：`speedBoost` 不得回到 1.15、`maxSpeed` 不得回 1250、`maxDamage` 不得回 3、`redirectThrottle` 不得取消（加速弹削弱契约）。任何 T1/T3 改动必须小于或等于当前削弱值。
- **禁止渲染层算伤害**：反弹系数、分裂概率、范围伤害半径全在 `Game`；`Scene3DBackend` 只读快照画轨迹（AB-027 / 视觉瞬时状态契约）。
- **轨迹首点锚定**：`DrawAimTrajectory` 首点必须是 `activeBall.x/y`，禁止恢复缺首点短预测（瞄准轨迹契约）。
- **投影一致性**：轨迹使用的投影参数必须与 `ScreenToGame`、空间反馈同一组，且相机震屏后刷新（AB-019 / AB-026）。
- **9:16 不拉伸**：轨迹坐标经 CONTAIN 缩放，禁止把设计坐标直接当屏幕（AB-018）。
- **Lua 作用域**：若 `BALL_TYPES` 被 `UPGRADE_POOL` 闭包引用，确保声明顺序正确（v0.9.0 bug 修复经验）。

---

## 六、验收标准

1. 巨型弹反弹更沉、加速弹更滑，手感可辨且数值不越削弱红线（T1）。
2. 分裂弹高速下不重叠、沿母弹扩散，分裂概率与 v0.9.0 一致（T2）。
3. 加速弹低速段不抖动，追击仍节流（T3，加速弹削弱契约）。
4. 巨型弹贯穿后继续飞行、仅一次武装，语义文档化（T4）。
5. 弹道预测线在 46° 倾斜下与实际碰撞边界吻合，首点锚定发射体（T5，瞄准轨迹契约）。
6. LSP 0 Error + 官方构建通过；`Game` 内无渲染 API 调用，升级链路无回归。

---

## 七、后续迭代建议

- 与 P5（升级池）协同：`splitBonus`/`speedMul`/`giantArea`/`iceBonus` 已是升级落点，T1/T2 新增的 `bounceElasticity`/`splitSpread` 可考虑纳入升级池作为进阶强化。
- 与 P7（输入手感）协同：拖拽发射的「蓄力时长 → 初速」映射应与 T1 反弹手感统一调参。
- 与 P10（音效）协同：T6 的反弹钩子驱动音效，触发在 `Presentation` 不在 `Game` 渲染循环。


## 八、实施里程碑排期

- **M1（反弹与分裂，1 周期）**：完成 T1/T2，差异化弹性、分裂连贯初速。Gate：巨型更沉、加速更滑，分裂高速不重叠。
- **M2（加速弹下限，0.5 周期）**：完成 T3，低速不追击。Gate：低速段无抖动，`redirectThrottle` 仍 0.45。
- **M3（贯穿语义，0.5 周期）**：完成 T4，巨型贯穿后继续飞。Gate：仅一次武装，文档化。
- **M4（弹道含半径，1 周期）**：完成 T5，预测线按权威半径半宽。Gate：46° 倾斜下与实际碰撞边界吻合。

## 九、回滚与降级预案

加速弹削弱红线（`speedBoost=1.06`/`maxSpeed=900`/`maxDamage=2`/`redirectThrottle=0.45`）任何 T1/T3 改动必须 ≤ 当前值，越线即回退。若分裂初速导致链式爆炸：收紧 `splitSpread` 或分裂概率（仍由 `BALL_TUNING.splitBonus` 控）。弹道预测若偏差：恢复 8 单位步长/140 采样与首点锚定（瞄准轨迹契约），`marble.radius` 半宽只影响绘制不影响规则判定。

## 十、关键伪代码参考

```lua
-- Game.UpdateMarbles 反弹（规则层）
local e = BALL_TYPES[marble.ballType].bounceElasticity or 1.0
marble.vel.y = -marble.vel.y * e  -- 顶部反弹
-- 加速弹追击下限
if marble.ballType == "speed" and marble.speed > REDIRECT_MIN_SPEED then
  if marble.redirectCooldown <= 0 then RedirectSpeedMarble(marble); marble.redirectCooldown = BALL_TYPES.speed.redirectThrottle end
end
```
反弹系数、追击节流全在 `Game`；`Scene3DBackend.DrawAimTrajectory` 只读 `marble.radius` 画预测线（AB-027 渲染只读）。


## 附录 A · 跨模块接口契约

- `Game`（弹珠规则）→ `Scene3DBackend`：轨迹只读 `marble.radius`/`marble.pos`，不读规则数值。
- `Game` → P5：分裂/加速/巨型/冰冻的 `BALL_TUNING` 落点由 P5 升级池改，本模块只定义基线。
- `Game` → P10：`bounce`/`hit`/`split`/`giant` 事件 `Emit` 给 `Presentation`，强度在反馈层不回写。
- `Game` → P7：蓄力上限常量为规则层，P7 只传意图。

## 附录 B · 验收用例清单

| 用例 | 步骤 | 期望 |
|------|------|------|
| 反弹差异 | 巨型 vs 加速 | 沉/滑可辨 |
| 分裂连贯 | 高速命中 | 不重叠、沿母弹扩散 |
| 加速下限 | 低速段 | 不抖动、仍节流 |
| 贯穿语义 | 巨型命中 | 继续飞、仅一次武装 |
| 轨迹半径 | 46° 斜视 | 预测线与碰撞边界吻合 |

## 附录 C · 风险检查表

- [ ] 加速弹削弱红线未破（1.06/900/2/0.45）
- [ ] 渲染层无伤害计算（AB-027）
- [ ] 轨迹首点锚定 activeBall（瞄准轨迹契约）
- [ ] 投影参数与 ScreenToGame 同组、震屏刷新（AB-026）
- [ ] Lua 作用域：BALL_TYPES 声明在 UPGRADE_POOL 上
