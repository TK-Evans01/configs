import QtQuick
import "../../config"

Item {
    id: root
    required property var service

    function stateColor(s, health) {
        if (s === "running") {
            if (health === "unhealthy") return Theme.red;
            if (health === "starting") return Theme.yellow;
            return Theme.green;
        }
        if (s === "restarting" || s === "created") return Theme.yellow;
        if (s === "paused") return Theme.orange;
        return Theme.grey;
    }

    Column {
        anchors.fill: parent
        spacing: 6

        Row {
            width: parent.width
            spacing: 8
            Text {
                id: header
                text: root.service.daemonUp ? "docker" : "docker (daemon down)"
                color: root.service.daemonUp ? Theme.blueBright : Theme.red
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 1
                font.bold: true
            }
            Item { width: 1; height: 1 }
            Text {
                text: root.service.running + " / " + root.service.total + " running"
                color: Theme.grey
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
                anchors.verticalCenter: header.verticalCenter
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.bg3 }

        Item {
            width: parent.width
            height: parent.height - 28

            Text {
                anchors.centerIn: parent
                visible: root.service.containers.length === 0
                text: root.service.daemonUp ? "no containers" : "start dockerd to view containers"
                color: Theme.greyDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }

            ListView {
                anchors.fill: parent
                visible: root.service.containers.length > 0
                clip: true
                spacing: 2
                model: root.service.containers
                delegate: Item {
                    id: row
                    required property var modelData
                    readonly property var m: row.modelData
                    width: ListView.view.width
                    height: 36

                    Rectangle {
                        anchors.fill: parent
                        color: hov.hovered ? Theme.bg2 : "transparent"
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 4
                        anchors.rightMargin: 4
                        spacing: 8

                        Rectangle {
                            width: 8; height: 8
                            radius: 4
                            color: root.stateColor(row.m.state, row.m.health)
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: row.width - 200
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            Text {
                                width: parent.width
                                text: row.m.name
                                color: Theme.fg0
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: row.m.image
                                color: Theme.greyDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 2
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            width: 110
                            text: row.m.status
                            color: Theme.grey
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 2
                            elide: Text.ElideRight
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            width: 22; height: 20
                            anchors.verticalCenter: parent.verticalCenter
                            color: btnToggle.hovered ? Theme.bg3 : Theme.bg2
                            border.color: Theme.bg3; border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: row.m.state === "running" ? "\uf04d" : "\uf04b"
                                color: row.m.state === "running" ? Theme.red : Theme.green
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 3
                            }
                            HoverHandler { id: btnToggle }
                            TapHandler {
                                onTapped: {
                                    if (row.m.state === "running") root.service.stop(row.m.id);
                                    else root.service.start(row.m.id);
                                }
                            }
                        }

                        Rectangle {
                            width: 22; height: 20
                            anchors.verticalCenter: parent.verticalCenter
                            color: btnRestart.hovered ? Theme.bg3 : Theme.bg2
                            border.color: Theme.bg3; border.width: 1
                            opacity: row.m.state === "running" ? 1 : 0.4
                            Text {
                                anchors.centerIn: parent
                                text: "\uf021"
                                color: Theme.yellow
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 3
                            }
                            HoverHandler { id: btnRestart }
                            TapHandler {
                                onTapped: if (row.m.state === "running") root.service.restartC(row.m.id)
                            }
                        }
                    }

                    HoverHandler { id: hov }
                }
            }
        }
    }
}
