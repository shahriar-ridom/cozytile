import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../config"
import "../../components"
import "../audio"
import "../../services"

PanelWindow {
    id: win

    anchors { top: true; left: true; right: true }
    margins { top: Theme.barMarginTop; left: Theme.barMarginSide; right: Theme.barMarginSide }
    implicitHeight: Theme.barHeight + 16
    mask: Region { item: bar }
    exclusiveZone: Theme.barHeight + Theme.barMarginBottom
    color: "transparent"
    WlrLayershell.namespace: "cozytile-bar"
    WlrLayershell.layer: WlrLayer.Top

    // Responsive levels: shed optional pieces as the bar narrows.
    readonly property int w: width
    readonly property bool wide: w >= 1500      // + network and temperature
    readonly property bool medium: w >= 1150    // + search cap, CPU/RAM
    readonly property int islandMax: Math.round(Math.max(200, Math.min(Theme.islandMaxWidth, w * 0.28)))

    Item {
        id: bar
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: Theme.barHeight

        // Base tone, full width. Caps sit on top of it.
        Rectangle {
            id: base
            anchors.fill: parent
            radius: Theme.barRadius
            color: Theme.barMid
            Behavior on color { ColorAnimation { duration: Theme.animNormal } }
        }
        Shadowed { target: base; z: -1 }

        // right-click anywhere on the bar opens settings (interactive items sit above this)
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: UiState.toggle("settings")
        }

        // ---- left -------------------------------------------------------
        Row {
            id: left
            anchors.left: parent.left
            height: parent.height
            Segment {
                leftEdge: "round"; rightEdge: "curve"; padding: 14
                Item {
                    width: 18; height: Theme.barHeight
                    LogoMark { anchors.centerIn: parent }
                    HoverArea {
                        anchors.fill: parent; anchors.margins: -6; highlight: false
                        onClicked: m => m.button === Qt.RightButton ? UiState.toggle("power")
                                 : m.button === Qt.MiddleButton ? UiState.toggle("wallpaper") : UiState.toggle("launcher")
                    }
                }
            }
            Item { width: 4; height: 1 }
            Segment {
                tone: Theme.barMid; padding: 6
                WorkspaceIndicator { screen: win.screen; anchors.verticalCenter: parent.verticalCenter }
            }
            Slash { visible: win.medium }
            // Search cap: dark piece with S-curved ends, opens the launcher (Cozytile's "Search")
            Segment {
                visible: win.medium
                leftEdge: "curve"; rightEdge: "curve"; padding: 14
                Item {
                    width: searchRow.implicitWidth; height: Theme.barHeight
                    Row {
                        id: searchRow; anchors.centerIn: parent; spacing: 8
                        Glyph { text: "\uf002"; color: Theme.barTextDim; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "Search"; color: Theme.barText; anchors.verticalCenter: parent.verticalCenter
                            font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true }
                    }
                    HoverArea { anchors.fill: parent; anchors.margins: -6; highlight: false; onClicked: UiState.toggle("launcher") }
                }
            }
        }

        // ---- centre: active window title ---------------------------------
        WindowTitle {
            visible: Settings.showWindowTitle && win.medium
            anchors.verticalCenter: parent.verticalCenter
            x: left.width + 18
            width: Math.max(0, (win.w - win.islandMax) / 2 - 14 - x)
        }

        // ---- right ------------------------------------------------------
        Row {
            id: right
            anchors.right: parent.right
            height: parent.height
            Segment {
                visible: tray.hasItems
                leftEdge: "curve"; rightEdge: "curve"; padding: 12
                SystemTray { id: tray; anchors.verticalCenter: parent.verticalCenter }
            }
            Segment {
                tone: Theme.barMid; padding: 4
                SystemStats { visible: win.medium; showTemp: win.wide }
                Slash { visible: win.medium }
                NetworkItem { visible: win.wide; width: visible ? implicitWidth : 0 }
                Slash { visible: win.wide }
                AudioWidget { onOpenPicker: UiState.toggle("audioPicker") }
                Slash { visible: BatteryService.present }
                BatteryItem {}
            }
            Segment {
                leftEdge: "curve"; rightEdge: "round"; padding: 10
                Clock {}
            }
        }
    }
}
