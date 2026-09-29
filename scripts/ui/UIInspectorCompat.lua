-- UIInspectorCompat.lua
-- v0.12.14：修「UI Inspector requested but failed to load」。
--
-- 根因（本地已复现）：平台没有广告 SDK 时（编辑器/预览走 urhox-libs/FakeAd 模拟激励视频），
-- FakeAd 只 require UI 的 Core（urhox-libs/UI/Core/UI），而 UI.Inspector 这个字段只由聚合模块
-- urhox-libs/UI/init.lua 赋值。本作的游戏 Runtime 从不加载聚合模块（游戏 UI 全是 raw NanoVG），
-- 于是 FakeAd 第一次调用 UI.Init 时 UI.Inspector 为 nil；而预览环境（GetTapMakerEnvString()
-- == "preview"）会让 UI.Init 自动请求 F9 检查器 —— 请求落空就写一条 ERROR 日志，
-- 被平台错误上报收集成「UI Inspector requested but failed to load」。
--
-- 修法：在可能触发 UI.Init 的路径（激励视频）前把聚合模块装载一次 —— 拿到真正的检查器，
-- F9 在预览里依旧可用；万一该运行时装载失败，兜底一个空实现，保证 UI.Init / UI.Shutdown
-- 不会因为 Inspector 缺失而报错（UI.Shutdown 会直接调 UI.Inspector.Shutdown()）。
local Compat = {}

local done = false

function Compat.Ensure()
    if done then return end
    done = true
    if pcall(require, "urhox-libs/UI") then return end
    local okCore, core = pcall(require, "urhox-libs/UI/Core/UI")
    if okCore and core and not core.Inspector then
        core.Inspector = {
            Init = function() end,
            Shutdown = function() end,
        }
        print("[UIInspectorCompat] inspector module unavailable, installed no-op fallback")
    end
end

return Compat
