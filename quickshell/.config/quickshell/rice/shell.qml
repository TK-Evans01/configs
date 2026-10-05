//@ pragma UseQApplication
//@ pragma IconTheme Gruvbox-Plus-Dark
import Quickshell
import Quickshell.Io
import QtQuick
import "modules/bar"
import "modules/lock"
import "services" as Svc

ShellRoot {
    // Singletons are created on first use; the clipboard watcher has to run
    // from startup, so touch it here.
    readonly property bool _clipboardReady: Svc.Clipboard.available
    // Idle lock, screen-off and lock-before-sleep live in the Lock singleton.
    readonly property bool _lockReady: Svc.Lock.locked

    Loader {
        active: Svc.Lock.locked
        sourceComponent: LockScreen {}
    }
    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData
            screenRef: modelData
        }
    }

    // Keybind hooks, e.g. in hyprland.conf:
    //   bind = $mainMod, D, exec, qs -c rice ipc call rice dashboard overview
    //   bind = $mainMod, Q, exec, qs -c rice ipc call rice quicksettings ""
    IpcHandler {
        target: "rice"

        function focused(): string {
            const m = Svc.Hyprland.focusedMonitor;
            return m ? m.name : (Quickshell.screens.length ? Quickshell.screens[0].name : "");
        }
        function dashboard(tab: string): void { Svc.Ui.toggle("dashboard", focused(), tab); }
        function quicksettings(page: string): void { Svc.Ui.toggle("quicksettings", focused(), page); }
        function close(): void { Svc.Ui.close(); }
        function refresh(): void { Svc.Weather.refresh(); Svc.Mail.refresh(); Svc.Calendar.refresh(); Svc.Github.refresh(); }
        function music(): void { Svc.Mpris.launch(); }
        function playpause(): void { Svc.Mpris.togglePlay(); }
        function next(): void { Svc.Mpris.next(); }
        function previous(): void { Svc.Mpris.previous(); }
        function mail(): void { Svc.Ui.toggle("quicksettings", focused(), "mail"); }
        function dnd(): void { Svc.Desktop.toggleDnd(); }
        function lock(): void { Svc.Lock.lock(); }
        function caffeine(): void { Svc.Lock.caffeine = !Svc.Lock.caffeine; }
        function nightlight(): void { Svc.Desktop.toggleNightLight(); }
        function launcher(): void { Svc.Ui.toggle("launcher", focused(), ""); }
        function clipboard(): void { Svc.Ui.toggle("launcher", focused(), "clipboard"); }
        function keybinds(): void { Svc.Ui.toggle("launcher", focused(), "keybinds"); }
        function screenshot(target: string, action: string): void { Svc.Screenshot.take(target || "area", action || ""); }
    }
}
