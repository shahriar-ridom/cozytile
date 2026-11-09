pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Picks the most relevant MPRIS player: a playing one, else the first available.
Singleton {
    id: root
    readonly property var players: Mpris.players.values
    readonly property MprisPlayer player: {
        for (const p of players) if (p.isPlaying) return p;
        return players.length > 0 ? players[0] : null;
    }
    readonly property bool active: player !== null && (player.trackTitle ?? "") !== ""
    readonly property string title: player ? (player.trackTitle ?? "") : ""
    readonly property string artist: player ? (player.trackArtist ?? "") : ""
    readonly property string album: player ? (player.trackAlbum ?? "") : ""
    readonly property string art: player ? (player.trackArtUrl ?? "") : ""
    readonly property bool playing: player ? player.isPlaying : false

    function toggle() { if (player && player.canTogglePlaying) player.togglePlaying(); }
    function next() { if (player && player.canGoNext) player.next(); }
    function previous() { if (player && player.canGoPrevious) player.previous(); }
}
