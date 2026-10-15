<!-- RECOVERY INSTRUCTIONS -->
<!-- 新会话 AI 读到此文件时： -->
<!-- 0. CLAUDE.md 已自动注入 → 已知当前状态和关键避雷 -->
<!-- 1. 读取本文件 → 恢复项目上下文 -->
<!-- 2. 读取 docs/persona.md → 加载助手人格 + 用户偏好 -->
<!-- END RECOVERY INSTRUCTIONS -->

# 项目记忆索引

## 敌机新行为「幻影体素块」+ 缓入曲线上移（2026-10-15，phantom-voxel 附记）
- 用户：①新增敌机行为——从**未被破坏的引擎灯光源块**发射高速「幻影体素块」，穿过其他敌机、继承源灯块剩余血量一半（≥1），越线按普通越线扣基地血；**不是所有机型都有**，频率按机型、是否发射按难度随机；**每关前 5 波至少 10 架**。②缓入 60%→100% 改为 **75%→100%**，起始倍率随关卡降到**关20 封底 60%**。
- **口径（AskUserQuestion 确认）**：幻影弹速乘新缓入；前5波≥10 = **每关前5波合计**；光源块=**引擎灯E**；越线**扣基地血**。
- **数据**：`StageCatalog.PHANTOM_KEYS`（7 型，精英/Boss 无）、`PHANTOM_SPEED_MUL=5.0`、`GetPhantomDifficulty`（0.6→1.5）；曲线 `start=0.75-min(stage-1,19)*0.15/19`。
- **规则**：`Game._phantom`（FindEngineBrick/Spawn[同屏≤8]/Update/TryFire），`CreateEnemy` 标 `isEngine`，快照 `s.phantoms`。
- **渲染**：`Renderer3D.phantom` 每块一个 `CustomGeometry` 盒子（DiffVCol 路径 + 常驻自发光）。**表现**：`phantom_fired/destroyed/breached` 三条反馈。
- ⚠️ scout 位图**原本无 E 块**（关1 唯一机型 → 恒零发射）→ 补背侧两枚引擎灯。
- ⚠️ 保底初版做成「保底期每次检查都强发」→ 实测 **64 架**；改为「随机/保底分开 + 挑未发射机型 + 成功才+1」→ **20 架**。
- 验证：LSP 36 文件 0 Error；`probe_phantom` ALL PASS（引擎灯 2 块、前5波发射 20、峰值在场 8）；`probe_phrender` 真渲染 `state=playing wave=3 phantomsSeenMax=8`、零目标错误。官方多人 build + 预览上传 ✅。抗体 AB-342/343/344。

项目：货车大战飞机
当前版本：0.13.65
简述：敌机新行为「幻影体素块」（引擎灯发射、穿敌机、越线扣血）；缓入曲线上移到 75%→关20 封底 60%。
最后巩固：2026-10-15

## 冲击波放大三层 + 外套 80%/1.2×/2s停留+3s消散 + 拖拽=设计空间圆投影（2026-10-15，bowwave-shell-drag-2026-10-15）
- 用户三点：①「冲击波太小太简单」；②「全息幻影以现在 80% 不透明度、比车稍微大一点（20%）套在车上，发射后 2s 才会开始消散，之后 3s 平滑消散完」；③「发射拖车辆的圆形拖动范围不是指 3d 空间的圆形范围，而是 2d 空间对应直径圆形范围的投影」。
- ① `VehicleBowWave` 放大 V 形参数（V_DEPTH 0.62/V_SPREAD 1.90/THICKNESS 0.18/HALF_HEIGHT 0.12/GAP 0.20）+ `EmitCar` 三层叠放（外层宽淡→内层窄亮白热核，`BANDS_PER_CAR=3`、`PER_CAR=1188`、预算 8 车/9504）。
- ② `VisualCatalog.CHARGE_HOLOGRAM`：shellScale 1.2（比车大 20%）、shellAlpha 0.80、shellHold 2.0 + shellFade 3.0（替换 shellSeconds）。`Presentation._chargeHologram` 增 shellFade，shellMaxLife=5.0；`VehicleChargeFx` 不透明度 `alpha*min(1, shellLife/shellFade)`（>fade 段停留满值，≤fade 段平滑淡出）。
- ③ 拖拽改在**设计(UI)坐标**里按 MAX_PULL 圆钳制（屏幕正圆），再 ÷投影缩放 → 玩法位移（玩法范围=屏幕圆的投影椭圆）。`Game._pullSpace`+`SetPullSpace`；`PullToGameplay(uiX,uiY)` 返回玩法 dx/dy + 设计像素 dist；死区/瞄准 power 都按设计像素。删除死 `ClampPull` 与只写不读 `grabStartX/Y`。车辆屏幕位移仍恒定 90 设计像素。
- 验证：LSP 36 文件 0 Error（1412W/125H）；官方多人 build + 预览上传 ✅。真渲染 `probe_v3` 14/14 PASS（shellScale1.2/shellAlpha0.80/hold2fade3；外套 1.5s 停留、2.5s 淡出、5s 归零；vertexBudget=9504；设计 150 拉距→车辆玩法位移 135.0）；独立 Forward 实图三层 V 形可见 `/workspace/screenshots/bw/bw3_bands.png`（1164 顶点）。主 HDR 3D 恒黑，可见性由独立 Forward 实图证明；参数为助手拟值；手机 FPS/全 DPR/真 SDK/审美未验收。

## 六项需求（2026-10-15，six-req-2026-10-15）
- 用户六项：①全息外套「发射后才会开始消散，3s 后消散完」；②蓄力达 85% 发射「立刻使它完成蓄力」；③「冲击波完全没有显示」（bug）；④拖尾「随子弹存在时间变长越来越短，分裂行为继承长度」；⑤附魔三连的两个副子弹「也视为分裂弹（功能保留本子弹相同）」；⑥「增加回弹特效」。
- ① 外套独立寿命：`Presentation._chargeHologram` 增 `shellLife/shellMaxLife`（`VisualCatalog.CHARGE_HOLOGRAM.shellSeconds=3.0`），蓄力期常驻满值、**仅 released 后**递减；`VehicleChargeFx` shell 用 `shellLife`（不透明度 `shellAlpha*(1-shellT)`），残像 `life` 独立，两者都归零才隐藏。
- ② `BALANCE.chargeCompleteThreshold=0.85`；`LaunchMarble` 里 `time/total>=0.85` 即 `time=total`（chargeBoosted）；快照 `s.chargeReady`，Presentation 据此提前爆发全息。
- ③ **真因（本轮最高价值）**：上一批把 V 形波壳从**无光照** `NoTextureUnlitVCol` 改成**带光照** `DiffAlpha`（LitSolid，法线 ±Z）→ 深空场景 `N·L≈0` → 全黑。改 **`DiffVColUnlitAlpha`**（无光照+顶点色+纹理 alpha），纹理改白 RGB+alpha 剖面。独立 Forward 渲染四模式对照实图实锤（lit=暗灰不可见 / unlit·vcolalpha=亮青）。
- ④ `Game.CreateMarble` 增 `trailAge`（随 dt 增；`CreateSplitMarble` 拷贝母车 age → 继承）；`Renderer3D.SyncVehicleTrails` 按 `trailAge` 算 `ageFactor`（0.35 前满长→4.5 收到 0.16）收 `keep`+`life`；粒子系同乘 `lifeScale`。新增只读 `DebugTrailLengths()`。
- ⑤ 三连副弹 `extra.words={copy}`、`extra.enchantIsChild=nil`（功能同主弹，仍 `isPrimary=false` 灰暗）。
- ⑥ 撞墙 `Emit("marble_bounce",{id,x,y,ballType,nx,ny})`；Presentation `marble_bounce→bounceImpact`（弹种色扩散环+火花+轻震）。
- 验证：LSP 36 文件 0 Error（1404W/125H）；官方多人 build + 预览上传 ✅。真渲染探针（真实 client_main）：`probe_six` 15/15、`probe_bounce` 3/3、`probe_traillen` 2/2（keep 16→5）、`probe_rules` 4/4、`probe_split2` PASS；独立 Forward 实图对照 `/workspace/screenshots/bw/bw_verified.png`。主 HDR 3D 恒黑，冲击波可见性由独立 Forward 实图证明；3s/85%/收短比例为助手拟值；手机 FPS/全 DPR/真 SDK/审美未验收。

## 全息外套放大到 1.5 倍（2026-10-14，shell-scale-1.5）
- 用户「全息幻影为 .5 倍大小」——原话「透明度40% + 比车稍微大一点 + .5 倍大小」，取**最合理读数 1.5 倍**（比车大一半）：0.5× 会比车小（与「稍微大一点」矛盾）、5× 远超「稍微」。**已按 1.5 实现**；若本意是别的倍数，改 `VisualCatalog.CHARGE_HOLOGRAM.shellScale` 一处即可（助手判断，非用户确认参数）。
- 改动仅两处：①shellScale 1.06 → **1.5**；②VehicleChargeFx.Debug() 增只读诊断 shellScaleRatio/shellAlphaNow（不改表现行为，供探针断言「外套实际世界缩放=源车×1.5」）。外套其余逻辑（逐帧跟随源车显示变换、shellAlpha 0.40、TTL (1-t)^1.2 淡出、源车回收即隐藏）不变。
- 验证：LSP36文件0Error（1393W/119H）；官方多人 build + 预览上传成功。真渲染 probe_shellscale **5/5 PASS、exit0**：shellScale==1.5、shellAlpha==0.40、爆发期 shellVisible>0、**外套世界缩放/源车世界缩放=1.5000**（精确1.5倍）；目标 Lua/overlay/LoadChunk 错误 0；探针走真实 client_main（含两轮开局选车）。
- 边界：主HDR3D恒黑，**1.5 倍是否合适（过小/过大/遮关键读点）待 Preview**；手机FPS/全DPR/真SDK/审美未验收。纹理禁压缩未完成、XHR96/233未定位不变。POST-1状态/索引、POST-2本人 VisualCatalog/VehicleChargeFx 独立提交、POST-3 AB-332/333执行；persona及随行偏好无新跨项目事实跳过。保留并发子车灰暗/拖拽减速/opening/ArtText/成就/纹理与初始未跟踪文件，不代提交。

## 拖拽全局减速（2026-10-14，drag-slowmo）
- 用户要求「拖拽时全局减速80%」。复用既有 timeScale 链路、零新增顶层 local：`BALANCE.dragTimeScale=0.2`；`Game.Update` 的 dt 倍率改 `dt * (空手2倍 or 1) * (拖拽0.2 or 1)`；快照 `s.timeScale` 优先级改「拖拽蓄力 > 空手长按」。各特效模块（波壳/附魔球）**天然只乘一次**、零改动；`elapsed` 仍按真实时间推进（不冻结 UI/震屏/表现衰减），只放慢玩法与依赖 timeScale 的特效。拖拽蓄力时必有待发车、空手2倍速要求空手，二者不共存。
- 验证：LSP36文件0Error（1393W/119H）；官方多人 build + 预览上传成功。真渲染 probe_dragslow **6/6 PASS、exit0**：未拖拽 timeScale=1 / 拖拽 timeScale=0.2 / **同一敌机同段真实帧下落 slow/fast ratio=0.200（精确5倍）** / 发射松手恢复1 / 死区松手也恢复1；目标 Lua/overlay/LoadChunk 错误 0；探针走真实 client_main（含两轮开局选车）。
- 边界：主HDR3D恒黑，**真机手感（0.2 是否过慢/影响瞄准）待 Preview**；手机FPS/全DPR/真SDK/审美未验收。纹理禁压缩未完成、XHR96/233未定位不变。POST-1状态/索引、POST-2本人 Game.lua 独立提交、POST-3 AB-330/331执行；persona及随行偏好无新跨项目事实跳过。保留并发子车灰暗/opening/ArtText/成就/纹理与初始未跟踪文件，不代提交。

## 青圈锚车与贴身全息外套（2026-10-14，charge-anchor-shell）
- 用户要求青圈圆心改为**车辆位置**（不再锚手指）；全息爆发后加一层**透明度 40%、比车略大**的幻影壳**套在车上**；车前**冲击波改为 V 字形、高质量半透明贴图**。只改 Game/Presentation/VisualCatalog/VehicleChargeFx/VehicleBowWave/ui.LaunchCharge，不动伤害/初速/回收/拖尾/附魔/金色强化与暗科技 UI。
- 圈心：快照增 `chargeCarX/chargeCarY`（=chargeActive 时 activeBall.x/y，否则 nil），`marble_launched` 补 `carX/carY`；LaunchCharge 圆心**优先** `project(chargeCarX,chargeCarY)`（同后端玩法投影=车辆屏幕中心），指针坐标降为旧调用回退；释放回声同样优先车辆坐标。车辆中心在玩法平面 z=0，用玩法投影即可，无需深度平面。
- 外套：VehicleChargeFx 第 3 批次 ChargeHologramShell（同型真实网格、PBRNoTextureAlpha），逐帧取源车当前实际显示变换 ×shellScale(1.06) 套在车上，**shellAlpha 0.40** 随 TTL `(1-t)^1.2` 淡出，源车回收即隐藏；两残像仍冻结基准+扩散，与外壳独立。Debug 增 shellVisible。
- V 形冲击波：VehicleBowWave 由「车前弧壳（HALF_ANGLE 扇形+NoTextureUnlitVCol 顶点色）」改为 V 字形——中线 `CentreX(s)=baseX+forward+V_DEPTH*(1-|s|)`（中央折角在车头正前最远、两翼后掠回落到车鼻前 GAP），厚 THICKNESS、半高 HALF_HEIGHT、展宽 V_SPREAD(1.12×车半宽)。材质改 **DiffAlpha + 程序化 V 形贴图**（CreateBowWaveTexture：横截面软边+沿 V 长中央折角最亮的细热核），颜色走 MatDiffColor（DiffAlpha 只读纹理 alpha、不读顶点 rgb），alpha 0.55 做高质量半透明；顶点写 UV(0/1) 供采样。Valid 删 HALF_ANGLE 门控改 hw<=1e-6；PER_CAR 仍 396、预算 8车/3168 不变；Shutdown 释放自有贴图。
- 验证：LSP36文件0Error（1393W/119H）；官方多人 build + 预览上传成功。真渲染 probe_chargeshell **8/8 PASS、exit0**：车(270,850)≠指针(200,600)→**圆心=车辆投影点**；shellAlpha==0.40；爆发期 shellVisible>0；V 形波壳蓄力真实提交 count=1/vertices=396/actualVerts=384、**材质绑定 true**；目标 Lua/overlay/LoadChunk/空顶点错误 0；探针走真实 client_main（含两轮开局选车）。
- 边界：主HDR中央3D仍黑（本环境既有），shellVisible>0/材质绑定仅证批次启用与数据通路，**V 形观感与 40% 透明度待 Preview**；手机FPS/全DPR/真SDK/审美未验收。纹理禁压缩未完成、XHR96/233未定位不变。POST-1状态/索引、POST-2本人六Lua独立提交、POST-3 AB-325/326/327执行；persona及随行偏好无新跨项目事实跳过。保留并发 opening/ArtText/成就/纹理与初始未跟踪文件，不代提交。

## 两轮开局选车自动承接（2026-10-14，opening-transition）
- briefing0.95秒说明两车出战，首发选择后between0.65秒提示再选不同备弹，次选后ready1.05秒展示完整阵容，自动接原完整3秒intro；每轮规则保护0.32秒。均为助手拟值，固定阶段3.29秒不含玩家选卡时间，无新增确认按钮。
- Game._opening阶段计时只在非playing开局推进，单帧钳0.05、微小尾数归零；select且timer0才可选，ready转playing本帧return不耗intro。不污染XP/pending/picks/stacks，首选待发次选备弹，无第三车；进关/next/retry/restart重选、revive不重选，正常升级/扩容/第三车/回收保持。
- 新OpeningTransition复用宿主ctx/字体/令牌/金属原语，无新资源所有权；淡入微缩侧滑双车卡与合批刻度。Backend七hunk零新增主块local，非select卡窗不可见/不可命中，实际WINDOW_IN与规则计时双保护，同轮次身份/Update-Render-HitTest幂等/WindowInput逆变换，opening旧残影不遮ready/intro；普通保留与重抽恢复。
- 正式规则11案例170505断言、四CLI exit0；最终merged-run3 UI610+guard42+胜败64共716/716 PASS、三exit0，真实Tick153/53/269；93脚本全程同生产，client最终0bb25e。四TakeScreenShot/SavePNG图briefing/between/ready/select2已逐张内部目视，目标脚本错误0。旧nil候选helper/旧快照/隔离缺Tick/早期空输出/patch失败保留不计PASS；模拟输入/广告非OS/SDK。
- 本人亲自官方1.0.3/build4预览上传成功719559df/d0ded454，225/226清单条目含19平台变体，共244/245实际产物size+CRC全对，45/46Lua同生产，UUID eb01ba2acf6dc96f334d90入包正确；证据/home/Maker/opening-transition-build4-verification-20261014.json。LSP36文件0Error（1410W/119H）、diff-check通过、收尾本人四SHA同冻结，验收后无生产Lua/assets修改、纯POST不重复build。
- POST-1状态/索引、POST-2本人四代码/meta及四记录独立提交、POST-3 AB322执行；persona/随行persona/preferences无新偏好跳过。保留4e108e7/62d7f9a与初始config/媒体；纹理禁压缩未完成、XHR96/233未定位，手机FPS/DPR/主HDR/手感/真实SDK/审美待Preview。

## 三项异步加固与纹理阻塞（2026-10-14，four-hardening）
- 高分先Get成功再Set，读写全局单在途，成功仅确认本请求；失败15秒退避且首menu不绕过，Stop最大值retained/尝试本地保存、Start恢复，旧callback隔离。throw/无终态保槽可能长期停发，非跨设备原子max/exactly-once，保留不跨页面/进程。
- 成就离线门控、每ID每Lua会话最多尝试一次、仅匹配SDK listener成功确认achPushed；未知终态/Shutdown/SDK切换保守停发，不新增持久不确定账本，不迁移历史错误确认。ArtText每图三次/0.5与1秒明确失败退避，UI Tick独立玩法时钟，ctx/lifetime与尺寸双检；CTA原图407×128/显示300.96×67不变。
- 纹理71组改名实验让非法none被采用，build1 213项全失败；142 XML/meta逐字节同HEAD仅撤回本人改名，PNG/UUID不动。build2恢复原策略：15success/198limit，71图默认5ASTC KTX1+66PNG，Windows4BC7 KTX1+67PNG；**禁压缩仍未完成**。
- 最终高分14进程38205检查、主循环6/1273（446Update/Backend/Tick）、成就mock36/123、Art mock15/540与real8/105两次PASS；失败日志保留。显式LSP36文件0Error，build2内部daemon不可用跳过gate。本人1.0.3/build2预览成功，eb402919/8e4fd346，234/235产物sizeCRC零错、45/46Lua与225/226meta同源、451冻结稳定；后续peer串行包另记。
- POST-1状态/索引、POST-2本人代码/版本精确hunk与记录、POST-3 AB319–321执行；persona及随行偏好无新增跨项目事实跳过。保留FX/opening及初始配置媒体、不代提交；XHR233未定位，无真SDK/手机FPS/DPR/主HDR/审美验收，三项加固不冒称网络错误消失。

## 满蓄全息与三球附魔（2026-10-14，charge-hologram-three-orbs）
- 巨大青圈继续用既有真实UI指针圆心，不重复改输入链；满蓄暂按青色描边（原文颜色词不明确），两层真实车型全息爆发，0.65秒/0.65米为助手拟值；原金色车前波与单次×1.5、拖尾/UI保持。
- Presentation分手势gestureId/epoch与爆发serial/vehicleId，真实释放事件或强化飞行快照只锁一次released，之后独立TTL；修源车回收/下一辆Down提前截断。VehicleChargeFx捕获实际显示root世界基准、沿确定轨迹扩散，槽6临时材质独立且重建/清理前恢复共享白边。
- VehicleEnchantOrbs替换旧10粒aura：每车严格3颗实体球/同心halo、相差120°，蓝紫金，最多四车12球4320顶点；稳定id相位，允许玩法dt、倍率一次，暂停/intro隐藏冻结。LOCAL动态批次、自有资源清理、空批不Commit、失败停用至Init，不改Game。
- 最终输入13案例188断言、基础规则32/789、增量10/529、整链run6与最终client合并run7各63/63均PASS/exit0，目标错误0；run7为245Update/245绘制/504Renderer、93脚本前后同生产/358引用assets无变更，最终client SHA为0bb25ebab78398183c58f2cd4aa1bb5ce714600b4e401214b705605d441fbab1。金波实际396顶点全暖金；run7两种源车自然回收时life均0.30、两层幻影仍可见至自然TTL结束。规则副本Presentation较旧只作Game回归，FX由最终输入/run7/专项证明。
- 上游9组41断言PASS（旧版9FAIL），三球两次36907、描边/全息79952及79959全PASS；独立Forward实图可辨。run7九张整链截图API成功但主HDR中央仍黑，不代表主HDR/手机FPS/全DPR/真实OS/广告SDK/审美验收，run6原图未覆盖；旧探针/截图/预检失败保留不计PASS。
- 本会话LSP36文件0Error（1410Warning/119Hint）与diff-check通过；本人官方多人1.0.3/build3预览成功，dc3efb5e/604cd420，239/240实际产物全size+CRC匹配。并发会话官方build4预览成功，本人独立亲验最终719559df/d0ded454：225/226清单条目含19变体，共244/245产物零错配；45/46Lua同生产、五FX同run7、两新meta正确入包。证据位于/home/Maker/vehiclefx-integration-20261014/evidence/的run7/build3/build4_verification.json；build3首轮校验exit1未定位、次轮错误fs_path前缀断言保留，修校验脚本后才PASS，不据此判包损坏。
- POST-1索引/状态执行、persona无新偏好跳过；POST-2版本记录与本人五Lua/两meta独立提交执行；POST-3 AB323/324执行，随行persona/preferences跳过。并发opening/ArtText/成就/XML/config和初始媒体保留；纹理禁压缩未完成、历史XHR96/233未定位不变。验收后无生产Lua/assets变更，纯POST不重复build。

## 每关两轮开局选车（2026-10-14，opening-vehicle-selection）
- 新默认档四首阶normal_1/ice_1/speed_1/giant_1，第二阶仍锁；成功旧本地档不强制赠送，旧AUTO_OWNED不扩。无本地档先默认再旧云并集可能保留四节点，ResetAll/读取失败回退同默认，不声称严格新账号迁移。
- 每关两轮只出车型解锁卡：第一轮四取三、次轮剩三，不固定送speed；首选待发、次选备弹，无第三车。opening账本独立XP/pending/picks/stacks，选完才原3秒intro；选关/下一关/再战/重开覆盖，复活不重选，正常升级/第三车/扩容/回收保持。
- opening隐藏且不命中保留/重抽广告，正常升级恢复；轮次参与同levelup窗口身份，Update/Render/HitTest同钟幂等逆变换，Shutdown复位。三Lua零新增Game/Backend顶层local，既有视觉/蓄力保留。
- 最终与复跑规则69873/存档mock132/公共API战斗1844断言全PASS，六进程exit0；实战1760帧/73发射/69回收/4经验升级，第三车与扩容均实际生效。真实UI处理器159与旧结算64共223 PASS/exit0；三正式真实读回图逐张内部目视，两轮及普通升级完整；87UI文件/六规则冻结同生产。旧探针假失败/额外首轮截图失败不计PASS，模拟eventData/File/广告拦截非OS/SDK。
- LSP32文件0Error；此前官方build4预览成功，client49840fdc/server1a234278清单222/223项size+CRC匹配，三Lua包内同源；收尾三SHA仍同正式冻结，diff-check通过。续接Python全清单重查exit1空输出与日志读取失败未定位，不称重查通过、不判包损坏；验收后无Lua变动，不重复build。
- POST-1项目记录/persona演进执行、POST-2本人三Lua与记录独立提交、POST-3 AB317/318执行；随行persona/preferences无新偏好跳过，保留peer AB315/316/蓄力及发布配置/初始媒体。不改展示版本；手机手感/FPS/DPR/主HDR/审美待验，XHR96/233未定位不变。

