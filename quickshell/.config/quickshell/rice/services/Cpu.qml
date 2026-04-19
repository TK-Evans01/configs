pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root
    property int percent: 0
    property var _prev: null

    readonly property var _poll: Process {
        running: true
        command: ["sh", "-c", "head -n1 /proc/stat"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split(/\s+/).slice(1).map(Number);
                const idle = parts[3] + parts[4];
                const total = parts.reduce((a, b) => a + b, 0);
                if (root._prev) {
                    const dt = total - root._prev.total;
                    const di = idle - root._prev.idle;
                    root.percent = dt > 0 ? Math.round((1 - di / dt) * 100) : 0;
                }
                root._prev = { total, idle };
            }
        }
    }

    readonly property var _timer: Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: if (!root._poll.running) root._poll.running = true
    }
}
