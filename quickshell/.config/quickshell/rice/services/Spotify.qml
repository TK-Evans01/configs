pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

// spotify_player's library through its CLI (talks to the running player):
// playlists + saved albums, and starting one of them (or Liked Songs).
// Loaded while something shows it (`wanted`); needs the player running.
QtObject {
    id: root

    property bool wanted: false
    property bool shuffle: false
    property bool loading: false
    property string error: ""
    property var playlists: []     // [{ id, name, owner }]
    property var albums: []        // [{ id, name, artist, year }]

    // Shuffle / repeat of the current playback (not in its MPRIS): 0 off,
    // 1 track, 2 context — same numbering as MPRIS loop states.
    property bool playbackShuffle: false
    property int playbackRepeat: 0

    // Run a CLI command against the player, then re-read shuffle/repeat.
    function cli(args) {
        _cliProc.command = [Settings.musicPlayer].concat(args);
        _cliProc.running = true;
    }
    readonly property var _cliProc: Process {
        onExited: root._statusDelay.restart()
    }
    readonly property var _statusDelay: Timer {
        interval: 700
        onTriggered: root.refreshStatus()
    }
    function refreshStatus() { if (!_statusProc.running) _statusProc.running = true; }
    readonly property var _statusProc: Process {
        command: [Settings.musicPlayer, "get", "key", "playback"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const o = JSON.parse(this.text);
                    root.playbackShuffle = o.shuffle_state === true;
                    root.playbackRepeat = ({ off: 0, track: 1, context: 2 })[o.repeat_state] || 0;
                } catch (e) {}
            }
        }
    }

    // The library is cached on disk: shown at once, refetched in the
    // background when older than Settings.spotifyLibraryMaxAgeH (the Web API
    // behind it is heavily rate-limited — a fetch can stall ~30s).
    property real fetchedAt: 0
    onWantedChanged: {
        if (!wanted) return;
        refreshStatus();
        if (Date.now() - fetchedAt > Settings.spotifyLibraryMaxAgeH * 3600000) load();
    }
    readonly property var cacheFile: FileView {
        path: Quickshell.env("HOME") + "/.cache/quickshell/spotify-library.json"
        printErrors: false
        onLoaded: {
            try {
                const o = JSON.parse(text());
                root.playlists = o.playlists || [];
                root.albums = o.albums || [];
                root.fetchedAt = o.fetchedAt || 0;
            } catch (e) {}
        }
    }

    function load() {
        if (_proc.running) return;
        loading = true;
        _proc.running = true;
    }

    readonly property var _proc: Process {
        command: ["sh", "-c", 'p="$1"; printf "@@playlists\\n"; "$p" get key user-playlists; printf "\\n@@albums\\n"; "$p" get key user-saved-albums',
                  "sh", Settings.musicPlayer]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = this.text;
                const a = t.indexOf("@@playlists"), b = t.indexOf("@@albums");
                let pl = null, al = null;
                try { pl = JSON.parse(t.slice(a + 11, b)); } catch (e) {}
                try { al = JSON.parse(t.slice(b + 8)); } catch (e) {}
                if (!pl && !al) {
                    root.error = "start spotify_player first";
                } else {
                    root.error = "";
                    if (pl) root.playlists = pl.map(p => ({ id: p.id, name: p.name, owner: (p.owner || [])[0] || "" }));
                    if (al) root.albums = al.map(x => ({
                        id: x.id, name: x.name,
                        artist: (x.artists || []).map(r => r.name).join(", "),
                        year: (x.release_date || "").slice(0, 4)
                    }));
                    root.fetchedAt = Date.now();
                    root.cacheFile.setText(JSON.stringify({ fetchedAt: root.fetchedAt, playlists: root.playlists, albums: root.albums }));
                }
            }
        }
        onExited: root.loading = false
    }

    // Starting a context can take a couple of seconds; one at a time.
    property string startingId: ""
    readonly property var _startClear: Timer {
        interval: 4000
        onTriggered: root.startingId = ""
    }
    function _start(args) {
        const id = args[0] === "context" ? args[2] : "liked";
        if (startingId === id) return;
        startingId = id;
        _startClear.restart();
        const cmd = [Settings.musicPlayer, "playback", "start"].concat(args);
        if (shuffle && args[0] === "context") cmd.splice(4, 0, "--shuffle");
        Quickshell.execDetached(cmd);
    }
    function playPlaylist(id) { _start(["context", "--id", id, "playlist"]); }
    function playAlbum(id) { _start(["context", "--id", id, "album"]); }
    function playLiked() { _start(["liked"].concat(shuffle ? ["--random"] : [])); }
}
