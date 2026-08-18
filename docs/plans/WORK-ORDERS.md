# 工作单总纲 · 太空飞机弹珠 v0.9.0 → v1.0 实施规划

> 本文件把 `docs/plans/P1..P12` 的 12 份模块计划拆为**可执行工作单**，每项标注：
> - 来源计划、文件改动范围、性能兼容性护栏
> - 依赖前置、是否当前环境可实施
> - 验收门槛（LSP 0 Error + 官方构建 + 契约守门）
>
> **当前环境限制（必须牢记）**：无 headless 运行器 / 无 GLES 截图；FXAA 禁用（AB-008）；音频/图像 MCP 可生成资源但不在此会话自动接线；`clientCloud` 需项目已配置云端变量。凡依赖上述外部项者，一律列入 `deferred.md`（暂不可实现）。

---

## 一、实施原则（性能兼容性红线）

1. **规则/渲染零越界**：`Game.lua` 永不调用渲染 API；`Renderer3D`/`Scene3DBackend`/`Presentation` 只读 `GetSnapshot()`/`Presentation.GetSnapshot()`。违反即回退（AB-027）。
2. **单 CustomGeometry + 双 section**：敌方体素、车辆、星空禁止逐元素 Node（3D 体素性能契约 / AB-009 / AB-005）。
3. **仅拓扑/状态改变时重建**：体素/拖尾重建必须有版本号或状态差触发，禁止每帧重建（P2/P9）。
4. **WORLD_SCALE 统一**：所有世界尺寸经 `WORLD_SCALE` 映射；`VOXEL_GAP` 只缩本体不缩中心。
5. **FXAA 永不开**：后效（Bloom/Vignette）需探测护栏，失败即降级（AB-008）。
6. **PRNG 隔离**：玩法随机用既有 Park-Miller `randomState`，禁止 `math.random`（AB-002）。
7. **Lua 作用域**：被闭包前向引用的 `local`（如 `BALL_TUNING`/`BALANCE`/`GainXp`/`RollUpgradeChoices`）必须声明在引用点之上。

---

## 二、工作单清单（按批次）

### 批次 0 · 地基（无视觉，纯规则层重构，最安全）
- **WO-01**（P1）：引入 `BALANCE` 表，收敛 `BASE_HP`/`BRICK_BASE_DAMAGE`/`XP_*`/`WAVE_*`/`MAX_CONCURRENT` 为表字段，保留旧名只读别名。
- **WO-02**（P1）：经验曲线公式化 `xpToNext = floor(baseXpToNext * xpToNextGrowth^(level-1))`，新增 `xpToNextGrowth` 入 `BALANCE`，移除原 `(1+(lv-1)*0.35)` 写死。
- **WO-03**（P1）：波次间隔/连击封顶常量迁入 `BALANCE`（`waveTightenStep`/`clearStreakBonusCap`），`UpdateWaveLogic` 改读表。
- **WO-04**（P9）：`Renderer3D` 加 `REBUILD_BUDGET` 单帧重建上限 + 脏标记（`topologyVersion`/`frozen` 差触发），超预算延下帧。
- **性能护栏**：`REBUILD_BUDGET` 默认 4；`BALANCE` 声明在 `UPGRADE_POOL` 之上。

### 批次 1 · 手感与输入（规则+输入，低风险）
- **WO-05**（P4）：`BALL_TYPES` 加 `bounceElasticity`/`wallGrace`/`redirectMinSpeed`；`UpdateMarbles` 应用；巨型沉、加速滑、低速不追击。
- **WO-06**（P4）：`TrySplitNormal` 继承母弹速度 + `splitSpread` 扩散；分裂概率 `0.05+BALL_TUNING.splitBonus`。
- **WO-07**（P4）：`DamageGiantArea` 贯穿后继续飞仅一次武装，语义文档化。
- **WO-08**（P7）：`main.lua` 蓄力（拖拽距离→初速，`POWER_PER_PIXEL`/`MIN_P`/`MAX_P` 由 `Game` 暴露常量）、letterbox 外硬过滤、多指归属、`TryPickUpgradeAt` 命中外扩 `HIT_PAD`。

### 批次 2 · 成长与界面（规则+UI，中风险）
- **WO-09**（P5）：`UPGRADE_POOL` 加 `weight`/`rarity`/`maxStacks`/`tradeoff`；`RollUpgradeChoices` 按权重+保底；`apply` 边际递减；抉择型负向项。
- **WO-10**（P5）：`GetSnapshot` 升级卡增 `delta` 字段（当前→升级后预览）。
- **WO-11**（P8）：`Scene3DBackend.DrawHud` 加波次/同屏/连击指标（读 P6 快照）；`DrawUpgradeCard` 显 `delta` 工程风参数行；`DrawGameOver` 加统计回顾。
- **WO-12**（P6）：`BALANCE` 加 `phaseLength`/`phaseTightenBonus`/`breatherEvery`/`safeGap`；`UpdateWaveLogic` 阶段呼吸 + 安全窗口；`GetSnapshot` 暴露 `wave`/`concurrentCount`。

### 批次 3 · 表现与反馈（渲染+反馈，需谨慎后效）
- **WO-13**（P2/P9）：冻结色偏移（读 `Presentation.freezeRatio`）、体素正面动态高光（顶点色）、拖尾速度档节流重建。
- **WO-14**（P2/P10）：防线四位一体（震屏+脉冲+冲击波+警示），`Presentation` 维护包络，渲染只读；`RefreshProjection` 封装。
- **WO-15**（P10）：`Presentation` `FEEDBACK_MAP` 事件→反馈映射；音频占位（实际音源接 `deferred.md`）。
- **WO-16**（P9）：碎片对象池、`GetSnapshot` 缓冲复用、敌机 `Dispose` 审计、FXAA 探测关闭。

---

## 三、依赖关系

```
WO-01 → WO-02 → WO-03 → WO-12 (P6 读 BALANCE)
WO-04 (P9 护栏) 独立，可并行 WO-01
WO-05 → WO-06 → WO-07 (P4 弹珠)
WO-08 (P7 输入) 依赖 WO-05 蓄力常量
WO-09 → WO-10 → WO-11 (P5/P8)
WO-13 → WO-14 → WO-15 → WO-16 (P2/P9/P10 渲染反馈链)
```

---

## 四、验收门槛（每单必过）

1. `mcp__sce-urhox__lua_lsp_client` 诊断 0 Error（重点查 undefined global / 作用域）。
2. `mcp__sce-urhox__build` 官方构建成功。
3. `Game.lua` 内无渲染 API 调用（grep 断言）。
4. 渲染层无 `Game.` 写入（grep 断言）。
5. 契约守门：单 CustomGeometry、仅拓扑重建、FXAA 未开、PRNG 隔离。

---

## 五、本会话执行范围

按依赖与风险，**本会话先实施批次 0 + 批次 1（WO-01..WO-08）**，因其纯规则层/输入层、不触碰后效与资源生成，在当前无 headless 环境下可凭 LSP + 构建验证。批次 2/3 视首轮稳定性与用户确认推进。所有依赖外部资源/MCP 接线的项见 `deferred.md`。
