# 暂不可实现与实现顺序 · 更新计划文档

> 配套 `WORK-ORDERS.md`。本文件单列：**当前环境/资源/依赖下暂无法实施**的项，以及它们的**实现顺序与解锁条件**。
> 判定标准：依赖 headless 截图验证、依赖 MCP 资源生成后接线、依赖 `clientCloud` 云端配置、依赖后效在本环境会黑屏、或依赖尚未落地的子系统。

---

## 一、暂不可实现清单（按原计划编号）

### A. 资源生成类（需 `generate_image` / `text_to_sound_effect` / `text_to_music` / `convert-panorama` / `run-lua-headless` 实际产出并接入）
- **P2-T4 星空 cubemap 近似反射**：需 `convert-panorama` 生成天空盒并绑定玻璃材质。当前未生成资源。
- **P2-T1/P12-T1 轮胎噪点纹理**：需 `run-lua-headless` 离线烘焙噪点 PNG 并入 PBR。未生成。
- **P10-T2 6 类 SFX + 1 BGM**：需 `text_to_sound_effect`/`text_to_music` 生成并落地 `assets/Sounds/`。本会话未自动接线（生成会落地资源但需 Preview 确认音频回放）。
- **P11 词条/异常图标**：需 `generate_image` 批量生成 64×64 工程风图标。未生成。
- **P12-T1 玻璃 cubemap / 清漆层纹理**：同 A 类资源依赖。

### B. 后效类（本验证环境 FXAA 禁用，Bloom/Vignette 需探测，盲目开即黑屏 — AB-008）
- **P12-T4 受控 Bloom / Vignette / ACES 色调映射**：必须 `Scene3DBackend` 初始化探测，确认无 shader cache 失败特征才启用；否则降级无后效。**不在此会话默认开启**。
- **P12-T3 镜头推近/旋转 juice**：可实施（仅相机位移 + `RefreshProjection`），但需实机确认不引发输入错位；属低风险但需 Preview 验证，列为「可实施但需确认」。

### C. 云端类（需项目 `clientCloud` 已配置且本会话未验证云端变量可用性）
- **P5-T? clientCloud 排行榜**：`examples/11-client-cloud-score-leaderboard-api.lua` 依赖云端配置。
- **P11-T4 局外 meta 养成（stardust 持久化）**：需 `clientCloud` 读写；失败降级用本地 `File`（见 `recipes/file-storage.md`）。
- **P11-T5 排行榜/每日挑战上报**：同上。
- **P11-T6 叙事碎片云端解锁**：可改用本地 `File` 解锁进度，降低依赖。

### D. 子系统未就绪（依赖其他工作单先落地）
- **P11-T1/T2 词条系统 + 五异常反应**：规则层可写，但**视觉协同图标（A 类）**与**反应特效（P12-T2 粒子）**未就绪 → 规则先落地、表现延后。
- **P11-T3 Boss 阶段机**：规则可写，但 Boss 旗舰 silhouette 需扩 `AircraftPixelData`（可纯数据做）、阶段切换特效需 P12。规则先落地。

### E. 验证类（无 headless 运行器 / 无 GLES 截图）
- 所有「实机确认」项（震屏手感、粒子密度、音频回放、后效不黑屏）均无法在本会话自动验证，必须用户在 Preview 确认。

---

## 二、实现顺序（解锁后推进）

```
阶段 α（本会话已/可实施，纯规则/输入/低风险渲染）：
  WO-01..WO-08（批次0+1）→ WO-09..WO-12（批次2，UI 只读快照）
  WO-13 冻结色偏移（顶点色，无需资源）→ WO-14 防线反馈（需 RefreshProjection，可实施）
  WO-16 碎片池/Dispose/快照复用（纯代码，可实施）

阶段 β（资源生成后接线）：
  A 类资源经 MCP 生成落地 → 接入 P2-T1/T4、P12-T1、P11 图标
  P10-T2 音频生成 → Presentation.PlaySfx 接线（需 Preview 确认回放）

阶段 γ（后效探测通过）：
  P12-T4 Bloom/Vignette 经 Scene3DBackend 探测护栏启用（AB-008）
  P12-T3 镜头 juice 实机确认后保留

阶段 δ（云端配置就绪）：
  P11-T4/T5/T6 接 clientCloud（或降级本地 File）
  P5 排行榜（若启用）

阶段 ε（子系统耦合）：
  P11-T1/T2/T3 规则落地后，等 A/D 类资源与 P12 粒子就绪，再补视觉协同
```

---

## 三、解锁条件检查表

| 项 | 解锁条件 | 当前状态 |
|----|---------|---------|
| A 类资源 | 调用对应 MCP 生成并落地 `assets/` | 未生成 |
| B 类后效 | Scene3DBackend 探测无 AB-008 失败 | 本环境默认禁 FXAA，Bloom 待探测 |
| C 类云端 | 项目配置 clientCloud 且云端变量可读 | 未验证 |
| D 类耦合 | 前置工作单落地 | 待批次0/1 |
| E 类验证 | 用户 Preview 确认 | 本会话无 headless |

---

## 四、风险与避雷（暂缓项同样守约）

- 即使暂缓，**规则层也先行落地**（如 P11 词条/异常/Boss 的 `Game` 逻辑），避免后期大规模重构；表现延后不延后规则。
- 任何暂缓项上线时，仍遵守：渲染只读快照、单 CustomGeometry、FXAA 禁用、PRNG 隔离、Lua 作用域。
- 资源生成后必须过 `recipes/preload-and-build-refs.md` 构建引用，避免运行时缺失（AB-003/AB-006 资源验证）。
- 音频加载失败必须 `print`+跳过不崩（规则 #16）。

---

## 五、本会话执行决策

- **现在做**：批次 0（WO-01..04）、批次 1（WO-05..08）——纯规则/输入，零资源/零后效依赖，LSP+构建可验证。
- **可顺带做（低风险、无资源依赖）**：WO-09..12（批次2 UI，只读快照）、WO-13/14/16（顶点色/反馈/性能，无资源）。
- **不做（写入本文件）**：A/B（除探测护栏）/C/D 视觉部分/E，待阶段 β–ε 解锁。
