import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services" as Svc

// Avatar, user + host, tools and power actions. Power buttons arm on the first click
// (turn red, "again?") and fire on a second click within 3s.
Card {
    id: root
    property string armed: ""
    property string hint: ""      // hovered button's name, shown under user@host

    Timer {
        id: disarm
        interval: 3000
        onTriggered: root.armed = ""
    }
    onVisibleChanged: armed = ""

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
                    size: Theme.iconSizeLarge - 11
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
                text: root.armed !== "" ? "click again to " + root.armed
                    : root.hint !== "" ? root.hint
                    : Svc.Sys.host
                size: Theme.fontSizeSmall
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
                    { icon: "󰌌", label: "keybinds", run: () => Svc.Ui.toggle("launcher", Svc.Ui.screen, "keybinds") }
                ]
                IconButton {
                    required property var modelData
                    icon: modelData.icon
                    onClicked: modelData.run()
                    onHoveredChanged: root.hint = hovered ? modelData.label : (root.hint === modelData.label ? "" : root.hint)
                }
            }
            Rectangle {
                Layout.leftMargin: 2
                Layout.rightMargin: 2
                implicitWidth: 1
                implicitHeight: Theme.fontSize
                color: Theme.surface2
            }
            Repeater {
                model: Svc.Desktop.actions
                IconButton {
                    required property var modelData
                    icon: modelData.icon
                    fg: root.armed === modelData.id ? Theme.textReverse : (modelData.id === "poweroff" ? Theme.error : Theme.text)
                    color: root.armed === modelData.id ? Theme.error : (hovered ? Theme.surface2 : Theme.surface1)
                    onHoveredChanged: root.hint = hovered ? modelData.label.toLowerCase() : (root.hint === modelData.label.toLowerCase() ? "" : root.hint)
                    onClicked: {
                        if (modelData.id === "lock") { Svc.Ui.close(); Svc.Desktop.power("lock"); return; }
                        if (root.armed === modelData.id) {
                            root.armed = "";
                            Svc.Ui.close();
                            Svc.Desktop.power(modelData.id);
                        } else {
                            root.armed = modelData.id;
                            disarm.restart();
                        }
                    }
                }
            }
        }
    }
}
