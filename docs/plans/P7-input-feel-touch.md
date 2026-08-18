# P7 · 输入手感与触控适配模块开发计划书

> 版本：v0.9.0 规划 / 草稿 v1
> 模块方向：拖拽发射、触控/鼠标统一、9:16 投影逆变换、蓄力、升级卡点击、暂停键
> 目标读者：负责 `main.lua` 输入分发与 `Scene3DBackend` 投影标定的开发者

---

## 一、模块目标

本模块负责「玩家怎么操作」。v0.9.0 已实装：拖拽发射（发射向量 = 发射点 − 拖拽点）、倾斜 46° 正交相机下 `ScreenToGame()` 用 `WorldToScreenPoint` 标定投影、升级态点击经 `TryPickUpgradeAt` 命中卡片、P/Esc 暂停恢复。本计划书规划**输入手感与多端适配的下一阶段打磨**，并固化「输入必须先回到设计画布再做玩法逆变换」的约束。

核心不变量（CLAUDE.md 避雷清单）：
- 9:16 铁律：NanoVG 与 3D `Viewport` 共用同一 CONTAIN 缩放与居中偏移；非 9:16 屏只允许 letterbox，禁止拉伸/裁切；输入先经同一 DPR/scale/offset 回到设计画布，再经相机玩法平面投影逆变换到权威坐标，画布外按下必须过滤。
- 倾斜正交输入契约：`ScreenToGame()`、瞄准轨迹、空间反馈共享当前投影参数，禁止把屏幕设计坐标直接传给 `Game.Pointer*`。
- 瞄准朝向契约（AB-012）：待发射载具速度为零时用发射向量算车头角，松手后切回速度朝向；载具转向最短角追踪（AB-014）。
- 载具碰撞比例契约：缩放由权威半径推导，输入点击命中区同理以权威碰撞圆为基准。

---

## 二、现状与手感缺口

### 2.1 已达标项
- `Scene3DBackend` 用 `WorldToScreenPoint` 标定 `projectionOffset/Scale`，震屏后刷新（AB-026）。
- `main.lua` `HandleMouseDown`/`HandleTouchBegin` 统一先转设计画布再 `ScreenToGame`。
- 升级态点击 `TryPickUpgradeAt` 命中卡片矩形。
- `HandleKeyDown` P/Esc 暂停切换。

### 2.2 手感缺口
1. **蓄力映射缺失**：当前拖拽直接决定发射角度，无「拖拽距离 → 初速强度」蓄力，玩家无法控制力度（与 P4 T1 反弹手感需统一）。
2. **多指冲突**：触屏多指时，第二指可能误触发发射或升级点击；缺多指归属（aim 指 vs UI 指）。
3. **画布外过滤边界模糊**：非 9:16 letterbox 区按下未明确 `return`，偶发误射。
4. **点击容差静态**：升级卡片命中区为固定矩形，触屏手指 2mm 误差易点错；缺放大命中区/防误触。
5. **暂停键移动端无入口**：P/Esc 仅键盘，触屏无暂停按钮（UI 安全层契约要求非 playing 态不画操作 Dock，但暂停按钮应在 HUD 常驻）。

---

## 三、架构切面

输入分发在 `main.lua`（外层），投影标定在 `Scene3DBackend`（只读快照 + 相机）。`main.lua` 调用 `Game.HandleAction`/`Game.Pointer*` 等规则层接口，**不**在输入层做玩法判定（AB-027：规则判定在 Game）。本模块：
- `main.lua`：蓄力、多指归属、画布外过滤、升级卡放大命中、触屏暂停按钮事件。
- `Scene3DBackend.lua`：`ScreenToGame` 容差、投影参数暴露（只读）、`TryPickUpgradeAt` 命中区扩展。
- 不新增规则数值（若有力度上限，由 `Game` 暴露常量，P1 管理）。

---

## 四、具体任务清单

