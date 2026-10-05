pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

// Lyrics for the current Mpris track from lrclib.net (no key). Looked up only
// while something shows them (`wanted`) and the track changed; hits are cached
// in ~/.cache/quickshell/lyrics.
//
// status: "idle" | "loading" | "synced" | "plain" | "instrumental" | "none"
QtObject {
    id: root

    property bool wanted: false
    property string status: "idle"
    // [{ time (s, -1 for plain), text }]
    property var lines: []
    readonly property bool synced: status === "synced"

    readonly property int currentIndex: {
        if (!synced) return -1;
        const t = Mpris.position + 0.25;
        let i = -1;
        for (let k = 0; k < lines.length && lines[k].time <= t; k++) i = k;
        return i;
    }

    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/quickshell/lyrics"
    readonly property string trackKey: Mpris.title ? Mpris.artist + " - " + Mpris.title : ""
    property string _loadedKey: ""

    onTrackKeyChanged: _maybeFetch()
    onWantedChanged: _maybeFetch()

    function _maybeFetch() {
        if (!Settings.lyrics || !wanted || trackKey === _loadedKey) return;
        _loadedKey = trackKey;
        lines = [];
        if (!trackKey) { status = "idle"; return; }
        status = "loading";
        fetcher.run(["sh", "-c", `
dir="$1"; file="$dir/$(printf '%s' "$2 - $3" | tr '/' '_' | cut -c1-180).json"
if [ -s "$file" ]; then cat "$file"; exit 0; fi
mkdir -p "$dir"
ua='rice-quickshell (github.com/quickshell)'
out="$(curl -sfG --max-time 8 https://lrclib.net/api/get -H "User-Agent: $ua" \
  --data-urlencode "artist_name=$2" --data-urlencode "track_name=$3" \
  --data-urlencode "album_name=$4" --data-urlencode "duration=$5")"
[ -z "$out" ] && out="$(curl -sfG --max-time 8 https://lrclib.net/api/search -H "User-Agent: $ua" \
  --data-urlencode "artist_name=$2" --data-urlencode "track_name=$3" | jq -c '.[0] // empty')"
[ -n "$out" ] && printf '%s' "$out" > "$file"
printf '%s' "$out"
`, "sh", cacheDir, Mpris.artist.split(",")[0].trim(), Mpris.title, Mpris.album, String(Math.round(Mpris.length))]);
    }

    function _parse(text) {
        let o = null;
        try { o = JSON.parse(text); } catch (e) { o = null; }
        if (!o) { status = "none"; return; }
        if (o.instrumental) { status = "instrumental"; return; }
        if (o.syncedLyrics) {
            const out = [];
            for (const l of o.syncedLyrics.split("\n")) {
                const m = l.match(/^\[(\d+):(\d+(?:\.\d+)?)\]\s?(.*)$/);
                if (m) out.push({ time: Number(m[1]) * 60 + Number(m[2]), text: m[3] });
            }
            lines = out;
            status = out.length ? "synced" : "none";
            return;
        }
        if (o.plainLyrics) {
            lines = o.plainLyrics.split("\n").map(t => ({ time: -1, text: t }));
            status = "plain";
            return;
        }
        status = "none";
    }

    // Newest track only: a fetch for a track already skipped is dropped.
    readonly property var fetcher: LatestRun {
        onDone: (stdout, stderr, code) => root._parse(stdout)
    }
}
