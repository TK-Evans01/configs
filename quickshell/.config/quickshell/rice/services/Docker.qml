pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property var containers: []
    property bool daemonUp: false

    readonly property int total: containers.length
    readonly property int running: containers.filter(c => c.state === "running").length

    function _parseHealth(status) {
        const m = status.match(/\((healthy|unhealthy|starting)\)/);
        return m ? m[1] : "";
    }

    readonly property var _poll: Process {
        running: true
        command: ["sh", "-c", "docker ps -a --no-trunc --format '{{json .}}' 2>/dev/null || echo __DAEMON_DOWN__"]
        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim();
                if (text === "__DAEMON_DOWN__" || text === "") {
                    root.daemonUp = text !== "__DAEMON_DOWN__";
                    root.containers = [];
                    return;
                }
                root.daemonUp = true;
                const list = [];
                for (const line of text.split("\n")) {
                    if (!line.trim()) continue;
                    try {
                        const o = JSON.parse(line);
                        list.push({
                            id: o.ID || "",
                            name: o.Names || "",
                            image: o.Image || "",
                            state: o.State || "",
                            status: o.Status || "",
                            ports: o.Ports || "",
                            health: root._parseHealth(o.Status || "")
                        });
                    } catch (e) { /* skip bad line */ }
                }
                list.sort((a, b) => {
                    if (a.state === b.state) return a.name.localeCompare(b.name);
                    if (a.state === "running") return -1;
                    if (b.state === "running") return 1;
                    return a.state.localeCompare(b.state);
                });
                root.containers = list;
            }
        }
    }

    // docker events streams container lifecycle changes; any line re-triggers poll.
    readonly property var _events: Process {
        running: true
        command: ["sh", "-c", "docker events --format '{{.Type}} {{.Action}}' --filter type=container 2>/dev/null"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (!line) return;
                if (!root._poll.running) root._poll.running = true;
            }
        }
        onRunningChanged: if (!running) restart.restart()
    }

    // If `docker events` exits (daemon restart), retry after a delay.
    readonly property var _restart: Timer {
        id: restart
        interval: 3000
        repeat: false
        onTriggered: if (!root._events.running) root._events.running = true
    }

    // Fallback poll in case events stream silent (e.g. daemon down, will also detect recovery).
    readonly property var _timer: Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: if (!root._poll.running) root._poll.running = true
    }

    function _run(args) {
        runner.command = args;
        runner.running = true;
    }

    readonly property var _runner: Process {
        id: runner
        running: false
        onRunningChanged: if (!running) root._poll.running = true
    }

    function start(id)   { _run(["docker", "start", id]); }
    function stop(id)    { _run(["docker", "stop", id]); }
    function restartC(id){ _run(["docker", "restart", id]); }
}