## 拖拽蓄力与金色强化发射（2026-10-14，launch-charge）
- 起手真实UI指针为圆心，匀速240→0；暂用1.2s蓄满/0.22s释放（助手拟值）。半径0不提交活动圈，释放扩散淡出；不跟世界震屏、不遮HUD/Dock，旧二参输入兼容。完整圆形拖拽、初速/死区/回收与既有效果保留。
- 规则锁定本发chargeBoosted，新车false、子车只复制布尔；中央GetMarbleDamage单次×1.5，附魔连锁/爆炸同源，炸弹/DOT不增强。输入时间独立hitStop/倍速、单帧钳0.05，正常释放保资格至Launch，取消则清除。Game/Backend零新增顶层local。
- 基础两次各32/789、增量10/529、输入12/160 PASS；最新Backend合并输入与实际圈Draw/截图通过（五阶段各4次，240/120/精确0/释放/过期）。模拟eventData/广告状态不代表OS/SDK。波壳797断言/792顶点通过，局部几何法线不变、金色实际提交；TakeScreenShot=false无波壳实图，失败历史不计PASS。
- LSP32文件0Error；本人build3与最终并发官方build4预览成功，主会话全量复核build4 client49840fdc/server1a234278共222/223项size+CRC匹配，七脚本与当前源码一致。静态审查无确定缺陷；手机手感/FPS/DPR/主HDR/最终金色观感未验。
- POST-1/2执行，POST-3 AB-315/316执行；persona/preferences无新跨项目偏好跳过。不改展示版本，仅本人片段与新模块/meta提交；opening/PlayerData/配置/初始媒体保留。

## 展台清晰度与 XHR233（2026-10-14，clarity-rt-xhr233）
- 固定512×288展台RT已替换为按最终物理显示矩形（设计尺寸×scale×DPR）16:9 contain、3%弹动余量、64px分档，512..1920宽；只升档、隐藏不更新，失败保旧并停重试。六车型大小/灯光/白轮廓/透明/30Hz不变，主战场不经过此RT。
- ArtText布局使用实测母版；CTA407×128原图不改，绘制300.96×67不缩水。异步完成才注册，拒绝占位尺寸；token与四处Backend Reset阻止ctx跨生命周期句柄复用，DigitFont同样清理。手机具体占位尺寸未取到，风险修复不等于手机根因复现。
- 八项最终Runtime回归exit0（尺寸39、Draw95帧、故障候选释放/保旧、生命周期14、初始化失败6、Art8/CTA300.96、图集mock14、延迟真绘制），目标脚本错误0；最终Forward同帧512→1024实图可辨细节改善，截图实际帧15。首个组合命令提前失败、首轮700帧战斗超时，均不算通过；最终280帧真实HandleUpdate/进关/发射冒烟exit0，playing/敌机/已发射断言与396顶点波壳提交通过，目标脚本错误0，不代表700帧长跑或手机输入。
- LSP32文件0Error；官方1.0.2/build2预览上传成功，client50e957f7/server26ca8616，两清单221/222项size+CRC32全匹配、五脚本产物与源码一致；独立静态审查无确定缺陷。
- XHR报告首条2026-10-13 14:22:08.171、生成14:22:27.324，233条非请求次数。公开报告器JSON.stringify对象丢Error不可枚举细节，原console.error仍有完整参数；只能解释{}，不能定位失败请求。引擎hash不是游戏hash；无同会话request/stack，**233仍未修且未验证消失**，不禁云/吞日志/重复盲扫发行包。
- POST-1/2执行，persona跳过无新偏好；POST-3执行AB-312/313/314，随行persona/preferences跳过。手机FPS/全DPR/实际新包加载/主HDR与审美未验收；保留并发发布配置与初始未跟踪文件，不改展示版本。

## 圆形拖拽与车头前方 3D 冲击波（2026-10-14，circle-drag-bow-wave）
- 用户明确圆形拖拽与「车辆前方」冲击波。完整输入圆半径保留 150，实际车位用 0.6 倍（半径 90）；方向/力度/15 死区/初速公式不变，Move/最终 Up 即时同步出生点。倍率为助手拟值。
- 新 `VehicleBowWave` LOCAL 动态批次：真实 bbox 与车辆平滑显示后的实际 root 世界变换绑定立体弧壳，白芯/弹种彩边；16 段、396 顶点/车、8 车/3168 顶点上限。Clear 后重绑材质、空批不 Commit、半成品 dirty 清理、异常停用至 Init、借用车辆不释放。只视觉，不扩大碰撞或伤害，原拖尾/附魔/胜败过渡保留。
- 允许玩法 dt 经 client→Backend→Renderer→波壳，广告 0、顿帧 gameDt、timeScale 只乘一次，暂停等模态隐藏冻结；旧四参兼容，Backend 零新增顶层 local。
- 圆形规则两次各 91 案例/4821 断言、输入处理器两次各 9/131、三项波壳几何生命周期各 3273、Renderer 36、pipeline 11、真实 base_hit 处理器 hitStop 77 全 PASS，正式本批五源码与冻结版指纹一致；最终主会话 hitStop 复跑 77/77、exit0。模拟 eventData/合成领域事件不冒称 OS 输入或自然越线。
- LSP 32 文件 0 Error（1329 Warning/118 Hint）；官方多人 1.0.2/build1 与预览上传成功，client c045182f/server6ad1f2a9 清单 221/222 条 size+CRC32 零错配，新模块已打包。
- 独立 Forward 六车实图可辨，但主游戏 HDR/手机手感/FPS/全 DPR/真广告 SDK/用户审美待验；环境噪音保留。POST-1/2 执行；POST-3 AB-309/310/311 执行，persona/preferences 均跳过无新跨项目偏好。只提交本人 hunk/记录，保留并发 ArtText/发布配置/RT；未改展示版本。

## XHR 96 次报告只读取证（2026-10-13，xhr-report-96）
- `fcb250f9/24772cad` 经公开 stable 1.33.14/manifest49920946/version.json 精确核验为**引擎身份**，不是游戏包哈希。源URL：`https://tapcode-sce.spark.xd.com/src/engine/assets/BNghoXJZYBHd9d6Ij4FLlfFu-212defa1.json`（125B、CRC32 212defa1）。
- 当前build33 client6007d810/server7e6e8b39，两清单220/221项size+CRC32全部匹配，sources仅engine-res、adopt空。运行索引588条覆盖UTC14:48:11..15:35:26，但无精确XHR/HTTP请求字段；调试反馈0条（只读、不标记处理）。成功云读写/余额日志不能证伪其它失败请求。
- 当前源码审查未见失败后每帧自重发；高分周期在途锁/成就确认等独立隐患未与本报告建立因果，不当作本错修复。公开loader/engineJS无精确报错catch。
- **根因未定位、未改Lua/配置、未完成平台不再报错验证**。待原请求的脱敏路径/方法/状态/响应类型/initiator及message/stack；不需要认证信息，不禁云或过滤日志。
- POST-1记录执行，persona无新偏好跳过；POST-2仅三份记录独立提交；POST-3沿用AB-238，跳过无新增跨项目事实。无Lua改动，LSP/build/玩法回归跳过；保留并发脚本与发布配置。

## 胜败过渡防误跳与结算入场（2026-10-13，end-transition-input-fix）
- 用户「胜利和战败动画被跳过」。只改 StageTransition/client_main/Backend，动画内容与胜利 2.15s、战败 4.0s 总时长不变。
- `transition_` 按 state/startAt/elapsed 回卷/离开过渡复位 skip；提示出现后才允许跳过（胜利1.55s/战败3.40s为助手选定门控）。早期鼠标/触摸只消费，清 armed 防同次 Up 点按钮；战败重复回车不跳过/重开，过渡中回车不直接重开。
- `uiFx.UpdateGameWindow` 在首次真实可见时启动窗口入场，Update/Render/HitTest 同源、下一 Update 不重复置零；覆盖输入先于 Render 的闪现边界，零新增 Backend 顶层 local。
- 同一真渲染时序探针修前56 PASS/4 FAIL，修后 **60/60 PASS、exit0**，目标 Lua/overlay/load/空顶点错误0；实际 Draw win75/defeat151，生产/冻结三脚本一致。LSP31文件0 Error；官方多人 build32/预览上传成功，client6007d810/server7e6e8b39 清单220/221文件 size+CRC32零错配。
- 边界：模拟 eventData 驱动真实处理器、强制结算非自然完整打一关；无手机动画实图/FPS/全DPR验收。早期探针显式ClientMain.Stop退出139未定位，最终不显式调用，不计Stop/Start通过。
- POST-1/2执行；persona跳过（无新偏好）；POST-3执行AB-307/308，随行persona/preferences跳过。保留并发ArtText/发布配置，不改展示版本。

## 装饰原语实现层反哺（2026-10-13，visual-recipes-primitives 附记）
- 用户「我要求最具体的绘制比如你这些流光纹理按钮也要反哺skill」——上一版只给**调用层**，用户要**原语本身的绘制代码**。
- **产出**：`visual-recipes.md` 新增 **§11「装饰原语实现」（+377 行）**——`MicroGrid` / `DiagonalHatch` / `Halftone`（隔行错位 + 自适应步长 + 合并路径）/ `DotMatrix` / `CircuitTrace` / `CornerBrackets` / `DashRule` / `TicksBatch`·`Ticks`·`TopTicks` / `TickRing` / `Cross`·`CrossBatch` / `ScanBand`（流光）/ `GlassStrip` / `Screws` / 悬停加色光 / 按钮流光（斜扫光四边形）的**完整代码** + §11.0 性能契约 + §11.16 检查清单。原 §10 检查清单顺延 §12。
- ⚠️ **AB-299（强化）**：反哺「具体绘制」要分**两层**——**调用层**（叠哪几层、在哪调）+ **实现层**（原语本身怎么画）；只给调用层会被判「不够具体」。**性能契约（合并单一路径 + 自适应步长）必须一起给**，否则复用时撑爆命令缓冲。
- 验证：LSP 30 文件 0 Error（1407 诊断）；skill 纯文档无需 build；官方多人 build + 预览上传 ✅。

## 逐层绘制配方库反哺（2026-10-13，visual-recipes-skill 附记）
- 用户「继续然后我要求最具体的绘制比如你这些流光纹理按钮也要反哺skill」——要的是**最具体的绘制层**（一个控件、一层的逐行画法），不是再写一遍「要贵」。
- **产出**：`.agent/skills/dark-tech-game-editor-ui/references/visual-recipes.md`（**469 行新增**）——金属面板六层 / 按钮漆面与扫光 / 窗口壳 / 背景在动 / 艺术字乘法染色 / 像素图标 / 悬停加色光 / 氛围标量 / 非阻塞提示 + 10 条交付检查清单。每条 = 观感目标 + 层序代码 + 参数来源 + 踩过的坑 + 尺寸门槛。`SKILL.md` + `elements.md` 已接入。
- ⚠️ **AB-299**：反哺「具体绘制」要给**层序 + 参数 + 性能门槛 + 踩过的坑**，不能只贴 `nvgXxx` 代码——本项目的坑多是「画了看不见/画了塌/画了撑爆」。
- ⚠️ **AB-300**：两个会话可能在做同一件事——动手前先 `grep` 关键符号 + `git log -- <file>`，发现重复就把归属让给已提交的一方（本批空仓提示即如此，`full-review-2026-10-13` 已修完并验证）。
- 验证：LSP 30 文件 0 Error（1390 诊断）；skill 纯文档无需 build；`probe_holdhint` 8/8 PASS。官方多人 build + 预览上传 ✅。

## 开局缓入起始倍率随关卡下降（2026-10-12，wave-speed-ramp-by-stage 附记）
- 用户「第一波到第四波敌人的移速倍率为60%逐渐加回到100%，随着关卡数字增大，60%这个值逐渐降低。在20关到下限40%」。
- **实现**：`StageCatalog.GetWaveSpeedRamp(stageWave, stage)`——`start = 0.6 - min(stage-1,19)*(0.2/19)`（关1 0.60 → 关20 起 0.40 封底），`ramp = start + (w-1)*((1-start)/3)`（`w>=4 → 1.0`）；`GetBaseSpeed` 传 `stage`。⚠️ `stage` 可选尾参，旧单参调用仍可用。
- ⚠️ 验证「相对倍率」别跨关卡比**绝对速度**（基数含 `min(stage-1,12)*1.8`，且实测 vy 含机型 speedMul）——只看纯函数。
- 验证：LSP 29 文件 0 Error；`probe_wsramp2` **14/14**（关1 0.60 / 关10 0.5053 / 关20 0.40 封底；波4+ 恒 1.0）；`probe_wsregress` ALL PASS；真渲染冒烟零目标错误。官方多人 build + 预览上传 ✅。抗体 AB-293/294。

## 设置页补全：音乐/音效开关 + 制作鸣谢（2026-10-12，settings-audio-credits）
- 用户「设置页补全功能，音乐音效。制作者：薪主  导入素材工作室出品。特别鸣谢TapTap」。
- **音频开关**：`AudioDirector` 新增 `SetMusicEnabled/SetSfxEnabled`（+ 诊断 `DebugEnabled/DebugSfxPlays`）。音乐关 = BGM **目标增益**变 0（`TargetGain()`，淡出静音、曲目保留可续播）；音效关 = `PlaySfx` 开头短路。
- **持久化**：`PlayerData.musicEnabled/sfxEnabled`（默认 true，`Load` 用 `~= false` 缺省开，云合并仅显式布尔才覆盖）。
- **设置屏**：4 行（音乐/音效/恢复购买/清空存档）+ 鸣谢三行；面板 h 360→600、y 300→180（先加高容器再排 y）。
- **链路**：PlayerData → RefreshMeta → HandleMetaAction（翻转+写档+`RenderBackend.Set*` 即时+云同步）→ Scene3DBackend 委托（挂表，零新增 local）；启动时/清档后各作用一次。
- 验证：LSP 29 文件 0 Error；`probe_audioset` **24/24**；真渲染 `probe_setrender`（真实点击→music=false sfx=false 同步）；截图目视开关+鸣谢；战斗冒烟零目标错误。官方多人 build + 预览上传 ✅。展示版本 → 0.13.60。抗体 AB-289/290/291/292。
- 边界：无 `/dev/snd`，静音/发声效果待 Preview 真机。

## 每关第一架不再贴最左（2026-10-12，spawn-lane-stage-fix 附记）
- 用户「为何每一关第一个飞机都靠很左啊」。
- **真因**：起始车道 `(wave-1) % 5` 用**累计波号**——每关首波 `wave-1` 是 10 的倍数，`%5` 恒 0 → 每关第一架恒在车道 0（最左）。
- **修法**：`StageCatalog.SPAWN_LANE_COUNT=5`（单一来源）+ 车道改 `(stage-1 + stageWave-1) % SPAWN_LANE_COUNT`（每关首波 `(关卡-1)%5` 逐关轮换）。
- ⚠️ 「按波次错开」的偏移别用累计波号——模数能整除关卡长度就会在每关起点退化成常数。
- 验证：LSP 29 文件 0 Error；`probe_lanefix` **6/6**（首架 x 25.1/111.6/198.1/263.6/343.1）；`probe_wsregress` ALL PASS；真渲染冒烟零目标错误。官方多人 build + 预览上传 ✅。抗体 AB-285。

## 每关前四波移速缓入（2026-10-12，wave-speed-ramp 附记）
- 用户「第一波到第四波敌人的移速倍率为60%逐渐加回到100%」——每关关内头四波「缓入」。
- **实现（`StageCatalog.lua` 一处，单一来源）**：`GetWaveSpeedRamp(stageWave)`：`w>=4→1.0`，否则 `0.6+(w-1)*(0.4/3)`（0.6/0.7333/0.8667/1.0）；`GetBaseSpeed = 原曲线 * ramp`。
- ⚠️ 只乘 `GetBaseSpeed`——普通波/护航/精英/Boss/间隔下界**全部经它**（避免只改普通波导致精英全速）。
- ⚠️ 「第 N 波」= **关内波次 `stageWave`**（不是累计 `wave`），所以每关都生效。
- 验证：LSP 29 文件 0 Error；`probe_wavespeed` **15/15**（实战 vy 7.711→11.236→14.065→31.623）；`probe_wsregress` ALL PASS；真渲染冒烟零目标错误。官方多人 build + 预览上传 ✅。抗体 AB-283/284。

## 机型种类随关卡号递进（2026-10-11，stage-variety-ramp 附记）
- 用户「在当前的标准下十关卡随着数字提高丰富多元」——承接上一批「每关开局机型雷同」，这次要求**关卡之间要递进**。
- **真因**：v0.13.58 的解锁进度 `(关卡-1)+关内波次` **关内每波 +1 档** → 第 1 关第 10 波就解锁全部 8 种，**一关看遍、后续关卡无新东西**。
- **修法（`Game.lua` 一处）**：`GetAvailableTypes` 进度改 `(关卡-1) + floor((关内波次-1)/3) + 1`（关内每 3 波 +1 档）→ 池子主要由**关卡号**驱动：关1 开局 1 种 → 关9 开局全 8 种；关1 整关最多 4 种。加只读诊断 `Game.DebugAvailableTypes(wave)`（挂表，不占顶层 local）。
- 验证：LSP 29 文件 0 Error；`probe_variety2` **7/7**（单调不减 / 关6>关1 / 关9+ 全机型 / 关1 整关<8）；回归 `probe_variety` 4/4；真渲染冒烟零目标错误。官方多人 build + 预览上传 ✅。抗体 AB-271。

## BGM 扩到 9 首 + 每态播放列表轮播（2026-10-11，bgm-playlist 附记）
- 用户「音乐太少生成更好的」——上一批只有 3 首 BGM（每态 1 首、单曲循环），长时游玩重复单调。
- **生成 6 首新曲**（`text_to_music`，8bit+太空+公路）：菜单 Drifting Hangar/Nebula Docks、战斗 Hyperdrive Skirmish/Asteroid Run、首领 Void Warlord/Core Meltdown → **每态 3 首、总数 3→9**；重命名语义名 + `.meta`。
- **`AudioDirector` 改「每态播放列表轮播」**：`BGM_PATHS`→`BGM_TRACKS`（路径数组）；`bgmPlaylist[key]=Sound[]`；`PlaylistTrack`/`StartTrack(key,idx)`（另一通道播指定曲+记录 trackIdx/trackLen 交叉淡入）；`UpdateBgm` 曲终轮播（`bgmTime>=bgmTrackLen` 切下一首；**长度取 `sound:GetLength()`，未知 ≤1s 回退单曲循环**防死循环）；新增 `DebugTrackCount(key)`。
- 验证：LSP **29 文件 0 Error**；**`probe_audio2` 14/14 PASS**（`bgm=9` / 每态 3 首 / 状态机全对 / **曲终轮播稳定**喂 250s 不崩 / Shutdown 清空）；**真渲染 `probe_audiorender`** 跑完一局 `tracks=3/3/3`、零错误；dist 含 9 首 BGM。官方多人 build + 预览上传 ✅。
- 抗体 AB-272（播放列表轮播非随机播）、AB-273（随机名生成物的 meta 要一起清理）。⚠️ 无 `/dev/snd`，实际听感必须 Preview 真机。

## 音频系统：音效 + 8bit 太空公路 BGM（2026-10-11，audio-system 附记）
- 用户「希望强化。音乐音效表现力」+「bgm需要是8bit+太空+公路风格」。**本项目此前零音频**。
- **素材**：`text_to_sound_effect` 出 **20 音效 mp3**（`assets/audio/sfx/`）+ `text_to_music` 出 **3 首 BGM ogg**（`bgm_menu` 星港/`bgm_battle` 战斗公路/`bgm_boss` 首领，随机文件名重命名）；每文件配 `.meta`（22hex uuid 验重）。
- **新模块 `scripts/AudioDirector.lua`**：`Init(scene)` 建 8 SoundSource 播放池 + 2 条 BGM 通道；`Update(dt, snapshot, events)` 消费**与 Presentation 同一份**领域事件 → 播音效（`brick_hit` 按 destroyed 分流 + 节流；`item_used` 按 key）；**BGM 状态机** menu→menu、战斗态→battle、**首领在场→boss**（`bossAlive` 由 `wave_started.isBoss`/`boss_defeated` 跟踪）；**交叉淡入淡出**；音效 pitch 随机防单调（`Play(sound, freq*pitch, gain)`，frequency 是绝对 Hz 非倍率）。
- **接线**：`uiFx.audio = require`（挂表，**零新增顶层 local**）+ `Backend.Init` pcall Init + `Backend.Shutdown` + `Backend.TickAudio/PlayUiSfx`（挂表）；`client_main.HandleUpdate` 把 DrainEvents 存 `frameEvents` 先给 Presentation 再给 TickAudio（只 Drain 一次）；`HandleMetaAction` 按 action 播 UI 音。资源可选（pcall，缺文件静默跳过）。
- 验证：LSP **30 文件 0 Error**；**纯模块探针 `probe_audio2` 10/10 PASS**（加载 20/20、BGM 状态机全对、事件+UI 音不崩、Shutdown 幂等）；**真渲染 `probe_audiorender`** 跑完一局 `ready/menu/battle=true`，零 LoadChunk/overlay/Lua/空顶点错误；dist 含全部 23 音频资源。官方多人 build + 预览上传 ✅。
- 抗体 AB-267（音频 0→1 先纯模块探针再真渲染集成探针；播放池轮转 + BGM 双通道交叉淡入）、AB-268（已满 200 顶层 local 的后端一律挂表+新模块）。⚠️ **本环境无 `/dev/snd`**，实际发声必须 Preview 真机。⚠️ 顺带修复并发会话造成的 broken commit（模块/资源未提交）。
- ⚠️ 顺带发现：`ui/StageTransition.lua` 被 HEAD 引用却未提交（属并发会话，**未代提交**）。

## 主菜单齿轮设置屏 + 危险操作确认面板（2026-10-11，gear-settings 附记）
- 用户四项：①CTA 去掉「选择关卡」小字让「开始战斗」更大；②局内暂停键右上→左上；③主菜单左上角加齿轮设置键；④设置页含恢复购买/清空存档，点后弹**手机键盘（0-9 * #）确认面板**，输入正确确认码才执行。
- **CTA**：去副标题，`ArtText.DrawCentered(..., FitHeight("startbattle",60))` 居中铺满。**暂停钮**：`GetHudPauseRect` 改 `{x=10,y=8,28,28}`，`BattleHUD` 左栏内容右移 26px。**齿轮**：`DrawMenu` 内联 40×40 按钮 + `Backend.HitTestMenuGear`（顶层 local 已满 200，只能内联+挂表）；新图标 `ui_icon_gear_20261011.png`（0718 管线）。
- **设置屏 `ui/Settings.lua`（新）**：两屏插件注册 `settings`/`reset_confirm`。列表屏两项（恢复购买 gem/金、清空存档 reroll/红）；确认屏 = 提示 + 确认码显示（restore 1234/delete 0000）+ 电话键盘 3×4 + 删除/确认/取消；`input_==code` 才启用确认。`PlayerData.ResetAll()` 新增。
- 验证：LSP 29 文件 0 Error；真渲染齿轮/设置屏/确认面板/战斗暂停钮/CTA 五图目视正常；`probe_setlogic` **9/9 PASS**（齿轮命中、确认码状态机、清档 11037→0）。官方多人 build + 预览上传 ✅。展示版本归并发会话（未动 BUILD_VERSION，当前 0.13.57）。
- 抗体 AB-265（顶层 local 满 200 → 内联+挂表）、AB-266（危险操作要键盘确认码；多行网格按行数反推面板高）。⚠️ 真机观感待 Preview。

## 附魔车光环改真 3D（2026-10-11，enchant-aura-3d）
- 用户「环绕车辆的粒子实行使用 3D 特效。因为呢，我们这个游戏呢，它这个 2D 的界面和 3D 界面并不是完全平行的，所以会导致有一些问题啊」。
- **真因（通道级）**：上一批的可见标识是 **2D overlay 光环**（`CombatImpact.DrawEnchantAura` 手工投影），46° 斜俯视正交下 `z` 投影到屏幕 Y，overlay 按玩法平面 z=0 标定、车辆锚点 z≈-0.09~-0.13m → 光环相对真实 3D 车分离。
- **修法**：`Renderer3D.SyncEnchantAura`——粒子绕 `GetVehicleAnchorWorld` 在 3D 空间 XZ 平面转圈 + Y 起伏；每档稀有度一个 BillboardSet（3 个，颜色烘焙进软圆纹理，DiffAlpha 不读顶点 rgb）；相位 `game.elapsed*2.6` 派生。移除 2D 版。诊断 `DebugEnchantAuraCount()`。
- 验证：LSP 29 文件 0 Error；真渲染探针（真实渲染路径 540 帧）**aura=0→aura=10**，零 overlay/Lua/LoadChunk/空顶点错误。官方多人 build + 预览上传 ✅。抗体 AB-264。

