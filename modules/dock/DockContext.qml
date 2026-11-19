import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../config"
import "../../services"
import "../../components"

// Right-click menu for a dock item, opened above the icon. A full-screen overlay catches every click outside the
// card (desktop, windows, the dock itself) and closes it; Esc closes it too.
PanelWindow {
    id: menu

    required property var dock
    property var item: null
    property real cx: 0          // icon centre and top, in dock window coordinates
    property real topY: 0
    property bool open: false

    function openFor(it, x, y) { item = it; cx = x; topY = y; open = true; }
    function close() { open = false; }

    readonly property var actions: {
        const it = item;
        if (!it) return [];
        const a = [];
        if (it.tool) return [{ label: "Open", run: () => DockService.openTool(it.id) }, { label: "Remove from Dock", run: () => DockService.removeTool(it.id) }];
        if (it.trash) return DockService.trashCount > 0 ? [{ label: "Empty Trash", danger: true, run: () => dock.askEmptyTrash() }] : [];
        if (it.stack) {
            const view = (v, l) => ({ label: l, checked: it.view === v, run: () => DockService.setStack(it.path, { view: v }) });
            const sort = (v, l) => ({ label: l, checked: it.sort === v, run: () => DockService.setStack(it.path, { sort: v }) });
            if (it.dir !== "recent") a.push({ label: "Open Folder", run: () => FolderService.openFolder(it.path) });
            a.push({ head: "View as" }, view("fan", "Fan"), view("grid", "Grid"), view("list", "List"));
            // Recent is always newest first
            if (it.dir !== "recent") a.push({ head: "Sort by" }, sort("modified", "Date Modified"), sort("name", "Name"), sort("kind", "Kind"));
            a.push({ label: "Remove from Dock", run: () => DockService.removeStack(it.path) });
            return a;
        }
        const n = it.windows.length;
        if (it.entry) a.push({ label: n ? "New Window" : "Open", run: () => DockService.launch(it) });
        if (it.entry) a.push(DockService.isPinned(it) ? { label: "Remove from Dock", run: () => DockService.unpin(it) }
                                                       : { label: "Keep in Dock", run: () => DockService.pin(it) });
        if (n) a.push({ label: n > 1 ? "Close " + n + " Windows" : "Close Window", run: () => it.windows.forEach(w => WindowService.close(w)) });
        if (n) a.push({ label: "Quit", danger: true, run: () => WindowService.quit(it.windows) });
        return a;
    }

    // stays mapped until the card has faded out
    visible: open || card.opacity > 0.01
    screen: dock.screen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "cozytile-dock-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    MouseArea { anchors.fill: parent; enabled: menu.open; acceptedButtons: Qt.AllButtons; onClicked: menu.close() }

    Rectangle {
        id: card
        width: Math.max(170, col.implicitWidth + 12)
        height: col.implicitHeight + 12
        // the dock window sits at the bottom of the screen
        x: Math.max(8, Math.min(menu.width - width - 8, menu.cx - width / 2))
        y: menu.height - menu.dock.height + menu.topY - height - 10
        radius: Theme.radius
        color: Theme.popupBg
        border.width: Theme.frost ? 0 : 1
        border.color: Theme.slash
        // grows out of the icon below it
        opacity: menu.open ? 1 : 0
        scale: menu.open ? 1 : 0.9
        transformOrigin: Item.Bottom
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
        focus: menu.open
        Keys.onEscapePressed: menu.close()
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
        Shadowed { target: card; z: -1 }
        Column {
            id: col
            x: 6; y: 6
            width: parent.width - 12
            Text {
                width: parent.width
                leftPadding: 10; topPadding: 4; bottomPadding: 6
                text: menu.item ? menu.item.name : ""
                elide: Text.ElideRight
                color: Theme.textMuted
                font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1; font.bold: true
            }
            Repeater {
                model: menu.actions
                Rectangle {
                    required property var modelData
                    width: col.width; height: modelData.head ? 24 : 30
                    radius: Theme.radiusSmall
                    color: m.containsMouse && !modelData.head ? Theme.hover : "transparent"
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 10
                        text: modelData.head ?? modelData.label
                        color: modelData.head ? Theme.textMuted : modelData.danger ? Theme.wsUrgent : Theme.text
                        font.family: Theme.font; font.pixelSize: modelData.head ? Theme.fontSmall : Theme.fontSize
                        font.bold: !!modelData.head
                    }
                    Rectangle {
                        visible: !!modelData.checked
                        width: 6; height: 6; radius: 3
                        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        color: Theme.accent
                    }
                    MouseArea {
                        id: m
                        anchors.fill: parent
                        enabled: !modelData.head
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { menu.close(); modelData.run(); }
                    }
                }
            }
        }
    }
}
