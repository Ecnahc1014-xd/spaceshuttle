# P8 · UI/HUD 与幸存者界面模块开发计划书

> 版本：v0.9.0 规划 / 草稿 v1
> 模块方向：HUD、弹药槽、升级三选一 modal、暂停遮罩、菜单/gameover、工程风视觉
> 目标读者：负责 `Scene3DBackend.lua` NanoVG 绘制层与 UI 状态机的开发者

---

## 一、模块目标

本模块负责「玩家看到的信息与菜单」。v0.9.0 已实装：HUD（y=0..76）含等级/经验条、playing Dock（y=880..960）四弹药槽（分裂/冰冻/加速/巨型 64×64，前两格左下后两格右下）、升级三选一卡片（cardW=144,cardH=188,gap=18,cy=470）、暂停遮罩、菜单/gameover modal。本计划书规划**UI 信息密度与幸存者界面完整度**，并固化「UI 安全层 + 像素工程风」双契约。

核心不变量（CLAUDE.md 避雷清单）：
- UI 视觉契约：raw NanoVG 固定 540×960 设计分辨率模式 A，深紫背景、淡蓝工程线/文字、明紫强调；保留技术网格、刻度光环、工程标注、状态码、半调点阵；**禁止恢复蓝白配色、PixelForge 主题或圆角卡片**。
- UI 安全层契约：HUD、playing Dock、menu/gameover modal 以不透明硬边区域遮断世界层；HUD `y=0..76`、Dock `y=880..960`，四槽仅 playing 态绘制；menu/gameover 从 HUD 下缘覆盖至画布底；非 playing 态禁止绘制弹夹、瞄准轨迹、基地冲击反馈；菜单刻度光环不得与 CTA 几何相交。
- 投影审查契约（AB-023）：判断 UI 与玩法遮挡前，先经 `projectionOffset/Scale` 投影，禁止把 `Game.y` 直接当屏幕 `y`。
- 9:16 铁律：NanoVG 与 3D 共用 CONTAIN，letterbox 不拉伸。

---

## 二、现状与界面缺口

### 2.1 已达标项
- HUD 等级/经验条、Dock 四弹药槽、升级卡三选一、暂停遮罩、menu/gameover。
- 工程风（深紫/淡蓝/明紫）、技术网格、刻度光环、工程标注（UI 视觉契约）。
- HUD/Dock/modal 不透明遮断（UI 安全层契约）。

### 2.2 界面缺口
1. **幸存者信息不足**：HUD 缺「当前波次/同屏数/连击」等节奏指标（P6 T6 已暴露快照，UI 未呈现）；升级卡缺「当前→升级后」数值预览（P5 T5）。
2. **升级卡可读性弱**：三卡仅名称+描述，未用工程风「参数面板」呈现 delta；卡片间距在 9:16 下偏挤。
3. **gameover 缺统计回顾**：gameover modal 只显示结束，缺「到达波次/升级数/击碎数/存活时长」回顾，幸存者正反馈缺失。
4. **弹药槽状态模糊**：四槽显示装填态/储备数量，但「当前手持弹型」高亮不清；触屏切换弹型入口（与 P7 协同）未在 UI 体现。
5. **menu 主视觉与 CTA 间距**：刻度光环与 CTA 按钮需几何边界检查，当前未断言不相交（UI 安全层契约）。

---

## 三、架构切面

UI 全在 `Scene3DBackend.lua` 的 NanoVG 绘制（`RenderOverlay` 分发）。绘制只读 `Game.GetSnapshot()` + `Presentation.GetSnapshot()`（AB-027 渲染只读）。交互命中（升级卡/暂停/菜单按钮）由 `main.lua` 调 `Game` 接口（P7）。本模块**不新增规则数值**，只呈现快照字段。文件改动：`scripts/Scene3DBackend.lua`（主）、`scripts/main.lua`（命中区协同，最小）。

---

## 四、具体任务清单

### T1：HUD 节奏指标
`DrawHud` 在等级/经验条旁加「WAVE %02d」「x%d 同屏」「COMBO %d」（读 P6 T6 快照 `wave/concurrentCount/clearStreak`）。布局遵守 HUD `y=0..76` 不透明区，工程标注风格（UI 视觉契约）。

