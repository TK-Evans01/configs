import QtQuick
import Quickshell.Io

// Runs commands one at a time without dropping any. A command given a
// `key` replaces an earlier queued one with the same key, so a slider
// drag or wheel burst ends on the latest value instead of losing steps.
// `drained` fires once the queue is empty (refresh state there).
QtObject {
    id: root

    property var _queue: []   // [{ key, args }]
    readonly property bool busy: _proc.running || _queue.length > 0
    signal drained()

    function run(args, key) {
        const q = _queue.slice();
        const i = key ? q.findIndex(c => c.key === key) : -1;
        if (i >= 0) q[i] = { key: key, args: args };
        else q.push({ key: key || "", args: args });
        _queue = q;
        _next();
    }

    function _next() {
        if (_proc.running) return;
        if (_queue.length === 0) { drained(); return; }
        const c = _queue[0];
        _queue = _queue.slice(1);
        _proc.command = c.args;
        _proc.running = true;
    }

    readonly property var _proc: Process {
        onRunningChanged: if (!running) root._next()
    }
}
