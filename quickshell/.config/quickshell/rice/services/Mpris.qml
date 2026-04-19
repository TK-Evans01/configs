pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell.Services.Mpris as M

QtObject {
    id: root
    readonly property var all: M.Mpris.players
    readonly property var _list: all && all.values ? all.values : []
    readonly property var player: {
        for (let i = 0; i < _list.length; i++) {
            const p = _list[i];
            if (p && (p.identity || "").toLowerCase() === "ncspot") return p;
        }
        return _list.length > 0 ? _list[0] : null;
    }

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

    // ncspot runs in a detached tmux session named "ncspot".
    // First click starts it headless; subsequent clicks attach a terminal to the session.
    readonly property var _launcher: Process {
        id: launcher
        running: false
        command: ["sh", "-c",
            "if tmux has-session -t ncspot 2>/dev/null; then "
          +   "exec alacritty -e tmux attach -t ncspot; "
          + "else "
          +   "exec tmux new-session -d -s ncspot ncspot; "
          + "fi"]
    }
    function launch() { launcher.running = true; }

    readonly property var _ticker: Timer {
        interval: 500
        running: root.running
        repeat: true
        onTriggered: root._refreshPos()
    }
}
