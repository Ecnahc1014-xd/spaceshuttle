-- AudioDirector.lua
-- 音频总控：消费 Game 的领域事件播放音效，按游戏状态切换 8bit 太空公路风格 BGM。
-- 与规则层/渲染层解耦：只读 Game.GetSnapshot() 与事件列表，不反向修改任何权威状态。
-- 所有音频资源都是**可选资源**——缺文件只静默跳过，绝不影响启动或玩法。

local AudioDirector = {}

-- 音效键 → 资源路径（assets/ 为资源根，路径从下一级写起）。
local SFX_PATHS = {
    launch      = "audio/sfx/sfx_launch.mp3",
    brick_hit   = "audio/sfx/sfx_brick_hit.mp3",
    brick_break = "audio/sfx/sfx_brick_break.mp3",
    enemy_clear = "audio/sfx/sfx_enemy_clear.mp3",
    base_hit    = "audio/sfx/sfx_base_hit.mp3",
    explode     = "audio/sfx/sfx_explode.mp3",
    crit        = "audio/sfx/sfx_crit.mp3",
    freeze      = "audio/sfx/sfx_freeze.mp3",
    pierce      = "audio/sfx/sfx_pierce.mp3",
    levelup     = "audio/sfx/sfx_levelup.mp3",
    ui_click    = "audio/sfx/sfx_ui_click.mp3",
    ui_confirm  = "audio/sfx/sfx_ui_confirm.mp3",
    coin        = "audio/sfx/sfx_coin.mp3",
    game_over   = "audio/sfx/sfx_game_over.mp3",
    boss        = "audio/sfx/sfx_boss.mp3",
    enchant     = "audio/sfx/sfx_enchant.mp3",
    heal        = "audio/sfx/sfx_heal.mp3",
    split       = "audio/sfx/sfx_split.mp3",
    wave        = "audio/sfx/sfx_wave.mp3",
    shield      = "audio/sfx/sfx_shield.mp3",
}

-- 事件类型 → 播放定义。gain 为线性音量，pitch 为倍率（内部换算成绝对 Hz），
-- throttle 为同键最小间隔（秒），防止高频事件刷屏。
local EVENT_SFX = {
    marble_launched    = { key = "launch",      gain = 0.55, pitch = { 0.94, 1.08 } },
    enemy_cleared      = { key = "enemy_clear", gain = 0.60 },
    enemy_destroyed    = { key = "explode",     gain = 0.62, pitch = { 0.96, 1.06 } },
    base_hit           = { key = "base_hit",    gain = 0.70 },
    normal_split       = { key = "split",       gain = 0.45 },
    speed_dash         = { key = "pierce",      gain = 0.34 },
    speed_pierce       = { key = "pierce",      gain = 0.42 },
    giant_pierce_armed = { key = "pierce",      gain = 0.50 },
    giant_area_hit     = { key = "explode",     gain = 0.68 },
    crit_hit           = { key = "crit",        gain = 0.55 },
    level_up           = { key = "levelup",     gain = 0.60 },
    upgrade_picked     = { key = "ui_confirm",  gain = 0.55 },
    base_revived       = { key = "heal",        gain = 0.65 },
    wave_started       = { key = "wave",        gain = 0.50 },
    boss_summoned      = { key = "boss",        gain = 0.70 },
    boss_defeated      = { key = "enemy_clear", gain = 0.75 },
    stage_cleared      = { key = "coin",        gain = 0.60 },
    game_over          = { key = "game_over",   gain = 0.70 },
    game_paused        = { key = "ui_click",    gain = 0.45 },
    game_resumed       = { key = "ui_click",    gain = 0.40 },
    item_granted       = { key = "ui_confirm",  gain = 0.50 },
    enchant_granted    = { key = "enchant",     gain = 0.55 },
    enchant_armed      = { key = "enchant",     gain = 0.45 },
    enchant_applied    = { key = "enchant",     gain = 0.55 },
    enchant_pierce     = { key = "pierce",      gain = 0.45 },
    enchant_explode    = { key = "explode",     gain = 0.65 },
    enchant_chain      = { key = "crit",        gain = 0.45 },
    enchant_triple     = { key = "split",       gain = 0.50 },
    enchant_split      = { key = "split",       gain = 0.45 },
    enchant_homing     = { key = "pierce",      gain = 0.35 },
    enchant_lifesteal  = { key = "heal",        gain = 0.45 },
}

