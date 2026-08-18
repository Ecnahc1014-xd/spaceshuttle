# P3 · 敌机编队与像素美术模块开发计划书

> 版本：v0.9.0 规划 / 草稿 v1
> 模块方向：敌方 occupied-cell 数据源、像素剪影设计、编队几何、碎片颜色
> 目标读者：负责 `AircraftPixelData.lua` 与敌机视觉协调的开发者

---

## 一、模块目标

本模块负责「敌人长什么样、怎么排」。v0.9.0 已把敌方 occupied cells 重写为经典太空飞机像素剪影（蟹形入侵者 / 箭头战机 / 圆盘飞碟 / 截击机），并确立「`AircraftPixelData.lua` 的 occupied cells 是规则砖块、2D 绘制、3D 体素、碎片颜色的唯一共同来源」这一权威契约（飞机采样权威契约）。本计划书规划**下一阶段敌机多样性与编队表现力**，并固化「单一数据源」约束，防止后续开发恢复蔬菜阵列或写实多边形轮廓。

核心不变量（来自 CLAUDE.md 避雷清单）：
- 像素敌人契约：occupied cells 参考经典太空飞机弹幕像素剪影，继续由 `AircraftPixelData.lua` 单一来源驱动规则、2D、3D 与碎片；**禁止恢复战斗机写实轮廓或蔬菜阵列**。
- 体素采样一致性（AB-024）：occupied cells 是规则/2D/3D/碎片唯一共同来源；体素中心用 `brickSize * WORLD_SCALE` 的权威 pitch，`VOXEL_GAP` 只缩本体不缩中心。
- 飞行器底座契约：敌方底座与推进器必须位于阵列远离玩家的一侧（设计坐标上方）；靠近防线的判定只用阵列底边 `enemy.y + height`，2D/3D 后端方向必须一致。

---

## 二、现状与扩展缺口

### 2.1 已达标项
- 四类剪影：scout（蟹形入侵者 12×9）、striker（箭头战机 13×8）、bomber（圆盘飞碟 14×8）、interceptor（截击机 10×10）。
- 同一 `col,row,r,g,b;` 数据格式、`gridW`/`gridH` 不变，使 `Renderer3D.RebuildEnemyMesh` 与 2D 绘制零改动适配。
- 编队整体下移（`enemy.y += vy`），每方块独立越线扣血（v0.9.0 幸存者核心契约）。

### 2.2 扩展缺口
1. **剪影密度单一**：四类敌机 occupied 比例（实心格占网格比）接近，缺少「重型机更密、轻型机更疏」的视觉层次，玩家靠轮廓难秒判威胁。
2. **缺少「编队阵型」概念**：当前每舰是单个 pixel 图，但同一波内多舰排布是随机 x，缺「V 字阵 / 横排阵 / 楔形阵」可识别编队形态，幸存者压迫感弱。
3. **碎片颜色来源未文档化**：`r,g,b` 在 `AircraftPixelData` 定义，但碎片（碎裂粒子）如何消费这些色未明确链路，易在后续被改成全局统一碎片色。
4. **前/后朝向未利用**：蟹形入侵者「眼」朝向应明确指向下方（玩家方向），但当前数据未约束「底座必须在远离玩家侧」的朝向符号，存在误翻风险（飞行器底座契约）。

---

## 三、架构切面

`AircraftPixelData.lua` 是纯数据模块（无引擎调用），它向 `Game`（规则：alive 判定、碰撞拓扑）、`Renderer3D`（3D 体素）、2D 绘制（NanoVG）、`Presentation`（碎片色）四方提供同一份 `occupied cells`。本模块**只改数据定义与少量读取约定**，不引入渲染 API。具体：
- 在 `AircraftPixelData.lua` 增加「阵型元数据」（formation pattern）与「密度档」（density tier），但**不改变 `col,row,r,g,b;` 行格式**，保证下游零改动。
- 编队排布逻辑若需规则层配合（如多舰 x 坐标成阵），放在 `Game.SpawnWave` 读取这些元数据，仍属规则层（AB-027）。

