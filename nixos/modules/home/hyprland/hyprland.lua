-- Native scrolling with the shared Quickshell desktop.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = @SCALE@ })
hl.env("TERMINAL", "@TERMINAL@")
hl.env("QS_ICON_THEME", "@ICONS@")
hl.env("XCURSOR_THEME", "@CURSOR@")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("NIXOS_OZONE_WL", "1")
hl.env("TZDIR", "/etc/zoneinfo")
-- Hyprland's own options live here, as text. HyprMod can override any of
-- them on the fly; its file loads last (see the end of this file).
hl.config({
    general = {
        layout = "scrolling", gaps_in = 8, gaps_out = 24, border_size = 1,
        col = { active_border = "rgba(f6f5f4ff)", inactive_border = "rgba(ffffff22)" },
    },
    scrolling = { column_width = 1.0, focus_fit_method = 1, fullscreen_on_one_column = false, explicit_column_widths = "0.5,0.66667,1.0" },
    decoration = { rounding = 14, blur = { enabled = true, size = 5, passes = 3 } },
    misc = { disable_hyprland_logo = true, force_default_wallpaper = 0 },
    -- The pointer stays visible while typing and hides after 5 s untouched.
    cursor = { hide_on_key_press = false, inactive_timeout = 5 },
    -- Tabbed columns are Hyprland groups, styled to match the bar and menus.
    group = {
        col = {
            border_active = "rgba(f6f5f4ff)", border_inactive = "rgba(ffffff22)",
            border_locked_active = "rgba(f6f5f4ff)", border_locked_inactive = "rgba(ffffff22)",
        },
        groupbar = {
            font_family = "Inter", font_size = 12, font_weight_active = "semibold", font_weight_inactive = "normal",
            height = 24, indicator_height = 0, gradients = true, gradient_rounding = 8,
            gaps_in = 6, gaps_out = 0, keep_upper_gap = true, blur = true,
            text_color = "rgba(f6f5f4ff)", text_color_inactive = "rgba(ffffff8c)",
            col = {
                active = "rgba(ffffff2e)", inactive = "rgba(ffffff0f)",
                locked_active = "rgba(ffffff2e)", locked_inactive = "rgba(ffffff0f)",
            },
        },
    },
    input = {
        kb_layout = "us", repeat_rate = 25, repeat_delay = 600,
        follow_mouse = 1,
        touchpad = { natural_scroll = true, tap_to_click = true, disable_while_typing = true, clickfinger_behavior = true },
    },
})
hl.animation({ leaf = "global", enabled = true, speed = 5, bezier = "default" })
hl.window_rule({ name = "settings", match = { class = "org.quickshell", title = "Settings" }, float = true, size = "960 680", center = true })
hl.window_rule({ name = "file-dialogs", match = { title = "^(Open File|Open Folder|Save As|Save File|Choose Files?|Select a File)$" }, float = true })
hl.layer_rule({ name = "shell-glass", match = { namespace = "^shell-.*" }, blur = true, ignore_alpha = 0.01 })

-- Settings adds the cursor size and the monitors you confirmed there.
local settings = io.open("@SETTINGS@", "r")
if settings then settings:close(); dofile("@SETTINGS@") end

