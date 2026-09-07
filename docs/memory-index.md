<!-- RECOVERY INSTRUCTIONS -->
<!-- 新会话 AI 读到此文件时： -->
<!-- 0. CLAUDE.md 已自动注入 → 已知当前状态和关键避雷 -->
<!-- 1. 读取本文件 → 恢复项目上下文 -->
<!-- 2. 读取 docs/persona.md → 加载助手人格 + 用户偏好 -->
<!-- END RECOVERY INSTRUCTIONS -->

# 项目记忆索引

项目：太空飞机弹珠
当前版本：0.10.5
简述：540×960 竖屏弹弓载具弹珠 + 肉鸽幸存者循环，采用 46° 正交斜俯视；敌方 occupied cells 以 `VOXEL_DEPTH=2.10` 的更厚箱体表现，正面使用箱体纹理、侧面按面向明暗；命中方块强制置于敌体前侧，以独立箱体进行世界 Z 抛射、X/Y/Z 多轴旋转、快速入场和末段缩放淡出；SpawnWave 和移动阶段都执行二维 AABB 防重叠；NanoVG Overlay 每帧重置状态；当前不绘制预瞄线和弹珠尾迹。
最后巩固：2026-09-03

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
| `scripts/Presentation.lua` | 消费领域事件，维护粒子、飘字、撞飞箱体、闪白、震屏、波次横幅、防线脉冲与冲击波 |
| `scripts/VisualCatalog.lua` | 当前 2D 后端的弹珠样式和飞机采样砖块颜色映射 |
| `scripts/AircraftPixelData.lua` | 独立低像素飞机 occupied cells、分数、速度倍率与采样 RGB 数据源 |
| `scripts/Renderer3D.lua` | 只读同步四类采样飞机（每个 occupied cell 对应一个可破坏体素，单 `CustomGeometry` 双 section）、官方木箱材质、放大大运式平头重卡、撞飞独立箱体；每敌人/车辆各一个 `CustomGeometry` |
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
- D-033: v0.9.1 冻结表现：渲染层只读 `enemy.freezeRatio`（Game 快照 0..1），按量化档位（×8）进签名触发顶点色冷白偏移与正面霜冻白高光；禁止每帧衰减重建（WO-13/P2）。
- D-034: v0.9.1 高频视觉对象（粒子/碎片/飘字）从 `particlePool/debrisPool/floatPool` 复用 table，`Game.GetSnapshot()` 复用常驻 `snapshotBuffer_`；`RemoveNode` 显式 `Dispose()`；FXAA 仅探测且默认关闭（WO-16/P9）。
- D-035: v0.9.1 `Presentation.FEEDBACK_MAP` 声明式事件→反馈分派；防线四位一体（震屏+危险带脉冲+冲击波+警示文字）由 `base_hit` 单点触发；`Backend.RefreshProjection/GetProjection` 封装投影刷新（WO-14/15/P2）。
- D-036: v0.9.1 词条系统 `BALL_WORDS`（pierce/chain/momentum/lifesteal/heavy）经 `CreateMarble(words)` 注入行为标记，`activeWords` 由专属升级写入、新弹珠自动携带；五异常反应（burn/shock/corrode/freeze/volatile，冻结+灼烧=融穿、寿终 volatile=邻格引爆）仅规则层结算 DoT/反应（P11）。
- D-037: v0.9.1 Boss 阶段机：每 10 波 `SpawnWave` 生成单支高血量 Boss，`bossPhase` 按存活砖块比例切换，`phase 2` 置 `vulnerable` 受 1.5x 伤害；仅规则层，视觉消费 `boss_spawn`/`boss_phase`（P11）。
- D-038: v0.9.1 命中顿帧 `hitStop` 由大命中触发、main.lua 对玩法 dt 打折（×0.15）；防线受创时 `camera_.orthoSize=18.0 - flash*1.6` 瞬时推近仍保持正交；词条图标 HUD 展示（P12）。
- D-027: v0.8.5 瞄准轨迹首点固定为当前 `activeBall.x/y`，采样提升为 140×8，并按权威半径预测左右/顶部反弹；46° 相机每帧震屏位移后无日志刷新玩法平面投影，使车辆、NanoVG 与输入共享当前相机标定。飞机 occupied cells 仅使用 XY 二维邻接剔除内部侧面，每个存活格的前后 Z 端面始终生成。
- D-028: v0.9.0 实装肉鸽幸存者最小完整循环——`BASE_HP=100`，敌方编队整体下移、每个存活方块越过 `DANGER_Y` 独立销毁并扣 `BRICK_BASE_DAMAGE`（受升级影响），`Game` 用 `levelup`/`paused` 状态暂停玩法；XP（击碎方块 +1、清整支飞船 +8 与连击）跨级累计升级并冻结经验，三选一强化池 `UPGRADE_POOL` 的 `apply()` 只改规则变量；持续收紧波次并受 `MAX_CONCURRENT` 同屏上限约束；世界反弹边缘渲染到 3D 背景层与 2D 设计空间边框；巨型车拖尾宽度锚定权威半径不再宽于本体；加速弹成长/追击/伤害削弱；敌方 occupied cells 重制为经典蟹形入侵者/箭头战机/圆盘飞碟/截击机像素剪影。

