# 击碎，飞机大战 — 项目核心记忆

> AI 自维护，每次 POST 自动更新。详细规则见 memory-system skill。

## 当前状态
- 版本: 0.13.40（恢复被过度削弱的暗科技质感与动态；审美仍待用户验收）：
  - 用户追加「还有更多的大贵效果被你删了。。。」：v0.13.39 恢复身份时同时削弱材质、受光和扫光，属于过度减法，不是用户授权。保留 Zpix/像素图标/深海军蓝/细框断线折角与真实六车，不回写实环境、MiSans或全窗半调，不擅自重开五轮。
  - PremiumSurface恢复同色族明显金属明暗、薄暗底座/柔影、顶部受光/底部暗边；按钮局部悬停柔光与浅亮边、3.2秒斜扫光/6秒亮流光，窗口标题舱光场、背景径向照明/顶青光/上下暗角，展台径向受光/同变换椭圆接触影/侧轨亮标与亮弧。MetaUI分区呼吸/空白断线流动重新接回；主CTA只补浅亮折角，不重复扫光。共享uiFx.anim，短按钮按尺寸钳裁剪，文字最后画，禁用/普通面板不假悬停。
  - 本批只修改四个Lua中的效果与展示版本，不改Game/Presentation/BattleHUD、车辆几何、价格/天赋/广告/IAP、输入命中/CONTAIN投影或资源所有权；无新增图片/字体/context。像素资产限色和二值alpha不扩张成NanoVG程序化工艺禁渐变。
  - 本人隔离快照十份最终真渲染通过（首轮窗口/升级卡超时后降低并发补测，超时不计PASS）：首页/商店/九元层与暂停及金色解锁、340高最坏卡完整两行、真实绘制长余额90/81px与Shop209≤240、多指鼠标失焦禁用/首页命中、Init与Stop-Start、六车门控/隐藏停更/30Hz、intro后发射与战斗长数道具。A/B固定相位扫光实图，按原图2040×1080的CONTAIN换算ROI有3671像素变化；首次按缩略图错误ROI得到0，已纠正，不为过测试改代码。目标Lua/overlay/load/空顶点/断言错误0，不等于全部引擎错误0。
  - 合并前后workspace LSP均0 Error（最终检查24文件875 Warning/107 Hint），官方多人build预览已上传；同步当前并发快照后串行首页/九窗口+暂停+金色解锁/intro后真实发射三项exit0，目标Lua/overlay/load/空顶点/断言0，首页与金色解锁实图目视完成。并发拖尾商店/PlayerData/Renderer3D等由其他会话负责，十份独立回归及三项合并冒烟不作为其功能验收；本批只暂存本人hunk及记忆片段，保留初始settings/VisualCatalog/记忆重排。Linux既有HDR/缺图/无体素使战斗3D黑场，手机FPS/全DPR/联网支付与用户审美仍未通过。
  - POST-1/2/3均执行：状态/版本/用户纠正与独立提交；随行更新AB-189的效果保全边界、补充素材规范作用域与真实原图ROI验收抗体。记忆规范skill当前未找到，按本项目明确的三步模板执行。

- 历史版本: 0.13.39（找回 dark-tech + 像素身份；后续用户指出质感效果被过度删除）：
  - 用户明确反馈「没有自己的风格会变得更便宜了」，指定 dark-tech-game-editor-ui 与 0718-pixelimage-aigc。v0.13.38 的通用正文/磨砂/写实环境没有获得审美认可；本轮按既有身份增强，不自行再开五轮、不整套回滚。
  - PremiumSurface改为Zpix同源测绘、深海军分层、小圆角细框、标题竖标/断线/折角；首页福利收藏卡重新各成可点边界、天赋入口实心青按钮，首页/商店改程序化技术展台，仍渲染真实六车。运行时不再加载写实环境或创建MiSans字体，旧两张环境PNG仍留磁盘，未宣称包体删除。去扩散投影/外发光/玻璃斜扫光及模态全窗半调，低频动态仅侧轨和按钮底边；青主操作/绿广告/金付费语义保持。
  - BattleHUD仅恢复宿主zpix，不动组件树/HP滞后/计分/四槽/道具/预告/首领规则。38张图标完整核对32×32、二值alpha、固定八色+透明；六张天赋图共40个额外亮青像素最小映射到品牌青，文件名/uuid/轮廓/透明度不变，字标单独色板保留。
  - 最终LSP24文件0 Error（845 Warning/105 Hint），官方多人build+预览上传成功；12份真实渲染日志无Lua/overlay/LoadChunk/空顶点/探针断言错误，首页/商店/九元层与暂停、最坏340高升级卡完整两行、19位钱包90/81px与商店完整数位209≤240px、真实TouchID0/第二指外结束/混合鼠标/右键Up/失焦/禁用/首页命中、direct Init/Stop-Start/重开draw、六车型门控/隐藏停更/30Hz通过。最终战斗长数字/库存道具与首领阶段2实图已内部目视、过intro真发射PASS；本地HDR shader/缺图/无体素既有错误仍在，战斗3D黑场不算通过，手机性能/全DPR/联网支付/用户审美未验收。
  - POST-1/2/3执行：项目状态/版本与独立提交，随行身份优先偏好及AB-189~190（风格恢复保技术安全、限色口径）。只提交本人五个Lua/六个像素修正与本人记忆片段，保留settings/VisualCatalog及记忆初始重排。Game/后端仍3202/3147行，不声称全面重构；行首local名字各197文本统计不替代实际编译（旧统计器误把函数参数算入）。

- 历史版本: 0.13.38（自主参考与连续五轮界面升级；技术通过，但后续用户否决风格流失）：
  - 用户在v0.13.32后仍「不够贵」，要求「你自己生成检索并对照实现。完成后再进行一次变贵，一个进行五次」。不再把参考搜集交给用户；五轮分别完成共享字体/磨砂表面、原创机库环境、首页信息主次、商店商品呈现、低频动效/状态与长数值适配。第一轮沿用并发0.13.33，后四轮展示35/36/37/38；不存在独立34预览包。
  - 新 `ui/PremiumSurface` 复用宿主NanoVG；MiSans正文/标题与像素Logo分层，测量与绘制按同字号选face。普通面板灰蓝受光细边、主操作青/广告绿/付费金，保留显式控件反馈；减少铆钉、青框、标题呼吸，主CTA保留扫光并加共享相位6秒底边流光。新机库/展台两张环境插画等比cover裁剪，首页只用单一机库，商店用横向展台，真实车辆仍由VehicleShowcase绘制，参考里的虚构车不进游戏。
  - 六浏览卡72高与独立购买区命中同源；不改售价、战斗属性、支付/广告/装备规则。FitText测到最低字号并返回fits，长余额超过宽度时钱包两行保留全数位；商店持有余额局部测宽，最低字号不继续缩。Surface图片在正常Shutdown、重复Init和失败清理中均先于宿主nvgDelete释放，环境缺图只局部降级。
  - 五轮均已官方多人build+预览上传、LSP 0 Error（仍有Warning/Hint）；最终真渲染已查首页/商店、九元层面板与暂停、最长升级卡完整两行、主TouchID=0/第二指画布外结束/混合鼠标/右键Up/失焦/禁用/渐灭、首页命中、六车型浏览与购买门控/隐藏停更/30Hz、直接Init及Stop-Start、环境缺图和礼包限次、横屏letterbox。19位余额两行实测87/79px，商店完整持有串234px≤240px。探针最初在Update中测字拿到无效尺寸，改真实绘制阶段测量后通过；不能沿用错误探针PASS。已目视内部实图；Linux既有HDR/缺图/无体素噪音不等于新Lua错误，手机帧率、联网支付和「够贵」审美未宣称通过。
  - 并发车辆结构与BattleHUD由各自会话独立提交，本批不代提交。POST-1/2执行；POST-3执行：自主参考/阶段验图偏好与AB-186字体测绘、AB-187环境cover、AB-188最低字号饱和抗体。大后端与Game仍超1500行，不把新增小模块声称为全面重构。

- 独立批次: 0.13.33-battle（战斗仪表舱精修；展示版本由并发商业化会话统一）：
  - 用户要求「优化战斗界面精致度科技感」。新增 `ui/BattleHUD.lua`，UI.Label/ProgressBar借官方 `UI.RenderWidgetSubtree` 嵌入宿主NanoVG帧，用同540×960 absoluteLayout复用树，不UI.Init/Render/SetRoot/Shutdown，不抢全局root/context，清理树早于宿主删除ctx。后端六个绘制入口委托，新增状态收进uiFx.battle，不增加主块local。
  - 三分区HUD、经验/耐久轨、0.32s掉血滞后段、得分跳动、四待发槽局部边缘动态、下一波预抽像素扫描、道具明暗/库存和首领阶段条；横幅期间不叠首领条。HUD92/Dock94/四槽64×64、暂停/道具几何未动，槽仅展示不伪装切弹。长最高分/零件分标签数字列+缓存测宽，角标进tab命中区；手势先投影再裁在Dock上方。
  - Game/Presentation/敌机/天赋/IAP/广告规则零改动。已有按下即暂停契约保留，不能承诺暂停按钮松手确认或持按反馈；新组件仅为该按钮补真实鼠标悬停反馈。使用道具再广告领取但本局不能再用的旧规则未在本批改写。
  - 验证：LSP0 Error、官方多人build+预览上传；普通/长数字/道具/首领阶段2实图内部目视，intro后真发射及HP保持→追平/得分复位PASS。真实输入/生命周期176断言174PASS/2FAIL：失败项是探针误期望按下仍playing/持按暂停，非新回归；实际暂停→继续、TouchID0/第二指/混合鼠标/失焦/用库存道具、开关/Shutdown-Init/live Init/Stop-Start、4树43控件不累积均PASS，Lua/overlay/LoadChunk/空顶点错误0，未调用广告SDK。独立HEAD配套版本冒烟也无Lua/overlay错误。
  - 边界：Linux BloomHDR既有shader错误使3D黑场；不声称本地3D、手机FPS、DPR全矩阵或用户审美通过。POST-1/2执行；POST-3两条通用UI混合/边界抗体执行，随行persona/preferences无新跨项目偏好跳过。本批hunk提交排除并发Surface/Menu/MetaUI/车辆及版本。

- 附记: vehicle-refine（2026-10-07，六车型结构优化；不另抢并发展示版本）：
  - 用户指定 `3d-vehicle-gen-ecnahc` 优化车辆；按现有六车型和项目局部 +X车头/Y轮距/-Z车顶适配，不套用案例的九车型、四轮或混搭系统。只改 `VehicleGeometry.lua`，战斗/首页/商店共用入口受益；默认重卡与装甲车仍六轮，其余四款四轮。四弹种、价格、存档权益、输入与渲染器世界缩放不变，未改材质。
  - 连续车壳与XYZ倒角、同壳参数贴面玻璃、真实轮洞/开放轮眉、胎肩/胎侧/凹轮圈/有厚度辐条、桥轴与控制臂、后视镜/尾翼/顶架/防滚架支脚补齐；修二次验证发现的机盖遮窗、踏板穿胎及沙地车轮眉/风挡连接。每车一个CustomGeometry、固定六section；等比拟合后重算法线，平面半径≤1.84/1.12，与既有0.98×1.12缩放配合保留2%碰撞余量。只缓存最近车型不可变CPU顶点/法线，不持有引擎资源；每次Clear/Commit后重绑六材质。
  - 冻结版六车×五固定角度（0/72/144/216/288）30张实图已逐图核验日志并内部目视，六section及材质非空，无Lua/渲染错误；纯几何探针六车法线/绕序/半径通过、退化三角0（10956～19950顶点）。同车型缓存命中跳过建模；六车展台正式回归25853/25853断言PASS（190帧，Lua/resource/engine错误0）：全±15°取景、逐车释放重建后实际Draw、隐藏停更及多输入频率30Hz限频通过。CPU mock计时受并发负载影响，不作为手机帧率。单文件及最终workspace LSP 0 Error（有Warning），官方多人build及预览上传成功。
  - 主游戏隔离冒烟实际开局、一次发射、六车型依次重建、暂停/恢复，Lua及overlay错误0；**整体报告FAIL**，含本地无体素模块、两项引擎缺图及llvmpipe HDR shader失败/尖峰，战斗3D可见性未据此通过。手机性能、真实联网支付与用户审美仍待验，不把技术验收写成用户认可。POST-3执行：沉淀贴面/邻接件与减面保体积两条跨项目抗体；既有用户偏好不人为增计。
  - 避雷：贴窗需同时审目标壳斜面、倒角边及相邻机盖/尾板；开好轮洞后仍要审后来加的踏板/裙边。减面不能将辐条/承重杆改成零厚贴纸；CPU缓存只存不可变几何。透明RT的NanoVG采样翻Y不代表GetImage读回PNG也要翻Y，应分别用实图确认。

- 版本: 0.13.33（天赋树价格相邻阶至少翻倍）：
  - 用户反馈「天赋树价格成长过低」，追加「每两级之间至少是倍数增长」；按相邻两阶至少 ×2 落地。单节点零件价由 200/350/600/900/1300/1800/2400 改为 **200/500/1200/2500/5000/10000/20000**，相邻倍率为 2.5/2.4/约2.08/2/2/2。具体曲线为助手拟值，用户明确的是倍增约束。
  - 只改 `TalentCatalog.STAGE_COST`，六线路42节点共用 `node.cost`；界面报价、余额差额、可买判定与真实扣费同源。首阶200、speed_1/normal_1自动拥有、星级门槛、前置链与所有天赋效果不变。旧档已拥有节点保留，不补扣差价；单线路标价39400，扣除两个自动节点后全树总投入236000。
  - 验证：价格隔离探针 **1315项断言 PASS**（42节点整数价格、相邻阶至少翻倍、所有非价格属性与旧版相同、余额边界、实际扣费/累计消费/保存/重复购买、报价差额/按钮命中、自动补齐/旧档/云合并）；第7阶真实渲染截图已目视确认六个20000胶囊及「解锁20000」按钮完整，无Lua/overlay错误。workspace LSP 0 Error，官方多人build与预览上传成功；手机长期经济节奏未宣称验收。headless CLI在引擎初始化阶段退出139，切已验证的graphicssurfaceless后测试通过。
  - 调价维护约束：价格增长必须核对相邻倍率，不把全表统一乘倍数当作增长加速；只改价格唯一来源，不迁移天赋、存档或支付。并发商业化UI/战斗HUD/车辆几何由其他会话负责，本批只提交价格、展示版本行及简记，未代提交其改动。POST-3 判定跳过：本批为项目数值调参，无新增跨项目偏好或通用随行规则。

- 历史版本: 0.13.32（首页实车主视觉 + 六车型展示商店；技术验收完成，审美待用户验收）：
  - 用户在 v0.13.31 后仍明确反馈「不够贵」。**v0.13.30/31 均未获审美验收**；渐变、柔光和扫光不是商业化视觉达标的证据。
  - 本轮方向由助手选择：用真实六车型商品展示建立主视觉，保留 dark-tech 配色、天赋/钱包/福利/收藏分组；浏览与购买/装备分离。售价、战斗属性、支付和广告规则不变。
  - 新模块 `ui/VehicleShowcase.lua` 复用 `VehicleGeometry.Build`，独立 LOCAL 场景、正交相机、透明 RenderTarget；隐藏不更新、只换车型重建，可见最高 30Hz。释放自有图像/纹理/场景后才销毁共享 NanoVG 上下文。
  - `GetControlFx` 由可交互控件显式登记几何、独立悬停/按压缓动、命中过 `WindowInput`；取消普通面板按尺寸自动发光。触摸结束/失焦清状态，鼠标松手保留悬停；绿色实心广告按钮改深色文字。
  - 已验证：最终官方多人 build+预览上传成功、workspace LSP 0 Error（仍有既有 Warning/Hint）；六车型真实像素、正向色标、全摆动取景、逐车 Shutdown→Init→Draw PASS。首页/商店实图已目视检查，浏览/购买门控、不改零件/装备、隐藏停更与 30Hz PASS；真实输入探针覆盖主 TouchID=0、第二指画布外结束、混合鼠标不抢主触点、右键不清左键、失焦/禁用/渐灭与全部首页命中。暂停真实渲染按钮反馈、直接 Backend.Init 及 ClientMain.Stop/Start 资源释放重建 PASS；最坏升级卡仍340高、完整折行，无 Lua/overlay 错误。离屏验证不代表手机帧率、联网支付或用户审美通过。
  - 运行时差异实锤：Forward 路径需 `EngineRes/RenderPaths/Forward.xml`；bbox 用 `CustomGeometry:GetBoundingBox()`；`SetOrthoSize(float)` 会把 aspect 复位为1，取景后最后重设16:9。GLES/OpenGL RT采样翻Y，只修目标纹理绘制、不反转车辆几何；先用世界上下色标验证，再看宿主实图，不能只数红色像素。
  - 交互新契约：`Begin/Move/EndTouchPointer` 按主 TouchID 维护视觉所有权（收进 uiFx，0为有效ID），非主结束/鼠标不抢反馈；失焦/Shutdown清所有权。只改反馈，不重写既有多指业务。`DrawMachinedPanel` 不再自动猜按钮，新增可操作控件显式登记 `GetControlFx`，普通展示/禁用无假反馈。

- 历史版本: 0.13.31（**「华丽 + 交互 + 动态」三件套：悬停发光 + 指针追踪 + 持续动效 + CTA 扫光**）：
  - **用户原话**「还不够华丽！还不够交互，还不够动态」——承接 v0.13.30 的静态质感升级。前两轮只做了「好看」，这一轮补「活」：**交互反馈 + 持续动画**。
  - **新增状态载体（1 个顶层 local 收表，守 AB-166）**：`uiFx = { hover={x,y,active}, hoverGlow=0..1, anim=秒 }`。`hoverGlow` 是**平滑**强度（`UpdateScene` 里按 dt×6.5 逼近目标，渐亮渐灭，非硬切）；`anim` 是全屏共享动画相位（流动光/呼吸/脉冲的公共时钟）。
  - **后端新 API（只读 uiFx）**：`Backend.SetPointer(uiX,uiY)` / `ClearPointer()` / `IsHovering(rect)` / `GetHoverGlow()` / `GetAnimPhase()`。
  - **交互（悬停发光）**：①`DrawMachinedPanel` 末尾——`h<=80 且 w>=40`（按钮尺寸）且指针命中 → `nvgBoxGradient` 青色外辉光 + 亮边，强度取 `hoverGlow`；大面板/HUD 横条天然跳过。②`MetaUI.Button` 非 disabled → 按 kind 取色（青/绿/金）同款外辉光。③注入 `MetaUI.Init{hovering, hoverGlow, anim}`（不反向 require）。
  - **动态（持续动效）**：①主菜单 CTA **周期性斜向扫光**（3.2s 一轮，`elapsed%3.2` 确定性，`nvgIntersectScissor` 裁剪不越圆角）；②`MetaUI.SectionHeader` 左竖条随相位**呼吸**（60%~100% 亮度）+ 下划线上**循环流动光点**。
  - **指针喂入**：`client_main` 的 `HandleMouseMove`/`HandleTouchMove` **先于所有分支 return** 调 `Backend.SetPointer`（悬停是全局反馈，不该被拖拽/模态分支吞掉）。
  - **验证**：官方多人 build+预览上传 ✅；LSP 两文件 **0 Error**；真渲染探针 `probe_hover`（把指针放到商店「购买」按钮上）像素取证——悬停按钮边缘 `(0,188,170)` 亮青辉光 vs 对照按钮 `(10,14,23)` 纯底色；CTA 扫光截图可见斜向光带；零 Lua/overlay 错误。BUILD_VERSION/大厅 →0.13.31。
  - ⚠️ **教训（AB-178）**：「华丽/动态」= **交互反馈（悬停/按下）+ 持续动画（扫光/呼吸/流动）**，不是静态装饰。用户连说两轮「不够」的根因是前几轮全是**静止画面**——一个完全静止的 UI 再精致也读作「截图」。做这类需求先找**共享原语的入口**（面板/按钮各一处）加反馈，并给一个**全屏共享动画时钟**（本项目 `uiFx.anim`），避免每个元素各自 `math.sin(elapsed*…)` 造成不同步。

