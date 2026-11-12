-- =============================================================================
-- Keybindings
-- =============================================================================

local Mod = "SUPER"

-- Every shell action is an IPC call into the Cozytile Quickshell instance.
local qs = "qs -c cozytile ipc call "

--------------------------------------------------------------------------------
-- Applications & Shell Menus
--------------------------------------------------------------------------------

-- Give the tiled terminal an explicit Wayland app-id.  Kitty's --class option
-- is the app-id on Wayland, which makes the launch mode unambiguous.
hl.bind(Mod .. " + Return", hl.dsp.exec_cmd("kitty --class kitty"))

hl.bind(Mod .. " + SHIFT + Return", hl.dsp.exec_cmd("kitty --class kitty-floating"))

hl.bind(Mod .. " + B", hl.dsp.exec_cmd("env MOZ_ENABLE_WAYLAND=0 GDK_BACKEND=x11 zen-browser"))

hl.bind(Mod .. " + E", hl.dsp.exec_cmd("luma"))

hl.bind(Mod .. " + N", hl.dsp.exec_cmd("kitty -e nvim"))

hl.bind(Mod .. " + C", hl.dsp.exec_cmd("code"))

-- Launcher (apps, calc, emoji, 'clip ' history)
hl.bind(Mod .. " + D", hl.dsp.exec_cmd(qs .. "launcher toggle"))

-- Island: notifications / media / quick actions
hl.bind(Mod .. " + A", hl.dsp.exec_cmd(qs .. "notifications toggle"))

--------------------------------------------------------------------------------
-- Scratchpads
--------------------------------------------------------------------------------

hl.bind(Mod .. " + Grave", hl.dsp.workspace.toggle_special("scratchpad"))

hl.bind(Mod .. " + O", hl.dsp.workspace.toggle_special("obsidian"))

--------------------------------------------------------------------------------
-- Window Management & Layout
--------------------------------------------------------------------------------

-- Close active window
hl.bind(Mod .. " + Q", hl.dsp.window.close())

-- Toggle Floating
hl.bind(Mod .. " + V", function()
	local win = hl.get_active_window()

	if win then
		local was_tiled = not win.floating

		-- Toggle floating
		hl.dispatch(hl.dsp.window.float({
			action = "toggle",
		}))

		-- Only resize + center when entering floating mode
		if was_tiled then
			hl.dispatch(hl.dsp.window.resize({
				x = 1180,
				y = 720,
				relative = false,
			}))

			hl.dispatch(hl.dsp.window.center())
		end
	end
end)

-- Center active floating window
hl.bind(Mod .. " + CTRL + C", hl.dsp.exec_cmd("hyprctl dispatch centerwindow"))

-- 1. True Fullscreen (Covers entire screen & bar)
hl.bind(
	Mod .. " + F",
	hl.dsp.window.fullscreen({
		mode = "fullscreen",
		action = "toggle",
	})
)

-- 2. Maximize / Fit to screen (Keeps bar & gaps)
hl.bind(
	Mod .. " + SHIFT + F",
	hl.dsp.window.fullscreen({
		mode = "maximized",
		action = "toggle",
	})
)

-- Layout controls
hl.bind(Mod .. " + P", hl.dsp.window.pseudo())

hl.bind(Mod .. " + S", hl.dsp.layout("togglesplit"))

hl.bind(Mod .. " + M", hl.dsp.layout("swapwithmaster"))

--------------------------------------------------------------------------------
-- Focus (Vim-style)
--------------------------------------------------------------------------------

