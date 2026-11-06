-- Window and layer rules.

hl.window_rule({
    name = "ignore-maximize-requests",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name = "no-idle-while-fullscreen",
    match = { class = ".*" },
    idle_inhibit = "fullscreen",
})

hl.window_rule({
    name = "float-file-dialogs",
    match = { title = "^(Open File|Open Folder|Save As|Save File|Choose Files?|Select a File).*" },
    float = true,
    center = true,
})

-- The shell animates its own surfaces; Hyprland only blurs behind them.
hl.layer_rule({
    name = "shell-no-animation",
    match = { namespace = "^shell-.*" },
    no_anim = true,
})
hl.layer_rule({
    name = "shell-blur",
    match = { namespace = "^shell-(bar|dock|control|dash|launcher|clipboard|notifications|osd)$" },
    blur = true,
    ignore_alpha = 0.3,
})
hl.layer_rule({
    name = "shell-lock-blur",
    match = { namespace = "^shell-lock$" },
    blur = true,
    ignore_alpha = 0.05,
})

-- Settings is a normal movable window, with no full-screen popup surface.
hl.window_rule({
    name = "desktop-settings",
    match = { title = "^Settings$", class = "^org.quickshell$" },
    float = true,
    center = true,
    size = "960 680",
})
