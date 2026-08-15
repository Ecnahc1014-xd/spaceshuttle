<!-- RECOVERY INSTRUCTIONS -->
<!-- 新会话 AI 读到此文件时： -->
<!-- 0. CLAUDE.md 已自动注入 → 已知当前状态和关键避雷 -->
<!-- 1. 读取本文件 → 恢复项目上下文 -->
<!-- 2. 读取 docs/persona.md → 加载助手人格 + 用户偏好 -->
<!-- END RECOVERY INSTRUCTIONS -->

# 项目记忆索引

项目：太空飞机弹珠
当前版本：0.8.4
简述：540×960 竖屏弹弓载具弹珠游戏，采用 46° 正交斜俯视；NanoVG 与 3D Viewport 共用固定 9:16 CONTAIN 画布；相机玩法平面投影统一驱动输入、轨迹与空间反馈；敌方为由用户飞机参考图采样生成的四类单网格低像素体素飞机，我方为随权威碰撞半径缩放的大运式重卡；顶部 76px HUD、playing 态底部 80px Dock 与 menu/gameover modal 形成不透明互斥安全层，四个 64×64 弹夹只在 playing 态左右分组显示。
最后巩固：2026-08-15

## 项目概况
- 技术栈：UrhoX Lua 5.4，单机模式，raw NanoVG 模式 A（540×960 设计分辨率 + letterbox）。
- 核心玩法：四类弹珠、低像素飞机逐块碰撞、波次、基地生命、计分。
- 当前强化玩法：基础弹每次命中独立 5% 概率生成两颗完整分裂弹且可递归；加速弹反弹/命中加速、速度分档增伤并追击最近砖块；巨型弹反弹后武装直径 7 格圆域贯穿。
- 敌方基础下落速度为原来的 25%；冰冻继续在此基础上应用 0.3 倍倍率。
- 分层数据流：引擎事件 → `main.lua` → `Game` 更新/事件 → `Presentation` → snapshot → 渲染后端。