- 版本: 0.13.30（**「界面太便宜」全局质感升级：金属面板 + 有光背景 + 发光窗口壳**；两轮迭代）：
  - **用户原话**「对一个商业化游戏来说现在的大多界面太便宜了」→ 第一轮改完仍「还是不够贵」→ 第二轮加码。**方向**：沿用 dark-tech 机加工金属（不引入新风格），**升级共享原语而非逐屏重画**——13 个界面全部经 `DrawMachinedPanel`/`DrawWindowShell`/`DrawModalBackdrop`/`Button`，改这几处即全屏生效。
  - **根因（量化）**：旧 `DrawMachinedPanel` 的渐变只有 **±5 RGB**（肉眼等同纯色）、描边 1.1px、无厚度；`DrawModalBackdrop`/`DrawMenu` 是**一整块平色 C.bg**（占屏 80% 却零层次）；CTA 是一块**纯青平板** `DrawRect(C.cyan)`（把下面的机加工面板整块盖掉）；`Button` 是平色 + 3px 竖条。
  - **第一轮**：①`DrawMachinedPanel` → 投影落地 + 金属渐变（±16/19/24）+ 上缘内高光/下缘内暗边 + 外描边 1.6 + **四角螺钉**（r≥5 且 w>130 且 h>70；HUD 横条 radius=0 天然跳过）②主菜单 CTA → 青色金属渐变 + 斜向光泽 + 倒角（`GetMenuCtaRect` 命中几何未动）③`MetaUI.Button` primary/ad → 亮→深渐变 + 倒角。
  - **第二轮（用户「还是不够贵」后加码）**：①`DrawModalBackdrop` → **径向渐变底**（`nvgRadialGradient` 中心偏亮深海军蓝→四周近黑）+ 顶部青色环境辉光 + 四角暗角；②`DrawMenu` 背景同款径向 + 辉光；③`DrawWindowShell` → **外辉光**（`nvgBoxGradient` 青柔光）+ 标题栏受光横带 + 内容区内凹暗角；④`MetaUI.Shell` 标题栏受光渐变横带；⑤新增 `MetaUI.SectionHeader`（青竖条 + 向右淡出渐变下划线）替换店铺分区平色小字。
  - ⚠️ **不加顶层 local**：`Scene3DBackend` 196/200、`Game` 200/200（AB-166），全部原地改写现有函数体 / 用局部量。`MetaUI` 新增 `SectionHeader` 是模块级 local（34→35，余量充足）。
  - ⚠️ **`nvgBoxGradient`/`nvgRadialGradient` 可用**（`.emmylua/NanoVG.d.lua` 已声明）——「贵」的关键是**真实柔光**（径向/盒式渐变），线性渐变做不出。
  - **验证**：官方多人 build+预览上传 ✅（两轮各一次）；LSP 两文件 **0 Error**；真渲染探针 13 界面全渲零 Lua/overlay 错误；像素取证：卡片内部竖向 `(26,37,58)→(13,22,39)` 跨度 ~19 级（旧版更窄更暗）。⚠️ 待 Preview 真机观感。
  - ⚠️ **教训（AB-177）**：用户说「不够贵/太便宜」时，**先找共用原语**——13 个界面共用的 `DrawMachinedPanel`/背景/按钮才是「廉价」的最大单一来源，逐屏重画是低杠杆；**「贵」的物理来源是层次**（渐变跨度 / 柔光 / 厚度 / 焦点），不是更多装饰线条。

- 版本: 0.13.29（**升级卡 UI 自适应：数值条折行 + 卡高 300→340 + 详情降字号**）：
  - **用户反馈（截图 + 一句「卡片UI适应性优化？」）**：升级面板第 1 张卡（装甲强化）的数值条文案 `-20% 受创 / +8% 零件` 左右两侧**溢出卡片边界**，压到相邻卡。
  - **根因**：数值条文案是**数据驱动**的（`Game.lua` 的 `UPGRADE_POOL[].value`），长度从 5 字（`+1 格`）到 32 字节（`伤害+3 / 弹速+10% / 受创+1`）不等，而 `DrawUpgradeCard` 固定 **16px 单行居中、无任何宽度约束**——最长的两张（玻璃巨炮、装甲强化）必然溢出。
  - **改动（全在 `Scene3DBackend.lua`）**：①新增 `MeasurePixelWidth`（设计空间实测宽度，`nvgResetTransform` 后再测，与 `WrapTextLines` 同约定）；②新增 `SplitValueLines`——**先按 ` / ` 拆语义段，再贪心打包**（能塞同一行的段合起来，塞不下才换行，**不在段中间切断**）；16px 下折出 **3 行以上**才降一档到 14px 重排，返回 `lines, size` 供绘制端用同一字号；③`DrawUpgradeCard` 数值条**按行数动态定高**（`valueBoxH = 8 + n*19`），底部锚点 `y+cardH-34` 上推，详情区与说明条自动避让；④**卡高 300 → 340**（带说明条的卡要同时装下 详情 2 行 + 说明条 + 数值条 2 行，300 会把详情挤成 1 行并**截断文案**）；⑤详情**字号自适应**（17px 装不下降 15px、行距 25→22）。
  - **命中几何**：`HitTestUpgradePanel` 完全由 `GetUpgradePanelLayout`→`GetUpgradeCardLayout` 派生（`client_main` 零常量），改卡高即两处同步，无需另改文件。
  - **验证**：官方多人 build+预览上传 ✅；LSP workspace **0 Error**（21 文件 818 诊断）；真渲染探针 `probe_upcard3`（覆写候选为最坏组合：玻璃巨炮/装甲强化/穿甲弹头）截图确认——数值条 2 行不溢出、说明条「高风险 / 高回报」不被压、详情 2 行完整（`伤害 +3、弹速 +10%` / `，但被撞多掉 1 点。`）；`probe_upcard2`（解锁车卡）确认 `新车型 · 本局解锁` 说明条正常；命中探针 `probe_uphit` **PASS**（三卡中心/上下缘/旧下缘 680/角标 hold/两个按钮全命中）；`probe_render` 真渲染冒烟零 Lua/overlay 错误。BUILD_VERSION/大厅 →0.13.29。
  - ⚠️ **教训（AB-174）**：**数据驱动的文案不能在绘制端假设长度**——同一字段长度可差 6 倍，固定字号单行必然溢出。做法：①按**语义分隔符**（此处 ` / `）拆分而不是按字符硬切（否则 `弹速+10%` 会被切成 `弹速+1`/`0% ...`）；②先按**像素宽度实测**决定换行；③**容器高度跟着内容走**（动态定高 + 上游锚点上推），不要写死。
  - ⚠️ **教训（AB-175）**：**缩短可见行数会静默丢信息**——本批一度把详情 `maxLines` 压到 1 行来腾空间，结果玻璃巨炮的详情被截成「伤害 +3、弹速 +10」并**丢掉「%，但被撞多掉 1 点。」**，而 LSP/构建都无感。正确做法是**先让容器变大（卡高 300→340）**，再让字号自适应兜底；「截断」永远不是布局手段。
  - ⚠️ **教训（AB-176）**：**命中探针必须推进 `Game.Update` 才能验窗口内命中**——`HitTest*` 会先过 `WindowInput` 的**窗口入场动画逆变换**（`WindowMotion`，入场 0.32s 内 scale≈0.91），而 `uiClock_` 由 `AdvanceUiClock(game.elapsed)` 驱动、`elapsed` 只在 `Game.Update` 里涨。探针若只调 `Backend.UpdateScene` 不调 `Game.Update`，`uiClock_` 恒 0 → scale 停在 0.91 → **卡中心命中、边缘全落空**（本次踩到，误以为 340 卡高的几何算错）。
- 版本: 0.13.28（**飞行尾迹整体下移半格（观感）**；同批承接常驻通用卡重做）：
  - **用户要求**「为了保证观感，拖尾额外向下移动半个格子单位距离」→ 3D 尾迹光带**整条再向下偏半格**。
  - **改动**：`Renderer3D.SyncVehicleTrails` 在采样点写入 `trailSamples_` **之前**统一做 `pos.y -= halfBrick * WORLD_SCALE`（游戏 Y 向下为正 → 世界 Y 减）。半格值 `halfBrick = brickSize * 0.5`，**优先取快照权威值 `s.brickSize`**（`Game.GetSnapshot` 新增 `s.brickSize = GetBrickSize(wave)`，随关卡 14/15/16 变化、波间隙无敌机时也稳定），缺省回退基准 16 的半格。⚠️ 放在 track 存储**之前**——若放在几何构建循环里，车头（`track.head`=实时位置）会下移而历史采样点不动，尾迹尾部会从车尾脱开。
  - **验证**：官方多人 build+预览上传 ✅；LSP workspace **0 Error**（21 文件 814 诊断，修掉新变量 `integer 目标配浮点来源` 一处）；真渲染探针 `probe_trailoff` 插桩实测 **`snapBS=14`（第 1 关权威格子）→ `halfBrick=7.0` → `gameDelta=7.00`**，偏移量正好半个格子；干净冒烟（工作区代码）零 Lua/overlay/VertexBuffer/LoadChunk 错误、进入第 1 关并发射。⚠️ 待 Preview：真机尾迹贴车观感（下移半格是否如预期）。
  - ⚠️ **注意探针开局 3 秒过渡**：v0.13.24 起 `INTRO_SECONDS=3` 内 `veggies` 为空，若只用 `game.veggies[1].brickSize` 取格值会退到回退值——这正是本批把权威 `brickSize` 放进快照的原因（AB-171 同族：开局过渡期取敌机字段为 nil）。
- 版本: 0.13.28（**常驻通用卡重做：改作用对象，让关1 就有用**；承接 v0.13.28 分裂车自动解锁）：
  - **用户原话**「通用卡（常驻）大类的用处均过低了」→ 澄清后为「这些数值在第一关等低难度没有明显帮助」，并选定**「改作用对象」**方向。
  - **根因（量化）**：关1~3 砖块 hp=1（`GetBrickHp` 关1=1、每 3 关 +1），越线伤害 = `max(1, ceil(行数*0.5) + lineDamageBonus)`——四张常驻卡的旧数值**作用在关1 不存在的变量上**：`damage +1` 对 1 血砖块纯溢出；`repair 回血 25` 玩家几乎不掉血、无处可用；`armor -1` 被单行越线的 `max(1,…)` 下限完全钳掉；`glass_cannon +2 伤害` 同样溢出而惩罚永久累积。
  - **重做（`Game.lua`，只改规则层，机制换挂点）**：①`damage` 穿甲弹头 = 伤害 +1 **且每击碎一块额外 +1 经验**（`brickXpFlat`，与砖块血量无关，关1 立刻加速升级）；②`repair` 前线维修 = **生命上限 +12 且立即回 12**（`maxHpBonus` 并入 `GetMaxBaseHp`，永久收益，不再空过一轮）；③`armor` 装甲强化 = **受创 -20%/级（百分比，`armorReduce`）+ 零件产出 +8%/级（`partsMul`）**（百分比对单行也生效、零件与难度无关，上限 2→3）；④`glass_cannon` 玻璃巨炮 = 伤害 +2→**+3** 且追加**发射初速 +10%/级（`launchSpeedMul`）**。
  - **新增 5 个 `BALL_TUNING` 字段**：`armorReduce`/`partsMul`/`launchSpeedMul`/`brickXpFlat`/`maxHpBonus`。`partsMul` 在四处产出点统一乘（击碎/清机/过波/关卡结算）；`launchSpeedMul` 在 `LaunchMarble` 乘进初速；`brickXpFlat` 在 `EjectBrick` 并入 `GainXp`；`armorReduce` 在越线结算做四舍五入减伤再 `max(1,…)`。
  - **浮点防线（必读）**：`partsMul` 让 `partsEarned` 变**浮点**，而渲染层用 `%d` 格式化 `runParts`（本项目「HUD 整数格式契约」踩过浮点崩帧）→ `GetRunParts`/`SettleParts`/快照 `partsEarned` 三处出口一律 `math.floor`；探针断言 `math.type(runParts)=="integer"`。
  - **⚠️ 前向引用（AB-100 同族，LSP 抓到）**：`repair` 卡的 `apply` 闭包要读 `GetMaxBaseHp`，而该函数定义在卡池之后 → 必须把 `local function GetMaxBaseHp` 改为**前向声明 `local GetMaxBaseHp` + 后置赋值**，否则闭包解析成全局 nil。
  - **⚠️ 复位顺序**：`BALL_TUNING.maxHpBonus` 必须在 `ResetGame` 的 `baseHp = GetMaxBaseHp()` **之前**清零，否则上一局的维修上限会带进新局。
  - **验证**：官方多人 build+预览上传 ✅；LSP 0 Error；探针 `probe_common` **7/7 PASS**（关1 砖块 hp=1 基线；四张卡各实测 `brickXpFlat=1`/`partsMul=1.08`/`maxHp 100→112`/`launchSpeedMul=1.10`；零件在 `partsMul` 下仍为整数 `runParts=256`；装甲减伤实测 **32 行越线 16→13**）；回归 `probe_growth` PASS（暴击/经验路径，顺手把其 v0.13.16-talent 前的陈旧血量断言更新为新契约）；真渲染 `probe_render` 零 Lua/overlay 错误、截图非空。BUILD_VERSION/大厅 **0.13.28**（版本号由并发会话推进，本批未动）。
  - ⚠️ **教训（AB-172）**：数值卡「有没有用」不能只看数值大小，要问**它作用的那条变量在低难度是否存在**——1 血砖块上的「伤害 +N」、不掉血时的「回血/减伤」数学上恒为 0 收益。增强这类卡要么改底层数值（提高砖块血量/去掉伤害下限），要么**改作用对象**（挂到经验/上限/零件/弹速等与难度无关的量上）；只调大数字会白做一轮。
- 版本: 0.13.28（**分裂车天赋节点开局也自动解锁**；承接 v0.13.27）：
  - **用户要求**「分裂车天赋树玩家一开始也解锁」→ 把分裂车的 1 阶节点 `normal_1`（「解锁分裂车 / 允许分裂车在局内出场」）并入开局自动拥有。
  - **改动（`TalentCatalog.lua` 一处）**：`AUTO_OWNED` `{ "speed_1" }` → **`{ "speed_1", "normal_1" }`**；`client_main.lua` 注释里的「初始分裂车」订正为「初始车」（该处调用与逻辑零改动，`EnsureAutoOwnedTalents` 本就遍历整个 `AUTO_OWNED`）。BUILD_VERSION/大厅 →0.13.28。
  - **语义（三层门控，未变）**：`normal_1` 自动解锁 = **局内出现「解锁分裂车」卡**（分裂车本局可进弹药队列）；**专属卡/基础卡（`split`/`base_split`）仍需 `normal_2`（ballCard 节点）**，自动解锁不顺带放开。开局自带车仍只有加速车（`STARTING_BALL_TYPE` 未动）。
  - **验证**：官方多人 build+预览上传 ✅；LSP 0 Error（21 文件 808 诊断）；探针 `probe_splitauto` PASS（①`AUTO_OWNED` 含 speed_1+normal_1 ②只有 speed_1 → `unlock_normal` 不进池 ③speed_1+normal_1 → `unlock_normal` 进池 ④`split`/`base_split` 仍被 `normal_2` 拦住）；探针 `probe_splitdraw` PASS（`EnsureAutoOwnedTalents` 后 `normal_1=true`，天赋树绘制该节点为「已解锁」、draw ok）。
  - ⚠️ **探针必须跳过 v0.13.24 的 3 秒进关过渡**（本次踩到）：开局有 `INTRO_SECONDS=3` 冻结期，`HandleAction("start")` 后立刻取快照 **`veggies[1]` 为 nil**（还没刷波）→ 必须先 `for _=1,200 do Game.Update(1/30) end` 推进过过渡再取敌机。
- 版本: 0.13.27（**修恶性回归：逐架生成的敌机全叠在正中**；承接 v0.13.26）：
  - **用户报「飞机全都生成在正中」**——这是 v0.13.26 我改逐架生成时引入的**恶性回归**：`SpawnNextNormalEnemy` 每架都写死 `x = DW*0.5 - shipW*0.5`，而横向铺开的 `ComputeFormationSlots` 同批被我当死代码删了 → **整波叠在同一条竖线上**。
  - **修法（`Game.lua`）**：`SpawnNextNormalEnemy` 加**确定性横向分道**——5 条车道，`lane = pendingSpawn.lane % 5; x = margin + (maxX-margin)*(lane/4)`（非随机，宽度按机型 `shipW` 自适应）；`pendingSpawn` 表加 `lane` 字段；每波开波时 `lane = (wave-1) % 5`（**起始车道随波次错开**，否则关1 每波仅 1 架会「总从最左出」）；`ResetGame` 归零。车道数/margin 用**函数内局部量**，不新增顶层 local（AB-166）。
  - **验证**：官方多人 build+预览上传 ✅；LSP 0 Error（21 文件）；真渲染冒烟零错误；探针 `probe_lane` 实测生成序列**唯一 x 位置 5→7 个**（x 20/114/188/316/376/415，不再全居中）；`probe_gap` 回归**1 格间距未破**（关1 120.85、关12 14.60）。BUILD_VERSION/大厅 →0.13.27。
  - ⚠️ **教训（AB-170）**：把「一次性编队」改成「逐架生成」时，**横向铺开逻辑是编队函数的一部分，不能连着函数一起删**——本次 `ComputeFormationSlots` 里除了编队还负责横向 x 分布，我整段删掉后新函数只留了纵向错峰，于是「所有敌机叠在中线」。**删除/替换生成路径时，先列出旧函数真正负责的每个维度（x 分布、y 错峰、阵型），逐条确认新路径都有等价实现**，别只看名字以为只是「阵型」。
- 版本: 0.13.26（出怪梯度重做：数量起点 1 架 + 同波逐架飞出 + 波间隔改逐关收紧 + 预告写明远方生成）：
  - **用户三点要求**（承接「第一关这么多，第七关就满了」的否决）：①普通波起点「比 2 更低」→ **1 架**，且「允许不到 12」；②「出怪间隔维度」= **同波内一架接一架飞出**，关1 间隔最长、之后逐关收紧，**任意两架初始至少隔 1 格**；③「出怪下方提示的怪不会立刻抵达屏幕，请写明在远方生成」。
  - **`StageCatalog.lua`**：`GetNormalCount` 起点 `2→1`（关1 1/1/2/2/3/3、关7 4/4/5/5/6/6、关15 9/9/10/10/11/11，**不触 12**）；`GetInterval` **方向反转**（旧版随关卡变长 15.5→25.1s 是反的 → 关1 22s 最长、每关 -0.9s、关内每波 -0.3s、下限 7s）；新增 `GetSpawnInterval`（关1 2.8s → 关13 起 1.12s）；`GetEscortCount` 改为前 3 关 0、关4 起每 3 关 +1 封顶 3。
  - **`Game.lua`（同波错峰生成）**：新增 `pendingSpawn` 状态表 + `SpawnNextNormalEnemy`（逐架放出、与在场敌机隔 1 格、满场/无空位则推迟绝不叠放）+ `ReleaseEscortVolley`（护航同机制）。普通波 `SpawnWave` 只登记参数并放第一架；`Game.Update` 在 `UpdateEnemies` 后按 `pendingSpawn.timer` 逐架放出。**删掉** `SpawnEliteEscorts`/`ComputeFormationSlots`/`LiftSlotsOffExisting`（一次性编队已废弃，死代码清理）。`FleetPositionOccupied` 加可选 `gap` 参数（同波传 `brickSize` 强制 1 格）。Boss 生成改「有人在位就从更远方生成」而非 `while` 上抬（消除「Boss 到场又瞬移头顶」）。
  - **`Scene3DBackend.lua`**：`DrawNextWavePreview` 面板 76→86 高、图形区压缩，新增「**自远方飞入**」一行说明（敌机在屏幕上沿之外生成、下落一段才进画面）。
  - **验证**：官方多人 build+预览上传 ✅；LSP 0 Error（21 文件 810 诊断）；真渲染探针零 Lua/overlay 错误；规则探针 `probe_grad`/`probe_gap` 实测**生成时刻最小间距**：关1 120.85、关12 14.60（均 ≥ 一格 14）；数量/波间隔/出怪间隔断言全 true。BUILD_VERSION/大厅 →0.13.26。
  - ⚠️ **运行时抓到 LSP/build 都查不到的编译期上限**：给 `Game.lua` 加 7 个顶层 local 后 **超 Lua 200 上限** → `LoadChunk failed: too many local variables`（整模块加载失败=黑屏）。改为收进 `pendingSpawn` 一张表。见 AB-166（大文件顶层 local 硬上限）。
  - ⚠️ **间隔下限必须按最慢机型估算**：`CurrentSpawnInterval` 的下界用**基准速度 × 0.42 × 最慢 descentMul(0.66)**，用基准速度会在高关卡漏掉下界、最慢那架来不及拉开就与后一架同格。
