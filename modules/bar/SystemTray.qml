import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../../config"
import "../../components"

Row {
    id: root
    spacing: 4
    readonly property bool hasItems: SystemTray.items.values.length > 0
    Repeater {
        model: SystemTray.items
        delegate: Item {
            id: cell
            required property var modelData
            width: 20; height: 20
            anchors.verticalCenter: parent.verticalCenter
            HoverArea { anchors.fill: parent; radius: 6
                onClicked: m => {
                    if (m.button === Qt.RightButton && cell.modelData.hasMenu) {
                        const pos = cell.mapToItem(null, 0, cell.height);
                        cell.modelData.display(QsWindow.window, pos.x, pos.y + 6);
                    } else if (m.button === Qt.MiddleButton) cell.modelData.secondaryActivate();
                    else if (cell.modelData.onlyMenu && cell.modelData.hasMenu) {
                        const pos = cell.mapToItem(null, 0, cell.height);
                        cell.modelData.display(QsWindow.window, pos.x, pos.y + 6);
                    } else cell.modelData.activate();
                }
            }
            Image {
                id: ico
                anchors.centerIn: parent
                width: 14; height: 14
                sourceSize: Qt.size(28, 28)
                // themed names are verified first; an unresolvable theme icon would render a checkerboard
                readonly property string raw: cell.modelData.icon
                readonly property bool themed: raw.startsWith("image://icon/")
                source: themed && Quickshell.iconPath(raw.slice(13).split("?")[0], true) === "" ? "" : raw
                smooth: true
                asynchronous: true
                visible: source !== "" && status === Image.Ready
            }
            // Fallback when the tray icon cannot be resolved from the icon theme.
            Glyph {
                anchors.centerIn: parent
                visible: ico.source == "" || ico.status !== Image.Ready
                text: "\uf111"; size: 8; color: Theme.barTextDim
            }
        }
    }
}
