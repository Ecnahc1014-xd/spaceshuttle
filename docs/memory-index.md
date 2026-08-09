<!-- RECOVERY INSTRUCTIONS -->
<!-- 新会话 AI 读到此文件时： -->
<!-- 0. CLAUDE.md 已自动注入 → 已知当前状态和关键避雷 -->
<!-- 1. 读取本文件 → 恢复项目上下文 -->
<!-- 2. 读取 docs/persona.md → 加载助手人格 + 用户偏好 -->
<!-- END RECOVERY INSTRUCTIONS -->

# 项目记忆索引

项目：燃烧的蔬菜
当前版本：0.6.1
简述：540×960 竖屏弹弓弹珠砖块游戏，采用带合并飞船船体的彩色体素敌人、大运式平头重卡弹珠、四弹药槽、双层车辆拖尾和动态深空星场；车辆平滑转向且视觉外轮廓受权威碰撞圆约束。
最后巩固：2026-08-09

## 项目概况
- 技术栈：UrhoX Lua 5.4，单机模式，raw NanoVG 模式 A（540×960 设计分辨率 + letterbox）。
- 核心玩法：四类弹珠、蔬菜像素砖块、波次、基地生命、计分。
- 当前强化玩法：基础弹每次命中独立 5% 概率生成两颗完整分裂弹且可递归；加速弹反弹/命中加速、速度分档增伤并追击最近砖块；巨型弹反弹后武装直径 7 格圆域贯穿。
- 敌方基础下落速度为原来的 25%；冰冻继续在此基础上应用 0.3 倍倍率。
- 分层数据流：引擎事件 → `main.lua` → `Game` 更新/事件 → `Presentation` → snapshot → 渲染后端。

## 关键文件
| 文件 | 用途 |
|------|------|
| `scripts/main.lua` | 纯编排入口；转发引擎输入和 Update，连接核心、表现、后端 |
| `scripts/Game.lua` | 引擎无关的权威规则、碰撞、波次、输入动作、领域事件与游戏快照 |
| `scripts/Presentation.lua` | 消费领域事件，维护粒子、飘字、拖尾、闪白、震屏、波次横幅、防线脉冲与冲击波 |
| `scripts/VisualCatalog.lua` | 当前 2D 后端的弹珠样式和蔬菜砖块颜色映射 |
| `scripts/Renderer3D.lua` | 只读同步带飞船船体的彩色敌人体素、大运式平头重卡、双层世界空间拖尾和碎片；每敌人/车辆各一个 `CustomGeometry` |
| `scripts/Scene3DBackend.lua` | 3D Scene/Camera/Viewport、30° 正交坐标映射、3 批动态视差星层、深空底板、四弹药槽和撞线反馈覆盖层 |
| `scripts/Renderer.lua` | 无规则计算的 NanoVG 绘制器，只消费两个快照 |
| `scripts/VeggiePixelData.lua` | 蔬菜网格、分数、速度倍率与像素数据源 |
| `assets/model/6d5f1062-5bea-5cf8-a404-280333d4d4c8/` | 低多边形越野皮卡 MDL、LOD、diffuse/normal 纹理和材质资源 |

