import QtQuick
import Quickshell
import "../../config"
import "../../components"

Item {
    id: root
    property bool showDate: false
    signal clicked(var mouse)
    implicitWidth: row.implicitWidth + 12
    implicitHeight: Theme.barHeight

    SystemClock { id: clock; precision: SystemClock.Minutes }

    HoverArea {
        anchors.fill: parent
        anchors.topMargin: 3; anchors.bottomMargin: 3
        radius: Theme.radiusSmall + 2
        onClicked: m => { root.showDate = !root.showDate; root.clicked(m); }
    }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8
        Glyph { text: ""; color: Theme.barTextDim; anchors.verticalCenter: parent.verticalCenter }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date, root.showDate ? "ddd d MMM  hh:mm AP" : "hh:mm AP")
            color: Theme.barText
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            font.bold: true
        }
    }
}
