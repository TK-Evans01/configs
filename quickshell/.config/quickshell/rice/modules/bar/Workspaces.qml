import QtQuick
import "../../config"
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

        Item {
            id: cell
            required property int modelData
            readonly property bool shown: modelData === root.activeId
            readonly property bool lit: shown && root.monitorFocused

            width: Math.max(Theme.fontSize * 2, num.implicitWidth + Theme.pad)
            height: Settings.barHeight - 1

            Rectangle {
                anchors.fill: parent
                color: hov.containsMouse ? Theme.surface2 : "transparent"
            }
            Text {
                id: num
                anchors.centerIn: parent
                text: cell.modelData
                color: cell.lit ? Theme.accent : (cell.shown ? Theme.text : Theme.muted)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: cell.shown
            }
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: cell.shown ? parent.width - 8 : 0
                height: Theme.accentThickness
                color: cell.lit ? Theme.accent : Theme.muted
                Behavior on width { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
            }
            MouseArea {
                id: hov
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Svc.Hyprland.dispatch("workspace " + cell.modelData)
                onWheel: w => Svc.Hyprland.dispatch("workspace " + (w.angleDelta.y > 0 ? "m-1" : "m+1"))
            }
        }
    }
}
