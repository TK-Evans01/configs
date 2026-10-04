pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

// grimblast-based capture. target: "area" (drag a region or click a window),
// "active" (focused window), "output" (this monitor), "screen" (all).
// action: "save" (save + copy), "copy", "text" (OCR → clipboard), "edit" (satty).
QtObject {
    id: root

    property string action: "save"
    property bool hasEditor: false
    property bool hasOcr: false
    property string latest: ""          // newest file in the folder
    readonly property string dir: Settings.screenshotDir

    readonly property var _probe: Process {
        running: true
        command: ["sh", "-c", "command -v satty >/dev/null && echo edit; tesseract --list-langs 2>/dev/null | grep -qx \"$1\" && echo ocr", "sh", Settings.ocrLang]
        stdout: StdioCollector {
            onStreamFinished: {
                root.hasEditor = this.text.indexOf("edit") >= 0;
                root.hasOcr = this.text.indexOf("ocr") >= 0;
            }
        }
    }

    function refreshLatest() {
        if (!_latest.running) _latest.running = true;
        if (!_probe.running) _probe.running = true;   // pick up satty / tesseract installs
    }
    readonly property var _latest: Process {
        command: ["sh", "-c", "ls -t \"$1\"/*.png 2>/dev/null | head -n1", "sh", root.dir]
        stdout: StdioCollector {
            onStreamFinished: root.latest = this.text.trim()
        }
    }

    // The popup that asked for it is still on screen; give it time to go.
    function take(target, act) {
        _pending = [target, act || action];
        _delay.restart();
    }
    property var _pending: null
    readonly property var _delay: Timer {
        interval: Theme.animLong + 80
        onTriggered: root._shoot(root._pending[0], root._pending[1])
    }

    function _shoot(target, act) {
        const scripts = {
            save: 'mkdir -p "$1" && f="$1/$(date +%Y-%m-%d_%H-%M-%S).png" && grimblast --notify copysave "$2" "$f"',
            copy: 'grimblast --notify copy "$2"',
            text: 'grimblast save "$2" - | tesseract stdin stdout -l "$3" 2>/dev/null | sed "/^\\s*$/d" > "$4" && [ -s "$4" ] && wl-copy < "$4" && notify-send -a Screenshot "Text copied" "$(head -c 200 "$4")" || notify-send -a Screenshot "No text found"',
            edit: 'mkdir -p "$1" && grimblast save "$2" - | satty --filename - --output-filename "$1/$(date +%Y-%m-%d_%H-%M-%S).png" --copy-command wl-copy'
        };
        _proc.command = ["sh", "-c", scripts[act] || scripts.save, "sh", dir, target, Settings.ocrLang,
                         Quickshell.env("XDG_RUNTIME_DIR") + "/rice-ocr.txt"];
        _proc.running = true;
    }
    readonly property var _proc: Process {
        onExited: root.refreshLatest()
    }

    function openFolder() { Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && xdg-open "$1"', "sh", dir]); }
    function openLatest() { if (latest) Quickshell.execDetached(["xdg-open", latest]); }
}
