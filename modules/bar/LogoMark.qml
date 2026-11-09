import QtQuick
import "../../config"

// Four-diamond launcher mark (original drawing in the spirit of Cozytile's logo).
Item {
    id: root
    property color color: Theme.barText
    implicitWidth: 18
    implicitHeight: 18
    Repeater {
        model: [[0, -1], [1, 0], [0, 1], [-1, 0]]
        Rectangle {
            required property var modelData
            width: 5; height: 5
            rotation: 45
            color: "transparent"
            border.width: 1.4
            border.color: root.color
            x: root.width / 2 - width / 2 + modelData[0] * 4.8
            y: root.height / 2 - height / 2 + modelData[1] * 4.8
        }
    }
}
