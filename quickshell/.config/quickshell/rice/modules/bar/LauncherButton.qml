import QtQuick
import "../../config"
import "../../components"
import "../../services" as Svc

BarButton {
    id: root
    required property string screenName

    visible: Settings.showLauncher
    active: Svc.Ui.isOpen("launcher", screenName)
    onClicked: Svc.Ui.toggle("launcher", screenName, "")

    Label {
        text: "󰣇"   // nf-md-arch
        size: Theme.iconSize
        color: root.hovered || root.active ? Theme.accent : Theme.info
    }
}
