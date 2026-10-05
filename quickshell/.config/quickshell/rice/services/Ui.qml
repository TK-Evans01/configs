pragma Singleton
import QtQuick
import "../config"

// Which bar popup is open, on which screen, and where inside it.
// Every bar owns its own Dashboard + QuickSettings window; each shows itself
// while `open`/`screen` name it, so only one popup is ever up.
QtObject {
    id: root

    property string open: ""       // "" | "dashboard" | "quicksettings" | "launcher" | "traymenu" | "sidebar" | "session"
    property string screen: ""     // screen name it is open on
    property string tab: "overview"
    // The settings window (a normal window, not a popup).
    property bool settingsOpen: false
    property string settingsPage: "appearance"
    function openSettings(p) {
        if (p) settingsPage = p;
        close();
        settingsOpen = true;
    }

    property string page: ""       // quick settings sub-page / launcher mode ("" = main / apps) / sidebar tab

    function isOpen(name, screenName) {
        return open === name && screen === screenName;
    }

    // Toggle `name` on `screenName`. A tab/page given while already open
    // switches to it instead of closing.
    function toggle(name, screenName, where) {
        const target = where === undefined ? "" : where;
        // A click on the bar button that owns the open popup first clears the
        // focus grab (→ dismiss), then reaches the button: that is a close.
        // Only the same place: another tab / page / tray item still switches.
        if (open === "" && _dismissed === name + "@" + screenName
                && (target === "" || target === _dismissedWhere) && Date.now() - _dismissedAt < 300) {
            _dismissed = "";
            return;
        }
        if (isOpen(name, screenName)) {
            if (name === "dashboard" && target !== "" && target !== tab) { tab = target; return; }
            if ((name === "quicksettings" || name === "launcher") && target !== page) { page = target; return; }
            if (name === "sidebar" && target !== "" && target !== page) { page = target; return; }
            close();
            return;
        }
        if (name === "dashboard") tab = target !== "" ? target : "overview";
        if (name === "quicksettings" || name === "launcher" || name === "traymenu") page = target;
        if (name === "sidebar") page = target !== "" ? target : "notifications";
        screen = screenName;
        open = name;
    }

    property string _dismissed: ""
    property real _dismissedAt: 0
    property string _dismissedWhere: ""

    // Closed from the popup itself (outside click / Escape).
    function dismiss() {
        _dismissed = open + "@" + screen;
        _dismissedWhere = open === "dashboard" ? tab : page;
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
