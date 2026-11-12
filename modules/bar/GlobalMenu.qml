import QtQuick
import "../../config"
import "../../services"
import "../../components"

// The focused app's menu titles (File, Edit, ...), like the macOS menu bar.
// Clicking a title opens its dropdown (GlobalMenuPopup); while one is open, hovering another switches to it.
// Titles that do not fit in maxWidth are replaced by a » button whose dropdown lists the rest.
Item {
    id: root
    property real maxWidth: 400
    readonly property int cellPad: 16        // horizontal padding inside a title
    readonly property int moreW: 28          // width of the » button
    readonly property var items: GlobalMenuService.items

    FontMetrics { id: fm; font.family: Theme.font; font.pixelSize: Theme.fontSize }

    // how many titles fit; if some do not, one slot is reserved for the » button
    readonly property int fit: {
        const n = items.length;
        let total = 0;
        const w = items.map(it => Math.ceil(fm.advanceWidth(it.label)) + cellPad);
        for (const x of w) total += x;
        if (total <= maxWidth) return n;
        let used = 0, k = 0;
        while (k < n && used + w[k] <= maxWidth - moreW) { used += w[k]; k++; }
        return k;
    }
    readonly property bool overflow: fit < items.length
    readonly property int overflowIndex: -2   // UiState.globalMenuIndex value for the » dropdown

    implicitWidth: row.implicitWidth
    implicitHeight: Theme.barHeight

    function open(index, cell) {
        if (UiState.globalMenuIndex === index) { UiState.globalMenuIndex = -1; return; }
        UiState.closeAll();
        place(index, cell);
    }
    function place(index, cell) {
        UiState.globalMenuX = cell.mapToItem(null, 0, 0).x + Theme.barOriginX;
        UiState.globalMenuFrom = fit;
        UiState.globalMenuIndex = index;
        if (index >= 0) GlobalMenuService.aboutToShow(items[index].id);
    }

    Row {
        id: row
        height: parent.height
        spacing: 0

        Repeater {
            model: root.items.slice(0, root.fit)
            delegate: Rectangle {
                id: cell
                required property var modelData
                required property int index
                readonly property bool active: UiState.globalMenuIndex === index
                anchors.verticalCenter: parent.verticalCenter
                width: Math.ceil(fm.advanceWidth(modelData.label)) + root.cellPad; height: 22
                radius: Theme.radiusSmall
                color: active ? Theme.press : (ma.containsMouse ? Theme.hover : "transparent")
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                Text {
                    anchors.centerIn: parent
                    text: cell.modelData.label
                    color: cell.modelData.enabled ? Theme.barText : Theme.barTextDim
                    font.family: Theme.font; font.pixelSize: Theme.fontSize
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.open(cell.index, cell)
                    onEntered: if (UiState.globalMenuOpen && !cell.active) root.place(cell.index, cell)
                }
            }
        }

        // » : the titles that did not fit
        Rectangle {
            id: more
            visible: root.overflow
            anchors.verticalCenter: parent.verticalCenter
            width: visible ? root.moreW : 0; height: 22
            radius: Theme.radiusSmall
            readonly property bool active: UiState.globalMenuIndex === root.overflowIndex
            color: active ? Theme.press : (moreMa.containsMouse ? Theme.hover : "transparent")
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
            Glyph { anchors.centerIn: parent; text: ""; size: 12; color: Theme.barText }
            MouseArea {
                id: moreMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.open(root.overflowIndex, more)
                onEntered: if (UiState.globalMenuOpen && !more.active) root.place(root.overflowIndex, more)
            }
        }
    }
}
