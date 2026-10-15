# 低配安卓试玩性能探测体系

## 已接入

scripts/PerformanceProbe.lua 在客户端启动时启用，挂在 game.client_main 的 Update 循环中。它不创建 UI，不扫描场景，不在每帧创建报告表，适合试玩包长期运行。

每 5 秒通过 Maker 控制台输出一条 [PerfProbe]：

- fps、avg、max：窗口平均帧率、平均帧耗时、最大帧耗时
- hitches：帧耗时达到 50ms 的次数（低于 20 FPS）
- game_avg/max：核心玩法更新耗时
- presentation_avg/max：表现层和音频前的状态更新耗时
- render_avg/max：3D 场景同步和渲染数据准备耗时
- lua_kb：Lua GC 统计的当前内存
- state/wave/enemies/screen/dpr：运行上下文

## 低配安卓判定线

| 指标 | 目标 | 需要处理 |
|---|---:|---:|
| 窗口 FPS | ≥ 30 | < 25 持续两个窗口 |
| 平均帧耗时 | ≤ 33ms | > 40ms |
| 单帧最大耗时 | ≤ 80ms | > 120ms 或频繁出现 |
| render_max | ≤ 25ms | > 40ms |
| Lua 内存 | 稳定 | 连续窗口上涨且不回落 |

## 排查顺序

1. 先比较 game、presentation、render 三段，定位 CPU 热点。
2. 若 render 占比高，检查 3D 节点、材质、阴影、粒子和重复几何重建。
3. 若 game 占比高，检查敌人数量、碰撞/弹道循环和每帧表分配。
4. 若 lua_kb 持续上涨，检查事件回调、临时表和缓存生命周期。
5. 只在复现稳定后改动；每次改动后重新收集至少两个 5 秒窗口。

## 运行方式

在本地 Maker 控制台启动试玩后，复制包含 [PerfProbe] 的日志即可形成基线。探测器默认开启；需要关闭时可在 ClientMain.Start 中传入 enabled = false，不影响玩法逻辑。
