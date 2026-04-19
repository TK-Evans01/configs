import QtQuick
import "../../config"

Item {
    id: root
    required property var service

    Column {
        anchors.fill: parent
        spacing: 10

        Column {
            width: parent.width
            spacing: 4

            Row {
                width: parent.width
                spacing: 8
                Text {
                    text: "output"
                    color: Theme.grey
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    width: 54
                }
                Rectangle {
                    width: 42; height: 20
                    color: muteOut.hovered ? Theme.bg3 : Theme.bg2
                    border.color: Theme.bg3; border.width: 1
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        anchors.centerIn: parent
                        text: root.service.outMuted ? "unmute" : "mute"
                        color: root.service.outMuted ? Theme.red : Theme.fg0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                    }
                    HoverHandler { id: muteOut }
                    TapHandler { onTapped: root.service.toggleMute() }
                }
                Text {
                    text: root.service.outPercent + "%"
                    color: Theme.fg0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Slider {
                width: parent.width
                value: root.service.outPercent
                onCommit: p => root.service.setOutputVolume(p)
            }

            DeviceSelect {
                width: parent.width
                items: root.service.outputs
                selected: root.service.outDefault
                onPicked: n => root.service.setDefaultSink(n)
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.bg3 }

        Column {
            width: parent.width
            spacing: 4

            Row {
                width: parent.width
                spacing: 8
                Text {
                    text: "input"
                    color: Theme.grey
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    width: 54
                }
                Rectangle {
                    width: 42; height: 20
                    color: muteIn.hovered ? Theme.bg3 : Theme.bg2
                    border.color: Theme.bg3; border.width: 1
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        anchors.centerIn: parent
                        text: root.service.inMuted ? "unmute" : "mute"
                        color: root.service.inMuted ? Theme.red : Theme.fg0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                    }
                    HoverHandler { id: muteIn }
                    TapHandler { onTapped: root.service.toggleInputMute() }
                }
                Text {
                    text: root.service.inPercent + "%"
                    color: Theme.fg0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Slider {
                width: parent.width
                value: root.service.inPercent
                onCommit: p => root.service.setInputVolume(p)
            }

            DeviceSelect {
                width: parent.width
                items: root.service.inputs
                selected: root.service.inDefault
                onPicked: n => root.service.setDefaultSource(n)
            }
        }
    }
}
