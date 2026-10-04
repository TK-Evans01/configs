import QtQuick
import "../../config"
import "../../components"
import "../../services" as Svc

// CPU sparkline; numbers slide out on hover (temp stays while hot).
// Click: dashboard System tab.
BarButton {
    id: root

    required property string screenName
    readonly property int cpu: Svc.Sys.cpuPercent
    readonly property bool hot: Svc.Sys.cpuTemp >= 80
    readonly property int peak: Math.max(cpu, Svc.Sys.memPercent, Svc.Sys.gpuPercent)
    readonly property color tone: Theme.usageColor(peak, Theme.info)
    readonly property bool expanded: hovered || active || hot

    visible: Settings.showSystem
    active: Svc.Ui.isOpen("dashboard", screenName) && Svc.Ui.tab === "system"
    onClicked: Svc.Ui.toggle("dashboard", screenName, "system")

    Row {
        spacing: Theme.spacing
        Label {
            text: "󰍛"
            size: Theme.iconSize
            color: root.active || root.peak >= 75 ? root.tone : Theme.subtext
        }
        Sparkline {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.iconSize * 2.5
            height: Theme.iconSize - 4
            values: Svc.Sys.cpuHistory
            capacity: 16
            autoScale: true
            color: Theme.usageColor(root.cpu, Theme.info)
        }
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: root.expanded ? details.implicitWidth : 0
            height: details.implicitHeight
            visible: width > 0
            clip: true
            Behavior on width { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
            Label {
                id: details
                text: "cpu " + root.cpu + "%  mem " + Svc.Sys.memPercent + "%"
                      + (root.hot ? "  󰔏 " + Math.round(Svc.Sys.cpuTemp) + "°" : "")
                size: Theme.fontSizeSmall
                color: root.hot ? Theme.tempColor(Svc.Sys.cpuTemp) : Theme.text
            }
        }
    }
}
