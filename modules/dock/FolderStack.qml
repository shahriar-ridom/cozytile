import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../config"
import "../../services"
import "../../components"

// A folder stack opened from the dock: Fan (entries arc up out of the icon), Grid or List (a card above the icon).
// Like the right-click menu it is a full-screen overlay that catches every click outside the content and closes
// itself; Esc closes it too. It stays mapped (transparent) so opening is instant. Clicking an entry opens it with
// the default app; dragging one out hands the file to whatever app it is dropped on (the overlay turns click-through
// for the drag, so the drop reaches the app underneath).
PanelWindow {
    id: stack

    required property var dock
    property string key: ""
    property real cx: 0                  // icon centre and top, in dock window coordinates
    property real topY: 0
    property bool open: false
    property bool dragging: false
    readonly property var item: { const k = key; return DockService.items.find(i => i.key === k) ?? null; }
    readonly property string view: item ? item.view : "grid"
    readonly property var entries: source.entries
    readonly property real iconTop: height - dock.height + topY      // the dock window sits at the bottom of the screen

    property bool confirming: false      // the Trash asks before emptying
    readonly property bool trash: item ? !!item.trash : false
    function openFor(it, x, y, ask) {
        if (open && key === it.key && !ask) { close(); return; }
        key = it.key; cx = x; topY = y; open = true; confirming = !!ask;
        source.refresh();
    }
    function close() { open = false; dragging = false; confirming = false; }
    function openEntry(e) { close(); FolderService.open(e.path); }
    onItemChanged: if (open && !item) close()

    StackSource { id: source; path: stack.item ? stack.item.dir : ""; more: stack.item ? stack.item.more ?? [] : []; sort: stack.item ? stack.item.sort : "modified"; showHidden: stack.trash }

    visible: open || card.opacity > 0.01 || fan.visible
    screen: dock.screen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "cozytile-dock-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: Region { item: stack.dragging ? idle : whole }
    Item { id: idle }
    Item { id: whole; anchors.fill: parent }
    MouseArea { anchors.fill: parent; enabled: stack.open; acceptedButtons: Qt.AllButtons; onClicked: stack.close() }
    Item { focus: stack.open; Keys.onEscapePressed: stack.close() }

    StackFan { id: fan; anchors.fill: parent; stack: stack }

    // ---- grid / list ----
    readonly property int cellW: 92
    readonly property int cellH: 104
    readonly property int rowH: 36
    readonly property int cols: 5
    readonly property int count: entries.length
    readonly property int total: source.total          // the header counts everything, not just the entries read
    readonly property real bodyW: view === "list" ? 380 : cols * cellW
    readonly property real bodyH: view === "list" ? Math.max(rowH * 2, Math.min(9, count) * rowH)
        : Math.max(cellH, Math.min(4, Math.ceil(count / cols)) * cellH)

    Rectangle {
        id: card
        readonly property bool shown: stack.open && stack.view !== "fan"
        width: stack.bodyW + 20
        height: 10 + 34 + 4 + stack.bodyH + 10
        x: Math.max(8, Math.min(stack.width - width - 8, stack.cx - width / 2))
        y: stack.iconTop - height - 10
        radius: Theme.radius
        color: Theme.popupBg
        border.width: Theme.frost ? 0 : 1
        border.color: Theme.slash
        opacity: shown ? 1 : 0
        scale: shown ? 1 : 0.9
        transformOrigin: Item.Bottom
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
        Shadowed { target: card; z: -1 }

        // header: name, count, open the folder
        Item {
            x: 10; y: 10
            width: parent.width - 20; height: 34
            Text {
                id: title
                visible: !stack.confirming         // the confirm row replaces the header (popupBg can be translucent)
                anchors.verticalCenter: parent.verticalCenter
                x: 6
                text: stack.item ? stack.item.name : ""
                color: Theme.text
                font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.bold: true
            }
            Text {
                visible: !stack.confirming
                anchors { left: title.right; leftMargin: 8; baseline: title.baseline }
                text: stack.total + (stack.total === 1 ? " item" : " items")
                color: Theme.textMuted
                font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1
            }
            Rectangle {
                visible: !stack.confirming && stack.item !== null && stack.item.dir !== "recent" && (!stack.trash || stack.total > 0)
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: openText.implicitWidth + 20; height: 26
                radius: Theme.radiusSmall + 2
                color: openArea.containsMouse ? Theme.hover : "transparent"
                Text {
                    id: openText
                    anchors.centerIn: parent
                    text: stack.trash ? "Empty Trash" : "Open Folder"
                    color: openArea.containsMouse ? (stack.trash ? Theme.wsUrgent : Theme.accent) : Theme.textMuted
                    font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1
                }
                MouseArea {
                    id: openArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { if (stack.trash) stack.confirming = true; else { stack.close(); FolderService.openFolder(stack.item.path); } }
                }
            }
            // emptying the Trash is permanent: ask first
            Rectangle {
                visible: stack.confirming
                anchors.fill: parent
                radius: Theme.radiusSmall + 2
                color: Theme.popupBg
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 6
                    text: "Delete " + stack.total + (stack.total === 1 ? " item" : " items") + " for good?"
                    color: Theme.text
                    font.family: Theme.font; font.pixelSize: Theme.fontSize
                }
                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 6
                    Repeater {
                        model: [{ label: "Cancel", danger: false }, { label: "Empty", danger: true }]
                        Rectangle {
                            required property var modelData
                            width: btn.implicitWidth + 20; height: 26
                            radius: Theme.radiusSmall + 2
                            color: btnArea.containsMouse ? (modelData.danger ? Theme.wsUrgent : Theme.press) : Theme.hover
                            Text {
                                id: btn
                                anchors.centerIn: parent
                                text: modelData.label
                                color: btnArea.containsMouse && modelData.danger ? Theme.popupBg : Theme.text
                                font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1
                            }
                            MouseArea {
                                id: btnArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { if (modelData.danger) DockService.emptyTrash(); stack.confirming = false; if (modelData.danger) stack.close(); }
                            }
                        }
                    }
                }
            }
        }

        Text {
            visible: stack.count === 0
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 20
            text: stack.trash ? "Trash is empty" : "Nothing here"
            color: Theme.textMuted
            font.family: Theme.font; font.pixelSize: Theme.fontSize
        }

        GridView {
            visible: stack.view === "grid"
            x: 10; y: 48
            width: stack.bodyW; height: stack.bodyH
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            cellWidth: stack.cellW; cellHeight: stack.cellH
            model: stack.view === "grid" ? stack.entries : []
            delegate: Item {
                id: cell
                required property var modelData
                width: stack.cellW; height: stack.cellH
                Rectangle {
                    anchors { fill: parent; margins: 3 }
                    radius: Theme.radius
                    color: area.containsMouse ? Theme.hover : "transparent"
                }
                StackThumb { id: thumb; x: (parent.width - size) / 2; y: 10; size: 56; entry: cell.modelData }
                Text {
                    x: 6; y: 72
                    width: parent.width - 12; height: 28
                    text: cell.modelData.name
                    wrapMode: Text.WrapAnywhere
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.text
                    font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1
                }
                StackEntryArea {
                    id: area
                    anchors.fill: parent
                    entry: cell.modelData
                    grab: thumb
                    onOpened: stack.openEntry(cell.modelData)
                    onDragStarted: stack.dragging = true
                    onDragFinished: stack.close()
                }
            }
        }

        ListView {
            visible: stack.view === "list"
            x: 10; y: 48
            width: stack.bodyW; height: stack.bodyH
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: stack.view === "list" ? stack.entries : []
            delegate: Item {
                id: row
                required property var modelData
                width: stack.bodyW; height: stack.rowH
                Rectangle {
                    anchors { fill: parent; topMargin: 1; bottomMargin: 1 }
                    radius: Theme.radiusSmall + 2
                    color: area.containsMouse ? Theme.hover : "transparent"
                }
                StackThumb { id: thumb; x: 8; anchors.verticalCenter: parent.verticalCenter; size: 24; entry: row.modelData }
                Text {
                    x: 42; width: parent.width - 42 - 150
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.name
                    elide: Text.ElideMiddle
                    color: Theme.text
                    font.family: Theme.font; font.pixelSize: Theme.fontSize
                }
                Text {
                    x: parent.width - 148; width: 56
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    text: row.modelData.dir || row.modelData.size === 0 ? "" : FolderService.sizeText(row.modelData.size)
                    color: Theme.textMuted
                    font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1
                }
                Text {
                    x: parent.width - 84; width: 76
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    text: row.modelData.modified ? Qt.formatDate(row.modelData.modified, "d MMM yyyy") : ""
                    color: Theme.textMuted
                    font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1
                }
                StackEntryArea {
                    id: area
                    anchors.fill: parent
                    entry: row.modelData
                    grab: thumb
                    onOpened: stack.openEntry(row.modelData)
                    onDragStarted: stack.dragging = true
                    onDragFinished: stack.close()
                }
            }
        }
    }
}
