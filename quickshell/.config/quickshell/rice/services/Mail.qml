pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

// Unread Proton mail through Proton Mail Bridge (scripts/proton-mail.py).
// state: "loading" | "ok" | "unconfigured" | "offline" | "error"
QtObject {
    id: root

    property string state_: "loading"
    property string error: ""
    property int unread: 0
    property int total: 0
    property var messages: []      // [{ uid, from, address, subject, date (s) }]
    property date updated: new Date(0)
    readonly property bool configured: state_ !== "unconfigured" && state_ !== "loading"

    readonly property string _script: Qt.resolvedUrl("../scripts/proton-mail.py").toString().replace("file://", "")
    property var _seen: null       // uids already notified about

    function refresh() {
        if (!proc.running) proc.running = true;
    }
    function openWebmail() { Quickshell.execDetached(["xdg-open", Settings.mailUrl]); }
    function startBridge() {
        Quickshell.execDetached(Settings.bridgeCommand);
        retry.restart();
    }

    readonly property var proc: Process {
        command: ["python3", root._script]
        stdout: StdioCollector {
            onStreamFinished: {
                let o = null;
                try { o = JSON.parse(this.text); } catch (e) { o = { state: "error", error: "bad helper output" }; }
                root.state_ = o.state;
                root.error = o.error || "";
                if (o.state !== "ok") return;
                root.unread = o.unread;
                root.total = o.total;
                root.messages = o.messages;
                root.updated = new Date();
                root._notifyNew(o.messages);
            }
        }
    }

    // First successful load just records what's there; later ones announce new uids.
    function _notifyNew(list) {
        const uids = list.map(m => m.uid);
        if (_seen !== null && Settings.mailNotify) {
            const fresh = list.filter(m => _seen.indexOf(m.uid) < 0);
            for (const m of fresh.slice(0, 3))
                Quickshell.execDetached(["notify-send", "-a", "Proton Mail", "-i", "mail-unread",
                                         m.from || m.address, m.subject]);
        }
        _seen = uids;
    }

    readonly property var timer: Timer {
        interval: Settings.mailRefreshSec * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
    readonly property var retry: Timer {
        interval: 8000
        onTriggered: root.refresh()
    }
}
