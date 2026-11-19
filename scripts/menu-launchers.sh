#!/usr/bin/env bash
# Global menu, native Wayland: apps run natively and scripts/globalmenu.py finds their menus on the session bus
# (Qt apps export one at /MenuBar/N without registering it; nothing to set up for them).
# Firefox-family browsers only export a menu on Wayland with two prefs, which this writes into a marked block of
# every LibreWolf / Zen / Firefox profile's user.js. Restart the browser afterwards.
# It also deletes the XWayland launcher overrides that earlier versions of this script wrote.
#
#   menu-launchers.sh            set up
#   menu-launchers.sh --remove   take the prefs out again
set -euo pipefail
DEST="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
MARK="# cozytile-global-menu"
BEGIN="// cozytile-global-menu begin"
END="// cozytile-global-menu end"

for f in "$DEST"/*.desktop; do
  if grep -qsF "$MARK" "$f"; then rm "$f"; echo "removed $f"; fi
done
command -v update-desktop-database >/dev/null && update-desktop-database "$DEST" 2>/dev/null || true

for prof in "$HOME"/.config/librewolf/librewolf/*/ "$HOME"/.librewolf/*/ "$HOME"/.config/zen/*/ "$HOME"/.zen/*/ \
            "$HOME"/.mozilla/firefox/*/; do
  [ -f "$prof/prefs.js" ] || continue
  js="${prof%/}/user.js"
  [ -f "$js" ] && sed -i "\|^$BEGIN\$|,\|^$END\$|d" "$js"
  if [ "${1:-}" = "--remove" ]; then echo "cleared $js"; continue; fi
  printf '%s\nuser_pref("widget.gtk.global-menu.enabled", true);\nuser_pref("widget.gtk.global-menu.wayland.enabled", true);\n%s\n' \
    "$BEGIN" "$END" >> "$js"
  echo "wrote $js"
done
