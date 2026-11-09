import QtQuick
import Quickshell.Hyprland
import "../../config"
import "../../components"
import "../../services"

// Dots for workspaces 1..N, driven by Hyprland's event stream (no polling).
Row {
    id: root
    required property var screen
    property int minCount: 5
    readonly property var monitor: Hyprland.monitorFor(screen)

    // highest workspace id in use, so dots never hide an occupied workspace
    readonly property int count: {
        let m = minCount;
        for (const w of Hyprland.workspaces.values) if (w.id > m) m = w.id;
        return m;
    }
    spacing: 0

    function byId(id) {
        for (const w of Hyprland.workspaces.values) if (w.id === id) return w;
        return null;
    }

    Repeater {
        model: root.count
        delegate: Item {
            id: dot
            required property int index
            readonly property int wsId: index + 1
            readonly property var ws: root.byId(wsId)
            readonly property bool active: root.monitor && root.monitor.activeWorkspace && root.monitor.activeWorkspace.id === wsId
            readonly property bool occupied: ws && ws.toplevels && ws.toplevels.values.length > 0
            readonly property bool urgent: ws && ws.urgent

            width: 24; height: Theme.barHeight

            Rectangle {
                anchors.centerIn: parent
                width: dot.active ? 12 : 10
                height: width
                radius: width / 2
                color: dot.urgent ? Theme.wsUrgent : dot.active ? Theme.wsActive : dot.occupied ? Theme.wsOccupied : Theme.wsEmpty
                Behavior on width { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: Theme.animNormal } }
            }
            Text {
                visible: Settings.showWorkspaceNumbers
                anchors.centerIn: parent
                text: dot.wsId
                font.family: Theme.font
                font.pixelSize: 8
                font.bold: true
                color: Theme.barCap
            }
            HoverArea {
                anchors.fill: parent
                highlight: false
                onClicked: m => HyprlandService.focusWorkspace(dot.wsId)
            }
        }
    }
    // scroll to switch
    WheelHandler {
        onWheel: e => HyprlandService.stepWorkspace(e.angleDelta.y > 0 ? -1 : 1)
    }
}
