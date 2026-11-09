#!/usr/bin/env bash
# Remove Cozytile. Config/state removal is opt-in:  ./uninstall.sh [--purge]
set -euo pipefail
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/cozytile"
if pgrep -f "qs -c cozytile" >/dev/null; then pkill -f "^qs -c cozytile" || true; echo "stopped running shell"; fi
[ -e "$CFG/cozytile" ] && { rm -rf "$CFG/cozytile"; echo "removed $CFG/cozytile"; } || echo "not installed"
if [ "${1:-}" = "--purge" ]; then rm -rf "$STATE"; echo "removed settings ($STATE)"; else echo "kept settings/backups: $STATE and $CFG/cozytile.bak-* (use --purge for settings)"; fi
echo "Dotfile symlinks (~/.config/hypr, kitty, ~/.zshrc, gtk) are untouched; restore the *.bak-<timestamp> copies next to them to go back."
