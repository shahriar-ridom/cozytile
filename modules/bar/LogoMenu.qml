import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../config"
import "../../services"

// Dropdown under the bar's logo: About / Settings, Recent Apps / Recent Files (flyouts), window + compositor
// actions, then power actions in two groups.
// Reuses MenuList for the rows. Force Quit, Restart, Shut Down and Log Out ask for a second click:
// the row turns into "Confirm ...".
PanelWindow {
    id: win
    screen: UiState.focusedScreen
    visible: UiState.logoMenu || card.opacity > 0.01
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "cozytile-logomenu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: UiState.logoMenu ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    readonly property real top: Theme.barMarginTop + Theme.barHeight + 4
    // the bar stays clickable so the logo can toggle the menu closed
    mask: Region { x: 0; y: win.top; width: win.width; height: Math.max(0, win.height - win.top) }
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: UiState.logoMenu = false }

    // ---- focused window, read once when the menu opens (the menu itself never takes Hyprland focus) ----
    property int winPid: 0
    property string winName: ""
    Process {
        id: probe
        command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const w = JSON.parse(text);
                    win.winPid = w.pid > 0 ? w.pid : 0;
                    win.winName = w.class || w.initialClass || "";
                } catch (e) { win.winPid = 0; win.winName = ""; }
            }
        }
    }

    // locker: the themed hyprlock script (as hypridle uses), else logind
    readonly property string lockCmd: "[ -x \"$HOME/.config/hypr/scripts/lock.sh\" ] && exec \"$HOME/.config/hypr/scripts/lock.sh\"; exec loginctl lock-session"

    property int pending: 0         // id of the row awaiting confirmation
    readonly property var actions: ({
        1: { run: () => { UiState.closeAll(); UiState.settingsPage = "about"; UiState.settings = true; } },
        2: { run: () => { UiState.closeAll(); UiState.settingsPage = ""; UiState.settings = true; } },
        3: { confirm: true, run: () => { if (win.winPid > 0) Quickshell.execDetached(["kill", "-9", String(win.winPid)]); } },
        4: { run: () => { Quickshell.execDetached(["hyprctl", "reload"]); Quickshell.reload(false); } },
        5: { run: () => Quickshell.execDetached(["sh", "-c", win.lockCmd]) },
        6: { run: () => Quickshell.execDetached(["systemctl", "suspend"]) },
        7: { confirm: true, run: () => Quickshell.execDetached(["systemctl", "reboot"]) },
        8: { run: () => Quickshell.execDetached(["systemctl", "hibernate"]) },
        9: { confirm: true, run: () => Quickshell.execDetached(["systemctl", "poweroff"]) },
        10: { confirm: true, run: () => Quickshell.execDetached(["sh", "-c", "hyprctl dispatch exit || loginctl terminate-user $USER"]) }
    })
    // flyout rows: ids 100+ are recent apps, 200+ recent files (index into the service lists)
    readonly property int appBase: 100
    readonly property int fileBase: 200

    function row(id, label, enabled) {
        return { id: id, label: pending === id ? "Confirm " + label : label, shortcut: "", children: [],
                 enabled: enabled !== false, toggle: "", state: 0, sep: false };
    }
    readonly property var sepRow: ({ id: -1, label: "", shortcut: "", children: [], enabled: false, toggle: "", state: 0, sep: true })
    function leaf(id, label, enabled) {
        return { id: id, label: label, shortcut: "", children: [], enabled: enabled !== false, toggle: "", state: 0, sep: false };
    }
    function flyout(id, label, kids, emptyText) {
        return { id: id, label: label, shortcut: "", enabled: true, toggle: "", state: 0, sep: false,
                 children: kids.length ? kids : [leaf(-2, emptyText, false)] };
    }
    readonly property var model: [
        row(1, "About This System"),
        row(2, "System Settings…"),
        sepRow,
        flyout(20, "Recent Apps", RecentService.apps.map((a, i) => leaf(appBase + i, a.name)), "No recent apps"),
        flyout(21, "Recent Files", RecentService.files.map((f, i) => leaf(fileBase + i, f.name)), "No recent files"),
        sepRow,
        row(3, winPid > 0 ? "Force Quit " + winName : "Force Quit", winPid > 0),
        row(4, "Reload Hyprland"),
        sepRow,
        row(5, "Lock Screen"),
        row(6, "Sleep"),
        row(8, "Hibernate"),
        sepRow,
        row(10, "Log Out"),
        row(7, "Restart"),
        row(9, "Shut Down")
    ]

    function activate(id) {
        const a = actions[id];
        if (id >= fileBase) { UiState.logoMenu = false; RecentService.openFile(RecentService.files[id - fileBase].path); return; }
        if (id >= appBase) { UiState.logoMenu = false; RecentService.launchApp(RecentService.apps[id - appBase].cls); return; }
        if (!a) return;
        if (a.confirm && pending !== id) { pending = id; return; }
        UiState.logoMenu = false;
        a.run();
    }

    property bool shown: false
    Component.onCompleted: { probe.running = true; RecentService.refreshFiles(); shown = Qt.binding(() => UiState.logoMenu); }
    readonly property bool busy: visible

    MenuList {
        id: card
        model: win.model
        limitX: win.width
        maxH: win.height - win.top - 16
        x: Math.max(8, Math.min(win.width - width - 8, UiState.logoMenuX))
        y: win.top + (win.shown ? 0 : -4)
        opacity: win.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
        Behavior on y { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
        focus: true
        Keys.onEscapePressed: win.pending !== 0 ? win.pending = 0 : UiState.logoMenu = false
        onActivated: id => win.activate(id)
    }
}
