#!/usr/bin/env bash
# Icon packs, system-wide: GTK (gsettings + settings.ini), Qt (qt6ct) and the shell (Quickshell follows qt6ct).
#   icon-theme.sh current               name of the active icon theme
#   icon-theme.sh list                  one JSON object per installed icon theme: {id, name, user, preview: [paths]}
#   icon-theme.sh apply <id>            make <id> the icon theme everywhere
#   icon-theme.sh install <archive|dir|url>   unpack into ~/.local/share/icons, print the installed ids
#   icon-theme.sh remove <id>           delete a pack from ~/.local/share/icons (system packs are left alone)
set -euo pipefail

USER_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/icons"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
PREVIEW=(folder user-home utilities-terminal web-browser accessories-text-editor preferences-system)

dirs() { printf '%s\n' "$USER_DIR" "$HOME/.icons"; IFS=:; for d in ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do echo "$d/icons"; done; }
# an icon theme (not a cursor-only theme) has Directories= in its index.theme
is_icon_theme() { [ -f "$1/index.theme" ] && grep -q '^Directories=' "$1/index.theme"; }

current() { gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'"; }

list() {
  dirs | python3 -I -c '
import json, os, re, sys
user, seen = sys.argv[1], set()
names = sys.argv[2:]
for base in sys.stdin.read().split():
    if not os.path.isdir(base): continue
    for tid in sorted(os.listdir(base), key=str.lower):
        t = os.path.join(base, tid)
        if tid in seen or tid == "hicolor": continue
        try: idx = open(os.path.join(t, "index.theme"), errors="ignore").read()
        except OSError: continue
        m = re.search(r"^Directories=(.*)$", idx, re.M)
        if not m: continue                      # cursor-only theme
        seen.add(tid)
        nm = re.search(r"^Name=(.*)$", idx, re.M)
        name = nm.group(1) if nm else tid
        # largest rendition first: scalable, then by the number in the directory name
        size = lambda d: 9999 if "scalable" in d else int((re.search(r"\d+", d) or ["0"])[0])
        ds = sorted((d for d in m.group(1).split(",") if d), key=size, reverse=True)
        prev = []
        for n in names:
            f = next((os.path.join(t, d, n + e) for d in ds for e in (".svg", ".png") if os.path.exists(os.path.join(t, d, n + e))), None)
            if f: prev.append(f)
        print(json.dumps({"id": tid, "name": name.strip(), "user": base == user, "preview": prev}))
' "$USER_DIR" "${PREVIEW[@]}"
}

apply() {
  local id=$1 found=
  while read -r base; do is_icon_theme "$base/$id" && found=1 && break; done < <(dirs)
  [ -n "$found" ] || { echo "no icon theme named $id" >&2; exit 1; }
  gsettings set org.gnome.desktop.interface icon-theme "$id" || true
  for f in "$CFG/gtk-3.0/settings.ini" "$CFG/gtk-4.0/settings.ini"; do
    [ -f "$f" ] && sed -i --follow-symlinks "s/^gtk-icon-theme-name=.*/gtk-icon-theme-name=$id/" "$f"
  done
  [ -f "$CFG/qt6ct/qt6ct.conf" ] && sed -i --follow-symlinks "s/^icon_theme=.*/icon_theme=$id/" "$CFG/qt6ct/qt6ct.conf"
  [ -f "$CFG/qt5ct/qt5ct.conf" ] && sed -i --follow-symlinks "s/^icon_theme=.*/icon_theme=$id/" "$CFG/qt5ct/qt5ct.conf"
  # refresh the cache so GTK sees new icons at once
  gtk-update-icon-cache -q -t "$USER_DIR/$id" 2>/dev/null || true
}

install() {
  local src=$1
  tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
  if [[ $src =~ ^https?:// ]]; then
    curl -fsSL "$src" -o "$tmp/pack" || { echo "could not download $src" >&2; exit 1; }
    src="$tmp/pack"
  fi
  src=${src/#\~/$HOME}
  mkdir -p "$tmp/x" "$USER_DIR"
  if [ -d "$src" ]; then cp -a "$src" "$tmp/x/"
  elif [ -f "$src" ]; then
    case "$(file -b --mime-type "$src")" in
      application/zip) unzip -q "$src" -d "$tmp/x" ;;
      *) tar -xf "$src" -C "$tmp/x" ;;
    esac || { echo "could not unpack $1" >&2; exit 1; }
  else echo "no such file: $1" >&2; exit 1; fi
  local n=0
  while read -r idx; do
    local t; t=$(dirname "$idx")
    is_icon_theme "$t" || continue
    local id=${t##*/}
    rm -rf "${USER_DIR:?}/$id"; cp -a "$t" "$USER_DIR/$id"
    gtk-update-icon-cache -q -t "$USER_DIR/$id" 2>/dev/null || true
    echo "$id"; n=$((n + 1))
  done < <(find "$tmp/x" -name index.theme -not -path '*/.git/*')
  [ $n -gt 0 ] || { echo "no icon theme found in $1" >&2; exit 1; }
}

remove() {
  local id=$1
  [[ $id != */* && -n $id && -d "$USER_DIR/$id" ]] || { echo "$id is not a user-installed pack" >&2; exit 1; }
  [ "$(current)" = "$id" ] && { echo "$id is in use; pick another pack first" >&2; exit 1; }
  rm -rf "${USER_DIR:?}/$id"
}

case "${1:-}" in
  current) current ;;
  list) list ;;
  apply|install|remove) [ $# -eq 2 ] || { echo "usage: $0 $1 <arg>" >&2; exit 2; }; "$1" "$2" ;;
  *) sed -n '2,7p' "$0"; exit 2 ;;
esac