- 版本: 0.13.25（尾迹不可见的**真根因**：`CustomGeometry:Clear()` 会清空材质槽；提交 1362c85）：
  - **用户报「特效不可见」**。几何早已验证提交（54 顶点）、节点也已启用，于是把探针扩到**读几何的材质**，一击命中：
    `speed: enabled=true numVert=54 **mat=false**` —— **几何有顶点但没有材质** → 渲染器无从绘制。
  - **根因**：`CustomGeometry:Clear()` **会连材质槽一起清空**，而尾迹只在 Init 绑过一次材质、之后每次重建都没重设 → 重建后的光带永远无材质。**敌机网格可见正是因为 `RebuildEnemyMesh` 每次 `Clear()` 后都重设 `SetMaterial`**（两处一对比即真相）。
  - **修复**：`Commit()` 之后重新 `geometry:SetMaterial(0, trailMaterial_)`。
  - **这也解释了此前几轮"修了仍不可见"**：v0.13.22 的 `SetDynamic(true)`、v0.13.23 的 CULL_NONE + 法线/自发光、以及更早的 billboard 版，**各自那层都是对的**，但材质在 `Clear()` 时就已丢失——单层验证永远看不到这一层。
  - **验证**：同一探针复测 → `speed: enabled=true numVert=54 **mat=true**`，零 Lua 错误；LSP 0 Error；前向引用 0；官方多人 build+预览上传 ✅。BUILD_VERSION/大厅 →0.13.25。
  - ⚠️ **教训（AB-168）**：`CustomGeometry` 每次 `Clear()` 后必须**重设材质**（材质不随几何保留）；诊断"几何有但看不见"时，**读 `GetMaterial(0)`** 是最快的一刀，比继续查剔除/光照/通道都直接。
- 版本: 0.13.24（关卡号数字贴图 + 进关过渡/准备动画）：
  - **数字贴图**：nanobanana 生成 0–9 → bbox 裁切 → 按高度归一（GLYPH_H=26）→ alpha 二值化 → 白+轮廓两色量化 → 24×32 母版；新增 `scripts/ui/DigitFont.lua` 懒加载、乘法染色、逐字宽度表与缺图字体回退，StageSelect 数字改贴图。
  - **进关准备**：`Game` 新增 `INTRO_SECONDS=3`/`introTimer`，开局先冻结玩法倒计时，归零才 SpawnWave；`StageIntro.lua` 绘制遮罩、关卡号、倒计时条与扫描带，取代重复的 `stage_started` 横幅。
  - 取舍：不新增 gameState、不再给接近 LUA_MAXLOCALS=200 的 Scene3DBackend 加一组局部变量，数字与过渡各自独立模块。
  - 验证：多人 build+Preview、LSP 四文件 0 Error、前向引用 0、intro 与选关数字真渲染探针零 overlay 错误。⚠️ 待 Preview：3s 时长与数字贴图真机清晰度。
- 版本: 0.13.23c（普通波数量再次放缓；代码提交 ccc4f69，展示版本后来由并发会话升至0.13.24）：
  - 普通波按普通波序号增长：关1 2/2/3/3/4/4；关7 5/5/6/6/7/7；关15 10/10/11/11/12/12，第15关后段才触及12架上限。
  - 精英护航与Boss召唤分别渐进，见 `StageCatalog.lua`；砖块HP、速度、波间隔未改。
  - 验证：LSP 0 Error，数值断言覆盖关1/7/15和12架上限，官方多人 build+Preview成功。
- 上次交付: v0.13.23c 普通波密度再次下调
  - **用户要求「小幅衰减」**（承接 v0.13.22 的「去掉速度上限」）：给加速加**软性递减**——**保留无硬上限**，但速度越高每次加速倍率越小，避免后期滚雪球。
  - **实现**：`BALL_TYPES.speed` 新增 `speedBoostFloor = 1.012`（衰减下限，恒 >1 所以速度永远在涨）与 `speedSoftCap = 1400`（到此速度降到下限）。`BoostSpeedMarble` 里按**从初速起算**的线性插值算倍率：`t = clamp((speed - 660) / (1400 - 660))`，`boost = 1.06 + (1.012 - 1.06) * t`。⚠️ **必须从初速起算**（第一版用 `speed/softCap` 导致初速 660 就吃到一半衰减、前期手感变钝，已修）。
  - **实测曲线**：660→×1.06（吃满）、1000→×1.038、1200→×1.025、1400 及以上→恒 ×1.012 稳步增长。
  - **验证**：官方多人 build+预览上传 ✅；探针 `probe_soft` PASS——实测最高速度 **1762**（仍 > softCap 1400，证明无硬上限），对比无衰减版的 1912 明显被压住。
  - ⚠️ **「去上限」与「软性递减」是两件事，别互相替代**：硬上限=到点不动；软性递减=一直涨但越来越慢。用户要的是后者——实现时**衰减下限必须严格 >1**，否则等价于偷偷加了上限。
  - **用户要求（v0.13.23b「普通波数量梯度放缓」）**：基础曲线从 6/8/10 架调整为 2/3/4 起步、关15 才到 12 架上限；细节和后续校准见下方 v0.13.23c。
- 版本: 0.13.23（尾迹不可见的真因：背面剔除 + 无光照；提交 92d91a9）：
  - **用户报「现在什么拖尾也没有啊」**。几何已验证提交（90 顶点、世界 AABB 在视锥内），所以问题在**光栅化**而非位置：
  - ①**背面剔除**：三角带绕序使面法线朝 **+Z**，而相机在 **-Z** 看向 +Z → 整条光带被剔除。共享的 `voxelMaterial_` **没有** `SetCullMode`，尾迹现改用**独立材质 + `CULL_NONE`**（敌机箱体材质早已因同样原因设了 CULL_NONE）。
  - ②**无光照**：法线硬编码 `(0,0,-1)` 是**水平**的，而场景光来自上方 → `N·L≈0` → 表面全黑、在近黑背景上不可见。法线改为**朝上 `(0,1,0)`**，并给材质**低强度常驻自发光 0.15**（`MatEmissiveColor`）做可见性保底——不依赖场景光、又不冲淡弹种配色与「头亮尾暗」顶点色渐变（同 v0.11.1 基准线在深空场景要自发光的教训）。
  - **验证**：探针读飞行中 **72–90 顶点真实提交**、零 Lua 错误；LSP 0 Error；前向引用 0；官方多人 build+预览上传 ✅。BUILD_VERSION/大厅 →0.13.23。⚠️ **本环境离屏 3D 整层恒黑（连敌机都不显示）**，像素可见性只能靠 Preview 目视确认。
  - ⚠️ **教训（并入 AB-162）**：3D 特效「几何提交了但看不见」按顺序查 ①**背面剔除/绕序**（`CULL_NONE`）②**法线方向 vs 光源**（`N·L≈0` 即全黑）③常驻自发光兜底。几何存在性用顶点数取证、位置用世界 AABB 取证，能快速把「没生成/位置错/渲染不出」三类原因分开。
- 版本: 0.13.22b（加速车去上限 + 速度卡改「加速度」；提交 0a38041）：
  - **用户要求（原话「加速车没有速度上限，相关改为加速度词条加成」，澄清后为「原先的加上限词条改为加加速度」+「速度分档，无限增长」）**：①**去掉速度上限**（`BALL_TYPES.speed.maxSpeed = 900` 删除）——每次反弹/命中仍 ×`speedBoost`(1.06) 无限加速；②**去掉伤害封顶**（`maxDamage = 2` 删除）——伤害按 `damageStep`(320) 分档**无限增长**；③**`speedMul` 语义从「最高速度倍率」改为「加速度加成」**——`BoostSpeedMarble` 里 `gain = speedBoost + (speedMul - 1) * 0.1`，即同样的反弹次数速度涨得更快（不再参与上限计算）。
  - **文案同步**：三张卡（`speed` 疾速引擎 / `overclock` 超载核心 / `base_speed` 引擎调校）与天赋 `BALL_STAT.speed.label` 全部由「极速/最高速度 +N%」改为「**加速度 +N%**」。
  - **验证**：官方多人 build+预览上传 ✅；探针 `probe_nocap` PASS（实测速度达 **1241** > 原上限 900）；`probe_dmg` PASS（实测伤害档到 **4** > 原上限 2）。⚠️ 真机需目视确认「越打越快」的手感与是否因无上限导致后期失控（如需要，可加软性递减而非硬上限）。
  - ⚠️ **删字段后要 grep 全库确认无残留引用**（本次 `maxSpeed`/`maxDamage` 只在注释里留了历史说明）。
## 当前状态
- 版本: 0.13.23（普通波数量梯度放缓；展示版本沿用并发 0.13.22）：
  - 普通波人数：关1 2/3/4；关7 5/6/7；关15 10/11/12，第15关末段才触及12架同屏上限。
  - 精英护航：关1–2为0、关3起每三关+1、关9封顶3；Boss召唤上限关1起1、关5升2、关9升3、关13封顶4；召唤间隔关1为12秒、关15为8.5秒。
  - 每关3/6/8精英、10 Boss不变；每3关砖块HP+1、基准速度及普通波间隔公式不变。
  - 验证：LSP 0 Error；第1/7/15关断言、普通波硬上限断言通过；多人build+Preview上传成功。
- 上次交付: 普通波数量梯度放缓（代码版本0.13.23，BUILD_VERSION由并发会话保留0.13.22）

## 本批次新增避雷（v0.13.23 普通波数量梯度）
- 用户明确否决“第1关6架、第7关满12”的曲线。调整无限关卡敌人数时，应把硬上限首次触发推迟到中后段；至少核对第1/7/15关分段人数与特殊波密度，别只看最终 `min(MAX_FLEET, ...)`。

## 历史
- 版本: 0.13.22（尾迹 = 真 3D 几何光带 + 锚定车尾；提交 d7d06d8）：
  - **用户两点纠正**：①「我要求的是复刻后一种的你错误做成 2d 的」——billboard 是 **2D 面向相机的四边形精灵**，做不出带朝向的渐细光带；要的是**真 3D 几何 ribbon**。②「要跟随车尾而不是体积中心哦」。
  - **改动**：`Renderer3D` 尾迹改为 **CustomGeometry 三角带**（每弹种一个批次），材质走敌机箱体同一条**已验证可见**的路径（`DiffVCol` + 白底纹理 + 顶点色）；16 点采样 / 0.016s 间隔 / 0.42s 寿命 / 半宽头 0.30→尾 0.012（×权威半径）/ 顶点色头亮尾暗 / z 再退 0.16m。**头部采样点从车辆锚点沿 -朝向 退 `1.75 × GetVehicleScale`**（车局部 +X 为车头、半长约 1.8 局部单位）→ 光带从**车尾**拖出；飞行朝向=速度朝向、瞄准朝向=发射向量，与 Renderer3D 同约定。
  - 🔴 **历史 ribbon「不可见」的真根因（本次实锤）**：v0.13.10 的 ribbon **每帧重建几何却从未 `SetDynamic(true)`** —— 非动态几何的顶点缓冲提交后不可再改，于是每帧重建全部失效、整条尾迹画不出来。**每帧重建的 `CustomGeometry` 必须 `SetDynamic(true)`**（`engine-docs/recipes/procedural-geometry.md` 有明文）。
  - **验证（可自证，绕开 3D 层恒黑）**：因本地离屏 3D 受 BloomHDR 故障恒黑，改用**顶点数取证**——探针驱动飞行后读 `geometry:GetNumVertices(0)`，实测 **78 顶点（13 段）真实提交**、全程零 Lua 错误；LSP 0 Error；前向引用 0；官方多人 build+预览上传 ✅。BUILD_VERSION/大厅 →0.13.22。
  - ⚠️ **探针开局方式已变（v0.13.4 起）**：菜单态 `Game.PointerDown(1,1)+PointerUp` **不再开局**（改为先开选关界面），必须调 **`Game.StartStageAt(1)`**。此前多轮"验证"因探针仍用旧开局方式而**全程 state=menu、marbles=0**，属无效验证——**探针报告要先确认它真的进入了目标状态**。
  - ⚠️ **调试打印别给函数挂字段**：`SyncVehicleTrails._logged = true` 触发 `attempt to index a function value`（Lua 函数不能挂字段），且该错误**把整个 Render 打断**、反而掩盖了真实症状。诊断状态一律用模块级 local。
- 版本: 0.13.21b（词条卡归入通用卡并加天赋门控 + 卡池分类审计；提交 2216994）：
  - **用户点名（原话「加速车分裂的专属词条还是天赋树没解锁就在局内被允许出现了」「合着这几个还有寒冰车的词条都不是天赋树规定的专属天赋卡范畴？给我优化管理！」）**：探针复现——无任何天赋时 `word_pierce/word_chain/word_momentum` 三张词条卡**都在池里**。根因：词条卡既无 `ballType`（不是车型卡）也无 `requiresCard`（不是通用卡），**两套门控都没覆盖它**，成了"三不管"常驻卡。
  - **修复（用户裁定归类）**：词条卡归**「通用卡（无车型）」**，与 xp/ammo 同一套 `requiresCard` 门控。①`Game.lua` 三张词条卡各加 `requiresCard = "word_pierce"/"word_chain"/"word_momentum"`；②`TalentCatalog` 通用卡线 `general_b` 扩为 **1阶=xp、2阶=贯穿、3阶=ammo、4阶=连锁、5阶=动量**（6/7 阶仍为结算零件 +5% 填充）；③`ICON_BY_CARD` 补三张词条卡 → `talent_word`。
  - **卡池分类最终定版（5 类，全部有明确门控）**：`通用卡(常驻)` damage/repair/armor/glass_cannon ｜ `通用卡(需天赋)` xp/ammo/word_×3 → `requiresCard` ｜ `车型基础卡` base_×4 → `ballType`(车已解锁) ｜ `车型专属卡` giant/split/speed/ice/overclock → `ballType` + 天赋 `ballCard` 节点 ｜ `解锁车卡` unlock_×4 → 天赋 `ballUnlock` 节点。**新增卡时必须落进这 5 类之一**。
  - **验证**：官方多人 build+预览上传 ✅；探针 `probe_wordgate` PASS（①无天赋→三张词条卡都不进池 ②解锁 `general_b_2/4/5` → 三张都进池 ③节点存在且 lane=general_b、kind=cardUnlock）；`audit.py` 全池审计 **0 张漏门控**。
  - ⚠️ **新增升级卡必须显式归类，不能"裸卡"进池**：本项目踩过两次——`ballCard`（v0.13.16）与词条卡（v0.13.21）都是"定义了但没被任何门控覆盖"，静默常驻。交付前跑一次全池审计（`audit.py` 模式：逐卡打印 kind/ballType/unlockBallType/requiresCard 并归类），确认没有落不进 5 类的卡。
- 版本: 0.13.21（尾迹回归 3D BillboardSet——「圆形版跟随正常」那条路；提交 2a558be）：
  - **用户第三次打回并给了决定性线索**：「还是没跟上，但是最开始的圆形的完全可以跟随啊」——最早那版（v0.13.3 软圆 billboard）**画在 3D 场景里、与车共用同一相机投影**，所以天然贴车、永不脱节；后面两次（v0.13.12 overlay / v0.13.19b 修回缩与宽度）都是**手工屏幕投影**，才反复错位。**根因不是参数，是通道选错了**。
  - **修法**：`Renderer3D` 尾迹回归 3D BillboardSet（每弹种一批、颜色烘焙进软圆 + DiffAlpha，与碰撞粒子同一条已验证可见路径）。为消除当年的"珠子感"：采样改**密集重叠**（0.022s 间隔、0.22s 寿命、每车 10 点）+ **头到尾强收束**，读起来是一道连续渐隐的光带而非离散点；z 相对车辆锚点再远 `TRAIL_BEHIND_Z=0.10`，保证尾迹在车体**之后**而不是压在上面（overlay 版"图层比车高"的教训）。沿用 flightTime 回绕防 id 复用串轨、瞬移/静止清轨、非 playing/重开/Shutdown 清空。
  - **移除 overlay 尾迹**：`Presentation.UpdateVehicleTrails` 整段 + `vehicleTrails` 快照字段 + `Scene3DBackend` 的 `DrawVehicleTrails`/`ProjectTrailPoint`/深度平面标定全部删除（Scene3DBackend 模块 local 198→193，离 200 上限更远）。
  - **验证**：真渲染启动→开局→发射零 LoadChunk/overlay stage/VertexBuffer 错误、日志确认 `vehicle trails ready (3D billboard, 80 slots/type)`；LSP 我改的三文件 0 Error；前向引用 0；官方多人 build+预览上传 ✅。BUILD_VERSION/大厅 →0.13.21。⚠️ 待 Preview：3D 尾迹在真机的跟随与观感。
  - ⚠️ **教训（并入 AB-158）**：改造反复失败时，先问「**原来能用的那版做对了什么**」——本次三次打回后才从用户一句「最开始圆形的可以跟随」定位到「3D 场景 vs 手工屏幕投影」这个通道级差异。贴在 3D 物体上的特效，优先画在 3D 场景里共享相机投影，别自己算屏幕坐标。
- 版本: 0.13.20（天赋车解锁语义订正；提交 dfbde86）：
  - **用户第三次澄清（原话「解锁车辆天赋树！=局内开局解锁车辆，应该=只有解锁车辆才会有局内解锁此车的解锁天赋卡。无论天赋树如何，开局自带的都是加速车」）**：天赋树的「解锁××车」节点**不是**"开局就能用这车"，而是**"局内那张『解锁××车』卡才会进池"**；开局自带**永远只有加速车**，与天赋树无关。
  - **改动**：①`ResetGame` 删掉「把 `talentUnlockedBalls` 的车并入 `unlockedBalls`」那段——开局 `unlockedBalls` 恒为 `{speed=true}`；②`CanOfferUpgrade` 新增门控——`unlock_*` 卡除「车尚未解锁」外，还要求 `talentUnlockedBalls[该车] == true`（天赋树解锁了才出现）。
  - **完整三层门控（现在的最终语义）**：天赋树解锁车 → 局内出现该车的**解锁卡**；局内解锁卡被选中 → 该车**本局**进入弹药队列；天赋树解锁专属卡节点 → 该车的**专属卡**才进池。未在天赋树解锁的车，局内既不出解锁卡、也不出 base/专属卡。
  - **验证**：官方多人 build+预览上传 ✅；探针 `probe_talentball` PASS——①任何天赋下开局都只有 speed ②天赋解锁 ice → 出现 `unlock_ice` 但 ice **未**预先解锁 ③未在天赋解锁的车 → 解锁卡都不进池 ④`unlock_speed` 永不出现。
  - ⚠️ **别再把「天赋解锁车」当成「开局可用车」**：本项目为此改了三轮（v0.13.19 加了开局解锁 → v0.13.20 撤回并改成门控解锁卡）。天赋是**卡池开关**，不是**初始装备**。
