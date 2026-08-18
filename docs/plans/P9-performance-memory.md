# P9 · 性能优化与内存管理模块开发计划书

> 版本：v0.9.0 规划 / 草稿 v1
> 模块方向：体素重建频次、CustomGeometry 批处理、节点生命周期、GC 压力、帧预算护栏
> 目标读者：负责 `Renderer3D.lua` / `Scene3DBackend.lua` 性能的开发者

---

## 一、模块目标

本模块负责「游戏跑得稳、不掉帧、不漏内存」。v0.9.0 已确立严苛性能契约：每个敌人只一个 `CustomGeometry` 根对象（面+棱线两 section），只在存活拓扑或冻结状态改变时重建（禁止每体素 Node / 每帧重建）；3D 星空按层合批、禁止每星 Node；顶点色体素用 VCol Technique + 白色基底纹理。本计划书规划**下一阶段性能护栏与内存可观测性**，并固化「禁止逐体素/逐星 Node、只在拓扑改变时重建」的硬约束。

核心不变量（CLAUDE.md 避雷清单）：
- 3D 体素性能契约：每个敌人只允许一个 `CustomGeometry` 根对象，但允许同一对象内使用面与棱线两个 section；**只在砖块存活拓扑或冻结状态改变时重建，禁止每体素创建 Node + StaticModel**。
- 体素立体表现契约：正面主色、背面/左右/顶面浅色因子；每个暴露面窄深色棱线 strip，棱线与面共用敌人单一 `CustomGeometry` 第二 section，禁止新增逐棱节点。
- 3D 星空必须位于游戏物体后、深空底板前，按层合批；禁止每颗星创建 Node（AB-009）。
- 顶点色体素必须使用支持 VCol 的 Technique 并绑定白色基底纹理（AB-007）。
- 3D 星空当前验证环境不可启用 FXAA，否则 ESSL shader cache 失败会吞掉整层 3D 画面（AB-008）。
- 显式释放：`Dispose()` 立即释放 Node/Component/File 等（规则 #15）。

---

## 二、现状与性能缺口

### 2.1 已达标项
- 单 `CustomGeometry` 敌方、双 section、拓扑/冻结改变时重建。
- 星空双层合批、无逐星 Node。
- 顶点色 VCol + 白基底纹理。
- `WORLD_SCALE` 统一体素尺寸映射。

### 2.2 性能缺口
1. **重建无计数护栏**：`RebuildEnemyMesh` 调用点无「每帧重建次数」上限，极端同屏 + 频繁冻结切换可能单帧重建爆炸（P6 T3 动态上限放大后风险更高）。
2. **拖尾重建频次**：`RebuildTrailGeometry` 是否每帧重建未明确；加速弹高速下拖尾顶点若每帧全量重建，是隐性热点。
3. **碎片生命周期**：`Presentation` 维护碎片，`Renderer3D` 消费；碎片粒子若用独立 Node/Component 池未文档化，可能 GC 抖动。
4. **快照分配压力**：`GetSnapshot()` 每帧构造新 table，含 `upgradeChoices` 子表，高频 GC；可复用快照缓冲。
5. **资源未显式释放**：敌机销毁、`Dispose` 调用点未审计，长期游玩可能有残留 `CustomGeometry` 未释放（规则 #15）。
6. **FXAA 禁用黑屏风险**：AB-008 已知，但无「启动期自动探测并关 FXAA」机制，依赖人工。

---

## 三、架构切面

性能治理在渲染后端（`Renderer3D`/`Scene3DBackend`）与 `Presentation`（碎片生命周期）。规则层 `Game` 不感知渲染性能（AB-027），但可提供「拓扑版本号」让渲染层判断是否需要重建（不强制）。本模块：
- `Renderer3D.lua`：重建护栏、拖尾节流、碎片对象池、显式 `Dispose`。
- `Scene3DBackend.lua`：FXAA 探测关闭、星空合批校验。
- `Game.lua`（最小）：`GetSnapshot` 复用缓冲（可选）。
- `Presentation.lua`：碎片生命周期 + 对象池。

