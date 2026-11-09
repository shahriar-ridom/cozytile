pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// PipeWire output/input state + control. Emits `osd` whenever the user-visible state changes.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool ready: sink !== null && sink.audio !== null
    readonly property real volume: ready ? sink.audio.volume : 0
    readonly property bool muted: ready ? sink.audio.muted : false
    readonly property bool hasMic: source !== null && source.audio !== null
    readonly property real micVolume: hasMic ? source.audio.volume : 0
    readonly property bool micMuted: hasMic ? source.audio.muted : true
    property real maxVolume: 1.0

    // Real output devices (not app streams).
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)

    // kind: "volume" | "mic"; value 0..1(+); muted
    signal osd(string kind, real value, bool muted)

    // Ignore the burst of property changes while PipeWire first connects.
    property bool _armed: false
    Timer { interval: 1500; running: true; onTriggered: root._armed = true }

    PwObjectTracker { objects: [root.sink, root.source].filter(o => o) }

    Connections {
        target: root.ready ? root.sink.audio : null
        // read from the node itself: root.volume / root.muted are bindings that may not have updated yet
        function onVolumeChanged() { if (root._armed && root.sink && root.sink.audio) root.osd("volume", root.sink.audio.volume, root.sink.audio.muted); }
        function onMutedChanged() { if (root._armed && root.sink && root.sink.audio) root.osd("volume", root.sink.audio.volume, root.sink.audio.muted); }
    }
    Connections {
        target: root.hasMic ? root.source.audio : null
        function onMutedChanged() { if (root._armed && root.source && root.source.audio) root.osd("mic", root.source.audio.volume, root.source.audio.muted); }
        function onVolumeChanged() { if (root._armed && root.source && root.source.audio) root.osd("mic", root.source.audio.volume, root.source.audio.muted); }
    }

    function setVolume(v) {
        if (!ready) return;
        sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(maxVolume, v));
    }
    function changeVolume(delta) { setVolume(volume + delta); }
    function toggleMute() { if (ready) sink.audio.muted = !sink.audio.muted; }
    function toggleMic() { if (hasMic) source.audio.muted = !source.audio.muted; }
    function setSink(node) { Pipewire.preferredDefaultAudioSink = node; }

    function icon() {
        if (muted || volume <= 0) return "";
        return volume < 0.5 ? "" : "";
    }
}
