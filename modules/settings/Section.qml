import QtQuick
import "../../config"

// Small caps group label with spacing above.
Item {
    property alias text: t.text
    width: parent ? parent.width : 0
    height: 34
    Text { id: t; anchors.bottom: parent.bottom; anchors.bottomMargin: 6
        color: Theme.accent; font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1; font.bold: true
        font.capitalization: Font.AllUppercase; font.letterSpacing: 1.2 }
}
