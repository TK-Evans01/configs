pragma Singleton
import QtQuick
import "../config"

// Which bar popup is open, on which screen, and where inside it.
// Every bar owns its own Dashboard + QuickSettings window; each shows itself
// while `open`/`screen` name it, so only one popup is ever up.
QtObject {
    id: root

    property string open: ""       // "" | "dashboard" | "quicksettings"
    property string screen: ""     // screen name it is open on
    property string tab: "overview"
    property string page: ""       // quick settings sub-page / launcher mode ("" = main / apps)

    function isOpen(name, screenName) {
        return open === name && screen === screenName;
    }

    // Toggle `name` on `screenName`. A tab/page given while already open
    // switches to it instead of closing.
    function toggle(name, screenName, where) {
        const target = where === undefined ? "" : where;
        // A click on the bar button that owns the open popup first clears the
        // focus grab (→ dismiss), then reaches the button: that is a close.
        if (open === "" && _dismissed === name + "@" + screenName && Date.now() - _dismissedAt < 300) {
            _dismissed = "";
            return;
        }
        if (isOpen(name, screenName)) {
            if (name === "dashboard" && target !== "" && target !== tab) { tab = target; return; }
            if ((name === "quicksettings" || name === "launcher") && target !== page) { page = target; return; }
            close();
            return;
        }
        if (name === "dashboard") tab = target !== "" ? target : "overview";
        if (name === "quicksettings" || name === "launcher") page = target;
        screen = screenName;
        open = name;
    }

    property string _dismissed: ""
    property real _dismissedAt: 0

    // Closed from the popup itself (outside click / Escape).
    function dismiss() {
        _dismissed = open + "@" + screen;
        _dismissedAt = Date.now();
        close();
    }

    function close() {
        open = "";
        screen = "";
        page = "";
    }

    function showPage(p) { page = p; }
    function back() { page = ""; }

    function cycleTab(step) {
        const ids = Settings.dashboardTabs.map(t => t.id);
        const i = ids.indexOf(tab);
        tab = ids[(i + step + ids.length) % ids.length];
    }
}
