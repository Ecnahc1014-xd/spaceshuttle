# 太空飞机弹珠 — 项目核心记忆

> AI 自维护，每次 POST 自动更新。详细规则见 memory-system skill。

## 当前状态
- 版本: 0.10.33（玩家向中文 UI）：
  - HUD/Dock/菜单/结算/升级/暂停/波次横幅全部改中文可读文案，去掉驾驶舱黑话和英文状态码。
  - 升级卡命中几何仍 168×300@cy530；dark-tech 骨架保留。
  - 验证：LSP 0、build 成功。
- 上次交付: v0.10.33 玩家向中文 UI

## 历史
- 版本: 0.10.32（激励广告复活 + clientCloud 云高分）：结算看广告回 50 血，本局一次；云高分 high_score。
- 版本: 0.10.31（底部中央下一波敌人小图）：nextWavePlan 同源预抽；Dock 中央 156×70 像素剪影+倒计时。
- 版本: 0.10.30（8bit 街机剪影 + 同波阵型）：8 机 ASCII 位图（蟹/黄蜂/蝴蝶/蜜蜂/宽翼/飞碟/双荚/截击）；同波同机 line/vee/grid/swarm。
- 版本: 0.10.29（修剩余碰撞漏检与碎裂未完成）：子步进收集重叠格打最近格、步进 6–16；挖空失败可重试并用规则签名强制对齐网格。
- 版本: 0.10.28（按 ecnach-ui-skill 重构精细 UI）：
  - **令牌**：废弃 Astroon/Laterano 蓝紫+金色。全页改 dark-tech：`bg/panel/rail/card/widget` 深黑蓝层级，品牌青 `cyan` 唯一强调，`warn` 仅警告/连击，红色仅错误/低血。
  - **骨架**：HUD/Dock 左 4px 青识别线 + 刻度；菜单/结算/暂停用窗口壳（标题栏竖线、角标、断线边框、局部微型网格）；主 CTA 青底 `ink` 字。
  - **升级卡**：几何仍 168×300/gap8/cy530（与 `main.lua` 命中同步）；外观改 card 底 + 稀有度左竖线/角标，不再用紫面+金边。
  - 玩法/3D/9:16 未改。验证：LSP 0 Error、官方 build 成功。
- 上次交付: v0.10.28 dark-tech HUD/模态精细重构

## 历史
- 版本: 0.10.27（波次再放慢 + 首波入场加快 + 修碰撞/碎裂丢失）：基础间隔 18s/下限 9s/收紧 0.15/首波冷却 3.2s；全局下落 0.42、首波速度 28；高速弹自适应子步进+扫掠；体素碎块失败回退 CustomGeometry。
- 版本: 0.10.26（修复 Preview 体素路径：敌机消失 + 碎块 1:1:2）：
  - **根因 1 敌机不可见**：编队被 FinalizeVolumeAsDynamic，动态体 Node 在质心；每帧 `node.position = 网格最小角` 把整机平移出视野，只剩独立碎块。现改为 `FinalizeVolume` 静态体，每帧只改 `GetNode().position`，不 RebuildDynamicProxy、不清速度。
  - **根因 2 碎块 1:1:2**：`CreateVolume(1,1,dimZ=2)` 是扁长条。碎块改 `voxelDebrisDepth_=1` 的 1×1×1 立方，编队主体仍 gridW×gridH×2 保持厚度。
  - **API**：体积 Node 一律 `volume:GetNode()`，禁止 `.node`。编队 `destructible=false`，命中仍 HollowBrick 挖空 + 独立动态碎块。
  - Linux CLI 仍 `voxel_physics=false` 走 CustomGeometry；Preview/真机走静态体积路径。规则层 AABB 未改。
  - 验证：LSP 0、build、headless 200 帧 lua=0 + VoxelPhysicsWorld unavailable 回退日志。
- 上次交付: v0.10.26 编队改静态体积+碎块改立方，修 Preview 敌机消失/扁条碎块