---

## 四、具体任务清单

### T1：重建频次护栏
在 `Renderer3D` 增加 `rebuildBudget`（每帧最大重建数，默认 4）。`UpdateEnemies` 渲染同步时，若待重建敌机数 > 预算，超额延到下一帧（保证单帧不卡）。重建触发条件维持「仅拓扑/冻结改变」（不放松契约）。

### T2：拖尾节流重建
`RebuildTrailGeometry` 改为「仅在 `marble.speed` 跨阈值档（如每 60 速度一档）或 `ballType` 改变时重建」，非每帧；顶点色渐隐（P2 T5）在档内用 uniform/顶点色缓存，不触发几何重建。

### T3：碎片对象池
`Presentation` 碎片用固定大小对象池（`maxParticles` 默认 256），复用而非新建；`Renderer3D` 消费池内活跃碎片，销毁时回收进池。禁止为单个碎片创建 Node（AB-009 精神延伸）。

### T4：快照缓冲复用
`Game.GetSnapshot` 若每帧分配，改为复用模块级 `snapshotBuf`，仅更新字段（Lua table 复用）。`upgradeChoices` 子表同样复用，避免高频 GC。需确认下游不持有旧快照引用（只读语义）。

### T5：显式释放审计
审计敌机销毁路径：敌机 `dead`/`alive=false` 全清后，`Renderer3D` 对应 `CustomGeometry` 调 `Dispose()`；场景切换/重开时批量 `Dispose` 残留节点（规则 #15）。补充调试计数「活跃 CustomGeometry 数」。

### T6：FXAA 自动探测关闭
`Scene3DBackend` 初始化时检测渲染后端是否支持 FXAA；若当前验证环境（AB-008）报 shader cache 失败特征，自动关 FXAA 并用无后处理兜底，避免 3D 全黑。记录到日志（非每帧）。

---

## 五、风险与避雷

- **禁止每体素/每星 Node**：所有体素/星点必须合批 CustomGeometry（3D 体素性能契约 / AB-009 / AB-005）。
- **禁止每帧重建**：重建只在拓扑/冻结改变；T1/T2 节流不得放松此契约，仅限制单帧数量（护栏不放松语义）。
- **禁止破坏 VCol**：顶点色仍 VCol + 白基底（AB-007）。
- **禁止启用 FXAA（验证环境）**：T6 仅在探测到失败时关闭，默认仍尊重引擎配置（AB-008）。
- **禁止渲染层改规则**：性能护栏不引入 `Game` 玩法判定（AB-027）。
- **显式释放**：销毁必 `Dispose`，防内存泄漏（规则 #15）。

---

## 六、验收标准

1. 单帧敌机重建 ≤ `rebuildBudget`，极端同屏不卡（T1）。
2. 拖尾非每帧重建，仅在速度档/类型改变时（T2，P2 T5 协同）。
3. 碎片走对象池，无逐碎片 Node（T3）。
4. 快照缓冲复用，GC 压力下降（T4）。
5. 敌机销毁显式 `Dispose`，活跃 CustomGeometry 计数稳定（T5，规则 #15）。
6. FXAA 失败自动关闭兜底，3D 不黑屏（T6，AB-008）。LSP 0 Error + 官方构建通过；无每体素/每星 Node 回归。

---

## 七、后续迭代建议

- 与 P6（波次）协同：T1 预算需覆盖 P6 T3 动态同屏上限（≤22 护栏），二者数值对齐。
- 与 P2（渲染）协同：T2 拖尾节流与 P2 T5 渐隐共享档位；T3 碎片池被 P2 特效消费。
- 与 P3（敌机）协同：拓扑改变触发来自 P3 的 occupied cells 变化（如 future 动态损毁），重建条件一致（AB-024）。
- 与 P10（音效）协同：T5 释放不影响音效资源（音效由 `Presentation` 管理，独立于 3D 节点）。


