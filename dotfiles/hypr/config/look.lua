-- =============================================================================
-- Cozytile look: even gaps, borderless, rounded, soft shadow, blur. Colours come from the palette
-- rendered by theme-apply.sh (~/.config/cozytile/generated/hypr/cozytile_colors.lua).
-- =============================================================================

local home = os.getenv("HOME")
package.path = home .. "/.config/cozytile/generated/hypr/?.lua;" .. package.path
local ok, C = pcall(require, "cozytile_colors")
if not ok then
	-- generated file missing: run dotfiles/theme-apply.sh everforest
	C = { active_border = "rgb(a7c080)", inactive_border = "rgb(374145)", shadow = "rgba(232a2eb3)" }
end

hl.config({
	general = {
		gaps_in = 5,
		gaps_out = 9,          -- Cozytile uses an even 9px margin
		border_size = 0,       -- Cozytile windows are borderless; focus is shown by opacity
		col = {
			active_border = C.active_border,
			inactive_border = C.inactive_border,
		},
	},

	decoration = {
		rounding = 10,
		rounding_power = 2,
		active_opacity = 1.0,
		inactive_opacity = 0.94,

		shadow = {
			enabled = true,
			range = 18,
			render_power = 3,
			color = C.shadow,
		},

		blur = {
			enabled = true,
			size = 6,
			passes = 2,
			vibrancy = 0.15,
		},
	},
})

-- Ignore client "maximize" requests (kitty asks for it when a tile gets too small, which made new
-- terminals jump to a full-screen layout instead of tiling). Same as Hyprland's stock config rule.
hl.window_rule({
	name = "cozytile-suppress-maximize",
	match = { class = ".*" },
	suppress_event = "maximize",
})