## 历史
- 版本: 0.10.25（接入引擎 VoxelPhysicsWorld，探测失败自动回退 CustomGeometry）：探测 CreateComponent，失败回退 CustomGeometry；规则层仍 AABB；模块可用时每敌机一体积网格+挖空+独立碎块。Linux CLI 未启用模块。
- 版本: 0.10.24（第 2 轮 10 项自主优化，聚焦移动端触摸闭环/输入防穿透/正反馈补全）：
  - **触摸恢复暂停**：Game.PointerDown 在 paused 态直接 Resume（移动端无键盘），DrawPaused 文案改"点击屏幕或按 P 继续"+英文副行。
  - **Pause/升级都取消拖拽**：Game.Pause 与进入 levelup（CheckLevelUp 分支）都把 aiming=false 并让 activeBall 归位 SLING，防恢复/选完强化后残留旧蓄力。
  - **低血量红色脉冲**：DrawHud hpRatio≤0.35 时基地血条文字色按 sin·7 在红↔亮红间脉冲。
  - **连击高亮**：HUD `COMBO xN` 在 clearStreak≥2 时改金色并随 sin·8 放大 1-2px。
  - **升级确认飘字**：FEEDBACK_MAP 登记 upgrade_picked→upgradeConfirm，中心青色"XX 已装配"飘字+轻微震屏（恢复 playing 后可见）。
  - **补弹 Dock 轻闪**：主球回收移除时 Emit marble_reloaded(ballType)（Game.UpdateMarbles 仅 isPrimary），Presentation.reloadFlash=0.3 衰减/重置/快照；DrawAmmoSlots 画 Dock 顶边一道从右向左的青色扫光 + 激活槽短暂提亮。
  - **发射点扩散环**：launchFlash 处理器追加一个 shockRing（r 8→26、0.24s、随弹种色），复用既有冲击环通道，零新增渲染路径。
  - **升级空白点击防御**：main.lua 的 Mouse/Touch 在 levelup 态对 Up/Move 全部拦截不穿透；Down 点卡片外不关面板、触发 Presentation.PulseUpgradeHint()（右下角"TAP A CARD TO EQUIP"金色脉冲放大 0.5s）。DrawLevelUp 签名加 presentation。
  - **菜单/结算松手确认**：PointerDown 在 menu/gameover 只武装 startArmed（不再按下即 StartGame），PointerUp 松手才 StartGame；死亡瞬间手指仍按着时抬手不再误重开。ResetGame 清 startArmed。
  - 验证：LSP 0、build、surfaceless 2503 帧 lua=0、探针自动开局+持续发射+自动选卡截图（wave4/LY03/8 机同屏/弹种轮换/Dock 状态正常）。临时探针已删。
- 上次交付: v0.10.24 触摸恢复暂停+暂停/升级取消拖拽+低血脉冲+连击高亮+升级飘字+补弹扫光+发射环+升级空白防御+松手开局

## 历史
- 版本: 0.10.23（10 轮自主优化，聚焦反馈闭环/可读性/防堆积/清死代码）：
  - **修复飘字在 3D 从不显示**：Presentation.floatTexts（+分数、防线-x、分裂/追击/贯穿/圆域等）此前只被已删除的旧 2D Renderer 消费，3D 后端无消费者。现 Scene3DBackend 新增 DrawFloatTexts，在 playing overlay（震屏 transform 内）用 ProjectGamePoint 世界→设计坐标投影绘制，末段放大+淡出、深色 nvg 描边保证亮字可读。
  - **新增击毁扩散环** Presentation.shockRings：击毁砖块 34% 概率一个从 r0=6 扩到 r1=20、0.3s 淡出的圆环（DrawShockRings，NanoVG 圆描边）。
  - **基地受击边缘红闪** DrawDamageVignette：由 baseBarrierFlash 驱动，屏幕四边向内红色渐变（HUD 层、不受震屏影响）。
  - **Boss 波红色警告横幅**：wave_started 带 isBoss（规则层 boss 分支 Emit），Presentation 存 waveBannerBoss，DrawWaveBanner 改红框+"!! WARNING !! // BOSS"+脉冲。
  - **瞄准线随蓄力渐长**：s.aimLine 增加 power（死区→满拉 0..1），Renderer3D 显示点数 30%→100%、尺寸 ×(0.7+0.3·power)，弱拉不再整条拉满到边界。
  - **防视觉堆积**：①烟雾去掉 UpdateParticles 里持续 `-14·dt` 上升项，改 0.90 强阻尼原地缓漂（旧逻辑导致烟全堆到屏顶）；②飞散 3D 箱体 EmitBrickShatterFx 初速 240-500→120-270、上抛 180-300→80-170、寿命 1.15-1.7s→0.7-1.1s，解决顶部大量立方体长时间悬停。
  - **清理死代码**：删除遗留探针 `_texprobe.lua`、旧 2D 后端 `Renderer.lua`+`NanoVGBackend.lua`（main 只用 Scene3DBackend）、旧蔬菜数据 `VeggiePixelData.lua`+空 `VeggieData/`（含 .meta）。scripts 仅剩 7 个 .lua。
  - 验证：LSP 0、build、2500 帧 lua=0、截图确认瞄准线贴车/软圆渐小、飘字与冲击环、粒子稀疏。
- 上次交付: v0.10.23 飘字3D可见+冲击环+边缘红闪+Boss横幅+蓄力渐长瞄准线+防堆积+清死代码

