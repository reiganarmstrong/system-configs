-- Entry point. Each file under ./modules handles one concern; values that
-- come from the Nix theme are in nix.lua, generated at build time.

require("modules.display")
require("modules.environment")
require("modules.appearance")
require("modules.animations")
require("modules.input")
require("modules.keybindings")
require("modules.rules")
require("modules.autostart")

require("modules.overrides")
