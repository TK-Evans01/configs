pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

// Events from a Proton Calendar share link (scripts/proton-calendar.py).
// state: "loading" | "ok" | "stale" (offline, cached) | "unconfigured" | "error"
QtObject {
    id: root

    property string state_: "loading"
    property string error: ""
    property var events: []        // [{ start, end (s), allDay, title, location }]
    readonly property bool configured: state_ === "ok" || state_ === "stale" || state_ === "error"

    readonly property string _script: Qt.resolvedUrl("../scripts/proton-calendar.py").toString().replace("file://", "")

    function refresh() {
        if (!proc.running) proc.running = true;
    }
    function open() { Quickshell.execDetached(["xdg-open", Settings.calendarUrl]); }

    function _dayKey(d) { return d.getFullYear() + "-" + d.getMonth() + "-" + d.getDate(); }

    // { "Y-M-D": [events] } — an event is listed on every day it touches.
    readonly property var byDay: {
        const map = {};
        for (const e of events) {
            const start = new Date(e.start * 1000);
            const end = new Date(Math.max(e.start, e.end - 1) * 1000);
            const d = new Date(start.getFullYear(), start.getMonth(), start.getDate());
            for (let n = 0; n < 62 && d <= end; n++) {
                const k = _dayKey(d);
                (map[k] = map[k] || []).push(e);
                d.setDate(d.getDate() + 1);
            }
        }
        return map;
    }
    function eventsOn(date) { return byDay[_dayKey(date)] || []; }

    // Not yet finished, soonest first.
    function upcoming(n) {
        const now = Date.now() / 1000;
        return events.filter(e => e.end > now).slice(0, n);
    }

    function fmtWhen(e) {
        if (e.allDay) return "all day";
        const s = new Date(e.start * 1000), t = new Date(e.end * 1000);
        return Qt.formatTime(s, "HH:mm") + (e.end > e.start ? "–" + Qt.formatTime(t, "HH:mm") : "");
    }
    function fmtDay(e) {
        const d = new Date(e.start * 1000);
        const today = new Date();
        const tomorrow = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1);
        if (_dayKey(d) === _dayKey(today)) return "today";
        if (_dayKey(d) === _dayKey(tomorrow)) return "tmrw";
        return Qt.formatDate(d, "ddd dd").toLowerCase();
    }

    readonly property var proc: Process {
        command: ["python3", root._script]
        stdout: StdioCollector {
            onStreamFinished: {
                let o = null;
                try { o = JSON.parse(this.text); } catch (e) { o = { state: "error", error: "bad helper output" }; }
                root.state_ = o.state;
                root.error = o.error || "";
                if (o.events) root.events = o.events;
            }
        }
    }

    readonly property var timer: Timer {
        interval: Settings.calendarRefreshMin * 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
