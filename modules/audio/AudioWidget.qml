import QtQuick
import Quickshell
import "../../config"
import "../../services"
import "../bar"

// Bar volume item: click = mute, scroll = volume, right click = output picker (see AudioPopup).
StatItem {
    id: root
    signal openPicker()
    icon: AudioService.icon()
    value: AudioService.muted ? "muted" : Math.round(AudioService.volume * 100) + "%"
    iconColor: AudioService.muted ? Theme.textMuted : Theme.barTextDim
    valueColor: AudioService.muted ? Theme.textMuted : Theme.barText
    onClicked: m => {
        if (m.button === Qt.RightButton) root.openPicker();
        else if (m.button === Qt.MiddleButton) AudioService.toggleMic();
        else AudioService.toggleMute();
    }
    onWheel: w => AudioService.changeVolume(w.angleDelta.y > 0 ? 0.03 : -0.03)
}
