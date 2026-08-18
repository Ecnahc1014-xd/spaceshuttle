# P2 · 渲染表现与 3D 体素美术模块开发计划书

> 版本：v0.9.0 规划 / 草稿 v1
> 模块方向：3D 渲染后端、体素表现、相机、世界边缘、特效承载
> 目标读者：负责 `Renderer3D.lua` / `Scene3DBackend.lua` 的渲染开发者

---

## 一、模块目标

本模块聚焦「把权威快照变成可观赏的 3D 画面」，覆盖：正交斜视相机、敌方体素网格、世界反弹边缘、星空背景、拖尾、载具大运重卡、以及所有「只读消费快照」的视觉呈现。v0.9.0 已落实：46° 倾斜正交相机（`orthoSize=18.0`）、敌方单 `CustomGeometry` 双 section（面 + 棱线）、世界边缘 z=1.45 的三边盒、巨型车拖尾锚定碰撞半径、像素敌人四个剪影。本计划书规划**下一阶段渲染表现力提升**，并明确哪些事「不能做」（避雷）。

核心原则（来自 CLAUDE.md 避雷清单）：`Renderer3D` 与 `Scene3DBackend` **只消费 `Game.GetSnapshot()` 与 `Presentation.GetSnapshot()`，不得反向修改权威状态**；3D 后端体素尺寸必须统一经 `WORLD_SCALE` 映射；每个敌人只允许一个 `CustomGeometry` 根对象，只在存活拓扑或冻结状态改变时重建。

---

## 二、现状与表现力缺口

### 2.1 已达标项
- 相机：正交投影、46° 倾角、CONTAIN 9:16 共享缩放（AB-018 / AB-019 / AB-026）。
- 敌方体素：单 `CustomGeometry`、面+棱线两 section、Z 端面前后必生成、XY 内部侧面可剔除（AB-024 / AB-025）。
- 世界边缘：3D 背景层三边盒 + 2D 边框描线一致（v0.9.0 世界边界契约）。
- 拖尾：巨型车拖尾宽度锚定 `marble.radius * WORLD_SCALE`，不再宽于本体（v0.9.0 拖尾比例契约）。
- 车辆：大运重卡 6 section PBR（漆/侧围/轮胎/金属/玻璃/灯光），显示朝向 420°/s 最短角追踪（大运重卡几何契约 / AB-014）。

### 2.2 表现力缺口（本模块要补）
1. **冻结反馈弱**：冰弹冻结只靠颜色微调，缺少「霜面/结晶体」剪影差异，玩家难辨冻结剩余时间。
2. **越线冲击无空间反馈闭环**：`base_hit` 事件已由 `Presentation` 维护，但 3D 后端对防线材质脉冲、冲击波、相机震屏的承接仍偏薄，需强化「防线被啃咬」的临场感（防线撞击契约）。
3. **体素 Z 厚度立体感不足**：现有体素厚度由 `VOXEL_GAP` 控制，正面主色、背面浅色因子固定，缺少「朝向相机侧的动态高光」让方块更有体积感（AB-016）。
4. **星空与深空底板层次**：当前星空在物体后、底板前，但未做「近大远小视差分层」，3D 星空不能启用 FXAA（AB-008），导致远景偏糊。
5. **拖尾与弹珠本体渐隐**：加速弹高速时拖尾应有速度感渐变，但当前尾段是常量宽度，缺少「运动模糊式衰减」。

---

## 三、架构切面

渲染后端严格只读。所有「瞬时状态」（冻结剩余、冲击脉冲、震屏强度）必须由 `Presentation.lua` 消费领域事件维护，再暴露给 `Presentation.GetSnapshot()`（详见 CLAUDE.md 视觉瞬时状态契约）。渲染层**不得**自己从事件 bus 订阅 `Game.DrainEvents()`——只能读 `Presentation` 快照。这是 AB-013 的硬约束。

文件改动范围：`scripts/Renderer3D.lua`、`scripts/Scene3DBackend.lua`、`scripts/Presentation.lua`。不改动 `Game.lua`（规则数值一律由规则层算好经快照下发）。

---

## 四、具体任务清单

