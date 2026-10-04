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

            Item {
                width: parent.width
                height: 22

                Text {
                    id: outLabel
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "output"
                    color: Theme.grey
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                Text {
                    id: outPct
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.service.outPercent + "%"
                    color: Theme.fg0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                MuteButton {
                    anchors.right: outPct.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    muted: root.service.outMuted
                    onToggled: root.service.toggleMute()
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

            Item {
                width: parent.width
                height: 22

                Text {
                    id: inLabel
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "input"
                    color: Theme.grey
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                Text {
                    id: inPct
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.service.inPercent + "%"
                    color: Theme.fg0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                MuteButton {
                    anchors.right: inPct.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    muted: root.service.inMuted
                    onIcon: "\uf130"    // nf-fa-microphone
                    offIcon: "\uf131"   // nf-fa-microphone_slash
                    onToggled: root.service.toggleInputMute()
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
