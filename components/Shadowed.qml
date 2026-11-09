import QtQuick
import QtQuick.Effects
import "../config"

// Cheap rectangular drop shadow behind a rounded item (GPU, no blur of content).
RectangularShadow {
    property Item target
    anchors.fill: target
    radius: target ? (target.radius ?? Theme.radius) : Theme.radius
    blur: Theme.shadowRadius
    spread: 0
    offset.y: 2
    color: Theme.shadow
}
