# 击碎，飞机大战 — 项目核心记忆

> AI 自维护，每次 POST 自动更新。详细规则见 memory-system skill。

## 当前状态
- 版本: 0.13.0（关卡制与独立精英/首领）：
  - **十波一关**：`StageCatalog` 定义关内第 3、6、8 波精英、第 10 波首领；普通波由 3 架随关卡逐步增加到 7 架，同屏总数限制 12。每三关普通方块血量 +1（第 1～3 关 1、第 4～6 关 2），精英/Boss 额外护甲；修复 `DamageBrick` 原来无视 HP 直接掉块的问题。Boss 击败即结算本关，清退残兵、4 秒休整进入下一关，当前局 XP、血量、强化、弹药及零件保留；首领逃脱只按越线行扣血，仍有血就重新派出同一关第 10 波。保留 `wave` 累计值给每日任务，快照另带 `stage/stageWave/wavesPerStage` 给 HUD、预告与结算。
  - **15 个原创机型**：`AircraftPixelData` 增 10 个精英 + 5 个 Boss 各自独立 ASCII 剪影、行为数据；精英连续多频/折返横移，每帧纵向推进限于同波普通基准的 **1.1 倍**（冻结只减速）；五款 Boss 分别召唤指定普通机，召唤有次数/间隔和 12 架预算；图鉴分页收录。`VisualCatalog` 共 23 型 × 4 色槽 × 冻结/常态 = 184 索引，不重叠且位于 LOCAL bank 0 的 1..255；预告图与真实刷怪同一预抽计划。战斗仍是客户端本地规则，服务端 IAP/钻石职责不动。
  - **验证**：LSP workspace 0 Error；官方多人 build+预览上传成功。隔离规则探针 5 关/50 波/10 精英独特外观/5 Boss 独特外观/5 次召唤/184 槽无重叠、首领全逃/部分越线后击杀、900 帧弹药回归通过；本地离屏真渲染战斗无 Lua 或 overlay stage 失败，但 Linux 无体素模块且 BloomHDR 在 llvmpipe 上报 shader 编译错误，真机体素与关卡 UI 效果仍需 Preview 验收。并发会话有独立六车型/窗口动画/尾迹改动，本提交仅包含关卡相关片段，保留其未暂存修改。
  - ⚠️ **关卡切换不调用 ResetGame**（会清所有成长）；只重置 stageWave/bossDefeated，wave 保持累计；精英纵速上限在运动步按 `normalVy*1.1` 钳制，不能只在行为表设置倍率。部分越线后 Boss 剩余砖被打光可通关/收录，全部逃脱不得通关；首领击败后残兵退场不计免费奖励。
- 版本: 0.12.14（修「UI Inspector requested but failed to load」）：
  - **根因（本地已复现）**：平台没有广告 SDK 时（编辑器/预览）引擎用 `urhox-libs/FakeAd` 模拟激励视频；FakeAd **只 require UI 的 Core**（`urhox-libs/UI/Core/UI`），并在 UI 未初始化时调用 `UI.Init`。而 `UI.Inspector` 字段**只由聚合模块 `urhox-libs/UI/init.lua` 赋值**——本作游戏 Runtime 从不加载聚合模块（游戏 UI 全是 raw NanoVG），于是首播广告时 `UI.Inspector == nil`；preview 环境（`GetTapMakerEnvString()=="preview"`）会让 `UI.Init` 自动请求 F9 检查器，请求落空即 `log:Write(LOG_ERROR, "UI Inspector requested but failed to load")`，被平台错误上报收集（帧号 1847 ≈ 玩家点了结算/暂停里的广告）。复现：本地运行时把 `GetTapMakerEnvString` 改成返回 "preview"，只 require Core 再 `UI.Init` → 稳定复现 1 次该 ERROR；补装聚合模块后 0 次。
  - **修复**：新增 `scripts/ui/UIInspectorCompat.lua`（`Ensure()`：先 `pcall(require,"urhox-libs/UI")` 装载聚合模块拿真正的检查器，失败才兜底 `{Init/Shutdown 空实现}`），`AdService.Show` 发广告前调用一次（幂等、按需加载，不进启动路径）。F9 检查器在预览里仍可用，且 `UI.Shutdown()` 里未加保护的 `UI.Inspector.Shutdown()` 也不会再空指针。BUILD_VERSION 与大厅版本→0.12.14。
  - **验证**：官方多人 build+预览上传 ✅；本地探针（模拟 preview + FakeAd 初始化路径）修复前 1 次 ERROR → 修复后 **0 次**且 `UI.Inspector` 为真模块；游戏启动与战斗态离屏渲染回归正常（截图非空、零 Lua/overlay 错误）。
  - ⚠️ **库的「聚合模块 vs Core 模块」字段分离**：`UI.Inspector` 这类字段只在聚合入口 `urhox-libs/UI/init.lua` 赋值；绕过聚合直接 require Core 的引擎内置模块（FakeAd 就是这样）拿到的表里它们为空。凡「引擎内部会替玩家调用 UI.Init」的路径，都要先保证聚合模块装载过。
- 版本: 0.12.13（初始弹药装载 5 辆 → 3 辆）：
  - **开局装载减量**：`Game.lua` 新增 `BASE_AMMO_SPARE = 2`（另有 1 辆待发），`LoadBalls` 按它装载 → 开局总装载 5 辆（1 待发 + 4 备弹）→ **3 辆（1 待发 + 2 备弹）**。补弹仍按「回收一辆补一辆」维持总量；`UnlockBallType` 插入新车时总量 +1（v0.12.12 行为，不是泄漏）。车辆种类仍为 4 种，底部四槽、解锁卡与卡池门控不变。BUILD_VERSION 与大厅版本→0.12.13。
  - **验证**：官方多人 build+预览上传 ✅；本地规则探针（900 帧 / 35 次发射）核对开局 `ready=1 spare=2 total=3`、播放期总量恒等于「3 + 已解锁新车数」、重开复位为 3；本地真渲染战斗态零 `overlay stage failed`、零 Lua 错误。⚠️ 真机手感（3 辆是否偏紧）待 Preview。
  - ⚠️ **校验池子总量时必须计入「解锁追加」**：v0.12.12 起每解锁一种新车会往队列插入一辆，静止期望值不是常数 3 而是 `3 + 已解锁新车数`；把 3 写死会让探针在解锁帧误报泄漏。同理，`PauseReload`（看广告补弹）也会临时 +1。
- 性能修复（e010e1c / 9c441a2，与 v0.12.12 解锁功能并行独立提交）：
  - **后期负载控制**：同屏机群预算由 `8+floor(wave/10)` 改为最多 12 架，刷波只按剩余名额生成；弹珠碰撞先用子步线段 AABB 对整机和单格粗筛，仍保留原最近格精判/扫掠。极端 60 秒持续飞行（例如纯水平球）有回收兜底，不动 5% 递归分裂机制。
  - **3D 碎块与重建**：本地体素碎块由渲染器按出生顺序和 1.2 秒寿命显式回收，24 个预算不再依赖可能过时的计数或扫描体素世界；体素创建后中途出错主动回收孤儿。冻结只有实际换色时触发网格重建；空闲粒子批次/瞄准线跳过重复 `Commit`。新局时清理上局同 ID 可见对象，避免错误复用。
  - **验证边界**：官方多人构建成功并上传预览；Linux 无体素模块，本地真渲染 850 帧无 Lua/overlay 错误，只覆盖 `CustomGeometry` 回退。合成负载（12 架、20 弹、200 帧）`Game.Update` 旧版 7.8202s → 优化版 0.1784s；固定种子命中旧新均 score=100、broken=1、alive=128、events=5。该数值不是手机 FPS。LSP daemon unavailable，未声称 0 Error；后期体素实机性能和碎块清理仍待 Preview 量测。
- 版本: 0.12.12（局内车型逐步解锁）：
  - **开局仅有分裂车**：`Game.lua` 的 `unlockedBalls` 每局重置为 `{normal=true}`；`NextBallType` 固定顺序跳过未解锁车型，开局待发车与储备队列均只含分裂车。冰冻/加速/巨型各新增一张一次性「解锁××车」升级卡，选中后把新车插入队首（下一发可见，不修改当前待发/飞行车辆），后续补弹纳入循环；重开新局重新锁定。
  - **专属强化门控**：升级定义加 `ballType`（分裂裂变核、冰冻深寒涂层、加速疾速引擎+超载核心、巨型重型化），`CanOfferUpgrade` 同时用于保留卡、加权抽选、候选不足回填和最终选卡；未解锁车型的专属卡不会进池，解锁后立即纳入。通用卡与全弹通用 `word` 不误锁；已解锁的解锁卡不再出现。快照新增 `unlockedBalls` 供渲染只读。
  - **界面**：四槽原位置不变，未解锁车置暗+「锁／待解锁」，已解锁仍显示待命/待发/库存；顶部提示改「升级解锁车辆 · 拖拽发射」（旧「点击切换」在规则里并不存在）；升级卡显示「新车型 · 本局解锁」。最小 Dock 回退也展示锁定态。BUILD_VERSION 和大厅版本→0.12.12。
  - **验证**：官方多人 build+预览上传成功，本地真实规则探针从敌机碎块正常获得 XP 并抽到两张解锁卡，核对开局单车、未解锁专属卡不入池、解锁即插队、重开复位；真渲染探针进战斗零 `overlay stage failed`/零 Lua 错误，截图非空。⚠️ 随机卡池未保证一局内三车全部解锁；真机 Dock 锁态观感待 Preview。Lua LSP 服务仍不可用，未声称诊断通过。并发性能优化已由其他会话独立提交 e010e1c/9c441a2，本批次保留不覆盖。
