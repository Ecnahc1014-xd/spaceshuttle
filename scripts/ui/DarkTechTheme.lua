-- ui/DarkTechTheme.lua
-- 把项目的 dark-tech / Ecnach 令牌映射成 urhox-libs/UI 主题。
--
-- 目的：大厅等「组件路线」界面与游戏的 NanoVG 界面共用同一套视觉，
-- 不出现「联机界面是另一套风格」的割裂。
-- 令牌来源与 Scene3DBackend 的 C 表一致；改色时两处一起改。

local Theme = require("urhox-libs/UI/Core/Theme")

-- 与 Scene3DBackend.C 同源的 dark-tech 色板
local T = {
    bg      = {7, 11, 20, 255},
    panel   = {10, 16, 28, 255},
    rail    = {12, 20, 34, 255},
    card    = {16, 26, 44, 255},
    widget  = {22, 36, 56, 255},
    cyan    = {0, 229, 208, 255},
    cyanDim = {0, 150, 148, 255},
    ink     = {4, 8, 16, 255},
    text    = {240, 248, 252, 255},
    dim     = {120, 148, 162, 255},
    warn    = {255, 196, 72, 255},
    error   = {232, 76, 76, 255},
    border  = {30, 58, 78, 255},
    borderStrong = {44, 78, 100, 255},
}

return Theme.ExtendTheme(Theme.defaultTheme, {
    colors = {
        -- 酸青是唯一主强调色：焦点 / 激活 / 主操作 / 进度
        primary         = T.cyan,
        primaryHover    = {60, 245, 226, 255},
        primaryPressed  = {0, 178, 162, 255},
        primaryDeep     = {0, 120, 116, 255},
        primarySoft     = T.cyanDim,
        primaryShadow   = {0, 120, 116, 255},

        -- 中性控件：深海军层级（panel < rail < card < widget）
        secondary        = T.widget,
        secondaryHover   = {32, 50, 74, 255},
        secondaryPressed = {18, 30, 48, 255},
        secondaryDeep    = T.rail,
        secondaryShadow  = T.rail,

        -- 背景分层（不用纯黑，不用厚阴影）
        background     = T.bg,
        surface        = T.panel,
        surfaceAlt     = T.rail,
        surfaceRaised  = T.card,
        surfaceTooltip = T.widget,

        text            = T.text,
        textSecondary   = {178, 196, 206, 255},
        textMuted       = T.dim,
        textPlaceholder = {140, 166, 178, 255},
        textInverse     = T.ink,

        border        = T.border,
        borderStrong  = T.borderStrong,
        borderFocus   = T.cyan,
        borderTooltip = T.border,
        divider       = T.border,

        disabled       = {48, 62, 82, 255},
        disabledBorder = {62, 80, 100, 255},
        disabledText   = {96, 116, 130, 255},

        -- 成功＝绿色（与游戏内「看广告」语义同色系，但此处仅表示成功态）
        success        = {46, 232, 107, 255},
        successHover   = {72, 245, 128, 255},
        successPressed = {28, 168, 78, 255},
        successShadow  = {28, 168, 78, 255},

        warning        = T.warn,
        warningPressed = {186, 140, 48, 255},
        error          = T.error,
        errorHover     = {255, 108, 108, 255},
        errorPressed   = {178, 56, 56, 255},
        errorShadow    = {178, 56, 56, 255},
        danger         = T.error,
        dangerHover    = {255, 108, 108, 255},
        dangerPressed  = {178, 56, 56, 255},

        overlay = {7, 11, 20, 214},

        infoSoft    = {14, 40, 54, 255},
        successSoft = {14, 40, 34, 255},
        warningSoft = {44, 38, 20, 255},
        dangerSoft  = {44, 26, 30, 255},
    },
    -- 小圆角、细描边（不要药丸，不要直角像素块）
    radius = {
        xs = 2,
        sm = 4,
        md = 6,
        lg = 8,
        xl = 10,
        pill = 10,
    },
})
