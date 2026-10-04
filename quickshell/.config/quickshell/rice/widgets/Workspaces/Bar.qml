import QtQuick
import Quickshell
import "../../config"
import "../../services" as Svc

// One cell per monitor, in monitor order. Shows only that screen's active
// workspace number; ordering tells you which monitor it belongs to.
// The focused monitor's cell is highlighted (accent color + underline).
Row {
    id: root
    spacing: 0
    height: Settings.barHeight

    Repeater {
        model: Svc.Hyprland.monitors

        Item {
            id: cell
            required property var modelData
            readonly property bool focused: Svc.Hyprland.focusedWorkspace
                && modelData.activeWorkspace
                && Svc.Hyprland.focusedWorkspace.id === modelData.activeWorkspace.id

            width: 44
            height: Settings.barHeight

            Rectangle {
                anchors.fill: parent
                color: hover.hovered ? Theme.bg3 : "transparent"
            }

            Text {
                anchors.centerIn: parent
                text: cell.modelData.activeWorkspace ? cell.modelData.activeWorkspace.id : "-"
                color: cell.focused ? Theme.yellow : Theme.fg0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 8
                height: Theme.accentThickness
                color: Theme.yellow
                visible: cell.focused
            }

            HoverHandler { id: hover }
            TapHandler { onTapped: Svc.Hyprland.dispatch("focusmonitor " + cell.modelData.name) }
        }
    }
}
