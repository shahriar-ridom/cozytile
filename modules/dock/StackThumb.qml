import QtQuick
import Quickshell.Widgets
import "../../config"
import "../../services"

// One stack entry drawn at `size`: images show a (lazily decoded, downscaled) thumbnail, everything else its kind icon.
Item {
    id: root

    property var entry: null
    property int size: 48
    readonly property bool image: FolderService.isImage(entry)

    width: size; height: size

    ClippingRectangle {
        visible: root.image
        anchors.fill: parent
        radius: Math.round(root.size * 0.18)
        color: Theme.hover
        Image {
            anchors.fill: parent
            source: root.image ? root.entry.url : ""
            sourceSize: Qt.size(root.size * 2, root.size * 2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
        }
    }
    IconImage {
        visible: !root.image && root.entry !== null
        anchors.fill: parent
        mipmap: true
        source: root.entry ? FolderService.iconPath(root.entry.icon ?? FolderService.iconName(root.entry)) : ""
    }
}