- 版本: 0.12.11（HUD 失踪真凶落网：Lua 前向引用 nil 调用 + 错误处理器自身崩溃）：
  - **真根因（本地真渲染复现 + 日志实锤，订正 v0.12.10 的大厅时序误判）**：v0.12.9 在 `DrawAmmoSlots`（~948 行）新增 `DrawIcon(ctx, ammoIcons[ballType], ...)` 调用，但 `DrawIcon` 的 `local function` 定义在其后（~1147 行）——**先用后声明的 local 函数解析成全局 nil**（AB-100 同类）。战斗中该阶段每帧抛 `attempt to call a nil value`；更致命的是错误处理器 `ReportOverlayStageError` 也犯同一错误（定义在 RenderOverlay 之后）→ stage 的 pcall 接住原始错误后调用它 → **再抛一次** → 整个 NanoVGRender 回调崩溃、`nvgEndFrame` 被跳过 → **该帧全部 NanoVG 绘制被丢弃**；菜单不经过这两个调用点所以正常，一进战斗 2D 全灭、只剩 3D——三张用户截图的完整解释。日志里此前只见 `attempt to call a nil value (global 'ReportOverlayStageError')`，原始 stage 错误被吞。
  - **修复**：两处都改为 AB-100 前向声明模式——`local DrawIcon = nil`（DrawAmmoSlots 之前）+ 后置定义改赋值 `DrawIcon = function(...)`；`local ReportOverlayStageError = nil`（ApplyOverlayDesignTransform 之前）+ 后置改赋值。全仓库前向引用扫描器（local function / local x = function，调用点早于定义）复扫 **0 问题**（Scene3DBackend/MetaUI/client_main 及全部 scripts）。BUILD_VERSION→0.12.11、大厅标题栏同步。
  - **本地真渲染验证链路（本次新建，务必复用）**：`URHO3D_PREFIX_PATH=/workspace/.cli LD_LIBRARY_PATH=/workspace/.cli .cli/UrhoXRuntime <script> -tapcode_dir=<probe项目> -tool_mode -graphicssurfaceless -screenshot=<png> -screenshot-frame=<N>`（llvmpipe + GLES3.1 离屏真渲染并截图；普通模式缺 .cli/Data 会段错误 139，**必须 -tool_mode**）。探针工程在 `/home/Maker/urhox-probe-live/`（scripts+assets 拷贝 + probe_play.lua 自动开局探针）。⚠️ 该运行时**每个脚本实例只保留一个 Update handler，后订阅者顶掉先订阅者**——探针订阅 Update 必须手动链式调用游戏自己的 `_G.HandleUpdate`，否则游戏主循环静默不跑。修复后本地截图确认：战斗 HUD 三栏/波次横幅/道具标签/弹药矩阵四卡全部渲染、零 stage 失败、零 Lua 错误。
  - 验证：本地离屏截图（菜单 + 战斗）✅、全库前向引用扫描 0 ✅、官方多人 build + 预览上传 ✅。⚠️ 待 Preview：真机进战斗确认 HUD/弹药栏恢复。
- 版本: 0.12.10（大厅 UI 上下文自毁时机）⚠️ **根因判断已被 v0.12.11 订正**：当批次的 `shutdownLobbyUI` 提前到 onProgress>=1 的改动保留（顺序确定性属于良性加固，符合 AB-117），但它**不是** HUD 失踪的原因；真凶是 v0.12.11 记录的前向引用 nil 调用。原文如下：
  - **根因（两张"战场有、2D 全没"截图 + 源码/库证据闭环）**：`nvgCreate` 是**全局单例**（`GetNanoVGContext` 文档自述 lazy singleton alias for nvgCreate），urhox-libs/UI 内部 `nvg_` 与 `Scene3DBackend.vg_` 其实是**同一个 NanoVG 上下文**，"双上下文"模型不成立。真正的危险是反向的：`UI.Shutdown()` 内部 `nvgDelete(nvg_)` 会把共享上下文整个销毁。v0.12.7 重写大厅时把成功路径改成只 `stopWaiting()`、`shutdownLobbyUI()` 留给引擎的 `stop()`——引擎不保证在切脚本后**立刻**调 stop：stop() 晚于 `ClientMain.Start` 跑，`UI.Shutdown` 的 nvgDelete 把游戏刚拿到的上下文连带销毁（订阅挂在对象上，随后 nvgCreate 复用底层单例但旧事件订阅已断），症状=3D 正常、NanoVG 输出归零、无任何 stage 错误日志（回调根本没再触发）。此前 AB-093/088c 的"先 Destroy 再 Shutdown"防的是降级双起，但**把 Shutdown 推迟到 stop() 恰恰制造了这个新坑**。
  - **修复**：`lobby_runtime.lua` onProgress>=1（连接完成、即将切脚本）当场 `shutdownLobbyUI()`（幂等，stop() 路径保留原样作兜底）——把两条 stop() 时序收敛为唯一安全顺序：销毁大厅订阅+上下文 → 引擎切换 → 新脚本 `nvgCreate` 拿到干净单例。BUILD_VERSION→0.12.10、大厅标题栏同步。验证：多人 build+预览上传 ✅；⚠️ **待实机验收**：进战斗 HUD/弹药 Dock/暂停页是否恢复（预览日志应见 `[Lobby] server connection completed` 后紧跟 `[Scene3DBackend] NanoVGRender callback active`，且无 overlay stage failed）。
- 版本: 0.12.9（高端 dark-tech UI 全局精修 + 8 张量化像素素材 + NanoVG HUD 容错）：
  - **素材规格先锁，再生成 8 张（遵循 `0718-pixelimage-aigc` + `dark-tech-game-editor-ui`）**：【项目建议】全部图标母版 32×32、显示 1×原生尺寸、透明、固定 8 色（#10131F/#252A3A/#555B6C/#9FA6B3/#F1EEF0/#00E5D0/#009694/#FFC448）。4 张高级奖品图标：补给箱/档案盾徽/能量核心/转盘奖章；4 张弹药专属剪影：分裂核心/冰锥弹头/加速弹体+速度刻线/巨型装甲球。nanobanana 256×256 草案经 bbox 裁切→LANCZOS 降到 32×32→alpha<128 透明化→8 色最近邻量化，全部实测 32×32/9 色（8 色+透明）→8 个 .meta 22hex UUID 全库无重复。最终成品 `assets/image/ui_{premium_supply_crate,premium_pass_crest,premium_energy_core,premium_wheel_medal,ammo_split_core,ammo_frost_shard,ammo_velocity_coil,ammo_giant_shell}.png`，草案移出 assets 到 `/home/Maker/ui_premium/drafts/`，不进入包。ICON_PATHS 用 `NVG_IMAGE_NEAREST` 注册，全部可选资源。
  - **全局机加工暗舱表面材质**：`DrawMachinedPanel`（短幅微渐层 + 外描边 + 内槽线 + 2 个黄铜铆点 + 1 个稀疏局部电路刻纹）取代旧单层平色 `DrawWindowShell/DrawBluePanel`；电路刻纹只在 w>150 且 h>w*0.14 的宽面板使用、位于右上边缘且 alpha 14–25，短卡/文字区不画，避免干扰信息。进度条统一 `DrawPixelBar/DrawPremiumProgress`（黑槽、描边、轻高光、宽条 24px 分段刻痕）；NanoVG 原生，不新增外部依赖。
  - **战斗 HUD / Dock**：HUD 三栏固定（x=14 分数、x=264 波次连击、x=384 基地耐久），分隔线明确，右上暂停按钮几何保持原样；删掉挤在一起的「云已同步」长尾，把云状态改 HUD x=140 的 5px 状态点。底部四槽加四张弹药图，图标按原生 32×32 NEAREST 显示，文字/待发态收敛，增加「弹药矩阵」「点击切换·拖拽发射」和细刻线。玩法与命中区域未变。
  - **暂停/档案/转盘/补给**：暂停去掉不适合手机的「按 P」提示，主标题「暂停控制台」+ 状态，5 项广告补给行统一成 48px 图标/标题/效果/广告状态 pill，继续与回主菜单出口原几何不变；战斗档案重排为「精英航空档案」英雄卡（大等级、本级奖励、进度刻度、免费/精英轨）+ 5 条里程碑奖励（能量核心图、奖励数字、领取状态），按钮 hit rect 跟随行偏移一起改；转盘改为仪表盘式 8 扇区、固定奖针、24 个黄铜/青色刻度、中央奖章，抽取命中按钮位置原样保留；每日补给弹窗变为补给箱英雄区+领取方式分区，两个按钮含实际奖励数，点击几何保持原值。
  - **主菜单**：开始战斗 CTA 外加黄铜机加工导轨与原生 32px 补给箱图标，按钮原命中几何不变；其余闭环三段式结构保留，钱包货币/充值图标各 32×32 原生尺寸。
  - **新截图暴露的战斗 HUD 丢失**：截图时间 18:06 早于当前预览构建；运行日志/服务端不可取，因此**尚未证实根因**。防御性加固：`RenderOverlay` 的 letterbox/world-FX/HUD/Dock/modal/banner 各 stage 独立 pcall，每阶段重设 transform/scissor，`nvgEndFrame` 单独保护；HUD 或 Dock 失败时画最小可读回退。NanoVGRender 订阅与首个快照状态仅各打一条诊断日志，便于下一轮确认回调是否触发。⚠️ v0.12.10 已证实：真因是大厅 stop() 时序（见 v0.12.10 条目），本批次 stage 容错与最小回退作为纵深防御保留。
  - BUILD_VERSION→0.12.9。验证：官方多人 build ✅、预览上传 ✅、8 PNG 均进 dist manifest、.meta UUID 无重复、`git diff --check` 干净；LSP daemon 持续 unavailable（child PID 7 code 1），build 明确 skip LSP gate，未宣称 LSP 通过。⚠️ 待 Preview：战斗截图确认 HUD/Dock 恢复、档案/转盘视觉密度、8 图原生像素观感。
- 版本: 0.12.8（主菜单像素字标轮播批次：AI 生图 → 0718 管线后处理 → 每 5 秒切换）：
  - **像素字标成品图（用户指定用 `0718-pixelimage-aigc` skill，并要求"图标太无聊，没有游戏元素介入"）**：`batch_generate_images`（nanobanana, 1344×768 草案, 4 seed）出 4 张「击碎飞机」字标，每张融合游戏元素（①重卡弹道击碎「碎」字+右上 8bit 敌机；②小货车点状弹道+飞碟+橙色碎块；③「击」字裂纹+invader 嵌在飞字前+底部砖墙被撞穿；④像素弹丸撞碎「碎」字+俯冲小敌机）。后处理按 skill 管线手写定制脚本（skill 自带 postprocess.py 只支持方形母版，字标需按内容纵横比）：包围盒裁切 → LANCZOS 等比缩到 **120 高母版**（宽 207/235/244/264 随字标比例）→ alpha 二值化(128) → **7 色 dark-tech 量化**（#10131F 轮廓/#252A3A 影/#009694 青暗/#00E5D0 青/#7FF2E6 青亮/#F1EEF0 白/#FFFFFF，全 ≤9 色达标）。成品 `assets/image/ui_logo_{a,b,c,d}_20260929162106.png` + 22hex uuid .meta（已验重、已进 dist manifest）。草案 png 已移出 assets（→ /home/Maker/logo_pp/drafts，不占包体）。
  - **主页轮播（用户指定：进主页随机一个、每 5 秒变化）**：`Scene3DBackend` 新增 `LOGO_PATHS`（含逐图宽 w）/`LoadLogoTitles()`（Init 里 LoadIcons 之后调，`nvgCreateImage(..., NVG_IMAGE_NEAREST)`，**可选资源**：全失败也只是回退，不进 Init 成功条件）/`PickLogoImage(elapsed, uiStateEnter_)`——`(floor(t/5)+logoRollOffset_) % n + 1`。`logoRollOffset_` 在 `UpdateUiState` 检测到进入 menu 态时 `math.random(0,3)` 摇一次（⚠️ 只在状态切换摇，禁止每帧 random）。`DrawMenu` ①区改：有字标则 `nvgImagePattern` **1× 等比居中**（lx=(w-图宽)/2, y=90..210，与断线 218/CTA 262 无冲突，已用 PIL 合成图验证），无字标回退 `DrawPixelLogo` 整串 zpix。BUILD_VERSION→0.12.8。
  - 验证：多人 build（内置 LSP 语法检查）🎉 成功 + 预览上传；4 张字标 + uuid 均进 dist manifest；云端 `lua_lsp_client` 本时段不可用（build 第 4 步已覆盖语法校验）。⚠️ 待 Preview：字标真机 NEAREST 硬边观感、5 秒轮播节奏、随机起点效果。