-- 局内道具 → 音效键。
local ITEM_SFX = { bomb = "explode", freeze = "freeze", shield = "shield" }

-- 状态 → BGM 播放列表（每态多首，曲终自动轮播下一首，避免长时游玩重复单调）。
local BGM_TRACKS = {
    menu   = { "audio/bgm_menu.ogg", "audio/bgm_menu_2.ogg", "audio/bgm_menu_3.ogg" },
    battle = { "audio/bgm_battle.ogg", "audio/bgm_battle_2.ogg", "audio/bgm_battle_3.ogg" },
    boss   = { "audio/bgm_boss.ogg", "audio/bgm_boss_2.ogg", "audio/bgm_boss_3.ogg" },
}

local SFX_POOL_SIZE = 8

-- v0.13.71 防噪（音效重复）：高频事件（连续击碎/暴击/爆炸/附魔）会在同一帧或几十毫秒内
-- 反复触发同一个采样，叠加后既糊又刺耳。三道上限：
--   ① gap      —— 同键最小间隔（秒），窗口内直接丢弃；
--   ② max      —— 同键"近期并发"上限（窗口 SFX_STACK_WINDOW），超了丢弃；
--   ③ frameCap —— 每帧总播放预算，防止一帧几十个击碎同时爆。
-- 未列出的键走 DEFAULT（gap 0.05 / max 2），既有调用点不用改。
local SFX_GATE = {
    brick_hit   = { gap = 0.045, max = 2 },
    brick_break = { gap = 0.030, max = 3 },
    explode     = { gap = 0.080, max = 2 },
    enemy_clear = { gap = 0.100, max = 2 },
    crit        = { gap = 0.060, max = 2 },
    pierce      = { gap = 0.060, max = 2 },
    launch      = { gap = 0.050, max = 2 },
    base_hit    = { gap = 0.100, max = 1 },
    heal        = { gap = 0.200, max = 1 },
    shield      = { gap = 0.120, max = 1 },
    coin        = { gap = 0.050, max = 2 },
    split       = { gap = 0.060, max = 2 },
    enchant     = { gap = 0.080, max = 1 },
    levelup     = { gap = 0.200, max = 1 },
    wave        = { gap = 0.300, max = 1 },
    boss        = { gap = 0.300, max = 1 },
    game_over   = { gap = 0.500, max = 1 },
    ui_click    = { gap = 0.050, max = 1 },
    ui_confirm  = { gap = 0.060, max = 1 },
} ---@type table<string, {gap: number, max: integer}>
local SFX_GATE_DEFAULT = { gap = 0.05, max = 2 }
local SFX_FRAME_BUDGET = 5      -- 每帧最多 5 个音效
local SFX_STACK_WINDOW = 0.12   -- "近期并发"统计窗口（秒）
local SFX_DUCK = 0.72           -- 同键叠加时每次衰减，避免削波
local BGM_GAIN = 0.34
local BGM_FADE_IN = 1.1
local BGM_FADE_OUT = 0.7

