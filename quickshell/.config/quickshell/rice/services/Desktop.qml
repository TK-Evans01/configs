pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

// Desktop-session odds and ends for Quick Settings: night light (hyprsunset),
// user, and session power actions.
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
    // Changing the defaults in Settings takes effect (and applies if it's on).
    readonly property int _defTemp: Settings.nightLightTemp
    readonly property int _defGamma: Settings.nightLightGamma
    on_DefTempChanged: { nightTemp = _defTemp; if (nightLight) _nlApply.restart(); }
    on_DefGammaChanged: { nightGamma = _defGamma; if (nightLight) _nlApply.restart(); }
    readonly property string _nlFile: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/rice-nightlight"

    readonly property var _poll: Process {
        running: true
        command: ["sh", "-c", `
echo "temp $(hyprctl hyprsunset temperature 2>/dev/null | tr -dc '0-9')"
echo "gamma $(hyprctl hyprsunset gamma 2>/dev/null | tr -dc '0-9')"
echo "nl $(cat "$1" 2>/dev/null)"
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

    // The shell is the only writer of the state file: watch it. hyprsunset
    // changes on its own only at its profile times (hyprsunset.conf), so a
    // slow re-check covers that.
    readonly property var _nlWatch: FileView {
        path: root._nlFile
        watchChanges: true
        printErrors: false
        onFileChanged: root.refresh()
    }
    readonly property var _timer: Timer {
        interval: 300000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    function refresh() {
        if (!_poll.running) _poll.running = true;
    }

    readonly property var _cmds: CmdQueue {
        onDrained: root.refresh()
    }
    function _run(args) { _cmds.run(args); }

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
