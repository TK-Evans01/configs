import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services" as Svc

// Proton Calendar: the picked day's events, or what's coming up.
Card {
    id: root

    property var day: null     // Date picked on the month grid, or null
    readonly property var list: day ? Svc.Calendar.eventsOn(day) : Svc.Calendar.upcoming(6)

    visible: Svc.Calendar.configured

    CardHeader {
        icon: "󰃭"
        title: root.day ? Qt.formatDate(root.day, "ddd dd MMM") : "Upcoming"
        subtitle: Svc.Calendar.state_ === "stale" ? "offline · cached" : ""
        accent: Theme.aqua
        IconButton {
            visible: root.day !== null
            icon: "󰅖"
            onClicked: root.day = null
        }
        IconButton {
            icon: "󰖟"
            onClicked: { Svc.Ui.close(); Svc.Calendar.open(); }
        }
    }

    Label {
        visible: root.list.length === 0
        text: root.day ? "nothing that day" : "nothing coming up"
        size: Theme.fontSizeSmall
        color: Theme.muted
    }

    Repeater {
        model: root.list
        RowLayout {
            id: ev
            required property var modelData
            Layout.fillWidth: true
            spacing: Theme.pad

            Rectangle {
                Layout.fillHeight: true
                implicitWidth: Theme.accentThickness
                color: ev.modelData.allDay ? Theme.yellow : Theme.aqua
            }
            Label {
                visible: root.day === null
                Layout.preferredWidth: Theme.fontSizeSmall * 4
                text: Svc.Calendar.fmtDay(ev.modelData)
                size: Theme.fontSizeSmall - 1
                color: Svc.Calendar.fmtDay(ev.modelData) === "today" ? Theme.accent : Theme.subtext
            }
            Label {
                Layout.preferredWidth: Theme.fontSizeSmall * 7
                text: Svc.Calendar.fmtWhen(ev.modelData)
                size: Theme.fontSizeSmall - 1
                color: Theme.subtext
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label {
                    Layout.fillWidth: true
                    text: ev.modelData.title
                    size: Theme.fontSizeSmall
                    color: Theme.textBright
                    elide: Text.ElideRight
                }
                Label {
                    Layout.fillWidth: true
                    visible: ev.modelData.location !== ""
                    text: "󰍎 " + ev.modelData.location
                    size: Theme.fontSizeSmall - 3
                    color: Theme.muted
                    elide: Text.ElideRight
                }
            }
        }
    }
}
