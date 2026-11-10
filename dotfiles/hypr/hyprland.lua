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

-- Settings app (display, windows, input, autostart): written by the Cozytile shell to
-- ~/.config/cozytile/generated/hypr/cozytile_settings.lua. Loaded last so it wins; optional.
do
	local cfg = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
	local gen = cfg .. "/cozytile/generated/hypr/"
	if not package.path:find(gen, 1, true) then package.path = gen .. "?.lua;" .. package.path end
	local ok, err = pcall(require, "cozytile_settings")
	if not ok and not tostring(err):find("not found", 1, true) then print("cozytile_settings: " .. tostring(err)) end
end
