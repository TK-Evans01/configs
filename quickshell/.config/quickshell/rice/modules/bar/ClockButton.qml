import QtQuick
import "../../config"
import "../../components"
import "../../services" as Svc

// Time + date; opens the dashboard (Overview).
BarButton {
    id: root

    required property string screenName
    property date now: new Date()

    active: Svc.Ui.isOpen("dashboard", screenName) && Svc.Ui.tab === "overview"
    onClicked: Svc.Ui.toggle("dashboard", screenName, "overview")

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    Row {
        spacing: Theme.spacing
        Label {
            text: Qt.formatDateTime(root.now, "HH:mm")
            font.bold: true
            color: root.active ? Theme.accent : Theme.textBright
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(root.now, "ddd dd MMM").toLowerCase()
            size: Theme.fontSizeSmall
            color: Theme.subtext
        }
    }
}