## 历史
- 版本: 0.10.22
- 进度（瞄准线起点对齐 + 粒子更小更少更不均一）：
  - **瞄准线起点修复（关键 bug）**：相机是 46° 斜俯视**正交**（不是纯俯视），z 差会投影到屏幕 Y——之前瞄准线固定 z=-6、车辆锚点 z≈0.09，导致整条线在屏幕上相对车辆偏移（截图可见线在左下、车在右下）。修复：SyncAimLine 起点直接用 `GetVehicleAnchorWorld(activeBall)`（XY 和 z 都取车辆锚点），终点用同一 z；规则层 ComputeAimLine 的 x1,y1 本就等于 activeBall.x/y（日志验证一致），问题纯在渲染 z 平面。瞄准线视觉也重做：22 个等大青方块 → **14 个青色软圆点，t 从 0（车中心）到 1（边界），尺寸 ×(1-0.55t) 渐小**；材质改 DiffAlpha+烘焙青色软圆纹理（旧 DiffVCol 忽略纹理 alpha 显示方块）。
  - **粒子进一步稀疏/变小/去均一**：Presentation 生成尺寸与生命随机范围拉大（spark 1.4-3.4px/0.18-0.42s，shard 2-4.5px、spin ±16，smoke 4-10px/0.45-0.9s 速度更小）；击毁=1-2 spark+55%概率1 shard+20%一缕烟，普通命中仅 35% 出 1 spark；防线 4-7 spark+35%烟，发射点击仅 1 spark+15%烟，分裂/追击/贯穿/巨型粒子数再降且数量随机。Renderer3D 世界尺寸系数整体下调（spark ×0.85、shard ×1.25、smoke ×0.85，最小尺寸 0.012-0.015m）。
- 上次交付: v0.10.22 瞄准线起点对齐车辆锚点 z（斜俯视投影坑）+软圆渐小，粒子更小更少随机

## 历史
- 版本: 0.10.21
- 进度（粒子重做：烟雾+三角碎片+小火花，点击轻反馈）：把原来"不透明、纯色、大小一致的方块粒子"换成三类**小而稀疏、偶尔点缀**的柔和粒子，全部程序生成纹理无外部资源：
  - **spark 小火花**：暖白软圆（烘焙色 1.0/0.92/0.62），短促收缩；击毁 3 粒、普通命中 50% 概率 1 粒（不再必出）。
  - **shard 三角碎片**：浅金属米色等腰三角（烘焙色 0.95/0.82/0.52），受重力、持续自旋（Presentation p.angle/p.spin → billboard.rotation），末 35% 收缩；击毁固定 2 片。
  - **smoke 烟雾**：灰蓝软圆（烘焙 rgb≈.72-.80、中心 alpha .5 边缘 0），上飘减速无重力、持续膨胀、半透明；击毁 35% 概率 1 缕、发射 25%、防线/巨型贯穿少量。
  - **点击发射反馈**：launchFlash 从 8 粒降为 2 粒随弹种颜色小火花 + 25% 一缕烟，轻度不刷屏。各事件粒子量整体下调（防线 24→10、分裂 16→5、追击 10/8→3/2、贯穿 16→5、巨型 32→≤8）。
  - Presentation.SpawnParticles(x,y,color,count,kind) 加 kind（默认 spark），UpdateParticles 按 kind 分运动；粒子对象池沿用，新增 p.kind/p.angle/p.spin。Renderer3D 从单 BillboardSet 改为**三个独立 BillboardSet**（particleSets_.spark/shard/smoke，槽 64/40/28，z=-0.95），各自绑定彩色程序纹理 + **Techniques/DiffAlpha**，SyncParticles 按 p.kind 分流；淡出统一靠末段尺寸收缩而非顶点 alpha。
  - ⚠️**关键显色坑（v0.10.21 实测，覆盖 v0.10.18 结论的一部分）**：透明粒子要"彩色+软边/异形"时，**DiffVCol 不透明会忽略纹理 alpha（软圆/三角显示成方块）；DiffVColAdd 读顶点色但也忽略纹理 alpha；DiffAlpha 读纹理 alpha 但不读 billboard 顶点 rgb（顶点色只影响 alpha/开关）**。唯一可行：**颜色烘焙进程序纹理 + DiffAlpha**，顶点色保持白。需要彩色透明软粒子就按此，不要指望 DiffVCol+alpha 纹理。三角纹理因 Billboard UV 的 V 翻转，生成时要把形状沿 y 反向画才能正向显示。
- 上次交付: v0.10.21 烟雾/三角碎片/小火花三类柔和粒子 + 点击轻反馈（DiffAlpha 烘焙纹理）

## 历史
- 版本: 0.10.20
- 进度（敌机扩到 8 种）：在原 4 型（scout青/striker红/bomber黄绿飞碟/interceptor紫精英=Boss）上新增 4 型，**外观轮廓与色相、运动性格都分化**：dart 金黄后掠翼尖头飞镖（11×9，最快 speedMul1.22/descent1.28/swayFreq1.35，wave2）、hive 橙色蜂群小机（9×7 最小，speed1.12/swayFreq1.6，wave4）、manta 翡翠绿宽翼鳐鱼（14×8 最宽，大横摆 swayAmp36，wave5）、cruiser 钢灰重装盒（13×9 装甲最密，最慢 descent0.68，wave8）。AircraftPixelData 新增 `bitmapToData(rows)` 位图转换器（字符 M=hullMain/d=hullDark/C=canopy/E=engine，映射到 ClassifySlot 能识别的像素 RGB；新机型用 ASCII 位图而非手写 entry 串），M.behavior 加四型；VisualCatalog.AIRCRAFT_PALETTES 加四套色相。Game 把硬编码 4 型解锁改为 **WAVE_ROSTER 门槛表**（scout1/dart2/striker3/hive4/manta5/bomber7/cruiser8/interceptor9，GetAvailableTypes 遍历过滤）。渲染完全 data 驱动无需改 Renderer3D。LSP 0、build、1500 帧 lua=0、8 机型同屏截图确认轮廓配色。
- 上次交付: v0.10.20 敌机 4→8 种（位图转换器+四新机型+WAVE_ROSTER）

