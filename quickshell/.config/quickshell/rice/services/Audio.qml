pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property int outPercent: 0
    property bool outMuted: false
    property string outDefault: ""
    property var outputs: []

    property int inPercent: 0
    property bool inMuted: false
    property string inDefault: ""
    property var inputs: []

    readonly property int percent: outPercent
    readonly property bool muted: outMuted

    readonly property var _poll: Process {
        running: true
        command: ["sh", "-c", [
            "echo '---out-vol---'",
            "pactl get-sink-volume @DEFAULT_SINK@ | awk '/Volume/{print $5; exit}' | tr -d '%'",
            "echo '---out-mute---'",
            "pactl get-sink-mute @DEFAULT_SINK@ | awk '{print $2}'",
            "echo '---out-def---'",
            "pactl get-default-sink",
            "echo '---in-vol---'",
            "pactl get-source-volume @DEFAULT_SOURCE@ | awk '/Volume/{print $5; exit}' | tr -d '%'",
            "echo '---in-mute---'",
            "pactl get-source-mute @DEFAULT_SOURCE@ | awk '{print $2}'",
            "echo '---in-def---'",
            "pactl get-default-source",
            "echo '---sinks---'",
            "pactl list short sinks | awk '{print $2}'",
            "echo '---sink-descs---'",
            "pactl list sinks | awk -F': ' '/Name:/{n=$2} /Description:/{print n\"\\t\"$2}'",
            "echo '---sources---'",
            "pactl list short sources | awk '$2 !~ /\\.monitor$/ {print $2}'",
            "echo '---source-descs---'",
            "pactl list sources | awk -F': ' '/Name:/{n=$2} /Description:/{print n\"\\t\"$2}'"
        ].join("; ")]
        stdout: StdioCollector {
            onStreamFinished: {
                const sections = {};
                let cur = null;
                for (const line of this.text.split("\n")) {
                    const m = line.match(/^---(.+)---$/);
                    if (m) { cur = m[1]; sections[cur] = []; continue; }
                    if (cur !== null) sections[cur].push(line);
                }
                const first = k => (sections[k] && sections[k][0] || "").trim();
                const all = k => (sections[k] || []).filter(l => l.trim() !== "");

                root.outPercent = parseInt(first("out-vol")) || 0;
                root.outMuted = first("out-mute") === "yes";
                root.outDefault = first("out-def");
                root.inPercent = parseInt(first("in-vol")) || 0;
                root.inMuted = first("in-mute") === "yes";
                root.inDefault = first("in-def");

                const buildList = (namesKey, descsKey) => {
                    const names = all(namesKey);
                    const descMap = {};
                    for (const l of all(descsKey)) {
                        const tab = l.indexOf("\t");
                        if (tab > 0) descMap[l.substring(0, tab)] = l.substring(tab + 1).trim();
                    }
                    return names.map(n => ({ name: n.trim(), description: descMap[n.trim()] || n.trim() }));
                };
                root.outputs = buildList("sinks", "sink-descs");
                root.inputs = buildList("sources", "source-descs");
            }
        }
    }

    // pactl subscribe streams events; each line re-triggers poll. Replaces periodic timer.
    readonly property var _subscribe: Process {
        running: true
        command: ["pactl", "subscribe"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (!line) return;
                if (line.indexOf("sink") >= 0 || line.indexOf("source") >= 0 || line.indexOf("server") >= 0) {
                    if (!root._poll.running) root._poll.running = true;
                }
            }
        }
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

    function toggleMute()       { _run(["pactl", "set-sink-mute",   "@DEFAULT_SINK@",   "toggle"]); }
    function toggleInputMute()  { _run(["pactl", "set-source-mute", "@DEFAULT_SOURCE@", "toggle"]); }
    function setOutputVolume(p) { _run(["pactl", "set-sink-volume",   "@DEFAULT_SINK@",   Math.max(0, Math.min(150, p)) + "%"]); }
    function setInputVolume(p)  { _run(["pactl", "set-source-volume", "@DEFAULT_SOURCE@", Math.max(0, Math.min(150, p)) + "%"]); }
    function setDefaultSink(n)   { _run(["pactl", "set-default-sink",   n]); }
    function setDefaultSource(n) { _run(["pactl", "set-default-source", n]); }
}