- 版本: 0.12.7（截图反馈整改批次：大厅换皮 + logo 空框修复 + 开局零自动弹窗 + 签到并入充值 + 钱包语义修正）：
  - **大厅加载页 dark-tech 换皮（用户否决裸 UI）**：`lobby_runtime.lua` 重写为窗口壳风格——深底 COL 令牌、panel 窗口（cyanDim 边 + 46px 标题栏：青识别条 +「击碎，飞机大战」+ 右侧版本号）、1px 断线、状态文案「正在连接服务器」+ 青色进度 fill + 「N 秒后自动进入单机模式」倒计时 + 三扫描点随机闪。状态迁移：onMatchFound→「正在接入战斗服务器」+setFill(0.5)；onProgress>=1→「连接完成，正在进入」+stopWaiting；SN onError / client OnError→「服务器不可用/连接失败，进入单机模式」。⚠️ urhox-libs/UI **无 ref 机制**：控件全部先建局部变量再组装进 children；`SetText`/`SetStyle` 动态更新用 pcall。契约保留：`shutdownLobbyUI()`（hideBanner+Destroy+UI.Shutdown+UnregisterHandler）、五秒兜底、banner 换皮通道。
  - **logo 空框修复（用户截图点名「还是个空框」）**：v0.12.6 的 `DrawPixelLogo` 用 utf8.codes **逐码位**在 104px 下渲染，zpix 位图字体超大号逐字退化成空心框（只剩阴影层成框）。改回**整串一次 nvgText + 右下硬偏移阴影双层**（与 36px 旧版同一条已验证路径）。BUILD_VERSION→0.12.7。
  - **开局零自动弹窗（用户二次否决）**：删除 `TryShowPremiumPassOffer`（v0.12.5 的付费轨主菜单 banner）与菜单自动弹补给 modal（`supplyPrompted`）及 `premiumOfferShown_`/`balanceReceived_` 门控——`HandleUpdate` menu 分支不再开任何弹窗；ShowSystemBanner 通道只服务平台 SystemNotification。付费轨解锁收回 `DrawPass` 内紧凑金按钮（`GetPassUnlockRect` 右上 140×40，affordable→「N 钻石解锁」/不足→「钻石不足」/离线→「需联网」，`HitTestPass` 先于奖励行返回 `buy_premium_pass`）。菜单「养成收藏」行删金框新手礼包顶替槽，固定 4 卡（open_shop/open_pass/open_codex/open_rank）。
  - **每日签到并入充值界面（用户指定）**：`RechargeShop` 顶部常驻 signIn 行（56px：可签时 cyan 边+左侧 3px 识别条+signin 图标+「每日签到」+「已连续 N 天 · 今日 +X 零件」+「签到/今日已签到」按钮），`HitTest` 返回 `"signin"`（经 `HandleRechargeAction` 自然穿透到 `HandleMetaAction` 的 signin 分支）。首充礼包行与签到行共存时布局 `GetLayout(w, showFirstGift)` 重排：signIn 常驻 shift 64、gift 68、spendStep/spendH 压缩 62/56（全开末行底 798 < retry 820 推演过）。菜单「今日福利」行剩 3 卡（补给/任务/转盘），`row()` 按数量水平居中。
  - **钱包条语义修正（用户两次点名同一截图「这里有问题」）**：删「零件 → 钻石」误导箭头（零件不会兑换成钻石，方向反了）——改左零件余额块/中钻石余额块/右**金色实心「充值」按钮**（`wb={x=L.wallet.x+L.wallet.w-112,y=L.wallet.y+10,w=96,h=36}`，`HitTestMenuBar` 整条仍 open_recharge）。
  - **backdrop 铺满连锁**：菜单无 HUD 后 RechargeShop backdrop 从 (0,92) 改 (0,0,w,960)。
  - 验证：Lua LSP 0 Error（15 files 538 诊断 0 error）、多人 build+预览上传成功。⚠️ 待 Preview：大厅换皮实机、logo 整串渲染观感、充值界面签到行、钱包条新排布。
- 版本: 0.12.6（主菜单重设计批次：像素大 logo + 菜单去 HUD + 变现闭环三段式）：
  - **像素超大打字 logo**：`DrawPixelLogo`（UTF-8 逐字排版、104px、首尾青/中间白、右下硬偏移阴影，zpix 程序化，无外部图片）。短名 `GAME_SHORT_TITLE="击碎飞机"` 用于 logo；对外全名 `GAME_TITLE` 契约不变（窗口/发布名仍「击碎，飞机大战」，logo 下方小字带全名）。
  - **菜单态隐藏战斗 HUD**：`RenderOverlay` 只在 `game.state ~= "menu"` 时画 `DrawHud`（分数/波次/防线对局读数不属于首页）；菜单改全屏自绘（bg 实心 + 角标/断线/微型网格），窗口壳与「本局目标」填充块删除；`DrawSupplyPopup` backdrop 从 y=92 改铺满 0..960（旧值假设 HUD 存在）。
  - **变现闭环三段式**（用户选定方案）：`GetMenuBarLayout` 全部重排——图鉴剪影展示条(y390, 8 机 data-driven 青=已收录, 点击进图鉴) → 钱包连接器(y496, 零件→钻石→充值, 整条点击开充值) → 「今日福利」行(y588: 签到/补给/任务/转盘, 免费青·广告绿) → 「养成收藏」行(y716: 商城/档案/图鉴或首充礼包/排行, 付费金)。`GetDailyDefs/GetGrowDefs(meta)` 纯函数供绘制与命中同源；`HitTestMenuBar` 完全由这两个 defs + layout 驱动（新增 fleet→open_codex）；首充限时窗内 third 槽被「新手礼包」顶替。卡片为竖构：图标居中 + 名称 + 一行 sub。
  - CTA「开始战斗」(y262 高 92) 保留松手确认（startArmed 通道不变）；toast y=904→848。BUILD_VERSION→0.12.6。
  - 验证：LSP 0 Error、多人 build+预览上传。⚠️ 待 Preview：logo 在真机 zpix 下的字距/阴影观感、三段式卡片信息密度、菜单无 HUD 后弹窗遮罩。
- 版本: 0.12.5（真机反馈整改批次：广告收敛 + 出口闭环 + 换皮通知 + 道具竖列 + 图标增强）：
  - **升级面板广告大瘦身（用户否决 v0.12.4：「广告多到玩家会骂娘」）**：删除选卡倒计时/+30 秒广告/超时自动选卡/看广告解锁第 4 张/单卡升格/额外再选全部 5 触点；`Game.Update(dt)` 恢复单参数。面板只剩 2 个广告位：免费重抽 + 看广告重抽必出稀有，另有卡片「锁定/保留」（免费）。`GetUpgradeChoices` 不再补 `__locked__` 占位卡；规则层删 `PickExtraChoice/ExtendUpgradeTime/CanUnlockFourthChoice/UnlockFourthChoice/CanBoostChoice/BoostUpgrade/CanArmExtraPick/ArmExtraPick`；`HitTestUpgradePanel` 只剩 reroll_free/reroll_ad/hold(先于卡体)/card。
  - **局内道具改右上角竖列**：`GetItemPanelLayout()`（收起标签 `{x=DESIGN_W-52,y=100,w=44,h=36}`，展开 3×52 槽 `y=146+(i-1)*58`）；`itemPanelOpen_` 由后端持有，`Backend.ToggleItemPanel/SetItemPanelOpen/IsItemPanelOpen`；`HitTestItemSlot` 返回 `("toggle"|"slot"), index`。收起标签带青色数量角标/绿色可领点；GrantItem 成功后保持展开。
  - **广告期间自动暂停玩法**：`HandleUpdate` 里 `AdService.IsInFlight() && state=="playing"` 时跳过 `Game.Update`（表现层照常衰减，画面冻结）；广告结束自然恢复，不弹旧状态。
  - **暂停页补真出口**：移动端无键盘曾完全没有暂停入口——HUD 右上角新增 28×28 暂停按钮（`GetHudPauseRect`/`HitTestHudPause` 同源，playing 态才画，缺图程序化双竖条回退）；暂停页底部补「继续战斗/返回主菜单」按钮行（`layout.resume/menu`，y=740）；规则层新增 `Game.GoToMenu()`（playing/paused/gameover → menu，Emit game_reset）。
  - **结算页补回主菜单**：`GetGameOverButtonLayout` 第四行 `menu`（rowPair 宽、y=616，窗口壳内），`HitTestGameOverButton` 返回 `"menu"`，编排层 `menuArmed` 松手确认。菜单「怎么玩」文案由「按 P 暂停」改「右上角按钮暂停」（移动端指引不能写键盘）。
  - **平台系统通知换皮（图二否决）**：游戏与大厅两处 `SystemNotification.RegisterHandler`，把 `Resolve(info)` 画成 dark-tech **顶端通知条**（`Backend.ShowSystemBanner/HitTestSystemBanner/HasSystemBanner`，HUD 下方 y=100、tone 左竖条、X 关闭、error 类不显示退出钮、exitOnClose 类带「退出」→`engine:Exit()`），banner 在 RenderOverlay 最上层、按 `gameSnapshot.elapsed` 差分计时（TickSystemBanner 在 UpdateScene）。大厅版用 urhox-libs/UI 绝对定位 Panel + 自维护 15s 计时，`shutdownLobbyUI` 里 hideBanner + `UnregisterHandler`。ClientMain.Start 注册（pcall）、Stop 反注册。⚠️ 两个 Runtime 各注册一次，切脚本会清 handler 槽。
  - **付费档案轨顶端通知化（图一否决）**：DrawPass 删除常驻大解锁行（`GetPassPremiumRect` 整体移除）；改为主菜单一次性顶部 banner（`TryShowPremiumPassOffer`，须 `balanceReceived_` 才弹——SetGemsListener/SetPurchasedPartsListener 都会置位，否则 gems=0 误报「钻石不足」；affordable→「立即解锁」复用 buy_premium_pass，不足→「去充值」）。`onBannerAction` 在 HandleMetaAction 之后赋值（同文件 local 前向引用）。
  - **图标与界面增强（用户追加需求）**：新增 4 张 32×32 dark-tech 像素图标（pause/home/barrier/levelup，均带 .meta 22hex uuid、进 dist manifest）；HUD 等级行加 levelup 图标（xp bar 100→116 宽缩至 112）、防线读数左移 36 让位暂停钮、零件加倍并入零件行；暂停/结算出口按钮带 home 图标 + 程序化播放三角。BUILD_VERSION → 0.12.5。
  - 验证：Lua LSP 0 Error、多人 build+预览上传成功、新图标全部进 manifest、uuid 无重复。⚠️ 待 Preview：换皮通知条实机（需真触发平台通知）、广告在途冻结、道具竖列点按、付费轨 offer 曝光时机。
  - ⚠️ v0.12.4 条目中的「选卡倒计时/+30秒/第4张解锁/升格/额外再选」已被本批次整体删除，仅保留卡 hold 存活。
  - ⚠️ 本条目的「付费档案轨主菜单一次性 banner（TryShowPremiumPassOffer）」已被 v0.12.7 删除（开局零自动弹窗），解锁收回 DrawPass 面板内按钮。
