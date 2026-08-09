# 燃烧的蔬菜 — 项目核心记忆

> AI 自维护，每次 POST 自动更新。详细规则见 memory-system skill。

## 当前状态
- 版本: 0.6.0
- 进度: 3D 表现第二轮强化完成；相机保持正交投影并提升为 30° 斜俯视；敌方体素厚度增至 1.18 且每敌人单网格内加入立体飞船船体/推进器；每个弹珠由一个 6 PBR section 的大运式平头重卡表现；底部已实现四个独立弹药槽；敌船撞线触发 3D 相机震动、防线材质脉冲、冲击波和警示文字
- 上次交付: `Renderer3D.lua` 重塑平头高顶、长货厢、三轴六轮的大运式重卡，并增加浅色独立侧围；待发射车辆按规则层发射向量实时转向；`Scene3DBackend.lua` 完成 30° 正交斜俯视、瞄准轨迹、四槽 HUD 与防线撞击反馈；LSP 0 Error、官方构建成功，菜单态及斜向瞄准游戏态 GLES 截图验证通过

## 用户画像摘要
- 使用简体中文沟通
- 重视先做架构解耦，为后续 3D 开发降低迁移成本 [observed]

## 预测下一步
- likely_next_task: 真实交互复测四类重卡的拖拽角度、连续反弹、分裂和巨型圆域，并按实机反馈微调重卡车身比例、侧围明暗、30° 倾角与防线撞击强度
- 相关文件: `scripts/Game.lua`, `scripts/Presentation.lua`, `scripts/Renderer3D.lua`, `scripts/Scene3DBackend.lua`

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
- 弹珠技能契约：基础弹每次直接命中独立 5% 概率生成两颗完整功能分裂弹，分裂弹可继续分裂；加速弹每次反弹/命中加速 15%，按速度最高增至 3 伤并自动追击最近砖块；巨型弹任意有效反弹只武装一次贯穿，贯穿命中造成直径 7 格圆形范围伤害
- 敌方基础下落速度固定乘以 0.25（降低 75%）；冰冻倍率继续叠加在此速度之上
- 视觉瞬时状态必须由 `Presentation.lua` 消费领域事件维护；2D 视觉参数放在 `VisualCatalog.lua`
- 渲染后端只能消费 `Game.GetSnapshot()` 与 `Presentation.GetSnapshot()`，不得反向修改权威状态
- 发现会话外并发修改时必须保留并合并，禁止直接覆盖
- headless 验证器当前会因自带 shader cache 字节码报 engine error；判断脚本时需关注 `lua_errors=0`、`resource_errors=0` 并结合 GLES 截图
- 3D 后端的体素尺寸必须统一经过 `WORLD_SCALE` 映射；Renderer3D 只消费快照，碎片生命周期由 Presentation 维护
- 3D 体素性能契约：每个敌人只允许一个 `CustomGeometry`，只在砖块存活拓扑或冻结状态改变时重建，禁止每体素创建 `Node + StaticModel`
- 相机契约：必须使用正交投影，禁止透视近大远小；当前相机从 XY 玩法平面法线向正视方向倾斜 30°，位置按 `(0, 25*sin(30°), -25*cos(30°))` 计算，车辆仍在 XY 平面绕 Z 轴朝向速度或瞄准发射向量
- 载具表现契约：每个 `marble.id` 对应一个大运式平头重卡 `CustomGeometry`，内部固定为主车漆/浅色侧围/轮胎/金属/玻璃/灯光 6 个 PBR section；禁止恢复球形弹珠、外部整车 MDL、固定装饰车发射台、跑车/皮卡轮廓或方块体素瓦片车辆
- 大运重卡几何契约：必须具备平头高顶驾驶室、长货厢、三轴六轮、大面积前风挡、重卡格栅与外露保险杠；浅色侧围必须作为独立材质分区；车辆局部 +X 为车头，飞行朝向由速度计算，待发射瞄准时由发射向量计算；规则层仍保留统一发射坐标
- 四弹药槽契约：3D 后端底部必须显示分裂/冰冻/加速/巨型四个独立槽位，包含序号、中文名、装填态、储备数量和类型色，禁止退化为纯文字图例
- 防线撞击契约：`base_hit` 必须先由 `Presentation.lua` 维护瞬时状态，再由 3D 后端消费为相机震动、防线材质脉冲、冲击波和警示文字，禁止只扣血无空间反馈
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
