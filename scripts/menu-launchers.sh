#!/usr/bin/env bash
# Global menu: Hyprland cannot export menus from native-Wayland windows, so apps that should show
# their menus in the bar run through XWayland. This writes launcher overrides to
# ~/.local/share/applications for Dolphin, LibreWolf and Zen only; every other app stays native.
#
#   menu-launchers.sh            install
#   menu-launchers.sh --remove   delete the overrides again
# Apps launched from a terminal or a keybind (not the launcher/desktop entry) need the same variables:
#   Qt:       QT_QPA_PLATFORM=xcb QT_QPA_PLATFORMTHEME=gtk3 dolphin
#   Firefox:  MOZ_ENABLE_WAYLAND=0 GDK_BACKEND=x11 zen-browser   (and widget.gtk.global-menu.enabled = true)
set -euo pipefail
SYS=/usr/share/applications
DEST="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
QT="QT_QPA_PLATFORM=xcb QT_QPA_PLATFORMTHEME=gtk3"
FX="MOZ_ENABLE_WAYLAND=0 GDK_BACKEND=x11"
MARK="# cozytile-global-menu"
APPS=("org.kde.dolphin:$QT" "librewolf:$FX" "zen:$FX")
# GTK apps need the appmenu-gtk-module package (sudo pacman -S appmenu-gtk-module); skipped without it
GTK="GTK_MODULES=appmenu-gtk-module GDK_BACKEND=x11"
if ls /usr/lib/gtk-3.0/modules/libappmenu-gtk3-module.so /usr/lib/gtk-3.0/modules/libappmenu-gtk-module.so >/dev/null 2>&1; then
  APPS+=("thunar:$GTK" "gimp:$GTK" "org.gimp.GIMP:$GTK")
fi

for a in "${APPS[@]}"; do
  id=${a%%:*}; vars=${a#*:}
  src="$SYS/$id.desktop"; dst="$DEST/$id.desktop"
  if [ "${1:-}" = "--remove" ]; then
    if grep -qsF "$MARK" "$dst"; then rm "$dst"; echo "removed $dst"; fi
    continue
  fi
  [ -f "$src" ] || { echo "skip $id (not installed)"; continue; }
  if [ -f "$dst" ] && ! grep -qsF "$MARK" "$dst"; then echo "skip $id ($dst is your own override)"; continue; fi
  mkdir -p "$DEST"
  { echo "$MARK"; sed "s|^Exec=|Exec=env $vars |" "$src"; } > "$dst"
  echo "wrote $dst"
done
command -v update-desktop-database >/dev/null && update-desktop-database "$DEST" 2>/dev/null || true
