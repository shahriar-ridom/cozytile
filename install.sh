#!/usr/bin/env bash
# Cozytile (Quickshell) installer. Safe by default: backs up anything it would replace.
#   ./install.sh [--dry-run] [--prefix DIR]
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/cozytile"
DEST="$CFG/cozytile"
DRY=0
while [ $# -gt 0 ]; do
  case $1 in --dry-run) DRY=1;; --prefix) CFG=$2; DEST="$CFG/cozytile"; shift;; -h|--help) sed -n 2,3p "$0"; exit 0;; *) echo "unknown arg $1" >&2; exit 2;; esac
  shift
done
run() { if [ $DRY = 1 ]; then echo "[dry-run] $*"; else "$@"; fi; }
ok() { printf '  \033[32mok\033[0m   %s\n' "$*"; }
warn() { printf '  \033[33mmiss\033[0m %s\n' "$*"; }
die() { printf '  \033[31mfail\033[0m %s\n' "$*" >&2; exit 1; }

echo "== Checking requirements"
command -v qs >/dev/null 2>&1 || command -v quickshell >/dev/null 2>&1 || die "quickshell not installed (pacman -S quickshell)"
ok "quickshell $(quickshell --version 2>/dev/null | head -1)"
command -v Hyprland >/dev/null 2>&1 || command -v hyprctl >/dev/null 2>&1 || die "Hyprland not installed"
ok "hyprland"
QML=/usr/lib/qt6/qml/Quickshell
for m in Hyprland Services/Pipewire Services/Mpris Services/Notifications Services/SystemTray Services/UPower Networking Io Wayland; do
  [ -d "$QML/$m" ] && ok "quickshell module $m" || die "quickshell module $m missing (quickshell build too old / built without it)"
done

echo "== Optional tools (features degrade gracefully without them)"
opt() { command -v "$1" >/dev/null 2>&1 && ok "$1  - $2" || warn "$1  - $2"; }
opt awww "wallpapers (or swww / hyprpaper / swaybg)"
opt matugen "wallpaper-derived theme"
opt hyprlock "lock action (falls back to loginctl lock-session)"
opt brightnessctl "brightness OSD (laptops)"
opt playerctl "media keys"
fonts=$(fc-list : family 2>/dev/null || true)
case "$fonts" in *"CaskaydiaCove Nerd Font"*) ok "CaskaydiaCove Nerd Font";; *) warn "CaskaydiaCove Nerd Font - icons/text (set Theme.font in config/Theme.qml)";; esac


echo "== Notification daemon check"
if command -v busctl >/dev/null && busctl --user list 2>/dev/null | grep -q "org.freedesktop.Notifications"; then
  owner=$(busctl --user status org.freedesktop.Notifications 2>/dev/null | sed -n 's/^Comm=//p' | head -1)
  warn "org.freedesktop.Notifications is already owned by '${owner:-another daemon}'. Stop it before running Cozytile or its notifications will not appear."
fi

echo "== Installing to $DEST"
if [ -e "$DEST" ] || [ -L "$DEST" ]; then
  TS=$(date +%Y%m%d-%H%M%S)
  BK="$CFG/cozytile.bak-$TS"
  run mv "$DEST" "$BK"
  run mkdir -p "$STATE"
  [ $DRY = 1 ] || echo "$BK" > "$STATE/last-backup"
  ok "existing install moved to $BK (restore with ./rollback.sh)"
fi
run mkdir -p "$CFG"
if [ $DRY = 1 ]; then echo "[dry-run] copy $SRC -> $DEST"; else
  mkdir -p "$DEST"
  ( cd "$SRC" && tar cf - --exclude='.git' --exclude='*.bak-*' . ) | ( cd "$DEST" && tar xf - )
  chmod +x "$DEST"/scripts/*.sh
fi
ok "installed"

cat <<EOT

== Done. Nothing in your Hyprland config was touched.

Launch (test):       qs -c cozytile
Keybinds:            see dotfiles/hypr/config/binds.lua (installed by setup.sh)
Enable at login:     started by dotfiles/hypr/config/startup.lua
Roll back:           $DEST/rollback.sh
Uninstall:           $DEST/uninstall.sh
EOT
