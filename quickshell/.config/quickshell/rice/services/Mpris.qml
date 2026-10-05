pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"
import Quickshell.Services.Mpris as M

QtObject {
    id: root
    readonly property var all: M.Mpris.players
    readonly property var _list: all && all.values ? all.values : []
    // Picked by hand in the dashboard; sticks until that player goes away.
    property var _picked: null
    readonly property var players: _list

    // Hand-picked > playing (music player first) > music player > first.
    readonly property var player: {
        if (_picked && _list.indexOf(_picked) >= 0) return _picked;
        const isMusic = p => (p.identity || "").toLowerCase().replace(/[ -]/g, "_") === Settings.musicPlayer
                            || (p.dbusName || "").indexOf(Settings.musicPlayer) >= 0;
        const playingNow = _list.filter(p => p && p.isPlaying);
        if (playingNow.length) return playingNow.find(isMusic) || playingNow[0];
        return _list.find(p => p && isMusic(p)) || (_list.length > 0 ? _list[0] : null);
    }
    function select(p) { _picked = p; }
    function playerName(p) { return p ? (p.identity || p.dbusName || "player") : ""; }
    readonly property string identity: playerName(player)

    readonly property bool running: player !== null
    readonly property bool hasPlayer: running

    readonly property string title: player ? (player.trackTitle || "") : ""
    readonly property string artist: {
        if (!player) return "";
        const a = player.trackArtists;
        if (Array.isArray(a)) return a.join(", ");
        if (typeof a === "string") return a;
        return player.trackArtist || "";
    }
    readonly property string album: player ? (player.trackAlbum || "") : ""
    readonly property string artUrl: player ? (player.trackArtUrl || "") : ""
    readonly property bool playing: player ? player.isPlaying === true : false

    property real position: 0
    readonly property real length: player ? (player.length || 0) : 0
    function _refreshPos() { position = player ? (player.position || 0) : 0 }
    onPlayerChanged: _refreshPos()
    readonly property bool canSeek: player ? player.canSeek === true : false
    readonly property bool canNext: player ? player.canGoNext === true : false
    readonly property bool canPrev: player ? player.canGoPrevious === true : false

    readonly property bool shuffle: player ? player.shuffle === true : false
    readonly property int loop: player ? (player.loopState || 0) : 0
    readonly property real volume: player ? (player.volume !== undefined ? player.volume : 1) : 0

    function togglePlay()    { if (player) player.togglePlaying(); }
    function next()          { if (player && player.canGoNext) player.next(); }
    function previous()      { if (player && player.canGoPrevious) player.previous(); }
    function seek(pos)       { if (player && player.canSeek) player.position = pos; }
    function toggleShuffle() { if (player) player.shuffle = !player.shuffle; }
    function cycleLoop() {
        if (!player) return;
        const next = ((player.loopState || 0) + 1) % 3;
        player.loopState = next;
    }
    function setVolume(v)    { if (player) player.volume = Math.max(0, Math.min(1, v)); }

    // The music player lives in a tmux session: open attaches a terminal to it
    // (starting it there the first time, so a login prompt is visible);
    // closing the terminal only detaches, so playback continues.
    function launch() {
        Quickshell.execDetached(["sh", "-c",
            'tmux has-session -t "$1" 2>/dev/null && exec "$3" -e tmux attach -t "$1"; '
          + 'exec "$3" -e tmux new-session -s "$1" "$2"',
            "sh", Settings.musicSession, Settings.musicPlayer, Settings.terminal]);
    }

    readonly property var _ticker: Timer {
        interval: 500
        running: root.running
        repeat: true
        onTriggered: root._refreshPos()
    }
}