- 版本: 0.13.19b（尾迹二次打回真修复：头锚定速度反向 + 光带瘦成车的配角；提交 3702e07）：
  - **用户二次点名同一症状**（「拖尾和车分离且图层比车还高了」）→ v0.13.15b 第一次修复读错根因。量化真凶：①旧回缩 `math.min(radius*1.15, hl*0.5)` 被钳到**采样间隙的一半（≈2.75px）**，车屏幕半长 23px，头根本没挪出车体；②光带头段全宽 29px≈车宽 2 倍，overlay 天然压 3D，「粗亮条骑在车上」即被读成「图层比车高」。
  - **修法**：头部沿**速度反方向**退 `radius*1.30`（飞行车显示朝向=速度朝向，同 Renderer3D 约定；不依赖采样间隙、慢速天然不反向）；光带瘦身为配角——头全宽 8.8px(radius20) 明显窄于车身、峰值 alpha 200→165；alphaMax 放进 group 表携带（**不为新参数加模块级 local**：改后槽位 199→主动收回 198，AB-154 纪律）。
  - **验证**：数据探针加断言「头全宽 7.8px < 车宽 15px」ALL PASS；真渲染发射冒烟零错误；前向引用 0；BUILD_VERSION 与并发初始车批次共用 0.13.19（记忆用 b 后缀区分，AB-131 惯例）；官方多人 build+预览上传 ✅。⚠️ 待 Preview：贴车观感终验。
- 版本: 0.13.19（初始车改加速车 + 四车都能局内解锁；提交 78cac51）：
  - **用户澄清机制分工（原话「天賦树解锁局内卡，局内卡解锁惧内车另外基础的车改为加速车」）**：①**天赋树**解锁「专属卡」（v0.13.16 已做：`ballCard` 节点）；②**局内卡**解锁「车」（保留 `unlock_*`）；③**初始车从分裂车改为加速车**。上一轮我把「封锁卡片还在局内生成」误读成要删局内解锁卡——用户指的是**另一件事**：他以为车只该由天赋树解锁，实际设计是「局内卡解锁车 + 天赋树解锁专属卡」两层，现在明确了。
  - **改动**：`STARTING_BALL_TYPE` `"normal"` → **`"speed"`**（连带把 `PauseReload` 里写死的 `or "normal"` 兜底改成 `or STARTING_BALL_TYPE`）；`TalentCatalog.AUTO_OWNED` `normal_1` → **`speed_1`**（初始车的「允许出场」节点自动拥有）；新增 `unlock_normal`（解锁分裂车）卡，四车都有对应解锁卡——初始车自己的解锁卡由 `unlockBallType` 门控自动退池，不会出现。
  - **验证**：官方多人 build+预览上传 ✅；规则探针 `probe_start` PASS——①开局 `unlockedBalls.speed=true / normal≠true` ②`AUTO_OWNED = speed_1` ③无天赋时 `unlock_normal/ice/giant` 都在池、`unlock_speed` 已退池 ④分裂车未解锁时 `base_split`/`split` 都不进池；战斗真渲染冒烟零 overlay/Lua 错误。
  - ⚠️ **两层解锁是正交的，别把任一层当"多余"删掉**：`unlock_*` 卡（车）与天赋 `ballUnlock`/`ballCard` 节点（出场资格 / 专属卡）各管一段；`CanOfferUpgrade` 的门控链是「车解锁 → base 卡」「车 + 天赋 ballCard 节点 → 专属卡」「`unlockBallType` 未解锁 → 解锁卡」，三者缺一不可。
## 当前状态
- 版本: 0.13.18（修平台报错链：官方素材 pin 订阅 + 主块 local 超限黑屏）：
  - **用户上报（12 条 / 2 唯一）**：`Error processing XMLHttpRequest response: {}` ×11 + `Could not find resource <official-res>/assets/DgRecSAR4qVdwosqqNXg2Hhe-5dd512f9.ktx`。根因链（全在构建产物里取证闭环）：`.build/asset_adopt.json` 记录项目「采纳订阅」了官方资产 `BgCviebF...=generated/__official_pinned_refs__.json`（#blocking），构建时注入 client/server 清单 → 运行时按链 DWP 拉取 18 个官方材质闭包（M_CarPaint/CelToon/PBRTriplanar/M_Grass_3D/**DiffSkyboxFog→Skybox.xml→Skybox.ktx 14MB**+shadercache .pak），预览环境拉 14MB 天空盒反复 XHR 失败（`{}`×11）→ 最终报找不到该 ktx。我们的代码**零依赖** official-res（8 类资源全在 engine-res，材质全程序化）→ **`settings.json` sources 删除 `official-res`**（治本：pin 随源消失，新清单 sources=[engine-res]、pinned=False）；同时删除已无引用的旧皮卡 `assets/model/6d5f1062...`（v0.3.x MDL 时代遗留，内含 4 个 uuid:// 远程引用；v0.13.1 六车型程序化后无人加载）。
  - **顺带揪出阻塞级黑屏 bug（真渲染冒烟时发现）**：`Scene3DBackend.lua` 主块顶层 local 达 **201 个 > Lua LUA_MAXLOCALS=200** → `LoadChunk failed: too many local variables` → 模块加载不了 → **整游戏黑屏 2D 全没**。⚠️ **官方 build 与 LSP 都不检查这条编译期上限，只有真运行时暴露**。回收 2 槽 →198：删 `projectionOriginNdcX_/Y_`（写而不读死变量）与 `MENU_CONTENT_BOTTOM`（零引用）。⚠️ 并发会话 v0.13.17 又向该文件加了 9 个模块级 local——**此后任何人给 Scene3DBackend 加顶层 local 前必须数槽位**（脚本统计法见避雷），逼近 200 就把同族变量收进一张表。
  - **验证**：新 dist 清单 client/server 均 sources=[engine-res]、无 pinned、无 Skybox；真渲染冒烟（启动→开局→发射）零 LoadChunk/overlay stage/Lua 错误，letterbox 存活、菜单/战斗完整渲染；本地残留 3 条报错为 `.cli` 环境既有噪音（Linux 无体素模块 ECEBFC51、本地缺 Vignetting.png 与 Skybox.xml 的 engine 自带数据——历史各版本探针日志同样存在，与上报无关）。官方多人 build+预览上传 ✅。BUILD_VERSION/大厅 →0.13.18。⚠️ 待 Preview：确认平台错误上报不再出现 XHR{}/ktx 两条。
- 版本: 0.13.17（skill 固化 + dark-tech 氛围层实装 + 旧图标重出 + 死代码清理；版本号由并发会话推进，本批未动 BUILD_VERSION）：
  - **用户两点要求**：①「skill 没有我们有的，规范补进 skill，比如生图工作流」②「补充图标的部分。然后对照我们没用上的使劲用上优化画面」。
  - **skill 补充（`.agent/skills/`，本批主要产出之一）**：①**dark-tech-game-editor-ui** 新增 `references/pipeline.md`（「界面素材生成与落地管线」：三类素材分类 / 项目 8 色板量化 / 32×32 母版 / 非方形字标 / `.meta` uuid / `ICON_PATHS`+NEAREST 装载 / 死键检查 / 全流程清单），SKILL.md 挂链接 + 工作流加「元素先分类」步 + 验收补 3 条；`references/atmosphere.md` 加「**克制实装**」一节（默认档：只上底噪/扫描带/半调/残影，不接强调色切换与文本异变；判据「这层会不会出现在玩家要读的东西上」）。②**0718-pixelimage-aigc** 新增 `references/urhox-icon-integration.md`（UI 图标统一规格 / 图标只画主体 / 非方形字标 / `.meta`+`ICON_PATHS` / 死键检查 / **存量色数审计** / 重出流程），SKILL.md §5 加 5.1–5.3 + 验收补 2 条。
  - **UI 氛围层（`Scene3DBackend.lua`，克制档）**：新增 `AnomalyPulse`（全屏共享 0..1 标量；基线 `0.08+0.06·sin` 不为 0、取模周期尖峰而非随机）+ 原未用原语 `DrawDashLine/DrawCrossMark/DrawTickRing/DrawHalftone/DrawScanBand` + `DrawModalTechDecor`；C 表补 `wash/washDim/ghost/klein/halftone/ash/railMark`。落点：**菜单**（半调网点 + 右侧装饰位扫描带 + 两侧虚线轴 + 十字取样点）、**结算/胜利/暂停窗**（环形刻度 + 虚线轴 + 半调底纹 + 十字）。**HUD 与战斗读数区一律不进装饰**。
  - **接上/清理死代码**：①`DrawBossPhaseBar` + `FindBoss` 定义了却**从未调用**（Boss 阶段条此前根本不显示）→ 接进 RenderOverlay 的 playing 分支（Boss 在场才画）。②5 个「已加载却从未绘制」图标键：`gem`→钱包条钻石（`premium_energy_core` 留给充值钮）、`boost`→HUD 零件 ×2 增益；`wheel/supply/pass` 已被 premium_* 取代 → 从 ICON_PATHS 删除（41→38）。③删对应 3 张 PNG + `.meta`。
  - **旧图标重出（0718 管线）**：审计发现早期 **26 张 `ui_icon_*` 实测 100–583 种颜色**（AI 原图直接缩到 32×32、没过管线；v0.12.9 之后的图标都是 8–9 色）。按原语义**重出 21 张**（nanobanana 512 草案 → bbox 裁切 → LANCZOS 缩到主体 26 → alpha 二值化 128 → 量化到项目 8 色 → 居中贴 32×32），全部 6–8 色达标；**沿用旧文件名覆盖**（ICON_PATHS 与 `.meta` 不变、零路径风险），另删 3 张失效（pass/supply/wheel）。
  - **验证**：官方多人 build + 预览上传 ✅；LSP 我改的 `Scene3DBackend/MetaUI` **0 Error**；全库前向引用扫描 0；真渲染探针（菜单 + `Game.StartStageAt(1)` 战斗态）**零 overlay stage 失败**，截图确认菜单新图标全渲染 + 氛围层克制可见、战斗 HUD/Dock/弹药槽/下一波预览正常。⚠️ 探针抓到真 bug：`DrawScanBand` 把 `DrawRect` 的 radius 与颜色表**参数写反**（`0, {color}` 应为 `{color}, 0`）→ 菜单 stage 报 `attempt to index a number value (local 'color')`；已修。
  - **并发会话 v0.13.17（天赋树布局/交互修复，本批未提交其文件）**：`TalentTree.lua` ROW_STEP 128→160、general_b/ice/giant 线路错开半阶段、新增右侧固定可拖滚动条、节点选中后滚到浮窗上缘以上并按线路色区分三态；根因=鼠标/触摸 Down 已启动 `ScrollBegin`、未移动的 Up/End 又重调 `HandleMetaPointerDown` 再次 `ScrollBegin` → `HitTest` 从不触发；`client_main.lua` 新增 release-only `HandleMetaPointerClick`，两个拖拽页面都走它。其 `TALENT-RELEASE`/`TALENT-INTERACT` 探针 PASS。
  - ⚠️ 本批只提交 `Scene3DBackend.lua`/`MetaUI.lua`/21 张图标 + 3 张删除 + 两个 skill；`TalentTree.lua`/`client_main.lua`/`VisualCatalog.lua`/版本号（BUILD_VERSION + lobby → 0.13.17）属并发会话，未触碰。
- 版本: 0.13.16-talent 补充二（天赋树滚动条引导；提交 0b69a26）：
  - **用户反馈（附截图，红框圈出滚动条）**：「这个引导性不强，后面加一个灰色的轨道，不然玩家怎么知道这个可以滑动」。
  - **两处根因**：①原轨道用 `C.rail`（22,36,56）与深色底（7,11,20）**几乎同色**，肉眼看不见；②更关键——旧 `DrawScrollbar` 把**整条滚动条（含轨道）**都放在 `GetScrollbarThumb` 之后并 `if not thumb then return end`，而 `thumb` 只在 `maxScroll > 0` 时存在 → **不选中节点/内容不够高时连轨道都不画**，完全没有"这里能滑"的提示。
  - **修复**：轨道改为**常驻绘制**（`trackColor={96,112,132}` 中灰 + `trackEdge={148,166,188}` 浅灰描边），上下两端外侧各加一个程序化三角箭头；滑块仍只在有内容可滚时画。⚠️ 箭头放在轨道**外侧**、不动 `scrollbarTrack`/`GetScrollbarThumb` 的内部数值——滑块几何与命中（`SetScrollFromThumb`）共用同一组数字，改内部会连带影响拖拽。
  - **验证**：官方多人 build+预览上传 ✅；真渲染探针 `probe_talent_shot`（经 `DebugOpenScreen("talent")` 真正打开面板）截图确认——灰色轨道像素 **58 → 915**、纵向覆盖 y=141~906 全高，青色滑块清晰压在轨道上。
  - ⚠️ **滚动条这类"可交互提示"必须常驻，不能跟着状态显示/隐藏**：它是"能操作"的引导，不是"正在滚动"的指示器。凡「有隐藏操作入口」的面板（可滚动、可拖拽、可横滑）都要给一个**静态可见**的把手/轨道。
  - ⚠️ **探针要真的打开目标面板**：本批探针一度只 `TT.SetSelected` 却没开面板，截到的是主菜单，白跑两轮。用 `ClientMain.DebugOpenScreen(name)` 是正式窄接口，比伪造输入可靠。
- 版本: 0.13.16-talent 补充（专属卡门控真凶 + 局内卡显著强于天赋树；提交 0171cf7）：
  - **用户报「封锁卡片包括专属卡还在局内生成」**：探针先验（全新玩家 400 次抽卡只出分裂车系、`unlockedBalls` 正确）→ 排除车解锁门控；真凶是**天赋树的「专属卡」节点（`kind="ballCard"`, stage 2）规则层从未消费**——`Game.SetTalents` 只处理 `cardUnlock`/`ballUnlock`/`partsPct`/`stat`，`ballCard` 被静默忽略，于是专属卡只要车解锁就能抽，那个节点纯装饰。**修复**：新增 `talentUnlockedBallCards[ballType]`，`SetTalents` 收集 `ballCard` 节点，`CanOfferUpgrade` 增加「带 `ballType` 且 `kind ~= "base"` 的卡必须是专属卡且该车型已解锁 ballCard 节点」。
  - **「局内卡要显著强于局外的树」**：实测原值**天赋大节点全面 ≥ 局内卡**（分裂天赋 5% vs 局内 3%、冰冻 0.5s vs 1.2s、极速 5% vs 8%、贯穿 0.6 格 vs 1.0 格）——与用户预期相反。按「局内 ≈ 天赋的 3～5 倍」下调天赋：分裂 `0.02/0.05 → 0.005/0.008`、冰冻 `0.20/0.50 → 0.12/0.30`、极速 `1.02/1.05 → 1.01/1.02`、贯穿 `0.25/0.60 → 0.12/0.25`。同时修百分比文案精度（数值下调后 `%d` 会把 0.5%/0.8% 都显示成「+1%」，改为能整除用整数、否则一位小数）。
  - **验证**：官方多人 build+预览上传 ✅；探针 `probe_gate` PASS——①无天赋→无专属卡 ②**车解锁但未解锁 ballCard 节点→专属卡仍被拦**（本次核心回归）③解锁 ballCard 节点后专属卡出现 ④天赋节点值 ≤ 局内卡 1/3；`probe_vals` 确认文案区分小/大节点（`分裂概率 +0.5%` / `+0.8%`）。
  - ⚠️ **教训**：目录里定义了 `kind` 不等于规则层消费了它——本项目 `ballCard` 静默失效了 11 个版本（v0.13.5→v0.13.16）。新增 `kind` 时必须在 `SetTalents` 的 if-else 链里加分支，并写探针断言「该 kind 的效果真的生效」。
- 版本: 0.13.16-talent（天赋：成长线改暴击/攻击 + 暴击实装 + 血量加成**全局说明一次**；版本号由并发会话推进）：
  - **用户追加澄清**：「加血量上限一点的效果是所有卡的」→ 血量加成是**所有卡通用**的规则，因此**不在每个节点里逐条重复**，改在天赋树**顶部统一说明一次**（`TalentCatalog.HP_RULE_TEXT = "每解锁 1 个天赋：生命上限 +1"`，`TalentTree` 标题栏下方渲染）。规则层效果不变（仍是「每个已解锁节点 +1 上限，不分卡的种类」，探针实测 5 个混合类型节点 → `hpBonus=+5`）。
  - ⚠️ 上一版（同日更早）曾把「生命上限 +N」拼进 42 个节点 desc——本批已撤销该重复，`WithHp()` 退化为直通函数，避免调用点散落改动。

  - **用户三点要求**：①「天赋树的血量加成要写出来」②「经验和扩容都是通用卡」③「成长里面应该只有子弹『伤害暴击率+2%学了上限额外+5』」。二次澄清：**每阶暴击率 +2%**、**每三阶额外 +1 基础攻击**、**暴击 = 伤害 ×1.5**、**结算零件 +5% 保留作为填充**。
  - **数据层 `TalentCatalog.lua`**：新增 `CRIT_MULT=1.5`/`CRIT_PER_STAGE=2`/`ATK_EVERY=3`/`ATK_GAIN=1`/`MASTERY_CRIT=5`；新增 `WithHp(text)` 把「生命上限 +N」统一拼到**每个节点 desc 尾部**（42 节点全覆盖）。**成长线 `general_a` 重做**：`kind="stat"`、`stat="critChance"`，每阶 +2%，第 3/6 阶附 `atkBonus=1`，第 7 阶（学满）= `+7%`（2% + 5% 额外）。**通用卡线 `general_b`**：1 阶=经验卡、3 阶=弹药扩容卡（经验卡从原 general_a 移来），其余阶=结算零件 +5%。节点结构新增 `atkBonus` 字段。
  - **规则层 `Game.lua`**：新增 `talentCritChance`/`talentAtkBonus`；`SetTalents` 里 `stat=="critChance"` 走**累加分支**（不再当车线路 ballStat 处理）；新增 `TalentDamageBonus()` 把 `talentAtkBonus` 并入**所有弹种**伤害；新增 `ApplyCrit(base, marble)` 按暴击率掷一次、命中 ×1.5 并 `Emit("crit_hit")`。⚠️ 注释写明「`GetMarbleDamage` 在子步进里被多次调用，但每次对应一次命中结算、同帧同砖已由 `frameHitBricks` 去重，故不会重复掷」。快照新增 `talentCritChance`/`talentAtkBonus`/`talentHpPerNode`；`GetTalentBonuses()` 补 critChance/atkBonus。
  - **表现层**：`FEEDBACK_MAP` 增 `crit_hit → critSpark`，金色「暴击」飘字 + 2~3 粒金色火花（与普通命中区分）。
  - **UI**：天赋树浮窗本来就渲染 `node.desc`，血量加成因此**自动可见**（实测 `暴击率 +2% · 生命上限 +1`）——`TalentTree.lua` 当时正被并发会话改（滚动条/布局），本批**未碰它**。
  - **验证**：官方多人 build+预览上传 ✅；规则探针 `probe_growth` PASS（42 节点全带血量文案、成长线合计 19% 暴击 + 2 攻击、经验卡@1/弹药卡@3、注入后 `hp=+7 crit=19% atk=+2`、1500 帧内 `brick_hit=254` 中 `crit_hit=34`）；`probe_growthdraw` PASS（浮窗文案 + 绘制无错）；战斗回归零 Lua/overlay 错误。
  - ⚠️ **同一份记忆里两条 0.13.15**：本批与并发会话的尾迹迁移都落到了 0.13.15，本批在记忆里记作 `0.13.16-talent`（脚本提交 `a62b004`），版本号常量仍由并发会话统一推进。
