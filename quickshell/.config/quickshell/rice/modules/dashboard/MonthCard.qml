import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services" as Svc

// Month grid, Monday first. Today filled with the accent; ‹ › walk months,
// clicking the title jumps back to today.
Card {
    id: root

    property date today: new Date()
    // Picked day (Proton Calendar), shown by the agenda; null = none.
    property var picked: null
    property int offset: 0
    readonly property date shown: new Date(today.getFullYear(), today.getMonth() + offset, 1)
    readonly property int lead: (shown.getDay() + 6) % 7
    readonly property int daysIn: new Date(shown.getFullYear(), shown.getMonth() + 1, 0).getDate()
    readonly property int prevDays: new Date(shown.getFullYear(), shown.getMonth(), 0).getDate()

    onVisibleChanged: if (visible) { today = new Date(); offset = 0; picked = null; }

    RowLayout {
        Layout.fillWidth: true
        IconButton { icon: "󰅁"; onClicked: root.offset-- }
        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatDate(root.shown, "MMMM yyyy").toUpperCase()
            size: Theme.fontBase
            font.bold: true
            font.letterSpacing: 1
            color: root.offset === 0 ? Theme.accent : Theme.text
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.offset = 0
            }
        }
        IconButton { icon: "󰅂"; onClicked: root.offset++ }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 7
        rowSpacing: 2
        columnSpacing: 2

        Repeater {
            model: ["mo", "tu", "we", "th", "fr", "sa", "su"]
            Label {
                required property string modelData
                required property int index
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                size: Theme.fontSm
                color: index >= 5 ? Theme.orangeDim : Theme.muted
            }
        }

        Repeater {
            model: 42
            Rectangle {
                radius: Theme.radiusSmall
                id: cell
                required property int index
                readonly property int day: index - root.lead + 1
                readonly property bool inMonth: day >= 1 && day <= root.daysIn
                readonly property int label: inMonth ? day : (day < 1 ? root.prevDays + day : day - root.daysIn)
                readonly property bool isToday: inMonth && root.offset === 0 && day === root.today.getDate()
                readonly property bool weekend: index % 7 >= 5
                readonly property date date: new Date(root.shown.getFullYear(), root.shown.getMonth(), day)
                readonly property int nEvents: inMonth ? Svc.Calendar.eventsOn(date).length : 0
                readonly property bool isPicked: root.picked !== null && inMonth
                    && root.picked.getTime() === date.getTime()

                Layout.fillWidth: true
                implicitHeight: Theme.fontMd + 10
                color: isToday ? Theme.accent : "transparent"
                border.width: inMonth && !isToday && (hov.containsMouse || isPicked) ? 1 : 0
                border.color: isPicked ? Theme.catTime : Theme.surface3

                Label {
                    anchors.centerIn: parent
                    text: cell.label
                    size: Theme.fontBase
                    font.bold: cell.isToday
                    color: cell.isToday ? Theme.textReverse
                         : !cell.inMonth ? Theme.surface3
                         : cell.weekend ? Theme.orange : Theme.text
                }
                // event dots (up to 3)
                Row {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 2
                    Repeater {
                        model: Math.min(3, cell.nEvents)
                        Rectangle {
                            width: 3
                            height: 3
                            color: cell.isToday ? Theme.textReverse : Theme.catTime
                        }
                    }
                }
                MouseArea {
                    id: hov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: cell.inMonth && Svc.Calendar.configured ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: if (cell.inMonth && Svc.Calendar.configured)
                        root.picked = cell.isPicked ? null : cell.date
                }
            }
        }
    }
}
