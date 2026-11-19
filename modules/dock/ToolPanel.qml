import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../config"
import "../../services"
import "../../components"

// A quick tool opened from the dock: a card above the tool's icon holding that tool's panel (clipboard, screenshot,
// notes, system monitor). Same shape as FolderStack: a full-screen overlay that closes on any click outside the card
// or on Esc, kept mapped (transparent) so opening is instant. The panel is loaded only while the card is showing.
PanelWindow {
    id: tp

    required property var dock
    property string tool: ""
    property real cx: 0                  // icon centre and top, in dock window coordinates
    property real topY: 0
    property bool open: false
    readonly property real iconTop: height - dock.height + topY
    readonly property var files: ({ clipboard: "ClipboardPanel.qml", screenshot: "ShotPanel.qml", notes: "NotesPanel.qml", system: "SystemPanel.qml" })

    function openFor(id, x, y) {
        if (open && tool === id) { close(); return; }
        tool = id; cx = x; topY = y; open = true;
    }
    function close() { open = false; }

    visible: open || card.opacity > 0.01
    screen: dock.screen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "cozytile-dock-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    MouseArea { anchors.fill: parent; enabled: tp.open; acceptedButtons: Qt.AllButtons; onClicked: tp.close() }

    Rectangle {
        id: card
        width: (body.item ? body.item.width : 0) + 24
        height: (body.item ? body.item.height : 0) + 24
        x: Math.max(8, Math.min(tp.width - width - 8, tp.cx - width / 2))
        y: tp.iconTop - height - 10
        radius: Theme.radius
        color: Theme.popupBg
        border.width: Theme.frost ? 0 : 1
        border.color: Theme.slash
        opacity: tp.open ? 1 : 0
        scale: tp.open ? 1 : 0.9
        transformOrigin: Item.Bottom
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
        focus: tp.open
        Keys.onEscapePressed: tp.close()
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
        Shadowed { target: card; z: -1 }

        Loader {
            id: body
            x: 12; y: 12
            active: tp.open || card.opacity > 0.01
            source: tp.files[tp.tool] ?? ""
            onLoaded: item.host = tp
        }
    }
}
