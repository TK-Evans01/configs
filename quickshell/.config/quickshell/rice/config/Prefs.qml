pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// User choices that the shell changes at runtime (theme, shape, font), kept in
// ~/.local/state/rice/prefs.json. Readonly defaults stay in Settings.qml.
// Writes wait until the file has loaded (so defaults never clobber it) and
// are coalesced into one save per event-loop turn.
Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/.local/state/rice"
    readonly property string path: dir + "/prefs.json"
    property bool loaded: false

    // Empty string = follow the theme's own default.
    readonly property string theme: data.theme
    readonly property string shape: data.shape
    readonly property string font: data.font
    readonly property bool dnd: data.dnd

    // Settings overrides: key → value. Reassigned (not mutated) so bindings
    // that read get() re-evaluate.
    readonly property var overrides: data.overrides
    function get(key, fallback) {
        const o = data.overrides;
        return o && Object.prototype.hasOwnProperty.call(o, key) ? o[key] : fallback;
    }
    function isSet(key) { return data.overrides && Object.prototype.hasOwnProperty.call(data.overrides, key); }
    // Writes made before the file loaded are re-applied once it has.
    property var _pending: []
    function override(key, value) {
        if (!loaded) _pending = _pending.concat([["override", key, value]]);
        const o = Object.assign({}, data.overrides || {});
        o[key] = value;
        data.overrides = o;
        _save.restart();
    }
    function reset(key) {
        if (!isSet(key)) return;
        const o = Object.assign({}, data.overrides);
        delete o[key];
        data.overrides = o;
        _save.restart();
    }

    function set(key, value) {
        if (!(key in _known)) { console.warn("Prefs: unknown key", key); return; }
        if (!loaded) _pending = _pending.concat([["set", key, value]]);
        data[key] = value;
        _save.restart();
    }
    readonly property var _known: ({ theme: 1, shape: 1, font: 1, dnd: 1 })

    readonly property var _mkdir: Process {
        running: true
        command: ["mkdir", "-p", root.dir]
        onExited: file.reload()
    }

    readonly property var _save: Timer {
        interval: 0
        onTriggered: if (root.loaded) file.writeAdapter()
    }

    readonly property var file: FileView {
        path: root.path
        blockLoading: false
        watchChanges: true
        atomicWrites: true
        onFileChanged: reload()
        onLoaded: {
            root.loaded = true;
            const p = root._pending;
            root._pending = [];
            for (const [kind, k, v] of p) kind === "set" ? root.set(k, v) : root.override(k, v);
        }
        onLoadFailed: err => {
            // First run: nothing on disk yet, write the defaults.
            if (err === FileViewError.FileNotFound) { root.loaded = true; writeAdapter(); }
            else console.warn("Prefs: can't read", root.path, err);
        }

        JsonAdapter {
            id: data
            property int schema: 1
            property string theme: "gruvbox-material-dark"
            property string shape: ""
            property string font: ""
            property bool dnd: false
            property var overrides: ({})
        }
    }
}