- 版本: 0.12.4（三十图补齐批次：升级变现闭环 + 首充礼包 + 付费档案轨 + 大厅生命周期加固）：
  - **升级面板三新机制（com_lvup_05/08）**：①「锁定已有卡保留到下次」——`Game.heldUpgradeId` + `Game.ToggleHeldUpgrade(index)`（卡片左上「锁定/保留」角标，hit kind `hold`，与升格角标同层级先判）；下次 `RollUpgradeChoices` 把保留卡放首位（保留卡为稀有时空转 forceRare 配额），重抽面板仍保留、选卡或换卡即清。②「选卡倒计时」——`UPGRADE_SECONDS=8`，`Game.Update(dt, upgradeTimerPaused)` 在 levelup 态倒数、超时 `RandomInt` 自动选一张真实候选（不含第 4 张占位）；面板顶部画剩余条+秒数，「看广告 +30 秒」一次（`Game.ExtendUpgradeTime`，hit kind `timer_ad`）。⚠️ 广告在途时必须暂停倒计时（编排层传 `AdService.IsInFlight()`，不能用 `IsBusy()`——3s 冷却期会把面板冻住），否则看广告回来卡被自动选了。
  - **首充新手礼包（com_menu_02）**：`Shared.FIRST_GIFT`（sku `first_gift_6`、24h 限时窗、本地补发 parts 500 + skin arctic、服务端发货 gems 100+first_gift 标志）。`PlayerData` 新增 `firstGiftClaimed`/`createdAt`（云合并 createdAt 取更早）；服务端 `serverCloud.money.first_gift` 标志；`PURCHASED_PARTS_SYNC` 现携带 premium/first_gift 双标志，客户端收到 first_gift=1 且本地未补发时一次性发皮肤零件并 `MarkFirstGiftClaimed`（幂等，离线补发）。RechargeShop 顶部横幅行（限时倒计时+¥价格+购买），`GetLayout(w, showFirstGift)` Draw/HitTest 同开关保证几何同源。
  - **付费战斗档案轨（com_menu_08）**：`GEM_SPENDS` 新增 `pass_premium`（100 钻石一次性，`grantCurrency=premium_pass`）；服务端先查标志、已购回 `already_owned`，事务扣钻+MoneyAdd 标志；客户端 `Client.GetPremiumPass()`；MetaUI DrawPass 双轨显示（未解锁→金按钮「N 钻石解锁」kind `buy_premium_pass`；已解锁→奖励 ×2 显示 `+X 零件（base ×2）`）；`PlayerData.ClaimPass(level, multiplier)`。Button 新增 `gold` kind（金色=钻石付费三分语义）。
  - **大厅生命周期修复（真机灰屏/UI 零星根因）**：`lobby_runtime.lua` ①降级统一 `shutdownLobbyUI()`＝`view:Destroy()`+`UI.Shutdown()`（urhox-libs/UI 是进程级 NanoVG 单例+自动事件订阅，`view:Destroy()` 不销毁上下文；不先销毁就 `ClientMain.Start` 会让 Scene3DBackend 建第二个 nvgCreate 上下文，同帧双 BeginFrame 合成不稳 = 历史「2D 页面全没」根因）；②`onProgress>=1` 立即 `stopWaiting()` 撤销五秒兜底防双起竞态；③`stop()` 成功路径同样清 UI 上下文；④起游戏失败打 FATAL 日志。`ClientMain.Start` 加 `started_` 幂等守卫（重复进入直接返回 true，防双订阅双 Update），`Stop()` 复位。
  - 验证：Lua LSP 0 Error、多人 build+预览上传成功。⚠️ 待 Preview 验收：五秒降级双上下文修复后 2D 完整性、选卡倒计时/自动选卡、保留卡跨面板传递；⚠️ 首充与付费轨真实支付仍被 IAP 白名单 403 阻塞，`first_gift_6`/付费档商品未在平台创建。
  - **三十图判定为平台强冲突跳过项**（.emmylua 无 Share/Friend API）：com_menu_06 好友榜切换、com_ingame_10 分享战绩按钮——引擎无对应能力，不做假按钮。
- 版本: 0.11.4（新手下拉手势提示）：
  - **手势图**：`assets/image/ui_hand_pull3_20260925153601.png`（256×384 RGBA，dark-tech 青色线稿，**右手握拳、食指斜朝左上**）。`Scene3DBackend` 用 `nvgCreateImage(vg_, "image/...png", 0)` 在 Init 加载一次，**可选资源**——失败只打日志跳过提示，绝不纳入初始化成功条件。⚠️ 手指方向必须是斜朝左上（下拉起手的姿态）；垂直向上或带向上箭头都与「向下拖拽」语义冲突，第一版即因箭头+垂直被弃用。
  - **触发条件**：规则层 `Game.lua` 新增 `hasLaunched`（`LaunchMarble` 置 true、`ResetGame` 复位），快照输出 `s.showPullHint = playing and not hasLaunched and not aiming`。玩家一拖拽就消失，发射过就永不出现。
  - **动画**：`DrawPullHint` 在弹弓车辆上方循环 1.6s——手沿 9 点青色虚线从上方下移到发射位（已滑过的点更亮更大），淡入/淡出，末尾跟一行「向下拖拽 松手发射」。
  - 验证：LSP 0 Error、多人 build 成功、资源已打进 dist manifest（uuid 与 .meta 一致）。⚠️ 环境 HDR Bloom shader 编译失败致离屏截图发白，需 Preview 验收动画。
- 版本: 0.11.3（修复联网客户端敌机体素失色）：
  - `Renderer3D.lua` 将敌机主体和飞散碎块显式创建为 `LOCAL` Volume；`SetPaletteEntry`/`SetPaletteEntryPBR`/`SetPaletteCutColor` 与 `GetPaletteMaterial` 统一指定 `VOXEL_PALETTE_LOCAL`，避免客户端本地体素从空的 Local 色板取色。规则层和逐格修复日志未改。
  - 验证：Lua LSP 0 Error、官方多人构建成功、色板/体积/材质域静态契约通过；Linux 本地无体素模块且多人模式不适用单机离屏验证，**Preview 战斗态色彩尚待目视确认**。
- 版本: 0.11.2（防线双线：紫线回原位 + 新增红线标扣血点）：
  - **两条线各司其职**：`DangerBand` 紫线回到**原位置** `Vector3(0, -8.0, 0.9)`（保留既有观感，不跟规则走，只做受击/Boss 警示）；新增 `BreachLine` 红线，每帧按快照 `gameSnapshot.dangerY` 刷 y、z=0（与敌机体素同平面），精确落在 `brickBottom > DANGER_Y` 的扣血瞬间。
  - **红线样式**：Diff (0.95,0.16,0.20) + 常驻自发光 (0.85,0.10,0.14)，线体 0.055；受击时加粗变亮。
  - **紫线常驻自发光**下调到 (0.26,0.09,0.46)，避免抢红线的注意力。
  - 验证：LSP 0 Error、多人模式 build 成功。⚠️ 离屏截图受环境 HDR Bloom shader 编译失败影响整屏发白，需 Preview 确认两条线的相对位置。
- 版本: 0.12.0（单机间接联机骨架 + 氪金代币）：
  - **架构**：`main.lua` 变成纯分流入口（`IsServerMode()` → `network.Server`；否则 → `game.client_main`）。原 929 行玩法编排整体搬到 `scripts/game/client_main.lua`，`HandleUpdate/HandleRender/HandleMouse*/HandleTouch*/HandleKey*` 保持**文件级全局 function**（`SubscribeToEvent` 按名字解析，加 `local` 会静默失效）。
  - **服务端只做两件事**：IAP 发货（`Shop.onDeliver` → `serverCloud:BatchCommit` + `orderId` 幂等/离线补发）+ 钻石余额（`serverCloud.money`）。不做场景复制、不跑战斗。`scripts/network/Server.lua` 用 `.meta {c_or_s:"s"}` 标记，不打进客户端包。
  - **氪金代币「钻石」**：唯一服务端权威货币。客户端只申请（`IAPGemSpend`），扣款在服务端 `MoneyCost`，成功后才由客户端发本地软货币。余额经 `IAPBalanceSync` / `IAPBalanceDirty` 推送。
  - **大厅**：`scripts/lobby_runtime.lua`（urhox-libs/UI，1 人秒开 + 5s 超时）→ 成功由引擎切游戏脚本；超时/失败 `GameMode.SetOffline(true)` → `local_game.lua` → `ClientMain.Start{offline=true}`。⚠️ `stop` 只 `UnsubscribeFromEvent` 自己订阅的，禁止 `UnsubscribeFromAllEvents`。
  - **离线只认 `GameMode.IsOffline()`**：禁止用 `IsNetworkMode()`（大厅启动后恒为 true）。云存档/云高分/排行榜/充值在离线路径全部短路。
  - **UI 无污染**：大厅用 urhox-libs/UI（进游戏后 `root.children={}` 拆掉）；标题/战斗/HUD/充值弹层全部沿用原 NanoVG dark-tech 令牌。充值弹层 `scripts/ui/RechargeShop.lua` 通过 `MetaUI.RegisterScreen` 插件注册，复用 `MetaUI.GetDeps()` 的令牌与原语，不反向 require。
  - 验证：Lua LSP 0 Error、官方 build 成功（多人模式 1 人秒开）。⚠️ 待 Preview/真机验收：大厅流程、内购商品开通。
