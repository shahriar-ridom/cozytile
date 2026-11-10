import QtQuick
import "../config"

// Button showing the current choice; asks `opener(dropdown)` to show the list
// (the settings panel draws one shared picker sheet so lists are never clipped).
Rectangle {
    id: root
    property var model: []          // [{ label, value }]
    property var current
    property string title: ""
    property var opener: null       // function(dropdown)
    signal picked(var value)

    readonly property string currentLabel: {
        const m = (model || []).find(x => x.value === current);
        return m ? m.label : (current === undefined || current === null ? "—" : String(current));
    }

    implicitWidth: Math.max(130, lbl.implicitWidth + 44); implicitHeight: 28
    radius: Theme.radiusSmall + 2
    color: ma.containsMouse ? Theme.surfaceHigh : Theme.surfaceAlt
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    Text {
        id: lbl
        anchors { left: parent.left; leftMargin: 12; right: chev.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
        text: root.currentLabel; elide: Text.ElideRight
        color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontSmall + 2; font.bold: true
    }
    Glyph { id: chev; anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
        text: ""; size: 9; color: Theme.textDim }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: if (root.opener) root.opener(root) }
}
