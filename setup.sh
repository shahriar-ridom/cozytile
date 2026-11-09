#!/usr/bin/env bash
# One-shot setup for the whole Cozytile desktop.
#   ./setup.sh [--dry-run] [--packages] [--sddm] [--theme everforest|sakura]
# 1. (--packages) installs packages.txt with pacman/paru   2. installs the Quickshell shell
# 3. renders the theme and links hypr/kitty/zsh/gtk/qt6ct from this repo (existing files are backed up)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY=0; PKG=0; EXTRA=()
for a in "$@"; do case $a in --dry-run) DRY=1;; --packages) PKG=1;; *) EXTRA+=("$a");; esac; done
[ $DRY = 1 ] && EXTRA+=(--dry-run)

if [ $PKG = 1 ]; then
  off=(); aur=(); sec=off
  while read -r l; do case $l in "# [official]") sec=off;; "# [aur]") sec=aur;; "#"*|"") ;; *) [ $sec = off ] && off+=("$l") || aur+=("$l");; esac; done < "$HERE/packages.txt"
  helper=$(command -v paru || command -v yay || true)
  if [ $DRY = 1 ]; then echo "[dry-run] sudo pacman -S --needed ${off[*]}"; echo "[dry-run] ${helper:-<aur helper>} -S --needed ${aur[*]}"
  else sudo pacman -S --needed "${off[@]}"; [ -n "$helper" ] && "$helper" -S --needed "${aur[@]}" || echo "no AUR helper: install manually: ${aur[*]}"; fi
fi

if [ $DRY = 1 ]; then "$HERE/install.sh" --dry-run; else "$HERE/install.sh"; fi
"$HERE/dotfiles/install-dotfiles.sh" --link --hook-gtk "${EXTRA[@]}"
echo; echo "Log out and back in (or run: hyprctl reload && qs -c cozytile) to use the new desktop."
