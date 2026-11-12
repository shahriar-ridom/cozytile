import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../config"
import "../../services"

// Dropdown for the global menu's open title. Leaves the bar itself clickable so titles can be
// hovered/clicked to switch menus.
PanelWindow {
    id: win
    screen: UiState.focusedScreen
    visible: UiState.globalMenuOpen || card.opacity > 0.01
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "cozytile-globalmenu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: UiState.globalMenuOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    readonly property real top: Theme.barMarginTop + Theme.barHeight + 4
    mask: Region { x: 0; y: win.top; width: win.width; height: Math.max(0, win.height - win.top) }
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: UiState.globalMenuIndex = -1 }

    // keep content while fading out
    property var model: []
    function sync() {
        const i = UiState.globalMenuIndex, items = GlobalMenuService.items;
        if (i === -2) model = items.slice(UiState.globalMenuFrom);
        else if (items[i]) model = items[i].children;
    }
    // the app's menu changed under an open dropdown
    function validate() {
        const i = UiState.globalMenuIndex, n = GlobalMenuService.items.length;
        if (i >= 0 && i >= n || i === -2 && UiState.globalMenuFrom >= n) UiState.globalMenuIndex = -1;
    }
    Connections { target: UiState; function onGlobalMenuIndexChanged() { win.sync(); } }
    Connections { target: GlobalMenuService; function onItemsChanged() { win.validate(); win.sync(); } }
    property bool shown: false
    Component.onCompleted: { sync(); shown = Qt.binding(() => UiState.globalMenuOpen); }
    readonly property bool busy: visible

    MenuList {
        id: card
        model: win.model
        limitX: win.width
        maxH: win.height - win.top - 16
        x: Math.max(8, Math.min(win.width - width - 8, UiState.globalMenuX))
        y: win.top + (win.shown ? 0 : -4)
        opacity: win.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
        Behavior on y { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
        focus: true
        Keys.onEscapePressed: UiState.globalMenuIndex = -1
        onActivated: id => { GlobalMenuService.activate(id); UiState.globalMenuIndex = -1; }
        // switching menus restarts any open flyout
        Connections { target: UiState; function onGlobalMenuIndexChanged() { card.openId = -1; } }
    }
}