- 版本: 0.11.0（商业化 P1+P2+P3+部分 P4）：
  - **三色语义落地**：新增 `C.ad` / `C.adDim`（绿＝看广告），与青（主操作/进度）、金（稀有）三分。所有「看广告」按钮一律绿色，免费领取一律青色。
  - **`PlayerData.lua`**：软货币「零件」、每日签到（7 天递增 100→300）、每日任务（击碎 300 / 抵达第 8 波 / 完成 3 局）、敌机图鉴、皮肤、统计；本地 `player_data.json` + `clientCloud` 字符串云同步（合并取大值）。新增通用每日计数器 `GetDailyCount/AddDailyCount`（转盘/补给/广告礼包限次）。
  - **`AdService.lua`**：激励视频统一调度（在途锁 + 3s 冷却 + 一次性完成 + `embed manual close` 归失败）。`main.lua` 所有广告走此处。
  - **`MetaCatalog.lua`**：元层静态数据（8 机型图鉴文案与收录奖励、5 款车辆皮肤配色与售价、商城广告礼包、转盘奖池与权重、每日补给基数 150）。
  - **`MetaUI.lua`**：元层界面绘制 + 命中（依赖注入拿 `Scene3DBackend` 的颜色令牌与绘制原语，样式同源）。主菜单商业区（货币栏/四入口/签到/每日补给）+ 任务/图鉴/排行榜/商城/转盘 5 个面板 + 每日补给弹窗。
  - **升级面板**：免费重抽 1 次/局、看广告重抽（含卡池升格保底稀有）、看广告解锁第 4 张（优先神秘词条，画成下方宽卡）、单卡升格（生效 ×2）、本次额外再选一张。
  - **结算**：击碎 +1 / 清机 +10 / 过波 +25 零件，出现即 ×1 入库 + 看广告双倍；结算页三按钮（复活/双倍/再来一局）。
  - **局内 P4（部分）**：HUD 右上「零件 +N」实时计数；暂停面板「战场补给站」——看广告防线急救 +25 血（1 次/局）、看广告下个强化必出稀有（1 次/局）。
  - **图鉴解锁**：`Game` 记录本局清掉的机型（`runAircraft`），结算时写入 PlayerData 并发放首次收录奖励。
  - **命中几何同源**：`Backend.HitTestUpgradePanel` / `HitTestPausePanel` / `HitTestMenuBar` / `HitTestMetaScreen` / `HitTestSupplyPopup`，`main.lua` 不再自持任何 UI 几何常量。
  - 验证：Lua LSP 0 Error、官方 build 成功、截图对照设计稿确认（菜单商业区/商城/转盘/每日补给弹窗）。
- **待做（P4 剩余）**：局内道具槽（看广告获取即时道具）、轨道支援（Boss 战广告支援）、局内零件 ×2 增益卡。
- 商业化设计稿 v0.11.0-design：30 张 UI mockup 落在 `assets/image/com_*.png`（主菜单 `com_menu_*` / 局内 `com_ingame_*` / 升级三选一 `com_lvup_*` 各 10 张）。
- 版本: 0.10.40（体素更新时序与幽灵块修复）：
  - `Game` 更新后在 `Update` 中同步场景与体素；`NanoVGRender` 仅绘制覆盖层，防止 3D Viewport 已渲染才提交几何。
  - 体素主体逐格对齐规则快照，不再靠短命飞散箱事件标记整机签名；变化时每机同帧单次重建，并验证占用、输出 `[Renderer3D][voxel-repair]` 修理日志。
  - 验证：Lua LSP 0 Error、官方 build 成功；Linux 运行时无体素模块且离屏报告/截图未落盘，Preview 命中后目视验收待做。
- 上次交付: v0.12.11 HUD 失踪真凶修复（Lua 同文件 local 函数前向引用 nil 调用 ×2 + 本地真渲染复现链路；v0.12.10 大厅时序结论已订正）

## 本批次新增避雷（后期负载治理 e010e1c/9c441a2）
- ⚠️ **不能把后期卡顿直接归为 GPU 3D**：每弹每帧 6–16 子步遍历全部敌机砖块，原同屏上限 `8+floor(wave/10)` 无界且可整波超额，CPU 玩法碰撞也会拖慢 3D 和 UI。先比较同屏敌机/弹珠数和规则/渲染时段，再定位 draw calls。现在机群最多 12 架，刷波按剩余名额补。
- ⚠️ **体素碎块的 Lua 计数不能代表真实体积数**：世界有自动年龄回收，本层原 `voxelDebrisCount_` 只增不随自动回收递减。现在本层登记每个创建的碎块，先于引擎自动回收时限按 1.2 秒删除，按出生顺序裁至 24；切回 `CustomGeometry` 或 Shutdown 时清理自身碎块，禁止重新扫描全 World 并猜索引和遍历顺序。Linux 无体素模块时该路径仍待真机测。
- ⚠️ **冻结重建条件要与实际换色一致**：体素仅 `freezeRatio>0.35` 才换色，后备网格只判断是否仍 `enemy.frozen>0`，不可用每 1/8 衰减比例都重建整机网格；每格死亡仍需同帧重建，保留 `[Renderer3D][voxel-repair]` 日志。

## 本批次新增避雷（v0.12.11 前向引用真凶 + 本地复现链路）
- 🔴 **同文件 local 函数前向引用会解析成全局 nil——本项目已两次踩雷（v0.12.11 实锤）**：`local function X` 声明在其使用点**之后**时，使用点读到的是全局 `X`（nil）。v0.12.9 一次踩两处：①`DrawAmmoSlots`（948）调用后置定义的 `DrawIcon`（1147）→ 战斗中每帧 `attempt to call a nil value (global 'DrawIcon')`；②错误处理器 `ReportOverlayStageError` 也是先用后声明 → stage pcall 接住①后调用它再次抛错 → **整个 NanoVGRender 回调崩溃、nvgEndFrame 被跳过、该帧全部 2D 绘制被丢弃**（菜单不经过该死点所以正常）。修法固定为 AB-100 模式：用点前 `local X = nil`，后置定义改 `X = function(...)`。**交付前跑全库前向引用扫描**（匹配 `local function N` / `local N = function` 与其前的调用点），本次复扫 0 问题。
- 🔴 **本地真渲染复现链路（诊断「3D 正常、2D 异常」的银弹，先复现再推理）**：`URHO3D_PREFIX_PATH=/workspace/.cli LD_LIBRARY_PATH=/workspace/.cli /workspace/.cli/UrhoXRuntime <script相对scripts> -tapcode_dir=<探针项目> -tool_mode -graphicssurfaceless -screenshot=<png> -screenshot-frame=<N> > run.log 2>&1`。要点：必须 `-tool_mode`（普通模式找 .cli/Data 会段错误 139）；加 `stdbuf -oL -eL` 防 stdout 缓冲丢日志；探针工程用 scripts+assets 拷贝（`/home/Maker/urhox-probe-live/`），不污染 /workspace。**判读法**：letterbox 颜色 = C.bg(7,11,20) → 覆盖层活着；(0,0,0) → 覆盖层没画；整块画布纯 C.bg 无内容 → 走了首帧兜底（快照没到）。日志搜 `Execute Lua function failed` / `overlay stage failed`。
- ⚠️ **探针订阅 Update 的陷阱**：该运行时每个脚本实例**只有一个 Update handler 槽，后订阅者顶掉先订阅者**（实锤：探针订阅后 `client_main.HandleUpdate` 完全不再被调用、无报错）。探针必须只订阅一个 handler，内部显式链式调用 `_G.HandleUpdate(eventType, eventData)`。
- ⚠️ **Shell heredoc 会把正则里的 `!` 改写成 `\!`**（本地实测）：`(?<!...)` 负向断言写进 heredoc 变成 `(?<\!...)` 导致 `re.error` 崩溃，且退出码 1 时工具可能不显示任何输出——排查「无输出的 exit 1」先怀疑脚本自身崩了；规避：正则不用 `!`，或先落盘脚本再执行。
- ⚠️ **诊断顺序教训（v0.12.10→v0.12.11）**：拿到「3D 正常、2D 全没」别先做架构归因推演（上批次误判为大厅 stop() 时序并据此改了代码）；本地跑一次真渲染、看 `Execute Lua function failed` 的实际行号与符号名即可分钟级定位。截图只用于确认症状边界（菜单 vs 战斗）。

## 本批次新增避雷（v0.12.10 HUD 全消失真因）
- 🔴 **NanoVG 上下文是全局单例，"双上下文抢帧"心智模型作废（订正 v0.12.3/v0.12.4 的机制描述）**：`nvgCreate` 与 `GetNanoVGContext` 是同一底层对象；urhox-libs/UI 内部 `nvg_` 与 raw NanoVG 后端 `vg_` 拿到的是**同一个 ctx**。危险是反向的——**`UI.Shutdown()` 里的 `nvgDelete(nvg_)` 会销毁共享上下文**。若大厅 Shutdown 发生在游戏 `Backend.Init` 之后（引擎不保证切脚本后立刻调旧脚本 `stop()`），游戏侧订阅挂在已销毁对象上、后续 `nvgCreate` 复用单例但旧事件绑定已断 → **3D 正常、全部 2D 静默消失、零报错**。
- 🔴 **自建大厅所有切脚本路径必须当场幂等 `shutdownLobbyUI()`**：匹配成功 onProgress>=1、降级 goOffline、stop() 三条路径都调用（`uiShutdown` 守卫），禁止把 Shutdown 只留给引擎 stop()——stop() 时序不可控。降级路径"先 Shutdown 再 Start"，成功路径"先 Shutdown 再让引擎切换"。
- ⚠️ **诊断模板（2D 缺失三分类）**：有 `Execute Lua function failed` → 启动期崩溃断订阅（AB 旧条目）；**零错误日志且 2D 全无** → 查共享上下文生命周期（谁 nvgDelete 了单例，本案）；零星元素 → 查字符串订阅失效/上下文抢帧。本次保留的 RenderOverlay stage 容错+最小回退+首帧日志即为此设计：能直接区分"回调未触发"与"某 stage 抛错"。
- ⚠️ **同症状族变体别沿用旧结论**：v0.12.4「零星元素」当时归因双上下文，其修复（Destroy 时不 Shutdown）反而酿成 v0.12.9 全消失。先穷举生命周期时序再选修复点，且修复幂等收敛所有路径。