文件改动：`scripts/AircraftPixelData.lua`（主）、`scripts/Game.lua`（阵型读取，最小）、`scripts/Renderer3D.lua`（碎片色消费，最小）、`scripts/Presentation.lua`（碎片色来源，最小）。

---

## 四、具体任务清单

### T1：剪影密度分层
在四类基础上扩展「密度档」字段（不新增行格式，作为每舰附加元数据 `densityTier`）：scout=疏（约 35% 实心）、striker=中（约 50%）、bomber=密（约 65%）、interceptor=极密（约 75%）。用更密的 occupied 表达「更难打穿」，视觉上重型机更厚实。规则层 `DamageBrick` 不依赖密度，密度只影响美术与「看起来更难」的心理预期（不破坏 per-brick 扣血契约）。

### T2：新增两到三类剪影（可选进阶）
在维持像素剪影范式下，增「巡洋舰（长条堡垒形）」「护卫艇（双翼尖锥）」，丰富波次视觉。新增类必须同样遵守「底座在远离玩家侧」「单一数据源」。建议总数控制在 6 类内，避免 `Renderer3D` 分支爆炸。

### T3：编队阵型元数据
为每波/spawn 组增加 `formation` 字段：`line`（横排）、`vee`（V 字）、`wedge`（楔形）、`stream`（纵列）。`Game.SpawnWave` 按 `formation` 计算各舰 `x` 偏移；`enemy.y` 同步下移逻辑不变。阵型只影响初始 x 布局，不影响 per-brick 越线判定（越线仍按 `enemy.y + brick.row*brickSize`）。

### T4：朝向符号固化
在 `AircraftPixelData` 中约定「第 0 行永远指向下方（玩家方向）」，即底座/推进器位于最大 `row` 侧（设计坐标上方）。`Renderer3D` 与 2D 绘制统一按此解释，杜绝误翻。写注释明确「row 增大 = 远离玩家 = 底座端」。

### T5：碎片色链路文档化 + 消费
明确 `Presentation` 在 brick 销毁时，从 `AircraftPixelData` 对应舰类型的 `r,g,b` 取主色生成碎片粒子；`Renderer3D` 不在自身硬编码碎片色。补充单测式断言（调试脚本）验证「同类敌机碎片色一致」。

### T6：编队形态可读化（2D/3D 协同）
NanoVG 2D 边框与 3D 边缘已一致；本模块额外要求：当某编队采用 `vee`/`wedge` 时，可在 2D 设计空间用极淡工程线勾出阵型参考（不破坏 UI 视觉契约——深紫背景、淡蓝工程线，AB-017 像素 UI 契约），帮助玩家预判弹道入射角。

---

## 五、风险与避雷

- **禁止恢复蔬菜/写实**：任何新敌机必须像素剪影，禁止 `VeggiePixelData` 轮廓或完整飞机多边形覆盖逐块缺失（飞机采样权威契约）。
- **禁止破坏单一数据源**：occupied cells 改了，规则/2D/3D/碎片必须同时正确；若某下游不能消费新字段，先改下游再上线，禁止「只改数据不管渲染」（AB-024）。
- **禁止改碰撞拓扑语义**：密度/阵型只改视觉与初始 x，绝不改 `alive` 判定、`DANGER_Y` 越线公式、体素中心 pitch（AB-024 / v0.9.0 幸存者核心契约）。
- **禁止每体素 Node**：3D 仍单 `CustomGeometry`（AB-005 / v0.9.0 体素性能契约）。
- **朝向一致性**：底座端方向在 2D 与 3D 必须一致，否则越线判定与视觉错位（飞行器底座契约 / AB-023 投影遮挡审查）。

---

## 六、验收标准

1. 四类（或六类）敌机 occupied 比例明显分层，重型机视觉更密（T1/T2）。
2. 同波多舰按 `formation` 成可识别阵型，且初始 x 布局不引发越线判定漂移（T3）。
3. 所有敌机剪影第 0 行明确指向下方，2D/3D 朝向一致无翻转（T4）。
4. 碎片粒子颜色与敌机主色同源，无全局统一碎片色回归（T5）。
5. 阵型参考线（若绘制）遵守像素 UI 契约，不与 HUD/modal 相交（T6，AB-022）。
6. LSP 0 Error + 官方构建通过；`AircraftPixelData` 行格式未破坏，下游零回归。

