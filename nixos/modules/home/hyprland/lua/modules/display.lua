-- Outputs. The host's display settings come from Nix. When they name the
-- built-in output, any other monitor plugged in gets its preferred mode,
-- placed to the right; an empty name already matches every output.
local display = require("nix").display

hl.monitor({
    output   = display.output,
    mode     = display.mode,
    position = "auto",
    scale    = display.scale,
})

if display.output ~= "" then
    hl.monitor({
        output   = "",
        mode     = "preferred",
        position = "auto-right",
        scale    = "auto",
    })
end
