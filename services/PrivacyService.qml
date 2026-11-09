pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// "Which app is listening / recording right now": capture streams in PipeWire (microphone, camera / screen video).
Singleton {
    id: root

    PwObjectTracker { objects: Pipewire.nodes.values }

    function _cls(n) { return n.properties ? (n.properties["media.class"] || "") : ""; }
    function _app(n) { return n.properties ? (n.properties["application.name"] || n.properties["node.name"] || n.name) : n.name; }

    // meters that merely monitor a sink are not "recording"
    readonly property var micStreams: Pipewire.nodes.values.filter(n => n.isStream && _cls(n) === "Stream/Input/Audio"
        && !(n.properties && n.properties["stream.capture.sink"] === "true"))
    readonly property var videoStreams: Pipewire.nodes.values.filter(n => n.isStream && _cls(n) === "Stream/Input/Video")

    readonly property bool mic: micStreams.length > 0
    readonly property bool video: videoStreams.length > 0
    readonly property string micApps: _names(micStreams)
    readonly property string videoApps: _names(videoStreams)
    readonly property bool any: mic || video

    function _names(list) {
        const out = [];
        for (const n of list) { const a = _app(n); if (out.indexOf(a) < 0) out.push(a); }
        return out.join(", ");
    }

    // announce when something starts (not on startup)
    property bool _armed: false
    Timer { interval: 4000; running: true; onTriggered: root._armed = true }
    // stream properties arrive a moment after the node appears: wait briefly before naming the app
    property string _pending: ""
    Timer {
        id: announce
        interval: 400
        onTriggered: {
            if (root._pending === "mic" && root.mic) ActivityService.post("priv-mic", "toast", {
                glyph: "\uf130", text: (root.micApps || "An app") + " is using the microphone", tone: "warn", priority: 55, ms: 3500 });
            else if (root._pending === "video" && root.video) ActivityService.post("priv-video", "toast", {
                glyph: "\uf03d", text: (root.videoApps || "An app") + " is capturing video", tone: "warn", priority: 55, ms: 3500 });
        }
    }
    onMicChanged: if (_armed && mic) { _pending = "mic"; announce.restart(); }
    onVideoChanged: if (_armed && video) { _pending = "video"; announce.restart(); }
}
