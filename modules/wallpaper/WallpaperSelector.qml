import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../config"
import "../../services"
import "../../components"

// Grid of thumbnails from the configured directories; click to apply to one monitor or all.
PanelWindow {
    id: win
    screen: UiState.focusedScreen
    visible: UiState.wallpaper || card.opacity > 0.01
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "cozytile-wallpaper"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: UiState.wallpaper ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property string target: "*"     // "*" = all monitors, otherwise output name
    readonly property var targets: ["*"].concat(Quickshell.screens.map(s => s.name))
    readonly property bool forLock: UiState.wallpaperFor === "lock"
    // desktop: apply to the chosen monitor; lock screen: remember the pick and close
    function choose(path) {
        if (!path) return;
        if (forLock) { LockscreenService.set("wallpaper", path); UiState.wallpaper = false; }
        else WallpaperService.set(path, target === "*" ? "" : target);
    }
    function currentPath() {
        if (forLock) return LockscreenService.wallpaper();
        return WallpaperService.current(target === "*" ? (Quickshell.screens[0] ? Quickshell.screens[0].name : "") : target);
    }
    function applyIndex(i) {
        const f = WallpaperService.files[i];
        if (f) win.choose(f);
    }
    // files arrive after the async scan: land on the current wallpaper once
    Connections {
        target: WallpaperService
        function onFilesChanged() { if (UiState.wallpaper) grid.currentIndex = Math.max(0, WallpaperService.files.indexOf(win.currentPath())); }
    }

    function opened() { WallpaperService.scan(); win.target = "*"; grid.currentIndex = Math.max(0, WallpaperService.files.indexOf(win.currentPath())); grid.forceActiveFocus(); }
    // false at creation, then follows the open state, so the open animation still plays
    // when the window is created already open (see the LazyLoader in shell.qml)
    property bool shown: false
    Component.onCompleted: { shown = Qt.binding(() => UiState.wallpaper); if (UiState.wallpaper) opened(); }
    Connections {
        target: UiState
        function onWallpaperChanged() { if (UiState.wallpaper) win.opened(); }
    }
    MouseArea { anchors.fill: parent; onClicked: UiState.wallpaper = false }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(900, parent.width - 60); height: Math.min(600, parent.height - 100)
        radius: Theme.radius + 4
        color: Theme.popupBg
        border.width: 1; border.color: Theme.border
        opacity: win.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent }
        Shadowed { target: card; z: -1 }

        Row {
            id: head
            x: 18; y: 14; width: parent.width - 36; height: 30; spacing: 8
            Text { text: win.forLock ? "Lock screen wallpaper" : "Wallpapers"; color: Theme.text; anchors.verticalCenter: parent.verticalCenter
                font.family: Theme.font; font.pixelSize: Theme.fontLarge; font.bold: true }
            Item { width: 10; height: 1 }
            // target chips: All + one per monitor
            Repeater {
                model: win.forLock ? [] : [{ n: "*", l: "All monitors" }].concat(Quickshell.screens.map(s => ({ n: s.name, l: s.name })))
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool on: win.target === modelData.n
                    height: 26; width: t.implicitWidth + 20; radius: 13; anchors.verticalCenter: parent.verticalCenter
                    color: on ? Theme.accent : Theme.surfaceAlt
                    Text { id: t; anchors.centerIn: parent; text: modelData.l
                        color: on ? Theme.barCap : Theme.textDim
                        font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1; font.bold: true }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.target = modelData.n }
                }
            }
            Item { width: 1; height: 1 }
        }
        Text {
            anchors { bottom: parent.bottom; bottomMargin: 6; horizontalCenter: parent.horizontalCenter }
            text: "← ↑ ↓ → move · Enter apply · Tab monitor · Esc close"
            color: Theme.textMuted; font.family: Theme.font; font.pixelSize: Theme.fontSmall
        }
        // wallpaper-derived theming toggle
        Rectangle {
            visible: ThemeService.available && !win.forLock
            anchors { right: parent.right; rightMargin: 18; top: parent.top; topMargin: 16 }
            height: 26; width: tl.implicitWidth + 24; radius: 13
            color: Settings.wallpaperTheming ? Theme.accent : Theme.surfaceAlt
            Text { id: tl; anchors.centerIn: parent; text: "Theme from wallpaper"
                color: Settings.wallpaperTheming ? Theme.barCap : Theme.textDim
                font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1; font.bold: true }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: ThemeService.setTheming(!Settings.wallpaperTheming) }
        }


        GridView {
            id: grid
            anchors { top: head.bottom; bottom: parent.bottom; left: parent.left; right: parent.right; margins: 18; topMargin: 14; bottomMargin: 26 }
            clip: true
            cellWidth: Math.floor(width / Math.max(2, Math.floor(width / 200)))
            cellHeight: cellWidth * 0.62 + 6
            model: WallpaperService.files
            boundsBehavior: Flickable.StopAtBounds
            focus: true
            keyNavigationEnabled: true          // arrows / Home / End / PageUp / PageDown
            keyNavigationWraps: false
            currentIndex: 0
            highlightFollowsCurrentItem: true
            highlight: Item {}                  // selection ring is drawn by the delegate
            Keys.onReturnPressed: win.applyIndex(currentIndex)
            Keys.onEnterPressed: win.applyIndex(currentIndex)
            Keys.onSpacePressed: win.applyIndex(currentIndex)
            Keys.onEscapePressed: UiState.wallpaper = false
            Keys.onTabPressed: win.target = win.targets[(win.targets.indexOf(win.target) + 1) % win.targets.length]
            Keys.onBacktabPressed: win.target = win.targets[(win.targets.indexOf(win.target) + win.targets.length - 1) % win.targets.length]
            delegate: Item {
                required property string modelData
                required property int index
                width: grid.cellWidth; height: grid.cellHeight
                readonly property bool active: win.currentPath() === modelData
                readonly property bool current: GridView.isCurrentItem && grid.activeFocus
                Rectangle {
                    anchors.fill: parent; anchors.margins: 4
                    radius: Theme.radius
                    color: Theme.surfaceAlt
                    border.width: (current || active) ? 2 : 0
                    border.color: current ? Theme.text : Theme.accent
                    clip: true
                    Image {
                        anchors.fill: parent; anchors.margins: active ? 2 : 0
                        source: "file://" + modelData
                        sourceSize.width: 360       // decode small; keeps memory low
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                    }
                    Rectangle { anchors.fill: parent; radius: Theme.radius; color: Theme.hover; visible: pm.containsMouse }
                    MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onEntered: grid.currentIndex = index
                        onClicked: win.choose(modelData) }
                }
            }
            Text {
                visible: WallpaperService.files.length === 0
                anchors.centerIn: parent
                text: WallpaperService.scanning ? "Scanning…" : "No images in " + Settings.wallpaperDirs.join(", ")
                color: Theme.textMuted; font.family: Theme.font; font.pixelSize: Theme.fontSize
            }
        }
    }
}
