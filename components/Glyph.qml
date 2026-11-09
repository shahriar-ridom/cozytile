import QtQuick
import "../config"

// Nerd Font icon. Pass the glyph as text, e.g. "".
Text {
    property int size: Theme.iconSize
    color: Theme.barText
    font.family: Theme.iconFont
    font.pixelSize: size
    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
}
