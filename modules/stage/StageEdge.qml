import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../config"
import "../../services"

// Invisible hot edge: resting the pointer on the screen edge opens the overview.
PanelWindow {
    id: win
    readonly property bool onRight: StageService.get("side") === "right"
    visible: StageService.enabled && StageService.get("hotEdge") && !UiState.overview
    color: "transparent"
    anchors { top: true; bottom: true; left: !onRight; right: onRight }
    margins { top: 70; bottom: 70 }          // keep the corners (bar, hot corners) clear
    implicitWidth: 3
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "cozytile-stageedge"
    WlrLayershell.layer: WlrLayer.Top

    // right after the overview closes the pointer may still rest on the edge (the edge window just reappeared
    // under it): ignore that first enter so it does not reopen
    property double closedAt: 0
    Connections { target: UiState; function onOverviewChanged() { if (!UiState.overview) win.closedAt = Date.now(); } }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: if (Date.now() - win.closedAt > 400) dwell.restart()
        onExited: dwell.stop()
    }
    Timer { id: dwell; interval: StageService.get("edgeDelay"); onTriggered: UiState.overview = true }
}
