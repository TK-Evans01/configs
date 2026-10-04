pragma Singleton
import QtQuick
import Quickshell.Hyprland as Hypr

QtObject {
    readonly property var raw: Hypr.Hyprland
    readonly property var workspaces: Hypr.Hyprland.workspaces
    readonly property var monitors: Hypr.Hyprland.monitors
    readonly property var focusedMonitor: Hypr.Hyprland.focusedMonitor
    readonly property var focusedWorkspace: Hypr.Hyprland.focusedWorkspace
    readonly property var activeToplevel: Hypr.Hyprland.activeToplevel

    function monitorFor(screen) {
        return screen ? Hypr.Hyprland.monitorFor(screen) : null;
    }

    // After a (re)start Quickshell knows no toplevels until the next event,
    // so the window title would stay blank until focus moves.
    Component.onCompleted: {
        Hypr.Hyprland.refreshToplevels();
        Hypr.Hyprland.refreshWorkspaces();
        Hypr.Hyprland.refreshMonitors();
    }

    function dispatch(cmd) {
        Hypr.Hyprland.dispatch(cmd);
    }
}