### T2：升级卡参数面板
`DrawUpgradeCard` 用工程风「参数行」展示 `delta`（P5 T5）：如 `伤害 1→2`、`巨型 +1 格`。卡片间距 `gap` 由 18 放宽到 22，cy 保持 470，三卡仍居中。非 levelup 态不绘制（UI 安全层契约）。

### T3：gameover 统计回顾
`DrawGameOver` 增加回顾面板：到达波次、升级数（`upgradePicks` 计数）、击碎砖块数（需 `Game` 暴露 `bricksBroken` 快照字段，规则层累加，本模块只读）、存活时长（规则层计时）。工程风边框，覆盖 HUD 下缘至画布底（UI 安全层契约）。

### T4：弹药槽手持高亮
`DrawDock` 四槽中，当前 `activeBall.ballType` 对应槽加明紫描边 + 脉冲（脉冲由 `Presentation` 瞬时状态，不自己计时）。触屏切换弹型按钮在 Dock 内绘制，命中区交 `main.lua`（P7 T5 协同）。

### T5：menu CTA 几何隔离
`DrawMenu` 的刻度光环绘制后，做「光环包围盒 vs CTA 按钮包围盒」相交断言（调试期 `print` 警告），确保不重叠（UI 安全层契约）。正式绘制时光环自动收缩避让。

### T6：半调点阵与状态码头
在 modal/游戏内常驻「状态码」角标（如 `SYS.PLAY`/`SYS.LVLUP`/`SYS.PAUSE`），用半调点阵点缀（UI 视觉契约），强化工程风沉浸。

---

## 五、风险与避雷

- **禁止圆角卡片/蓝白配色**：升级卡、modal 必须硬边矩形 + 深紫/淡蓝/明紫工程风（UI 视觉契约）。
- **禁止非态绘制玩法反馈**：非 playing 态不得画弹夹、瞄准轨迹、基地冲击反馈（UI 安全层契约）。
- **禁止 UI 与玩法坐标混用**：UI 用设计空间坐标，玩法对象先用投影映射再判遮挡（AB-023）。
- **禁止 9:16 拉伸**：letterbox 外留黑，UI 始终 540×960 设计空间（9:16 铁律）。
- **只读快照**：所有数值来自 `GetSnapshot`/`Presentation`；不得 `Game.` 写（AB-027）。
- **HUD/Dock/modal 不透明遮断**：这些区必须硬边不透明，遮断世界层（UI 安全层契约）。

---

## 六、验收标准

1. HUD 显示波次/同屏/连击，布局在 y=0..76 内（T1，P6 协同）。
2. 升级卡展示数值 delta，工程风参数面板，间距合规（T2，P5 协同）。
3. gameover 含完整统计回顾，覆盖区正确（T3）。
4. 弹药槽手持高亮清晰，触屏切换入口存在（T4，P7 协同）。
5. menu 光环与 CTA 不相交（T5，UI 安全层契约）。
6. 半调点阵/状态码强化工程风（T6，UI 视觉契约）。LSP 0 Error + 官方构建通过；UI 层无 `Game.` 写入。

---

## 七、后续迭代建议

- 与 P5（升级）协同：T2 delta 来自 P5 T5 快照字段，字段名需稳定。
- 与 P6（波次）协同：T1 节奏指标来自 P6 T6 快照。
- 与 P7（输入）协同：T4 切换入口命中区、T5 menu 按钮由 P7 分发。
- 与 P2（渲染）协同：T4 脉冲来自 `Presentation` 瞬时状态（P2 T2），UI 只读。
- 与 P10（音效）协同：modal 切换可触发音效，但触发在 `Presentation`。


## 八、实施里程碑排期

- **M1（HUD 指标，0.5 周期）**：完成 T1，波次/同屏/连击进 HUD。Gate：布局在 y=0..76。
- **M2（升级卡面板，1 周期）**：完成 T2，卡片显数值 delta。Gate：工程风参数行，间距合规。
- **M3（gameover 回顾，1 周期）**：完成 T3，统计回顾面板。Gate：覆盖区正确。
- **M4（手持高亮与 CTA，1 周期）**：完成 T4/T5，弹药槽高亮、menu 光环避让。Gate：CTA 不相交。

## 九、回滚与降级预案

