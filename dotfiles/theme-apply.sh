#!/usr/bin/env bash
# theme-apply.sh <everforest|sakura|wallpaper> [--dotfiles-only] [--no-reload] [--fonts]
# Renders every generated dotfile for the theme, then live-reloads whatever is hooked up.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
theme=${1:?usage: theme-apply.sh <theme> [--dotfiles-only] [--no-reload]}; shift || true
only=0; reload=1; fonts=0
for a in "$@"; do case $a in --dotfiles-only) only=1;; --no-reload) reload=0;; --fonts) fonts=1;; esac; done

CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/cozytile"
GEN="$CFG/cozytile/generated"

# current wallpaper (all-monitors entry, else first) for lock screen / login background
wall=$(python3 - "$STATE/settings.json" <<'P' 2>/dev/null
import json,sys
try:
    w=json.load(open(sys.argv[1])).get("wallpapers",{})
    print(w.get("*") or next(iter(w.values()), ""))
except Exception: print("")
P
)
args=(); [ -n "$wall" ] && args+=(--wallpaper "$wall")
python3 "$HERE/render.py" "$theme" "${args[@]}" >/dev/null || exit 1
echo "rendered $theme -> $GEN"

[ $fonts = 1 ] && [ -f "$GEN/gtk/fonts.sh" ] && sh "$GEN/gtk/fonts.sh" >/dev/null 2>&1 && echo "applied GTK fonts"

hooked() { grep -rqs "cozytile/generated" "$1" 2>/dev/null; }   # only touch apps the user wired up

if [ $reload = 1 ]; then
  if hooked "$CFG/kitty/kitty.conf"; then pkill -USR1 -x kitty && echo "reloaded kitty"; fi
  if hooked "$CFG/hypr/"; then hyprctl reload >/dev/null 2>&1 && echo "reloaded hyprland"; fi
  pkill -USR2 -x cava 2>/dev/null && echo "reloaded cava"
fi

if [ $only = 0 ]; then
  if qs -c cozytile ipc call theme set "$theme" >/dev/null 2>&1; then echo "shell updated"
  else
    python3 - "$STATE/settings.json" "$theme" <<'P'
import json,sys,os
p,t=sys.argv[1:3]
d=json.load(open(p)) if os.path.exists(p) else {}
d["theme"]=t; os.makedirs(os.path.dirname(p),exist_ok=True); json.dump(d,open(p,"w"),indent=2)
P
    echo "shell not running; saved theme for next start"
  fi
fi