## 历史
- 版本: 0.10.19
- 进度（3D 直瞄线）：拖拽蓄力超过 15px 死区时显示一条从待发车辆沿发射方向到最近玩法边界（左/右/TOP_BOUND_Y，不含底）的点状青色虚线，松手/死区内不显示。规则层 ComputeAimLine（local，GetSnapshot 之前定义）只在 `aiming 且 activeBall` 时算 {x1,y1,x2,y2}，方向=-pull 归一化（与 LaunchMarble 一致），射线按 activeBall.radius 求最近正 t，s.aimLine 输出、无瞄准时 nil。渲染层 Renderer3D.SyncAimLine 用**单 BillboardSet（22 槽，AimLine 节点，白 1px 纹理+DiffVCol+billboard.color）沿射线 t=(i-.5)/22 排点**，点世界尺寸 0.085m、z=-6（正交投影 z 不改屏幕 XY，只避遮挡雾）、alpha 起 1.0→终 0.65 渐隐；空槽 enabled=false、每帧 Commit；Init 建/Shutdown 释放。⚠️关键避坑：本引擎动态 CustomGeometry 的 DefineColor 顶点色与 NoTextureUnlit/NoTextureVCol/MatDiffColor 在游戏 Zone 光照下**实测恒显灰白**（独立探针场景无 Zone 时显色正常，游戏场景失效；纯红顶点色也灰白），只有 BillboardSet+DiffVCol+billboard.color（碰撞火花同款路径）在游戏场景稳定显色——辅助线/特效要彩色就走 billboard，不要再试 CustomGeometry 顶点色。基线 v0.10.18：碰撞火花 BillboardSet(96) z=-.95；无召回；全屏相对拖拽；回收 vy>0 越 DANGER_Y。LSP 0、build、400 帧 lua=0、拖拽截图确认青色虚线。
- 上次交付: v0.10.19 3D 点状虚线辅助瞄准（规则层 aimLine + billboard 渲染）

## 历史
- 版本: 0.10.18
- 进度: 碰撞粒子特效实装到 3D 后端（此前 Presentation.particles 只被旧 2D Renderer 消费，3D 后端完全没画，碰撞无火花）。Renderer3D 用**单个 BillboardSet**（96 固定槽、relative=false、白 1px 纹理 + DiffVCol，每粒子 billboard.color 顶点色）承载全部火花，只占 1 draw call；SyncParticles 把 presentation.particles 的设计坐标经 GameToWorld 映射到 z=-0.95（浮在敌机体素与飞散箱之前），worldSize=p.size·WORLD_SCALE·3.4·(0.45+0.55·lifeT)（最小 0.05m，随生命收缩），alpha=clamp(lifeT/0.65) 前段全亮后段淡出；超出 96 丢弃，槽位 enabled=false 复用。Init 创建、Shutdown 释放节点/组件/材质。沿用既有 brick_hit 粒子（击毁 10 粒暖白/命中 4 粒、分裂/追击/贯穿/召回已删事件各色）。验证：独立场景与游戏场景固定色块双探针确认 billboard 顶点色+位置+尺寸在本渲染管线可见；同步计数 active=8..38；400 帧 lua=0、build 成功。基线 v0.10.17：无召回（球自然回落）、全屏相对拖拽、回收 vy>0 且越 DANGER_Y、升级卡 cy530 详情垂直居中。
- 上次交付: v0.10.18 3D 碰撞火花（BillboardSet 批次粒子）



## 用户画像摘要
- 使用简体中文沟通
- 重视先做架构解耦，为后续 3D 开发降低迁移成本 [observed]
- 倾向"全部执行别停下"的批量推进风格，要求逐批 LSP+构建+契约+提交 [observed]

## 预测下一步
- likely_next_task: Preview 验收中文 UI 是否一眼能懂（菜单点开始、战斗分数/防线/下一波、结算看广告复活/再来一局）。禁止把英文黑话加回去。顺带真机测广告与云高分。
- 相关文件: `scripts/main.lua`, `scripts/Game.lua`, `scripts/Scene3DBackend.lua`, `scripts/Presentation.lua`

## 本批次新增避雷（v0.10.33 玩家向中文 UI / v0.10.32 广告/云存档）
- ⚠️ 玩家 UI 必须中文优先（v0.10.33）：标题、按钮、HUD 标签、结算、升级提示用玩家能看懂的中文。dark-tech 装饰可以留，但禁止把 FLIGHT CONTROL / SESSION SEALED / HOSTILES 这类黑话当主文案。升级卡几何不要跟着文案一起改。