-- 模块级状态（收进一张表，避免散装 local；本项目大文件有 Lua 200 顶层 local 上限的教训）。
local state = {
    ready = false,
    scene = nil,
    sfxSounds = {},     -- key → Sound|false
    sfxPool = {},       -- SoundSource[]
    sfxCursor = 1,
    throttle = {},      -- key → 上次播放时刻
    sfxGateAt = {},     -- v0.13.71 key → 上次真正播放时刻（防噪最小间隔）
    sfxStack = {},      -- v0.13.71 key → 近期并发计数
    sfxStackUntil = {}, -- v0.13.71 key → 并发窗口截止时刻
    sfxFramePlays = 0,  -- v0.13.71 本帧已播放数（每帧预算）
    sfxFrameCap = SFX_FRAME_BUDGET,
    sfxThrottled = 0,   -- v0.13.71 被最小间隔挡掉的次数
    sfxDropped = 0,     -- v0.13.71 被并发/预算挡掉的次数
    clock = 0,
    bgmPlaylist = {},   -- key → Sound[]（该态的全部曲目，缺文件已剔除）
    bgmSources = {},    -- 两条通道做交叉淡入淡出
    bgmActive = 0,      -- 当前通道索引 1/2
    bgmKey = nil,       -- 当前目标 BGM 键
    bgmTrackIdx = 1,    -- 当前播放列表内的曲目下标
    bgmTime = 0,        -- 当前曲目已播放秒数（用于曲终轮播）
    bgmTrackLen = 0,    -- 当前曲目时长（秒）
    bgmGain = {},       -- 每通道当前增益
    bgmFade = {},       -- 每通道目标增益
    bgmMixViolations = 0, -- v0.13.68：两通道同时发声的帧数（应恒为 0，用于自证不混音）
    lastState = nil,
    bossAlive = false,  -- 由 wave_started(isBoss) / boss_defeated 事件跟踪，决定是否切首领主题
    musicEnabled = true, -- 设置页开关：关则 BGM 淡出并静音（不动曲目状态，开回来可续）
    sfxEnabled = true,   -- 设置页开关：关则直接跳过所有音效播放
    sfxPlays = 0,        -- 已播放音效计数（只读诊断，供探针自证开关生效）
}

-- 创建一条音效节点（相对场景、非 3D 定位，2D 玩法全局音）。
local function MakeSource(name)
    if not state.scene then return nil end
    local node = state.scene:CreateChild(name)
    local source = node:CreateComponent("SoundSource")
    if source then source.soundType = SOUND_EFFECT end
    return source
end

local function LoadSound(path)
    local ok, sound = pcall(function()
        return cache:GetResource("Sound", path)
    end)
    if ok and sound then return sound end
    return false
end