## 八、实施里程碑排期

- **M1（重建护栏，1 周期）**：完成 T1，单帧重建 ≤ 预算。Gate：极端同屏不卡。
- **M2（拖尾与碎片，1 周期）**：完成 T2/T3，拖尾节流、碎片对象池。Gate：无逐碎片 Node。
- **M3（快照复用，0.5 周期）**：完成 T4，快照缓冲复用。Gate：GC 压力下降。
- **M4（释放与 FXAA，1 周期）**：完成 T5/T6，显式 `Dispose`、FXAA 自动关。Gate：活跃节点计数稳定。

## 九、回滚与降级预案

若重建预算导致视觉延迟（敌机冻结切换晚一帧）：放宽 `rebuildBudget` 至 6，仍限单帧。若拖尾节流出现跳变：细化速度档（每 30 一档）。FXAA 探测若误关正常环境：仅当日志出现 AB-008 所述 shader cache 失败特征才关，否则尊重引擎配置。所有性能治理不放松「单 CustomGeometry / 仅拓扑重建 / VCol」契约。

## 十、关键伪代码参考

```lua
-- Renderer3D 重建护栏
local budget = REBUILD_BUDGET
for _, e in ipairs(dirtyEnemies) do
  if budget <= 0 then break end
  RebuildEnemyMesh(e); budget = budget - 1  -- 超额延下帧
end
-- 触发条件：仅拓扑或冻结态改变
if e.topologyVersion ~= e.lastBuiltVersion or e.frozen ~= e.lastBuiltFrozen then
  e.dirty = true
end
```
`topologyVersion` 可由 `Game` 暴露（规则层不感知渲染，仅给版本号）；重建仍单 `CustomGeometry`、双 section（3D 体素性能契约）。碎片走 `Presentation` 对象池（T3），禁止逐碎片 Node（AB-009）。


## 附录 A · 跨模块接口契约

- `Renderer3D`（性能）→ `Game`：可要拓扑版本号，不感知渲染预算。
- `Renderer3D` → P6：重建预算覆盖 P6 动态同屏上限（≤22）。
- `Renderer3D` → P2：拖尾节流与 P2 T5 渐隐共享速度档。
- `Presentation` → P9：碎片对象池由本模块消费，禁止逐碎片 Node。
- `Scene3DBackend` → P9：FXAA 探测关闭兜底。

## 附录 B · 验收用例清单

| 用例 | 步骤 | 期望 |
|------|------|------|
| 重建护栏 | 22 同屏+冻结 | 单帧重建 ≤ 预算 |
| 拖尾节流 | 加速弹 | 非每帧重建 |
| 碎片池 | 大量碎裂 | 复用、无逐碎片 Node |
| 快照复用 | 长跑 | GC 压力下降 |
| FXAA | 验证环境 | 失败自动关、不黑屏 |

## 附录 C · 风险检查表

- [ ] 无每体素/每星 Node（3D 体素性能契约 / AB-009）
- [ ] 重建仅拓扑/冻结改变，护栏不放松语义
- [ ] VCol + 白基底未破坏（AB-007）
- [ ] FXAA 默认尊重引擎、仅失败关（AB-008）
- [ ] 销毁显式 Dispose（规则 #15）


## 十二、协作依赖图

`P9 性能` 是稳健底座，上游依赖 `P3 敌机`（拓扑改变触发重建）、`P2 渲染`（拖尾/体积感重建频次）、`P6 波次`（动态同屏上限护栏）、`P10 音频`（音源 Dispose 同步）；下游保障所有模块不卡顿。改动性能护栏时，须确认：①`P3` 单 CustomGeometry/双 section 契约不被破坏；②`P6` 动态上限 ≤ 本模块护栏；③`P10` 碎片/音源对象池复用，无逐节点创建。FXAA 在本验证环境必须保持关闭（AB-008），任何「开了更清楚」的尝试都会黑屏，属已知陷阱而非可优化项。
