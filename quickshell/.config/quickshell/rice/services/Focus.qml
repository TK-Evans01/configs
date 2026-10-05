pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland as Hypr
import "../config"

// Focus mode: a timer with rounds (focus → break → …) that, while focusing,
//   - blocks sites: the root helper rice-focus-dns sinkholes the profile's
//     hostnames (sudo -n, no prompt; see README › Focus mode for the setup);
//   - hides / closes app windows whose initial class matches the profile
//     (also windows opened later), restoring hidden ones afterwards;
//   - quiets notifications (critical only, or nothing), then summarises.
// Breaks lift the blocks. Once started a session can't be cancelled — it
// runs out (root keeps the sites blocked until each focus phase ends, and
// the hidden apps' workspace stays shut). State is saved, so a shell reload
// or crash resumes the session.
QtObject {
    id: root

    // --- state (persisted) ---
    property string profileId: ""
    property string phase: ""          // "" | "focus" | "break"
    property real endsAt: 0            // ms, end of the current phase
    property real startedAt: 0         // ms, start of the session
    property int round: 0
    property int minutesOverride: 0
    property var hidden: ({})          // address → workspace name it came from
    readonly property bool active: phase !== ""
    readonly property bool focusing: phase === "focus"
    readonly property var profile: Settings.focusProfiles.find(p => p.id === (profileId || Settings.focusDefault))
                                   || Settings.focusProfiles[0] || null
    // Every session is binding: no stop, strict enforcement.
    readonly property bool hard: active
    readonly property int focusMinutes: minutesOverride > 0 ? minutesOverride : (profile ? profile.minutes : 25)

    // Ticks once a second while running.
    property real now: Date.now()
    readonly property int remainingSec: active ? Math.max(0, Math.round((endsAt - now) / 1000)) : 0
    readonly property string remainingText: {
        const s = remainingSec, h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), ss = s % 60;
        return (h ? h + ":" + String(m).padStart(2, "0") : m) + ":" + String(ss).padStart(2, "0");
    }
    readonly property string endsText: active ? Qt.formatTime(new Date(endsAt), "HH:mm") : ""
    readonly property var _tick: Timer {
        interval: 1000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: { root.now = Date.now(); if (root.now >= root.endsAt) root._advance(); }
    }

    // --- blocking state for the UI ---
    property string helper: "unknown"  // ready | missing | unknown
    property string siteNote: ""       // last helper message
    property int blockedCount: 0

    // --- start / stop ---
    function start(id, minutes) {
        if (active) return false;     // one at a time; it has to run out
        profileId = id || Settings.focusDefault;
        minutesOverride = minutes > 0 ? minutes : 0;
        startedAt = Date.now();
        round = 1;
        _enter("focus");
        Quickshell.execDetached(["notify-send", "-a", "Focus", "-i", "appointment-soon",
            (profile ? profile.label : "Focus") + " · " + focusMinutes + " min",
            "until " + endsText + " — no way to stop it early"]);
        if (profile && profile.playlist && !Mpris.playing) Spotify.playPlaylist(profile.playlist);
        return true;
    }

    // Only the timer ends a session (internal: _advance at the last phase).
    function stop(confirmed) {
        if (!active) return "none";
        if (!confirmed) return "running until " + endsText;
        const wasFocusing = focusing;
        _lift(true);
        phase = "";
        endsAt = 0;
        _save();
        if (wasFocusing || startedAt) _summary();
        startedAt = 0;
        return "stopped";
    }

    function _enter(p) {
        phase = p;
        const min = p === "focus" ? focusMinutes : (profile ? profile.breakMin : 5);
        endsAt = Date.now() + min * 60000;
        now = Date.now();
        if (p === "focus") _block(); else _lift(false);
        _save();
    }
    function _advance() {
        if (phase === "focus" && profile && profile.breakMin > 0 && round < profile.rounds) {
            _enter("break");
            Quickshell.execDetached(["notify-send", "-a", "Focus", "Break · " + profile.breakMin + " min",
                "round " + round + " of " + profile.rounds + " done"]);
        } else if (phase === "break") {
            round++;
            _enter("focus");
            Quickshell.execDetached(["notify-send", "-a", "Focus", "Back to it · round " + round + " of " + profile.rounds, "until " + endsText]);
        } else {
            stop(true);
        }
    }

    // --- sites: the root helper ---
    property var bundles: []
    readonly property var _bundleFile: FileView {
        path: Quickshell.shellDir + "/config/focus-bundles.json"
        onLoaded: { try { root.bundles = JSON.parse(text()).bundles; } catch (e) {} }
    }
    function hostsFor(p) {
        if (!p) return [];
        let h = [];
        for (const id of (p.bundles || [])) {
            const b = bundles.find(x => x.id === id);
            if (b) h = h.concat(b.hosts);
        }
        return h.concat(p.sites || []);
    }
    readonly property string _helperPath: "/usr/local/bin/rice-focus-dns"
    readonly property var _dns: Process {
        property string payload: ""
        stdinEnabled: true
        onStarted: { if (payload) write(payload); payload = ""; stdinEnabled = false; }
        stdout: StdioCollector { id: dnsOut; waitForEnd: true }
        stderr: StdioCollector { id: dnsErr; waitForEnd: true }
        onExited: code => {
            stdinEnabled = true;
            const msg = (dnsOut.text + dnsErr.text).trim();
            root.siteNote = msg.replace(/^rice-focus-dns: /, "");
            // sudo -n with no matching sudoers rule says so and exits 1.
            if (/password is required|not allowed|command not found|No such file/.test(msg)) root.helper = "missing";
            else if (code === 0) root.helper = "ready";
            root._checkStatus();
            // A refused clear (the root timer is a second away): look again shortly.
            if (code === 3) root._recheck.restart();
            Qt.callLater(root._dnsNext);
        }
    }
    // Calls are queued: an apply right after a clear (or the reverse) must both run.
    property var _dnsQueue: []
    function _dnsRun(args, input) {
        _dnsQueue = _dnsQueue.concat([{ args: args, input: input || "" }]);
        _dnsNext();
    }
    function _dnsNext() {
        if (_dns.running || !_dnsQueue.length) return;
        const c = _dnsQueue[0];
        _dnsQueue = _dnsQueue.slice(1);
        _dns.command = ["sudo", "-n", _helperPath].concat(c.args);
        _dns.payload = c.input;
        _dns.running = true;
    }
    readonly property var _recheck: Timer { interval: 2500; onTriggered: root._checkStatus() }
    readonly property var _status: Process {
        command: ["sudo", "-n", root._helperPath, "status"]
        stdout: StdioCollector { id: stOut; waitForEnd: true }
        stderr: StdioCollector { id: stErr; waitForEnd: true }
        onExited: code => {
            if (code !== 0) { root.helper = "missing"; root.blockedCount = 0; return; }
            root.helper = "ready";
            try { const s = JSON.parse(stOut.text); root.blockedCount = s.active ? s.count : 0; } catch (e) {}
        }
    }
    function _checkStatus() { if (!_status.running) _status.running = true; }
    Component.onCompleted: _checkStatus()

    // --- apps: hide / close matching windows ---
    function _rules() {
        return (profile && profile.apps || []).map(a => {
            try { return { re: new RegExp(a.re), action: a.action || "hide" }; } catch (e) { return null; }
        }).filter(x => x);
    }
    function _consider(addr, cls, ws) {
        if (!focusing || !cls) return;
        for (const r of _rules()) {
            if (!r.re.test(cls)) continue;
            if (r.action === "close") Hyprland.dispatch("closewindow address:" + addr);
            else if (!(addr in hidden) && ws !== "special:focus") {
                const h = Object.assign({}, hidden); h[addr] = ws; hidden = h;
                Hyprland.dispatch("movetoworkspacesilent special:focus,address:" + addr);
                _save();
            }
            return;
        }
    }
    readonly property var _events: Connections {
        target: Hypr.Hyprland
        enabled: root.focusing
        function onRawEvent(ev) {
            if (ev.name === "openwindow") {
                const f = ev.parse(4);
                root._consider("0x" + f[0], f[2], f[1]);
            } else if (ev.name === "activespecial" && root.hard) {
                // Hard mode: the hidden apps' workspace stays shut.
                if (ev.parse(2)[0] === "special:focus") Hyprland.dispatch("togglespecialworkspace focus");
            }
        }
    }
    // Windows already open at the start.
    readonly property var _sweep: Process {
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector { id: sw; waitForEnd: true }
        onExited: {
            let list = [];
            try { list = JSON.parse(sw.text); } catch (e) {}
            for (const c of list) root._consider(c.address, c.initialClass || c["class"], c.workspace ? c.workspace.name : "");
        }
    }

    // --- notifications ---
    // Notifications reads this: "off" | "focus" (critical only) | "total".
    readonly property string quiet: focusing && profile ? (profile.dnd || "off") : "off"

    function _block() {
        const hosts = hostsFor(profile);
        if (hosts.length) _dnsRun(["apply"].concat(hard ? ["--hard"] : []).concat([String(Math.floor(endsAt / 1000))]), hosts.join("\n") + "\n");
        if (_rules().length) _sweep.running = true;
    }
    function _lift(ending) {
        if (helper !== "missing") _dnsRun(["clear"]);
        // Put hidden windows back where they were.
        let n = 0;
        for (const addr in hidden) {
            const ws = hidden[addr] || "1";
            Hyprland.dispatch("movetoworkspacesilent " + (ws.startsWith("special") ? "e+0" : ws) + ",address:" + addr);
            n++;
        }
        hidden = ({});
        if (n && ending) Quickshell.execDetached(["notify-send", "-a", "Focus", "Restored " + n + (n === 1 ? " window" : " windows")]);
    }

    // What arrived while focusing, grouped by source.
    function _summary() {
        const since = startedAt;
        const got = Notifications.history.filter(h => typeof h.time === "number" && h.time >= since && h.app !== "Focus");
        if (!got.length) return;
        const by = {};
        for (const h of got) { const l = Notifications.sourceInfo(h.source).label; by[l] = (by[l] || 0) + 1; }
        Quickshell.execDetached(["notify-send", "-a", "Focus", "While you focused",
            Object.keys(by).map(k => k + " " + by[k]).join("  ·  ")]);
    }

    // --- persistence: survive reloads / crashes ---
    readonly property string _path: Quickshell.env("HOME") + "/.local/state/rice/focus.json"
    function _save() {
        _file.setText(JSON.stringify({ profileId: profileId, phase: phase, endsAt: endsAt, startedAt: startedAt,
                                       round: round, minutesOverride: minutesOverride, hidden: hidden }));
    }
    readonly property var _file: FileView {
        path: root._path
        atomicWrites: true
        onLoaded: {
            let s = null;
            try { s = JSON.parse(text()); } catch (e) {}
            if (!s || !s.phase) return;
            root.profileId = s.profileId; root.round = s.round; root.startedAt = s.startedAt;
            root.minutesOverride = s.minutesOverride || 0; root.hidden = s.hidden || ({});
            root.endsAt = s.endsAt; root.phase = s.phase;
            root._fastForward();
        }
    }

    // After downtime (shell down, machine off): walk the stored timeline to
    // where the session would be now instead of replaying missed rounds; a
    // session whose planned end has passed just finishes.
    function _fastForward() {
        const p = profile;
        if (!p) { stop(true); return; }
        let ph = phase, end = endsAt, r = round;
        const brk = (p.breakMin || 0) * 60000, foc = focusMinutes * 60000;
        while (Date.now() >= end) {
            if (ph === "focus" && brk > 0 && r < p.rounds) { ph = "break"; end += brk; }
            else if (ph === "break") { ph = "focus"; r++; end += foc; }
            else { stop(true); return; }
        }
        round = r;
        if (ph === phase) { endsAt = end; if (ph === "focus") _block(); _save(); return; }
        phase = ph;
        endsAt = end;
        if (ph === "focus") _block(); else _lift(false);
        _save();
    }

    // Launcher / voice "open X": is this desktop entry blocked right now?
    function blocksEntry(e) {
        if (!focusing || !e) return false;
        const bin = (e.command && e.command.length ? e.command[0] : "").split("/").pop();
        const names = [e.id, e.startupClass, bin, (e.name || "").toLowerCase()].filter(x => x);
        return _rules().some(r => names.some(n => r.re.test(n)));
    }

    // For IPC / the voice assistant.
    function statusJson() {
        return JSON.stringify({ active: active, profile: profile ? profile.id : "", phase: phase,
            remainingSec: remainingSec, endsAt: endsAt, round: round, rounds: profile ? profile.rounds : 0,
            hard: hard, helper: helper, blocked: blockedCount });
    }
}
