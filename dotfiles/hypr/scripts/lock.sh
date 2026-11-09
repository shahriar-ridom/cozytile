#!/usr/bin/env bash
# Lock the screen with the themed hyprlock config; fall back to the stock one so the session never stays unlocked.
pgrep -x hyprlock >/dev/null && exit 0
conf="${XDG_CONFIG_HOME:-$HOME/.config}/cozytile/generated/hypr/hyprlock.conf"
[ -f "$conf" ] && exec hyprlock -c "$conf"
exec hyprlock
