<!-- RECOVERY INSTRUCTIONS -->
<!-- 新会话 AI 读到此文件时： -->
<!-- 0. CLAUDE.md 已自动注入 → 已知当前状态和关键避雷 -->
<!-- 1. 读取本文件 → 恢复项目上下文 -->
<!-- 2. 读取 docs/persona.md → 加载助手人格 + 用户偏好 -->
<!-- END RECOVERY INSTRUCTIONS -->

# 项目记忆索引

项目：燃烧的蔬菜
当前版本：0.2.0
简述：540×960 竖屏弹弓弹珠砖块游戏，当前使用 NanoVG 2D 后端，已为 3D 后端完成逻辑/表现解耦。
最后巩固：2026-08-04

## 项目概况
- 技术栈：UrhoX Lua 5.4，单机模式，raw NanoVG 模式 A（540×960 设计分辨率 + letterbox）。
- 核心玩法：四类弹珠、蔬菜像素砖块、波次、基地生命、计分。
- 已有强化玩法：常规球首次命中生成双响回声；加速球蓄能后连锁；巨型球首次反弹后进入贯穿。
- 分层数据流：引擎事件 → `main.lua` → `Game` 更新/事件 → `Presentation` → snapshot → 渲染后端。

## 关键文件
| 文件 | 用途 |
|------|------|
| `scripts/main.lua` | 纯编排入口；转发引擎输入和 Update，连接核心、表现、后端 |
| `scripts/Game.lua` | 引擎无关的权威规则、碰撞、波次、输入动作、领域事件与游戏快照 |
| `scripts/Presentation.lua` | 消费领域事件，维护粒子、飘字、拖尾、闪白、震屏和波次横幅 |
| `scripts/VisualCatalog.lua` | 当前 2D 后端的弹珠样式和蔬菜砖块颜色映射 |
| `scripts/NanoVGBackend.lua` | NanoVG 生命周期、540×960 模式 A 适配、坐标转换、2D renderer 调用 |
| `scripts/Renderer.lua` | 无规则计算的 NanoVG 绘制器，只消费两个快照 |
| `scripts/VeggiePixelData.lua` | 蔬菜网格、分数、速度倍率与像素数据源 |

## 有效决策
- D-001: 采用“权威规则快照 + 领域事件 + 表现快照 + 可替换后端”的渐进式分层，不重写现有玩法（v0.2.0）。
- D-002: 逻辑随机数使用 `Game.lua` 内部 Park-Miller PRNG，避免渲染帧率消耗全局 `math.random()` 后改变玩法结果（v0.2.0）。
- D-003: 瞄准轨迹由规则层生成点集，渲染器只画点，避免 2D/3D 后端重复发射公式（v0.2.0）。
- D-004: 当前保留 540×960 设计空间作为玩法坐标；3D 后端负责将其映射到米制世界坐标（v0.2.0）。

## 活跃系统契约
| 契约 | 文件 | 状态 |
|------|------|------|
| `Game.GetSnapshot()` | `scripts/Game.lua` | 稳定，渲染只读 |
| `Game.DrainEvents()` | `scripts/Game.lua` | 稳定，单次消费 |
| `Presentation.Update(dt, gameSnapshot, events)` | `scripts/Presentation.lua` | 稳定 |
| `Presentation.GetSnapshot()` | `scripts/Presentation.lua` | 稳定，渲染只读 |
| 后端 `Init/Shutdown/Resize/ScreenToGame/Render/GetDesignSize` | `scripts/NanoVGBackend.lua` | 3D 后端需实现同等编排职责 |

## 避雷清单
- TodoWrite 必须前置创建并包含 DEV + POST-1/2/3。
- `Game.lua` 禁止出现任何渲染 API、引擎对象、视觉参数或输入枚举。
- 不要让 renderer 自行重算瞄准轨迹或硬编码蔬菜 7×7 尺寸；尺寸来自快照中的 `gridW/gridH`。
- 不要向 NanoVG context 注入自定义字段传递状态。
- 不要用全局 `math.random()` 同时驱动玩法与画面；玩法使用独立随机流。
- 会话外修改可能与当前任务并发；写后若内容变化，必须重读并合并。
- validate 的 shader cache engine error 不是 Lua 错误；需结合 Lua/resource error 计数和真实截图判断。

## 最近变更
- v0.2.0: 分离核心玩法、表现状态、视觉目录、NanoVG 后端和应用编排；保留并合并三类新增弹珠强化玩法；LSP 0 Error，官方构建成功，GLES 菜单截图正常。

## 验证记录
- Lua LSP：0 Error。
- 官方 build：成功，入口 `main.lua`，单机模式。
- UrhoXRuntime：120 帧完整运行，`lua_errors=0`、`resource_errors=0`；验证器因 runtime shader cache 报 engine error。
- GLES surfaceless：生成 `screenshots/architecture-refactor.png`，视觉检查正常。

## 下一步
1. 新建 3D 后端/renderer，消费相同的 `Game.GetSnapshot()` 和领域事件。
2. 定义设计坐标到米制世界坐标的映射，并以稳定实体 `id` 同步 Scene Node。
3. 将 HUD 保留在 UI/2D overlay，世界对象改为 3D 节点与材质。