- ⚠️ 激励广告契约（v0.10.32）：只接 `sdk:ShowRewardVideoAd`；`success==true` 才发奖。`accepted==false` 可能无回调，必须同时处理返回值与回调，并用一次性 `completed` 防重复。中途关闭不复活。广告/云 API 只在 `main.lua`。
- 结算按钮几何必须与 `HitTestGameOverButton` 同源；禁止结算页全屏松手重开。每局只能复活一次。
- 云高分用 `SetInt/Get` 的 `high_score`（iscores）。`clientCloud` 失败只标 LOCAL，不挡开局。

- ⚠️ 下一波预告必须同源（v0.10.31）：规则层 `PlanWave` 预抽并锁定 `nextWavePlan`，`SpawnWave` 消费同一份，禁止 UI 再 Random 一次。`GetSnapshot` 只读 `nextWavePlan`，不在快照里抽签。小图放 Dock 中央（四槽左右分组中间），只画 VisualCatalog 像素格，禁止新贴图。

- ⚠️ 同波必须同机成阵（v0.10.30）：随机散点 + 混种会把 8bit 剪影拆成“一坨砖”。`SpawnWave` 抽一种机、按 `line/vee/grid/swarm/wedge/stream` 算槽位；宽机 3+ 走 2+1 grid，不要硬塞横排再退化成纵列。整队锁定 swayAmp/swayFreq/phase，opts 里 0 必须用 `~= nil` 判断。
- 底座契约仍有效：位图小 row = 引擎/背侧（远离玩家），大 row = 朝玩家。新剪影禁止把推进器画到阵列底边。
- ⚠️ 多格重叠不要按数组顺序 break（v0.10.29）：圆同时压住几格时，bricks 表顺序命中第一格会漏掉真正碰到的格（穿机翼/座舱无碰撞）。应收集本步重叠格、打距离最近的一格；挖空失败禁止一次性 consumed，必须按规则签名强制对齐网格。
- ⚠️ UI 令牌契约（v0.10.28）：只用 `C.bg/panel/rail/card/widget/cyan/cyanDim/ink/text/dim/warn/error`。青色只表示焦点/激活/主操作/进度，禁止把标题、边框、图标全染青；金色不再是主 CTA（改青底 ink 字）；警告用 `warn`，错误/低血才用红。装饰限 2–3 种：角标 + 断线边框 + 局部微型网格/刻度，贴边不穿正文。
- 升级卡几何仍 168×300/gap=8/cy=530/`HIT_PAD=4`，与 `main.lua:TryPickUpgradeAt` 同步；本次只换外观，禁止改命中常量。
- HUD `y=0..92`、Dock `y=866..960`、四槽左右分组、letterbox 只填画布外：信息架构不变。

- 节奏数值必须四处一起改（v0.10.27）：BALANCE.waveInterval / waveIntervalMin / waveTightenStep、ResetGame 首波冷却、GetWaveParams 基础速度、CreateEnemy 全局下落系数。只调间隔会留下“下一波还没来但首机仍贴顶蠕动”。多次放慢仍会被嫌快（9.5→11→14→18s）。
- ⚠️ 体素碎裂必须有可见回退（v0.10.27）：体素路径不再画全部 ejectedBoxes。CreateVolume 碎块或 HollowBrick 失败时必须 `needVisualFallback` 走 CustomGeometry，否则命中只有缺口或完全无特效。高速弹要自适应子步进 + 扫掠，4 步不够会穿格。
- ⚠️ 编队体积必须静态（v0.10.26）：`CreateVolume` 的 position 是网格最小角；动态体 Node 在质心。每帧把动态 Node 设回最小角会把整机平移出视野（敌机消失、只剩碎块）。编队用 `FinalizeVolume` 静态体，每帧只改 `GetNode().position`；碎块才 `FinalizeVolumeAsDynamic`。禁止对编队 RebuildDynamicProxy / SetLinearVelocity。
- ⚠️ 碎块必须是立方（v0.10.26）：编队深度 2 是为了斜视厚度；碎块再 `CreateVolume(1,1,2)` 就是扁长条 1:1:2。碎块用 1×1×1（voxelDebrisDepth_=1）。
- 体积 Node API：用 `volume:GetNode()`，不要 `.node`。
- ⚠️ VoxelPhysicsWorld 探测契约（v0.10.25）：`scene:CreateComponent("VoxelPhysicsWorld")` 返回 nil 表示当前运行时未编译该模块（Linux CLI 实测未知类型 ECEBFC51）。探测必须 pcall，失败只打日志并走 CustomGeometry，**禁止**把失败当 `Backend.Init=false`（否则 Start 不订阅事件，UI 消失卡死）。一个 Scene 只能有 PhysicsWorld 或 VoxelPhysicsWorld 其一；本项目不用 Bullet。
- ⚠️ 体素物理与权威规则分离（v0.10.25）：规则层继续 AABB 逐块碰撞；体素体积只做表现。编队位置每帧由快照传送静态 Node，collisionMask=0，禁止让 Jolt 推动编队。
- ⚠️ 禁止对编队主体 ApplyDamage（v0.10.25）：伤害 API 会按连通性分裂体积，机翼/座舱会变成独立刚体，和“整机编队下移、逐块 AABB”冲突。命中=HollowBrick 只挖当前格 occupancy + 另建 1×1×1 动态碎块赋初速。挖空后立刻把该机 signature 对齐快照，避免同帧 FillEnemyVolume 把刚挖的格填回去。
- 体积原点契约（v0.10.25）：VoxelVolume 原点在网格最小角。规则 enemy.x/y 是阵列左上、设计 Y 向下、世界 Y 向上，原点=GameToWorld(x, y+gridH*brickSize)；体素 (col-1, gridH-row, z) 对应规则格 (col,row)。voxelSize=brickSize*WORLD_SCALE，编队深度 2 体素、碎块深度 1，z 居中。调色板槽位只由 VisualCatalog.GetVoxelMatIndex 分配（1-64），CreateVolume 前 SetPaletteEntry 完毕。
- 碎块预算：MAX_VOXEL_DEBRIS=24，碎块 evictable=true、编队 evictable=false；超预算删最老碎块。模态（非 playing）SetSimulationPaused(true)。
- Linux CLI / 部分运行时体素物理未启用：headless 验证只能证明回退路径 lua=0，不能证明碎块物理；真机验收必须看 VoxelPhysicsWorld ready 日志。

