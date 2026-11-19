#!/bin/sh
# screenshot.sh region|window|screen: grim + slurp. Saves to ~/Pictures/Screenshots, copies to the clipboard, notifies.
need() { command -v "$1" >/dev/null 2>&1 || { notify-send -a Screenshot "Screenshot needs $1" "Install it to take screenshots."; exit 1; }; }
need grim; need wl-copy
dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$dir"
file="$dir/Screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"
sleep 0.3   # let the dock's panel fade out of the picture
case "$1" in
    region) need slurp; geo=$(slurp) || exit 0 ;;
    window)
        need slurp; need jq
        geo=$(hyprctl clients -j | jq -r --argjson ws "$(hyprctl monitors -j | jq '[.[].activeWorkspace.id]')" \
            '.[] | select(.mapped and (.hidden | not) and (.workspace.id as $w | $ws | index($w))) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' \
            | slurp -r) || exit 0 ;;
    *) geo= ;;
esac
if [ -n "$geo" ]; then grim -g "$geo" "$file"; else grim "$file"; fi || exit 1
wl-copy < "$file"
notify-send -a Screenshot -i "$file" "Screenshot saved" "Copied to the clipboard\n$file"
