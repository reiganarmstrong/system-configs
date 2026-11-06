-- Environment for applications started by Hyprland.
local programs = require("nix").programs

hl.env("TERMINAL", programs.terminal)
hl.env("XCURSOR_THEME", programs.cursor)
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", programs.cursor)
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QS_ICON_THEME", programs.icons)
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("NIXOS_OZONE_WL", "1")
