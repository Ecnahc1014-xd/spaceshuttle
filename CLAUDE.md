# 太空飞机弹珠 — 项目核心记忆

> AI 自维护，每次 POST 自动更新。详细规则见 memory-system skill。

## 当前状态
- 版本: 0.10.15
- 进度: 操作体感优化：①全屏任意位置相对拖拽起手——取消旧 `py < DANGER_Y-100` 底部 160px 起手限制，PointerDown 记录 grabStart 点，拉弓量=当前点-按下点（`ClampPull`，保留向下钳制 PULL_MAX_DOWN_DY=DH-SLING_Y-20 与 MAX_PULL=150），车辆只在 SLING(270,850) 附近移动，手指不再遮挡车辆；②弹夹打空点击召回——`activeBall=nil 且 ballQueue 空 且有在飞主弹珠` 时快照 canRecall=true，点击战场标记全部 isPrimary 主球 recalling（vy 加速 1700/s²封顶1150、vx 按 exp(-2.6dt) 衰减、途中碰撞伤害照常），回收点从屏幕底 DH 提前到 DANGER_Y（进 Dock 即回库补弹）；分裂子球 isPrimary=false 不召回；③反馈 marbles_recalled→Presentation.recallPulse（Dock 青色横向扫光+粒子+轻震屏），canRecall 时 Dock 上沿呼吸光带与“点击战场 召回载具 // TAP TO RECALL”胶囊。LSP 0、build 成功，截图确认全屏拖拽/召回提示扫光，500 帧自动发射→打空→召回→补弹探针 lua=0。
- 上次交付: v0.10.15 全屏相对拖拽起手 + 空窗点击召回 + 回收点提前



## 用户画像摘要
- 使用简体中文沟通
- 重视先做架构解耦，为后续 3D 开发降低迁移成本 [observed]
- 倾向"全部执行别停下"的批量推进风格，要求逐批 LSP+构建+契约+提交 [observed]

## 预测下一步
- likely_next_task: 真机触摸复测全屏起手的拖拽灵敏度（MAX_PULL=150 的相对位移手感）、空窗点击召回的误触边界（当前战场任意点击都触发，可能与将来其他点击交互冲突）、召回加速度 1700 的手感；Boss 波(每10波)与词条/异常反应实机手感；刷怪 14s 节奏体感。若继续调视觉，只基于实机截图调整像素飞机剪影密度、世界边界发光或卡片排版，不改变权威 HP、逐块扣血、XP 曲线、召回/拖拽契约和 9:16 共同投影契约
- 相关文件: `scripts/AircraftPixelData.lua`, `scripts/Game.lua`, `scripts/Presentation.lua`, `scripts/Renderer3D.lua`, `scripts/Scene3DBackend.lua`, `scripts/main.lua`, `docs/plans/WORK-ORDERS.md`, `docs/plans/deferred.md`

