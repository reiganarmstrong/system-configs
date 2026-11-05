-- A minimal set of bindings to get around; the full scheme comes later.
local programs = require("nix").programs
local super = "SUPER"

local function shell(...)
    return hl.dsp.exec_cmd(programs.shell .. " ipc call " .. table.concat({ ... }, " "))
end

hl.bind(super .. " + T", hl.dsp.exec_cmd(programs.terminal))
hl.bind(super .. " + Space", shell("launcher", "toggle"))
hl.bind(super .. " + S", shell("control", "toggle"))
hl.bind(super .. " + L", shell("lock", "lock"))
hl.bind(super .. " + Q", hl.dsp.window.close())
hl.bind(super .. " + F", hl.dsp.window.fullscreen())
hl.bind(super .. " + V", hl.dsp.window.float({ action = "toggle" }))

for _, dir in ipairs({ "left", "right", "up", "down" }) do
    hl.bind(super .. " + " .. dir, hl.dsp.focus({ direction = dir }))
    hl.bind(super .. " + SHIFT + " .. dir, hl.dsp.window.move({ direction = dir }))
end

for i = 1, 10 do
    local key = i % 10
    hl.bind(super .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(super .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(super .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(super .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Hardware keys go through the shell so it can show its on-screen display.
local held = { locked = true, repeating = true }
hl.bind("XF86AudioRaiseVolume", shell("osd", "volume", "up"), held)
hl.bind("XF86AudioLowerVolume", shell("osd", "volume", "down"), held)
hl.bind("XF86AudioMute", shell("osd", "volume", "mute"), { locked = true })
hl.bind("XF86MonBrightnessUp", shell("osd", "brightness", "up"), held)
hl.bind("XF86MonBrightnessDown", shell("osd", "brightness", "down"), held)
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
