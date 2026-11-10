import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../config"
import "../../services"
import "../../components"

// Lock / Logout / Suspend / Reboot / Shutdown. Destructive ones ask for confirmation first.
PanelWindow {
    id: win
    screen: UiState.focusedScreen
    visible: UiState.power || card.opacity > 0.01
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "cozytile-power"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: UiState.power ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Locker detection: hyprlock if installed, otherwise logind's lock-session.
    property string lockCmd: "loginctl lock-session"
    Process {
        running: true
        command: ["sh", "-c", "command -v hyprlock >/dev/null && echo hyprlock || { command -v swaylock >/dev/null && echo swaylock; } || true"]
        stdout: StdioCollector { onStreamFinished: { const t = text.trim(); if (t) win.lockCmd = t; } }
    }

    readonly property var actions: [
        { id: "lock",     label: "Lock",     icon: "", confirm: false, cmd: () => win.lockCmd },
        { id: "logout",   label: "Logout",   icon: "", confirm: true,  cmd: () => "hyprctl dispatch exit || loginctl terminate-user $USER" },
        { id: "suspend",  label: "Suspend",  icon: "", confirm: false, cmd: () => "systemctl suspend" },
        { id: "reboot",   label: "Reboot",   icon: "", confirm: true,  cmd: () => "systemctl reboot" },
        { id: "shutdown", label: "Shutdown", icon: "", confirm: true,  cmd: () => "systemctl poweroff" }
    ]
    property int index: 0
    property int pending: -1      // index awaiting confirmation

    function run(i) {
        const a = actions[i];
        if (a.confirm && pending !== i) { pending = i; return; }
        UiState.power = false;
        pending = -1;
        Quickshell.execDetached(["sh", "-c", a.cmd()]);
    }
    function close() { pending = -1; UiState.power = false; }

    // false at creation, then follows the open state, so the open animation still plays
    // when the window is created already open (see the LazyLoader in shell.qml)
    property bool shown: false
    function opened() { win.index = 0; win.pending = -1; keys.forceActiveFocus(); }
    Component.onCompleted: { shown = Qt.binding(() => UiState.power); if (UiState.power) opened(); }
    Connections {
        target: UiState
        function onPowerChanged() { if (UiState.power) win.opened(); }
    }

    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.35); opacity: win.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } } }
    MouseArea { anchors.fill: parent; onClicked: win.close() }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: win.pending >= 0 ? win.pending = -1 : win.close()
        Keys.onLeftPressed: { win.pending = -1; win.index = (win.index + win.actions.length - 1) % win.actions.length; }
        Keys.onRightPressed: { win.pending = -1; win.index = (win.index + 1) % win.actions.length; }
        Keys.onReturnPressed: win.run(win.index)
        Keys.onEnterPressed: win.run(win.index)
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: row.width + 40; height: 150
        radius: Theme.radius + 6
        color: Theme.popupBg
        border.width: 1; border.color: Theme.border
        opacity: win.shown ? 1 : 0
        scale: win.shown ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent }
        Shadowed { target: card; z: -1 }

        Row {
            id: row
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -8
            spacing: 10
            Repeater {
                model: win.actions
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool sel: win.index === index
                    readonly property bool asking: win.pending === index
                    width: 84; height: 84; radius: Theme.radius + 2
                    color: asking ? Theme.bad : sel ? Theme.surfaceHigh : (m.containsMouse ? Theme.hover : Theme.surfaceAlt)
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Column {
                        anchors.centerIn: parent; spacing: 8
                        Glyph { anchors.horizontalCenter: parent.horizontalCenter; size: 24; text: modelData.icon
                            color: asking ? Theme.barCap : sel ? Theme.accent : Theme.text }
                        Text { anchors.horizontalCenter: parent.horizontalCenter
                            text: asking ? "Confirm?" : modelData.label
                            color: asking ? Theme.barCap : Theme.textDim
                            font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1; font.bold: true }
                    }
                    MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onEntered: win.index = index
                        onClicked: win.run(index) }
                }
            }
        }
        Text {
            anchors { bottom: parent.bottom; bottomMargin: 12; horizontalCenter: parent.horizontalCenter }
            text: win.pending >= 0 ? "Press Enter again (or click) to confirm · Esc cancels" : "← → select · Enter run · Esc close"
            color: Theme.textMuted
            font.family: Theme.font; font.pixelSize: Theme.fontSmall
        }
    }
}
