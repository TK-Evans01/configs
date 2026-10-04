import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../config"
import "../../components"
import "../../services" as Svc

// dunst history: newest first. Row: click = show it again, 󰆴 = remove.
ColumnLayout {
    id: page
    spacing: Theme.pad

    readonly property bool shown: Svc.Ui.page === "notifications" && Svc.Ui.open === "quicksettings"
    Binding {
        target: Svc.Desktop
        property: "historyWanted"
        value: page.shown
    }

    function appIcon(n) {
        if (n.icon && n.icon.startsWith("/")) return "file://" + n.icon;
        const guess = (n.app || "").toLowerCase().replace(/\s+/g, "-");
        return guess ? Quickshell.iconPath(guess, true) : "";
    }

    PageHeader {
        icon: Svc.Desktop.dnd ? "󰂛" : "󰂚"
        title: "Notifications"
        subtitle: Svc.Desktop.history.length + " in history" + (Svc.Desktop.dnd ? "  ·  do not disturb" : "")
        onBackClicked: Svc.Ui.back()
        Switch {
            checked: Svc.Desktop.dnd
            onToggled: Svc.Desktop.toggleDnd()
        }
    }

    Card {
        Layout.fillWidth: true

        CardHeader {
            icon: "󰋚"
            title: "History"
            subtitle: Svc.Desktop.dnd && Svc.Desktop.waitingCount ? Svc.Desktop.waitingCount + " held back" : ""
            accent: Theme.purple
            IconButton {
                icon: "󰎟"
                text: "clear all"
                fg: Theme.red
                enabledState: Svc.Desktop.history.length > 0
                onClicked: Svc.Desktop.clearHistory()
            }
        }

        Label {
            visible: Svc.Desktop.history.length === 0
            Layout.alignment: Qt.AlignHCenter
            Layout.margins: Theme.pad
            text: "nothing here"
            size: Theme.fontSizeSmall
            color: Theme.muted
        }

        ListView {
            id: list
            Layout.fillWidth: true
            implicitHeight: Math.min(contentHeight, 560)
            visible: count > 0
            clip: true
            spacing: 1
            boundsBehavior: Flickable.StopAtBounds
            model: Svc.Desktop.history

            delegate: Rectangle {
                id: row
                required property var modelData
                width: ListView.view.width
                implicitHeight: body.implicitHeight + 12
                color: hov.containsMouse ? Theme.surface1 : "transparent"

                Rectangle {
                    visible: row.modelData.urgency === "CRITICAL"
                    width: Theme.accentThickness
                    height: parent.height
                    color: Theme.red
                }

                MouseArea {
                    id: hov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Svc.Desktop.showAgain(row.modelData.id)
                }

                RowLayout {
                    id: body
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Theme.spacing
                    anchors.rightMargin: Theme.spacing
                    spacing: Theme.pad

                    Item {
                        Layout.alignment: Qt.AlignTop
                        implicitWidth: Theme.iconSize + 4
                        implicitHeight: implicitWidth
                        Image {
                            id: img
                            anchors.fill: parent
                            source: page.appIcon(row.modelData)
                            sourceSize.width: width * 2
                            sourceSize.height: height * 2
                            visible: status === Image.Ready
                            asynchronous: true
                            mipmap: true
                        }
                        Label {
                            anchors.centerIn: parent
                            visible: !img.visible
                            text: "󰂚"
                            color: Theme.purple
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                Layout.fillWidth: true
                                text: (row.modelData.app || "unknown").toLowerCase()
                                size: Theme.fontSizeSmall - 2
                                color: Theme.subtext
                                elide: Text.ElideRight
                            }
                            Label {
                                text: Svc.Desktop.fmtAge(row.modelData.age)
                                size: Theme.fontSizeSmall - 2
                                color: Theme.muted
                            }
                        }
                        Label {
                            Layout.fillWidth: true
                            text: row.modelData.summary
                            size: Theme.fontSizeSmall + 1
                            font.bold: true
                            color: Theme.textBright
                            elide: Text.ElideRight
                        }
                        Label {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: row.modelData.body
                            size: Theme.fontSizeSmall - 1
                            color: Theme.text
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }
                    }

                    IconButton {
                        Layout.alignment: Qt.AlignTop
                        opacity: hov.containsMouse || hovered ? 1 : 0
                        icon: "󰆴"
                        fg: Theme.red
                        onClicked: Svc.Desktop.removeNotification(row.modelData.id)
                    }
                }
            }
        }

        Label {
            visible: Svc.Desktop.history.length > 0
            text: "click: show again  ·  󰆴 remove"
            size: Theme.fontSizeSmall - 3
            color: Theme.muted
        }
    }
}
