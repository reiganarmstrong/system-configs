-- Helpers shared by the modules.
local M = {}

-- "#rrggbb" and an opacity from 0 to 1 -> Hyprland's "rgba(rrggbbaa)".
function M.rgba(hex, alpha)
    local a = math.floor((alpha or 1) * 255 + 0.5)
    return string.format("rgba(%s%02x)", hex:gsub("^#", ""), a)
end

return M
