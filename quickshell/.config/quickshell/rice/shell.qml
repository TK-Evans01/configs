//@ pragma UseQApplication
//@ pragma IconTheme Gruvbox-Plus-Dark
import Quickshell
import Quickshell.Io
import QtQuick
import "modules/bar"
import "services" as Svc

ShellRoot {
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
        function refresh(): void { Svc.Weather.refresh(); Svc.Mail.refresh(); Svc.Calendar.refresh(); }
        function mail(): void { Svc.Ui.toggle("quicksettings", focused(), "mail"); }
        function dnd(): void { Svc.Desktop.toggleDnd(); }
        function nightlight(): void { Svc.Desktop.toggleNightLight(); }
        function launcher(): void { Svc.Ui.toggle("launcher", focused(), ""); }
        function clipboard(): void { Svc.Ui.toggle("launcher", focused(), "clipboard"); }
        function keybinds(): void { Svc.Ui.toggle("launcher", focused(), "keybinds"); }
        function screenshot(target: string, action: string): void { Svc.Screenshot.take(target || "area", action || ""); }
    }
}
