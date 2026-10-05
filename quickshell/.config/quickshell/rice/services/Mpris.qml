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
    // Some players (spotify_player) report a new play state ~1–3s after the
    // command; show the expected state right away and fall back to the
    // player's own once it reports (or after 4s).
    property var _expectPlaying: null
    readonly property bool _reportedPlaying: player ? player.isPlaying === true : false
    readonly property bool playing: _expectPlaying !== null ? _expectPlaying : _reportedPlaying
    on_ReportedPlayingChanged: if (_expectPlaying === _reportedPlaying) _expectPlaying = null
    readonly property var _expectTimer: Timer {
        interval: 4000
        onTriggered: root._expectPlaying = null
    }
    property real _seekHoldUntil: 0

    property real position: 0
    readonly property real length: player ? (player.length || 0) : 0
    function _refreshPos() {
        // Right after a seek the player may still report the old position.
        if (Date.now() < _seekHoldUntil) return;
        position = player ? (player.position || 0) : 0;
    }
    onPlayerChanged: _refreshPos()
    readonly property bool canSeek: player ? player.canSeek === true : false
    readonly property bool canNext: player ? player.canGoNext === true : false
    readonly property bool canPrev: player ? player.canGoPrevious === true : false

    // spotify_player has no shuffle/loop over MPRIS: those go through its CLI
    // and the state comes from Spotify.playbackShuffle / playbackRepeat.
    readonly property bool _viaCli: player !== null && !player.shuffleSupported && root.identity.toLowerCase().replace(/[ -]/g, "_") === Settings.musicPlayer
    readonly property bool shuffle: _viaCli ? Spotify.playbackShuffle : (player ? player.shuffle === true : false)
    readonly property int loop: _viaCli ? Spotify.playbackRepeat : (player ? (player.loopState || 0) : 0)
    readonly property real volume: player ? (player.volume !== undefined ? player.volume : 1) : 0

    function togglePlay() {
        if (!player) return;
        // Explicit play/pause from the state we show: togglePlaying() would go
        // by the player's lagging report and repeat the last command.
        const wantPlaying = !playing;
        _expectPlaying = wantPlaying;
        _expectTimer.restart();
        if (wantPlaying) player.play(); else player.pause();
    }
    function next()          { if (player && player.canGoNext) player.next(); }
    function previous()      { if (player && player.canGoPrevious) player.previous(); }
    function seek(pos) {
        if (!player || !player.canSeek) return;
        position = pos;
        _seekHoldUntil = Date.now() + 2500;
        player.position = pos;
    }
    function toggleShuffle() {
        if (_viaCli) { Spotify.cli(["playback", "shuffle"]); return; }
        if (player && player.shuffleSupported) player.shuffle = !player.shuffle;
    }
    function cycleLoop() {
        if (_viaCli) { Spotify.cli(["playback", "repeat"]); return; }
        if (!player || !player.loopSupported) return;
        player.loopState = ((player.loopState || 0) + 1) % 3;
    }
    function setVolume(v)    { if (player) player.volume = Math.max(0, Math.min(1, v)); }

    // The player runs headless (`spotify_player -d`, started by Hyprland).
    // Open: make sure the daemon runs, then show its TUI — a remote, in tmux
    // session musicSession — reusing it when it's already up there. Closing
    // the terminal only detaches; playback is the daemon's either way.
    function launch() {
        Quickshell.execDetached(["sh", "-c",
            'p="$1"; s="$2"; t="$3"; shift 3; '
          + 'pgrep -f "^$p -d" >/dev/null || { setsid -f "$p" -d >/dev/null 2>&1; sleep 2; }; '
          + 'if tmux has-session -t "$s" 2>/dev/null && [ "$(tmux display -p -t "$s" "#{pane_current_command}")" = "$p" ]; then '
          +   'exec "$t" -e tmux attach -t "$s"; fi; '
          + 'tmux kill-session -t "$s" 2>/dev/null; '
          + 'exec "$t" -e tmux new-session -s "$s" "$p" "$@"',
            "sh", Settings.musicPlayer, Settings.musicSession, Settings.terminal].concat(Settings.musicTuiArgs));
    }

    readonly property var _ticker: Timer {
        interval: 500
        running: root.running
        repeat: true
        onTriggered: root._refreshPos()
    }
}
