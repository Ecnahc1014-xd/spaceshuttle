<!-- RECOVERY INSTRUCTIONS -->
<!-- 新会话 AI 读到此文件时： -->
<!-- 0. CLAUDE.md 已自动注入 → 已知当前状态和关键避雷 -->
<!-- 1. 读取本文件 → 恢复项目上下文 -->
<!-- 2. 读取 docs/persona.md → 加载助手人格 + 用户偏好 -->
<!-- END RECOVERY INSTRUCTIONS -->

# 项目记忆索引

项目：燃烧的蔬菜
当前版本：0.3.1
简述：540×960 竖屏弹弓弹珠砖块游戏，已接入高性能 3D 体素敌人、碎裂表现和完整车辆本体发射后端。
最后巩固：2026-08-05

## 项目概况
- 技术栈：UrhoX Lua 5.4，单机模式，raw NanoVG 模式 A（540×960 设计分辨率 + letterbox）。
- 核心玩法：四类弹珠、蔬菜像素砖块、波次、基地生命、计分。
- 当前强化玩法：基础弹每次命中独立 5% 概率生成两颗完整分裂弹且可递归；加速弹反弹/命中加速、速度分档增伤并追击最近砖块；巨型弹反弹后武装直径 7 格圆域贯穿。
- 敌方基础下落速度为原来的 25%；冰冻继续在此基础上应用 0.3 倍倍率。
- 分层数据流：引擎事件 → `main.lua` → `Game` 更新/事件 → `Presentation` → snapshot → 渲染后端。

## 关键文件
| 文件 | 用途 |
|------|------|
| `scripts/main.lua` | 纯编排入口；转发引擎输入和 Update，连接核心、表现、后端 |
| `scripts/Game.lua` | 引擎无关的权威规则、碰撞、波次、输入动作、领域事件与游戏快照 |
| `scripts/Presentation.lua` | 消费领域事件，维护粒子、飘字、拖尾、闪白、震屏和波次横幅 |
| `scripts/VisualCatalog.lua` | 当前 2D 后端的弹珠样式和蔬菜砖块颜色映射 |
| `scripts/Renderer3D.lua` | 只读同步 3D 体素方块、车辆本体、碎片；每敌人一个 `CustomGeometry`，每个 `marble.id` 一个完整车辆模型 |
| `scripts/Scene3DBackend.lua` | 3D Scene/Camera/Viewport、正交坐标映射和 NanoVG HUD 覆盖层 |
| `scripts/Renderer.lua` | 无规则计算的 NanoVG 绘制器，只消费两个快照 |
| `scripts/VeggiePixelData.lua` | 蔬菜网格、分数、速度倍率与像素数据源 |
| `assets/model/6d5f1062-5bea-5cf8-a404-280333d4d4c8/` | 低多边形越野皮卡 MDL、LOD、diffuse/normal 纹理和材质资源 |

## 有效决策
- D-001: 采用“权威规则快照 + 领域事件 + 表现快照 + 可替换后端”的渐进式分层，不重写现有玩法（v0.2.0）。
- D-002: 逻辑随机数使用 `Game.lua` 内部 Park-Miller PRNG，避免渲染帧率消耗全局 `math.random()` 后改变玩法结果（v0.2.0）。
- D-003: 瞄准轨迹由规则层生成点集，渲染器只画点，避免 2D/3D 后端重复发射公式（v0.2.0）。
- D-004: 当前保留 540×960 设计空间作为玩法坐标；3D 后端负责将其映射到米制世界坐标（v0.2.0）。
- D-005: 敌方存活砖块由每敌人一个顶点色 `CustomGeometry` 组成，仅在拓扑或冻结状态改变时重建；`brick_hit.destroyed` 只在 Presentation 创建临时碎片，碎片不参与规则碰撞（v0.3.1）。
- D-006: 每个 `marble.id` 绑定一个完整车辆模型；待发射、飞行、反弹、碰撞、分裂和巨型弹都由车辆表现，规则层仍使用统一发射坐标（v0.3.1）。

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
- v0.3.1: 将逐体素 `Node + StaticModel` 改为每敌人顶点色 `CustomGeometry` 并剔除内部面；修复固定车辆字符串键长度判断导致的节点泄漏；使用低多边形越野皮卡 MDL 替代简陋基础几何；每个 marble 统一显示车辆本体；本地纹理路径消除 UUID 资源错误；Lua LSP 0 Error，官方构建成功，GLES 菜单截图成功生成。
- v0.3.0: 新增 3D 体素/运输车后端；敌方方块击碎后生成分散、旋转、缩小碎片；四类弹珠绑定四辆运输车；Lua LSP 0 Error，官方构建成功，GLES 截图可生成但 runtime 的 NanoVG shader cache 有错误。
- v0.2.1: 完成常规“双响分裂”、加速“四连撞超载电弧”、巨型“首撞反震后贯穿”；加入一帧内砖块去重、回响弹出生砖忽略与技能领域事件；LSP 0 Error，官方构建成功。
- v0.2.0: 分离核心玩法、表现状态、视觉目录、NanoVG 后端和应用编排。

## 验证记录
- Lua LSP：`Renderer3D.lua` Error 0。
- 官方 build：成功，入口 `main.lua`，单机模式。
- UrhoXRuntime headless：`lua_errors=0`；用户车辆 MDL、diffuse/normal、本地体素 Technique 均无资源错误；剩余 `Editor/Textures/Engine/Vignetting.png` 与 shader cache 错误属于运行时环境。
- GLES surfaceless：退出码 0，生成 `/workspace/screenshots/scene.png`；菜单画面已显示待发射运输车辆。日志仍有 NanoVG ESSL shader cache 与 Vignetting 环境错误。

## 下一步
1. 在真实 GLES shader cache 正常的运行环境中复测 3D 体素、碎片和运输车动画。
2. 如需更高辨识度，再用真实车辆模型替换基础几何车体，不改变 `ballType` 映射。
3. 保持 HUD 与规则层解耦，继续让 3D 后端只消费两个 snapshot。
