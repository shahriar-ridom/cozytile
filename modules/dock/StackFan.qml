import QtQuick
import "../../config"
import "../../services"
import "../../components"

// The Fan view: entries rise out of the stack's icon along a curve, newest nearest, each on a small card with its
// name beside it. They leave the icon one after another (stagger) and fold back into it on close. At most 8 entries
// (fewer when the screen is short), plus "Open Folder" at the top.
Item {
    id: fan

    required property var stack
    readonly property bool shown: stack.open && stack.view === "fan"
    property real t: shown ? 1 : 0
    Behavior on t { NumberAnimation { duration: fan.shown ? 480 : 240; easing.type: Easing.Linear } }
    visible: t > 0

    readonly property int tile: Math.round(Math.max(44, Math.min(64, stack.dock.iconSize)))
    readonly property real step: tile * 0.92
    readonly property real ax: stack.cx                               // the icon's centre
    readonly property real ay: stack.iconTop + stack.dock.iconSize / 2
    readonly property int dir: ax > stack.width / 2 ? -1 : 1          // lean toward the middle of the screen
    readonly property int fit: Math.max(1, Math.min(8, Math.floor((stack.iconTop - 40) / step) - 1))
    readonly property var list: {
        const it = stack.item;
        if (!it) return [];
        const l = stack.entries.slice(0, fit);
        if (it.dir !== "recent") l.push({ name: "Open Folder", path: it.dir, url: "", dir: true, size: 0, suffix: "", icon: "folder-open" });
        return l;
    }

    Repeater {
        model: fan.list
        Item {
            id: cell
            required property var modelData
            required property int index
            readonly property real p0: Math.max(0, Math.min(1, (fan.t - index * 0.05) / 0.5))
            readonly property real p: 1 - Math.pow(1 - p0, 3)
            readonly property real fx: fan.ax + fan.dir * fan.tile * 0.035 * index * index
            readonly property real fy: fan.stack.iconTop - 14 - fan.tile / 2 - index * fan.step
            width: fan.tile; height: fan.tile
            x: fan.ax + (fx - fan.ax) * p - width / 2
            y: fan.ay + (fy - fan.ay) * p - height / 2
            opacity: p
            scale: (0.4 + 0.6 * p) * (area.containsMouse ? 1.1 : 1)
            Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

            // the card leans a little more the higher it sits; its label stays level
            Item {
                anchors.fill: parent
                rotation: fan.dir * cell.index * 2 * cell.p
                Rectangle {
                    id: card
                    anchors.fill: parent
                    radius: Math.round(fan.tile * 0.24)
                    color: Theme.popupBg
                    border.width: Theme.frost ? 0 : 1
                    border.color: area.containsMouse ? Theme.accent : Theme.slash
                    StackThumb { anchors.centerIn: parent; size: parent.width - 10; entry: cell.modelData }
                }
                Shadowed { target: card; z: -1 }
            }

            Rectangle {
                id: label
                readonly property real room: fan.dir > 0 ? cell.x - 24 : fan.stack.width - cell.x - cell.width - 24
                width: Math.min(220, name.implicitWidth + 20); height: name.implicitHeight + 10
                x: fan.dir > 0 ? -width - 10 : cell.width + 10
                anchors.verticalCenter: parent.verticalCenter
                radius: Theme.radiusSmall + 2
                color: Theme.tooltipBg
                visible: room > 80
                Text {
                    id: name
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, 200)
                    text: cell.modelData.name
                    elide: Text.ElideMiddle
                    color: area.containsMouse ? Theme.accent : Theme.text
                    font.family: Theme.font; font.pixelSize: Theme.fontSize
                }
                TapHandler { onTapped: fan.stack.openEntry(cell.modelData) }
            }

            StackEntryArea {
                id: area
                anchors.fill: parent
                entry: cell.modelData
                grab: card
                enabled: fan.shown
                onOpened: fan.stack.openEntry(cell.modelData)
                onDragStarted: fan.stack.dragging = true
                onDragFinished: fan.stack.close()
            }
        }
    }
}
