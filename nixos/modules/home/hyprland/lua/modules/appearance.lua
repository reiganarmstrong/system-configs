-- Window styling: squircle corners, a clear white rim on the focused window
-- (a faint one elsewhere), deep soft shadows and
-- heavy blur behind translucent surfaces.
local theme = require("nix").theme
local rgba = require("modules.util").rgba

hl.config({
    general = {
        gaps_in = theme.spacing.gapsIn,
        gaps_out = theme.spacing.gapsOut,
        border_size = 2,
        col = {
            active_border = rgba(theme.colors.accent, theme.opacity.activeBorder),
            inactive_border = rgba(theme.colors.accent, theme.opacity.inactiveBorder),
        },
        resize_on_border = true,
        extend_border_grab_area = 12,
        layout = "dwindle",
    },

    decoration = {
        rounding = theme.radius.window,
        rounding_power = 2.4,

        shadow = {
            enabled = true,
            range = theme.shadow.range,
            render_power = 3,
            offset = "0 " .. theme.shadow.offsetY,
            color = rgba("#000000", theme.shadow.opacity),
            color_inactive = rgba("#000000", theme.shadow.inactiveOpacity),
        },

        blur = {
            enabled = true,
            size = theme.blur.size,
            passes = theme.blur.passes,
            vibrancy = theme.blur.vibrancy,
            noise = 0.01,
            popups = true,
            special = true,
            new_optimizations = true,
        },
    },

    dwindle = {
        preserve_split = true,
    },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        background_color = rgba(theme.colors.background, 1),
        focus_on_activate = true,
        -- Lets a restarted shell take over the session lock if it crashed.
        allow_session_lock_restore = true,
        vrr = 2,
    },
})