- D-039: v0.9.3 UI 结构重构：实机截图暴露的视觉问题按信息架构解决，不再追加孤立装饰。playing 态固定为顶部 92px 战术仪表盘、中央战场、底部 94px 火控舱；首页与升级模态改用 Laterano 蓝白高对比主视觉，冷白背景承载克莱因蓝主块，金色仅作焦点；升级卡统一 156×214、gap=8、cy=478，`main.lua` 点击命中同步同一几何参数；玩法规则、3D 投影和 9:16 CONTAIN 不变。

- D-040: 3D 消失根因是 NanoVG 渲染事件位于 3D Viewport 之后，旧 `DrawFullFrameBackground` 用整屏不透明填充覆盖设计画布；修复为 `DrawLetterboxBackground`，只填充 CONTAIN 画布外区域，`Backend.Render` 保持 `Renderer3D.Render` → `RenderOverlay` 顺序。
- D-041: 主循环必须在 `Game.Update` 后重新获取快照，再把同一更新后快照传给 `Presentation.Update` 和渲染；升级触发后 `Game.Update` 立即状态中断；升级同帧新增 XP 使用 `deferredXp` 原值缓冲，最后一张升级卡后只结算一次倍率。
- D-042: UI 统一 Astroon 蓝紫主题，不允许首页蓝白、升级白卡、结算深紫、暂停黑 overlay 混搭；token 为深蓝紫渐变、紫色 surface、蓝/青强调、白字、金色焦点。升级点击使用 `ScreenToUi`，玩法瞄准使用 `ScreenToGame`。

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
- v0.9.4: 修复 3D 渲染失灵根因：NanoVG 从整屏不透明背景改为仅填充 CONTAIN 画布外 letterbox，保护 3D Viewport；`Backend.Render` 保持 `Renderer3D.Render` → `RenderOverlay`；修复主循环更新前快照滞后、升级点击使用错误玩法逆投影、跨画布释放残留瞄准状态、升级/游戏结束同帧继续推进以及升级同帧 XP 丢失；新增 `deferredXp` 原值缓冲；全页面统一 Astroon 深蓝紫渐变、紫色 surface、蓝/青强调、白字与金色焦点。LSP 0 Error、官方 build 成功、菜单态 GLES 截图成功；战斗态探针受沙箱落盘限制未完成，代码级确认渲染顺序和 Viewport 合成。
- v0.9.3: 按实机截图反馈重构 UI 信息架构：playing 态改为顶部 92px 战术仪表盘、中央战场、底部 94px 火控舱；修复画布外大块黑边；首页改为 Laterano 蓝白高对比视觉，增加主 CTA、任务参数块、半调点阵与分段规则线；升级模态改为可读的三张 156×214 蓝白强化卡，点击命中同步 `main.lua` 的 cardW/cardH/gap/cy；保持玩法规则、46° 正交投影和 540×960 9:16 CONTAIN 不变。LSP 0 Error、官方 build 成功、GLES 首页截图确认，运行时 `lua_errors=0`，环境资源错误与 llvmpipe 帧尖峰已记录。
- v0.9.2: A 组纯代码打磨（用户要求先做可感知度提升，音频/美术等需生成 MCP 的 B 组与需用户放宽酸性 UI 契约的 C 组暂缓）。A3 敌人行为分化：`AircraftPixelData.behavior` 增加 scout/striker/bomber/interceptor 的 swayAmp/swayFreq/descentMul/agility/accent，`Game.CreateEnemy` 消费并加随机抖动。A1/A2 四模态 EaseOutCubic 淡入（`ModalIntro`/`nvgGlobalAlpha`）+ 波次横幅 `DrawWaveBanner` 顶部滑入淡出。A4 `DrawMarbleTrails` 按 `SLOT_COLORS[ballType]` 投影四色拖尾。A5 `DrawWaveThemeTint` 酸性风格内按波次色相旋转低 alpha 背景氛围。A6 `FindBoss`/`DrawBossPhaseBar` 阶段条 + 危险带 Boss 波常驻紫色警示。LSP 0 Error、官方构建成功、契约守门通过（Game 无渲染 API、表现层无 Game 写回、FXAA 仅探测默认关闭）。提交 2c2a37c。
- v0.9.1: WO-13/16/14/15 + P11/P12 实装。冻结顶点色偏移+正面霜冻高光、粒子/碎片/飘字对象池+快照缓冲复用+Dispose 审计+FXAA 探测关闭、FEEDBACK_MAP 反馈映射、防线四位一体、RefreshProjection 封装、词条系统(贯穿/连锁/动量)、五异常反应(冻结+灼烧=融穿/易暴/腐蚀)、Boss 阶段机(每10波 vulnerable 窗口)、命中顿帧(hitStop 对玩法 dt 打折)、相机推近(orthoSize 下沉)、词条图标 HUD 展示。LSP 0 Error、官方构建成功、契约守门通过。提交 cfe55e7 + 记忆 6927a72。
- v0.9.0: 肉鸽幸存者化最小完整循环实装。基地生命改 100；敌方编队整体下移、每个存活方块独立越线销毁并扣 `BRICK_BASE_DAMAGE`；XP（方块+1/清机+8 与连击）跨级累计并冻结，三选一强化池 `UPGRADE_POOL`（穿甲/重型/裂变/疾速/深寒/维修/装甲/数据回收）只改规则变量；持续涌出波次随波次收紧并受 `MAX_CONCURRENT` 上限约束；P/Esc 暂停、`levelup` 暂停选强化并暴露 `upgradeChoices` 给 UI；世界反弹边缘渲染到 3D 背景层与 2D 设计空间边框；巨型车拖尾宽度锚定权威半径不再宽于本体；加速弹 `speedBoost` 1.06/`maxSpeed` 900/`maxDamage` 2 且追击节流 0.45s；敌方 occupied cells 重制为经典蟹形入侵者/箭头战机/圆盘飞碟/截击机像素剪影。LSP 0 Error、正式入口官方构建成功（本环境无 headless 运行器，受控 GLES 截图需用户在预览中确认）。
- v0.8.5: 修复瞄准轨迹遗漏车辆中心首点、短距离采样和墙边折返点可读性，改为 140 个 8 单位采样；相机震屏位移后即时刷新 `WorldToScreenPoint` 标定，使 3D 车辆、NanoVG 轨迹与输入逆映射继续共享当前投影。修复二维飞机 occupied-cell 邻接误用于 Z 方向，恢复每块正反端面，同时保留 XY 内部面剔除。巨型车继续由半径 30 对普通半径 20 形成安全的 1.5×。LSP 0 Error、正式入口官方构建成功、240 帧 `lua_errors=0`；受控截图 `fix_controlled_aim.png` 与 `fix_controlled_giant.png` 通过。
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