## 本批次新增避雷（v0.12.8 像素字标轮播）
- ⚠️ **AI 生图≠像素素材成品，必须过管线后处理才能进包（v0.12.8）**：高分辨率草案（1344×768）直接进资源会带抗锯齿/颜色漂移/主体占比失控。`0718-pixelimage-aigc` 管线：包围盒裁切 → LANCZOS 缩母版 → alpha 二值化(阈值 128) → 色板量化（映射到项目色板，可见色 ≤9）。字标这类非方形主体别用 skill 自带 `postprocess.py`（它 `--master` 只支持正方形），按内容纵横比手写（固定高、宽=round(高×宽高比)）。
- ⚠️ **像素图运行时装载三铁律（v0.12.8）**：①加载必须 `nvgCreateImage(..., NVG_IMAGE_NEAREST)`，默认线性过滤会糊；②显示尺寸只能是母版的整数倍（本项目母版=显示尺寸 1×，禁止非整数拉伸）；③多张字标纵横比不同时，逐图存各自宽度 w 居中绘制，不要强塞同一矩形。
- ⚠️ **轮播的随机起点只在状态切换摇一次（v0.12.8）**：`UpdateUiState` 检测 `state=="menu"` 时 `math.random(0,3)` 写 `logoRollOffset_`；索引 `(floor(t/5)+offset)%n+1`。禁止每帧 random（会疯狂跳变）；t 用 `game.elapsed - uiStateEnter_`（进菜单归零）。
- ⚠️ **装饰性大图一律可选资源（v0.12.8，同 v0.11.4 手势图）**：`LoadLogoTitles` 全失败也不能崩 Init 成功条件，`DrawMenu` 无字标回退 `DrawPixelLogo` 整串 zpix 大字。缺图=UI 全没/卡死的头号诱因。
- ⚠️ **沙箱坑：`/workspace/.tmp` 被 root 占（drwxr-xr-x 不可写）**，临时脚本/中间产物写 `/home/Maker/`；`Write` 工具对 /workspace 外路径也可能报 Internal error，改小段 `printf >> file` 或写 /home/Maker。

## 本批次新增避雷（v0.12.7 截图整改）
- 🔴 **zpix 位图字体逐字绘制在超大字号退化成空心框（v0.12.7 实测）**：`DrawPixelLogo` 曾用 utf8.codes 逐码位 nvgText 画 104px 中文，真机只剩阴影层是框、主层空白——大字号必须**整串一次绘制**（36px 旧版即此路径），想做首尾异色也别拆单字（可拆「前缀串+后缀串」两段整串，不能拆单码位）。
- 🔴 **urhox-libs/UI 没有 ref 机制，别用属性回取控件（v0.12.7）**：构建后 `view.children` 下标遍历或 `ref=function(w)` 都拿不到（库源码无此支持，恒 nil）。需要动态更新的控件**先建局部变量再组装进 children**；`SetText`/`SetStyle` 调用 pcall 包裹防库行为差异。
- 🔴 **开局禁止任何自动营销弹窗（v0.12.5 banner→v0.12.7 二次否决）**：用户点名「把开局的 1 首充弹窗去了」——付费轨 offer 从主菜单自动 banner 再收回 DrawPass 面板内紧凑按钮；自动弹补给 modal（supplyPrompted）一并删。营销触点只能存在于**玩家主动打开的面板**里；`ShowSystemBanner` 通道从此只服务平台 SystemNotification，不再复用给商业推广。
- ⚠️ **平行货币条别画兑换箭头（v0.12.7 用户两次点名）**：「零件 → 钻石」箭头暗示零件能兑钻石（实际方向相反：钻石兑零件/充值得钻石），误导即缺陷。两种余额各自成块，获得途径交给明确的「充值」按钮，别用连接线脑补兑换关系。
- ⚠️ **弹窗并入后布局要推演最坏堆叠（v0.12.7）**：签到行常驻 + 首充限时行共存时 RechargeShop 内容高度 798 逼近 retry 按钮 y=820——新增行时把 spendStep/spendH 设条件压缩并在注释里留下底边数值推演，防止只测单行态。

## 本批次新增避雷（v0.12.6 主菜单重设计）
- ⚠️ **菜单态隐藏 HUD 后，所有假设「顶部有 92px HUD」的层都要自查（v0.12.6）**：`RenderOverlay` 里 menu 态不再画 `DrawHud`，凡是遮罩/弹窗从 `HUD_HEIGHT(92)` 起画的（如 `DrawSupplyPopup` 的 backdrop）会在顶部留 92px 不遮断的缝——全屏模态一律从 0 起铺满。改渲染分层时 grep `MENU_CONTENT_TOP`/`HUD_HEIGHT` 找齐依赖方。
- ⚠️ **变现入口重组走「defs 纯函数」模式（v0.12.6）**：把两行卡片的 action/icon/label/sub/hot/tone 收进 `GetDailyDefs(meta)/GetGrowDefs(meta)` 纯函数，绘制遍历 defs+layout、`HitTestMenuBar` 用同一对 defs+layout 判定——新增/挪动入口只改 defs，命中永不漂移。行标签字符串禁止参与分支判断（用 rects 数组而不是给 rowDef 塞单 rect 再特判）。
- ⚠️ **对外全名契约与 logo 短名分开（v0.12.6）**：像素大标题用 `GAME_SHORT_TITLE`（4 字才撑得起 104px），但窗口标题/发布名/CTA 下方小字仍是「击碎，飞机大战」——别把 D-052 的对外名契约"顺手"改成短名。
- ⚠️ **闭环式变现要有"连接器"视觉（v0.12.6 用户拍板）**：玩家看不出零件/钻石/充值的关系=没整合。钱包条做成「零件 →(箭头) 钻石 →充值」横排，福利行标「今日福利」、消耗行标「养成收藏」，三色边框（青免费/绿广告/金付费）直接落在卡片描边上，语义一眼分层。

## 本批次新增避雷（v0.12.5 真机反馈整改）
- 🔴 **激励视频在途必须冻结玩法推进（v0.12.5）**：浏览器 embed 覆盖时游戏 Update 循环照常跑，广告回来敌人已压线。正确门控在编排层 `HandleUpdate`：`AdService.IsInFlight() && snapshot.state=="playing"` 时跳过 `Game.Update`，表现层照常衰减。⚠️ 不要用 `IsBusy()`（含 3s 冷却）——会把广告关闭后的 3 秒也冻住；结算/升级/暂停态本就停玩法无需处理。
- 🔴 **平台 SystemNotification 换皮要在「两个 Runtime」各注册一次（v0.12.5）**：全局只有一个 handler 槽且切脚本会清掉——大厅（lobby_runtime）与游戏（ClientMain.Start）都要 `RegisterHandler`，离开时各自 `UnregisterHandler`（大厅在 `shutdownLobbyUI` 统一做）。handler 必须只接管画得出的 kind，未知 id 返回 false 让 Host 兜底；返回 true 就必须自己提供关闭途径（X 或限时）。error 类只提示，exitOnClose/kicked 才给「退出」→ `engine:Exit()`。
- 🔴 **一次性营销提示走顶部通知条，不做常驻大面板行（v0.12.5 图一否决）**：付费档案轨解锁从 DrawPass 大行改为 `Backend.ShowSystemBanner` 顶部条。**曝光前必须等余额首推**（`balanceReceived_`：SetGemsListener/SetPurchasedPartsListener 都置位），否则 gems=0 误报「钻石不足」；每会话只弹一次（premiumOfferShown_），有 banner 占位则不弹（HasSystemBanner）。
- ⚠️ **banner 计时不能用 dt 累计在 Draw 里做（v0.12.5）**：RenderOverlay 可能因快照缺失停帧；统一用 `gameSnapshot.elapsed` 差分（TickSystemBanner 在 UpdateScene 调），菜单/暂停态 elapsed 也持续递增。banner 命中永远最先消费（TryBannerAt 在 Down 处理器最前），点条体=关闭。
- ⚠️ **移动端 UI 禁止键盘指引文案（v0.12.5）**：「按 P 暂停」在真机无法执行——暂停入口必须是 HUD 可见按钮（GetHudPauseRect 与绘制同源、playing 态才画、缺图程序化回退），文案改「右上角按钮」。凡是 PC 快捷键提示都要问「手机上怎么办」。
- ⚠️ **回主菜单出口三态共用一个 Game.GoToMenu()（v0.12.5）**：playing/paused/gameover → menu 并 Emit game_reset（Presentation fullReset 已映射）；升级态必须先选卡，不允许中途离开。结算与暂停页出口都走松手确认（menuArmed），防死亡瞬间误触。
- ⚠️ **同文件 local 函数前向引用（v0.12.5）**：`onBannerAction` 若在 `HandleMetaAction` 之前用 `local function` 定义会捕获 nil；正确做法是前面 `local onBannerAction = nil` 声明，后面 `onBannerAction = function(...) ... end` 赋值（闭包引用的是同一 upvalue）。
- ⚠️ **Lua 运算符优先级 `+` 高于 `and/or`（v0.12.5 复发）**：`r.y + (owned or def.canGrant) and 6 or ...` 会把 boolean 参与加法运行时崩。条件偏移要么加括号，要么写进分支。
- ⚠️ **新图标资源三件套缺一不可（v0.12.5）**：PNG + 同名 `.meta`（22 位 hex uuid，别写 24 位与既有不一致）+ ICON_PATHS 注册；构建后用 dist manifest grep 文件名确认打包；uuid 全库唯一（grep -ho uuid *.meta | uniq -d 验重）。

