import QtQuick
import Quickshell
import Quickshell.Widgets
import "../../config"

// One dock icon. Position, magnification and input belong to the dock; the item only draws: the icon (scaled from
// its bottom centre), running dots under it, and the launch / attention bounce.
Item {
    id: root

    required property var info          // a DockService item
    required property int base          // resting icon size, px
    required property real factor       // magnification, 1 = resting
    property real appear: 1             // 0..1 while entering or leaving the dock
    property bool dim: false            // files are being dragged over the dock and this icon cannot take them
    property bool bouncing: false
    property real press: 1              // click feedback
    property real lift: 0               // bounce height, px

    function pulse() { clickAnim.restart(); }

    width: base; height: base
    opacity: appear * (dim ? 0.3 : 1)
    Behavior on opacity { enabled: root.appear >= 1; NumberAnimation { duration: 160 } }

    SequentialAnimation {
        id: clickAnim
        NumberAnimation { target: root; property: "press"; to: 0.82; duration: 80; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "press"; to: 1; duration: 260; easing.type: Easing.OutBack }
    }
    SequentialAnimation {
        loops: Animation.Infinite
        running: root.bouncing
        alwaysRunToEnd: true
        NumberAnimation { target: root; property: "lift"; to: root.base * 0.45; duration: 260; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "lift"; to: 0; duration: 260; easing.type: Easing.InQuad }
        PauseAnimation { duration: 140 }
    }

    IconImage {
        id: icon
        // IconImage rasterises at its own width, so it is sized for the fully magnified icon and scaled down at rest:
        // scaling down stays sharp, scaling up would blur
        readonly property int full: Math.round(root.base * Math.max(1, Settings.dockMagnification))
        width: full; height: full
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        transformOrigin: Item.Bottom
        scale: root.factor * root.press * (0.5 + 0.5 * root.appear) * root.base / full
        transform: Translate { y: -root.lift }
        mipmap: true
        source: {
            const i = root.info.icon;
            if (i && i.startsWith("/")) return i;
            return Quickshell.iconPath(i, true) || Quickshell.iconPath("application-x-executable", true);
        }
    }

    // a folder stack wears its newest item as a badge, drawn in the icon's own box so it scales and bounces with it
    Item {
        visible: root.info.stack === true && !root.info.trash
        width: icon.width; height: icon.height
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        transformOrigin: Item.Bottom
        scale: icon.scale
        transform: Translate { y: -root.lift }
        Loader {
            active: root.info.stack === true && !root.info.trash
            anchors.fill: parent
            sourceComponent: Item {
                StackSource { id: src; path: root.info.dir ?? ""; sort: root.info.sort ?? "modified"; limit: 1 }
                Rectangle {
                    visible: src.newest !== null
                    width: parent.width * 0.44; height: width
                    x: parent.width * 0.5; y: parent.height * 0.5
                    radius: width * 0.24
                    color: Theme.popupBg
                    border.width: 1; border.color: Theme.slash
                    StackThumb { anchors.centerIn: parent; size: parent.width - 6; entry: src.newest }
                }
            }
        }
    }

    // running indicator: one dot per window (up to three); the focused app shows a single accent dash instead, like
    // the bar's active workspace
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.base + 3
        spacing: 3
        Repeater {
            model: root.info.focused ? 1 : Math.min(3, root.info.windows.length)
            Rectangle {
                width: root.info.focused ? Math.round(root.base * 0.32) : 4
                height: 4; radius: 2
                color: root.info.focused ? Theme.accent : Theme.textMuted
            }
        }
    }
}
