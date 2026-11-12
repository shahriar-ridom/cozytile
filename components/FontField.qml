import QtQuick
import "../config"

// Button showing a typeface in its own letterforms; asks `opener(current, title, callback)` to show the
// searchable font list (the settings panel draws one shared picker sheet).
// `value` "" means "use the default"; `fallback` is shown in that case.
Rectangle {
    id: root
    property string value: ""
    property string fallback: ""
    property string title: "Choose a font"
    property var opener: null       // function(current, title, callback)
    signal picked(string family)

    readonly property string shown: value || fallback

    implicitWidth: 220; implicitHeight: 28
    radius: Theme.radiusSmall + 2
    color: ma.containsMouse ? Theme.surfaceHigh : Theme.surfaceAlt
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    Text {
        anchors { left: parent.left; leftMargin: 12; right: chev.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
        text: root.shown || "Default"; elide: Text.ElideRight
        color: Theme.text; font.family: root.shown || Theme.font; font.pixelSize: Theme.fontSmall + 2
    }
    Glyph { id: chev; anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
        text: ""; size: 9; color: Theme.textDim }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: if (root.opener) root.opener(root.value, root.title, f => root.picked(f)) }
}
