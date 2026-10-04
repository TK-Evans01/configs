pragma Singleton
import QtQuick
import Quickshell.Hyprland as Hypr

QtObject {
    readonly property var raw: Hypr.Hyprland
    readonly property var workspaces: Hypr.Hyprland.workspaces
    readonly property var monitors: Hypr.Hyprland.monitors
    readonly property var focusedWorkspace: Hypr.Hyprland.focusedWorkspace
    readonly property var activeToplevel: Hypr.Hyprland.activeToplevel

    function dispatch(cmd) {
        Hypr.Hyprland.dispatch(cmd);
    }
}
