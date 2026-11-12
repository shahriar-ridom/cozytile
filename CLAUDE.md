# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Cozytile is a Hyprland desktop built on **Quickshell** (QML): top bar, dynamic island, launcher, notification daemon, settings app, desktop clock, plus themed dotfiles. There is no build step and no test suite.

## Commands

- Run straight from the repo (no install): `qs -p .`. Note that only one notification daemon can own the bus, so don't run this beside an already-running `qs -c cozytile`.
- Install the shell: `./install.sh` copies it to `~/.config/quickshell/cozytile`. **The installed shell is a copy, not a symlink.** Re-run `./install.sh` after editing QML if you want the running desktop to change.
- Full desktop: `./setup.sh [--dry-run] [--packages] [--sddm] [--theme NAME]`. It is safe to re-run, and it backs up anything it replaces as `*.bak-<timestamp>`. `./rollback.sh` and `./uninstall.sh [--purge]` undo it.
- Start the installed shell: `scripts/launch.sh` (wraps `qs -c cozytile` with transparent huge pages disabled).
- Lint QML: `qmllint <files>`. Quickshell's own logs are in `/run/user/$UID/quickshell/by-id/*/log.qslog`. A QML error in any file makes the **whole** config fail to load ("Failed to load configuration"), so always launch it once after changing QML.
- Control the running shell: `qs -c cozytile ipc call <target> <function>`. The targets are the `IpcHandler` blocks in `shell.qml` (launcher, search, notifications, island, timer, clock, keys, power, settings, wallpaper, workspace, theme, nightlight, audio, brightness, frost). Hyprland keybinds call these (`dotfiles/hypr/config/binds.lua`).
- Re-render themed dotfiles: `dotfiles/theme-apply.sh <theme>`.

### Testing a visual change without touching the live shell
Copy `config services modules components` into a scratch dir, add a minimal `shell.qml` that instantiates only the piece you changed, and run `qs -p <dir>/shell.qml`. Screenshot with `grim`. Do not use `pkill -f` with a pattern that appears in your own command line (it kills the calling shell).

## Architecture

**`shell.qml`** is the entry point. It declares the IPC handlers, one `Bar`, `Island` and `DesktopClock` per screen via `Variants`, and the overlay panels (launcher, search, settings, power, wallpaper picker, audio picker, popups) as `LazyLoader`s. Each overlay is created only while open (`UiState.<flag>`) and kept alive until its close animation ends through the `held` binding. Follow that pattern when adding an overlay.

Layers, each with its own `qmldir` that must list new files:
- `config/`: the `Settings` singleton persists to `~/.local/state/cozytile/settings.json` through a `JsonAdapter` and reloads live. Every new persisted key needs an adapter property **and** an alias at the top of `Settings.qml`. `Theme` holds every colour and metric; components must not hardcode colours.
- `services/`: stateless-UI singletons (audio, media, network, notifications, timer, `UiState`, ...). `UiState` is the single source of truth for which overlay is open, and `closeAll()` must be updated when you add an overlay flag. Options-style services (`LockscreenService`, `DesktopClockService`) wrap an object-valued Settings key with `get(k)`, `set(k, v)` and `reset()`.
- `modules/<feature>/`: UI per feature. The settings app lists its pages in `SettingsPanel.qml` (`pages`), with each page a `Page*.qml` loaded by file name.
- `components/`: shared widgets (Toggle, Segmented, Dropdown, ...).

**Theming pipeline spans QML and the dotfiles.** `config/palettes.json` is the one palette source. `Theme.qml` reads it at runtime, and `dotfiles/render.py` renders `dotfiles/templates/*.tpl` (kitty, hyprlock, starship, GTK, Qt, ...) from the same file into `~/.config/cozytile/generated/`. `Theme.apply()` triggers `theme-apply.sh` for the dotfiles. The "wallpaper" theme is a matugen-derived palette cached under `~/.local/state/cozytile/`. The lock screen options (`Settings.lockscreen`) are also read by `render.py`, so changing their shape means touching both sides.

**Frosted glass** (`Settings.frostedGlass`, toggled by `FrostService`) copies the kitty terminal's look across the desktop: palette-tinted surfaces at about 0.78 opacity over a compositor blur, with no rims or gradients. `Theme.frost` makes the panel fills translucent (`popupBg`, `barCapFill`, ...), window translucency exists only while it is on (`dotfiles/hypr/config/frost.lua`, loaded through the generated Lua; `rules.lua` and `kitty.conf` stay opaque, kitty's opacity comes from the rendered `colors.conf`), the blur settings are left as they are, `rules.lua` blurs every `cozytile-*` layer, and `render.py` reads the flag for hyprlock, GTK, Qt and SDDM. `barCap`/`barMid` stay solid because they double as text-on-accent colours: use the `*Fill` tokens for backgrounds. Palette entries are plain strings, so use `Theme.veil(color, alpha)` rather than reading `.r/.g/.b` off them.

**Global menu** is a Python bridge, not QML-only. `scripts/globalmenu.py` registers as the session's `com.canonical.AppMenu.Registrar`, reads the focused app's dbusmenu and talks to the shell over stdin/stdout JSON lines (protocol in its docstring). Hyprland can't export menus from native-Wayland windows, so `scripts/menu-launchers.sh` writes XWayland launcher overrides for a few apps (Dolphin, LibreWolf, Zen). Run it with `--remove` to undo.

**Dotfiles are symlinked, not copied**: `~/.config/hypr`, kitty, zsh and the GTK settings point into `dotfiles/`. Edit them in the repo. Hyprland uses the **Lua config** (0.55 or newer, `dotfiles/hypr/hyprland.lua`). Layer rules in `config/rules.lua` match the `cozytile-*` namespaces set through `WlrLayershell.namespace`, so a new layer window that should blur or animate needs its namespace added there. Machine-specific overrides go in the git-ignored `dotfiles/hypr/config/local.lua`.

## QML gotchas hit in this repo

- Don't name custom properties after built-in `Item` or window members (`top`, `scale`, and similar). It fails as "Cannot override FINAL property" and takes down the whole shell.
- Qt's `h` time format is 24-hour unless the format string also contains `AP`. Compute 12-hour values by hand.
- The desktop clock (`modules/clock/`) sits on `WlrLayer.Bottom` with an empty `mask: Region {}`, so it is behind windows and click-through. To see it in a screenshot you must temporarily move it to Overlay, because windows cover it.
