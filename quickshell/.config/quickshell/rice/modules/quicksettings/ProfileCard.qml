import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services" as Svc

// Avatar, user + host, tools and power actions (PowerRow: arm, then confirm).
Card {
    id: root
    property string toolHint: ""   // hovered tool's name
    readonly property string armed: power.armed
    readonly property string hint: power.hoveredLabel !== "" ? power.hoveredLabel : toolHint

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.pad

        // Avatar: the SDDM face (round PNG) with SDDM's ring; letter tile if missing.
        Item {
            implicitWidth: Theme.iconSizeLarge + Theme.pad
            implicitHeight: implicitWidth
            Image {
                id: face
                anchors.fill: parent
                source: "file://" + Settings.avatar
                sourceSize.width: width * 2
                sourceSize.height: height * 2
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                visible: status === Image.Ready
            }
            Rectangle {
                anchors.fill: parent
                visible: face.visible
                color: "transparent"
                radius: width / 2
                border.width: 2
                border.color: Theme.text
            }
            Rectangle {
                anchors.fill: parent
                visible: !face.visible
                color: Theme.accent
                Label {
                    anchors.centerIn: parent
                    text: Svc.Desktop.user.charAt(0).toUpperCase()
                    size: Theme.iconSize
                    font.bold: true
                    color: Theme.textReverse
                }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            Layout.minimumWidth: 0
            spacing: 0
            Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: Svc.Desktop.user
                font.bold: true
                color: Theme.textBright
            }
            Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: root.armed !== "" ? "click again to " + Svc.Desktop.actions.find(a => a.id === root.armed).label.toLowerCase()
                    : root.hint !== "" ? root.hint
                    : Svc.Sys.host
                size: Theme.fontBase
                color: root.armed !== "" ? Theme.error : root.hint !== "" ? Theme.accent : Theme.subtext
            }
        }
        // tools │ power — one tight group so all seven fit beside the name
        RowLayout {
            spacing: 4
            Repeater {
                model: [
                    { icon: "󰹑", label: "screenshot", run: () => Svc.Ui.showPage("screenshot") },
                    { icon: "󰅌", label: "clipboard", run: () => Svc.Ui.toggle("launcher", Svc.Ui.screen, "clipboard") },
                    { icon: "󰌌", label: "keybinds", run: () => Svc.Ui.toggle("launcher", Svc.Ui.screen, "keybinds") },
                    { icon: "󰒓", label: "settings", run: () => Svc.Ui.openSettings("") }
                ]
                IconButton {
                    required property var modelData
                    icon: modelData.icon
                    onClicked: modelData.run()
                    onHoveredChanged: root.toolHint = hovered ? modelData.label : (root.toolHint === modelData.label ? "" : root.toolHint)
                }
            }
            Rectangle {
                Layout.leftMargin: 2
                Layout.rightMargin: 2
                implicitWidth: 1
                implicitHeight: Theme.fontMd
                color: Theme.surface2
            }
            PowerRow {
                id: power
                onFire: id => { Svc.Ui.close(); Svc.Desktop.power(id); }
            }
        }
    }
}
