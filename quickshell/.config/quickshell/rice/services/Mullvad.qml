pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root
    property string state: ""
    property string relay: ""
    property string location: ""
    property string ip: ""

    readonly property bool connected: state === "Connected"
    readonly property bool connecting: state.startsWith("Connecting")

    readonly property var _poll: Process {
        running: true
        command: ["sh", "-c", "mullvad status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = this.text;
                const lines = out.split("\n");
                root.state = (lines[0] || "").trim();
                const relayM = out.match(/Relay:\s+(\S+)/);
                root.relay = relayM ? relayM[1] : "";
                const locM = out.match(/Visible location:\s+(.+)/);
                root.location = locM ? locM[1].trim() : "";
                const ipM = out.match(/IPv4:\s+(\S+)/);
                root.ip = ipM ? ipM[1] : "";
            }
        }
    }

    readonly property var _timer: Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: if (!root._poll.running) root._poll.running = true
    }

    readonly property var _toggleProc: Process {
        id: toggleProc
        command: ["sh", "-c", "if [ \"$(mullvad status | head -n1)\" = \"Connected\" ]; then mullvad disconnect; else mullvad connect; fi"]
        running: false
        onRunningChanged: if (!running) root._poll.running = true
    }

    readonly property var _reconnectProc: Process {
        id: reconnectProc
        command: ["mullvad", "reconnect"]
        running: false
        onRunningChanged: if (!running) root._poll.running = true
    }

    function toggle()    { toggleProc.running = true; }
    function reconnect() { reconnectProc.running = true; }
}
