import QtQuick
import "../../config"
import "../../components"
import "../../services" as Svc

// Current conditions; click: dashboard Weather tab.
BarButton {
    id: root

    required property string screenName
    readonly property var now: Svc.Weather.current

    visible: Settings.showWeather && now !== null
    active: Svc.Ui.isOpen("dashboard", screenName) && Svc.Ui.tab === "weather"
    onClicked: Svc.Ui.toggle("dashboard", screenName, "weather")

    Row {
        spacing: Theme.spacing
        Label {
            text: root.now ? Svc.Weather.icon(root.now.code, root.now.isDay) : ""
            size: Theme.iconSize
            color: root.now ? Svc.Weather.color(root.now.code, root.now.isDay) : Theme.muted
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: root.now ? Svc.Weather.fmtTemp(root.now.temp) : ""
            size: Theme.fontTitle
            color: root.active ? Theme.accent : Theme.text
        }
    }
}
