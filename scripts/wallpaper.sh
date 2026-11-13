#!/usr/bin/env bash
# wallpaper.sh <image> [monitor]   - set a wallpaper with whichever backend is installed.
# Detects awww (swww successor) > swww > hyprpaper > swaybg. Starts the daemon if needed.
set -u
img=${1:?usage: wallpaper.sh <image> [monitor]}
mon=${2:-}
[ -f "$img" ] || { echo "no such file: $img" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

awww_like() {  # $1 = awww | swww
    local bin=$1 daemon=$1-daemon i
    pgrep -x "$daemon" >/dev/null || { setsid "$daemon" >/dev/null 2>&1 & disown; }
    # at login the daemon (and the compositor outputs) may not be ready yet: wait for it, up to ~15s
    for i in $(seq 1 60); do "$bin" query >/dev/null 2>&1 && break; sleep 0.25; done
    # retry the set itself: it can still fail right after the daemon comes up
    for i in 1 2 3 4 5 6 7 8; do
        if [ -n "$mon" ]; then "$bin" img -o "$mon" --transition-type fade "$img" && return 0
        else "$bin" img --transition-type fade "$img" && return 0; fi
        sleep 1
    done
    return 1
}

if have awww; then awww_like awww
elif have swww; then awww_like swww
elif have hyprpaper; then
    pgrep -x hyprpaper >/dev/null || { hyprpaper >/dev/null 2>&1 & disown; sleep 0.8; }
    hyprctl hyprpaper preload "$img" >/dev/null
    hyprctl hyprpaper wallpaper "${mon:-},$img" >/dev/null
elif have swaybg; then
    # swaybg cannot change in place: replace the process (per-monitor: only that output is restarted)
    pkill -x swaybg 2>/dev/null; sleep 0.1
    swaybg ${mon:+-o "$mon"} -i "$img" -m fill >/dev/null 2>&1 & disown
else
    echo "no wallpaper backend found (install awww, swww, hyprpaper or swaybg)" >&2; exit 2
fi
