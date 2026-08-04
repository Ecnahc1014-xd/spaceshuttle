# 燃烧的蔬菜 — 项目核心记忆

> AI 自维护，每次 POST 自动更新。详细规则见 memory-system skill。

## 当前状态
- 版本: 0.3.0
- 进度: 玩法规则与表现层稳定，已接入 3D 体素/运输车后端；敌方单位显示为体素方块，击碎后分散旋转并缩小；四类弹珠分别由四辆类型运输车待命/发射
- 上次交付: 新增 `Renderer3D.lua` 与 `Scene3DBackend.lua`；体素敌人、碎裂动画、四辆运输车和 3D HUD 已接入同一快照/事件链路

## 用户画像摘要
- 使用简体中文沟通
- 重视先做架构解耦，为后续 3D 开发降低迁移成本 [observed]

## 预测下一步
- likely_next_task: 基于 `Game.GetSnapshot()` 和领域事件实现 `Renderer3D`/3D 后端
- 相关文件: `scripts/Game.lua`, `scripts/Presentation.lua`, `scripts/NanoVGBackend.lua`, `scripts/Renderer.lua`, `scripts/main.lua`

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
- 四辆运输车是四类弹珠的表现绑定，规则层仍保留统一发射坐标，避免改变既有弹道与技能平衡

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
