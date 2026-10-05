pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import "../config"

// Session lock: PAM password check, caps-lock state, wallpaper per output,
// lock before sleep (logind delay inhibitor), idle lock / screen-off, caffeine.
// The surfaces live in modules/lock/LockScreen.qml, loaded while `locked`.
QtObject {
    id: root

    property bool locked: false
    property string buffer: ""          // typed password (shared by every screen)
    property bool authenticating: false
    property bool failed: false
    property string failMessage: ""
    property int attempts: 0
    property bool capsLock: false
    property bool secure: false         // compositor confirmed the lock
    property date lockedAt: new Date()
    property var wallpapers: ({})       // output name → image path

    signal authSucceeded()

    // A hot reload rebuilds this singleton; without this a reload while
    // locked would come up unlocked and drop the session lock. The marker
    // lives in $XDG_RUNTIME_DIR (gone after a reboot) and is read
    // synchronously, before the lock surface's Loader evaluates.
    readonly property var _lockMark: FileView {
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/rice-locked"
        blockLoading: true
        printErrors: false
    }
    Component.onCompleted: {
        if (_lockMark.text().trim() === "1") {
            lockedAt = new Date();
            locked = true;
            checkCaps();
            if (!_wallProc.running) _wallProc.running = true;
        }
    }

    function lock() {
        if (locked) return;
        buffer = "";
        failed = false;
        failMessage = "";
        attempts = 0;
        authenticating = false;
        lockedAt = new Date();
        Ui.close();
        _lockMark.setText("1");
        locked = true;
        checkCaps();
        if (!_wallProc.running) _wallProc.running = true;
    }

    // Called by the lock surface once it has let go of the session.
    function finishUnlock() {
        _lockMark.setText("0");
        locked = false;
        secure = false;
        buffer = "";
    }

    function type(text) {
        if (authenticating) return;
        failed = false;
        buffer += text;
    }
    function backspace() { if (!authenticating) buffer = buffer.slice(0, -1); }
    function clear() { if (!authenticating) buffer = ""; }

    function submit() {
        if (authenticating || buffer === "") return;
        _pending = buffer;
        authenticating = true;
        failed = false;
        pam.start();
    }
    property string _pending: ""

    readonly property var pam: PamContext {
        config: "login"
        user: Quickshell.env("USER")
        onResponseRequiredChanged: if (responseRequired) respond(root._pending)
        onCompleted: result => {
            root.authenticating = false;
            root._pending = "";
            if (result === PamResult.Success) {
                root.failed = false;
                root.authSucceeded();
            } else {
                root.attempts++;
                // PAM's own words when it has them (e.g. faillock lockout)
                root.failMessage = messageIsError && message ? message.toLowerCase() : "wrong password";
                root.failed = true;
                root.buffer = "";
            }
        }
        onError: err => {
            root.authenticating = false;
            root._pending = "";
            root.failMessage = "authentication error";
            root.failed = true;
            root.buffer = "";
        }
    }

    // --- caps lock (Hyprland knows each keyboard's state) ---
    function checkCaps() { if (!_capsProc.running) _capsProc.running = true; }
    readonly property var _capsProc: Process {
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.capsLock = JSON.parse(this.text).keyboards.some(k => k.capsLock); } catch (e) {}
            }
        }
    }

    // --- wallpaper per output (awww) ---
    readonly property var _wallProc: Process {
        command: ["awww", "query"]
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                for (const line of this.text.split("\n")) {
                    const m = line.match(/^:?\s*([^:]+):.*image:\s*(.+)$/);
                    if (m) map[m[1].trim()] = m[2].trim();
                }
                root.wallpapers = map;
            }
        }
    }

    // --- lock before sleep ---
    // A logind "delay" inhibitor holds suspend (lid / menu / systemctl) until
    // the lock is secure; PrepareForSleep(true) locks, (false) re-arms it.
    // The inhibitor follows the setting; `_released` drops it while suspending
    // (once the lock is secure) and is reset on resume.
    property bool _released: false
    readonly property var _sleepInhibitor: Process {
        running: Settings.lockBeforeSleep && !root._released
        command: Settings.tether.concat(["systemd-inhibit", "--what=sleep", "--mode=delay", "--who=rice",
                                         "--why=Lock the screen before sleeping", "sleep", "infinity"])
    }
    readonly property var _sleepWatch: Process {
        running: Settings.lockBeforeSleep
        command: Settings.tether.concat(["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1",
                                         "--object-path", "/org/freedesktop/login1"])
        stdout: SplitParser {
            onRead: line => {
                if (line.indexOf("PrepareForSleep") < 0) return;
                if (line.indexOf("true") >= 0) {
                    root.lock();
                    if (root.secure) root._released = true;
                    else root._releaseFallback.restart();
                } else {
                    root._releaseFallback.stop();
                    root._released = false;
                }
            }
        }
    }
    onSecureChanged: if (secure && _releaseFallback.running) { _releaseFallback.stop(); _released = true; }
    // Never keep the machine awake if the lock surface doesn't come up.
    readonly property var _releaseFallback: Timer {
        interval: 3000
        onTriggered: root._released = true
    }

    // --- idle ---
    property bool caffeine: false
    readonly property var _idleLock: IdleMonitor {
        enabled: Settings.lockAfterMin > 0 && !root.caffeine && !root.locked
        timeout: Settings.lockAfterMin * 60
        respectInhibitors: true
        onIsIdleChanged: if (isIdle) root.lock()
    }
    readonly property var _idleScreen: IdleMonitor {
        enabled: Settings.screenOffAfterMin > 0 && !root.caffeine
        timeout: Settings.screenOffAfterMin * 60
        respectInhibitors: true
        onIsIdleChanged: Quickshell.execDetached(["hyprctl", "dispatch", "dpms", isIdle ? "off" : "on"])
    }
}