## 关键文件
| 文件 | 用途 |
|------|------|
| `scripts/main.lua` | 纯编排入口；转发引擎输入和 Update，连接核心、表现、后端 |
| `scripts/Game.lua` | 引擎无关的权威规则、碰撞、波次、输入动作、领域事件与游戏快照 |
| `scripts/Presentation.lua` | 消费领域事件，维护粒子、飘字、拖尾、闪白、震屏、波次横幅、防线脉冲与冲击波 |
| `scripts/VisualCatalog.lua` | 当前 2D 后端的弹珠样式和飞机采样砖块颜色映射 |
| `scripts/AircraftPixelData.lua` | 独立低像素飞机 occupied cells、分数、速度倍率与采样 RGB 数据源 |
| `scripts/Renderer3D.lua` | 只读同步四类采样飞机（每个 occupied cell 对应一个可破坏体素，单 `CustomGeometry` 双 section）、大运式平头重卡、双层世界空间拖尾和碎片；每敌人/车辆各一个 `CustomGeometry` |
| `scripts/Scene3DBackend.lua` | 3D Scene/Camera/Viewport、46° 正交斜俯视与 `orthoSize=18.0`、固定 9:16 `IntRect` CONTAIN、相机投影标定、3 批动态视差星层、深空底板、深紫/淡蓝 Laterano 酸性 HUD/四弹药槽/菜单和撞线反馈覆盖层 |
| `scripts/Renderer.lua` | 无规则计算的 NanoVG 绘制器，只消费两个快照 |
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
- D-013: 正交相机改为 38° 斜俯视并将 `orthoSize` 收紧至 16.4；车辆仍保持正交无透视缩放，借助更紧视锥放大整体战场可读性（v0.7.0）。
- D-014: 敌人体素面 section 保留正面主色并将背面/左右/顶部提亮；所有外露面用窄深色 strip 描边，棱线与面合并在同一敌人 `CustomGeometry` 的第二 section（v0.7.0）。
- D-015: HUD、四弹药槽和菜单统一采用 PixelForge 硬边矩形、2px 内描边、零模糊硬阴影、深色表面、高饱和类型色和状态条，继续由 NanoVG 后端只读消费快照（v0.7.0）。
- D-016: 游戏正式更名为“太空飞机弹珠”；UI 改为深紫背景、淡蓝工程线与明紫强调的 Laterano 酸性技术图纸风格，使用网格、刻度光环、工程标注、状态码和半调点阵（v0.8.0）。
- D-017: 540×960 / 9:16 为不可变玩法画布；NanoVG 与 3D `Viewport` 共用 CONTAIN 缩放和居中偏移，输入使用同一逆变换；非 9:16 屏幕只 letterbox，禁止拉伸或裁切（v0.8.0）。
- D-018: 敌方权威砖块尺寸改为 14/15/16，我方分裂/冰冻/加速/巨型权威半径改为 13/13/12/21；模型继续由快照半径映射到 98% 碰撞圆（v0.8.0）。
- D-019: 敌方飞行器底座与推进器统一移到阵列远离玩家的上侧，防线命中只检测阵列底边；3D 与备用 2D 后端保持相同语义（v0.8.0）。
- D-020: 38° 正交相机的玩法 XY 平面投影与 540×960 UI 坐标分离；`Scene3DBackend` 用 `WorldToScreenPoint` 标定线性投影参数，输入逆变换、瞄准轨迹与空间反馈统一使用该参数，并过滤 letterbox 外起始输入（v0.8.1）。
- D-021: 四类权威半径提升为分裂/冰冻 20、加速 18、巨型 30；车辆局部 XY 拟合半径校准为 2.06，并用缩放后的局部 Z 视觉中心补偿保持权威坐标与屏幕模型中心一致（v0.8.1）。
- D-022: 四弹夹统一为 64×64 小正方形，前两格停靠左下、后两格停靠右下，中间保留发射主体和轨迹空间（v0.8.1）。
- D-023: v0.8.2 将敌方视觉统一为六类主题飞机；每敌人仍单 `CustomGeometry`，飞机由尖鼻机身、主翼、尾翼、凸起驾驶舱、双发动机与尾鳍组成；砖块 HP 只存在于 Game 规则层且不进入渲染签名，前六波为 1 HP，7/12 波起提升至 2/3 HP；相机保持 46° 正交斜俯视而非透视，固定 9:16 交互契约不变。
- D-024: v0.8.3 将 HUD、playing Dock、menu/gameover modal 明确为不透明互斥安全层；四弹夹只在 playing 态绘制，非 playing 态不再绘制瞄准轨迹和基地冲击反馈；菜单主光环与 CTA 使用独立几何区，禁止相交。
- D-025: UI/玩法遮挡审查必须先用当前相机 `projectionOffset/Scale` 把权威坐标投影到屏幕设计空间；46° 当前标定约为 `offset=(124.20,159.90), scale=(0.5400,0.6669)`，禁止把 `Game.y` 直接当成屏幕 y 后误改权威危险线或弹弓规则。
- D-026: v0.8.4 敌方数据从 `VeggiePixelData` 完全迁移到独立 `AircraftPixelData`；同一 occupied-cell 清单同时驱动规则砖块、2D 砖块、3D 体素和碎片颜色。3D 中每个 alive cell 生成可见体素并剔除相邻内部面，死亡格直接从网格消失；隐藏 HP 不进入签名。体素中心使用规则 brick pitch，`VOXEL_GAP` 只缩小方块本体，禁止用缩小后的 unit 推导中心造成碰撞/显示漂移。

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
- v0.8.4: 从用户参考截图中的飞机区域采样出独立 `AircraftPixelData`，建立 scout/striker/bomber/interceptor 四套低像素 occupied-cell 网格。`Game`、`VisualCatalog`、备用 2D 后端、`Presentation` 和 `Renderer3D` 全链路改用 `aircraftKey`；3D 每个 alive cell 生成一个真正可破坏体素，相邻格剔除内部面并与深色棱线合并在单敌人双 section `CustomGeometry` 中。修正 voxel gap 只缩小方块、不改变规则中心间距。LSP 0 Error、官方构建成功，受控 GLES 游戏态截图确认飞机方块完整度与场地/UI 比例可读，`lua_errors=0`。
- v0.8.2: 敌方从蔬菜体素阵列重制为六类主题飞机，单 `CustomGeometry` 包含尖鼻机身、主翼、尾翼、凸起驾驶舱、双发动机和尾鳍；砖块 HP 隐藏维护，前六波为 1 HP，后续在第 7/12 波提升；敌方波次数量/速度重新调平；相机保持 46° 正交斜俯视，保留固定 9:16 投影和输入契约；LSP 0 Error，官方构建成功，240 帧 `lua_errors=0`，GLES 竖屏截图 `screenshots/v082_aircraft_perspective.png` 已生成。验证环境仍有音频、shader cache 和两个内置资源错误。
- v0.8.1: 四类权威弹珠半径提升为 20/20/18/30，车辆局部拟合半径校准为 2.06 并补偿负 Z 几何视觉中心；相机玩法平面投影统一驱动 `ScreenToGame`、瞄准轨迹和撞线反馈，letterbox 外按下不再进入玩法；四弹夹改为左下两格、右下两格的 64×64 正方形。合并保留会话外新增的敌方主题飞机和波次节奏调整；LSP 0 Error、正式入口官方构建成功、240 帧 `lua_errors=0`，菜单与受控拖拽 GLES 截图通过。
- v0.8.0: 正式更名为“太空飞机弹珠”；UI 重做为深紫/淡蓝 Laterano 酸性技术图纸风格；NanoVG 与 3D Viewport 共用固定 540×960 CONTAIN，横屏只 letterbox；`orthoSize=18.0` 保证完整场地边缘；敌方权威砖块缩为 14/15/16，我方四类权威半径放大为 13/13/12/21；敌方飞行器底座和推进器移到远离玩家的一侧。LSP 0 Error，正式入口官方构建成功，240 帧 `lua_errors=0`，三组 GLES 截图通过。
- v0.7.0: 38° 正交斜俯视、`orthoSize=16.4`；车辆视觉外轮廓占权威碰撞圆 98%；敌方体素侧面/背面/顶面提亮并在第二 section 增加深色棱线；HUD、弹药槽和菜单采用 PixelForge 硬边像素面板。LSP 0 Error，官方构建成功，240 帧运行时 `lua_errors=0`，GLES 菜单态与受控游戏态截图通过。
- v0.6.1: 车辆目标朝向与显示朝向分离，以 420°/s 沿最短角平滑追踪瞄准向量或飞行速度；车辆缩放改为由 `marble.radius × WORLD_SCALE` 和模型局部 XY 包围半径精确推导，外轮廓固定占权威碰撞圆 94%，移除分裂弹与巨型弹的额外经验倍率。LSP 0 Error，官方构建成功，120 帧运行时 `lua_errors=0`，GLES 截图确认普通车辆不再覆盖弹药槽。
- v0.6.0: 待发射重卡按瞄准发射向量实时转向；正交相机从 20° 提升到 30°，敌人体素加厚并并入立体飞船船体/推进器；车辆重塑为大运式平头高顶、长货厢、三轴六轮重卡，增加浅色独立侧围和 6 PBR section；底部改为四个完整弹药槽；`base_hit` 增加 3D 相机震动、防线材质脉冲、冲击波和警示文字。LSP 0 Error，官方构建成功，GLES 菜单态和斜向瞄准游戏态截图验证通过。
- v0.5.0: 相机保持 `orthographic=true`，从 XY 玩法平面法线向正视方向倾斜 20°，无近大远小；车辆由方块拼贴重建为单 `CustomGeometry` 五分区精品几何，包含倒角棱台车壳、透明驾驶舱、12 段圆柱轮胎与轮毂、金属饰件、自发光灯组；LSP 0 Error，官方构建成功，GLES 菜单态和受控发射游戏态截图验证通过。
- v0.4.0: 修复敌人体素颜色未生效（`DiffVCol` + 白色基底纹理）；以每车一个合并 `CustomGeometry` 重建俯视体素车辆；增加按 `Presentation.marbleTrails` 生成的双层世界空间拖尾；增加 3 批合并动态星层和深空底板；关闭验证环境中会吞掉 3D 画面的 FXAA。Lua LSP 0 Error，官方构建成功，GLES 菜单态与受控发射游戏态截图均验证通过。
- v0.3.1: 将逐体素 `Node + StaticModel` 改为每敌人顶点色 `CustomGeometry` 并剔除内部面；修复固定车辆字符串键长度判断导致的节点泄漏；使用低多边形越野皮卡 MDL 替代简陋基础几何；每个 marble 统一显示车辆本体；本地纹理路径消除 UUID 资源错误；Lua LSP 0 Error，官方构建成功，GLES 菜单截图成功生成。
- v0.3.0: 新增 3D 体素/运输车后端；敌方方块击碎后生成分散、旋转、缩小碎片；四类弹珠绑定四辆运输车；Lua LSP 0 Error，官方构建成功，GLES 截图可生成但 runtime 的 NanoVG shader cache 有错误。
- v0.2.1: 完成常规“双响分裂”、加速“四连撞超载电弧”、巨型“首撞反震后贯穿”；加入一帧内砖块去重、回响弹出生砖忽略与技能领域事件；LSP 0 Error，官方构建成功。
- v0.2.0: 分离核心玩法、表现状态、视觉目录、NanoVG 后端和应用编排。