- 版本: 0.13.15（车辆尾迹迁移到已验证可见的 NanoVG 覆盖层）：
  - **根因/决策**：两版 3D 尾迹真机都「不可见」（v0.13.3 软圆 billboard、v0.13.10/11 ribbon CustomGeometry）——本地离屏 3D 因 llvmpipe BloomHDR 编译失败恒黑，无法自证可见；本环境唯一已验证可见的是 NanoVG overlay 通道（冲击环/飘字用的 `ProjectGamePoint` 投影）。故尾迹彻底改走覆盖层，规则层零改动。
  - **数据层 `Presentation.UpdateVehicleTrails`**：每帧读飞行车辆快照（`activeBall` 与 `marbles` 中非 onSling 者），**按路程**在**游戏坐标**采样点（间距 11px、寿命 0.34s、每车≤20 点、同屏≤10 车），相邻点连成渐宽渐亮四边形段（尾细头粗、头 alpha≈200）输出 `vehicleTrails`（`[{ballType,polys={x1..y4,a}}]`）。重开（elapsed 回卷）、非 playing、瞬移（>50px）均清空；发射瞬间按 id 去重防 activeBall/marble 双收导致双倍老化；静止弹弓车不拖尾。
  - **绘制层 `Scene3DBackend.DrawVehicleTrails`**：在 world-fx 段（跟随震屏、playing 才画）用 `SLOT_COLORS[ballType]` 弹种色 + 头部向白热混合，`NVG_LIGHTER` 加色叠出「热焰拖尾」——四边形填充叠一道更亮的芯线描边强化方向感。
  - **回滚**：`Renderer3D` 里 3D ribbon 全套常量/状态/函数（`SyncVehicleTrails`/`ClearTrailSamples`/`AddTrailQuad`/`TrailColor`）与 Init/Render/Shutdown/ClearRunVisuals 钩子整段删除（含并发会话 v0.13.11 的空缓冲防护）。⚠️ 用脚本切整段时误删了紧邻的 `local function SyncDebris(presentation)` 签名行（注释在签名之后），补回后 LoadChunk 恢复正常——**整段删除要以「函数签名行」为边界锚点，不能只锚注释**。
  - **验证**：离线数据探针 PASS（直线 7 段、头宽 14.7、峰值 alpha 200；静止弹弓车/gameover 零拖尾）；真渲染发射→飞行冒烟零 Lua/overlay/VertexBuffer 错误；LSP 我改的三文件 0 Error；前向引用扫描 0；官方多人 build+预览上传 ✅。⚠️ 待 Preview：真机拖尾观感与长度/亮度手感（覆盖层光带是 2D 屏幕空间四边形，斜俯视下不随车辆透视缩放，属预期）。BUILD_VERSION/大厅 →0.13.15。
  - ⚠️ **并发**：本批只提交 `Renderer3D/Presentation/Scene3DBackend`（`31e0da1`）。提交时并发会话正把 `Game.lua` 改到**语法错误中间态**（LSP 报 `ApplyBrickStatus` 附近 `unexpected token` + 若干 `undefined global`），非我文件、未代其修复；等待其自行补完（现 `Game.lua` 语法恢复正常）后才构建。构建一并带上了并发会话已入工作树的选关/天赋改动（其 versions 已到 0.13.14）。
  - **v0.13.15b 真机反馈修复（用户：「和车分离且图层比车还高了」）**：①**分离根因 = z 投影**——overlay 光带按玩法平面 z=0 标定投影（`UpdateProjectionMetrics` 三点全在 z=0），而车辆根节点在锚点深度 z≈-0.086~-0.13m，46° 斜俯视正交下 z 会进屏幕 Y → 光带整体悬在车上方约 5px。修法：投影标定加 `projectionDepthX/Y_`（同 x/y 只差 z 的 **W2S 两点对测**，别拿 z 探针混 WorldFromGame 原点否则混入 x 分量）；`Renderer3D.VehicleDepthZ(radius)` 导出与 `GetVehicleAnchorWorld` 同式的深度；`ProjectTrailPoint(x,y,z)` 供尾迹按车深投影；group 携带 radius。②**盖过车根因** = overlay 天然在 3D 上 + 头段全宽 ~29px > 车头 ~15px。修法：光带头部沿来向**回缩 radius×1.15**（≈车尾）并钳 ≤ 间隙一半防慢速反向；world-fx 内尾迹移到冲击环/飘字**之前**绘制。验证：数据探针 ALL PASS（回缩后仍 7 段/头宽 14.7）、前向引用 0、LSP 我文件 0 Error、多人 build+预览上传 ✅。⚠️ 待 Preview：贴车观感与遮挡层级。
- 版本: 0.13.14（选关重做为「开心消消乐式蜿蜒路径地图」）：
  - **用户否决 v0.13.13 的样式**（原话「不行，我想要开心消消乐那种的」+ 参考图）：上一版是「直线微偏移 + 细描边圆钮」，被判定不像消消乐。参考图（`assets/image/下载 (3).webp`）的关键特征：**粗壮的蜿蜒路径**（大振幅蛇形，不是轻微抖动）、**节点像可点的糖果钮**（亮色厚环 + 亮芯 + 粗体描边数字）、**三颗星在节点下方外侧**、**两侧竖排圆形图标栏**。
  - **重做 `ui/StageSelect.lua`**：①`SWAY_AMP` 46→**96**、`SWAY_PERIOD` 4→**3**、`ROW_STEP` 96→**132**——大振幅 + 长周期才看出"蛇形路径"；②新增 `StrokePath`（Catmull-Rom → 三次贝塞尔，`nvgBezierTo` + `NVG_ROUND` 端点）把各关圆心串成**平滑曲线**，三层叠画（路肩 40px 深色 → 路面 30px → 高光 8px 青）做出"一条有厚度的路"；③节点改**大圆果冻钮**（半径 40，落影 + 亮色厚环 + 亮芯 + 顶部高光），数字 42px 粗体（三位数 30px）；④**三颗星移到圆钮下方外侧**（`sy = cy + r + 12`）——首版误画在圆内底缘被裁掉一半；⑤左侧道具栏改**圆形图标钮 + 角标库存数字**（`DrawRoundIcon`），右侧保留确定性像素装饰。
  - **验证**：官方多人 build+预览上传 ✅；真渲染截图确认（蜿蜒路径三层可见、金色厚环圆钮 + 粗体数字、星在节点下方、左侧圆钮带角标）——量化：路肩深色 8564px、亮青 1646px、金星 1695px；`probe_towerdraw` PASS（绘制无错、`buy_item,1` 命中、滚动 begin/move/end）；规则探针 `probe_tower` 仍 PASS。BUILD_VERSION/大厅 →0.13.14。
  - ⚠️ **探针工程同步脚本时必须用已提交版本**：并发会话正在编辑 `Renderer3D.lua`（半成品、语法不完整），直接 `cp -r scripts/.` 会让探针 `LoadChunk failed`、截图变成纯色。做法：`git show HEAD:scripts/<file> > 探针路径` 取已提交版本，只覆盖自己改的文件。
  - ⚠️ **与并发会话同改一个文件时用 hunk 级暂存**：`Scene3DBackend.lua` 里并发会话加了尾迹绘制（+45 行），我只改了 `BUILD_VERSION` 一行。`git apply --cached` 一个只含该 hunk 的 patch（从 `git diff -U3` 抽出）即可只提交自己那行，工作区保留对方改动。⚠️ 手写 patch 必须带 ≥3 行上下文，否则 `patch does not apply`。
- 版本: 0.13.13（选关改无限爬塔 + 道具永久库存）：
  - **选关重做（用户给参考图 + 规格）**：`ui/StageSelect.lua` 从「15 关网格」改为**纵向无限爬塔**——中间一列**圆形关卡按钮**，圆心用 zpix 位图字体画关卡数字（≥3 位数自动缩小到 22px）；**第 1 关在最下方、越往上关数越高**；每层横向偏移是 `StageSelect.StageSway` 的**确定性正弦**（`sin((stage-1)/4*2π)*46`，固定写死在代码里，非随机），形成错落爬塔感；相邻关之间画竖直短虚线。打开面板（`OpenMetaScreen`/`DebugOpenScreen`）默认 **`FocusLatest` 定位到最新已解锁关**。可上下拖拽滚动（沿用天赋树那套 `ScrollBegin/Move/End` + 编排层 `stageSelectScrollArmed` 转发，拖动过则吞掉本次点击）。
  - **两侧空余空间**：①**左侧栏 = 花零件买局内道具**（`ui/ItemShop.lua`：炸弹 120 / 冰冻 100 / 护盾 100 零件，库存封顶 3）；②**右侧栏 = 随机低透明度像素插图**（3 种程序化小图，按滚动位置确定性挑选、alpha 26~40 纯装饰）。
  - **道具「每局每样限用一次」**：规则层 `Game.itemUsedThisRun` 在 `CanUseItem` 里拦截，`UseItem` 置位；快照 `items[].usedThisRun` 供渲染层用**精灵变暗 + 角标数字**表达，**界面上不写任何文字说明**（用户明确要求）。库存为 0 时图标压暗到 0.28。
  - **关卡无限**：`StageCatalog.STAGE_COUNT` 改为 `STAGE_SOFT_CAP`（仅作难度封顶参考，不再是硬上限）；`Game.NextStage` 去掉上限判定、`stageHasNext` 恒真；难度公式全部可外推（速度/召唤次数/间隔早已 `math.min` 封顶，方块血量继续每 3 关 +1，精英/Boss 按取模循环）。选关列表只列到「最高已解锁关」，随进度增长。
  - **库存持久化**：`PlayerData.itemStock`（`AsIntMap` 解码 + 云合并取更大值）；`Game.SetItemStockProvider(PlayerData.GetItemStock)` 注册一次，**`ResetGame` 开局自动拉取**（覆盖选关/下一关/再战/重开全部入口，沿用天赋树的 provider 模式）。
  - **验证**：官方多人 build + 预览上传 ✅；规则探针 `probe_tower` PASS（1~1000 关难度公式全合法、道具首次可用/二次被拦、usedThisRun 置位、provider 重开自动重注入、可开第 40/200 关）；真渲染 `probe_towerdraw` PASS（面板绘制无错、道具行命中 `buy_item,1`、滚动 begin/move/end 正常）+ `probe_towerfull` 通过 `DebugOpenScreen("stage_select")` 真实打开并截图，面板区 4040 色、塔身带 936 色、金色星条 1328px、左侧栏 1967 色；战斗回归零 Lua/overlay 错误。全库前向引用扫描 **0 问题**。
  - ⚠️ **provider 声明必须在 `ResetGame` 之前**：`itemStockProvider` 若声明在文件后段，`ResetGame`（582 行）开局就调用它会读到全局 nil（AB-100 同族）——已前移到第 133 行，与 `ResetItems` 前向声明同处。
  - ⚠️ **探针验证要贴调用契约**：`Game.StartStageAt` 只在 `menu` 态有效，连续开两关之间必须 `GoToMenu()`（本次探针连踩两次）；`GetSpecialKey` 对**普通波返回 nil 是正常的**，只有精英/Boss 波有关键字。
- 版本: 0.13.12（天赋树：星级门槛改按横行 + 拉开间距支持滑动）：
  - **用户澄清两处（原话「支持上下滑动页面，不要塞这么死。另外他妈的一共有六条，星星们限制的阶段指的是每个横行从下到上」）**：①**星级门槛属于「阶段（横行）」不是「线路（纵列）」**——早期版本用 `TalentCatalog.STAGE_STARS[li]`（`li` 是线路索引）显示成「成长 0★ / 通用卡 3★ / 分裂车 9★…」，读起来像每条线路星级要求不同，语义完全错。现改为**左侧独立门槛栏**，按横行从下到上标（最底行 0★ → 3★ → 9★ → 18★ → 27★ → 36★ → 45★），门槛与线路解耦；顶部表头只留 6 条线路名。②**内容必须显著高于可视区才能滑动**：原 `ROW_STEP=92` 且 `topPad/botPad` 偏小 → 内容总高恰好等于可视区高 → `MaxScroll=0`、滚不动、「塞这么死」。现 `ROW_STEP` 92→**128**、卡半径 34→**30**、`topPad= CARD_R+40`/`botPad=CARD_R+24`、表头由两行收成一行 → 内容总高 **892** vs 可视区 **678**，可滚动约 **214px**（约 1.7 个阶段）。
  - **卡片**：去掉卡面上重复的阶段序号（改由左侧栏统一标注）；新增左侧 44px 门槛栏（`LABEL_W`），线路列相应收窄。
  - **验证**：LSP 0 Error；真渲染截图确认（左侧 0★/3★/9★/18★ 按横行标注、卡片不再挤、顶部内容被裁切即说明可上滑）；官方多人 build+预览上传。BUILD_VERSION/大厅 →0.13.12。
  - ⚠️ **教训（同一处连错两轮）**：给"矩阵式"界面（6 线路 × 7 阶段）标门槛时，**先确认门槛挂在哪条轴**——本项目门槛属于**阶段轴（横行）**，用线路索引去查 `STAGE_STARS` 是轴错位。另一个通用坑：**可滚动容器必须让内容高度显著大于可视区高度**，把两者凑到相等（或相等附近）等于禁用滚动；设计时先算 `contentH - content.h` 的差值再定间距。
- 版本: 0.13.11（修平台报错「VertexBuffer is empty!」）：
  - **根因（本地真渲染复现 + 日志时序实锤）**：用户上报 2 类错误，其中 `VertexBuffer is empty!Material ,compute:(nil),vertexBufferSize:1,geomerty type:0` 由**尾迹光带**造成——v0.13.10 新建 4 个 `VehicleTrail_*` 节点后，`CustomGeometry` 在**提交任何几何之前**节点就是启用状态，渲染器尝试绘制空顶点缓冲即报错（日志时序：`trail ribbons ready` 15:47:49.500 → ERROR 15:47:49.576，晚 76ms）。另两处同族：`ClearTrailSamples` 在收尾时 `Clear()` 后 `BeginGeometry+Commit` 提交 **0 顶点**几何；`SyncVehicleTrails` 在"有光带→无光带"收尾帧用空 `verts` 提交。
  - **修复（三处，均不提交空几何）**：①创建尾迹节点后立即 `node.enabled = false`，等提交了非空几何再启用；②`ClearTrailSamples` 只 `geometry:Clear()` + `root.enabled = false`，不再 Commit 空内容；③`SyncVehicleTrails` 只在 `#verts > 0` 时 Clear+重建+启用，否则禁用节点。
  - **另一类错误 `Error processing XMLHttpRequest response: {}`（29 次）**：项目代码内**零引用** `XMLHttpRequest`，来自平台云变量请求层（云不可用时重试）。所有云调用已有 `pcall` + `error`/`timeout` 回调兜底、`metaSaveInFlight` 串行守卫，**不影响游戏运行，也无法在游戏代码内消除**——已如实标注，不做假修复。
  - **验证**：本地真渲染探针（`probe_trail` 启动期 + `probe_trail3` 完整一局含重开/清空重建路径）`VertexBuffer is empty` 由 **1 次 → 0 次**、overlay/Lua 错误 0；LSP 0 Error；官方多人 build+预览上传。BUILD_VERSION/大厅 →0.13.11。
  - ⚠️ **教训**：`CustomGeometry` 是"先有节点后有几何"的组件——**新建后、提交几何前必须禁用节点**（或立刻提交有效几何），否则渲染器报空缓冲；同理"清空/收尾"不要 `Commit` 0 顶点，禁用节点即可。这类错误只在真渲染时出现，LSP/build 都发现不了。
- 版本: 0.13.10（飞行尾迹重做 ribbon 光带）：
  - 用户否决 v0.13.3 尾迹「尾迹特难看廉价」——软圆串珠 + 不随朝向的等宽放大是廉价感根源。`Renderer3D` 尾迹改为沿运动折线的**渐窄渐暗光带 ribbon**：每弹种一个 `CustomGeometry` 批次（`DiffVCol` + 白底纹理 + CULL_NONE、法线 (0,0,-1)，敌机箱体同一条已验证显色路径），相邻采样点（末段接车辆当前位置）各出一个四边形；半宽头 0.22 → 尾 0.02 ×权威半径线性收束，顶点色按头程 `t^1.7` 压暗 + 头段向白热插值（引擎钳 Color 到 0..1，亮头只能靠白插值表达）；采样 0.035s/寿命 0.3s/每车 6 点/同弹种 8 车、jump/静止清轨、flightTime 回绕防 id 复用串轨、非 playing/重开/Shutdown 清空全沿用。规则层零改动。
  - **中间方案被弃**：billboard 沿运动朝向拉长的速度线——`Billboard.rotation` 屏幕旋向无法本地验证（llvmpipe BloomHDR 编译失败使离屏 3D 全黑、独立探针拿不到任何像素），不押注未知约定，改走可静态推导的几何 ribbon。
  - **验证**：LSP workspace 0 Error（修掉本批两处自身 doc 批注/窄化 Error）；前向引用 0；真渲染飞行段探针 30→160 帧（含暂停→恢复重建路径）零 Lua/overlay 错误、letterbox 存活；官方多人 build+预览上传 ✅。本批只提交 `Renderer3D.lua`（并发 v0.13.9 天赋树不冲突）；`BUILD_VERSION` 常量停在 0.13.8（v0.13.9 未推进），由并发会话统一处理。⚠️ 待 Preview：真机光带观感与密度。
- 版本: 0.13.9（天赋树改圆形爬塔卡 + 局内升级卡图标化）：
  - **天赋树重做（用户给参考图 + 明确规格）**：`ui/TalentTree.lua` 整体重写为**纵向爬塔式**——6 条线路各占一列（2 通用 + 4 车），每条线路阶段 1 在**最下方**、阶段越高越往上，节点为**圆形卡**（圆底 + 彩色圆环 + 32px 图标 + 状态角标），相邻阶段之间画**连线**（已解锁亮青、未解锁暗）。内容高于可视区 → **拖拽上下滑动**（`ScrollBegin/ScrollMove/ScrollEnd`，编排层从鼠标/触摸转发，拖拽后抑制本次点击）。顶部固定表头（线路名 + 星级门槛 0★/3★/…），点圆形卡 → **底部方形浮窗**（天赋名 + 线路·阶段 + 详情 + 按钮四态：解锁 N / 已解锁 / 未开放 / 零件不足 还差 X）。
  - **线路配色**：通用线路=品牌青；四条车线路用各自弹种色（分裂青 / 冰冻浅蓝 / 加速蓝 / 巨型金），与底部弹药槽一致。
  - **9 张天赋图标**：nanobanana 草案 → `0718-pixelimage-aigc` 管线（bbox 裁切→LANCZOS 32×32→alpha 二值化 128→项目 8 色板量化），色数 5–9 全达标、22hex uuid 全库唯一，NEAREST 加载。`assets/image/ui_icon_talent_{damage,repair,armor,xp,glass,overclock,ammo,unlock,word}.png`。⚠️ 草案先移出 assets（`/home/Maker/talent_icons/drafts`）再放成品。
  - **映射单一来源**：`TalentCatalog.ICON_BY_CARD/ICON_BY_KIND/ICON_BY_BALL` 是卡片/节点→图标键的**唯一映射**（节点构造时 `DecorateNode` 赋 `icon/tint`）；`Scene3DBackend` 与 `TalentTree` 都查它，禁止各写一套。`MetaCatalog` 也提供 `GetTalentIcon/GetTalentKindIcon` 供元层查。
  - **局内三选一升级卡加图标并重排 UI**：卡片顶部 34px 图标 + 暗色圆角底板（描边取稀有度色），「锁定/保留」角标移到右上避让图标；卡名 y74→86、稀有度 y102→114、分隔线 y124→136、详情上移到 y146 且最多 2 行（原 3 行）——因为顶部让出图标区。图标按卡 id → kind → ballType 回退。
  - **验证**：LSP 0 Error（本批文件；`Renderer3D.lua` 的 10 个 `TRAIL_*` 报错属并发会话在途改动，未触碰）；`probe_talentui` PASS（图标/tint/空白命中/滚动 begin-move-end）；真渲染截图确认天赋树（线路名+星级表头、圆形卡+连线、弹种配色、浮窗）与升级卡（图标全渲染）均正常、零 overlay/Lua 错误；官方多人 build+预览上传。BUILD_VERSION/大厅 →0.13.9。⚠️ 待 Preview：真机拖拽滚动手感、圆形卡密度、图标观感。
