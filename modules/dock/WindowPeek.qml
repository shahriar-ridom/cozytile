import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../../config"
import "../../services"
import "../../components"

// Window Peek: hovering a running app in the dock shows its windows as live thumbnails in a card above the icon.
// Click a thumbnail to focus that window (switching workspace), the hover-revealed × closes just that window.
// The dock owns the hover logic (dwell, grace, which app); this window only draws. It stays mapped so opening is
// instant: closed, it is fully transparent with an empty input region, and its thumbnails (and captures) are gone.
PanelWindow {
    id: peek

    required property var dock
    readonly property bool open: dock.peekOpen
    readonly property bool busy: open || card.opacity > 0.01

    // the app whose windows are shown; switching apps fades the contents out and back in while the card moves
    property string shownKey: ""
    readonly property var shown: { const k = shownKey; return DockService.items.find(i => i.key === k) ?? null; }
    readonly property var wins: shown ? shown.windows : []
    function follow() {
        const k = dock.peekKey;
        if (k === shownKey) return;
        if (card.opacity < 0.05 || shownKey === "") shownKey = k;
        else swap.restart();
    }
    Connections { target: peek.dock; function onPeekKeyChanged() { peek.follow(); } }
    Component.onCompleted: shownKey = dock.peekKey
    SequentialAnimation {
        id: swap
        NumberAnimation { target: body; property: "opacity"; to: 0; duration: 70; easing.type: Easing.InQuad }
        ScriptAction { script: peek.shownKey = peek.dock.peekKey }
        NumberAnimation { target: body; property: "opacity"; to: 1; duration: 130; easing.type: Easing.OutQuad }
    }
    // the last window closed: nothing left to peek at
    onWinsChanged: if (open && shownKey === dock.peekKey && wins.length === 0) dock.hidePeek()

    // ---- layout: thumbnails keep the window's aspect, rows wrap at 80% of the screen ----
    readonly property int thumbH: Math.round(Math.max(90, Math.min(150, dock.screenH * 0.11)))
    readonly property int tilePad: 6
    readonly property int titleH: 22
    readonly property int spacing: 4
    readonly property real maxRowW: dock.screenW * 0.8 - 2 * 8
    function tileW(t) {
        const o = t ? t.lastIpcObject : null;
        const a = o && o.size && o.size[1] > 0 ? o.size[0] / o.size[1] : 1.6;
        return Math.round(Math.max(thumbH * 0.75, Math.min(thumbH * 2, thumbH * a)) + 2 * tilePad);
    }
    readonly property real rowW: {
        let best = 0, row = 0;
        for (const t of wins) {
            const w = tileW(t);
            const next = row ? row + spacing + w : w;
            if (row && next > maxRowW) { best = Math.max(best, row); row = w; }
            else row = next;
        }
        return Math.max(best, row);
    }

    // the card's bottom sits just above the fully magnified icons; this window spans the dock plus room for the card
    readonly property real cardBottom: height - dock.height + dock.baseY - dock.iconSize * dock.maxScale - 10

    screen: dock.screen
    color: "transparent"
    anchors { bottom: true; left: true; right: true }
    implicitHeight: dock.height + 2 * (thumbH + titleH + 2 * tilePad) + 40
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "cozytile-dock-peek"
    WlrLayershell.layer: WlrLayer.Overlay
    // input only over the card, and only while open, so the dock underneath keeps its hover
    mask: Region { item: hitBox }
    Item { id: hitBox; x: card.x; y: card.y; width: peek.open ? card.width : 0; height: peek.open ? card.height : 0 }

    HoverHandler { onHoveredChanged: peek.dock.peekHovered = hovered }

    Rectangle {
        id: card
        // slide and resize only between apps while fully shown; opening appears in place above the icon
        readonly property bool settled: peek.open && opacity > 0.99
        width: Math.round(peek.rowW + 2 * 8)
        height: Math.round(body.implicitHeight + 2 * 8)
        x: Math.max(8, Math.min(peek.width - width - 8, peek.dock.peekCx - width / 2))
        y: peek.cardBottom - height
        Behavior on x { enabled: card.settled; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on width { enabled: card.settled; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on height { enabled: card.settled; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        radius: Theme.radius + 4
        color: Theme.popupBg
        border.width: Theme.frost ? 0 : 1
        border.color: Theme.slash
        // grows out of the icon below it
        opacity: peek.open ? 1 : 0
        scale: peek.open ? 1 : 0.92
        transformOrigin: Item.Bottom
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
        Shadowed { target: card; z: -1 }

        Flow {
            id: body
            x: 8; y: 8
            width: peek.rowW
            spacing: peek.spacing
            Repeater {
                // diffed, so a window opening or closing doesn't recreate (and re-capture) every other thumbnail
                model: ScriptModel { values: peek.busy ? peek.wins : [] }
                Item {
                    id: tile
                    required property var modelData
                    readonly property var tl: modelData
                    width: peek.tileW(tl)
                    height: peek.thumbH + peek.titleH + 2 * peek.tilePad

                    HoverHandler { id: th }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { WindowService.focus(tile.tl); peek.dock.hidePeek(); }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radius
                        color: th.hovered ? Theme.hover : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    }

                    ClippingRectangle {
                        id: thumb
                        x: peek.tilePad; y: peek.tilePad
                        width: tile.width - 2 * peek.tilePad
                        height: peek.thumbH
                        radius: Theme.radiusSmall + 1
                        color: Theme.p.bg2
                        ScreencopyView {
                            id: cap
                            anchors.fill: parent
                            captureSource: tile.tl ? tile.tl.wayland : null
                            // windows on hidden workspaces are not rendered, so they get no new frames: grab them
                            // once a second instead of waiting on a live stream
                            live: WindowService.onScreen(tile.tl)
                            paintCursor: false
                            Timer { running: !cap.live; repeat: true; triggeredOnStart: true; interval: 1000; onTriggered: cap.captureFrame() }
                            // a failed capture ends the stream for good: re-arm the source until a frame arrives
                            Timer {
                                running: !cap.hasContent; repeat: true; interval: 600
                                onTriggered: { if (!tile.tl || !tile.tl.wayland) return; cap.captureSource = null; cap.captureSource = tile.tl.wayland; }
                            }
                        }
                        // fallback while the window cannot be captured
                        IconImage {
                            anchors.centerIn: parent
                            visible: !cap.hasContent
                            implicitSize: Math.round(peek.thumbH * 0.36)
                            source: {
                                const i = peek.shown ? peek.shown.icon : "";
                                if (i && i.startsWith("/")) return i;
                                return Quickshell.iconPath(i, true) || Quickshell.iconPath("application-x-executable", true);
                            }
                        }
                    }

                    Text {
                        x: peek.tilePad + 2
                        y: peek.tilePad + peek.thumbH
                        width: tile.width - 2 * peek.tilePad - 4
                        height: peek.titleH
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: tile.tl ? (tile.tl.title || (peek.shown ? peek.shown.name : "")) : ""
                        elide: Text.ElideRight
                        color: tile.tl && tile.tl.activated ? Theme.text : Theme.textDim
                        font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1
                    }

                    // close button, revealed on hover
                    Rectangle {
                        width: 22; height: 22; radius: 11
                        x: tile.width - width - 2; y: 2
                        opacity: th.hovered ? 1 : 0
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                        color: cb.containsMouse ? Theme.wsUrgent : Theme.tooltipBg
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        Glyph { anchors.centerIn: parent; text: ""; size: 11; color: Theme.text }
                        MouseArea {
                            id: cb
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: WindowService.close(tile.tl)
                        }
                    }
                }
            }
        }
    }
}
