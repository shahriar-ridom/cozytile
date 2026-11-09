#!/usr/bin/env bash
# Restore the install that ./install.sh moved aside (state in ~/.local/state/cozytile/last-backup).
set -euo pipefail
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/cozytile"
[ -f "$STATE/last-backup" ] || { echo "no backup recorded"; exit 1; }
BK=$(cat "$STATE/last-backup")
[ -d "$BK" ] || { echo "backup $BK is gone"; exit 1; }
if [ -e "$CFG/cozytile" ]; then mv "$CFG/cozytile" "$CFG/cozytile.replaced-$(date +%Y%m%d-%H%M%S)"; fi
mv "$BK" "$CFG/cozytile"
rm -f "$STATE/last-backup"
echo "restored $BK -> $CFG/cozytile (the version you rolled back from is kept as cozytile.replaced-*)"