- 版本: 0.13.8（主菜单布局调间距 + 天赋树做成明确可点入口）：
  - **主页上下间距**：`MetaUI.GetMenuBarLayout` 整体下移并拉开行距——fleet 390/92→**400/106**、wallet 496/56→**524/62**、daily 588→**628**(h102)、grow 716→**770**(h102)。原先内容止于 ~808 而画布高 960，底部留约 150px 空白；现收束到 ~872，上下呼吸更匀。wallet 内容（图标/标签/数值/分隔线/充值胶囊）与 daily/grow 卡内图标框（42×40→46×44）、标签 y51→58、副行 y72→80 同步按新高度重排；底部 toast 848→**892**（原值会与新的养成行底边 872 重叠）。
  - **天赋树入口「像个能点进去的东西」**：`MetaUI.DrawHomeFleet` 重写——左侧 68×68 大图标框（`premium_energy_core`）+ 标题 21px + 「已解锁 N/M 节点」+ 解锁进度条 + **右侧青色实心「进入 ›」胶囊按钮**；有可解锁节点时整框描边青色高亮 + 右上红点，无则 `cyanDim` 压暗。仍整框命中 `open_talent`（`HitTestMenuBar` 未改，几何同源）。
  - **版本号修正**：`Scene3DBackend.BUILD_VERSION` 与 `lobby_runtime` 标题栏长期停在 **0.13.4**（0.13.5/6/7 三批交付均未推进常量）→ 本批一并 → **0.13.8**。
  - **验证**：LSP workspace 0 Error（19 files，0 error）；真渲染主页探针 `probe_menu`（离屏截图）——命中几何 PASS（fleet→open_talent、wallet→open_recharge、daily 3 卡、grow 4 卡 shop/pass/codex/rank 全部命中新坐标），截图确认间距均衡、天赋树入口「进入 ›」胶囊/进度条/红点清晰、零 overlay/Lua 错误。官方多人 build + 预览上传 ✅。⚠️ 待 Preview：真机行距观感、「进入 ›」胶囊点按手感。
- 版本: 0.13.7（主菜单大面板：敌机图鉴 → 天赋树）：
  - 用户澄清「上面那个大的敌机图鉴」指的是菜单 y=390 的**大展示面板**（原 8 架飞机剪影），不是养成行小卡。改动：大面板改为**天赋树入口**（标题 + 节点解锁进度条 + 「★N · 已开放 X/7 阶段」+ 红点提示），点大面板 `open_talent`；「敌机图鉴」降回养成行小卡，养成行恢复 **4 卡**（车型商店/战斗档案/敌机图鉴/排行榜，`row(716,92,4)`）。`GetGrowDefs` 移除天赋树项、`HitTestMenuBar` 的 fleet 命中改 `open_talent`；`DrawHomeFleet` 重写为天赋树进度面板。新增 meta 字段 `talentTotal/talentMaxStage/talentStageCount`（`RefreshMeta` 由 `TalentCatalog.GetNodes()/MAX_STAGE/GetUnlockedStageCount` 填）。
  - ⚠️ 上一版 v0.13.6 的「养成行内换位」是对用户意图的误解——用户说的是**大面板**。教训：菜单里同名/近名的入口有两处（大展示条 + 小卡）时，先确认指的是哪一个，别默认成小卡。
  - 验证：LSP 0 Error；`probe_menu` 命中探针 PASS（大面板→open_talent、养成行 4 卡→shop/pass/codex/rank）；真渲染菜单冒烟零 overlay/Lua 错误、letterbox=(7,11,20)、19838 非黑像素；官方多人 build+预览上传。
- 版本: 0.13.6（主菜单：天赋树与敌机图鉴换位）：
  - 「养成收藏」行内交换「天赋树」与「敌机图鉴」的显示顺序（现为 车型商店 / 战斗档案 / 天赋树 / 敌机图鉴 / 排行榜）。只改 `MetaUI.GetGrowDefs` 的 defs 数组顺序——绘制与 `HitTestMenuBar` 同源，交换即两处同步，无需改命中代码。验证：LSP 0 Error、官方多人 build+预览上传、真渲染菜单冒烟（letterbox=(7,11,20)、19837 非黑像素、零 overlay/Lua 错误）。
- 版本: 0.13.5-floattext（跳字特效修复：真实得分 + 就近聚合 + 越线不飘分；版本号行由并发会话统一推进，本批只改 `Game.lua`/`Presentation.lua`/`Scene3DBackend.lua` 的相关 hunk）：
  - **根因（用户点名「频繁的 +0」）**：`brick_hit` 的 `score` 在 `EmitBrickShatterFx`/`DamageBrick` 两处都硬编码 0——真实得分只在 `EjectBrick` 里累加进规则层 `score` 变量、从未外发；而 `Presentation.brickSpark` 对每次 `destroyed` 击碎无条件 `SpawnFloatText("+" .. event.score)`，于是每次击碎都飘 "+0"、真实得分从未显示。越线碎裂（惩罚）复用同一视觉事件，也错误地飘分。
  - **规则层**：`EmitBrickShatterFx(enemy, brick, x, y, scoreValue)` 新增第 5 参；`EjectBrick` 传 `data.score`（80~320/砖，随机型），`ShatterBreachedBrick` 不传（=0）——得分击碎与惩罚碎裂从此在事件数据上可分。
  - **表现层**：`SpawnFloatText` 加 `kind` 字段并返回对象；新增 `SpawnScoreFloat`——`kind=="score"` 的飘字在 46 设计像素内自动聚合累加（数字变大、寿命刷新重跳、按总值 24/27/30px 三档尺寸），同屏上限 6 条（超出时并入最近一条，**不丢分**）；`brickSpark` 只在 `event.score > 0` 时飘分。跳字手感：出生初速 -70~-90 上飘 + 线性减速到停（不回坠），绘制端入场 1.42 倍弹性收拢。
  - **验证**：LSP 0 Error（19 files 744 诊断）；纯规则/表现探针 `probe_floattext` PASS（真实击碎事件 score 与 `AircraftPixelData[key].score` 逐机型一致；越线碎裂 score=0；合成事件下 5 个近距击碎合并为 1 条 `+500`、10 个分散击碎被钳到 6 条且总值 1700 无丢失、score=0 不生成飘字）；真渲染 `probe_floatshot`（维持 playing + 持续注入合成击碎）零 Lua/零 overlay stage 失败，截图确认 `+300`/`+105200` 两条聚合飘字与深色描边渲染正常。官方多人 build + 预览上传 ✅。⚠️ 待 Preview：真机聚合节奏、数字跳动与尺寸分档手感。
- 版本: 0.13.5（天赋树：主页入口 + 阶段解锁 + 基础天赋池重构）：
  - **天赋树（`scripts/TalentCatalog.lua` 纯数据 + `scripts/ui/TalentTree.lua` 界面）**：6 行（2 通用线 + 4 车线）× 7 阶段。阶段星级门槛 `0/3/9/18/27/36/45`（第 3 阶起 +9），满星 15 关 × 3 = 45。每阶段 6 节点、**点一次即满**（单级）。解锁需 ①该阶段星级达标 ②同线路上一阶段节点已解锁（链式）。主菜单「养成收藏」行新增「天赋树」入口（现 5 卡，`GetMenuBarLayout.row()` 改为自适应卡宽防溢出）。
  - **节点类型**：通用线路 `general_a` 1 阶=解锁「数据回收」（经验卡）、`general_b` 3 阶=解锁「弹药扩容」，其余阶段=结算零件 +5%；车线路 1 阶=允许该车局内出场、2 阶=解锁该车专属卡、3/4/6/7 阶=小幅数值、5 的倍数阶=专属卡效果增强（数值更大）。**初始分裂车的 1 阶节点自动拥有**（`TalentCatalog.AUTO_OWNED = {normal_1}`，`EnsureAutoOwnedTalents` 幂等补上）。
  - **每个已解锁节点 +1 基地生命上限**（`TalentCatalog.MAX_HP_PER_NODE`）；血量上限不再由通用卡提供，改由 `Game.GetMaxBaseHp() = BASE_HP + talentMaxHpBonus` 统一（`repair`/暂停急救/星级评级/快照全部走它，保证上限与评级一致）。
  - **规则层接入（`Game.lua`）**：`Game.SetTalentProvider(fn)` 注册一次，`ResetGame` 每次开局自动拉取（覆盖选关/下一关/重开，避免在多入口重复注入）；`SetTalents` 把节点汇总为 `talentMaxHpBonus`（血量）、`talentPartsPct`（结算零件%）、`talentBallStats`（车线路 splitBonus/iceBonus/speedMul/giantArea 叠加）、`talentUnlockedCards`（xp/ammo）、`talentUnlockedBalls`（开局即解锁的车）。`CanOfferUpgrade` 新增 `requiresCard` 门控；`SettleParts` 在广告倍数前叠加零件百分比。⚠️ 天赋派生变量块**必须在 `UPGRADE_POOL` 之前声明**——`repair` 卡的 `apply` 闭包读 `talentMaxHpBonus`，后置声明会变成全局 nil（AB-100 同类）。
  - **基础天赋池重构**：`xp`/`ammo` 卡加 `requiresCard`（未解锁不进池）；四车各补一张基础数值卡（`base_split/base_ice/base_speed/base_giant`，`kind="base"`、`ballType` 门控）。
  - **存档（`PlayerData.lua`）**：新增 `talents`（节点 id→bool，`AsBoolMap` 读写，云合并取并集）；新增 `GetTotalStars`（星级总和，供阶段门槛）/`HasTalent`/`GetTalents`/`TalentCount`/`UnlockTalent`（扣零件+落盘）/`EnsureAutoOwnedTalents`。解锁动作由编排层 `HandleMetaAction("unlock_talent", nodeId)` 处理（`TalentCatalog.CanUnlock` 校验 stars/prereq/parts，失败给具体 toast）。
  - **验证**：LSP workspace 0 Error；前向引用扫描 0；纯规则探针 `probe_talent`（阶段门槛/线路链/节点类型/5阶>3阶/CanUnlock 三因/Game 注入血量与车解锁）PASS，`probe_talent2`（未解锁 xp/ammo 不进池、解锁后进池、零件%累加）PASS，`probe_stageflow` 回归 PASS；真渲染 probe_play 零 Lua/overlay 错误、截图非黑且 letterbox=深底。官方多人 build + 预览上传 ✅。BUILD_VERSION/大厅 →0.13.5。⚠️ 待 Preview：天赋树真机布局/点击、节点数值手感、菜单 5 卡信息密度。
- 版本: 0.13.4（关卡式：选关界面 + 胜利结算 + 星级/解锁存档）：
  - **选关入口**：主菜单「开始战斗」不再直接开局，改为打开 `scripts/ui/StageSelect.lua`（插件式注册进 `MetaUI.RegisterScreen("stage_select")`，复用注入令牌，零 urhox-libs/UI）。15 关按 5 列铺格，显示每关历史星级（★）与「未解锁」程序化锁形；点已解锁格 `HandleMetaAction("play_stage", index)` → `Game.StartStageAt(index)`。`Game.PointerDown/Up` 在 menu 态不再开局（`startArmed` 退化为防误触守卫）；键盘回车在 menu 同样转开选关。
  - **胜利结算态 `stagewin`（不再自动进下一关）**：`Game` 新增状态，Boss 击败即置 `stageResult`（含 stage/stars/rating/bonusScore/bonusParts）+ 提交最高分 + `gameState="stagewin"`；v0.13.0 的 4 秒休整自动进关逻辑（`stageClearPending`/`stageBreak`）整体删除。`Scene3DBackend.DrawStageWin` 复用 `DrawAnimatedWindow("game")` 弹动窗 + 命中逆变换；按钮「下一关 `Game.NextStage()` / 再战本关 `Game.RetryStage()` / 回主菜单 `Game.GoToMenu()`」由 `client_main` 松手确认（`HandleStageWinPointerDown/Up`，仿 gameover 模态）。`UpdateUiState` 的 leaving 快照三处 state 判定全部加进 stagewin，避免旧窗残影。
  - **评级 + 星级 + 存档**：`ComputeStageResult` 按剩余 `baseHp` 比例折算（≥0.75=完美3星 / ≥0.40=优良2星 / else 险胜1星），bonus=200×星 分、50×星 零件，随 win 计入 score/partsEarned。`PlayerData` 新增 `stageStars`（关号→最佳星）+ `maxStage`（解锁上界，win 后 =stage+1），`RecordStageResult/GetStageStars/GetMaxStage/IsStageUnlocked`；`AsStageStars` 把 JSON 字符串键还原整数并钳 1..3；`ImportFromCloud` 跨设备取更大星级、更远 maxStage。入库守卫 `TakeSettlementStats`/`SettleParts` 与 `client_main` 结算块扩到 `gameover ∪ stagewin`，win 时落库。`RefreshMeta` 填 `metaState.stageStars/maxStage` 供选关只读。
  - **验证**：LSP workspace 0 Error（build 上传 ✅）；纯规则探针 `probe_stageflow`（选关起点/波次密度翻倍/Boss→stagewin/星级映射/NextStage 累计波号/入库/hasNext 边界）PASS，`probe_partial_boss`（部分越线后击杀仍记 bossDefeated→stagewin）、`probe_boss_escape`（完全越线只扣血、血未归零重派同关第十波）迁移到新语义后 PASS；上一批 `probe_stage`（五关/50波/十精英/五Boss/召唤/184 色板无冲突 + 手动 NextStage）PASS。真渲染冒烟 probe_play 战斗帧零 Lua/overlay 错误。⚠️ 待 Preview：选关/胜利窗真机弹动手感、六车型 × 关卡节奏叠加后的真机帧时与手感。BUILD_VERSION/大厅 →0.13.4。
  - ⚠️ **关卡切换绝不走 ResetGame**（会清成长）；`StartGameAt` 只重置局内态并把 `wave` 换算为 `(stage-1)*10+1` 累计波号（每日任务「抵达第N波」在后期关仍成立）。`stage_started` 横幅仅 stage>1 播报，stagewin 由独立界面承接、`stage_cleared` 事件不再驱动表现（FEEDBACK_MAP 已移除 stageClearBanner）。
  - ⚠️ **多状态模态必须四处同步**：新增可弹窗玩法态（如 stagewin）要同时改 `UpdateUiState` 的 leaving/visual 判定、`RenderOverlay` 的 currentWindow/in/out 分发、规则层 `PointerDown/Up/GoToMenu/TakeSettlement`、`client_main` 六个输入处理器 + `HandleKeyDown` + 结算块——漏任一处就是「点不动/残影/入库丢」。用 grep 上一个同类态（gameover）的全部命中点逐一补齐。
- 版本: 0.13.3（车辆飞行尾迹 + 全窗口渐显渐隐弹动过渡）：
  - **3D 车辆尾迹（用户点名恢复）**：`Renderer3D` 新增 `SyncVehicleTrails`——只给**飞行中**（`not onSling`）车辆沿轨迹采样软圆点：0.035s 间隔、寿命 0.3s、每车最多 6 点、同弹种最多 8 车，四种弹药各一个 `BillboardSet`（DiffAlpha 颜色烘焙纹理，沿用 v0.10.21 透明粒子显色契约，4 draw call 封顶）；点尺寸锚定 `marble.radius*WORLD_SCALE` 随生命收缩，z 取车辆锚点 -0.05（斜俯视投影贴车）。非 playing 态、重开（ClearRunVisuals）与 Shutdown 均清空；`flightTime` 回绕检测防 id 复用串轨；静止/暂停采样不推进。规则层未改。
  - **窗口过渡动画**：`Scene3DBackend` 新增统一 `DrawAnimatedWindow`——入场 0.32s 渐显 + 弹性缩放（0.91→1.03→1.0，EaseOutCubic 两段），退场 0.18s 渐隐 + 微缩；覆盖**结算/升级/暂停**三个游戏窗口与**元层面板（任务/图鉴/排行/商城/档案/转盘/充值）+ 每日补给弹窗**，窗口按快照 state/screen/supplyOpen 变化驱动，独立视觉时钟 `uiClock_`（game.elapsed 差分、重开归零）与玩法解耦。旧四模态的 `ModalIntro` 整层 alpha 改为仅遮罩/内容分层处理（遮罩不随缩放、避免边缘漏底），主菜单保留原全屏淡入。
  - **命中同源逆变换**：窗口弹动期间输入不漂移——`WindowInput()` 对 `HitTestGameOverButton/HitTestUpgradePanel/HitTestPausePanel/HitTestMetaScreen/HitTestSupplyPopup` 做缩放逆变换后再判命中；退场残影在开新窗时立即作废（leaving 快照取消），防快速关闭重开叠绘。peer 会话点名的两个风险（backdrop 随缩放漏遮、残影叠绘）均已处理。
  - **验证**：LSP workspace 0 Error（17 files 652 诊断）；全库前向引用扫描 0；真渲染探针发射→暂停→恢复零 `overlay stage failed`/零 Lua 错误、`vehicle trails ready` 日志确认；官方多人 build + 预览上传 ✅（BUILD_VERSION 与大厅标题 →0.13.3，避让并发批次 0.13.1 六车型 / 0.13.2 弹药）。⚠️ 待 Preview：真机尾迹密度与帧率、窗口弹动手感、快速开关时遮罩是否仍漏。
  - ⚠️ **v0.10.0「废弃弹珠尾迹」契约已被用户于本批次显式推翻**：当时嫌的是 2D 球形弹珠的拖尾；3D 重卡飞行无尾迹反而显得"干"，恢复时按新契约执行（见避雷清单更新）。
- 版本: 0.13.2-ammo（开局弹药减为 1 辆 + 通用「弹药扩容」卡；版本号行由并发会话统一推进，本批次只改 `Game.lua`）：
  - **开局弹药 3 → 1**：`Game.lua` 新增 `BASE_AMMO_TOTAL = 1` 与 `ammoCapacity`（本局弹药总量）。`LoadBalls` 改为「先放 1 辆待发，再排入 `ammoCapacity-1` 辆备弹」——开局只有待发车、**没有备弹**；发射后要等球回收才补弹。
  - **通用天赋「弹药扩容」**：`id="ammo"`、common、weight 1、**maxStacks = 3**，apply → `IncreaseAmmo()`（`ammoCapacity + 1` 并**立刻**补一辆进队列；之后主球回收仍按「回收一辆补一辆」维持新总量）。它是通用卡（无 `ballType`/`unlockBallType`），任何车型、任何解锁状态都能抽到。
  - 快照新增 `s.ammoCapacity`；重开（ResetGame）复位为 `BASE_AMMO_TOTAL`。
  - **验证**：本地规则探针——开局 `ready=1 spare=0 total=1 capacity=1`；卡池出现该卡且 `maxStacks=3`；选中后 `capacity=2 spare=1 total=2`（立刻生效）；600 帧真实玩法长跑（含升级、解锁、重开）池子总量恒等于「`ammoCapacity` + 已解锁新车数」。官方多人 build + 预览上传 ✅。
  - ⚠️ **校验弹药池总量时必须计入「解锁追加」**（v0.12.13 记过同一条，本次探针又踩一次）：解锁新车会往队列插一辆，期望值是 `ammoCapacity + (已解锁车型数 - 1)`；写死等于 `ammoCapacity` 会在解锁那一帧误报成泄漏。
  - ⚠️ 并发会话当时正在改 `Scene3DBackend`/`Renderer3D`（窗口动画等，未提交），本批次**只提交 `Game.lua`**，不覆盖也不代提交他们的在途改动。
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
- 上次交付: v0.13.3 车辆飞行尾迹（3D BillboardSet 四弹种合批）+ 全窗口渐显渐隐弹动过渡（命中逆变换、遮罩不缩放、退场残影作废）

