pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Central theme + design tokens. No component may hardcode a colour.
Singleton {
    id: root

    // ---- selection -------------------------------------------------------
    // Name of the active theme. Set through Theme.apply(name) so it persists.
    property string name: "everforest"
    // Palette produced by matugen from the wallpaper (set by ThemeService), or null.
    property var wallpaperPalette: null

    readonly property var themeNames: wallpaperPalette ? ["everforest", "sakura", "wallpaper"] : ["everforest", "sakura"]
    readonly property var themeLabels: ({ everforest: "Everforest", sakura: "Sakura", wallpaper: "Wallpaper" })

    // ---- base palettes ---------------------------------------------------
    // Each palette defines raw colours; derived semantic roles are built below.
    // Canonical palettes live in palettes.json (shared with the dotfile renderer so they never drift).
    readonly property var builtin: {
        try { return JSON.parse(palettesFile.text()); } catch (e) { return { everforest: {} }; }
    }
    readonly property var palettes: Object.assign({}, builtin, { wallpaper: wallpaperPalette })
    FileView {
        id: palettesFile
        path: Quickshell.shellPath("config/palettes.json")
        blockLoading: true
    }

    readonly property var p: palettes[name] || palettes.everforest

    // ---- semantic colours ------------------------------------------------
    // bar: two tones, "cap" (dark end pieces) and "mid" (long section), as in Cozytile
    readonly property color barCap: p.dim
    readonly property color barMid: p.bg3
    readonly property color barText: p.fg
    readonly property color barTextDim: p.fg2
    readonly property color slash: Qt.rgba(p.fg.r, p.fg.g, p.fg.b, 0.14)
    readonly property color shadow: Qt.rgba(0, 0, 0, 0.38)

    readonly property color wsActive: p.workspaceActive
    readonly property color wsOccupied: p.fg2
    readonly property color wsEmpty: p.bg3
    readonly property color wsUrgent: p.red

    readonly property color accent: p.accent
    readonly property color text: p.fg
    readonly property color textDim: p.fg2
    readonly property color textMuted: p.muted
    readonly property color hover: Qt.rgba(p.fg.r, p.fg.g, p.fg.b, 0.09)
    readonly property color press: Qt.rgba(p.fg.r, p.fg.g, p.fg.b, 0.16)

    readonly property color surface: p.bg
    readonly property color surfaceAlt: p.bg2
    readonly property color surfaceHigh: p.bg3
    readonly property color border: p.bg3
    readonly property color popupBg: p.bg
    readonly property color tooltipBg: p.dim
    readonly property color launcherBg: p.bg
    readonly property color notifBg: p.bg
    readonly property color notifBorder: p.bg3
    readonly property color osdBg: p.bg
    readonly property color osdTrack: p.bg3
    readonly property color osdFill: p.accent

    readonly property color good: p.green
    readonly property color info: p.blue
    readonly property color warn: p.yellow
    readonly property color caution: p.orange
    readonly property color bad: p.red
    readonly property color special: p.purple

    // ---- typography ------------------------------------------------------
    readonly property string defaultFont: "SF Pro Text"
    readonly property string defaultFontMono: "CaskaydiaCove Nerd Font Mono"
    readonly property string font: Settings.uiFont || defaultFont
    readonly property string iconFont: "CaskaydiaCove Nerd Font"
    readonly property string fontMono: Settings.monoFont || defaultFontMono
    readonly property int fontSize: 12
    readonly property int fontSmall: 10
    readonly property int fontLarge: 15
    readonly property int fontTitle: 20
    readonly property int iconSize: 14

    // ---- metrics ---------------------------------------------------------
    readonly property int barHeight: 30
    readonly property int barMarginTop: 8
    readonly property int barMarginSide: 40
    readonly property int barMarginBottom: 6
    readonly property int barPad: 16             // transparent room around the bar window so shadows are not clipped
    readonly property int barOriginX: barMarginSide - barPad   // screen x of the bar window's left edge
    readonly property int barRadius: 10          // outer corners of the bar
    readonly property int edgeSlant: 9           // horizontal travel of slash / S-curve separators
    readonly property int gap: 8
    readonly property int pad: 12
    readonly property int radius: 8              // popups, cards
    readonly property int radiusSmall: 5
    readonly property int shadowRadius: 12
    // dynamic island
    readonly property int islandMaxWidth: 340       // collapsed pill upper bound
    readonly property int islandExpandedWidth: 460

    // ---- motion ----------------------------------------------------------
    readonly property int animFast: 110
    readonly property int animNormal: 180
    readonly property int animSlow: 260

    onWallpaperPaletteChanged: { if (wallpaperPalette && Settings.theme === "wallpaper") name = "wallpaper"; }

    // ---- API -------------------------------------------------------------
    function apply(n) {
        if (themeNames.indexOf(n) < 0) return;
        name = n;
        Settings.theme = n;
        if (n !== "wallpaper") Settings.baseTheme = n;
        if (Settings.syncDotfiles)
            Quickshell.execDetached([Quickshell.shellPath("dotfiles/theme-apply.sh"), n, "--dotfiles-only"]);
    }
    // Push the chosen fonts to the rest of the desktop (GTK, kitty, hyprlock) by re-rendering the dotfiles.
    function applyFonts() {
        if (Settings.syncDotfiles)
            Quickshell.execDetached([Quickshell.shellPath("dotfiles/theme-apply.sh"), name, "--dotfiles-only", "--fonts"]);
    }
    function next() {
        const i = themeNames.indexOf(name);
        apply(themeNames[(i + 1) % themeNames.length]);
    }

    // Follow persisted selection (including external edits of settings.json).
    Connections {
        target: Settings
        function onThemeChanged() {
            if (root.themeNames.indexOf(Settings.theme) >= 0 && root.name !== Settings.theme)
                root.name = Settings.theme;
        }
        function onLoadedChanged() { if (Settings.loaded) root.name = Settings.theme; }
    }
}