## 每关开局机型多样化（2026-10-11，stage-start-variety）
- 用户「每关开局的这些敌机类型都一样，真是太无聊了。」
- **真因**：`Game.GetAvailableTypes` 用 `StageCatalog.GetStageWave`（关内波次 1..10、**每关重置**）当 `WAVE_ROSTER` 门槛 → 每关第 1 波可用池都只有 `scout`（基线探针实测 12 关开局全 scout）。
- **修法（`Game.lua` 两处）**：①解锁进度改「累计难度」`(GetStage(wave)-1)+GetStageWave(wave)`（第 1 关与原版一致，第 2 关起开局带上已解锁机型）；②`PickWaveAircraft` 最新机偏置 0.6→0.3。
- 验证：LSP 27 文件 0 Error；`probe_variety` **4/4**（关1 恒 scout / 关5 4 种 / 关10 5 种）；`probe_offscreen` 回归 4/4；真渲染冒烟零目标错误。官方多人 build + 预览上传 ✅。抗体 AB-263。

## 局内附魔卡（2026-10-10，v0.13.57）
- 用户「每完成一波，玩家将允许获取/更换一个'附魔卡'，显示在局内界面左上角，与道具对称，使用后消失，效果是改变预备发射/当前若空则顺延下个预备发射的车，让它拥有一种强力的特殊效果，该效果也分蓝紫黄三种稀有度，高波次容易出高稀有度」+「没附魔时不显示，太挡了，用完之后2s内渐隐」。
- 新增 `scripts/EnchantCatalog.lua`（9 卡，每张不同机制轴）：蓝=裂变/吸血/追踪、紫=穿透/连锁/霜冻、黄=重击/爆裂/三连。`Roll(wave,rng)` 稀有度权重随波次线性上升（wave1 蓝80/紫18/黄2 → wave21+ 蓝25/紫45/黄30）。
- `Game.lua`：`UpdateWaveLogic` 波次推进处 `GrantEnchant`；`UseEnchant` 有车立即生效、无车顺延（`CreateMarble` 消费 pending）；命中效果（伤害倍率/穿透/回血/追踪/连锁/爆炸/冻结全场/分裂/三连）全落机制上。**零新增顶层 local**（状态收 `Game._enchant` 表、暂停常量收 `PAUSE_SUPPLY` 表腾槽位）；`ApplyEnchantToMarble` 前向声明。
- UI：`ui/BattleHUD.DrawEnchant` 左上角（宽 132 避 Boss 阶段条 x=150）；**空手不画**、**用掉后 2 秒渐隐**（`state.enchantAlpha` 1→0）。`Backend.GetEnchantRect`/`HitTestEnchant` 同源。9 张 32×32 像素图标（0718 管线，5–7 色）。
- 验证：LSP 27 文件 0 Error；`probe_enchant` **62/62**；`probe_encheff` **9/9**；真渲染 `probe_enchrender` 零目标错误；有卡/无卡像素对比 **3699 vs 0**。官方多人 build + 预览上传 ✅。版本 → 0.13.57。
- 抗体 AB-247（周期性发奖钩子挂「真正推进」那行）、AB-248（常驻 UI 元素要给显隐/渐隐）、AB-249（顶层 local 逼近上限时收表腾槽位）。⚠️ 手机 FPS/真机观感待 Preview（渐隐中间帧未截到，AB-220）。

## 屏外敌机超过 3 架时暂停生成队列（2026-10-10，offscreen-spawn-cap 附记）
- 用户「屏幕外飞机超过3架时暂停生成队列」。判据 = 敌机底边仍在可见战场顶之上 `enemy.y + gridH*brickSize < -102`（与 `ResolveFleetOverlaps` 的 `aOffscreen` 同口径）；`StageCatalog.MAX_OFFSCREEN = 3`。
- **两处门控**：①`SpawnNextNormalEnemy` 逐架放出——屏外**在场**数 ≥3 推迟本架；②`UpdateWaveLogic` 波次启动——屏外**在场数 + `pendingSpawn.remaining`** ≥3 不开新一波。⚠️ **真凶**：精英/护航/首领走 `SpawnSpecialEnemy` 不走队列，只改 ① 时精英波会插进来把屏外顶到 4（8 种子全复现 `scout,scout,scout,elite_hammer`）。
- ⚠️ 两处口径**不能统一**：①只数在场（把 `remaining` 也算进去会死锁——整波一开始 `remaining=10` 永远 >3）；②必须算 `remaining`（待放的将来也生成在屏外）。零新增顶层 local（Game.lua 已 199，AB-166），计数内联在函数体内。
- 验证：LSP 27 文件 0 Error；`probe_offscreen` **4/4 PASS**；**8 固定种子全部峰值=3**（修前 8/8 都是 4）；真渲染冒烟零目标错误；官方多人 build + 预览上传 ✅。展示版本归并发会话（未动 BUILD_VERSION，当前 0.13.55）。
- 抗体 AB-231（生成限流要覆盖所有生成路径，特殊单位常不走队列）、AB-232（逐架 vs 波次两处口径不同）、AB-233（空间判据复用既有口径）、AB-234（峰值类探针必须固定种子多布局）。⚠️ 真机观感待 Preview。

## 艺术字去黑幕铺满按钮 + 商店标签转白（2026-10-11，arttext-fill-white 附记）
- 用户「车型外观与拖尾样式要更白更浅」+「开始战斗还是不合格，**直接占满按钮无黑幕**」+「继续战斗有开始战斗同款问题」——三处都是艺术字运用。
- **① CTA「开始战斗」**：上一批的「暗铭牌 + 白 tint」被判不合格 → **去掉暗铭牌**，白 tint **等比放大铺满按钮**（`FitHeight("startbattle", 50)`，scale≈1.14），金属字直接压在青底上、无黑幕。**② 暂停「继续战斗」**同款（放大到按钮高 34px）。
- **③ 商店分页标签**：原 `tint = active and C.warn or C.dim`（金/暗灰）→ 金属字被非白 tint 塌陷（AB-258）→ 改**白 tint** + 未激活降 alpha（255→190）→ 更白更浅。
- **ArtText 新增**：`Draw/DrawCentered` 加可选 `scale` 尾参；新增 `FitHeight(key, targetH)` 返回 scale/w/h。⚠️ 母版是完整成品，只等比缩放。
- 验证：LSP 27 文件 0 Error；真渲染 `probe_cta`/`probe_pausetxt`/`probe_shop` 三屏 exit0、零目标错误；实图目视 CTA/暂停/商店标签均金属白字。官方多人 build + 预览上传 ✅。展示版本归并发会话（未动 BUILD_VERSION，当前 0.13.57）。
- 抗体 AB-260（金属字亮底无铭牌：白 tint + FitHeight 铺满，优于暗铭牌）。⚠️ 真机观感待 Preview。

## 主菜单 CTA 艺术字改白 tint + 按钮加高（2026-10-11，cta-arttext-fit 附记）
- 用户截图点名「你看出这个开始战斗涉及的问题了吗？」——放大定位**两个真问题**（非审美分歧）。
- **① 副标题压铭牌（布局回归）**：arttext-metal 把 `startbattle` 母版 38→44 高，而 CTA 绘制没跟着调——铭牌高 `ah+8`=52 从 `ctaY+4` 起 → 底边 `ctaY+56`；副标题仍固定 `ctaY+52` → **交叠约 4px**。修法：`GetMenuCtaRect` **72→84 高**，副标题 `ctaY+62`、铭牌 `ctaY+6`。实测铭牌底 486、副标题 492–508、按钮底 514（间隙 6px），CTA 底距天赋大卡 18px。
- **② 金属被青 tint 压塌**：CTA 艺术字原用 `C.cyan` 乘法染色——新母版是**立体金属灰**，乘青后压成**扁平暗青**、倒角全丢。修法：改 **白 tint `{255,255,255}` + 保留暗铭牌**。暂停「继续战斗」同源改白。
- 验证：LSP 27 文件 0 Error；真渲染 `probe_cta`（停菜单）+`probe_pausetxt`（暂停）实图确认金属倒角清晰、不压副标题、`[ArtText] loaded=8/8`；两探针零目标错误；官方多人 build + 预览上传 ✅。顺手补 `scripts/ui/ArtText.lua.meta`（此前漏入库、清单已引用）。展示版本归并发会话（未动 BUILD_VERSION，当前 0.13.57）。
- 抗体 AB-258（乘法染色：金属素材用青/深 tint 都会塌，默认白 tint）、AB-259（母版尺寸变更要 grep 全部绘制点核对硬编码偏移）。⚠️ 手机 FPS/真机观感待 Preview。

## 按序号封顶血量的曲线换成指数缓升（2026-10-11，hp-cap-curve 附记）
- 用户「第n架飞机的血量上限改为0.5*（1.25^n+1）向下取整」。只改 `StageCatalog.GetFirstShipHpCap` 的函数体：`2n−1` → `floor(0.5×(1.25^n + 1))`；调用点/门控/「只封顶不抬升」/精英Boss 不参与 全部不动。
- 新曲线：n=1..4→1、n=5..7→2、n=8→3、n=10→5、n=12→7、n=15→14、n=20→43（旧 2n−1 = 1/3/5/7…，**前期显著更平缓**、前 4 架恒 1 血）。
- 验证：LSP 27 文件 0 Error；`probe_hpcap` **26/26 PASS**（n=1..20 逐值 / 边界钳 1 / 单调 / 前 4 恒 1 / 与旧公式对比）；真渲染冒烟零目标错误；官方多人 build + 预览上传 ✅。展示版本归并发会话（未动 BUILD_VERSION，当前 0.13.55）。
- 抗体 AB-235（改曲线只动一个纯函数、调用点语义全留）、AB-236（换曲线要逐值新旧对比，指数曲线两端手感都要点出）。⚠️ 平衡手感待 Preview。

## 拖尾形态重做（2026-10-10，trail-shape-rework 附记）
- 用户三点：「有些拖尾比车都粗」「有些纹理循环太招笑」「你明明甚至都可以抛弃线性」——都是**形态层面**的真问题。
- **① 太粗**：宽度基准挂在**碰撞半径**（0.36m）而车体真实半宽仅 0.137m（2.6 倍差）→ `ember` 主体达车体 147%。新增 `VEHICLE_HALF_FACTOR≈0.403`，宽度基准改车体半宽，`headW/tailW` 变**车体半宽倍数**。修后最宽 `ember/normal` 97.4%。
- **② 循环招笑**：`(i+flowOffset)%3==0` 每 3 段画 1 段 + `flow=7` 每秒跳 7 次 = 机械节拍。删 `dash/flow/bead/head`，改**空间锚定噪声** `flicker*sin(along*freq)`（相位沿弧长、不随时间跳）。
- **③ 抛弃线性**：新增 `waver/waverLen/waverDrift` 中线横向正弦波动，幅度 `vHalf*waver*(1-t)`（尾端更飘），用波动后端点重算法线。twin 0.22 / ember 0.34 / comet 0.06，其余笔直。
- 验证：`probe_trailwidth` ALL PASS 24 组（≤车体半宽）；`probe_trailstyles` ALL PASS；`probe_trailhead` ALL PASS（worst 0.0570）；真渲染冒烟零目标错误；LSP 27 文件 0 Error；官方多人 build + 预览上传 ✅。
- 抗体：AB-244（宽度上限锚宿主真实尺寸，不用碰撞半径）、AB-245（周期性图案改空间锚定噪声）、AB-246（抛弃线性=中线加沿弧长横向波动）。

## 重出数字图标 + 修复糊字标（2026-10-10，digit-arttext-regen 附记）
- 用户「10个数字图标重新生成，很多其他艺术字装载出错」。**分开处理**：①10 个数字图标重出；②「装载出错」诊断后是**部分字标字形糊**，非加载失败。
- **诊断（关键）**：真渲染日志 `[ArtText] pixel titles loaded=8/8` + `[DigitFont] pixel digits loaded=10/10` —— 加载 100% 成功。放大图目视定位真凶：`ui_tt_daily`/`ui_tt_menu`/`ui_tt_resume` 字形糊（core/outline 比仅 0.09–0.30，清晰张 0.28–0.44）。**「装载出错」= 图本身画坏**（AB-242）。
- **数字重出（0718 管线）**：nanobanana `transparent:true` 384×512 出 10 草案 → alpha 二值化 128 → bbox → **按字形高度归一**（`GLYPH_H=26`，非 bbox 等比，AB-243）→ **4-邻域腐蚀**得白芯 + 掩码减芯得近黑轮廓（两色）→ 居中贴 24×32（字形顶 y=2）。10 张全 2 色、高 26 统一。新 `DIGIT_W = {19,16,17,19,17,19,18,19,17,17}` 已进 `ui/DigitFont.lua`。
- **3 张糊字标重出**：各出 a/b 两版，选 b（白粗体+黑描边）→ 按显示高度归一（daily 24 / menu 22 / resume 26）→ 亮度阈值分两色 → **沿用旧文件名 + 旧 .meta uuid** 覆盖。新 core/outline 比 ~0.47–0.50。
- 验证：LSP 0 Error（27 文件 1195 诊断）；真渲染探针（真实 `ClientMain.Start`）装载 8/8 + 10/10；选关/首页/暂停三屏 exit0、零目标错误；裁剪设计画布实图目视——选关「1」清晰、首页分区标题清晰、暂停两按钮不再糊。官方多人 build + 预览上传 ✅。展示版本归并发会话。

## 选关界面风格重做：星座星图（2026-10-09，stagemap-star 附记）
- 用户一句「选关界面太难看了，重做风格」——上一版「蜿蜒光带 + 圆钮」被判难看；**换风格 = 换视觉隐喻，不是调参**（AB-239）。
- **新隐喻（只改 `ui/StageSelect.lua` 绘制层 + 命中形状）**：①**六边形关卡芯片**取代圆钮（已解锁=亮色环 + 底盘 + 内环 + 顶面受光；当前最新关=亮色实心底 + 深关号 + 脉冲外环；未解锁=暗六边形 + 小锁）；②**星座直线连线**取代蜿蜒光带（外发光+主线+白芯，已解锁亮青/延伸暗青，端点内缩避让芯片）；③**视差星空底**；④三星改菱形。
- **命中与绘制同形**：六边形判定 `|dy| ≤ r` 且 `(dy·0.5 + |dx|·0.866) ≤ r`（原来用圆形会「角上点不到、圆外能点到」）。
- 删死代码 `PathPoints`/`StrokePath`（蜿蜒路径，无调用点）；保留 `NodeYAt`。
- 验证：LSP 0 Error；真渲染 `probe_ui`(stage_select) 与 `probe_stage5`（预置 5 关→maxStage=6）exit0、零 overlay/Lua 错误；实图目视六边形芯片/星座连线/星空底/当前关焦点均清晰。官方多人 build + 预览上传 ✅。展示版本归并发会话。

## 按钮/选项卡艺术字 + 选关统一化（2026-10-09，arttext-buttons 附记）
- 用户「我还想要更贵更贵…大量使用艺术字生成按钮/选项卡的标题」+「另外我想要更酷炫更统一的选关界面UI」（附截图）。
- **艺术字素材（0718 管线）**：nanobanana `transparent:true` 出 8 个标题 → bbox 裁切 → 按目标显示高度缩 → alpha 二值化 → 压成**两色「白芯 + 近黑轮廓」** → `ui_tt_{startbattle,daily,collect,vehicle,trail,resume,menu,stage}.png` + `.meta`。**母版高 = 显示高**，1× 最近邻，逐图记宽。
- **新模块 `ui/ArtText.lua`**：懒加载（首绘才 `nvgCreateImage(ctx,…,NEAREST)`）；`Has/Width/Height/Draw/DrawCentered`；**全部可选资源 + zpix 回退**。零新增 Scene3DBackend 顶层 local（AB-166）。
- 🔴 **AB-238（最坑）**：两色艺术字用 `nvgImagePatternTinted` 乘法染色时，**tint 越接近黑越会塌成黑疙瘩**（用户「异常变色？！」）。亮底按钮要深字时，**别深 tint**，改「垫暗色铭牌 + 亮 tint 艺术字」。
- 接入点：CTA「开始战斗」、暂停「继续战斗/返回主菜单」（带铭牌/图标右侧）、`SectionHeader`（今日福利/养成收藏）、商店分页标签（车型外观/拖尾样式）、选关标题「选择关卡」。全部保留 zpix 回退。
- **选关统一化（只改绘制层）**：内容区补仪器边框（四角折线+网格+刻度带）；**未来关幽灵节点**（路径延长线 6 个占位，极低 alpha、不参与命中）补满内容区；**流动光点**沿路径按 `D.anim()` 相位前进。
- ⚠️ **AB-237**：`NodeCenter(L, stage)` 只对 1..maxStage 有效，幽灵节点越界取到 nil → `attempt to compare number with nil` → 选关白屏（LSP/build 都发现不了）。修法：新增 `NodeYAt(L, stage)` 按同一公式算任意关号 y，真实布局不动。
- 验证：LSP 0 Error；真渲染 home/stage_select/shop/pause 四屏 exit0、零 overlay/Lua 错误；实图目视 CTA/分区标题/商店标签/暂停按钮/选关均正确。官方多人 build + 预览上传 ✅（`[ArtText] pixel titles loaded=8/8`）。展示版本归并发会话。

## 选关滚动修复与 XHR 核验边界（2026-10-09，stage-scroll-fix 附记）
- 用户报 XHR 响应处理 `{}` 159 次与「关卡列表拖不动」，两项分别核验。
- 只修 `ui/StageSelect.lua`：倒置塔布局加 `scrollY_`，合法滚动范围应为 `[0,MaxScroll]`，旧负范围把定位与拖动钳回 0；装饰 seed 同步正号。第 20 关默认 Y=-1706→234，视口 164..872。代码提交 `0838fc8`，不改展示版本。
- 规则 140 断言、真实鼠标/主 TouchID=0/第二指隔离/取消/轻点第 2 关 12 断言通过；真实 Draw 覆盖顶端 15..20 和底端 1..6；intro 后敌机入场与实际飞行通过，目标 Lua/overlay/LoadChunk/空顶点错误 0。LSP 27 文件 0 Error，官方多人 build 与预览上传成功。没有截图落盘，不宣称目视或手机全 DPR 验收。
- XHR：当前 sources/adopt 不支持旧 official-res 固定引用链复发；平台现有业务日志有云/高分/余额成功，但缺 HTTP/宿主请求上下文。未证实自动重试风暴，未禁云、未过滤日志；**159 次 XHR 尚未定位或验证消除**。同日公开引擎清单核验：stable 引擎 `1.33.2` / manifest `d2e42cce` 的 `version.json` 明确带 `binary_hash=0d39599c, commit_hash=62ae71fb, branch=HEAD`，与报告完全匹配，不能再因本地游戏 hash 未命中判旧游戏包。
- 增量只读核查：最新索引为 86 条（此前 264），UTC 11:50:43..11:53:43 / UTC+8 19:50:43..19:53:43，不是追加保留历史；未见原报错时段、宿主 HTTP 渠道或已落盘反馈。限定本地文件、公开加载器/正式引擎 JS/解压 WASM 未找到精确报错来源；data 只检查资源索引、未扫描全包。桥接 JSON.stringify 可丢对象可枚举信息，但正常同 realm Error 保留 stack/message，不能把 `{}` 直接判网络/JSON 失败。后续仅需同报错会话脱敏请求路径/方法/状态/响应类型/异常栈，无需存档或凭证。本轮不改游戏代码/展示版本，POST-1/2执行，persona与POST-3跳过（没有新增用户特征/跨项目规则）。
- 合并补测：首轮漏同步新增 ArtText 依赖导致探针失败，补齐后发现并发幽灵节点超出 `nodeY` 范围、`cy=nil` 中断选关绘制；对应会话以 `NodeYAt` 修正。修后完整冻结快照重跑 140 规则/12 输入/顶端15..20与底端1..6真实 Draw/intro后实际飞行均 PASS，五进程 exit0、目标错误0；失败日志保留，不作为并发美术目视验收。最终 LSP27文件0 Error、官方多人build+预览上传成功。
- POST-1 执行（persona 无新增特征跳过）；POST-2 本人代码/记录独立提交；POST-3 执行 AB-237/238（倒置列表符号、HTTP 证据边界），随行 persona/preferences 无新增偏好跳过。并发美术与过渡修改保留。

## 拖尾跟随修复（2026-10-09，trail-follow-fix 附记）
- 用户报「尾焰起点跟不上车且粗细没有跟随车辆」——两句是**两个独立真因**。
- **① 起点跟不上车**：光带只画到最新采样点 `samples[n]`（永远落后一个采样间隔），且**断续样式 `dash=3` 只画每第 3 段**、车头那一段常不在采样点上 → 前沿停在离车 **1.2 世界单位（≈67px）**（探针实测 `dash/speed gap=1.2175`）。修法：(a) `track.head`（存了却从未消费）追加为最后一点，循环改 `for i=1,n` / `b=(i<n) and samples[i+1] or tailPt` / `t=(i-1)/n`；(b) **头段 `i==n` 永远画**，不受断续图案影响。修复后 **worst 1.2175 → 0.0726（≈4px）**。
- **② 粗细没跟随车辆**：`glow` 最大 2.8 × `headW` 0.56 = **1.57× 碰撞半径**，光带比车体宽。修法：所有层半宽钳到 `maxHalf = radius*WORLD_SCALE`（柔光/爆闪/光珠/双轨柔光逐层 `math.min`）；`ember.glow` 2.80→1.45（否则被钳平失去层次）。
- **③ 扭转锚点订正**：v2 扭转角 `twist*(i-1)` **在车头取最大**，46° 斜俯视下 z 投影成屏幕 Y → 车头被推出车体。改为**锚定车头** `twistAngle(k)=twist*max(0,n-k)`；2D 预览 `wob` 同步（车头位移 0）。
- 验证：`probe_trailhead` ALL PASS（worst=0.0726）；`probe_trailwidth` ALL PASS 24 组（每层 ≤ 半径，giant/speed 半宽比 1.67）；`probe_trailstyles` ALL PASS；真渲染 `probe_render` 零目标错误；LSP 27 文件 0 Error；官方多人 build + 预览上传 ✅。展示版本归并发会话。
- 抗体：AB-234（前沿贴车 = 「画到车尾」×「头段不受断续影响」两条约束）、AB-235（加层时每层独立受「不宽于车体」约束）、AB-236（斜俯视下沿长度增长的 z 位移必须锚定贴物体那端）。

## UI 布局错位修复 / 适应性（2026-10-09，ui-adaptability-fix 附记）
- 用户给五张实机截图（天赋树/首页/选关/战斗/暂停）点名「精美程度和 UI 适应性不满意」——**逐屏读图后是真布局 bug，不是审美分歧**。
- **天赋树**：血量规则行(y+146) 与线路名表头(y+164) 只差 18px → 两行糊在一起。头部拆成**标题栏(48)/规则行(y+52)/表头带(y+66 高 24)** 三段，内容区下移到 y+96。另：已解锁节点原**统一染青**丢掉线路身份 → 改为**保留线路色亮环 + 内亮环**。
- **选关**：关卡少时内容矮于可视区却仍贴底 → 上方大片空白。`freeSpace = content.h - contentH`，`>0` 时整塔**垂直居中**（偏移写进布局函数，绘制与命中同源）；`FocusLatest` 改读布局 `nodeY[maxStage]` 反算。
- **战斗**：新手「向下拖拽 松手发射」原贴在**手势图底部**，同时压住手势与扣血红线 → 移到动画**上方**（`topY - 24`）。
- **暂停**：「继续战斗」播放三角固定 `x+58` 而文字整宽居中 → 文字压住三角。改为三角锚左半区 `x+w*0.30`、文字锚右半区 `x+w*0.60`。
- 验证：LSP 27 文件 0 Error；几何探针 `probe_layout` **8/8 PASS**；真渲染探针 talent/stage_select/pause 三屏 exit0、零目标错误；裁剪设计画布后**实图目视**三屏均正确。官方多人 build + 预览上传 ✅。展示版本归并发会话（未动 BUILD_VERSION，当前 0.13.55）。
- 抗体 AB-230（「UI 不适应」先逐屏量错位再谈美化）、以及「内容矮于可视区要显式居中」「多段文本行距 ≥ 字号×1.35」「图标+文字按钮用左右半区锚点」「状态色别覆盖身份色」四条。