hl.on("hyprland.start", function()
    hl.exec_cmd("qs")
end)
hl.gesture({ fingers = 3, direction = "horizontal", action = "scroll_move" })
hl.gesture({ fingers = 3, direction = "vertical", action = "workspace" })
local function run(key, command, flags) hl.bind(key, hl.dsp.exec_cmd(command), flags or {}) end
run("SUPER + T", "@TERMINAL@")
run("SUPER + E", "nautilus")
run("SUPER + D", "qs ipc call launcher toggle")
run("SUPER + Space", "qs ipc call launcher toggle")
run("SUPER + comma", "qs ipc call settings toggle")
run("SUPER + S", "qs ipc call control toggle")
run("SUPER + H", "hyprmod")
run("SUPER + SHIFT + V", "qs ipc call clipboard toggle")
run("SUPER + ALT + L", "qs ipc call lock lock")
run("SUPER + L", "qs ipc call lock lock")
run("SUPER + SHIFT + P", "sleep 0.3; desktop-compositor power-off")
run("CTRL + ALT + Delete", "desktop-compositor quit")
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + F", hl.dsp.window.fullscreen())
hl.bind("SUPER + SHIFT + Space", hl.dsp.window.float({ action = "toggle" }))
hl.bind("SUPER + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind("SUPER + R", hl.dsp.layout("colresize +conf"))
hl.bind("SUPER + C", hl.dsp.layout("center"))
-- Like niri: a window that shares its column leaves it for a new column on
-- that side; a window alone in its column joins the neighbouring one.
hl.bind("SUPER + bracketleft", hl.dsp.layout("consume_or_expel prev"))
hl.bind("SUPER + bracketright", hl.dsp.layout("consume_or_expel next"))

-- Tabbed columns, like niri's Super+W. Hyprland shows them as a group with a
-- tab bar. Turning tabs off stacks the windows back into one column.
local function same_window(a, b) return a.address == b.address end
local function toggle_tabbed_column()
    local active = hl.get_active_window()
    if not active or active.floating then return end
    if active.group then
        local others = {}
        for _, w in ipairs(active.group.members) do
            if not same_window(w, active) then table.insert(others, w.address) end
        end
        hl.dispatch(hl.dsp.group.toggle())
        -- Ungrouping gives each window its own column, on either side.
        -- Move them back into the original column, nearest first.
        local function find(address) return hl.get_window("address:" .. address) end
        local home = find(active.address)
        local function distance(address) return math.abs(find(address).at.x - home.at.x) end
        table.sort(others, function(a, b) return distance(a) < distance(b) end)
        for _, address in ipairs(others) do
            local w = find(address)
            hl.dispatch(hl.dsp.focus({ window = w }))
            hl.dispatch(hl.dsp.layout(w.at.x < home.at.x and "consume_or_expel next" or "consume_or_expel prev"))
            home = find(active.address)
        end
        hl.dispatch(hl.dsp.focus({ window = home }))
        return
    end
    -- Gather the rest of the column into a new group, nearest first.
    local above, below = {}, {}
    for _, w in ipairs(hl.get_workspace_windows(active.workspace)) do
        if not same_window(w, active) and not w.floating and w.at.x == active.at.x then
            table.insert(w.at.y < active.at.y and above or below, w)
        end
    end
    table.sort(below, function(a, b) return a.at.y < b.at.y end)
    table.sort(above, function(a, b) return a.at.y > b.at.y end)
    hl.dispatch(hl.dsp.group.toggle())
    for _, w in ipairs(below) do hl.dispatch(hl.dsp.window.move({ into_group = "up", window = w })) end
    for _, w in ipairs(above) do hl.dispatch(hl.dsp.window.move({ into_group = "down", window = w })) end
    hl.dispatch(hl.dsp.focus({ window = active }))
end
hl.bind("SUPER + W", toggle_tabbed_column)

-- In a tabbed column, up and down switch tabs (with Shift, reorder them).
local function in_tabs()
    local active = hl.get_active_window()
    return active ~= nil and active.group ~= nil and active.group.size > 1
end
local tab_keys = {
    up = { focus = hl.dsp.group.prev(), move = hl.dsp.group.move_window({ forward = false }) },
    down = { focus = hl.dsp.group.next(), move = hl.dsp.group.move_window({ forward = true }) },
}
for _, direction in ipairs({"left", "right", "up", "down"}) do
    local focus = hl.dsp.focus({ direction = direction })
    local move = hl.dsp.window.move({ direction = direction })
    local tabs = tab_keys[direction]
    hl.bind("SUPER + " .. direction, tabs and function() hl.dispatch(in_tabs() and tabs.focus or focus) end or focus)
    hl.bind("SUPER + SHIFT + " .. direction, tabs and function() hl.dispatch(in_tabs() and tabs.move or move) end or move)
    hl.bind("SUPER + CTRL + " .. direction, hl.dsp.focus({ monitor = direction }))
end
for i = 1, 10 do
    hl.bind("SUPER + " .. (i % 10), hl.dsp.focus({ workspace = i }))
    hl.bind("SUPER + SHIFT + " .. (i % 10), hl.dsp.window.move({ workspace = i }))
end
hl.bind("SUPER + Page_Down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("SUPER + Page_Up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })
for key, command in pairs({
    XF86AudioRaiseVolume = "qs ipc call osd volume up", XF86AudioLowerVolume = "qs ipc call osd volume down",
    XF86AudioMute = "qs ipc call osd volume mute", XF86AudioMicMute = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle",
    XF86MonBrightnessUp = "qs ipc call osd brightness up", XF86MonBrightnessDown = "qs ipc call osd brightness down",
    XF86AudioPlay = "playerctl play-pause", XF86AudioPause = "playerctl play-pause",
    XF86AudioNext = "playerctl next", XF86AudioPrev = "playerctl previous",
}) do run(key, command, { locked = true, repeating = true }) end
run("Print", "desktop-compositor screenshot region")
run("CTRL + Print", "desktop-compositor screenshot screen")
run("ALT + Print", "desktop-compositor screenshot window")

-- HyprMod owns this ordinary user file, for overrides on the fly. It starts
-- empty and its edits survive Nix rebuilds; move keepers into this file.
-- require() also lets Hyprland watch it for automatic reloads.
local overrides = io.open("@HYPRMOD@", "r")
if overrides then overrides:close(); require("hyprland-gui") end
