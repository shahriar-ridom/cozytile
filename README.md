# Cozytile: a complete Hyprland desktop (Quickshell shell + dotfiles)

A Wayland-native recreation of the [Cozytile](https://github.com/Darkkal44/Cozytile) look (Qtile/X11) for
**Hyprland + Quickshell**. It reproduces the design language, not the implementation.

## What it is

| Piece | How |
|---|---|
| Top bar | One floating bar in two tones (dark caps, lighter middle) joined by S-curve and slash separators, workspace dots, search cap, window title, tray, media, CPU/RAM/temp, network, volume, battery (hidden on desktops), notifications bell, clock |
| Dynamic island | Centre of the bar (screens ≥ 1500 px wide). Idle shows the date; shows now-playing, or a banner for each new notification. Click to expand: clock, media card (seek, transport, shuffle/loop, volume), latest notifications (actions, dismiss, DND, clear), quick actions (theme, wallpapers, mic, audio output, power). Click outside or Esc to close. `Super+Shift+I` / `ipc call island toggle` |
| Island feedback | Replaces the OSD and toasts: volume / mic / brightness / keyboard-backlight levels (with mute state), notification banners, and short toasts for Do-Not-Disturb, theme, wallpaper, network up/down, output device, Bluetooth connect/disconnect and battery. Lock keys (Caps/Num/Scroll) toast, with a CAPS chip while on (needs the Hyprland binds in `dotfiles/hypr/binds.lua`). A mic / video-capture indicator names the app using it. A native timer shows a countdown chip, and rings (pulsing island + sound) when done; click the island to silence it. |
| Launcher | Real desktop entries (`DesktopEntries`), fuzzy-ish ranking, category chips, keyboard driven |
| Notifications | Own freedesktop daemon. Everything shows in the island: a banner (with a progress bar for apps that report progress), and the full scrolling history, actions, dismiss, clear-all and Do-Not-Disturb in the expanded card. There are no separate popups, centre or bar bell. |
| OSD | Volume, microphone, brightness, keyboard backlight |
| Audio / Media | PipeWire (volume, mute, output picker, mic) and MPRIS (track, play/pause/next/prev) |
| Power menu | Lock / Logout / Suspend / Reboot / Shutdown, confirm on destructive ones |
| Wallpapers | Thumbnail grid, per-monitor or all, remembered and restored, backend auto-detected (awww, swww, hyprpaper, swaybg) |
| Themes | Everforest (default), Sakura, plus an optional matugen "Wallpaper" theme. Switch live, persisted |

## Requirements

Required: `quickshell` (>= 0.3, built with Hyprland, Pipewire, Mpris, Notifications, SystemTray, UPower, Networking), `hyprland`.
Optional: `awww`/`swww`/`hyprpaper`/`swaybg` (wallpapers), `matugen` (wallpaper theme), `hyprlock` (lock),
`brightnessctl` (backlight OSD), `playerctl`, **CaskaydiaCove Nerd Font** (icons; change `Theme.font` for another Nerd Font).

Only one notification daemon can run. **Stop other shells/daemons (dunst, swaync, mako, ...) before using Cozytile.**

## Install (whole desktop)

```sh
./setup.sh --dry-run            # preview everything
./setup.sh --packages           # optional: pacman/AUR packages from packages.txt
./setup.sh                      # shell + dotfiles; existing files are moved to *.bak-<timestamp>
```

`setup.sh` installs the Quickshell shell to `~/.config/quickshell/cozytile`, renders the theme into
`~/.config/cozytile/generated`, and **symlinks from this repo**: `~/.config/hypr`, `kitty/kitty.conf`, `~/.zshrc`,
GTK 3/4 `settings.ini`; it renders `qt6ct.conf` and adds the GTK colour import. Edit the repo, not `~/.config`.
SDDM is opt-in: `./setup.sh --sddm` (sudo). Shell only: `./install.sh`; try without installing: `qs -p .`.

### Repo layout

| Path | What |
|---|---|
| `shell.qml`, `config/`, `services/`, `modules/`, `components/` | the Quickshell shell |
| `dotfiles/hypr/hyprland.lua` + `config/*.lua` | Hyprland: monitor, env, input, appearance, animations, workspaces, rules, startup, binds, `look.lua` (theme-driven) |
| `dotfiles/hypr/config/local.lua` | per-machine overrides (monitor, GPU); git-ignored, template in `local.example.lua` |
| `dotfiles/hypr/hypridle.conf`, `scripts/` | idle (lock 5 min, screen off 6, suspend 20), lock wrapper, helpers |
| `dotfiles/kitty`, `zsh`, `gtk`, `qt6ct` | terminal, shell, toolkit settings |
| `dotfiles/templates` + `render.py` | themed kitty/starship/hyprlock/cava/btop/fastfetch/GTK/Qt/SDDM from `config/palettes.json` |
| `packages.txt` | Arch/CachyOS package list |

Main keys (see `dotfiles/hypr/config/binds.lua`): `Super+Return` terminal, `Super+D`/`Space` launcher, `Super+A` island,
`Super+X` power, `Super+Ctrl+L` lock, `Super+Shift+T` next theme, `Super+Ctrl+O` wallpapers, `Super+Shift+S` screenshot region,
`Super+H/J/K/L` focus, `Super+1..0` workspaces.

Every action is an IPC call, so any keybind tool works:

```
qs -c cozytile ipc call launcher toggle
qs -c cozytile ipc call notifications toggle|clear|dnd      # toggle opens the island
qs -c cozytile ipc call keys refresh                        # lock-key state (bound to Caps/Num/Scroll)
qs -c cozytile ipc call power toggle
qs -c cozytile ipc call island toggle|close
qs -c cozytile ipc call timer start 5m|90s|1h30m|25:00   # also: stop, toggle, add 1m, status
qs -c cozytile ipc call workspace goto <n>|next|prev
qs -c cozytile ipc call wallpaper toggle
qs -c cozytile ipc call theme next|set sakura|get
qs -c cozytile ipc call audio up|down|mute|micMute
qs -c cozytile ipc call brightness up|down|kbdUp|kbdDown
```

Bar mouse actions: logo = launcher (right = power, middle = wallpapers), volume = mute / scroll / right-click output picker /
middle mic mute, clock = toggle date; island: click = expand, middle = play/pause, right = Do-Not-Disturb,
workspace dots = switch (scroll too).

## Full desktop (dotfiles)

Beyond the shell, `dotfiles/` recreates the rest of the Cozytile desktop from the same palette
(`config/palettes.json`, also read by the shell, so nothing drifts):

| Piece | File |
|---|---|
| Hyprland look: even 9px gaps, borderless, 10px rounding, soft shadow, blur, layer rules | `dotfiles/hypr/cozytile.lua` (+ optional `binds.lua`) |
| Terminal colours (kitty) | generated `kitty/colors.conf` |
| Powerline prompt in stepped shades | generated `starship.toml`, `zsh/cozytile.zsh` |
| Lock screen | generated `hypr/hyprlock.conf` |
| fastfetch, cava, btop | generated configs/themes |
| GTK 3/4 and Qt6 colours | generated `gtk/colors.css`, `qt6ct/cozytile.conf` |
| Login screen (SDDM, Qt6) | `dotfiles/sddm/Cozytile` |

```sh
~/.config/cozytile/theme-apply.sh sakura        # re-render everything and reload hooked apps
```

Switching theme from the shell (`theme next`, or `Mod+Shift+T`) re-renders all of it too (`syncDotfiles` in settings).
Generated files live in `~/.config/cozytile/generated/`. Only apps that you hooked up are reloaded.
Wallpapers are not bundled: point the wallpaper selector at your own folder.

Wallpaper selector keys: arrows move, Enter/Space apply, Tab switches monitor, Esc closes.
The island is always on; on narrow screens its pill shrinks and the bar drops its optional pieces (network/temperature below 1500 px, search/CPU/RAM below 1150 px).

## Configuration

Persisted in `~/.local/state/cozytile/settings.json` (created on first run, live-reloaded):
`theme`, `syncDotfiles`, `wallpaperDirs`, `wallpapers`, `wallpaperTheming`, `osdTimeout` (ms), `showWorkspaceNumbers`, `showWindowTitle` (off by default), `dnd`.

Design tokens (fonts, bar height, margins, radii, animation timings) live in `config/Theme.qml`.

## Themes

Palettes are in `config/Theme.qml` (`palettes`). Add one by adding an entry with the same keys
(`bg bg2 bg3 dim fg fg2 muted green blue yellow orange red purple accent workspaceActive`) and listing its name in
`themeNames`/`themeLabels`. Components only use semantic roles (`Theme.barCap`, `Theme.accent`, ...), never raw colours.
"Theme from wallpaper" (wallpaper selector) runs matugen with `--dry-run` and adds a third theme; Everforest and Sakura are never replaced.

## Layout

`shell.qml` entry + IPC · `config/` Theme, Settings · `services/` state (audio, media, network, battery, system monitor,
notifications, wallpaper, theme, UI state) · `modules/` UI per feature · `components/` shared drawing (Segment, Slash, ...)
· `scripts/` wallpaper backend + theme switcher.

## Troubleshooting

- *No notifications*: another daemon owns `org.freedesktop.Notifications` (`busctl --user status org.freedesktop.Notifications`). Stop it.
- *Missing icons / tofu*: install a Nerd Font and set `Theme.font`.
- *Wallpaper does not change*: run `scripts/wallpaper.sh /path/img` in a terminal to see backend errors.
- *No temperature*: no `k10temp`/`coretemp`/`zenpower` hwmon found; the item hides itself.
- *Logs*: `qs -c cozytile log` (or `~/.cache/quickshell`).

## Rollback / uninstall

`./rollback.sh` restores the install the installer moved aside. `./uninstall.sh [--purge]` removes the install (settings kept unless `--purge`).

## Fidelity notes

Compared screenshot-to-screenshot with the reference's bar (two-tone, S-curve caps, slash separators, dot workspaces,
search cap, 30px height): structure and proportions match; separators are drawn as vector shapes, not the original PNGs, and
the logo is an original four-diamond mark. This is not pixel-identical.

### About timers
The island has its own timer (expanded card, or `ipc call timer start 5m`). A timer running inside a web page (for example Google's) is invisible to the desktop: browsers do not expose page content or countdowns, so it cannot be mirrored here. If a page raises a web notification, it shows up as a normal notification banner.
