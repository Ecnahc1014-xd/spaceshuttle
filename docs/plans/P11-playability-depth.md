# P11 · 可玩度深度系统开发计划书（对标一线大作系统密度）

> 版本：v0.9.0 规划 / 草稿 v1
> 模块方向：构筑多样性、Boss 编队、状态异常体系、局外养成、赛季/挑战、世界观叙事
> 目标读者：负责 `Game.lua` 规则层深度扩展与 `clientCloud` 云存档接入的开发者

---

## 一、模块目标与诚实定位

《原神》作为一线大作，其「可玩度」来自系统密度：元素反应、圣遗物构筑、角色命座、周本 Boss、版本活动、世界观叙事。本游戏是 540×960 9:16 体素弹珠幸存者，不可能复制开放世界，但可以在**同屏系统密度与构筑深度**上对标其「肉鸽/刷宝」子类（如《吸血鬼幸存者》《元气骑士》），并在几个维度做到更聚焦的深度。

本模块目标：把当前「四弹珠 + 8 升级 + 连续波次」的薄循环，扩展为具备**构筑层、异常层、Boss 层、养成层、社交层、叙事层**六层结构的深度可玩系统，且每一层都严守「规则在 `Game`、渲染只读」的架构契约（AB-027）。

诚实边界：我们不与《原神》比「画面规模」，而比「单局策略深度 + 元进度粘性 + 系统间耦合涌现」。这恰是肉鸽幸存者类型的制胜点——用极简操作承载极深构筑。

---

## 二、六层深度设计

### 2.1 构筑层：弹珠词条与协同（超越 4 基础弹）
当前四弹珠（分裂/冰冻/加速/巨型）仅类型差异。扩展为**词条系统**：每颗弹珠除 `ballType` 外，携带 2–3 条 `modifiers`（如 `pierce+1`、`explodeOnDeath`、`lifestealOnHit`、`chainLightning`、`slowAura`）。升级池从「改 BALL_TUNING」扩展为「给当前手持/全部弹珠追加词条」。词条间产生**协同**（如 `chainLightning` + `freeze` = 冻结链式传导）。规则层用 `MarbleDef.mods` 表，渲染只画词条图标（读 `GetSnapshot`）。

### 2.2 异常层：状态反应体系
当前仅有冰冻。扩展为**五异常**：冰冻（减速/定身）、燃烧（持续 DOT + 脆弱）、腐蚀（降甲/增伤）、感电（连锁跳跃）、过载（蓄满爆发）。规则层 `StatusSystem` 维护每砖块的 `statusStacks`；异常间有**反应**（冰冻+燃烧=碎裂额外伤害，感电+腐蚀=范围腐蚀爆）。反应公式在 `Game`，渲染只消费反应事件做特效（P12 协同）。

### 2.3 Boss 层：精英编队与周本
当前敌机均匀随机。扩展为**阶段 Boss 编队**：每 5 波生成一个「旗舰编队」（更大像素 silhouette、多段血、阶段切换弹幕阵型）。Boss 有 `phase` 状态机（规则层 FSM），阶段切换时改变 `formation` 与 spawn 节奏。击破 Boss 掉落「核心词条」或大量 XP。周本（P5 协同）由 `clientCloud` 记录最佳成绩。

### 2.4 养成层：局外 meta 进度
当前每局从零开始。扩展为**局外货币**（每局结算按存活/击碎/波次给 `stardust`），`clientCloud` 持久化；meta 商店解锁「起始词条槽 +1」「基础 brickDmg 微调」「起始携带一颗强化弹珠」。养成只改 `Game` 初始 `BALL_TUNING`/起始状态，不破坏单局平衡（P1 协同）。

### 2.5 社交层：排行榜与挑战
利用现有 `clientCloud` 云变量（见 `examples/11-client-cloud-score-leaderboard-api.lua`）：周榜（最高波次）、赛季榜（累计 stardust）、每日挑战（固定种子 `seed` + 强制 mutator）。`Game` 暴露 `seed` 与 `mutators` 字段，渲染只读展示。

