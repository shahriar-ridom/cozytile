import QtQuick
import "../../config"
import "../../services"
import "../../components"

// One level of an app menu, laid out on fixed columns so nothing can overlap:
//   [ check ] label ............ shortcut  [ > ]
// The width comes from measuring the real strings once per model; long menus scroll.
// Submenus fly out beside the hovered row, to the left when the right edge is too close.
Item {
    id: root
    property var model: []
    property real limitX: 100000        // right edge of the screen, in this list's window
    property real maxH: 600             // taller menus scroll
    property int openId: -1             // item whose flyout is showing
    signal activated(int id)

    readonly property int pad: 5
    readonly property int rowH: 28
    readonly property int sepH: 11
    readonly property int gutter: 26     // check / radio mark
    readonly property int inset: 10      // text inset inside a row
    readonly property int labelFont: Theme.fontSize + 1
    readonly property int shortcutFont: Theme.fontSmall + 1

    FontMetrics { id: lm; font.family: Theme.font; font.pixelSize: root.labelFont }
    FontMetrics { id: sm; font.family: Theme.font; font.pixelSize: root.shortcutFont }

    // widest label / shortcut, whether any row has a submenu, total content height
    readonly property var stats: {
        let l = 0, s = 0, sub = false, h = 0;
        for (const it of model) {
            if (it.sep) { h += sepH; continue; }
            h += rowH;
            l = Math.max(l, lm.advanceWidth(it.label));
            s = Math.max(s, sm.advanceWidth(it.shortcut));
            if (it.children.length) sub = true;
        }
        return { label: l, shortcut: s, sub: sub, height: h };
    }
    readonly property int arrowW: stats.sub ? 22 : 0
    readonly property int shortcutW: stats.shortcut > 0 ? Math.ceil(stats.shortcut) + 28 : 0
    width: Math.round(Math.max(200, Math.min(400, 2 * pad + gutter + Math.ceil(stats.label) + shortcutW + arrowW + inset + 6)))
    height: Math.min(maxH, stats.height + 2 * pad)

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Theme.radius + 2
        color: Theme.popupBg
        border.width: 1; border.color: Theme.border
        Shadowed { target: bg; z: -1 }
    }

    // ---- rows ---------------------------------------------------------------
    Flickable {
        id: flick
        anchors { fill: parent; margins: root.pad }
        clip: true
        contentWidth: width
        contentHeight: col.height
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        flickableDirection: Flickable.VerticalFlick

        Column {
            id: col
            width: flick.width
            Repeater {
                model: root.model
                delegate: Item {
                    id: row
                    required property var modelData
                    readonly property bool sep: modelData.sep
                    readonly property bool hasSub: modelData.children.length > 0
                    readonly property bool live: !sep && modelData.enabled
                    width: col.width
                    height: sep ? root.sepH : root.rowH

                    Rectangle {      // separator
                        visible: row.sep
                        x: root.inset; width: parent.width - 2 * root.inset
                        anchors.verticalCenter: parent.verticalCenter
                        height: 1; color: Theme.border
                    }
                    Rectangle {      // hover / open-parent highlight
                        visible: !row.sep
                        anchors.fill: parent
                        radius: Theme.radiusSmall + 1
                        color: !row.live ? "transparent"
                             : ma.pressed ? Theme.press
                             : (ma.containsMouse || root.openId === row.modelData.id) ? Theme.hover : "transparent"
                    }
                    Glyph {          // check / radio mark
                        visible: !row.sep && row.modelData.toggle !== "" && row.modelData.state === 1
                        x: 0; width: root.gutter + 4; height: parent.height
                        text: row.modelData.toggle === "radio" ? "" : ""
                        size: row.modelData.toggle === "radio" ? 6 : 10
                        color: Theme.accent
                    }
                    Text {
                        visible: !row.sep
                        x: root.gutter; width: row.width - root.gutter - root.shortcutW - root.arrowW - root.inset
                        height: parent.height
                        verticalAlignment: Text.AlignVCenter
                        text: row.modelData.label
                        elide: Text.ElideRight
                        color: row.live ? Theme.text : Theme.textMuted
                        opacity: row.live ? 1 : 0.55
                        font.family: Theme.font; font.pixelSize: root.labelFont
                    }
                    Text {
                        visible: !row.sep && row.modelData.shortcut !== "" && !row.hasSub
                        x: row.width - root.arrowW - root.inset - implicitWidth
                        height: parent.height
                        verticalAlignment: Text.AlignVCenter
                        text: row.modelData.shortcut
                        color: Theme.textMuted
                        opacity: row.live ? 1 : 0.55
                        font.family: Theme.font; font.pixelSize: root.shortcutFont
                    }
                    Glyph {
                        visible: row.hasSub
                        x: row.width - width - 8; width: 12; height: parent.height
                        text: ""; size: 8; color: Theme.textMuted
                    }
                    MouseArea {
                        id: ma
                        visible: !row.sep
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: {
                            if (row.hasSub && row.live) {
                                root.pendingId = row.modelData.id;
                                root.pendingY = row.y - flick.contentY + root.pad;
                                openTimer.restart();
                                GlobalMenuService.aboutToShow(row.modelData.id);
                            } else { openTimer.stop(); root.openId = -1; }
                        }
                        onClicked: if (row.live && !row.hasSub) root.activated(row.modelData.id)
                    }
                }
            }
        }
    }

    // ---- flyout ---------------------------------------------------------------
    property int pendingId: -1
    property real pendingY: 0
    property real openY: 0
    // short delay so a diagonal move toward the flyout does not close it
    Timer { id: openTimer; interval: 90; onTriggered: { root.openY = root.pendingY; root.openId = root.pendingId; } }
    readonly property var openItem: openId < 0 ? null : (model.find(x => x.id === openId) ?? null)

    Loader {
        id: sub
        active: root.openItem !== null && root.openItem.children.length > 0
        source: "MenuList.qml"          // by URL: a component cannot instantiate its own type
        readonly property bool flip: root.mapToItem(null, 0, 0).x + root.width + (item ? item.width : 220) > root.limitX
        x: flip ? -(item ? item.width : 0) + 6 : root.width - 6
        y: Math.max(0, root.openY - root.pad)
        onLoaded: {
            item.limitX = Qt.binding(() => root.limitX);
            item.maxH = Qt.binding(() => root.maxH);
            item.model = Qt.binding(() => root.openItem ? root.openItem.children : []);
        }
        Connections { target: sub.item; function onActivated(id) { root.activated(id); } }
    }
}
