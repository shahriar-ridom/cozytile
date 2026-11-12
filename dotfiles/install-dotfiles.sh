#!/usr/bin/env bash
# Cozytile dotfiles installer. Copies templates into ~/.config/cozytile, renders the theme, and (with --link)
# links the Hyprland / kitty / zsh / GTK / Qt configs from this repo into place. Anything replaced is backed up.
#
#   ./install-dotfiles.sh [--theme everforest|sakura] [--dry-run] [--link] [--hook-gtk] [--sddm]
set -euo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
DEST="$CFG/cozytile"
THEME=$(python3 -c "import json,os;print(json.load(open(os.path.expanduser('~/.local/state/cozytile/settings.json'))).get('theme','everforest'))" 2>/dev/null || echo everforest)
DRY=0; LINK=0; GTK=0; SDDM=0
while [ $# -gt 0 ]; do case $1 in
  --theme) THEME=$2; shift;; --dry-run) DRY=1;; --link) LINK=1;; --hook-gtk) GTK=1;; --sddm) SDDM=1;;
  -h|--help) sed -n 2,6p "$0"; exit 0;; *) echo "unknown $1" >&2; exit 2;; esac; shift; done
TS=$(date +%Y%m%d-%H%M%S)
run() { if [ $DRY = 1 ]; then echo "[dry-run] $*"; else "$@"; fi; }
ok() { printf '  \033[32mok\033[0m %s\n' "$*"; }

echo "== Copying theme files to $DEST"
run mkdir -p "$DEST/zsh" "$DEST/sddm" "$DEST/templates" "$DEST/config"
run cp "$SRC"/zsh/cozytile.zsh "$DEST/zsh/"
run cp -r "$SRC"/sddm/Cozytile "$DEST/sddm/"
run cp "$SRC"/templates/* "$DEST/templates/"
run cp "$SRC"/render.py "$SRC"/theme-apply.sh "$DEST/"
run cp "$SRC/../config/palettes.json" "$DEST/config/palettes.json"
ok "files copied"

echo "== Rendering theme '$THEME'"
if [ $DRY = 1 ]; then echo "[dry-run] render $THEME"; else python3 "$SRC/render.py" "$THEME" >/dev/null && ok "generated: $DEST/generated"; fi

# link <repo-path> <target>: symlink target -> repo path; an existing different file/dir/link is moved aside first
link() {
  local src=$1 dst=$2
  if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then ok "already linked $dst"; return; fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then run mv "$dst" "$dst.bak-$TS"; ok "moved $dst -> $dst.bak-$TS"; fi
  run mkdir -p "$(dirname "$dst")"; run ln -s "$src" "$dst"; ok "linked $dst -> $src"
}
append_once() { # file line
  local f; f=$(readlink -f "$1" 2>/dev/null || echo "$1")
  [ -f "$f" ] || { run mkdir -p "$(dirname "$f")"; run touch "$f"; }
  grep -qsF "$2" "$f" && { ok "already in $f"; return; }
  run cp -a "$f" "$f.bak-$TS"; if [ $DRY = 1 ]; then echo "[dry-run] append to $f: $2"; else printf '\n%s\n' "$2" >> "$f"; fi; ok "updated $f (backup alongside)"
}

if [ $LINK = 1 ]; then
  echo "== Linking configs from $SRC"
  link "$SRC/hypr" "$CFG/hypr"
  run mkdir -p "$CFG/kitty"
  [ -L "$CFG/kitty" ] && run mv "$CFG/kitty" "$CFG/kitty.bak-$TS" && run mkdir -p "$CFG/kitty"
  link "$SRC/kitty/kitty.conf" "$CFG/kitty/kitty.conf"
  link "$SRC/zsh/zshrc" "$HOME/.zshrc"
  link "$SRC/gtk/settings.ini" "$CFG/gtk-3.0/settings.ini"
  link "$SRC/gtk/settings.ini" "$CFG/gtk-4.0/settings.ini"
  # qt6ct needs the absolute palette path, so it is rendered rather than linked
  run mkdir -p "$CFG/qt6ct"
  if [ $DRY = 1 ]; then echo "[dry-run] render qt6ct.conf"; else
    [ -f "$CFG/qt6ct/qt6ct.conf" ] && cp -a "$CFG/qt6ct/qt6ct.conf" "$CFG/qt6ct/qt6ct.conf.bak-$TS"
    sed "s#@HOME@#$HOME#g" "$SRC/qt6ct/qt6ct.conf.in" > "$CFG/qt6ct/qt6ct.conf"; ok "rendered qt6ct.conf"
  fi
  run mkdir -p "$CFG/btop/themes"
  run ln -sf "$DEST/generated/btop/cozytile.theme" "$CFG/btop/themes/cozytile.theme"
  [ -e "$SRC/hypr/config/local.lua" ] || run cp "$SRC/hypr/config/local.example.lua" "$SRC/hypr/config/local.lua"
fi

if [ $GTK = 1 ]; then
  for v in 3.0 4.0; do append_once "$CFG/gtk-$v/gtk.css" "@import url(\"file://$DEST/generated/gtk/colors.css\");"; done
  # GTK4 only: makes GTK4 windows ask for compositor blur while Frosted glass is on (see the template)
  append_once "$CFG/gtk-4.0/gtk.css" "@import url(\"file://$DEST/generated/gtk/gtk4-frost.css\");"
fi

if [ $SDDM = 1 ]; then
  echo "== SDDM (needs root)"
  cmds="mkdir -p /usr/share/sddm/themes && cp -r '$DEST/sddm/Cozytile' /usr/share/sddm/themes/ && cp '$DEST/generated/sddm/theme.conf' /usr/share/sddm/themes/Cozytile/theme.conf && mkdir -p /etc/sddm.conf.d && printf '[Theme]\nCurrent=Cozytile\n' > /etc/sddm.conf.d/cozytile.conf"
  if [ $DRY = 1 ]; then echo "[dry-run] sudo sh -c \"$cmds\""; else sudo sh -c "$cmds" && ok "SDDM theme installed"; fi
fi

cat <<EOT

== Done. Switch themes any time:  $DEST/theme-apply.sh sakura   (or Super+Shift+T)
EOT
