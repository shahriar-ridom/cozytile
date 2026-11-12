//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import "config"
import "services"
import "modules/bar"
import "modules/launcher"
import "modules/search"
import "modules/island"
import "modules/audio"
import "modules/power"
import "modules/settings"
import "modules/wallpaper"

ShellRoot {
    // singletons load lazily; night light must run its schedule from startup
    Component.onCompleted: NightLightService.tick()

    // ---- keybind entry points: `qs -c cozytile ipc call <target> <function>` ----
    IpcHandler {
        target: "launcher"
        function toggle(): void { UiState.toggle("launcher"); }
        function open(): void { UiState.closeAll(); UiState.launcher = true; }
        // open pre-filled, e.g. `ipc call launcher search "5 km to miles"`
        function search(text: string): void { UiState.closeAll(); UiState.launcherQuery = text; UiState.launcher = true; }
        function close(): void { UiState.launcher = false; }
        // launch by desktop-entry id, e.g. `ipc call launcher launch org.gnome.Calculator`
        function launch(id: string): bool {
            const e = DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id);
            if (!e) return false;
            e.execute();
            return true;
        }
    }
    IpcHandler {
        target: "search"
        function toggle(): void { UiState.toggleSearch(UiState.searchX); }
        function close(): void { UiState.search = false; }
    }
    IpcHandler {
        target: "notifications"
        function toggle(): void { UiState.toggleIsland(); }     // notifications live in the island
        function clear(): void { NotificationService.clearAll(); }
        function dnd(): void { NotificationService.toggleDnd(); }
    }
    IpcHandler {
        target: "island"
        function toggle(): void { UiState.toggleIsland(); }
        function close(): void { UiState.islandOpenOn = ""; }
    }
    IpcHandler {
        target: "timer"
        // spec: 5m, 90s, 1h30m, 25:00; a bare number means minutes
        function start(spec: string): bool { return TimerService.start(TimerService.parse(spec), ""); }
        function stop(): void { TimerService.stop(); }
        function toggle(): void { TimerService.toggle(); }
        function add(spec: string): void { TimerService.add(TimerService.parse(spec)); }
        function status(): string { return TimerService.active ? TimerService.format(TimerService.remaining) + (TimerService.paused ? " (paused)" : "") : "idle"; }
    }
    IpcHandler {
        target: "keys"
        // called by Hyprland binds on Caps/Num/Scroll lock; re-reads the lock state
        function refresh(): void { LockKeysService.refresh(); }
        // debug: pretend a lock changed (which = caps|num|scroll)
        function test(which: string, on: bool): void {
            LockKeysService._apply(which === "caps" ? on : LockKeysService.caps, which === "num" ? on : LockKeysService.num, which === "scroll" ? on : LockKeysService.scroll);
        }
    }
    IpcHandler {
        target: "power"
        function toggle(): void { UiState.toggle("power"); }
    }
    IpcHandler {
        target: "settings"
        function toggle(): void { UiState.toggle("settings"); }
        // open on a page: appearance | bar | general | display | windows | input | autostart | power | about
        function open(page: string): void { UiState.closeAll(); UiState.settingsPage = page; UiState.settings = true; }
    }
    IpcHandler {
        target: "wallpaper"
        function toggle(): void { UiState.toggle("wallpaper"); }
        function set(path: string): void { WallpaperService.set(path, ""); }
        // theme the whole desktop from the wallpaper: on | off | toggle
        function theming(mode: string): void { ThemeService.setTheming(mode === "toggle" ? !Settings.wallpaperTheming : mode === "on"); }
    }
    IpcHandler {
        target: "workspace"
        function goto(id: int): void { HyprlandService.focusWorkspace(id); }
        function next(): void { HyprlandService.stepWorkspace(1); }
        function prev(): void { HyprlandService.stepWorkspace(-1); }
    }
    IpcHandler {
        target: "theme"
        function next(): void { Theme.next(); }
        function set(name: string): void { Theme.apply(name); }
        function get(): string { return Theme.name; }
        // derive the optional "wallpaper" theme from an image (matugen), without touching other themes
        function fromImage(path: string): void { ThemeService.generate(path); }
    }
    IpcHandler {
        target: "nightlight"
        function toggle(): void { NightLightService.toggle(); }
        function on(): void { NightLightService.set({ enabled: true }); }
        function off(): void { NightLightService.set({ enabled: false }); }
        // kelvin, e.g. 4000 (lower is warmer)
        function temperature(k: int): void { NightLightService.setTemperature(k); }
        // software dimming, 20..100 percent
        function dim(percent: int): void { NightLightService.setGamma(percent); }
        function status(): string { return NightLightService.status + " · " + NightLightService.temperature + " K · " + NightLightService.gamma + "%"; }
    }
    IpcHandler {
        target: "audio"
        function up(): void { AudioService.changeVolume(0.05); }
        function down(): void { AudioService.changeVolume(-0.05); }
        function mute(): void { AudioService.toggleMute(); }
        function micMute(): void { AudioService.toggleMic(); }
    }
    IpcHandler {
        target: "brightness"
        function up(): void { BrightnessService.change("brightness", 5); }
        function down(): void { BrightnessService.change("brightness", -5); }
        function kbdUp(): void { BrightnessService.change("kbd", 10); }
        function kbdDown(): void { BrightnessService.change("kbd", -10); }
    }

    // ---- per-screen bar (follows monitor hotplug) ----
    Variants {
        model: Quickshell.screens
        Bar { required property var modelData; screen: modelData }
    }

    // ---- dynamic island (one per screen; hides itself on narrow screens) ----
    Variants {
        model: Quickshell.screens
        Island { required property var modelData; screen: modelData }
    }

    // ---- overlays (live on the focused screen) ----
    // Each overlay window exists only while open or fading out: the loader activates on open,
    // the window holds it via `held` until its close animation ends, then it is destroyed.
    // Hidden windows otherwise keep their whole item tree, scene graph and bindings alive.
    LazyLoader { id: launcherL; property bool held: false; active: UiState.launcher || held
        Launcher { id: launcherW; Component.onCompleted: launcherL.held = Qt.binding(() => launcherW.busy) } }
    LazyLoader { id: searchL; property bool held: false; active: UiState.search || held
        BarSearch { id: searchW; Component.onCompleted: searchL.held = Qt.binding(() => searchW.busy) } }
    LazyLoader { id: audioL; property bool held: false; active: UiState.audioPicker || held
        AudioPicker { id: audioW; Component.onCompleted: audioL.held = Qt.binding(() => audioW.visible) } }
    LazyLoader { id: statL; property bool held: false; active: UiState.statPopup !== "" || held
        StatPopup { id: statW; Component.onCompleted: statL.held = Qt.binding(() => statW.visible) } }
    LazyLoader { id: settingsL; property bool held: false; active: UiState.settings || held
        SettingsPanel { id: settingsW; Component.onCompleted: settingsL.held = Qt.binding(() => settingsW.visible) } }
    LazyLoader { id: powerL; property bool held: false; active: UiState.power || held
        PowerMenu { id: powerW; Component.onCompleted: powerL.held = Qt.binding(() => powerW.visible) } }
    LazyLoader { id: wallpaperL; property bool held: false; active: UiState.wallpaper || held
        WallpaperSelector { id: wallpaperW; Component.onCompleted: wallpaperL.held = Qt.binding(() => wallpaperW.visible) } }
}
