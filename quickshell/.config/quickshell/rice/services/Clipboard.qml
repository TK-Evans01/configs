pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

// Clipboard history through cliphist. While cliphist exists the shell keeps
// `wl-paste --watch cliphist store` running (text + images). Image entries get
// thumbnails decoded into ~/.cache/quickshell/cliphist/<id>.png.
// entries: [{ id, text, image (bool), info, thumb }]
QtObject {
    id: root

    property bool available: false
    property var entries: []
    readonly property string thumbDir: Quickshell.env("HOME") + "/.cache/quickshell/cliphist"

    readonly property var _probe: Process {
        running: true
        command: ["sh", "-c", "command -v cliphist >/dev/null && command -v wl-paste >/dev/null"]
        onExited: code => {
            root.available = code === 0;
            if (root.available) root.load();
        }
    }

    // One process per type, run directly: background jobs of an sh wrapper
    // outlived the shell and piled up.
    readonly property var _watchText: Process {
        running: root.available
        command: Settings.tether.concat(["wl-paste", "--type", "text", "--watch", "cliphist", "store"])
    }
    readonly property var _watchImage: Process {
        running: root.available
        command: Settings.tether.concat(["wl-paste", "--type", "image", "--watch", "cliphist", "store"])
    }

    // Re-probes while missing, so installing cliphist needs no shell restart.
    function load() {
        if (!available) { if (!_probe.running) _probe.running = true; return; }
        if (!_list.running) _list.running = true;
    }

    // "[[ binary data 12 KiB png 800x600 ]]" → image
    function _parse(text) {
        const out = [];
        for (const line of text.split("\n")) {
            const tab = line.indexOf("\t");
            if (tab <= 0) continue;
            const id = line.slice(0, tab), body = line.slice(tab + 1);
            const m = body.match(/^\[\[ binary data (.+?) (\w+) (\d+x\d+) \]\]$/);
            out.push(m ? { id, text: m[3] + " " + m[2], image: true, info: m[1], thumb: "file://" + thumbDir + "/" + id + ".png" }
                       : { id, text: body, image: false, info: "", thumb: "" });
        }
        return out.slice(0, Settings.clipboardMax);
    }

    readonly property var _list: Process {
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.entries = root._parse(this.text);
                const ids = root.entries.filter(e => e.image).slice(0, 40).map(e => e.id);
                if (ids.length) {
                    root._thumbs.command = ["sh", "-c",
                        'd="$1"; shift; mkdir -p "$d"; for id; do [ -s "$d/$id.png" ] || cliphist decode "$id" > "$d/$id.png"; done',
                        "sh", root.thumbDir].concat(ids);
                    root._thumbs.running = true;
                }
            }
        }
    }
    readonly property var _thumbs: Process {
        onExited: root.thumbsVersion++
    }
    // Bumped when thumbnails land so Images reload.
    property int thumbsVersion: 0

    readonly property var _runner: Process {
        onExited: root.load()
    }
    function _run(cmd) {
        _runner.command = ["sh", "-c", cmd[0]].concat(["sh"]).concat(cmd.slice(1));
        _runner.running = true;
    }
    function copy(e) { _run(['cliphist decode "$1" | wl-copy', e.id]); }
    function remove(e) { _run(['printf "%s\\t\\n" "$1" | cliphist delete; rm -f "$2/$1.png"', e.id, thumbDir]); }
    function wipe() { _run(['cliphist wipe; rm -rf "$1"', thumbDir]); }
}