### T1：冻结视觉强化（基于冻结剩余比例）
`Presentation` 新增 `freezePulse` 字段（0..1 反映剩余冻结）；`Renderer3D.RebuildEnemyMesh` 在冻结态时，把体素正面顶点色向冷白偏移，并在棱线 section 叠加更高亮度的霜色带。重建触发条件维持「仅冻结状态改变时」（不每帧重建）。需确认 `Presentation` 的 freeze 计时与 `Game` 的 `freezeDuration + BALL_TUNING.iceBonus` 同源。

### T2：防线冲击反馈闭环
`Presentation` 维护 `baseHitShake`（衰减包络）与 `baseHitFlash`（防线脉冲强度）。`Scene3DBackend` 在 `RenderScene` 后：根据 `baseHitShake` 给相机做极短位移（位移后**必须无日志刷新**投影缓存，AB-026），并让 `CreateWorldEdges` 的底边（若未来扩展四边）或下方警示带按 `baseHitFlash` 提亮；NanoVG 层叠「⚠ 防线受损」短文本（UI 安全层契约：仅非菜单态绘制，且不得与 HUD 几何相交，AB-022）。

### T3：体素体积感
在 `RebuildEnemyMesh` 的面 section，按法线与相机方向点乘给正面加动态高光系数（仍走顶点色，AB-007 白色基底纹理 + VCol Technique）。顶面/侧面维持浅色因子，但依据 46° 相机投影权重微调，避免平光塑料感。

### T4：星空分层（不用 FXAA）
`CreateSpaceEnvironment` 把星点拆为 2 层 `CustomGeometry`（近层粗星、远层细星），均位于游戏物体之后、`Scene3DBackend` 深空底板之前，按层合批（AB-009）。因验证环境禁用 FXAA（AB-008），近层星点可用稍大点精灵，远层用程序化闪烁（经 `Presentation` 时间相位，非随机流）。

### T5：拖尾速度渐隐
`RebuildTrailGeometry` 在尾部对顶点色做 alpha/亮度衰减（基于当前 `marble.speed / def.maxSpeed`），让高速拖尾尾部更淡，强化速度感；宽度仍锚定碰撞半径（v0.9.0 拖尾比例契约，禁止突破）。

### T6：相机震屏投影刷新自动化
把 AB-026 的「震屏后无日志刷新投影」封装为 `Scene3DBackend.RefreshProjection()`，所有相机位移调用点统一走它，避免遗漏导致 3D/Overlay/输入错位（AB-019 / AB-026）。

---

## 五、风险与避雷

- **只读契约**：任何「根据当前血量改颜色」「根据冻结改碰撞」的逻辑，若是规则判定必须在 `Game` 算好经快照；渲染层只读。违反 AB-027 / 视觉瞬时状态契约将破坏分层。
- **禁止逐体素 Node**：敌方仍强制单 `CustomGeometry`；禁止为冻结晶体新增逐棱节点（AB-016 / v0.9.0 体素立体表现契约）。
- **禁止改玩法几何**：`DANGER_Y`、墙体位置、相机 `orthoSize`、46° 倾角不得为美术效果变动，否则破坏 9:16 投影与碰撞一致性（AB-023 / AB-018）。
- **FXAA 不可用**：本环境验证器禁用 FXAA，3D 全黑排查先关后处理（AB-008）。
- **WORLD_SCALE 统一**：所有体素中心间距 = `brickSize * WORLD_SCALE`，`VOXEL_GAP` 只缩小本体不缩中心（v0.9.0 飞机采样权威契约）。

---

## 六、验收标准

1. 冻结敌机在视觉上明显区别于普通敌机，且冻结解除瞬间不出现体素重建闪烁（T1）。
2. 方块越线扣血时，相机有可感知短震屏、防线有脉冲、NanoVG 警示文本出现且不与 HUD 重叠（T2，AB-022）。
3. 体素正面有动态体积高光，但顶点色仍走 VCol Technique，无新增材质（T3，AB-007）。
4. 星空两层合批，无逐星 Node，FXAA 关闭下不黑屏（T4，AB-009 / AB-008）。
5. 加速弹高速拖尾尾部更淡，宽度仍 ≤ 碰撞半径（T5）。
6. 所有相机位移后投影缓存被刷新，输入点击与 3D 模型在同帧对齐（T6，AB-026）。
7. LSP 0 Error + 官方构建通过；`Renderer3D`/`Scene3DBackend` 内无 `Game.` 写入调用（只读断言）。

