-- =============================================================================
-- Startup
-- Hyprland 0.56.1
-- =============================================================================

hl.on("hyprland.start", function()
	--------------------------------------------------------------------------
	-- Core Services
	--------------------------------------------------------------------------

	hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")

	hl.exec_cmd("fcitx5 -d")

	hl.exec_cmd("nm-applet --indicator")
	-- idle timeouts from the settings app (Power & idle), else the stock hypridle.conf
	local cfg = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
	local idle = cfg .. "/cozytile/generated/hypr/hypridle.conf"
	local f = io.open(idle, "r")
	if f then f:close(); hl.exec_cmd("hypridle -c " .. idle) else hl.exec_cmd("hypridle") end

	-- Clipboard history for the launcher ("clip " in Super+D); text and images.
	hl.exec_cmd("wl-paste --type text --watch cliphist store")
	hl.exec_cmd("wl-paste --type image --watch cliphist store")

	--------------------------------------------------------------------------
	-- UI
	--------------------------------------------------------------------------

	hl.exec_cmd("qs -c cozytile")

	--------------------------------------------------------------------------
	-- Applications
	--------------------------------------------------------------------------

	hl.exec_cmd("thunar --daemon")


	--------------------------------------------------------------------------
	-- GTK Fonts
	--------------------------------------------------------------------------

	hl.exec_cmd("gsettings set org.gnome.desktop.interface font-name 'SF Pro Text 11'")

	hl.exec_cmd("gsettings set org.gnome.desktop.interface document-font-name 'SF Pro Text 11'")

end)