- D-043: 预瞄线和拖尾对不上的根因不是玩法轨迹，而是 3D 车辆根节点、3D 拖尾、2D 拖尾和 NanoVG 预瞄使用了不同的 Z/投影锚点。3D 车辆根节点继续使用 `GetVehicleAnchorWorld(marble)` 的局部中心补偿；2D 预瞄通过 `Renderer3D.GetVehicleAnchor()` 复用实际车辆根锚点；2D/3D 拖尾通过 `GetTrailAnchor()` 和统一 `TRAIL_DEPTH_OFFSET` 复用拖尾锚点；3D 拖尾首点与当前车辆一致；投影标定保留 `WorldToScreenPoint()` 的运行时原点/轴增量。

- D-045: 新需求废弃旧预瞄/拖尾产品方向：Game 不再生成 `aimTrajectory`，2D Renderer、Scene3DBackend 和 Renderer3D 均不绘制预瞄线/弹珠尾迹；拖拽输入仍保留为发射控制。
- D-046: 敌方命中采用“箱体脱离”规则：`EjectBrick` 将砖块标记 `alive=false,ejected=true`，事件携带随机平面速度、角速度和生命周期；Presentation 更新飞散箱体，Renderer3D 用独立 Box 节点表现旋转，未 ejected 方块才可碰撞。
- D-047: 敌方箱体网格继续由 occupied cells 驱动，但视觉本体 gap 收紧为 0.82，前后端面保留；使用官方木箱材质 UUID `uuid://C6Zh4Wb78SYH1lDk3QOBw_NQ`，不可用时回退顶点色材质。
- D-049: 3D 箱体不能只依赖薄体素和单轴 Z 旋转；敌方体素本体需提高厚度并保持紧凑间距，飞散箱体需使用可见多轴姿态、世界 Z 抛射和缩放淡出，才能在正交斜视下形成明确立体运动反馈。
- D-051: 用户反馈上一版仍未达到箱体和解体可视标准；箱体必须在敌方主体中使用可见的真实纹理和足够厚度，飞散对象必须置于主体前侧，并以多轴姿态、世界 Z 抛射及缩放淡出形成明确退出动画，不能只发布事件或只绕 Z 轴轻微转动。
- v0.10.0: 废弃预瞄线与全部弹珠尾迹；3D 车辆按权威半径放大 1.12，敌方体素 gap 收紧并接入官方木箱材质；规则层新增 `EjectBrick`，命中方块立即取消碰撞并通过 `brick_ejected` 事件随机旋转飞散，表现层/3D 后端维护独立箱体生命周期；SpawnWave 改为二维 AABB 严格候选布局。官方 build 成功；当前沙箱 validate/GLES 未落盘报告或截图，需预览确认。
- Lua LSP v0.9.4：`Game.lua`、`main.lua`、`Scene3DBackend.lua`、`Presentation.lua`、`Renderer3D.lua` 均 Error 0。
- 官方 build v0.9.4：成功，正式入口 `main.lua`，单机模式。
- GLES 菜单态 v0.9.4：`screenshots/ui_logic_final.png` 成功生成，确认蓝紫主题和 540×960 画布；日志确认 3D 场景、Renderer3D、PBRLitSolid、LitSolid、Skybox、NanoVGFill 均初始化成功。菜单态不生成敌机/重卡，因此不作为战斗态对象可见性证据。
- GLES 战斗态探针：当前沙箱中自动战斗态入口运行未落盘日志/截图，未将其标记为通过；代码级确认 `Renderer3D.Render` 先于 `RenderOverlay`，NanoVG 只填充 letterbox。需在预览中点击开始后确认飞机/重卡。
- 逻辑验证：当前沙箱 headless/部分截图进程可能被外层直接终止且无日志文件，不能仅凭 exit code 判定；以 LSP 0 Error、官方 build 成功和可落盘 GLES 菜单截图作为已完成证据。
- 当前 46° 投影由运行时 `WorldToScreenPoint()` 标定，并在相机震屏位移后刷新；禁止硬编码旧 offset/scale。

- 下一步改为：在预览中点击开始，重点确认 UI 仍可见、敌方箱体材质、车辆体量、命中后箱体旋转飞散、飞机无重叠，以及暂停/升级触摸命中。预瞄线和尾迹不再回归。