## 本批次新增避雷（v0.12.4 三十图补齐 + 大厅双上下文）
- 🔴 **urhox-libs/UI 是进程级 NanoVG 单例：换渲染接管方前必须 UI.Shutdown()（v0.12.4 根因）**：大厅挂 `ctx.root` 的 UI.Panel 背后是 UI 自己的 `nvgCreate(1)` 上下文＋自动 Update/Render/输入订阅；`view:Destroy()` 只拆控件树**不拆上下文**。降级起游戏前不 `UI.Shutdown()`，Scene3DBackend 会建第二个上下文，同帧两套 BeginFrame/EndFrame 交替，真机表现「2D UI 只剩零星元素/全没」。所有降级/stop 路径收敛到一个 `shutdownLobbyUI()`（pcall Destroy + pcall UI.Shutdown），禁止只写一处。
- ⚠️ **五秒兜底必须在连服完成时撤销（v0.12.4）**：`onProgress>=1` 后引擎即将切游戏脚本，若计时继续跑会在切换竞态窗口里抢跑 `goOffline()` 本地起一局（双起）。匹配成功即 `stopWaiting()`。
- ⚠️ **ClientMain.Start 必须幂等（v0.12.4）**：降级路径与引擎脚本切换可能各调一次 Start；无 `started_` 守卫会重复 SubscribeToEvent → Game.Update 每帧跑两遍（双倍 dt、双倍事件）。
- 🔴 **升级倒计时不能被广告冷却暂停（v0.12.4）**：`Game.Update(dt, upgradeTimerPaused)` 编排层必须传 `AdService.IsInFlight()`（在途锁），不能传 `IsBusy()`（含 3s 冷却）——冷却期冻结面板会让玩家无法操作且倒计时不动，语义错乱。超时自动选卡只从真实候选 `RandomInt(1,#upgradeChoices)` 抽，第 4 张锁定占位不参与。
- ⚠️ **保留卡（heldUpgradeId）与升格/解锁是三种不同状态（v0.12.4）**：「锁定已有卡保留到下次」≠「看广告解锁第 4 张占位」；保留卡在新面板 `RollUpgradeChoices` 首位重现，选完或重抽换卡即清；重抽面板保留卡仍占首位（防白锁）。UI 角标命中 hold 必须在 boost 之前判，否则左上角标点成升格。
- ⚠️ **一次性兑换商品要在服务端事务前查已购标志（v0.12.4）**：付费档案轨 `pass_premium` 先 `serverCloud.money:Get` 判断 `premium_pass>=1` 回 `already_owned`，否则重复点会重复扣钻；普通钻石兑换（累计额语义）不需要此防重。
- ⚠️ **首充礼包发放幂等靠本地标志+服务端标志双保险（v0.12.4）**：`firstGiftClaimed`（本地/云，随 BatchCommit 发货推送补发）＋服务端 `first_gift` money 标志；限时窗基准 `createdAt` 云合并取两台设备更早值。真实商品 `first_gift_6` 尚未在平台创建（IAP 白名单 403），构建通过不代表可支付。
- ⚠️ **RechargeShop 布局行开关必须 Draw/HitTest 同参（v0.12.4）**：`GetLayout(w, showFirstGift)` 首充行存在时其余分区下移 68px；两边传同一个条件，禁止只在 Draw 判可见。

## 本批次新增避雷（v0.11.4 新手引导）
- ⚠️ **新手提示必须由规则层给"是否已操作过"的标志，别让渲染层猜（v0.11.4）**：`Game.lua` 的 `hasLaunched` 在 `LaunchMarble` 置 true、`ResetGame` 复位，快照出 `s.showPullHint = playing and not hasLaunched and not aiming`。渲染层只读，不自行判断"玩家是否操作过"。玩家一拖拽（`aiming`）提示即消失，发射过就永不出现。
- ⚠️ **UI 用的图片资源是可选依赖（v0.11.4）**：`nvgCreateImage(vg_, "image/xxx.png", 0)` 失败只打日志并跳过该 UI 元素，**绝不**能进 `Backend.Init` 的成功条件——否则缺图会导致整个后端启动失败（UI 全没 + 卡死）。图片放 `assets/image/`，路径从 assets 根写起（`image/...`），且必须同时有 `.meta`（uuid），构建才会打进 manifest。

## 历史
- 版本: 0.11.1（扣血线同源修正）：紫线曾一度改为跟规则线，见下条避雷的「z 投影」根因。

## 历史
- 版本: 0.10.40 体素权威占用与渲染时序修复。

## 历史
- 版本: 0.10.39（升级卡文案压缩）：详情一句短话、字号 17、卡名 22，卡片几何仍 168×300@cy530。

## 历史
- 版本: 0.10.37（修存活机幽灵块）：Update 晚于体素世界步进，挖空必须同帧 SetSolid + RebuildGeometry。
- 版本: 0.10.35（全面加大玩家 UI 字号）：
  - 标签/辅助字 8–11 → 12–16，正文 12–14 → 15–18，标题 22–28 → 26–32。
  - 升级卡详情 11→13，卡名 14→18；卡片几何仍 168×300@cy530，命中区未改。
  - 飘字基础尺寸 20→26。验证：LSP 0、build 成功。

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
- likely_next_task: 在多人 Preview 战斗态确认敌机主体与飞散体素碎块恢复各机型原色（冻结颜色也需确认），并验收扣血红线与紫线。
- 相关文件: `scripts/Renderer3D.lua`（EnsureVoxelPalette / CreateEnemyVolume / SpawnVoxelDebris）, `scripts/VisualCatalog.lua`（GetVoxelMatIndex）。

## 本批次新增避雷（v0.11.3 客户端本地体素颜色）
- ⚠️ **体素色板域必须匹配 Volume 的有效 CreateMode**：本项目战斗只在客户端本地运行；`LOCAL` 的敌机 Volume 读取 `VOXEL_PALETTE_LOCAL`，而 `SetPaletteEntry*`/`GetPaletteMaterial` 省略 domain 时默认 `VOXEL_PALETTE_REPLICATED`，会导致机身与碎块失色。敌机主体/碎块 `CreateVolume(..., Quaternion(), LOCAL)`，色板基础色第五参、PBR 第六参（无自发光要先传 `Color(0,0,0,0)`）、断面色第三参、材质第二参均须显式指定 Local 域；bank 仍为 0、格子材质仍为 VisualCatalog 的 1–64 槽位。LSP/构建不能证明多人 Preview 颜色已恢复，需在真机看战斗态。

## 本批次新增避雷（v0.11.2 防线双线 / v0.12.0 单机间接联机）
- ⚠️ **视觉警示线与规则判定线是两条线，别合并（v0.11.2）**：玩家要的是「紫线留在原位置当防线标记 + 另加一条红线标真正的扣血点」。**禁止**为了“对齐”把既有紫线挪走——那会破坏玩家已习惯的观感。正确做法是两条并存：紫线固定原坐标只做警示（受击/Boss 变亮），红线每帧按规则值刷新。
- ⚠️ **规则基准线必须与判定同源、且与敌机同 z 平面（v0.11.2）**：46° 斜俯视正交相机下 **z 会投影到屏幕 Y**——同 XY 不同 z 屏幕 Y 不同。红线用 `z=0`（与敌机体素同平面）、`y = (DESIGN_H*0.5 - dangerY) * 0.018`，才精确落在 `Game.lua` 的 `brickBottom > DANGER_Y` 瞬间；写死近相机 z（如 0.9）会偏移约一行砖。横线 x 必须居中 0，**不能**用 `WorldFromGame(0, y)`（它的 x=-4.86 会把线整体左移）。
- ⚠️ **深空场景的细线要常驻自发光（v0.11.1）**：本场景很暗，纯漫反射的细长盒几乎不可见（玩家报「那条线是不可见的」）。基准线这类必须一眼可辨的元素要加 `MatEmissiveColor` 常驻底光，受击/Boss 再在其上叠加，而不是只在 flash 时才有亮度。两条线并存时，次要那条的底光要压暗，避免抢焦点。
- ⚠️ **离屏截图整屏发白 ≠ 你的改动有问题（v0.11.1 实测）**：本环境 llvmpipe 下 `BloomHDR(... TONEMAP_LUT)` 编译失败（`texture3DLod` no matching overload），HDR 渲染链断掉导致截图为纯白，与业务代码无关。判断时先看日志有没有该 shader 编译错误，别拿白图当回归证据；这类改动最终要靠 Preview 目视验收。

## 本批次新增避雷（v0.12.3 自建大厅修复 / v0.12.0 单机间接联机 / v0.11.0 商业化）
- 🔴 **「自建大厅」≠「官方大厅」，别把两者混为一谈（v0.12.3 订正 v0.12.2 的错误结论）**：`lobby_runtime` 是**开发者自己写的脚本**，不是平台默认大厅 UI。玩家明确要求「不使用默认联机大厅的任何形式」= 不用官方那套 UI，但**保留自建大厅这条启动路径**。⚠️ v0.12.2 曾据此把整层删掉改成 background_match，是**过度反应**，已恢复。判断标准：`lobby_runtime` 里怎么画由你决定（本项目=纯 NanoVG 自绘 dark-tech，零 urhox-libs/UI）；要避免的只是「引入平台默认 UI 框架」。
- 🔴 **切换 NanoVG 上下文的时序：先销毁旧的，再建新的（v0.12.3 根因）**：大厅降级进本地游戏时，**必须先 `nvgDelete(vg)` 再调 `ClientMain.Start`**。漏掉这一步会让同一帧内两个 NanoVG 上下文各画各的 `BeginFrame/EndFrame`，合成顺序不稳定，真机表现为「**游戏 UI 只剩零星几个元素 / 2D 页面全没**」。把「销毁自己 → 起游戏」抽成一个 `GoOffline()`，所有降级路径共用，禁止在多处各写一遍。
- 🔴 **`UnsubscribeFromEvent` 必须用单参数形式（v0.12.3 实测报错）**：签名有 `(eventName)` 与 `(sender, eventName)` 两个重载；传 `UnsubscribeFromEvent("Update", handler)` 会被解析成后者 → `argument #1 is 'string'; 'userdata' expected`。只退订事件名时写单参数。
- ⚠️ **灰帧类问题的排查输入是「时刻」而不是「描述」（v0.12.2 教训）**：「变灰了一下」会让人去猜主题或渲染层；「**倒计时到 3 之后**变灰」直接钉死是「切换那一帧」。遇到这类反馈先问清**时刻 / 时长 / 触发动作**，能省好几轮。
- ⚠️ **内购只走 serverCloud 是对的，但 serverCloud 需要服务端进程（v0.12.2）**：`Shop.onDeliver` → `serverCloud:BatchCommit` + `orderId`（原子幂等 + 离线补发）是官方唯一正确做法，客户端不能写别人的钱。但**发货回调必须有一个服务端进程在跑**——这才是在单机游戏里接入服务端的唯一理由。