## 受伤未碎的砖块极短闪白（2026-10-09，brick-hit-flash 附记）
- 用户「飞机方块受伤但没丝网碎裂的要有极短受伤闪烁」。**信号早就存在**：`DamageBrick` 未击碎分支本就 `Emit("brick_hit",{destroyed=false})` → `Presentation.brickSpark` 本就写 `hitFlashes[key]=0.12` → `ui/CombatImpact.DrawHits` 本就消费。**问题只是画成了「白色十字标记」而不是「方块闪一下」**。
- **改动（仅 `ui/CombatImpact.lua` 的 `DrawHits` 一个函数）**：十字 → 砖块世界矩形转屏幕矩形的**暖白实心闪 + 白亮边**（inset 6%、圆角 min(w,h)*0.18、alpha 180*flash、亮边宽 1.0+1.4*flash）。寿命常数提为 `HIT_FLASH_SECONDS=0.12`（与 Presentation 同源）。只用 `brick.alive` 的格闪（击碎格走碎裂特效，不叠闪白）。
- 验证：LSP 26 文件 0 Error；**记录式 mock NVG 探针** `probe_hitflash` **11/11 PASS**（几何/alpha/半衰/击碎格不画/过期不画/找不到敌机不崩）；真渲染冒烟 `probe_render` 零目标错误；官方多人 build + 预览上传 ✅。展示版本归并发会话（未动 BUILD_VERSION，当前 0.13.55）。
- 抗体 AB-226（先查信号是否已存在、只是形状不对）、AB-227（逐轴仿射投影→两角点求屏幕矩形）、AB-228（未碎闪白要与击碎特效按 alive 互斥）、AB-229（本环境离屏截图不可靠，纯绘制改动用记录式 mock NVG 单测 + 探针自身两个坑）。⚠️ 真机观感待 Preview。

## 前期出怪放慢 + 按出场序号封顶血量（2026-10-09，spawn-ramp-hp-cap 附记）
- 用户「前期的连续生成飞机间隔时长放三倍，到最后三波是现在的情况，中间平滑过渡。第一个飞机最多一血，第二个最多3血，第三个最多五血这样顺延」。
- **间隔**：`StageCatalog.GetSpawnInterval` 保留原曲线（关1 2.8s → 关13 起 1.12s）作为「最后三关目标值」，只乘 `ramp`——关1–5 ×3.0、关6 ×2.5→关9 ×1.0 线性、关10+ ×1.0。实测关1 2.80→8.40s，关9/13/15 不变。
- **血量封顶**：新增 `StageCatalog.GetFirstShipHpCap(n)=2n−1`；`Game.SpawnNextNormalEnemy` 用 `min(pendingSpawn.hp, cap)`——**只封顶不抬升**。判定用 `pendingSpawn.spawned`（本关已放出计数，非「场上无敌机」）+ `wave==本关第一波` 约束；`ResetGame`/每波开波都复位。精英/Boss 不参与。实测关1=1,2,3,2,2,2 / 关15=1,3,5,7,9,9。
- 零新增顶层 local（把 v0.13.50 的 `pendingSpawn.firstDone` 就地改成 `spawned`）。LSP 26 文件 0 Error；官方多人 build ✅（dist 1.0.1 含本改动）。展示版本归并发会话（未动 BUILD_VERSION，当前 0.13.55）。
- 抗体 AB-222（目标值当作曲线端点，不改整条公式）、AB-223（封顶用 min 不用 =）、AB-224（计数复位点与判定作用域一致）、AB-225（build 通过 ≠ 手感对）。⚠️ 平衡手感待 Preview 实机。

## 分裂车同时最多 15（2026-10-09，split-concurrent-cap 附记）
- 用户先要「分裂车同时最多存在20个」，随后改口径「改为15个」——上限常量最终为 **15**。限制真实生成而非渲染隐藏：存活待发 + 飞行 + 同帧 pending 分裂子车最多 15，库存车型键不计。
- `Game._NormalMarbleSlots` / `BALL_TYPES.normal.maxConcurrent` 同源预算；分裂不足名额截生成数，0 不发成功事件，单子车居中，保留递归与 splitCount 2/3/4。常规装填/暂停补弹满额保队首，不删场上车、不丢库存；回收后自动装填。上限是单一常量，改口径只需改 `maxConcurrent` 一处。
- 独立静态审查未发现问题，LSP 26 文件 0 Error；本地 Runtime **51/51、1578 断言 PASS、exit0**（cap=15）。官方多人 build 与预览上传 ✅（早期一次 `PLATFORM_OPERATION_FORBIDDEN` 为临时限制，重试成功）。POST-1 执行（persona 不新增），POST-2 代码独立提交（20 版 `c9f3413`、15 版单独提交），POST-3 判定跳过（小调整无新增跨项目信息）。展示版本不改，保留并发存钱罐/首机曲线/拖尾；手机与 3D 可见性未验收。

## 局内道具加强 + 分裂 ±5° 随机（2026-10-10，item-split-buff 附记）
- 用户「三个道具强度不明显，特别是炸弹继续加强；分裂车分裂时中间的车左右随机偏移 5 度以内」。
- 炸弹：每机炸「存活格一半、上限 12」（原固定 4）；冰冻 4→6s；护盾 30→60。分裂：每颗子车在扇区基准角叠 ±5° 随机，中间车不再固定走正前方，不改数量/宽度。
- 规则探针 4/4、496 断言、exit0（含实测最大偏移 4.997°）；LSP 0 Error；官方多人 build+预览上传 ✅。POST-1 执行、POST-2 本人 3 hunk 独立提交、POST-3 跳过（数值小调无新跨项目偏好）。

## 拖尾样式精进（2026-10-08，trail-style-mechanics 附记）
- 用户「商店拖尾拉完了，然后需要精进」。根因：六种样式此前只是同一条光带的宽/亮/断续/双轨**数值微调**（本项目自己记过的 AB-214：差异化要落在机制不是数值）。
- **加 7 条机制轴**（`MetaCatalog.TRAIL_STYLE_PARAMS` 纯数据）：`taper` 宽度曲线指数、`bulge` 头端鼓包亮核、`hue` 沿长度色相游移、`flow` 断续图案流动速度、`pulse` 明暗脉动、`railSpread`/`railTaper` 双轨间距与收拢。六种各占不同轴：经典=中性基准；彗星=taper+bulge；霓虹=hue；流光=dash+flow；双轨=railSpread+railTaper；余烬=taper+pulse。
- **渲染 `Renderer3D`**：`TrailColor(base,t,style,phase)` 参与 pulse/hue；几何按 taper/bulge 算宽度、`(i+flowOffset)%dash` 让图案流动、双轨按 `t^railTaper` 收拢。新增一个顶层 local `trailPhase_`（玩法 dt 累加，非 playing 不推进）。**预览 `MetaUI.DrawTrailPreview` 改为同一套参数与机制轴**（含 `D.anim()`），保证预览=实机。
- 验证：`probe_trailstyles` ALL PASS（各轴字段齐全、付费样式签名两两不重复、ribbon 中性、宽度曲线 ribbonMid 0.520 vs cometMid 1.061、未知样式回退）；逐样式真渲染截屏实图目视六者清晰可辨（经典 vs 余烬像素差 56363）；3D 战斗冒烟零 Lua/overlay/LoadChunk/空顶点错误。LSP 0 Error、官方多人 build 与预览上传成功。⚠️ 手机 FPS / 战斗 3D 可见性（Linux 黑场）未验收。
- 抗体 AB-221（机制轴而非数值）、预览须同轴、动画相位只走玩法 dt、纯观感改动必须像素取证。

## 第 1 关「测试模式」询问（2026-10-08，v0.13.56）
- 用户：进第 1 关时问「是否测试后期关卡」；**是**→解锁全部天赋 + 直入第 20 关强度；**否**→正常从第 1 关玩。追加「不需要是新玩家，第一关一直有」→ **每次进第 1 关都问**，不做「只问一次」。
- 触发点：①选关界面点第 1 关 ②第 1 关 stagewin「再战本关」。实现：新增 `scripts/ui/TestModePrompt.lua`，`MetaUI.RegisterScreen("test_mode", Draw, HitTest)` 插件注册（自动获得窗口弹动 + `WindowInput` 命中逆变换，**零改 `Scene3DBackend`/`Game.lua`**）。`HandleUpdate` 在菜单态执行 `pendingTestStage_` 跳关。
- ⚠️ 询问屏开在**菜单态**：再战分支必须先 `Game.GoToMenu()` 再开屏（否则永不跳关）。⚠️ Draw/HitTest 的 meta 注解必须**非空** `MetaState`，否则 RegisterScreen 那行报 `param-type-mismatch`。⚠️ 本环境离屏 `-screenshot-frame` 不生效，询问屏画面未自证，待 Preview。

## 车辆专属卡 vs 基础卡差异化（2026-10-08，v0.13.55）
- 用户「车辆专属和基础卡差异化做的太差」。根因：八张车卡=**四条公式各写两遍**（`base_X` 与 `X` 都改同一个 `BALL_TUNING` 字段，专属卡只是数值更大）。定案：**基础卡=主属性打底数值**（保持简单、常出、可叠高），**专属卡=换机制维度**（挂到引擎已有但卡池未用的钩子）。
- 四张专属卡（全升 `rare`、`weight` 1→0.6）：`split` 裂变核→分裂数量 +1 颗（`splitCount` 2→3→4）；`ice` 霜裂涂层→冻结中敌机受击 +30%/级（`iceShatter`）；`speed` 动能穿刺→加速车每次飞行穿透 +1 块不反弹（`speedPierce`）；`giant` 冲击波→范围击碎 15%/级 概率双倍伤害（`giantCritChance`）。
- 实现全在 `Game.lua`、**零新增顶层 local**（只加 `BALL_TUNING` 字段）：`CreateMarble` 加 `pierceLeft`；`TrySplitNormal` 按 `splitCount` 在 ±splitSpread 扇区均分生成 N 颗；`DamageBrick` 冻结时 `×(1+iceShatter)`；碰撞分支 speed 车 `pierceLeft>0` 不反弹、沿速度前推 0.75 格、`ignoredBrick`+`Emit(speed_pierce)`；`DamageGiantArea` 逐格掷暴击×2（复用 `crit_hit` 金色飘字）；`ResetGame` 在 `LoadBalls` **之前**复位四字段。`Presentation` 只加 `speed_pierce→pierceSpark`（橙色火花）。
- 门控不变：专属卡仍需 `ballCard` 天赋节点（`kind~="base"` 且带 `ballType`），基础卡只需车解锁——差异化只在效果维度。验证：规则探针 `probe_card_diff` **10/10、61 断言、0 Lua 错误**（含「专属卡不改任何打底数值字段」硬断言）；真渲染冒烟注入四机制→真实发射→战斗帧 exit0、目标 Lua/overlay/LoadChunk/空顶点错误 0；LSP 两文件 0 Error；官方多人 build+预览上传 ✅。
- POST-1/2/3 均执行；抗体 AB-214（差异化落机制不落数值）。随行 persona/preferences 跳过（无新增跨项目偏好）。
## 范围攻击与完整击毁反馈（2026-10-08，v0.13.54）
- `Game.EjectBrick` 最后存活格消失且未越线时即发 `enemy_destroyed`（中心/宽高），`Presentation` 独立消费；原 `enemy_cleared` 奖励时序/击破字不变、不重播新冲击。独立审查抓到最后砖XP同帧升级导致旧清机事件延迟，已拆事实与奖励，未提前结算。8对象预算/对象池，范围寿命0.48s/整机0.62s，max轻震0.22/0.18，无新顿帧，退菜单/复位清理。
- `ui/CombatImpact` 纯宿主绘图（双环/白芯/短光刺，清机另加碎光），投影两轴分别取值；新模块避开Backend200 local上限，无图/字体/context/RT。升级 y270、胜利 y155 的遮罩后回声不穿正文/按钮，不放开其他旧 world-fx。
- 最终即时事实接口规则/表现15/15、289断言PASS；原1秒CD与就绪提示专项重跑72/72、1377断言PASS。六场真实Draw及各自独立完整TTL/相机归位通过，15进程exit0、目标Lua/overlay/load/空顶点错误0；五份冻结源码SHA逐进程与生产一致。六份最终原图已内部目视（范围/整机/范围升级/清机升级/Boss胜利/普通末块XP），环与回声可辨、不压正文按钮；普通/范围最后砖经验同帧升级立即反馈、选卡后不重播。LSP24文件0 Error（922 Warning/106 Hint），官方多人build372与预览上传成功。失败/超时的中间探针保留不计PASS；手机FPS、全DPR、真实支付、用户审美与Linux既有HDR/缺图/无体素导致的中央3D黑场不计验收。
- POST-1执行：状态与本轮用户原话；POST-2执行：版本与本人hunk提交；POST-3执行：通用抗体AB-213，随行persona/preferences跳过（本轮具体反馈无新增跨项目偏好）。保留53记录/AB-211/212与原VisualCatalog缓存。

## 巨型车就绪提示与冷却一致（2026-10-08，v0.13.52）
- 用户「cd还没到就跳可以贯穿了！」。复现旧版真实 area→consumed→armed：CD=1、Presentation 有一条「可以贯穿」；0.25s 后普通碰撞有效、圆域邻格不受伤。旧 36/36 CD 测试没覆盖反馈，还曾接受立即 rearm，不能据此否认用户问题。
- `Game` 新增实例 `giantPiercePending`：CD 中只保留反弹资格、`giantPiercing=false`，`ArmGiantPiercing` 不发提示；玩法子步归零时自动武装且仅提示一次。1 秒内置 CD、冷却期普通碰撞、范围/伤害/暴击/异常/逐帧砖去重与暂停升级冻结不变，无新增顶层 local。
- `Presentation` 登记 consumed 反馈；armed/consumed 携带车 id，ready 字记录 kind=giantReady、marbleId。消费时回收本车旧提示，异车与普通飘字保留；池复用重置 id。同帧恢复就绪后马上消费也无错误残字。
- 正式 runtime 新专项 36/36、968 断言 PASS；旧专项适配 3 处 rearm 断言后新跑 36/36、409 断言 PASS，两次 exit0。9 格 30/60/120Hz×0/100/5000 速度、0.99/1 秒、自动恢复、多车/同帧/冻结/范围等覆盖；当前生产指纹吻合。LSP 0 Error（24 文件，有既有 Warning/Hint），官方多人 build 与预览上传成功，展示版本/大厅 0.13.52。最终两次真渲染 exit0、目标 Lua/overlay/load/空顶点错误0；CD≈0.767 时 ready=0，归零后 ready=1 且额外反弹0；两份实图已内部目视，真实过 intro 发射/暂停冻结恢复通过。首轮截图计帧偏差已补测；Linux 既有 HDR/缺图/无体素 3D 黑场与手机性能不计验收。生产提交 `f31f305`，只含 Game/Presentation/两处版本行。
- POST-1 执行：状态与用户反馈；POST-2 执行：版本行+本人片段独立提交；POST-3 执行：通用抗体 AB-210（结算/就绪/反馈同源、同车提示消费清理）。随行 persona/preferences 判定跳过：没有新增跨项目用户偏好。保留初始 `VisualCatalog.lua` 修改。

## 游戏更名 + 字标重出（2026-10-08，v0.13.51）
- 用户要求「更新游戏名称：货车大战飞机，包括有星系内标图片需要重新生成」→ **改名与字标一起做**（首页大标题是 AI 位图，不是文字渲染，只改字符串会留旧名 logo）。
- 改名点：`Scene3DBackend.GAME_TITLE`/`GAME_SHORT_TITLE`、`client_main.graphics.windowTitle`、`lobby_runtime` 加载页标题栏、`lobby_ui` 的 `title_` 默认值 + 6 处 `title=`、`Game.lua` 顶部注释、`.project/project.json` 的 `taptap_publish.title`（发布名契约）；description 的「竖屏飞机大战」→「竖屏弹射对战」。旧名全库 grep 零残留。
- 字标重出：nanobanana 出 4 张透明底草案（**必须 `transparent:true`**）→ 按内容 bbox 裁切 → 缩到 120 高 → alpha 二值化 128 → 量化到项目 7 色 → 4 张全部 7 色、宽 294/268/201/232。新文件 `ui_logo_truck_[abcd]_20261008175431.png` + 各自 `.meta`（99 个 uuid 无重复），旧 4 张与全部草案已删。
- `LOGO_PATHS` 换新路径并逐图更新 `w`；顺手把 `DrawMenu` 的 zpix 回退字号由写死 104 改为按 `utf8.len` 反推（6 字写死 104 会溢出画布）。
- 验证：官方多人 build + 预览上传成功；LSP 0 Error（24 文件 1028 诊断）；`probe_logo` 日志 `pixel logo titles loaded=4/4` + 截图实图确认新字标清晰；`probe_render` 战斗冒烟 exit0、`overlay stage failed` 0 次、零 Lua/LoadChunk 错误。BUILD_VERSION/大厅 →0.13.51。
- ⚠️ 抗体：AB-205（更名=名+图两件事）、AB-206（字标草案必须透明底，生成后量 alpha0）、AB-207（字标是完整成品、宽度逐图记；回退字号按字数反推）。
## 车辆白色轮廓（2026-10-08，vehicle-outline 附记）
- 用户要求「为车辆加入白色轮廓」。用**翻面外壳**实现：`VehicleGeometry.GetMesh` 把车体全部六段三角面绕整车包围盒中心放大 `OUTLINE_SCALE=1.035` 后翻转绕序（顶点序 a,c,b、法线取反），作为第 7 个 section；默认背面剔除下只剩远侧壳，在车体外缘露出白边。几何随 `meshCache` 缓存，战斗与展台共用。
- 材质由两边各自提供：战斗 `Renderer3D.GetVehicleOutlineMaterial`（`vehicleOutlineMaterial_` 跨弹种共享、Shutdown 复位）、展台 `VehicleShowcase.state.outlineMaterial`（登记进 `state.materials` 随展台释放）。`VehicleGeometry.Build` 新增第 4 参 `outlineMaterial`，缺省不绑定第 7 段。
- ⚠️ 轮廓必须覆盖**全部六段**（含轮胎/金属/玻璃/灯具），只取主漆段会让轮胎/轮眉/后视镜穿出白边。⚠️ 绕中心放大时半径**不单调**，`fit` 必须取 `max(bodyRadius, outlineRadius)` 约束，否则轮廓挤掉车体 2% 碰撞余量（实测 obsidian 车体冲到 1.6736）。实测车体 ≤1.5883、轮廓 =1.6429 = PLANAR。
- 顶点量约翻倍（10956–19950 → 13200–39900），每车仍一个 CustomGeometry、7 段。验证：`probe_outline` 六车 ALL PASS（放大副本 err<1e-4、法线全反 minDot<-0.99、半径不越 PLANAR、退化三角 0）；展台六车实图白边完整；战斗冒烟六车重建+发射+暂停/恢复，Lua/overlay/LoadChunk/空顶点错误 0。LSP 0 Error、官方多人 build 与预览上传成功。主游戏离屏 FAIL 仍是本地既有噪音，手机性能与审美未验收。

## 巨型车范围冷却（2026-10-08，v0.13.42）
- 用户指定「巨型车的范围伤害加入内置cd1s」；`BALL_TYPES.giant.areaCooldown=1.0` 与实例 `giantAreaCooldown` 实现，实际圆域前置冷却，子步递减至 0。保留反弹武装，冷却期命中走普通碰撞，不以反弹或换敌机刷新冷却。
- 规则仍在 `Game.lua`，由联网/离线共同的客户端编排消费；服务端 IAP/钻石职责与配置不改。没有新增顶层 local、UI 冷却显示、存档或图片。展示版本与大厅同步 0.13.42。
- 最终专项 `probe_giant_cd` 36/36 案例、409 断言 PASS，源码 SHA256 与工作区相同，exit0/ERROR0。覆盖 0.99禁止/精确1秒归零及后续合法撞击、30/60/120Hz×三档速度、首次/同帧多击/跨敌机/普通伤害/独立双车/反弹/暂停升级与结束冻结/回收重开/圆域边界和升级范围。初版浮点尾数导致晚一帧已修：≤1e-9秒剩余归0；到期不会自动爆炸，本帧已普通命中的砖不重复圆域命中。最终真渲染真实开局→过intro→发射→暂停恢复 PASS、目标 Lua/overlay/load/空顶点0；Linux既有3D黑场与并发UI在途效果不计验收。最终官方多人build预览上传成功，LSP0 Error。
- POST-1/2 执行；POST-3 判定跳过：项目规则小调整，暂无新增跨项目偏好，不改初始已脏的随行记忆。并发 UI/VisualCatalog/settings 和 persona 的初始重排保留，提交仅含本人片段。

## UI 纹路再加密度 + 修 NanoVG 命令缓冲溢出（2026-10-08，ui-trace-density-2）
- 用户再次「无关紧要的纹路不够多」并点名两份 skill → 按规范 §3 补齐 8 种母题（新增 Halftone/ScanBand/Cross/TickRing/Ticks），并把落点密度大幅提高（Panel/Window/Background/Stage/Button + MetaUI 全部卡片 + 战斗 HUD/Dock/弹药槽/升级卡）。
- 🔴 真坑：**NanoVG 逐点绘制撑爆单帧命令缓冲 → 本帧后续绘制被静默丢弃**（无报错），症状「商店只剩背景、卡片文字全没」。修法：一批同色点**合并单一路径**（1 次 beginPath + N 次 circle + 1 次 fill），并按面积自适应放大步长（budget 600）。
- 定位法：像素取证（同帧 bright 计数 74904 vs 4372）+ 同帧 HEAD 对照 + 二分文件/函数/参数。
- 纪律：「渲染无报错」≠「画出来了」——加逐点绘制后必须像素取证或实图目视。
- 验证：LSP 0 Error（25 文件 1092 诊断）；五探针 exit0、目标错误 0；实图目视商店/首页/战斗 HUD/Dock/升级卡纹路可见且不压读数；官方多人 build 与预览上传成功。

## UI 装饰纹路加密（2026-10-08，ui-trace-density 附记）
- 用户「还是不够贵无关紧要的纹路不够多」——要的是**不承载信息的装饰线**（密度），不是新功能。
- 新增 6 个纯绘制原语（ui/PremiumSurface）：微网格 / 斜向拉丝 / 电路刻纹 / 四角取景折线 / 断线 / 点阵；全部自带 scissor 裁剪、低 alpha、按尺寸门槛。
- 落点：Panel / Window / Button / Background / Stage（改共享原语即全屏生效）+ MetaUI 新增本地 CardTrace 接到福利卡/商店卡/任务行/图鉴卡/排行行；转盘加虚线环+点阵环。
- 只画不参与命中与几何；不改玩法/价格/广告/IAP；版本号归并发会话。
- 验证：LSP 0 Error（24 文件 1072 诊断）；probe_home/probe_shop/probe_windows exit0、目标错误 0；实图目视纹路可见不糊字；官方多人 build 与预览上传成功。

## 提消费欲望：付费路径转暖金（2026-10-08，v0.13.53）
- 用户「还是不够贵！太冷酷消失消费欲望！」——反馈升级：不只是不够贵，而是缺温度。参考图全屏冷色，唯一暖色是金色按钮；而首页唯一的暖色（钻石商店）恰恰被画得最平。
- 付费入口：首页钻石商店改 D.button + 常驻暖金辉光（不再只悬停才亮）。
- 贵金属配方：Surface.Button 对金色系（R>200,G>140,B<130）用暖白高光 (255,232,168)、暗端保留金色、常驻辉光更强；冷色按钮配方不变。
- 商店整条路径转暖：分页标签/浏览卡/购买区改金色系（选中金边金标金下划线），未选中仍中性灰，不做全屏泛金。
- 只改 MetaUI + ui/PremiumSurface；无删除、无新资源/字体/context/RT。展示版本归并发会话。
- 验证：LSP 0 Error（24 文件 1029 诊断）；首页/商店/升级卡/战斗/九窗口探针 exit0、目标错误 0；商店实图目视暖色比例明显上升；官方多人 build 与预览上传成功。

## 修黑边黑字与黑框（2026-10-08，v0.13.50）
- 用户「检查游戏里所有黑框黑文字的给我改了」+「黑边黑字也算」。
- 黑边黑字真凶：DrawPixelText 的描边无条件用近黑 C.ink，而大量文字本身是 C.ink（青/绿/金按钮上的字）→ 暗字被黑描边裹住。修法：按亮度选描边，lum>=120 才画深描边，暗字不描（该函数是 MetaUI/天赋树/选关所有 D.text 的注入源，一处修全屏生效）。
- 黑框真凶：未拥有/未解锁/不可用态用 C.widget(22,36,56) 作边框压在同色系 C.card(16,26,44) 上 → 几乎同色＝黑框。改成可见中灰 {dim,130}（图鉴未拥有卡/战斗档案未解锁里程碑/钻石商店不可负担行）；已拥有/可领取态仍青色系。
- 天赋树浮窗补内受光/内沉影/顶亮线（只加不减）；天赋树本体是圆形卡树，无「行」概念，不套分区标题。
- 只改 Scene3DBackend/MetaUI/ui/RechargeShop/ui/TalentTree；无删除、无新资源/字体/context/RT。
- 验证：LSP 0 Error（24 文件 1027 诊断）；天赋树/商店/首页/升级卡/战斗/九窗口探针 exit0、目标错误 0；官方多人 build 与预览上传成功。展示版本由并发会话统一推进。