若升级卡 delta 占用过高导致间距挤压：恢复 `gap=18`、delta 改为单行缩写（仍工程风）。若 menu 光环避让失败：T5 改为光环固定收缩到 CTA 包围盒外，不做动态断言。所有 UI 改动保持硬边矩形 + 深紫/淡蓝/明紫（UI 视觉契约），禁止圆角卡片/PixelForge。非 playing 态不得绘制弹夹/轨迹/冲击反馈（UI 安全层契约）。

## 十、关键伪代码参考

```lua
-- Scene3DBackend.DrawUpgradeCard（只读快照）
local choice = snapshot.upgradeChoices[index]
nvgFontFace(vg, "sans"); nvgFontSize(vg, 16)
nvgText(vg, cx, cy+40, choice.name)
nvgFontSize(vg, 12)
nvgText(vg, cx, cy+64, "伤害 "..choice.delta)  -- P5 T5 快照字段
-- 仅 levelup 态绘制，非态不命中（UI 安全层契约）
```
`choice.delta` 由 `Game.GetSnapshot()` 提供，`DrawUpgradeCard` 不计算规则数值（AB-027 渲染只读）。卡片矩形命中区由 `main.TryPickUpgradeAt` 外扩 `HIT_PAD`（P7 T4）。


## 附录 A · 跨模块接口契约

- `Scene3DBackend`（UI）→ `Game`：`DrawXxx` 只读 `GetSnapshot`/`Presentation`，无 `Game.` 写入。
- `Scene3DBackend` → P7：升级卡/暂停/切换命中区由 P7 分发，本模块只绘制矩形。
- `Scene3DBackend` → P5：卡片 `delta` 来自 P5 T5 快照字段。
- `Scene3DBackend` → P6：HUD `wave`/`concurrentCount` 来自 P6 T6 快照。
- `Scene3DBackend` → P2：脉冲来自 `Presentation`（P2 T2），UI 只读。

## 附录 B · 验收用例清单

| 用例 | 步骤 | 期望 |
|------|------|------|
| HUD 指标 | 游玩中 | 波次/同屏/连击可见、在 y0..76 |
| 卡面板 | 升级态 | 显 delta、工程风、间距合规 |
| gameover | 结束 | 含统计回顾、覆盖正确 |
| 手持高亮 | 切弹 | 当前槽明紫描边、触屏可切 |
| menu CTA | 菜单 | 光环不相交 |

## 附录 C · 风险检查表

- [ ] 无圆角卡片/蓝白配色（UI 视觉契约）
- [ ] 非 playing 态不绘弹夹/轨迹/冲击（UI 安全层契约）
- [ ] UI 用设计坐标、玩法对象先投影（AB-023）
- [ ] 9:16 letterbox 不拉伸
- [ ] HUD/Dock/modal 不透明遮断世界层


## 十一、设计哲学与反模式

幸存者 UI 的第一性原理是「信息密度高但不抢戏，工程风沉浸但不喧宾夺主」。反模式有四：其一是圆角卡片 + 蓝白配色，破坏项目既定的深紫/淡蓝工程风视觉契约（UI 视觉契约）；其二是非 playing 态仍绘制弹夹/轨迹/冲击反馈，导致世界层与 UI 层逻辑冲突（UI 安全层契约 AB-022）；其三是把玩法坐标当屏幕坐标判遮挡，导致 UI 压到 gameplay 对象（AB-023 投影遮挡审查）；其四是 HUD/Dock/modal 用半透明叠加而非不透明遮断，世界层透出造成可读性问题。本模块以硬边矩形、不透明安全层、设计空间坐标、工程标注四件套维持 UI 契约，并把波次/升级/统计等幸存者信息以可读方式呈现，强化「太空生存」的临场感。


## 十二、协作依赖图

`P8 UI` 是信息出口，上游依赖 `P5 成长`（卡片 delta）、`P6 波次`（HUD 节奏指标）、`P2 渲染`（脉冲瞬时状态）、`P7 输入`（命中区分发）、`P10 音频`（modal 音效触发在 Presentation）；下游无强依赖，仅自身遵守 UI 视觉契约与 UI 安全层契约。改动 UI 布局时，须确认：①`P7` 命中区与绘制矩形一致，防点不到；②`P5/P6` 快照字段名稳定；③ 非 playing 态不绘玩法反馈（AB-022）。工程风（深紫/淡蓝/明紫、硬边、半调点阵）是所有 UI 改动的不可动摇基调，禁止圆角卡片或 PixelForge 主题回归。
