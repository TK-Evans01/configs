pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

// Desktop-session odds and ends for Quick Settings: night light (hyprsunset),
// do-not-disturb (dunst), user/host, and session power actions.
QtObject {
    id: root

    readonly property string user: Quickshell.env("USER") || ""

    // --- night light ---
    // hyprsunset keeps reporting its last temperature even while `identity`
    // is active, so on/off can't be read back from it. We keep
    // "on|off <kelvin> <gamma%>" in $XDG_RUNTIME_DIR/rice-nightlight (cleared
    // on reboot, like hyprsunset); without the file, hyprsunset's own numbers
    // decide (under 6000K = its profile has it on).
    property int temperature: 6000     // what hyprsunset reports
    property bool nightLight: false
    property int nightTemp: Settings.nightLightTemp
    property int nightGamma: Settings.nightLightGamma
    readonly property string _nlFile: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/rice-nightlight"

    // --- dunst ---
    property bool dnd: false
    property int historyCount: 0
    property int waitingCount: 0

    readonly property var _poll: Process {
        running: true
        command: ["sh", "-c", `
echo "temp $(hyprctl hyprsunset temperature 2>/dev/null | tr -dc '0-9')"
echo "gamma $(hyprctl hyprsunset gamma 2>/dev/null | tr -dc '0-9')"
echo "nl $(cat "$1" 2>/dev/null)"
echo "dnd $(dunstctl is-paused 2>/dev/null)"
echo "hist $(dunstctl count history 2>/dev/null)"
echo "wait $(dunstctl count waiting 2>/dev/null)"
`, "sh", root._nlFile]
        stdout: StdioCollector {
            onStreamFinished: {
                let saved = [];
                let gamma = 100;
                for (const line of this.text.split("\n")) {
                    const f = line.trim().split(/\s+/);
                    if (f[0] === "temp" && f[1]) root.temperature = Number(f[1]);
                    else if (f[0] === "gamma" && f[1]) gamma = Number(f[1]);
                    else if (f[0] === "nl") saved = f.slice(1).filter(x => x);
                    else if (f[0] === "dnd") root.dnd = f[1] === "true";
                    else if (f[0] === "hist") root.historyCount = Number(f[1]) || 0;
                    else if (f[0] === "wait") root.waitingCount = Number(f[1]) || 0;
                }
                if (root._nlBusy) return;   // a slider write is in flight
                if (saved.length) {
                    root.nightLight = saved[0] === "on";
                    if (saved[1]) root.nightTemp = Number(saved[1]);
                    if (saved[2]) root.nightGamma = Number(saved[2]);
                } else {
                    root.nightLight = root.temperature < 6000;
                    if (root.nightLight) { root.nightTemp = root.temperature; root.nightGamma = gamma; }
                }
            }
        }
    }

    readonly property var _timer: Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    function refresh() {
        if (!_poll.running) _poll.running = true;
    }

    readonly property var _runner: Process {
        onRunningChanged: if (!running) root.refresh()
    }
    function _run(args) {
        _runner.command = args;
        _runner.running = true;
    }

    function toggleNightLight() { setNightLight(!nightLight); }
    function setNightLight(on) {
        nightLight = on;   // update now; the poll confirms from the state file
        _nlApply.restart();
    }
    // Sliders: moving one turns night light on and applies (debounced).
    function setNightTemp(k) { nightTemp = k; nightLight = true; _nlApply.restart(); }
    function setNightGamma(g) { nightGamma = g; nightLight = true; _nlApply.restart(); }

    property bool _nlBusy: _nlApply.running || _nlProc.running
    readonly property var _nlApply: Timer {
        interval: 60
        onTriggered: {
            if (root._nlProc.running) { restart(); return; }
            root._nlProc.command = ["sh", "-c", root.nightLight
                ? "hyprctl hyprsunset temperature \"$2\" && hyprctl hyprsunset gamma \"$3\" && echo on $2 $3 > \"$1\""
                : "hyprctl hyprsunset identity && hyprctl hyprsunset gamma 100 && echo off $2 $3 > \"$1\"",
                "sh", root._nlFile, String(root.nightTemp), String(root.nightGamma)];
            root._nlProc.running = true;
        }
    }
    readonly property var _nlProc: Process {}
    function toggleDnd() { _run(["dunstctl", "set-paused", "toggle"]); }

    // --- notification history (dunst) ---
    // [{ id, app, summary, body, urgency, icon, age (s) }], newest first.
    // Fetched while something shows it (`historyWanted`).
    property bool historyWanted: false
    property var history: []
    onHistoryWantedChanged: if (historyWanted) loadHistory()

    function loadHistory() {
        if (!_histProc.running) _histProc.running = true;
    }
    // dunst timestamps are µs on the monotonic clock → age against uptime.
    readonly property var _histProc: Process {
        command: ["sh", "-c", "cut -d' ' -f1 /proc/uptime; dunstctl history"]
        stdout: StdioCollector {
            onStreamFinished: {
                const nl = this.text.indexOf("\n");
                const up = Number(this.text.slice(0, nl));
                let o = null;
                try { o = JSON.parse(this.text.slice(nl + 1)); } catch (e) { o = null; }
                const list = o && o.data && o.data[0] ? o.data[0] : [];
                const v = (n, k) => n[k] ? n[k].data : "";
                root.history = list.map(n => ({
                    id: v(n, "id"),
                    app: v(n, "appname"),
                    summary: v(n, "summary"),
                    body: String(v(n, "body")).replace(/<[^>]*>/g, ""),
                    urgency: v(n, "urgency"),
                    icon: v(n, "icon_path"),
                    age: Math.max(0, up - Number(v(n, "timestamp")) / 1e6)
                })).sort((a, b) => a.age - b.age);
            }
        }
    }
    readonly property var _histTimer: Timer {
        interval: 5000
        running: root.historyWanted
        repeat: true
        onTriggered: root.loadHistory()
    }
    function _histRun(args) {
        _histRunner.command = args;
        _histRunner.running = true;
    }
    readonly property var _histRunner: Process {
        onRunningChanged: if (!running) { root.loadHistory(); root.refresh(); }
    }
    function showAgain(id) { _histRun(["dunstctl", "history-pop", String(id)]); }
    function removeNotification(id) { _histRun(["dunstctl", "history-rm", String(id)]); }
    function clearHistory() { _histRun(["dunstctl", "history-clear"]); }

    function fmtAge(s) {
        if (s < 60) return "now";
        if (s < 3600) return Math.floor(s / 60) + "m";
        if (s < 86400) return Math.floor(s / 3600) + "h";
        return Math.floor(s / 86400) + "d";
    }

    // --- power ---
    readonly property var actions: [
        { id: "lock",     label: "Lock",     icon: "󰌾", cmd: [] },
        { id: "logout",   label: "Log out",  icon: "󰍃", cmd: ["hyprctl", "dispatch", "exit"] },
        { id: "suspend",  label: "Suspend",  icon: "󰤄", cmd: ["systemctl", "suspend"] },
        { id: "reboot",   label: "Reboot",   icon: "󰜉", cmd: ["systemctl", "reboot"] },
        { id: "poweroff", label: "Shut down", icon: "󰐥", cmd: ["systemctl", "poweroff"] }
    ]
    function power(id) {
        if (id === "lock") { Lock.lock(); return; }
        const a = actions.find(x => x.id === id);
        if (a) Quickshell.execDetached(a.cmd);
    }
}
