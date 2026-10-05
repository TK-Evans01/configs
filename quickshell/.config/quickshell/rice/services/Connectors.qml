pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

// Third-party connections (config/connectors.json) and their state, via
// scripts/connectors.sh. `preview` walks the flows without touching real
// accounts: every login connector starts unconnected, connect/disconnect
// only report what they would run, typed values go to
// ~/.cache/rice/connectors-preview/.
QtObject {
    id: root

    property var defs: []
    property bool preview: false
    // Bumped on a mode switch: a check started in the other mode is dropped.
    property int _gen: 0
    onPreviewChanged: { _gen++; _queue = []; status = ({}); checkAll(); }
    // id → { state: ok|off|missing|error|checking, detail, note }
    property var status: ({})
    readonly property string _script: Quickshell.shellDir + "/scripts/connectors.sh"
    // Every run gets the mode as an argument, fixed when it starts.
    function _cmd(args) { return [_script].concat(preview ? ["--preview"] : [], args); }

    readonly property var _file: FileView {
        path: Quickshell.shellDir + "/config/connectors.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.defs = JSON.parse(text()).connectors; } catch (e) { console.warn("connectors.json", e); } }
    }

    function _set(id, patch) {
        const s = Object.assign({}, status);
        s[id] = Object.assign({}, s[id] || {}, patch);
        status = s;
    }

    // --- checks: one at a time, queued ---
    property var _queue: []
    function check(id) {
        if (_queue.indexOf(id) < 0) _queue = _queue.concat([id]);
        _set(id, { state: "checking" });
        _next();
    }
    function checkAll() { for (const d of defs) check(d.id); }
    function _next() {
        if (_checker.running || !_queue.length) return;
        _checker.cid = _queue[0];
        _checker.gen = _gen;
        _checker.command = _cmd(["check", _checker.cid]);
        _queue = _queue.slice(1);
        _checker.running = true;
    }
    readonly property var _checker: Process {
        property string cid: ""
        property int gen: 0
        command: []
        stdout: StdioCollector { id: checkOut; waitForEnd: true }
        // Read the result here, before _next() starts another check (stdout's
        // own finished signal can arrive after that and mix up results).
        onExited: {
            if (gen === root._gen) {
                const line = checkOut.text.trim().split("\n").pop() || "error\tno answer";
                const tab = line.indexOf("\t");
                root._set(cid, { state: line.slice(0, tab), detail: line.slice(tab + 1), at: new Date() });
            } else if (root._queue.indexOf(cid) < 0) {
                root._queue = [cid].concat(root._queue);   // started in the other mode: run again
            }
            // Next one on a fresh event-loop turn (not from inside this handler).
            Qt.callLater(root._next);
        }
    }

    // --- save a typed value (stdin, never on a command line) ---
    // Saves and logins/logouts are queued: a second one while the first runs
    // must not be dropped or reported against the wrong connector.
    property var _saveQ: []
    function save(id, field, value) {
        _saveQ = _saveQ.concat([{ id: id, cmd: _cmd(["save", id, field]), value: value }]);
        _nextSave();
    }
    function _nextSave() {
        if (_saver.running || !_saveQ.length) return;
        const j = _saveQ[0]; _saveQ = _saveQ.slice(1);
        _saver.cid = j.id; _saver.command = j.cmd; _saver.pending = j.value;
        _saver.running = true;
    }
    readonly property var _saver: Process {
        property string cid: ""
        property string pending: ""
        stdinEnabled: true
        onStarted: { write(pending + "\n"); pending = ""; stdinEnabled = false; }
        stdout: StdioCollector { onStreamFinished: root._set(_saver.cid, { note: this.text.trim() }) }
        stderr: StdioCollector { onStreamFinished: if (this.text.trim()) root._set(_saver.cid, { note: this.text.trim() }) }
        onExited: { stdinEnabled = true; root.check(cid); Qt.callLater(root._nextSave); }
    }

    // --- interactive login / logout ---
    // Real: opens the terminal with the flow, then re-checks every 5 s for 2 min.
    // Preview: runs the script (it only prints) and shows that as a note.
    function login(id) {
        if (preview) { _runNote(id, "login"); return; }
        Quickshell.execDetached([Settings.terminal, "-e", "sh", "-c",
            '"$0" login "$1"; echo; printf "done — press enter to close "; read -r _', _script, id]);
        _set(id, { note: "finish the login in the terminal; this re-checks on its own" });
        _watch.id = id; _watch.left = 24; _watch.restart();
    }
    function logout(id) { _runNote(id, "logout"); }
    property var _runQ: []
    function _runNote(id, what) {
        _runQ = _runQ.concat([{ id: id, cmd: _cmd([what, id]) }]);
        _nextRun();
    }
    function _nextRun() {
        if (_runner.running || !_runQ.length) return;
        const j = _runQ[0]; _runQ = _runQ.slice(1);
        _runner.cid = j.id; _runner.command = j.cmd;
        _runner.running = true;
    }
    readonly property var _runner: Process {
        property string cid: ""
        stdout: StdioCollector { onStreamFinished: if (_runner.cid) root._set(_runner.cid, { note: this.text.trim() }) }
        onExited: { if (cid) root.check(cid); Qt.callLater(root._nextRun); }
    }
    readonly property var _watch: Timer {
        property string id: ""
        property int left: 0
        interval: 5000
        repeat: true
        onTriggered: {
            if (--left <= 0 || (root.status[id] && root.status[id].state === "ok")) { stop(); return; }
            root.check(id);
        }
    }

    function resetPreview() { _runNote("", "reset-preview"); Qt.callLater(checkAll); }
}