### 2.6 叙事层：世界观碎片
太空飞机弹珠的「基地防线」可承载轻叙事：每升 10 级解锁一段「舰队日志」文本（读 `clientCloud` 或本地 `File`），在 menu 静态展示。叙事不进玩法，纯 menu 层（P8 协同），强化「为什么守这条线」的代入感。

---

## 三、架构切面与契约坚守

- `Game.lua`：新增 `StatusSystem`、`BossFSM`、`Modifiers`、`MetaProgress`（读 `clientCloud`）、`RunSeed`。全部规则计算。
- `clientCloud`（客户端）：`MetaProgress` 持久化、`Leaderboard` 上报。仅在 `Game.StartGame`/`Game.EndRun` 边界调用，不进每帧循环（AB-027：规则层纯净，云调用属边界 IO）。
- `Renderer3D`/`Scene3DBackend`：只读 `GetSnapshot` 的 `mods`/`status`/`boss`/`seed` 字段画图标/特效/编队。
- `AircraftPixelData`：Boss 旗舰 silhouette 仍是像素剪影（遵守飞机采样权威契约，禁止写实）。

---

## 四、具体任务清单

### T1：词条系统
`BALL_TYPES` 每型加 `modPool`；升级池新增「追加词条」项，写 `marble.mods`。`GetSnapshot` 暴露 `marbleMods`。协同表 `SYNERGIES` 在 `Game` 计算额外效果。

### T2：五异常与反应
`StatusSystem` 维护 `statusStacks`，`DamageBrick` 结算 DOT/反应。反应事件 `Emit("reaction", {...})` 供 P12 特效。`freezeDuration` 等仍受 `iceBonus` 影响（P5 协同）。

### T3：Boss 阶段机
`BossFSM` 每 5 波生成旗舰，多段血 + `phase` 切换改变 `formation`/`spawnRate`。`SpawnWave` 读 `BossFSM` 状态。击破给 `XP_PER_CLEAR * bossMult`（P5 协同）。

### T4：局外养成
`MetaProgress` 用 `clientCloud` 存 `stardust` 与解锁项；`Game.StartGame` 读解锁初始化 `BALL_TUNING`/起始弹珠。失败降级：本地 `File` 缓存（见 `recipes/file-storage.md`）。

### T5：排行榜与每日挑战
`clientCloud.score` 上报最高波次/累计；`RunSeed` 由每日日期哈希 + `mutators` 表。`GetSnapshot` 暴露 `seed`/`mutatorTags`。

### T6：叙事碎片
menu 层读 `clientCloud`/`File` 的「舰队日志」解锁进度，静态展示（P8 协同），不进玩法。

---

## 五、风险与避雷

- **禁止渲染层算构筑/异常/反应**：全部在 `Game`；渲染只读快照（AB-027 / 视觉瞬时状态契约）。
- **禁止破坏单一数据源**：Boss 旗舰 silhouette 仍由 `AircraftPixelData` 单一来源（飞机采样权威契约）。
- **禁止离散波次回归**：Boss 是连续涌出中的特殊编队，非「清完才出」（波次节奏契约）。
- **云调用边界化**：`clientCloud` 只在开局/结算调用，不进每帧（AB-002 随机流 / AB-027 纯净）。
- **PRNG 隔离**：`RunSeed` 用 Park-Miller 派生，不 `math.random`（AB-002）。
- **数值护栏**：meta 养成只微调，不破坏单局平衡（P1 协同，进 `BALANCE`）。

---

## 六、验收标准

1. 弹珠带词条且产生协同，升级池可追加（T1）。
2. 五异常生效且有反应，特效由 P12 承接（T2）。
3. 每 5 波出 Boss，多段血 + 阶段切换（T3，波次契约守住）。
4. 局外 stardust 持久化，解锁影响开局（T4）。
5. 排行榜/每日挑战可用（T5，clientCloud）。
6. 叙事碎片在 menu 展示（T6，P8 协同）。LSP 0 Error + 官方构建通过；`Game` 外无规则计算。

---

## 七、实施里程碑与对标结论

