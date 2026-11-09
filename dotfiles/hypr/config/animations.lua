-- =============================================================================
-- Animations
-- Smooth • macOS-inspired springs (fine-tuned)
-- Hyprland 0.56.1 Lua Config
-- =============================================================================

------------------------------------------------------------
-- Curves (Springs & Beziers)
------------------------------------------------------------

-- Global / Layers: controlled physical spring (macOS-style baseline)
hl.curve("macSpring", {
	type = "spring",
	mass = 1,
	stiffness = 220,
	dampening = 26,
})

-- App Windows: quick response with a single, restrained settle.
hl.curve("appBounce", {
	type = "spring",
	mass = 1,
	stiffness = 250,
	dampening = 27,
})

-- Workspaces: slightly slower so switching feels deliberate.
hl.curve("workspaceSpring", {
	type = "spring",
	mass = 1,
	stiffness = 205,
	dampening = 25,
})

-- Beziers for fades and borders (springs don't work well for opacity)
hl.curve("smoothOut", {
	type = "bezier",
	points = {
		{ 0.25, 1.00 },
		{ 0.50, 1.00 },
	},
})

hl.curve("fastOut", {
	type = "bezier",
	points = {
		{ 0.16, 1.00 },
		{ 0.30, 1.00 },
	},
})

------------------------------------------------------------
-- Enable
------------------------------------------------------------

hl.config({
	animations = {
		enabled = true,
	},
})

------------------------------------------------------------
-- Global
------------------------------------------------------------

hl.animation({
	leaf = "global",
	enabled = true,
	speed = 4.5,
	spring = "macSpring",
})

------------------------------------------------------------
-- Border
------------------------------------------------------------

hl.animation({
	leaf = "border",
	enabled = true,
	speed = 4.5,
	bezier = "smoothOut",
})

------------------------------------------------------------
-- Windows
------------------------------------------------------------

hl.animation({
	leaf = "windows",
	enabled = true,
	speed = 4.5,
	spring = "appBounce",
	style = "popin 75%",
})

hl.animation({
	leaf = "windowsIn",
	enabled = true,
	speed = 5,
	spring = "appBounce",
	style = "popin 75%",
})

hl.animation({
	leaf = "windowsOut",
	enabled = true,
	speed = 3,
	bezier = "fastOut",
	style = "popin 92%",
})

hl.animation({
	leaf = "windowsMove",
	enabled = true,
	speed = 4.8,
	spring = "macSpring",
	style = "slide",
})

------------------------------------------------------------
-- Fade
------------------------------------------------------------

hl.animation({
	leaf = "fade",
	enabled = true,
	speed = 3,
	bezier = "smoothOut",
})

hl.animation({
	leaf = "fadeIn",
	enabled = true,
	speed = 3,
	bezier = "smoothOut",
})

hl.animation({
	leaf = "fadeOut",
	enabled = true,
	speed = 2.5,
	bezier = "fastOut",
})

------------------------------------------------------------
-- Layers (Cozytile bar, island, launcher and menus)
------------------------------------------------------------

hl.animation({
	leaf = "layers",
	enabled = true,
	speed = 4.5,
	spring = "macSpring",
})

hl.animation({
	leaf = "layersIn",
	enabled = true,
	speed = 4.5,
	spring = "macSpring",
	style = "slide",
})

hl.animation({
	leaf = "layersOut",
	enabled = true,
	speed = 3,
	bezier = "fastOut",
	style = "slide",
})

------------------------------------------------------------
-- Workspaces
------------------------------------------------------------

hl.animation({
	leaf = "workspaces",
	enabled = true,
	speed = 5,
	spring = "workspaceSpring",
	style = "slidefade 20%",
})

hl.animation({
	leaf = "workspacesIn",
	enabled = true,
	speed = 5,
	spring = "workspaceSpring",
	style = "slidefade 20%",
})

hl.animation({
	leaf = "workspacesOut",
	enabled = true,
	speed = 5,
	spring = "workspaceSpring",
	style = "slidefade 20%",
})