## 本批次新增避雷（WO-13/16/14/15/P11/P12）
- 全屏拖拽契约（v0.10.15）：起手不再限定底部区域；PointerDown 在 playing 态任意战场坐标都记录 grabStart(grabStartX/Y)，拉弓量 = 当前点 - 按下点，经 `ClampPull` 钳 MAX_PULL=150 与向下 PULL_MAX_DOWN_DY=DH-SLING_Y-20；待发车辆只在 SLING(270,850)+pull 附近移动，禁止让车辆跳到手指位置；15px 死区松手归位。
- 召回契约（v0.10.15）：`activeBall=nil 且 #ballQueue=0 且 HasFlyingPrimary()` 时 canRecall=true；此时 PointerDown 只触发 RecallMarbles（标记所有 isPrimary 主球 recalling），不起拖拽；recalling 在物理子步进内 vy+=1700·dt（封顶 1150）、vx*=exp(-2.6dt)，碰撞/伤害/反弹照常；回收判定从 `y-radius>DH(960)` 提前到 `>DANGER_Y(900)`，进 Dock 安全层即回库补弹（EnqueueNextBall 仅 isPrimary）；分裂子球 generation>0/isPrimary=false 不召回。改这些值要同步快照 canRecall 与 UI 提示。
- 召回反馈契约：marbles_recalled 事件只写 Presentation.recallPulse（1.0，dt*1.8 衰减）+ 轻震屏/粒子；Scene3DBackend Dock 画青色横向扫光（scissor 在 Dock 矩形内），canRecall 常态画上沿呼吸光带+“点击战场 召回载具”胶囊；规则层禁止直接调渲染。
- 顶点色材质契约：任何需要顶点色染色的 CustomGeometry/箱体材质必须用消费顶点色的 Technique（`DiffVCol`），普通 `Diff` 不读顶点色会让面板纹理盖住整机颜色；程序化金属面板纹理基底要压暗（≈0.62）避免冲淡主色。
- 敌机部件槽位契约：像素数据原色只用于槽位分类，最终颜色由 VisualCatalog 的机型配色表给出；座舱判定要区分高亮蓝（b-r≥55 且 g≥100）与灰蓝装甲（b-r≈30），禁止把大面积灰蓝装甲误判成座舱。
- 升级抽卡去重契约：同一张三选一里用局内 `chosenThisRoll` 保证 id 唯一，叠加上限只控制跨局，不能让同名天赋在同一面板重复出现。
- NanoVG 文本测量契约（v0.10.14 根因）：UrhoX 绑定的 `nvgTextBounds(ctx,x,y,str,nil)` 返回两个值 `(advance, boundsTable)`，boundsTable 是 `{minx,miny,maxx,maxy}` 数组，**不是** C API 的多返回值——`local minx,_,maxx = nvgTextBounds(...)` 会让 minx=advance、maxx=nil，恒走 fallback；且测量处于 CONTAIN 缩放 transform 下时必须先 `nvgSave`+`nvgResetTransform` 再 `nvgRestore`，否则宽度按物理像素翻倍；fallback 估宽按 `utf8.len`（字符数）禁止用 `#s`（中文 3 字节）。
- 升级卡详情契约（v0.10.14）：天赋池每项必须带一句完整 `detail`，UI 用 `WrapTextLines` 做 UTF-8 逐字自动换行（实测 bounds 宽度）；卡片 168×300/gap=8：标题 15px 单行（天赋名≤7 汉字）、稀有度 11px、分隔线 y+74、详情 12px/18 行距/最多 6 行、底部标签 26px+增量徽标 30px+层数 9px 三段固定，避免重叠；HUD/卡片词条标识一律 NanoVG 程序化绘制，禁止外部 Icons PNG。
- 升级卡命中同步契约（v0.10.14）：`main.lua:TryPickUpgradeAt` 的 cardW/cardH/gap/cy/HIT_PAD 必须与 `Scene3DBackend:GetUpgradeCardLayout` 视觉几何逐值一致（当前 168/300/8/cy470/HIT_PAD 4），禁止两套常量漂移；升级点击用 `ScreenToUi`。
- 顶部边界契约：规则反弹顶边是游戏坐标 `TOP_BOUND_Y=-135`（v0.10.10 取 0 与 -270 的均值，投影 designY≈105 在 HUD 下方）；规则常量与 3D 视觉 `EDGE_TOP_GAME_Y` 必须同步，左右边仍是 0/DW。禁止把游戏坐标 y=0 当屏幕顶。
- 节奏平衡契约（v0.10.14）：刷怪基础间隔 14s、下限 7.5s、收紧 0.18/波，同屏上限 8（每 10 波 +1），单波 ≤5 架，首波冷却 2.5s；XP 首升 26、成长 ×1.26。改节奏时同时改 BALANCE、GetWaveParams、ResetGame 初始冷却与同屏增长分母，禁止只调一处。
- 机群防重叠契约：`FleetPositionOccupied` 必须同时检查本批次 placed 与场上全部存活机；逐帧 `ResolveFleetOverlaps` 在所有飞机摆动/下移完成后统一跑 8 轮全对全 AABB，结束统一钳边界并回写 baseX；新增编队必须走 `ENEMY_SPACING=8` 与确定性逐层 fallback。
- 屏外生成与进场契约（v0.10.11）：新编队必须“整机”位于可见战场顶（gameY≈-102）之上，生成 y = `-102 - 飞机高度 - 24`，随机候选只能在该屏外层选 X、禁止随机 y 落到屏内；新敌机 `phase=0`（首帧位置=baseX，禁止随机相位横向突跳）；逐帧分离在任一方仍屏外时只纵向抬高（overlap 阈值 >1px 防浮点），双方都进场后才允许横向让位。
- HUD 整数格式契约：快照中被升级倍率（xpMul 等）作用过的字段可能是浮点，NanoVG `string.format("%d")` 在 Lua 5.4 对浮点直接抛错会中断整帧 HUD 绘制；显示前一律 `math.floor`。
- 初始化致命依赖契约：`Renderer3D.Init` 的成功返回值只能由必需资源决定；`Models/Box.mdl` 等可选资源（仅供旧碎片）缺失时必须降级跳过，禁止纳入初始化条件——否则 `Backend.Init=false → Start() 提前 return → 不订阅 Update/NanoVGRender/输入`，真机表现为“2D UI 消失 + 游戏完全卡死”。
- 瞬时独立节点预算契约：每个飞散箱体是独立 `CustomGeometry` 节点 + draw call，表现层（`MAX_EJECTED_BOXES`）与渲染层（`MAX_RENDERED_BOXES`）必须各设同屏硬上限，超预算丢弃最旧对象，防止高命中频率真机帧率归零。
- 冻结表现契约：渲染层只读 `enemy.freezeRatio`（Game 快照，0..1），按此做顶点色冷色抬升与正面霜冻白高光；签名按 `freezeRatio*8` 量化档位触发重建，禁止每帧衰减都重建
- 对象池契约：高频视觉(粒子/碎片/飘字)从 `particlePool/debrisPool/floatPool` 复用 table，禁止每帧 table.insert 新表；`Game.GetSnapshot()` 复用常驻 `snapshotBuffer_`，调用方不得跨帧持有引用
- FXAA 契约：本环境不可启用 FXAA（ESSL shader cache 失败吞 3D 层），`ProbeFxaa()` 仅探测渲染路径是否声明 fxaa 命令，默认 `fxaaAvailable_=false` 且绝不强制启用
- 反馈映射契约：`Presentation.FEEDBACK_MAP` 是事件→反馈的声明式表，新增反馈只登记映射+处理函数，所有处理只写 Presentation 瞬时状态，不触达规则层
- 词条契约：`BALL_WORDS`(pierce/chain/momentum/lifesteal/heavy) 仅通过 `CreateMarble(words)` 注入行为标记；`activeWords` 由专属升级 apply 写入，新弹珠自动携带；视觉染色推迟到表现层消费 word 事件
- 五异常契约：砖块 `status` 表记录 burn/shock/corrode/freeze/volatile，仅规则层结算 DoT/反应/易暴，视觉染色由表现层推迟消费 `status_reaction` 事件；冻结+灼烧=融穿、寿终 volatile=邻格引爆
- Boss 契约：每 10 波 `SpawnWave` 生成单支高血量 Boss(`interceptor` 外形)，`bossPhase` 按存活砖块比例 1/2/3 切换，`phase 2` 置 `vulnerable` 受 1.5x 伤害；仅规则层，视觉消费 `boss_spawn`/`boss_phase` 事件
- 顿帧契约：`Presentation.hitStop` 由大命中(base_hit/pierce/giant)触发，main.lua 对 `Game.Update` 的 dt 打折(×0.15)但表现层用真实 dt 推进震屏/闪光衰减
- 相机推近契约：防线受创时 `camera_.orthoSize = 18.0 - baseBarrierFlash*1.6`，仍正交投影仅瞬时缩放，flash 归零自动复原，绝不变透视
- 敌人行为分化契约：四类 aircraft 的摆动/下移差异只能由 `AircraftPixelData.behavior[aircraftKey]` 单一来源驱动（swayAmp/swayFreq/descentMul/agility/accent），`Game.CreateEnemy` 仅消费该表并叠加随机抖动，禁止把行为数值硬编码进 Game 其他分支或渲染层
- 模态缓动契约：四模态（menu/gameover/levelup/paused）淡入由 `ModalIntro(game)`（EaseOutCubic，0.28s）经 `nvgGlobalAlpha` 控制，波次横幅 `DrawWaveBanner` 由 `presentation.waveBannerTimer` 驱动滑入淡出；仅表现层瞬时状态，不得写规则层
- 预瞄轨迹与尾迹契约：产品当前不绘制预瞄线、2D 弹珠尾迹或 3D 车辆尾迹；拖拽瞄准仍只负责发射输入，不向渲染快照生成轨迹。
- 敌方箱体契约：alive occupied cells 仍来自 AircraftPixelData 并保持单敌人 CustomGeometry；`VOXEL_GAP` 只缩小视觉箱体，中心 pitch 继续等于 `brickSize * WORLD_SCALE`；面使用官方木箱材质，缺失时才回退顶点色材质。
- 撞飞箱体契约：命中方块通过 `ejected=true` 立即退出规则碰撞和编队主体，`brick_ejected` 事件带随机速度、角速度和生命周期；Presentation 维护飞散状态，Renderer3D 以独立箱体节点消费，未撞方块继续使用 AABB 碰撞。
- 飞机布局契约：SpawnWave 对飞机完整二维 AABB（含间距）进行候选检查，失败时仅向更高层确定性错位，禁止接受重叠候选。
- 车辆尺寸契约：车辆显示缩放继续从 `marble.radius` 推导，在局部包围半径约束内放大 12%，禁止按球种硬编码额外尺寸。

