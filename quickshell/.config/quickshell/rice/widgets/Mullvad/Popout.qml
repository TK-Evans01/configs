import QtQuick
import "../../config"

Item {
    id: root
    required property var service

    Column {
        anchors.fill: parent
        spacing: 6

        Row {
            spacing: 8
            Rectangle {
                width: 8; height: 8
                color: root.service.connected ? Theme.green : (root.service.connecting ? Theme.yellow : Theme.red)
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: root.service.state || "unknown"
                color: root.service.connected ? Theme.green
                     : (root.service.connecting ? Theme.yellow : Theme.red)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 1
                font.bold: true
            }
        }

        Text {
            visible: root.service.relay !== ""
            text: "relay: " + root.service.relay
            color: Theme.grey
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
        Text {
            visible: root.service.location !== ""
            text: root.service.location
            color: Theme.grey
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
        Text {
            visible: root.service.ip !== ""
            text: "ip: " + root.service.ip
            color: Theme.greyDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
        }

        Item { width: 1; height: 4 }

        Row {
            width: parent.width
            spacing: 6

            Rectangle {
                width: (parent.width - 6) / 2
                height: 28
                color: btnToggle.hovered ? Theme.bg3 : Theme.bg2
                border.color: Theme.bg3
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: root.service.connected ? "disconnect" : "connect"
                    color: root.service.connected ? Theme.red : Theme.green
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
                HoverHandler { id: btnToggle }
                TapHandler { onTapped: root.service.toggle() }
            }

            Rectangle {
                width: (parent.width - 6) / 2
                height: 28
                color: btnReconnect.hovered ? Theme.bg3 : Theme.bg2
                border.color: Theme.bg3
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "reconnect"
                    color: Theme.yellow
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
                HoverHandler { id: btnReconnect }
                TapHandler { onTapped: root.service.reconnect() }
            }
        }
    }
}
