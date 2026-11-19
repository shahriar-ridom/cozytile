import QtQuick

// Mouse handling for one stack entry: hover, click to open, and drag out to other apps (as a file URI).
// `grab` is the item whose picture follows the pointer.
MouseArea {
    id: root

    required property var entry
    property Item grab: null
    signal opened()
    signal dragStarted()
    signal dragFinished()

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    drag.target: entry.url ? proxy : null
    drag.threshold: 12
    onClicked: opened()
    // the picture is taken on press, so it is ready when the drag begins
    onPressed: if (grab) grab.grabToImage(r => proxy.Drag.imageSource = r.url)

    // a stand-in that moves instead of the entry, so views keep their layout
    Item {
        id: proxy
        width: 1; height: 1
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction | Qt.LinkAction
        Drag.mimeData: ({ "text/uri-list": root.entry.url + "\r\n", "text/plain": root.entry.path })
        Drag.active: root.drag.active
        Drag.hotSpot: Qt.point(root.grab ? root.grab.width / 2 : 0, root.grab ? root.grab.height / 2 : 0)
        Drag.onActiveChanged: if (Drag.active) root.dragStarted()
        Drag.onDragFinished: root.dragFinished()
    }
}
