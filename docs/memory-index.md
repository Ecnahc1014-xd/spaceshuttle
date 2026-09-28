<!-- RECOVERY INSTRUCTIONS -->
<!-- 新会话 AI 读到此文件时： -->
<!-- 0. CLAUDE.md 已自动注入 → 已知当前状态和关键避雷 -->
<!-- 1. 读取本文件 → 恢复项目上下文 -->
<!-- 2. 读取 docs/persona.md → 加载助手人格 + 用户偏好 -->
<!-- END RECOVERY INSTRUCTIONS -->

# 项目记忆索引

项目：击碎，飞机大战
当前版本：0.12.4
简述：三十图补齐批次——升级面板（选卡倒计时+自动选卡、锁定保留卡）、首充新手礼包、付费战斗档案轨全部落地；自建大厅修复双 NanoVG 上下文/五秒兜底竞态/Start 幂等。
最后巩固：2026-09-28

## 项目概况
- 技术栈：UrhoX Lua 5.4，启用多人匹配但战斗客户端本地运行（服务端仅 IAP/钻石），raw NanoVG 模式 A（540×960 设计分辨率 + letterbox）。
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
| `scripts/Scene3DBackend.lua` | 3D Scene/Camera/Viewport、46° 正交斜俯视与 `orthoSize=18.0`、固定 9:16 `IntRect` CONTAIN、相机投影标定、3 批动态视差星层、深空底板、dark-tech HUD/四弹药槽/菜单和撞线反馈覆盖层 |
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
- D-016: 游戏曾更名为“太空飞机弹珠”（v0.8.0）；v0.10.34 对外正式名改为「击碎，飞机大战」。UI 经 Laterano/Astroon 后落到 dark-tech。
- D-052: v0.10.34 玩家可见标题（windowTitle / 菜单主标题 / taptap_publish.title）必须同步为「击碎，飞机大战」。
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
- D-044: v0.10.28 按 `ecnach-ui-skill` 将全页 UI 改为 dark-tech：深黑蓝层级底、品牌青唯一强调、青底 ink 字主 CTA、角标/断线边框/局部网格装饰。升级卡命中几何保持 168×300/gap8/cy530。禁止恢复 Astroon 蓝紫金或 Laterano 蓝白。
- D-043: v0.10.25 接入引擎 `VoxelPhysicsWorld` 仅作表现：规则层继续 AABB；模块探测失败必须回退 CustomGeometry，禁止 Init 失败。编队体积零重力传送、命中挖空+独立碎块，禁止对编队 ApplyDamage（连通性会撕机翼）。Linux CLI 当前未编译该模块。

## 活跃系统契约
| 契约 | 文件 | 状态 |
|------|------|------|
| `Game.GetSnapshot()` | `scripts/Game.lua` | 稳定，渲染只读 |
| `Game.DrainEvents()` | `scripts/Game.lua` | 稳定，单次消费 |
| `Presentation.Update(dt, gameSnapshot, events)` | `scripts/Presentation.lua` | 稳定 |
| `Presentation.GetSnapshot()` | `scripts/Presentation.lua` | 稳定，渲染只读 |
| 后端 `Init/Shutdown/Resize/ScreenToGame/Render/GetDesignSize` | `scripts/Scene3DBackend.lua` | 唯一后端（旧 2D NanoVGBackend/Renderer 已于 v0.10.23 删除） |

## 避雷清单
- TodoWrite 必须前置创建并包含 DEV + POST-1/2/3。
- `Game.lua` 禁止出现任何渲染 API、引擎对象、视觉参数或输入枚举。
- 不要让 renderer 自行重算瞄准轨迹或硬编码蔬菜 7×7 尺寸；尺寸来自快照中的 `gridW/gridH`。
- 不要向 NanoVG context 注入自定义字段传递状态。
- 不要用全局 `math.random()` 同时驱动玩法与画面；玩法使用独立随机流。
- 会话外修改可能与当前任务并发；写后若内容变化，必须重读并合并。
- headless 验证器当前会因自带 shader cache 字节码报 engine error；判断脚本时需关注 `lua_errors=0`、`resource_errors=0` 并结合 GLES 截图

## 最近变更
- v0.12.4（三十图补齐：升级变现闭环 + 首充礼包 + 付费档案轨 + 大厅加固）：
  - **升级面板**：①com_lvup_05 锁定保留卡——`Game.heldUpgradeId`/`ToggleHeldUpgrade`，卡片左上角标「锁定↔保留」（hit kind `hold`，判定先于 boost），下次面板 `RollUpgradeChoices` 放首位、重抽仍保留、选走即清；②com_lvup_08 选卡倒计时——`UPGRADE_SECONDS=8`、levelup 态 `Game.Update(dt, upgradeTimerPaused)` 倒数、超时随机自动选真实候选，面板顶部剩余条+「看广告 +30 秒」一次（kind `timer_ad`）；⚠️ 暂停条件必须用 `AdService.IsInFlight()` 而非 `IsBusy()`（冷却期冻面板）；广告在途锁 timer 不消耗。
  - **首充新手礼包**：`Shared.FIRST_GIFT`（sku first_gift_6、24h 窗、parts 500 + arctic 皮肤 + 服务端 100 钻石）；PlayerData `firstGiftClaimed/createdAt`（云合并取更早 createdAt）；服务端 money 标志 first_gift；PURCHASED_PARTS_SYNC 扩带 premium/first_gift 双标志；RechargeShop 顶部横幅行（倒计时+价格+立即购买），GetLayout(w, showFirstGift) Draw/Hit 同源。
  - **付费档案轨**：GEM_SPENDS 增 pass_premium（100 钻一次性、grantCurrency 分支、服务端已购回 already_owned）；DrawPass 双轨显示 + gold Button kind；ClaimPass(level, multiplier) ×2。
  - **大厅修复**：lobby_runtime 降级/stop 统一 `shutdownLobbyUI()`（view:Destroy + UI.Shutdown——urhox-libs/UI 是进程级 nvg 单例，不拆上下文=历史「2D 零星元素」根因）；onProgress>=1 撤销五秒兜底；ClientMain.Start `started_` 幂等守卫；失败打 FATAL。
  - **平台强冲突跳过**：好友榜/分享战绩（.emmylua 无 Share/Friend API），不做假按钮。
  - 验证：LSP 0 Error、多人 build+预览上传成功。待 Preview：降级 2D 完整性、倒计时自动选卡、保留卡；⚠️ IAP 白名单 403 未解除，新商品未在平台创建。
