import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services" as Svc

Card {
    id: root
    property date now: new Date()
    Timer {
        interval: 1000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    RowLayout {
        spacing: Theme.spacing
        Label {
            text: Qt.formatDateTime(root.now, "HH:mm")
            size: Theme.fontSizeHuge
            color: Theme.textBright
        }
        Label {
            Layout.alignment: Qt.AlignBottom
            Layout.bottomMargin: Theme.spacing
            text: Qt.formatDateTime(root.now, "ss")
            size: Theme.fontSizeLarge
            color: Theme.accent
        }
    }
    Label {
        text: Qt.formatDateTime(root.now, "dddd, dd MMMM yyyy").toLowerCase()
        color: Theme.text
    }
    RowLayout {
        visible: Svc.Weather.current !== null
        spacing: Theme.spacing
        readonly property var now: Svc.Weather.current
        Label {
            text: parent.now ? Svc.Weather.icon(parent.now.code, parent.now.isDay) : ""
            color: parent.now ? Svc.Weather.color(parent.now.code, parent.now.isDay) : Theme.muted
        }
        Label {
            text: parent.now ? Svc.Weather.fmtTemp(parent.now.temp) + "  " + Svc.Weather.describe(parent.now.code)
                  + "  ·  " + Settings.weatherPlace : ""
            size: Theme.fontSizeSmall
            color: Theme.text
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Svc.Ui.tab = "weather"
            }
        }
    }
    Label {
        text: "up " + Svc.Sys.fmtUptime(Svc.Sys.uptime) + "  ·  " + Svc.Desktop.user + "@" + Svc.Sys.host
        size: Theme.fontSizeSmall
        color: Theme.subtext
    }
}
