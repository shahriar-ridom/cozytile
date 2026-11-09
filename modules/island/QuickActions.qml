import QtQuick
import "../../config"
import "../../services"
import "../../components"

// Shortcut row at the bottom of the expanded island.
Row {
    id: root
    signal done()      // an action opened another surface: collapse the island
    spacing: 8

    IconButton { glyph: ""; label: "Theme"; size: 38; glyphSize: 13; onClicked: Theme.next() }
    IconButton { glyph: ""; label: "Wallpaper"; size: 38; onClicked: { UiState.toggle("wallpaper"); root.done(); } }
    IconButton { glyph: AudioService.micMuted ? "" : ""; size: 38; active: AudioService.hasMic && !AudioService.micMuted
        onClicked: AudioService.toggleMic() }
    IconButton { glyph: ""; size: 38; onClicked: { UiState.toggle("audioPicker"); root.done(); } }
    IconButton { glyph: ""; size: 38; onClicked: { UiState.toggle("power"); root.done(); } }
}
