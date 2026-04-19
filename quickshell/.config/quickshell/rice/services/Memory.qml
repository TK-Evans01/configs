pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root
    property int percent: 0

    readonly property var _poll: Process {
        running: true
        command: ["sh", "-c", "awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf \"%d\\n\", (t-a)*100/t}' /proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: root.percent = parseInt(this.text.trim()) || 0
        }
    }

    readonly property var _timer: Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: if (!root._poll.running) root._poll.running = true
    }
}
