-- Programs started with the session.
local programs = require("nix").programs

hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd --all && systemctl --user start hyprland-session.target")
    hl.exec_cmd("hyprctl setcursor " .. programs.cursor .. " 24")
    hl.exec_cmd(programs.shell)
end)