## 有效决策
- D-001: 采用“权威规则快照 + 领域事件 + 表现快照 + 可替换后端”的渐进式分层，不重写现有玩法（v0.2.0）。
- D-002: 逻辑随机数使用 `Game.lua` 内部 Park-Miller PRNG，避免渲染帧率消耗全局 `math.random()` 后改变玩法结果（v0.2.0）。
- D-003: 瞄准轨迹由规则层生成点集，渲染器只画点，避免 2D/3D 后端重复发射公式（v0.2.0）。
- D-004: 当前保留 540×960 设计空间作为玩法坐标；3D 后端负责将其映射到米制世界坐标（v0.2.0）。
- D-005: 敌方存活砖块由每敌人一个顶点色 `CustomGeometry` 组成，仅在拓扑或冻结状态改变时重建；`brick_hit.destroyed` 只在 Presentation 创建临时碎片，碎片不参与规则碰撞（v0.3.1）。
- D-006: 每个 `marble.id` 绑定一个完整车辆表现；待发射、飞行、反弹、碰撞、分裂和巨型弹都走统一车辆同步，规则层仍使用统一发射坐标（v0.3.1）。
- D-007: 车辆不再依赖外部整车 MDL，而以局部 +X 为车头的合并体素 `CustomGeometry` 拼装；四类车辆只换体素调色板，不改变碰撞或弹道（v0.4.0）。
- D-008: 敌人与车辆统一使用 `DiffVCol` + 白色基底纹理保障顶点色；星空按 3 个 `CustomGeometry` 批次动态旋转/漂移/闪烁，置于游戏物体后方（v0.4.0）。
- D-009: 车辆视觉锁定为大运式平头重卡，在单 `CustomGeometry` 中拆为主车漆/浅色侧围/轮胎/金属/玻璃/灯光 6 section；待发射时按发射向量转向，飞行时按速度转向（v0.6.0）。
- D-010: 正交相机提升至 30° 斜俯视，并将敌人体素厚度增至 1.18；敌方飞船船体和推进器并入每敌人现有单网格，不增加逐部件节点（v0.6.0）。
- D-011: `base_hit` 由 Presentation 维护防线脉冲/冲击波状态，3D 后端只读消费为相机震动、材质发光和 HUD 冲击反馈；四弹药槽直接消费 ballQueue/activeBall（v0.6.0）。
- D-012: 车辆记录分离 `targetHeading` 与 `heading`，以 420°/s 沿最短角平滑追踪；视觉 XY 外轮廓统一按程序化模型局部半径映射到 `marble.radius` 权威碰撞圆的 94%，不再按主弹/分裂弹/巨型弹叠加经验缩放（v0.6.1）。

## 活跃系统契约
| 契约 | 文件 | 状态 |
|------|------|------|
| `Game.GetSnapshot()` | `scripts/Game.lua` | 稳定，渲染只读 |
| `Game.DrainEvents()` | `scripts/Game.lua` | 稳定，单次消费 |
| `Presentation.Update(dt, gameSnapshot, events)` | `scripts/Presentation.lua` | 稳定 |
| `Presentation.GetSnapshot()` | `scripts/Presentation.lua` | 稳定，渲染只读 |
| 后端 `Init/Shutdown/Resize/ScreenToGame/Render/GetDesignSize` | `scripts/NanoVGBackend.lua` / `scripts/Scene3DBackend.lua` | 2D 与 3D 后端保持同等编排职责 |

## 避雷清单
- TodoWrite 必须前置创建并包含 DEV + POST-1/2/3。
- `Game.lua` 禁止出现任何渲染 API、引擎对象、视觉参数或输入枚举。
- 不要让 renderer 自行重算瞄准轨迹或硬编码蔬菜 7×7 尺寸；尺寸来自快照中的 `gridW/gridH`。
- 不要向 NanoVG context 注入自定义字段传递状态。
- 不要用全局 `math.random()` 同时驱动玩法与画面；玩法使用独立随机流。
- 会话外修改可能与当前任务并发；写后若内容变化，必须重读并合并。
- headless 验证器当前会因自带 shader cache 字节码报 engine error；判断脚本时需关注 `lua_errors=0`、`resource_errors=0` 并结合 GLES 截图