---

## 七、后续迭代建议

- 与 P3（敌机像素美术）协同：敌机 silhouette 密度变化只改 `AircraftPixelData.lua` 的 occupied cells，本模块渲染自动适配（AB-024 单一数据源）。
- 与 P9（性能）协同：T1/T3 的「仅拓扑/状态改变时重建」需配合 P9 的重建计数监控，防止意外每帧重建。
- 与 P10（音效反馈）协同：T2 的 `baseHitShake` 包络可同步驱动音效触发，但触发判定在 `Presentation`，不在渲染层。


## 八、实施里程碑排期

- **M1（冲击闭环，1 周期）**：完成 T2 防线四位一体反馈，依赖 `Presentation` 的 `baseHitShake`/`baseHitFlash` 已就位。Gate：越线扣血有震屏+脉冲+警示，且不与 HUD 相交。
- **M2（体积与冻结，1 周期）**：完成 T1/T3，冻结色偏移、正面动态高光。Gate：冻结敌机视觉可辨，体素不每帧重建。
- **M3（星空与拖尾，1 周期）**：完成 T4/T5，星空双层合批、拖尾速度渐隐。Gate：FXAA 关闭下不黑屏，拖尾尾部更淡。
- **M4（投影自动化，0.5 周期）**：完成 T6 `RefreshProjection()` 封装。Gate：所有相机位移走统一刷新，输入点击对齐。

## 九、回滚与降级预案

若 VCol 顶点色高光导致某机型着色异常：回退 T3 到固定浅色因子（v0.9.0 行为），保留棱线 section 不变。若星空层导致远景闪烁：禁用远层，仅留近层（仍合批无逐星 Node）。FXAA 相关一律保持关闭（AB-008），任何「开了更清楚」的尝试在本验证环境都会黑屏。所有渲染改动不得回写 `Game` 状态。

## 十、关键伪代码参考

```lua
-- Renderer3D.RebuildEnemyMesh 冻结视觉（只读快照）
if snapshot.enemies[i].frozen > 0 then
  local t = snapshot.enemies[i].freezeRatio -- 0..1 剩余
  faceColor = lerp(faceColor, COLD_WHITE, 0.35 + 0.4*t)
end
-- 仅在拓扑/冻结状态改变时调用本函数（性能契约）
```
冻结色由 `Presentation` 维护的 `freezeRatio` 驱动，渲染层只读；重建触发条件维持「拓扑或冻结态改变」，禁止每帧重建（3D 体素性能契约）。


## 附录 A · 跨模块接口契约

- `Presentation` → 本模块：冻结色由 `Presentation.freezeRatio` 驱动，渲染只读；`baseHitShake`/`baseHitFlash` 由本模块消费做震屏/脉冲。
- 本模块 → P10：震屏包络同时驱动音效触发，但触发在 `Presentation` 不在渲染层。
- 本模块 → P9：重建次数受 `REBUILD_BUDGET` 护栏（P9 T1）约束，不得每帧重建。
- 本模块 → P3：敌机 silhouette 密度变化自动适配，不依赖具体 occupied 比例。

## 附录 B · 验收用例清单

| 用例 | 步骤 | 期望 |
|------|------|------|
| 冻结视觉 | 冰弹命中 | 敌机冷白偏移、解除无闪烁 |
| 越线反馈 | 方块越线 | 震屏+脉冲+警示、不重叠 HUD |
| 体素高光 | 斜视观察 | 正面有体积感、VCol 有效 |
| 星空分层 | 关 FXAA | 两层合批、不黑屏 |
| 拖尾渐隐 | 加速弹高速 | 尾部更淡、宽 ≤ 碰撞半径 |

## 附录 C · 风险检查表

- [ ] 渲染层无 `Game.` 写入调用
- [ ] 单 CustomGeometry、双 section 未破坏
- [ ] 重建仅拓扑/冻结改变触发
- [ ] FXAA 保持关闭（AB-008）
- [ ] `WORLD_SCALE` 统一映射、VOXEL_GAP 只缩本体
