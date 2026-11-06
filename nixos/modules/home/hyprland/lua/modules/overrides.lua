-- User choices from Settings override the reproducible Nix defaults.
local state = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
local path = state .. "/system-configs/settings.lua"
local file = io.open(path, "r")
if file then
    file:close()
    dofile(path)
end
