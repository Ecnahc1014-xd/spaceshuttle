# 货车大战飞机 — 项目核心记忆

> AI 自维护，每次 POST 自动更新。详细规则见 memory-system skill。

## 当前状态

- 附记: bowwave-shell-drag-2026-10-15（2026-10-15，**冲击波放大三层 + 外套 80%/1.2×/发射后2s停留+3s消散 + 拖拽范围=设计空间圆的投影**；沿用展示0.13.63，不抢并发版本）：
  - 用户三点要求：①「冲击波太小太简单」→ 放大 + 加层次；②「全息幻影以现在 80% 不透明度、比车稍微大一点（20%）套在车上，发射后 2s 才会开始消散，之后 3s 平滑消散完」；③「发射拖车辆的圆形拖动范围不是指 3d 空间的圆形范围，而是 2d 空间对应直径圆形范围的投影」。只改 VisualCatalog/Presentation/VehicleChargeFx/VehicleBowWave/Game/client_main，不动伤害/初速/回收/附魔/拖尾/暗科技 UI。
  - **① 冲击波放大三层**：`VehicleBowWave` 的 V 形参数 `V_DEPTH 0.34→0.62 / V_SPREAD 1.12→1.90 / THICKNESS 0.12→0.18 / HALF_HEIGHT 0.05→0.12 / GAP 0.16→0.20`；`EmitCar` 改为**三层叠放**（`BANDS` 表：外层最宽最淡 bright0.42 → 中层 0.68/0.78 → 内层最窄最亮 0.38/1.30 白热核），每层各自缩放宽度/深度/厚度/半高并沿前向错开（ahead 0.10/0.03/0.00），形成有纵深的冲击波墙。`BANDS_PER_CAR=3`、`PER_CAR = SEGMENTS*24*3+12 = 1188`（预算 8 车/9504 顶点）。独立 Forward 实图确认三层可见。
  - **② 外套 80%/1.2×/发射后 2s 停留 + 3s 消散**：`VisualCatalog.CHARGE_HOLOGRAM` 改 `shellScale 1.5→1.2`（比车大 20%）、`shellAlpha 0.40→0.80`（80% 不透明）、新增 `shellHold=2.0`+`shellFade=3.0`（替换原 `shellSeconds=3.0`）。`Presentation._chargeHologram` 的 `shellMaxLife = shellHold+shellFade = 5.0`，增 `shellFade` 字段。`VehicleChargeFx` 不透明度改 `shellAlpha * min(1, shellLife/shellFade)`——`shellLife > shellFade` 段为**停留期**（满 80%），随后按 `shellFade` 平滑淡出到 0。
  - **③ 拖拽=设计空间圆的投影**：旧实现把拉弓量在**玩法坐标**里按 `MAX_PULL` 圆钳制 → 玩法平面上的范围是正圆，但投影到屏幕是**椭圆**（手感不是屏幕上的圆）。改为在**设计(UI)坐标**里钳制：`Game._pullSpace = {sx, sy, uiX, uiY, dist}` + `Game.SetPullSpace(sx, sy)`（编排层每帧从 `RenderBackend.GetProjection()` 取投影缩放喂入）；新增 `PullToGameplay(uiX, uiY)`——①在设计坐标求 pull、按 `MAX_PULL` 半径圆钳制（**屏幕上是正圆**）；②除以投影缩放 `sx/sy` → 玩法位移（玩法平面范围因此是「屏幕圆的投影」椭圆）；③写 `pull.dist`（设计像素拉距）。`PointerDown/Move/Up` 全部改走它；死区按**设计像素** 15 判定；`ComputeAimLine` 的 `power` 改用设计像素 `uiDist` 归一（玩法长度可能因投影 >MAX_PULL，用它归一会让弱拉显示满亮）。删除死的 `ClampPull` 与只写不读的 `grabStartX/Y`。**车辆屏幕位移仍恒定**：`玩法位移 × pullPositionScale(0.6) × 投影缩放 = 设计 150×0.6 = 90 设计像素`，与旧行为一致。
  - 验证：LSP **36 文件 0 Error**（1412 Warning/125 Hint）；官方多人 build + 预览上传 ✅。真渲染探针 `probe_v3`（走真实 client_main，含两轮开局选车）**14/14 PASS**：shellScale==1.2 / shellAlpha==0.80 / hold2+fade3；外套满蓄常驻、发射后 1.5s 仍在停留期、约 2.5s 进入淡出段、约 5s 消散完；波壳 initialized 且未 faulted、`vertexBudget=8×1188=9504`；`SetPullSpace(0.5,0.6669)` 下设计 150 竖直拉距 → 车辆玩法位移 135.0（= 150/0.6669×0.6），证明按投影换算。**独立 Forward 渲染实图**三层 V 形可见（`/workspace/screenshots/bw/bw3_bands.png`，1164 顶点/1152 实际）。
  - 边界：主 HDR 中央 3D 本环境恒黑，冲击波可见性由**独立 Forward 渲染实图**证明；外套 80%/1.2×/2s+3s 与三层参数为**助手拟值**（非用户确认参数）；手机 FPS/全 DPR/真实 SDK/审美未验收。纹理禁压缩未完成、XHR96/233 未定位不变。
  - **POST 判定**：POST-1 状态/索引执行，persona 跳过（无新跨项目偏好）；POST-2 本人六 Lua 独立提交；POST-3 AB-336/339/340 执行，随行 persona/preferences 同理由跳过。保留并发 opening/ArtText/成就/纹理与发布配置、初始未跟踪文件，不代提交。

- 附记: six-req-2026-10-15（2026-10-15，**外套发射后 3s 消散 + 85% 补满 + 修 V 形冲击波不可见 + 拖尾随龄变短 + 三连副弹同主弹 + 回弹特效**；沿用展示0.13.63，不抢并发版本）：
  - 用户六项要求：①「透明度40%的全息幻影比车稍大套在车上，**发射后才会开始消散，3s 后消散完**」；②「蓄力未满但已完成85%以上并发射的**立刻使它完成蓄力**」；③「**冲击波完全没有显示**」；④「拖尾随着子弹存在时间变长会**越来越短**，分裂行为**继承长度**」；⑤「附魔三重发射的两个副子弹也**视为分裂弹**（功能保留本子弹相同）」；⑥「**增加回弹特效**」。只改 Game/Presentation/Renderer3D/VehicleBowWave/VehicleChargeFx/VisualCatalog 六文件，不动伤害/初速/回收/附魔稀有度/金色强化与暗科技 UI。
  - **① 外套生命周期**（真凶：旧外套 TTL 与两层残像共用 0.65s，且源车回收即隐藏）：`Presentation._chargeHologram` 增**独立** `shellLife/shellMaxLife`（= `VisualCatalog.CHARGE_HOLOGRAM.shellSeconds = 3.0`）；蓄力期间保持满值常驻，**只有 `released`（真发射）后**才按 3s 线性递减；取消/切车（未发射）立刻清空。`VehicleChargeFx` 的 shell 分支改用 `shellLife`（不透明度 `shellAlpha*(1-shellT)`），残像 `life` 与外套 `shellLife` 相互独立（两者都归零才整体隐藏）。
  - **② 85% 补满**：`BALANCE.chargeCompleteThreshold = 0.85`；`LaunchMarble` 里 `time/total >= 0.85` 就把 `time = total`（chargeBoosted=true）；快照增 `s.chargeReady = chargeProgress >= 0.85`，Presentation 用 `chargeReady`（而非 `>=1`）提前爆发全息。
  - **③ 冲击波不可见真因（本轮最高价值）**：上一批把 V 形波壳材质从 **无光照** `NoTextureUnlitVCol` 改成**带光照** `DiffAlpha`（= `LitSolid` shader，法线 ±Z）——本作深空场景很暗，`N·L≈0` → **整片变黑**。独立 Forward 渲染探针（`hdrRendering=false` + 真实光照场景）四模式对照实锤：lit=暗灰几乎不可见、unlit/vcolalpha=亮青。修法：改 **`Techniques/DiffVColUnlitAlpha.xml`**（Unlit + VERTEXCOLOR + DIFFMAP + alpha，即**无光照 + 读顶点色 + 读纹理 alpha**），纹理改**白 RGB + alpha 剖面**（白 RGB 不压暗弹种色）。
  - **④ 拖尾随龄变短**：`Game.CreateMarble` 增 `trailAge`（随 dt 递增；`CreateSplitMarble` **拷贝母车 trailAge** → 分裂继承长度）；`Renderer3D.SyncVehicleTrails` 按 `trailAge` 算 `ageFactor`（`TRAIL_AGE_FULL=0.35` 前满长 → `TRAIL_AGE_GONE=4.5` 收到 `TRAIL_AGE_MIN_FACTOR=0.16`），据此收 `keep`（保留采样点数）与 `life`（采样存活时间）；粒子系同乘 `lifeScale`。新增只读 `Renderer3D.DebugTrailLengths()`。
  - **⑤ 三连副弹同主弹**：`LaunchMarble` 三连分支给每个副弹 `extra.words = {copy of activeBall.words}`、`extra.enchantIsChild = nil`（清除后与主弹一样可触发裂变等），仍 `isPrimary=false`（灰暗渲染）。
  - **⑥ 回弹特效**：`Game` 撞左/右/顶墙各 `Emit("marble_bounce", {id,x,y,ballType,nx,ny})`；`Presentation` 登记 `marble_bounce → bounceImpact`（弹种色扩散环 + 2~4 火花 + 轻震 0.05）。
  - 验证：LSP **36 文件 0 Error**（1404 Warning/125 Hint）；官方多人 build + 预览上传 ✅。真渲染探针（走真实 `client_main`，含两轮开局选车）：`probe_six` **15/15 PASS**（85% 发射→boosted、外套蓄力期满寿命/发射后 1.5s 仍在/约 3s 归零、波壳 initialized 且未 faulted、trailAge 递增、三连 4 副弹）；`probe_bounce` **3/3 PASS**（bounceCount≥1、回弹触发冲击环）；`probe_traillen` **2/2 PASS**（同一飞行车 keep **16→5**）；`probe_rules` **4/4 PASS**（三连副弹 4/4 带词条、4/4 带附魔、0 仍标记子车）；`probe_split2` PASS。**独立 Forward 渲染实图**对照：旧 lit=暗灰不可见 vs 修复后=亮青 V 形（`/workspace/screenshots/bw/bw_verified.png`）。
  - 边界：主 HDR 中央 3D 本环境恒黑，冲击波可见性由**独立 Forward 渲染实图**证明（非主 HDR）；外套 3s/85%/拖尾收短比例均为**助手拟值**（非用户确认参数）；手机 FPS/全 DPR/真实 SDK/用户审美未验收。纹理禁压缩未完成、XHR96/233 未定位不变。
  - **POST 判定**：POST-1 状态/索引执行，persona 跳过（无新跨项目偏好）；POST-2 本人六 Lua 独立提交；POST-3 AB-336/337/338 执行，随行 persona/preferences 同理由跳过。保留并发 opening/ArtText/成就/纹理与发布配置、初始未跟踪文件，不代提交。

- 附记: trail-opacity（2026-10-14，**全部拖尾整体不透明度降到 30%（透明度 +70%）**；沿用展示0.13.63，不抢并发版本）：
  - 用户「全部拖尾不透明度降低70%，变得透明」——所有拖尾（光带系 + 粒子系）统一乘一个不透明度系数。只改 `Renderer3D.lua`（3D 实机拖尾）+ `MetaUI.lua`（商店拖尾 2D 预览，按「预览=实机」契约同步），不动玩法/宽度/形态/样式差异/规则层。
  - **单一常量**：`Renderer3D.TRAIL_OPACITY = 0.30`（1.0=原不透明，0.30=透明度 +70%）；`MetaUI.TRAIL_PREVIEW_OPACITY = 0.30`（同值，注释互指）。
  - **光带（`DiffVCol`，原本不透明）**：`DiffVCol` 的 base pass 默认 `BLEND_REPLACE` → **顶点 alpha 被忽略**，只改顶点 alpha 不会透明。修法：`baseTech:Clone("TrailAlphaVCol")` 克隆一份 technique，`alphaTech:GetPass("base"):SetBlendMode(BLEND_ALPHA)`（**克隆而非改共享资源**——敌机/飞散箱也用 `DiffVCol`，直接改会连它们一起变透明）；顶点 alpha 在 `EmitTrailQuad` **一处**统一写 `TRAIL_OPACITY`（覆盖主体/柔光/芯所有层，避免逐调用点散改）。
  - **粒子（`DiffAlpha`，本就混合）**：`bb.color = Color(1,1,1,TRAIL_OPACITY)`——顶点 alpha 乘到纹理 alpha 上，故贴图本体与顶点色都不用改。
  - **2D 预览同步**：`DrawTrailPreview`（光带）与 `DrawTrailParticlePreview`（粒子）的 alpha 一律乘 `TRAIL_PREVIEW_OPACITY`（主体/柔光/芯/灼核四处）。
  - 验证：LSP **36 文件 0 Error**（1399 Warning/119 Hint）；官方多人 build + 预览上传 ✅。真渲染 `probe_trailopacity` **ALL PASS、exit0**（交替渲染 classic/comet 两种通道）：`opacity=0.30`、`ribbonBlend=3.0`（= BLEND_ALPHA）、`ribbonVerts=162`（改混合模式未破坏几何）、`particleAlpha=0.30`；目标 Lua/overlay/LoadChunk/空顶点错误 0。
  - 边界：**主 HDR 中央 3D 仍黑（本环境既有）**，探针只证「混合模式/顶点 alpha 真的生效 + 几何仍提交」，**真机观感（30% 是否够透、是否看得清）待 Preview**；手机 FPS/全 DPR/真实 SDK/用户审美未验收。纹理禁压缩未完成、XHR96/233 未定位状态不变。
  - **POST 判定**：POST-1 状态/索引执行，persona 跳过（无新跨项目偏好）；POST-2 本人 Renderer3D/MetaUI 独立提交；POST-3 AB-330/331 执行，随行 persona/preferences 同理由跳过。保留并发 Game.lua/opening/ArtText/成就/纹理与发布配置、初始未跟踪文件，不代提交。

- 附记: shell-scale-1.5（2026-10-14，**全息外套放大到 1.5 倍**；沿用展示0.13.63，不抢并发版本）：
  - 用户要求「全息幻影为 .5 倍大小」——原话「透明度40% + 比车稍微大一点 + .5 倍大小」三处并列，取**最合理读数 1.5 倍**（比车大一半）：`0.5×` 会比车**小**（与「稍微大一点」矛盾）、`5×` 远超「稍微」。**已按 1.5 实现**；若用户本意是别的倍数，改 `VisualCatalog.CHARGE_HOLOGRAM.shellScale` 一处即可（助手判断，非用户确认参数）。
  - 改动仅两处：①`VisualCatalog.CHARGE_HOLOGRAM.shellScale` 1.06 → **1.5**；②`VehicleChargeFx.Debug()` 增只读诊断 `shellScaleRatio`/`shellAlphaNow`（**不改表现行为**，供探针断言「外套实际世界缩放 = 源车 ×1.5」）。外套其余逻辑（逐帧跟随源车显示变换、`shellAlpha` 0.40、TTL `(1-t)^1.2` 淡出、源车回收即隐藏）不变。
  - 验证：LSP **36 文件 0 Error**（1393 Warning/119 Hint）；官方多人 build + 预览上传 ✅。真渲染 `probe_shellscale` **5/5 PASS、exit0**：`shellScale==1.5`、`shellAlpha==0.40`、爆发期 `shellVisible>0`、**外套世界缩放/源车世界缩放 = 1.5000**（精确 1.5 倍）；目标 Lua/overlay/LoadChunk 错误 0。探针走真实 `client_main`（含两轮开局选车）。
  - 边界：本环境主 HDR 3D 恒黑，**1.5 倍是否合适（是否过小/过大、是否遮住车体关键读点）待 Preview 目视**；手机 FPS/全 DPR/真实 SDK/审美未验收。纹理禁压缩未完成、XHR96/233 未定位不变。
  - **POST 判定**：POST-1 状态/索引执行，persona 跳过（无新跨项目偏好）；POST-2 本人 VisualCatalog/VehicleChargeFx 独立提交；POST-3 AB-332 执行，随行 persona/preferences 同理由跳过。保留并发子车灰暗/拖拽减速/opening/ArtText/成就/纹理与发布配置、初始未跟踪文件，不代提交。

- 附记: drag-slowmo（2026-10-14，**拖拽蓄力期间全局减速 80%**；沿用展示0.13.63，不抢并发版本）：
  - 用户要求「拖拽时全局减速80%」。实现复用**既有 timeScale 链路**，零新增顶层 local：`BALANCE.dragTimeScale = 0.2`（拖拽时玩法时间放慢到 20%），`Game.Update` 的 dt 倍率改 `dt * (空手2倍 or 1) * (拖拽0.2 or 1)`；快照 `s.timeScale` 优先级改「拖拽蓄力 > 空手长按」，各特效模块（波壳/附魔球）**天然只乘一次**、无需改动。`elapsed` 仍按真实时间推进（不冻结 UI/震屏/表现衰减），只放慢玩法与依赖 timeScale 的特效。
  - **互斥说明**：拖拽蓄力时必有待发车，空手 2 倍速（`CanHoldSpeed`）要求空手，二者不共存；dt 乘法写全两个因子只是保持与旧代码一致。
  - 验证：LSP **36 文件 0 Error**（1393 Warning/119 Hint）；官方多人 build + 预览上传 ✅。真渲染 `probe_dragslow` **6/6 PASS、exit0**：未拖拽 `timeScale=1` / 拖拽 `timeScale=0.2` / **同一敌机同段真实帧下落 `slow/fast ratio=0.200`（精确 5 倍减速）** / 发射松手恢复 1 / 死区松手（未发射）也恢复 1；目标 Lua/overlay/LoadChunk 错误 0。探针走真实 `client_main`（含两轮开局选车）。
  - 边界：本环境主 HDR 3D 恒黑，**真机手感（0.2 是否过慢、是否影响瞄准）待 Preview 目视**；手机 FPS/全 DPR/真实 SDK/审美未验收。纹理禁压缩未完成、XHR96/233 未定位不变。
  - **POST 判定**：POST-1 状态/索引执行，persona 跳过（无新跨项目偏好）；POST-2 本人 Game.lua 独立提交；POST-3 AB-330 执行，随行 persona/preferences 同理由跳过。保留并发子车灰暗/opening/ArtText/成就/纹理与发布配置、初始未跟踪文件，不代提交。

- 附记: split-child-dim（2026-10-14，**分裂/三连子车改灰暗 + 降渲染层级**；沿用展示0.13.63，不抢并发版本）：
  - 用户「分裂产生的车既然不是正式的车那就变成灰色的暗淡的而且显示图层要低」——只改 `Renderer3D.lua`，不动玩法/伤害/分裂数量/拖尾/附魔/金色强化/暗科技 UI。
  - **识别子车**：无需改规则层——`Game.lua` 里所有非正式车（`CreateSplitMarble` 分裂车、`LaunchMarble` 的三连附加车）都带 `isPrimary = false`，且 `GetSnapshot` 的 `s.marbles` 是**原始引用**（字段可见）。`SyncVehicles.SyncOne` 取 `isChild = marble.isPrimary == false`。
  - **灰暗**：新增 `GetVehicleChildMaterials()`——中性灰调色板（body `{0.30,0.32,0.37}`、side/金属/灯同系灰）+ 压低的金属度，不再随弹种配色；`GetVehicleChildOutlineMaterial()` 把轮廓壳由**白亮**改**暗灰**并压低自发光（`0.05/0.055/0.065`）。⚠️ 子车轮子用**专属灰 `p.wheel`**，不复用 `WHEEL_COLOR`——`CreateMaterial` 按颜色缓存，复用会拿到正式车同一 `Material`，改它的 render order 会连正式车轮一起沉。
  - **低层级**：`VEHICLE_CHILD_ORDER = 64`，子车**全部 6 段 + 轮廓**统一 `SetRenderOrder(64)`；正式车保持默认。⚠️ **关键坑**：Urho3D 材质 render order **默认是 128（不是 0）**，值越小越早绘制=层级越低；**传负数会回绕成 246**（实测 `SetRenderOrder(-10)` → `GetRenderOrder()` 返回 `246`，反而更靠上）。所以子车取 **64（< 128）**。
  - **重建门控**：`record` 新增 `isChild`；`SyncVehicles` 的 elseif 条件加 `or record.isChild ~= isChild`，保证同一 id 在「正式↔子车」间切换时重建几何（防御性，正常 id 不复用）。
  - 验证：LSP **36 文件 0 Error**（1402 Warning/119 Hint）；官方多人 build + 预览上传 ✅。真渲染 `probe_child` **ALL PASS、exit0**：真实 `client_main` 路径（含两轮开局选车）注入三连附魔发射 → `maxChildCount=2`、`childOrder=64.0`、`normalOrder=128.0`、子车 body `{0.30,0.32,0.37}`；目标 Lua/overlay/LoadChunk/空顶点错误 0。
  - 边界：**主 HDR 中央 3D 仍黑（本环境既有）**，`childOrder=64<128` 只证明数据层材质真的下沉，**真机观感（子车是否够灰够暗、层级是否肉眼可辨）待 Preview**；手机 FPS/全 DPR/真实 SDK/用户审美未验收。纹理禁压缩未完成、XHR96/233 未定位状态不变。
  - **POST 判定**：POST-1 状态/索引执行，persona 跳过（无新跨项目偏好）；POST-2 本人 Renderer3D 独立提交；POST-3 AB-328/329 执行，随行 persona/preferences 同理由跳过。保留并发 Game.lua/opening/ArtText/成就/纹理与发布配置、初始未跟踪文件，不代提交。

- 附记: charge-anchor-shell（2026-10-14，**青圈圆心改锚车辆 + 40% 全息外套 + V 形半透明冲击波**；沿用展示0.13.63，不抢并发版本）：
  - 用户三点要求：①巨大青色圈以**车辆位置**为圆心；②全息爆发后一层**透明度 40%、比车稍大**的幻影壳**套在车上**（上一批 0.10 已按新值改为 0.40）；③车前**冲击波改为 V 字形、高质量半透明贴图**。只改 Game/Presentation/VisualCatalog/VehicleChargeFx/VehicleBowWave/ui.LaunchCharge，不动伤害/初速/回收/拖尾/附魔/金色强化与暗科技 UI。
  - **圈心改锚车辆**：`Game.GetSnapshot` 新增 `s.chargeCarX/chargeCarY`（= `chargeActive` 时 `activeBall.x/y`，否则 nil）；`marble_launched` 补 `carX/carY`。`ui/LaunchCharge` 圆心**优先** `project(chargeCarX, chargeCarY)`（与后端同一玩法投影 = 车辆屏幕中心），指针坐标降为旧调用回退；释放回声同样优先车辆坐标。车辆中心在玩法平面 z=0，用玩法投影即可，无需额外深度平面。
  - **40% 贴身外套**：`VehicleChargeFx` 第 3 批次 `ChargeHologramShell`（同型真实网格 + `PBRNoTextureAlpha`），逐帧取源车当前实际显示变换 ×`shellScale`(1.06) 套在车上，`shellAlpha` **0.40** 随 TTL `(1-t)^1.2` 淡出，源车回收即隐藏；两残像仍冻结基准+扩散，与外套独立。
  - **V 形半透明冲击波**：`VehicleBowWave` 由「车前弧壳（`HALF_ANGLE` 扇形 + `NoTextureUnlitVCol` 顶点色）」改为 **V 字形**——中线 `CentreX(s)=baseX+forward+V_DEPTH*(1-|s|)`（中央折角在车头正前最远、两翼后掠回落到车鼻前 `GAP`），横截面厚 `THICKNESS`、半高 `HALF_HEIGHT`、展宽 `V_SPREAD`（=1.12×车半宽，翼尖超出车体）。材质改 **`DiffAlpha` + 程序化 V 形贴图**（`CreateBowWaveTexture`：横截面软边 + 沿 V 长中央折角最亮的细热核），颜色走 `MatDiffColor`（`DiffAlpha` 只读纹理 alpha、不读顶点 rgb），`MatDiffColor` alpha 0.55 做高质量半透明；顶点仍写 `DefineTexCoord`(0/1) 供纹理采样。`Valid()` 删除 `HALF_ANGLE` 宽度门控，改 `hw<=1e-6` 拒绝。`PER_CAR` 仍 396、预算 8 车/3168 不变；`Shutdown` 释放自有贴图。
  - 验证：LSP **36 文件 0 Error**（1393 Warning/119 Hint）；官方多人 build + 预览上传 ✅。真渲染 `probe_chargeshell` **8/8 PASS、exit0**：车(270,850)≠指针(200,600)→**圆心=车辆投影点**；`shellAlpha==0.40`；爆发期 `shellVisible>0`；V 形波壳蓄力时真实提交 `count=1/vertices=396/actualVerts=384`、**材质绑定 true**（半透明带纹理）；目标 Lua/overlay/LoadChunk/空顶点错误 0。探针走真实 `client_main`（含两轮开局选车）。
  - 边界：**主 HDR 中央 3D 仍黑（本环境既有）**，`shellVisible>0`/材质绑定只证批次启用与数据通路，**V 形观感与 40% 透明度是否合适待 Preview 目视**；手机 FPS/全 DPR/真实 SDK/审美未验收。纹理禁压缩未完成、XHR96/233 未定位不变。
  - **POST 判定**：POST-1 状态/索引执行，persona 跳过（无新跨项目偏好）；POST-2 本人六 Lua 独立提交；POST-3 AB-325/326/327 执行，随行 persona/preferences 同理由跳过。保留并发 opening/ArtText/成就/纹理与发布配置、初始未跟踪文件，不代提交。

- 附记: charge-hologram-shell（2026-10-14，**青圈锚车 + 贴身全息外套**；已并入上条，保留历史）：
  - 用户两点要求：①巨大青色圈以**车辆位置**为圆心（不再锚手指拖拽处）；②全息幻影爆发后，额外有一层**很浅透明度、比车稍大**的幻影壳**套在车上**。本批只改 Game/Presentation/VisualCatalog/VehicleChargeFx/ui.LaunchCharge 五文件，不动伤害/初速/回收/拖尾/附魔/金色波壳与既有暗科技 UI。
  - **圈心改锚车辆**：`Game.GetSnapshot` 新增 `s.chargeCarX/chargeCarY`（= `chargeActive` 时 `activeBall.x/y`，玩法坐标，否则 nil）；`marble_launched` 事件补 `carX/carY`（发射瞬间车辆权威位置）。`ui/LaunchCharge` 圆心**优先**用 `project(chargeCarX, chargeCarY)`（与后端同一玩法投影 → 车辆屏幕中心），**指针坐标降为旧调用回退**；释放回声同样优先 `carX/carY`。车辆中心在玩法平面 z=0，故用玩法投影即可，无需额外深度平面。
  - **贴身全息外套**：`VehicleChargeFx` 新增第 3 个批次 `ChargeHologramShell`（同型真实网格、`PBRNoTextureAlpha` 半透明），逐帧取**源车当前实际显示变换**（worldPosition/Rotation/Scale）×`shellScale`(1.06) 等比放大套在车上，`shellAlpha`(0.10) 起随 TTL `(1-t)^1.2` 淡出；源车回收即隐藏。两残像仍是冻结基准 + 扩散，外套是**跟随源车**，二者独立。`VisualCatalog.CHARGE_HOLOGRAM` 增 `shellScale/shellAlpha`（助手拟值）。`Debug()` 增 `shellVisible`。
  - 验证：LSP **36 文件 0 Error**（1402 Warning/119 Hint）；官方多人 build + 预览上传 ✅。**真渲染探针 `probe_chargeshell` 12/12 PASS、exit0**：车辆坐标 (270,850) 与指针 (200,600) 不同 → **圆心等于车辆投影点（非指针）**；满蓄爆发期 `chargeHologram.life>0` 且 `shellVisible>0`（外套确实套在车上）；释放回声带 `carX/carY`；目标 Lua/overlay/LoadChunk/空顶点错误 0。探针走真实 `client_main` 路径（含两轮开局选车）。
  - 边界：**主 HDR 中央 3D 仍黑（本环境既有）**，`shellVisible>0` 只证明外套批次真实启用，**外套真机观感（透明度是否够浅、放大是否合适）待 Preview 目视**；手机 FPS/全 DPR/真实 SDK/用户审美未验收。纹理禁压缩未完成、XHR96/233 未定位状态不变。
  - **POST 判定**：POST-1 状态/索引执行，persona 跳过（无新跨项目偏好）；POST-2 本人五 Lua 独立提交；POST-3 AB-325 执行，随行 persona/preferences 同理由跳过。保留并发 opening/ArtText/成就/纹理与发布配置、初始未跟踪文件，不代提交。

- 附记: opening-transition（2026-10-14，**两轮开局选车的自动承接动画与文字提示**；沿用展示0.13.63）：
  - 用户反馈「开局机制突兀，需要有过渡动画和文字提示」；只补选车前后承接，不改上一批四车首阶、两轮三选一、两辆库存或正常经验升级。流程为briefing「两辆车，一起出战」→首发选择→between「首发已就位」→备弹选择→ready「出战阵容已就绪」→原完整3秒准备。自动衔接，无新增必须点击的确认按钮；0.95/0.65/1.05秒承接与每轮0.32秒保护为助手拟值，固定阶段合计3.29秒不含玩家选卡停留，非用户确认参数。
  - **规则**：Game._opening增加phase/timer/durations，仍借levelup冻结；只有select且timer归零允许PickUpgrade，选中事件保留原音效/反馈，账本独立XP/pending/picks/stacks。计时单帧最多0.05秒、微小尾数归零，大dt不跨多个阶段；ready结束本帧return，intro保持精确3秒且未刷敌。首选待发、次选备弹，不藏第三车；选关/下一关/再战/重开均重新承接，复活不重选，第三车/扩容/回收保持。
  - **表现与输入**：新ui/OpeningTransition只借宿主ctx/字体/令牌/原语，无新帧、上下文、字体、图片或RT；淡入/微缩/侧滑展示首发备弹、进度条及合批刻度，保留暗科技金属纹路。Backend七处opening接线、零新增Game/Backend顶层local；非select不画或命中卡窗，select还等真实首次可见WINDOW_IN，Update/Render/HitTest同源幂等计时与WindowInput逆变换。轮次仍参与同levelup身份，opening旧窗残影不遮ready/intro；正常升级保留/重抽广告恢复，承接连点不越轮或误射。
  - **验证**：正式规则11案例170505断言PASS，四CLI exit0（phase5/2382、64种子选车4/69873、公共战斗1/1844、自然normal上限1/96406）。战斗1760帧73发射135击碎69回收4升级，8种子自然分裂32000帧峰值≤15。最终merged-run3 UI610/guard42/胜败64共716/716 PASS，三exit0，真实ArtText.Tick153/53/269次；93脚本复制前后/结束同生产，最终client SHA0bb25ebab78398183c58f2cd4aa1bb5ce714600b4e401214b705605d441fbab1。目标Lua/overlay/load/空顶点错误0，四张实际TakeScreenShot/SavePNG图逐张内部目视briefing/between/ready/select2，标题/双车/三卡完整；模拟eventData/广告拦截非手机OS/SDK。
  - **正式构建**：本人亲自官方多人1.0.3/build4构建及预览上传成功，client719559df/serverd0ded454/engine ef9e23e2；225/226清单条目含各19平台变体，共244/245实际产物全size+CRC32匹配，45/46 Lua逐字节同生产，OpeningTransition UUID eb01ba2acf6dc96f334d90正确入包。证据/home/Maker/opening-transition-build4-verification-20261014.json；最新LSP36文件0Error（1410Warning/119Hint）、diff-check通过，提交前四本人文件SHA仍同冻结。纯POST不改生产Lua/assets、不重复build。
  - **失败与边界**：旧规则helper对nil候选、guard旧快照断言、隔离缺Tick与早期Python空输出/patch分段失败保留不计PASS；最终合并走真实Tick，修探针不改正确生产。无音频/体素/本地HDR噪音单列，四张overlay实图不等于主HDR3D或手机FPS/全DPR/手感/审美验收。纹理禁压缩未完成、历史XHR96/233未定位不变，不拿本批通过代替平台错误消失。
  - **POST判定**：POST-1状态/索引执行，persona跳过（本轮无新跨项目用户偏好）；POST-2本人Game/Backend七hunk/新模块meta与四份记录精确独立提交；POST-3 AB322执行，随行persona/preferences同理由跳过。保留4e108e7/62d7f9a及其记录、初始发布配置/媒体/未跟踪文件，不代提交。
  - **AB-322**：自动承接阶段与可交互选择阶段分离，规则计时和实际可见窗口入场双保护；切入玩法本帧不吞准备时间，同状态多轮共用真实可见身份与幂等Update/Render/HitTest。回归输入→Render→Update、重复Down/多指/旧Up、完整intro及正常升级恢复，alpha/隐藏控件不能替代规则保护。

- 版本: 0.13.63（2026-10-14，**高分/平台成就/艺术字异步加固；纹理禁压缩未完成**）：
  - **高分**：client_main先读云高分再允许写，全局Get/Set单在途；成功只确认本请求分数，失败/timeout保脏并15秒退避，首menu边沿不绕过读失败退避。Stop取规则/dirty/在途/retained最大值尝试本地保存，Start恢复；旧回调只释放旧槽，不污染新生命周期。提交throw或无终态保槽，不凭本地计时猜远端未执行；可能长期停发，非跨设备原子max/exactly-once，retained不跨页面/进程，Save返回false透传与清档全链未在本轮完整重审。
  - **成就**：离线不派发，全局单在途、每ID每Lua会话最多尝试一次；仅normal/ID/operation/currentStep匹配的SDK listener成功才写achPushed并保存。attempted墓碑跨Shutdown/Init，无终态不释放；throw/false/未知Shutdown/SDK变更或注销异常停止当前会话派发。不新增achUncertain、不迁移旧虚假确认，不声称真实SDK或跨刷新exactly-once。
  - **艺术字**：每图最多三次总尝试，明确失败后0.5/1秒退避，无回调保持waiting；资源与NVG尺寸双检、ctx/lifetime隔离，Ensure幂等，Tick由独立UI dt驱动，Backend仅可选第五尾参兼容旧调用。八图母版、CTA用户原图407×128及显示300.96×67不变，不重生图、不灰度量化、不删暗科技效果。
  - **纹理失败与撤回**：实验把71组.png.xml改为同stem.xml，使cooker实际读取非法none，build1的213项全部Unknown compress format:none。无可信合法跳过/无损配置，已逐字节核对142个XML/meta同HEAD，只撤回本人改名，PNG/UUID不变；受跟踪纹理无diff。build2恢复原实际策略，213结果15成功/198因cooking limit跳过/none错误0；71图默认5KTX1 ASTC6×6+66PNG，Windows4KTX1 BC7+67PNG。**禁压缩仍未完成**，不把总build成功、PNG扩展名或fallback冒称禁压缩成功。
  - **验证**：最终高分14独立进程/10业务组共38205检查、37707驱动帧PASS/exit0；旧P1/P2/P3及错误fixture日志保留。主循环run3 6案例1273断言、446Update/Backend/Tick、280发射后更新PASS；成就mock36/123、ArtText mock15/540与真实离线资源8/105两次PASS。五加固/接线源码同集成副本，菜单真实读回已内部目视，CTA实际pattern同300.96×67；单模块Art截图失败不称目视。mock云/SDK/eventData不等于真实服务/手机。
  - **正式构建**：展示0.13.63/包1.0.3为助手选值。本人官方build1与build2预览上传成功；build2 client eb402919/server8e4fd346/engine ef9e23e2，client234/server235产物（含各9Windows变体）全size/CRC32匹配，45/46 Lua及225/226 meta同源，451冻结前后无变，证据/home/Maker/four-hardening-package-integrity-1.0.3-build2.json。显式LSP36文件0Error（1410Warning/119Hint）；build2内置daemon不可用跳过gate，不能冒称内部gate通过。并发FX/opening后续串行构建由对应会话另记，不将本条固定build2当永久latest。
  - **边界与POST**：XHR233仍缺同会话请求/异常证据，与三项加固无因果证明；不禁云、不滤错、不称平台错误消失。手机FPS/全DPR/主HDR/真实SDK/用户审美待验。POST-1状态/索引执行，persona跳过（无新增跨项目偏好）；POST-2本人三Lua/Backend三处/版本及记录精确提交；POST-3 AB319–321执行，随行persona/preferences同理由跳过。保留并发FX/opening与其POST、settings/发布媒体/初始未跟踪文件，不代提交；纯POST不重复构建。

- 附记: charge-hologram-three-orbs（2026-10-14，**满蓄青色描边/双层全息爆发 + 每车三颗等距附魔球**；不抢并发展示版本）：
  - 用户要求跟手巨大青圈、满蓄描边变色/全息幻影、附魔减少为三个等距环绕球；原文颜色词不明确，本批暂按青色描边，不声称另获颜色确认。圈心原有真实ScreenToUi链已正确，不重复修改；保留满蓄金色车前波壳与单次×1.5伤害、拖尾及既有UI。两残像/0.65秒/0.65米为助手拟值。
  - **表现分层**：Presentation以pointerEpoch/gestureId识别满蓄边沿，serial/vehicleId标识爆发，真实marble_launched或强化飞行快照只锁一次released；已释放后不再依赖源车存活，防下一辆Down/源车自然回收截断TTL，未发射取消仍清。VehicleChargeFx新serial捕获实际显示root世界变换，两层真实车型残像沿确定轨迹扩散；轮廓临时换槽6材质，取消/重建/删除前恢复，不修改共享白材质。
  - **三球**：VehicleEnchantOrbs替换旧十粒aura，每车严格3颗真实3D球相差120°，各配同心halo，无卫星碎粒；四车最多12球/4320顶点，单车1080。蓝紫金稀有度、稳定id初相，允许玩法dt且timeScale只乘一次，暂停/intro隐藏冻结。独立LOCAL动态批次，空批不Commit、Clear后重绑、故障停用至Init，自有资源释放、不释放借用车。只改本人五Lua/两meta，Game/Backend零新增顶层local。
  - **验证**：上游专项9组41断言PASS、旧版同探针9FAIL；三球两次各36907断言，描边/全息79952与79959断言全PASS/exit0，独立Forward实图内部目视可见三球/青边/双残像。最终合并输入13案例188断言、规则32/789及10/529、整链run6与最终client合并run7各63/63全PASS/exit0，目标Lua/overlay/load/空顶点错误0；run7为245实际Update/245绘制帧/504Renderer调用，93脚本前后SHA同生产、358引用assets无变更，client SHA为0bb25ebab78398183c58f2cd4aa1bb5ce714600b4e401214b705605d441fbab1。整链实际金波396顶点/全暖金；run7两种源车自然回收时life均0.30、双残像仍可见并继续至自然过期，run6原图未覆盖。输入eventData/广告状态模拟不等于OS/SDK；规则副本Presentation较旧仅证明Game规则，最终FX由输入/run7/专项覆盖。
  - **正式构建**：本人亲自官方多人1.0.3/build3预览上传成功，client dc3efb5e/server604cd420；225/226清单条目含各14平台变体，共239/240实际产物全size+CRC32匹配。随后并发会话官方build4上传成功，本人独立亲验最终719559df/d0ded454：225/226条目含各19平台变体，共244/245实际产物零错配，45/46 Lua逐字节同生产、五FX同run7，两新模块meta UUID正确入包；证据/home/Maker/vehiclefx-integration-20261014/evidence/{run7,build3,build4}_verification.json。未手写dist，不把peer build4调用说成本人调用。
  - **失败与边界**：早期opening fixture/intro等待探针错误、run4错误恒定中心断言、run6启动前Python预检失败均保留不计PASS；冻结初始变换不等于扩散平均中心恒定，修探针不改正确动画。build3校验首轮exit1空输出未定位、次轮误认fs_path含scripts前缀使Lua核对失败，改资源根相对路径并补平台变体后才正式PASS，不据错误探针判包损坏。run7九张实际TakeScreenShot/SavePNG成功，但主HDR中央3D仍黑，不称主HDR/手机FPS/全DPR/用户审美验收；纹理禁压缩未完成、历史XHR96/233未定位不变。最新本会话LSP36文件0Error（1410Warning/119Hint）、diff-check通过。
  - **POST判定**：POST-1状态/索引执行，persona跳过（无新跨项目用户偏好）；POST-2版本记录及本人五Lua/两meta独立提交执行；POST-3 AB323/324执行，随行persona/preferences跳过同理由。保留并发opening/ArtText/成就/纹理XML与发布配置/初始未跟踪资源，不代提交；验收后无生产Lua/assets修改，纯POST不重复build。
  - **AB-323**：独立残像的上游TTL与下游冻结基准须一致；真实释放事实锁一次，后续源对象回收/下一手势不能截断已释放反馈；回归自然回收、下一辆Down、同帧释放回收与未释放取消。
  - **AB-324**：冻结初始变换不等于动画中心恒定；测试按规定世界轨迹与实际显示变换核验，断言错误只改探针并保留失败，独立Forward/截图API不冒称主HDR/手机验收。

- 附记: opening-vehicle-selection（2026-10-14，**新档四车首阶 + 每关两轮车型三选一**；不改展示版本）：
  - 用户要求新存档四车天赋首阶默认解锁，每关额外两次只出车辆解锁卡的三选一。实现不再固定赠送加速车：第一轮四种取三，第二轮排除首选、展示剩余三种；两辆不同车型，首选待发、次选备弹，无隐藏第三辆。候选排列为助手方案，非另行用户确认参数。
  - **规则与存档**：`Game._opening` 借用 levelup 模态，但轮次/已选列表独立于 XP、pendingLevelUps、upgradePicks/stacks；两选结束才启动原3秒 intro。选关/下一关/再战/重开覆盖，复活不重选；第三车解锁/扩容/回收照旧。`PlayerData.NewState` 默认 normal_1/ice_1/speed_1/giant_1，第二阶仍锁；成功旧本地档不强制迁移、AUTO_OWNED仍旧两项。无本地档先默认四节点再旧云并集可能保留四节点，不声称严格新账号识别；ResetAll/读取失败回退同默认。
  - **界面与输入**：显示开局选车/第1或2轮/已选车型，opening隐藏且禁止命中重抽广告与保留，正常经验升级恢复旧操作区。两轮同为levelup，openingRound参与窗口身份；Update/Render/HitTest共用幂等入场起点及WindowInput逆变换，Shutdown复位。保留暗科技卡片/字体/折行/既有效果与并发蓄力，Game/Backend零新增顶层local，仅改本人三Lua。
  - **验证**：规则4组69873断言、存档mock5组132、真实公共API战斗1组1844，全PASS，最终与复跑六进程exit0；64种子/576次两轮覆盖12有序车型组合、298次不含speed。实战1760帧/73发射/135击碎/69回收/4经验升级，第三车21发、扩容后43回收。UI run5真实处理器159/159、旧胜败边沿64/64（共223）exit0，目标Lua/overlay/load/空顶点错误0；三张真实TakeScreenShot/SavePNG已逐张内部目视两轮与普通升级，opening两图差8018像素。输入eventData/存档File/广告拦截为模拟，不等于OS/SDK；早期错误断言及额外稳态首轮截图两次失败保留、不计PASS。
  - LSP32文件0Error（1334Warning/118Hint）；此前最终官方多人1.0.2/build4与预览上传成功，client49840fdc/server1a234278，222/223项size+CRC32全匹配、三本人Lua包内同源码，规则六模块/UI87文件冻结一致，独立静态审查无确定缺陷。收尾三源码SHA仍与正式冻结一致、diff-check通过；续接后的Python全清单重查exit1无输出/日志读取失败原因未定位，不冒称重查通过、不据此判包损坏或重建。未改验收后生产Lua，纯POST不重复build。
  - **POST判定**：POST-1状态/索引与项目persona规则演进执行；POST-2版本附记及本人三Lua/记录独立提交；POST-3 AB-317/318执行，随行persona/preferences跳过（无新跨项目偏好）。保留c89aa98蓄力及AB315/316、配置/初始未跟踪文件，不代提交；手机手感/FPS/全DPR/主HDR/真实SDK/用户审美待Preview，历史XHR96/233未定位状态不变。

- 附记: launch-charge（2026-10-14，**拖拽收缩圈 + 满蓄金色车前冲击波与 1.5 倍伤害**；不改展示版本）：
  - 用户要求起手大圈跟随拖拽处匀速缩到0，发射消散，归零后发射车前波壳染金且伤害×1.5。实现暂用1.2s/半径240设计像素/0.22s消散（助手拟值，不是用户确认参数）。圈心走真实ScreenToUi指针，不锚车辆/虚拟aim、不随世界震屏；旧二参输入回退玩法投影。原圆形相对拖拽、方向/初速/死区/回收、拖尾/附魔/胜败过渡保留。
  - **规则**：Game._launchCharge使用允许inputDt且单帧最多0.05，独立于hitStop与空仓倍速；暂停/失焦/广告/升级等取消。Up先仅CancelHoldSpeed，发射锁定实例chargeBoosted后清手势；死区不发射。新车false，分裂/附魔追加子车只继承布尔，不累乘；GetMarbleDamage在附魔后暴击前统一×1.5，圆域/连锁/爆炸同入口，炸弹/DOT不增强。Game/Backend零新增顶层local。
  - **表现**：Presentation消费marble_launched保存释放回声TTL，新ui/LaunchCharge复用宿主ctx，三层环与24刻度合批，半径精确0不绘制、HUD/Dock裁剪；VehicleBowWave只对本车资格染金/暖白金，原396顶点、几何、法线、变换和时钟不改。
  - **验证**：基础规则两次各32案例/789断言，增量10案例/529断言全PASS/exit0（chain各格2.5→3.75、explode2→3、power6→9；炸弹/DOT反例不变，DOT状态fixture不代表自然施加全路径）。输入12案例/160断言PASS；最新Backend合并复跑同样通过，实际圈Draw五阶段各4次、半径240→120→精确0、释放/过期正确，实际截图已内部目视。波壳实际792顶点/797断言PASS，396对局部位置/法线相同、396色差，**TakeScreenShot=false，无波壳实图，不称目视通过**。失败探针/两次截图失败保留，不计PASS；输入eventData与广告状态为模拟，不冒称手机OS/真SDK。
  - LSP32文件0Error（1334Warning/118Hint）；本人官方build3成功上传，最终合并官方1.0.2/build4由并发会话执行，client49840fdc/server1a234278；主会话全量复核222/223项size+CRC32零错配，七脚本包内与当前源码一致。独立静态审查无确定缺陷。手机手感/FPS/全DPR/主HDR/金色波壳最终观感与用户审美待Preview。
  - **POST判定**：POST-1状态/索引执行，persona跳过无新跨项目偏好；POST-2本人七脚本/新模块meta与记录独立提交；POST-3执行AB-315/316，随行persona/preferences跳过。保留opening选车/PlayerData/配置/初始未跟踪媒体，不代提交，不处理历史XHR。
  - **AB-315**：本次发射强化在释放瞬间锁实例，中央伤害只乘一次，子实例复制资格非复制已放大伤害，新待发实例复位；测试真实每格HP减量、分裂与附魔组合及非车辆伤害反例。
  - **AB-316**：指针蓄力要分玩法/真实UI坐标与输入/模拟时钟；取消与正常释放分开，精确归零不留最小圆，覆盖最后Up坐标、时钟钳制、重复Down/失焦/广告/模态与旧Up，实际Draw及截图不能由静态公式替代。

- 修复/调查: clarity-rt-xhr233（2026-10-14，**展台自适应物理 RT + 艺术字就绪/生命周期；233 次 XHR 未定位**；不改展示版本）：
  - 用户要求以固定 512×288 展台 RT 为模糊主因修复，并追查「开始战斗缩水」及 233 次 XHR。仅改 MetaUI/Backend/VehicleShowcase/ArtText/DigitFont，保留六车显示大小、灯光、白轮廓、透明、30Hz、原特效与圆形拖拽/车前波壳 dt 链；不改战斗规则、正交投影或服务端。
  - **展台**：Update/Draw 共用矩形，尺寸预算乘 `scale_*dpr_`，16:9 contain 后预留3%弹动，64px分档，512×288至1920×1080；同生命周期只升档，隐藏/拖尾商店页不更新。新 RT 先准备成功，再释放旧 NVG 包装/解绑旧surface/Dispose旧纹理；增长失败保旧、停止逐帧重试，Shutdown复位。3%/64/1920为助手策略，不是用户参数。1080×1920首页896×504，1440×2560首页1216×684；超上限仍可能放大。
  - **艺术字**：八图布局改用实测成品母版，用户CTA原图407×128、绘制300.96×67不变。GetResourceAsync真实资源回调后注册并核对尺寸，拒绝正数占位；失败保持zpix回退，不每帧重试。lifetime token拒绝旧ctx迟到回调；Backend四处nvgDelete前Reset ArtText/DigitFont。手机那次具体占位尺寸未取得，不将风险封堵冒称手机根因复现。
  - **验证**：最终生产七源码与冻结副本SHA一致；八项真实Runtime回归exit0：尺寸39断言、换档真实Draw95帧/2次分配、故障注入只尝试1/释放候选1、Backend生命周期14、初始化失败6、首页Art8/CTA300.96、图集mock14、延迟完成真实NanoVG。八项目标Lua/overlay/load/空顶点错误0。最终同帧Forward对照512→1024实图已目视轮圈/线条更清楚，实际TakeScreenShot帧15、exit0；不代表手机或主HDR战场验收。最初组合命令探针启动前退出，不计PASS；首轮700帧战斗超时，不计PASS。最终缩短280帧仍走真实HandleUpdate/进关/发射并保留正向断言，exit0、state=playing/enemies=1/launched=true，波壳实际396顶点，目标脚本错误0；未证明700帧长跑或手机输入。
  - LSP32文件0 Error（1332 Warning/118 Hint）；官方多人1.0.2/build2预览上传成功，client50e957f7/server26ca8616，两清单221/222项size+CRC32全匹配，五修改脚本包内与源码一致；未手写dist。独立只读审查无确定缺陷，仅静态/算式证据。
  - **XHR233未修**：报告首条2026-10-13 14:22:08.171、生成14:22:27.324，fcb250f9/24772cad为引擎身份。公共loader的formatError将对象JSON.stringify，标准Error不可枚举message/stack丢为{}，原console.error保留完整参数；这只证明诊断细节丢失，不解释原异常。原手机同会话请求URL/方法/状态/响应类型/initiator/message/stack缺失，公共引擎发行包未找到精确catch；不重复盲扫、不禁云、不屏蔽错误、不拿本地离线或成功业务替代消除验证。96与233报告独立记录，未部署宿主报告器修改。
  - **POST判定**：POST-1状态/索引执行，persona跳过无新跨项目偏好；POST-2版本附记与本人五脚本独立提交；POST-3执行AB-312/313/314，随行persona/preferences跳过无新偏好。手机清晰度/实际新包加载/FPS/全DPR/用户审美待Preview；保留发布配置与初始未跟踪文件，不代提交。

- 附记: circle-drag-bow-wave（2026-10-14，**完整圆形拖拽 + 车头前方真 3D 冲击波**；不改展示版本）：
  - 用户要求「手感操控优化，从发射拖拽范围变为圆形，和车辆之前增加3d冲击波开始做起」，位置明确「车辆前方」。本批仅改 Game/Renderer3D/Backend/client_main 并新增 `VehicleBowWave.lua`（含 `.meta`），保留原拖尾、附魔光环与胜败过渡，不改伤害、碰撞半径、成长、初速公式、回收条件或服务端职责。
  - **圆形输入与车位分离**：删除半径钳制后的 `dy<=90` 削平限制；完整输入半径仍 150、方向仍 −pull、死区仍 15、力度仍用完整向量。`pullPositionScale=0.6` 将实际车位位移缩成半径 90，避免下拉满幅把待发车拖出画布。PointerMove 与最终 PointerUp 同帧更新 aim/车位，释放出生点不再落后一帧。0.6 为助手拟值，非用户指定或已认可。
  - **车前立体弧壳**：独立 LOCAL 动态 CustomGeometry 单批次，16 段/396 顶点每车/最多 8 车（3168 顶点）；真实车型 bbox 定车鼻与半宽，白热内核/弹种彩边，UnlitVCol 可辨性兜底。局部厚度 0.12、半高 0.05、最小间隙 0.16、宽比 1.1、0.9s 前向脉冲均为助手参数。在 SyncVehicles 之后用实际 `root:LocalToWorld` 与世界旋转绑定，跟随平滑显示朝向而非速度目标角；批次节点世界恒等，反射/非等比/剪切安全跳过。
  - **生命周期与时钟**：有效几何 Commit 后重绑材质；空批禁用且不 Commit；dirty 覆盖半成品清理，Sync 失败释放并停用直到 Init，不每帧重试，不释放借用车辆。`UpdateScene→Renderer.Render` 增可选允许玩法 dt 尾参，广告传 0、顿帧传 gameDt，波壳模块只乘一次 timeScale；暂停/升级/结算隐藏冻结、新局复位。Backend 零新增顶层 local，旧四参 Renderer 调用兼容。
  - **验证**：圆形规则两次各 91 案例/4821 断言全 PASS；真实输入处理器两次各 9 案例/131 断言全 PASS（eventData 模拟，非手机 OS 输入）；冻结波壳 phase0/phase0.45/生命周期三次各 3273 断言 PASS、Renderer 36/36、广告/暂停/真实长按 2× 11/11；真实 Presentation `base_hit` 处理器顿帧专项 77/77，主会话最终同源码复跑仍 77/77、exit0。五源码 SHA256 与冻结测试版一致，目标 Lua/overlay/LoadChunk/空顶点错误 0；环境既有 HDR/无音频/无体素噪音不计脚本错误。
  - LSP **32 文件 0 Error**（1329 Warning/118 Hint）；官方多人 **1.0.2/build1** 成功并上传预览，client `c045182f` / server `6ad1f2a9`，清单 **221/222 项 size+CRC32 全部匹配**，新模块 uuid `6cd4fc94d3da47d48bb16c` 已入包；未手写 dist。独立 Forward 六车型实图可辨，两相位原图差异 11481 像素；不等于主游戏 HDR/手机 FPS/全 DPR/真广告 SDK/用户审美已验收，手感与最终观感待 Preview。
  - **POST 判定**：POST-1 执行状态/索引，persona 跳过（具体需求无新跨项目偏好）；POST-2 执行版本附记与本人片段独立提交；POST-3 执行 AB-309/310/311，随行 persona/preferences 跳过（无新偏好）。保留并发 ArtText、发布配置、RT/Reset 与初始未跟踪文件，不代提交；构建冻结窗口已释放，后续记录不代表并发新版本验收。

- 调查: xhr-report-96（2026-10-13，**96 次 `XMLHttpRequest response: {}` 尚未定位，不冒称修复**；无游戏代码/配置改动）：
  - 用户报告 `fcb250f9 (HEAD@24772cad)`、2026-10-13 15:14:12.632 首条、15:36:07.413 生成。公开 stable→引擎 **1.33.14 / manifest49920946**；`src/engine/assets/BNghoXJZYBHd9d6Ij4FLlfFu-212defa1.json` 返回相同 binary_hash/commit_hash/branch，125B CRC32=212defa1。**两哈希是引擎身份，不是游戏包哈希，不能据此判旧包**。
  - 本轮只读校验当前 **build33**（client6007d810/server7e6e8b39）清单 **220/221 项 size+CRC32 零错配**，sources仅engine-res、adopt空；不支持重现此前清单损坏/official pin 两条根因。
  - 平台运行索引本轮588条，UTC14:48:11..15:35:26，仅engine/user_script/server_user_script三渠道，**无精确XHR条目或URL/HTTP状态/异常栈**；调试反馈查询返回0条（不标记已处理）。包含23:14:12本地启动及随后云高分/存档/余额成功，但成功业务不能证伪宿主其它请求失败，也不能把96个错误等同96次请求。
  - 当前代码只读审查未发现失败后每帧重发闭环；高分15s周期无在途锁、成就离线门控/异步确认等为**独立候选隐患，尚无请求级证据关联本报告**，不以顺手加固代替根因修复。公开loader/引擎JS未找到精确报错catch；不改只读宿主或dist、不禁云、不过滤错误。
  - **待证据**：原报错请求的脱敏路径/方法/状态/响应类型/initiator与异常message/stack，或可复现的操作链；没有Cookie/Authorization需求。本轮未改Lua，LSP/build/玩法回归判定跳过；**未完成用户要求的代码修复及平台错误消失验证**。POST-1执行调查状态，persona跳过无新偏好；POST-2独立记录提交；POST-3沿用AB-238证据纪律，跳过无新增跨项目事实。保留并发ArtText/发布配置及其它玩法修改，不代提交。

- 修复: end-transition-input-fix（2026-10-13，**修胜利/战败动画被输入跳过 + 结算窗先闪后弹**；不改展示版本）：
  - 用户「胜利和战败动画被跳过」。本批只改 `ui/StageTransition.lua`、`game/client_main.lua`、`Scene3DBackend.lua`，不改动画视觉/总时长、Game/Presentation/Renderer3D、存档或服务端职责。
  - **跳过门控与生命周期**：旧 `Skip()` 无条件置位，战斗连点会吞掉开头；旧状态只以 `animAt` 数值复位，重开时间回卷/两态同起点会串场。改 `transition_={state,startAt,lastElapsed,skipped}`，状态/起点变化、离开过渡、时间回卷均复位；后端每帧同步。只在原「点击跳过」提示时刻后允许跳过（胜利 1.55s、战败 3.40s，助手选定防误触门控，非用户指定参数）。**总时长仍胜利 2.15s、战败 4.0s**，提示与资格共用常量。
  - **输入**：过渡 Down 清结算 armed，早期点击只消费；尾段合法跳过的同一次 Up 不再操作按钮。战败回车/空格过渡期只尝试合法 Skip、重复键不跳过/重开。隐藏结算按钮不可命中，胜利回车仍不自动下一关。
  - **结算窗入场**：此前 0.32s 入场在进入结算态时已开始，前置动画结束时入场早已耗尽。改在首次真正可见时启动；复核再发现「输入 Skip → Render → 下一 Update」可先完整闪现再归零，抽 `uiFx.UpdateGameWindow(game)` 让 **Update/Render/HitTest 同步同一可见边沿与入场时钟**，下一 Update 不重复重置。挂既有 uiFx 表，零新增 Backend 顶层 local。
  - **验证**：`probe_endedge` 同一探针修前 **56 PASS / 4 FAIL**（新增两态各两条时序断言抓到先闪/重置），修后 **60/60 PASS、exit0**；实际过渡 Draw 胜利 75 次/战败 151 次，窗口 scale 0.9738..1.0299；覆盖早期鼠标/触摸、TouchID0/第二指/跨态抬手、重复键、自然结束/尾段跳过/同手势不重开、相同时间戳跨态/重开隔离、输入后先绘制。目标 Lua/overlay/LoadChunk/空顶点错误 0，三脚本生产/隔离副本 SHA256 一致。LSP **31 文件 0 Error**（1291 Warning/118 Hint）；官方多人 **build32 + 预览上传成功**（client `6007d810` / server `7e6e8b39`），两清单 **220/221 文件 size+CRC32 全部匹配**；`git diff --check` 通过。
  - **边界与 POST 判定**：探针驱动真实处理器但 eventData 是模拟输入，强制结算状态非完整自然打一关；本环境深帧截图不可靠，未自证手机动画画面/手感/FPS/全 DPR。早期探针显式 `ClientMain.Stop` 清理路径退出139未定位，最终探针不显式调用它，**不声称 Stop/Start 通过**。POST-1 执行状态记录、persona 跳过（无新用户偏好）；POST-2 独立代码/记录提交；POST-3 执行 AB-307/308，随行 persona/preferences 跳过（无新偏好）。保留并发 ArtText/发布配置，不代提交。
  - **AB-307**：过渡跳过状态不能只由重置型时间戳标识，须同时处理状态身份、离开与时间回卷；提示、跳过资格、按钮可见性共享裁决，覆盖键盘重复与同一手势不穿透。
  - **AB-308**：延迟显示窗口的入场计时必须在首次可见边沿开始，Update/Render/HitTest 共用幂等同步；测试必须包含「输入 → Render → Update」，只测 Update 后 Draw 会漏掉先闪再弹。
- 版本: 0.14.0（**成就并入战斗档案：单入口 + 页签 + 翻页 + 已解锁置顶**；不改展示版本常量）：
  - 用户「成就界面并入战斗档案任务，同时战斗档案任务也并入平台成就，并增加额外成就，列表变为上下翻页且被解锁的优先在顶端」→ 澄清后：①主菜单**只留「战斗档案」一个入口**（去掉独立「成就」卡）；②档案屏内加**两个页签**（战斗档案 / 成就）；③档案里程碑各做成一条**平台成就**；④**再加额外成就**；⑤成就列表改**上下翻页**且**已解锁优先置顶**。
  - **入口合并**：`MetaUI.GetGrowDefs` 删掉「成就」卡（grow 行 5→4，`GetMenuBarLayout` 的 `grow` 回到 `row(842,80,4)`）；战斗档案卡副标题在有可领奖励时优先提示、否则显示 `成就 N/M`。
  - **页签（`MetaUI.DrawPass`/`HitTestPass`）**：新增 `GetPassTabs(content)`（两枚各半宽页签，`content.y+2`，h40）与 `GetPassBody(content)`（页签下移 50px 的内容区）。**档案内容整体改用 `body` 定位**（`hero`/`GetPassUnlockRect(body)`/`SectionHeader(body...)`/`GetPassRewardRect(body,i)` 全部由 `content`→`body`）——⚠️ 改几何来源时**绘制与命中必须同改**（`HitTestPass` 的 piggy cr / unlock rect / 里程碑行也全部换 `body`），否则「看得见点不到」。页签命中返回 `pass_tab`/`ach_tab`。
  - **成就列表（`ui/Achievements.lua` 重写）**：不再注册独立屏，改为 `MetaUI.DrawPass` 在成就页签直接 `Achievements.Draw(ctx, body, meta)` / `Achievements.HitTest(uiX,uiY,body,meta)`（`MetaUI` 顶部 `require "ui.Achievements"`）。列表**已解锁优先置顶**（`BuildList` 两趟收集：unlocked 在前、locked 在后，稳定不跳变）；**翻页**改「‹ 上一页 / 页码 / 下一页 ›」三件（`ach_prev_page`/`ach_next_page`，`metaState.achPage` 钳 1..pages），删掉旧的「点文字区循环」。单页可见数由 `GetListRect` 高度反推（`VisibleCount`）。
  - **额外成就（`AchievementCatalog`）**：新增 3 条档案里程碑成就 `pass_lv3`/`pass_lv5`/`pass_lv6`（steps = 档案等级 3/5/6，`ComputeValue` 读 `PlayerData.GetPassLevel()`）。目录 20→**23 条**。
  - **里程碑条数 5→4**：页签占去 50px，第 5 条里程碑会被底栏裁掉 → `client_main` 的 `#rewards >= 5` 改 `>= 4`（真渲染截图实锤）。
  - 验证：LSP workspace **30 文件 0 Error**；真渲染探针 `probe_achtab`（`DebugOpenScreen("pass")` → 页签命中 `pass_tab`/`ach_tab` 各半区正确、零 overlay/Lua/LoadChunk 错误）；`probe_ache2e`（**真实鼠标点击**：菜单「战斗档案」卡 → 成就页签，端到端零错误）；`probe_passtab`（档案页签真渲染截图确认 3 条里程碑完整、无裁切）。**实图目视**：成就页签——8 张已解锁卡全「已达成」置顶、`1/3 页`、上一页禁用/下一页可点、查看平台成就按钮；档案页签——页签在顶、英雄卡+里程碑完整。官方多人 build + 预览上传 ✅。展示版本归并发会话（本批未动 BUILD_VERSION）。
  - 边界：⚠️ **本环境 `-screenshot-frame` 深层帧不可靠（AB-220）**，但本次真渲染截到目标屏（成就/档案页签内容清晰可辨）→ 实图可视作有效证据。手机 FPS / 全 DPR / 用户审美未验收。
  - ⚠️ **避雷 AB-301：把「某面板」并入「另一面板」时，被并入方若原本是独立「元层屏」，要**取消其 RegisterScreen 并改为被调用**（achievement-into-pass）：本项目 `ui/Achievements.lua` 原本 `MetaUI.RegisterScreen("achievements", …)` 独立成屏；并入后改为 `MetaUI.DrawPass` 直接 `Achievements.Draw/HitTest(ctx, body, meta)`（`MetaUI` 顶部 require），**删掉 `RegisterScreen` 与 `open_achievements` 分支**（否则残留一个永远打不开的屏 + 主菜单多一张卡）。⚠️ 被并入的 Draw/HitTest 形参要从「w 整宽」改成「rect 内容区」，且**绘制与命中共用同一 rect**（本项目传 `body`）——几何来源一改，两侧必须同改。
  - ⚠️ **避雷 AB-302：给「底部有固定按钮/状态栏」的面板加内容，要先算「内容底边 vs 底栏顶边」的间隙**（achievement-into-pass，承接 AB-259/292）：档案屏加 50px 页签后，第 5 条里程碑（`content.y+196+4*92` 附近）被底部状态栏裁掉——**只有真渲染截图能发现**（LSP/build/纯几何探针都无感）。修法：把可变内容条数从 5 收到 4（或加高容器）。**通用规则**：给面板顶部/底部加固定高度元素时，先算中间可变内容的可用高度，装不下就**减条数或加高容器**，别只挪 y。

- 修复: highscore-cloud-write-merge（2026-10-13，**最高分云写合并——修「每击碎一块砖刷新最高分就写一次云」**；承接 skill 合规检查，不改展示版本）：
  - 用户先让对照 `@tianyi_multiplayer-game-skill` 检查云端存档实现形式 → 结论：本项目属 skill 定义的「JSON/存档中继 + 私有实例」（M=0、无 Scene/pawn、服务端只做 IAP 发货 + 钻石余额），**配置/`.meta`/远程事件/user_id 键/云变量分工均合规**；唯一实质问题是**最高分云写未合并**。
  - **真因**：`client_main.HandleUpdate` 的 `if snapshot.highScore > lastSavedHighScore then SaveHighScoreToCloud(...)` 在**每次分数刷新最高分**时立即写云（`lastSavedHighScore` 写入时即抬到当前值）——一局破百砖就是上百次 `SetInt`。云写配额 300 次/分钟（recipe），单条不越界但形态正是 skill 反复点名的「没有每帧 SetVar / 每加一条同步先问 O(?)」。
  - **修法（`client_main.lua` 一处 + 4 个顶层 local，95/200 余量充足）**：①`MarkHighScoreDirty(score)`——局内只累计待提交值（`highScoreDirty`）；②`CommitHighScore()`——**进入结算/菜单态那一帧**提交一次 + **每 15 秒周期兜底**（防玩家局内久留丢分）；③`SaveHighScoreToCloud` 改「**成功才确认** `lastSavedHighScore`」（失败时重新标脏，等下次提交重试，离线/配额超限不丢分）；④`CommitHighScore` **每次调用都重置 15 秒冷却**（防写失败时持续态每帧重试）。
  - ⚠️ **关键陷阱（本批自己踩到并修，见避雷 AB-306）**：结算/菜单是**持续态**——首版写 `if gameover or stagewin or menu then CommitHighScore()` 会让写失败（error 回调重新标脏）**每帧重试**，远超配额。修法：加 `prevHighScoreState_` 记上一帧 state，只在**进入**这些态的那一帧提交。
  - 验证：LSP **30 文件 0 Error**（1390 诊断）；**真渲染 mock 探针**（mock `clientCloud` 计数 + 真实 `HandleUpdate` 路径，用 `Game.ApplyCloudHighScore` 注入待提交值）——**快乐路径** `probe_hsmock5`：局内 140 帧 **0 次写**（核心优化成立）→ 进菜单提交 **1 次**、值正确（5000）、写入成功；**风暴路径** `probe_hsmock4`：1000 帧（其中 800 帧处于写失败的菜单态）**只尝试 3 次**（进入 1 + 15s 周期 2），旧代码会是 ~800 次 → **storm 已消除**。官方多人 build + 预览上传 ✅。展示版本归并发会话（本批未动 BUILD_VERSION）。
  - 边界：手机 FPS / 全 DPR / 真实联网（平台侧云写配额）未验收；**真机长时间游玩时「局末提交是否及时、失败重试是否如预期」需 Preview 目视**。
  - ⚠️ **避雷 AB-303：`debug.getupvalue` 在本运行时取不到被 require 模块的私有 upvalue（名字被剥）——验证私有函数别指望它**（highscore-cloud-write-merge）：本批首版纯逻辑探针用 `debug.getupvalue(_G.HandleUpdate, i)` 想取 `MarkHighScoreDirty`/`CommitHighScore`，实测 `got Mark=false Commit=false`（且 `probe_dbg` 连 `[DBG]` 打印都没出——该运行时可能不支持 `debug` 库）。**做法**：验证私有逻辑走**真实公共路径**——mock 外部依赖（本项目 mock `_G.clientCloud` 计数）+ 驱动真实 `HandleUpdate`，用**公共接口注入状态**（`Game.ApplyCloudHighScore(n)` 造待提交值），断言外部可观测效果（写次数/写入值）。
  - ⚠️ **避雷 AB-304：验证「周期性/冷却」逻辑时，要按「帧数×dt 上限」换算真实时长，别用帧数当秒数**（highscore-cloud-write-merge）：本项目 `dt = math.min(inputDt, 0.05)`——**每帧最多 0.05s**，所以「15 秒冷却」需要 **≥300 帧**才到期。本批探针首版菜单窗口只 218 帧 → 周期兜底还没触发 → 断言「菜单期尝试次数」时把「进入菜单那一帧的提交」算进了边界外，误读成「0 次/漏写」。**做法**：验证冷却/周期时，先算 `需要的帧数 = 冷却秒数 / dt上限`，窗口取 ≥ 该值 + 余量；断言窗口的**起止帧**要避开状态切换那一帧（提交落在「进入态的那一帧」，在窗口边界上）。
  - ⚠️ **避雷 AB-305：探针工程目录残留的存档文件会污染注入值**（highscore-cloud-write-merge）：`/home/Maker/urhox-probe-live/player_data.json` 是**历史探针留下的**（`highScore=160000`），`PlayerData.Load` 会把它读进内存，导致探针 `ApplyCloudHighScore(5000)` 被忽略、日志出现莫名其妙的 `SetInt high_score=160000`。**做法**：跑涉及存档的探针前 `rm -f <探针目录>/player_data.json`（或先备份），确保从「无本地存档」的干净状态起步；发现「注入值不生效」先怀疑残留存档。
  - ⚠️ **避雷 AB-306：给「持续态」（菜单/结算）挂「进入时执行一次」的动作，必须记上一帧 state 做边沿触发——否则「失败会重试」的动作会每帧触发（写风暴）**（highscore-cloud-write-merge）：本项目「最高分提交」首版写 `if gameover or stagewin or menu then CommitHighScore()`——而云写失败的 `error` 回调会**重新标脏**，于是持续态**每帧重试写云**（远超 300 次/分钟配额）。修：`prevHighScoreState_` 记上一帧 state，只在**进入**这些态的那一帧提交（边沿触发）。**判据**：任何「失败会重试」的动作，挂到「会停留多帧的状态」上时，一律用**边沿触发**（`state ~= prevState and <进入条件>`）而不是**电平触发**（每帧判 `<处于该状态>`）。

- 附记: visual-recipes-skill（2026-10-13，**把「逐层绘制」反哺进 dark-tech skill**；纯文档，不改展示版本）：
  - 用户「继续然后我要求最具体的绘制比如你这些流光纹理按钮也要反哺skill」——上一轮反哺的是**架构/界面/适配**层，这次要的是**「最具体的绘制」**：一个控件、一层的**逐行画法**（面板怎么叠六层、按钮的漆面与扫光怎么画、艺术字怎么染色）。**「具体」是关键词**——不是再写一遍「要贵」，而是把**代码**给出来。
  - **产出（`references/visual-recipes.md`，469 行新增）**：把本项目**已落地并跑过真机**的绘制提炼成可复制配方，每条 = 完整代码 + 参数 + **层序** + 性能门槛 + 踩过的坑：①金属面板六层（双层投影 → 对角金属渐变 `+30/−9` → 内顶受光 → 内底沉影 → 玻璃漆面斜高光 → 亮暗描边，装饰门槛 `big=w>=130 and h>=66`）；②按钮（漆面斜高光 / 3.2s 斜扫光前 55% / 6s 底边流光 / **暖金「贵金属」配方**，`warm` 判定别写成「非青即暖」）；③窗口壳（外辉光 + 标题舱受光带）；④背景在动（径向底 + 暗角 + 顶部环境辉光 + 7s 慢速扫光）；⑤艺术字（**乘法染色塌陷约束**）；⑥像素图标（NEAREST / 32×32 / ≤9 色 / 死键 / 「AI 原图直接缩 32×32 ≠ 像素画」）；⑦悬停加色光（`GetControlFx` 显式登记 + 平滑逼近 + 指针在所有 return 之前喂入）；⑧氛围标量（`AnomalyPulse`）；⑨非阻塞提示（上边界不能用 dangerY + 互斥 + 按状态自隐）；⑩10 条交付检查清单。`SKILL.md` 参考列表 + 工作流指引 + `elements.md` 文件清单已接入。
  - **同批的空仓「长按加速」提示**：我实现了 `uiFx.holdHintLayout`/`uiFx.holdHint`（挂 `uiFx` 表，零新增顶层 local），但**并发会话的 `full-review-2026-10-13` 已一并修完并验证**（修了我第一版把 `dangerY` 当上边界的 bug + 加了「按住时自隐」门控）。我的独立验证 `probe_holdhint` **8/8 PASS**（进关过渡 `visible=false` / 球在弹弓 `visible=false` / 发射后空仓 `visible=true cx=270 ringY=383` 带高 494 / 按住 `timeScale=2 visible=false` / 松手 `timeScale=1 visible=true` / 互斥 `showPullHint=true→false` / `pending`·`2x` 均 `false`）。**本批不重复记入版本行**。
  - **加强（同日第二版，用户「我要求最具体的绘制比如你这些流光纹理按钮也要反哺skill」）**：上一版 `visual-recipes.md` 只给了**调用层**（「面板叠哪六层、在哪调什么原语」），**没给原语本身的绘制代码**——用户点名要「最具体的绘制」。**补 §11「装饰原语实现」（+377 行）**：把 `ui/PremiumSurface.lua` 里每个装饰 helper 的**完整代码**搬进 skill——`MicroGrid`（极淡方格，合并单一路径）/ `DiagonalHatch`（斜拉丝，起点 -h→终点 w 覆盖全矩形）/ `Halftone`（**隔行错位半调 + 按面积自适应步长 + 合并路径**，budget 600）/ `DotMatrix` / `CircuitTrace`（L 形走线 + 端点焊盘，dx/dy 可负）/ `CornerBrackets`（四角折线，**同一组 ± 符号同时定角点与臂朝向**）/ `DashRule`（断线，末段自动截短）/ `TicksBatch`/`Ticks`/`TopTicks` / `TickRing`（**长短两档各合并 1 条路径**）/ `Cross`/`CrossBatch` / `ScanBand`（**流光**：三条同向不同 alpha 的线 = 扫过 + 拖尾）/ `GlassStrip` / `Screws` / **悬停加色光**（`nvgBoxGradient` 内半径小外半径大 → 光从边缘外泄；alpha 由平滑 glow 驱动）/ **按钮流光**（斜扫光**四边形**非竖条 + 底边亮流光，两段都裁进圆角、相位确定性）+ §11.0 **性能契约**（同色一批线/点必须合并单一路径，逐段各起路径会撑爆命令缓冲 → 本帧绘制静默丢弃）+ §11.16 检查清单。原 §10 检查清单顺延为 §12（置于末尾）。`SKILL.md` 指引/参考列表 + `elements.md` 文件清单同步标注「§1–9 调用层 + §11 原语实现层」。纯文档，无需 build/预览。
  - 验证：LSP **30 文件 0 Error**（1390 诊断）；官方多人 build + 预览上传 ✅；skill 为纯文档，无需 build。展示版本归并发会话（本批未动 BUILD_VERSION）。
  - ⚠️ **避雷 AB-299：反哺 skill 的「具体绘制」时，要连 层序 + 参数 + 性能门槛 + 踩过的坑 一起给，不能只贴代码**（visual-recipes-skill）：用户要「最具体的绘制」——但**只给一段 `nvgXxx` 调用是没用的**：①**层序**（先投影后色面再漆面）决定了「厚度」，顺序错就白画；②**参数**（渐变跨度 `+30/−9`、扫光周期 3.2s/6s、装饰门槛 `w>=130`）是从「±5 看不出、±30 才有金属感」「步长 8 撑爆命令缓冲、12 才安全」这类**实测**里定出来的；③**坑**（青/深 tint 塌成黑疙瘩、`stretchX` 上限 1.0 等于禁用拉伸、上边界用 dangerY 会让带高为负）是**只有踩过才知道**的。**做法**：每条配方写成「观感目标 → 层序代码 → 参数来源 → 踩过的坑 → 尺寸门槛」五段；⚠️ 本项目的坑大多**不是「不会画」而是「画了看不见/画了塌/画了撑爆」**——把「为什么这么画」写清楚，下一个项目才不会重踩。
  - ⚠️ **避雷 AB-300：两个会话同时在做同一件事时，先 `git log`/读 CLAUDE.md 现状再动手，别各做一遍**（visual-recipes-skill）：本批我实现空仓提示时，**并发会话已在同一文件同一函数上修了同一 bug 并写了 AB-297/298**——我发现时已有**三处重复**（同函数改动、同 bug 的抗体、同功能的验证探针）。**做法**：接「看起来像新功能」的任务前先 `grep` 该功能的关键符号（本项目 `holdHint`）与 `git log -- <file>`，确认是否已有人在途；**若发现重复，把归属让给已提交的一方，自己只保留独有产出**（本批只保留 skill 反哺，版本行不重复记）。⚠️ 我的第一版探针还因**没意识到该功能已被改对**而误报 FAIL——**探针跑之前先确认被测代码是当前 HEAD/工作区的哪一版**。
  - ⚠️ **避雷 AB-306：反哺界面绘制要分「调用层」与「原语实现层」——只给调用层会被判「不够具体」（visual-recipes-primitives）**：上一版 `visual-recipes.md` 给了「面板叠哪六层、在哪调什么原语」（**调用层**），用户「我要求最具体的绘制比如你这些流光纹理按钮也要反哺skill」→ 真缺的是**原语实现层**（微网格/斜拉丝/半调/点阵/电路刻纹/刻度/扫描带流光/玻璃条/螺钉/悬停光/扫光**本身**怎么画）。**做法**：反哺绘制时**两层都给**——调用层（层序 + 参数 + 在哪调）+ 实现层（原语的完整代码 + 关键算法：如 `Halftone` 隔行错位/自适应步长、`CornerBrackets` 用同一组 ± 符号定角点与臂朝向、`ScanBand` 三条同向不同 alpha = 扫过+拖尾、悬停光用 `nvgBoxGradient` 内小外大让光外泄）。⚠️ **实现层必须连性能契约一起给**（合并单一路径 + 自适应步长），否则别人照抄会撑爆命令缓冲（AB-216）。

- 修复: full-review-2026-10-13（2026-10-13，**全量排查 + 修 3 处真 bug**；承接 preload-corrupt-manifest）：
  - 用户「全量排查游戏问题」。机械检查 + 探针 + agent 深审三层，结论：**无编译级/加载级致命错误**（LSP 0 Error；`Scene3DBackend.lua`/`Game.lua` 各 **200 顶层 local** 仍在硬上限内但零余量，AB-166 纪律继续）。
  - **修 3 处真 bug**：①🔴 **空仓「长按加速」提示从不显示**（`Scene3DBackend.uiFx.holdHintLayout`）——把 `dangerY`(游戏 Y=900) 当**上边界**、`slingY`(850) 当下边界，但游戏 **Y 向下为正** → danger 在弹弓**下方** → `bottomLimit-topY≈-173 < 104` → 恒 `visible=false`（整条功能是死的，探针实测全程 false）。修：上边界改用 `HUD_HEIGHT+44`（空场 = HUD 下方→弹弓车上方）、`ringY` 取带中；②**长按时提示未隐藏**（同函数）——加门控 `if game.holdSpeedPending or (game.timeScale or 1) ~= 1 then return out end`（玩家已按住时「长按加速」提示多余）；③**成就 toast 永久驻留**（`client_main` 结算块）——`metaState.toast = ...` 直接赋值**不重置 `metaToastTimer`** → 提示永不自动消失。修：改用 `SetMetaToast(...)`。
  - **顺手加固 2 处维护隐患**（`AchievementCatalog`）：`codex_all` 的 `steps` 写死 **23** → `MetaCatalog.GetCodexTotal()`；`talent_all` 写死 **42** → `#TalentCatalog.GetNodes()`（新增图鉴/天赋节点后，写死值会让成就**永远无法达成**或提前解锁）。
  - **审查排除的「疑似 bug」**（实测非 bug，记录以免重复排查）：①agent 报「高分开局被重置会丢分」——**不成立**：`Game.lua` 的 `highScore` 是**单调**的（所有赋值都是 `if score > highScore`，`ApplyCloudHighScore` 只抬不降，`ResetGame` 不碰它），`snapshot.highScore` 不会下降 → 顶部 guard 会重新标脏；②`probe_hslogic` 的 3 个 FAIL 是**探针断言错**（失败尝试也调了 `SetInt`、自然计入 `writes` 计数；代码的「失败重标脏 + 下次重试」逻辑正确）；③`uiFx.holdHint` 覆盖「每次补弹窗口」是**设计本意**（`canHoldSpeed` = 空手 = 补弹窗口，不是「空弹夹」）。
  - 验证：LSP **0 Error**（1390 诊断）；`probe_ach` **29/29 PASS**（加固后复跑仍全绿）；**时序正确的真渲染探针 `probe_hold2`**——4 项全 PASS（进关过渡不显示 / 空仓显示 `cx=270` / 长按 2x 时隐藏 / 松手 1x）；真实玩法冒烟 `probe_render` `frame=700 state=playing stage=1 wave=2 launched=true` 零 Lua/overlay/LoadChunk 错误；本地真实启动零 `Module not found`。官方多人 build（client `6ac5f814`）+ 预览上传 ✅；**全清单完整性校验 217 文件 0 错配**（crc32+size 全匹配）。展示版本归并发会话（本批未动 BUILD_VERSION）。
  - 边界：手机 FPS / 全 DPR / 用户审美未验收；**空仓提示的真机观感（位置/文案/脉冲）需 Preview 目视**。
  - ⚠️ **避雷 AB-297：画「屏幕空间的一条带」时，务必先确认「游戏 Y 方向」与「屏幕 Y 方向」的关系**（full-review-2026-10-13）：本项目游戏 **Y 向下为正**（`DANGER_Y=900` 在屏幕**下方**、`SLING_Y=850` 在其上方），而写代码时很容易把「危险线」直觉当成「上边界」。`holdHintLayout` 因此把 danger 当上边界、sling 当下边界 → 带高恒为负 → **整条提示永不显示**（LSP/build/纯几何断言都发现不了，只有**真渲染探针读 `visible`** 才暴露）。**做法**：①用 `ProjectGamePoint` 打印两点的**屏幕 Y** 确认上下关系，别凭命名猜；②带类几何的可见性断言要覆盖**「该显示时必须显示」**（本项目原探针只测了「不该显示时不显示」，全绿却漏了主功能死掉）。
  - ⚠️ **避雷 AB-298：给 UI 写「直接赋值 toast/提示」前，先看有没有 `SetXxx` 封装——直接赋值常漏掉「计时器/生命周期」**（full-review-2026-10-13）：本项目 `metaState.toast` 由 `metaToastTimer` 驱动自动清除，`SetMetaToast()` 同时设文本**和**重置计时器；结算块直接 `metaState.toast = ...` → 计时器没重置 → **提示永久驻留屏上**。**做法**：凡是「有配对计时器/状态机」的展示字段，一律走封装函数；`grep "function Set"` 确认封装存在。
  - ⚠️ **避雷 AB-299：「全量排查」要三层并用，且**不轻信 agent 结论**——逐条回代码验证**（full-review-2026-10-13）：①机械检查（顶层 local 数、前向引用、清单完整性、LSP）；②真渲染探针（抓 LSP 查不到的绘制期/几何期 bug）；③agent 深审（广度）。⚠️ 本次 agent 报的 6 条里**只有 1 条成立**（toast），其余是**误报**（高分单调性、hint 覆盖范围）或**维护隐患**（写死步数）——**agent 的「发现」必须回代码逐条验证**再决定改不改（同 AB-296 的「先验证再动手」）。⚠️ 真渲染探针要**断言「正向功能」**（该显示时显示），只测「不该出现时没出现」会让**主功能死掉也全绿**（本项目 holdHint 探针正是如此）。

- 修复: preload-corrupt-manifest（2026-10-13，**修「黑屏 + Module not found: Scene3DBackend」——清单与产物哈希错配**；不改展示版本）：
  - 平台报错 20 条 / 6 类，核心链：`LoadPreloadResources` → `Download failed: 1 file(s) (Downloaded file is incomplete or corrupted)黑屏` → `BootstrapPipeline: step 'LoadPreloadResources' failed` → 1852 帧后 `Error executing Lua module 'game.client_main': [string "game/client_main"]:12: Module not found: Scene3DBackend` → `Execute Lua function failed`（main.Start 连锁崩）。其余：`XMLHttpRequest response: {}` ×14、`Server error occurred before connection`。
  - **真因（完整性校验实锤）**：**清单记录的资源哈希/大小与实际产物不一致**。`dist/1.0.1/manifest-d8030526.json` 里 `Scene3DBackend.lua` 记 `hash=8d87062e, size=155296`，但 `dist/assets/DAy-mUok7X6-cXy_fLKON6zk-8d87062e.lua` 实际 **155424 字节**（=当前源码）。清单哈希算法 = **CRC32**（实测产物 `crc32=8d87062e` 与清单 hash 一致，但 size 不匹配 → 下载后校验判「incomplete or corrupted」）。成因：**上次构建时（22:43:29）有并发会话正在写该文件**——构建早段读中间态（155296）算哈希、后段复制到最终态（155424），**清单/产物错配**。`Scene3DBackend` 是 `#blocking` 资源 → 预下载失败 → `require` 拿不到 → 黑屏 + Module not found。
  - **修法（两步）**：①**移出无引用的垃圾参考图** `assets/image/OIP (1).webp`、`assets/image/下载 (3).webp`（+`.meta`，带空格/括号/中文名、无任何代码引用，被 `resources.json` 的 `**` 全量引用打进了包 → 移出，减少下载面）→ `/home/Maker/junk_refs/`；②**重新构建**（build 25，`client=0f370e6e`），让清单与产物重新一致。
  - 验证：**全清单完整性校验**——新清单 **217 个文件全部存在、0 处 size 不匹配**（旧清单 1 处错配 = `Scene3DBackend.lua`）；`Scene3DBackend.lua` 条目现为 `size=155424` 且实测 `crc32=8d87062e` **与 hash 精确匹配**；垃圾 webp 已从清单消失（219→217）；**本地真实启动**（`UrhoXRuntime main.lua -tool_mode -graphicssurfaceless`）**零 `Module not found` / 零 `Execute Lua function failed` / 零 `LoadChunk failed`**，日志见 `[Scene3DBackend] NanoVGRender callback active` + `overlay snapshot active state=menu`（剩余 ERROR 全为本环境既有噪音：无音频设备 / 无体素模块 ECEBFC51 / llvmpipe BloomHDR shader）。官方多人 build + 预览上传 ✅。展示版本归并发会话（本批未动 BUILD_VERSION）。
  - 边界：手机 FPS / 全 DPR / 用户审美未验收；**真实预览包下载**（平台侧 CDN）未自证，需 Preview 目视确认黑屏消失。
  - ⚠️ **避雷 AB-295：构建产物「下载损坏/黑屏 + Module not found」先查**清单哈希 vs 实际产物**（preload-corrupt-manifest）：本项目包清单给每个资源记 `hash`（**CRC32**，8 位 hex）+ `size`；运行时下载后按此校验，不匹配即 `Downloaded file is incomplete or corrupted`。**根因是构建时清单与产物错配**——典型场景：**构建期间有并发会话正在改文件**（本项目 `Scene3DBackend.lua` 被并发写），构建早段读到的内容算哈希、后段复制的却是最终内容 → 错配。**做法**：①写脚本逐条校验 `dist/<ver>/manifest-<client>.json` 的每个 `files[]`：按 `uuid-hash.ext` 拼路径，比对 `os.path.getsize` 与 `size`、`zlib.crc32` 与 `hash`——**0 处不匹配才算包干净**；②发现错配**直接重新构建**（会重算）；③**构建前确认没有并发会话在改脚本**（本项目报错的 HEAD 是 `d29142cf`，本地工作区 `Scene3DBackend.lua` 恰在构建时被改过）。⚠️ 全量引用（`resources.json` 的 `**`）会把**无引用的垃圾文件**也打进包（本项目两张参考图 webp）——交付前扫 `assets/` 有无「带空格/括号/中文名且无代码引用」的文件，一并移出。
  - ⚠️ **避雷 AB-296：`Module not found: <X>` 不一定是 X 本身缺失——先确认 X 在清单里且清单/产物一致**（preload-corrupt-manifest，承接 AB-238 同族）：本项目报 `Module not found: Scene3DBackend`，但**清单里有 `Scene3DBackend.lua` 且与源码逐字节相同**——真因是**资源下载校验失败**（清单哈希错配）导致该模块拿不到。**判据**：先本地 `pcall(require, X)` 隔离（本项目实测四个大模块**全部加载正常**）→ 排除代码问题；再查清单完整性；再看 `LoadPreloadResources` 是否失败。**别一上来就怀疑 X 的语法/顶层 local 上限**（AB-166/217 是另一条路径：那条会报 `LoadChunk failed: too many local variables`）。

- 版本: 0.13.60（**设置页补全：音乐/音效开关 + 制作鸣谢**）：
  - 用户「设置页补全功能，音乐音效。制作者：薪主  导入素材工作室出品。特别鸣谢TapTap」——在既有设置屏（恢复购买/清空存档）上补 ①音乐/音效两个开关 ②制作鸣谢三行。
  - **音频开关（`AudioDirector`）**：新增 `SetMusicEnabled/SetSfxEnabled/IsMusicEnabled/IsSfxEnabled` + 只读诊断 `DebugEnabled/DebugSfxPlays`。`state.musicEnabled`（默认 true）控制 **BGM 目标增益**（`TargetGain()` 返回 `BGM_GAIN` 或 0）——关音乐时**淡出静音、曲目状态保留**（开回来续播，不 Stop 断音）；`state.sfxEnabled` 在 `PlaySfx` 开头短路（关音效时**不播任何音效**）。
  - **持久化（`PlayerData`）**：新增 `musicEnabled/sfxEnabled`（默认 true）；`Load` 用 `d.musicEnabled ~= false`（**缺省开**，旧档无字段不误关）；云合并**仅当云端是显式布尔才覆盖**（纯偏好，不取并集）。新增 `IsMusicEnabled/IsSfxEnabled/SetMusicEnabled/SetSfxEnabled`。
  - **设置屏（`ui/Settings.lua`）**：`GetSettingRows` 从 2 行扩到 **4 行**（音乐/音效/恢复购买/清空存档）；新增 `ToggleRow`（拨动开关：开=青轨道+右滑青滑块，关=暗轨+左灰滑块）；面板 `h 360→600`、`y 300→180`、行高 64→60、step 76→72（**先加高容器再排 y**，AB-259）；鸣谢区（「制作鸣谢」青色标题 + 断线 + 三行 `制作者：薪主 / 导入素材：工作室出品 / 特别鸣谢：TapTap`）。命中新增 `toggle_music`/`toggle_sfx`。
  - **编排层（`client_main`）**：metaState 加 `musicEnabled/sfxEnabled`，`RefreshMeta` 从 PlayerData 填；`HandleMetaAction` 新增 `toggle_music`/`toggle_sfx`（翻转 → 写存档 → `RenderBackend.SetMusicEnabled/SetSfxEnabled` 立即生效 → 云同步 → toast）；启动时（`PlayerData.Load` 后）把存档开关作用到音频总控；**清档后**开关回默认开并重新作用。
  - **后端（`Scene3DBackend`）**：`Backend.SetMusicEnabled/SetSfxEnabled/AudioEnabled`（挂 Backend 表，**零新增顶层 local**，AB-265/268）。
  - 验证：LSP **29 文件 0 Error**（1334 诊断）；纯模块探针 `probe_audioset` **24/24 PASS**（默认开 / 音效关后 `DebugSfxPlays` 不再增 / 音乐关后 `DebugEnabled=false` / PlayerData 开关持久化 reload 存活 / 云显式布尔覆盖 + 旧档保留本地 / 设置屏 4 行 + 关闭命中 + 面板外不命中 + Draw 不崩）；真渲染探针 `probe_setrender`（真实鼠标点击两行开关，经 `ScreenToUi` 逆变换）实测 `music=false sfx=false pdMusic=false pdSfx=false`（编排层→AudioDirector+PlayerData 同步）、后端委托 `AudioEnabled()→false`；真渲染截图**实图目视**——音乐/音效青色开关、危险操作行、鸣谢三行（薪主/工作室出品/TapTap）、关闭按钮不压鸣谢；完整战斗冒烟 `probe_audiorender`（进关+发射）`AudioDirector initialized sfx=20/20 bgm=9`、零 `overlay stage failed`/`Execute Lua function failed`/`LoadChunk failed`/`VertexBuffer is empty`。官方多人 build + 预览上传 ✅。展示版本 → **0.13.60**（BUILD_VERSION + lobby_runtime）。
  - 边界：⚠️ **本环境无 `/dev/snd`（`Could not initialize audio output`）**——探针只能证「开关状态机 + 通路 + 不崩」，**实际静音/发声效果必须 Preview 真机**。手机 FPS / 全 DPR / 用户审美未验收。
  - ⚠️ **避雷 AB-289：给音频总控加「静音开关」要改**目标增益**，不要 `Stop`/`Play` 硬切**（settings-audio-credits）：本项目 `AudioDirector` 的 BGM 走**两条通道交叉淡入淡出**（v0.13.x 契约）。加音乐开关时若在 `SetMusicEnabled(false)` 里直接 `Stop()`，会**断音**（下次开回来要重新淡入、且曲目位置丢失）。做法：引入 `TargetGain()`（开=`BGM_GAIN`、关=0），`StartTrack` 与 `UpdateBgm` 都从它取目标增益 → 关音乐只是「目标增益变 0、自然淡出」，曲目状态（`bgmTrackIdx/bgmTime`）保留，开回来续播。⚠️ 音效开关同理——在 `PlaySfx` **开头短路**（不播），别去 `Stop` 已播放的音源。
  - ⚠️ **避雷 AB-290：加「设置项开关」要三处同源——存档(默认开) + 编排层(即时生效) + 后端委托**（settings-audio-credits）：本项目开关链路是 `PlayerData`（持久化，`~= false` 缺省开）→ `client_main.RefreshMeta`（填 metaState 供屏渲染）→ `HandleMetaAction`（翻转+写档+`RenderBackend.Set*` 即时生效+云同步）→ `Scene3DBackend` 委托（挂 Backend 表，零新增 local）。⚠️ **启动时**（`PlayerData.Load` 之后）必须把存档开关**作用一次**到音频总控，否则重启后设置屏显示「关」但实际还在响；**清档**后也要重作用（回默认开）。⚠️ 云合并对「纯偏好」用**显式布尔才覆盖**（不是取并集/取大）——否则新设备会把本机的关静音强行打开。
  - ⚠️ **避雷 AB-291：往「已满 200 顶层 local」的后端加开关委托，只能挂表**（settings-audio-credits，承接 AB-265/268）：`Scene3DBackend.lua` 顶层 local 已满 200——本批的 `SetMusicEnabled/SetSfxEnabled/AudioEnabled` 全部是 `function Backend.Xxx(...)`（挂表），**零新增顶层 local**。自检：`git diff scripts/Scene3DBackend.lua | grep "^+local "` 应为空。
  - ⚠️ **避雷 AB-292：新增设置行要「先加高容器再排 y」，并用**真渲染截图**验证不重叠**（settings-audio-credits）：把设置屏从 2 行扩到 4 行 + 鸣谢区时，首版 `h 360→500` **不够**——关闭按钮（`y+h-64`）压住了鸣谢第三行「特别鸣谢：TapTap」（**只有真渲染截图能发现**，LSP/build/纯几何探针都无感）。修法：`h 500→600`、`y 220→180`、行高/step 收紧（60/72）。**通用规则**：给「底部有固定按钮 + 中间有可变内容」的面板加内容时，先算「内容底边 vs 按钮顶边」的间隙，容器不够就加高——别只调行 y。

- 附记: wave-speed-ramp-by-stage（2026-10-12，**开局缓入起始倍率随关卡下降**：关1 60% → 关20 起 40%；不改展示版本）：
  - 用户「第一波到第四波敌人的移速倍率为60%逐渐加回到100%，随着关卡数字增大，60%这个值逐渐降低。在20关到下限40%」——在 v0.13.60 的「关内前四波缓入」之上，把**起始倍率**从常量 0.6 改成**随关卡号下降**：关1 = 0.60、每关线性降、**关 20 起封底 0.40**；第 4 波仍恒回 1.0。
  - **实现（`StageCatalog.GetWaveSpeedRamp(stageWave, stage)` 一处）**：`start = 0.6 - min(stage-1, 19) * (0.2/19)`，`ramp = start + (w-1) * ((1-start)/3)`（`w>=4 → 1.0`）。`GetBaseSpeed` 传入 `stage`。⚠️ **`stage` 形参可选**（缺省 1 = 起始 0.6），**旧单参调用（探针等）仍可用**；**零新增 `Game.lua` 顶层 local**（AB-166）。
  - 验证：LSP workspace **29 文件 0 Error**（1334 诊断）；规则探针 `probe_wsramp2` **14/14 PASS**（关1=0.6000 / 关10=0.5053 / 关20=0.4000 / 关21=0.4000 封底；关1..20 单调下降且线性等步长 0.2/19；波4..10 在关1/5/20/30 全为 1.0；关1 首波 = 原曲线×0.60、关20 首波 = 原曲线×0.40、关20 波4 = 原曲线；实战关1/关20 首波真实生成 vy>0）；回归 `probe_wsregress` ALL PASS；真渲染冒烟 `probe_render` `state=playing stage=1 wave=2 enemies=3 launched=true`、零 `overlay stage failed`/`Execute Lua function failed`/`LoadChunk failed`/`VertexBuffer is empty`。官方多人 build + 预览上传 ✅。展示版本归并发会话（本批未动 BUILD_VERSION）。
  - 边界：手机 FPS / 全 DPR / 用户手感未验收；**真机观感（高关开局更慢是否明显、关20 后 40% 是否过缓）需 Preview 目视**。
  - ⚠️ **避雷 AB-293：验证「相对倍率」时别拿**绝对速度**跨关卡比——基数本身随关卡涨**（wave-speed-ramp-by-stage）：本批探针两度 FAIL 都是我自己的断言错——①断言「关20 首波速度 < 关1 首波速度」，但绝对速度含 `min(stage-1,12)*1.8` 的关卡基数（关20 首波 55.6×0.4=22.24 > 关1 34×0.6=20.40）；②断言「关20 实测 vy < 关1 实测 vy」，但实测 vy 还乘了**机型 speedMul**（关20 池里有更快机型）。**做法**：验证「相对倍率/缓入比」只看**纯函数**（`GetWaveSpeedRamp` 返回值、或 `GetBaseSpeed / 原曲线`），**别跨关卡比绝对速度**；实战探针只断言「真实生成成功、不崩」。
  - ⚠️ **避雷 AB-294：给「随关卡变化」的曲线加形参时，把新形参设为**可选**以保住旧调用**（wave-speed-ramp-by-stage）：`GetWaveSpeedRamp` 原签名 `(stageWave)`，本批要加 `stage`——设为**可选尾参**（`stage or 1` 缺省），既让 `GetBaseSpeed` 传关卡号、又让历史探针/其他单参调用零改动。**判据**：给「已被多处调用」的函数加形参时，若旧调用语义仍成立（缺省 = 原行为），一律做成**可选尾参**而不是必填——省掉 grep 所有调用点（同 AB-196「可选尾参」纪律）。

- 附记: spawn-lane-stage-fix（2026-10-12，**修「每关第一架都贴最左」**；不改展示版本）：
  - 用户「为何每一关第一个飞机都靠很左啊」。
  - **真因（算式实锤）**：`SpawnWave` 的起始车道 `pendingSpawn.lane = (wave - 1) % 5` 用的是**累计波号 `wave`**——每关首波 `wave = (关卡-1)*10 + 1`，减 1 后是 **10 的倍数**，`(10k) % 5 == 0` 恒成立 → **每关第一架永远落在车道 0（最左）**。v0.13.27 的「起始车道随波次错开」对**同关内**后续波有效，但**跨关的首波恒贴左**（用户看到的正是每关开局）。
  - **修法（2 处）**：①`StageCatalog.SPAWN_LANE_COUNT = 5`（单一来源，替换 `Game` 里的函数内魔数 `laneCount = 5`）；②起始车道改 **`(stage - 1 + stageWave - 1) % SPAWN_LANE_COUNT`**——每关首波 = `(关卡-1) % 5`，逐关轮换（关1→车道0、关2→车道1 … 关6 回车道0）；同关内仍随波次错开。**零新增 `Game.lua` 顶层 local**（AB-166）。
  - 验证：LSP workspace **29 文件 0 Error**（1319 诊断）；规则探针 `probe_lanefix` **6/6 PASS**（公式：关1..10 首波车道 `0,1,2,3,4,0,1,2,3,4` 覆盖全部 5 条、关6 周期回 0；**实战每关第一架 x 实测 25.1 / 111.6 / 198.1 / 263.6 / 343.1**（关1..5，横跨场地，此前全 ≈25 贴左））；回归 `probe_wsregress` ALL PASS（机型池递进 / 血量封顶 / 屏外上限 / 真实发射 playing）；真渲染冒烟 `probe_render` `state=playing stage=1 wave=2 enemies=2 launched=true`、零 `overlay stage failed`/`Execute Lua function failed`/`LoadChunk failed`/`VertexBuffer is empty`。官方多人 build + 预览上传 ✅。展示版本归并发会话（本批未动 BUILD_VERSION）。
  - 边界：手机 FPS / 全 DPR / 用户手感未验收；**真机观感（每关开局位置轮换是否自然）需 Preview 目视**。
  - ⚠️ **避雷 AB-285：「按波次错开」的偏移量别用**累计波号**，否则会被关卡长度整除、退化成常数**（spawn-lane-stage-fix，用户「为何每一关第一个飞机都靠很左」）：本项目车道 = `(wave-1) % 5`，而每关 10 波 → 每关首波 `wave-1` 恒为 10 的倍数 → `%5` 恒 0 → **每关第一架都贴最左**。**判据**：凡「随波次/关卡轮换」的偏移，若它的模数能整除**关卡长度**（或任何周期性基数），就会在每个周期起点退化成同一个值。**做法**：偏移里**显式掺入关卡号**（本项目 `(stage-1 + stageWave-1) % N`），并**探针断言「连续多关的该位置两两不同、且覆盖全部槽位」**——只测「同关内后续波不同」会漏掉这个坑（v0.13.27 的探针正是只测了同关内）。

- 附记: defeat-transition（2026-10-12，**失败结算加 4 秒「防线崩溃」动态漫过渡**；承接 endpage-layout，不改展示版本）：
  - 用户「失败重构之后需要用三到五秒动画表现，甚至要复杂一点，做成动态漫」——**失败页此前无过渡**（`gameover` 直接弹结算窗），而胜利页早就有 `StageTransition`（2.15s 星级分档动画）。本批把过渡**扩展到失败态**，并做成 4.0s 的**多段落动态漫**。
  - **数据层（`Game.lua`，挂 `Game._defeat` 表——顶层 local 已满 200，AB-166）**：gameover 分支写 `Game._defeat.at = elapsed`（过渡计时基准）+ `.revive`（是否可复活）；快照出 `s.defeatAt`/`s.defeatRevive`；`ResetGame` 复位。**零新增顶层 local**。
  - **动画层（`ui/StageTransition.lua`，本批新增失败动画）**：新增 `DEFEAT_DURATION = 4.0` + `DrawDefeat(ctx, game)`——**红/暗红/铁灰**色调（与胜利的青/金区分），**12 个段落**按 t 秒依次展开：①白色冲击闪（0.10s）+ 强震屏 ②红色裂纹从中心蔓裂（10 条确定性折线 + 白热核）③砖块碎片自下飞散（16 片，确定性初速/自转/重力回落）④防线断裂（横向裂痕 + 红色警戒光带扫过）⑤「防线失守」大字冲击入（缩放 + 双描边）⑥分数滚动（战报数字）⑦统计逐条淡入（到达关卡/击碎/强化/存活）⑧底部红色警戒扫描线 ⑨四角取景折线（红调）⑩「点击跳过」提示。**全部确定性伪随机**（`hash01(n)=sin(n*12.9898+78.233)*43758.5453` 取小数，**非 math.random**——重开/暂停不抖动）。
  - **门控泛化（关键）**：`StageTransition` 原只读 `stageResult.animAt`，本批抽出 `TransitionInfo(game)` 统一返回「本态起点 + 时长」——`gameover` 读 `defeatAt`/`DEFEAT_DURATION`、`stagewin` 读 `animAt`/`DURATION`；`WindowVisible`/`IsActive`/`Skip`/新增的 `Elapsed` **全部走它**，渲染与命中同源。
  - **接线（`Scene3DBackend.lua` 一处 + `client_main.lua` 一处）**：绘制条件 `game.state == "stagewin"` → **`(stagewin or gameover)`**；`HandleGameOverPointerDown` 补「过渡期间任意点击 = 跳过」（与 `HandleStageWinPointerDown` 同款）。
  - **`Game.DebugForceGameOver` 增强**（探针用）：原来只把 `baseHp=1`，改为**复刻真实 gameover 分支**（置 `gameState`/`_defeat.at`/发 `game_over` 事件），探针才能进失败结算态。
  - 验证：LSP workspace **29 文件 0 Error**（1339 诊断）；**逻辑探针** `probe_defeat`——`state=gameover defeatAt=1.0`、`DURATION=4.0`、门控边界实测 **t=0~3.9 `visible=false`（结算窗不弹）/ t=4.0 `visible=true` / t=4.5 `elapsed=nil`（过渡结束）**；**真渲染探针** `probe_defrun`（让动画跑满 t 0→3.03s）**零 `overlay stage failed`/`Execute Lua function failed`/`LoadChunk failed`/`VertexBuffer is empty`**。官方多人 build + 预览上传 ✅。展示版本归并发会话（本批未动 BUILD_VERSION）。
  - 边界：⚠️ **本环境 `-screenshot-frame` 截不到深层帧（AB-220）**——**失败动画的实图未自证**（只能证明「门控正确 + 绘制路径不崩」），**真机观感（动态漫是否够「复杂」、红调是否够重、节奏是否合适）必须 Preview 目视**。手机 FPS（动画有多层循环绘制，需看真机帧率）/ 全 DPR / 用户审美未验收。
  - ⚠️ **避雷 AB-291：给「结算/过渡」类动画加「另一态」时，把「本态起点 + 时长」抽成一个 helper，别在每处 `if state==...` 里各写一套计时**（defeat-transition）：本项目 `StageTransition` 原本只服务 `stagewin`（硬编码读 `stageResult.animAt` + `DURATION`），加失败态时若在每个函数里各判一次，`WindowVisible`/`IsActive`/`Skip`/`Elapsed` 四处的边界会漂移（命中与渲染不同步）。**做法**：抽 `TransitionInfo(game) → startAt, dur`，所有计时相关函数都走它；⚠️ **`Skip` 的去重键要从「单一 animAt」改成「本态起点」**（本项目 `seenAnimAt_` 现在比的是 `startAt`，两态各自独立重置）。验收探针要**断言门控边界**（本项目实测 t=3.9 不可见 / t=4.0 可见 / 4.5 结束）。
  - ⚠️ **避雷 AB-292：过渡动画的「计时基准」要用**规则层的 `elapsed`**（非 playing 仍递增），并在进入该态时**同帧写入**（defeat-transition）**：本项目 `Game._defeat.at = elapsed` 在 gameover 分支里与 `gameState="gameover"` **同帧**设置；动画读 `game.elapsed - defeatAt`。⚠️ **别用渲染层自己累计的 dt**（模态态下渲染可能停帧，累计会与真实时间脱节）；⚠️ 也别复用 `stageResult.animAt`（那是胜利专用，两态并存会串）。
  - ⚠️ **避雷 AB-293：给「失败」类动画定色调时，要和「成功」拉开——本项目失败走红/暗红/铁灰，成功走青/金**（defeat-transition）：两态共用一套 `StageTransition` 骨架，但**配色令牌分开**（`DEFEAT_RED/DEEP/IRON` vs `TIERS` 的青/金）——否则失败动画会和胜利「长得一样」，玩家分不清。⚠️ 复用 `StageTransition` 模块时，`Draw` 开头按 `game.state` **分发到 `Draw`/`DrawDefeat`**，不要在同一个函数里塞两套段落。

- 附记: settings-credit-fix（2026-10-12，**修设置屏「制作鸣谢被挡住」——面板再加高 600→640**；不改展示版本）：
  - 用户上传设置屏截图 + 「制作鸣谢被挡住了」——截图里**「关闭」按钮压在「制作者/导入素材/特别鸣谢」三行文字上**。
  - **真因（两层）**：①**截图是旧预览包**——设置屏「补全音乐/音效开关 + 制作鸣谢」是并发会话提交 `5238492` 才加的，而截图里面板仍是**旧布局**（`y=300, h=360`，关闭按钮 y=592），鸣谢文字被关闭按钮压住。②**即便在 `5238492` 之后**（面板 180/600、关闭按钮 y=716），关闭按钮顶边距鸣谢末行（652）**仅 46px**——真机字体/缩放差异下仍有压字风险（AB-259 同族：容器加高不足）。
  - **修法（`ui/Settings.lua` 一处）**：`PANEL_H` **600→640** → 关闭按钮下移到 y=756，距鸣谢末行 **104px**（探针实测 `gap=104`），稳妥。
  - 验证：**几何断言探针** `probe_setgeo`——鸣谢三行 y=604/628/652 处 `Settings.HitTest` 全部 **`nil`**（不被按钮命中）、关闭按钮中心 y=780 **`hit=close`**、关闭按钮上方空隙 y=746 **`hit=nil`**（`gap=104`）。官方多人 build + 预览上传 ✅（首次 `PLATFORM_OPERATION_FORBIDDEN` 属平台临时限制，重试成功——不绕过）。展示版本归并发会话（本批未动 BUILD_VERSION）。
  - 边界：⚠️ **本环境 `-screenshot-frame` 截不到深层帧（AB-220）**——设置屏真渲染截图未生成，**实图未自证**；但几何断言（`HitTest` 逐行验）已证明「鸣谢行不被关闭按钮命中」，**真机观感需 Preview 目视**。手机 FPS / 全 DPR / 用户审美未验收。
  - ⚠️ **避雷 AB-289：用户报「某处被挡住了」时，先量「遮挡物与被挡物的实际间距」，再判断是**布局 bug**还是**旧包**——两者都要查**（settings-credit-fix）：本项目用户截图显示关闭按钮压住鸣谢，但**工作区代码里那个布局已被并发会话改成「面板加高 + 关闭下移」**（只是**尚未提交进预览包**），截图是旧包；同时**新布局的间距也偏紧**（46px），真机可能仍压。**做法**：①先按截图**量出遮挡物与被挡物的设计 y 区间**，与当前代码复算对照——若不符 = 旧包（让用户重开预览即可）；②**即便当前代码「看起来没重叠」，也要把间距加大到有明显余量**（本项目 46→104px），因为真机字体/缩放会吃掉余量（AB-259 同族：**容器宁高勿矮**）；③验证用**几何断言探针**（逐行 `HitTest` 断言被挡区域 `nil`），比截图可靠（本环境截图不可靠，AB-220）。
  - ⚠️ **避雷 AB-290：跨会话改动「在途未提交」时，先 `git log <file>` 看清哪些已提交、哪些只在工作区**（settings-credit-fix）：本项目设置屏的「鸣谢 + ToggleRow + 面板加高」由**并发会话**提交（`5238492`），而我看到的 `git diff` 只剩自己那一行——**用 `git log -- <file>` + `git show HEAD:<file> | grep <关键符号>` 确认「已提交内容」，别把「工作区有 diff」误当成「这些改动都是我加的/都没提交」**。

- 附记: endpage-layout（2026-10-12，**失败/胜利结算页重排：窗口垂直居中 + 广告按钮降级为次级**；不改展示版本）：
  - 用户「不改了你理解错了，调整失败和胜利界面，浪费Ui空间且广告太过密集」（附失败页截图）——**先说清「理解错了」**：用户前一句「横向怎么说」被**误解成**要改 logo 横竖构图，我据此出了 4 张横版 logo 草案（**已全部删除，未进包**）。用户随即澄清真正要改的是**结算界面**。
  - **失败页两个真问题（截图实锤）**：①🔴 **浪费 UI 空间**——窗口 `winY=200, winH=520`（200..720）**只占上半屏**，下方 720..960 一大片空白（可视区 92..960，窗口上方留 108、下方留 240，严重偏上）。②🔴 **广告太过密集**——「看广告复活」（**整行宽实心绿块**）+「看广告 双倍零件」（**半宽实心绿描边**）两块绿叠在一起，加「再来一局」实心青 + 「回主菜单」共 4 个按钮挤在 496..664，**视觉上 3 个实心/高亮块抢焦点**。
  - **修法（`Scene3DBackend.lua` 两处布局函数 + 两处 Draw，零新增顶层 local）**：
    - **窗口垂直居中**：两页统一 `winY=216, winH=620`（216..836，上下各留白 **124**）——填满可视区、不再偏上。
    - **按钮重排（两页同语言）**：**主 CTA 置顶整行宽**（失败页「再来一局」/ 胜利页「下一关」，**唯一实心青块** = 视觉焦点）；**两个广告按钮降为「次级描边」**——底改 `C.card`（暗）+ 描边 `C.ad`（绿），**不再实心绿块**（绿只留描边与文字）；回主菜单/再战本关并列底行次级。按钮行高 48→**56**、间距 12→**14**。
    - **失败页按钮新序**：restart（整行宽主 CTA，y=560）→ revive + double（并列，y=630）→ menu（y=700）。**胜利页新序**：next（整行宽主 CTA，y=560）→ retry + menu（并列，y=630）。
  - **命中同源**：`GetGameOverButtonLayout`/`GetStageWinButtonLayout` 是绘制与 `Backend.HitTestGameOverButton`/`HitTestStageWinButton` 的**共同来源**，改一处两处同步；`client_main` 零几何常量。
  - 验证：LSP workspace **29 文件 0 Error**（1334 诊断）；**几何命中探针** `probe_endgeom`/`probe_endgeom2`——失败页 `restart@(270,588)=restart`、`revive@(155,658)=revive`、`double@(486,658)=double`、`menu@(270,724)=menu`、**旧位置 `oldRevive@(270,496)=nil`**（证明确实下移）、列间隙 `gap@(270,658)=nil`；布局复算：窗口 216..836 上下各留 124、失败页按钮 560..748（下方留 88）、胜利页按钮 560..686。官方多人 build + 预览上传 ✅。展示版本归并发会话（本批未动 BUILD_VERSION）。
  - **顺带加的调试接口（`Game.lua`，挂 `Game.` 表、零新增顶层 local）**：`Game.DebugForceGameOver()`（把 baseHp 打到 1，走真实失败结算路径）+ `Game.DebugForceStageWin()`（复用真实 `ComputeStageResult` 构造 stagewin）——供探针在**不真打一局**的前提下进结算态截图/验几何（本项目结算态难以自然触发）。⚠️ 该两函数**已被并发会话的提交带入**（`Game.lua` 工作区无 diff）。
  - 边界：⚠️ **本环境 `-screenshot-frame=N` 截不到深层帧（AB-220 复现）**——失败页探针跑到 gameover 态（日志 `forceGameOver ok=true`）但截图**始终停在早期 playing 帧**（帧 140/300 都是开局画面）。故**结算页的实图未自证**，只证明「无渲染错误 + 命中几何正确 + 布局数值正确」，**真机观感（窗口居中、广告不再密集）需 Preview 目视**。手机 FPS / 全 DPR / 用户审美未验收。
  - ⚠️ **避雷 AB-286：用户一句含糊的追问（如「横向怎么说」）可能是**要澄清**而不是**要动手**——先确认指代对象，别据此改一版（endpage-layout，用户「不改了你理解错了」）**：用户先问「横向怎么说」（承接上一轮 logo 横竖构图的话题），我**默认他在催 logo 改横向**并出了 4 张横版草案；用户立刻澄清「不改了，你理解错了」——真正要改的是**失败/胜利界面**。**做法**：①含糊追问先回一句「你指的是 X 还是 Y？」（本项目该问「你指的是 logo 还是结算页？」），**别先出一版**；②用户说「理解错了」时**先停手上正在做的事**（我及时删了 4 张草案），别把错误方向的产出继续做完。⚠️ 同族：v0.13.6/v0.13.7 的「菜单里同名入口有两处，先确认指哪一个」。
  - ⚠️ **避雷 AB-287：结算/弹窗类界面「窗口只占上半屏」是常见的空间浪费——窗口要在可视区**垂直居中**，不是从顶往下排**（endpage-layout，用户「浪费Ui空间」）：本项目失败页窗口 `200..720`（可视区 92..960）→ 上方留 108、下方留 240，**明显偏上、下方一大片空白**。**做法**：`winY = contentTop + (viewH - winH) * 0.5`（本项目 `92 + (868-620)/2 = 216`）；⚠️ 窗口高度要**按内容反推**（内容 + 按钮 + 上下内边距），别沿用旧值——旧 winH 与旧按钮 y 是一起调的，改一个必须改另一个。
  - ⚠️ **避雷 AB-288：「广告太过密集」= 多个广告按钮都做成**实心高亮块**在视觉上抢焦点——降级为「次级描边」+ 只留**一个**主 CTA（endpage-layout，用户「广告太过密集」）：本项目结算页原有两个广告按钮（复活=**整行宽实心绿**、双倍=半宽绿描边）+ 主 CTA 实心青，**三个高亮块**挤在一起。**做法**：①**主 CTA 只留一个**（整行宽、实心语义色，置顶当视觉焦点）；②**广告按钮改次级**——底用暗色（`C.card`）、只保留**绿色描边 + 绿色文字**（绿 = 看广告语义仍在，但不再是大色块）；③广告按钮**并列一行**而不是各占一整行。**判据**：一屏内「实心/高亮块」≤2 个（1 主 CTA + 最多 1 个次强调），其余全用描边/暗底。

- 附记: wave-speed-ramp（2026-10-12，**每关前四波移速 60%→100% 缓入**；不改展示版本）：
  - 用户「第一波到第四波敌人的移速倍率为60%逐渐加回到100%」——给**每关关内**的头四波加「缓入」：第 1 波 60%、逐波线性加回、第 4 波起 100%（此后完全回到关卡曲线）。
  - **实现（`StageCatalog.lua` 一处，单一来源）**：新增 `StageCatalog.GetWaveSpeedRamp(stageWave)`——`w>=4 → 1.0`，否则 `0.6 + (w-1)*(0.4/3)`（0.6 / 0.7333 / 0.8667 / 1.0）；`GetBaseSpeed` 改为 `原曲线 * ramp`。⚠️ **只乘 `GetBaseSpeed`**——普通波（`GetWaveParams`→`pendingSpawn.speed`）、精英护航（`ReleaseEscortVolley`）、精英/Boss（`SpawnSpecialEnemy`）、Boss 召唤、出怪间隔下界（`CurrentSpawnInterval`）**全部经它**，天然一致；**零新增 `Game.lua` 顶层 local**（AB-166）。
  - 验证：LSP workspace **29 文件 0 Error**（1312 诊断）；规则探针 `probe_wavespeed` **15/15 PASS**（ramp 端点 0.6/1.0、第5+波不变、单调、线性等步长；`GetBaseSpeed` 关1/5/12/15 × 波1-6 共 24 组 = 原曲线×ramp；**实战真实生成敌机 vy 逐波抬升 7.711→11.236→14.065→31.623**，wave1 ≈ 60% 基准）；回归 `probe_wsregress` **ALL PASS**（机型池递进 关1=1/关6=5/关9=8、关1 整关不饱和、血量封顶 1/2/43、MAX_OFFSCREEN=3、真实发射后 state=playing）；真渲染冒烟 `probe_render`（菜单→选关→战斗→发射）`state=playing stage=1 wave=2 enemies=3 launched=true`、零 `overlay stage failed`/`Execute Lua function failed`/`LoadChunk failed`/`VertexBuffer is empty`。官方多人 build + 预览上传 ✅。展示版本归并发会话（本批未动 BUILD_VERSION）。
  - 边界：手机 FPS / 全 DPR / 用户手感未验收；**真机观感（开局缓入是否舒适、第4波切回全速是否有突兀感）需 Preview 目视**。
  - ⚠️ **避雷 AB-283：给「每关前几波」加缓入/缓冲曲线时，乘在**速度的单一来源**（`GetBaseSpeed`）上，不要只改普通波那条路径**（wave-speed-ramp）：本项目敌机速度有 5 条消费路径（普通波 / 精英护航 / 精英+Boss / Boss 召唤 / 出怪间隔下界）——若只在 `GetWaveParams` 或 `pendingSpawn.speed` 乘倍率，**精英波和护航不受影响**（玩家会在第 3 波突然撞到全速精英）。做法：找到所有路径共用的**那个函数**（本项目 `StageCatalog.GetBaseSpeed`）乘一次；⚠️ 副作用是 `CurrentSpawnInterval` 的间隔下界也会跟着变（descent 变小 → 间隔变大，属良性：更慢的敌机本来就需要更长间隔才拉开一格），**改完要核对间隔仍有限、不爆炸**。
  - ⚠️ **避雷 AB-284：「第 N 波」的口径要先定死是**关内波次**还是**累计波号****（wave-speed-ramp）：用户说「第一波到第四波」——本项目每关 10 波、`wave` 是**累计**波号（关2 第1波 = wave 11），而 `stageWave` 是**关内**波次（1..10）。用户要的是「每关开局的缓入」，即 `stageWave` 1..4。**做法**：加「每关前几波」类规则前，先确认 `Game.lua` 里哪个量是关内波次（本项目 `stageWave`）、哪个是累计（`wave`）——用错会让规则只在第 1 关生效。探针要断言「**关 5 / 关 12 的第 1 波同样拿到 60%**」，不能只测关 1。

- 附记: trail-particle-lag-fix（2026-10-12，**修「拖尾滞后明显」**；不改展示版本）：
  - 用户「拖尾滞后明显」——承接 trail-particle-styles（彗星/流光改粒子系）。**滞后 = 尾迹在车尾前方就断了**（贴车那段没有粒子）。
  - **两个真因（都在 `SyncTrailParticles`）**：①🔴 **每帧重走整条轨迹采样**（`for k=1,n` 遍历 `track.points` 的每一段），且对每段都 `acc += len*emit`——同一段被**反复累加** → 粒子暴增（探针实测彗星 287 粒 / 流光 111 粒，远超寿命所需的稳态量）→ 撞槽位上限。②🔴 **提交按 `ipairs` 从头取**（列表里最老的粒子）→ 超预算时被丢掉的是**最新（贴车）那批**，于是「车头段」永远画不出来 = 滞后。
  - **修法**：①只沿「**上一帧发射点 `track.emitX/Y` → 当前车尾 `track.x/y`**」这段**新走过的距离**发射（`dx=hx-ex`），粒子位置取**当前段**（贴车）；`acc` 跨帧保留小数余量，`emitX/Y` 每帧更新。②提交改 **`for i=#list,1,-1`（从列表尾=最新往回取）**，超预算丢**最老的**（尾端），保证贴车段永远在。
  - 验证：`probe_trailpart` ALL PASS（comet **287→43 粒**、dash **111→13**，不再暴增/截断）；稳态实测彗星 **28-32 粒** / 流光 **10-12 粒**（与运动成比例、无截断）；LSP **29 文件 0 Error**；官方多人 build + 预览上传 ✅。展示版本归并发会话（本批未动 BUILD_VERSION）。
  - 边界：手机 FPS / 全 DPR / 用户审美未验收；**真机观感（粒子密度是否合适、是否彻底不滞后）需 Preview 目视**。
  - ⚠️ **避雷 AB-278：粒子/尾迹发射「只算增量距离」，不要每帧重走整条历史轨迹**（trail-particle-lag-fix）：按「每米 N 颗」撒布粒子时，若每帧遍历**整条** `points` 采样并对每段累加 `len*emit`，同一段会被**反复发射**（N 倍过量）→ 撞上限。做法：记录 `track.emitX/emitY`（上一帧发射点），每帧只沿「上一帧点 → 当前点」这段**新距离**发射，`acc` 跨帧保留余量。判据：**稳态粒子数应 ≈ 发射率 × 寿命 × 速度**（本项目彗星 60×0.42×~1.2≈30，实测 28-32 吻合）；若实测远大于估算，就是「重走历史」了。
  - ⚠️ **避雷 AB-279：有「槽位上限」的粒子系统，超预算要丢**最老的**，不能丢最新的**（trail-particle-lag-fix）：提交时 `for _,p in ipairs(list)`（从头=最老）填槽，超上限就丢弃**后面**的（最新的）——而「最新」恰好是**贴发射源（车尾）**那批，于是源头段永远没粒子 = 「拖尾滞后/跟不上」。做法：**从列表尾（最新）往回取** `for i=#list,1,-1`，超预算丢最老的（尾端）。**判据**：任何「跟随移动实体」的粒子/尾迹，**离实体最近的那批必须优先保留**（同 AB-234「锚定贴物体那端」的同一原则）。
- 附记: bgm-playlist（2026-10-11，**BGM 扩到 9 首 + 每态播放列表轮播**；承接 audio-system，不改展示版本）：
  - 用户「音乐太少生成更好的」——**「太少」是关键词**：上一批只有 3 首 BGM（每态 1 首、单曲循环），长时游玩必然重复单调（同用户对「重复/无聊」的低容忍度，见 AB-263/AB-271）。
  - **生成 6 首新曲**（`text_to_music`，全部 8bit+太空+公路风格）：菜单 `bgm_menu_2` Drifting Hangar / `bgm_menu_3` Nebula Docks；战斗 `bgm_battle_2` Hyperdrive Skirmish / `bgm_battle_3` Asteroid Run；首领 `bgm_boss_2` Void Warlord / `bgm_boss_3` Core Meltdown。**每态从 1 首扩到 3 首，BGM 总数 3→9**。生成后**重命名为语义名** + 生成 `.meta`（22hex uuid 全库验重）。
  - **`AudioDirector` 从「单曲循环」改为「每态播放列表轮播」**：①`BGM_PATHS`（key→单路径）→ **`BGM_TRACKS`（key→路径数组）**；②Init 把每态的多首加载成 `state.bgmPlaylist[key] = Sound[]`（缺文件自动剔除）；③新增 `PlaylistTrack(key, idx)`（下标环绕取曲）+ `StartTrack(key, idx)`（在另一通道播指定曲、记录 `bgmTrackIdx`/`bgmTrackLen`，交叉淡入）；`SwitchBgm` 改调 `StartTrack(key, 1)`（换主题从该态第一首开始）；④`UpdateBgm` 加**曲终轮播**：`bgmTime += dt`，`>= bgmTrackLen` 就 `StartTrack(key, bgmTrackIdx+1)`——**曲目长度取 `sound:GetLength()`，未知（≤1s）时保持单曲循环不轮播**（防探针/异常资源死循环）。⑤新增只读诊断 `DebugTrackCount(key)`。
  - 验证：LSP workspace **29 文件 0 Error**（1311 诊断）；**纯模块探针 `probe_audio2` 14/14 PASS**（`bgm=9` 全加载 / 每态 playlist=3 / BGM 状态机 menu→battle→boss→battle→menu 全对 / **曲终轮播稳定**（喂 250 秒仍停在 menu 不崩）/ 事件突发+UI 音不崩 / Shutdown 清空播放列表）；**真渲染集成探针 `probe_audiorender`** 跑完一局 `ready/menu/battle=true`、`tracks=3/3/3`，零 LoadChunk/overlay/Lua/空顶点错误；构建后 **dist 清单含全部 9 首 BGM**。官方多人 build + 预览上传 ✅。展示版本归并发会话（本批未动 BUILD_VERSION）。
  - 顺手清理：6 个**孤儿 `.meta`**（`text_to_music` 会为每次生成的随机名 ogg 也生成 meta，重命名时漏删）→ 删掉，`assets/audio/` 现 9 ogg + 9 meta 一一对应。
  - ⚠️ **避雷 AB-273：`text_to_music`/`text_to_sound_effect` 生成的随机名文件**，重命名成语义名后**必须连 `.meta` 一起处理**——生成器会为**随机名 ogg** 也产出 `.meta`（`music_<ts>.ogg.meta`），重命名 ogg 时这些 meta **不会跟着改名** → 变成孤儿（无同名 ogg）。做法：重命名后 `for m in assets/audio/*.meta; do [ -f "${m%.meta}" ] || rm "$m"; done` 扫一遍，再确认 `ls *.ogg | wc -l` == `ls *.ogg.meta | wc -l`。
  - ⚠️ **避雷 AB-272：给「单曲循环」的 BGM 系统加「更多曲目」时，要的是「播放列表轮播」不是「多首随机播」**（bgm-playlist，2026-10-11）：用户说「音乐太少」——直接解法是**每态一个播放列表、曲终自动切下一首**（本项目 3 首/态），而不是随机抽一首（随机会出现「刚放完又抽到同一首」）。实现要点：①曲目长度用 `sound:GetLength()` 取**真实时长**驱动轮播（不是写死秒数）；②长度取不到（异常/静音资源）时**回退单曲循环**，别让 `bgmTime` 无限涨却不切换（也防探针里的 0 长度资源触发死循环）；③切主题与曲终轮播**复用同一个 `StartTrack`**（都在另一通道交叉淡入，旧通道淡出）。⚠️ 本项目**本环境无 `/dev/snd`**，轮播只能由**纯模块探针喂长 dt**证明「喂 250 秒不崩、键不变」，**实际听感（曲目衔接是否顺、风格是否统一）必须 Preview 真机**。

- 附记: stage-variety-ramp（2026-10-11，**机型种类随关卡号递进**——关卡越高越丰富多元；不改展示版本）：
  - 用户「在当前的标准下十关卡随着数字提高丰富多元」——承接上一批「每关开局机型雷同」，这次要求**关卡之间要递进**（越高越丰富）。
  - **真因（探针实锤）**：上一批 v0.13.58 把解锁进度改成 `(关卡-1) + 关内波次`，**第 1 关第 10 波 progress=10 就已解锁全部 8 种机型**——玩家**一关之内就看遍所有机型**，第 2 关起开局虽不再只有 scout，但**后续关卡没有新东西**（都饱和到 8 种）。「丰富」是有了，「多元/递进」没有。
  - **修法（`Game.lua` 一处）**：`GetAvailableTypes` 的解锁进度**放慢关内解锁**——`(关卡-1) + floor((关内波次-1)/3) + 1`（每 3 波才 +1 档，而非每波 +1）。效果：**机型池主要由关卡号驱动**——关1 开局 1 种 → 关2 开局 2 种 → … → **关9 开局即全 8 种**；关1 整关最多 4 种（不再一关看遍），且每关关内仍随波次小幅放宽。另加只读诊断 `Game.DebugAvailableTypes(wave)`（**表字段赋值，不占顶层 local 槽位**，AB-166）。
  - 验证：LSP workspace **29 文件 0 Error**（1306 诊断）；规则探针 `probe_variety2` **7/7 PASS**（关1 开局池=1 种 / 开局池随关卡号单调不减 / 关6>关1 有递进 / 关9+ 开局=8 种全机型 / 关1 整关<8 种不再一关看遍 / 每关关内最大池≥开局池）；回归 `probe_variety` **4/4 PASS**（关1 恒 scout、关5 4 种、关10 7 种）；真渲染冒烟 `probe_render` 零 `overlay stage failed`/`Execute Lua function failed`/`LoadChunk failed`/`VertexBuffer is empty`（日志确认关1 波1 出 `scout`）。官方多人 build + 预览上传 ✅。展示版本归并发会话（本批未动 BUILD_VERSION）。
  - 边界：手机 FPS / 全 DPR / 用户审美未验收；**真机观感（高关开局是否确实更丰富）需 Preview 目视**。
  - ⚠️ **避雷 AB-271：「关卡之间要有递进」要求「解锁曲线随关卡号拉开」，不能只修「每关开局一样」（stage-variety-ramp，承接 AB-263）**：v0.13.58 修了「每关开局都只有 scout」（解锁进度不再每关归零），但用的是 `(关卡-1)+关内波次` —— **关内每波 +1 档，第 1 关第 10 波就把 8 种全解锁了**，于是「一关看遍、后续关卡没有新东西」。用户接着提「关卡越高越丰富多元」正是在说这一层。**判据**：让内容「随关卡递进」，解锁曲线的**关内斜率要远小于关卡斜率**（本项目改成「关内每 3 波 +1 档」，让池子主要由关卡号决定）；**验收探针要同时断言「关1 整关不饱和」+「高关开局饱和」**，只测「开局不再雷同」会漏掉「一关看遍」。

- 附记: trail-particle-styles（2026-10-11，**彗星/流光改成粒子系拖尾**；不改展示版本）：
  - 用户「3d拖尾粒子代码lua 千万千万不要太便宜。…经典尾焰是好看的。霓虹和余烬还有双轨也可以算好看的，但是这个彗星一点也不好看啊。…这个流光，流光其实和一开始的普通的也没什么区别。把它们做成粒子效果类的吧。」——**保留**经典/霓虹/余烬/双轨，**重做**彗星（丑）+ 流光（和普通没区别），且**改成粒子系**。
  - **真因**：彗星/流光是**同一条光带的数值微调**（彗星=taper/bulge 鼓包、流光=flicker 高频明暗）——形态上仍是「一条光带」，所以「彗星丑」「流光=普通」。**修法=换通道**：从**三角带光带**换成 **billboard 粒子**（真粒子系，形态上与光带完全不同）。
  - **数据层（`MetaCatalog`）**：给 `TrailStyleParams` 加粒子轴（**全部 `|nil`**——只有粒子样式有，否则 LSP `assign-type-mismatch` 报「missing member emit」）：`particle/emit/emitSpread/pSize/pGrow/pJitter/pSpin/pDrift/pLife`。`comet`：emit60/暖金密集尘/头端灼核；`dash`：emit22/大颗离散青白光片/高速自旋 420°/s。`TRAILS.desc` 同步改写。
  - **渲染（`Renderer3D.SyncTrailParticles`）**：沿**已有轨迹采样**（`trailSamples_`）按**弧长**撒布粒子（每米 N 颗 → 帧率/速度无关；`track.emitAcc/emitSeq` 跨帧累加）。发射点=段内插值 + 法向散布/抖动；**确定性 hash**（`sin(n*12.9898+78.233)*43758.5453` 取小数）**非 math.random**（重开/暂停不跳变）。粒子沿寿命**膨胀 + 横向漂移 + 末段收缩**消散。每样式×每弹种一个 BillboardSet（各绑**专属烘焙纹理**——DiffAlpha 不读顶点 rgb），`TRAIL_PARTICLE_SLOTS=320`。新增只读诊断 `DebugTrailParticleCount`。
  - **纹理（`CreateTrailCometTexture`/`CreateTrailDashTexture`）**：程序化生成，**热核 + 外辉光两级**（避免「一个糊圆点」的廉价感，用户「千万不要太便宜」）。彗星=暖金软圆（灰阶→多弹种通用），流光=拉长椭圆光片。
  - **互斥（关键）**：`particle` 样式下 `SyncVehicleTrails` 必须**清空并停用光带节点**——`tracks` 置空 + `active=false` + `or particleStyle` 进入清理分支；`SyncTrailParticles` 放在 `SyncVehicleTrails` **之前**（粒子先关光带）。
  - **2D 预览（`MetaUI.DrawTrailParticlePreview`）**：与 3D 同参数、确定性散布（相位滚动让光尘「往后飘」）+ 头端灼核。
  - 验证：**`probe_trailpart` ALL PASS**（走真实 `client_main` 渲染路径：comet 287 粒/0 顶点、dash 111/0、光带样式 0 粒 → 互斥成立）；`probe_trailwidth` ALL PASS 24 组（comet 98.3% 车体半宽 / dash 92.7%）；`probe_trailstyles`/`probe_trailhead`（worst 0.0570）ALL PASS；商店拖尾页逐样式 0 overlay/Lua 错误，**像素取证 classic↔comet 4649px、classic↔dash 4511px、comet↔dash 2502px**（预览确实画了且不同）；LSP **29 文件 0 Error**；官方多人 build + 预览上传 ✅。展示版本归并发会话（本批未动 BUILD_VERSION）。
  - 边界：手机 FPS（320 槽×8 set 上限）/ 全 DPR / 用户审美未验收；**真机观感（彗星粒子密度、流光光片大小与自旋、是否「不便宜」）需 Preview 目视**。
- 附记: audio-system（2026-10-11，**从 0 到 1 建立音频系统：20 音效 + 3 首 8bit 太空公路 BGM + 状态机切换**；不改展示版本）：
  - 用户「希望强化。音乐音效表现力」+「bgm需要是8bit+太空+公路风格」——**本项目此前零音频**（无任何音频资源、无 SoundSource 调用），本批从 0 到 1 建整套音频层。
  - **素材（走 `text_to_sound_effect` / `text_to_music` 生成）**：**20 个音效 mp3**（launch/brick_hit/brick_break/enemy_clear/base_hit/explode/crit/freeze/pierce/levelup/ui_click/ui_confirm/coin/game_over/boss/enchant/heal/split/wave/shield，落 `assets/audio/sfx/`）+ **3 首 BGM ogg**（`bgm_menu` 星港主题 / `bgm_battle` 战斗公路主题 / `bgm_boss` 首领主题，落 `assets/audio/`）。每个文件配 `.meta`（22hex uuid，全库验重无重复）。BGM 由 `text_to_music` 生成时返回的随机文件名（`music_<ts>.ogg`）**重命名为语义名**（`bgm_menu/battle/boss.ogg`）。
  - **新模块 `scripts/AudioDirector.lua`（核心）**：①`Init(scene)` 在场景下建 **8 个 SoundSource 播放池**（音效轮转复用）+ **2 条 BGM 通道**（交叉淡入淡出）；②`Update(dt, snapshot, events)` **消费与 Presentation 同一份领域事件**（编排层把 `Game.DrainEvents()` 的结果同时传给两者，只读）→ 按事件类型播对应音效（含 `brick_hit` 的 `destroyed` 分流：击碎用 break 音、未碎用 hit 音，**带节流** 0.03/0.045s 防刷屏；`item_used` 按 `key` 分炸弹/冰冻/护盾）；③**BGM 状态机**：`menu→menu 主题`、`playing/levelup/paused/stagewin/gameover→battle 主题`、**首领在场时→boss 主题**（`state.bossAlive` 由 `wave_started.isBoss`/`boss_defeated` 事件跟踪，不依赖快照字段）；④**交叉淡入淡出**：切主题时新通道淡入、旧通道淡出（`UpdateBgm` 按 dt 线性逼近目标增益）。⑤音效 pitch 随机 ±6~18% 防重复听感单调（`Play(sound, sound:GetFrequency()*pitch, gain)`，⚠️ frequency 是**绝对 Hz 不是倍率**）。
  - **接线（`Scene3DBackend.lua`）**：`uiFx.audio = require "AudioDirector"`（挂在 uiFx 表，**不加顶层 local**——该文件顶层 local 已满 200，AB-265）；`Backend.Init` 里 `pcall(function() uiFx.audio.Init(scene_) end)`；`Backend.Shutdown` 里 `uiFx.audio.Shutdown()`；新增 `Backend.TickAudio(dt, snapshot, events)` + `Backend.PlayUiSfx(kind)`（挂 Backend 表）。**编排层 `client_main.HandleUpdate`**：把 `Game.DrainEvents()` 结果存进 `frameEvents`，先给 `Presentation.Update` 再给 `RenderBackend.TickAudio`（**同一份事件只 Drain 一次**，两个消费者只读）；`HandleMetaAction` 开头按 action 类型播 UI 音（购买/解锁/领取→confirm 音，其余→click 音）。
  - **可选资源契约**：所有音频加载用 `pcall(cache:GetResource("Sound", path))`，缺文件返回 `false` 只静默跳过——**绝不进 Init 成功条件**（同 v0.11.4 手势图 / v0.12.8 字标契约）。
  - 验证：LSP workspace **30 文件 0 Error**（1310 诊断）；**纯模块探针 `probe_audio2` 10/10 PASS**（加载 `sfx=20/20`、BGM 状态机 menu→battle→boss→battle→menu 全对、事件突发+UI 音效不崩、Shutdown 幂等）；**真渲染集成探针 `probe_audiorender`**（走 `client_main` 真实路径跑完一局：菜单→选关→战斗→发射→wave1 scout→wave2 dart→附魔卡）实测 `ready=true menu=true battle=true final=battle`，**零** `LoadChunk failed`/`overlay stage failed`/`Execute Lua function failed`/`VertexBuffer is empty`。构建后 **dist 清单含全部 23 个音频资源**（20 mp3 + 3 ogg）。官方多人 build + 预览上传 ✅。展示版本归并发会话（本批未动 BUILD_VERSION）。
  - ⚠️ **并发会话造成的 broken commit 已修复**：音频集成代码（Scene3DBackend/client_main 的 hunk）被并发会话的 `git add -A` 扫进了 commit `9e50861`，但 **`AudioDirector.lua` 模块与 `assets/audio/` 资源当时未提交** → HEAD 引用不存在的模块。本批补提交 `scripts/AudioDirector.lua`（+.meta）+ 48 个音频文件（20 mp3×2 + 3 ogg×2 + meta）修复。另发现 `ui/StageTransition.lua`（并发会话的过渡模块）**同样被 HEAD 引用却未提交**（`?? scripts/ui/StageTransition.lua`）——**未代其提交**（属并发会话），仅在探针工程临时补齐以完成验证。
  - 边界：⚠️ **本环境无 `/dev/snd`（无音频设备）**——探针只能验证「资源加载 + 状态机 + 事件通路 + 不崩」，**实际发声（音量/音色/混音平衡/BGM 是否真的 8bit+太空+公路风格）必须 Preview 真机目视**。手机 FPS / 全 DPR / 用户审美未验收。
  - ⚠️ **避雷 AB-267：音频「从 0 到 1」的落地顺序——先纯模块探针证明数据通路，再真渲染集成探针证明不打断游戏**（audio-system，2026-10-11）：本项目此前零音频。做法：①先写**独立模块探针**（只 require AudioDirector + 自建 `Scene()`，不跑游戏 3D）——**规避并发会话在途的 3D 半成品**（本批真渲染首跑就撞上并发会话未提交的 `Renderer3D:1404 trailParticleSets_` 错误，纯模块探针完全不受影响），且能精确断言「加载 N/N、BGM 键随状态切换、Shutdown 幂等」；②再写真渲染集成探针走 `client_main` 真实路径，证明「不打断 2D/3D/快照」。**两个探针各证明一半**，缺一不可。⚠️ 音效播放要用**播放池轮转**（`pool[cursor]; cursor = cursor%#pool+1`），不要每帧新建 SoundSource；BGM 切换用**两条通道交叉淡入淡出**，不要 `Stop` 后 `Play`（会断音）。
  - ⚠️ **避雷 AB-268：给「已满 200 顶层 local」的后端加功能，一律挂表 + 新模块**（audio-system，2026-10-11，承接 AB-265）：`Scene3DBackend.lua` 顶层 local 已满 200——本批加音频时，**所有新增都是**「`uiFx.audio`（挂 uiFx 表）+ `Backend.TickAudio/PlayUiSfx`（挂 Backend 表）+ 一个 `require`」，**零新增顶层 local**。这是该文件唯一安全的加法模式。⚠️ 用 `git diff | grep "^+local "` 自检（应为空）。

- 附记: cta-stretch-cap-fix（2026-10-12，**修「谁要你缩小了」——stretchX 上限误设 1.0 把 CTA 压回自然宽度**；承接 cta-user-asset，不改展示版本）：
  - 用户发来**主菜单实机截图** + 「**谁要你缩小了**」——截图里「开始战斗」金属字**明显偏小**（像素取证：金属核心仅占按钮宽 **12.6%**，而参考图应约 **57%**）。
  - **真因（上批自己引入）**：`cta-user-asset` 那批我误把 `stretchX` 上限写成 **`math.min(1.0, ...)`**——`FitWidth` 算出 **1.28** 被 `min(1.0,…)` 直接压回 **1.0**，字只剩**自然宽度**（新素材 aspect 3.18 的裸宽 213 设计像素，按钮 456 宽 → 仅 47%），看起来就是「被缩小」。⚠️ **上一批我「为保持自然比例不拉伸」的判断是错的**——用户要的是「铺开」，不是「原图比例」。
  - **修法（一处）**：`sx = math.min(1.9, ArtText.FitWidth("startbattle", cta.w * 0.66, s))`——上限 `1.0→1.9`、目标宽 `0.60→0.66`（与历史 `cta-stretch` 一致）。实测 `sx=1.41`（未触上限），字宽 **213→301 设计像素**。
  - 验证：真渲染探针 `probe_ctastretch`（停菜单）——`[ArtText] loaded=8/8`、零 `overlay stage failed`/`Execute Lua function failed`/`LoadChunk failed`/`VertexBuffer is empty`；**像素取证**：金属核心宽 **12.6% → 60.2% 按钮宽**（实测 309px / 按钮 513px），与参考图 57% 吻合；实图确认字横向铺开、青晕完整。官方多人 build + 预览上传 ✅。展示版本归并发会话（本批未动 BUILD_VERSION）。
  - 边界：手机 FPS / 全 DPR / 用户审美未验收；**真机观感（字大小是否合适）需 Preview 目视**。
  - ⚠️ **避雷 AB-282：给「用户成品素材」算横向拉伸时，`stretchX` 上限别写成 1.0——那等于「禁用拉伸」，会把字压回自然宽度（cta-stretch-cap-fix，用户「谁要你缩小了」）**：`cta-user-asset` 我误以为「保持原图自然比例」= 不拉伸，把上限设成 `math.min(1.0, FitWidth(...))` → `FitWidth` 算出的 1.28 被压回 1.0 → 字只有自然宽度（占按钮 47%，实测金属核心更只有 12.6%）→ 用户读成「被缩小」。**判据**：「不压缩素材」指的是**别改素材像素**（别灰度/量化），**不是**「运行时别缩放」——**运行时该铺满还是要铺满**（`FitHeight` 定高 + `stretchX` 铺宽）。**做法**：①横向拉伸上限给足（本项目 1.9），别用 1.0「保比例」；②改素材后**必须真渲染 + 像素取证**「字宽 / 按钮宽」占比（本项目目标 ~57–66%），**别只看「渲染无报错」**（同 AB-277/280 的「量→算→验」纪律）。⚠️ 素材 aspect 越大（本项目新素材 3.18 vs 旧 2.14），`FitWidth` 算出的 `sx` 越小（1.41 vs 1.87）——**换素材后要重算，别沿用旧上限**。

- 附记: cta-user-asset（2026-10-12，**直接用用户提供的「开始战斗」成品图**；承接 scale-fix2，不改展示版本）：
  - 用户直接发来一张**带青晕的斜体金属字**成品 PNG（1248×832，可见内容 aspect **3.18**），并说「**你直接把这个加上去得了，也不用特意压缩**」——**明确指示：不要后处理、直接采用**。
  - **做法**：①只**裁掉透明留白**（`alpha>128` bbox → 1216×382）+ 缩到母版高 **128**（→ **407×128**，保留原图，**不做灰度/量化/两色**）；②覆盖 `ui_tt_startbattle.png`（沿用旧 `.meta` uuid + `.png.xml` 跳过压缩）；③CTA 参数改 **`FitHeight 67` + `stretchX 1.0`**——**保持原图自然比例，不再横向拉伸**（此前 scale-fix2 的 `sx~1.87` 是针对旧窄素材 aspect 2.14 补宽的，新素材 aspect 3.18 本身就够宽，再拉会扁）。
  - 验证：真渲染探针 `probe_ctastretch`——`[ArtText] loaded=8/8`、`has_startbattle=true w=407 h=128`、零 `overlay stage failed`/`Execute Lua function failed`/`LoadChunk failed`/`VertexBuffer is empty`；实图确认带青晕斜体金属字、自然比例。官方多人 build + 预览上传 ✅。展示版本归并发会话（本批未动 BUILD_VERSION）。
  - 边界：手机 FPS / 全 DPR / 用户审美未验收；**真机观感（青晕强度、字大小）需 Preview 目视**。
  - ⚠️ **避雷 AB-281：用户直接给成品素材说「直接加上去/不用压缩」时，只做「裁透明留白 + 缩到母版尺寸」，别自作主张后处理**（cta-user-asset，承接 AB-254「别过度处理」）：本项目前几轮我按 0718 管线做了**灰度化/两色量化/横向拉伸**，用户本轮直接发成品图并说「不用特意压缩」——**用户的成品已经是想要的样子**，再灰度/量化/拉伸都会改变它。**做法**：①「直接加上去」= **只裁 bbox 留白 + 等比缩到母版尺寸**（这两步是必须的，否则 `FitHeight` 按整图算会让字变小 / 文件过大）；②**不做**调色/量化/拉伸/加特效；③改素材后**必须同步重算 CTA 的 `stretchX`**——新素材 aspect 变了，旧拉伸倍率会把它拉扁（本项目新素材 aspect 3.18 vs 旧 2.14，`sx` 从 1.87 降到 1.0）。⚠️ 「不用压缩」也指**别压成两色/低色数**——保留原图色阶（AB-254：压两色会丢明暗层次）。
  - ⚠️ **用户给的成品图要放 assets 并配 `.meta`**（本项目沿用旧 `ui_tt_startbattle.png.meta` uuid + `.png.xml`）——**别只留在 `_uploads/`**（那会被自动清理、也不打包）。

- 附记: cta-startbattle-scale-fix2（2026-10-12，CTA「开始战斗」**放大到参考图占比**；承接 scale-fix，不改展示版本）：
  - 用户又上传截图（无文字，仅图）——CTA「开始战斗」**明显偏小**：上一版 scale-fix 把 `FitHeight 64 + stretchX 上限 1.10` 收得太狠，字只占按钮一小块（用户「素材缩放有误」的第二轮，实为**我上版改过头**）。
  - **精确定标（本轮方法论）**：从参考图**逐行/逐列量**金属字的 bbox——**字宽占按钮 57%、字高占 80%、字框 aspect≈4.0**（不是先前目测的 2.5）。素材 `sb_a` aspect **2.14** → 要补到参考 aspect 4.0 需**横向拉伸 ~1.87×**。**修法**：`FitHeight 64→67`、`stretchX` 目标宽 `0.60→0.57`（上限 `1.10→1.90`）。
  - **验证**：真渲染探针 `probe_ctastretch`——`[ArtText] loaded=8/8`、零 `overlay stage failed`/`Execute Lua function failed`/`LoadChunk failed`/`VertexBuffer is empty`；三图并排（参考/用户上版/本版）确认字大小与参考图一致。官方多人 build + 预览上传 ✅。展示版本归并发会话（本批未动 BUILD_VERSION）。
  - 边界：手机 FPS / 全 DPR / 用户审美未验收；**真机观感（字够不够大、斜体倾斜是否合适）需 Preview 目视**。
  - ⚠️ **避雷 AB-277：调「素材占比」时用「逐行/逐列数像素」量出**目标比例**，别靠目测猜参数——目测误差可达 2×**（cta-startbattle-scale-fix2）：本项目我先目测「参考字 aspect ≈2.5」，据此设 `stretchX≈1.22`，结果字偏小；**逐行/逐列数像素**实测才发现真实是 **aspect≈4.0、占按钮宽 57%/高 80%**，需 `stretchX≈1.87`。**做法**：①在参考图上用「某行/列内亮像素数超阈值」定位按钮与字的精确 bbox（`rowsum>阈值` 找行、`colsum>阈值` 找列），算出「字/按钮」的宽高占比；②用「素材 aspect vs 目标 aspect」反推所需 `stretchX`（`sx = 目标aspect / 素材aspect`）；③离线 PIL 合成候选变体比每次真渲染快。⚠️ **一次调不对不要紧，但要「量→算→验」闭环**，别连续靠目测瞎试（本项目为此多花了好几轮）。
  - ⚠️ **避雷 AB-280：「改过头」和「没改到」是同一个坑的两端——改完必须跟参考图并排复核**（cta-startbattle-scale-fix2）：scale-fix 把字收小（修「偏散」），scale-fix2 又要放大（修「偏小」）——**两轮方向相反**，根因是**每轮只改参数、没跟参考图并排复核最终占比**。**做法**：任何「调比例/大小」的改动，交付前**必做「参考图 vs 我的渲染」按同基准归一化并排**（本项目 `/workspace/screenshots/cta_*cmp.png`），确认占比一致再收工；**别只凭「这版看着差不多」**（同 AB-216/220 的「渲染无报错 ≠ 观感对」纪律）。

- 附记: cta-startbattle-scale-fix（2026-10-12，修「开始战斗」**素材缩放有误**——换回无青晕紧凑金属字；不改展示版本）：
  - 用户上传截图 + 「素材缩放有误」——CTA「开始战斗」看起来**偏散/偏扁**。**真因（并排比对定位）**：上一批 `cta-startbattle-regen` 我选的是**带青色光晕**的 `sb_b` 草案——它 **aspect 3.18（比参考图 2.55 宽）、4 字之间空隙大、且带一圈青晕**，青晕让字在视觉上「膨胀发虚」；而用户参考图是**无光晕的紧凑银白金属字**（字宽笔画厚、字距紧）。「素材缩放有误」的语义 = **选的素材本身形态不对**（不是运行时 scale 算错）。
  - **修法**：①素材换回 **`sb_a`（无青晕版，aspect 2.14）** → 覆盖 `ui_tt_startbattle.png`（沿用旧 `.meta` uuid + `.png.xml`）；②CTA 参数收紧——`FitHeight 60→64`（更饱满）、`stretchX` 上限 **1.7→1.10**、目标宽 `0.66→0.60`（对齐参考图 aspect≈2.4，不拉扁）。
  - **定位方法（本轮关键）**：把「参考图 CTA」「用户截图 CTA」「我的渲染 CTA」**三张按按钮宽度归一化后并排**（`/workspace/screenshots/cta_*cmp.png`），一眼看出「参考=紧凑实心金属、我的=宽而带青晕」。再**离线 PIL 合成多个 `stretchX`/`FitHeight` 变体**逐一看哪个 aspect 最接近参考（避免每次真渲染）。⚠️ **本环境 Read 工具读 `/home/Maker/*.png` 常失败**——**裁出的对比图要存到 `/workspace/screenshots/` 再读**（`/workspace` 下可读）。
  - 验证：LSP workspace **29 文件 0 Error**；真渲染探针 `probe_ctastretch`——`[ArtText] loaded=8/8`、`has_startbattle=true w=94 h=44`（新素材尺寸）、零 `overlay stage failed`/`Execute Lua function failed`/`LoadChunk failed`/`VertexBuffer is empty`；三图并排确认修复后与参考图风格一致（紧凑银白金属字、无青晕、比例自然）。官方多人 build + 预览上传 ✅。展示版本归并发会话（本批未动 BUILD_VERSION）。
  - 边界：手机 FPS / 全 DPR / 用户审美未验收；**真机观感（字是否够大够饱满、与青底对比）需 Preview 目视**。
  - ⚠️ **避雷 AB-276：「素材缩放有误」常指「选的素材形态不对」，不是运行时 scale 算错——先并排比对再改参数**（cta-startbattle-scale-fix，承接 AB-275）：上一批我按「复刻参考图」选了**带青晕**的草案（以为青晕是参考特征），结果用户报「缩放有误」——真因是**青晕版本身字距散、aspect 偏宽（3.18 vs 参考 2.55）**，青晕还让字发虚。**做法**：①用户报「素材缩放/比例不对」时，**先把「参考图 / 用户截图 / 我的渲染」按同一基准（如按钮宽）归一化并排**——一眼区分「形态不对（换素材）」还是「倍数不对（调参数）」；②出草案时**两版都留**（本项目 `sb_a` 无晕 / `sb_b` 带晕），别只凭猜选定；③**带光晕的草案 aspect 会偏宽且视觉发虚**——参考图的字若紧凑实心，就别加光晕。⚠️ 离线用 PIL 合成多组 `stretchX`/`FitHeight` 变体比每次真渲染快得多。

- 附记: cta-startbattle-regen（2026-10-12，**「开始战斗」艺术字重出为斜体银白金属字 + 青色光晕**；不改展示版本）：
  - 用户上传主菜单截图 + 「重新生成一个开始战斗吧」→ 参考图里 CTA 是**斜体（向右倾斜）+ 银白金属立体字 + 青边缘光晕**，而现有 `ui_tt_startbattle.png` 是**正体**金属字（121×44）。**用户随后回「这个好」**确认方向。
  - **做法（0718 管线，沿用旧文件名/uuid，零路径风险）**：`batch_generate_images`（nanobanana, `transparent:true`, 1248×832）出 2 版草案——`sb_a` 干净斜体银白金属字、`sb_b` **同款 + 青边缘光晕**；选 **`sb_b`**（与参考图一致：青晕与青底 CTA 同语义；`sb_a` 无晕会读成「平」）。后处理：**alpha>128 裁切** → **按母版高度 44 归一**（宽 140，**高度不变 = 零布局改动**，AB-259 同族）→ 覆盖同名 `ui_tt_startbattle.png`。⚠️ **`sb_b` 是彩色（银+青）**，与旧版「灰度金属」不同——但 CTA 用**白 tint**（`ArtText.DrawCentered(..., {255,255,255}, ...)`），乘法染色对**近白**安全，青晕只被乘到略暗、不塌（AB-258 只针对「非白 tint」塌，白 tint 对彩色素材同样安全）。若哪天 CTA 改用非白 tint，这版彩色素材会塌——**彩色素材的 tint 约束比灰度更严**。
  - **草案清理**：`sb_a/sb_b` PNG + 生成的 `.png.meta` 残片全部移出 assets 到 `/home/Maker/sb_v2/drafts/`，`assets/image/` 只留按目标名命名的成品（AB-206/207 目录纪律）。
  - 验证：LSP workspace **29 文件 0 Error**；真渲染探针 `probe_ctastretch`（停菜单）——`[ArtText] loaded=8/8`、`has_startbattle=true w=140 h=44`、零 `overlay stage failed`/`Execute Lua function failed`/`LoadChunk failed`/`VertexBuffer is empty`；**像素取证**：CTA 银白金属像素 **4286（旧 1952）**、青色光晕 **29033px**、金属字宽 267 设计像素。官方多人 build + 预览上传 ✅（首次 `PLATFORM_OPERATION_FORBIDDEN` 属平台临时限制，重试成功——不绕过）。展示版本归并发会话（本批未动 BUILD_VERSION）。
  - 边界：手机 FPS / 全 DPR / 用户审美未验收；**真机观感（斜体倾斜角度、青晕强度、金属高光是否够亮）需 Preview 目视**。
  - ⚠️ **避雷 AB-275：换「艺术字风格」时，参考图里的「光晕/描边/颜色」要一起复刻——别只换字形**（cta-startbattle-regen）：用户给参考图说「重新生成」，参考 CTA 的特征是**斜体 + 青边缘光晕**两件；只出干净斜体字（`sb_a`）会缺掉「青晕」这一层，读起来仍与参考不同。做法：**先量参考图的构成**（本项目用像素分析确认 CTA 区 35927px 青调 vs 7143px 银调 → 青晕是主导特征），再按此出草案。⚠️ 带光晕的草案是**彩色**素材——比灰度素材更依赖「白 tint」才不塌（见上）。

- 附记: cta-stretch（2026-10-11，CTA「开始战斗」艺术字**横向拉伸**；不改展示版本）：
  - 用户「继续，开始战斗横向也需要拉长」——上一批（gear-settings）把 CTA 改成艺术字**等比**放大铺满（FitHeight 60，宽 ~165 设计像素），但 4 字标题在 456 宽的按钮里**左右留白仍多**，用户要「更宽」。
  - **做法（`ui/ArtText.lua` 加横向拉伸能力，零破坏既有调用点）**：`Draw`/`DrawCentered` 新增**可选尾参 `stretchX`（缺省 1）**——`w = it.w * s * stretchX`、`h = it.h * s`（只横向拉、纵向不变）；新增 `ArtText.FitWidth(key, targetW, scale)` 返回「让字标宽约等于 targetW 所需的横向拉伸倍数」。⚠️ `nvgImagePatternTinted(ctx, ox,oy, ex,ey, ...)` 的 `ex,ey` 就是图案填充矩形尺寸，**横向拉伸只需 w 与 h 不同**，无需改纹理。
  - **CTA（`Scene3DBackend.DrawMenu`，~1607）**：`s = FitHeight("startbattle", 60)`（纵向不变），`sx = math.min(1.7, FitWidth("startbattle", cta.w * 0.66, s))`——横向拉到按钮宽 ~66%、**上限 1.7×**（4 字标题拉过头会明显变形），`DrawCentered(..., s, sx)`。实测金属字宽 **165 → 258 设计像素**（撞 1.7× 上限）。
  - **验证**：LSP workspace **29 文件 0 Error**（1311 诊断）；真渲染探针 `probe_ctastretch`（停菜单、`-screenshot-frame=160`）——`[ArtText] loaded=8/8`、零 `overlay stage failed`/`Execute Lua function failed`/`LoadChunk failed`/`VertexBuffer is empty`；**像素取证**（按 CONTAIN 映射裁 CTA 区，数白亮金属像素）实测金属字宽 258 设计像素（原 ~165）。官方多人 build + 预览上传 ✅。展示版本归并发会话（本批未动 BUILD_VERSION）。
  - 边界：手机 FPS / 全 DPR / 用户审美未验收；**真机观感（1.7× 拉伸后字是否显宽扁、与青底按钮比例）需 Preview 目视**。
  - 附：**除 Zpix 外适合本项目的像素字体**（用户问「除了 ZPix 还有什么适合的像素字体」）——项目内 `ui-pixelforge` skill 自带 **Fusion Pixel 12px**（`FusionPixel-12px-Prop-zh_hans.ttf` 正文 / `-Bold.ttf` 加粗 / `-Mono-zh_hans.ttf` 等宽数字），含简体中文、体量 ~7MB/款。实测渲染对比：**Fusion Pixel 比 Zpix 更细更干净**（Zpix 更重、带硬描边，适合标题/大字；Fusion Pixel 线条细，适合正文/小字/数字），两者可**分层使用**（标题 Zpix、正文 Fusion Pixel）。⚠️ 换字体要 `nvgCreateFont` 重新注册 + 按字号调行高（Fusion 12px 网格比 Zpix 更小）。

- 附记: gear-settings（2026-10-11，主菜单齿轮设置屏 + 危险操作确认面板 + CTA 去副标题 + 暂停钮移左上；不改展示版本）：
  - 用户四项要求：①CTA 去掉「选择关卡」小字、让「开始战斗」更大；②局内暂停键从**右上移到左上**；③主菜单左上角加**齿轮设置键**；④设置页含**恢复购买 + 清空存档**，二者点后弹**手机键盘（0-9 * #）确认面板**，输入正确确认码才执行。
  - **① CTA**：去掉 `DrawPixelText(... "选择关卡" ...)`，艺术字改 `ArtText.DrawCentered(ctx, "startbattle", cta, {255,255,255}, 0, ArtText.FitHeight("startbattle", 60))` 居中铺满（原 ctaY+8 顶对齐 + FitHeight 50）。
  - **② 暂停钮左上**：`GetHudPauseRect` 从 `{x=w-42,y=10}` 改 **`{x=10,y=8,w=28,h=28}`**；`ui/BattleHUD.DrawHud` 左栏内容（得分/最高/Lv/经验条）**右移 26px** 让位（`18→44`、`52→78`、`77→103` 等），命中 `Backend.HitTestHudPause` 与几何同源。
  - **③ 齿轮入口**：`Scene3DBackend.DrawMenu` 左上角内联画 40×40 齿轮按钮（`uiFx.surface.Button` 底 + `DrawIcon("gear")`，缺图回退程序化八齿环）；命中 `Backend.HitTestMenuGear`（挂在 Backend 表，**顶层 local 已满 200 不能加**）；新图标 `assets/image/ui_icon_gear_20261011.png`（0718 管线 32×32/7 色/uuid `469afb97c40c7710c0e339`）+ `.meta` + `.png.xml`(跳过 ASTC) + `.xml.meta`。
  - **④ 设置屏 `scripts/ui/Settings.lua`（新增）**：`MetaUI.RegisterScreen("settings", …)` + `("reset_confirm", …)` **插件式注册**（复用元层窗口动画/命中逆变换，后端零状态）。设置屏两项：恢复购买（`gem` 图标/金）/清空存档（`reroll` 图标/红），点后 `Settings.BeginConfirm(reason)` + 开确认面板。确认面板 = 标题 + 自动换行提示 + 确认码显示（restore=`1234`/delete=`0000`）+ **电话键盘 3×4**（1-9,*,0,#）+ 删除/确认/取消三按钮；`input_ == ConfirmCode()` 才启用「确认」。`Settings.KeyCharAt/PushChar/Backspace/IsConfirmed/GetInput/BeginConfirm/GetConfirmReason`。
  - **⑤ 编排层（client_main）**：新增 `local Settings = require "ui.Settings"` + 两处 `RegisterScreen`；`HandleMetaAction` 新增 `open_settings`/`restore_purchase`/`reset_save`/`confirm_key`/`confirm_backspace`/`confirm_cancel`/`confirm_ok` 分支；`HandleMetaPointerDown` 菜单态先判 `HitTestMenuGear`。**清档** = `PlayerData.ResetAll()`（新增，重置内存态为出厂默认）+ `Save()` + 云同步 + 复位 itemStock/talents/gems；**恢复购买** = `NetClient.RequestBalance()`（离线提示「需联网」）。
  - 验证：LSP workspace **29 文件 0 Error**（1294 诊断）；真渲染探针 —— 菜单齿轮图标清晰（`gear_zoom`）、设置屏两行 + 关闭按钮完整（`set_screen3`）、确认面板键盘 12 键完整不压按钮（`set_confirm2`，首版第 4 行被切→面板 628→676 高、键 84→68、上移）、战斗 HUD 暂停钮已在左上（`pause_pos`）、CTA 无副标题金属字居中铺满（`cta_final`）；三屏 exit0、零 `overlay stage failed`/`Execute Lua function failed`/`LoadChunk failed`；行为探针 `probe_setlogic` **9/9 PASS**（齿轮命中/未命中、确认码状态机、delete 0000 / restore 1234、清档 11037→0）。官方多人 build + 预览上传 ✅。展示版本归并发会话（本批未动 BUILD_VERSION，当前常量 0.13.57）。
  - 边界：手机 FPS / 全 DPR / 真机观感未验收；**真机观感（齿轮键、设置屏、键盘面板、暂停钮位置）需 Preview 目视**。
- 附记: enchant-aura-3d（2026-10-11，附魔车环绕粒子改**真 3D**；不改展示版本）：
  - 用户「环绕车辆的粒子实行使用 3D 特效。因为呢，我们这个游戏呢，它这个 2D 的界面和 3D 界面并不是完全平行的，所以会导致有一些问题啊」——**这是一个通道级判断**：上一批给附魔车加的可见标识是 **2D overlay 光环**（`CombatImpact.DrawEnchantAura` 用 `ProjectGamePoint` 手工投影 + `nvgRadialGradient` 旋转双环）。**真因**：本项目相机是 **46° 斜俯视正交**，`z` 会投影到屏幕 Y——overlay 用**玩法平面 z=0** 标定的投影去画，而车辆锚点在 z≈-0.09~-0.13m，于是光环整体相对真实 3D 车**在屏幕上分离**（同 v0.13.15b 尾迹「与车分离」的同一根因族）。**2D 与 3D 不平行 = overlay 画不出「贴在 3D 物体上」的效果**。
  - **修法（`Renderer3D.lua`，真 3D）**：新增 `SyncEnchantAura(game)`——粒子**绕车辆世界锚点 `GetVehicleAnchorWorld(m)` 在 3D 空间 XZ 平面转圈** + 轻微 Y 起伏，因此与车永远对齐（3D 世界坐标天然同投影）。**每档稀有度一个 BillboardSet**（3 个，各带自己稀有度色的软圆纹理）——因为 **DiffAlpha 不读 billboard 顶点 rgb**（本项目 v0.10.21 契约），颜色只能烘焙进纹理。相位 `game.elapsed * 2.6` 派生（确定性、非逐帧随机），各车 `+ci*1.7` 错开。`Init` 建 / `Shutdown` 清；只画、不参与命中。新增只读诊断 `Renderer3D.DebugEnchantAuraCount()`（返回本帧**实际启用**的 billboard 数，供探针自证数据通路）。
  - **移除 2D 版**：`Scene3DBackend` 的 `uiFx.impact.DrawEnchantAura(...)` 调用删除；`ui/CombatImpact.lua` 的 `DrawEnchantAura` 整段 + 本地 `ENCHANT_RARITY` 删除（被 3D 版取代）。
  - 验证：LSP workspace **29 文件 0 Error**（1295 诊断）；真渲染探针（走 `client_main` 真实渲染路径：菜单→选关→战斗→附魔→发射→飞行 540 帧）实测 **`aura=0`（无附魔）→ `aura=10`（附魔后，10 个 3D billboard 启用）** 并随飞行持续；零 `overlay stage failed`/`Execute Lua function failed`/`LoadChunk failed`/`VertexBuffer is empty`。官方多人 build + 预览上传 ✅。展示版本归并发会话（本批未动 BUILD_VERSION）。
  - ⚠️ **避雷 AB-264：贴 3D 物体的特效**必须画在 3D 世界里（共享相机投影），不要用 2D overlay 手工投影——本项目 2D/3D 不平行（46° 斜俯视正交，z 投影到屏幕 Y），overlay 的光环/尾迹会与真实车辆分离（enchant-aura-3d，同 v0.13.15b 尾迹族）：用户一句话点破「2D 界面和 3D 界面并不是完全平行的」——**这是「光环跟车分离」的真因**，不是参数问题。做法：把特效挂到物体的**世界坐标**上（`GetVehicleAnchorWorld`），粒子绕世界锚点在 **3D 空间**转圈，由 3D 相机统一投影 → 天然对齐。⚠️ 但**本环境离屏 3D 层恒黑（AB-220），无法目视 3D 特效**——只能用**数据探针**自证（读 `DebugEnchantAuraCount()>0` 证明粒子真的提交到 3D 场景）；真机观感仍需 Preview。⚠️ 颜色进 3D BillboardSet 必须**烘焙进纹理**（DiffAlpha 不读顶点 rgb），**每色一个 set**——不能指望一个 set 靠 `bb.color` 区分稀有度。
  - 边界：手机 FPS / 全 DPR / 用户审美未验收；**真机观感（3D 光环是否真的绕车、稀有度色是否可辨）需 Preview 目视**（本环境 3D 层不可见，只证明了数据通路）。

- 附记: stage-start-variety（2026-10-11，修「每关开局的敌机类型都一样」；不改展示版本）：
  - 用户「每关开局的这些敌机类型都一样，真是太无聊了。」
  - **真因（探针实锤）**：`Game.GetAvailableTypes(waveNum)` 用 `StageCatalog.GetStageWave(waveNum)` 做 `WAVE_ROSTER` 门槛，而 **`GetStageWave` 每关都从 1 重新数**（1..10 循环）→ 每关第 1 波可用池都只有 `scout`。基线探针 `probe_variety` 实测 **12 关开局全 `scout`（`uniqFirst=1`）**。
  - **修法（`Game.lua` 两处）**：①`GetAvailableTypes` 的解锁进度改用「**累计难度**」`(StageCatalog.GetStage(waveNum) - 1) + StageCatalog.GetStageWave(waveNum)`——**第 1 关与原版完全一致**（1~10 波依次解锁全部机型），第 2 关起开局就带上已解锁机型、关卡越高类型越丰富；②`PickWaveAircraft` 的「最新机优先」偏置 **0.6→0.3**（池变大后过高偏置会让每波过度偏向单一机型、削弱多样性）。
  - **验证**：LSP workspace **0 Error**（27 文件 1238 诊断）；规则探针 `probe_variety` **4/4 PASS**（关1 ×12seed 开局恒 `scout`＝第 1 关体验保留 / 关5 ×16seed 出现 4 种 / 关10 ×16seed 出现 5 种 / 固定 seed 下 12 关开局首机 >= 4 种）；回归 `probe_offscreen` **4/4 PASS**（屏外上限未破）；真渲染冒烟 `probe_render` 零 `overlay stage failed`/`Execute Lua function failed`/`LoadChunk failed`/`VertexBuffer is empty`（日志确认关1 波1 出 `scout`、波2 出 `dart`）。官方多人 build + 预览上传 ✅。展示版本归并发会话（本批未动 BUILD_VERSION）。
  - 边界：手机 FPS / 全 DPR / 用户审美未验收；**真机观感（中后期开局机型分布是否足够多样）需 Preview 目视**。
  - ⚠️ **避雷 AB-263：机型/内容「按门槛表解锁」时，门槛不能用「关内波次」——那样每关都会从头重新解锁，导致每关开局都一样（stage-start-variety）**：本项目 `WAVE_ROSTER`（机型按 minWave 门槛解锁）一直用 `GetStageWave`（关内波次 1..10，**每关重置**）当门槛 → **每关第 1 波可用池都只有第一档**，玩家看到「每关开局都是同一种小飞机」。**判据**：任何「随进度解锁」的门槛，若关卡是**可重复进入**的（选关/重开），门槛变量必须**单调累积**（本项目 = `(关卡-1) + 关内波次`），**不能用每关重置的关内计数**。⚠️ 修的时候要**同时检查随机偏置**——门槛放开后池子变大，原本「新机优先 0.6」的偏置会反过来压掉多样性，要一并下调。

- 附记: arttext-fill-white（2026-10-11，艺术字去黑幕铺满按钮 + 商店标签转白；不改展示版本）：
  - 用户「车型外观与拖尾样式需要变得更白一些（颜色更浅）」+「开始战斗还是不合格，**直接占满按钮无黑幕**」+「继续战斗有开始战斗同款的问题」——三处都是**艺术字运用问题**。
  - **① CTA「开始战斗」去黑幕铺满**：上一批（cta-arttext-fit）是「暗色铭牌 + 白 tint」，用户判不合格。**最终形态**：**去掉暗铭牌**，艺术字白 tint **等比放大铺满按钮高度**（`ArtText.FitHeight("startbattle", 50)` → scale≈1.14），金属字直接压在青色按钮上——青色按钮本身就是它的底，无黑幕。
  - **② 暂停「继续战斗」同款**：去铭牌 + 白 tint 放大到按钮高 34px（scale≈1.13）。
  - **③ 商店分页标签「车型外观/拖尾样式」转白**：原用 `tint = active and C.warn or C.dim`（金/暗灰）——**金属立体字被非白 tint 染色会塌**（同 AB-258）；改**白 tint**，未激活降 alpha（255→190）→ 更白更浅。
  - **ArtText 新增能力**：`Draw/DrawCentered` 加可选 `scale` 尾参（缺省 1，等比缩放）；新增 `ArtText.FitHeight(key, targetH)` 返回 `scale,w,h`（铺满容器高度用）。⚠️ 母版是**完整成品**，只能**等比**缩放，别非等比拉伸（AB-207）。
  - ⚠️ **AB-260（本轮）：金属立体艺术字的「亮底无铭牌」用法——白 tint + 等比放大铺满，比「暗铭牌 + 白 tint」更符合「直接占满按钮」的观感**：cta-arttext-fit 的暗铭牌解决了「金属字压在亮青底上对比不足」，但用户要的是**字直接占满按钮**、不要铭牌那块「黑幕」。做法：白 tint（保住金属明暗两级）+ `FitHeight` 放大到接近按钮高 → 金属字本身就是按钮的视觉主体。**判据**：金属字的「底」可以就是按钮色本身（青色即对比），不必额外垫暗色块；只有当按钮色与金属灰**明度太接近**时才需要铭牌。
  - 验证：LSP workspace 27 文件 **0 Error**（1236 诊断）；真渲染探针 `probe_cta`（菜单）/`probe_pausetxt`（暂停）/`probe_shop`（商店）三屏 exit0、零 `overlay stage failed`/`Execute Lua function failed`/`LoadChunk failed`；实图目视——CTA「开始战斗」金属字无黑幕占满按钮、暂停「继续战斗」同款、商店两标签亮白金属字。官方多人 build + 预览上传 ✅。展示版本归并发会话（本批未动 BUILD_VERSION，当前常量 0.13.57）。
  - 边界：手机 FPS / 全 DPR / 用户审美未验收；**真机观感（金属字放大后是否过满、商店未激活标签亮度）需 Preview 目视**。
- 附记: cta-arttext-fit（2026-10-11，修主菜单 CTA 艺术字压副标题 + 金属感被青 tint 压塌；不改展示版本）：
  - 用户截图点名「你看出这个开始战斗涉及的问题了吗？」——放大后定位**两个真问题**（不是审美分歧，是 bug + 素材契约错用）：
  - **① 副标题压铭牌（布局回归）**：上一批 arttext-metal 把 `startbattle` 母版从 **38 高改成 44 高**，而 CTA 绘制代码没跟着调——铭牌高 `ah+8`=52、从 `ctaY+4` 起 → 底边落到 `ctaY+56`；副标题「选择关卡」却仍固定在 `ctaY+52` → **必然交叠约 4px**（实测确认）。**修法**：`GetMenuCtaRect` 按钮 **72→84 高**（44 字 + 铭牌留白 + 13 副标题在 72 里塞不下），副标题移到 `ctaY+62`、铭牌 `ctaY+6`。实测新布局：铭牌底 486、副标题 492–508、按钮底 514、**间隙 6px**；CTA 底 514 距下方天赋大卡（y=532）留 18px，不挤压。
  - **② 金属被青 tint 压塌（素材契约错用）**：CTA 艺术字原先用 **`C.cyan` 青 tint** 乘法染色——新母版是**立体金属灰**（明暗两级），乘青色后金属灰被压成**扁平暗青**、立体倒角全丢（离线三变体对比实测：青+铭牌 vs 白无铭牌 vs 白+铭牌）。**修法**：改 **白 tint `{255,255,255}` + 保留暗色铭牌**——金属明暗两级完整保留、铭牌提供对比、青色按钮语义由底与描边承载。暂停「继续战斗」同源改白（保留其铭牌）。
  - ⚠️ **AB-258（本轮价值最高）：`nvgImagePatternTinted` 乘法染色对「金属/立体」素材，青 tint 和深 tint 一样会塌**——上一批只记了「深 tint 塌成黑」，本批发现**青 tint 把金属灰压成扁平暗青**（`C.cyan`=(0,229,208) 的 R 通道=0，金属的红色分量被直接乘没）。**判据**：tint 必须在**所有三个通道都接近白**（白/浅灰）才能保住金属的明暗层次；任何「某通道≈0」的 tint（青 R=0、红 G=B=0、深色全体）都会塌。金属/立体素材的默认 tint 用**白**，语义色交给底/描边/铭牌承载。
  - 验证：LSP workspace 27 文件 **0 Error**（1239 诊断）；真渲染探针 `probe_cta`（停在菜单）实图确认——「开始战斗」金属倒角清晰、副标题不压铭牌、`[ArtText] pixel titles loaded=8/8`；`probe_pausetxt`（进关后暂停）实图确认「继续战斗/返回主菜单」金属立体字；两探针 exit0、零 `overlay stage failed`/`Execute Lua function failed`/`LoadChunk failed`/`VertexBuffer is empty`。官方多人 build + 预览上传 ✅。展示版本归并发会话（本批未动 BUILD_VERSION，当前常量 0.13.57）。
  - 顺手补 `scripts/ui/ArtText.lua.meta`（v0.13.57 的 ArtText 模块此前**只提交了 .lua、漏了 .meta**，而构建清单已引用其 uuid）——避免 uuid 解析依赖构建期重新生成。
  - 边界：手机 FPS / 全 DPR / 用户审美未验收；**真机观感（金属字清晰度、按钮加高后的比例）需 Preview 目视**。
- 附记: hp-cap-curve（2026-10-11，按出场序号封顶血量的**曲线换成指数缓升**；不改展示版本）：
  - 用户「第n架飞机的血量上限改为0.5*（1.25^n+1）向下取整」——把 v0.13.51 的 `GetFirstShipHpCap` 从 `2n−1` 改成 `floor(0.5×(1.25^n + 1))`。**只改 `StageCatalog.GetFirstShipHpCap` 一个函数体**，调用点/门控/「只封顶不抬升」语义/精英Boss 不参与 全部不变。
  - **新曲线**（实测）：n=1..4 → **1**、n=5..7 → 2、n=8 → 3、n=10 → 5、n=12 → 7、n=15 → 14、n=20 → 43。对比旧 `2n−1`（1/3/5/7…）**前期显著更平缓**（前 4 架恒 1 血）、后期随序号指数级拉开。
  - 验证：LSP workspace 27 文件 **0 Error**（1239 诊断）；规则探针 `probe_hpcap` **26/26 PASS**（n=1..20 逐值匹配公式 / nil·0·负数钳到 1 / 1..40 单调不减 / 前 4 架恒 1 血 / 与旧公式 n=5 处 2 vs 9 确实不同）；真渲染冒烟 `probe_render`（菜单→选关→战斗→发射）零 `LoadChunk failed`/`overlay stage failed`/`Execute Lua function failed`/`VertexBuffer is empty`。官方多人 build + 预览上传 ✅。展示版本归并发会话（本批未动 BUILD_VERSION，当前常量 0.13.55）。
  - 边界：手机 FPS / 全 DPR / 用户审美未验收；**平衡手感（前 4 架都 1 血是否太软、后期 15+ 架涨到 14/43 血是否过陡）需 Preview 实机确认**。
- 附记: arttext-metal（2026-10-10，艺术字重出为**立体金属字**；不改展示版本）：
  - 用户「艺术字不够艺术」——**原艺术字是 AI 生成的纯白平块**（`tt_*_b` 草案 3711 色只是边缘抗锯齿噪声，主体是实心白），后处理又压成「白芯 + 近黑描边」两色 → **零层次**，读起来像普通加粗字。**根因是素材本身不艺术，不是渲染问题**。
  - **重出 8 个艺术字**（走 0718 管线）：`batch_generate_images` 出**立体金属**草案（金属拉丝渐变 / 顶亮底暗 / 倒角立体 / 发光描边）→ 后处理：**alpha>128 裁切**（别用 `getbbox()`，会被微弱发光撑到全画布，导致宽高比失真、字被压扁）→ **按 SPECS 原高度等比归一**（`startbattle 44 / resume·menu·stage 30 / daily·collect 26 / vehicle·trail 20`，**高度不变 = 零布局改动**，宽度随内容自动）→ **转灰度保明暗**（不是压成两色）→ 覆盖同名 `ui_tt_*.png`（沿用旧 `.meta` uuid，零路径风险）。实测宽度：startbattle 121 / menu 128 / resume 87 / stage 99 / daily 88 / collect 77 / vehicle 71 / trail 82。
  - 🔴 **关键设计（保住 tint 契约）**：转**灰度**而非两色——保留金属明暗层次的同时，`nvgImagePatternTinted` 仍能把同一张图乘成 **青/白/金**（实测三色都成立、层次完整）。**若用全彩 AI 图就丢了 tint**（每个语义要多套图）；**若压成两色就丢了层次**（回到「不够艺术」）。灰度是**两者兼得**的解。
  - 验证：真渲染探针（选关→暂停）——「继续战斗 / 返回主菜单」显示**金属立体艺术字**（倒角/明暗清晰）；`[ArtText] loaded=8/8`；manifest 中 8 张均为**未压缩 PNG**（`.png.xml` 生效）。官方多人 build + 预览上传 ✅。草案移出 assets 到 `/home/Maker/art2/drafts/`（连 `.png.meta` 残片一并清）。展示版本归并发会话（本批未动 BUILD_VERSION，当前常量 0.13.55）。
  - ⚠️ **教训（AB-254）**：「素材不够艺术」要先看**原始素材**——本项目 AI 草案本身就是纯白平块，问题在**生成提示词**（要写「立体金属/倒角/顶亮底暗/发光描边」），不在后处理或渲染；且后处理**「压成两色」会静默丢掉所有明暗层次**（本项目为此丢了两版）。**灰度化**是「保留层次 + 保留 tint 染色」的折中。
  - ⚠️ **教训（AB-255）**：像素/艺术字素材的 bbox **别用 `Image.getbbox()`**（只要有一个 alpha>0 的噪点/发光就撑到全画布）——用**更高 alpha 阈值**（本项目 `>128`）取 bbox，否则裁切比例失真、字被压扁。
- 附记: item-split-buff（2026-10-10，局内道具加强 + 分裂中间车 ±5° 随机；不改展示版本）：
  - 用户「局内的三个道具强度不明显，特别是炸弹继续加强。另外分裂车分裂时中间的车左右随机偏移5度以内」。
  - **炸弹**（`Game.UseItem` 的 `bomb` 分支）：每机炸掉「存活格数一半（向上取整）」、上限 12 格（原固定 4 格）——满编队约半清、大机更明显，仍非一键全清。**冰冻** `FREEZE_SECONDS` 4→6s。**护盾** `SHIELD_POINTS` 30→60。
  - **分裂 ±5° 随机**（`TrySplitNormal`）：每颗子车在扇区基准角上叠 `Random()*10-5`（±5°）——中间的（基准 0°）不再永远走正前方，整个扇形略随机化。偏移上限固定 5°，**不改分裂数量与铺开宽度**（与「专属卡=机制、基础卡=数值」及 15 上限契约一致）。
  - 验证：规则探针 `probe_itemsplit` **4/4 PASS、496 断言、exit0**（炸弹 4/6/10/24/40 格机分别炸 2/3/5/12/12 且剩余格数精确、冰冻=6、护盾=60、分裂 40 次×2/3/4 颗角度**实测最大偏移 4.997° ≤ 5°**）；LSP workspace 27 文件 **0 Error**。官方多人 build 与预览上传 ✅。
  - POST-1 执行（persona 不新增：延续「数值不够明显就加强」的既有偏好）。POST-2 代码独立提交（仅本人 3 处 hunk，保留并发附魔改动）。POST-3 判定跳过（本项目数值/机制小调，无新增跨项目偏好）。边界：手机 FPS / 全 DPR / 用户审美未验收；炸弹新强度与分裂随机观感需 Preview 实机确认。

- 附记: texture-uncompressed（2026-10-10，UI 像素图跳过 ASTC 压缩，修「艺术字异常缩放」乱码；不改展示版本）：
  - 用户「现在就是确实有艺术字加上异常缩放」——**上一批 arttext-preload-fix 只解决了「有没有加载」，真凶是「压缩把字糊了」**。
  - **真因（构建产物取证 + 放大实图）**：构建把**所有**纹理压成 **ASTC 6×6 + 7 级 mipmap**（mobile）/ BC7（windows）——`cooking_results.json` 记 `output_file=..._ASTC_6X6_medium_mip.png`；运行时 `Image:IsCompressed()==true`、`Texture2D:GetLevels()==7`。**细描边像素图**（艺术字 1–2px 轮廓、32×32 图标、24×32 数字）被 6×6 块压缩**平均掉**，真机解码后呈**竖条块状乱码**（用户截图放大可见）。⚠️ 之前我用桌面软件解 KTX **看不出糊**（软件解码近似无损），差点误判「压缩不是原因」——**判据要看真机 GPU 解码 + 放大实图**，不是离线解码。
  - **修复**：给 `assets/image/ui_*.png`（**70 张**：艺术字 8 / 数字 10 / 图标 / 徽章 / 字标 / 手势图）各加**同名 `.png.xml`**（Urho3D 纹理配置约定），内容 `<compress format="none"/>` → **构建跳过压缩**。`ui_tt_resume.png.xml` 单独验证过：重建后该图 `size=761`（=源码，未压缩）。
  - **验证**：重建后新清单 `manifest-origin.b409.json` 里 **70 张 `ui_*.png` 产物全部为原始 PNG（PNG=70 / KTX=0）**，`size == size@windows`。官方多人 build + 预览上传 ✅。展示版本归并发会话（本批未动 BUILD_VERSION，当前常量 0.13.55）。
  - ⚠️ **提交注意**：构建会为每个 `.png.xml` 生成 `.xml.meta`（uuid），**清单按 xml.meta 引用** → xml 与 xml.meta **必须一起提交**（本批 140 个文件 = 70 xml + 70 meta）。
  - ⚠️ **与 arttext-preload-fix 的关系**：那批修的是「`Has()` 不触发加载 → 首次绘制前永远走 zpix 回退」（间歇性「有时艺术字有时文字」）；本批修的是「加载了但被压缩糊成乱码」。**两个独立真因**，都要。
- 附记: arttext-preload-fix（2026-10-10，修「贴图艺术字概率出错」；不改展示版本）：
  - 用户报「贴图艺术字概率出错」+ 两张实机截图（暂停按钮「继续战斗」/选关面板标题位置各有一处**竖条状乱码**）。**「概率」是关键词**——间歇性、非确定。
  - **真因（本地复现实锤）**：`ui/ArtText.lua` / `ui/DigitFont.lua` 是**懒加载**（只有 `Draw()` 触发 `nvgCreateImage`），而 **`Has()/Width()/Height()` 不触发加载**。全项目多数调用点是 `if ArtText.Has(k) then Draw(...) else zpix` → **首次绘制前 `images_` 为空 → `Has()` 恒 false → 永远走 zpix 回退**；只有 `ui/StageSelect.lua` 的 `Draw("stage")` 是**无条件调用**（加载整个表）→ **打开过选关屏后艺术字才「恢复」**。于是同一按钮在不同路径下时而艺术字、时而 zpix 文字 = 用户说的「概率出错」。另一层风险：`nvgCreateImage` 在 `NanoVGRender` 帧内执行，纹理尚未上传完就同帧绘制。
  - **修复**：`ArtText`/`DigitFont` 各加**公开 `Ensure(ctx)`**（幂等）；`Backend.Init` 在 `vg_` 就绪后调 `ArtText.Ensure(vg_)` + `DigitFont.Ensure(vg_)`，**启动即加载**；`Draw/DrawCentered` 内部改用 `Ensure`（预加载后为 no-op）。新增 1 个顶层 require（`DigitFont`）+ 2 行调用，零新增顶层 local（AB-166）。
  - **⚠️ 探针方法论漏洞（本轮最重要）**：我最初写的暂停探针**从未真正渲染艺术字**——因为 `Has()` 返回 false 时走 zpix 回退，**日志里根本没有 `[ArtText] pixel titles loaded`**（我误以为「加载成功」）。修复后同一探针在**帧 3（Init）**就打印 `loaded=8/8`。**教训**：验证「贴图是否真的画出来」时，**先确认加载日志出现**（`[ArtText]/[DigitFont] loaded=`），别把 zpix 回退当成「渲染正常」（同 AB-242 的「装载出错 vs 图本身坏」、AB-216 的「无报错 ≠ 画出来了」）。
  - 验证：真渲染探针 `probe_race`（**直接进暂停**、不先开选关）——修复前显示 zpix 文字，**修复后显示真艺术字**；菜单 CTA「开始战斗」启动即艺术字；`[ArtText] loaded=8/8` + `[DigitFont] loaded=10/10` 在帧 3 打印。LSP workspace **0 Error**（27 文件 1239 诊断）。官方多人 build + 预览上传 ✅。展示版本归并发会话（本批未动 BUILD_VERSION，当前常量 0.13.55）。
  - 排除项（记录以免重复排查）：①素材本身完好（ASCII 渲染可读、每张 2 色、alpha0 14–30%）；②`nvgImageSize` 返回**正确**（resume 103×26）；③构建的 **ASTC 6×6 压缩**虽把 761B→2145B，但**强制加载后 KTX 版与 PNG 版渲染差异 ≈0**（同帧 62489 px 中仅 14 px 差 >20）→ **不是压缩问题**。
- 版本: 0.13.57（**局内附魔卡：每完成一波获得/更换，使用后附到待发车，蓝紫黄三稀有度**）：
  - 用户「每完成一波，玩家将允许获取/更换一个'附魔卡'，显示在局内界面左上角，与道具对称，使用后消失，效果是改变预备发射/当前若空则顺延下个预备发射的车，让它拥有一种强力的特殊效果，该效果也分蓝紫黄三种稀有度，高波次容易出高稀有度」；随后追加「没附魔时不显示，太挡了，用完之后2s内渐隐」。
  - **数据层 `scripts/EnchantCatalog.lua`（新增）**：9 张卡，**每张落在不同机制轴**（承接 AB-214/221 纪律）。蓝=裂变 `splitOnHit`(命中额外分裂 1 颗)/吸血 `healPerHit`(命中回血 1)/追踪 `homing`(命中后自动追最近砖)；紫=穿透 `pierce`(穿透 4 块不反弹)/连锁 `chain`(命中溅射最近砖)/霜冻 `freezeAll`(命中冻结全场 2s)；黄=重击 `damageMul`(伤害 ×2.5)/爆裂 `explodeRadius`(命中半径 2.2 格爆炸)/三连 `tripleShot`(发射扇形 +2 同型车)。`EnchantCatalog.Roll(wave, rng)` **稀有度权重随波次线性上升**：`t=(wave-1)/20` → wave1 蓝80/紫18/黄2 → wave21+ 蓝25/紫45/黄30；稀有度内均匀抽。rng 传 Game 的确定性随机流。
  - **规则层 `Game.lua`**：①`UpdateWaveLogic` 在**波次真正推进处**（`stageWave+1` 之后）`GrantEnchant()`——不在 Boss 重派/开波失败路径触发。②`Game.UseEnchant()`：有 `activeBall` → 立即 `ApplyEnchantToMarble`（`marble.enchant` + `enchantPierce`）；无（球在飞/补弹中）→ 存 `Game._enchant.pending`，`CreateMarble` 建车时消费（顺延）。③命中效果挂点：伤害倍率在 `GetMarbleDamage`；穿透在碰撞分支（`enchantPierce>0` 不反弹、沿速度前推 0.75 格、`ignoredBrick`）；回血/追踪/连锁/爆炸/冻结全场/分裂 在 `best` 命中块内（爆炸/连锁逐帧 `frameHitBricks` 去重）；三连在 `LaunchMarble`（`CreateSplitMarble` 造 +2 同型车、扇形 ±16°、继承附魔）。④**零新增顶层 local**——状态收进 `Game._enchant = { card, pending, lastWave }` 表；为腾槽位把 `PAUSE_HEAL_MAX/AMOUNT`+`PAUSE_RARE_MAX` 三个顶层 local **收进 `PAUSE_SUPPLY` 表**（AB-166，Game.lua 顶层 local 一直卡在 197–199）。⑤`ApplyEnchantToMarble` 前向声明 `local ApplyEnchantToMarble`（`CreateMarble` 约 500 行先于其定义，AB-100）。⑥快照出 `s.enchantCard`/`s.enchantPending`（有才建小表，避免每帧 GC）。
  - **UI**：`ui/BattleHUD.DrawEnchant(ctx, game, rect)` 左上角附魔卡（与右上道具竖列**镜像对称**）；**宽度 132**——Boss 阶段条从 `x=150` 起（`DrawBossPhaseBar`），更宽会重叠。**空手完全不画**（不是画占位），**用掉后 2 秒渐隐**（`state.enchantAlpha` 1→0，`Update` 里 `dt*0.5`，`DrawEnchant` 用 `nvgGlobalAlpha` + 逐色 alpha 跟随；渐隐期用缓存 `state.enchantCard` 继续画旧卡）。`Backend.GetEnchantRect`/`HitTestEnchant` 同源（挂 Backend 表，不加顶层 local）。`client_main.TryUseEnchantAt` 在鼠标/触摸 Down 中先于 `TryUseItemAt` 消费。
  - **Presentation**：8 条 `enchant_*` 事件反馈（granted/armed/applied/pierce/explode/chain/triple/lifesteal → 飘字/火花/震屏）。
  - **9 张 32×32 像素图标**（`0718-pixelimage-aigc` 管线：nanobanana `transparent:true` 草案 → bbox 裁切 → LANCZOS 缩到主体 26 → alpha 二值化 128 → 量化项目 8 色板 → 居中贴 32×32），实测 **5–7 色**、22hex uuid 全库唯一、NEAREST 装载。`assets/image/ui_ench_{split,lifesteal,homing,pierce,chain,freeze,power,explode,triple}.png`。
  - 验证：LSP workspace **0 Error**（27 文件 1239 诊断）；规则探针 `probe_enchant` **62/62 PASS**（9 卡机制签名两两不重复 / 稀有度随波次上升 / 开局空手 / 每波发卡 / 有车立即生效+穿透次数注入 / 无车顺延下一辆自动带附魔 / 重开清空）；效果探针 `probe_encheff` **9/9 PASS**（重击命中 / 三连 3 车 / 爆炸 / 穿透 / 冻结全场 / 追踪 / 连锁全部真实触发）；真渲染 `probe_enchrender` 零 `overlay stage failed`/`Execute Lua function failed`/`LoadChunk failed`/`VertexBuffer is empty`；**有卡/无卡像素对比**（左上角区域亮像素 **3699 vs 0**，证明空手不画）；渐隐状态机探针实测 `card=nil → gave card → before use true → after use false`。官方多人 build + 预览上传 ✅。版本常量 → **0.13.57**（BUILD_VERSION + lobby_runtime）。
  - 边界：⚠️ **手机 FPS / 全 DPR / 真机观感未验收**；本环境离屏 `-screenshot-frame` 深层帧不可靠（AB-220），**渐隐的中间帧未能截到**（只证明状态机 + 有/无卡像素差），「2 秒渐隐手感、左上角卡是否仍挡视野」需 Preview 目视。
  - ⚠️ **避雷 AB-247：给「每完成一波」这类周期性发奖加钩子，要挂**波次真正推进**的那一行，不是任意 `SpawnWave` 调用点**（v0.13.57）：`UpdateWaveLogic` 里有三处 `SpawnWave`——① Boss 逃脱后重派同一波（`stageWave` **不变**）② 正常推进（`stageWave+1`）③ 开场。把发卡钩子挂错点会导致「Boss 没打死反复重派、附魔卡刷屏」。做法：**放在 `stageWave = stageWave + 1` 之后**（唯一表示「真的过了一波」的位置）。
  - ⚠️ **避雷 AB-248：局内新增一个「常驻 UI 元素」要按用户要求给显隐与渐隐，别默认常驻**（v0.13.57）：附魔卡初版做成了「空手也画一个压暗占位」，用户立刻反馈「太挡了」。做法：①**空手完全不画**（占位 ≠ 有信息）；②**用掉后 2 秒渐隐**（`alpha` 线性衰减，`nvgGlobalAlpha` + 逐色 alpha 跟随，渐隐期用缓存的上一次卡数据继续画）；③渐隐状态放 `ui/BattleHUD.state`（表现层瞬时），不写规则层。
  - ⚠️ **加强（同日第二版，用户「效果太弱」）**：量化后揪出两类真问题——①🔴 **连锁只 `Emit("enchant_chain")` 发事件、零伤害**（真 bug）：改为命中时对最近另一块周围小片造成 **2× 真实伤害**（新增 `chainDamage` 字段）。②**低关卡砖块 1~2 血，纯伤害倍率看不出差别**（AB-172 陷阱）：蓝卡全走覆盖/可见方向，重击额外给穿透 4 块（一发贯穿一排）。③**分裂子车不继承附魔**（母车一分裂附魔即失效）：`CreateSplitMarble` 继承 `enchant`/`enchantPierce`，但标记 `enchantIsChild` 使子车命中不再触发 `splitOnHit`（防无限递归，15 上限只兜底）。**数值**：裂变 1→3、吸血 1→4、穿透 4→8、连锁 1.5→2.0×、霜冻 2→4s、重击 ×2.5→×5.0+穿透4、爆裂 2.2→3.5 格 ×0.6→×1.6、三连 +2→+3（共 4 车）。**视觉**：爆炸改大范围扩散环（`radius×3.2`）+12 火花+烟+震屏 0.3；连锁改双向火花+冲击环。验证：LSP 0 Error；`probe_enchant` **62/62**、`probe_encheff` **9/9**（探针断言同步新值）；真渲染零目标错误；**伤害探针实测**连锁 0→5、重击 4→7、分裂 8→8.8、追踪 27、爆裂 20（基准 2）。教训 → AB-254/255/256。
  - ⚠️ **加强（同日第三版，用户「还是不够强，而且缺乏特效表现力」）**：量化后定位**两层**问题——①**数值仍偏弱**：再抬一档（裂变 3→4、吸血 4→6、穿透 8→12、连锁 2.0→2.5×、霜冻 4→5s、重击 ×5→×6+穿透6、爆裂 3.5→4.5 格 ×1.6→×2.0、三连 +3→+4=5 车）；伤害探针实测裂变 8.8→**11.8**、三连 2→**5**。②🔴 **「表现力」的真因 = 附魔车毫无可见标识**（玩家看不到卡在生效 → 感觉没效果）：新增 `CombatImpact.DrawEnchantAura`（**overlay 通道**，本环境已验证可见）——稀有度色**旋转双环** + 呼吸脉冲 + 顶部三角标记，半径锚车辆权威半径、相位由 `game.elapsed` 派生（确定性非随机），接入 `Scene3DBackend` world-fx 段（shockRings 之前）。③**命中特效戏剧化**：爆炸改**扩散双环**（外橙+内白芯）+18 火花+6 烟+5 碎片+震屏 0.42；穿透/三连加扩散环；连锁双向 8+6 火花+环；新增 `enchant_split`/`enchant_homing` 两条反馈。验证：LSP 0 Error；`probe_enchant` **62/62**、`probe_encheff` **9/9**；真渲染零目标错误；**有/无附魔像素对比 6560 px 差异**（光环确实渲染，实图见琥珀色八边形环+三角标记）。教训 → AB-261/262。
  - ⚠️ **避雷 AB-261：「效果不够强/没有表现力」要分两层查——「数值强度」和「玩家能否看见它在生效」（v0.13.58 第三版）**：用户说「附魔卡还是不够强，而且缺乏特效表现力」，我第一反应是继续调数值；但**「表现力」的真因是附魔车完全没有视觉标识**——玩家打出一颗带附魔的车，屏幕上看不出它和普通车有任何区别，于是无论数值多高都「感觉没效果」。**做法**：接「效果不够强」类反馈时，除了数值，必须问一句「**玩家能不能看到这个效果正在发生？**」——给效果加**持续可见的标识**（本项目：附魔车旋转双环+稀有度色+顶部三角）往往比再调数值更能提升「强度感」。⚠️ 标识走**已验证可见的 overlay 通道**（本项目 3D 层离屏恒黑，见 AB-220），别加在 3D 层。
  - ⚠️ **避雷 AB-262：给「移动实体」画光环/标识要锚「该实体的权威半径」并覆盖「待发+飞行」两种状态（v0.13.58）**：附魔车可能停在弹弓待发位、也可能在飞行中，光环数据源要**同时收 `game.activeBall`（待发）和 `game.marbles` 里非 onSling 的飞行车**，否则「附在待发车上时看不见光环」。半径用 `project(x+r) - project(x)` 量（锚权威半径），别写死像素。相位用 `game.elapsed` 派生（确定性，非逐帧随机，同 v0.13.13）。
- 附记: offscreen-spawn-cap（2026-10-10，**屏外敌机超过 3 架时暂停生成队列**；不改展示版本）：
  - 用户「屏幕外飞机超过3架时暂停生成队列」——即屏幕上沿之外（尚未进入可见战场）的敌机达到 3 架就暂停生成，等它们下落进场再放下一架。
  - **「屏幕外」判据**：敌机**底边**仍在可见战场顶之上，即 `enemy.y + gridH*brickSize < -102`（与 `ResolveFleetOverlaps` 里既有的 `aOffscreen = ay + ah < -102` **同一口径**，不新增常量）。`StageCatalog.MAX_OFFSCREEN = 3`（与 `MAX_FLEET` 同处）。
  - **两处门控（缺一不可）**：①`SpawnNextNormalEnemy`——逐架放出的队列，屏外**在场**数 ≥3 就推迟本架（`pendingSpawn.timer = 0.3`）。②`UpdateWaveLogic` 的**波次启动**——屏外**在场数 + 本波待放数**（`pendingSpawn.remaining`）≥3 就不开新一波。⚠️ **第二条是本批真凶**：精英/护航/首领走 `SpawnSpecialEnemy`，**不经过** `pendingSpawn` 队列；只在 ① 加检查时，精英波会在「屏外 2 架 + 普通波还有几架没放」时插入，随后那几架放出就把屏外顶到 **4**（8 种子探针全部复现 `scout,scout,scout,elite_hammer`）。
  - ⚠️ **两处口径不同且不能统一**：① 只数**在场**（逐架放出一架停一次）；② 必须把 **`pendingSpawn.remaining`** 也算进去（待放的将来也会生成在屏外）。**把 `remaining` 也算进 ①会死锁**——整波一开始 `remaining=10` 永远 >3，一架都放不出。这是本批的关键区分。
  - **零新增顶层 local**（`Game.lua` 已 **199**，逼近 Lua 200 上限 AB-166）：两处计数循环都**内联在函数体内**，只复用 `StageCatalog.MAX_OFFSCREEN` 一个常量。
  - 验证：LSP workspace 27 文件 **0 Error**（1208 诊断）；规则探针 `probe_offscreen` **4/4 PASS**（常量=3 / 关15 屏外峰值=3 / 队列未死锁「屏外数曾降到 0」/ 关12 峰值=3）；**8 个固定布局种子**（`SC.BeginStage(15, seed)`）**全部峰值=3**（修前 8/8 都是 4）；真渲染冒烟 `probe_render`（菜单→选关→战斗→发射）零 `LoadChunk failed`/`overlay stage failed`/`Execute Lua function failed`/`VertexBuffer is empty`。官方多人 build + 预览上传 ✅。展示版本归并发会话（本批未动 BUILD_VERSION，当前常量 0.13.55）。
  - 边界：手机 FPS / 全 DPR / 用户审美未验收；**真机观感（屏外 3 架的出场节奏是否更舒适）需 Preview 目视**。
- 附记: trail-shape-rework（2026-10-10，拖尾形态重做：**宽度锚车体 + 抛弃直线 + 去周期化**；不改展示版本）：
  - 用户三点反馈：「有些拖尾比车都粗」「有些纹理循环太招笑」「你明明甚至都可以抛弃线性」——三条都是**形态层面**的真问题，不是调数值。
  - **① 太粗（真因量化）**：宽度基准一直挂在**碰撞半径** `radiusWorld = radius*WORLD_SCALE`（normal=0.36m），而车体真实半宽只有 `radiusWorld × 0.5965 × 0.63 ≈ 0.137m`——**上限比车体宽 2.6 倍**。实测 `ember` 主体 headW 0.56 → **1.47× 车体半宽**、`comet` 1.10×，正是「比车还粗」。修法：新增 `VEHICLE_HALF_FACTOR = VEHICLE_COLLISION_FILL*1.12/VEHICLE_PLANAR_RADIUS*0.675`（≈0.403），宽度基准改 `vHalf = radiusWorld × VEHICLE_HALF_FACTOR`；`headW/tailW` 全部改成**车体半宽的倍数**（1.0 = 与车同宽），所有层 `math.min(..., vHalf)`。修复后最宽的 `ember/normal` 0.1413 vs 车体半宽 0.1450（**97.4%**，此前 147%）。
  - **② 纹理循环招笑（真因）**：`dash` 样式是 `(i + flowOffset) % 3 == 0`——**每 3 段画 1 段**的机械重复，`flow=7` 又让它每秒跳 7 次；`bead` 每隔固定段数点一颗，也是规则重复。修法：**删掉 dash/flow/bead/head 四个轴**，改为**空间锚定的逐段明暗噪声** `flicker`（`segNoise(along) = flicker*sin(along*flickerFreq)`，相位沿弧长取、**不随时间跳**）+ `flickerFreq` 控颗粒。`dash` 样式 flicker 0.85/freq 17（碎光断续），`comet` 0.55/9（劈啪明灭），`ember` 0.30/5（烟状）。
  - **③ 抛弃直线（新增形态轴）**：新增 `waver/waverLen/waverDrift`——**中线横向正弦波动**，幅度 `vHalf*waver*(1-t)`（尾端更飘）、相位沿弧长 `cum/waverLen + trailPhase_*waverDrift`。**按弧长累加**（同屏各车、各帧一致），不是逐帧随机。`twin` 0.22（蛇形辫）、`ember` 0.34（烟状漂移）、`comet` 0.06（微摆），`ribbon/neon/dash` 保持笔直（0）。
  - **六样式现在的机制签名（两两不重复）**：ribbon=中性基准；comet=taper0.55+bulge1.1+**flicker0.55**；neon=hue0.65+**twist0.40**；dash=taper1.3+**flicker0.85/freq17**；twin=twin1+railTaper0.30+**waver0.22**；ember=taper1.7+**waver0.34**+pulse0.34+flicker0.30。
  - **2D 预览同步**（`MetaUI.DrawTrailPreview`）：改用同一套新轴（waver/flicker、去 dash/bead/head），segs 26→40（更平滑的波动），沿弧长取相位与 3D 同式。
  - 验证：**`probe_trailwidth` ALL PASS（24 组）**（每样式所有层 ≤ **车体半宽**，`ember/normal` 97.4%；`giant/speed` 比 1.67）；**`probe_trailstyles` ALL PASS**（6 样式机制轴齐全、签名两两不重复、ribbon 中性、未知样式回退）；**`probe_trailhead` ALL PASS**（worst 0.0570，前沿仍贴车）；真渲染冒烟 `probe_render` 零 `overlay stage failed`/`Execute Lua function failed`/`LoadChunk failed`/`VertexBuffer is empty`、真实进战斗并发射；LSP workspace **0 Error**（27 文件 1204 诊断）；官方多人 build + 预览上传 ✅。展示版本归并发会话（本批未动 BUILD_VERSION）。
  - ⚠️ **避雷 AB-244：特效「宽度上限」必须锚**宿主真实尺寸**，不能用碰撞半径（trail-shape-rework，用户点名「比车都粗」）**：碰撞圆是**为了手感/命中留的余量**，通常远大于视觉本体——本项目碰撞半径 0.36m 而车体半宽仅 0.137m（2.6 倍）。用碰撞半径当尾迹上限，看着「没超上限」实则比车宽 47%。**做法**：先量出「视觉本体真实半宽 / 碰撞半径」的比值（本项目 `VEHICLE_HALF_FACTOR≈0.403`），宽度基准乘它；**探针的 cap 也要改成同一比值**，否则探针会继续报 PASS（本批探针原用碰撞半径，改车体半宽后才暴露 147%）。
  - ⚠️ **避雷 AB-245：周期性图案（每 N 段画 1 段 / 每隔 N 点一颗）会读成「循环太招笑」，改用**空间锚定的噪声**（trail-shape-rework，用户点名）**：`i % dash == 0` 这类规则重复 + 时间驱动的相位平移（`floor(t*speed)`）会产生**肉眼可数的节拍**。替代：`flicker * sin(along * freq)`——相位取**沿弧长**（`along` 按段长累加），**不随时间跳**；再叠 `trailPhase_*drift` 做缓慢漂移即可。**关键区别**：噪声的相位来自几何位置（每段不同、不重复），不是来自段序号取模。
  - ⚠️ **避雷 AB-246：「抛弃线性」= 给中线加**沿弧长**的横向波动（trail-shape-rework）**：一条光带「线性」的本质是**中线是直线**。做法：在段法线方向加 `off = vHalf*waver*(1-t)*sin(along/waverLen + phase)`，用**波动后的端点**重新算段方向与法线（`ca/cb` 替代原 `a/b`），宽度仍垂直于波动后的线。⚠️ 幅度要 `×(1-t)`（贴车端为 0，尾端最飘）——否则车头会被波动推离车体（同 AB-236 的「锚定贴物体那端」）。⚠️ 相位按 `along` 累加，禁止逐帧随机（会抖）。

- 附记: digit-arttext-regen（2026-10-10，**重出 10 个关卡数字图标 + 3 张糊掉的艺术字**；不改展示版本）：
  - 用户「10个数字图标重新生成，很多其他艺术字装载出错」。**两件事分开处理**——①10 个数字图标重出；②「艺术字装载出错」实为**部分字标字形糊**（AI 生中文字没画清），不是加载失败。
  - **诊断（关键）**：真渲染探针日志 `[ArtText] pixel titles loaded=8/8` + `[DigitFont] pixel digits loaded=10/10` —— **装载本身 100% 成功**，8 张艺术字 + 10 张数字都在。把 8 张字标拼成放大图目视，定位真凶：`ui_tt_daily`（今日福利）/ `ui_tt_menu`（返回主菜单）/ `ui_tt_resume`（继续战斗）**字形糊成一团**（core/outline 比仅 0.09–0.30，其它清晰张 0.28–0.44），游戏内渲染就是乱码块。**「装载出错」= 字标图本身画坏了，不是运行时加载问题**（AB-242）。
  - **重出数字（0718 管线）**：`batch_generate_images`(nanobanana, `transparent:true`, 384×512) 出 10 个数字草案 → 手写后处理：alpha 二值化 128 → bbox → **按字形高度归一**（`GLYPH_H=26`，**不是**按 bbox 等比——数字宽高比不同，等比会让「1」和「8」高低不齐，AB-236 同族）→ **4-邻域腐蚀**得白芯、原掩码减芯得近黑轮廓（两色 `(255,255,255)` + `(16,19,31)`）→ 居中贴 24×32 母版（字形顶 y=2）。**10 张全部 2 色、字形高 26 统一**。新宽度表 `DIGIT_W = {19,16,17,19,17,19,18,19,17,17}` 已同步进 `ui/DigitFont.lua`。
  - **重出 3 张糊字标**：各出 a/b 两版草案（a=白芯+深蓝描边、b=白粗体+黑描边），选 **b 版**（字形方正清晰、白芯+黑描边，正是两色母版要的）。后处理：alpha 二值化 → bbox → **按显示高度归一**（daily 24 / menu 22 / resume 26）→ 按亮度阈值（`lum≥150`）分成白芯/近黑轮廓两色 → 存回同名 `ui_tt_{daily,menu,resume}.png`（**沿用旧文件名与 .meta uuid**，零路径/uuid 风险）。三张新 core/outline 比 ~0.47–0.50（旧 resume 仅 0.09）。
  - **验证**：LSP workspace **0 Error**（27 文件 1195 诊断）；真渲染探针（真实 `ClientMain.Start` 路径）——`[ArtText] loaded=8/8` + `[DigitFont] loaded=10/10`；选关 / 首页 / 暂停三屏 exit0、零 `overlay stage failed`/`Execute Lua function failed`/`LoadChunk failed`/`VertexBuffer is empty`；裁剪设计画布**实图目视**——选关「1」粗壮清晰压在青色六边形上、首页「今日福利/养成收藏」分区标题清晰艺术字、暂停「继续战斗/返回主菜单」不再糊。官方多人 build + 预览上传 ✅。展示版本归并发会话（本批未动 BUILD_VERSION，当前常量 0.13.55）。
  - 边界：手机 FPS / 全 DPR / 用户审美未验收；**真机观感（新数字/字标清晰度）需 Preview 目视**。旧数字/字标 PNG 已覆盖（git 显示为 M），草案全部移出 assets 到 `/home/Maker/{digit_v2,tt_v2}/drafts`。
- 附记: stagemap-star（2026-10-09，选关界面**风格重做**为「星座星图」；不改展示版本）：
  - 用户一句「选关界面太难看了，重做风格」——上一版是「蜿蜒光带 + 圆钮」，被判定难看。**换风格不是调参**：整个视觉隐喻从「爬塔路」换成**太空星图**（与游戏深空主题一致），节点/连线/底图全部换掉。
  - **新隐喻（只改 `ui/StageSelect.lua` 绘制层 + 命中形状）**：①**六边形关卡芯片**（`HexPath/HexFill/HexStroke`，尖角朝上下）取代圆钮——已解锁=亮色环（有星金/无星青）+ 底盘 + 内环 + 顶面受光；**当前最新关=整片亮色实心底 + 深色关号**（全屏最亮焦点）+ 随共享相位脉冲的外环；未解锁=暗六边形 + 程序化小锁 + 压暗关号。②**星座连线**（`DrawLink`）取代蜿蜒光带——相邻关之间一条**直线**（外发光 + 主线 + 白芯三层），已解锁段亮青、延伸段暗青；线段端点沿连线方向**内缩 `NodeHalfW()`** 以免压住芯片。③**星空底**（`DrawStarfield`）——确定性散布的星点（**合并单一路径**，AB-216），随 `scrollY_` **视差滚动**，营造「航行」。④三星从圆点改**菱形**（与六边形/科技语言一致）。
  - **命中必须与绘制同形**：圆形命中换成**六边形判定**（尖角朝上下）——`|dy| ≤ hr` 且 `(dy·0.5 + |dx|·0.866) ≤ hr`（`hr = NODE_R+3`）。**通用规则**：把节点形状从圆改成多边形时，命中判定要一起改，否则「看着是六边形、点在角上没反应」。
  - **删死代码**：`PathPoints`/`StrokePath`（Catmull-Rom 蜿蜒路径）整段删除——重做风格后无调用点。保留 `NodeYAt`（未来关幽灵节点仍需要，见 AB-237）。
  - **验证**：LSP workspace **0 Error**；真渲染探针 `probe_ui`(stage_select) 与 `probe_stage5`（预置 5 关成绩→maxStage=6）**exit0、零 `overlay stage failed`/`Execute Lua function failed`**；裁剪设计画布后**实图目视**——六边形芯片（金/青环、菱形星）、星座连线、星空底、当前关实心焦点均清晰可辨，明显优于上一版圆钮+光带。官方多人 build + 预览上传 ✅。展示版本归并发会话（本批未动 BUILD_VERSION）。
  - 边界：手机 FPS（星点/连线调用数上升，已合并路径）/ 全 DPR / 用户审美未验收；**真机观感需 Preview 目视**。
- 附记: darktech-skill-fixup（2026-10-10，用户指出反哺**漏了新效果**；纯文档）：
  - 用户「新版darktech不包含你这些反光六边形呀异色呀等各种酷炫效果吗」→ 核对确认**确实漏了**：反哺进去的是较早一版（商业化/拖尾/选关），而项目后来长出的新效果都没进，且 `elements.md` §14.8「蜿蜒路径」**已过时**（选关早已重做成星图）。**根因**：反哺时按记忆里较早的版本号取材，没核对「当前代码 vs skill 描述」。
  - **补/修 5 处**：①`elements.md` §14.8 **重写**为星图（六边形芯片尖角朝上下 + **顶面受光**「斜切金属」反光 + 星座连线**三层**外发光/主线/白芯 + **视差星空** + 菱形星 + 六边形命中判定），并显式标注「旧版已被用户否决」；②新增 §14.11 **两色母版乘法染色的塌陷约束**（深 tint → 白芯与轮廓两级都塌成黑疙瘩）；③新增 §14.12 **拖尾机制轴**（`hue` 沿长度色相游移 / `waver` 非直线中线波动 / `flicker` 空间锚定噪声替代周期图案 / `twist` 真三维螺旋 + 宽度必须锚**车体真实半宽**而非碰撞半径）；④`screens.md` 新增 **§12 星图配方**（可直接复用），§1 蜿蜒路径标注「已被 §12 取代」并重编号；⑤**修正 `architecture.md` §9 与 `pipeline.md` §6.1 的错误建议**——原文写着「乘 `C.ink` → 深字（配青/绿/金实心按钮）」，**这正是「黑疙瘩」的成因**，改为「亮底要深色字用暗色铭牌 + 亮 tint」。
  - 提交 `75accfa`。纯文档。⚠️ **教训**：反哺/写规范时要**以当前代码为准**核对，别照记忆里的旧版本——本项目 §14.8 就这样带着一个被否决的旧设计进了 skill。
- 附记: darktech-adaptation（2026-10-09，适配与输入规范补齐；承接反哺，纯文档）：
  - 用户问「还有什么值得总结加入的？」→ 盘点出**界面之外、每个项目都会踩**的一层尚未覆盖，新增 **`references/adaptation.md`（220 行）**：①**三层坐标**（物理屏幕 / 设计 / 玩法）别混——UI 命中用设计坐标、玩法用玩法坐标、画布过滤用物理坐标；玩法坐标 ≠ 设计坐标（46° 斜俯视有投影偏移缩放，须用 `WorldToScreenPoint` 标定，且相机位移后刷新）；②**画布外过滤**（按下过滤、移动/抬起允许跨出）+ 命中容差 26/22；③**双命中空间**（状态优先于命中；模态态 Move/Up 早退不透传玩法）；④**3D+2D 共用 CONTAIN 投影**（9:16 铁律 + 高 DPI 测量文字前 `nvgResetTransform`）；⑤**文字三级降级**（降字号 → 分两行 → **永不截断**；CJK 按字符切不按字节）；⑥**数值格式化契约**（`%d` 遇浮点**崩帧**，显示前一律 `math.floor`；引入倍率后所有出口都要过）；⑦**玩家可见文案纪律**（中文优先 / 变现去直白 / 不写机制说明与键盘指引 / 只改字符串不动 action）；⑧**只读契约**（渲染层不写权威状态）。
  - 接入 `SKILL.md`（工作流指引 + 参考列表）+ `elements.md` 文件清单。纯加法。提交 `0241355`。
- 附记: darktech-screens（2026-10-09，各种独有界面与绘制实现通用化；承接 darktech-skill-feedback，纯文档）：
  - 用户追加「各种独有界面与绘制实现都要通用化加进去」→ 新增 **`references/screens.md`（496 行）**，把本项目**每一种独有界面与绘制实现**提炼成**参数化配方**（换尺寸/主题/数据即可用）：①蜿蜒路径地图（关卡/章节选择：三层叠画路径 + 果冻钮 + 倒置列表滚动范围要从布局公式推导）；②爬塔式矩阵（技能树/天赋树：线路身份色 × 状态色**正交**、常驻滚动条、拖拽与点击分离）；③滞后血条（`damageHold` 保持 + 追平缓动）；④程序化展台（椭圆接触影几何与 paint 同变换）；⑤星级结算过渡（**档位分表** + `seg` 时间轴 + `WindowVisible` 渲染命中同源、结算窗延迟弹出）；⑥进关倒计时（用标志位而非新增 gameState）；⑦分区标题 + 卡片厚度四件套；⑧三选一升级卡（语义分隔符拆段 + 像素宽度贪心 + 容器跟内容定高）；⑨屏幕插件注册；⑩像素贴图；⑪通用绘制原语表；⑫参数速查表（换项目改哪些值）。
  - 接入 `SKILL.md`（两处：工作流指引 + 参考列表）+ `elements.md`（文件清单 + §14 交叉引用）。纯加法。
  - 提交 `1effef3`。纯文档，无需 build/预览。展示版本归并发会话。
- 附记: darktech-skill-feedback（2026-10-09，用本项目独有做法反哺 dark-tech skill；纯文档、不改游戏代码/展示版本）：
  - 用户要求「用本游戏所有的独有东西对 darktech skill 进行反哺」，并追加「旧的实验室/培养舱项目的部分也要保留」——即**只做加法**，旧 `elements.md`（培养舱项目）一字不动。
  - **新增 `references/architecture.md`（507 行）**：本项目最独特的资产是**工程架构**，不是视觉母题。13 个界面共用一套 raw NanoVG 工艺跑 50+ 版本，沉淀出：①共享表面原语单模块（`ui/PremiumSurface` 的 Panel/Window/Button/Background/Stage，改一处全屏生效）；②依赖注入（`Init(deps)`，前端不 require 后端、不自定义颜色）；③**绘制与命中同源**（每屏一组不画图的几何函数，绘制与命中都从它取）；④**窗口动效 = 绘制缩放 + 命中逆变换共用同一函数**（`WindowMotion`/`WindowInput`，入场 0.32s 弹性 0.91→1.03→1.0、退场 0.18s）；⑤交互反馈三段式（指针全局喂入 + 控件显式登记 `GetControlFx(rect,enabled)` + 平滑缓动）；⑥单一动画相位源；⑦**屏幕插件注册** `RegisterScreen`（后端零改动接入新屏）；⑧**Lua 顶层 local 200 上限**（本项目后端 197/200，超限 `LoadChunk failed` 全屏黑、LSP/build 都不查）；⑨贴图模块（两色母版 + `nvgImagePatternTinted` 乘法染色 + 懒加载 + 缺图回退）；⑩验收纪律（渲染无报错 ≠ 画出来了）。
  - **追加章节（全部加法）**：`tokens.md` 补商业化语义色（看广告绿/免费青/付费金 + 暖金付费入口 + 文字描边按亮度选色）；`nanovg.md` 补批量绘制性能契约（合并单一路径 + 面积自适应步长 + 全屏底纹层数克制，来自 AB-216 命令缓冲溢出）；`elements.md` 新增 **§14 商业化/弹射对战界面元素**（三色语义/变现闭环三段式/分区标题/自适应卡片/战斗 HUD/程序化展台/蜿蜒关卡地图/过渡动画/像素数字与艺术字，标注为「第二来源项目」，与旧培养舱项目并存）；`atmosphere.md`/`pipeline.md` 各补一段本项目落地实例；`SKILL.md` 接入 architecture.md 指引 + 验收清单补 3 条。
  - 提交 `6506f40`（只暂存 `.agent/skills/dark-tech-game-editor-ui/`，不碰并发会话的 scripts/ 改动）。纯文档，无需 build/预览。旧内容经 `git diff` 核对为**纯新增**（6 文件 +319/-2，-2 是 `elements.md` 两处替换行，无内容删除）。
- 附记: arttext-buttons（2026-10-09，按钮/选项卡标题改 AI 艺术字 + 选关界面统一化；不改展示版本）：
  - 用户「我还想要更贵更贵。是不是可以大量使用艺术字生成…生成按钮/选项卡的标题。还要有更多更贵的改造」，随后追加「另外我想要更酷炫更统一的选关界面UI」（附现有选关截图）。两次需求一并做。
  - **艺术字素材（走 `0718-pixelimage-aigc` 管线）**：`batch_generate_images`(nanobanana, **transparent:true**, 1376×768) 出 8 个标题草案 → 手写后处理（**内容 bbox 裁切 → 按目标显示高度等比缩 → alpha 二值化 128 → 压成「白芯 + 近黑轮廓」两色**）→ `assets/image/ui_tt_{startbattle,daily,collect,vehicle,trail,resume,menu,stage}.png` + `.meta`（22hex uuid，全库验重）。**母版高度 = 运行时显示高度**（startbattle 38 / daily·collect 24 / vehicle·trail 19 / resume 26 / menu 22 / stage 28），**1× 最近邻**，宽度随字数浮动逐图记宽。
  - **新模块 `scripts/ui/ArtText.lua`**（零新增 Scene3DBackend 顶层 local，AB-166）：懒加载（首次 Draw 才 `nvgCreateImage(ctx,…,NVG_IMAGE_NEAREST)`，与 `ui/DigitFont.lua` 同契约，ctx 即进程级单例 vg）；`Has/Width/Height/Draw/DrawCentered`；**全部可选资源**——缺图返回 false，调用方回退 zpix 文本，绝不影响布局/启动。
  - **两色可染色设计**：母版是「白(255) + 近黑(16,19,31)」两色 → 运行时 `nvgImagePatternTinted` **乘法染色**，一份素材同时适配「深底亮字」和「亮底深字」。
  - 🔴 **AB-238（本轮实测，价值最高）：青/亮底上不能用深色 tint 艺术字**——双色母版乘深色后「白芯」与「近黑轮廓」**两级都塌成黑**，整块读成**黑疙瘩**（用户原话「艺术字都没做好！还都异常变色？！」）。**正确做法**：亮底按钮上给艺术字**垫一块暗色铭牌**（`{C.ink,140}` 圆角 + 青描边），艺术字用**亮色 tint**（青/白），既保留按钮色语义、又让两级明暗完整显出来。深底处（分区标题/商店标签/返回主菜单）直接用亮 tint 即可，无需铭牌。**乘法染色只对「乘完仍保留两级明暗差」的 tint 有效**——tint 越接近白/单色越安全，越接近黑越会塌。
  - **接入点**：`Scene3DBackend` 主 CTA「开始战斗」+ 暂停「继续战斗」「返回主菜单」（带铭牌 / 图标右侧）；`MetaUI.SectionHeader` 加可选 `artKey`（「今日福利」「养成收藏」，深底亮字，并用**同一 measure 分支**算右侧断线起点）；商店分页标签「车型外观」「拖尾样式」（金/暗 tint）；`ui/StageSelect` 面板主标题「选择关卡」。**全部保留 zpix 回退**，命中几何/字号语义不变。
  - **选关统一化（`ui/StageSelect`，只改绘制层）**：①内容区补**仪器边框**（四角折线 + 极淡网格 + 顶/底刻度带），与其余面板同语言；②**未来关幽灵节点**——在路径延长线画 6 个未解锁占位节点 + 路径延伸段，把内容区补满、让爬塔可见更长（**纯装饰、不参与命中**，极低 alpha 避免与「当前最新关」抢焦点）；③**流动光点**沿路径按共享 `D.anim()` 相位前进（确定性非随机，给静态地图「在运行」感）。
  - ⚠️ **AB-237：`NodeCenter(L, stage)` 只对 1..maxStage 有效——画「未来关/延长线」要另算 y**（本轮踩到，peer 也复现）：`GetLayout` 的 `nodeY` 表只填了 `1..maxStage`，幽灵节点循环调 `NodeCenter(L, maxStage+k)` 得到 `nil` → `attempt to compare number with nil`，整段 stage 被 pcall 吞掉（选关白屏）。修法：新增 `NodeYAt(L, stage)` 用同一公式直接算任意关号圆心 y（含滚动与居中偏移），幽灵节点/延长线走它；**真实节点布局（nodeY 1..maxStage）不动**。**通用规则**：任何「超出已生成数据范围」的循环（未来项、延长线、占位）都不要复用只覆盖已生成范围的查表函数。
  - **验证**：LSP workspace **0 Error**；真渲染探针 home / stage_select / shop / pause **四屏 exit0、零 `overlay stage failed`/`Execute Lua function failed`**；裁剪设计画布后**实图目视**——首页 CTA「开始战斗」青字清晰不糊、「今日福利/养成收藏」分区标题为艺术字、商店分页标签金/暗艺术字、暂停两按钮为艺术字且不与三角/图标重叠、选关补满内容区且幽灵节点明显弱于真实节点。官方多人 build + 预览上传 ✅（构建日志 `[ArtText] pixel titles loaded=8/8`）。展示版本归并发会话（本批未动 BUILD_VERSION，当前常量 0.13.55）。
  - 边界：手机 FPS / 全 DPR / 用户审美未验收；**真机观感（艺术字清晰度、幽灵节点密度、流动光点节奏）需 Preview 目视**。
- 附记: stage-scroll-fix（2026-10-09，选关拖不动已修；XHR 报告仍待请求证据，不改展示版本）：
  - 用户上报 `Error processing XMLHttpRequest response: {}` 共 159 次，并报「关卡列表拖不动」。分开处理，不能用滚动修复代表网络错误已消失。
  - 滚动真因：倒置塔布局 `nodeY = bottom - (stage-1)*ROW_STEP + scrollY_` 需要正偏移，旧 `ClampScroll` 却钳到 `[-MaxScroll,0]`，把 `FocusLatest` 与下拖的正偏移归零。只改 `ui/StageSelect.lua`：范围改 `[0,MaxScroll]`、装饰 seed 同步正号，保留布局、鼠标/触摸所有权和松手点击链。第 20 关定位 Y 从 -1706 修为 234（视口 164..872）。代码独立提交 `0838fc8`。
  - 验证：规则探针 140/140 断言、真实输入 12/12（鼠标、TouchID=0、第二指不抢、不误开关、取消、轻点第 2 关）通过；真实 Draw 分别消费 15..20 与 1..6 关，战斗过 intro/刷敌后真实飞行通过，目标 Lua/overlay/LoadChunk/空顶点错误 0。LSP 27 文件 0 Error，官方多人 build 与预览上传成功。手机全 DPR/截图像素与美术观感未验收；没有实际截图落盘，不把 Draw 调用记录写成目视通过。
  - XHR 只读核验：sources 仅 engine/engine-res、adopt 空，未见历史 official-res 固定引用链；已读平台日志含成功的云存档/高分/余额操作，但缺 HTTP/宿主通道，报告没有 URL/状态/响应/栈。`0d39599c/62ae71fb` 未在本地游戏构建与 Git 找到，**随后公开引擎清单核验找到完全相同的版本元数据**：`src/engine/stable.json` → 引擎 `1.33.2` / 客户端清单 `d2e42cce` → `version.json` 中 `binary_hash=0d39599c, commit_hash=62ae71fb, branch=HEAD`；这组哈希对应引擎信息，不能据此判定旧游戏包。平台时间可能是 UTC 与北京时间差异，不能把相差 8 小时的日志排除。没有证实自动重试风暴，未禁云、未屏蔽日志，**159 次 XHR 尚未定位或证明消除**。
  - XHR 增量核查（同日，只读、不改代码）：运行索引由此前 264 条变为当前 86 条，窗口为 UTC 11:50:43..11:53:43（UTC+8 19:50:43..19:53:43），不能按追加行号读取增量，也未保留原报错时段。只有客户端/引擎/服务端脚本渠道，没有宿主 HTTP 字段或已落盘反馈。限定本地检索与公开 `index.min.js` / 正式 `UrhoXRuntime.js` / gzip 解压后 WASM 检索均未找到精确报错实现；资源 data 只读了索引，未扫描全包。预览桥接会把普通对象 JSON.stringify，但同 realm Error 保留 stack/message，不能单凭 `{}` 推断网络错误或 JSON 解析错误。下一步依赖原报错会话一条脱敏请求级证据（路径/方法/状态/响应类型/原始异常栈），不需要存档、Cookie 或 Authorization；本轮无新修复、不改展示版本，POST-3 判定跳过（新证据仅属本项目，通用 HTTP 证据纪律已记录）。
  - 合并复验首轮仅同步 MetaUI/Backend、漏拷新增 `ui.ArtText`，模块加载失败并超时，属于探针自身失败，不计 PASS；补齐完整 scripts 后发现并发选关绘制 `NodeCenter(L,stage>maxStage)` 的 `cy=nil`，导致 `overlay stage failed`。对应会话已用 `NodeYAt` 计算幽灵节点坐标；修后完整冻结快照重跑 140 规则/12 输入/两端真实 Draw/intro 后飞行全部 PASS，五进程 exit0、目标错误 0。原失败日志保留，最终 LSP 27 文件 0 Error、官方多人 build 与预览上传成功；此回归不作为并发美术观感验收。
  - POST-1 执行状态与边界记录，persona 判定跳过（具体错误反馈无新增跨项目用户特征）；POST-2 只提交本人 hunk 与附记；POST-3 执行倒置列表滚动符号与 HTTP 证据纪律，随行 persona/preferences 判定跳过（无新偏好）。并发艺术字/选关美化/关卡过渡保留，由对应会话验收。

- 附记: trail-follow-fix（2026-10-09，修「尾焰起点跟不上车且粗细没有跟随车辆」；不改展示版本）：
  - 用户报「尾焰起点跟不上车且粗细没有跟随车辆」——两句是**两个独立真因**，都在 v2 拖尾（层叠/扭转/光珠/爆闪）之后暴露。
  - **① 起点跟不上车（真因）**：光带只画到最新采样点 `samples[n]`，而它永远落后一整个采样间隔（0.016s）；且**断续样式 `dash=3` 只画每第 3 段**，车头那一段常常不在采样点上 → 光带前沿停在离车 **1.2 世界单位（≈67px）** 处（探针实测 `dash/speed gap=1.2175`）。修法两处：**(a) 前沿锚定车辆当前车尾**——`track.head`（存了却从未消费，v0.13.10 注释写了「末段接车辆当前位置」但代码没实现）追加为最后一点，循环改 `for i=1,n`、`b = (i<n) and samples[i+1] or tailPt`、`t=(i-1)/n`；**(b) 头段 `i==n` 永远画**，不受断续图案影响。修复后探针 **worst 1.2175 → 0.0726（≈4px）**。
  - **② 粗细没跟随车辆（真因）**：`glow` 倍率最大 2.8 × `headW` 0.56 = **1.57× 碰撞半径**，光带比车体还宽。修法：所有层的半宽统一钳到 `maxHalf = radius*WORLD_SCALE`（柔光 `min(w*glow,maxHalf)`、爆闪 `min(w*(1+head),maxHalf)`、光珠 `min(halfHead*beadR,maxHalf)`、双轨柔光 `min(railW*glow,maxHalf*0.5)`）；`ember.glow` 2.80→1.45（否则柔光被钳成与主体等宽、失去层次）。
  - **③ 扭转锚点订正**：v2 的 `TwistedNormal` 让扭转角 `twist*(i-1)` **在车头取最大**，而 46° 斜俯视下 **z 投影成屏幕 Y** → 光带头部被推出车体（也贡献了「跟不上车」）。改为**锚定车头** `twistAngle(k)=twist*max(0,n-k)`（车头环恒 0，螺旋只向尾端展开）；2D 预览的 `wob` 同步改为车头位移为 0（与 3D 同向）。
  - 验证：**`probe_trailhead` ALL PASS**（`worst=0.0726`，6 样式 × 4 弹种，前沿贴车）；**`probe_trailwidth` ALL PASS（24 组）**（每样式所有层半宽 ≤ 权威半径，`giant/speed` 半宽比 **1.67** 证明随 radius 缩放）；规则探针 `probe_trailstyles` ALL PASS；真渲染冒烟 `probe_render` 零 `overlay stage failed`/`Execute Lua function failed`/`LoadChunk failed`/`VertexBuffer is empty`、真实进战斗并发射；LSP workspace **0 Error**（27 文件 1146 诊断）；官方多人 build + 预览上传 ✅。展示版本归并发会话（本批未动 BUILD_VERSION）。
  - ⚠️ **避雷 AB-234：拖尾「前沿贴车」是两个独立约束的乘积——「画到车尾」+「头段不受断续图案影响」（trail-follow-fix）**：`track.head` 早就存了却从未被消费（注释写了、代码没写），而断续样式让「前沿贴车」这件事**在图案层面**也可能失效。修「跟不上车」要同时查这两条：①几何末端是否真的接到实时位置（`b = (i<n) and samples[i+1] or tailPt`）；②断续/流动图案是否把头段也过滤掉了（`i == n or (...)%dash==0`）。**探针必须量「顶点到车尾的最小距离」**（本项目 `DebugTrailHeadGap`），只看「有没有顶点」永远发现不了这类脱节。
  - ⚠️ **避雷 AB-235：给「光带」加层（柔光/爆闪/光珠）时，每层都要独立受「不宽于车体」约束（trail-follow-fix）**：「拖尾比例契约」不是只管主体宽度——`glow`/`head`/`beadR` 每个倍率都会乘出更宽的一层，漏钳任何一层都会出现「光晕比车宽」。做法：定义 `maxHalf = radius*WORLD_SCALE` 后**逐层 `math.min(..., maxHalf)`**；倍率大到被钳平（本项目 ember 2.8）就回调倍率本身，别让钳制把层次压没。验收探针要**遍历「样式 × 弹种」全矩阵**断言每层 ≤ 半径，并断言宽度随 radius 缩放（否则可能只是常数）。
  - ⚠️ **避雷 AB-236：46° 斜俯视下任何「沿长度线性变化」的 z 位移，都会让光带一端在屏幕上脱离物体（trail-follow-fix）**：v2 把截面绕切线扭转做成真三维（法线带 z 分量），但扭转角**锚定错了端**——在车头取最大 → 车头被 z 位移推出车体。**规则**：贴 3D 物体的特效，任何「沿弧长增长的 z/深度变化」必须**锚定在贴物体的那一端（=0）**，变化只朝远离物体的一侧展开。2D 预览要复刻同一锚点（否则「预览对、实机错」）。

- 附记: ui-adaptability-fix（2026-10-09，用户五张截图点名「精美程度和 UI 适应性不满意」；不改展示版本）：
  - 用户给了五张实机截图（天赋树 / 首页 / 选关 / 战斗 / 暂停），**逐屏读图**后定位四处**真布局错位**（不是审美分歧，是 bug），全部修好并实图复验。
  - **天赋树（最严重）**：血量规则说明 `HP_RULE_TEXT` 画在 `y+146`、线路名表头画在 `y+164`——**两行只差 18px、字号 13 行高约 17**，肉眼读成「两行字糊在一块」（截图确认）。修法：头部拆成**标题栏(48) / 规则行(y+52) / 表头带(y+66, 高 24)** 三段，内容区下移到 `y+96`；表头带补独立栏头底（`C.rail` alpha 150 + 顶亮线）。
  - **选关（适应性）**：`maxStage=5` 时内容高 976 < 可视区 708×？ → 实际是**内容矮于可视区却仍贴底**，上方留一大片空白（截图里塔只在中间偏下）。修法：`freeSpace = content.h - contentH`，`freeSpace>0` 时整座塔**垂直居中**（`centerOffset = freeSpace*0.5`）；`FocusLatest` 改为 `scrollY_=0` 后读布局里的 `nodeY[maxStage]` 反算（自动含居中偏移）。
  - **战斗**：新手「向下拖拽 松手发射」文案原锚在 `bottomY + handH - 8`（手势图底部），**同时压住手势图与下方扣血红线**（截图里红线穿过文字）。修法：移到动画**上方** `topY - 24`。
  - **暂停**：继续战斗按钮的播放三角固定画在 `x+58..74`，而文字用 `x + w*0.5 + 14` 居中 → **文字压住三角**（截图确认「继续战斗」的「继」盖住三角）。修法：三角移到左半区 `x + w*0.30` 居中、文字移到 `x + w*0.60` 居中。
  - **天赋树质感**：已解锁节点原**统一染青**（`fill=C.widget` 但环色仍取 lane 色——实为环色被 owned 分支覆盖丢失），六列读起来一片青、丢掉线路身份。修法：已解锁**保留线路色亮环** + 叠一层内亮环（只加不减）。
  - **验证**：LSP workspace 27 文件 **0 Error**；几何探针 `probe_layout` **8/8 PASS**（头部三段不重叠、maxStage 1–4 可居中、6 需滚动）；真渲染探针 `probe_ui`（talent / stage_select）与 `probe_pause` 三屏 **exit0、零 `overlay stage failed`/`Execute Lua function failed`/`LoadChunk failed`/`VertexBuffer is empty`**；设计画布裁剪后**实图目视**——天赋树规则行与表头已分离、选关塔垂直居中且路径更完整、暂停三角与文字不再重叠。官方多人 build + 预览上传 ✅。展示版本归并发会话（本批未动 BUILD_VERSION，当前常量 0.13.55）。
  - 边界：手机 FPS / 全 DPR / 用户审美未验收；**离屏 `-screenshot-frame` 本环境按 AB-220 不可靠**，但本批裁剪后画面确为目标屏（可见天赋树/选关/暂停各自内容），故本次实图可视作有效证据。
- 附记: brick-hit-flash（2026-10-09，受伤未碎的砖块改为**方块整体极短闪白**；不改展示版本）：
  - 用户「飞机方块受伤但没丝网碎裂的要有极短受伤闪烁」——即**挨打但没被打掉**的砖块要有一下闪。
  - **关键发现（省掉整条新链路）**：这个信号**早就存在**——`DamageBrick` 未击碎分支走 `Emit("brick_hit", {destroyed=false})` → `Presentation.brickSpark` 写 `hitFlashes[key]=0.12`（**击碎与未碎都写**）→ `ui/CombatImpact.DrawHits` 消费。**问题不是「没有反馈」，而是反馈形状错了**：旧 `DrawHits` 画的是一个**白色十字标记**（`+`），读不出「方块挨了一下」。修法=**只改绘制形状**，不动规则层/表现层。
  - **改动（仅 `scripts/ui/CombatImpact.lua` 的 `DrawHits`）**：把十字改成**砖块世界矩形 → 屏幕矩形**（投影是逐轴仿射，取两角点即可）的**暖白实心闪 + 白亮边**，`inset 6%`、圆角 `min(w,h)*0.18`；闪 alpha `180*flash`、亮边 `1.0+1.4*flash`。**暖白=撞击发热**，与「冻结」的冷白区分。寿命常数提为模块 local `HIT_FLASH_SECONDS=0.12`（与 `Presentation` 写入值同源，注释互指）。仍只对 `brick.alive` 的格闪——击碎那格走碎裂特效，不叠闪白；找不到敌机/过期 flash 都不画。
  - **验证**：LSP workspace 26 文件 **0 Error**（1124 诊断）；**记录式 mock NVG 探针** `probe_hitflash` **11/11 PASS**（受伤未碎→画方块 2 次 roundedRect / 宽高实测 14.784×13.552 / 半衰 alpha<满亮 / 击碎格不画 / 过期不画 / 找不到敌机不崩 / 0.12 与 0.24 均 clamp 满亮 180 / 亮边宽 2.4）；真渲染冒烟 `probe_render`（菜单→选关→战斗→发射）零 `LoadChunk failed`/`overlay stage failed`/`Execute Lua function failed`/`VertexBuffer is empty`。官方多人 build + 预览上传 ✅。展示版本归并发会话（本批未动 BUILD_VERSION，当前常量 0.13.55）。
  - 边界：**离屏截图本环境不可靠（AB-220），未做像素取证**——用 mock 探针断言几何+alpha 代替；**真机观感（闪得够不够短、暖白是否合适）待 Preview 目视**。手机 FPS / 全 DPR / 用户审美未验收。
- 附记: spawn-ramp-hp-cap（2026-10-09，前期出怪间隔 ×3 + 本关按出场序号封顶血量；不改展示版本）：
  - 用户「前期的连续生成飞机间隔时长放三倍，到最后三波是现在的情况，中间平滑过渡。第一个飞机最多一血，第二个最多3血，第三个最多五血这样顺延这个相知进行平衡协助」。两件事：①**同波逐架生成的间隔前期放慢 3 倍**；②**本关内按出场序号给普通敌机血量封顶**（第 n 架 ≤ 2n−1 血）。
  - **间隔（`StageCatalog.GetSpawnInterval`）**：原曲线（关1 2.8s → 关13 起 1.12s）保留为「最后三关目标值」，前段乘 `ramp`——关1–5 恒 **×3.0**、关6 ×2.5 → 关9 ×1.0 **线性平滑收敛**、关10+ **×1.0（最后三关＝原曲线）**。实测关1 2.80→**8.40s**、关9/13/15 与改动前一致。仍叠加「密集编队」`spawnMul`。
  - **血量封顶（新增 `StageCatalog.GetFirstShipHpCap(spawnIndex)`，上限 `2×序号−1`）**：`Game.SpawnNextNormalEnemy` 把 `pendingSpawn.hp` 与上限取 min——**只封顶不抬升**（关卡曲线更低时保持曲线值）。判定用 **`pendingSpawn.spawned`（本关已放出计数）** 而非「场上无敌机」（AB-204 同族：首机被打掉后第二架会被误判成第一个），且带 `wave == (stage-1)*WAVES_PER_STAGE+1` 约束（**只在本关第一波生效**），`ResetGame`/每波开波都复位。精英/Boss 走各自曲线不参与本表。实测关1=1,2,3,2,2,2 / 关5=1,3,4,4,4,4 / 关7=1,3,5,5,5,5 / 关15=1,3,5,7,9,9（关卡曲线更高处被压到上限）。
  - **零新增顶层 local**：把 v0.13.50 的 `pendingSpawn.firstDone`（bool）就地改成 `spawned`（计数），仍是 `pendingSpawn` 表内一个字段（AB-166）。
  - 验证：LSP workspace 26 文件 **0 Error**（1122 诊断）；官方多人 build ✅（构建日志 05:33 完成、dist 1.0.1 含本改动，产物 Client 92 / Server 2 资源）。展示版本归并发会话（本批未动 BUILD_VERSION，当前常量 0.13.55）。
  - 边界：手机 FPS / 全 DPR / 用户审美未验收；**平衡手感（前期是否偏慢、封顶曲线是否顺滑）需 Preview 实机确认**。
- 附记: split-concurrent-cap（2026-10-09，分裂车同时最多 **15**；不改展示版本）：
  - 用户先要求「分裂车同时最多存在20个」，随后改口径「改为15个」——上限常量最终为 **15**。统计存活待发分裂车 + 飞行分裂车 + 本帧 pending 子车；备弹队列只存车型键，未生成，不占名额。
  - `BALL_TYPES.normal.maxConcurrent=15`，`Game._NormalMarbleSlots(pendingMarbles)` 按实际存活对象求剩余名额（零新增顶层 local / 零跨帧计数器）。`TrySplitNormal` 生成 `min(splitCount, 名额)`，满额不生成/不发成功事件；只剩一个名额时角度 0，事件 count 与实际出生数一致。保留 2/3/4 颗专属卡效果和递归分裂。
  - `QueueNextBall` / `PauseReload` 满额时不移除 normal 队首，保库存等待回收；pending 入场后才常规装填，避免分裂到上限后补车超员。发射只是待发转飞行；死亡/回收/超时释放名额，重开清场，无累计生成上限。上限是单一常量，改口径只需改 `maxConcurrent` 一处（本次 20→15 仅改此值 + 记录）。
  - 验证：五处变更独立静态审查未发现问题；workspace LSP 26 文件 0 Error（有既有 Warning/Hint）。本地 Runtime 规则测试 **51/51、1578 断言 PASS、exit0**（cap=15，含同帧多母弹、2/3/4 颗、13/14/15 边界、递归、库存保全、真实发射、重开与 1x/2x Update）。首轮 13 项探针把入场转移期间同一对象双计造成假失败，仅修探针，保留首轮日志不计通过。官方多人 build 与预览上传 ✅（早期一次调用返回 `PLATFORM_OPERATION_FORBIDDEN` 属临时限制，重试成功；不绕过平台限制）。
  - POST-1：项目状态与边界执行，persona 判定不新增（本轮明确数量参数，已有数值反馈画像足够）。POST-2：代码独立提交（初始 20 版 `c9f3413`，改 15 独立提交），本附记随记录提交。POST-3：判定跳过（小范围实例预算，已有同帧预算/生命周期纪律，无新增跨项目偏好）。保留存钱罐/首机 HP/拖尾等并发修改；手机与战斗 3D 可见性未验收。

- 附记: trail-style-mechanics（2026-10-08，六种拖尾精进出真实机制差异；不抢并发展示版本）：
  - 用户「商店拖尾拉完了，然后需要精进」。根因：六种样式此前**只是同一条光带的数值微调**（宽/亮/断续/双轨），战斗里颜色还按弹种取、商店预览除余烬外全是一条青——正是本项目自己记过的 AB-214「差异化要落在机制不是数值」。
  - **给样式表加 7 条机制轴（`MetaCatalog.TRAIL_STYLE_PARAMS`，纯数据）**：`taper`（宽度曲线指数）、`bulge`（头端鼓包/实心亮核）、`hue`（沿长度色相游移）、`flow`（断续图案流动速度）、`pulse`（明暗脉动）、`railSpread`/`railTaper`（双轨头端间距与收拢指数）。六种各占不同轴：经典=中性基准；彗星=taper0.55+bulge1.0；霓虹=hue0.60；流光=dash3+flow7；双轨=railSpread1.6+railTaper0.30；余烬=taper1.8+pulse0.38。
  - **渲染（`Renderer3D`）**：`TrailColor` 加 `phase` 参与 pulse、加 hue 色相游移；几何发射按 taper/bulge 算宽度、按 `(i+flowOffset)%dash` 让断续图案随时间平移、双轨轨距按 `t^railTaper` 收拢。新增**一个顶层 local** `trailPhase_`（按玩法 dt 累加，非 playing 不推进，与 CD 计时同契约）。
  - **预览（`MetaUI.DrawTrailPreview`）**：改为与 3D **同一套参数与同一套机制轴**（含 `D.anim()` 相位），保证「预览里看到的差异 = 实机差异」；描述文案同步改写。
  - 验证：机制探针 `probe_trailstyles` **ALL PASS**（6 样式各机制轴字段齐全、五种付费样式各有非中性轴且两两签名不重复、ribbon 保持中性基准、宽度曲线实测 ribbonMid 0.520 vs cometMid 1.061、未知样式回退 ribbon）；真渲染逐样式截屏**实图目视**——经典均匀青/彗星头端鼓包/霓虹尾端品红/流光断续/双轨收拢双轨/余烬暖色宽幅，六者清晰可辨（经典 vs 余烬像素差 56363）；3D 战斗冒烟（开局→多次发射→飞行）Lua/overlay/LoadChunk/空顶点错误 **0**。LSP workspace 0 Error（26 文件 1118 诊断）；官方多人 build 与预览上传成功。
  - 边界：手机 FPS / 全 DPR / 用户审美仍未验收；Linux 既有 HDR/缺图/无体素致战斗中央 3D 黑场，尾迹可见性未据此验收（样式差异用商店 2D 预览取证）。

- 版本: 0.13.56（**第 1 关「测试模式」询问：可选直入后期关卡并解锁全天赋**）：
  - 用户要求「新玩家开局第一关会询问是否要测试后期关卡？如果选择是，那么变为第二十关强度并解锁所有天赋树。如果选择不则继续游玩」，追加「不需要是新玩家，第一关一直有」——即**每次进入第 1 关都询问**（不做「只问一次」记忆）。
  - **触发点（第 1 关 = 三处入口）**：①选关界面点第 1 关；②第 1 关通关后「再战本关」；③重开（`RestartFromOver` 固定回第 1 关）。前两处由编排层 `client_main` 在开局前插入询问屏（`HandleMetaAction("play_stage")` 与 `HandleStageWinPointerUp` 的 retry 分支）；第 ③ 处沿用「每次进第 1 关」的自然行为（重开=再次进第 1 关），未额外加询问。
  - **实现（零新增后端 local / 零改 Game.lua）**：新增 `scripts/ui/TestModePrompt.lua`（+`.meta`，22 位 uuid `Lf4EtJlBNB0p7dZUCEK5hy`，已验重）——纯绘制/命中模块，靠 `MetaUI.RegisterScreen("test_mode", ...)` **插件式注册**，自动获得元层窗口的入场/退场弹动动画与 `WindowInput` 命中逆变换（**不需要给 `Scene3DBackend` 加任何状态**，避开 AB-166 顶层 local 上限）。屏内两按钮：`test_mode_yes` / `test_mode_no`；**点窗外/ESC 都不关闭**（ESC 等同「否」），保证玩家显式选择。
  - **「是」的效果**：`PlayerData.EnsureAutoOwnedTalents(全部节点 id)` → 解锁整棵天赋树（42 节点）→ `PersistMeta()` 落盘 + 云同步 → `pendingTestStage_ = TestModePrompt.TARGET_STAGE`（**20**）→ `HandleUpdate` 在菜单态进入该关。**「否」**：`pendingTestStage_ = 1`，不动天赋，从第 1 关开始。目标关号是模块常量 `TestModePrompt.TARGET_STAGE`，改一处即可。
  - **⚠️ 询问屏是「菜单态」屏**：`HandleUpdate` 的待决跳关判定要求 `state == "menu"`，而「再战本关」时 `Game` 正处于 `stagewin` 态 → **必须先 `Game.GoToMenu()` 再 `OpenMetaScreen("test_mode")`**，否则询问屏显示了却永远不跳关（本次踩到并已修）。
  - **验证**：官方多人 build + 预览上传 ✅；LSP workspace **0 Error**（26 文件 1118 诊断）；行为探针 `probe_testmode` **ALL PASS**（点第 1 关→停在菜单不直接开局→「是」→`state=playing stage=20 talents=42/42`→回菜单→再点第 1 关→「否」→`stage=1`）；`probe_tmretry` **ALL PASS**（第 1 关 stagewin 点「再战本关」→回菜单并弹询问→「是」→第 20 关 + 全天赋）；两探针 + 常规冒烟 `probe_render` 的 `overlay stage failed`/`Execute Lua function failed`/`LoadChunk failed`/`VertexBuffer is empty` 均 **0**。展示版本归并发会话（本批未动 BUILD_VERSION）。
  - 边界：⚠️ **本批未能自证询问屏的实际画面**——本地离屏 `-screenshot-frame=N` 在本环境**不生效**（三张不同帧参数的截图字节完全相同、均为早期菜单帧），只能证明「无渲染错误 + 命中几何正确 + 状态机正确」，**真机观感需 Preview 目视**。手机 FPS / 全 DPR / 用户审美未验收。
- 版本: 0.13.55（**车辆专属卡改机制维度，与基础卡区分**）：
  - 用户「车辆专属和基础卡差异化做的太差」。根因量化：八张车卡其实是**四条公式各写两遍**——`base_split`/`split` 都只改 `BALL_TUNING.splitBonus`、`base_ice`/`ice` 都改 `iceBonus`、`base_speed`/`speed` 都改 `speedMul`、`base_giant`/`giant` 都改 `giantArea`，专属卡纯粹是「数值更大」（+3% vs +2%、+1.2s vs +0.5s、×1.08 vs ×1.04、+1格 vs +0.5格），零机制差异。
  - **定案：基础卡 = 该车型主属性的「打底数值」（保持简单、常出、可叠高）；专属卡 = 换一个机制维度**（挂到引擎里已存在但卡池未启用的钩子上）。四张专属卡全部 `rarity` 升 `rare`、`weight` 1→0.6：
    - `split` 裂变核 → **分裂数量 +1 颗**（`BALL_TUNING.splitCount` 2→3→4，`maxStacks` 2）
    - `ice` 霜裂涂层 → **冻结中的敌机受击伤害 +30%/级**（`BALL_TUNING.iceShatter` 0..0.9）
    - `speed` 动能穿刺 → **加速车每次飞行穿透 +1 块不反弹**（`BALL_TUNING.speedPierce`）
    - `giant` 冲击波 → **范围击碎 15%/级 概率双倍伤害**（`BALL_TUNING.giantCritChance` 0..0.45）
  - 实现点（全在 `Game.lua`，零新增顶层 local——只加 `BALL_TUNING` 表字段）：`CreateMarble` 加 `pierceLeft = BALL_TUNING.speedPierce`；`TrySplitNormal` 按 `splitCount` 在 ±splitSpread 扇区内均匀生成 N 颗；`DamageBrick` 在 `enemy.frozen>0` 时 `damage *= (1+iceShatter)`；碰撞分支在 speed 车 `pierceLeft>0` 时**不反弹**、沿速度前推 0.75 格、`ignoredBrick` + `pierceLeft--` + `Emit("speed_pierce")`；`DamageGiantArea` 逐格按 `giantCritChance` 掷暴击（×2，复用 `crit_hit` 金色飘字）。`ResetGame` 在 `LoadBalls` **之前**复位四个字段。
  - `Presentation.lua` 只加两处：`FEEDBACK_MAP` 增 `speed_pierce = {"pierceSpark"}` + `pierceSpark` handler（橙色火花，与「追击」同色系更短促）。
  - **门控不变**：专属卡仍需 `ballCard` 天赋节点（`kind ~= "base"` 且带 `ballType`），基础卡只需车解锁——差异化只在「效果维度」，不动解锁链。
  - 验证：隔离规则探针 `probe_card_diff` **10/10 PASS、61 断言、0 Lua 错误**（专属卡不动四个打底字段 / 基础卡仍持有打底字段 / splitCount 驱动分裂数量 / iceShatter 只对冻结敌机生效 / speedPierce 穿透不反弹 vs 无穿透照常反弹 / giantCritChance 双倍+发 crit_hit vs 0 不暴击 / ResetGame 复位 / 门控仍拦专属卡）；真渲染冒烟（注入四机制→真实发射→战斗帧）exit0、目标 Lua/overlay/LoadChunk/空顶点错误 **0**。LSP `Game.lua`/`Presentation.lua` 0 Error。官方多人 build + 预览上传 ✅。展示版本归并发会话（本批未动 BUILD_VERSION）。
  - ⚠️ **避雷 AB-214**：**「专属卡 vs 基础卡」的差异化必须落在「机制」而不是「数值」上**——只要两张卡改同一个 `BALL_TUNING` 字段，无论数字差多少，玩家读到的都是「同一张卡的两个强度」，等于把一条公式写两遍。做法：基础卡保留主属性打底值，专属卡**换一个字段/换一个作用对象**（本项目：分裂概率→分裂数量、冰冻时长→冻结增伤、加速度→穿透、范围半径→范围暴击）。**验收探针必须显式断言「专属卡不改任何打底数值字段」**，否则很容易悄悄退回「更大的数字」。
  - 边界：手机 FPS / 全 DPR / 真实联网支付 / 用户审美仍未验收；Linux 既有 HDR/缺图/无体素致战斗中央 3D 黑场，不计通过。
- 版本: 0.13.54（**范围攻击与完整击毁反馈**）：
  - 用户「范围攻击增加特效和轻度震屏！整架飞机一个块不剩击败时也要」。范围采用紫色双环/白芯/短径向光刺，整机完整击毁采用青白环/离散碎光；保留旧粒子与飘字，不增加伤害或顿帧。
  - `Game.EjectBrick` 在最后存活格消失时发布 `enemy_destroyed`（中心/宽高），只在机体未越线时发；`Presentation` 独立消费产生整机冲击。`enemy_cleared` 仍在原 `UpdateEnemies` 奖励链发布，只保留旧「击破」字，不重复冲击。部分破坏、越线/逃脱/胜利清退不触发新全毁反馈；部分越线后 Boss 击败仍按原规则通关。最后砖经验同帧触发升级也先发击毁事实，不提前结算奖励。
  - `Presentation.combatImpacts` + 对象池，最多 8 个（满时复用最老），寿命范围 0.48s / 整机 0.62s；轻震取 max 0.22/0.18，不相加，既有基地重震不削弱。复位/退菜单清理、暂停时视觉自然衰减，技能 CD 仍冻结。
  - 新 `ui/CombatImpact.lua` 复用宿主 ctx 与世界投影（中心+X/Y边界分别量，倾斜正交下圆域显示椭圆），无新字体/context/图片/RT。Backend 只挂 `uiFx.impact`，不新增顶层 local。同帧升级/胜利在遮罩后空白带绘制紧凑回声（升级 y270、胜利 y155），不放开所有旧 world-fx、不盖文字或按钮；回声不是实际范围位置。
  - 最终即时击毁接口规则/表现 **15/15、289断言 PASS**；原1秒CD与就绪提示专项重跑 **72/72、1377断言 PASS**。六场真实Draw（范围/整机/范围升级/清机升级/Boss胜利/普通末块XP）及各自独立完整TTL/相机归位通过，15个进程exit0、目标Lua/overlay/load/空顶点错误0；全部冻结源码指纹与生产一致，六份原图已内部目视环/回声可辨、不压正文按钮。最后砖经验同帧升级立即反馈，选卡后奖励不重播。LSP24文件0 Error（922 Warning/106 Hint），官方多人build372/预览上传成功；中间版假失败与超时日志保留不计PASS。Linux既有HDR/缺图/无体素导致中央3D黑场，手机FPS/全DPR/真实支付与用户审美未验收。
  - 抗体 AB-213：击毁反馈要同时核验领域语义与模态实际绘制，事件保留不是可见性通过。保留并发 UI 53（5824e0a）与初始 VisualCatalog 缓存，只提交本人 hunk。
- 附记: ui-trace-density-2（2026-10-08，纹路再加密度 + **修 NanoVG 单帧命令缓冲溢出**；不抢并发展示版本）：
  - 用户再次「无关紧要的纹路不够多」并点名两份 skill。上一轮只落了 4 种母题、覆盖也薄；本轮按规范 §3 把 **8 种装饰母题补齐**并大幅提高落点密度。
  - **补齐 4 个缺失母题（`ui/PremiumSurface`）**：`Halftone`（半调网点，隔行错位）、`ScanBand`（扫描带+拖尾，随 `phase` 下移）、`Cross`（十字取样点）、`TickRing`（环形刻度，每 3 段加长）；另加 `Ticks`（长短交替刻度带）。此前只有 MicroGrid / DiagonalHatch / CircuitTrace / CornerBrackets / DashRule / DotMatrix。
  - **密度提升（同层叠多种）**：`Panel` 大面板 → 微网格 + **粗网格(46px)** + 半调 + 斜拉丝 + **双层四角折线** + 断线 + **底边刻度带** + 点阵 + 电路刻纹 + 角落十字 + 扫描带；`Window` → 双层四角折线 + 半调 + 刻度 + 双断线 + 十字；`Background` → 双层网格 + 双层斜纹 + 半调 + 三处点阵 + 8 个十字；`Stage` → 双层网格 + 半调 + 点阵×3 + 刻度带 + 环形刻度 + 四角十字；`Button` 大按钮 → 斜拉丝 + 底边刻度 + 角落十字。
  - **MetaUI `CardTrace` 加厚**：双层网格 + **双层四角折线** + 底边长短刻度 + 断线 + 角落点阵 + 角落取样十字；接到福利/收藏卡、钱包条、天赋入口大卡、商店标签/浏览卡/购买区、任务行、图鉴卡、排行行/页脚条。
  - **战斗侧（`Scene3DBackend` / `ui/BattleHUD`）**：升级卡补双层网格 + 半调 + 内圈折角 + 底边刻度 + 断线 + 两处十字；HUD 三块仪器 / 弹药舱 / 四个弹药槽各补网格 + 半调 + 底边刻度（`BattleHUD` 新增本地 `Trace`，前向声明 + 后置赋值，避免跨模块依赖）。
  - 🔴 **真坑（本轮实测，价值最高）**：**NanoVG 单帧命令缓冲会溢出**——半调/点阵原按「每点各起一条 `nvgBeginPath` + `nvgFill`」写，几千条命令把缓冲撑爆后，**本帧后续绘制被静默丢弃**（无任何报错、无 stage failed），表现为「商店/窗口**只剩背景，卡片与文字全没了**」。定位过程：同帧对比 HEAD（bright 74904）vs 我的版本（4372）→ 二分到 `PremiumSurface` → 再二分到 `Halftone`（改步长 8→22，bright 回到 36363）→ 结论是**点数而非面积**。
  - **修法**：`Halftone` / `DotMatrix` / `BattleHUD.Trace` 全部改为**合并单一路径**（一次 `nvgBeginPath` + 循环 `nvgCircle` + 一次 `nvgFill`），并把半调点数按面积**自适应放大步长**（budget 600）钳住。修复后同帧 bright 回到 **75304**（≈HEAD 基线），实图确认商店卡片/文字全部回来且纹路可见。
  - ⚠️ **验收纪律**：**「渲染无报错」不等于「画出来了」**——本轮全程 `overlay stage failed` / `Execute Lua function failed` 均为 **0**，但画面确实缺内容。判据必须是**像素取证**（同帧 bright 计数 / 实图目视），不能只看错误计数。
  - 验证：LSP workspace **0 Error**（25 文件 1092 诊断）；五个真渲染探针（`probe_home`/`probe_shop`/`probe_windows` 九窗口/`probe_upcard3`/`probe_battle_stress_final`）exit0、目标 overlay/Lua 错误 0；实图目视商店（双层折角+网格+刻度）、首页卡、战斗 HUD/Dock/弹药槽、升级卡纹路均可见且不压读数；官方多人 build 与预览上传成功。
  - 边界：手机 FPS（纹路调用数上升，已按面积钳点数）/ 全 DPR / 用户审美仍未验收。
- 附记: ui-trace-density（2026-10-08，UI 装饰纹路加密；不抢并发展示版本 0.13.54/55）：
  - 用户「还是不够贵无关紧要的纹路不够多」——**要的不是更多功能，是更多「无关紧要的纹路」**（不承载任何信息的装饰线）。上一轮（0.13.53）解决的是「温度」，这一轮解决的是**密度**。
  - **新增纹路原语（`ui/PremiumSurface`，6 个纯绘制 helper）**：`MicroGrid`（极淡方格）、`DiagonalHatch`（斜向拉丝）、`CircuitTrace`（L 形走线 + 焊盘）、`CornerBrackets`（四角取景折线）、`DashRule`（断线）、`DotMatrix`（小圆点阵）。全部**自带 `nvgIntersectScissor` 裁剪**，只画不参与命中。
  - **落点（改共享原语即全屏生效）**：`Panel` 大面板（网格 + 斜纹 + 四角折线 + 断线 + 点阵 + 电路刻纹）、`Window` 窗口壳（标题舱底断线 + 右上点阵 + 内容区斜纹 + 四角取景）、`Button` 大按钮（斜向拉丝）、`Background`（全屏网格 + 斜纹 + 两处点阵）、`Stage` 展台（地面网格 + 角落点阵）。
  - **MetaUI 小卡片**：新增本地 `CardTrace(ctx, r, alpha)`（`D.grid` + `D.corner` + 角落点阵），接到菜单福利/收藏卡、商店分页标签/浏览卡/购买区、任务行、图鉴卡、排行行/页脚条；幸运轮盘另加**虚线环 + 点阵环**。
  - **纪律**：全部低 alpha（网格 9–16、斜纹 5–12、折线 95–130、点阵 26–46），**门槛化**（网格只在大面板、斜纹只在 ≥110 宽按钮/≥190 宽面板、点阵只在够宽卡）——不承载信息、不穿正文、不改任何命中几何、不动玩法/价格/广告/IAP。
  - 验证：LSP workspace **0 Error**（24 文件 1072 诊断）；真渲染探针 `probe_home`/`probe_shop`/`probe_windows` exit0、`overlay stage failed`/`Execute Lua function failed` **0**；实图目视——首页福利/收藏卡四角取景线与极淡网格可见、商店浏览卡与分页标签有纹理、转盘外圈虚线环 + 点阵环可见，均不糊字。官方多人 build 与预览上传成功。
  - 边界：手机 FPS（新增逐条描边/逐点绘制，低 alpha 但调用次数上升）/ 全 DPR / 用户审美仍未验收。
- 版本: 0.13.53（**提消费欲望：付费/商店路径转暖金，破「太冷酷」**）：
  - 用户「还是不够贵！太冷酷消失消费欲望！」——反馈升级：不只是「不够贵」，而是**缺温度**。参考图里全屏冷色（青/海军蓝），**唯一暖色是金色按钮**；而首页唯一的暖色（钻石商店按钮）恰恰被画得最平（纯色 panel）。
  - **付费入口（首页钻石商店）**：改用完整按钮工艺 `D.button(wb, C.warn, 0.62)` + **常驻暖金辉光**（不再只悬停才发光）——现在它是全屏最亮最暖的一点。
  - **金色走「贵金属」配方**（`Surface.Button`）：`warm` 判定（R>200 且 G>140 且 B<130）→ 高光改 `(255,232,168)` 暖白、暗端保留金色（不再压成灰）、常驻辉光 alpha 提升到 130/半径 12。青/绿等冷色按钮**配方不变**。
  - **商店整条路径转暖**（收藏/稀有语义，与冷色战斗 UI 区分）：分页标签（激活金底 + 金下划线 + 金悬停）、浏览卡（金顶亮线 + 金左标 + 选中金边 + 暖白内受光）、购买区（金框 + 暖内受光）。**未选中的卡仍中性灰**，不做全屏泛金。
  - 只改 `MetaUI`（金按钮 + 商店 3 处转暖）与 `ui/PremiumSurface`（Button 贵金属分支）；无删除、无新资源/字体/context/RT，不改玩法/价格/车辆几何/广告/IAP/输入命中/CONTAIN 投影。展示版本归并发会话（本批未动 BUILD_VERSION）。
  - 验证：LSP workspace 0 Error（24 文件 1029 诊断）；首页/商店/升级卡/战斗/九窗口真渲染探针 exit0、目标错误 0；商店实图目视——选中卡金框金标、标签激活金、购买区金框，整屏暖色比例明显上升；官方多人 build 与预览上传成功。
  - 边界：手机 FPS / 全 DPR / 真实联网支付 / 用户审美仍未验收。
- 版本: 0.13.52（**修巨型车冷却未到就提示「可以贯穿」**）：
  - 用户反馈「cd还没到就跳可以贯穿了！」。旧版只在圆域伤害分支检查 CD，范围消费后尾部立刻 `ArmGiantPiercing`，发出 `giant_pierce_armed`；真实 Presentation 据此生成「可以贯穿」。复现 CD=1 仍出提示、0.25s 后 CD=0.75 仍只走普通伤害，确认是就绪状态/反馈提前，不能用旧 CD 探针通过否认反馈。
  - 修复：`giantPiercing` 仅代表真正就绪；实例 `giantPiercePending` 保留 CD 中的反弹资格。`ArmGiantPiercing` 在 CD>0 只置 pending、不发就绪；子步 CD 归零后自动武装，不强迫多反弹一次。1 秒 CD、范围/伤害/普通碰撞/逐帧砖去重、冻结与独立实例不变，零新增顶层 local。
  - 反馈闭环：armed/consumed 事件携带车辆 `id`；就绪字用 `kind=giantReady`+`marbleId`，实际消费立即清掉本车旧提示，另一车提示保留；对象池复用时重置 `marbleId`。同帧 ready→hit→consumed 也不能残留到冷却期。不删既有 UI 质感、其他技能/广告/IAP 规则与更名资源。
  - 验证：当前生产副本新专项 **36/36、968 断言 PASS**；旧专项按 pending 语义更新 3 处断言后重新运行 **36/36、409 断言 PASS**，两次正式 CLI exit0。涵盖 0.99/1 秒、9 格帧率速度矩阵、CD 中无就绪事件/飘字、到期无额外反弹恢复、同帧旧字清除/异车保留、冻结/回收重开/范围/去重。LSP workspace **0 Error**（24 文件；有既有 Warning/Hint）；官方多人 build 与预览上传成功，BUILD_VERSION/大厅→0.13.52。真实渲染最终两次 exit0：冷却截图 CD≈0.767/ready=0、到期截图 CD=0/ready=1/额外反弹0，已内部目视确认「范围击碎」与「可以贯穿」分时显示；真实过 intro 发射/暂停恢复通过、目标 Lua/overlay/load/空顶点错误0。首轮截图计帧偏差已补测不冒称通过；Linux 既有 HDR/缺图/无体素导致 3D 黑场，不据此验收手机/3D 可见性。
  - 避雷 **AB-210**：CD 必须同时管「真实结算 + 就绪状态 + 就绪反馈」，待冷却资格与真实就绪分开；消费事件要清同实体旧提示，回归包括同帧 armed→consumed、到期恢复及多实例。
- 版本: 0.13.51（**游戏更名「货车大战飞机」+ 星系内标字标全部重出**）：
  - **用户要求**「更新游戏名称：货车大战飞机，包括有星系内标图片需要重新生成」→ 对外名与**游戏内字标图**一起换。
  - **改名（6 个文件 + 发布配置，全量替换「击碎，飞机大战」/「击碎飞机」→「货车大战飞机」）**：①`Scene3DBackend.GAME_TITLE`/`GAME_SHORT_TITLE`（回退用 zpix 大 logo 也变 6 字）；②`client_main` 的 `graphics.windowTitle`（窗口标题）；③`lobby_runtime` 加载页标题栏；④`lobby_ui` 的 `title_` 默认值 + 6 处 `title=`；⑤`Game.lua` 顶部注释；⑥`.project/project.json` 的 `taptap_publish.title`（**发布名契约**）。`taptap_publish.description` 的「竖屏飞机大战」→「竖屏弹射对战」（正文无需带旧名，顺手去掉过时词）。
  - **字标重出（走 `0718-pixelimage-aigc` 管线）**：`batch_generate_images`(nanobanana) 出 4 张「货车大战飞机」草案（1344×896，**必须 `transparent:true`**）→ 手写后处理（**按内容 bbox 裁切 → 等比缩到 120 高 → alpha 二值化 128 → 量化到项目 7 色**：`#10131F/#252A3A/#009694/#00E5D0/#7FF2E6/#F1EEF0/#FFFFFF`）→ 实测 **4 张全部 7 色**、宽 294/268/201/232（高度统一 120）。旧 4 张 `ui_logo_[abcd]_20260929162106.png` 与草案全部删除，新文件 `ui_logo_truck_[abcd]_20261008175431.png` + 各自 `.meta`（22 位 hex uuid，已验重：全库 99 个 uuid 无重复）。
  - **接线**：`LOGO_PATHS` 换成 4 个新路径并**逐图更新 `w`**（⚠️ 各图宽度不同，**必须逐图记宽居中**，塞进同一矩形会拉伸——字标是「完整成品」不是 9-slice）。`LOGO_H=120`、5 秒轮播、随机起点、NEAREST 1× 全部不变。
  - **顺手修的溢出隐患**：`DrawMenu` 的 zpix 回退原来写死 `size=104`，对 4 字标题刚好、对 **6 字会溢出画布**（6×104=624 > 540）→ 改为按 `utf8.len` 反推字号 `min(104, (width-56)/n)`。
  - **验证**：官方多人 build + 预览上传 ✅；LSP workspace **0 Error**（24 文件 1028 诊断）；真渲染探针 `probe_logo`（启动停在菜单）日志 `pixel logo titles loaded=4/4`、截图实图确认新字标「货车大战飞机」清晰可读、货车/飞机剪影完整、零 Lua/overlay 错误；战斗冒烟 `probe_render`（菜单→选关→战斗→发射）exit0、`overlay stage failed` **0 次**、零 `Execute Lua function failed`/`LoadChunk failed`。BUILD_VERSION/大厅 →0.13.51。
  - ⚠️ **教训（AB-205）**：**「游戏更名」= 对外名 + 游戏内字标图两件事**，只改字符串会留下旧名 logo（用户本次明确点名「星系内标图片需要重新生成」）。交付前用 `grep -rn "<旧名>" scripts/ .project/` 全库扫一遍（含 `taptap_publish.title` 这个发布名契约），再 `grep` 确认新名已落到窗口标题/大厅/字标三处。
  - ⚠️ **教训（AB-206）**：**给游戏出字标草案必须开 `transparent:true`**——本批第一轮 4 张全生成成了**白底不透明**（`alpha0ratio=0`），白底「文字黑边」在深色游戏背景上会变成一道白框。历史上正确的 4 张 logo 都是透明底（`alpha0count≈12000`）。生成后先量 `alpha==0` 的像素占比，为 0 就重生成，别硬跑管线。
  - ⚠️ **教训（AB-207）**：**字标是「完整成品」不是 9-slice，宽度必须逐图记**——4 张新字标宽 294/268/201/232（差 1.46 倍），`LOGO_PATHS` 里每项自带 `w`、绘制时 `lx=(width-w)*0.5`。若统一用一个宽度，宽图会被压扁、窄图会被拉伸。同理**回退用的 zpix 大 logo 字号要按字数反推**（写死 104 只对 4 字成立）。
- 版本: 0.13.50（**每关第一个飞船固定 1 血**）：
  - **用户要求**「每关第一个飞船必须是 1 血」→ ①`Game.SpawnNextNormalEnemy` 里，**本关第一波的第一架**强制 `hp=1`（其余按关卡曲线）；②`StageCatalog.BeginStage` 的精英波位池**从 `1..9` 收窄为 `2..9`**——否则精英可能落在第 1 波，开局就撞精英，「第一个飞船 1 血」读不通（也反玩家直觉：不该开场就遇精英）。
  - **实现细节**：用 `pendingSpawn` 表新增的 **`firstDone` 标记**判定「是否已放过本关首机」，而不是用「场上无敌机」——否则首机被打掉后、同波第二架会被误判成「第一个」也拿 1 血。判定同时带 `wave == (stage-1)*WAVES_PER_STAGE+1` 双保险；`ResetGame` 与每波开波（`SpawnWave`）都复位 `firstDone`。**未新增顶层 local**（加在 `pendingSpawn` 表里，AB-166）。
  - **验证**：LSP workspace **0 Error**（24 文件 1027 诊断）；探针 `probe_first` 实测——**关1/5/12 首机 HP 均为 1**，第二架分别为 2/4/7（= 各关曲线值，说明只有首机被改）；精英波位扫 180 组（关1/5/12 × 60 种子）**0 次落在第 1 波**；真渲染冒烟零 Lua/overlay/VertexBuffer 错误（日志确认 `elites@4,5,6` / `elites@5,6,9` 均不含第 1 波）。官方多人 build+预览上传 ✅。BUILD_VERSION/大厅 →0.13.50。
  - ⚠️ **教训（AB-204）**：「首个单位特殊化」要用**显式「已放过」标记**，不能用「场上是否有单位」推断——首机若在下一架出场前就被清掉，「场上为空」会把第二架误判成第一个。配套：这类「本关只生效一次」的标记要**在关卡开局与每次开波都复位**，避免跨波/跨关残留。
- 版本: 0.13.49（**整体抬高敌怪难度曲线**；订正 v0.13.48 的削玩家方向）：
  - **用户订正**：v0.13.48 我削了玩家侧（基地 100→80、加速车 damageStep 320→480），用户明确指出「**不对你应该整体提高地怪难度曲线来实现平衡**」→ **撤销玩家侧改动**（`BASE_HP` 回 100、`damageStep` 回 320），改为**抬敌方**。
  - **改动（全在 `StageCatalog.lua`，不动玩法/渲染）**：①**砖块 HP** `2 + floor((stage-1)/2)`（原 `1 + floor(/3)`）——关1 **1→2**、关7 3→**5**、关15 5→**9**（精英 +1、Boss +2 不变）；②**基准速度** `34 + (wave-1)*4 + min(stage-1,12)*1.8`（原 28 / 1.5）——关1 首波 28→**34**、关13 起 46→**56**；③**精英护航** `min(3, 1 + floor(progress/2))`（原关1–3 为 0）——关1 起就有 **1 架**、关5 起封顶 3；④**Boss 召唤**上限 `min(5, 2 + floor(progress/3))`（原 1 起/封顶 4）、间隔 `max(6, 10 - progress*0.3)`（原 12s 起/8.5s 封顶）——关1 **2 架/10s**、关13 起 **5 架/6s**。
  - ⚠️ **刻意没动的**：**普通波数量**（关1 2/2/3/3/4/4 不变）——用户 v0.13.26 明确要求过「数量起点要低、不要满 12」，所以抬难度走**血量/速度/护航/召唤**四条轴，**不碰数量**；玩家侧全部还原（基地 100、加速车 damageStep 320、无限成长+软性递减契约不变）。
  - **验证**：LSP workspace **0 Error**（24 文件）；探针 `probe_curve` 实测新曲线（关1 HP=2/精英3/Boss4、关15 HP=9/10/11；速度关1 34、关13 56；护航关1=1、关5=3；Boss 召唤关1 2架/10s、关13 5架/6s；**普通波数量与玩家基地 100 均保持不变**）；真渲染冒烟零 Lua/overlay/VertexBuffer 错误。官方多人 build+预览上传 ✅。BUILD_VERSION/大厅 →0.13.49。
  - ⚠️ **教训（AB-203）**：用户说「数值不平衡」时，**先问「该调哪一侧」**——本项目 v0.13.48 我默认「削玩家」（更保守、改动更小），但用户的意图是**抬高敌方曲线**（让成长更有意义、后期更有压力）。**在「玩家强/敌人弱」的不平衡里，用户偏好加强敌人而不是削弱玩家**（尤其玩家侧已有他明确指定的设定与契约时）。⚠️ 抬难度时**先排除用户明确限制过的轴**（本项目「普通波数量」被点名要求低），改走其余轴（血量/速度/护航/召唤）。
- 版本: 0.13.48（**前期我方数值过高——收敛基地生命与加速车增伤**）⚠️ **本批方向已被 v0.13.49 订正并撤销**：
  - **用户报**「前期我方数值过高啊」→ 定位「我方数值」= 玩家侧（基地生命 / 弹珠伤害 / 弹药 / 初速）。
  - **根因（量化前期过强）**：①`BASE_HP=100`，而越线伤害 `max(1, ceil(越线行数×0.5)+lineDamageBonus)` 在关1 每行仅 **1 伤** → 前几关几乎不可败；②开局车是**加速车**（用户 v0.13.19 指定），`speedBoost=1.06` **无上限** + `damageStep=320` **无上限分档增伤** → 关1 敌机 HP=1，初速 660 已 1 伤秒杀，且**反弹 8 次即到 2 伤**、越打越快越痛；③还有 `redirectThrottle=0.45` 自动追击几乎不空枪。
  - **改动（`Game.lua` 两处常量，只收敛前期、不动车型设定与后期无上限契约）**：①`BASE_HP` **100→80**（关1 多挨几行才有压力）；②`BALL_TYPES.speed.damageStep` **320→480**（分档增伤爬得更慢：初速 660 仍 1 伤、约 1140 才 +1、反弹 16 次才到 2 伤，旧值 8 次即到）。⚠️ **没有加回伤害/速度上限**——v0.13.22/0.13.23 的「无限增长 + 软性递减」契约保留，只把**曲线斜率**放缓。
  - **验证**：LSP workspace **0 Error**（24 文件）；探针 `probe_early` 实测——关1 砖块 HP=1、加速车初速 660 伤害 1、**反弹 16 次才到 2 伤**（旧 320 时 8 次）、Game 集成 `state=playing 基地血量=80 上限=80`；真渲染冒烟零 Lua/overlay/VertexBuffer 错误（含随机布局日志）。官方多人 build+预览上传 ✅。BUILD_VERSION/大厅 →0.13.48。
  - ⚠️ **`BASE_HP` 是单一来源**（`BALANCE.baseHp` / `local baseHp` 初始化 / `GetMaxBaseHp()` 三处都读它），改一处即可；交付前 grep 确认没有别处硬编码 100。
  - ⚠️ **教训（AB-202）**：「我方数值过高」要先分清是**哪一侧**——玩家侧（基地生命/伤害/初速）还是敌方侧（血量/数量/速度）。本项目根因是「关1 敌机 HP=1 而玩家伤害 1 + 无限成长」，属**双方数值比例**问题：调**基数**（HP）与**成长斜率**（damageStep）即可，**不要动用户指定的车型设定**（加速车开局），也不要为压前期而加回已被明确要求去掉的**上限**。
- 版本: 0.13.50（**修「黑边黑字 / 黑框」+ 天赋树浮窗厚度**）：
  - 用户要求「检查游戏里所有黑框黑文字的给我改了」并补充「黑边黑字也算」。
  - **真凶（黑边黑字）**：`DrawPixelText` 的描边**无条件**用近黑的 `C.ink`(4,8,16)——而全项目大量文字是 `C.ink`（青/绿/金按钮上的字）。于是暗字被近黑描边裹住＝**黑边黑字**。修法：按字色亮度选描边，`lum >= 120`（亮字）才画深描边，暗字不描边（`0.299R+0.587G+0.114B`）。该函数是 MetaUI/天赋树/选关等所有 `D.text` 的注入源，一处修全屏生效。
  - **真凶（黑框）**：多处「未拥有 / 未解锁 / 不可用」态用 `C.widget`(22,36,56) 作**边框**压在 `C.card`(16,26,44) 上——两色几乎相同，边框读起来就是一道黑框。修法：换成可见中灰 `{dim,130}`（图鉴未拥有卡、战斗档案未解锁里程碑、钻石商店不可负担行）。**已拥有/可领取**态仍用青色系，不受影响。
  - **天赋树浮窗**补内受光 / 内沉影 / 顶亮线（与其余面板同一套厚度语言，只加不减）。天赋树本体是**圆形卡树**（无「行」概念），不强行套分区标题。
  - 只改 `Scene3DBackend`（描边亮度判定）、`MetaUI`（2 处边框）、`ui/RechargeShop`（1 处边框）、`ui/TalentTree`（浮窗厚度）；无删除、无新资源/字体/context/RT。
  - 验证：LSP workspace **0 Error**（24 文件 1027 诊断）；天赋树/商店/首页/升级卡/战斗/九窗口真渲染探针 exit0、目标错误 0；天赋树与商店实图内部目视确认（未拥有卡边框已可见、暗字不再被黑边包）；官方多人 build 与预览上传成功。展示版本由并发会话统一推进（本批未动 BUILD_VERSION）。
  - 边界：手机 FPS / 全 DPR / 真实联网支付 / 用户审美仍未验收。
- 版本: 0.13.47（**减少关卡同质化：每关随机布局 + 关卡特性**）：
  - **用户要求**「减少各关卡之间的同质化，一部分东西我希望局内随机」（并明确「不要问我细节自己做好」）→ 自助定方案：**关卡结构保留骨架，把「每关都一样」的维度改成本关内随机**。
  - **根因（量化同质化）**：`StageCatalog` 里 `ELITE_SLOTS={[3]=1,[6]=2,[8]=3}` 是**写死的波位**、`GetSpecialKey` 按 `(stage-1)*3+slot` 做**确定性循环**、`PickFormation` 按 `(wave-1)%6` **确定性循环** → **每关都是 3/6/8 精英、机型与阵型走同一条轮转带**，玩家几关后就能背出来。
  - **做法（`StageCatalog.lua` 新增随机布局层）**：新增 `BeginStage(stage, seed)` + `MakeRng`（自持 LCG，**不依赖引擎 math.random**，可复现）+ `currentLayout` 缓存；**每次进关重掷**：①**精英波位**从 1–9 随机抽 3 个（不再固定 3/6/8）②**精英机型**按关+序号取模、**Boss 机型**随机 ③**关卡特性** `MODIFIERS`（标准×2 权重 / 急行推进 intervalMul 0.82 / 密集编队 spawnMul 0.82 / 增援编队 waveAdd +1）④**副标题**带上特性名。`GetKind/GetSpecialKey/GetNormalCount/GetInterval/GetSpawnInterval` 改为读布局（未 `BeginStage` 时回退旧固定值）。
  - **硬约束（不许随机）**：**第 10 波恒为 Boss**——`UpdateWaveLogic` 的胜负判定绑定 `stageWave == WAVES_PER_STAGE`，只随机它的**机型**；BOSS/精英的**数量与关卡骨架**不变（仍是十波、三精英一首领）。
  - **接线**：`Game.ResetGame` 在设好 `stage` 后调 `StageCatalog.BeginStage(startStage, os.time())`——**选关/下一关/再战/重开四条入口都经过它**，故每次进入同一关都会重掷（生产种子是 `os.time()`，每次启动不同）。`GetKind` 调用点补上 `stage` 实参（唯一调用点在 `PlanWave`）。快照新增 `s.stageSubtitle`，`Scene3DBackend.DrawWaveBanner` 的硬编码「十波防线 · 三精英一首领」改为读它。
  - **为什么随机逻辑放 StageCatalog 而非 Game**：`Game.lua` 顶层 local 已 **197/200**（AB-166 硬上限），随机层在独立模块里实现，Game 侧**零新增顶层 local**（`BeginStage` 调用 + 一个快照字段）。
  - **验证**：官方多人 build+预览上传 ✅；LSP workspace **0 Error**（24 文件 1024 诊断）；规则探针 `probe_layout` 全绿——同种子可复现、**12 个种子产生 12 种不同布局**、每关恒 3 精英且波位不重复、**第 10 波恒 boss**、三特性数值实测生效（急行 18.40→**15.09**、增援 3→**4 架**、密集 2.24→**1.84**）、Game 集成开局 `state=playing subtitle=十波防线 · 3 精英 · 1 首领`；真渲染冒烟零 Lua/overlay/VertexBuffer 错误，日志实锤**两次进入同一关生成了不同布局**（`elites@5,6,8 mod=surge` vs `elites@2,5,8 mod=standard`）。BUILD_VERSION/大厅 →0.13.47。
  - ⚠️ **教训（AB-201）**：消除「关卡同质化」要**先量化「哪一维每关都一样」**再随机那一维——本项目是「精英波位写死 + 机型/阵型走确定性取模循环」；**随机的必须只覆盖「每次都一样」的部分，骨架（波数、精英数、Boss 波位）保留**，否则会破坏结算/胜负判定（Boss 必须在第 10 波）。
- 版本: 0.13.46（**UI 纯加法调配：任务/图鉴/排行/转盘补分区标题与行厚度**）：
  - 承接 v0.13.45「已有贵的部分要保留」：本轮**只新增**，不重写既有绘制、不调低任何既有 alpha/层数/渐变。
  - **补分区标题**：每日任务补「今日任务」、幸运转盘补「转盘奖池」（青色，与主菜单/商店/战斗档案同一套竖条 + 淡出断线）。
  - **补行/卡厚度**：图鉴卡片、排行榜行与页脚条、转盘中奖条统一补「内顶受光 + 内底沉影 + 顶边亮线」，与 v0.13.42 给商店浏览卡加的是同一套语言。
  - ⚠️ **列表行下移要同步两处**：`DrawTasks` 与 `HitTestTasks` 各有一份 `y` 起点，加分区标题时两处必须一起 +22px，否则「看得见点不到」。
  - 只改 `MetaUI`（+30/-3）；无删除、无新资源/字体/context/RT。展示版本由并发会话统一推进（本批未动 BUILD_VERSION）。
  - 验证：LSP workspace 0 Error；任务/图鉴/排行/转盘 + 首页/商店/升级卡/战斗/九窗口真渲染探针 exit0、目标错误 0，四面板实图内部目视确认标题与厚度到位；官方多人 build 与预览上传成功。
  - 边界：手机 FPS / 全 DPR / 真实联网支付 / 用户审美仍未验收。
- 版本: 0.13.45（**按 skill 调配其余面板 + 措辞统一；纯加法，不删已有质感**）：
  - 用户追加「对，但是已有的贵的部分要保留，别给我删了！」→ 本轮**只做加法与调配，不动任何既有质感**（面板多层受光/漆面/描边/背景扫光/展台光场/文字描边全部原样保留）。
  - **战斗档案补分区标题**：该面板是唯一没有分区的长列表，新增 `SectionHeader`「里程碑奖励」（青色＝免费产出语义，与主菜单/钻石商店同语言）；`GetPassRewardRect` 的 y 由 `content.y+174` → **`+196`**（下移 22px 让出标题位）——该函数是绘制与 `HitTestPass` 的**共同来源**，改一处两处自动同步，命中不漂移。
  - **措辞继续去直白**（承接 v0.13.44）：皮肤商店购买区 `购买样式` → **`解锁样式`**、`购买车型` → **`解锁车型`**（与既有「解锁」「装备」措辞一致，仍是游戏内表述）。`DrawShopPurchase` 的按钮文案参数，`HitTestShop` 的 action 串不动。
  - 只改 `MetaUI`（SectionHeader 调用 + 里程碑 y + 两处文案）与 `Scene3DBackend`/`lobby_runtime` 版本行；**无删除、无新资源/字体/context/RT**，不动玩法/价格/车辆几何/广告/IAP/输入命中/CONTAIN 投影。
  - 验证：LSP workspace **0 Error**（24 文件 1017 诊断）；五个真渲染探针（`probe_home`/`probe_windows` 九窗口+暂停/`probe_shop`/`probe_upcard3`/`probe_battle_stress_final`）exit0、目标 overlay/Lua/LoadChunk/空顶点/断言错误 **0**；战斗档案实图内部目视——「里程碑奖励」青色分区标题与里程碑行不重叠、既有面板质感完整保留。官方多人 build 与预览上传成功；展示版本与大厅 →0.13.45。
  - 边界：手机 FPS / 全 DPR / 真实联网支付 / 用户审美仍未验收；Linux 既有 HDR/缺图/无体素致战斗中央 3D 黑场，不计通过。

- 版本: 0.13.44（**变现措辞去直白化：充值 → 钻石商店 + 分区标题规范**）：
  - 用户要求「别把充值写的那么明面，而是钻石商店等。之后根据 skill 调配各种 UI」→ 玩家侧不再出现直白的「充值/购买」字样，统一按游戏内商店表述；并按 dark-tech 规范给商店面板补分区标题样式。
  - **措辞（玩家可见文案）**：主菜单钱包金按钮 `充值` → **`钻石商店`**（宽度 96→104、字号 16→15 容纳 4 字；图标由 `premium_energy_core` 换成 `gem` 钻石，与标题同语义）；商店面板首充按钮 `¥N 立即购买` → `¥N 立即获取`、钻石礼包按钮 `购买` → `获取`。面板主标题 `钻石商店`、分区 `钻石礼包`/`钻石兑换`、按钮 `兑换`/`签到` 原本已是游戏内表述，保持不变。
  - **分区标题（规范 §5/§10）**：`RechargeShop` 新增本地 `SectionHeader`——金色识别竖条（`C.warn`，付费语义）+ 向右淡出的断线（`D.rule`，`warnDim` 120），替换原来两行裸金色小字；与主菜单青色 `SectionHeader` 同语言、按语义换色。用 `D.measure` 实测标题宽度后再起断线，避免压字。
  - ⚠️ **只改玩家可见文案与绘制，不改任何规则**：`Shared.GEM_PACKS/GEM_SPENDS/FIRST_GIFT` 的 sku/价格/发货内容、`metaState` 字段、`HitTest` action 串（`buy`/`spend`/`buy_first_gift`/`signin`）**全部不变**，只改 `D.text` 的字符串与 `SectionHeader` 绘制。命中几何除钱包按钮宽度 96→104（整条 wallet 仍 `open_recharge`）外不变。
  - 只改 `MetaUI`（钱包按钮文案/图标/宽度 + 注释）、`ui/RechargeShop`（分区标题 + 两处按钮文案 + 注释）、`Scene3DBackend`/`lobby_runtime` 版本行；无新资源/字体/context/RT，不动玩法/价格/车辆几何/广告/IAP/输入命中/CONTAIN 投影。
  - 验证：LSP workspace **0 Error**（24 文件 1017 诊断）；五个真渲染探针（`probe_home`/`probe_windows` 九窗口+暂停/`probe_shop`/`probe_upcard3`/`probe_battle_stress_final`）exit0、目标 overlay/Lua/LoadChunk/空顶点/断言错误 **0**；首页与钻石商店实图内部目视——按钮「钻石商店」+ 钻石图标、面板金色分区标题与断线、无直白充值字样。官方多人 build 与预览上传成功；展示版本与大厅 →0.13.44。
  - 边界：手机 FPS / 全 DPR / 真实联网支付 / 用户审美仍未验收；Linux 既有 HDR/缺图/无体素致战斗中央 3D 黑场，不计通过。

- 版本: 0.13.43（**第四轮「更贵 / 更清晰 / 更好看」：文字描边 + 玻璃漆面 + 侧栏胶囊**）：
  - 用户要求「还想要更贵并且更清晰更好看」，并再次点名 dark-tech 与 0718 两份规范。本轮按规范 §8/§4 补两处**清晰度**缺口，并在既有层次上再加一层**漆面光泽**。
  - **文字描边（清晰度，规范 §8）**：`DrawPixelText` 新增第 7 参 `outlined`，缺省按字号自动判定（`size >= 17` 才描边）；用**四方向偏移同字绘制**（`x±1 / y±1`）而非 `nvgStrokeText`，描边色取 `C.ink` 且 alpha 跟随字色（淡字不被描边反客为主）。此前全项目文字**完全没有描边**，亮字压在亮色敌机/浅底/浅色按钮上边界发糊——这是「不清晰」的最大单一来源。小字（<12px）不描边，避免糊成一团。
  - **玻璃漆面（更贵）**：`Surface.Panel` 上半区加一道极淡斜向高光（裁剪在圆角内，普通面板 alpha 12 / 强调 20）；`Surface.Button` 同款斜高光（alpha 26+glow*26）。色面从「平涂金属」变成「有漆面反射」，与既有内顶受光/内底沉影叠成三层。
  - **侧栏胶囊标记（更好看，规范 §4）**：`Surface.Background` 两侧轨每 92px 加一枚 4×11 圆角胶囊 + 短横线（`cyanDim` alpha 130/90），给侧轨「仪器格」读数感；与既有 46px 刻度错开，不抢焦点。
  - 只改 `Scene3DBackend`（`DrawPixelText` + 版本行）、`ui/PremiumSurface`（Panel/Button/Background）与 `lobby_runtime` 版本；**不改玩法/价格/车辆几何/广告/IAP/输入命中/CONTAIN 投影**，无新资源、字体、context、RT。几何与签名不变（`DrawPixelText` 只加可选尾参，全部既有调用点零改动）。
  - 验证：LSP workspace **0 Error**（24 文件 1015 诊断）；五个真渲染探针（`probe_home`/`probe_shop`/`probe_windows` 九窗口+暂停/`probe_upcard3` 最坏卡/`probe_battle_stress_final`）exit0、目标 overlay/Lua/LoadChunk/空顶点/断言错误 **0**；首页/商店/升级卡实图内部目视——logo 与卡片文字描边清晰、按钮漆面高光可见、侧栏胶囊出现。官方多人 build 与预览上传成功。展示版本与大厅 →0.13.43。
  - 边界：手机 FPS / 全 DPR / 真实联网支付 / 用户审美仍未验收；Linux 既有 HDR/缺图/无体素致战斗中央 3D 黑场，不计通过。

- 附记: vehicle-outline（2026-10-08，六车型白色轮廓；不抢并发展示版本）：
  - 用户要求「为车辆加入白色轮廓」。做法是**翻面外壳**而不是描边 shader：车体全部六段三角面绕整车包围盒中心等比放大 `OUTLINE_SCALE=1.035` 后**翻转绕序**（顶点序 a,c,b、法线随绕序取反），作为第 7 个 section 绑不透明白色 PBR 材质（`MatEmissiveColor` 0.34/0.36/0.40 兜底深空暗场）。默认背面剔除下只剩远侧壳，正好在车体外缘露出一圈白边。
  - 单一来源：几何在 `VehicleGeometry.GetMesh` 生成并随 `meshCache` 缓存；战斗 `Renderer3D.GetVehicleOutlineMaterial` 与展台 `VehicleShowcase.state.outlineMaterial` 各自提供白色材质。`VehicleGeometry.Build(geometry, key, materials, outlineMaterial)` 新增第 4 参，缺省不绑定第 7 段（几何仍在、材质为 nil）。
  - ⚠️ 轮廓必须覆盖**全部六段**（含轮胎/金属/玻璃/灯具），只取车身主漆会让轮胎、轮眉、后视镜穿出白边，轮廓断成一截一截。
  - ⚠️ 放大绕包围盒中心做，「离原点距离」对车体与轮廓**不单调**：`fit = min(1, PLANAR_RADIUS / max(bodyRadius, outlineRadius))`，两者都要约束，否则轮廓挤掉车体原本 2% 碰撞余量。实测车体 ≤1.5883、轮廓 ≤1.6429 = PLANAR，均不越碰撞圆。
  - 顶点量：车体 10956–19950 → 含轮廓后 13200–39900（约 2 倍）。每车仍一个 CustomGeometry、7 段。
  - 验证：几何探针 `probe_outline` 六车 **ALL PASS**（7 段、轮廓=车体放大副本 err<1e-4、法线全反 minDot<-0.99、半径不越 PLANAR、退化三角 0、无材质路径不绑定第 7 段）；展台六车真渲染实图目视白边完整、无空段；战斗隔离冒烟六车依次重建 + 发射 + 暂停/恢复，Lua/overlay/LoadChunk/空顶点错误 **0**。LSP workspace 0 Error（908 Warning/107 Hint）；官方多人 build 与预览上传成功。
  - 边界：主游戏离屏报告整体 FAIL 仍是本地既有噪音（BloomHDR 编译失败/缺图/无体素），战斗 3D 黑场不据此验收；手机性能与用户审美未通过。

- 版本: 0.13.42（巨型车范围伤害内置 1 秒冷却）：
  - 用户明确要求「巨型车的范围伤害加入内置cd1s」。只在 `Game.lua` 加 `BALL_TYPES.giant.areaCooldown=1.0` 与实例 `giantAreaCooldown=0`；圆域分支检查冷却并先置位，子步按 `subDt` 递减至 0，反弹不重置冷却、不同车互不影响。
  - 冷却期间仍走普通碰撞伤害，保留反弹武装资格，冷却结束后的有效命中可再次释放圆域；原半径、伤害、暴击、挥发异常与逐格去重不变。暂停/升级/广告冻结不消耗玩法冷却，新建/回收补车及重开不继承旧车计时。未新增顶层 local、存档、UI 冷却显示或资源，服务端 IAP/钻石职责和多人配置保持。
  - 展示版本与大厅同步 0.13.42；LSP 0 Error（有既有 Warning/Hint），官方多人 build 与预览上传成功。专项规则探针 36/36 案例、409 断言 PASS（0.99秒禁止、精确1秒归零、30/60/120Hz×三档速度、独立车/反弹/冻结/重开/范围/去重），运行 exit0、ERROR0；初版浮点尾数导致晚一帧已修，≤1e-9秒剩余归零。本地最终真渲染已确认 intro 后真实发射、暂停恢复，目标 Lua/overlay/load/空顶点错误 0，Linux 既有 HDR/缺图/无体素问题仍在，不将 3D 黑场或并发 UI 在途画面当验收通过。
  - 维护约束：冷却必须在实际圆域命中时启动，不在反弹/武装时启动或刷新；计时只放玩法步，不能用暂停也继续增长的 `elapsed`。POST-1/2 执行，POST-3 判定跳过（项目小调整，暂无新增跨项目偏好），保留初始随行记忆/settings/VisualCatalog 与并发 UI 改动，只提交本人片段。
- 历史版本: 0.13.41（**多种拖尾样式 + 皮肤商店可替换**；承接 0.13.40 质感恢复）：
  - **用户要求**「以现在为基础设计多种拖尾，加入皮肤商店可以替换」→ 在既有 3D 几何光带基础上做**6 种拖尾样式**，与「车型」并列进皮肤商店购买/装备，两者相互独立。
  - **数据层（`MetaCatalog`）**：新增 `TRAILS`（classic/comet/neon/dash/twin/ember，价格 0/600/1200/1800/2600/3600，各带 `style` 键）+ `GetTrails/GetTrail/GetTrailStyle`；**样式几何参数单一来源** `TRAIL_STYLE_PARAMS` + `GetTrailStyleParams(style)`（headW/tailW/bright/base/dash/twin/warm），Renderer3D 与 MetaUI 共用一份，禁止各写一套。
  - **存档（`PlayerData`）**：新增 `trails`（`AsBoolMap`）+ `selectedTrail`；默认 `{classic=true}`/`"classic"`；`HasTrail/GetSelectedTrail/SelectTrail/PurchaseTrail`（与 Skin 同款，购买即装备）；云合并**解锁取并集、装备仅当本机仍为 classic 时接受云端值**（避免覆盖本地选择）。
  - **渲染（`Renderer3D`）**：`TRAIL_STYLES` 就地改为查 `MetaCatalog.GetTrailStyleParams`；几何构建抽 `EmitTrailQuad` 辅助；样式差异——`dash` 每 2 段画 1 段（断续光点）、`twin` 画左右两条细轨（railW=headW×0.32、偏移 ±headW×1.35，不再画中线）、`warm` 向暖色偏移、`bright/base` 控制明暗与尾端下限。`Renderer3D.Render(game, presentation, skin, trail)` 新增第 4 参；新增只读诊断 `DebugTrailVertexCount()`。
  - **接线**：`Scene3DBackend` 传 `metaState.selectedTrail`；`client_main` 的 `metaState` 增 `trails/selectedTrail`（`RefreshMeta` 填）、新增 `HandleShopTrail` + `preview_trail`/`buy_trail`/`shop_tab` action。
  - **商店 UI（`MetaUI`）**：商店改名「皮肤商店」，顶部加**分页标签**（车型外观 / 拖尾样式，靠左紧凑 116×32，右侧留白给当前项名称+序号）；拖尾页含 2D 预览条（与 3D 同参数、右=车尾亮、左=尾端暗）、6 格浏览卡、购买/装备区。`DrawShop` 拆出 `DrawShopTabs/DrawShopCard/DrawShopPurchase` 供两页共用；`HitTestShop` 加标签与拖尾分支；新增 `MetaUI.PreviewTrail/SetShopTab/GetShopTab`。
  - **验证**：LSP workspace **0 Error**（24 文件 982 诊断）；官方多人 build+预览上传 ✅；数据探针 `probe_traildata2` **ALL PASS**（6 定义唯一、样式参数齐全、未知样式回退 ribbon、默认拥有 classic、购买扣款/自动装备/重复购买被拒、云导出含 trails/selectedTrail）；真渲染 `probe_traile2e` 端到端（真实点击：开商店→切拖尾页→选卡→购买→装备 neon→style 传播）；`probe_trailpoll` 逐样式各发射一次轮询 **6/6 提交几何 maxVerts=48、零 Lua/overlay 错误**；`probe_trailshot` 截图确认两个分页与拖尾预览条（暖色渐宽朝车、双轨两条细轨）。
  - ⚠️ **教训（AB-191）**：`D.rect`/NanoVG 颜色是 **0..255 RGBA**，而拖尾样式色是 0..1 → 预览直接用 0..1 会画成近黑（实测预览条几乎不可见）；跨模块复用「渲染用 0..1 色」时必须 ×255。
  - ⚠️ **教训（AB-192）**：从右往左（车尾→尾端）画矩形时 `xb - xa` 为**负宽**，NanoVG 直接不绘制（不是反向填充）；必须 `rx=min(xa,xb), rw=abs(xb-xa)`。同理参数方向要对：`t` 要在车尾取最大宽/最亮（与 3D「头亮尾暗」一致），否则渐细方向反了。
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
## 本批次新增避雷（v0.13.42 UI 再度加贵 + 找回层次）
- 🔴 **AB-193：用户第三次说「还不够贵」时，加的是「层次密度」不是「新装饰种类」（v0.13.42）**：v0.13.30（柔光）、v0.13.31（交互/动效）、v0.13.40（恢复被删效果）之后用户仍要「加和找回更多东西」。根因：面板/按钮**只有一层金属渐变 + 一条顶亮线**，读起来仍是「一块有色的板」。本轮把共享原语加厚为**多层**：双层扩散投影 + 对角金属渐变 + 内顶受光 + 内底沉影 + 左缘玻璃窄条 + 顶边长短刻度 + 四角螺钉；按钮再加双层落地影 + 上下倒角 + 玻璃条。**加的是同一平面上的层数与明暗跨度，不是新的装饰母题**——加新几何种类会变「花」，加层数才变「厚」。
- ⚠️ **卡片内部也要有厚度，别只加外框（v0.13.42）**：菜单福利/收藏卡、商店分页标签与浏览卡、任务行、天赋入口大卡此前只有平色底 + 描边。统一补「内顶受光 + 内底沉影 + 顶边亮线 + 左识别标记」四件套（`D.rect` 即可，不需新原语）。这类**小卡片的厚度**是「精致感」的主要来源，比大面板更影响观感。
- ⚠️ **背景要「在动」而不是纯渐变（v0.13.42）**：`Surface.Background` 新增**慢速斜向高光扫过**（7s 一轮，确定性，用共享 `uiFx.anim`）。首页/模态背景从「静态径向底」变成「缓慢运行的环境」。⚠️ 需要把 `phase` 传进 `Background`——后端两处调用（`DrawMenu`、`DrawModalBackdrop`）必须同步补 `uiFx.anim`，**签名加参数要 grep 所有调用点**（漏一处就是背景不扫/报错）。
- ⚠️ **给已迁移到 Surface 的共享原语加效果时，先确认没有「影子实现」（v0.13.42）**：`DrawMachinedPanel`/`DrawWindowShell`/`DrawModalBackdrop` 已委托给 `uiFx.surface`，但后端仍保留 `DrawHalftone`/`DrawScanBand`/`DrawTickRing` 等**独立装饰原语**（只被 `DrawModalTechDecor` 用）。加效果改 Surface 即可全屏生效；不要再往这些散装原语里重复实现一遍——两套并存会出现「有的窗有、有的窗没有」的不一致。
- ⚠️ **在别人正在改的文件上做 UI 批次，提交只取自己的 hunk（v0.13.42）**：本批与并发会话（巨型车 CD）同时改 `Scene3DBackend.lua`（它改 `BUILD_VERSION` 一行、我改两处 `Background` 调用）。提交时用 hunk 级暂存，**不整文件 add**；版本号归并发会话，不抢。

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

## 本批次新增避雷（charge-anchor-shell 青圈锚车 + 贴身全息外套）
- 🔴 **AB-325：UI 覆盖层的「圈心」锚点要么走与后端同一投影函数、要么锚 3D 物体的世界坐标——别用「指针坐标」当默认（charge-anchor-shell）**：用户要「青圈以车辆为圆心」，而旧实现圆心直接用 `game.chargeUiX/chargeUiY`（**指针**设计坐标）。**关键判据**：玩法对象在玩法平面 z=0 上时，其屏幕中心 = `project(marble.x, marble.y)`（与后端 `ProjectGamePoint` 同一函数）；直接投影车辆权威坐标即可，**不需要**额外的深度平面（那是 overlay 贴 z≠0 物体时才需要，见 v0.13.15b）。**做法**：快照暴露 `chargeCarX/chargeCarY`（= `activeBall.x/y`，非蓄力时 nil），UI 端**优先**用它投影，指针坐标降为旧调用回退——这样「锚车」与「锚指针」在数据层就分开了。**验收探针要挑「车辆坐标 ≠ 指针坐标」的场景**（本项目车 (270,850) vs 指针 (200,600)），断言圆心等于**车辆投影点**，否则两者相近时锚错也测不出。
- ⚠️ **AB-326：给「爆发残像」再加一层「贴身外壳」时，两者的运动语义要分开——残像冻结基准+扩散，外壳逐帧跟随源车（charge-anchor-shell）**：本项目的两层全息残像是**冻结爆发瞬间的真实显示变换**再沿确定轨迹扩散（AB-323/324），而用户新要的「套在车上的幻影壳」必须**逐帧取源车当前 world transform** 并等比放大（`shellScale`），随 TTL 淡出、源车回收即隐藏。**别把外壳做成第三层残像**——残像会离开车体，外壳必须贴着车。**做法**：同一模块里外壳用独立批次（独立材质/几何），`Sync` 里 `SetWorldTransform(源车当前变换 × grow)`；`Debug()` 增 `shellVisible` 供探针断言「确实启用了」。（货车大战飞机/charge-anchor-shell）
- ⚠️ **AB-327：把「顶点色几何特效」改成「半透明贴图特效」时，通道要成套换——`DiffAlpha` 只读纹理 alpha、不读顶点 rgb（VehicleBowWave）**：本项目冲击波原走 `NoTextureUnlitVCol` + 顶点色（颜色在 `DefineColor`）。要「高质量半透明贴图」时必须同时换三件：①Technique `NoTextureUnlitVCol` → **`DiffAlpha`**；②新增程序化 `Texture2D` 并 `SetTexture(TU_DIFFUSE)`（`DiffAlpha` 的 alpha 来自**纹理**，顶点 rgb 被忽略）；③颜色/透明度改走 **`MatDiffColor`**（`Color(r,g,b,a)`），顶点色可留但无效、顶点 UV 必须真的写（`DefineTexCoord`）。⚠️ 只换 Technique 不换贴图 = 全透明或全不透明；只加贴图不改 Technique = 贴图被忽略。**验收**：探针读 `Debug().material==true` + `actualVertices>0` 证明「批次启用且材质绑定」，但**贴图观感必须 Preview 目视**（本环境 3D 层恒黑）。（货车大战飞机/charge-anchor-shell）
- 🔴 **AB-328：Urho3D 材质 render order 默认是 128（不是 0），要「降低层级」必须设**小于 128** 的值——传负数会回绕成 246（反而更靠上）**（split-child-dim 实测）：本项目要把「分裂/三连子车」沉到正式车之下，首版按「默认 0、负值更早绘制」设 `SetRenderOrder(-10)` → 探针读 `GetRenderOrder()` 得到 **246**（无符号回绕），子车反而**比正式车更靠上**。**判据**：Urho3D `Material::SetRenderOrder` 是 **uint8**，默认 **128**，**值越小越先绘制**（层级越低）；安全区间是 **0..127** 低于默认、**129..255** 高于默认；**不要传负数**。**做法**：降层级取一个明确的 `<128` 常量（本项目 64），并用探针断言 `childOrder < 128` **且** `normalOrder == 128`（把默认值也断进去，否则默认值是多少完全靠猜）。⚠️ 改共享缓存材质前先确认**没有别的部件复用同一 Material**（`CreateMaterial` 按颜色 key 缓存——本项目子车轮若复用 `WHEEL_COLOR` 会连带把正式车轮一起沉下去）。（货车大战飞机/split-child-dim）
- ⚠️ **AB-329：「非正式单位」的灰暗/低层级要落在**表现层**，识别标志走规则层已有的字段，别新造规则状态**（split-child-dim）：用户要「分裂车（不是正式车）变灰暗 + 低层级」——**不要**在 `Game.lua` 加新标志，规则层早已把「非正式车」标成 **`isPrimary = false`**（`CreateSplitMarble` 分裂车、`LaunchMarble` 三连附加车都是），且 `GetSnapshot().marbles` 是**原始引用**（自定义字段渲染层可直接读）。**做法**：`SyncVehicles` 取 `isChild = marble.isPrimary == false` → 换灰材质 + `SetRenderOrder`；材质/几何**只在表现层**（`Renderer3D`）改，规则层的伤害/数量/初速/回收一律不动。⚠️ 材质集合按 `isChild` 分两套（正式/子车），`record` 记 `isChild` 并在变化时重建几何。（货车大战飞机/split-child-dim）

## 本批次新增避雷（six-req-2026-10-15 六项需求）
- 🔴 **AB-336：深空/暗场景里的 3D 特效**必须用「无光照」技术，带光照的会让 `N·L≈0` 变全黑——「几何提交了但看不见」的头号原因（six-req-2026-10-15，用户「冲击波完全没有显示」）**：本项目 V 形波壳上一批把材质从**无光照** `NoTextureUnlitVCol` 改成**带光照** `DiffAlpha`（= `LitSolid` shader），法线朝 ±Z，而场景主光来自上方 → `N·L≈0` → **整片渲染成近黑**（在暗背景上「完全没有显示」）。**判据**：`DiffAlpha`/`DiffVCol`/`PBR*` 都是**带光照**的（shader = LitSolid）；暗场景要「一定看得见」的发光/半透明特效要用**无光照**技术：`NoTextureUnlitVCol`（不透明+顶点色）、`DiffUnlitAlpha`（透明+纹理，无顶点色）、**`DiffVColUnlitAlpha`（透明+纹理+顶点色，最通用）**。**做法**：改技术后必须**真渲染取证**（本项目用独立 Forward 渲染探针 + `-screenshot`，四模式对照：lit=暗灰不可见 vs unlit/vcolalpha=亮青）——LSP/build/错误计数**都证明不了「画得出来」**（同 AB-216/220）。⚠️ `DiffVColUnlitAlpha` 的**颜色走顶点色 × `MatDiffColor`**，故程序纹理要做成**白 RGB + alpha 剖面**（若纹理是灰阶会压暗顶点色）。（货车大战飞机/six-req-2026-10-15）
- ⚠️ **AB-337：给「生命周期随时间变化的特效」加「延迟启动的计时」时，要给它**独立的寿命字段**，别复用另一个视觉的 TTL（six-req-2026-10-15）**：本项目「全息外套」原本与两层残像共用同一个 `life/maxLife`（0.65s）→ 残像到期就把外套一起关掉，无法实现「发射后才开始、3s 才消散」。**做法**：在外套的宿主表里加**独立** `shellLife/shellMaxLife`（=3.0）；蓄力期间保持满值常驻，**只在 `released` 事实锁定后**才递减；取消/切车（未发射）立刻清空。⚠️ 隐藏条件要**两个都归零**才整体隐藏（`not echoesOn and not shellAlive`），否则残像到期会误关外套。⚠️ 「发射」事实的识别沿用既有 `released`（`marble_launched` 事件或飞行中 `chargeBoosted` 车）。（货车大战飞机/six-req-2026-10-15）
- ⚠️ **AB-338：「随存在时间变短」的收尾效果要**按年龄算比例**、且分裂子车要**继承母车年龄**（six-req-2026-10-15）**：用户要「拖尾随子弹存在时间越来越短，分裂继承长度」。做法：①规则层给 `marble.trailAge`（随 dt 递增）；②`CreateSplitMarble` **拷贝 `source.trailAge`**（子车不从 0 重计 → 长度延续）；③渲染层按 `trailAge` 映射一个 `ageFactor`（本项目 `TRAIL_AGE_FULL=0.35` 前满长 → `TRAIL_AGE_GONE=4.5` 收到 `0.16`），据此同时收 **保留采样点数 `keep`** 与 **采样存活时间 `life`**（两条通道各收一次）。⚠️ **验收要读运行时实际保留量**（本项目新增只读 `Renderer3D.DebugTrailLengths()`，探针实测同一飞行车 `keep 16→5`），别只断言常量——常量对不证明运行时真的收短了（同 AB-333）。⚠️ 探针要**锁定真正在飞的车**（`onSling=false`），待发车也在 `trailSamples_` 里但永不飞行，会得到恒定的错误读数。（货车大战飞机/six-req-2026-10-15）

## 本批次新增避雷（bowwave-shell-drag-2026-10-15 三层冲击波 + 外套停留淡出 + 设计空间圆投影）
- 🔴 **AB-339：「拖拽范围是 2D 圆的投影」= 在设计(UI)坐标里钳制，再除以投影缩放换算成玩法位移——不要在玩法坐标里钳制（bowwave-shell-drag-2026-10-15）**：用户「拖拽范围不是 3d 空间的圆，而是 2d 空间对应直径圆的投影」。本项目相机是 46° 斜俯视正交、投影 `scaleX≠scaleY`（实测 0.5400/0.6669）——**玩法坐标里的正圆投影到屏幕是椭圆**（水平/竖直拉同样玩法距离，屏幕位移不等），手感不是「屏幕上的圆」。**做法**：①输入一律在**设计(UI)坐标**里求位移、按 `MAX_PULL` 半径**圆**钳制（屏幕上是正圆）；②再 `÷(scaleX, scaleY)` 换算成玩法位移（玩法平面范围因此是「屏幕圆的投影」椭圆）；③投影缩放由编排层每帧从后端 `GetProjection()` 喂给规则层（`Game.SetPullSpace`）。⚠️ **两个连带**：死区必须按**设计像素**判（`dist <= 15`），不能用玩法长度（会随投影漂移）；瞄准线的 `power` 归一也必须用**设计像素拉距**（玩法长度因 `÷scale<1` 会 >MAX_PULL，用它归一会让弱拉就显示满亮）。⚠️ **验收**：给一个 `scaleY<1` 的投影、竖直拉满 150 设计像素，断言玩法位移 ≈ `150/scaleY` 且**车辆屏幕位移 = 玩法位移×pullPositionScale×scale 仍 = 90 设计像素**（与旧行为一致才说明只是换了钳制空间）。（货车大战飞机/bowwave-shell-drag-2026-10-15）
- ⚠️ **AB-340：「发射后 X 秒才开始消散、之后 Y 秒淡完」= 一个「先停留、后淡出」的两段不透明度，不是一个线性 TTL（bowwave-shell-drag-2026-10-15）**：用户「发射后 2s 才会开始消散，之后 3s 平滑消散完」——若只给一个 `shellSeconds` 线性淡出，则发射后立刻开始变淡，与「2s 后才开始」矛盾。**做法**：把寿命拆成 `shellHold`（停留）+ `shellFade`（淡出），`shellMaxLife = hold+fade`；不透明度 `alpha * min(1, life/fade)`——`life > fade` 段恒为满值（停留），`life <= fade` 段线性淡出。⚠️ 别用一个 `1 - t` 的线性式（那是「立刻开始、均匀淡完」，没有停留段）。验收要**分别断「停留期仍满值」和「淡出期在递减」和「结束归零」三个点**（本项目实测发射后 1.5s 仍在停留、2.5s 进入淡出、5s 归零）。（货车大战飞机/bowwave-shell-drag-2026-10-15）
- ⚠️ **AB-341：「太小太简单」的 3D 特效 = 放大尺寸 + 加**层数/纵深**，不是调亮或加粒子（bowwave-shell-drag-2026-10-15）**：用户「冲击波太小太简单」——直接解法是 ①**放大**几何参数（V_DEPTH/V_SPREAD/THICKNESS/HALF_HEIGHT 全面上调）；②**叠层**（同一形状按不同缩放/亮度/前向偏移叠 2–3 层：外层最宽最淡 → 内层最窄最亮白热核），做出「有纵深的冲击波墙」。⚠️ 加层要**同步放大顶点预算常量**（本项目 `PER_CAR` 从 `SEGMENTS*24+12=396` 改成 `SEGMENTS*24*3+12=1188`），否则 `Debug().vertices` 与实际不符、探针断言会错。（货车大战飞机/bowwave-shell-drag-2026-10-15）

## 本批次新增避雷（trail-opacity 拖尾整体透明度）
- 🔴 **AB-334：要「不透明几何变半透明」时，只改顶点 alpha 没用——`DiffVCol` 的 base pass 默认 `BLEND_REPLACE`，必须克隆 technique 把 pass 改成 `BLEND_ALPHA`**（trail-opacity 实测）：本项目 3D 光带拖尾走 `Techniques/DiffVCol.xml`（消费顶点色），其 base pass 是**不透明**的 → 顶点 alpha 被**忽略**，只改 `Color(r,g,b,a)` 的 a 不会让它透明。**做法**：`cache:GetResource("Technique", …):Clone("TrailAlphaVCol")` 克隆一份，`alphaTech:GetPass("base"):SetBlendMode(BLEND_ALPHA)`（`BLEND_ALPHA = 3`），再 `material:SetTechnique(0, alphaTech)`。⚠️ **必须克隆、不能改共享资源**——敌机/飞散箱/瞄准线也用同一份 `DiffVCol`（`cache` 是进程级缓存，改的是同一对象），直接 `SetBlendMode` 会把它们一起变透明。**判据/验收**：`GetPass(0,"base"):GetBlendMode()` 应返回 `3`；探针要同时断「混合模式已改」**和**「几何仍提交顶点」（改 pass 不该破坏几何）。（货车大战飞机/trail-opacity）
- ⚠️ **AB-335：「整体降低某属性」的改动要收敛到**一个常量 + 一个作用点**，并同步 2D 预览**（trail-opacity）：用户「全部拖尾不透明度降低 70%」——**别**逐个调用点手改 alpha，而是 ①定义一个常量（`TRAIL_OPACITY = 0.30`）②在**所有层汇聚的那个函数**里统一乘（本项目光带全经 `EmitTrailQuad`、粒子全经 billboard 提交那几行）③**同步 2D 商店预览**（项目契约「预览里看到的差异 = 实机差异」，`MetaUI` 里另建同值常量 `TRAIL_PREVIEW_OPACITY`，注释互指）。⚠️ 粒子通道（`DiffAlpha`，本就混合）与光带通道（`DiffVCol`，需改 pass）的**实现方式不同**——前者改顶点 alpha 即可，后者必须先改混合模式（见 AB-334）；「降透明度」要两条通道各验一次。（货车大战飞机/trail-opacity）

## 本批次新增避雷（shell-scale-1.5 全息外套尺寸）
- ⚠️ **AB-332：用户给的「倍数」与相邻描述矛盾时，取最合理的那个读数、并在回复里点明你的解读（shell-scale-1.5）**：用户「透明度40% + 比车稍微大一点 + **.5 倍大小**」——`.5×` 会让外套**比车小**（与「稍微大一点」直接矛盾）、`5×` 远超「稍微」，只有 **1.5×（比车大一半）** 同时满足两句。**做法**：①按最合理解读实现（本项目取 1.5）；②**在回复首句说明这是你的解读**（「按 1.5 倍实现，若你指别的倍数我再改」），别把猜测写成用户确认；③把倍率放**单一常量**（`VisualCatalog.CHARGE_HOLOGRAM.shellScale`）——改口径只需改一处。（货车大战飞机/shell-scale-1.5）
- ⚠️ **AB-333：验「缩放倍率」要读**实际世界变换比**，不能只断言配置常量**：只断言 `VisualCatalog.shellScale==1.5` 只证明「配置对」，不证明「运行时真按它缩放」（可能被 `SetWorldTransform` 的写法吃掉、或被源车 scale 覆盖）。**做法**：模块内记 `shellScaleRatio = 外套世界缩放 / 源车世界缩放`（只读诊断），探针断言 `≈1.5`（本项目实测 **1.5000**）。⚠️ 源车 `worldScale` 为 0 时要防除零。（货车大战飞机/shell-scale-1.5）

## 本批次新增避雷（drag-slowmo 拖拽全局减速）
- ⚠️ **AB-330：给「拖拽/瞄准中」加全局减速时，复用既有 `timeScale` 链路、别另造冻结机制（drag-slowmo）**：本项目已有 `Game._holdSpeed.active → s.timeScale=2`（空手长按加速）与「各特效模块在 `Sync` 里只乘一次 `timeScale`」的契约。加「拖拽减速」只需①`BALANCE.dragTimeScale=0.2`；②`Game.Update` 的 dt 乘法补一个 `dragSlow` 因子；③快照 `s.timeScale` 改为**优先级**（拖拽蓄力 > 空手长按）。**特效模块零改动**——它们已经乘 `timeScale`，自动跟着慢。⚠️ **`elapsed` 不要跟着放慢**：它是真实时钟，UI/震屏/表现衰减依赖它，冻结会让 UI 卡顿；只放慢玩法 dt 与依赖 `timeScale` 的特效。（货车大战飞机/drag-slowmo）
- ⚠️ **AB-331：「拖拽减速」的验收要测「玩法时间真的慢了」，不能只断言 `timeScale` 字段**：`s.timeScale` 只是**表现层字段**，玩法减速发生在 `Game.Update` 的 `dt` 乘法里。只断言 `timeScale==0.2` 会漏掉「dt 乘法没接上」的情况。**做法**：探针量**同一敌机、同一段真实帧数**下的下落位移比（本项目拖拽 30 帧 dy=1.542 vs 正常 7.711 → **ratio 0.200**，精确 5 倍）。⚠️ 采样要**锁定同一个 `enemy.id`**（编队会新增/淘汰，按列表首元素取会在切换时得到错误比值）。（货车大战飞机/drag-slowmo）

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

- **AB-278：粒子/尾迹发射「只算增量距离」，不要每帧重走整条历史轨迹**（trail-particle-lag-fix，2026-10-12）：按「每米 N 颗」撒布粒子时，若每帧遍历**整条** `points` 采样并对每段累加 `len*emit`，同一段会被**反复发射**（N 倍过量）→ 撞上限。做法：记录 `track.emitX/emitY`（上一帧发射点），每帧只沿「上一帧点 → 当前点」这段**新距离**发射，`acc` 跨帧保留余量。判据：**稳态粒子数 ≈ 发射率 × 寿命 × 速度**（本项目彗星 60×0.42×~1.2≈30，实测 28-32 吻合）；若实测远大于估算，就是「重走历史」了。
- **AB-279：有「槽位上限」的粒子系统，超预算要丢最老的，不能丢最新的**（trail-particle-lag-fix，2026-10-12）：提交时 `for _,p in ipairs(list)`（从头=最老）填槽，超上限就丢弃后面的（最新的）——而「最新」恰好是**贴发射源（车尾）**那批，于是源头段永远没粒子 = 「拖尾滞后/跟不上」。做法：**从列表尾（最新）往回取** `for i=#list,1,-1`，超预算丢最老的（尾端）。**判据**：任何「跟随移动实体」的粒子/尾迹，**离实体最近的那批必须优先保留**（同 AB-234「锚定贴物体那端」的同一原则）。
- **AB-272：给「单曲循环」的 BGM 加「更多曲目」时，要的是「播放列表轮播」不是「多首随机播」**（bgm-playlist，2026-10-11）：用户说「音乐太少」——直接解法是**每态一个播放列表、曲终自动切下一首**，不是随机抽一首（随机会出现「刚放完又抽到同一首」）。要点：①曲目长度用 `sound:GetLength()` 取**真实时长**驱动轮播（不写死秒数）；②长度取不到（异常/静音资源）时**回退单曲循环**，别让计时器无限涨却不切换（防探针 0 长度资源死循环）；③切主题与曲终轮播**复用同一个 `StartTrack`**（都在另一通道交叉淡入、旧通道淡出）。⚠️ 无 `/dev/snd` 时只能由**纯模块探针喂长 dt**证明「喂 250 秒不崩、键不变」，**实际听感必须 Preview 真机**。
- **AB-273：`text_to_music`/`text_to_sound_effect` 生成的随机名文件，重命名后必须连 `.meta` 一起清理**（bgm-playlist，2026-10-11）：生成器会为**随机名 ogg**（`music_<ts>.ogg`）也产出 `.meta`，重命名 ogg 为语义名时这些 meta **不跟着改名** → 变孤儿（无同名 ogg）。做法：重命名后扫 `for m in assets/audio/*.meta; do [ -f "${m%.meta}" ] || rm "$m"; done`，再确认 `ls *.ogg | wc -l` == `ls *.ogg.meta | wc -l`。
- **AB-268：给「已满 200 顶层 local」的后端加功能，一律挂表 + 新模块**（audio-system，2026-10-11，承接 AB-265）：`Scene3DBackend.lua` 顶层 local 已满 200——加音频时**所有新增都是**「`uiFx.audio`（挂 uiFx 表）+ `Backend.TickAudio/PlayUiSfx`（挂 Backend 表）+ 一个 `require`」，**零新增顶层 local**。这是该文件唯一安全的加法模式；`git diff | grep "^+local "` 自检应为空。
- **AB-269：换「渲染通道」是解决「这个样式丑/和普通没区别」的最强手段——不要继续调同一条光带的数值**（trail-particle-styles，2026-10-11，承接 AB-221）：用户点名「彗星一点也不好看」「流光和一开始的普通没什么区别」——两者当时都是**同一条三角带光带**的数值变体（彗星 taper/bulge 鼓包、流光 flicker 明暗），**形态上仍是「一条光带」**，所以无论怎么调都读作「同一根东西」。做法：**换通道**——把这两个样式从 `CustomGeometry` 三角带换成 **billboard 粒子**（真粒子系统），形态上与光带**根本不同**（离散光尘 vs 连续带）。**判据**：当用户说某个变体「丑 / 和默认没区别」时，先问「它和默认是不是同一个通道的同一个形状？」——是，就别再调数值，**换通道**（光带↔粒子↔…）。⚠️ 换通道后必须处理**互斥**：粒子样式下要**清空并停用**光带节点（`tracks` 置空 + `active=false` + `or particleStyle` 进入清理分支），否则两套叠着画（本项目实测「光带顶点残留在节点上」= 粒子与光带同时可见，`maxVerts=162` 不归零）。
- **AB-270：给「只有部分变体用」的数据表加字段，`@field` 必须写 `|nil`**（trail-particle-styles，2026-10-11）：给 `TrailStyleParams` 加粒子轴（emit/pSize/…）时，只有 comet/dash 有、其余样式没有 → LSP `assign-type-mismatch`：`Cannot assign {…} to table<string,TrailStyleParams>. missing member emit`。**修法**：这些字段声明为 **`---@field emit number|nil`**（可选）。**通用规则**：往「共享的变体参数表」加字段时，若该字段**不是所有变体都有**，`@field` 一律加 `|nil`；否则 LSP 会拿「最严的那个变体」去要求全体。同族：v0.13.56 的 `RegisterScreen` 形参非空注解（AB-218）——**Lua LSP 的「可选性」要在类型注解里显式表达**。
- **AB-267：音频「从 0 到 1」的落地顺序——先纯模块探针证数据通路，再真渲染集成探针证不打断游戏**（audio-system，2026-10-11）：①**独立模块探针**（只 require 模块 + 自建 `Scene()`，不跑游戏 3D）——**规避并发会话在途的 3D 半成品**（本批真渲染首跑就撞上并发未提交的 `Renderer3D:1404 trailParticleSets_`，纯模块探针完全不受影响），精确断言「加载 N/N、BGM 键随状态切换、Shutdown 幂等」；②**真渲染集成探针**走 `client_main` 真实路径，证明「不打断 2D/3D/快照」。**两个探针各证一半**。⚠️ 音效要用**播放池轮转**（`pool[cursor]; cursor=cursor%#pool+1`）不要每帧新建 SoundSource；BGM 切换用**两条通道交叉淡入淡出**不要 `Stop` 后 `Play`（断音）。⚠️ 本环境**无 `/dev/snd`**，探针只能证「加载+状态机+通路+不崩」，**实际发声必须 Preview 真机**。
- **AB-265：`Scene3DBackend.lua` 顶层 local 已满 200，新增「菜单按钮/命中」只能内联几何 + 挂 `Backend.` 表**（gear-settings，2026-10-11）：加齿轮入口时该文件顶层 local **正好 200**（Lua 硬上限，超了 `LoadChunk failed` 全屏黑、LSP/build 都不查）——所以按钮几何用 **`do ... end` 块内联局部量**（不占模块级槽位），命中函数写成 **`function Backend.HitTestMenuGear(...)`**（挂表，不新增 local）。**判据**：给该文件加任何东西前先数顶层 local（脚本统计 `^local\s+\w`）；=200 时唯一安全的加法是「内联几何 + 挂 Backend 表 + 新模块 require」。同 AB-166/AB-217。
- **AB-266：「危险操作」要手机键盘输入确认码，不能只点一次按钮**（gear-settings，2026-10-11 用户点名）：用户要求「恢复购买/清空存档」点后弹**手机键盘（0-9 * #）**、输入正确密码才执行——因为移动端没有系统级二次确认，误触一次就丢全部存档。做法：`ui/Settings.lua` 做成**两个屏**（`settings` 列表屏 + `reset_confirm` 键盘屏，`MetaUI.RegisterScreen` 各注册一次）；键盘用**电话布局 3×4**（1-9,*,0,#）；确认码按操作区分（restore/delete 各一个常量）；`input_ == ConfirmCode()` 才把「确认」按钮从 disabled 变可点。⚠️ 键盘**几何必须留足高度**（本项目首版面板 628 高、键 84px → 第 4 行 `*0#` 被面板底边切掉且压住按钮；改 676 高 + 键 68px + 键盘上移后完整）——**多行网格布局要按 `行数 × (键高+间隙) + 按钮区` 反推面板高，别拍脑袋**。
- **AB-260：金属立体艺术字的「亮底」用法——白 tint + 等比放大铺满按钮，优于「暗铭牌 + 白 tint」**（arttext-fill-white，2026-10-11，承接 AB-258）：AB-258 定「金属素材用白 tint」，本批补**亮底无铭牌**这一档——用户要「直接占满按钮、无黑幕」时，**去掉暗色铭牌**，白 tint + `ArtText.FitHeight(key, 接近按钮高)` 等比放大，金属字直接压在亮色按钮上。**判据**：金属字的「底」可以就是按钮色本身（青色即对比）；**只有当按钮色与金属灰明度太接近**时才需要铭牌垫底。⚠️ 母版是**完整成品**，只能**等比**缩放（AB-207），用 `FitHeight` 算 scale，别非等比拉伸。
- **AB-258：`nvgImagePatternTinted` 乘法染色——「金属/立体」素材用青/深 tint 都会塌，默认用白 tint**（cta-arttext-fit，2026-10-11）：v0.13.57 记过「深 tint（`C.ink` 4,8,16）把两色母版塌成黑疙瘩」；本批发现**青 tint 同样会塌**——`C.cyan`=(0,229,208) 的 **R 通道=0**，金属灰的红色分量被直接乘没，整块读成**扁平暗青**、立体倒角全丢（离线三变体对比实测）。**判据**：tint 必须**三个通道都接近白**（白/浅灰）才能保住金属明暗层次；任何「某通道≈0」的 tint（青 R=0、红 G=B=0、深色全体）都会塌。**做法**：金属/立体素材的 tint 用**白 `{255,255,255}`**，语义色（青/金/绿）交给**底/描边/铭牌**承载——亮底按钮配**暗色铭牌 + 白 tint**，深底直接用白 tint。⚠️ 通用规则：`nvgImagePatternTinted` 是**逐通道乘法**，「非白 tint」只在素材本身是「纯白 + 近黑」两色平块时才安全（乘完仍保留两级差）；一旦素材有**中间灰阶**（金属/渐变），非白 tint 会把灰阶压向 tint 色而丢层次。⚠️ **本批追加**：商店分页标签原用 `C.warn`/`C.dim` 非白 tint（金/暗灰）也踩此坑 → 改白 tint + 降 alpha 表「未激活」。
- **AB-259：「母版尺寸变更」必须同步核对所有绘制点的硬编码偏移**（cta-arttext-fit，承接 AB-236 同族）：arttext-metal 把 `startbattle` 母版 38→44 高，但 CTA 绘制里**副标题固定在 `ctaY+52`**、铭牌高 `ah+8`——母版一变，`ah` 变大、铭牌变高，**副标题就压到铭牌上**（实测重叠 4px）。**规则**：改素材母版尺寸时，`grep` 该素材 key 的**全部绘制点**，逐点检查「依赖 `ah` 的偏移 + 不依赖 `ah` 的固定偏移」是否还兼容；容不下就**先加高容器**（本批 CTA 72→84），再调各元素 y。同 v0.13.29 AB-175「先让容器变大，再让字号自适应兜底」。

- **AB-242：用户说「素材装载出错」时，先看装载日志证明「加载成功/失败」，再目视素材本身是否「画坏了」**（digit-arttext-regen，2026-10-10）：用户报「很多其他艺术字装载出错」——真渲染日志实锤 `[ArtText] pixel titles loaded=8/8` + `[DigitFont] pixel digits loaded=10/10`，**运行时加载 100% 成功**。真凶是**部分字标图本身糊**（AI 生中文字形没画清，core/outline 像素比仅 0.09，其它清晰张 0.28–0.44）。**判据**：①先 grep 装载日志确认「有没有加载失败」；②再**把素材拼成放大图目视**（看字形是否清晰、两色是否分明）；③只有这两步都排除后才怀疑代码路径。⚠️「装载出错」的语义可能指「图本身坏」而不是「加载失败」——**别一上来就查 nvgCreateImage/路径/uuid**（本批险些白查一轮）。同类：数字/字标这类「两色母版」的质量指标是 **core(白芯)/outline(轮廓) 像素比**，比值过低（≈0.1）= 只剩描边糊块，必重出。
- **AB-243：两色像素母版「按高度归一」而不是「按 bbox 等比」**（digit-arttext-regen，承接 AB-236/v0.13.24）：数字 0–9 的字形宽高比不同（1 窄、8 宽），若各自按 bbox 等比缩放，节点上的数字会**高低不齐**。正确做法：后处理统一缩到**同一字形高度**（本项目 `GLYPH_H=26`），宽度随字形浮动、逐字记宽度表。**数字的「两色」用腐蚀法生成**——alpha 二值化得掩码 → **4-邻域腐蚀**得白芯 → 原掩码减芯得近黑轮廓；比按亮度阈值切更稳（AI 草案的白芯亮度不一）。⚠️ **重出沿用旧文件名 + 保留旧 .meta uuid**（`ui_digit_%d.png` / `ui_tt_*.png` 覆盖），零路径/uuid 风险；草案必须先移出 assets 到 `/home/Maker/<batch>/drafts`。
- **AB-237：倒置列表的滚动范围必须从布局公式推导**：若节点位置含 `+scrollOffset`，向更高关滚动需要正偏移，不能沿用普通列表的负范围。测试同时覆盖默认定位最新、双端钳制、拖动实际位移、少内容居中和拖后轻点；只测 `ScrollEnd()==true` 证明不了内容移动。
- **AB-238：XHR 空对象报告要保留证据边界**：错误次数不是请求次数，Lua `pcall` 和成功业务日志不能证伪宿主 HTTP 失败；哈希不匹配不能独自证明旧包，8 小时时差可能是时区。应关联同会话 URL/方法/状态/响应类型/initiator 与已定义版本字段；未拿到请求证据时不得通过禁云或过滤错误假称修复。

## 本批次新增避雷（offscreen-spawn-cap 屏外生成上限）
- 🔴 **AB-231：给「生成队列」加限流时，必须同时覆盖**所有**生成路径——特殊单位往往不走队列（offscreen-spawn-cap 真凶）**：用户要「屏外敌机超过 3 架就暂停生成队列」。我在 `SpawnNextNormalEnemy`（逐架放出的普通波队列）加了检查，8 种子探针**仍全部峰值 4**。真凶：**精英/护航/首领走 `SpawnSpecialEnemy`，完全不经过 `pendingSpawn` 队列**——普通波还有几架没放（屏外 2）时，精英波照常启动，随后那几架放出就顶到 4。**规则**：给「生成」加限流前，先 `grep CreateEnemy` / `grep Spawn` **列出全部生成路径**（本项目：普通波队列 + 精英 + 护航 + 首领召唤 + 复活重排），逐条判断是否需要同样门控。**只改「队列」那条永远不够**——特殊单位是最容易漏的那条。
- ⚠️ **AB-232：「逐架放出」与「波次启动」两处门控的**计数口径不同**，不能统一（offscreen-spawn-cap）**：①**逐架放出**只数**屏外在场**数（放一架、停一次，`>= cap` 就推迟）——**绝不能把「本波待放数 `remaining`」也算进来**，否则整波一开始 `remaining=10` 就永远 `>cap`、**一架都放不出（死锁）**。②**波次启动**必须把 **`remaining`** 也算进去（待放的将来也会生成在屏外；否则「屏外2 + 队列还有1架」会放行新一波 → 顶到 4）。**同一个上限、两种口径**——写之前先问「这个检查点是『放一架』还是『开一波』」。
- ⚠️ **AB-233：「屏幕外」这类空间判据要复用既有口径，别新造（offscreen-spawn-cap）**：项目里 `ResolveFleetOverlaps` 已有 `aOffscreen = ay + ah < -102`（敌机**底边**在可见战场顶之上）。新加检查直接用同一式 `enemy.y + gridH*brickSize < -102`，**不新增具名常量、不改判据含义**——否则「生成时算屏外」与「重叠分离时算屏外」会漂移（两处对同一架机给出不同结论）。
- ⚠️ **AB-234：布局随机 + `os.time()` 种子会让「峰值类」探针结果不稳定，必须固定种子复测（offscreen-spawn-cap 踩到）**：v0.13.47 起 `ResetGame` 用 `os.time()` 播种关卡布局 → 同一段探针**两次运行布局不同**（一次峰值 3、一次 4），无法定位。做法：探针里显式 `SC.BeginStage(stage, fixedSeed)` 跑**多个固定种子**（本项目 8 个），把「偶发峰值」变成「每个布局都验」。**凡是验证「上限/峰值/最坏情况」的探针，都要固定种子并覆盖多布局**，否则会被随机性骗过。

## 本批次新增避雷（trail-style-mechanics 拖尾样式精进）
- 🔴 **AB-221：给「同一种东西的多个变体」加差异化时，要加「机制轴」而不是继续调数值（trail-style-mechanics，承接 AB-214）**：六种拖尾原先是同一条光带的宽/亮/断续/双轨数值微调，玩家读到的是「同一张卡的两个强度」。做法：在纯数据表里**加一组正交的机制轴**（本项目：宽度曲线指数 `taper`、头端鼓包 `bulge`、色相游移 `hue`、图案流动 `flow`、明暗脉动 `pulse`、双轨收拢 `railTaper`），每种样式**占不同的轴**，并保留一个「中性基准」变体（本项目 `ribbon`）。**验收探针必须断言「各变体在机制轴上的签名两两不重复」**，否则很容易悄悄退回「更大的数字」。
- ⚠️ **2D 预览必须与 3D 用「同一套参数 + 同一套机制轴」（trail-style-mechanics）**：预览若只复刻了部分轴（本项目旧预览只读宽/亮/断续/双轨，不读 taper/bulge/hue/pulse），就会出现「预览里六条几乎一样、实机却不同」的误导。做法：预览与渲染共用 `MetaCatalog.GetTrailStyleParams`，逐轴实现同一公式（含共享动画相位 `D.anim()`）。
- ⚠️ **样式动画相位要按「玩法 dt」累加、非 playing 不推进（trail-style-mechanics）**：流动/脉动用共享相位 `trailPhase_`（在 `SyncVehicleTrails` 里 `+= dt`），**不能**用 `game.elapsed`（暂停/升级/结算期间仍增长，会让尾迹在冻结画面里继续动）。这与「CD 计时只放玩法步」是同一条契约。
- ⚠️ **「像素取证」是这类纯观感改动的唯一有效验收（trail-style-mechanics）**：LSP/build/错误计数**都证明不了「画得不一样」**。做法：逐样式真渲染截屏 → 实图目视 + 像素差（本项目经典 vs 余烬 56363 像素差）。本环境 `-screenshot-frame=N` 对「启动首帧附近」有效、对深层帧不可靠，取样式差异用**商店 2D 预览**（同一帧内逐样式切换截屏）比等 3D 飞行帧可靠。

## 本批次新增避雷（v0.13.56 第 1 关测试模式询问）
- 🔴 **AB-217：新增「元层弹窗」优先走 `MetaUI.RegisterScreen` 插件注册，不要往 `Scene3DBackend` 加状态（v0.13.56）**：`Scene3DBackend.lua` 顶层 local 已 **197/200**（AB-166），新增一个弹窗若要「后端持有 open 标志 + 配对窗口动画 + 命中分发」，至少要 4–5 个 local 槽位 → 极易撞 200 上限导致 `LoadChunk failed` 全屏黑。**正确做法**：写成独立 `ui/Xxx.lua`（纯绘制 + 命中，`D` 依赖注入），`MetaUI.RegisterScreen("name", Draw, HitTest)` 注册 → **自动复用 `metaScreen_` 那一套**（入场/退场弹动 `DrawAnimatedWindow`、`WindowInput` 命中逆变换、开新屏作废旧残影），后端**零改动**。开屏 = `metaState.screen = "name"`（编排层 `OpenMetaScreen`），输入经 `HandleMetaPointerDown/Click` → `Backend.HitTestMetaScreen` 自动分发到你的 HitTest。
- 🔴 **AB-218：`RegisterScreen` 的 Draw/HitTest 形参注解必须写 `---@param meta MetaState`（非空），否则 LSP 报 `param-type-mismatch` Error（v0.13.56）**：`MetaUI.RegisterScreen(name, drawer, hitTester)` 的形参表把 meta 声明为**非空** `MetaState`；若你的模块写 `---@param meta table|nil` 或 `table?`，注册那一行会报 `expected fun(..., meta: MetaState) but found fun(..., meta: table?)` —— 两个 Error，且**改成 `MetaState|nil` 也一样报**。只能写**非空** `MetaState`（函数体内不要做 `meta and ...` 判空，或判空后仍标注非空）。⚠️ 改完 LSP 有缓存，需 `touch` 文件或重新诊断才刷新。
- 🔴 **AB-219：新增「元层屏」必须确认它开在**菜单态**——`state ~= menu` 时任何依赖菜单态的待决逻辑都不会生效（v0.13.56 踩到）**：本项目「确认询问 → 下一帧进关」的待决跳关放在 `HandleUpdate` 里判 `state == "menu"`。若在 `stagewin`（胜利结算）态直接 `OpenMetaScreen`，屏能显示、但**永远不跳关**（玩家点了没反应）。修法：**开屏前先 `Game.GoToMenu()`**（回菜单再开询问屏），并在同帧 `RefreshSnapshots()`。⚠️ 通用规则：把「新屏挂在哪个 state 下」先写清楚——凡是「只在菜单态画/只在菜单态判」的屏，从非菜单态进入时都要先回菜单。
- ⚠️ **AB-220：本地离屏 `-screenshot-frame=N` 在本环境可能完全不生效，不能据此自证画面（v0.13.56 实测）**：本次三张截图（`-screenshot-frame=120/200/420`）**字节数完全相同、均为同一条早期菜单帧**，即截的是「启动首帧附近」而非第 N 帧。后果：**只能证明「无渲染错误 + 命中几何正确 + 状态机正确」，不能证明新屏真的画出来了**。凡「新 UI 屏」的交付，若像素取证/实图均拿不到，**必须在记忆与回复里显式标注「画面未经自证，待 Preview 目视」**，不得把行为探针 PASS 写成画面通过（同 AB-216「渲染无报错 ≠ 画出来了」）。

## 本批次新增避雷（ui-trace-density-2 NanoVG 命令缓冲溢出）
- 🔴 **AB-216：NanoVG 逐点绘制会撑爆单帧命令缓冲，导致本帧后续绘制被「静默丢弃」（2026-10-08 实测，本轮最重要）**：半调/点阵若按「每点各起一条 `nvgBeginPath` + `nvgFill`」写，几千条命令后缓冲溢出，**该帧之后的所有绘制消失**——**没有任何报错、没有 `overlay stage failed`、没有 Lua 异常**。本项目实测症状：商店/窗口**只剩背景，卡片与文字全没了**；首页因先画内容后画纹路所以「看起来正常」，迷惑性极强。
  - **修法**：同色同形的一批点/圆**必须合并为单一路径**——`nvgBeginPath()` 一次，循环里只 `nvgCircle()`，最后 `nvgFill()` 一次。命令数从 N 降到 3。
  - **定位法（可复用）**：①**像素取证**——同帧数设计区内 `r+g+b>200` 的像素数（HEAD 74904 vs 出问题 4372），比看日志可靠；②**同帧对照**——用 `git show HEAD:<file>` 铺进探针工程跑同一帧；③**二分文件→二分函数→二分参数**（本轮改步长 8→22 使 bright 回升，直接锁定「点数」而非「面积」）。
  - ⚠️ **验收纪律**：「渲染无报错」≠「画出来了」。本轮全程错误计数为 0 但画面确实缺内容。**加了逐点/循环绘制后，必须做像素取证或实图目视**，不能只 grep 错误。
- ⚠️ **大面积纹理的调用成本要按面积钳（2026-10-08）**：即便合并了路径，点数仍随面积平方增长。做法：按面积**自适应放大步长**（`step = max(step, sqrt(w*h / budget))`，本项目 budget=600），小卡片保持密度、全屏背景自动稀疏。规范 §3 也提示「大面积纹理优先 `nvgImagePattern` 平铺」。
- ⚠️ **战斗侧独立模块需要自己的一份纹路实现（2026-10-08）**：`ui/BattleHUD` 不 require `ui/PremiumSurface`（避免跨模块依赖），纹路母题需**本地再实现一份**（本项目 `BattleHUD.Trace`）。⚠️ 它被 `Surface`（定义在前）调用，必须**前向声明 `local Trace = nil` + 后置赋值**（AB-100 同族），否则 `local function` 写在使用点之后会解析成全局 nil。

## 本批次新增避雷（ui-trace-density 装饰纹路加密）
- 🔴 **AB-215：用户说「纹路不够多」时要加的是「无关紧要的纹路」，不是新功能或更亮的装饰（2026-10-08 用户点名）**：用户原话「还是不够贵**无关紧要的纹路不够多**」——「无关紧要」是关键词：**不承载任何信息**的装饰线/网/点，用来提高**画面密度**，而不是加读数、加图标、加对比度。做法：在**共享原语**里加一组纯绘制 helper（微网格 / 斜向拉丝 / 电路刻纹 / 四角取景折线 / 断线 / 点阵），改一处即全屏生效。⚠️ **每个 helper 自带 `nvgIntersectScissor` 裁剪**（否则斜纹/网格会越出宿主几何）、**全部低 alpha**（网格 9–16 / 斜纹 5–12 / 点阵 26–46）、**门槛化**（小控件不画，否则糊成一团）。
- ⚠️ **加纹路要「改共享原语 + 小卡片助手」两层，别逐屏重画（2026-10-08）**：大面板/窗口/按钮/背景/展台都在 `ui/PremiumSurface`（改 5 处函数即全覆盖）；MetaUI 的小卡片（福利卡/商店卡/任务行/图鉴卡/排行行）各自散落，抽一个本地 `CardTrace(ctx, r, alpha)` 复用 `D.grid`+`D.corner` 再逐个接上。**先找共用入口，再补散点**。
- ⚠️ **纹路是「只画」，绝不参与命中与几何（2026-10-08）**：本批全部新增都是 `nvg*` 绘制调用，没有一处改 rect、没有一处进 `HitTest*`。交付前确认 `git diff` 里没有 `Inside(`/`HitTest` 的改动——**视觉加密不该动几何**（同 v0.13.30 的 AB-177 纪律）。
- ⚠️ **低 alpha 的逐条/逐点绘制仍是「调用次数」成本（2026-10-08，待真机验）**：网格/点阵/斜纹都是循环内 `nvgBeginPath+Stroke/Fill`，alpha 低但**绘制调用数随面积增长**。本项目已用**尺寸门槛**压住（网格只在大面板、点阵只在角落小区域、斜纹只在 ≥110 宽按钮）。手机 FPS 未验收——若真机掉帧，先降 `step`（间距）而不是砍掉整组。

## 本批次新增避雷（v0.13.53 提消费欲望：付费路径转暖金）
- 🔴 **AB-211：用户说「太冷酷 / 没有消费欲望」时，缺的不是「更贵」而是「温度」（v0.13.53 用户点名）**：v0.13.30/31/40/42/43 四轮都在加「贵」（层次、柔光、描边、漆面），用户仍说「还是不够贵」——本批参考图揭示了真因：**全屏冷色（青/海军蓝）里唯一暖色是金色按钮**，而本项目首页唯一的暖色（钻石商店）恰恰被画得最平（纯色 `D.panel`）。**结论**：「贵」= 层次/光；「有消费欲望」= **暖色锚点 + 付费路径整体暖化**。做变现类审美反馈时先问：屏幕上有几个暖色点？付费入口是不是其中最亮的那个？
- ⚠️ **「暖化」要按「语义分区」而不是全屏泛金（v0.13.53）**：只把**付费/收藏/稀有语义**的路径转暖（首页钻石商店按钮 + 商店分页标签/浏览卡/购买区），**战斗 HUD 与冷色主操作保持青**。全屏泛金会破坏 dark-tech 的「青=主操作」契约（v0.11.0 三色语义），也会让「哪个要花钱」重新变模糊。未选中的卡一律保持中性灰。
- ⚠️ **「贵金属」配方只在金色系生效，别动冷色按钮（v0.13.53）**：`Surface.Button` 里用 `warm = color[1] > 200 and color[2] > 140 and color[3] < 130` 判定，命中才走高光 `(255,232,168)` + 暗端保留金色 + 常驻辉光（alpha 130/半径 12）。**常驻辉光**是关键——付费入口不该「只有悬停才亮」，那是「冷」的来源之一。⚠️ 判定阈值别写成「非青即暖」，会把绿色广告按钮一起染暖（绿色是「看广告」语义，必须保持冷绿）。
- ⚠️ **改共享 Button 的色面配方要同时核对 `C.ink` 文字对比度（v0.13.53）**：暖金面比青面更亮，`C.ink`(4,8,16) 深字在暖白高光端对比度下降——本批实测仍可读（按钮文字在偏暗的右下段）。凡是调亮按钮色面的批次，都要目视一次按钮文字，别只看按钮本身好看。

## 本批次新增避雷（v0.13.51 游戏更名 + 字标重出）
- 🔴 **AB-205：「游戏更名」= 对外名 + 游戏内字标图两件事（v0.13.51 用户点名）**：用户说「更新游戏名称：货车大战飞机，**包括有星系内标图片需要重新生成**」——只改字符串会留下**旧名 logo 图**（首页大标题是 AI 生成的位图，不是文字渲染）。改名清单：`GAME_TITLE`/`GAME_SHORT_TITLE`、`graphics.windowTitle`、`lobby_runtime` 加载页标题栏、`lobby_ui` 的 `title_` 默认值 + 全部 `title=`、`.project/project.json` 的 `taptap_publish.title`（**发布名契约**）。交付前 `grep -rn "<旧名>" scripts/ .project/` 确认零残留，再 grep 新名确认已落到窗口/大厅/字标三处。
- 🔴 **AB-206：给游戏出字标草案必须开 `transparent:true`（v0.13.51 实测）**：本批第一轮 4 张全部生成成**白底不透明**（`alpha0ratio=0.00`）——白底图经管线量化后，文字外围的「近白」会映射成高光白，在深色游戏背景上变成一道**白框**（等于把透明底丢掉）。正确做法：`batch_generate_images` 传 `transparent:true`，**生成后先量 `alpha==0` 的像素占比**（本项目正确草案约 0.40–0.64），为 0 立即重生成，别硬跑后处理。历史正确的 logo 都是透明底。
- ⚠️ **AB-207：字标是「完整成品」不是 9-slice，宽度必须逐图记（v0.13.51）**：4 张新字标宽 **294/268/201/232**（差 1.46 倍）——`LOGO_PATHS` 每项自带 `w`，绘制 `lx=(width-w)*0.5` 逐图居中。**统一用一个宽度会让宽图压扁、窄图拉伸**（完整成品禁止非等比缩放，见 `0718-pixelimage-aigc` §2）。同理**回退用的 zpix 大 logo 字号要按字数反推**：本项目原写死 `size=104` 只对 4 字成立，**6 字会溢出画布**（6×104=624 > 540）→ 改 `min(104, (width-56)/n)`。**改标题字数时，回退路径与位图路径都要过一遍**。
- ⚠️ **字标重出的目录纪律（v0.13.51）**：草案生成直接落 `assets/image/`，必须**生成后立刻把草案与 `.meta` 一起移出**（连 `.png.meta` 残片也要清），只留按目标名命名的成品 + 新 `.meta`；旧 logo 的 PNG 与 `.meta` 一并删除。交付前 `ls assets/image/ | grep -i logo` 应只剩 4 组成品。

## 本批次新增避雷（stagemap-star 选关风格重做）
- 🔴 **AB-239：用户说「重做风格」时，换的是**视觉隐喻**，不是调参数（stagemap-star）**：用户一句「选关界面太难看了，重做风格」——上一版是「蜿蜒光带 + 圆钮」，我在上面加纹路/流光/幽灵节点都算「调参」，用户仍判难看。**做法**：换掉**整个隐喻**（本项目：从「爬塔路」→**太空星图**，与深空主题一致），节点形状（圆钮→六边形芯片）、连接（贝塞尔光带→直线星座连线）、底图（纯底→视差星空）**三件一起换**。**判据**：「重做风格」= 玩家一眼看出「这是另一个东西」，不是「同一个东西多了几道纹」。
- ⚠️ **节点形状从圆改成多边形时，命中判定必须一起改（stagemap-star）**：六边形（尖角朝上下）命中不能用 `dx²+dy² ≤ r²`，否则**角上看得见点不到、圆角外能点到**。正六边形判定：`|dy| ≤ r` 且 `(dy·0.5 + |dx|·0.866) ≤ r`（`0.5=sin30°`、`0.866=cos30°`）。**通用规则**：绘制形状与命中形状必须是同一个——改了绘制就同步改 `HitTest`，并实图/探针验证边缘。
- ⚠️ **重做风格后要删死代码（stagemap-star）**：换隐喻会留下整段无调用点的旧绘制（本项目 `PathPoints`/`StrokePath` 的 Catmull-Rom 蜿蜒路径）。**交付前 grep 每个旧 helper 的调用点**，为 0 就整段删；但**别删仍被复用的**（本项目 `NodeYAt` 是未来关幽灵节点要的，保留）。
- ⚠️ **星空/星点这类散布装饰要「确定性 + 视差 + 合并路径」三件套（stagemap-star）**：①位置用 `(i·素数 + 偏移) % 尺寸` 算（**非随机**，重开一致，同 v0.13.13）；②y 加 `scrollY_ * 系数` 做**视差**（滚动时星空比节点动得慢，出「航行」感）；③所有星点**合并成一条路径**再 fill（逐点各起路径会撑爆单帧命令缓冲，AB-216）。

## 本批次新增避雷（arttext-buttons 艺术字 + 选关统一化）
- 🔴 **AB-238：两色像素艺术字用 `nvgImagePatternTinted` 乘法染色时，tint 越接近黑越会「塌成黑疙瘩」（arttext-buttons 实测，用户点名「异常变色」）**：母版是「白芯 + 近黑轮廓」两色；乘法染色下，tint 若接近黑（如 `C.ink` 4,8,16），**白芯×深色 ≈ 深色、近黑轮廓×深色 ≈ 更黑**——两级明暗差被压没，整块读成一块黑。**判据**：tint 的亮度要足够高（青/白/金都安全），**别把深色当 tint 用在亮底按钮上**。**亮底按钮要「深色字」时，不要深 tint 艺术字**，改为**垫一块暗色铭牌**（`{C.ink,140}` 圆角 + 语义色描边）+ 艺术字用**亮 tint**——既保留按钮色语义、又让两级明暗完整显出来（本项目 CTA「开始战斗」、暂停「继续战斗」都这么做）。**通用规则**：任何「乘法染色」的素材，只有「乘完仍保留内部明暗差」的 tint 才有效。
- ⚠️ **AB-237：画「未来项 / 延长线 / 占位」时不要复用只覆盖已生成范围的查表函数（arttext-buttons 实测，peer 也复现）**：`ui/StageSelect` 的 `nodeY` 表只填了 `1..maxStage`，幽灵节点循环调 `NodeCenter(L, maxStage+k)` 得到 `nil` → `attempt to compare number with nil`，整段 stage 被 pcall 吞掉（**选关白屏**，且 LSP/build 都发现不了）。修法：新增 `NodeYAt(L, stage)` 用**同一公式**直接算任意关号圆心 y（含滚动与居中偏移），幽灵节点/延长线走它，**真实节点布局不动**。**通用规则**：凡「超出已生成数据范围」的循环，都要有一个「按公式直接算任意索引」的取坐标函数，别复用按范围预生成表的函数。
- ⚠️ **「艺术字标题」的落地三件套（arttext-buttons）**：①素材母版**高度 = 运行时显示高度**（1× 最近邻，禁止非整数缩放），宽度随字数浮动**逐图记宽**；②做成**两色可染色**（白芯 + 近黑轮廓）→ 一份素材适配深底/亮底两种语义（见 AB-238 的 tint 约束）；③**全部可选资源 + zpix 回退**——`ArtText.Draw` 返回 false 时调用方画原 zpix 文本，缺图绝不影响布局/启动（同 v0.11.4 手势图 / v0.12.8 字标契约）。
- ⚠️ **模块懒加载用「Draw 传入的 ctx」而不是「后端暴露 vg」（arttext-buttons，承接 v0.13.24）**：`ui/ArtText.lua` 首次 `Draw(ctx,…)` 时才 `nvgCreateImage(ctx,…)`——NanoVG 上下文是进程级单例、ctx 即 vg，既免去给 `Scene3DBackend` 加访问器（也省顶层 local 槽位），也避免注入顺序问题。与 `ui/DigitFont.lua` 同契约。
- ⚠️ **选关「补满内容区」用幽灵节点 + 延长路径，不是把真实节点缩小（arttext-buttons）**：关卡少时内容矮于可视区 → 除垂直居中（AB-231）外，再在**路径延长线**上画未解锁占位节点（极低 alpha、**不参与命中**）并延伸路径段，把内容区填满、让「爬塔还很长」可见。⚠️ 幽灵节点 alpha 要**明显低于**真实节点（本项目描边 42 vs 真实 200+），否则会被读成「可点的关」。

## 本批次新增避雷（ui-adaptability-fix 布局错位 / UI 适应性）
- 🔴 **AB-230：用户说「UI 适应性不满意」时，先把截图**逐屏量出具体错位**，不要当审美分歧去重做视觉（ui-adaptability-fix）**：本批五张截图里「不满意」的真实成分是**四处硬布局 bug**——①天赋树两行文字只差 18px 糊在一起；②选关内容矮于可视区却贴底、上方留白；③战斗新手文案压住手势图与红线；④暂停按钮三角与文字重叠。**做法**：把每张截图按设计画布裁剪 → 量出「哪两个元素重叠 / 哪块该有内容却是空白」，逐个对应到源码里的硬编码 y/x。**先修错位，再谈美化**——重做视觉不会修掉「两行字贴在一起」。
- ⚠️ **「内容矮于可视区」必须显式居中，不能沿用「贴底/贴顶」的默认（ui-adaptability-fix）**：选关塔按「第 1 关在最下方」写死贴底，关卡少时内容高度 < 可视区高度 → 上方空一大片，读起来像「没适配」。修法：算 `freeSpace = viewH - contentH`，`>0` 时把整组内容**居中**（`offset = freeSpace*0.5`）。⚠️ 居中偏移要**加进布局函数本身**（`nodeY[stage]` 里减 `centerOffset`），这样绘制与命中天然同步；`FocusLatest` 这类「反算滚动量」的函数要改成**读布局里的最终位置**（`target - L.nodeY[n]`），否则会漏掉居中偏移。
- ⚠️ **多段文本头部要按「行高」而不是「大概看着够」留间距（ui-adaptability-fix）**：标题栏下沿 + 规则行 + 表头三行，行高 13 的字实际占 ~17px；把规则行放在「标题栏底 + 52」、表头放在「+66」时两行只差 14px → 必然视觉粘连。**规则：相邻两行文本的 y 差 ≥ 字号 × 1.35**（13 字 → ≥18），并给中间那条表头一个**可见的栏头底/分隔线**把语义分开。
- ⚠️ **「图标 + 文字」按钮里，文字别用「整宽居中 + 偏移」（ui-adaptability-fix）**：暂停「继续战斗」是 `x + w*0.5 + 14` 居中 + 三角固定在 `x+58`，宽按钮下两者必然重叠。**做法**：把图标锚在**左半区中心**（`x + w*0.30`）、文字锚在**右半区中心**（`x + w*0.60`），两者各占一半、永不相交。凡「图标 + 文字」横排按钮都按这个分区法，别用固定像素偏移。
- ⚠️ **「已解锁」态不要丢掉语义色（ui-adaptability-fix）**：天赋树节点原按 `owned` 分支把环色覆盖成统一青 → 六条线路（通用青/分裂青/冰冻浅蓝/加速蓝/巨型金）读起来全一样，**解锁越多越看不出自己在哪条线**。**规则**：状态色（已解锁/可买/未开放）与**身份色（线路/弹种/稀有度）是两条正交的轴**——已解锁改的是**明度/内亮环**，不该覆盖身份色。

## 本批次新增避雷（brick-hit-flash 受伤闪烁）
- 🔴 **AB-226：「加一个反馈」之前先查「这个信号是不是已经存在、只是形状不对」（brick-hit-flash，本轮最省事的一刀）**：用户说「受伤但没碎裂的要有极短闪烁」，直觉是「规则层发事件 → 表现层存状态 → 渲染层画」三处新建。实际**整条链路早就通了**——`DamageBrick` 未击碎分支**本就** `Emit("brick_hit",{destroyed=false})`，`Presentation.brickSpark` **本就**写 `hitFlashes[key]`，`CombatImpact.DrawHits` **本就**消费它。真正的问题只是**画出来的形状是「白色十字标记」而不是「方块闪一下」**。**做法**：接反馈类需求先 `grep` 事件名与消费点，确认「有没有 / 存没存 / 画没画」，多数情况只需改**最末端的绘制形状**，不必动规则层与表现层（本项目这次只改了 `DrawHits` 一个函数）。⚠️ 反向也成立：**「有没有反馈」要看的是「画出来像不像那回事」，不是「代码里有没有这个函数」**——一个十字标记在代码上算「有反馈」，在玩家眼里等于没有。
- ⚠️ **AB-227：按「世界矩形 → 屏幕矩形」画覆盖物，前提是投影为逐轴仿射（brick-hit-flash）**：本项目 `ProjectGamePoint(x,y)` 是 `offset + x*scaleX, offset + y*scaleY`（**无交叉项**），所以砖块屏幕矩形只要投影**两个角点**即可（`rw=|bx1-bx0|, rh=|by1-by0|`），不必投影四点或算矩阵。**前提要先读一眼投影函数**——若哪天换成带旋转/透视的投影，两角点法就失效（矩形会斜/梯形），要改回四点。这是「斜俯视正交 + 逐轴缩放」场景的通用简化。
- ⚠️ **AB-228：给「未击碎」加闪，必须与「击碎」特效互斥（brick-hit-flash）**：`hitFlashes` 对**击碎与未碎都写**，所以绘制端必须用 `brick.alive` 过滤——**只在存活格闪**，否则击碎那一格会「碎裂特效 + 闪白」叠一起（闪白还会盖住刚出现的缺口）。规则：同一个状态容器被两种语义共用时，绘制端要按语义分流（本项目：`alive` → 闪白；`not alive` → 碎裂粒子/环）。
- ⚠️ **AB-229：本环境离屏截图不可靠，纯绘制改动用「记录式 mock NVG」单测（brick-hit-flash）**：`-screenshot-frame` 在本环境截不到深层帧（AB-220）。**替代方案**：写一个 mock NVG 上下文（覆盖 `nvgRoundedRect/nvgFillColor/...` 全局为记录闭包），直接调绘制函数并**断言调用序列与几何数值**——本项目实测能精确验出「画了 2 次 roundedRect、宽高 14.784×13.552、满亮 alpha=180、亮边宽 2.4、击碎格不画」。⚠️ 两个**探针自身**的坑（都不是被测代码的问题）：①mock 表必须是**同一个表**（方法宿主 == 调用日志），`mkctx()` 返回新表会让 `#calls==0` 假失败；②`nvgRGBA` 打包是 `((a*256+r)*256+g)*256+b`，**alpha 在高字节**，解包要 `floor(v/16777216)%256`，取 `%256` 拿到的是**蓝通道**。⚠️ 该运行时**允许**覆盖 `nvg*` 全局（`_G` 有 `__newindex` 但仍生效），可放心用此法。

## 本批次新增避雷（hp-cap-curve 曲线换公式）
- ⚠️ **AB-235：改「曲线」类需求时，先只改**一个纯函数**、把调用点/语义全留着（hp-cap-curve）**：用户「第 n 架血量上限改为 `floor(0.5*(1.25^n+1))`」——只需把 `StageCatalog.GetFirstShipHpCap` 的函数体从 `2n−1` 换掉。**调用点（`Game.SpawnNextNormalEnemy` 的 `min(curve, cap)`）、「只封顶不抬升」语义、`pendingSpawn.spawned` 计数、精英/Boss 不参与——一处都不动**。这类「换个公式」的需求，改动面越小越好：任何顺手重构都可能碰到 v0.13.51 已调好的门控/复位（AB-224 计数复位、AB-204 首机标记）。
- ⚠️ **AB-236：换曲线后要**逐值打印新旧对比**，别只报「改成了新公式」（hp-cap-curve）**：本项目旧 `2n−1` = 1/3/5/7/9…，新 `floor(0.5*(1.25^n+1))` = 1/1/1/1/2/2/2/3/4/5…——**前期差异巨大**（前 4 架从「1/3/5/7」变成「全 1」）。探针要**逐序号断言到 20+ 并附上新旧对照**（本项目 `probe_hpcap` 26 断言），否则「换了公式」这句话掩盖了「前几架变软很多」这个真正的手感变化。指数曲线在**低 n 段几乎不动、高 n 段暴涨**（n=20 已 43 血）——这类曲线的**两端手感**都要在交付说明里点出。

## 本批次新增避雷（spawn-ramp-hp-cap 前期放慢出怪 + 按序号封顶血量）
- ⚠️ **AB-222：调「节奏曲线」时把「用户给的目标值」当作曲线的一个端点，而不是改整条公式（spawn-ramp-hp-cap）**：用户要求「前期间隔放三倍，**到最后三波是现在的情况**，中间平滑过渡」——关键约束是**最后三波必须等于改动前的现状**。做法：**保留原公式不动**，只在其上乘一个 `ramp` 倍率（前段 ×3 → 线性 → 末段 ×1.0），末段 `ramp=1.0` 天然等于原值，不需要第二套公式也不需要碰「最后三关」的常量。**别把原曲线整体乘 3 再在末段硬改回来**——那样会引入两处需要同步的魔数。验证探针要同时断言「前段变了」和「末段没变」（本项目实测关1 2.80→8.40、关9/13/15 与改动前逐一相等）。
- ⚠️ **AB-223：「只封顶不抬升」要用 `min(curve, cap)`，别用 `= cap`（spawn-ramp-hp-cap）**：用户「第一个最多 1 血、第二个最多 3 血」的「最多」是**上限语义**。写法必须是 `if hp > cap then hp = cap end`——后期关卡曲线本就高于上限时才压、曲线更低时保持曲线值（否则后期会把血**抬高**成 2n−1，越往后反而越软）。探针要挑「曲线高于上限」和「曲线低于上限」两种关卡各验一次（本项目关1 曲线=2 被压到 1、关15 曲线 9 处第 4 架被压到 7）。
- ⚠️ **AB-224：「按出场序号」的计数是**跨波持续**的，但判定要限定在目标波（spawn-ramp-hp-cap）**：序号计数 `pendingSpawn.spawned` 在 `ResetGame` 与**每波开波**都复位（因为判定带 `wave == 本关第一波` 约束，复位保证第一波从 1 重新数）。⚠️ 别把复位只放在 `ResetGame`——那样第二波及以后 `spawned` 会持续累加，虽然当前有 wave 约束兜住，但一旦哪天放开到「每波都封顶」就会立刻出错。**计数复位点要与判定的作用域一致**。
- ⚠️ **AB-225：改节奏/数值类改动，LSP 与 build 只证明「不崩」，不证明「手感对」（spawn-ramp-hp-cap）**：本批 LSP 0 Error、build 成功，但「前期 8.4 秒一架是否偏慢」「封顶曲线是否顺滑」只能靠 Preview 实机。交付时如实标注「平衡手感待实机」，不要把「构建通过」写成「平衡已验收」（同 AB-216/220 的「技术通过 ≠ 观感/手感通过」纪律）。

## 本批次新增避雷（v0.13.50 每关首机 1 血）
- 🔴 **AB-204：「首个单位特殊化」要用显式「已放过」标记，不能用「场上有没有单位」推断（v0.13.50）**：给「每关第一个飞船固定 1 血」写判定时，最直觉的写法是 `wave == 本关第一波 and #veggies == 0`——**错**：同波是逐架飞出的（v0.13.26），首机若在第二架出场前就被清掉，`#veggies` 回到 0，**第二架会被误判成「第一个」也拿 1 血**。正确做法：`pendingSpawn` 表加 **`firstDone`** 布尔，放过一次就置位；判定带 `wave == (stage-1)*WAVES_PER_STAGE+1` 双保险；**在关卡开局与每次开波都复位**（否则跨波残留）。⚠️ 通用规则：任何「本关/本波只生效一次」的规则，都用**状态标记**而不是**从场景推断**（场景是间歇的、会被清空）。
- ⚠️ **加「每关首机 1 血」这类规则时，要检查同关其他机制是否会被它破坏（v0.13.50）**：精英波位原本从 **1–9** 随机抽——若精英落在第 1 波，「每关第一个飞船 1 血」就变成「第一个是 1 血精英」（自相矛盾且反直觉）。修法：精英池**收窄为 2–9**，保证首波恒为普通机。**新增/调整「首波」相关规则时，先确认首波的内容是可控的**（本项目靠「精英池不含第 1 波」保证）。
- ⚠️ **探针读敌机血量要读 `enemy.bricks[i].hp`（v0.13.50 踩到）**：敌机没有顶层 `brickHp` 字段——HP 存在每块砖上（`CreateEnemy` 里 `bricks[i].hp = brickHp`）。探针直接取 `enemy.brickHp` 会拿到 `nil` 并让 `string.format("%d", nil)` 报 `bad argument #6`。**读敌机状态前先看一眼 `CreateEnemy` 的字段表**，别按直觉猜字段名。
- 🔴 **AB-203：「数值不平衡」时先问该调哪一侧——本项目用户偏好「加强敌人」而非「削弱玩家」（v0.13.48→v0.13.49 订正）**：用户先报「前期我方数值过高」，我按「削玩家」做了 v0.13.48（基地 100→80、加速车 damageStep 320→480）；用户随即订正「**不对你应该整体提高地怪难度曲线来实现平衡**」→ 撤销玩家侧、改抬敌方。**规则**：在「玩家强 / 敌人弱」的不平衡里，**默认改敌方**——尤其当玩家侧存在**用户明确指定过的设定**（本项目「基础的车改为加速车」开局）或**明确要求过的契约**（去速度/伤害上限、改软性递减）时，动玩家侧等于推翻用户决定。削玩家更「保守」但方向可能是错的。
- ⚠️ **抬难度前先排除「用户点名限制过的轴」（v0.13.49）**：本项目**普通波数量**被用户 v0.13.26 明确要求「起点要低、不要满 12」——所以抬难度**不能动数量**，改走其余四条轴（砖块 HP / 基准速度 / 精英护航 / Boss 召唤）。做法：抬难度前先列出所有可调轴，划掉用户明确表态过的，只动剩下的。
- ⚠️ **改完数值要同时核对「玩家侧没被顺手改动」（v0.13.49）**：本批先撤销 v0.13.48 的两处玩家改动再抬敌，探针 `probe_curve` 专门断言「基地血量=100 上限=100」确认还原干净。**改一个方向时，用探针把反方向的值也断一遍**，避免半改状态（如「敌人抬了但玩家还留在被削的值」）。
- ⚠️ **「订正上一批方向」要在记忆里显式标注撤销（v0.13.49）**：v0.13.48 的条目已加「⚠️ 本批方向已被 v0.13.49 订正并撤销」，避免后续会话读到 0.13.48 又按削玩家的方向改回去（同 v0.13.3 的「历史契约被推翻要同步改写」教训）。

## 本批次新增避雷（v0.13.48 前期我方数值收敛）
- 🔴 **AB-202：「我方数值过高」先分清是哪一侧，再调「基数 + 斜率」而不是加回上限（v0.13.48 用户点名）**：用户一句「前期我方数值过高啊」——**「我方」= 玩家侧**（基地生命 / 弹珠伤害 / 弹药 / 初速），不要误改成敌方。本项目根因是**双方比例**：关1 敌机 HP=1，而玩家 ①基地 100 血、越线每行仅 1 伤（几乎不可败）②开局加速车 `damageStep=320` **无上限**分档增伤（初速 660 已 1 伤秒杀、反弹 8 次到 2 伤）。**调法**：动**基数**（`BASE_HP` 100→80）与**成长斜率**（`damageStep` 320→480），⚠️ **不要动用户明确指定的设定**（v0.13.19「基础的车改为加速车」开局），⚠️ **也不要为压前期而加回被用户明确要求去掉的上限**（v0.13.22 去 maxSpeed/maxDamage、v0.13.23 改软性递减）——放缓斜率即可，契约保留。
- ⚠️ **基地生命是单一来源，改一处即可（v0.13.48）**：`BASE_HP` 被 `BALANCE.baseHp`（只读快照）、`local baseHp = BASE_HP`（开局值）、`GetMaxBaseHp()`（上限/评级基准）三处引用——**改 `local BASE_HP` 一处全同步**。交付前 `grep -n "BASE_HP"` + 查有没有别处硬编码 100，别只改一半导致「上限 80 但评级按 100 算」。
- ⚠️ **数值类改动用「次数→伤害」曲线自证，而不是只报新旧常量（v0.13.48）**：本批探针打印「反弹 N 次后的速度与伤害」，一眼看出前期被压住（旧 320：8 次到 2 伤 → 新 480：16 次到 2 伤）。**玩家感知的是「打几下变强」，不是「常量从多少改成多少」**——调成长类数值时把曲线跑出来。
- 🔴 **AB-201：消除「关卡同质化」要先量化「哪一维每关都一样」，且只随机那一维、保留骨架（v0.13.47 用户点名）**：用户要求「减少各关卡之间的同质化，一部分东西我希望局内随机」。做法**不是**乱加随机，而是先找出「每次都一样」的维度——本项目是 ①`ELITE_SLOTS={[3],[6],[8]}` **写死的精英波位**、②`GetSpecialKey` 按 `(stage-1)*3+slot` 的**确定性取模循环**、③`PickFormation` 按 `(wave-1)%6` 的**确定性循环**；把这三处改成「每关进入时随机生成一次」即可，玩家不再能背板。⚠️ **必须保留骨架**：波数（十波）、精英数量（3）、**Boss 波位（第 10 波）**都不许随机——`UpdateWaveLogic` 的胜负判定绑定 `stageWave == WAVES_PER_STAGE`，把 Boss 随机到别处会**直接破坏结算**。可随机的只是「机型、精英落点、关卡特性」这类**表现/压力**维度。
- ⚠️ **随机层要放「独立模块」，别塞进已逼近上限的大文件（v0.13.47）**：`Game.lua` 顶层 local 已 197/200（AB-166），随机布局逻辑（LCG + 布局缓存 + 特性表）全部放进 `StageCatalog.lua`（Game 已 require 它），Game 侧只加**一次 `BeginStage` 调用 + 一个快照字段**，零新增顶层 local。
- ⚠️ **「局内随机」要在「进关」这个入口生成，且必须覆盖所有开局路径（v0.13.47）**：布局在 `ResetGame` 里 `BeginStage(startStage, os.time())` 生成——选关/下一关/再战/重开**四条入口都经过 `ResetGame`**，所以天然全覆盖；若放在 `StartStageAt` 之类只覆盖部分入口的地方，会出现「某些入口进去还是上一关的布局」。种子用 `os.time()`（生产每次不同）→ 每次游玩同一关都不同；探针给固定 seed → 可复现。
- ⚠️ **自持 LCG 而不是引擎 `math.random`（v0.13.47）**：随机层用模块内 7 行 LCG（`MakeRng`），好处是**不污染 Game 的确定性随机流**（`Game.lua` 有自己的 `randomState` 用于弹种/分裂等玩法随机，混用会让玩法随机序列随关卡布局变化而漂移），且**同 seed 可复现**便于探针断言。
- ⚠️ **玩家可见的「每关不同」要有 UI 出口（v0.13.47）**：随机了精英落点/特性却不显示，玩家感知不到——快照加 `s.stageSubtitle`（如「十波防线 · 3 精英 · 1 首领 · 急行推进」），把 `DrawWaveBanner` 里**硬编码**的「十波防线 · 三精英一首领」改为读它。⚠️ 硬编码文案散布在绘制层时，改数据要 grep 一遍确认没有第二处。
- 🔴 **AB-200：用户说「已有的贵的部分要保留，别给我删了」时，本轮只能做加法（v0.13.45 用户点名）**：用户在要求继续调配 UI 的同时追加这条——意味着**任何重构都不能顺手削掉既有效果**。做法：新功能只**新增**（补一个分区标题、改几个字符串），不重写既有绘制函数体、不调低既有 alpha/层数/渐变跨度。**交付前对照上一批的 CLAUDE.md 描述逐条核对「这些效果还在吗」**（多层受光、漆面、描边、背景扫光、展台光场、文字描边）。
- ⚠️ **给已有列表补分区标题要连带下移列表锚点，且改「几何共同来源」（v0.13.45）**：战斗档案的里程碑列表原从 `content.y+174` 起，加标题会重叠 → 必须把 `GetPassRewardRect` 的 y 下移到 `+196`。⚠️ 该函数同时被绘制与 `HitTestPass` 调用，**改这一处即两处同步**；若当初有人在 HitTest 里另算 y，就会「看得见点不到」。
- ⚠️ **措辞去直白化要全库统一（v0.13.45 承接 AB-198）**：`充值` 改完后仍残留 `购买样式`/`购买车型` 两处玩家可见文案 → 一并改 `解锁样式`/`解锁车型`。做法：改完一轮后 `grep -rn "购买\|充值" scripts/ --include=*.lua`，逐个判断是**玩家可见文案**（要改）还是**内部注释/action 串**（不改）。

## 本批次新增避雷（v0.13.44 变现措辞去直白化）
- 🔴 **AB-198：变现入口的玩家侧措辞要「游戏内表述」，不是「充值/购买」（v0.13.44 用户点名）**：用户明确「别把充值写的那么明面，而是钻石商店等」。做法：钱包金按钮 `充值` → `钻石商店`；IAP 按钮 `¥N 立即购买` → `¥N 立即获取`；礼包按钮 `购买` → `获取`。**保留价格（`¥N`）与商品名**——用户要改的是「动作措辞」不是「隐藏付费」。⚠️ 措辞改动**只动 `D.text` 的字符串**：`HitTest` 的 action 串（`buy`/`spend`/`buy_first_gift`）与 `Shared` 的 sku/价格/发货**一律不动**，否则会连带打断编排层的分发。
- ⚠️ **换文案要连带核算按钮宽度与字号（v0.13.44）**：`充值`(2 字) → `钻石商店`(4 字) 时，原 96 宽 + 16px 会挤出按钮；必须同时放宽矩形（96→104）并降一档字号（16→15）。**改标题字符串前先按 `D.measure` 估宽**，别只看字面长度。
- ⚠️ **分区标题按语义换色，不照搬主菜单的青色（v0.13.44）**：`RechargeShop` 的 `SectionHeader` 用**金色系**（`C.warn` 竖条 + `warnDim` 断线）而非主菜单的青色——因为商店分区是付费/稀有语义。同一套「竖条 + 淡出断线」几何、按语义换色，是规范允许且推荐的复用方式。

## 本批次新增避雷（v0.13.43 第四轮加贵 + 清晰度）
- 🔴 **AB-196：「更清晰」的第一手段是给文字描边，不是加对比度或换字号（v0.13.43 用户点名）**：本项目全项目文字此前**零描边**，亮字压在浅底/亮色按钮/亮色敌机上边界发糊。规范 §8 的做法是**四方向偏移同字绘制**（`x±1`/`y±1` 各画一遍深色，再画本字），**不是** `nvgStrokeText`（后者在小字上糊成一团）。门槛：`size >= 17` 才默认描边、`size < 12` 永不描边；描边 alpha 跟随字色（淡字别被深描边反客为主）。**加描边是「清晰」；加对比度/加大字号是「更贵」——两者别混。**
- ⚠️ **给高频绘制函数加可选尾参是安全的扩展方式（v0.13.43）**：`DrawPixelText` 加第 7 参 `outlined` 且缺省自动判定，**全部既有调用点零改动**（不像必填参要 grep 所有调用点改）。给全屏复用的绘制函数加能力时，优先「可选尾参 + 缺省合理行为」。
- ⚠️ **「漆面」= 一道斜向高光裁剪在圆角内（v0.13.43）**：面板/按钮的「贵」再上一层是**玻璃漆面**——上半区一道极淡斜向白高光（面板 alpha 12–20、按钮 26+glow×26），必须 `nvgIntersectScissor` 裁在圆角内，否则斜光会越出圆角。它和内顶受光/内底沉影是**三个不同的层**：受光是竖直的、漆面是斜向的、沉影在底部。
- ⚠️ **侧栏「胶囊标记」要与刻度错开间距（v0.13.43）**：规范 §4 侧栏是「刻度 + 胶囊标记」双结构；本项目刻度 46px 一档，胶囊用 92px（倍数错开）才不会挤在一起。胶囊用 `cyanDim` alpha ~130，比刻度（~110）略亮但不抢焦点。

## 本批次新增避雷（vehicle-outline 白色轮廓）
- 🔴 **AB-195：做「白色轮廓」用「翻面外壳」而不是描边 shader（vehicle-outline）**：把车体三角面**等比放大后翻转绕序**做成第 7 段（法线随绕序取反），绑不透明白色材质；默认背面剔除下只剩远侧壳，自然在车体外缘露出白边。**不要**去写描边 Technique/改 glsl，也不要用 `SetCullMode(CULL_FRONT)` 单独翻转剔除——前者超出「改几何」的范围，后者会把所有车体材质一起翻掉。放大倍率折进 `fit`，轮廓与车体**取较大半径**共同约束 `PLANAR_RADIUS`。
- ⚠️ **轮廓必须覆盖车体「全部 section」，不能只取主漆段（vehicle-outline 实测）**：只放大车身会让轮胎、轮眉、后视镜、防滚架穿出白边，轮廓断成一截一截。做法：拼接 section 1..6 一起派生轮廓。
- ⚠️ **绕包围盒中心放大时，半径不是单调的（vehicle-outline 实测）**：`outlineR ≠ bodyR × scale`（缩放把点拉离/拉近原点取决于它相对中心的位置）。必须**分别量** `bodyRadius` 与 `outlineRadius`，`fit = min(1, PLANAR_RADIUS / max(bodyRadius, outlineRadius))`；只按轮廓算会挤掉车体原本的 2% 碰撞余量（实测 obsidian 车体冲到 1.6736 > 1.6429 上限）。
- ⚠️ **几何探针要比对「绕序翻转后的顶点顺序」（vehicle-outline 踩到）**：轮廓按 (a,c,b) 输出以翻转绕序，逐索引 `outline[i] == expand(body[i])` 必然失败（首版报 err=1.49）。正确比对：按三角形取 `order = {base+1, base+3, base+2}`。
- ⚠️ **新增几何 section 后要同步探针的 section 上限（vehicle-outline）**：`probe_vehicle_five`/`refine_*.lua` 里的 `for section=0,5` 是硬编码 6 段，不改会漏检第 7 段材质；改成 `0,6`。

## 本批次新增避雷（v0.13.41 拖尾样式商店）
- ⚠️ **AB-191：跨模块复用「渲染用 0..1 颜色」到 NanoVG `D.rect` 时必须 ×255（v0.13.41 实测）**：拖尾样式参数（`TRAIL_STYLE_PARAMS`）里的 base 色是 0..1（供 3D 顶点色/`Color()` 用），MetaUI 的 2D 预览直接把它塞进 `D.rect` 的颜色表 → 期望 0..255，结果画成近黑（截图实测预览条几乎不可见，只采样到背景色）。修法：`rgba(f,alpha)` 把 `base[i]*f*255` 取整。**规则**：任何跨「3D 渲染色（0..1）」与「NanoVG 色（0..255）」边界复用的数值都要显式换算，别指望两边同一量纲。
- ⚠️ **AB-192：NanoVG 画矩形，`w`/`h` 为负 = 不绘制（v0.13.41 实测）**：2D 预览从右（车尾 x0）往左（尾端 x1）迭代，`xb - xa` 为负 → `D.rect` 什么都不画（不是反向填充）。修法：`rx = math.min(xa,xb); rw = math.abs(xb-xa)`。同时**方向参数要对**——渐细/渐亮的 `t` 必须在车尾取最大值（与 3D「头亮尾暗」同向），否则预览的渐细方向与实机相反。**教训**：任何「反向遍历画渐变条」的 2D 代码，先确认宽度取正 + 明暗端与 3D 一致，再看截图。

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