## 恢复指令（新会话必执行）
1. 读本文件 → 获取项目状态和避雷清单
2. 读 `docs/memory-index.md` → 恢复项目上下文
3. 读 `docs/persona.md` → 加载用户画像和偏好
4. 自测：项目是什么？上次做了什么？下一步？不够清楚就多读文件
5. 如有 likely_next_task → 预加载相关文件
6. 详细规则见 memory-system skill（`**/skills/memory-system/SKILL.md`）

## 避雷清单
- POST 是记忆存活唯一入口，每次交付后必须执行 3 步 POST
- `Game.lua` 是引擎无关的权威规则层，禁止加入 NanoVG、Scene/Node、材质、颜色、粒子、震屏或按键枚举
- 主循环时序契约：`main.lua` 先用上一帧 Presentation 状态决定 hitStop，再调用 `Game.Update()`；随后重新获取 `Game.GetSnapshot()`，同一份更新后快照同时传给 `Presentation.Update()` 和渲染变量，禁止把更新前快照传给表现层或渲染层
- 状态中断契约：`Game.Update()` 在 `UpdateMarbles()` 后、`UpdateEnemies()` 后检查 `gameState`；升级/游戏结束在当前帧切换状态后，禁止继续推进敌人、越线扣血、换弹或波次刷新
- XP 保全契约：升级期间或升级触发同帧新增经验进入 `deferredXp` 原值缓冲，最后一张升级卡完成后只结算一次倍率；禁止用 `pendingLevelUps > 0` 直接丢弃经验
- 输入契约：画布外按下必须过滤；移动和释放允许跨出画布以完成钳制和结束拖拽；升级卡必须用 `ScreenToUi` 命中，玩法瞄准必须用 `ScreenToGame`；playing 态全屏任意位置按下都可起手拖拽（v0.10.15，旧底部 160px 限制已删），弹夹打空且 canRecall 时按下改为召回而非拖拽
- 渲染合成契约：`Backend.Render()` 必须先执行 `Renderer3D.Render()` 再执行 `RenderOverlay()`；NanoVG 仅允许绘制画布外 letterbox 与透明/局部 UI，禁止使用整屏不透明矩形覆盖设计画布
- 弹珠技能契约：基础弹每次直接命中独立 5% 概率生成两颗完整功能分裂弹，分裂弹可继续分裂；加速弹每次反弹/命中加速 15%，按速度最高增至 3 伤并自动追击最近砖块；巨型弹任意有效反弹只武装一次贯穿，贯穿命中造成直径 7 格圆形范围伤害
- 敌方基础下落速度固定乘以 0.25（降低 75%）；冰冻倍率继续叠加在此速度之上
- 视觉瞬时状态必须由 `Presentation.lua` 消费领域事件维护；2D 视觉参数放在 `VisualCatalog.lua`
- 渲染后端只能消费 `Game.GetSnapshot()` 与 `Presentation.GetSnapshot()`，不得反向修改权威状态
- 发现会话外并发修改时必须保留并合并，禁止直接覆盖
- headless 验证器当前会因自带 shader cache 字节码报 engine error；判断脚本时需关注 `lua_errors=0`、`resource_errors=0` 并结合 GLES 截图
- 3D 后端的体素尺寸必须统一经过 `WORLD_SCALE` 映射；Renderer3D 只消费快照，碎片生命周期由 Presentation 维护
- 3D 后端的体素性能契约：每个敌人只允许一个 `CustomGeometry` 根对象，允许面与棱线两个 section；撞飞箱体属于低频瞬时对象，独立节点随 Presentation 生命周期回收。
- 车辆视觉比例：`VEHICLE_PLANAR_RADIUS` 作为局部包围半径基准，世界缩放由 `marble.radius * WORLD_SCALE` 推导；当前显示放大系数固定 1.12，不能突破权威碰撞圆。
- 飞机采样权威契约：`AircraftPixelData.lua` 的 occupied cells 是规则砖块、2D 绘制、3D 体素和碎片颜色的唯一共同来源；禁止恢复 `VeggiePixelData` 敌人轮廓或用完整飞机多边形覆盖逐块缺失。3D 体素中心必须使用 `brickSize * WORLD_SCALE` 的规则 pitch，`VOXEL_GAP` 只能缩小体素本体，不能改变中心间距；occupied cells 只有二维 XY 邻接，XY 内部侧面可剔除，但每个 alive cell 的前后 Z 端面必须生成，禁止再把自身误判为 Z 邻居
- 相机契约：必须使用正交投影，禁止透视近大远小；当前相机从 XY 玩法平面法线向正视方向倾斜 46°，位置按 `(0, 25*sin(46°), -25*cos(46°))` 计算，`orthoSize=18.0`，保证 540 宽场地在 9:16 视锥内完整可见；车辆仍在 XY 平面绕 Z 轴朝向速度或瞄准发射向量
- 载具表现契约：每个 `marble.id` 对应一个大运式平头重卡 `CustomGeometry`，内部固定为主车漆/浅色侧围/轮胎/金属/玻璃/灯光 6 个 PBR section；禁止恢复球形弹珠、外部整车 MDL、固定装饰车发射台、跑车/皮卡轮廓或方块体素瓦片车辆
- 大运重卡几何契约：必须具备平头高顶驾驶室、长货厢、三轴六轮、大面积前风挡、重卡格栅与外露保险杠；浅色侧围必须作为独立材质分区；车辆局部 +X 为车头，飞行朝向由速度计算，待发射瞄准时由发射向量计算；显示朝向必须以 420°/s 沿最短角追踪目标朝向，禁止直接跳变；规则层仍保留统一发射坐标
- 载具碰撞比例契约：程序化车辆局部 XY 包围半径固定按 `VEHICLE_PLANAR_RADIUS` 计量，世界缩放只能由 `marble.radius * WORLD_SCALE * VEHICLE_COLLISION_FILL / VEHICLE_PLANAR_RADIUS` 推导；视觉外轮廓当前占权威碰撞圆 98%，禁止按 `isPrimary`、`ballType` 再叠加经验倍率
- 体素立体表现契约：正面使用主色，背面/左右/顶面采用明显浅色因子；每个暴露面使用窄深色棱线 strip，棱线与面共用敌人单一 `CustomGeometry` 的第二 section，禁止新增逐棱节点
- UI 视觉契约：raw NanoVG 固定使用 540×960 设计分辨率模式 A；v0.9.4 全部页面统一 Astroon 深蓝紫渐变与紫色 surface，使用蓝/青交互强调、白色文字、金色焦点；playing HUD 保留顶部战术仪表盘、底部两侧四弹药槽火控舱和中央战场安全空间；禁止恢复无层级文字堆叠、整屏不透明 NanoVG 覆盖 3D Viewport、页面间蓝白/深紫混搭或升级卡消失
- UI 投影契约：NanoVG 与 3D `Viewport` 继续共用 540×960 CONTAIN 缩放、居中偏移和 DPR；NanoVG 只能填充画布外 letterbox，设计画布内部必须保持 3D 可见；升级卡视觉布局与 `main.lua:TryPickUpgradeAt` 命中布局必须共享 cardW=156/cardH=214/gap=8/cy=478，且升级命中使用 `ScreenToUi` 而非 `ScreenToGame`
- 投影对齐契约：3D 车辆根节点使用 `GetVehicleAnchorWorld(marble)`；NanoVG 预瞄线使用 `Renderer3D.GetVehicleAnchor()`；2D/3D 拖尾使用 `GetTrailAnchor()`/`TRAIL_DEPTH_OFFSET`；禁止让预瞄/拖尾回退到独立经验 offset 或另一套简化线性投影
- 9:16 铁律：NanoVG 与 3D `Viewport` 必须共用同一个 CONTAIN 缩放与居中偏移；非 9:16 屏幕只允许画布外 letterbox，禁止拉伸、裁切或让 3D 铺满而 UI 单独居中；输入先使用同一 DPR/scale/offset 回到设计画布，再使用相机玩法平面投影参数逆变换到权威游戏坐标，画布外按下必须被过滤
- 倾斜正交输入契约：玩法 XY 平面经 46° 相机投影后不等同于 540×960 UI 坐标；`Scene3DBackend` 必须用 `Camera:WorldToScreenPoint()` 标定投影 offset/scale，且每次相机震屏位移后必须无日志刷新；`ScreenToGame()`、瞄准轨迹和空间反馈共享这组当前参数，禁止把屏幕设计坐标直接传给 `Game.Pointer*`
- 瞄准轨迹契约：轨迹首点必须是当前 `activeBall.x/y`，确保车辆中心与轨迹起点重合；当前使用 8 单位步长、140 次采样并按权威半径处理左右/顶部反弹，禁止恢复缺首点的短 50 点预测
- UI 安全层契约：HUD、playing Dock、menu/gameover modal 必须以不透明硬边区域遮断世界层；当前 HUD 为 `y=0..92`，playing Dock 为 `y=866..960`，四槽只在 playing 态绘制；menu/gameover 从 HUD 下缘覆盖至画布底，非 playing 态禁止绘制弹夹、瞄准轨迹和基地冲击反馈；首页与升级模态的 CTA/卡片不得与主视觉光环冲突
- 投影审查契约：判断 UI 与玩法对象是否遮挡前，必须先把权威坐标通过当前 `projectionOffset/Scale` 投影到 540×960 屏幕设计空间；禁止把 `Game.lua` 的 `y` 直接当屏幕 `y` 并据此修改危险线、弹弓或碰撞规则
- 敌我尺寸契约：敌方权威 `brickSize` 为前两波 14、3–4 波 15、后续 16；我方权威半径为分裂 20、冰冻 20、加速 18、巨型 30，Renderer3D 必须继续由快照半径推导模型缩放，禁止仅做视觉假放大
- 飞行器底座契约：敌方底座与推进器必须位于阵列远离玩家的一侧（设计坐标上方）；靠近防线的规则判定只使用阵列底边 `enemy.y + height`，备用 2D 与 3D 后端方向必须一致
- 四弹药槽契约：3D 后端底部必须显示分裂/冰冻/加速/巨型四个 64×64 小正方形槽位，前两格停靠左下、后两格停靠右下；每格保留序号、中文名、装填态、储备数量和类型色，中间必须留出弹弓/车辆可视空间，禁止恢复横向铺满底边或退化为纯文字图例
- 防线撞击契约：`base_hit` 必须先由 `Presentation.lua` 维护瞬时状态，再由 3D 后端消费为相机震动、防线材质脉冲、冲击波和警示文字，禁止只扣血无空间反馈
- 幸存者核心契约：基地生命 `BASE_HP=100`，敌方以编队整体下移（`enemy.y += vy`）；越线按**行**结算——越线方块先按 brick.row 分组，该行全部碎裂（飞箱但不加分/经验，`ShatterBreachedBrick`），每帧扣血只算一次：`max(1, ceil(越线行数*0.5) + lineDamageBonus)`，装甲/玻璃大炮改 `lineDamageBonus`（整体加成，禁止逐块乘）；`Game.lua` 用 `gameState="levelup"`/`"paused"` 暂停玩法，禁止在规则层调渲染。
- 经验与升级契约：击碎方块获 `XP_PER_BRICK`、清整支飞船获 `XP_PER_CLEAR`（+连击加成），跨级累计 `pendingLevelUps` 并冻结经验；升级池 `UPGRADE_POOL` 的 `apply()` 只修改 `BALL_TUNING`/`baseHp` 等规则变量，必须通过 `Game.GetSnapshot().upgradeChoices` 暴露给 UI 三选一，禁止硬编码升级效果到渲染层
- 波次节奏契约：幸存者持续涌出，间隔随波次从 `WAVE_INTERVAL` 收紧到 `WAVE_INTERVAL_MIN`，并受 `MAX_CONCURRENT` 同屏上限约束；禁止恢复"清场才出下一波"的离散波次
- 世界边界契约：左/右反弹边为游戏坐标 0/DW 并渲染到 3D 背景层（`CreateWorldEdges`）与 2D 设计空间边框一致；顶部反弹边为 `TOP_BOUND_Y=-135`（0 与 -270 的中值，投影在 HUD 下方战场顶部），视觉顶边与规则共用常量，左右边线向上延伸闭合。禁止把边界只当视觉或把游戏 y=0 当屏幕顶；`Game.lua` 边界规则是权威碰撞来源。
- 拖尾比例契约：拖尾宽度必须锚定权威碰撞半径（`marble.radius * WORLD_SCALE`），巨型车拖尾不得宽于车辆本体；车辆视觉仍由 `marble.radius * WORLD_SCALE * VEHICLE_COLLISION_FILL / VEHICLE_PLANAR_RADIUS` 推导
- 像素敌人契约：敌方 occupied cells 参考经典太空飞机弹幕像素剪影（蟹形入侵者/箭头战机/圆盘飞碟/截击机），继续由 `AircraftPixelData.lua` 单一来源驱动规则、2D、3D 与碎片；禁止恢复战斗机写实轮廓或蔬菜阵列
- 加速弹削弱契约：加速弹 `speedBoost` 收紧到 1.06、`maxSpeed` 900、`damageStep` 320、`maxDamage` 2，且自动追击受 `redirectThrottle=0.45s` 节流；禁止恢复 1.15/1250/3 的强成长与无节流黏着
- 顶点色体素必须使用支持 VCol 的 Technique 并绑定白色基底纹理；`NoTextureUnlit` 不保证消费顶点颜色
- 3D 星空必须位于游戏物体后、深空底板前，按层合批；禁止每颗星创建 Node。当前验证环境不可启用 FXAA，否则 ESSL shader cache 失败会吞掉整层 3D 画面
- headless 运行时可出现自带 shader cache engine error；判断脚本需关注 `lua_errors=0`，同时确认资源错误不包含用户车辆/体素路径并结合 GLES 截图

