-- =============================================================================
-- Frosted glass: window translucency. NOT loaded by hyprland.lua. The shell (Settings > Appearance >
-- Frosted glass) loads it through the generated cozytile_settings.lua and, when you switch it on, with
-- `hyprctl eval`. With the setting off no window is translucent. The compositor blur comes from look.lua.
-- Panels in the shell, kitty (generated/kitty/colors.conf) and GTK/Qt colours use the same ~0.78 alpha, so
-- apps (own alpha x the rule below, about 0.6) and shell panels match.
-- =============================================================================

-- every window except fullscreen ones (games, video); specific rules below are loaded later and win
hl.window_rule({ name = "frost-all", match = { class = ".*", fullscreen = false }, opacity = "0.75 0.70" })

hl.window_rule({ name = "frost-floating-terminal", match = { class = "^kitty-floating$" }, opacity = "0.85 0.80" })
hl.window_rule({ name = "frost-kitty",    match = { class = "^kitty$" },            opacity = "0.75 0.70" })
hl.window_rule({ name = "frost-librewolf", match = { class = "^[Ll]ibre[Ww]olf$" }, opacity = "0.95 0.88" })
hl.window_rule({ name = "frost-zen",      match = { class = "zen$" },               opacity = "0.80 0.72" })
hl.window_rule({ name = "frost-code",     match = { class = "^code$" },             opacity = "0.90 0.82" })
hl.window_rule({ name = "frost-luma",     match = { class = "[Ll]uma$" },              opacity = "0.82 0.75" })