## 验证记录
- Lua LSP：工作区 Error 0（`Game.lua`、`Renderer3D.lua`、`Scene3DBackend.lua`、`main.lua`）。
- 官方 build：成功，正式入口 `main.lua`，单机模式。
- Runtime v0.8.3：正式入口 240 帧，`lua_errors=0`；验证器仍报告 2 个内置资源错误和软渲染帧耗时错误，未发现用户脚本运行时错误。
- GLES v0.8.3：`screenshots/v083_menu_safe_zones.png` 确认不透明 modal、光环/CTA 分离且菜单态不透出弹夹和车辆；`screenshots/v083_playing_safe_dock.png` 确认危险线、弹弓车辆、瞄准轨迹位于独立 Dock 上方，四槽左右分组且中部状态区清晰。
- 当前 46° 投影标定：`offset=(124.20,159.90)`、`scale=(0.5400,0.6669)`；此值用于解释当前截图，不应硬编码替代运行时 `WorldToScreenPoint()` 标定。

## 下一步
1. 在真实交互中复测放大后的四类权威车辆碰撞、拖拽瞄准、连续反弹、分裂、追击和巨型圆域。
2. 在手机与非 9:16 桌面窗口实测输入边界、letterbox 和深紫/淡蓝酸性 UI 字号。
3. 保持 HUD 与规则层解耦，继续让 3D 后端只消费两个 snapshot。
