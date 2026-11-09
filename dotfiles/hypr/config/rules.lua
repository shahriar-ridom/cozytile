-- =============================================================================
-- Rules
-- Hyprland 0.56.1
-- =============================================================================

------------------------------------------------------------
-- Layer Rules (Cozytile shell)
------------------------------------------------------------
-- Namespaces come from WlrLayershell.namespace in the QML: bar, island, launcher, power, wallpaper, audio.

hl.layer_rule({
	name = "cozytile-blur",
	match = { namespace = "^cozytile-(bar|island|launcher|power|wallpaper|audio)$" },
	blur = true,
	ignore_alpha = 0.2,
})

hl.layer_rule({
	name = "cozytile-popups",
	match = { namespace = "^cozytile-(launcher|power|wallpaper|audio)$" },
	dim_around = true,
	animation = "popin 90%",
})

------------------------------------------------------------
-- Floating Terminal
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
	opacity = "0.85 0.80",
})

------------------------------------------------------------
-- Kitty
------------------------------------------------------------

hl.window_rule({
	name = "kitty-opacity",

	match = {
		class = "^kitty$",
	},

	opacity = "0.75 0.70",
})

------------------------------------------------------------
-- LibreWolf
------------------------------------------------------------

hl.window_rule({
	name = "librewolf-opacity",

	match = {
		class = "^[Ll]ibre[Ww]olf$",
	},

	opacity = "0.95 0.88",
})

hl.window_rule({
	name = "zen-opacity",

	match = {
		class = "zen$",
	},

	opacity = "0.80 0.72",
})

------------------------------------------------------------
-- VSCode
------------------------------------------------------------

hl.window_rule({
	name = "code-opacity",

	match = {
		class = "^code$",
	},

	opacity = "0.90 0.82",
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
	opacity = "0.82 0.75",
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