hl.bind(Mod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(Mod .. " + J", hl.dsp.focus({ direction = "down" }))
hl.bind(Mod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(Mod .. " + L", hl.dsp.focus({ direction = "right" }))

--------------------------------------------------------------------------------
-- Move Windows
--------------------------------------------------------------------------------

hl.bind(Mod .. " + SHIFT + H", hl.dsp.window.move({ direction = "l" }))
hl.bind(Mod .. " + SHIFT + J", hl.dsp.window.move({ direction = "d" }))
hl.bind(Mod .. " + SHIFT + K", hl.dsp.window.move({ direction = "u" }))
hl.bind(Mod .. " + SHIFT + L", hl.dsp.window.move({ direction = "r" }))

--------------------------------------------------------------------------------
-- Mouse Controls
--------------------------------------------------------------------------------

hl.bind(Mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(Mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind(Mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { mouse = true })
hl.bind(Mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }), { mouse = true })

--------------------------------------------------------------------------------
-- Workspaces (1 - 10)
--------------------------------------------------------------------------------

for i = 1, 10 do
	local key = i % 10

	hl.bind(Mod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind(Mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------
-- Stage: Mission Control style overview (workspaces are the desktops)
--------------------------------------------------------------------------------

-- global shortcut (registered by the shell): no process to spawn, so it opens at once
hl.bind(Mod .. " + TAB", hl.dsp.global("cozytile:overview"))
hl.bind(Mod .. " + ALT + S", hl.dsp.global("cozytile:overview"))
hl.bind(Mod .. " + CTRL + TAB", hl.dsp.exec_cmd(qs .. "stage next"))
hl.bind(Mod .. " + CTRL + SHIFT + TAB", hl.dsp.exec_cmd(qs .. "stage prev"))

-----
-- Audio & Brightness (the island shows the feedback)
--------------------------------------------------------------------------------

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(qs .. "audio up"), { locked = true, repeating = true })

hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(qs .. "audio down"), { locked = true, repeating = true })

hl.bind("XF86AudioMute", hl.dsp.exec_cmd(qs .. "audio mute"), { locked = true })

hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(qs .. "brightness up"), { locked = true, repeating = true })

hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(qs .. "brightness down"), { locked = true, repeating = true })

--------------------------------------------------------------------------------
-- Media Controls
--------------------------------------------------------------------------------

hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

--------------------------------------------------------------------------------
-- Screenshots
--------------------------------------------------------------------------------

hl.bind(Mod .. " + SHIFT + S", hl.dsp.exec_cmd("hyprshot -m region -o ~/Pictures/Screenshots"))

hl.bind(Mod .. " + CTRL + S", hl.dsp.exec_cmd("hyprshot -m output -o ~/Pictures/Screenshots"))

hl.bind(Mod .. " + SHIFT + W", hl.dsp.exec_cmd("hyprshot -m window -o ~/Pictures/Screenshots"))

--------------------------------------------------------------------------------
-- Lock Screen & Session
--------------------------------------------------------------------------------

hl.bind(Mod .. " + CTRL + L", hl.dsp.exec_cmd("~/.config/hypr/scripts/lock.sh"))

hl.bind(Mod .. " + X", hl.dsp.exec_cmd(qs .. "power toggle"))

--------------------------------------------------------------------------------
-- Hyprland & Shell Controls
--------------------------------------------------------------------------------

hl.bind(Mod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))

hl.bind(Mod .. " + SHIFT + E", hl.dsp.exit())

--------------------------------------------------------------------------------
-- Wallpaper & Theming
--------------------------------------------------------------------------------

hl.bind(Mod .. " + CTRL + O", hl.dsp.exec_cmd(qs .. "wallpaper toggle"))

--------------------------------------------------------------------------------
-- Optional utilities
--------------------------------------------------------------------------------

hl.bind(Mod .. " + SHIFT + G", hl.dsp.exec_cmd("~/.config/hypr/scripts/gemini-brain.sh"))

--------------------------------------------------------------------------------
-- Cozytile extras
--------------------------------------------------------------------------------
hl.bind(Mod .. " + SHIFT + T", hl.dsp.exec_cmd(qs .. "theme next"))
hl.bind(Mod .. " + SHIFT + N", hl.dsp.exec_cmd(qs .. "notifications toggle"))
hl.bind(Mod .. " + SPACE", hl.dsp.exec_cmd(qs .. "launcher toggle"))
hl.bind(Mod .. " + SHIFT + I", hl.dsp.exec_cmd(qs .. "island toggle"))

-- Lock-key hints in the island (non-consuming: the key still works).
-- On release the CAPS / MOD2 modifier is already set when the lock turns ON, hence the second bind.
hl.bind("Caps_Lock", hl.dsp.exec_cmd(qs .. "keys refresh"), { release = true, non_consuming = true })
hl.bind("CAPS + Caps_Lock", hl.dsp.exec_cmd(qs .. "keys refresh"), { release = true, non_consuming = true })
hl.bind("Num_Lock", hl.dsp.exec_cmd(qs .. "keys refresh"), { release = true, non_consuming = true })
hl.bind("MOD2 + Num_Lock", hl.dsp.exec_cmd(qs .. "keys refresh"), { release = true, non_consuming = true })
hl.bind("Scroll_Lock", hl.dsp.exec_cmd(qs .. "keys refresh"), { release = true, non_consuming = true })
