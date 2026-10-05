import QtQuick
import Quickshell.Io

// Runs a command where only the newest request matters (search as you type,
// lyrics for the current track). A request while one runs waits; when the
// running one exits its output is dropped and the newest pending one starts.
// `done(stdout, stderr, code)` fires for the newest request only.
QtObject {
    id: root

    property var _pending: null
    property bool _stale: false
    readonly property bool busy: _proc.running || _pending !== null
    signal done(string stdout, string stderr, int code)

    function run(cmd) {
        if (_proc.running) { _pending = cmd; _stale = true; return; }
        _start(cmd);
    }
    function _start(cmd) {
        _stale = false;
        _proc.command = cmd;
        _proc.running = true;
    }

    readonly property var _proc: Process {
        stdout: StdioCollector { id: out; waitForEnd: true }
        stderr: StdioCollector { id: err; waitForEnd: true }
        onExited: code => {
            if (root._pending !== null) {
                const next = root._pending;
                root._pending = null;
                Qt.callLater(() => root._start(next));
                return;
            }
            if (!root._stale) root.done(out.text, err.text, code);
        }
    }
}
