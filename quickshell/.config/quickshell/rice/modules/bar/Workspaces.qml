import QtQuick
import "../../config"
import "../../components"
import "../../services" as Svc

// This monitor's workspaces, in order. The shown one is lit; on the focused
// monitor it gets the accent + underline. Wheel walks this monitor's set.
Row {
    id: root

    required property var screenRef
    readonly property var monitor: Svc.Hyprland.monitorFor(screenRef)
    readonly property bool monitorFocused: monitor !== null && Svc.Hyprland.focusedMonitor === monitor
    readonly property int activeId: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : -1

    readonly property var ids: {
        const out = [];
        const all = Svc.Hyprland.workspaces ? Svc.Hyprland.workspaces.values : [];
        for (const ws of all)
            if (ws.id > 0 && ws.monitor && monitor && ws.monitor.name === monitor.name) out.push(ws.id);
        if (activeId > 0 && out.indexOf(activeId) < 0) out.push(activeId);
        return out.sort((a, b) => a - b);
    }

    spacing: 0

    Repeater {
        model: root.ids

        BarButton {
            id: cell
            required property int modelData
            readonly property bool shown: modelData === root.activeId
            readonly property bool lit: shown && root.monitorFocused

            // The shown workspace keeps its indicator; muted when this
            // monitor isn't focused.
            active: shown
            indicator: lit ? Theme.accent : Theme.muted
            minWidth: Theme.fontMd * 2
            onClicked: Svc.Hyprland.dispatch("workspace " + cell.modelData)
            onWheeled: d => Svc.Hyprland.dispatch("workspace " + (d > 0 ? "m-1" : "m+1"))

            Label {
                text: cell.modelData
                color: cell.lit ? Theme.accent : (cell.shown ? Theme.text : Theme.muted)
                size: Theme.fontMd
                font.bold: cell.shown
            }
        }
    }
}