---

## 七、后续迭代建议

- 与 P2（渲染）协同：T1 密度档可被 `Renderer3D` 用于正面/侧面浅色因子微调（仍走顶点色，AB-016）。
- 与 P6（波次节奏）协同：`formation` 与波次阶段绑定（前期 line、后期 wedge），由 P6 的节奏逻辑读取本模块元数据。
- 与 P5（升级池）协同：若未来加「穿甲弹无视密度」，其「密度」概念来自本模块 T1 的 `densityTier`，需保持字段名稳定。


## 八、实施里程碑排期

- **M1（密度分层，1 周期）**：完成 T1，四类敌机 occupied 比例按 `densityTier` 拉开。Gate：重型机视觉更密，规则 `DamageBrick` 不依赖密度。
- **M2（朝向与碎片，1 周期）**：完成 T4/T5，朝向符号固化、碎片色链路文档化。Gate：同类敌机碎片色一致，2D/3D 朝向无翻转。
- **M3（编队元数据，1 周期）**：完成 T3，阵型 `line/vee/wedge/stream` 由 `Game.SpawnWave` 读取。Gate：同波成可识别阵，越线判定不漂移。
- **M4（新增剪影，可选）**：完成 T2，扩至 6 类。Gate：新类遵守单一数据源与底座端约定。

## 九、回滚与降级预案

若新增剪影导致 `Renderer3D` 分支膨胀：保持 4 类，删除 T2 扩展；`densityTier` 仅作元数据不影响下游。若阵型导致初期难度误判：T3 阵型只改初始 x，绝不改 `alive`/`DANGER_Y`，回滚只需让 `SpawnWave` 忽略 `formation` 字段（均匀随机）。occupied cells 行格式（`col,row,r,g,b;`）禁止变更，下游零改动是硬约束。

## 十、关键伪代码参考

```lua
-- AircraftPixelData 单条记录（不变格式）
{ col=3, row=2, r=0.9, g=0.2, b=0.15; }  -- 蟹形入侵者红眼格
-- 元数据包（附加，不破坏行格式）
local META = {
  scout   = { densityTier = "sparse",  base = "down" },
  bomber  = { densityTier = "dense",   base = "down" },
}
```
`base="down"` 约定第 0 行永远指玩家方向；`densityTier` 仅供渲染/心理预期，规则层不消费（保持 per-brick 扣血契约纯净）。


## 附录 A · 跨模块接口契约

- `AircraftPixelData` → `Game`：occupied cells 是 `alive`/碰撞拓扑唯一源；`densityTier` 元数据 `Game` 不消费。
- `AircraftPixelData` → `Renderer3D`：同一 `col,row,r,g,b;` 行格式，3D 体素零改动适配。
- `AircraftPixelData` → `Presentation`：碎片色取 `r,g,b` 主色，禁止全局统一碎片色。
- `formation` 元数据 → P6：`SpawnWave` 读取排阵，不影响 per-brick 越线判定。

## 附录 B · 验收用例清单

| 用例 | 步骤 | 期望 |
|------|------|------|
| 密度分层 | 观察四类 | 重型明显更密 |
| 朝向一致 | 2D/3D 对比 | 第 0 行均指玩家 |
| 阵型排布 | 同波多舰 | vee/wedge 可识别 |
| 碎片同源 | 击碎敌机 | 碎片色=舰主色 |
| 单一数据源 | 改 occupied | 规则/2D/3D 同步 |

## 附录 C · 风险检查表

- [ ] 未恢复蔬菜/写实轮廓（飞机采样权威契约）
- [ ] occupied 行格式未变，下游零回归
- [ ] 密度/阵型未改碰撞拓扑语义
- [ ] 朝向 2D/3D 一致，底座在远离玩家侧
- [ ] 无每体素 Node（AB-005）