## UI 纯加法调配：四个面板（2026-10-08，v0.13.46）
- 承接 v0.13.45「已有贵的部分要保留」：本轮**只新增**，不重写既有绘制、不调低任何既有 alpha/层数/渐变。
- 补分区标题：每日任务→「今日任务」、幸运转盘→「转盘奖池」（青色，与主菜单/商店/战斗档案同一套竖条 + 淡出断线）。
- 补厚度：图鉴卡片、排行榜行与页脚条、转盘中奖条统一补「内顶受光 + 内底沉影 + 顶边亮线」（与 v0.13.42 给商店浏览卡的同一套语言）。
- ⚠️ 列表行下移必须同步两处：DrawTasks 与 HitTestTasks 各有一份 y 起点，加标题时两处一起 +22px，否则「看得见点不到」。
- 只改 MetaUI（+30/-3）；无删除、无新资源/字体/context/RT。展示版本由并发会话统一推进（本批未动 BUILD_VERSION）。
- 验证：LSP 0 Error；任务/图鉴/排行/转盘 + 首页/商店/升级卡/战斗/九窗口真渲染探针 exit0、目标错误 0；四面板实图内部目视确认；官方多人 build 与预览上传成功。

## 按 skill 调配其余面板（2026-10-08，v0.13.45）
- 用户「对，但是已有的贵的部分要保留，别给我删了！」——本轮**纯加法**：不重写既有绘制函数体、不调低任何既有 alpha/层数/渐变，多层受光/漆面/描边/背景扫光/展台光场/文字描边全部原样保留。
- 战斗档案补分区标题：新增 SectionHeader「里程碑奖励」（青色＝免费产出语义）；GetPassRewardRect y 174→196 让位（该函数是绘制与 HitTestPass 共同来源，改一处两处同步）。
- 措辞继续去直白：商店 购买样式→解锁样式、购买车型→解锁车型；HitTestShop action 串不动。
- 验证：LSP 0 Error（24 文件 1017 诊断）；五个真渲染探针 exit0、目标错误 0；战斗档案实图目视确认标题不重叠、既有质感完整；官方多人 build 与预览上传成功；展示版本 →0.13.45。手机 FPS / 全 DPR / 联网支付 / 用户审美未验收。

## 变现措辞去直白化（2026-10-08，v0.13.44）
- 用户原话「别把充值写的那么明面，而是钻石商店等。之后根据 skill 调配各种 UI」。玩家侧不再出现直白「充值/购买」，统一游戏内商店表述；并按 dark-tech 规范补商店分区标题。
- 措辞：主菜单钱包金按钮 充值→钻石商店（宽 96→104、字号 16→15、图标 premium_energy_core→gem）；首充按钮「¥N 立即购买」→「¥N 立即获取」；礼包按钮 购买→获取。面板标题/分区/兑换/签到原本已是游戏内表述，不动。
- 分区标题：RechargeShop 加本地 SectionHeader（金色竖条 + 向右淡出断线，付费语义），替换两行裸金色小字；用 D.measure 实测标题宽后再起断线。
- ⚠️ 只改玩家可见文案与绘制：HitTest action 串（buy/spend/buy_first_gift/signin）与 Shared 的 sku/价格/发货全不动；命中几何除钱包按钮宽度外不变。无新资源/字体/context。
- 验证：LSP 0 Error（24 文件 1017 诊断）；五个真渲染探针 exit0、目标错误 0；首页与钻石商店实图目视确认措辞与金色分区标题；官方多人 build 与预览上传成功；展示版本 →0.13.44。手机 FPS / 全 DPR / 联网支付 / 用户审美未验收。

## 第四轮加贵与清晰度（2026-10-08，v0.13.43）
- 用户原话「还想要更贵并且更清晰更好看」+ 再次点名 dark-tech / 0718 两份规范。前几轮都在加「层次」（柔光/厚度/交互），本轮补的是规范里一直被漏掉的**清晰度**与**漆面**。
- 文字描边（规范 §8）：`DrawPixelText` 加可选第 7 参 `outlined`，缺省 `size>=17` 自动描边，用**四方向偏移同字绘制**（非 nvgStrokeText），描边取 `C.ink` 且 alpha 跟随字色；`<12px` 不描边。此前全项目文字零描边，是「不清晰」的最大单一来源。全部既有调用点零改动。
- 玻璃漆面（更贵）：Panel 上半区斜向极淡高光（普通 12 / 强调 20）、Button 同款（26+glow×26），`nvgIntersectScissor` 裁在圆角内；与内顶受光（竖直）、内底沉影（底部）构成三层。
- 侧栏胶囊（更好看，规范 §4）：Background 侧轨每 92px 一枚 4×11 胶囊 + 短横线（cyanDim 130/90），与 46px 刻度错开。
- 只改 `Scene3DBackend`（DrawPixelText + 版本）、`ui/PremiumSurface`（Panel/Button/Background）、`lobby_runtime` 版本；无新资源/字体/context/RT，不改玩法/价格/车辆几何/广告/IAP/输入命中/投影。
- 验证：LSP 0 Error（24 文件 1015 诊断）；五个真渲染探针 exit0、目标 overlay/Lua/LoadChunk/空顶点/断言错误 0；首页/商店/升级卡实图目视确认描边清晰 + 漆面高光 + 侧栏胶囊；官方多人 build 与预览上传成功；展示版本 →0.13.43。手机 FPS / 全 DPR / 联网支付 / 用户审美未验收。

## UI 再度加贵与找回层次（2026-10-08，v0.13.42 UI 批次）
- 用户原话「还不够贵，加和找回更多东西」——第三次质感反馈。前几轮（0.13.30 柔光 / 0.13.31 交互动效 / 0.13.40 恢复）都在「单层金属面」上加装饰，本轮改为**加层次密度**：共享原语 `PremiumSurface` 的面板/按钮/窗口/背景/展台全部加厚。
- 小卡片补厚度（MetaUI）：菜单福利/收藏卡、商店分页标签、商店浏览卡、任务行、天赋入口大卡统一补「内顶受光 + 内底沉影 + 顶边亮线 + 左识别标记」；分区标题竖标加呼吸辉光。全部用现有 `D.rect`/`nvgRadialGradient`，无新原语、无新资源、无新字体/context。
- 验证：LSP 0 Error（24 文件 1008 诊断）；五个真渲染探针（首页 / 商店 / 九窗口+暂停 / 战斗压力 / 最坏升级卡）exit0、零 overlay/Lua/LoadChunk/空顶点/断言错误，首页与商店实图内部目视层次恢复；官方多人 build 与预览上传成功。版本行归并发会话（巨型车 CD），本批不抢 42。
- 边界：手机 FPS、全 DPR、真实联网支付、用户审美均未验收；Linux 既有 HDR/缺图/无体素致战斗中央 3D 黑场，不计通过。

## 效果保全与同风格增强（2026-10-08，v0.13.40）
- 用户原话「还有更多的大贵效果被你删了。。。」；找回风格不等于减掉厚度/柔光/受光/动态，v0.13.39减法未获认可。按真实提交diff审计：39削弱Panel/Button/Background/Stage及CTA；分区呼吸更早已去除，本轮是重新加入，不能把螺钉/独立窗口外光等更早删除项都误报为39所删。
- PremiumSurface集中恢复工艺与两种扫描，MetaUI重新接分区呼吸/流动与控件受光，Backend主CTA避免重复扫光；只改四Lua本人区域和版本。无新图片/font/context/RT/Scene；共享时钟、矩形交集裁剪内缩避圆角、椭圆影几何与paint同变换、32/48/96/180宽按钮实际Draw。Zpix测绘、NEAREST限色图标、文字完整分行与输入/资源安全不回退。
- 十份有效隔离最终日志目标Lua/overlay/load/空顶点/断言0，九窗口/暂停/金色解锁、长字、最坏卡、输入所有权、Init/Stop-Start、六车门控隐藏停更30Hz及开局发射通过；首轮两超时独立保留并补测成功。A/B相位0.8/2.3，原图2040×1080按CONTAIN换算ROI3671像素变化，首次缩略图ROI=0已纠正。最后窗口金色解锁实图已目视。
- 最终workspace LSP24文件0 Error/875 Warning/107 Hint与官方多人build上传；当前并发快照串行首页/九窗口+暂停+金色解锁/intro后发射三项补测exit0、目标错误0，首页/解锁实图目视。另有拖尾商店/存档/Renderer3D并发批次，十份独立验收与合并冒烟不扩大为其功能通过，按hunk提交不覆盖。POST三步执行；手机FPS/全DPR/真实联网支付/审美以及Linux HDR故障下战斗3D可见性未通过。

## 风格身份恢复（2026-10-07，v0.13.39；后续纠正效果减法）
- 用户原话「没有自己的风格会变得更便宜了」，指定dark-tech-game-editor-ui与0718-pixelimage-aigc；实际读取已安装同名规范，用户给的docs路径不存在，不伪造读取。v0.13.38仍保留五轮历史，但不能当审美通过。
- PremiumSurface改Zpix、细框分层、断线标题/折角/刻度；背景不用写实图片/玻璃投影/外发光，首页商店用程序化支架展台，动效收在侧轨与按钮底边。首页卡各有边界，天赋入口主按钮；BattleHUD只换字体、保组件树与规则。独立审查发现旧模态全窗半调进入正文后已删除。可读性FitText饱和/完整分行、输入所有权、资源生命周期与真实车辆均保留，不整套回滚。
- 资产审计同时查颜色数量和精确色板：解锁图RGBA10色，另五张虽颜色数合格但有亮青漂色，合计40像素映射到项目青；全部38图标32×32/二值alpha/固定八色+透明，轮廓/uuid不变。字标用独立既有色板，不盲套图标规则。两张旧环境仍留assets但不再被运行时加载，不能说减包体已完成。
- 最终LSP24文件0 Error/845 Warning/105 Hint，官方多人build+上传；12份真渲染日志Lua/overlay/load/空顶点/探针断言0。首页/商店/九元层与暂停、最坏升级卡、金色双行按钮、钱包19位90/81px≤125/137与Shop完整数字209≤240、输入多指/鼠标/失焦/禁用/首页命中、direct Init/Stop-Start、六车门控/隐藏停更/30Hz通过。战斗长数字/库存道具/首领阶段2实图内部目视，intro后真发射PASS。横屏letterbox中央9:16实图不等于手机DPR矩阵；既有Linux HDR/缺图/无体素使战斗3D黑场，不声称手机FPS/真实支付/审美通过。
- POST-1/2/3执行，随行补身份优先偏好与AB-189/190；保留并发settings/VisualCatalog/记忆重排，不代提交。Game/后端仍大文件，行首local名字各197仅文本统计，实际运行无LoadChunk失败；旧脚本误计函数参数的269不能当超限结论。

## 五轮界面升级（2026-10-07，v0.13.38；后续用户指出风格流失，未获审美通过）
- 用户要求助手自行检索生成并连续五次对照实现；首轮保留并发33，后四轮35/36/37/38，五轮各有实际修改/官方build/实图，不虚构34包。三张生成图中两张无车环境落地，方向图只借构图不打包，实际展台继续真实车辆。
- PremiumSurface统一字体/表面/按钮/环境；测绘face同源、最低字号饱和返回fits。钱包极长余额两行不丢数位；环境cover+scissor不拉伸、首页不双叠背景；可选图片在宿主context删除前清理。
- 最终独立输入/购买装备门控/礼包限次/六车型/30Hz/隐藏停更/Init与Stop-Start/缺图/横屏/长卡/九元层面板与暂停渲染通过，LSP0 Error、多人build预览成功；19位钱包分段实宽87/79px，Shop完整串234≤240px。一次Update内测字预设失败已用绘制期复测替代，不能计入有效PASS。手机帧率、真实支付及审美没有用户确认。
- POST-1/2执行；POST-3执行自主参考偏好和AB-186~188通用测绘/环境/饱和兜底抗体。车辆结构与BattleHUD独立提交，保留并发文件与记忆。

## 车辆附记（2026-10-07，vehicle-refine，不改并发展示版本）
- 指定车辆规范落地到现有六车型共用VehicleGeometry；连续倒角壳、同壳斜面玻璃、开放轮眉/轮洞、完整胎肩轮圈立体辐条、轴臂与各装饰支脚。默认重卡/装甲六轮、其余四轮，单网格六材质保持；不改技能/价格/权益/输入/世界缩放。
- 等比fit并重算法线，局部XY半径≤1.84/1.12保留最终2%碰撞余量；单车型不可变CPU几何缓存，换key覆盖，Clear后重绑材质。二次实图定位并修机盖遮窗、踏板穿胎、沙地车轮眉与风挡连接。
- 冻结30张固定五角度实图均已日志核验/内部目视、六section与材质非空；纯几何六车法线/绕序/半径PASS、退化0（10956～19950顶点）；六车展台正式190帧25853断言全PASS、Lua/resource/engine0，覆盖全±15°取景、释放重建后实Draw、隐藏120次不更新及60/120/240/600Hz输入各秒30次QueueUpdate。单文件及最终workspace LSP 0 Error有Warning，官方多人build上传成功。主游戏冒烟Lua/overlay0、实际一次发射/六车型重建/暂停恢复，整体报告仍FAIL（本地引擎缺图/体素模块/HDR shader及尖峰）；不宣称手机性能、网络支付或审美通过。
- POST-1短段与真实用户观察执行；POST-2仅车辆文件与本人记忆，保留并发UI/settings/VisualCatalog；POST-3补两条跨项目结构抗体，既有preferences不变（没有新跨项目偏好）。

## 战斗界面独立批次（2026-10-07，v0.13.33-battle）
- 用户要求「优化战斗界面精致度科技感」；仪表舱方向为助手实现，审美仍待用户验收。展示版本不抢并发商业化会话的0.13.38。
- 新 `ui/BattleHUD` 用UI.Label/ProgressBar与官方RenderWidgetSubtree嵌入宿主帧，复用绝对设计坐标树，宿主先销毁自有树再删共享ctx；三分区HUD、两组四槽、预告扫描、道具明暗和首领阶段，规则零改动，暂停/道具命中同源未动。
- 内部真渲染普通/长数值/已用道具/首领阶段2，提示与预告避让；intro后真实发射PASS，独立HP保持/追平/得分复位PASS；LSP0、官方多人build+预览成功。独立提交验证宿主与MetaUI应配同一HEAD，不能混入并发新增environment依赖的UI。Linux BloomHDR黑场不作为3D验收，手机性能/审美未宣称通过。
- 真实输入/生命周期176断言174PASS/2FAIL；失败为探针误期望暂停松手（既有按下即paused），不属新回归。实际暂停→继续、TouchID0/多指/混合鼠标/失焦/库存道具、开关/live Init/Shutdown-Init/Stop-Start均PASS，4树43控件不累积，Lua/overlay/LoadChunk/空顶点0，广告SDK尝试0。尚未覆盖DPR全矩阵及首领1/3阶段截图。
- POST-1/2执行；POST-3仅通用UI混合渲染和HUD边界抗体执行，随行persona/preferences因无新跨项目偏好跳过。BattleHUD已从大后端抽出，但后端仍超1500行，全面重构另行处理，不借本轮改规则。

## 本轮变更（2026-10-07，v0.13.33）
- 用户反馈「天赋树价格成长过低」，追加「每两级之间至少是倍数增长」；按相邻阶至少×2执行，具体200/500/1200/2500/5000/10000/20000为助手拟值而非用户指定数字。
- 仅改STAGE_COST及首页/大厅展示版本，42节点报价、余额差额、CanUnlock及实际扣费同源。单线39400；扣两个自动首阶节点后全树236000；已买节点不补扣，所有非价格属性不变。
- 隔离1315断言PASS（价格/倍增/非价格属性/余额边界/扣费保存/重复购买/报价差额/按钮命中/旧档与自动补齐）；真实第7阶截图六个20000胶囊及解锁20000按钮完整，无Lua/overlay错误。LSP0 Error、官方多人build+预览成功；headless初始化退出139后改graphicssurfaceless通过。手机长期经济节奏待验，不能按理论机数声称刷几局买满。
- POST-1简记执行、POST-2版本与Git持久化执行；POST-3判定跳过：小型项目调参，无新增跨项目信息。并发商业化UI、BattleHUD和车辆几何不属于此提交。

