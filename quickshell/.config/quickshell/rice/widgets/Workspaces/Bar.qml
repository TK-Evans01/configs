import QtQuick
import Quickshell
import "../../config"
import "../../services" as Svc

Row {
    id: root
    spacing: 0
    height: Settings.barHeight

    Repeater {
        model: Svc.Hyprland.workspaces

        Item {
            id: cell
            required property var modelData
            readonly property bool focused: Svc.Hyprland.focusedWorkspace && Svc.Hyprland.focusedWorkspace.id === modelData.id

            width: 32
            height: Settings.barHeight

            Rectangle {
                anchors.fill: parent
                color: hover.hovered ? Theme.bg3 : "transparent"
            }

            Text {
                anchors.centerIn: parent
                text: cell.modelData.id
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
            TapHandler { onTapped: Svc.Hyprland.dispatch("workspace " + cell.modelData.id) }
        }
    }
}