- **M1**：T1 词条 + T2 异常（构筑与异常层）。
- **M2**：T3 Boss 阶段机（Boss 层）。
- **M3**：T4 meta 养成（养成层）。
- **M4**：T5 排行榜/挑战 + T6 叙事（社交/叙事层）。

**对标诚实结论**：在「单局策略深度 + 元进度粘性 + 系统耦合涌现」上，本系统可在肉鸽幸存者类型内达到《原神》刷宝/活动子系统的密度；但在画面规模、开放世界、动作演出上不可能、也不应复制《原神》。本游戏的优势是「极小操作承载极深构筑」，对标对象应是《吸血鬼幸存者》《元气骑士》而非开放世界 ARPG。把资源砸在系统密度与 juice 打磨（P12），而非复制不可能的大世界，才是正确路线。

## 八、反模式与契约红线对照表

| 反模式 | 红线契约 | 本模块守约做法 |
|--------|---------|--------------|
| 渲染层算异常/反应伤害 | AB-027 规则层纯净 | StatusSystem 全在 Game，渲染只读 snapshot.status |
| Boss 退化成离散波次 | 波次节奏契约 | Boss 是连续涌出中的特殊编队，spawn 守卫不变 |
| 写实 Boss 多边形 | 飞机采样权威契约 | 旗舰仍是像素 silhouette，单一数据源 |
| 云调用进每帧 | AB-002 随机流/AB-027 | clientCloud 仅开局/结算边界 IO |
| meta 破坏单局平衡 | P1 BALANCE 护栏 | 养成只微调起始，不越 BALANCE 上限 |
| 随机用 math.random | AB-002 随机流隔离 | RunSeed 用 Park-Miller 派生 |

## 九、系统耦合涌现示例

当 P11 六层叠加，会自然涌现深度策略：例如「冰冻词条 + 燃烧异常 = 碎裂反应」产生范围 AOE，配合「加速弹 + chainLightning 词条」在密集编队中连锁，再叠加 Boss 阶段切换的弹幕阵型变化，单局内形成《原神》元素反应式的「构筑 → 异常 → 连锁 → Boss 应对」闭环。这正是我们用极简操作承载极深策略的设计哲学——不比画面规模，比系统密度与涌现深度。

## 十、深度系统验收用例表

| 层 | 用例 | 期望 |
|----|------|------|
| 构筑 | 升级追加 chainLightning | 弹珠带词条图标，命中连锁相邻砖块 |
| 异常 | 冰冻+燃烧 | 触发碎裂反应，额外 AOE 伤害 |
| Boss | 第 5 波 | 旗舰编队出现，多段血 + phase 切换阵型 |
| 养成 | 结算后重开 | stardust 增加，解锁项影响起始弹珠 |
| 社交 | 每日挑战 | 同 seed 同 mutator，排行榜可上报 |
| 叙事 | 升 10 级 | menu 解锁一段舰队日志文本 |

## 十一、资源与技能调度

本模块需调用多个引擎 MCP：词条/异常图标用 `generate_image` 批量生成 64×64 工程风图标；Boss 旗舰 silhouette 在 `AircraftPixelData` 以像素数据定义（不依赖贴图）；噪点/全景天空盒用 `run-lua-headless` 与 `convert-panorama` 离线生成（AB-003 资源验证）；排行榜/养成走 `clientCloud`（见 `examples/11-client-cloud-score-leaderboard-api.lua`）。所有生成资源落地 `assets/` 并经构建引用策略（见 `recipes/preload-and-build-refs.md`），避免运行时缺失。

## 十二、结语

六层深度系统不是一次性铺开，而应按 M1–M4 里程碑渐进交付：先构筑与异常（单局深度），再 Boss（节奏高点），再养成与社交（元进度粘性），最后叙事（代入感）。每一层都经现有架构契约守门，确保「深而不乱」。当六层叠加，本游戏将在肉鸽幸存者赛道形成《原神》活动副本级别的「系统密度 + juice 手感」组合，这正是我们超越「三维弹珠 + 肉鸽打砖块 + 太空飞机」简单相加的发力点：不是三个类型的拼接，而是一个有深度的系统生态。
