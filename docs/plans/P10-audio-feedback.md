# P10 · 音效音乐与反馈打磨模块开发计划书

> 版本：v0.9.0 规划 / 草稿 v1
> 模块方向：BGM、SFX、空间反馈、震屏/冲击波、升级/越线音画同步
> 目标读者：负责 `Presentation.lua` 反馈状态机与音频资源接入的开发者

---

## 一、模块目标

本模块负责「玩家听到的与感受到的反馈」。v0.9.0 已把「视觉瞬时状态」收口到 `Presentation.lua`：它消费 `Game.DrainEvents()` 的领域事件（如 `base_hit`、`bounce`、`hit`、`upgradeApplied`），维护短生命周期脉冲/冲击波/冻结计时，供 `Renderer3D` 与 `Scene3DBackend` 只读消费（AB-013）。但**音频层尚未接入**——音效与 BGM 仍是空白。本计划书规划**音频与反馈闭环**，并固化「反馈触发在 `Presentation`，渲染/音频只读消费，规则层不参与」的约束。

核心不变量（CLAUDE.md 避雷清单）：
- 视觉瞬时状态契约：`Presentation` 维护瞬时状态，渲染后端只读消费；`Game` 规则层不直调渲染或输入。
- 防线撞击契约：`base_hit` 先由 `Presentation` 维护瞬时状态，再由 3D 后端消费为相机震动、防线材质脉冲、冲击波和警示文字；禁止只扣血无空间反馈。
- 幸存者核心契约：升级由 `Game.PickUpgrade` 恢复 `playing`，`Presentation` 维护 `upgradeApplied` 供反馈消费。
- 显式释放（规则 #15）：音频/粒子资源销毁需 `Dispose` 或引擎回收，防泄漏。

实现路径：音频资源通过 UrhoX 官方 MCP 生成——`text_to_sound_effect`（打击/UI/环境循环音）、`text_to_music`（BGM 段落），下发给 `cache:GetResource("Sound", ...)` 由 `SoundSource` 播放；不自行拼接二进制。

---

## 二、现状与反馈缺口

### 2.1 已达标项
- `Presentation` 已维护 `base_hit` 的冲击包络、`freeze` 计时、`upgradeApplied` 钩子（供后续消费）。
- 3D 后端已承接部分（`baseHitShake` 相机震屏、防线脉冲，见 P2 T2）。
- 事件总线 `Game.DrainEvents()` 是反馈唯一来源（规则层不直绘）。

### 2.2 反馈缺口
1. **音频完全缺失**：无 BGM、无打击音、无反弹音、无升级音、无越线警报。幸存者循环缺少「听觉压力」维度。
2. **反馈与事件耦合松散**：`Presentation` 维护了状态，但震屏/脉冲/音效未统一「事件 → 反馈强度」映射表，易各写各的。
3. **空间反馈单薄**：越线只有相机微震，缺「防线被啃」的专属冲击波粒子与音画同步（防线撞击契约要求冲击波+警示文字+脉冲+震屏四位一体）。
4. **升级反馈弱**：`upgradeApplied` 仅逻辑钩子，无「卡牌选定 → 光效扫过 → 音效确认」的爽点。
5. **音频资源未规划**：哪些音效用生成、哪些循环、音量/优先级未定义，直接调 `text_to_sound_effect` 易杂乱。

---

## 三、架构切面

反馈中枢在 `Presentation.lua`（消费 `Game` 事件，产出瞬时状态 + 触发音频播放指令）。`Renderer3D`/`Scene3DBackend` 只读 `Presentation.GetSnapshot()` 画视觉；音频播放由 `Presentation` 内的 `SoundSource` 驱动（规则层 `Game` 不感知音频，AB-027）。本模块：
- `Presentation.lua`：事件→反馈映射表、音频播放封装、`Dispose` 回收。
- `Scene3DBackend.lua`（最小）：消费 `Presentation` 冲击波/脉冲（与 P2 T2 协同）。
- 资源生成：经 `text_to_sound_effect` / `text_to_music` MCP 落地 `assets/Sounds/`。
- 不引入 `Game` 玩法判定（AB-027）。

---

## 四、具体任务清单

### T1：事件→反馈映射表
在 `Presentation` 建 `FEEDBACK_MAP`：`base_hit`→{shake=0.6, flash=0.8, sfx="sfx_base_hit", wave=true}；`bounce`→{sfx="sfx_bounce", vol=0.4}；`hit`→{sfx="sfx_hit", vol=0.6}；`upgradeApplied`→{sfx="sfx_upgrade", flash=1.0}；`freeze`→{sfx="sfx_freeze"}。所有视觉/音频强度集中此表，禁止散落（AB-013 精神）。

