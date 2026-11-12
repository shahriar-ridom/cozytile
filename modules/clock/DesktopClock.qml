import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../../config"
import "../../services"

// Clock drawn on the desktop itself: above the wallpaper, below every window, and click-through.
// In move mode (DesktopClockService.editing) it rises above the windows so it can be dragged anywhere;
// the spot is saved as fractions of the free screen area (position "custom", keys fx / fy).
PanelWindow {
    id: win

    readonly property var svc: DesktopClockService
    readonly property string style: svc.get("style")
    readonly property string pos: svc.get("position")
    readonly property bool h24: svc.get("hour24")
    readonly property bool showSeconds: svc.get("seconds")
    readonly property bool showDate: svc.get("showDate")
    readonly property bool editing: svc.editing
    readonly property real sizeK: ({ small: 0.75, medium: 1, large: 1.3 })[svc.get("size")] ?? 1

    SystemClock { id: sc; precision: win.showSeconds ? SystemClock.Seconds : SystemClock.Minutes }
    readonly property date now: sc.date
    readonly property string hh: h24 ? Qt.formatDateTime(now, "HH") : String(((now.getHours() + 11) % 12) + 1)
    readonly property string mm: Qt.formatDateTime(now, "mm")
    readonly property string ss: Qt.formatDateTime(now, "ss")
    readonly property string ampm: h24 ? "" : Qt.formatDateTime(now, "AP")
    readonly property string weekday: Qt.formatDateTime(now, "dddd")
    readonly property string dayMonth: Qt.formatDateTime(now, "d MMMM")

    // text alignment follows the corner the clock sits in
    readonly property int align: pos.endsWith("left") ? Qt.AlignLeft : pos.endsWith("right") ? Qt.AlignRight : Qt.AlignHCenter

    visible: svc.get("enabled")
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "cozytile-clock"
    WlrLayershell.layer: win.editing ? WlrLayer.Overlay : WlrLayer.Bottom
    WlrLayershell.keyboardFocus: win.editing ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    // empty input region: clicks fall through to whatever is behind (only the clock itself is grabbable when moving)
    mask: win.editing ? editRegion : noRegion
    Region { id: noRegion }
    Region { id: editRegion; item: editBox }

    Item {
        id: holder
        readonly property int sideInset: 72
        readonly property int topInset: Theme.barMarginTop + Theme.barHeight + 56
        width: loader.implicitWidth
        height: loader.implicitHeight
        property bool dragging: false
        property real liveX: 0
        property real liveY: 0
        readonly property real fx: Number(svc.get("fx"))
        readonly property real fy: Number(svc.get("fy"))
        x: dragging ? liveX : win.pos === "custom" ? Math.max(0, Math.min(1, fx)) * (win.width - width)
          : win.pos.endsWith("left") ? sideInset : win.pos.endsWith("right") ? win.width - width - sideInset : (win.width - width) / 2
        y: dragging ? liveY : win.pos === "custom" ? Math.max(0, Math.min(1, fy)) * (win.height - height)
          : win.pos.startsWith("top") ? topInset : win.pos.startsWith("bottom") ? win.height - height - sideInset : (win.height - height) / 2
        Behavior on x { enabled: !holder.dragging; NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutCubic } }
        Behavior on y { enabled: !holder.dragging; NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutCubic } }

        // soft shadow keeps the clock readable over bright wallpapers
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#99000000"
            shadowBlur: 0.9
            shadowVerticalOffset: 3
        }

        Loader {
            id: loader
            anchors.fill: parent
            source: win.style === "stacked" ? "ClockStacked.qml" : win.style === "analog" ? "ClockAnalog.qml" : "ClockMinimal.qml"
            onLoaded: item.t = win
            opacity: status === Loader.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
        }
    }

    // ---- move mode: outline, drag surface and a Done pill around the clock ----
    Item {
        id: editBox
        visible: win.editing
        x: holder.x - 16; y: holder.y - 16
        width: holder.width + 32; height: holder.height + 32 + 40
        focus: win.editing
        Keys.onEscapePressed: svc.editing = false
        Keys.onReturnPressed: svc.editing = false

        Rectangle {
            x: 0; y: 0; width: parent.width; height: holder.height + 32
            radius: Theme.radius + 4
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.10)
            border.width: 2; border.color: Theme.accent
        }
        MouseArea {
            x: 0; y: 0; width: parent.width; height: holder.height + 32
            cursorShape: holder.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            property real offX; property real offY
            onPressed: m => {
                const p = mapToItem(null, m.x, m.y);
                offX = p.x - holder.x; offY = p.y - holder.y;
                holder.liveX = holder.x; holder.liveY = holder.y;
                holder.dragging = true;
            }
            onPositionChanged: m => {
                if (!holder.dragging) return;
                const p = mapToItem(null, m.x, m.y);
                holder.liveX = Math.max(0, Math.min(win.width - holder.width, p.x - offX));
                holder.liveY = Math.max(0, Math.min(win.height - holder.height, p.y - offY));
            }
            onReleased: {
                if (!holder.dragging) return;
                const fw = win.width - holder.width, fh = win.height - holder.height;
                svc.setMany({ position: "custom", fx: fw > 0 ? holder.liveX / fw : 0.5, fy: fh > 0 ? holder.liveY / fh : 0.5 });
                holder.dragging = false;
            }
        }
        Rectangle {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
            width: doneText.implicitWidth + 28; height: 30; radius: 15
            color: Theme.accent
            Text { id: doneText; anchors.centerIn: parent; text: "Drag to move  ·  Done"
                color: Theme.surface; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: svc.editing = false }
        }
    }
}
