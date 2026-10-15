-- Lightweight runtime performance probe for low-end Android试玩。
-- 默认只做定时采样，不创建 UI，不分配每帧临时表；日志可直接从 Maker 控制台收集。

local Probe = {}
local enabled_ = true
local reportInterval_ = 5.0
local reportClock_ = 0
local frameCount_ = 0
local totalDt_ = 0
local maxDt_ = 0
local hitchCount_ = 0
local phaseTotal_ = {}
local phaseMax_ = {}
local phaseStart_ = {}
local phaseCount_ = {}
local frameStart_ = 0
local provider_ = nil
local session_ = 0

local function Now() return os.clock() end
local function SafeCall(fn)
    if not fn then return nil end
    local ok, value = pcall(fn)
    if ok then return value end
    return nil
end
local function ResetWindow()
    frameCount_, totalDt_, maxDt_, hitchCount_ = 0, 0, 0, 0
    phaseTotal_, phaseMax_, phaseStart_, phaseCount_ = {}, {}, {}, {}
end

function Probe.Start(opts)
    opts = opts or {}
    enabled_ = opts.enabled ~= false
    reportInterval_ = math.max(1.0, tonumber(opts.reportInterval) or 5.0)
    reportClock_, session_ = 0, session_ + 1
    ResetWindow()
    print(string.format("[PerfProbe] start session=%d report=%.1fs", session_, reportInterval_))
end
function Probe.Stop()
    if enabled_ then Probe.Report("stop") end
    enabled_, provider_ = false, nil
end
function Probe.SetEnabled(value) enabled_ = value == true end
function Probe.IsEnabled() return enabled_ end
function Probe.SetProvider(fn) provider_ = fn end
function Probe.BeginFrame(dt)
    if not enabled_ then return end
    frameStart_ = Now()
    frameCount_ = frameCount_ + 1
    local value = math.max(0, tonumber(dt) or 0)
    totalDt_ = totalDt_ + value
    if value > maxDt_ then maxDt_ = value end
    if value >= 0.05 then hitchCount_ = hitchCount_ + 1 end
end
function Probe.BeginPhase(name)
    if enabled_ then phaseStart_[name] = Now() end
end
function Probe.EndPhase(name)
    if not enabled_ then return end
    local started = phaseStart_[name]
    if not started then return end
    phaseStart_[name] = nil
    local elapsed = Now() - started
    phaseTotal_[name] = (phaseTotal_[name] or 0) + elapsed
    phaseCount_[name] = (phaseCount_[name] or 0) + 1
    if elapsed > (phaseMax_[name] or 0) then phaseMax_[name] = elapsed end
end
local function BuildExtras()
    local extras = SafeCall(provider_)
    if type(extras) ~= "table" then return "" end
    local parts = {}
    for key, value in pairs(extras) do
        if type(value) == "number" or type(value) == "string" or type(value) == "boolean" then
            parts[#parts + 1] = tostring(key) .. "=" .. tostring(value)
        end
    end
    table.sort(parts)
    return #parts > 0 and (" " .. table.concat(parts, " ")) or ""
end
function Probe.Report(reason)
    if not enabled_ or frameCount_ == 0 then return end
    local fps = totalDt_ > 0 and frameCount_ / totalDt_ or 0
    local avgMs = frameCount_ > 0 and totalDt_ / frameCount_ * 1000 or 0
    local parts = {}
    for name, total in pairs(phaseTotal_) do
        local count = phaseCount_[name] or 1
        parts[#parts + 1] = string.format("%s_avg=%.2fms %s_max=%.2fms", name, total / count * 1000, name, (phaseMax_[name] or 0) * 1000)
    end
    table.sort(parts)
    local memoryKb = SafeCall(function() return collectgarbage("count") end)
    print(string.format("[PerfProbe] reason=%s frames=%d fps=%.1f avg=%.2fms max=%.2fms hitches=%d lua_kb=%.0f %s%s", tostring(reason), frameCount_, fps, avgMs, maxDt_ * 1000, hitchCount_, tonumber(memoryKb) or 0, table.concat(parts, " "), BuildExtras()))
    ResetWindow()
end
function Probe.EndFrame(dt)
    if not enabled_ then return end
    local elapsed = Now() - frameStart_
    reportClock_ = reportClock_ + math.max(0, tonumber(dt) or 0)
    if reportClock_ >= reportInterval_ then reportClock_ = 0; Probe.Report("interval") end
    if elapsed >= 0.05 then print(string.format("[PerfProbe] hitch frame_ms=%.2f", elapsed * 1000)) end
end
return Probe