## 工作流模板（收到任务后立即创建） 🔴

**核心原则：POST 前置，不是后置。** 收到任何非纯讨论的任务后，第一个动作就是用 TodoWrite 创建包含 POST 的完整工作流。这样即使后续上下文被冲，POST 条目仍然存在，AI 会被未完成的 todo 驱动继续执行。

```
TodoWrite([
  { content: "DEV: [具体任务描述]", status: "in_progress" },
  { content: "POST-1 更新记忆：CLAUDE.md（状态+避雷）+ memory-index.md（变更记录）+ persona.md（用户特征）", status: "pending" },
  { content: "POST-2 持久化：versions.md 追加版本行 + git add + commit", status: "pending" },
  { content: "POST-3 同步随行记忆：合并写入 .agent/memory-runtime/（persona + antibodies + preferences）", status: "pending" }
])
```

**强制判定原则**：每个 POST 步骤执行时必须做"执行/跳过"判定：
- 执行 → 正常完成并标记 completed
- 跳过 → 必须在 TodoWrite 条目中标注理由，如 `POST-3 [判定跳过: 小调整无跨项目信息]`
- 禁止：直接删除 POST 条目、不做判定就跳过、因为"上次跳过了"这次也跳过

**小调整可简化判定**: POST-1 简写 + POST-2，POST-3 判定跳过并标注理由。