- v0.11.4（新手下拉手势提示）: 玩家要求做首次进入游戏的引导——还没做过任何操作时循环播放「手从上往下拉」的动画，提示拖拽发射。做法：①规则层加 `hasLaunched`（`LaunchMarble` 置 true、`ResetGame` 复位），快照出 `s.showPullHint = playing and not hasLaunched and not aiming`——一拖拽即消失、发射过永不出现，渲染层不自行猜"是否操作过"。②手势图 `assets/image/ui_hand_pull3_20260925153601.png`（256×384 RGBA，dark-tech 青色线稿、右手握拳食指斜朝左上，AI 生成；⚠️ 方向必须是斜朝左上，垂直向上/带箭头与下拉语义冲突），`nvgCreateImage(vg_, "image/...png", 0)` 在 `Backend.Init` 加载一次，**可选资源**——失败只打日志跳过提示，绝不进初始化成功条件（否则缺图会 UI 全没 + 卡死）。③`DrawPullHint` 在弹弓车辆上方循环 1.6s：手沿 9 点青色虚线从上方下移到发射位（已滑过的点更亮更大），淡入/淡出，末尾跟「向下拖拽 松手发射」。LSP 0、多人 build 成功、资源已进 dist manifest（uuid 与 .meta 一致）。⚠️ 环境 HDR Bloom shader 编译失败致离屏截图发白，需 Preview 验收动画。
- v0.12.2（后台匹配，删掉大厅层）: 玩家反馈「预览连不到服务器」，加上前几轮反复出现的灰帧/主题不匹配/UI 只剩零星元素，根因统一指向「1 人匹配 + lobby_runtime」这套方案——它为了拿一个服务端进程承载 `Shop.onDeliver`，付出了「进游戏前必须等匹配」的代价。改为 `background_match: true`：游戏脚本立即加载、匹配后台跑、服务端就绪触发 `ServerReady` 再启用联机层与云。删除 lobby_runtime.lua / local_game.lua / ui.LoadingScreen.lua 整层；settings 去掉 lobby_runtime；GameMode 默认离线起步（不碰云，避免无谓请求）。另修 `DrawLetterboxBackground` 不能当全屏兜底（只填画布外，9:16 偏移为 0 时一笔不画），灰帧改为整屏实心填。\n- v0.11.3（本地体素失色修复）：联机项目的敌机战斗仍只在客户端本地 Scene 运行；`LOCAL` Volume 查询 Local 色板，但 `SetPaletteEntry`/`SetPaletteEntryPBR`/`SetPaletteCutColor`/`GetPaletteMaterial` 省略 domain 时默认 Replicated，导致机身和飞散碎块无机型色。`Renderer3D` 明确以 `CreateVolume(..., Quaternion(), LOCAL)` 创建两类体积，并把基础色、PBR（无发光时传占位 `Color(0,0,0,0)`）、切面色、材质全部指定 `VOXEL_PALETTE_LOCAL`；仍用 VisualCatalog 的 bank 0 槽位 1–64，不动 Game/逐格修理日志。Lua LSP 0 Error、官方多人构建和静态契约通过；Linux 无体素模块且单机验证器不适用多人战斗，Preview 实际颜色待验。
- v0.11.1（扣血线位置 + 可见性）: 玩家反馈「扣分那条线不可见，而且方块过了紫线才掉血」。根因两层：①位置——规则层越线判定是 `Game.lua` 的 `brickBottom > DANGER_Y(900)`，而 3D 紫线写死 `Vector3(0,-8.0,0.9)`；46° 斜俯视**正交**相机下 z 会投影到屏幕 Y，z=0.9 把线整体抬高约一行砖。改为 `CreateDangerBand` 初值 `(DESIGN_H*0.5-900)*0.018`、z=0（与敌机体素同平面），并在 `Backend.UpdateScene` 每帧按快照 `gameSnapshot.dangerY` 刷位置，与规则同源；横线 x 必须居中 0，不能用 `WorldFromGame(0,y)`（x=-4.86 会把线左移）。②可见性——深空场景纯漫反射细盒几乎看不见，加常驻 `MatEmissiveColor(0.40,0.13,0.70)`、线体 0.06→0.09、底色提亮 (0.39,0.19,0.67)→(0.62,0.26,0.92)，受击/Boss 在其上叠加。LSP 0、多人 build 成功。⚠️ 本环境 llvmpipe 下 `BloomHDR(...TONEMAP_LUT)` 编译失败（`texture3DLod`），HDR 链断导致离屏截图整屏纯白，无法目视验收，需 Preview 确认。
- v0.12.0（单机间接联机 + 氪金代币）: 为了接内购（单机架构原先做不了 IAP），按「单机间接联机」把项目改成 client+server 双入口。`main.lua` 退化成纯分流（`IsServerMode()` → `network.Server`，否则 `game.client_main`），929 行玩法编排整体搬到 `scripts/game/client_main.lua`，HandleXxx 保持文件级全局（SubscribeToEvent 按名字解析）。服务端 headless 只承载两件事：IAP 发货（`Shop.onDeliver` → `serverCloud:BatchCommit` + orderId 幂等/离线补发）与氪金代币「钻石」余额（`serverCloud.money`，`.meta c_or_s=s`）；不复制场景、不跑战斗。客户端加 `network/Client.lua`：连上上报 ready、收 `IAPBalanceSync`/`IAPBalanceDirty` 推余额、`IAPGemSpend` 只申请扣款（权威在服务端）。`GameMode.lua` 是唯一离线标志（禁止用 `IsNetworkMode()`，大厅启动后恒 true），离线时云存档/云高分/排行榜/充值全部短路。`lobby_runtime.lua`（urhox-libs/UI）1 人秒开 + 5s 超时 → `SetOffline(true)` → `local_game.lua` → `ClientMain.Start{offline=true}`；stop 只退订自己的事件。`ui/RechargeShop.lua` 是 NanoVG 充值弹层，靠 `MetaUI.RegisterScreen` 插件接入，复用 `MetaUI.GetDeps()` 令牌，UI 无污染。settings.json 开 `multiplayer.enabled=true` + `lobby_runtime` + `player_number:1/immediately_start`。LSP 0、多人 build 成功。待 Preview/真机验收大厅与内购开通。
- v0.11.0（商业化 P1+P2+P3+部分 P4）: 单机激励广告变现从「只有复活」扩成完整闭环。**三色语义落地**：新增 `C.ad/C.adDim` 绿＝看广告，青＝免费/主操作，金＝稀有，所有广告按钮一律绿色。新增 `PlayerData.lua`（零件/签到/每日任务/图鉴/皮肤/统计 + 本地存档 + clientCloud 云合并取大值 + 通用每日计数器 `GetDailyCount/AddDailyCount`）、`AdService.lua`（激励视频统一调度）、`MetaCatalog.lua`（图鉴文案/皮肤/商城/转盘奖池静态数据）、`MetaUI.lua`（元层界面绘制+命中，依赖注入拿后端颜色令牌与绘制原语）。主菜单商业区＝货币栏+四入口（商城/图鉴/任务/排行）+每日签到+每日补给弹窗；五个面板＝任务/图鉴/全服排行榜（`GetRankList`+`GetUserNickname`）/商城（5 款程序化车辆皮肤+广告礼包）/幸运转盘（raw NanoVG 扇形）。升级面板＝免费重抽 1/局、看广告重抽（卡池升格保底稀有）、看广告四选一（优先神秘词条，画成下方宽卡）、单卡升格（生效×2）、额外再选一张。结算＝击碎+1/清机+10/过波+25 零件，出现即×1入库+看广告双倍，三按钮。局内 P4＝HUD 右上「零件 +N」+ 暂停面板战场补给站（看广告防线+25血 / 下个强化必出稀有，各 1 次/局）。图鉴靠 `Game.runAircraft` 记录本局清掉的机型，结算解锁并发收录奖励。命中几何全部收敛到 `Backend.HitTest*` 单一来源。验证：LSP 0、build 成功、截图对照设计稿（菜单商业区/商城/转盘/补给弹窗）。待做：道具槽/轨道支援/零件×2 增益。
- v0.11.0-p1（商业化 P1）: 单机激励广告变现从「只有复活」扩到完整闭环。新增 `PlayerData.lua`（软货币零件/签到/每日任务/图鉴/皮肤 + 本地 `player_data.json` + clientCloud 字符串云同步，合并取大值）与 `AdService.lua`（在途锁 + 3s 冷却 + 一次性完成 + embed manual close 归失败；main 所有广告统一走此处）。升级面板新增：免费重抽 1 次/局、看广告重抽（含卡池升格保底稀有）、看广告解锁第 4 张（优先神秘词条卡）、单卡升格角标（生效 ×2）、本次额外再选一张；第 4 张是下方宽卡而非第 4 列，3 张主线卡几何 168×300@cy530 不变。命中几何改为 `Backend.HitTestUpgradePanel` 单一来源，main 不再自持常量。结算：击碎 +1 / 清机 +10 / 过波 +25 零件，页面出现即 ×1 入库，看广告双倍补发等额；ReviveFromAd 复位结算守卫。验证：LSP 0、build 成功、headless 90 帧无 Lua 报错。待做 P2 主菜单 / P3 收集层 / P4 局内。
- v0.11.0-design: 商业化界面设计稿 30 张（无玩法代码变更）。先做变现盘点：单机只走激励视频，`ad.status=1` 但唯一触点是复活且每局限 1 次；无软货币、无 meta 层，IAP 因单机架构不可用，发布资产（icon/截图/宣传图）仍为空。随后按商业化思路出 3 页 ×10 张 mockup，存 `assets/image/com_*.png`：`com_menu_*`（签到/首充礼包/每日任务/商城/图鉴/排行榜/转盘/通行证/每日补给/综合）、`com_ingame_*`（局内双倍/暂停补给站/增益/复活/限时横幅/道具槽/Boss 支援/弹药/结算/新纪录）、`com_lvup_*`（重抽/升阶/四选一解锁/双按钮/锁定/额外选/卡池升格/倒计时/神秘词条/综合）。确立三色语义：绿=看广告、金=付费/稀有、青=既有强调色。设计稿仅为方向候选，落地前须重新对齐升级卡 168×300@cy530 命中契约。
- v0.10.40: 修体素更新延迟/幽灵块。根因：NanoVGRender 晚于 3D 绘制，且短命飞散事件挖一格即把整架机签名对齐导致同帧其余格漏挖。Update 中游戏/表现快照就绪后同步 3D 场景；NanoVGRender 只画覆盖层。逐格以 Game 快照对齐实心占用和冻色，按机合批单次 MarkRegionDirty + RebuildGeometry，复验 IsSolid；飞散事件仅产生碎块。修理日志 `[Renderer3D][voxel-repair] enemy=... removed=... added=... rebuilt=true grid=ok`（失败含 error，碎块回退有 fallback）。LSP 0、官方 build 成功；Linux 运行时无体素模块且 validate 报告/截图未落盘，Preview 待验收。
- v0.10.39: 升级卡文案压缩。玩家嫌“小作文太长”，12 张卡 detail 全部改成一句短话；详情字号 15→17、行距 22→25、最多 3 行，卡名 20→22。卡片几何不变。LSP 0、build 成功。
- v0.10.38: 玩家仍反馈字号不够，再抬一档。标签/辅助≥15，正文≥17，标题≥28；分数/波次 30，卡名 20，详情 15；飘字 32。HUD/Dock 高度与升级卡几何不变。LSP 0、build 成功。
- v0.10.37: 修存活机幽灵块。玩法订 Update，体素世界本帧已步进完毕；只 MarkRegionDirty 要等下一帧，飞机还活着时缺口永不刷新。HollowBrick 改 SetSolid(false)+同帧 RebuildGeometry，IsSolid 确认挖空。漏挖兜底仍避开本帧已挖机，整网对齐后立刻重建。LSP 0、build 成功。
- v0.10.36: 修物块刷新滞后。体素路径 HollowBrick 只 MarkRegionDirty，禁止每命中 RebuildGeometry；挖空成功立刻对齐规则签名；漏挖兜底只处理本帧没挖过的机，避免整网 Fill 把刚挖的格填回去。CustomGeometry 回退去掉每帧 4 架重建预算，命中缺口同帧消失。LSP 0、build 成功。
- v0.10.35: 全面加大玩家 UI 字号。标签/辅助 8–11→12–16，正文 12–14→15–18，标题 22–28→26–32；升级卡详情 11→13、卡名 14→18；卡片几何仍 168×300@cy530。飘字 20→26。LSP 0、build 成功。
- v0.10.34: 正式更名为「击碎，飞机大战」。窗口标题、菜单主标题、TapTap 发布名同步；菜单主视觉改「击碎飞机」；升级卡「词条/已装配」改「特殊效果/已选」。玩法未改。LSP 0、build 成功。
- v0.10.33: 玩家向中文 UI。HUD/菜单/结算/升级/暂停/波次横幅去掉驾驶舱英文黑话，改成分数/防线/点击开始/再来一局等可读文案。升级卡几何不变。LSP 0、build 成功。
- v0.10.32: 激励广告复活 + 云高分。结算「看广告复活」走 ShowRewardVideoAd，完整观看才 ReviveFromAd（50 血、编队抬回屏外、本局一次）；clientCloud 读写 high_score；结算按钮几何命中，不再全屏松手重开。LSP 0、build 成功。
- v0.10.31: 战斗 Dock 中央下一波预告。规则层 PlanWave 预抽 nextWavePlan，SpawnWave 消费同一份；VisualCatalog.GetAircraftPreview 给上色 occupied cells；DrawNextWavePreview 在四弹药槽中间画 156×70 像素小图+倒计时+机名/数量。LSP 0、build、截图、headless 200 帧 lua=0。
- v0.10.30: 8bit 街机剪影 + 同波同机阵型。AircraftPixelData 8 机全部 ASCII 位图（蟹/黄蜂/蝴蝶/蜜蜂/宽翼/飞碟/双荚/菱形截击）；SpawnWave 抽一种机按 line/vee/grid/swarm/wedge/stream 排槽，hive 强制 swarm、宽机 3+ 用 2+1 grid，整队锁定横摆。前三波 3 机。LSP 0、build、roster/line/vee/swarm 截图、headless 200 帧 lua=0。
- v0.10.29: 修剩余碰撞漏检与碎裂未完成。子步进改为收集本步所有重叠格再打最近格（不再按 bricks 顺序 break）；步进 6–16。体素 HollowBrick 失败每帧重试，规则签名强制 FillEnemyVolume，禁止一次性 consumed。碎块失败才画 CustomGeometry。LSP 0、build、headless 180 帧 lua=0。
- v0.10.28: 按 ecnach-ui-skill 精细重构 UI。废弃 Astroon/Laterano 蓝紫金；HUD/Dock/菜单/结算/升级/暂停统一 dark-tech 令牌与窗口骨架（角标、断线边框、局部网格、刻度、青识别线）。升级卡外观换肤，几何/命中仍 168×300@cy530。玩法与 3D 未改。LSP 0、build 成功。
- v0.10.27: 波次再放慢+首波加快+修碰撞/碎裂丢失。基础间隔 14→18s、下限 7.5→9s、收紧 0.18→0.15、首波冷却 2.5→3.2s；全局下落 0.25→0.42、首波基础速度 18→28。高速弹自适应子步进 4–12 + 线段 AABB 扫掠。体素碎块/挖空失败时 needVisualFallback 走 CustomGeometry 飞散箱，碎块 vz 朝相机。LSP 0、build、headless 200 帧 lua=0。
- v0.10.26: Preview 体素路径修敌机消失+碎块 1:1:2。根因：编队 FinalizeVolumeAsDynamic 后 Node 在质心，每帧设回网格最小角把整机平移出视野；碎块 CreateVolume(1,1,2) 是扁长条。现编队 FinalizeVolume 静态、每帧只改 GetNode().position；碎块 1×1×1。LSP 0、build、headless 200 帧 lua=0。
- v0.10.25: 接入引擎 VoxelPhysicsWorld（探测+回退）。Scene3DBackend 创建体素世界失败则 voxel_physics=false 走 CustomGeometry；模块可用时每敌机一个 VoxelVolume（gridW×gridH×2、voxelSize=brickSize*WORLD_SCALE、原点对齐阵列底边）、VisualCatalog 调色板 1-64、命中 HollowBrick+独立动态碎块（禁止 ApplyDamage）、碎块上限 24、模态暂停求解。Linux CLI 未知组件 ECEBFC51 回退成功。LSP 0、build、400/200 帧 lua=0。
- v0.10.24: 第2轮10项优化（移动端触摸闭环/输入防穿透/正反馈）。①PointerDown paused 态直接 Resume（移动端恢复）；②Pause 与进 levelup 都 aiming=false+activeBall 归位 SLING，防残留蓄力；③DrawHud 基地血≤35% 文字色 sin·7 红脉冲；④COMBO(clearStreak)≥2 金色+sin·8 放大；⑤FEEDBACK_MAP upgrade_picked→upgradeConfirm 中心青色"已装配"飘字+轻震屏；⑥UpdateMarbles 主球移除 Emit marble_reloaded(仅 isPrimary)→Presentation.reloadFlash(.3s)，DrawAmmoSlots Dock 顶边右→左青色扫光+激活槽提亮；⑦launchFlash 处理器 push shockRing(r8→26/.24s/弹种色)复用冲击环零新增 draw call；⑧main.lua levelup 态 Mouse/Touch 的 Up/Move 全 return 防穿透，卡片空白点击不关面板改 Presentation.PulseUpgradeHint()（右下提示金色脉冲.5s），DrawLevelUp 加 presentation 参；⑨menu/gameover PointerDown 只置 startArmed、PointerUp 松手才 StartGame（防死亡抬手误重开），ResetGame 清 startArmed；⑩BUILD→0.10.24。LSP 0、build、surfaceless 2503 帧 lua=0、自动开局/发射/选卡探针截图验证后探针已删。
- v0.10.23: 飘字 3D 可见（DrawFloatTexts 投影+描边+末段放大）、击毁 34% shockRings 扩散环、DrawDamageVignette 受击四边红闪、Boss 波红框 WARNING 横幅（waveBannerBoss）、瞄准线 power 30%→100% 渐长、烟雾去持续上升改强阻尼防堆屏顶、飞散箱初速/寿命减半防顶部堆积、删死代码（_texprobe/Renderer/NanoVGBackend/VeggiePixelData，scripts 仅 7 lua）。
- v0.10.22: ①瞄准线起点脱离车辆修复——相机是 46° 斜俯视**正交**（非纯俯视），z 差会投影到屏幕 Y；旧瞄准线固定 z=-6、车锚点 z≈0.09，整条线在屏幕偏移。SyncAimLine 改为起点直接取 GetVehicleAnchorWorld(activeBall)（含 z）、终点同 z（规则层 x1,y1 本就=车坐标，问题纯在渲染 z）。②瞄准线视觉：22 等大青方块→14 青色软圆点，t=(i-1)/(N-1) 从 0(车中心)到 1(边界)，尺寸 ×(1-0.55t) 渐小；材质 DiffVCol→DiffAlpha+烘焙青软圆纹理。③粒子更小更少去均一：Presentation 生成尺寸/生命随机范围拉大（spark 1.4-3.4px/0.18-0.42s、shard 2-4.5px spin±16、smoke 4-10px/0.45-0.9s 低速）；击毁 random(1,2) spark+55% 1 shard+20%烟，普通命中 35% 1 spark，防线 random(4,7) spark+35%烟，发射点击 1 spark+15%烟，分裂/追击/贯穿/巨型数量再降且随机；Renderer3D 世界系数下调（spark×0.85/shard×1.25/smoke×0.85，min 0.012-0.015m）。LSP 0、build、1200 帧 lua=0、瞄准线截图确认贴车渐小。
- v0.10.21: 粒子从"不透明纯色等大方形"重做为三类柔和点缀。Presentation.SpawnParticles 加 kind(spark/shard/smoke，默认 spark)，p 新增 angle/spin/kind，UpdateParticles 分运动：shard 重力+自转、smoke 上飘减速无重力且 size 膨胀、spark 重力短促。事件降频降量：击毁=3 spark+2 shard+35% 1 smoke，普通命中 50% 概率 1 spark，防线 24→10(+50%烟)，分裂 16→5、追击 10/8→3/2、贯穿 16→5、巨型 32→≤8(+40%烟)；launchFlash 点击反馈 8→2 spark+25% 烟。Renderer3D 单 BillboardSet 改三个(particleSets_ spark/shard/smoke 槽 64/40/28、DiffAlpha)，程序生成 CreateSoftCircleTexture(r,g,b,cA,eA) 暖白/灰半透明、CreateTriangleTexture 金属三角，SyncParticles 按 kind 分流、淡出靠末段尺寸收缩。踩坑（探针实证）：DiffVCol/DiffVColAdd 忽略纹理 alpha（软圆/三角→方块），DiffAlpha 读纹理 alpha 但不读 billboard 顶点 rgb（白纹+顶点色不染色），唯一解=颜色烘焙进纹理+DiffAlpha+顶点白；三角因 Billboard UV V 翻转要在图像里反向画。LSP 0、build、1500 帧 lua=0、三类形状截图确认。
- v0.10.20: 敌机 4→8 种。AircraftPixelData 新增 `bitmapToData(rows)`（M=hullMain红棕/d=hullDark灰蓝/C=canopy高亮蓝/E=engine暗，字符 RGB 落在 ClassifySlot 阈值，转成 col,row,r,g,b entry 串），新增 4 机型位图+behavior：dart 金黄尖头后掠飞镖 11×9（speed1.22/descent1.28/swayFreq1.35，最快）、hive 橙蜂群小机 9×7（swayFreq1.6 急促、分高）、manta 翡翠绿宽翼鳐鱼 14×8（swayAmp36 大横摆、speed.88）、cruiser 钢灰重装盒 13×9（装甲最密、descent.68 最慢、180分）。VisualCatalog 加 4 套四槽位色相。Game.GetAvailableTypes 硬编码 4 型+波次 index 改为 WAVE_ROSTER 门槛表（scout1/dart2/striker3/hive4/manta5/bomber7/cruiser8/interceptor9）。渲染完全 data 驱动不改 Renderer3D。LSP 0、build、1500 帧 lua=0、8 机型同屏两列冻结截图确认轮廓/配色/座舱/引擎灯。
- v0.10.19: 一条 3D 辅助瞄准线。规则层新增 local ComputeAimLine（定义在 GetSnapshot 之前）：仅 aiming 且 activeBall 且 pull 长>15（AIM_DEAD_ZONE）时返回 {x1,y1,x2,y2}，dir=-pull 归一化（与 LaunchMarble 同源），按 activeBall.radius 求射线与左(0+r)/右(DW-r)/顶(TOP_BOUND_Y+r) 最近正 t（不含底边），s.aimLine 输出，无瞄准 nil。渲染层 Renderer3D.SyncAimLine 用单 BillboardSet（AimLine 节点、22 槽、白 1px 纹理+DiffVCol），沿射线 t=(i-.5)/22 排点，点尺寸 0.085m、z=-6（正交投影不改屏幕 XY、避遮挡雾）、alpha 1.0→0.65 渐隐，空槽 enabled=false/每帧 Commit，Init 建/Shutdown 释放。踩坑：先试 CustomGeometry 细四边形——游戏场景（Zone 环境光/雾）下动态 DefineColor 顶点色、NoTextureUnlit 的 MatDiffColor、NoTextureVCol、DiffVCol 无纹理全部恒显灰白（独立无 Zone 探针显色正常、纯红顶点色也灰白），最终改用碰撞火花同款 BillboardSet+billboard.color 路径才稳定青色；点状虚线同时避开方形 billboard 密排的斜线阶梯锯齿。LSP 0、build、400 帧 lua=0、拖拽截图确认。
- v0.10.18: 碰撞粒子接入 3D 后端。根因：Presentation.particles（SpawnParticles，击毁 10/命中 4 粒、对象池）此前只被旧 2D Renderer.lua 消费，Renderer3D 完全没读，3D 后端下碰撞无火花。实现：Renderer3D 增单个 BillboardSet `HitParticles`（SetNumBillboards(96)、relative=false、castShadows=false、1px 白纹理 + DiffVCol），SyncParticles 每帧把粒子经 GameToWorld 放到 z=-0.95（相机在 -Z，浮于敌机体素/飞散箱前），billboard.color 用事件 rgb+alpha，worldSize=p.size·0.018·3.4·(0.45+0.55·lifeT)、min 0.05m、随生命收缩，alpha=clamp(lifeT/0.65) 前段全亮；超 96 丢弃、空槽 enabled=false、每帧 Commit；Init 建/Shutdown 释放。排查关键：先独立场景后游戏场景双固定色块探针证明 billboard 顶点色/位置/尺寸在真实相机+光照下可见，再发现真实火花不可见纯因尺寸过小（3.7px·0.018≈0.067m）与淡出过快；SetFaceCameraAngle 绑定不存在（默认即面向相机，勿调用）。LSP 0、build 成功、400 帧 lua=0。
- v0.10.17: 回滚召回机制 + 修复“射不出去” + 升级卡垂直节奏。①删除 v0.10.15-16 全部召回：RecallMarbles/HasFlyingPrimary、marble.recalling 物理加速、queuedLaunch、UpdateReload 自动发射、s.canRecall/recallFireQueued、FEEDBACK_MAP 两事件、Presentation.recallPulse、Dock 召回提示/呼吸光带/扫光；空仓 PointerDown 恢复直接 return（球自然回落补弹），保留全屏相对拖拽（grabStart+ClampPull）。②根因修复回收出生即死：回收线 DANGER_Y=900 在弹弓发射位 y=850 之上仅 50px，下拉待发车可到 y≈940（巨型半径 30），旧 `y-radius>DANGER_Y` 无条件判定让球一发射还没向上走就被回收；改为 `vy>0 且 y-radius>DANGER_Y` 只回收向下回落的球。③升级 UI：GetUpgradeCardLayout cy 470→530（卡 380..680，在标题与 y704 提示间居中），详情文本块在详情区 y+88..y+208 垂直居中，底部标签 26→24/徽标 30→26、层数提亮 α85→{184,196,226} 且上移到 y+279 不贴底，副标题 UI_INK→UI_COLD，底部提示 8→9px，main.lua 命中 cy 同步 530。探针：向下拉满向上射 vy=-414 稳定上行 y843→443 flying=1；升级态截图均衡；400 帧 lua=0。
- v0.10.16: 修复 v0.10.15 召回导致没法快速射击——召回与发射合流。PointerDown 空仓分支触发 RecallMarbles 后不再 return（继续 aiming=true 记录 grabStart）；PointerUp distance≤15 死区只清空 queuedLaunch/归位（纯点按=仅召回），distance>15 时：有 activeBall 立即 LaunchMarble，空仓则存 `queuedLaunch={dx,dy,power}` 并发 recall_fire_queued 事件；UpdateReload 在 QueueNextBall 后同帧消费 queuedLaunch 自动发射首个回库主球（单发消费即清），ResetGame 清空。快照增 recallFireQueued；Presentation FEEDBACK_MAP 增 recall_fire_queued→recallFireLock（复用 recallPulse+金色粒子）；Dock 提示 canRecall 青色“拖拽瞄准松手即射 // 点按仅召回”、queued 金色“召回中 // 方向锁定·回库即射”（胶囊宽 240→264）。LSP 0、build 成功、锁定态 GLES 截图确认、700 帧探针 6 射+2 空仓拖拽手势→autoFired=2 且 flying=4，lua=0。
- v0.10.15: 操作体感优化。①全屏相对拖拽起手：删除 PointerDown 的 `py < DANGER_Y-100` 底部 160px 限制，新增 grabStartX/Y 记录按下点，GetPullState 改 ClampPull(pull=当前点-按下点)，保留 MAX_PULL=150 与向下钳制 PULL_MAX_DOWN_DY=DH-SLING_Y-20；待发车辆仍只在 SLING(270,850) 附近移动，手指在战场任意位置起手都不遮挡车辆。②点击召回：activeBall=nil 且 ballQueue 空且有在飞主弹珠时快照 canRecall=true，PointerDown 触发 RecallMarbles 标记所有 isPrimary 主球 recalling；物理子步进内 recalling 球 vy+=1700·dt（封顶 1150）、vx*=exp(-2.6dt)，碰撞伤害反弹照常；回收判定 `y-radius>DH` 提前为 `>DANGER_Y`（进 Dock 即回库补弹）；分裂子球 isPrimary=false 不召回不补弹。③反馈：FEEDBACK_MAP 增 marbles_recalled→recallPulse（1.0/dt*1.8 衰减+轻震屏+弹弓区粒子），Dock 青色横向扫光（Dock 矩形 scissor），canRecall 常态上沿呼吸光带+“点击战场 召回载具 // TAP TO RECALL”胶囊。LSP 0、build 成功、截图验证全屏拖拽（战场上部起手车辆只在弹弓附近）与召回提示扫光、500 帧自动发射→打空→召回→补弹探针 lua=0。
- v0.10.14: 升级卡可读性修复 + 刷怪再放慢。根因修复 `WrapTextLines`：UrhoX 绑定的 nvgTextBounds(ctx,x,y,str,nil) 返回 `(advance, boundsTable)`（{minx,miny,maxx,maxy} 数组）而非 C API 多返回值，旧 `minx,_,maxx=` 解构恒为 nil，fallback 按 `#s` 字节数（中文×3）计宽 → 每行只容 4-5 字、大量空白与截断；测量须在 nvgSave/nvgResetTransform/nvgRestore 内进行（避开 CONTAIN scale=2），fallback 改用 utf8.len。卡片布局 168×300/gap8：标题 15px 单行、稀有度 y+50、分隔线 y+74、详情 12px/18 行距/限 6 行、底部标签/徽标/层数三段；删除无引用的 DrawWrappedText。同步 main.lua 命中布局（原 156×214@478 与视觉漂移）为 168/300/8/cy470/HIT_PAD 4。刷怪：基础 11→14s、下限 5.5→7.5s、收紧 0.22→0.18、首波冷却 1.2→2.5s（GetWaveParams 数量曲线不动）。LSP 0、build 成功、强制升级态 GLES 截图确认详情完整折行、300 帧 validate lua=0（仅引擎壳 Vignetting/Skybox 缺资源噪音）。
- v0.10.13: 升级 UI 大修。天赋池每项新增完整 detail 文案，`GetUpgradeChoices` 透出 detail/kind；Scene3DBackend 新增 `WrapTextLines`/`DrawWrappedText`（nvgTextBounds 实测宽度、UTF-8 按字节步进逐字折行，取代按 8 字硬切）；卡片 162×300 重排：序号圆点+稀有度（标准蓝/稀有金/史诗紫）+类型+7 行详情+抉择风险或词条标签+增量徽标+已装配层数/上限（维修 ∞）；HUD 词条图标去 Icons/*.png 依赖改程序化“贯/链/量”徽标，删除 wordIconTex_ 与 Init 加载。LSP 0、build 成功、强制升级态截图验证三卡、420 帧 lua=0。
- v0.10.12: 越线扣血改按行结算。越线方块按 brick.row 分组，整行碎裂（复用 EmitBrickShatterFx 发飞箱，新增 ShatterBreachedBrick 不加分/经验）；每帧收集越线行数后只扣一次血 `max(1, ceil(rows*0.5)+lineDamageBonus)`；BALL_TUNING.brickDmg 改为 lineDamageBonus（装甲 -1 / 玻璃大炮 +1 都在整体合计后加），聚合单条 base_hit(damage,rows)，防线飘字显示“xN行 防线 -伤害”。单测：2 行无加成扣 1、+1 加成扣 2；420 帧 lua=0。
- v0.10.11: 修复屏内非法生成与进场回撤。根因：随机候选 y 仅 -43~-70（侦察机高 168，机身仍在可见顶 -102 之内），且 CreateEnemy 随机 phase 让首帧 x=baseX+sin(phase)*amp 突跳。修复：生成 y 改为 `-102-机高-24` 整机屏外（Boss 同规则），随机候选锁定屏外层只选 X；新敌机 phase=0；逐帧分离在任一方仍屏外时只纵向抬高（overlap>1px 防浮点误推），双方进场后才横移。刷怪间隔再放慢（11s/下限 5.5s）。420 帧探针 illegalSpawn=0、xJumps=0、lua=0。
- v0.10.10: 刷怪放慢 + 经验曲线重做 + 顶边取中值。刷怪：基础间隔 7→9.5s、下限 2.8→4.5s、收紧 0.35→0.22/波，同屏上限 14→8（每 10 波 +1），单波最多 6→5 架，首波冷却 0.5→1.2s。XP：首升 12→26、成长 1.18→1.26（约两架侦察机首次升级，中期约一架一级）。顶边 `TOP_BOUND_Y` 与 3D `EDGE_TOP_GAME_Y` 从 -270 改为 0 与 -270 的均值 -135（投影 designY≈105，HUD 下方）。LSP 0、build 成功、10s 探针 4 波/2 级（原 7+波/连升）、420 帧 lua=0。
- v0.10.9: 敌机太空战机化。VisualCatalog 把像素原色归类为 canopy/engine/hullMain/hullDark 四槽位（座舱 b-r≥55 且 g≥100，避免灰蓝装甲误判），每类敌机一套配色（侦察青蓝/强袭红橙/飞碟黄绿/截击品紫）；Renderer3D 箱体材质由木箱图换成程序化金属铆钉面板纹理并改用 `DiffVCol`（普通 Diff 不吃顶点色导致整机灰白），座舱/引擎槽位最低亮度，飞散箱继承所属格配色；修复同一升级面板出现重复同名天赋（chosenThisRoll 去重）。LSP 0、build 成功、自动战斗 420 帧 lua=0。待办：用户报“选完天赋后概率异常”，需补截图确认现象。
- v0.10.8: 顶部反弹边外移+机群防重叠重做+修 HUD 浮点格式化。规则层新增 `TOP_BOUND_Y=-270`（投影下 designY=0 约对应 gameY=-240），载具飞出画布顶才反弹；3D 顶边移到屏外、左右边线上延闭合，左右仍 0/540。生成候选 `FleetPositionOccupied` 同时检查本批次与场上存活机（含 Boss），fallback 逐层抬高+均匀 X 槽；逐帧 `ResolveFleetOverlaps` 在全机摆动/下移后跑 8 轮全对全 AABB（水平对称让位/碰墙单向推、垂直只抬高不下压），统一钳边界回写 baseX。修 `DrawHud` 的 `XP %d` 在 xpMul=1.2 浮点时抛错中断 HUD 绘制（math.floor）。LSP 0、build 成功、隔离自动战斗 420 帧 lua=0/零穿插，截图确认顶边出屏。
- v0.10.7: 修复真机“2D UI 消失 + 游戏卡死”致命链。根因是 `Renderer3D.Init` 把项目内不存在的可选资源 `Models/Box.mdl` 纳入初始化成功条件，真机/裁剪构建一旦缺失会让 `Backend.Init=false → Start() 提前 return`，从而不订阅 Update/NanoVGRender/输入。修复：初始化成功只取决于必需材质；`SyncDebris` 在无 Box 模型时直接跳过；飞散箱已是程序化六面体不依赖该模型。飞散箱在表现层 `MAX_EJECTED_BOXES=24`、渲染层 `MAX_RENDERED_BOXES=28` 各设同屏节点预算，防止高命中频率 draw call/节点堆积拖死帧率；清理逐对象 print。LSP 0 Error、官方 build 成功、正式菜单截图完整、隔离自动战斗 420 帧真实渲染 `lua_errors=0` 且 `scene_stalled=false`。
- v0.10.6: 修复敌方箱体飞散不可见的实际根因：项目中不存在 `Models/Box.mdl`，飞散节点改为独立闭合 `CustomGeometry` 六面体并复用箱体纹理材质；保留前侧深度偏移、世界 Z 抛射、多轴旋转、首段完整尺寸和末段缩放淡出。修正 `GainXp` 前置声明槽赋值以支持隔离命中探针；正式 `main.lua` 清除自动测试注入，菜单 2D UI 真实截图恢复；隔离运行态序列确认敌机、箱体和底部 UI 可见，LSP MCP 超时，官方 build 成功。
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
