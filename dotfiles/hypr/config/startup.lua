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

	-- launch.sh starts qs with transparent huge pages off (~80 MB less RAM); plain qs if it is missing
	local launch = cfg .. "/quickshell/cozytile/scripts/launch.sh"
	local l = io.open(launch, "r")
	if l then l:close(); hl.exec_cmd("sh " .. launch) else hl.exec_cmd("qs -c cozytile") end

	--------------------------------------------------------------------------
	-- Applications
	--------------------------------------------------------------------------

	hl.exec_cmd("thunar --daemon")


	--------------------------------------------------------------------------
	-- GTK Fonts
	--------------------------------------------------------------------------

	-- fonts chosen in Settings > Appearance are rendered to generated/gtk/fonts.sh; fall back to the defaults
	hl.exec_cmd("sh -c 'f=\"$HOME/.config/cozytile/generated/gtk/fonts.sh\"; if [ -f \"$f\" ]; then sh \"$f\"; else gsettings set org.gnome.desktop.interface font-name \"SF Pro Text 11\"; gsettings set org.gnome.desktop.interface document-font-name \"SF Pro Text 11\"; fi'")

end)
