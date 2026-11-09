-- =============================================================================
-- Appearance: layout, cursor, misc. The visual look (gaps, borders, rounding, shadow, blur,
-- opacity, colours) is config/look.lua, generated from the active theme palette.
-- =============================================================================

hl.config({
	general = {
		layout = "dwindle",
		resize_on_border = false,
		allow_tearing = false,
	},

	cursor = {
		no_warps = true,
	},

	dwindle = {
		preserve_split = true,
	},

	misc = {
		disable_hyprland_logo = true,
		disable_splash_rendering = true,
		force_default_wallpaper = 0,
	},
})
