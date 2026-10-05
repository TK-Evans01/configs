pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

// Pushes the committed theme to the apps outside the shell: sends the
// resolved palette + roles as JSON to scripts/theme-apply.py, which writes
// ~/.local/state/rice/theme/* (Hyprland, ghostty, tmux, nvim, btop,
// zathura, SDDM) and reloads what's running. Never for a hover preview;
// debounced so a switch's cross-fade lands as one apply.
QtObject {
    id: root

    readonly property var _paletteKeys: ["bg0", "bg1", "bg2", "bg3", "bg4", "fg0", "fg1", "grey", "greyDim"]
        .concat(["red", "orange", "yellow", "green", "aqua", "blue", "purple"].reduce((a, h) => a.concat([h, h + "Dim", h + "Bright"]), []))
    readonly property var _roleKeys: ["background", "surface0", "surface1", "surface2", "surface3", "text", "textBright",
        "textReverse", "subtext", "muted", "accent", "success", "warning", "error", "info", "pending", "outline",
        "catMedia", "catSystem", "catNet", "catTime", "catWeather", "catDev", "catNotify"]

    function _hex(c) {
        const h = v => ("0" + Math.round(v * 255).toString(16)).slice(-2);
        return "#" + h(c.r) + h(c.g) + h(c.b);
    }
    function snapshot() {
        const pal = {}, roles = {};
        for (const k of _paletteKeys) pal[k] = _hex(Theme[k]);
        for (const k of _roleKeys) roles[k] = _hex(Theme[k]);
        return { id: Theme.themeId, variant: Theme._theme.variant || "dark", shape: Theme.shape,
                 font: Theme.fontFamily, palette: pal, roles: roles };
    }

    // Changes only for the committed theme (a hover preview leaves it alone).
    readonly property string _sig: Theme.previewId === ""
        ? [Theme.themeId, Theme.shape, Theme.text, Theme.background, Theme.accent, Theme.outline].join("|") : _lastSig
    property string _lastSig: ""
    // Only when the committed theme really changed (not a preview ending, and
    // not on startup / hot reload — the last apply is still in place).
    on_SigChanged: if (Theme.previewId === "" && _sig !== _appliedSig && _ready) _debounce.restart()
    property string _appliedSig: ""
    property bool _ready: false
    // Settle first (theme file + palette load), then remember what's showing.
    readonly property var _settle: Timer { interval: 3000; running: true; onTriggered: { root._appliedSig = root._sig; root._ready = true; } }
    readonly property var _debounce: Timer {
        interval: Theme.animLong + 150
        onTriggered: root.apply()
    }

    property string lastResult: ""
    function apply() {
        if (_proc.running) { _debounce.restart(); return; }
        _lastSig = _sig;
        _appliedSig = _sig;
        _proc.payload = JSON.stringify(snapshot());
        _proc.running = true;
    }
    readonly property var _proc: Process {
        property string payload: ""
        command: ["python3", Quickshell.shellDir + "/scripts/theme-apply.py"]
        stdinEnabled: true
        onStarted: { write(payload); stdinEnabled = false; }
        stdout: StdioCollector { onStreamFinished: root.lastResult = this.text.trim() }
        stderr: StdioCollector { onStreamFinished: if (this.text.trim()) console.warn("theme-apply:", this.text.trim()) }
        onExited: stdinEnabled = true
    }

    // Kept for shell.qml's startup touch.
    readonly property int windowRounding: Theme.round ? 10 : 0
}
