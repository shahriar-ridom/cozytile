<div align="center">

# Cozytile

**A cozy, complete desktop for Hyprland, built on Quickshell.**

Top bar · Dynamic island · Launcher · Notifications · Settings app · Desktop overview · Themed dotfiles

[Install](#install) · [Features](#features) · [Keyboard shortcuts](#keyboard-shortcuts) · [Settings](#settings) · [Troubleshooting](#troubleshooting)

![Cozytile desktop](docs/screenshots/desktop.png)

</div>

Cozytile turns a bare Hyprland install into a finished desktop. You get a floating bar, a dynamic island for
notifications and media, a Spotlight-style launcher, a settings app, a Mission Control-style overview, a desktop
clock, and matching dotfiles for your terminal, prompt, lock screen, GTK and Qt apps. Everything shares **one
colour palette**, so the whole desktop looks like it belongs together.

It is a Wayland-native take on the [Cozytile](https://github.com/Darkkal44/Cozytile) look, originally made for Qtile/X11.

## Contents

- [Features](#features)
- [Install](#install)
- [Requirements](#requirements)
- [Keyboard shortcuts](#keyboard-shortcuts)
- [Settings](#settings)
- [Theming](#theming)
- [Command line and scripting](#command-line-and-scripting)
- [Troubleshooting](#troubleshooting)
- [Project layout](#project-layout)
- [License and credits](#license-and-credits)

---

## Features

| | |
|---|---|
| **Top bar** | Workspaces, window title, global menu, system stats, network, volume, battery, tray, clock |
| **Dynamic island** | Notifications, media controls, timer and quick actions in one place |
| **Launcher** | Apps, windows, calculator, conversions, files, emoji, clipboard, web search, commands |
| **Notifications** | Built-in daemon with history, actions, progress bars and Do-Not-Disturb |
| **Overview (Stage)** | Mission Control-style view of every desktop and window, with drag and drop |
| **Settings app** | Themes, bar, display, windows, input, autostart, lock screen, power and more |
| **Desktop clock** | Minimal, stacked or analog, behind your windows |
| **Wallpapers** | Per-monitor picker, plus a theme built from the picture |
| **Themes** | Everforest, Sakura and from-wallpaper, applied to the shell and your apps |
| **Frosted glass** | An optional translucent, blurred look across the whole desktop |
| **Lock screen, power menu, night light, monitors, idle** | Themed and configurable from Settings |

### The top bar

A floating bar with rounded caps. The left holds the logo, workspace dots, search and (optionally) the focused app's
menus. The right holds CPU, RAM, temperature, network, volume, battery, tray icons and the clock. Items you don't
need can be hidden in Settings, and the bar drops optional items automatically on narrow screens.

![The top bar, with the global menu on the left](docs/screenshots/bar.png)

The logo's system menu (left-click the logo):

![The logo's system menu](docs/screenshots/logo-menu.png)

- **Logo**: left-click for the system menu (About This System, **System Settings**, recent apps and files, force quit, reload Hyprland, lock, sleep, ...), right-click for the power menu, middle-click for the wallpaper picker.
- **Volume**: click to mute, scroll to change, right-click for the output picker, middle-click to mute the mic.
- **Clock**: click to show the date. **Workspace dots**: click or scroll to switch.
- **Global menu**: turn it on in Settings → Bar to show the focused app's menus (File, Edit, View, ...) on the bar, like macOS. See [Global menu setup](#global-menu-setup).

### The launcher

Press `Super + Space` (or `Super + D`) and start typing.

![The launcher](docs/screenshots/launcher.png)

| Type | You get |
|---|---|
| `ffx` | Apps and open windows, with fuzzy matching |
| `12 km to mi` | Calculator and unit and currency conversion, as you type |
| `/` + name | Files |
| `g`, `yt`, `gh`, `w`, `so`, `aur`, `aw`, `mdn` + text | Web search |
| `:smile` | Emoji, with your recent ones first |
| `clip` | Clipboard history |
| `>` + command | Run a shell command |
| | System actions (lock, suspend, ...) |

![Calculator and conversions](docs/screenshots/launcher-calc.png)
![Emoji search](docs/screenshots/launcher-emoji.png)

### The dynamic island

The island sits at the top centre and does three jobs:

- **Banners**: notifications, volume, microphone and brightness feedback pop up here, so there are no separate OSD popups.
- **Media**: shows what's playing, with play/pause and skip controls.
- **Panel**: click it to open the full card with the timer, notification history and quick actions (theme, wallpaper, microphone, night light, volume, power).

![A notification banner](docs/screenshots/notification.png)
![The island panel](docs/screenshots/island.png)

**Timers.** Pick a preset (1m, 5m, 10m, 25m) or a custom time. A countdown chip stays in the island while it runs,
and it rings with a pulse and a sound when finished. Click the island to silence it.

![A running timer](docs/screenshots/island-timer.png)

The island also tells you when **Caps Lock, Num Lock or Scroll Lock** is on, and when an app is using your
**microphone or camera**, and which app.

### Notifications

Cozytile includes its own notification daemon, so there is nothing extra to install. It supports actions, progress
bars, a history you open from the island, and **Do-Not-Disturb** (toggle it from the island's notification panel).

### Overview (Stage)

Press `Super + Tab` for a Mission Control-style overview. Each Hyprland workspace is a **desktop** shown as a card
along the top, and below it are the windows of the selected desktop, zoomed out from their real positions with live
thumbnails.

![The overview](docs/screenshots/overview.png)

- Click a window to jump to it, or drag it onto another desktop (or the **+**) to move it.
- Name your desktops and add **app rules** so an app always opens on a given desktop (Settings → Stage).
- `Super + Ctrl + Tab` jumps to the next desktop. Windows are never closed by switching.

### The desktop clock

A clock on your wallpaper, behind your windows and click-through, so it never gets in the way. Choose a style, size,
font, 12 or 24-hour time, and drag it anywhere in Settings → Desktop.

| Minimal | Stacked | Analog |
|---|---|---|
| ![Minimal clock](docs/screenshots/clock-minimal.png) | ![Stacked clock](docs/screenshots/clock-stacked.png) | ![Analog clock](docs/screenshots/clock-analog.png) |

### Wallpapers

A thumbnail picker (`Super + Ctrl + O`) shows the images in the folders you choose. Each monitor can have its own
wallpaper, and **Theme from wallpaper** builds the whole colour scheme from the picture. Cozytile doesn't ship
wallpapers, so point it at your own folder.

![The wallpaper picker](docs/screenshots/wallpapers.png)

### Power menu and lock screen

`Super + X` opens a menu to **lock**, **log out**, **suspend**, **reboot** or **shut down**. Use the arrow keys and
`Enter`, or click.

![The power menu](docs/screenshots/power-menu.png)

The lock screen (hyprlock) is themed to match. In Settings → Lock screen you can pick a background, set its blur and
brightness, and choose the clock size, font and 12 or 24-hour time. A live preview is shown.

### Frosted glass

Turn on **Frosted glass** in Settings → Appearance for a translucent look: the bar, island, panels, terminal, GTK/Qt
apps, lock screen and login screen get a blurred, palette-tinted surface. Turn it off for solid surfaces.

![Frosted glass off: solid surfaces](docs/screenshots/frost-off.png)

*Above: frosted glass off. The desktop at the top of this page has it on.*

### Display, input and power

- **Night light** warms the screen, always or on a schedule. You can also dim all screens in software.
- **Monitors**: resolution, refresh rate, scale, rotation, position, VRR and on/off. Changes revert after 15 seconds unless you keep them, so you can't lock yourself out of a display.
- **Keyboard and mouse**: layouts, XKB options, key repeat, pointer speed and acceleration, focus-follows-mouse, touchpad options and cursor hiding.
- **Power and idle**: when to lock, turn off the screen and suspend.
- **Autostart**: run any command or app at login, with an app picker. You can test-run, reorder and toggle entries.

### Hyprland, made easy

Windows, gaps, rounding, borders, opacity, blur, shadows and animations all have sliders and toggles in
Settings → Windows. Changes apply live and survive reloads. Hyprland's own config stays readable and
hand-editable, and the settings app writes only the values you change.

---

## Install

On Arch or CachyOS, with an internet connection:

```sh
git clone https://github.com/shahriar-ridom/cozytile.git
cd cozytile
./setup.sh --dry-run         # 1. preview every change (touches nothing)
./setup.sh --packages        # 2. install the packages Cozytile needs
./setup.sh                   # 3. install the shell and link the dotfiles
```

Then log out, choose **Hyprland** at the login screen, and log in. That's it.

Want to try it in your current session first? Run `~/.config/quickshell/cozytile/scripts/launch.sh`.
`setup.sh` is safe to re-run. Anything it would replace is first moved to `*.bak-<timestamp>`.

### Other ways to install

| I want... | Run |
|---|---|
| The full desktop (recommended) | `./setup.sh` |
| Only the bar, island and launcher, with my own Hyprland config | `./install.sh` |
| To try it without installing | `qs -p .` from the repo folder |
| The Cozytile login screen (SDDM) | `./setup.sh --sddm` (needs sudo) |
| To start with the Sakura theme | `./setup.sh --theme sakura` |

> The installed shell is a **copy** in `~/.config/quickshell/cozytile`. After you edit the QML, run `./install.sh`
> again, or use `qs -p .` to run straight from the repo.

### What the installer changes

- The shell goes to `~/.config/quickshell/cozytile`.
- Your themed config files are generated into `~/.config/cozytile/generated/`.
- These are **symlinked to this repo**, so editing them here updates your desktop right away:
  `~/.config/hypr`, `kitty`, `~/.zshrc`, and the GTK 3/4 settings. Qt (`qt6ct`) is rendered as well.

Edit the dotfiles in this repo, not in `~/.config`. Machine-specific settings (monitor layout, GPU) go in
`dotfiles/hypr/config/local.lua`, which `setup.sh` creates from `local.example.lua`. It is git-ignored.

### Undo and uninstall

```sh
./rollback.sh                # restores the previous shell install
./uninstall.sh               # removes the installed shell (your settings are kept)
./uninstall.sh --purge       # also removes your saved settings
```

The dotfile symlinks aren't removed automatically. To go back to your old config, restore the `*.bak-<timestamp>`
copies next to them.

---

## Requirements

| Needed | Why |
|---|---|
| **Hyprland 0.55 or newer** (Lua config) | The window manager. The bundled config is `hyprland.lua` |
| **Quickshell 0.3 or newer**, built with Hyprland, PipeWire, MPRIS, Notifications, SystemTray, UPower and Networking | The bar, island, launcher and settings app |
| **CaskaydiaCove Nerd Font** | Icons and monospace text. Any Nerd Font works; set `Theme.fontMono` in `config/Theme.qml` |
| **SF Pro Text** (optional) | The UI font. It isn't in the Arch repos, so Qt falls back to another sans font. Set `Theme.font` to any font you like |

`./setup.sh --packages` installs everything in `packages.txt`. Optional extras, each unlocking a feature:

| Tool | Unlocks |
|---|---|
| `awww`, `swww`, `hyprpaper` or `swaybg` | Wallpapers |
| `matugen` | The from-wallpaper theme |
| `hyprlock` | The lock screen |
| `hypridle` | Idle timeouts |
| `brightnessctl` | Screen brightness keys |
| `playerctl` | Media keys |
| `hyprshot` | Screenshots |
| `kitty`, `zsh`, `starship` | The themed terminal and prompt |
| `python3` + PyGObject | The global menu |

> **Important:** only one notification daemon can run at a time. Stop any others first (`dunst`, `swaync`, `mako`, ...).

---

## Keyboard shortcuts

`Super` is the Windows/Command key. The full list lives in `dotfiles/hypr/config/binds.lua`.

**Apps and shell**

| Keys | Action |
|---|---|
| `Super + Return` | Terminal (kitty) |
| `Super + Shift + Return` | Floating terminal |
| `Super + B` | Browser (Zen) |
| `Super + C` | VS Code |
| `Super + N` | Neovim in the terminal |
| `Super + Space` or `Super + D` | Launcher |
| `Super + Tab` or `Super + Alt + S` | Overview |
| `Super + Ctrl + Tab` (`+ Shift` for previous) | Next desktop |
| `Super + A`, `Super + Shift + N` or `Super + Shift + I` | Island (notifications, media, timer) |
| `Super + Shift + T` | Next theme |
| `Super + Ctrl + O` | Wallpaper picker |
| `Super + X` | Power menu |
| `Super + Ctrl + L` | Lock screen |

**Windows and layout**

| Keys | Action |
|---|---|
| `Super + Q` | Close window |
| `Super + V` | Toggle floating |
| `Super + Ctrl + C` | Centre a floating window |
| `Super + F` | Fullscreen (covers the bar) |
| `Super + Shift + F` | Maximise (keeps the bar and gaps) |
| `Super + S` | Toggle split direction |
| `Super + P` | Pseudo-tile |
| `Super + M` | Swap with master |
| `Super + H / J / K / L` | Move focus left / down / up / right |
| `Super + Shift + H / J / K / L` | Move the window in that direction |
| `Super + Mouse drag` | Move a window |
| `Super + Right-drag` | Resize a window |
| `` Super + ` `` | Toggle the scratchpad |
| `Super + O` | Toggle the Obsidian scratchpad |

**Workspaces**

| Keys | Action |
|---|---|
| `Super + 1 ... 0` | Go to workspace 1-10 |
| `Super + Shift + 1 ... 0` | Move the window to workspace 1-10 |
| `Super + Mouse wheel` | Previous / next workspace |

**Screenshots** (saved to `~/Pictures/Screenshots`)

| Keys | Action |
|---|---|
| `Super + Shift + S` | Region |
| `Super + Ctrl + S` | Whole screen |
| `Super + Shift + W` | A window |

**Session:** `Super + Shift + R` reloads Hyprland, `Super + Shift + E` exits it.

**Media and hardware keys:** volume, mute, brightness and play/pause/next/previous are bound by default. Volume and
brightness show their feedback in the island.

---

## Settings

Open the settings app from the logo's menu in the bar (**System Settings...**), or run `qs -c cozytile ipc call settings toggle`. Jump straight to a page with:

```sh
qs -c cozytile ipc call settings open <page>
```

Pages: `appearance`, `desktop`, `lock screen`, `bar`, `general`, `display`, `windows`, `stage`, `input`, `autostart`, `power`, `about`.

| Group | Page | What's in it |
|---|---|---|
| Personalise | **Appearance** | Colour scheme, from-wallpaper theme, app syncing, frosted glass, fonts |
| Personalise | **Desktop** | Wallpapers, desktop clock style, position, size, font and time format |
| Personalise | **Lock screen** | Background, blur, brightness, clock size, font, 12/24-hour time |
| Shell | **Bar** | Bar style, global menu, window title, workspace numbers, temperature, stats refresh |
| Shell | **General** | Do-Not-Disturb, clearing notifications, OSD duration, reload Hyprland, restart the shell |
| System | **Display** | Night light, software dimming, monitors (resolution, refresh, scale, rotation, position, VRR) |
| System | **Windows** | Layout (dwindle, master, scrolling), gaps, rounding, borders, opacity, blur, shadows, animations |
| System | **Stage** | Overview edge, corner radius, animation speed, app rules |
| System | **Input** | Keyboard layouts, XKB options, key repeat, pointer speed, touchpad, cursor |
| System | **Autostart** | Commands and apps started at login |
| System | **Power & idle** | Lock, screen-off and suspend timeouts |
| | **About** | System info and config file locations |

| Appearance | Bar |
|---|---|
| ![Appearance](docs/screenshots/settings-appearance.png) | ![Bar](docs/screenshots/settings-bar.png) |
| **Desktop** | **Display** |
| ![Desktop](docs/screenshots/settings-desktop.png) | ![Display](docs/screenshots/settings-display.png) |
| **Windows** | **Input** |
| ![Windows](docs/screenshots/settings-windows.png) | ![Input](docs/screenshots/settings-input.png) |
| **Lock screen** | **Stage** |
| ![Lock screen](docs/screenshots/settings-lock-screen.png) | ![Stage](docs/screenshots/settings-stage.png) |
| **General** | **Power & idle** |
| ![General](docs/screenshots/settings-general.png) | ![Power and idle](docs/screenshots/settings-power.png) |

**Good to know**

- Hyprland changes apply live and are saved to `~/.config/cozytile/generated/hypr/cozytile_settings.lua`, which loads after the shipped config. Your choices survive reloads.
- A small accent-coloured dot next to a setting means you've changed it from the default. Click the dot to go back.
- The settings app remembers the page you last used. Press `Esc` to close and `Ctrl + Tab` for the next page.

### Settings file

Settings are saved to `~/.local/state/cozytile/settings.json` and reload live. Keys include `theme`,
`syncDotfiles`, `wallpaperDirs`, `wallpapers`, `wallpaperTheming`, `osdTimeout` (ms), `showWorkspaceNumbers`,
`showWindowTitle`, `globalMenu`, `dnd`, `showTemp`, `statsInterval` (ms), `frostedGlass`, `desktopClock`, `stage` and
`lockscreen`. The settings app also stores `hypr` (Hyprland overrides), `monitors`, `autostart` and `idle`.

Design tokens (fonts, bar height, margins, radii, animation timings) are in `config/Theme.qml`.

---

## Theming

Cozytile ships two colour schemes, **Everforest** (default) and **Sakura**, plus an optional **from-wallpaper** theme
that derives its colours from your picture with `matugen`. Switch with `Super + Shift + T` or in Settings → Appearance.

A theme change re-colours the bar, island, launcher and settings, and re-themes the apps you've hooked up (kitty,
starship, hyprlock, GTK and Qt) from the same palette.

**Adding a theme.** The palettes live in `config/palettes.json`, the one source used by both the shell and the
dotfile renderer (`dotfiles/render.py`). Add an entry with the same keys as the existing ones
(`bg bg2 bg3 dim fg fg2 muted green blue yellow orange red purple accent workspaceActive`) and add its name to
`themeNames` and `themeLabels` in `config/Theme.qml`. Every component uses semantic colour roles, so a new theme
recolours everything automatically.

### Global menu setup

The global menu needs apps to run through XWayland, because Hyprland can't export menus from native Wayland windows.

- `scripts/menu-launchers.sh` writes launcher overrides for Dolphin, LibreWolf and Zen (plus Thunar and GIMP when
  `appmenu-gtk-module` is installed). Run it with `--remove` to undo.
- Start those apps from the launcher or a desktop entry. Only apps started after the shell is running export a menu.
- Firefox-family browsers also need `widget.gtk.global-menu.enabled` set to `true` in the profile (`user.js`).
- Some apps never export a menu. kitty has no global-menu support on Linux.

---

## Command line and scripting

Every action is an IPC call, so any keybind tool can use them:

```sh
qs -c cozytile ipc call launcher toggle|open|close
qs -c cozytile ipc call launcher search "5 km to miles"
qs -c cozytile ipc call notifications toggle|clear|dnd
qs -c cozytile ipc call island toggle|close
qs -c cozytile ipc call timer start 5m|90s|1h30m|25:00   # also: stop, toggle, add 1m, status
qs -c cozytile ipc call workspace goto <n>|next|prev
qs -c cozytile ipc call stage overview|next|prev|goto <n>|list
qs -c cozytile ipc call stage create|switchTo|rename|remove <name>
qs -c cozytile ipc call wallpaper toggle|set <path>
qs -c cozytile ipc call theme next|set sakura|get
qs -c cozytile ipc call frost toggle|on|off|get
qs -c cozytile ipc call clock toggle|on|off|style minimal|stacked|analog
qs -c cozytile ipc call audio up|down|mute|micMute
qs -c cozytile ipc call brightness up|down|kbdUp|kbdDown
qs -c cozytile ipc call nightlight toggle|on|off|status   # also: temperature 4000, dim 80
qs -c cozytile ipc call power toggle
qs -c cozytile ipc call settings toggle|open <page>
```

Run `qs -c cozytile ipc show` for the full, current list. To re-render the themed dotfiles for a theme:

```sh
~/.config/cozytile/theme-apply.sh sakura
```

Only apps you've set up are reloaded.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| **No notifications** | Another daemon owns them. Check with `busctl --user status org.freedesktop.Notifications`, then stop it. |
| **Missing icons or empty boxes** | Install a Nerd Font and set `Theme.fontMono` in `config/Theme.qml`. |
| **Wallpaper doesn't change** | Run `scripts/wallpaper.sh /path/to/image.png` in a terminal to see the error. |
| **No temperature shown** | No sensor was found (`k10temp`, `coretemp` or `zenpower`). The item hides itself. |
| **Installer says a module is missing** | Your Quickshell build lacks a service module. Rebuild it with the modules listed in [Requirements](#requirements). |
| **Shell fails to load after editing QML** | One QML error stops the whole shell. Lint with `qmllint <files>`, then check the log with `qs -c cozytile log`. |
| **No global menu for an app** | See [Global menu setup](#global-menu-setup). |
| **Something else looks wrong** | Check `~/.cache/quickshell`, or run `qs -c cozytile log`. |

On narrow screens, the bar drops optional items: network and temperature below 1500 px, and search, CPU and RAM below 1150 px.

---

## Project layout

| Path | What's inside |
|---|---|
| `shell.qml` | The entry point: IPC handlers, the bar, island, desktop clock, and overlays |
| `config/` | Settings, the theme, and the palette (`palettes.json`) |
| `services/` | Stateless services: audio, network, media, notifications, timer, stage, frosted glass, and more |
| `modules/` | The UI, one folder per feature (bar, island, launcher, settings, stage, power, wallpaper, clock, ...) |
| `components/` | Shared widgets (toggle, dropdown, segmented control, slider, ...) |
| `scripts/` | Helper scripts: wallpapers, theme switching, global menu, recent files |
| `dotfiles/hypr/` | Hyprland config (`hyprland.lua`, `config/*.lua`), idle, lock and helper scripts |
| `dotfiles/kitty`, `zsh`, `gtk`, `qt6ct`, `sddm` | Terminal, shell, toolkit and login-screen settings |
| `dotfiles/templates/` + `render.py` | Renders themed configs from `config/palettes.json` |
| `packages.txt` | Arch and CachyOS package list |
| `docs/screenshots/` | Screenshots used in this README |

Contributing: there is no build step and no test suite. Run the shell from the repo with `qs -p .`, lint with
`qmllint`, and launch it once after any QML change, because a single error stops the whole config from loading.

---

## License and credits

Cozytile is released under the [MIT License](LICENSE).

Its look is inspired by the original [Cozytile](https://github.com/Darkkal44/Cozytile) for Qtile.
Built with [Quickshell](https://quickshell.org) and [Hyprland](https://hyprland.org).