## 上轮变更（2026-10-07，v0.13.32）
- 用户继续否决「不够贵」；此次改首页/商店信息结构和商品展示，不能把上一轮像素取证当审美达标。
- 新增独立 `ui/VehicleShowcase.lua`；修运行时Forward资源前缀、bbox方法，RT上下方向用实图核验。
- `MetaUI.Update` 由 `Backend.UpdateScene` 在3D绘制前推进；`Shutdown` 在 `nvgDelete` 前释放展台包装。
- 浏览只改展示index，真实触摸选择六车型不扣零件、不改装备；购买/装备与广告仍经旧业务校验。
- 已跑并通过：六车型真实正向图/全摆动取景/购买门控/隐藏停更/30Hz；实际TouchID=0、画布外第二指抬起、混合鼠标、右键Up、失焦/渐灭/禁用/首页命中；暂停页真实反馈、直接Backend.Init和Stop/Start释放重建；最坏升级卡340高与完整折行。最终workspace LSP 0 Error、官方多人构建及预览上传成功。首页/商店/六车实图已内部目视检查，手机性能与用户审美仍待Preview验收。

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
| `scripts/Game.lua` | 引擎无关的权威规则、碰撞、波次、关卡状态（stage/stageWave/stagewin 评级）、输入动作、领域事件与游戏快照 |
| `scripts/StageCatalog.lua` | 关卡编排纯数据：十波一关、3/6/8 精英 + 10 Boss 槽位、逐关编队量/血量/间隔/召唤上限、15 关总数与波号↔关号换算（不含任何引擎/渲染 API） |
| `scripts/ui/StageSelect.lua` | 选关界面（15 关铺格、星级/锁定态、点已解锁格 play_stage），插件式注册进 MetaUI，复用注入令牌，只画与命中 |
| `scripts/TalentCatalog.lua` | 天赋树纯数据：6 线路（2 通用 + 4 车）× 7 阶段、星级门槛 0/3/9/18/27/36/45、前置链、节点类型与 `CanUnlock` 校验（不含引擎/渲染 API） |
| `scripts/ui/TalentTree.lua` | 天赋树界面（6×7 网格、已解锁/可买/未开放三态、点格解锁），插件式注册进 MetaUI，只画与命中 |
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
- v0.13.50（**每关第一个飞船固定 1 血**）：用户「每关第一个飞船必须是 1 血」。①`Game.SpawnNextNormalEnemy` 本关首架强制 hp=1（用 `pendingSpawn.firstDone` 标记，不用「场上无敌机」判定——否则首机被打掉后第二架会误判）；②`StageCatalog.BeginStage` 精英波位池由 1–9 收窄为 **2–9**（否则精英可能落第 1 波、开局撞精英）。验证：LSP 0 Error、`probe_first`（关1/5/12 首机 HP=1、第二架 2/4/7、精英 180 组 0 次落第1波）、真渲染冒烟零错误、多人 build+预览。教训→AB-204。
- v0.13.49（**整体抬高敌怪难度曲线**，订正 0.13.48 削玩家方向）：用户订正「不对你应该整体提高地怪难度曲线来实现平衡」→ 撤销玩家侧改动（BASE_HP 回 100、damageStep 回 320），改为抬敌方四条轴：①砖块 HP `2+floor((stage-1)/2)`（关1 1→2、关15 5→9）②基准速度 34/1.8（关1 28→34、关13 46→56）③精英护航 `min(3,1+floor(progress/2))`（关1 起 1 架）④Boss 召唤 `min(5,2+floor(progress/3))` + 间隔 `max(6,10-progress*0.3)`（关1 2架/10s、关13 5架/6s）。⚠️ 普通波数量刻意不变（用户 v0.13.26 要求低数量），玩家侧全还原。验证：LSP 0 Error、`probe_curve` 实测新曲线且玩家基地 100 不变、真渲染冒烟零错误、多人 build+预览。教训→AB-203。
- v0.13.48（**前期我方数值过高——收敛基地生命与加速车增伤**）：用户「前期我方数值过高啊」。根因：`BASE_HP=100` 而关1 越线每行仅 1 伤 → 前几关几乎不可败；开局加速车 `damageStep=320` 无上限分档增伤，关1 敌机 HP=1、初速 660 已秒杀且反弹 8 次即到 2 伤。改动：`BASE_HP` 100→80、`BALL_TYPES.speed.damageStep` 320→480（初速仍 1 伤、约 1140 才 +1、反弹 16 次才到 2 伤）。⚠️ 未加回速度/伤害上限（保留 v0.13.22/0.13.23 的无限增长+软性递减契约），也未动用户指定的加速车开局。验证：LSP 0 Error、`probe_early`（关1 HP=1/初速伤害1/反弹16次到2伤/基地80）、真渲染冒烟零错误、多人 build+预览。教训→AB-202。
- v0.13.47（**减少关卡同质化：每关随机布局 + 关卡特性**）：用户「减少各关卡之间的同质化，一部分东西我希望局内随机」（并明确「不要问我细节自己做好」）。根因：`ELITE_SLOTS={[3],[6],[8]}` 写死波位 + `GetSpecialKey`/`PickFormation` 确定性取模循环 → 每关都是 3/6/8 精英、机型阵型同一条轮转带。做法：`StageCatalog` 新增 `BeginStage(stage,seed)` + 自持 LCG `MakeRng` + `currentLayout`；每次进关重掷①精英波位（1–9 随机抽 3）②精英/Boss 机型③关卡特性（标准×2/急行 intervalMul0.82/密集 spawnMul0.82/增援 waveAdd+1）④副标题。`Game.ResetGame` 设好 stage 后调 `BeginStage(startStage, os.time())`（选关/下一关/再战/重开四入口都覆盖）；`GetKind` 补 stage 实参；快照加 `s.stageSubtitle`，横幅硬编码文案改读它。硬约束：第 10 波恒 Boss（胜负判定绑定），只随机机型。随机逻辑放独立模块以避开 Game.lua 197/200 顶层 local 上限。验证：多人 build+预览、LSP 0 Error、`probe_layout` 全绿（同种子可复现/12 种子 12 种布局/恒 3 精英/第10波恒 boss/三特性数值生效）、真渲染冒烟零错误且日志实锤同关两次进入布局不同。教训→AB-201。
- v0.13.27（**修恶性回归：逐架生成的敌机全叠在正中**）：用户报「飞机全都生成在正中」——v0.13.26 改逐架生成时 `SpawnNextNormalEnemy` 每架写死 `x = DW*0.5 - shipW*0.5`，而横向铺开的 `ComputeFormationSlots` 同批被当死代码删了 → 整波叠在一条竖线。修法：`SpawnNextNormalEnemy` 加**确定性横向分道**（5 条车道，`lane = pendingSpawn.lane % 5`，x 按 `shipW` 自适应；`pendingSpawn` 加 `lane` 字段；每波 `lane = (wave-1)%5` 起始错开；ResetGame 归零；车道数用函数内局部量不占顶层 local）。验证：多人 build+预览、LSP 0、真渲染探针零错误、`probe_lane` 唯一 x 位置 5→7 个（20/114/188/316/376/415，不再全居中）、`probe_gap` 1 格间距未破（关1 120.85/关12 14.60）。教训→AB-170：删/换生成路径前先列旧函数负责的每个维度（x 分布/y 错峰/阵型）逐条确认新路径有等价实现。
- v0.13.26（出怪梯度重做：数量起点 1 架 + 同波逐架飞出 + 波间隔逐关收紧 + 预告写明远方生成）：用户三点要求——①普通波起点「比 2 更低」且「允许不到 12」；②「出怪间隔维度」= 同波内**一架接一架飞出**，关1 间隔最长、逐关收紧，任意两架初始≥1 格；③「出怪下方提示的怪不会立刻抵达屏幕，请写明在远方生成」。改动：`GetNormalCount` 起点 2→1（关1 1/1/2/2/3/3、关7 4/4/5/5/6/6、关15 9/9/10/10/11/11，不触 12）；`GetInterval` **方向反转**（旧版随关卡变长 15.5→25.1s 是反的 → 关1 22s 最长、每关 -0.9s、下限 7s）；新增 `GetSpawnInterval`（2.8s→1.12s）；护航改前 3 关 0。`Game.lua` 加 `pendingSpawn` 状态表 + `SpawnNextNormalEnemy`/`ReleaseEscortVolley`（逐架放出、隔 1 格、满场/无空位则推迟绝不叠放），**删除** `SpawnEliteEscorts`/`ComputeFormationSlots`/`LiftSlotsOffExisting` 死代码；`FleetPositionOccupied` 加 `gap` 参数；Boss 改「有人在位就从更远方生成」。`DrawNextWavePreview` 加「自远方飞入」一行。验证：多人 build+预览、LSP 0 Error、真渲染探针零错误、`probe_gap` 实测生成时刻最小间距关1 120.85/关12 14.60（均≥一格）。⚠️ 运行时抓到 AB-169：加 7 个顶层 local 超 Lua 200 上限 → LoadChunk failed（LSP/build 都查不到）；间隔下限须按最慢机型（×0.66）估算。
- v0.13.25（尾迹不可见**真根因**：`CustomGeometry:Clear()` 清空材质槽）：用户「特效不可见」。几何已验证提交（54 顶点）、节点已启用 → 探针扩到读材质，一击命中 `enabled=true numVert=54 mat=false`（有顶点无材质）。根因：`Clear()` 连材质槽一起清空，尾迹只在 Init 绑过一次、重建后从不重设；**敌机可见正因为每次 Clear 后都重设 SetMaterial**。修复：Commit 后重绑材质。⚠️ 此前 SetDynamic/CULL_NONE/法线/自发光各层都对，材质在 Clear 时就丢了 → 单层验证看不到。验证：复测 mat=true、零 Lua 错误、LSP 0、前向引用 0、build+预览上传。教训→AB-168。\n
- v0.13.24（关卡号数字贴图 + 进关过渡/准备动画）：用户两点要求——「让 ai 生成各个数字的贴图用于选关界面的数字显示替代」「进入关卡的过渡和准备动画你也没做」。①**数字贴图**：nanobanana 生成 0–9 → bbox 裁切 → **按高度归一**（同高 26，防高低不齐）→ alpha 二值化 → 量化「白+轮廓」两色 → 24×32 母版 → `ui_digit_{0..9}.png`；新增 `scripts/ui/DigitFont.lua`（懒加载 + `nvgImagePatternTinted` 染色 + 逐字宽度表 + 缺图回退字体），StageSelect 节点数字改走贴图。②**进关过渡**：`Game` 加 `INTRO_SECONDS=3`/`introTimer`，`StartGameAt` 不立刻刷怪、`Update` 在 intro 期冻结玩法并 return，归零才 SpawnWave；新增 `scripts/ui/StageIntro.lua`（暗化遮罩 + 中央面板 + 大号关卡号贴图 + 倒计时条 + 跳秒 + 扫描带），Scene3DBackend 在 HUD/Dock 之后按 `introTimer>0` 调它；删原 `stage_started` 横幅。两处取舍：**不新增 gameState**（用标志位冻结，免动所有 state 分支）、**不加模块级 local**（Scene3DBackend 已 193/200，新功能各成模块）。验证：多人 build+预览、LSP 四文件 0 Error、前向引用 0、真渲染探针（intro 界面 + 选关数字贴图）零 overlay 错误。⚠️ 待 Preview：3s 时长手感、数字贴图真机清晰度。
- v0.13.23b（加速车软性递减）：用户要求「小幅衰减」（承接 v0.13.22 去掉速度上限）。实现：`BALL_TYPES.speed` 加 `speedBoostFloor = 1.012`（下限，恒 >1 → 永远在涨）与 `speedSoftCap = 1400`；`BoostSpeedMarble` 按**从初速起算**的线性插值算倍率 `t = clamp((speed-660)/(1400-660))`、`boost = 1.06 + (1.012-1.06)*t`。⚠️ 必须从初速起算——首版用 `speed/softCap` 让初速 660 就吃一半衰减、前期变钝，已修。曲线：660→×1.06 / 1000→×1.038 / 1200→×1.025 / ≥1400→恒 ×1.012。验证：`probe_soft` 实测最高 **1762**（>softCap 1400，证明无硬上限）对比无衰减版 1912 明显压住；build+预览上传。⚠️ 软性递减 ≠ 硬上限：下限必须严格 >1，否则等于偷偷加上限。提交 162799c。
- v0.13.23（尾迹不可见真因：背面剔除 + 无光照）：用户「现在什么拖尾也没有啊」。几何已验证提交（90 顶点、AABB 在视锥内）→ 光栅化问题：①三角带法线朝 +Z 而相机在 -Z → 整条被背面剔除（voxelMaterial_ 无 SetCullMode）→ 改用独立材质 + CULL_NONE；②法线水平 `(0,0,-1)` 而光来自上方 → N·L≈0 全黑 → 法线朝上 + 常驻自发光 0.15（深空场景保底，不冲淡配色与头亮尾暗）。验证：72–90 顶点提交、零 Lua 错误、LSP 0、前向引用 0、build+预览上传。⚠️ 本环境离屏 3D 恒黑，可见性待 Preview。教训→AB-162。\n- v0.13.22b（加速车去上限 + 速度卡改「加速度」）：用户「加速车没有速度上限，相关改为加速度词条加成」，澄清为「原先的加上限词条改为加加速度」+「速度分档，无限增长」。①删 `BALL_TYPES.speed.maxSpeed=900`——每次反弹/命中 ×speedBoost(1.06) 无限加速；②删 `maxDamage=2`——伤害按 damageStep(320) 分档**无限增长**；③`speedMul` 语义由「最高速度倍率」改为「**加速度加成**」（`BoostSpeedMarble` 用 `gain = speedBoost + (speedMul-1)*0.1`，不再参与上限计算）；④三张速度卡与天赋 `BALL_STAT.speed.label` 文案「极速/最高速度」→「**加速度**」。验证：`probe_nocap` 实测速度 **1241**>原 900；`probe_dmg` 实测伤害档 **4**>原 2；build+预览上传。⚠️ 待真机确认越打越快的手感与后期是否失控。提交 0a38041。
- v0.13.23c: 普通波梯度二次下调并按普通波序号校准：最终关1 2/2/3/3/4/4，关7 5/5/6/6/7/7，关15 10/10/11/11/12/12，第15关后段触及12架上限。中间试过首关3/4/5，复核后因“第一关还是太多”整体再减1。精英护航/ Boss 召唤缓慢成长；HP、速度、间隔不变。代码提交 ccc4f69，展示号并入 v0.13.24 并发版本。
- v0.13.22（尾迹 = 真 3D 几何光带 + 车尾锚定）：用户纠正「要复刻后一种（光带）但你做成了 2d」+「要跟随车尾而不是体积中心」。billboard 是 2D 面向相机精灵 → 改 CustomGeometry 三角带，材质走敌机箱体同一条已验证可见路径（DiffVCol+白底+顶点色）；半宽头 0.30→尾 0.012、顶点色头亮尾暗；头部采样点沿 -朝向 退 1.75×GetVehicleScale 锚到车尾。🔴 历史 ribbon 不可见真因：v0.13.10 每帧重建但从未 SetDynamic(true)（顶点缓冲不可改）→ 每帧重建几何必须 Dynamic。验证：顶点数取证 78 顶点(13段)真实提交、零 Lua 错误；LSP 0、前向引用 0、build+预览上传。⚠️ 探针开局须用 Game.StartStageAt(1)（v0.13.4 起菜单 PointerDown 不再开局），否则 state 恒 menu = 无效验证；⚠️ 别给函数挂字段做诊断。\n- v0.13.21b（词条卡归入通用卡 + 卡池分类审计）：用户点名「加速车分裂的专属词条还是天赋树没解锁就在局内被允许出现了」「合着这几个还有寒冰车的词条都不是天赋树规定的专属天赋卡范畴？给我优化管理！」。探针复现：无天赋时 `word_pierce/word_chain/word_momentum` 三张词条卡**都在池里**——根因是词条卡既无 `ballType`（非车型卡）也无 `requiresCard`（非通用卡），**两套门控都没覆盖它**。按用户裁定归入**「通用卡（无车型）」**：①三张词条卡各加 `requiresCard`；②`TalentCatalog` 通用卡线 `general_b` 扩为 1阶=xp、2阶=贯穿、3阶=ammo、4阶=连锁、5阶=动量（6/7 阶仍结算零件 +5%）；③`ICON_BY_CARD` 补词条卡→`talent_word`。**卡池分类最终定版 5 类**（通用常驻 / 通用需天赋 / 车型基础 / 车型专属 / 解锁车卡），新增卡必须归类。验证：`probe_wordgate` PASS（无天赋无词条卡 / 解锁 general_b_2/4/5 后三张进池 / 节点存在且 kind=cardUnlock）；`audit.py` 全池审计 0 张漏门控；build+预览上传。提交 2216994。
- v0.13.21（尾迹回归 3D BillboardSet）：用户「还是没跟上，但是最开始的圆形的完全可以跟随啊」——根因是**通道**：最早的软圆 billboard 版画在 3D 场景、与车共用相机投影（永不脱节），v0.13.12 overlay 与 v0.13.19b 修补都用手工屏幕投影才反复错位。修法：Renderer3D 回归 3D BillboardSet（每弹种一批、颜色烘焙软圆+DiffAlpha），采样密集重叠（0.022s/0.22s/10点）+头尾强收束消除珠子感，z 再远 0.10m 使尾迹落在车体之后；删除 overlay 尾迹全套（Presentation.UpdateVehicleTrails/vehicleTrails + Scene3DBackend.DrawVehicleTrails/ProjectTrailPoint/深度标定，Backend 槽位 198→193）。验证：真渲染发射冒烟零错误、trail ready 日志；LSP 三文件 0 Error、前向引用 0、build+预览上传、BUILD_VERSION/大厅→0.13.21。教训→AB-158。
- v0.13.20（天赋车解锁语义订正）：用户第三次澄清「解锁车辆天赋树！=局内开局解锁车辆，应该=只有解锁车辆才会有局内解锁此车的解锁天赋卡。无论天赋树如何，开局自带的都是加速车」。改动：①`Game.ResetGame` 删除「把 `talentUnlockedBalls` 并入 `unlockedBalls`」——开局恒为 `{speed=true}`；②`CanOfferUpgrade` 为 `unlock_*` 卡加门控「该车已在天赋树解锁」才进池。最终三层语义：天赋解锁车 → 局内出现**解锁卡**；选中解锁卡 → 该车**本局**入队；天赋解锁专属卡节点 → 专属卡进池；未在天赋解锁的车，局内既不出解锁卡也不出 base/专属卡。验证：`probe_talentball` PASS（开局恒 speed / 天赋解锁 ice → 出现 unlock_ice 但 ice 未预先解锁 / 未解锁车无解锁卡 / unlock_speed 永不出现）；build+预览上传。提交 dfbde86。
- v0.13.19b（尾迹二次打回真修复）：用户再报「和车分离且图层比车还高」→ v0.13.15b 读错根因。量化：①回缩被 `min(radius*1.15, 采样间隙*0.5)` 钳到 ~2.75px（车半长 23px），头没挪出去；②头全宽 29px≈2 倍车宽且 overlay 压 3D。修法：头沿速度反向退 radius*1.30（不依赖间隙、慢速不反向），光带头宽 8.8px<车身、alpha 165、alphaMax 进 group 表（模块 local 槽位 199→198 主动守 AB-154）。验证：探针断言头宽 7.8<15 ALL PASS、发射冒烟零错误、build+预览上传。教训→AB-157（贴体特效位移锚定物体几何、尺寸<依附对象）。
- v0.13.19（初始车改加速车 + 四车都能局内解锁）：用户澄清机制分工「天賦树解锁局内卡，局内卡解锁惧内车，另外基础的车改为加速车」——即**两层正交**：天赋树解锁「专属卡」（v0.13.16 的 `ballCard` 节点），局内卡解锁「车」（保留 `unlock_*`）。上一轮我把「封锁卡片还在局内生成」误读成要删局内解锁卡，用户指的是他以为车只该由天赋树解锁。改动：`STARTING_BALL_TYPE` `normal`→**`speed`**（连带 `PauseReload` 兜底 `or "normal"` → `or STARTING_BALL_TYPE`）、`AUTO_OWNED` `normal_1`→**`speed_1`**、新增 `unlock_normal`（解锁分裂车）使四车都有解锁卡（初始车自己的卡由 `unlockBallType` 自动退池）。验证：`probe_start` PASS（开局 speed 解锁/normal 锁定、AUTO_OWNED=speed_1、无天赋时 normal/ice/giant 解锁卡在池且 speed 卡退池、分裂车未解锁时 base_split/split 不进池）；build+预览上传；战斗真渲染冒烟零错误。提交 78cac51。
- v0.13.18（修平台报错链 + 主块 local 超限黑屏）：用户上报 XHR{}×11 + 缺 official-res Skybox.ktx。取证：`.build/asset_adopt.json` 采纳订阅 `__official_pinned_refs__.json`(#blocking) → 构建注入清单 → 运行时拉 18 个官方材质闭包含 14MB Skybox.ktx，预览下载反复失败。代码零依赖 official-res（资源全 engine-res、材质程序化）→ settings sources 删 official-res（清单验证无 pinned）；删无引用旧皮卡 assets/model/6d5f1062（4 个 uuid:// 遗留）。顺带真渲染冒烟揪出阻塞级黑屏：Scene3DBackend 主块顶层 local 201>LUA_MAXLOCALS 200 → LoadChunk failed、整模块加载失败，**build/LSP 都不查**；删 projectionOriginNdcX_/Y_（写而不读）+MENU_CONTENT_BOTTOM（零引用）→198。验证：新清单 sources=[engine-res] 无 pin；真渲染启动→发射零错误、letterbox 存活；残留 3 条为 .cli 既有噪音（历史探针同款）。BUILD_VERSION/大厅→0.13.18；build+预览上传 ✅。⚠️ 给大文件加模块级 local 前必须数槽位（python re 统计 `^local ` 声明名数）。

- v0.13.17（skill 固化 + 氛围层 + 图标重出 + 死代码清理）：用户两点要求——「skill 没有我们有的规范补进 skill，比如生图工作流」「补充图标的部分，对照我们没用上的使劲用上优化画面」。①**skill 补充**：`dark-tech-game-editor-ui` 新增 `references/pipeline.md`（界面素材生成与落地管线：三类素材分类/项目 8 色板/32×32 母版/非方形字标/`.meta` uuid/`ICON_PATHS`+NEAREST 装载/死键检查），`atmosphere.md` 加「克制实装」一节，SKILL.md 挂链接+工作流+验收；`0718-pixelimage-aigc` 新增 `references/urhox-icon-integration.md`（UI 图标统一规格/图标只画主体/非方形字标/`.meta`+装载/死键检查/存量色数审计/重出流程），SKILL.md §5 加 5.1–5.3。②**氛围层（克制档，`Scene3DBackend`）**：新增 `AnomalyPulse`（全屏共享 0..1 标量，基线不为 0、取模周期尖峰）+ 原未用原语 `DrawDashLine/DrawCrossMark/DrawTickRing/DrawHalftone/DrawScanBand` + `DrawModalTechDecor`；C 表补 `wash/ghost/klein/halftone/ash/railMark`；落点菜单（半调+扫描带+虚线轴+十字）与结算/胜利/暂停窗（环形刻度+虚线+半调），HUD/战斗读数不进装饰。③**死代码**：接上从未调用的 `DrawBossPhaseBar`/`FindBoss`（Boss 阶段条此前不显示）；5 个已加载未绘制图标键——`gem`→钱包钻石、`boost`→HUD 零件×2，`wheel/supply/pass` 已被 premium_* 取代 → 删（ICON_PATHS 41→38）+ 删 3 张 PNG/meta。④**旧图标重出**：审计早期 26 张 `ui_icon_*` 实测 100–583 色（AI 原图直接缩放，v0.12.9 后为 8–9 色）；按 0718 管线重出 21 张（nanobanana 512 草案→bbox→LANCZOS 缩主体 26→alpha 二值化→量化项目 8 色→贴 32×32），全 6–8 色达标，沿用旧文件名覆盖（零路径风险）。验证：官方多人 build+预览上传、LSP 我改文件 0 Error、前向引用扫描 0、真渲染探针（菜单 + `StartStageAt(1)` 战斗）零 overlay stage 失败、截图确认新图标全渲染+氛围层克制可见；⚠️ 探针抓到 `DrawScanBand` 把 `DrawRect` 的 radius 与颜色表参数写反（运行时 `index a number value`）已修。本批只提交 `Scene3DBackend/MetaUI` + 21 图标 + 3 删除 + 两个 skill；`TalentTree/client_main/VisualCatalog` 与版本号（→0.13.17）属并发会话。**并发会话 v0.13.17**：天赋树布局/交互修复（ROW_STEP 128→160、general_b/ice/giant 错开半阶段、右侧可拖滚动条、选中滚到浮窗上缘；根因=Down 已 `ScrollBegin` 而未移动的 Up 又重调 `HandleMetaPointerDown` → `HitTest` 从不触发；`client_main` 加 release-only `HandleMetaPointerClick`）。
- v0.13.16-talent 补充二（天赋树滚动条引导）：用户附截图圈出滚动条「这个引导性不强，后面加一个灰色的轨道，不然玩家怎么知道这个可以滑动」。两处根因：①原轨道 `C.rail`(22,36,56) 与深色底(7,11,20) 几乎同色；②旧 `DrawScrollbar` 把整条滚动条（含轨道）放在 `GetScrollbarThumb` 之后且 `if not thumb then return end`，而 thumb 只在 `maxScroll>0` 时存在 → **不选中节点时连轨道都不画**。修复：轨道**常驻**绘制（中灰 96/112/132 + 浅灰描边 148/166/188）+ 上下外侧各加程序化三角箭头；滑块仍按需绘制。⚠️ 箭头放轨道**外侧**、不动内部数值（滑块几何与命中 `SetScrollFromThumb` 共用）。验证：真渲染截图确认轨道像素 58→915、纵向覆盖 y=141~906 全高。提交 0b69a26。⚠️ 教训：可交互提示（滚动条/把手）必须常驻，不能跟状态显示隐藏；探针必须真的打开目标面板（用 `DebugOpenScreen`），否则截到的是主菜单。
- v0.13.16-talent 补充（专属卡门控 + 局内卡强度）：用户报「封锁卡片包括专属卡还在局内生成」。探针先验排除车解锁门控（全新玩家 400 次抽卡只出分裂车系、`unlockedBalls` 正确），真凶是**天赋树的 `kind="ballCard"` 节点规则层从未消费**——`SetTalents` 的 if-else 链漏了该分支，专属卡只要车解锁就能抽，该节点纯装饰（静默失效 11 个版本）。修复：新增 `talentUnlockedBallCards[ballType]` + `CanOfferUpgrade` 增加「非 base 的带 ballType 卡需专属卡资格」判定。另按用户「局内卡要显著强于局外的树（3～5 倍）」下调天赋数值：分裂 0.02/0.05→**0.005/0.008**、冰冻 0.20/0.50→**0.12/0.30**、极速 1.02/1.05→**1.01/1.02**、贯穿 0.25/0.60→**0.12/0.25**（原值实测反而 ≥ 局内卡）；并修百分比文案精度（0.5%/0.8% 不再都显示成 +1%）。验证：`probe_gate` PASS（无天赋无专属卡 / **车解锁但未解锁 ballCard 节点仍被拦** / 解锁后出现 / 天赋 ≤ 局内卡 1/3）；`probe_vals` 文案正确；build+预览上传。提交 0171cf7。
- v0.13.16-talent 补充（血量加成改全局说明）：用户澄清「加血量上限一点的效果是所有卡的」——血量加成对**所有卡一视同仁**，因此不再逐条写进 42 个节点，改为天赋树**顶部统一说明一次**（`TalentCatalog.HP_RULE_TEXT = "每解锁 1 个天赋：生命上限 +1"`，`TalentTree` 标题栏下方渲染，青色小字）。规则层效果不变（每个已解锁节点 +1 上限）；`WithHp()` 退化为直通。验证：`probe_hprule` PASS（全局文案含数值、42 节点均不再重复、5 个混合类型节点 → hpBonus=+5）；真渲染 `probe_growthdraw` 确认节点详情已是干净的「暴击率 +2%」、全局说明单独成行。提交 2bd592e。
- v0.13.16-talent（天赋成长线改暴击/攻击 + 血量加成可见 + 暴击实装）：用户三点要求「天赋树的血量加成要写出来」「经验和扩容都是通用卡」「成长里面应该只有子弹伤害/暴击率+2%/学满额外+5」；澄清确认**每阶暴击 +2%、每 3 阶额外 +1 基础攻击、暴击 = 伤害 ×1.5、结算零件 +5% 保留填充**。`TalentCatalog` 新增 `CRIT_MULT`/`CRIT_PER_STAGE`/`ATK_EVERY`/`ATK_GAIN`/`MASTERY_CRIT` 与 `WithHp()`（把「生命上限 +N」拼到**每个节点** desc，42 节点全覆盖）；成长线 `general_a` 改为 `critChance` 属性（每阶 +2%，第 3/6 阶附 `atkBonus=1`，末阶学满 7%）；通用卡线 `general_b` 收编经验卡(1 阶)与弹药扩容卡(3 阶)，其余阶结算零件 +5%。`Game` 新增 `talentCritChance`/`talentAtkBonus`，`SetTalents` 为 critChance 走累加分支，新增 `TalentDamageBonus()`（并入所有弹种伤害）与 `ApplyCrit()`（暴击 ×1.5 + `Emit("crit_hit")`）；快照暴露 `talentCritChance`/`talentAtkBonus`/`talentHpPerNode`。`Presentation` 增 `crit_hit → critSpark`（金色「暴击」飘字 + 火花）。天赋树浮窗本就渲染 `node.desc`，血量加成自动可见（实测「暴击率 +2% · 生命上限 +1」）。验证：build+预览；`probe_growth` PASS（42 节点带血量文案、19% 暴击/2 攻击、1500 帧 brick_hit=254 中 crit_hit=34）；`probe_growthdraw` PASS；战斗回归零错误。本批只改 Game/Presentation/TalentCatalog（并发会话在改 TalentTree/client_main，未触碰）。
- v0.13.15b（真机反馈修复：尾迹与车分离 + 盖过车）：用户「和车分离且图层比车还高了」。①分离=z 投影：overlay 标定只测 z=0 玩法平面，车根节点在锚点深度 z≈-0.086~-0.13m，斜俯视正交下 z 进屏幕 Y → 光带悬在车上方。修：`UpdateProjectionMetrics` 加 `projectionDepthX/Y_`（同 x/y 只差 z 的 W2S 两点对测；首版把 z 探针传成 `WorldFromGame(0,0)` 的 x=-4.86 起点，会混入 x 分量，已改纯 `Vector3(0,0,0/1)`）+ `Renderer3D.VehicleDepthZ(radius)`（与 GetVehicleAnchorWorld 同式）+ `ProjectTrailPoint(x,y,z)`，group 携带 radius。②盖车：overlay 天然在 3D 上 + 头段全宽 ~29px>车头 ~15px → 头段沿来向回缩 radius×1.15（≈车尾，钳 ≤ 间隙一半防慢速反向），world-fx 内尾迹移到冲击环/飘字之前。验证：数据探针 ALL PASS（7 段/头宽 14.7 不变）、前向引用 0、LSP 我文件 0 Error、多人 build+预览上传 ✅。⚠️ 待 Preview 贴车观感。教训并入投影审查契约：overlay 贴 3D 物体特效必须带物体 world Z。
- v0.13.15（车辆尾迹迁移到 NanoVG overlay）：用户报「不可见」——两版 3D 尾迹（v0.13.3 软圆 billboard、v0.13.10/11 ribbon CustomGeometry）真机都看不见。根因认知：本环境离屏 3D 因 llvmpipe BloomHDR 编译失败恒黑，**无法自证 3D 层可见性**，之前"零 Lua/overlay 错误 + trail ready 日志"只能证明代码跑了、不能证明画出来了。决策：改走本项目**唯一已验证可见**的 overlay 通道（冲击环/飘字同款 `ProjectGamePoint`）。①`Renderer3D` 整段删 3D ribbon（常量/状态/SyncVehicleTrails/ClearTrailSamples/AddTrailQuad/TrailColor + Init/Render/Shutdown/ClearRunVisuals 钩子）。⚠️ 用 python 按 `s.index(注释)` 切段时，把紧邻 SyncDebris 的**函数签名行**一并删了（注释在签名之后），留下孤悬函数体 → LoadChunk failed；补回签名后正常。**整段删除要以函数签名行为边界锚点，不能只锚注释**。②`Presentation.UpdateVehicleTrails`：读飞行车辆快照（activeBall + marbles 非 onSling），**游戏坐标按路程采样**（11px/0.34s/每车≤20 点/同屏≤10 车），相邻点连成尾细头粗、头 alpha≈200 的四边形段输出 `vehicleTrails`；重开（elapsed 回卷）/非 playing/>50px 瞬移清空，静止弹弓车不拖尾；发射瞬间 activeBall 与 marble 是同一对象，**按 id 去重防双倍老化**。⚠️ Lua 函数不能挂字段（`UpdateVehicleTrails.lastElapsed` → `attempt to index a function value`），回卷检测用模块 local。③`Scene3DBackend.DrawVehicleTrails`：world-fx 段（随震屏、playing 才画），`SLOT_COLORS[ballType]` 弹种色 + 头部向白热混合，`NVG_LIGHTER` 加色叠四边形填充 + 更亮芯线描边。验证：离线数据探针（纯 Lua 不渲染）PASS（直线 7 段/头宽 14.7/峰 alpha 200，idle+gameover 零拖尾）；真渲染发射→飞行冒烟零 Lua/overlay/VertexBuffer 错误；LSP 三文件 0 Error、前向引用 0；多人 build+预览上传 ✅。BUILD_VERSION/大厅→0.13.15。本批只提交 Renderer3D/Presentation/Scene3DBackend（31e0da1）；提交时并发会话 Game.lua 处语法错误中间态（非我文件，未代修），等其补完后构建（⚠️ 印证并发教训：探针同步应 `git show HEAD:` 取已提交版本，别 cp 半制品）。⚠️ 待 Preview：真机拖尾观感与长度/亮度手感。
- v0.13.14（选关重做为蜿蜒路径地图）：用户否决 v0.13.13 的「直线微偏移+细描边圆钮」，明确「我想要开心消消乐那种的」并给参考图（`assets/image/下载 (3).webp`）。参考特征：粗壮蜿蜒路径、像糖果的可点圆钮、星在节点下方、两侧圆形图标栏。重做 `ui/StageSelect.lua`：`SWAY_AMP` 46→96、`SWAY_PERIOD` 4→3、`ROW_STEP` 96→132；新增 `StrokePath`（Catmull-Rom→`nvgBezierTo`+`NVG_ROUND`）串成平滑曲线并三层叠画（路肩 40/路面 30/高光 8）；节点改大圆果冻钮（R40、落影、厚环、高光、42px 粗数字）；三颗星移到 `cy + r + 12`（首版误画在圆内被裁）；左侧道具改 `DrawRoundIcon` 圆钮+角标。验证：build+预览上传；真渲染截图（路肩 8564px/亮青 1646px/金星 1695px）；`probe_towerdraw` 绘制+命中+滚动 PASS；`probe_tower` 规则 PASS。BUILD_VERSION/大厅→0.13.14。⚠️ 探针同步脚本要用 `git show HEAD:` 取已提交版本（并发会话的 Renderer3D 半成品会让 LoadChunk failed）；⚠️ 与并发会话同改一文件时用 `git apply --cached` 只暂存自己的 hunk。
- v0.13.13（选关改无限爬塔 + 道具永久库存）：用户给参考图并要求「中间是关卡圆形按钮上面有高质量像素贴图数字，从下往上生成更多这种按钮有轻度且固定在代码的横向偏移无限爬塔进入高关。默认打开在最新关」，两侧空余分别做「花零件购买局内道具次数（不看广告每局最多使用一次，这种事别写出来，通过精灵图明暗和角标数字）」与「随机的透明度像素风格插图」。实现：`ui/StageSelect.lua` 重写为纵向爬塔（圆形钮 + zpix 数字 + `StageSway` 确定性正弦偏移 + 相邻虚线 + `FocusLatest` 默认定位最新关 + 拖拽滚动，编排层新增 `stageSelectScrollArmed` 转发）；`ui/ItemShop.lua` 新增价格表与购买（炸弹120/冰冻100/护盾100，库存封顶3）；规则层 `Game.itemUsedThisRun` 实现「每局每样限用一次」并出快照 `usedThisRun`，渲染层只用图标明暗+角标表达；`PlayerData.itemStock` 持久化（AsIntMap + 云合并取大），`Game.SetItemStockProvider` 由 `ResetGame` 开局自动拉取；关卡改无限（`STAGE_COUNT`→`STAGE_SOFT_CAP`，`NextStage` 去上限、`stageHasNext` 恒真、列表只列到最高已解锁关）。验证：官方多人 build+预览上传；`probe_tower`（1~1000 关公式、道具首用/二次拦截、provider 重注入、开第 40/200 关）PASS；`probe_towerdraw`（绘制+命中+滚动）PASS；`probe_towerfull` 经 `DebugOpenScreen` 真实打开截图（面板 4040 色/塔身 936 色/星条 1328px/左栏 1967 色）；战斗回归零 Lua/overlay 错误；前向引用扫描 0。⚠️ 待 Preview：真机拖拽滚动手感、圆钮数字清晰度、两侧栏信息密度。
- v0.13.12（天赋树星级门槛改横行 + 可滑动）：用户澄清「支持上下滑动页面，不要塞这么死」「星星限制的阶段指的是每个横行从下到上」。①**轴错位**：星级门槛属于**阶段（横行）**，早期却用 `TalentCatalog.STAGE_STARS[li]`（li 是**线路**索引）标在每列标题旁 → 显示成「成长0★/通用卡3★/分裂车9★…」，语义错误。改左侧独立门槛栏（LABEL_W=44）按横行从下到上标（0★/3★/9★/18★/27★/36★/45★），与线路解耦；顶部表头只留 6 线路名。②**可滚动**：原 ROW_STEP=92 + 小 padding 使 contentH 恰等于可视区高 → MaxScroll=0 滚不动。改 ROW_STEP 128、卡半径 30、topPad=CARD_R+40/botPad=CARD_R+24、表头两行收一行 → contentH 892 vs 可视 678，可滚约 214px。③卡片去掉重复阶段序号。验证：LSP 0 Error、真渲染截图（左栏按横行门槛、卡片不挤、顶部被裁切即证明可上滑）、官方多人 build+预览上传。⚠️ 教训：矩阵式界面标门槛先确认挂哪条轴；可滚动容器必须让 contentH 显著大于可视区高。
- v0.13.11（修 VertexBuffer is empty）：用户上报 2 类平台错误。① `VertexBuffer is empty\!Material ,compute:(nil),vertexBufferSize:1,geomerty type:0` —— 本地真渲染复现 + 日志时序实锤：v0.13.10 新建 4 个 `VehicleTrail_*` 尾迹 `CustomGeometry` 后，**提交几何前节点已启用**，渲染器绘制空顶点缓冲报错（`trail ribbons ready` 15:47:49.500 → ERROR 15:47:49.576，晚 76ms）；同族另两处：`ClearTrailSamples` 收尾 `Clear()` 后 `BeginGeometry+Commit` 提交 0 顶点、`SyncVehicleTrails` 在「有光带→无光带」收尾帧用空 `verts` 提交。修复三处均**不提交空几何**：创建后立即 `node.enabled=false`、清空只 `Clear()`+禁用节点、仅在 `#verts>0` 时重建启用。② `Error processing XMLHttpRequest response: {}`（29 次）项目代码零引用，来自平台云变量请求层（云不可用时重试），已有 pcall+error/timeout 兜底与 `metaSaveInFlight` 串行守卫，不影响游戏且无法在游戏代码内消除。验证：本地真渲染探针（启动期 + 完整一局含重开/清空重建）`VertexBuffer is empty` **1→0 次**、overlay/Lua 错误 0；LSP 0 Error；官方多人 build+预览上传。⚠️ 教训：`CustomGeometry` 新建后/提交几何前必须禁用节点，「清空/收尾」不要 Commit 0 顶点；此类错误只在真渲染暴露，LSP/build 查不到。
- v0.13.10（飞行尾迹重做 ribbon 光带）：用户否决 v0.13.3 尾迹「尾迹特难看廉价」——软圆串珠 + 不随朝向的等宽放大是廉价感根源。中间试 billboard 沿运动朝向拉长的速度线，但 billboard `rotation` 屏幕旋向**无法本地验证**（llvmpipe BloomHDR 编译失败使离屏 3D 全黑，独立探针拿不到任何像素），放弃押注未知约定。最终沿运动折线做 **ribbon 光带**：`Renderer3D` 每弹种一个 `CustomGeometry` 批次（`DiffVCol` + 白底纹理、CULL_NONE、法线 (0,0,-1)，与敌机箱体同一条已验证显色路径），相邻两采样点（末段接到车辆当前位置）各出一个四边形；半宽头 0.22→尾 0.02 ×权威半径线性收束，顶点色按头程 t^1.7 压暗、头段向白热插值（引擎钳 Color 到 0..1，亮头只能靠白插值）；采样 0.035s/寿命 0.3s/每车 6 点/同弹种 8 车、jump/静止清轨、flightTime 回绕防 id 复用串轨、非 playing/重开/Shutdown 清空等规则全沿用 v0.13.3。验证：LSP workspace 0 Error（修掉了两处自身批注/窄化 Error）、前向引用 0、真渲染飞行段探针 30→160 帧（含暂停→恢复的重建路径）零 Lua/overlay 错误、letterbox 存活；官方多人 build+预览上传 ✅。⚠️ 待 Preview：真机光带观感与密度。本批只提交 `Renderer3D.lua`，并发 v0.13.9 天赋树批次不冲突；BUILD_VERSION 常量仍停在 0.13.8（0.13.9 批未推进），由并发会话统一处理。
- v0.13.9（天赋树圆形爬塔 + 升级卡图标）：用户给参考图 + 规格——天赋树做成圆形大卡用线连接、向上延伸可滑动的爬塔式；每个天赋生成与局内三道具同风格图标（按车辆/通用区分颜色）；点卡片底部弹方形浮窗显示天赋名+详情+解锁按钮（花零件/已解锁/未开放/零件不足还差x）；追加局内三选一升级卡也要图标并调整 UI。①`ui/TalentTree.lua` 整体重写：6 线路纵向爬塔（阶段 1 在最下）、圆形卡（圆底+彩色圆环+32px 图标+状态角标）＋阶段连线、拖拽滚动（ScrollBegin/Move/End，编排层从鼠标+触摸转发，拖拽后抑制点击）、顶部固定表头（线路名+星级门槛）、底部方形浮窗四态。②线路配色：通用=品牌青，车线路=弹种色（分裂青/冰冻浅蓝/加速蓝/巨型金）。③新增 9 张 32×32 天赋图标（0718-pixelimage-aigc 管线：bbox→LANCZOS→alpha 二值化→8 色量化，色数 5-9、22hex uuid 唯一），`TalentCatalog.ICON_BY_CARD/KIND/BALL` 唯一映射（DecorateNode 赋 icon/tint）。④局内升级卡顶部 34px 图标+暗底板，「锁定」角标移右上，卡面下移让出图标区、详情限 2 行。⑤`client_main` 加 `DebugOpenScreen` 窄接口（仅离屏验收用，不改游戏逻辑）。验证：LSP 0 Error（本批文件；Renderer3D.lua 的 TRAIL_* 报错属并发在途改动，未触碰）、probe_talentui PASS、真渲染截图确认（天赋树线路配色/浮窗、升级卡图标全渲染，零 overlay/Lua 错误）、官方多人 build+预览上传。
- v0.13.5-floattext（跳字特效修复）：用户点名「修复优化跳字特效特别是频繁的+0」。根因：`brick_hit` 的 `score` 自早期起硬编码 0（真实分数只在 `EjectBrick` 累加、从未外发），`Presentation.brickSpark` 对每次 `destroyed` 无条件飘 `"+"..score`；越线惩罚碎裂复用同一事件也误飘分。①规则层 `EmitBrickShatterFx` 加第 5 参 `scoreValue`，`EjectBrick` 传 `data.score`（80~320/砖），`ShatterBreachedBrick` 保持 0（得分/惩罚从此可分）。②表现层 `SpawnFloatText` 加 `kind` 并返回对象；新增 `SpawnScoreFloat`——同 kind 飘字 46 设计像素内自动聚合累加（寿命刷新重跳、按总值 24/27/30px 三档尺寸），同屏上限 6 条（超出并入最近一条、数值不丢）；仅 `score>0` 时飘分。③手感：初速上飘 -70~-90 + 线性减速到停（`min(0, vy+170dt)`、不回坠），绘制端入场 1.42 倍二次收拢（`pop=1+0.42·lifeT²`）。验证：LSP 0 Error（19 files 0 error）；`probe_floattext` PASS（真实击碎事件分数与 `AircraftPixelData[key].score` 逐机型一致、越线碎裂 score=0、近距 5 连击合并为 1 条 `+500`、10 分散点钳 6 条总值 1700 无丢失、score=0 不生成飘字）；真渲染 `probe_floatshot`（维持 playing+持续注入）零 Lua/overlay 错误，截图确认 `+300`/`+105200` 聚合飘字与描边。官方多人 build+预览上传 ✅。本批只暂存三文件相关 hunk（`git apply --cached`），并发天赋树在途改动未覆盖/未代提交；版本号由并发会话统一推进（BUILD_VERSION 未动）。⚠️ 待 Preview：真机聚合节奏与跳动手感。
- v0.13.5（天赋树）：用户规格——主页加天赋树、消耗零件升级、阶段由星星收集度解锁（0/3/9/18/27/36/45，第 3 阶起 +9）、每阶段 6 点（2 通用 + 4 车）、每点一次即满、需同线路上一阶段已完成、每节点额外给极低血量加成、血量不再由通用卡提供。①新增 `scripts/TalentCatalog.lua`（6 线路 × 7 阶段纯数据；`GetStageStars`/`IsPrereqMet`/`CanUnlock`/`GetLaneNodes`；节点类型 cardUnlock/ballUnlock/ballCard/stat/partsPct；`AUTO_OWNED={normal_1}`）与 `scripts/ui/TalentTree.lua`（插件注册进 MetaUI，6×7 网格三态绘制 + 点格命中）。②`Game.lua`：新增 `SetTalentProvider`（`ResetGame` 每次开局自动拉取，覆盖所有开局入口）、`SetTalents`（派生 `talentMaxHpBonus/talentPartsPct/talentBallStats/talentUnlockedCards/talentUnlockedBalls`）；`GetMaxBaseHp()` 收敛 repair/暂停急救/星级评级/快照/stage_cleared 的全部血量上限引用；`CanOfferUpgrade` 加 `requiresCard`；`SettleParts` 叠加零件%；基础池四车各补 `base_*` 数值卡、xp/ammo 加 `requiresCard`。⚠️ 天赋派生变量块必须在 `UPGRADE_POOL` 之前声明（repair 闭包读 `talentMaxHpBonus`）。③`PlayerData.lua`：`talents`（`AsBoolMap`，云合并并集）+ `GetTotalStars/HasTalent/GetTalents/TalentCount/UnlockTalent/EnsureAutoOwnedTalents`。④`client_main.lua`：require + 注册 talent 屏、`EnsureAutoOwnedTalents`（Load 之后）、`SetTalentProvider`、`HandleMetaAction("open_talent"/"unlock_talent")`、`RefreshMeta` 填 talents/totalStars/talentCount/talentAffordable。⑤`MetaUI.lua`：`GetGrowDefs` 加「天赋树」入口（养成行 5 卡）、`GetMenuBarLayout.row()` 自适应卡宽防溢出、MetaState 注解补 stage/talent 字段。验证：LSP 0 Error、前向引用扫描 0、`probe_talent`+`probe_talent2`+`probe_stageflow` PASS、真渲染零 Lua/overlay 错误、官方多人 build+预览上传；BUILD_VERSION/大厅→0.13.5。⚠️ 待 Preview：天赋树真机布局/点击、数值手感、菜单 5 卡密度。
- v0.13.4（关卡式：选关界面 + 胜利结算 + 星级/解锁存档）：用户澄清「一波 = 原先两波以上的密度」「关卡式要有独立选关界面、打完不自动进下一关而是出胜利界面供玩家选、按剩余防线血量给评级+星级、星级和解锁度入存档」。①`StageCatalog.GetNormalCount` 每波编队量翻倍（`6+2*floor((stageWave-1)/3)+(stage-1)`，6→8→10 阶梯、硬顶 MAX_FLEET=12），新增 `STAGE_COUNT=15`。②`Game` 新增 `stagewin` 态 + `stageResult`（`ComputeStageResult` 按 baseHp 折算：≥0.75 完美 3 星 / ≥0.40 优良 2 星 / else 险胜 1 星；bonus=200×星分 + 50×星零件计入 score/partsEarned）；Boss 击败只停在该态，**删除 v0.13.0 的 4 秒休整自动进关（stageClearPending/stageBreak）**；`StartStageAt/NextStage/RetryStage` 手动进关，`ResetGame(stage)` 后 `wave=(stage-1)*10+1` 换算累计波号；快照加 `stageResult/stageHasNext/stageTotal`。③新 `scripts/ui/StageSelect.lua`（5 列 15 格、★历史星级、未解锁程序化锁形、`HitTest→play_stage`），经 `MetaUI.RegisterScreen("stage_select")`；主菜单 CTA「开始战斗→选择关卡」改开选关（menu 态 PointerDown/回车均不再直接开局）。④`Scene3DBackend.DrawStageWin` 复用 v0.13.3 `DrawAnimatedWindow("game")`+`WindowInput` 逆变换；`HitTestStageWinButton/HitTestMenuCta` 与绘制同源；`UpdateUiState` leaving/visual 三处并入 stagewin。⑤`PlayerData` 加 `stageStars`+`maxStage`（`AsStageStars` 还原整数键钳 1..3、`RecordStageResult` 取 max、`ImportFromCloud` 跨设备合并）；`client_main` 结算块与 `TakeSettlementStats/SettleParts` 扩到 `gameover ∪ stagewin`，win 落库。验证：LSP 0 Error、官方多人 build+预览上传、BUILD_VERSION/大厅→0.13.4；`probe_stageflow` PASS、`probe_partial_boss`/`probe_boss_escape`/`probe_stage` 迁移新语义后 PASS、真渲染 probe_play 零 Lua/overlay 错误。⚠️ 待 Preview：选关/胜利窗弹动手感、六车型×关卡叠加真机帧时。并发批次（六车型/尾迹/窗口动画/弹药）各自提交未覆盖。
- v0.13.3（车辆飞行尾迹 + 全窗口渐显渐隐弹动过渡）：用户「给车辆弹珠增加尾迹特效，给各种窗口加上渐显渐隐弹动的过渡动画」。①`Renderer3D` 新增 `SyncVehicleTrails`：只给飞行中（not onSling）车辆采样软圆尾迹，0.035s 间隔/0.3s 寿命/每车 6 点/同弹种 8 车，四弹种各一 BillboardSet（DiffAlpha 烘焙色纹理、48 槽、空闲跳 Commit），点尺寸锚 marble.radius、z 取车辆锚点 -0.05；非 playing、ClearRunVisuals、Shutdown 三处清空；flightTime 回绕判 id 复用即重建采样。规则层零改动。②`Scene3DBackend` 新增 `DrawAnimatedWindow`（入场 0.32s 渐显 + 0.91→1.03→1.0 弹性缩放，退场 0.18s 渐隐微缩）接管结算/升级/暂停三窗口与 MetaUI 面板（含充值/补给弹窗）；独立 uiClock_（elapsed 差分、回卷归零）驱动；遮罩在恒等变换下绘制不随缩放（防边缘漏底，peer 会话点名）；`WindowInput` 缩放逆变换接入 HitTestGameOverButton/UpgradePanel/PausePanel/MetaScreen/SupplyPopup（弹动期按钮仍可点）；任何开关切换立即清 leaving 残影槽（快速关→重开不叠影）。BUILD_VERSION/大厅 →0.13.3。验证：LSP 0 Error、前向引用扫描 0、真渲染探针（发射→暂停→恢复）零 overlay stage 失败/零 Lua 错误、trail ready 日志确认；官方多人 build+预览上传。⚠️ 待 Preview：真机尾迹密度/帧率、弹动手感、快速开关遮罩缝隙。尾迹与「暂停冻结尾迹」交互：playing 之外状态一律清采样，画面干净恢复。并发 StageCatalog/Game.lua 改动未触碰。
- v0.13.2-ammo（开局弹药 1 辆 + 通用「弹药扩容」卡）：用户「初始弹药减少为1，加入通用天赋卡增加1点弹药数量，该天赋最多三级」。`Game.lua` 以 `BASE_AMMO_TOTAL = 1` + `ammoCapacity` 取代原 `BASE_AMMO_SPARE`，`LoadBalls` 改为「先放 1 辆待发 → 再排入 `ammoCapacity-1` 辆备弹」，开局只有待发车、没有备弹；`UPGRADE_POOL` 新增通用卡 `ammo`（弹药扩容，common/weight 1/**maxStacks 3**），apply → `IncreaseAmmo()`（`ammoCapacity+1` 并立刻补一辆进队列，之后回收补给维持新总量）；快照新增 `s.ammoCapacity`，重开复位。本地探针：开局 `ready=1/spare=0/total=1/capacity=1`、卡片 `maxStacks=3`、选中后 `capacity=2/spare=1/total=2`、600 帧长跑（含升级/解锁/重开）池子总量恒等于「`ammoCapacity` + 已解锁新车数」；官方多人 build + 预览上传。⚠️ 本批次只改 `Game.lua`（并发会话的 Scene3DBackend/Renderer3D 窗口动画改动未提交、未被覆盖）。
- v0.13.1（六车型商店）：用户指出单纯涂装换色缺乏变化，明确允许不同车种且要六款。`MetaCatalog` 保留 default/arctic/crimson/jade/obsidian 老 key（已有购买记录及首充权益仍可用），加 rally，换成默认平头重卡/越野车/跑车/厢式车/装甲车/沙地越野车六种形体；`VehicleGeometry` 单网格六材质分区、几何顶点限定在权威碰撞圆，`Renderer3D` 改按选择构建形体而弹种配色独立。`MetaUI` 六行剪影与绘制/命中同源、免费补给仍保留；购买零件扣费/解锁/装备一次落盘，云继承默认车的选中款。首充展示越野车。LSP 0、多人 build 成功；六车战斗态全部切换且零 Lua/overlay 报错；六车顶点、商城按钮/免费礼包、购买幂等隔离探针通过。Linux llvmpipe HDR shader 编译失败导致 3D 层黑，外形观感仍需真机 Preview。提交 34cab19，尾迹和窗口动画均未包含。
- v0.13.0（十波关卡+十精英五首领）：`StageCatalog.lua` 将持续无限波改为每关十波，第 3/6/8 波各一精英、第 10 波专属 Boss；十精英在前三关轮换后第 4 关覆盖最后一型、5 Boss 按关循环。普通波逐关增加至每波最多 7 架，同屏预算 12；每过三关普通飞机方块 HP +1，精英 +1/Boss +2，`DamageBrick` 修复成真正扣到 HP≤0 才脱格（旧实现任何命中都脱格，增长无效）。精英横向不规则连续避让，纵向每帧钳至同波普通基准 `normalVy*1.1`；五款 Boss 分别召唤 hive/dart/scout/bomber/striker，频率与总次数受限。Boss 击败即 `stage_cleared`，残兵撤场后 4 秒进下一关，保留单局血量/Xp/弹药/零件；Boss 完全越线只按行扣血，血还在则补发同一第十波，部分越线后打光仍通关与图鉴收录。规则预抽 `PlanWave` 与 Dock 预告一致，HUD/横幅/结算显示关与关内进度；图鉴 23 型分页，体素材质 bank 0 使用 184 个 LOCAL 槽位。验证：LSP 0 Error、官方多人 build+上传，独立五关/50 波/十精英五 Boss/五次召唤/184 不重复槽探针 PASS；Boss 完全越线/部分越线 PASS，900 帧弹药回归 PASS；离屏渲染战斗无 Lua/overlay stage 失败，Linux 无体素模块且 BloomHDR shader 编译失败，手机 Preview 未验。并发六车型/窗口动画/载具尾迹等独立修改只合并保留，不写进本版本提交。
- 后期 3D/规则负载治理（e010e1c、9c441a2）：同屏机群由每十波递增改为最多 12，刷波按剩余容量生成；弹珠每个子步先粗筛整机／单格 AABB，再走原最近命中精判和扫掠，异常长达 60 秒的飞行球回收（纯水平轨道不再永久占场）。体素碎块由渲染层显式按 1.2 秒寿命和出生顺序回收、最多 24 个，不再扫描整个 World 或依赖过期计数；初始化失败主动回收孤儿 volume；冻结签名仅实际换色时变化，空粒子／瞄准线跳过重复提交；新局清理旧局同 ID 视觉节点。官方多人构建成功，850 帧 Linux 离屏战斗无 Lua 错误；该运行时无体素模块且 LSP daemon unavailable，真机体素碎块与后期帧时仍待测。
- v0.12.14（修 UI Inspector 报错）：平台错误上报「UI Inspector requested but failed to load」。根因：平台无广告 SDK 时（编辑器/预览）引擎用 `urhox-libs/FakeAd` 模拟激励视频，FakeAd **只 require** `urhox-libs/UI/Core/UI` 并在 UI 未初始化时调 `UI.Init`；`UI.Inspector` 字段只由聚合模块 `urhox-libs/UI/init.lua` 赋值，游戏 Runtime 从不加载聚合模块 → `UI.Inspector` 为 nil；preview 环境（`GetTapMakerEnvString()=="preview"`）下 `UI.Init` 自动请求 F9 检查器落空 → 打 ERROR 上报。本地复现：把 `GetTapMakerEnvString` 改成返回 "preview"、只 require Core 再 `UI.Init` → 稳定 1 次 ERROR，补装聚合模块后 0 次。修复：新增 `scripts/ui/UIInspectorCompat.lua`（`Ensure()` 先装聚合模块拿真检查器，失败才兜底空实现），`AdService.Show` 发广告前幂等调用（不进启动路径）；顺带消除 `UI.Shutdown` 里 `UI.Inspector.Shutdown()` 的空指针风险。BUILD_VERSION/大厅版本→0.12.14。验证：探针模拟 preview+FakeAd 路径修复前 1 次→修复后 0 次且 Inspector 为真模块；游戏启动与战斗态离屏渲染回归正常；官方多人 build+预览上传 ✅。
- v0.12.13（初始弹药 5→3 辆）：用户「车辆基础数量-2」，确认后指初始装载车辆数而非车辆种类。`Game.lua` 新增 `BASE_AMMO_SPARE=2`，`LoadBalls` 由「装 #BALL_ORDER 辆」改为「装备弹 N 辆 → 取 1 辆待发 → 再补 1 辆」，开局总装载 5 辆 → 3 辆（1 待发 + 2 备弹）；车辆种类仍 4 种，底部四槽/解锁卡/卡池门控不变；BUILD_VERSION 与大厅标题 →0.12.13。本地规则探针（900 帧、35 次发射、含升级解锁）核对开局 `ready=1 spare=2 total=3`、播放期总量恒等于「3 + 已解锁新车数」（解锁插入新车是预期追加，不是泄漏）、重开复位为 3；本地真渲染战斗态零 overlay stage 失败与 Lua 错误。⚠️ 3 辆是否偏紧的手感待 Preview。POST-3 判定：随行记忆无需变更（纯数值调参，无跨项目偏好）。
- v0.12.12（单车开局与卡牌解锁）：用户明确要求「游戏开局只解锁其中一种车，剩余车辆需要升级后的卡牌解锁，未解锁的车的对应天赋卡不会一开始进入卡池，解锁后加入」。规则层 `unlockedBalls` 本局初始 `{normal=true}`，NextBallType 仅在已解锁集合中固定顺序轮换，普通回收／广告补弹合法；`UPGRADE_POOL` 新增 ice/speed/giant 三张一次性车型解锁卡，`UnlockBallType` 即时插队（下一发）、保留当前待发/在飞车；分裂裂变核、冰冻深寒涂层、加速疾速引擎及超载核心、巨型重型化均标注 `ballType`。`CanOfferUpgrade` 统一过滤持有卡、加权抽选、候选不足补齐及最终选卡，解锁后直接开放专属卡、已解锁解锁卡退池。UI 四槽未解锁置暗+「锁／待解锁」、卡片「新车型 · 本局解锁」，删原来误导的「点击切换」（原游戏不存在点槽换车）；最小回退 Dock 同步锁态。官方多人 build+预览上传、本地规则探针通过（真实 XP 触发升级/解锁两车/新车下一发/重开复位）、本地战斗渲染无 Lua 或 overlay stage 错误；随机第三车是否抽到取决于后续升级，未作保底。LSP 连接不可用。
- v0.12.11（HUD 失踪真凶：前向引用 nil ×2 + 本地复现链路）：用户第三次发战斗截图「hud失踪」（22:50，晚于 v0.12.10 预览）→ 判定大厅时序理论错误，改用本地真渲染复现：`UrhoXRuntime -tool_mode -graphicssurfaceless -screenshot`（llvmpipe+GLES3.1 离屏真渲染，探针工程 `/home/Maker/urhox-probe-live/` 用 scripts+assets 拷贝）。逐层取证：菜单态覆盖层健康（letterbox=7,11,20）；探针订阅 Update 顶掉游戏 handler（单槽、后订阅者胜）→ 探针需手动链式 `_G.HandleUpdate`；修好探针后战斗态每帧 `Execute Lua function failed: Scene3DBackend.lua:948 attempt to call a nil value (global 'DrawIcon')`——v0.12.9 在 `DrawAmmoSlots`(948) 用了后置定义的 `DrawIcon`(1147)，且错误处理器 `ReportOverlayStageError` 同样先用后声明（nil）→ stage pcall 接住原始错误后调用 nil 再抛 → 整个 NanoVGRender 回调崩溃、nvgEndFrame 跳过、整帧 2D 丢弃（菜单无此路径故正常）。修复：两处 AB-100 前向声明（`local X = nil` + 后置赋值），全库扫描器复扫 0 问题。BUILD_VERSION/大厅标题栏→0.12.11，本地菜单+战斗截图验证通过、官方多人 build+预览上传。
- v0.12.10（大厅 UI 上下文自毁时机）⚠️ 根因已被 v0.12.11 订正：`shutdownLobbyUI` 提前到 onProgress>=1 的改动保留为顺序确定性加固，但 HUD 失踪与此无关；真凶是前向引用 nil 调用。
- v0.12.9（高端 dark-tech UI 精修 + 8 量化像素素材 + overlay 容错）：用户 5 截图「UI不够贵」+「要生成设计很多新素材/自定义纹理nanovg代码」（0718-pixelimage-aigc + dark-tech-game-editor-ui）。8 张 32×32/8 可见色像素素材（补给箱/档案盾徽/能量核心/大奖章 + 四弹药图）走草案→bbox→LANCZOS→alpha 二值化→量化管线入包（manifest/uuid 验证）。`DrawMachinedPanel` 机加工表面（微渐层/内槽线/铆点/边缘电路刻纹，宽面板限用）、精密进度条统一；HUD 三栏重排、Dock 图标化、暂停资源卡+去 P 键、战斗档案英雄区+里程碑、仪表盘转盘、补给弹窗奖励区、CTA 主题图标；RenderOverlay 分 stage pcall+最小回退（v0.12.11 证实真因是前向引用 nil；本纵深保留并已修复其错误处理器）。多人 build+上传，LSP daemon unavailable 如实记录。
- v0.12.8（主菜单像素字标轮播：AI 生图 → 0718 管线 → 5 秒切换）：用户否决纯程序化标题「图标太无聊啦，没有游戏元素介入」并指定走 `0718-pixelimage-aigc` skill。①`batch_generate_images`（nanobanana 1344×768、4 seed）出 4 张融合玩法元素的「击碎飞机」字标（重卡弹道击碎「碎」+8bit 敌机 / 小货车点状弹道+飞碟+碎块 / 「击」裂纹+invader+底部砖墙撞穿 / 像素弹丸撞碎+俯冲敌机）。②后处理手写定制（skill 的 postprocess.py 只支持方形母版）：bbox 裁切→LANCZOS 等比缩 **120 高**（宽 207/235/244/264）→alpha 二值化 128→**7 色 dark-tech 量化**（≤9 达标）→成品 `ui_logo_{a,b,c,d}_20260929162106.png`+22hex uuid meta，草案移出 assets。③轮播：`LoadLogoTitles`（Init 里 NEAREST 加载，可选资源不进成功条件）+`PickLogoImage(elapsed,uiStateEnter_)`=`(floor(t/5)+logoRollOffset_)%n+1`，`logoRollOffset_` 进 menu 时 `math.random(0,3)` 摇一次；`DrawMenu` 1× 等比居中（y90..210 与断线/CTA 无冲突，PIL 合成验证），缺图回退 `DrawPixelLogo`。BUILD_VERSION→0.12.8。多人 build（内置 LSP 语法检查）成功+预览上传，4 图进 manifest。⚠️ 待 Preview：真机 NEAREST 硬边、5 秒节奏、随机起点。⚠️ 环境：`/workspace/.tmp` 被 root 占不可写→临时文件走 `/home/Maker/`。
- v0.12.7（截图整改：大厅换皮 + logo 空框 + 开局零弹窗 + 签到并入充值 + 钱包语义）：用户三张截图与多次插话。①`lobby_runtime.lua` 重写为 dark-tech 窗口壳（深底/panel 标题栏/断线/青色进度 fill/倒计时/扫描点，状态迁移文案），⚠️ urhox-libs/UI 无 ref→控件先建局部变量再组装、SetText/SetStyle pcall。②logo 空框根因=**zpix 逐码位超大号退化**，改整串 nvgText+右下硬阴影双层；BUILD_VERSION→0.12.7。③开局零自动弹窗：删 `TryShowPremiumPassOffer`/`premiumOfferShown_`/`balanceReceived_`/自动补给 modal；付费轨解锁收回 DrawPass 紧凑金按钮（`GetPassUnlockRect`/`buy_premium_pass`）；养成收藏行固定 4 卡。④每日签到并入 `RechargeShop` 顶部 signIn 行（HitTest→"signin" 穿透 HandleMetaAction）；菜单福利行 3 卡 `row()` 居中；gift 共存时 spendStep/spendH 压缩（798<820 推演）。⑤钱包条删「零件→钻石」误导箭头，改双余额块+金色实心「充值」钮；RechargeShop backdrop 0..960。LSP 0、多人 build+预览上传。⚠️ 待 Preview：大厅实机、logo 观感、签到行、钱包排布。
- v0.12.6（主菜单重设计：像素大 logo + 去 HUD + 变现闭环三段式）：用户截图反馈「击碎飞机应该本身变成像素超级大标题；主页明显需要重新设计；所有变现点之间没有良好的整合」。①`DrawPixelLogo`（UTF-8 逐字 104px、首尾青中间白、硬偏移阴影、zpix 程序化无外部图），短名 `GAME_SHORT_TITLE` 只用于 logo，对外全名契约不变；菜单从窗口壳+「本局目标/怎么玩」填充块改全屏自绘（bg+角标+断线+微型网格），CTA 上移 y262。②`RenderOverlay` menu 态不画战斗 HUD；`DrawSupplyPopup` backdrop 0..960 铺满。③变现三段式（AskUser 用户拍板）：图鉴剪影条→钱包连接器（零件→钻石→充值）→今日福利行（签到/补给/任务/转盘）→养成收藏行（商城/档案/图鉴或首充礼包顶替/排行）；`GetDailyDefs/GetGrowDefs` 纯函数驱动绘制+`HitTestMenuBar` 同源；三色边框落卡描边。LSP 0、多人 build+预览。⚠️ 待 Preview：logo 真机观感、卡片信息密度、遮罩缝。
- v0.12.5（真机反馈整改：广告收敛 + 出口闭环 + 换皮通知 + 道具竖列 + 图标增强）：
  - **升级面板广告瘦身**（用户 4 截图否决）：删除选卡倒计时/+30 秒/超时自动选卡/看广告解锁第 4 张/单卡升格/额外再选；`Game.Update(dt)` 恢复单参数；面板只剩免费重抽+看广告重抽（必出稀有）+免费锁定/保留。规则层删 8 个接口与占位卡；`HitTestUpgradePanel` 只剩 4 种 kind。
  - **局内道具右上角竖列**：默认收起「道具」标签（青色数量角标/绿色可领点），展开 3×52 槽；`itemPanelOpen_` 后端持有，`ToggleItemPanel/SetItemPanelOpen`；`HitTestItemSlot` 返回 `("toggle"|"slot"),index`；Grant 成功保持展开。
  - **广告在途自动暂停**：`HandleUpdate` 以 `AdService.IsInFlight() && state=="playing"` 跳过 `Game.Update`（勿用 IsBusy，冷却会多冻 3s）；表现层照常衰减。
  - **暂停/结算出口**：HUD 右上角 28×28 暂停按钮（绘制/命中同源、playing 才画、缺图程序化竖条回退）；暂停页「继续战斗/返回主菜单」行 y=740；结算页第四行「回主菜单」y=616（menuArmed 松手确认）；`Game.GoToMenu()` playing/paused/gameover→menu。菜单文案「按 P」改「右上角按钮」（移动端禁键盘指引）。
  - **平台通知换皮 + 付费轨顶部条**：`Backend.ShowSystemBanner/HitTestSystemBanner/HasSystemBanner`（y=HUD_HEIGHT+8、elapsed 差分计时、最上层绘制、点条体=关闭）；ClientMain 与 lobby_runtime 两处 RegisterHandler（各自 Unregister，大厅 shutdownLobbyUI 统一 hideBanner+退订）；exitOnClose/kicked 带「退出」→engine:Exit()，error 只提示。付费档案轨大行从 DrawPass 删除，改主菜单一次性 banner（`balanceReceived_` 门控防 gems=0 误报；affordable→立即解锁 / 不足→去充值；`onBannerAction` 延后赋值解 local 前向引用）。
  - **图标与 HUD 增强**：新 4 张 32×32（pause/home/barrier/levelup，.meta 22hex uuid、manifest 验证打包）；等级行 levelup 图标+xp 条右移缩窄；防线列左移 36 让位暂停钮；零件加倍并入零件行；出口按钮 home 图标+程序化播放三角。BUILD_VERSION 0.12.5。
  - 验证：LSP 0 Error、多人 build+预览上传、manifest 含新图标、uuid 无重复。⚠️ 待 Preview：通知条实机、广告冻结、竖列点按、offer 时机。
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
- 拖尾粒子系（2026-10-11）：彗星/流光从「三角带光带」换成 **billboard 粒子**（真粒子系）——彗星=密集暖金尘+头端灼核、流光=离散青白光片+自旋；经典/霓虹/余烬/双轨保留光带不变。粒子按弧长撒布（每米 N 颗，帧率/速度无关）、确定性 hash（非 math.random）、沿寿命膨胀+漂移+收缩；颜色烘焙进专属纹理（DiffAlpha 不读顶点 rgb）；**与光带互斥**（particle 样式下清空并停用光带节点）。2D 预览同步。详见 versions.md / CLAUDE.md 附记 trail-particle-styles，抗体 AB-269/270。
- CTA 横向拉伸（2026-10-11）：`ui/ArtText.lua` 新增可选尾参 `stretchX`（`Draw`/`DrawCentered`）+ `FitWidth(key,targetW,scale)`；CTA「开始战斗」纵向 FitHeight 60 不变、横向拉伸到按钮宽 ~66%（上限 1.7×，实测金属字宽 165→258 设计像素）。除 Zpix 外的像素字体推荐：`ui-pixelforge` skill 自带 Fusion Pixel 12px（Prop/Prop-Bold/Mono，含简体中文），比 Zpix 更细更干净，适合正文/小字，可与 Zpix（标题）分层使用。详见 CLAUDE.md 附记 cta-stretch。
- 「开始战斗」艺术字重出（2026-10-12）：按用户参考图重出为**斜体银白金属字 + 青边缘光晕**（0718 管线：transparent 草案 → alpha>128 裁切 → 按母版高度 44 归一宽 140 → 覆盖同名 `ui_tt_startbattle.png`，沿用旧 uuid）。CTA 白 tint 安全（彩色素材比灰度更依赖白 tint）。真渲染银白像素 1952→4286、青晕 29033px。详见 CLAUDE.md 附记 cta-startbattle-regen，抗体 AB-275。
- 「开始战斗」素材缩放修复（2026-10-12）：用户报「素材缩放有误」——真因是上一批选了**带青晕**的草案（aspect 3.18、字距散），参考图是**无光晕紧凑银白金属字**（2.55）。换回 `sb_a`（无晕，2.14）+ CTA 参数收紧（FitHeight 64 / stretchX 上限 1.10 / 目标宽 0.60）。定位法：参考图/用户截图/我的渲染按按钮宽归一化并排。详见 CLAUDE.md 附记 cta-startbattle-scale-fix，抗体 AB-276。
- 拖尾粒子滞后修复（2026-10-12）：粒子系拖尾（彗星/流光）的发射改为「只算上一帧→当前的新增距离」，提交改为「从最新往回取、超预算丢最老」——修「尾迹在车尾前方断掉」的滞后。详见 versions.md / CLAUDE.md 附记 trail-particle-lag-fix，抗体 AB-278/279。
- 「开始战斗」CTA 放大到参考图占比（2026-10-12）：上一版 scale-fix 改过头（字偏小）。精确量参考图：字占按钮宽 57%/高 80%、字框 aspect≈4.0 → 素材 aspect 2.14 需横向拉伸 ~1.87×。参数 FitHeight 67 / stretchX 目标 0.57（上限 1.90）。详见 CLAUDE.md 附记 cta-startbattle-scale-fix2，抗体 AB-277/278。
- 「开始战斗」直接用用户成品图（2026-10-12）：用户直接发来带青晕的斜体金属字成品 PNG 并说「直接加上去、不用压缩」——只裁透明留白（alpha>128 bbox 1216×382）+ 缩到母版高 128（→407×128，保留原图色阶，不灰度/不量化），覆盖 `ui_tt_startbattle.png`（沿用旧 uuid + `.png.xml`）。CTA 参数改 `FitHeight 67` + `stretchX 1.0`（新素材 aspect 3.18 本身就够宽，不再横向拉伸）。详见 CLAUDE.md 附记 cta-user-asset，抗体 AB-281。
- 「开始战斗」CTA 被缩小修复（2026-10-12）：用户「谁要你缩小了」——真因是上批 `cta-user-asset` 误把 `stretchX` 上限写成 `math.min(1.0,…)`，`FitWidth` 的 1.28 被压回 1.0，字只剩自然宽度（金属核心仅占按钮 12.6%）。修：上限 1.0→1.9、目标宽 0.60→0.66（`sx=1.41`），实测字宽 213→301 设计像素、占比 12.6%→60.2%（与参考 57% 吻合）。详见 CLAUDE.md 附记 cta-stretch-cap-fix，抗体 AB-282。
- 失败/胜利结算页重排（2026-10-12）：用户「调整失败和胜利界面，浪费Ui空间且广告太过密集」。真问题：窗口 200..720 只占上半屏（下方大片空白）+ 两个广告按钮实心绿块叠一起。修：窗口垂直居中（winY=216/winH=620，上下各留 124）+ 主 CTA 置顶整行宽（唯一实心青）+ 广告按钮降为次级描边（底暗 card + 绿描边）+ 行高 56。命中几何同源，探针验证旧位置已 nil。详见 CLAUDE.md 附记 endpage-layout，抗体 AB-286/287/288。
- 设置屏「制作鸣谢被挡住」修复（2026-10-12）：用户截图显示关闭按钮压住鸣谢三行。真因两层：①截图是旧预览包（鸣谢由并发会话 `5238492` 才加）；②新布局间距仍偏紧（46px）。修：`PANEL_H` 600→640，间距 104px。几何断言探针 `probe_setgeo` 验鸣谢三行 HitTest 全 nil、关闭按钮命中。详见 CLAUDE.md 附记 settings-credit-fix，抗体 AB-289/290。
- 失败结算「防线崩溃」动态漫过渡（2026-10-12）：用户「失败重构之后需要用三到五秒动画表现，甚至要复杂一点，做成动态漫」。失败页此前无过渡。新增 `StageTransition.DEFEAT_DURATION=4.0` + `DrawDefeat`（红调、12 段落、确定性伪随机）；`Game._defeat` 挂表记计时基准（零新增顶层 local）；门控抽 `TransitionInfo` 统一两态。探针验门控边界 + 跑满零错误。详见 CLAUDE.md 附记 defeat-transition，抗体 AB-291/292/293。
- 构建清单哈希错配修复（2026-10-13）：平台报「黑屏 + Module not found: Scene3DBackend」。真因：清单 `manifest-d8030526.json` 记 `Scene3DBackend.lua` 为 `hash=8d87062e,size=155296`，产物实为 155424（=源码）→ 下载校验判「incomplete or corrupted」→ `#blocking` 资源拿不到 → 黑屏。成因：构建时有并发会话在写该文件。修：移出无引用垃圾参考图（`OIP (1).webp`/`下载 (3).webp`）+ 重新构建（build 25）→ 新清单 217 文件 0 错配、crc32 精确匹配；本地真实启动零 Module not found。详见 CLAUDE.md 修复条目，抗体 AB-295/296。
- 全量排查（2026-10-13）：机械检查（顶层 local 200 上限内 / LSP 0 Error / 清单完整性）+ 真渲染探针 + agent 深审三层。修 3 处真 bug：①空仓「长按加速」提示因游戏 Y 向下为正、把 dangerY 当上边界 → 带高恒负 → 永不显示；②长按时提示未隐藏（加 timeScale/holdSpeedPending 门控）；③成就 toast 直接赋值 metaState.toast 漏重置 metaToastTimer → 永久驻留（改 SetMetaToast）。加固 2 处写死步数（codex_all→GetCodexTotal、talent_all→#GetNodes）。agent 报 6 条仅 1 条成立（高分单调性/覆盖范围是误报）。详见 CLAUDE.md 修复条目，抗体 AB-297/298/299。
- 成就并入战斗档案（2026-10-13）：用户「成就界面并入战斗档案任务，同时战斗档案任务也并入平台成就，并增加额外成就，列表变为上下翻页且被解锁的优先在顶端」（澄清：主菜单只留一个合并入口 / 里程碑做成平台成就条目）。做法：主菜单删「成就」卡（grow 5→4），档案屏加「战斗档案/成就」两页签（`GetPassTabs`/`GetPassBody`，档案内容改 `body` 定位，绘制与命中同改）；`ui/Achievements.lua` 取消独立屏、改由 `MetaUI.DrawPass` 调用，列表已解锁置顶 + 上下翻页；`AchievementCatalog` 加 `pass_lv3/lv5/lv6`（20→23）；里程碑条数 5→4（页签占位后第 5 条被底栏裁掉）。真渲染截图目视两页签。详见 CLAUDE.md 附记 achievement-into-pass，抗体 AB-301/302。
- 最高分云写合并（2026-10-13）：对照 `@tianyi_multiplayer-game-skill` 检查云端存档 → 本项目属 skill 的「JSON/存档中继 + 私有实例」（M=0），合规；唯一实质问题=最高分**每刷新一次就写一次云**（一局上百次 `SetInt`）。修：局内只累计 `highScoreDirty`，**进入结算/菜单那一帧**提交 + **每 15 秒周期兜底**；`SaveHighScoreToCloud` 改「成功才确认」、失败重新标脏重试；`CommitHighScore` 每次调用都重置 15s 冷却（防持续态每帧重试）。真渲染 mock 探针：局内 140 帧 0 次写 / 进菜单提交 1 次（值 5000）/ 800 帧失败菜单态仅 3 次尝试（旧 ~800）。详见 CLAUDE.md 修复条目，抗体 AB-303/304/305。
- 分裂/三连子车灰暗 + 降层级（2026-10-14）：用户「分裂产生的车既然不是正式的车那就变成灰色的暗淡的而且显示图层要低」。识别走规则层已有字段 `isPrimary == false`（分裂车 + 三连附加车都带），不新增规则状态（`GetSnapshot().marbles` 是原始引用）。表现层新增子车专属灰材质（body `{0.30,0.32,0.37}`）+ 暗灰轮廓；低层级 `VEHICLE_CHILD_ORDER=64`（⚠️ Urho3D 材质 render order 默认 **128**，值越小越低，**负数回绕成 246** 反而更靠上）。只改 Renderer3D.lua。真渲染 probe_child ALL PASS（childOrder=64<128、normalOrder=128、子车 body 灰）。详见 CLAUDE.md 附记 split-child-dim，抗体 AB-328/329。
- 拖尾整体不透明度降低 70%（2026-10-14）：用户「全部拖尾不透明度降低70%，变得透明」。所有拖尾（光带系 + 粒子系）统一乘 `TRAIL_OPACITY=0.30`。光带走 `DiffVCol`（base pass 默认 BLEND_REPLACE，顶点 alpha 被忽略）→ 克隆 technique 改 base pass 为 BLEND_ALPHA（不能改共享资源，敌机/飞散箱也用 DiffVCol）；粒子走 `DiffAlpha` → billboard 顶点 alpha。`MetaUI` 商店 2D 预览同步降（`TRAIL_PREVIEW_OPACITY`）。真渲染 probe_trailopacity ALL PASS（opacity=0.30、ribbonBlend=3=BLEND_ALPHA、ribbonVerts=162、particleAlpha=0.30）。详见 CLAUDE.md 附记 trail-opacity，抗体 AB-334/335。