## 本批次新增避雷（v0.13.13 无限爬塔选关 + 道具库存）
- 🔴 **provider 型注入的 local 声明必须在「首次调用点」之前（v0.13.13 又踩一次）**：`itemStockProvider` 被 `ResetGame` 调用，若声明写在道具段（1700 行附近）而 `ResetGame` 在 582 行，则开局读到全局 nil → 库存永不注入。这与 AB-100（前向引用）、v0.13.5 天赋 `talentMaxHpBonus` 是同一族：**凡是「开局/初始化就会读」的模块级 local，声明一律前移到文件头部的前向声明区**（本项目集中在 `local ResetItems` 附近）。交付前跑前向引用扫描（注意：扫描器只认 `local function X` / `local X = function`，且要跳过 ≤4 字符的短名，否则 `y(`/`s(` 这类参数会淹没结果）。
- ⚠️ **「每局限用一次」这类隐性规则只走状态 + 视觉，不写字（v0.13.13 用户点名）**：用户明确要求「这种事别写出来，通过精灵图明暗和角标数字」表达。做法：规则层给 `usedThisRun` 布尔，渲染层用**图标压暗 + 角标数字**区分「没有 / 有 / 本局已用」，禁止加「每局限用一次」这类说明文字。同理，库存为 0 时压暗到 ~0.28 而不是画灰字。
- ⚠️ **无限内容面板必须给「确定性的伪随机」而不是真随机（v0.13.13）**：塔身横向偏移用 `sin((stage-1)/4*2π)*AMP`（同一关永远同一偏移），右侧装饰插图按滚动位置取模挑选。用 `math.random` 会让每帧位置抖动、重开对不上，玩家一眼看出是 bug。
- ⚠️ **放开「有限数量」常量时要把所有消费点一起改（v0.13.13）**：`STAGE_COUNT` 15 → `STAGE_SOFT_CAP` 后，`Game.NextStage` 的上限判定、`stageHasNext`、`client_main` 的星级统计循环、`StageSelect` 的铺格循环全部要跟着改；漏一处就是「列表显示到 15 但能打到 200」或反过来。做法：grep 常量名拿全部命中点，逐个判断是「硬上限」还是「仅展示」。
- ⚠️ **探针要贴调用契约，别把状态机约束当 bug（v0.13.13）**：`Game.StartStageAt` 只在 `menu` 态有效，探针连开两关必须中间 `GoToMenu()`；`StageCatalog.GetSpecialKey` 对普通波**返回 nil 是正确的**。探针红了先分清「契约变更 / 探针写错 / 真 bug」，别为过探针改正确设计。
- ⚠️ **离屏探针打开面板走 `ClientMain.DebugOpenScreen(name)`（v0.13.13）**：这是既有的窄接口（只置 `metaState.screen` + `RefreshMeta/RefreshSnapshots`），比伪造鼠标事件可靠；本次已让它与 `OpenMetaScreen` 行为一致（开选关时也 `FocusLatest`）。

## 本批次新增避雷（v0.13.8 主页间距 + 天赋树入口）
- ⚠️ **菜单行间距改动要连带重排「行内元素」，别只挪 rect（v0.13.8）**：`GetMenuBarLayout` 的 y/h 一变，wallet 的图标/标签/数值/分隔线/充值胶囊、daily/grow 卡的图标框与 label/sub 的**绝对偏移**全部要按新高度重算（都是 `r.y + N` 硬编码）。同时 grep 底部锚点：菜单 toast 曾固定 y=848，行下移后会与养成行底边重叠——锚定「内容底边」而不是「离屏底边」。改动后必跑 `probe_menu`（几何命中）+ 真渲染截图（视觉），二者缺一不可。
- ⚠️ **「看起来能点」的入口要有明确的可点击视觉（v0.13.8 用户点名）**：纯信息面板（标题+进度条）玩家不认为可点。做法：给一个**实心胶囊按钮**（本项目用青色实心 + ink 字 +「进入 ›」，与 CTA/主操作同色语义）+ 左侧大图标框 + 悬停/可解锁态整框描边高亮 + 红点。命中仍可整框（无需改 `HitTest`），但视觉上必须有「一个按钮」的落点。
- ⚠️ **版本常量是独立于 git 提交的「展示事实」，交付前要核对（v0.13.8）**：`BUILD_VERSION`/大厅标题栏曾连续三批（0.13.5/6/7）停在 0.13.4——因为那些批次只提交了脚本、没人改常量。凡标了「BUILD_VERSION→x.y.z」的批次，提交前 `grep -n "BUILD_VERSION" scripts/` 与 `grep -n "v0\.1" scripts/lobby_runtime.lua` 各确认一次，别让展示版本与记忆版本长期漂移。

## 本批次新增避雷（v0.13.5-floattext 跳字特效）
- 🔴 **玩法事件里的"展示用字段"必须真的带上数据（v0.13.5-floattext）**：`brick_hit` 的 `score` 自早期版本起就是硬编码 0（真实分数只在规则层变量里累加），表现层却一直拿它拼 "+N" → 每次击碎飘 "+0"，且真实得分从未显示。**审计规则**：凡是表现层/UI 消费的事件字段（score/hp/damage/amount…），交付前确认规则层真的填了值，而不是常量占位；同类风险是"不同语义共用同一事件"（玩家击碎 vs 越线惩罚碎裂）——需要显式字段（score=0）或标记区分，表现层才能分流。
- ⚠️ **高频同类飘字必须聚合 + 限流（v0.13.5-floattext）**：一次范围击碎/贯穿连发多个 `brick_hit`，逐块飘字刷屏且互相重叠。规则：同 `kind` 飘字在 46 设计像素内自动合并累加（寿命刷新重跳、尺寸按总值 24/27/30 三档），同屏上限 6 条，**超出时并入最近一条而不是丢弃最旧**（数值不丢）。新增伤害数字/掉落提示类高频反馈按此模式。
- ⚠️ **飘字文本先判"值有无意义"再生成（v0.13.5-floattext）**：`"+0"` 比不飘更糟——纯噪音且会让玩家怀疑计分坏了。别把"事件发生了"当作"有内容可展示"；表现层生成文本前过滤 0/空值（`event.score > 0`）。
- ⚠️ **「跳字」手感三件套（v0.13.5-floattext）**：初速上飘（-70~-90）+ 线性减速到停（`math.min(0, vy + 170*dt)`，不回坠）替代旧指数阻尼 `vy*0.96`；绘制端入场 1.42 倍二次收拢（`pop = 1 + 0.42*lifeT²`）替代线性 1.18；聚合/重跳靠刷新 `life` 触发自然重播入场动画，不额外加 bump 字段。

## 本批次新增避雷（v0.13.5 天赋树）
- 🔴 **「升级池闭包读到的派生变量」必须声明在池之前（v0.13.5）**：`UPGRADE_POOL` 里 `repair` 卡的 `apply` 闭包读 `talentMaxHpBonus`（天赋血量加成）。若把该变量声明在池**之后**，闭包捕获的是全局 nil → 运行时崩，且 LSP 报 `undefined global variable`。修法：把天赋派生状态块（`talentOwned/talentMaxHpBonus/talentPartsPct/...`）整体前移到 `UPGRADE_POOL` 之前。**通用规则**：任何被 `UPGRADE_POOL` 闭包引用的规则变量，其 `local` 声明必须在池定义之前（AB-100 前向引用的同族，但这里是闭包捕获而非函数调用，扫描器要额外覆盖「池内闭包引用的外部 local」）。
- ⚠️ **血量上限要收敛到单一函数（v0.13.5）**：天赋给的是「生命上限加成」，凡是写死 `BASE_HP` 的地方（repair 卡回血封顶、暂停急救 `CanPauseHeal/PauseHeal`、星级评级 `baseHp/BASE_HP` 比例、快照 `maxBaseHp`、`stage_cleared` 事件）都必须改走 `GetMaxBaseHp()`，否则「上限涨了但评级按 100 算」会出现 3 星判定错位。新增任何「按血量比例」的逻辑前先 grep `BASE_HP` 找齐依赖方。
- ⚠️ **天赋解锁集合要走「provider 拉取」而不是各入口手动注入（v0.13.5）**：开局有 5+ 个入口（选关/下一关/再战/重开/复活），逐个调 `Game.SetTalents` 必漏。做法：`Game.SetTalentProvider(fn)` 注册一次，`ResetGame` 内部拉取——覆盖所有开局路径。玩家中途解锁节点不影响进行中的一局（下局生效），符合「局外养成」语义。
- ⚠️ **天赋节点必须「单级」+ 前置链（v0.13.5）**：用户规格「每个节点点一次就满了」——不要复用 `maxStacks` 那套多级逻辑；解锁判定要同时校验 ①阶段星级 ②同线路上一阶段节点（`IsPrereqMet`），且**星级门槛与前置链是两把独立的锁**（探针易只测一把：`CanUnlock` 先判星级再判前置，传错星级会拿到 `stars` 而非 `prereq`）。
- ⚠️ **整数键/布尔键 map 进存档各用各的解码器（v0.13.5 复用 v0.13.4 教训）**：`talents` 是 `table<string,boolean>` 用 `AsBoolMap`；`stageStars` 是 `table<integer,integer>` 用 `AsStageStars`（`tonumber(k)` 还原）。两者别混用，云合并都是取并集/更大值。

## 本批次新增避雷（v0.13.4 选关 + 胜利结算 + 星级存档）
- 🔴 **新增一个可弹窗玩法状态，必须把上一个同类态（gameover）的每个命中点都补齐（v0.13.4）**：stagewin 要在 ①`Game.PointerDown/Up` 早退、`GoToMenu`、`TakeSettlementStats`/`SettleParts`；②`UpdateUiState` 的 leaving/visual 三处 state 判定；③`RenderOverlay` 的 `currentWindow` + `game-window-in/out` 分发；④`client_main` 六个 Mouse/Touch 处理器 + `HandleKeyDown` + 结算入库块 —— 全部并列处理。漏任一处分别表现为「点了没反应 / 旧窗残影 / 胜利页不入库 / 键盘穿透」。做法：`grep -n gameover` 拿到全部出现点逐条加 stagewin 分支。
- ⚠️ **过关绝不能复用 ResetGame；累计波号必须换算而非重置（v0.13.4）**：ResetGame 会清 level/upgrade/unlockedBalls。`StartGameAt(stage)` 走 ResetGame 后立即把 `wave=(stage-1)*10+1`，保证每日任务「抵达第N波」在后期关按真实进度计；stagewin→NextStage/RetryStage 也走 StartGameAt。胜利态只置 `stageResult` 并停住，不推进波次、不扣血。
- ⚠️ **星级/解锁这类「整数键 map」进 JSON 存档要自建解码器（v0.13.4）**：`AsIntMap`/`AsBoolMap` 把键 `tostring`，关卡号需要 `table<integer,integer>`；新增 `AsStageStars` 用 `tonumber(k)` 还原并钳 `1..3`；`RecordStageResult` 取 max、`maxStage` 取更远，`ImportFromCloud` 跨设备同规则合并，否则换设备回退解锁进度。
- ⚠️ **弹动窗口的胜利/结算页命中要过 WindowInput（v0.13.4 复用 v0.13.3 契约）**：`HitTestStageWinButton`/`HitTestMenuCta` 里先 `uiX,uiY=WindowInput(...)`（game-window 用 `uiStateMotionEnter_`，菜单 CTA 用恒等变换不套 WindowInput）再判矩形，与 `DrawStageWin` 几何同源。
- ⚠️ **探针断言要跟规则语义同步（v0.13.4）**：改「自动进关→手动 stagewin」后，旧探针（认 stageClearPending、认游戏结束才 next）必红；升级优先于胜利结算，清 Boss 若同帧触发 levelup，探针要先 `PickUpgrade` 回 playing 再等下一帧 stagewin。红探针先分清「契约变更」vs「真 bug」，别为过探针回退正确设计。

## 本批次新增避雷（v0.13.3 车辆尾迹 + 窗口弹动过渡）
- 🔴 **动画窗口必须做命中逆变换，否则弹动期间按钮点不准（v0.13.3）**：窗口内容用 `nvgTranslate(center)+nvgScale(s)` 绘制时，输入侧必须 `WindowInput(x,y)` 以同一 scale 做逆变换再进 `HitTest*`。只改绘制不改命中=「看得到点不到」，用户必然截图打回（历史上弹窗按钮漂移被点过名）。
- ⚠️ **遮罩不能跟着窗口内容一起缩放（v0.13.3 peer 点名）**：全屏/半屏 backdrop 若画在缩放变换内部，scale<1 时边缘内缩会漏出下层世界层/菜单层。正确做法：遮罩在 `ApplyOverlayDesignTransform` 后**先以恒等变换画**，再进 translate+scale 画内容。alpha 可以整层统一（遮罩+内容同淡入淡出）。
- ⚠️ **开新窗立即作废旧窗退场残影（v0.13.3）**：退场快照（leaving）若不与入场互斥，快速「关→重开」会在新面板下面叠一份 0.18s 旧残影。规则：任何 state/screen/supplyOpen 切换时清同类 leaving 槽。
- ⚠️ **尾迹 id 复用必须用 flightTime 回绕判定清轨（v0.13.3）**：marble.id 会复用（回收→再发射），单按 id 存轨迹采样会把上一颗球的尾迹串给新车。`flightTime` 变小 = 同 id 新球，立刻重建采样；重开/非 playing 也要 `ClearTrailSamples`（否则暂停时旧尾迹冻结在屏上）。
- ⚠️ **BillboardSet 批次特效沿用「颜色烘焙 + DiffAlpha」**（v0.10.21 契约复用）：透明软圆尾迹不要用顶点色染色（DiffAlpha 不读顶点 rgb），四弹种各自一张烘焙软圆纹理 + 各自一个 set，48 槽/类型封顶，空闲帧跳过 Commit。
- ⚠️ **历史契约被用户推翻时要同步改写，不留双真相（v0.13.3）**：v0.10.0 曾「废弃全部尾迹」，本次用户点名恢复 3D 车辆尾迹。若只加代码不改契约条目，下个会话会按旧契约把它再删掉。v0.10.0 嫌的对象（2D 球形弹珠拖尾）与新需求（3D 重卡飞行尾迹）不同源，条目里要写清区别。

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
- 预瞄轨迹与尾迹契约：v0.13.15 更新——3D 飞行车辆**有**尾迹，但走 **NanoVG overlay 通道**（`Presentation.vehicleTrails` 采样游戏坐标 + `Scene3DBackend.DrawVehicleTrails` 用 `ProjectGamePoint` 投影 + `NVG_LIGHTER` 加色，见 0.13.15 条目）；两版 3D 尾迹（billboard v0.13.3、CustomGeometry ribbon v0.13.10/11）真机均「不可见」已废弃——本环境离屏 3D 因 BloomHDR 编译失败恒黑，无法自证 3D 层可见性，禁止再往 3D 层加需要目视验收的特效，一律走已验证可见的 overlay 通道。仍不绘制预瞄线与 2D 球形弹珠拖尾；拖拽瞄准只负责发射输入，尾迹只读规则快照采样，不向渲染快照写入轨迹。
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

## 本批次新增避雷（v0.13.24 数字贴图 + 进关过渡）
- ⚠️ **「给选关数字做贴图」要按高度归一，不能按包围盒等比**（v0.13.24）：数字 0–9 的字形宽高比不同（1 窄、8 宽），若各自等比缩放，节点上的数字会**高低不齐**。正确做法：后处理统一缩到**同一字形高度**（本项目 GLYPH_H=26），宽度随字形浮动，逐字记宽度表用于多位数排版（否则等宽留白会让「11」中间空一条）。
- ⚠️ **单色贴图用 `nvgImagePatternTinted` 染色，别为每个状态出图**（v0.13.24）：数字/图标只要做成「白 + 轮廓」两色，运行时就能乘任意色（白=原色、青=当前态、压暗=禁用）。⚠️ 是**乘法叠色**（压暗/染色），不是去饱和——乘灰只会变暗，做不出真灰度。省掉「正常版/禁用版/选中版」多套素材。
- ⚠️ **`Scene3DBackend.lua` 顶层 local 逼近 200，新增功能优先新开模块**（v0.13.24，v0.13.18 教训延续）：加功能前先数顶层 local（本项目 193→加 1 到 194，余量 6）。数字图集、过渡界面都做成独立模块（`ui/DigitFont.lua`/`ui/StageIntro.lua`），后端只加 1 个 require，不塞 local 常量。
- ⚠️ **「不新增 gameState」是加过渡/弹窗态的首选**（v0.13.24）：本项目新增可弹窗状态要在 `UpdateUiState`/`RenderOverlay`/六个输入处理器/结算块全部补分支（v0.13.4 stagewin 的教训），漏一处即「点不动/残影/入库丢」。进关过渡只需一个 `introTimer`（`Update` 里 `>0` 就冻结玩法并 return），零状态分支改动。**能用标志位就别加状态**。
- ⚠️ **模块不要依赖「后端暴露 vg」**（v0.13.24）：`Scene3DBackend` 未导出 vg，新绘制模块改为**用 Draw 传入的 ctx 懒加载**图片句柄（NanoVG 上下文是进程级单例，ctx 即 vg），既免去后端加访问器，也避免本地验证时的注入顺序问题。
- ⚠️ **`batch_generate_images` 会给草案也生成 `.meta`，且清理时容易漏**（v0.13.24）：生成后 `mv *.png` 出 assets 时，同名 `*.png.meta` **不会跟着走**（或跟走了但草稿目录里留下），assets 里会残留 `digit_x_<时间戳>.png.meta` 这类孤儿。清理时用 `rm assets/image/<batch>_*_2026*.png.meta` 一并扫掉，再确认 `ls assets/image/<batch>_*` 为空。

## 本批次新增避雷（v0.13.30 界面「不够贵」全局质感升级）
- 🔴 **AB-177：用户说「界面太便宜/不够贵」时，先找共用原语，别逐屏重画（v0.13.30 用户两轮点名）**：本项目 13 个界面**全部**经 `DrawMachinedPanel`（9 直调 + `DrawBluePanel` 6 + `MetaUI.D.panel` 22）、`DrawWindowShell`、`DrawModalBackdrop`、`MetaUI.Button` 渲染——所以「廉价感」的最大单一来源是这几个函数，改它们 = 全屏生效，且**签名不变、调用点零改动**（也绕开大文件 local 上限）。逐屏重画是低杠杆。
- 🔴 **AB-177b：「贵」的物理来源是层次，不是更多装饰线条（v0.13.30）**：第一轮只把渐变从 ±5 提到 ±19、加螺钉，用户仍说「还是不够贵」；第二轮加了**真实柔光**（`nvgRadialGradient` 径向底 + `nvgBoxGradient` 窗口外辉光）与**环境光**（顶部青辉光 + 四角暗角）后才成立。量化判据：面板内部竖向渐变跨度（旧 ~7-15 级 → 新 ~19 级）、背景不再是单一色值、窗口有外发光。**先补「光/厚度/焦点」，再谈装饰**。
- ⚠️ **`nvgRadialGradient` / `nvgBoxGradient` 本项目可用**（`.emmylua/NanoVG.d.lua` 已声明 `nvgBoxGradient(ctx,x,y,w,h,r,f,icol,ocol)`、`nvgRadialGradient(ctx,cx,cy,inr,outr,icol,ocol)`）；线性渐变做不出柔光/暗角，要「贵」就用这两个。大范围单次 fill，无性能问题。
- ⚠️ **改共享原语时保持签名与命中几何不变**：CTA 改画法但 `GetMenuCtaRect` 未动；`DrawMachinedPanel` 加装饰但参数表未动；`Shell` 加标题横带但 `GetShellLayout` 未动——这样所有命中探针与调用点都不受影响。**视觉升级不该动几何**。
- ⚠️ **螺钉/装饰要有尺寸门槛**：四角螺钉只在 `r>=5 且 w>130 且 h>70` 画，否则小按钮/细条上会糊成一团；HUD 横条 `radius=0` 天然跳过。装饰门槛没设好会把小控件画脏。