## 最近变更
- v0.6.1: 车辆目标朝向与显示朝向分离，以 420°/s 沿最短角平滑追踪瞄准向量或飞行速度；车辆缩放改为由 `marble.radius × WORLD_SCALE` 和模型局部 XY 包围半径精确推导，外轮廓固定占权威碰撞圆 94%，移除分裂弹与巨型弹的额外经验倍率。LSP 0 Error，官方构建成功，120 帧运行时 `lua_errors=0`，GLES 截图确认普通车辆不再覆盖弹药槽。
- v0.6.0: 待发射重卡按瞄准发射向量实时转向；正交相机从 20° 提升到 30°，敌人体素加厚并并入立体飞船船体/推进器；车辆重塑为大运式平头高顶、长货厢、三轴六轮重卡，增加浅色独立侧围和 6 PBR section；底部改为四个完整弹药槽；`base_hit` 增加 3D 相机震动、防线材质脉冲、冲击波和警示文字。LSP 0 Error，官方构建成功，GLES 菜单态和斜向瞄准游戏态截图验证通过。
- v0.5.0: 相机保持 `orthographic=true`，从 XY 玩法平面法线向正视方向倾斜 20°，无近大远小；车辆由方块拼贴重建为单 `CustomGeometry` 五分区精品几何，包含倒角棱台车壳、透明驾驶舱、12 段圆柱轮胎与轮毂、金属饰件、自发光灯组；LSP 0 Error，官方构建成功，GLES 菜单态和受控发射游戏态截图验证通过。
- v0.4.0: 修复敌人体素颜色未生效（`DiffVCol` + 白色基底纹理）；以每车一个合并 `CustomGeometry` 重建俯视体素车辆；增加按 `Presentation.marbleTrails` 生成的双层世界空间拖尾；增加 3 批合并动态星层和深空底板；关闭验证环境中会吞掉 3D 画面的 FXAA。Lua LSP 0 Error，官方构建成功，GLES 菜单态与受控发射游戏态截图均验证通过。
- v0.3.1: 将逐体素 `Node + StaticModel` 改为每敌人顶点色 `CustomGeometry` 并剔除内部面；修复固定车辆字符串键长度判断导致的节点泄漏；使用低多边形越野皮卡 MDL 替代简陋基础几何；每个 marble 统一显示车辆本体；本地纹理路径消除 UUID 资源错误；Lua LSP 0 Error，官方构建成功，GLES 菜单截图成功生成。
- v0.3.0: 新增 3D 体素/运输车后端；敌方方块击碎后生成分散、旋转、缩小碎片；四类弹珠绑定四辆运输车；Lua LSP 0 Error，官方构建成功，GLES 截图可生成但 runtime 的 NanoVG shader cache 有错误。
- v0.2.1: 完成常规“双响分裂”、加速“四连撞超载电弧”、巨型“首撞反震后贯穿”；加入一帧内砖块去重、回响弹出生砖忽略与技能领域事件；LSP 0 Error，官方构建成功。
- v0.2.0: 分离核心玩法、表现状态、视觉目录、NanoVG 后端和应用编排。

## 验证记录
- Lua LSP：工作区 Error 0。
- 官方 build：成功，入口 `main.lua`，单机模式。
- GLES 比例修复态：`screenshots/vehicle-collision-fit.png`，确认普通车辆从旧版百像素级外轮廓缩至约 18 像素碰撞直径内，不再侵入弹药槽；数值校验 speed/normal/ice/giant 四类视觉半径均为对应碰撞半径的 94%。
- 最短角数值校验：`170° → -170°` 首步为 `+7°`，`-170° → 170°` 首步为 `-7°`，确认跨 ±180° 不会反向绕行。
- Runtime：120 帧 `lua_errors=0`；非零 validate 退出仍来自环境自带 shader cache，GLES surfaceless 截图退出码 0。

## 下一步
1. 在真实交互中复测四类大运重卡的拖拽瞄准、连续反弹、分裂、追击和巨型圆域。
2. 根据设备实机观感微调 30° 斜俯视下的重卡比例、浅色侧围、玻璃反射、拖尾长度与撞线反馈强度。
3. 保持 HUD 与规则层解耦，继续让 3D 后端只消费两个 snapshot。