## 历史避雷（v0.10.24 输入闭环 / WO-13/16/14/15/P11/P12）
- 模态输入防穿透契约（v0.10.24）：main.lua 每个 Mouse/Touch 处理器必须先判模态再决定是否调 Game.Pointer*——levelup 态 Down 只走 TryPickUpgradeAt（UI 坐标 ScreenToUi），且 **Move/Up 在 levelup 态直接 return**（旧代码 Up/Move 无模态守卫，升级面板上抬手会穿透成玩法 PointerUp）。paused 态 PointerDown 恢复（移动端无键盘）。卡片空白点击不关面板、调 Presentation.PulseUpgradeHint() 做提示脉冲，禁止让空白点击关闭/透传。
- ⚠️ 模态切换必须取消拖拽（v0.10.24）：进入任何非 playing 模态（Pause、CheckLevelUp 进 levelup）都要 `aiming=false` 并把 activeBall 归位 SLING，否则拖拽蓄力中触发升级、选完回到 playing 会残留 aiming/grabStart 导致下一抬手误射。
- 菜单/结算松手确认契约（v0.10.24）：menu/gameover 的 PointerDown 只置 startArmed=true（不立即 StartGame），PointerUp 在仍处于该态且 startArmed 时才 StartGame——防止死亡瞬间手指还按着、抬手即误重开。startArmed 在 ResetGame 清。键盘 SPACE/RETURN 仍走 HandleAction 不受影响。
- 补弹/发射瞬时反馈契约（v0.10.24）：主球回收移除（UpdateMarbles，仅 isPrimary）Emit marble_reloaded{ballType}→Presentation.reloadFlash(.3s)→DrawAmmoSlots 顶边青色扫光+激活槽提亮；发射环直接在 launchFlash 处理器里 push 一个 shockRing（r8→26/.24s/随弹种色），复用 shockRings 通道，**禁止为单次反馈新建 BillboardSet/draw call**。这类纯瞬时状态只写 Presentation，不进规则层。
- 敌机扩展契约（v0.10.30 最新）：敌机=像素网格砖块（AircraftPixelData.M.xxx：hp/score/speedMul/gridW/gridH/data）+ behavior 表 + VisualCatalog 四槽位色 + WAVE_ROSTER 门槛，四处 key 一致；渲染完全 data 驱动，加新机**不改 Renderer3D**。轮廓一律 `bitmapToData`（M/d/C/E），字符必须落在 ClassifySlot 阈值内。差异要同时落在剪影+色相+运动。同波用阵型槽位而不是随机 x。验证用两列冻结排开全部机型 + 单独阵型截图。Boss 仍复用 interceptor。
- 辅助瞄准线契约（v0.10.22 最新）：规则层 ComputeAimLine 只在 aiming 且 activeBall 且 pull 长>15 死区时返回射线，方向=-pull 归一化（与 LaunchMarble 同源），终点为射线与左(0+r)/右(DW-r)/顶(TOP_BOUND_Y+r) 三边最近正 t（不含底），x1,y1=activeBall.x/y，s.aimLine=nil 即不显示；渲染层只读 {x1,y1,x2,y2} 画线，禁止算弹道/反弹预测（用户只要一条直线）。视觉=14 个青色软圆 billboard，t 0→1 尺寸 ×(1-0.55t) 渐小；材质 DiffAlpha+烘焙青色软圆纹理（DiffVCol 忽略纹理 alpha 显示方块）。
- ⚠️ 斜俯视正交相机的 z 投影契约（v0.10.22 实测，纠正 v0.10.19 旧结论）：相机是 46° 斜俯视正交，**不是纯俯视，z 会投影到屏幕 Y**——同一 XY、不同 z 的两个物体在屏幕上有 Y 偏移。因此辅助物若要贴在车辆/玩法对象上，**z 必须取该对象锚点的 z**（瞄准线起点用 GetVehicleAnchorWorld(activeBall)，整条线同一 z），不能用固定的近相机 z（旧 -6 相对车 z≈0.09 偏移 6 米，导致瞄准线脱离车辆）。仅当辅助物不需要贴任何对象（如全屏方向指示）时才可放独立近相机 z。火花粒子 z=-.95 是固定小值，因其从命中点迸出、不要求精确贴车中心；体素/车辆/碎片各自有正确 z。
- ⚠️ 引擎显色契约（v0.10.19）：游戏 Zone 光照下动态 CustomGeometry 顶点色/NoTextureUnlit 不可靠；不透明彩色 billboard 用 DiffVCol+billboard.color，透明软粒子用 DiffAlpha+烘焙纹理（见下条）。
- 碰撞粒子契约（v0.10.21 最新，取代 v0.10.18 单集不透明方块方案）：粒子分 spark 暖白软圆/shard 金属三角自旋/smoke 灰软圆膨胀三 kind，**小而稀疏、偶尔点缀**。Presentation.SpawnParticles(x,y,rgb,count,kind) 生成（对象池、p.kind/p.angle/p.spin），UpdateParticles 按 kind 分运动（shard 重力+自旋、smoke 上飘减速膨胀无重力、spark 重力短促）；Renderer3D 用**三个 BillboardSet**（particleSets_.spark/shard/smoke，槽 64/40/28、relative=false、z=-0.95）按 p.kind 分流，空槽 enabled=false 每帧 Commit。击毁=3 spark+2 shard+35%一缕烟，普通命中 50% 概率 1 spark；新增粒子只在表现层加，禁止规则层/每粒子建 draw call。
- ⚠️ 透明软粒子显色契约（v0.10.21 实测）：要"彩色+软边/异形+半透明"billboard，颜色必须**烘焙进程序纹理 + Techniques/DiffAlpha.xml**。DiffVCol/DiffVColAdd 忽略纹理 alpha（软圆/三角显示成方块）；DiffAlpha 读纹理 alpha 但不读 billboard 顶点 rgb（白纹+顶点色不染色，顶点色只影响 alpha/开关）。做法：CreateSoftCircleTexture(r,g,b,centerA,edgeA)/CreateTriangleTexture(r,g,b) 生成带颜色+渐变 alpha 的 Image→Texture2D，材质 DiffAlpha+该纹理，billboard.color 保持白、淡出靠末段尺寸收缩。三角因 Billboard UV 的 V 翻转要在图像里沿 y 反向画才正向。不透明彩色体素仍用 DiffVCol+顶点色（见 v0.10.9 顶点色材质契约）；按是否需要透明软边二选一。
- 全屏拖拽契约（v0.10.15 保留，v0.10.17 召回删除后仍有效）：PointerDown 仅在 playing 态且 activeBall 存在时起手（空仓直接 return，等球自然回库），任意战场坐标记录 grabStart(grabStartX/Y)，拉弓量 = 当前点 - 按下点，经 `ClampPull` 钳 MAX_PULL=150 与向下 PULL_MAX_DOWN_DY=DH-SLING_Y-20；待发车辆只在 SLING(270,850)+pull 附近移动，禁止让车辆跳到手指位置；15px 死区松手归位。
- ⛔ 召回机制已废弃（v0.10.15 引入→v0.10.17 整体删除）：用户判定多余——球本来就会自然回落补弹；召回会误触吞输出、逻辑复杂且与快速发射冲突。禁止恢复 RecallMarbles/recalling/queuedLaunch/canRecall/marbles_recalled/recall_fire_queued/recallPulse/Dock 召回提示扫光。空窗问题靠“回收点提前到防线 + 自然回落”解决，不要再加主动召回类机制。
- 回收线契约（v0.10.17 根因修复）：回收判定必须是 `marble.vy > 0 且 marble.y - marble.radius > DANGER_Y(900)`，两个条件缺一不可。DANGER_Y 在弹弓发射位 y=850 之上仅 50px，而向下拉满待发车可到 y≈940、巨型车半径 30——只判位置会让球一发射（出生点已在线下、还没向上走）就被回收，表现为“射不出去”；vy>0 保证只回收回落的球。
- 顶点色材质契约：任何需要顶点色染色的 CustomGeometry/箱体材质必须用消费顶点色的 Technique（`DiffVCol`），普通 `Diff` 不读顶点色会让面板纹理盖住整机颜色；程序化金属面板纹理基底要压暗（≈0.62）避免冲淡主色。
- 敌机部件槽位契约：像素数据原色只用于槽位分类，最终颜色由 VisualCatalog 的机型配色表给出；座舱判定要区分高亮蓝（b-r≥55 且 g≥100）与灰蓝装甲（b-r≈30），禁止把大面积灰蓝装甲误判成座舱。
- 升级抽卡去重契约：同一张三选一里用局内 `chosenThisRoll` 保证 id 唯一，叠加上限只控制跨局，不能让同名天赋在同一面板重复出现。
- NanoVG 文本测量契约（v0.10.14 根因）：UrhoX 绑定的 `nvgTextBounds(ctx,x,y,str,nil)` 返回两个值 `(advance, boundsTable)`，boundsTable 是 `{minx,miny,maxx,maxy}` 数组，**不是** C API 的多返回值——`local minx,_,maxx = nvgTextBounds(...)` 会让 minx=advance、maxx=nil，恒走 fallback；且测量处于 CONTAIN 缩放 transform 下时必须先 `nvgSave`+`nvgResetTransform` 再 `nvgRestore`，否则宽度按物理像素翻倍；fallback 估宽按 `utf8.len`（字符数）禁止用 `#s`（中文 3 字节）。
- 升级卡详情契约（v0.10.17）：天赋池每项必须带一句完整 `detail`，UI 用 `WrapTextLines` 做 UTF-8 逐字自动换行（实测 bounds 宽度）；卡片 168×300/gap=8/cy=530（卡 380..680，在标题区与 y=704 操作提示之间垂直居中）：标题 15px 单行、稀有度 11px、分隔线 y+74、详情 12px/18 行距/最多 6 行且**文本块在详情区（y+88..y+208）内垂直居中**（短文案不留空洞）、底部标签 24px（y+216）+增量徽标 26px（y+248）+层数 9px（y+279，提亮色 {184,196,226} 不贴底）三段固定；HUD/卡片词条标识一律 NanoVG 程序化绘制，禁止外部 Icons PNG。
- 升级卡命中同步契约（v0.10.17）：`main.lua:TryPickUpgradeAt` 的 cardW/cardH/gap/cy/HIT_PAD 必须与 `Scene3DBackend:GetUpgradeCardLayout` 视觉几何逐值一致（当前 168/300/8/cy530/HIT_PAD 4），禁止两套常量漂移；升级点击用 `ScreenToUi`。
- 顶部边界契约：规则反弹顶边是游戏坐标 `TOP_BOUND_Y=-135`（v0.10.10 取 0 与 -270 的均值，投影 designY≈105 在 HUD 下方）；规则常量与 3D 视觉 `EDGE_TOP_GAME_Y` 必须同步，左右边仍是 0/DW。禁止把游戏坐标 y=0 当屏幕顶。
- 节奏平衡契约（v0.10.27）：刷怪基础间隔 18s、下限 9s、收紧 0.15/波，同屏上限 8（每 10 波 +1），单波 ≤5 架，首波冷却 3.2s；全局下落 ×0.42，首波基础速度 28；XP 首升 26、成长 ×1.26。改节奏时同时改 BALANCE、GetWaveParams、ResetGame 初始冷却、CreateEnemy 下落系数，禁止只调一处。
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
- 输入契约：画布外按下必须过滤；移动和释放允许跨出画布以完成钳制和结束拖拽；升级卡必须用 `ScreenToUi` 命中，玩法瞄准必须用 `ScreenToGame`；playing 态全屏任意位置按下都可起手拖拽（v0.10.15，旧底部 160px 限制已删），但仅在 activeBall 存在时起手，空仓（球在飞/补弹中）按下不响应（v0.10.17 召回已删）
- 渲染合成契约：`Backend.Render()` 必须先执行 `Renderer3D.Render()` 再执行 `RenderOverlay()`；NanoVG 仅允许绘制画布外 letterbox 与透明/局部 UI，禁止使用整屏不透明矩形覆盖设计画布
- 弹珠技能契约：基础弹每次直接命中独立 5% 概率生成两颗完整功能分裂弹，分裂弹可继续分裂；加速弹每次反弹/命中加速 15%，按速度最高增至 3 伤并自动追击最近砖块；巨型弹任意有效反弹只武装一次贯穿，贯穿命中造成直径 7 格圆形范围伤害
- 敌方基础下落速度固定乘以 0.42（v0.10.27，原 0.25 首波过慢）；冰冻倍率继续叠加在此速度之上
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
- UI 视觉契约：raw NanoVG 固定 540×960 模式 A；v0.10.28 全页 dark-tech（深黑蓝层级 + 品牌青唯一强调 + zpix）。playing HUD 顶部 92px 仪表盘、底部 94px 火控舱、中央战场；菜单/结算/暂停用窗口壳。禁止恢复 Astroon 蓝紫金、Laterano 蓝白、整屏不透明 NanoVG 盖 3D、升级卡消失。
- UI 投影契约：NanoVG 与 3D `Viewport` 继续共用 540×960 CONTAIN 缩放、居中偏移和 DPR；NanoVG 只能填充画布外 letterbox，设计画布内部必须保持 3D 可见；升级卡视觉布局与 `main.lua:TryPickUpgradeAt` 命中布局必须共享 cardW=168/cardH=300/gap=8/cy=530/HIT_PAD=4，且升级命中使用 `ScreenToUi` 而非 `ScreenToGame`
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