- 🔴 **「3D 正常但 2D 界面全没」的头号原因是启动期崩溃，不是渲染层（v0.12.1 实测）**：`ClientMain.Start` 在中途抛错（本次是 `NetClient.Start` 为 nil）会**中断后续所有 `SubscribeToEvent`**，而 3D 场景是 `RenderBackend.Init()` 建好的静态画面，于是看起来「3D 在、2D 全无」。**排查顺序：先在日志里搜 `Execute Lua function failed` / `attempt to call a nil value`，再怀疑渲染。** 防御：联机/可选子系统一律 `pcall` 包裹并降级，禁止让它们有能力中断游戏启动。
- 🔴 **模块里的 `function Start()` / `function Stop()` 是全局函数，会覆盖入口的 Start/Stop（v0.12.1 实测）**：`network/Client.lua` 写成 `function Start()` 后，`require` 会把它挂到 `_G.Start`，覆盖 `main.lua` 的入口 `Start`；随后 `Module.Start()`（Module 是模块表）为 nil → 崩。**被 `require` 的模块必须写 `function Module.Start()`**；`main.lua` 是唯一允许定义全局 `Start`/`Stop` 的文件。
- ⚠️ **事件订阅优先用函数引用（v0.12.1 加固）**：`SubscribeToEvent("Update", HandleUpdate)` 传函数值，不要传 `"HandleUpdate"` 字符串。字符串形式按文件作用域解析，处理器换文件或入口搬迁后可能静默失效。渲染后端已改成自持 `NanoVGRender` 订阅（订阅/处理器/快照三者在同一文件内闭环），不再依赖入口脚本里的 `HandleRender`。
- ⚠️ **离线判断只认 `GameMode.IsOffline()`（v0.12.0）**：`IsNetworkMode()` 在大厅启动后**恒为 true**，即使匹配超时降级本地也仍是 true。用它判离线必然出错。
- ⚠️ **服务端脚本必须用 `.meta {c_or_s:"s"}` 标记（v0.12.0）**：`scripts/network/Server.lua.meta`。否则服务端专属代码会打进客户端包。服务端禁止 require 任何渲染/HUD/商店 UI/玩法模块。
- ⚠️ **氪金代币的扣款只能在服务端（v0.12.0）**：客户端 `IAPGemSpend` 只是「申请」，服务端 `serverCloud.money:Cost` 才是权威；扣款成功后才由客户端发本地奖励。发货必须 `serverCloud:BatchCommit` + `orderId`（幂等 + 离线补发），禁止用 `clientCloud` 发货。
- ⚠️ **两套云职责分离（v0.12.0）**：`clientCloud` = 自己的排行榜/成就/养成存档（客户端读写自己）；`serverCloud` = 钻石发货与余额（服务端读写任意 userId）。**禁止**因为「已经联机了」就把排行榜/成就搬到服务端——本作没有防作弊/售卖绑定/代写他分的需求。
- ⚠️ **大厅的 `stop` 只退订自己的事件（v0.12.0）**：`UnsubscribeFromEvent(name)`，**禁止** `UnsubscribeFromAllEvents()`（会误伤即将启动的游戏）。大厅进游戏时用 `root.children = {}` 交出界面，不是销毁 root。
- ⚠️ **服务端专属全局要走 `_G` 取（v0.12.0）**：`Shop` / `SERVER_MAX_PLAYERS` / `SERVER_REGISTERED_PLAYERS` / `SERVER_TICK_RATE` 只在服务端脚本环境注入，直接引用会让 LSP 报未定义全局、也让「客户端打包同文件」时语义不清。用 `local g = _G --[[@as table]]; g.Shop` 取用。
- ⚠️ **面板的插件式注册（v0.12.0）**：`MetaUI.RegisterScreen(name, draw, hit)` 让外部弹层（如 `ui/RechargeShop.lua`）接入既有 screen 分发，靠 `MetaUI.GetDeps()` 复用颜色令牌与绘制原语。这样 MetaUI 不需要反向 require 业务模块，避免循环依赖与样式漂移。

## 本批次新增避雷（v0.11.0 商业化 P1+P2+P3 / v0.11.0-design 设计稿）
- ⚠️ **绿色＝看广告，青色＝免费/主操作，金色＝稀有（v0.11.0 落地）**：`C.ad / C.adDim` 是新增令牌。所有 `sdk` 激励视频入口（复活/双倍/重抽/四选一/升格/额外选/防线急救/稀有保底/广告礼包/转盘/补给双倍）必须用 `C.ad`；免费领取（签到/任务领取/直接领补给）用 `C.cyan`；稀有度与数值徽标才用 `C.warn`。⚠️ 禁止再用金色画广告按钮——玩家分不清「哪个要花钱、哪个看广告就行」。
- ⚠️ **元层面板的命中必须用纯几何函数（v0.11.0）**：`MetaUI` 里 `GetShellLayout(w)` / `GetBoostBadgeRect` 等是**不画图**的；`Shell(ctx,...)` 才画。⚠️ 命中函数里**禁止**调 `Shell(ctx=nil,...)`——它内部会调 `D.backdrop/D.text`，ctx 为 nil 直接崩。新增面板时照 `GetShellLayout` 的写法拆。
- ⚠️ **MetaUI 依赖注入（v0.11.0）**：`MetaUI` 不 require `Scene3DBackend`，靠 `MetaUI.Init{deps}` 拿颜色令牌与绘制原语（在 `Backend.Init` 里注入）。禁止在 MetaUI 里自己再定义一套颜色常量，否则样式必然漂移。
- ⚠️ **HUD 可用空位只有 y=74..90 的右侧带（v0.11.0）**：HUD 三行已满——(14,4/20/52) 分数与最高、(270,4/20/52) 波次与敌机连击、(528,4/20/48/64) 防线与血条、(14,70)+(100,74)+(236,70) 等级/经验条/经验。新增 HUD 读数只能放**血条下方 y≥74 且 x 靠右**（左半边被等级行占着）。⚠️ 曾把「零件 +N」放在 (14,70) 与「等级」重叠。
- ⚠️ **headless 截图文件大小恒定（v0.11.0 实测）**：`-screenshot` 输出的 PNG 是 1080×1920 未压缩存储（固定 8,305,983 字节），**文件大小与画面内容无关**，不能用大小判断截图是否更新或两次渲染是否相同。要看效果只能真的读图。
- ⚠️ **升级面板命中必须走 `Backend.HitTestUpgradePanel`（v0.11.0）**：`main.lua:TryPickUpgradeAt` 已删除自持的 cardW/cardH/gap/cy/HIT_PAD 常量，改为消费后端返回的 `kind,index`。kind ∈ `card|boost|reroll_free|reroll_ad|fourth|extra_pick`。⚠️ 升格角标**必须先于**卡片本体判定，否则点角标会被当成选卡。新增面板按钮时只改 `GetUpgradePanelLayout`，禁止在 main.lua 再写第二套几何。
- ⚠️ **第 4 张卡是「宽卡」不是第 4 列（v0.11.0）**：3 张主线卡仍是 168×300/gap8/cy530（y 380..680，视觉与命中都不变）；第 4 张画在下方 `extra` 矩形（x24,y692,w492,h104）。4 张卡横排会 696px 超出 540 画布，禁止把 `GetUpgradeCardLayout` 改成按 `#choices` 均分宽度。
- ⚠️ **广告只能走 `AdService`（v0.11.0）**：所有 `sdk:ShowRewardVideoAd` 调用集中在 `AdService.Show`（在途锁 + 3s 冷却 + 一次性 completed + `embed manual close` 归失败 + 未受理且无回调时自行收尾）。禁止在业务代码里再写裸 `ShowRewardVideoAd`，否则返回值和迟到回调两条路径会漏处理出重复发奖。
- ⚠️ **云变量只在编排层（v0.11.0）**：`PlayerData` 只提供 `ExportForCloud/ImportFromCloud` 字符串编解码，`clientCloud:Set/Get` 全部写在 `main.lua`。云合并取大值（parts/totalParts/highScore/codex/skins 并集），避免换设备回退进度。
- ⚠️ **零件结算幂等 + 复活重开（v0.11.0）**：`SettleParts` 有 `partsSettled` 守卫，`main.HandleUpdate` 每帧调用安全。⚠️ `ReviveFromAd` **必须**把 `partsSettled/partsDoubled/lastSettledParts` 复位，否则复活后继续赚的零件会被守卫吞掉。
- ⚠️ 商业化三色语义契约（v0.11.0-design）：设计稿起手确立、落地实现时不得混用——**绿色=看广告（免费获取）、金色=付费/稀有、青色=既有 dark-tech 强调色（焦点/主操作/进度）**。红色仍只留给错误/低血/危险预警，禁止拿红当促销色。
- ⚠️ 商业化设计稿不是实现（v0.11.0-design）：30 张 mockup 只是方向候选，`assets/image/com_*.png` 不参与构建逻辑。落地任一方案前必须重新对齐既有契约——升级卡几何仍 168×300/gap8/cy530 且与 `main.lua:TryPickUpgradeAt` 同源，新增按钮（重抽/升阶/解锁）**不得压掉卡片命中区**，HUD `y=0..92`、Dock `y=866..960` 也不得被商业化元素顶开。
- ⚠️ 广告触点密度上限（v0.11.0-design）：单局激励视频触点建议 ≤3–5 个，且禁止在死亡瞬间连弹两个广告（复活 + 结算双倍）。引擎侧只有 `sdk:ShowRewardVideoAd`，横幅/插屏无 API，设计稿里不要按插屏方案出图。
- ⚠️ 升级卡详情必须一句话（v0.10.39）：玩家把长描述称“小作文”。`UPGRADE_POOL.detail` 保持 ≤14 字左右、单句、含数字结果；具体数值交给 `value` 徽标，不要再在 detail 里重复解释机制。字号加大后卡片最多容 3 行。
- ⚠️ 玩家 UI 字号下限（v0.10.38）：标签/辅助≥15，正文≥17，标题≥28。v0.10.35 的 12/15/22 仍会被判定“不够”。加大字号时 HUD/Dock 高度与升级卡几何不要改。
- ⚠️ 体素渲染时序（v0.10.40，覆盖 v0.10.37 的事件式 HollowBrick）：`Update` 在物理步后但 3D Viewport 绘制前，Game.Update → Presentation.Update → Backend.UpdateScene（逐格以权威快照对齐 SetSolid/冻色、每机一次 RebuildGeometry）→ 3D 渲染 → `NanoVGRender` 只画 overlay。飞散箱有寿命/上限，仅用于碎块，不得用其事件挖主体后直接把整机签名对齐（同帧漏事件会留下永久幽灵块）。日志 `[Renderer3D][voxel-repair]` 记录 removed/added/rebuilt/grid；Linux 无体素模块时只可验回退，Preview 仍需命中目视验收。

- ⚠️ 对外游戏名必须是「击碎，飞机大战」（v0.10.34）：窗口标题、菜单主标题、`taptap_publish.title` 三处同步。内部代码注释/历史决策可保留旧名，玩家可见处禁止写「太空飞机弹珠」。
- ⚠️ 玩家 UI 必须中文优先（v0.10.33）：标题、按钮、HUD 标签、结算、升级提示用玩家能看懂的中文。dark-tech 装饰可以留，但禁止把 FLIGHT CONTROL / SESSION SEALED / HOSTILES 这类黑话当主文案。升级卡不要写「词条/已装配」，改成「特殊效果/已选」。

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
