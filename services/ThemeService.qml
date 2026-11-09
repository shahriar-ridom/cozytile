pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

// Optional wallpaper-derived palette via matugen. The built-in Everforest/Sakura themes are untouched:
// the result only fills Theme.wallpaperPalette, which adds a third, selectable "wallpaper" theme.
Singleton {
    id: root
    readonly property bool available: matugenCheck.found
    property string error: ""
    property bool _pending: false

    // Turn wallpaper-driven theming on/off. On: derive from the current wallpaper and switch to it.
    // Off: go back to the last built-in theme.
    function setTheming(on) {
        Settings.wallpaperTheming = on;
        Settings.save();
        if (on) {
            const mon = UiState.focusedScreen ? UiState.focusedScreen.name : "";
            const cur = WallpaperService.current(mon);
            if (cur) generate(cur);
        } else if (Theme.name === "wallpaper") {
            Theme.apply(Settings.baseTheme);
        }
    }

    readonly property string cacheFile: Settings.stateDir + "/cozytile/wallpaper-palette.json"

    function generate(path) {
        if (!available || gen.running) return;
        gen.command = ["matugen", "image", path, "--dry-run", "-j", "hex", "--prefer", "saturation", "-m", "dark", "-t", "scheme-tonal-spot"];
        gen.running = true;
    }

    function toPalette(json) {
        const c = json.colors;
        const g = k => (c[k] && c[k].dark ? c[k].dark.color : null);
        const p = {
            bg: g("surface"), bg2: g("surface_container"), bg3: g("surface_container_high"),
            dim: g("surface_container_lowest") || g("surface_dim"),
            fg: g("on_surface"), fg2: g("on_surface_variant"), muted: g("outline"),
            // light-on-dark roles only (the *_container roles are dark and unreadable as accents)
            green: g("tertiary"), aqua: g("tertiary_fixed") || g("tertiary"), blue: g("secondary"),
            yellow: g("primary"), orange: g("primary_fixed") || g("primary"),
            red: g("error"), purple: g("secondary_fixed") || g("secondary"),
            accent: g("primary"), workspaceActive: g("primary")
        };
        for (const k of Object.keys(p)) if (!p[k]) return null;
        return p;
    }

    Process {
        id: matugenCheck
        property bool found: false
        running: true
        command: ["sh", "-c", "command -v matugen"]
        stdout: StdioCollector { onStreamFinished: matugenCheck.found = text.trim().length > 0 }
    }

    Process {
        id: gen
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const pal = root.toPalette(JSON.parse(text));
                    if (!pal) { root.error = "matugen output incomplete"; return; }
                    Theme.wallpaperPalette = pal;
                    root.error = "";
                    root._pending = true;
                    cache.setText(JSON.stringify(pal));   // dotfile renderer reads this file; apply once it is on disk
                } catch (e) { root.error = "matugen: " + e; }
            }
        }
    }

    // Persist the last generated palette so the wallpaper theme survives restarts.
    FileView {
        id: cache
        path: root.cacheFile
        printErrors: false
        onLoaded: { try { Theme.wallpaperPalette = JSON.parse(text()); } catch (e) {} }
        onSaved: {
            if (root._pending) {
                root._pending = false;
                if (Settings.wallpaperTheming) Theme.apply("wallpaper");
            }
        }
    }
}
