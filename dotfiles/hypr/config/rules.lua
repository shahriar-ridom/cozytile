-- =============================================================================
-- Rules
-- Hyprland 0.56.1
-- =============================================================================

------------------------------------------------------------
-- Layer Rules (Cozytile shell)
------------------------------------------------------------
-- Namespaces come from WlrLayershell.namespace in the QML. Every shell surface that draws a panel is listed
-- (the desktop clock is not: it sits under windows). Blur is invisible while panels are opaque and is what
-- Settings > Appearance > Frosted glass relies on once they turn translucent. ignore_alpha 0.4 keeps soft
-- shadows (alpha <= 0.38) and fully clear areas out of the blur.

hl.layer_rule({
	name = "cozytile-blur",
	match = { namespace = "^cozytile-(bar|island|launcher|power|wallpaper|audio|logomenu|globalmenu|stats|settings|osd|search|notifications|notification-center)$" },
	blur = true,
	blur_popups = true,
	ignore_alpha = 0.4,
})

hl.layer_rule({
	name = "cozytile-popups",
	match = { namespace = "^cozytile-(launcher|power|wallpaper|audio)$" },
	dim_around = true,
	animation = "popin 90%",
})

------------------------------------------------------------
-- Floating Terminal (window opacity is part of Frosted glass: config/frost.lua)
------------------------------------------------------------

hl.window_rule({
	name = "floating-terminal",

	match = {
		-- Kitty uses --class as the Wayland app-id.
		class = "^kitty-floating$",
	},

	float = true,
	center = true,
	size = "1100 700",
})

------------------------------------------------------------
-- Luma file Manager
------------------------------------------------------------

hl.window_rule({
	name = "luma",

	match = {
		class = "luma$",
	},

	float = true,
	center = true,
	size = "1260 730",
})

------------------------------------------------------------
-- File Operation Progress
------------------------------------------------------------

hl.window_rule({
	name = "file-progress",

	match = {
		title = "^File Operation Progress$",
	},

	float = true,
	center = true,
})

------------------------------------------------------------
-- Skyrim
------------------------------------------------------------

hl.window_rule({
	name = "skyrim",

	match = {
		class = "^Skyrim$",
	},

	float = true,
	border_size = 0,
	immediate = true,
})