--- 初始化：绑定场景、预加载音效、建立播放池。
---@param scene Scene
function AudioDirector.Init(scene)
    state.ready = false
    state.scene = scene
    state.sfxSounds = {}
    state.sfxPool = {}
    state.sfxCursor = 1
    state.throttle = {}
    state.sfxGateAt = {}
    state.sfxStack = {}
    state.sfxStackUntil = {}
    state.sfxFramePlays = 0
    state.sfxThrottled = 0
    state.sfxDropped = 0
    state.clock = 0
    state.bgmPlaylist = {}
    state.bgmSources = {}
    state.bgmActive = 1
    state.bgmKey = nil
    state.bgmTrackIdx = 1
    state.bgmTime = 0
    state.bgmTrackLen = 0
    state.bgmGain = { 0, 0 }
    state.bgmFade = { 0, 0 }
    state.lastState = nil
    state.sfxPlays = 0

    local loaded, total = 0, 0
    for key, path in pairs(SFX_PATHS) do
        total = total + 1
        local sound = LoadSound(path)
        state.sfxSounds[key] = sound
        if sound then loaded = loaded + 1 end
    end
    for i = 1, SFX_POOL_SIZE do
        state.sfxPool[i] = MakeSource("SfxVoice_" .. tostring(i))
    end
    local bgmLoaded = 0
    for key, paths in pairs(BGM_TRACKS) do
        local list = {}
        for _, path in ipairs(paths) do
            local sound = LoadSound(path)
            if sound then
                pcall(function() sound.looped = true end)
                list[#list + 1] = sound
                bgmLoaded = bgmLoaded + 1
            end
        end
        state.bgmPlaylist[key] = list
    end
    state.bgmSources[1] = MakeSource("BgmChannelA")
    state.bgmSources[2] = MakeSource("BgmChannelB")
    state.ready = true
    print("[AudioDirector] initialized sfx=" .. tostring(loaded) .. "/" .. tostring(total)
        .. " pool=" .. tostring(SFX_POOL_SIZE) .. " bgm=" .. tostring(bgmLoaded))
end

--- 播放一个音效键。
---@param key string
---@param gain? number
---@param pitch? number
function AudioDirector.PlaySfx(key, gain, pitch)
    if not state.ready or not state.sfxEnabled then return end
    local sound = state.sfxSounds[key]
    if not sound then return end
    local pool = state.sfxPool
    if #pool == 0 then return end

    -- ==== v0.13.71 防噪闸门：三道限制都在这里统一执行，调用点无需改动 ====
    local gate = SFX_GATE[key] or SFX_GATE_DEFAULT
    local now = state.clock
    -- ① 同键最小间隔
    local last = state.sfxGateAt[key]
    if last and now - last < gate.gap then
        state.sfxThrottled = state.sfxThrottled + 1
        return
    end
    -- ② 同键近期并发上限（窗口内累加）
    if not state.sfxStackUntil[key] or now >= state.sfxStackUntil[key] then
        state.sfxStack[key] = 0
    end
    local stack = state.sfxStack[key] or 0
    if stack >= gate.max then
        state.sfxDropped = state.sfxDropped + 1
        return
    end
    -- ③ 每帧总预算
    if state.sfxFramePlays >= state.sfxFrameCap then
        state.sfxDropped = state.sfxDropped + 1
        return
    end
    state.sfxGateAt[key] = now
    state.sfxStack[key] = stack + 1
    state.sfxStackUntil[key] = now + SFX_STACK_WINDOW
    state.sfxFramePlays = state.sfxFramePlays + 1

    local source = pool[state.sfxCursor]
    state.sfxCursor = state.sfxCursor % #pool + 1
    if not source then return end
    local freq = 0
    if pitch and pitch ~= 1 then
        local ok, base = pcall(function() return sound:GetFrequency() end)
        if ok and base then freq = base * pitch end
    end
    -- 同键叠加时按 0.72^n 衰减，避免多个同采样同相位叠成削波噪音。
    local ducked = (gain or 0.55) * (SFX_DUCK ^ math.min(stack, 4))
    pcall(function() source:Play(sound, freq, ducked) end)
    state.sfxPlays = state.sfxPlays + 1
end

--- 供 UI 直接调用的音效入口（按钮点击/确认等）。
---@param kind string
function AudioDirector.PlayUi(kind)
    if kind == "confirm" then
        AudioDirector.PlaySfx("ui_confirm", 0.55)
    else
        AudioDirector.PlaySfx("ui_click", 0.45)
    end
end

--- 设置页开关：音乐开/关（关闭时 BGM 淡出静音，曲目状态保留，开回来可续播）。
---@param enabled boolean
function AudioDirector.SetMusicEnabled(enabled)
    state.musicEnabled = enabled == true
end

--- 设置页开关：音效开/关（关闭时直接跳过所有音效播放）。
---@param enabled boolean
function AudioDirector.SetSfxEnabled(enabled)
    state.sfxEnabled = enabled == true
end

---@return boolean
function AudioDirector.IsMusicEnabled()
    return state.musicEnabled
end

---@return boolean
function AudioDirector.IsSfxEnabled()
    return state.sfxEnabled
end

-- 事件 → 音效（含砖块击中/击碎的 destroyed 分流与节流）。
local function HandleEvent(event)
    local etype = event.type
    -- 首领在场状态（用于 BGM 切换）：入场置位、被击败/逃脱清除。
    if etype == "wave_started" and event.isBoss then
        state.bossAlive = true
    elseif etype == "boss_defeated" or etype == "boss_withdrawn" or etype == "game_reset" then
        state.bossAlive = false
    end
    if etype == "brick_hit" then
        -- v0.13.71：节流统一交给 PlaySfx 的防噪闸门（避免两层 gap 叠加把节奏压太稀）。
        local key = event.destroyed and "brick_break" or "brick_hit"
        AudioDirector.PlaySfx(key, event.destroyed and 0.45 or 0.32, 0.92 + math.random() * 0.18)
        return
    end
    if etype == "item_used" then
        local key = ITEM_SFX[event.key or ""]
        if key then AudioDirector.PlaySfx(key, 0.65) end
        return
    end
    local def = EVENT_SFX[etype]
    if not def then return end
    if def.throttle then
        local last = state.throttle[def.key]
        if last and state.clock - last < def.throttle then return end
        state.throttle[def.key] = state.clock
    end
    local pitch = nil
    if def.pitch then
        pitch = def.pitch[1] + math.random() * (def.pitch[2] - def.pitch[1])
    end
    AudioDirector.PlaySfx(def.key, def.gain, pitch)
end

-- 依据游戏状态决定目标 BGM 键（菜单/战斗/首领）。
local function TargetBgm(snapshot)
    if not snapshot then return nil end
    local s = snapshot.state
    if s == "menu" then return "menu" end
    if s == "playing" or s == "levelup" or s == "paused"
        or s == "stagewin" or s == "gameover" then
        -- 首领在场时切首领主题；其余战斗态用战斗主题。
        if s == "playing" and state.bossAlive then return "boss" end
        return "battle"
    end
    return nil
end

-- 取某态播放列表内的第 idx 首（下标环绕）。
local function PlaylistTrack(key, idx)
    local list = state.bgmPlaylist[key]
    if not list or #list == 0 then return nil, 0 end
    local n = #list
    local i = ((idx - 1) % n) + 1
    return list[i], i
end

-- BGM 目标增益：关闭音乐时为 0（淡出并静音），否则回到常驻音量。
local function TargetGain()
    return state.musicEnabled and BGM_GAIN or 0
end

-- 在另一条通道上播放指定曲目并淡入，旧通道淡出（用于切状态与曲终轮播）。
-- v0.13.68 修「多轨混音」：任何时刻只允许一条通道在响——
--   ① 目标通道若正是上一首还在淡出的通道，先 Stop 再 Play（不叠尾音）；
--   ② 其余非活动通道一律清零增益，并立刻 Stop，绝不与新区并行发声。
local function StartTrack(key, idx)
    local sound, realIdx = PlaylistTrack(key, idx)
    local nextCh = state.bgmActive % 2 + 1
    local source = state.bgmSources[nextCh]
    if sound and source then
        state.bgmGain[nextCh] = 0
        state.bgmFade[nextCh] = TargetGain()
        pcall(function() source:Stop() end)
        pcall(function() source:Play(sound, 0, 0) end)
        pcall(function() source:SetGain(0) end)
        state.bgmTrackIdx = realIdx
        local okLen, len = pcall(function() return sound:GetLength() end)
        state.bgmTrackLen = (okLen and len) or 0
    else
        state.bgmTrackLen = 0
    end
    -- 旧通道：立即停声（交叉段已经由新版从 0 淡入承担，不需要两条同时响）。
    for ch = 1, 2 do
        if ch ~= nextCh then
            state.bgmFade[ch] = 0
            state.bgmGain[ch] = 0
            local other = state.bgmSources[ch]
            if other then pcall(function() other:Stop() end) end
        end
    end
    state.bgmActive = nextCh
    state.bgmKey = key
    state.bgmTime = 0
end

-- 切换 BGM 状态（换主题时从该态第一首开始）。
local function SwitchBgm(key)
    if state.bgmKey == key then return end
    StartTrack(key, 1)
end

local function UpdateBgm(dt)
    -- 曲终轮播：当前曲目放完就交叉淡入同态的下一首（bgmTrackLen 未知时保持循环、不轮播）。
    if state.bgmTrackLen > 1 and state.bgmKey then
        state.bgmTime = state.bgmTime + dt
        if state.bgmTime >= state.bgmTrackLen then
            StartTrack(state.bgmKey, state.bgmTrackIdx + 1)
        end
    end
    -- 开关切换：只同步**活动通道**的目标增益（关闭时淡出静音）。
    -- v0.13.68：旧版对两条通道都写 tgt，会把正在淡出的旧曲重新拉回满增益，
    -- 造成两首 BGM 同时响（多轨混音）。非活动通道永远保持 0 并停声。
    local tgt = TargetGain()
    if state.bgmKey then
        for ch = 1, 2 do
            if ch == state.bgmActive then
                state.bgmFade[ch] = tgt
            else
                state.bgmFade[ch] = 0
                if (state.bgmGain[ch] or 0) > 0 then
                    state.bgmGain[ch] = 0
                    local other = state.bgmSources[ch]
                    if other then pcall(function() other:Stop() end) end
                end
            end
        end
    end
    -- v0.13.68 不混音自证：任一帧出现两条通道同时有增益就算违规（正常应恒为 0）。
    if (state.bgmGain[1] or 0) > 0.01 and (state.bgmGain[2] or 0) > 0.01 then
        state.bgmMixViolations = (state.bgmMixViolations or 0) + 1
    end
    for ch = 1, 2 do
        local gain = state.bgmGain[ch] or 0
        local target = state.bgmFade[ch] or 0
        local source = state.bgmSources[ch]
        if gain ~= target and source then
            local rate = (target > gain) and (BGM_GAIN / BGM_FADE_IN) or (BGM_GAIN / BGM_FADE_OUT)
            if gain < target then
                gain = math.min(target, gain + rate * dt)
            else
                gain = math.max(target, gain - rate * dt)
            end
            state.bgmGain[ch] = gain
            pcall(function() source:SetGain(gain) end)
            if gain <= 0.001 and target <= 0.001 then
                pcall(function() source:Stop() end)
            end
        end
    end
end

--- 每帧更新：消费事件、按状态切换 BGM、推进淡入淡出。
---@param dt number
---@param snapshot table|nil
---@param events table[]|nil
function AudioDirector.Update(dt, snapshot, events)
    if not state.ready then return end
    state.clock = state.clock + dt
    state.sfxFramePlays = 0 -- v0.13.71：每帧音效预算从 0 起算
    if events then
        for i = 1, #events do
            local ev = events[i]
            if type(ev) == "table" then HandleEvent(ev) end
        end
    end
    if snapshot and snapshot.state ~= state.lastState then
        state.lastState = snapshot.state
    end
    SwitchBgm(TargetBgm(snapshot))
    UpdateBgm(dt)
end

--- 释放：停止所有音源、清空引用（场景由调用方销毁）。
function AudioDirector.Shutdown()
    state.ready = false
    for _, source in pairs(state.sfxPool) do
        if source then pcall(function() source:Stop() end) end
    end
    for _, source in pairs(state.bgmSources) do
        if source then pcall(function() source:Stop() end) end
    end
    state.sfxPool = {}
    state.bgmSources = {}
    state.sfxSounds = {}
    state.bgmPlaylist = {}
    state.scene = nil
    print("[AudioDirector] shutdown")
end

--- 只读诊断：返回当前 BGM 键与是否就绪，供探针自证数据通路。
--- v0.13.68：含 bgmMixViolations（两通道同时发声帧数，正常恒 0）。
---@return string|nil, boolean
function AudioDirector.DebugState()
    return state.bgmKey, state.ready
end

--- v0.13.68：不混音自证（两通道同时有增益的帧数，正常恒 0）。
---@return integer
function AudioDirector.DebugMixViolations()
    return state.bgmMixViolations or 0
end

--- v0.13.71：防噪统计（played 真正播放 / throttled 被最小间隔挡 / dropped 被并发或帧预算挡）。
---@return table
function AudioDirector.DebugSfxStats()
    return {
        played = state.sfxPlays or 0,
        throttled = state.sfxThrottled or 0,
        dropped = state.sfxDropped or 0,
        frameCap = state.sfxFrameCap or 0,
        framePlays = state.sfxFramePlays or 0,
    }
end

--- 只读诊断：返回某态播放列表的曲目数（供探针断言轮播池）。
---@param key string
---@return integer
function AudioDirector.DebugTrackCount(key)
    local list = state.bgmPlaylist[key]
    return list and #list or 0
end

--- 只读诊断：返回音乐/音效开关状态（供探针断言设置页开关真的生效）。
---@return boolean, boolean
function AudioDirector.DebugEnabled()
    return state.musicEnabled, state.sfxEnabled
end

--- 只读诊断：返回已播放音效计数（供探针断言「关音效后不再新增」）。
---@return integer
function AudioDirector.DebugSfxPlays()
    return state.sfxPlays
end

return AudioDirector