### T2：音频资源生成与落地
用 `text_to_sound_effect` 生成：`sfx_bounce`（清脆弹跳）、`sfx_hit`（砖块碎裂）、`sfx_base_hit`（低沉冲击+警报感）、`sfx_upgrade`（上行确认音）、`sfx_freeze`（霜冻嘶鸣）、`sfx_split`（分裂 pop）、`sfx_giant`（贯穿轰鸣）。用 `text_to_music` 生成 BGM：一段循环「太空生存压力」低频脉冲（loop=true）。落地 `assets/Sounds/`，`cache` 引用。

### T3：音频播放封装
`Presentation` 内 `PlaySfx(name, vol)`：`sound = cache:GetResource("Sound", "Sounds/"..name..".ogg")`；`source:Play(sound)`（复用场景级 `SoundSource` 或节点级）。BGM 在 `StartGame` 时 `source:SetLooped(true)` 播放，`gameover`/`paused` 时 `Stop`。资源加载失败打 `print` 不崩。

### T4：防线四位一体反馈
`base_hit` 事件驱动（防线撞击契约）：① `Presentation` 维护 `baseHitShake` 包络 → `Scene3DBackend` 相机震屏（P2 T2）；② `baseHitFlash` → 防线材质脉冲；③ 冲击波粒子（对象池，P9 T3）；④ NanoVG 警示文字「⚠ 防线受损」（UI 安全层契约，仅非菜单态）。T1 映射表统一强度，音画同步。

### T5：升级爽点反馈
`upgradeApplied` 触发：卡片选定后 `Presentation` 维护 `upgradeSweep`（扫光包络 0.3s）→ `Scene3DBackend.DrawLevelUp` 只读展示扫光；同时 `sfx_upgrade` 播放。恢复 `playing` 的瞬间无突兀。

### T6：反馈强度随状态（可选）
`baseHitShake` 强度可随 `baseHp` 百分比提升（血越低震越强），但「血量」读 `GetSnapshot().baseHp`（规则层数值），`Presentation` 只读不写（AB-027）。映射表 `shake` 改为 `base(baseHp)` 函数。

### T7：显式释放音频
`Presentation` 卸载/重开时 `Dispose` `SoundSource`、停止 BGM，防残留（规则 #15）。调试计数「活跃音源数」。

---

## 五、风险与避雷

- **禁止规则层播音频**：`Game` 不持有 `SoundSource`、不调 `Play`；音频触发在 `Presentation`（AB-027 / 视觉瞬时状态契约）。
- **禁止只扣血无反馈**：`base_hit` 必须四位一体（防线撞击契约），T4 不可缺项。
- **禁止渲染层算反馈强度**：`shake/flash` 来自 `Presentation` 映射表，渲染只读（AB-013）。
- **禁止破坏 UI 安全层**：警示文字/扫光仅非菜单态绘制，不与 HUD 相交（UI 安全层契约 AB-022）。
- **资源失败不崩**：音频加载失败 `print` + 跳过，不中断游戏（规则 #16 日志先行，但最终清理调试）。
- **显式释放**：音源 `Dispose`（规则 #15）。

---

## 六、验收标准

1. 所有核心事件有统一反馈映射表，强度集中不散落（T1，AB-013）。
2. 6 类 SFX + 1 段 BGM 经 MCP 生成落地 `assets/Sounds/`，可播放（T2）。
3. 音频播放封装复用音源，失败不崩（T3）。
4. 越线扣血四位一体（震屏+脉冲+冲击波+警示），音画同步（T4，防线撞击契约）。
5. 升级有扫光+确认音爽点（T5）。
6. 反馈强度可随血量只读演化（T6，AB-027）。
7. 重开显式释放音源，活跃音源计数稳定（T7，规则 #15）。LSP 0 Error + 官方构建通过；`Game` 无音频 API 调用。

---

## 七、后续迭代建议

- 与 P2（渲染）协同：T4 震屏/脉冲由 P2 T2 承接，T1 映射表是二者共享强度源。
- 与 P5（升级）协同：T5 `upgradeApplied` 来自 P5 T6 钩子，字段名稳定。
- 与 P4（弹珠）协同：T1 `bounce`/`hit`/`split`/`giant` 事件由 P4 规则层 `Emit`，强度在 `Presentation` 不回写 `Game`。
- 与 P9（性能）协同：T4 冲击波粒子用 P9 T3 对象池；T7 释放与 P9 T5 节点释放同步审计。
- 与 P8（UI）协同：T4 警示文字、T5 扫光遵守 UI 视觉契约（深紫/淡蓝工程风，AB-017）。