### T1：拖拽蓄力
`HandleTouchBegin/Move` 记录拖拽起点与当前点；发射初速 = `clamp(dragDist * POWER_PER_PIXEL, minP, maxP)`，`POWER_PER_PIXEL`/`minP`/`maxP` 由 `Game` 暴露（规则层常量，P1 收敛）。角度仍 = 发射点 − 拖拽点（AB-012）。`Scene3DBackend` 轨迹按蓄力等级显示颜色/粗细（只读快照）。

### T2：多指归属
`HandleTouchBegin` 为每个 touchId 记录「意图」：`aim` 指（在玩法区按下且非升级态）或 `ui` 指（在 HUD/卡片/暂停按钮区）。`ui` 指不触发发射；`aim` 指移动只更新瞄准。避免双指互扰。

### T3：画布外硬过滤
`HandleTouchBegin`/`HandleMouseDown` 首行判断设计坐标是否在 `[0,540]×[0,960]` 内（letterbox 外直接 `return`），并在 `Scene3DBackend.ScreenToGame` 入口加相同断言（9:16 铁律）。

### T4：升级卡放大命中
`TryPickUpgradeAt` 命中区在原 `cardW×cardH` 外扩 `HIT_PAD`（如 12px，设计空间），并对三卡做矩形排斥（只命中最近一张）。触屏手指误差被吸收（UI 安全层契约：卡片仅在 levelup 态绘制，非态不命中）。

### T5：触屏暂停按钮
在 `Scene3DBackend.DrawHud` 的 HUD 区（y=0..76）常驻一个暂停图标按钮（不违反 UI 安全层契约——HUD 始终不透明遮断世界层）；`main.lua` 在 HUD 命中区调 `Game.Pause/Resume`。键盘 P/Esc 保留。

### T6：投影容差与刷新断言
`ScreenToGame` 增加 `tolerance` 参数（设计空间像素），对近边界点击容错；所有相机位移后调用 `RefreshProjection()`（AB-026 自动化，P2 T6 协同），保证输入与 3D 同帧对齐。

---

## 五、风险与避雷

- **禁止直接传设计坐标给规则层**：`ScreenToGame` 必须经投影逆变换，禁止 `Game.Pointer*(desX, desY)` 直接喂设计坐标（倾斜正交输入契约 / AB-023 投影遮挡审查）。
- **禁止拉伸 9:16**：letterbox 外必须过滤，禁止把非 9:16 屏的溢出区当玩法（9:16 铁律）。
- **禁止输入层做玩法判定**：蓄力上限、命中伤害等规则值在 `Game`；`main.lua` 只传意图（AB-027）。
- **禁止 UI 与轨迹重叠误触**：升级卡/暂停按钮命中区与 playing 态轨迹绘制互斥（UI 安全层契约 AB-022）。
- **朝向语义**：待发射用发射向量算车头（AB-012），松手切速度朝向；输入不得反向赋目标角（AB-014）。

---

## 六、验收标准

1. 拖拽距离决定初速，角度仍由发射向量定，力度上限在 `Game`（T1，P1 协同）。
2. 多指不互扰，ui 指不误发射（T2）。
3. letterbox 外按下被硬过滤，无溢出误射（T3，9:16 铁律）。
4. 升级卡点击容差放大，触屏不点错（T4，UI 安全层契约）。
5. 触屏有暂停按钮，键盘 P/Esc 保留（T5）。
6. 投影逆变换有容差且震屏后刷新，输入与 3D 同帧对齐（T6，AB-026）。LSP 0 Error + 官方构建通过。

---

## 七、后续迭代建议

- 与 P4（弹道）协同：T1 蓄力力度与 P4 T1 反弹手感统一调参，避免「轻拖弹软、重拖弹飘」。
- 与 P8（UI）协同：T5 暂停按钮、T4 卡片布局由 P8 视觉契约统一风格（深紫/淡蓝工程风，AB-017）。
- 与 P2（渲染）协同：T6 的 `RefreshProjection` 由 P2 T6 提供，本模块只调用不实现。
- 与 P10（音效）协同：发射/暂停可触发音效，但触发判定在 `Presentation` 而非输入层。


## 八、实施里程碑排期

