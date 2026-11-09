import QtQuick
import QtQuick.Shapes
import "../config"

// Thin diagonal separator, Cozytile's "/" between sections.
Item {
    id: root
    property color color: Theme.slash
    implicitWidth: Theme.edgeSlant + 6
    implicitHeight: Theme.barHeight
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.color
            strokeWidth: 1.5
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: root.width / 2 + Theme.edgeSlant / 2
            startY: 0
            PathLine { x: root.width / 2 - Theme.edgeSlant / 2; y: root.height }
        }
    }
}
