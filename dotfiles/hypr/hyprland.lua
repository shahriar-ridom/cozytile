-- =============================================================================
-- Hyprland (Lua config) - Cozytile
-- =============================================================================

require("config.monitor")
require("config.env")
require("config.input")
require("config.appearance")
require("config.animations")
require("config.workspaces")
require("config.rules")
require("config.startup")
require("config.binds")
require("config.look")                 -- theme-driven look, loaded after the above so it wins

pcall(require, "config.local")         -- per-machine overrides (monitor, GPU); optional