- **M1（蓄力与过滤，1 周期）**：完成 T1/T3，拖拽距离定初速、letterbox 外硬过滤。Gate：力度上限在 `Game`，溢出误射为零。
- **M2（多指与命中，1 周期）**：完成 T2/T4，多指归属、升级卡放大命中。Gate：ui 指不误发射，触屏不点错卡。
- **M3（触屏暂停，0.5 周期）**：完成 T5，HUD 常驻暂停钮。Gate：键盘 P/Esc 保留。
- **M4（投影容差，0.5 周期）**：完成 T6，`ScreenToGame` 容差 + 震屏刷新。Gate：输入与 3D 同帧对齐。

## 九、回滚与降级预案

若蓄力导致「轻拖弹软」手感差：调 `POWER_PER_PIXEL`/`minP`（规则常量，P1 收敛），不影响角度语义（AB-012）。若多指归属误判：回退为单指优先（首个 touchId 为 aim），T2 仅作优化。投影容差若让边缘误触：收紧 `tolerance`。所有输入层只传意图，任何玩法判定回归 `Game`（AB-027）。

## 十、关键伪代码参考

```lua
-- main.lua HandleTouchBegin
local dx, dy = desX - aimStartX, desY - aimStartY
local dragDist = math.sqrt(dx*dx + dy*dy)
local power = clamp(dragDist * POWER_PER_PIXEL, MIN_P, MAX_P)
local ang = math.atan2(-dy, -dx)  -- 发射向量 = 发射点 - 拖拽点
if not InCanvas(desX, desY) then return end  -- letterbox 外过滤
Game.PointerAim(aimX_game, aimY_game, power, ang)
```
`InCanvas` 与 `ScreenToGame` 共用 CONTAIN 变换与投影逆变换（9:16 铁律 / 倾斜正交输入契约），禁止把设计坐标直接喂 `Game.Pointer*`。


## 附录 A · 跨模块接口契约

- `main.lua`（输入）→ `Game`：只传意图（aim 坐标/蓄力/升级 pick/暂停），不传设计坐标。
- `main.lua` → P8：升级卡/暂停按钮命中区由本模块算，P8 只绘制。
- `Scene3DBackend`（投影）→ `main.lua`：暴露 `ScreenToGame` 与 `RefreshProjection`，输入逆变换共用。
- `main.lua` → P4：`Scene3DBackend.DrawAimTrajectory` 消费蓄力等级，只读快照。

## 附录 B · 验收用例清单

| 用例 | 步骤 | 期望 |
|------|------|------|
| 蓄力 | 短/长拖 | 初速小/大、角度由发射向量 |
| 多指 | 双指 | ui 指不发射 |
| 画布外 | letterbox 点 | 硬过滤、无误射 |
| 卡命中 | 触屏点卡 | 容差吸收、不点错 |
| 暂停钮 | 触屏点 HUD | 暂停/恢复，P/Esc 保留 |

## 附录 C · 风险检查表

- [ ] 设计坐标未直传 Game.Pointer*（倾斜正交输入契约）
- [ ] letterbox 外硬过滤（9:16 铁律）
- [ ] 输入层无玩法判定（AB-027）
- [ ] 卡片/暂停命中区与轨迹互斥（UI 安全层契约）
- [ ] 待发射用发射向量算车头（AB-012），松手切速度朝向


## 十一、设计哲学与反模式

输入手感的第一性原理是「操作意图与设计坐标、玩法坐标三层解耦，且投影变换单一可信」。反模式有三：其一是把屏幕设计坐标直接喂规则层（倾斜正交输入契约 AB-019 禁止），导致 46° 斜视下点击点与真实落点系统性错位；其二是 9:16 非目标屏拉伸或裁切，导致操作区漂移（9:16 铁律）；其三是输入层做玩法判定（如算伤害），破坏 Game 权威规则层纯净（AB-027）。本模块以「先回设计画布 → 再投影逆变换 → 只传意图」三步法，配合蓄力、多指归属、画布外硬过滤，把输入做成可预测的操控界面。触屏适配不是简单映射鼠标，而是多指意图归属 + 命中容差，这是移动端肉鸽幸存者的必要打磨。