## 本批次新增避雷（v0.13.31 华丽/交互/动态）
- 🔴 **AB-178：「华丽 + 动态」= 交互反馈 + 持续动画，不是静态装饰（v0.13.31 用户连说两轮「不够」）**：v0.13.30 把质感（渐变/柔光/厚度）做足后，用户仍说「还不够华丽！还不够交互，还不够动态」——根因是前几轮产出全是**静止画面**，再精致也读作「截图」。做法：①**交互反馈**（指针悬停 → 加色外辉光 + 亮边；悬停强度用**平滑**值渐亮渐灭，非硬切）；②**持续动画**（CTA 周期性扫光、分区标题呼吸 + 流动光点）。找**共享原语入口**各加一处（`DrawMachinedPanel`/`MetaUI.Button`），不要逐屏做。
- ⚠️ **全屏共享一个动画时钟，别每个元素各自 `math.sin(elapsed*…)`（v0.13.31）**：本项目用 `uiFx.anim`（`UpdateScene` 里写 `gameSnapshot.elapsed`）作为**唯一相位源**，所有呼吸/流动/扫光都派生自它——元素才会**同步**。各自取 elapsed 会相位不一致，读起来像 bug。
- ⚠️ **悬停状态要「全局喂入」，不能被模态/拖拽分支吞掉（v0.13.31）**：`HandleMouseMove`/`HandleTouchMove` 里 `Backend.SetPointer` 必须在**所有 return 之前**调用——否则拖拽滚动/元层面板打开时悬停失效。悬停是全局交互反馈，与业务分支正交。
- ⚠️ **装饰性动画必须确定性 + 可裁剪（v0.13.31）**：CTA 扫光用 `elapsed % 3.2` 定相位（非随机），并用 `nvgIntersectScissor` 裁进圆角内（否则斜光带会越出按钮边缘）。任何循环动效都要有明确周期，且不越出宿主几何。
- ⚠️ **悬停判定要用**设计坐标**，且只对按钮尺寸生效（v0.13.31）**：`Backend.SetPointer` 收的是 `ScreenToUi` 后的设计坐标（与绘制同空间）；`DrawMachinedPanel` 里悬停发光限 `h<=80 且 w>=40`，否则 HUD 横条/大面板会被误点亮。

## 避雷清单

## 本批次新增避雷（v0.13.29 升级卡 UI 自适应）
- 🔴 **AB-174：数据驱动的文案，绘制端不能假设长度（v0.13.29 用户截图点名）**：升级卡数值条文案来自 `UPGRADE_POOL[].value`，同一字段长度从 `+1 格`(4) 到 `伤害+3 / 弹速+10% / 受创+1`(18 字符/32 字节)，而绘制端固定 16px 单行居中 → 最长两张必然溢出卡片。**通用规则**：凡是**数据驱动**（表/配置/后端下发）的文本，绘制前必须 ①按**语义分隔符**拆分（` / `），②按**像素宽度实测**决定换行/降字号，③**容器高度跟着内容走**。⚠️ 拆分必须按语义分隔符而不是按字符硬切——否则 `弹速+10%` 会被切成 `弹速+1`/`0% ...`，数字被腰斩比溢出更难读。
- 🔴 **AB-175：「截断可见行数」是静默丢信息，不是布局手段（v0.13.29 实测）**：本批为腾空间一度把详情 `maxLines` 压到 1 行，结果玻璃巨炮的详情被截成「伤害 +3、弹速 +10」并**丢掉「%，但被撞多掉 1 点。」**——LSP 与构建**都无感**（纯绘制期行为），只有真渲染截图能发现。**正确顺序**：先让容器变大（本次卡高 300→340），再用字号自适应兜底；把「少显示几行」当解法一定会丢内容。
- ⚠️ **AB-176：命中探针必须推进 `Game.Update` 才能验「窗口内」命中（v0.13.29 踩到）**：`Backend.HitTest*` 会先过 `WindowInput` 的**窗口入场动画逆变换**（`WindowMotion`，入场 `WINDOW_IN=0.32s` 内 scale≈0.91），而 `uiClock_` 由 `AdvanceUiClock(game.elapsed)` 驱动、`game.elapsed` **只在 `Game.Update` 里涨**。探针若只调 `Backend.UpdateScene` 不调 `Game.Update`，`uiClock_` 恒 0 → scale 停在 0.91 → 表现为**卡中心命中、上下缘/角标/按钮全落空**（本次一度误判为「340 卡高把命中几何算错了」）。写面板命中探针时，驱动帧里必须同时调 `Game.Update(dt)` 与 `Backend.UpdateScene(...)`。
- ⚠️ **升级卡的「视觉卡高」与「命中卡高」同源，改一处即同步（v0.13.29）**：`Backend.HitTestUpgradePanel` 的矩形完全由 `GetUpgradePanelLayout`→`GetUpgradeCardLayout` 派生，`client_main.lua` 里**零常量**（只有一句「几何完全由 HitTestUpgradePanel 提供」的注释）。所以调卡高只需改 `GetUpgradeCardLayout` 一处；若哪天有人在 `client_main` 里另写 cardW/cardH，这里就会漂移——**保持同源**。

## 本批次新增避雷（v0.13.28 尾迹下移半格）
- ⚠️ **AB-173：「按格偏移」要取「关卡权威格值」，别取「场上敌机字段」（v0.13.28 实测）**：用户要求尾迹「额外向下移动半个格子」。第一版用 `game.veggies[1].brickSize` 取格值——**开局 3 秒进关过渡内 `veggies` 为空**（AB-171 同族），插桩实测退到回退值 8 而非第 1 关真实半格 7。修法：`Game.GetSnapshot` 暴露 `s.brickSize = GetBrickSize(wave)`（**按波次算、与有无敌机无关**），表现层优先读快照、缺省才回退。**凡是「按当前关卡/格子」的表现偏移，一律走快照权威值，不要从在场实体反推**（实体是间歇的、关卡是持续的）。
- ⚠️ **偏移要作用在「采样点写入之前」，不能作用在「几何构建时」（v0.13.28）**：`SyncVehicleTrails` 的几何用 `track.points`（历史采样）+ `track.head`（实时车尾）拼三角带。若在构建循环里下移，车头会下移而历史点不动 → **尾迹尾部从车尾脱开**。正确位置：采样点 `pos` 落 `trailSamples_` 之前统一偏移，保证头尾一致平移。（击碎，飞机大战/v0.13.28）

## 本批次新增避雷（v0.13.28 常驻通用卡重做：改作用对象）
- 🔴 **AB-172：数值卡「有没有用」要问「它作用的变量在低难度是否存在」（v0.13.28 用户点名）**：用户原话「通用卡（常驻）大类的用处均过低了」，澄清为「这些数值在第一关等低难度没有明显帮助」。量化后四张卡**全部作用在关1 不存在的变量上**：关1~3 砖块 hp=1 →「伤害 +N」纯溢出；玩家几乎不掉血 →「回血 / 减伤」无从发挥；单行越线伤害被 `max(1, ceil(行数*0.5)+bonus)` 钳成 1 → 固定 -1 减伤连 1 都减不掉。**结论：只调大数字会白做一轮**，必须 ①改底层数值（提高砖块血量/去掉伤害下限）或 ②**改作用对象**（挂到经验/生命上限/零件产出/发射初速等与难度无关的量上）。本批按用户选定走 ②。（击碎，飞机大战/v0.13.28）
- ⚠️ **「加百分比/加产出」类改动要顺手查浮点渗漏（v0.13.28 实测）**：`partsMul`（×1.08）让 `partsEarned` 变成**浮点**，而渲染层用 `string.format("… ×%d", runParts)` 格式化（本项目「HUD 整数格式契约」踩过浮点崩帧）。**做法**：所有对外出口（`GetRunParts`/`SettleParts`/快照字段）一律 `math.floor`，并在探针里断言 `math.type(v) == "integer"`。凡在规则层引入「倍率/百分比」的改动都要走这一步。
- ⚠️ **卡池闭包引用的函数必须前向声明（v0.13.28，AB-100 同族）**：`repair` 卡的 `apply` 闭包读 `GetMaxBaseHp`，而该函数定义在 `UPGRADE_POOL` 之后 → 闭包解析成**全局 nil**（LSP 报 `undefined-global`，运行时会崩）。修法同 AB-100：`local GetMaxBaseHp` 前向声明 + 后置赋值。**新增卡池卡且 `apply` 读任何规则函数/变量时，先确认其声明在卡池之前**。
- ⚠️ **`BALL_TUNING` 新增字段的复位必须早于依赖它的初始化（v0.13.28）**：`repair` 的永久上限写在 `BALL_TUNING.maxHpBonus`，而 `ResetGame` 里 `baseHp = GetMaxBaseHp()` 用的是它 → 清零必须放在该行**之前**，否则上一局的维修上限带进新局。凡是「开局初始化会读的 `BALL_TUNING` 字段」，复位一律前移到 `ResetGame` 开头。
- ⚠️ **改玩法数值后要跑一次真渲染冒烟（v0.13.28）**：`probe_common`（纯规则）能证明数值对，但证明不了 `%d`/绘制路径不崩——必须再跑 `probe_render`（菜单→选关→战斗→发射）确认零 Lua/overlay 错误。规则探针 + 真渲染冒烟是两条独立的验收线。

## 本批次新增避雷（v0.13.28 分裂车天赋自动解锁）
- ⚠️ **「开局自动拥有的天赋节点」是一张白名单，加车就加一行（v0.13.28）**：`TalentCatalog.AUTO_OWNED` 控制「哪些节点开局就是已解锁」。v0.13.19 初始车由分裂车改加速车时它被设成 `{ "speed_1" }`，于是**分裂车的「允许局内出场」节点变成要花零件买**。用户要求「分裂车天赋树玩家一开始也解锁」→ 加 `"normal_1"` 即可（`EnsureAutoOwnedTalents` 本就遍历整表，调用点零改动）。**加新初始车/新自动节点时，只需改这一处**，别去改 `client_main` 的调用或 `Game` 的门控。
- ⚠️ **自动解锁的是「1 阶」不是整条线（v0.13.28）**：`normal_1` 只放开「局内出现解锁卡」；**专属卡/基础卡（`split`/`base_split`）仍需 `normal_2`（ballCard 节点）**。加自动节点时先确认该节点的 `kind`——`ballUnlock`（出场资格）可以自动给，`ballCard`（专属卡资格）自动给会一次性放开整条车线，通常不该给。探针要断言「自动解锁**没有**顺带放开下一阶」。
- ⚠️ **玩法探针必须先推进过 `INTRO_SECONDS` 再取敌机（v0.13.28 踩到）**：v0.13.24 起开局有 3 秒进关过渡（`Game.Update` 冻结玩法），`HandleAction("start")` 之后立刻 `GetSnapshot().veggies[1]` 是 **nil** → 探针报 `attempt to index a nil value (local 'boss')`。修法：`for _ = 1, 200 do Game.Update(1/30) end` 先过过渡。**凡「开局→造 Boss→刷升级面板」这类探针都要加这一步**（v0.13.24 之前的探针模板已过时）。

## 本批次新增避雷（v0.13.27 修逐架生成全居中回归）
- 🔴 **AB-170：把「一次性编队」改成「逐架生成」时，横向铺开逻辑不能连函数一起删（v0.13.27 恶性回归）**：v0.13.26 我把一次性编队 `ComputeFormationSlots` 当死代码整段删除、换成 `SpawnNextNormalEnemy` 逐架生成，结果**所有敌机叠在正中一条竖线**——因为 `ComputeFormationSlots` 除了「阵型」还负责**横向 x 分布**，而新函数只实现了纵向错峰，每架都写死 `x = DW*0.5 - shipW*0.5`。**规则**：删除/替换生成路径前，先列出旧函数真正负责的**每一个维度**（x 分布、y 错峰、阵型/编队形状），逐条确认新路径有等价实现；别只按函数名以为它只是「阵型」。**逐架生成也要有横向分道**：确定性轮换车道（非随机），且**起始车道随波次错开**（否则每波只有 1 架时会「总从最左出」）。（击碎，飞机大战/v0.13.27）

## 本批次新增避雷（v0.13.26 出怪梯度重做 + 同波错峰生成）
- 🔴 **给主块加顶层 local 前必须数「Lua 200 上限」（v0.13.26 又踩一次，AB-166 同族）**：给 `Game.lua` 加了 7 个模块级 local（错峰生成状态）后，运行时直接 `Load Buffer failed for Game.lua: [string "Game"]:2581: too many local variables (limit is 200)` → **整模块加载失败、游戏全黑**。⚠️ **LSP 与官方 build 都只查语法、不查这条编译期上限，只有真运行时暴露**。修法：把同族变量**收进一张表**（`local pendingSpawn = { remaining=0, timer=0, ... }`），只占 1 个槽。**纪律**：给 `Game.lua`/`Scene3DBackend.lua` 这类巨型文件加顶层 local 前先数槽位（脚本统计法见 v0.13.18 避雷），逼近上限就收表；**新增状态优先设计成一张表，而不是一组散装 local**。
- 🔴 **AB-169：逐架/错峰生成必须处理「满场/找不到空位」，不能强行落位（v0.13.26 探针实测重叠）**：把「一波一次性编队」改成「逐架飞出」后，探针在关12 敌机堆到 12 架时发现**两架生成在同一位置（实测间距 -124，重叠）**——找空位的循环用尽后代码仍照常 `CreateEnemy`。规则：生成前先判 `#veggies >= MAX_FLEET` 直接推迟；找空位循环结束**再判一次**，仍占用就推迟（本项目 `pendingSpawn.timer = 0.5~1.0`），**任何情况下都不允许为了「本波计划数」而叠放**。配套：错峰间隔的**下界要按最慢的那一架**估（本项目 `基准速度 × 0.42 × 最慢 descentMul(0.66)`）——用基准速度算会在高关卡漏掉下界，慢机来不及拉开就与后一架同格。（击碎，飞机大战/v0.13.26）
- ⚠️ **「出怪间隔」两个维度别混（v0.13.26）**：①**波与波之间**的冷却（`GetInterval`，旧版随关卡变长=越往后越简单，方向反了，已改为逐关收紧）；②**同波内逐架飞出**的间隔（`GetSpawnInterval`，关1 最长逐关收紧）。用户说的「出怪间隔维度」是后者，但两者都要符合「越往后越紧张」。⚠️ **一次性编队 `ComputeFormationSlots`/`LiftSlotsOffExisting` 已废弃删除**——改逐架生成后它们无调用点，属死代码。
- ⚠️ **敌机「生成但看不见」是预期，要在 UI 写明（v0.13.26 用户要求）**：敌机在屏幕上沿之外（`y = -102 - 机高 - 24`）生成、下落一段才进画面，玩家会以为没刷出来。预告面板加「自远方飞入」一行说明即可，**不要去改生成位置让它一生成就可见**（那会破坏「从屏外平滑进入」的既有契约）。

## 本批次新增避雷（v0.13.21 核验：XHR{} 复发上报 = 陈旧预览包，非代码问题）
- ⚠️ **`Error processing XMLHttpRequest response: {}` 复发上报先核验四证，别重复改代码（v0.13.21 实测）**：v0.13.18 已删 official-res 源修过此错，但再次收到 78 次上报。核验结论=**陈旧预览构建的残留**，当前代码与配置均干净，**无需改代码**。四证：①`.project/settings.json` sources 无 official-res（当前只有 engine/engine-res）；②`.build/asset_adopt.json` = `{"official_uuids":[],"asset_paths":[]}` 空；③`dist/latest.json` 指向的构建 manifest `sources=['engine-res']`、无 `pinned`；④报错头部构建哈希 `52ee01a8/0c6c1c48` **不在任何本地产物里**（本地最新是另一套 client/server 哈希）→ 上报来自更早的预览构建。结论：玩家/审核当时加载的是旧包。
- ⚠️ **`dist/` 是 root 所有、Maker 不可写（v0.13.21 实测）**：`rm dist/...` 会**静默失败**（无报错、文件仍在），别以为清掉了。清理前先 `touch dist/.wtest` 判可写性；`dist/1.0.0` 这类陈旧版本目录删不掉，但只要 `dist/latest.json` 不指向它就无影响。**可写并能真正清掉的是 `.build/manifest_cache/official-res-*.json`**（14MB 陈旧缓存，会残留官方素材 uuid 引用）——已删。
- ⚠️ **运行时单条 `RuntimeRetargeterCache: Cannot load mapping table: uuid://<x>` 是引擎自带噪音，别当根因（v0.13.21 实测）**：本项目 **116 个历史探针日志全都有这一条**（最早版本起就有），且本地真渲染 **0 次** `XMLHttpRequest` 复现。它只存在于陈旧 official-res 缓存里、当前包不含该 uuid。看到它别往"官方素材订阅"上引。
- ⚠️ **本地真渲染对平台网络错误无法复现（v0.13.21）**：`URHO3D_PREFIX_PATH=... UrhoXRuntime -tool_mode` 探针可复现 2D/3D/Lua/overlay 类问题，但平台 XHR/DWP 下载失败属平台环境特有，本地 0 次即不能证伪。这类"平台错误上报"的判据是**构建产物取证**（sources/pinned/adopt/manifest + 报错哈希比对），不是本地跑一遍。

## 本批次新增避雷（v0.13.17 skill 固化 + 氛围层 + 图标重出）
- 🔴 **自绘绘制函数的参数顺序要靠「真渲染探针」验，LSP/build 都查不到（v0.13.17 实锤）**：新写的 `DrawScanBand` 调 `DrawRect(ctx,x,y,w,h, color, radius)` 时把 `0`（radius）和颜色表写反 → 运行时 `attempt to index a number value (local 'color')`，菜单整段 stage 被 pcall 吞掉。LSP 的 undefined-field 只看**字段名**、不看**实参顺序**，构建也只查语法——**这类错只有跑一次真渲染（探针日志里搜 `overlay stage failed`）才抓得到**。写新绘制辅助后，务必真渲染冒烟一次再交付。
- ⚠️ **氛围层要「克制档」落地，别照抄全量（v0.13.17）**：skill 的 atmosphere.md 默认全量（强调色切换 + 文本异变 + 乱码），但游戏 HUD/战斗界面全量会干扰读数。做法：机制照旧（全屏共享一个标量、基线不为 0、非等距阈值），但**只实现低位阈值症状**（底噪/扫描带/半调/残影），且**装饰不进入任何玩家要读的东西**（HUD 读数、按钮文字、正文、命中区）。判据：「这层会不会出现在玩家要读的东西上？会 → 关掉」。
- ⚠️ **`ICON_PATHS` 会积累「已加载却从未绘制」的死键（v0.13.17 实测 5 个）**：`gem/wheel/supply/pass/boost` 白占显存还误导。交付前**逐 key grep 一次调用点**：有语义的接上（gem→钻石、boost→增益），被新资源取代的删掉（wheel/supply/pass 已被 premium_* 取代）。同时**删对应的 PNG + `.meta`**，别留孤儿资源。
- ⚠️ **「AI 原图直接缩到 32×32」= 不是像素画，只能重出（v0.13.17 实测）**：早期 26 张 `ui_icon_*` 实测 **100–583 种颜色**（v0.12.9 之后按管线走的都是 8–9 色）。判定方法就是**数每张图 >128 alpha 的唯一 RGB 数**：≤9 合规、100+ 必是原图缩放。这类补量化救不回来（原图没有干净色块边界）→ 按原语义走 0718 管线重出。**重出后沿用旧文件名覆盖**（ICON_PATHS/.meta 不动、零路径风险），别改名（改名必须同步代码路径 + 可能漏 .meta）。
- ⚠️ **会话内生成的草案 PNG 会直接落进 `assets/`（v0.13.17）**：`batch_generate_images` 的产物直接写 `assets/image/`，会占包体。流程：**生成后立刻 `mv` 到 `/home/Maker/<batch>/drafts/`**，后处理成品再按目标文件名放回 assets；`assets/` 里不要留 `iconregen_*` 之类中间文件（连 `.meta` 残片也要清）。
- ⚠️ **并发会话的展示版本号归其所有（v0.13.17）**：`BUILD_VERSION` 与 `lobby_runtime` 的 `v0.13.17` 由并发会话推进；提交时用 `git diff` 逐行核对，只 `git add` 自己的文件，**不要整文件暂存混有他人 hunk 的版本常量**。

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
- 投影审查契约：判断 UI 与玩法对象是否遮挡前，必须先把权威坐标通过当前 `projectionOffset/Scale` 投影到 540×960 屏幕设计空间；禁止把 `Game.lua` 的 `y` 直接当屏幕 `y` 并据此修改危险线、弹弓或碰撞规则。⚠️ v0.13.15b 补充：**overlay 特效要贴在 3D 物体上（尾迹/光环跟随车辆）时，必须额外按该物体的 world Z 投影**（`ProjectTrailPoint` + `Renderer3D.VehicleDepthZ`）——投影标定默认玩法平面 z=0，46° 斜俯视下 z 差直接变成屏幕 Y 分离；车辆锚点 z 是 radius 的函数，别用常数
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