## 八、实施里程碑排期

- **M1（映射与生成，1 周期）**：完成 T1/T2，反馈映射表 + 6 SFX/1 BGM 生成落地。Gate：资源可加载播放。
- **M2（播放封装，0.5 周期）**：完成 T3，复用音源、失败不崩。Gate：`gameover`/`paused` 止 BGM。
- **M3（四位一体，1 周期）**：完成 T4，越线震屏+脉冲+冲击波+警示。Gate：音画同步。
- **M4（升级爽点+释放，1 周期）**：完成 T5/T7，扫光+确认音、显式 `Dispose`。Gate：活跃音源稳定。

## 九、回滚与降级预案

若某 SFX 生成不符预期：用 `text_to_sound_effect` 重生成同名覆盖 `assets/Sounds/`，不改代码（资源与逻辑解耦）。若音频导致卡顿：BGM 改更低码率、SFX 限同时播放数（音源池大小）。任何音频触发不得在 `Game` 出现（AB-027）；若误加，回退到 `Presentation.PlaySfx`。资源加载失败必须 `print`+跳过，不中断（规则 #16 日志先行，最终清理调试日志）。

## 十、关键伪代码参考

```lua
-- Presentation 反馈映射 + 播放（规则层不感知）
local FEEDBACK_MAP = {
  base_hit = { shake=0.6, flash=0.8, sfx="sfx_base_hit", wave=true },
  bounce   = { sfx="sfx_bounce", vol=0.4 },
  upgradeApplied = { sfx="sfx_upgrade", flash=1.0 },
}
function OnEvent(ev)
  local fb = FEEDBACK_MAP[ev.type]; if not fb then return end
  if fb.shake then baseHitShake = fb.shake end  -- 供渲染只读
  if fb.sfx then PlaySfx(fb.sfx, fb.vol or 0.6) end
end
```
`OnEvent` 消费 `Game.DrainEvents()`；`baseHitShake`/`baseHitFlash` 由 `Scene3DBackend` 只读（AB-013）。`PlaySfx` 复用场景 `SoundSource`，`Gameover` 时 `Stop`（规则 #15 显式释放）。


## 附录 A · 跨模块接口契约

- `Presentation`（反馈）→ `Game`：消费 `DrainEvents`，`Game` 不感知音频（AB-027）。
- `Presentation` → `Scene3DBackend`：`baseHitShake`/`baseHitFlash`/`upgradeSweep` 只读消费。
- `Presentation` → P9：冲击波粒子走 P9 对象池，音源 `Dispose` 与 P9 节点释放同步。
- `Presentation` → P4：`bounce`/`hit` 事件由 P4 `Emit`，强度在本层不回写。
- `Presentation` → P8：警示文字/扫光遵守 UI 视觉契约。

## 附录 B · 验收用例清单

| 用例 | 步骤 | 期望 |
|------|------|------|
| 映射表 | 各事件 | 强度集中、不散落 |
| 资源 | 生成落地 | 6 SFX+1 BGM 可播 |
| 播放 | 加载失败 | print+跳过、不崩 |
| 四位一体 | 越线 | 震屏+脉冲+冲击波+警示同步 |
| 升级爽点 | 选卡 | 扫光+确认音 |

## 附录 C · 风险检查表

- [ ] `Game` 无 SoundSource/Play 调用（AB-027）
- [ ] `base_hit` 四位一体无缺项（防线撞击契约）
- [ ] 渲染层无反馈强度计算（AB-013）
- [ ] 警示/扫光仅非菜单态、不交 HUD（UI 安全层契约）
- [ ] 音源显式 Dispose（规则 #15）


## 十一、设计哲学与反模式

反馈系统的第一性原理是「规则事件单向驱动视觉与音频，反馈中枢在 Presentation 而非 Game 或渲染层」。反模式有三：其一是规则层 `Game` 直接播音频或调震屏，破坏权威规则层纯净（AB-027）；其二是渲染层自己算反馈强度（如根据血量改震屏），导致强度来源不唯一（AB-013 要求反馈状态由 Presentation 维护）；其三是 `base_hit` 只扣血无空间反馈，违反防线撞击契约的四位一体要求。本模块以 `FEEDBACK_MAP` 集中事件→强度映射，音频由 `Presentation` 的 `PlaySfx` 触发，视觉由 `Scene3DBackend` 只读消费，形成「事件进、音画出」的单向闭环。资源经官方 MCP 生成、加载失败不崩，是生产环境稳健性的底线（规则 #16）。
