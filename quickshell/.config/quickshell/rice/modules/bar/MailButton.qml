import QtQuick
import "../../config"
import "../../components"
import "../../services" as Svc

// Proton unread count (via Bridge); dimmed until set up. Click: Mail page.
BarButton {
    id: root

    required property string screenName
    readonly property int n: Svc.Mail.unread
    readonly property bool ok: Svc.Mail.state_ === "ok"

    visible: Settings.showMail
    active: Svc.Ui.isOpen("quicksettings", screenName) && Svc.Ui.page === "mail"
    onClicked: Svc.Ui.toggle("quicksettings", screenName, "mail")
    onMiddleClicked: Svc.Mail.openWebmail()

    Row {
        spacing: Theme.spacing
        Label {
            text: !root.ok ? "󰇮" : (root.n > 0 ? "󰇰" : "󰇮")
            size: Theme.iconSize
            color: Svc.Mail.state_ === "unconfigured" || Svc.Mail.state_ === "loading" ? Theme.muted
                 : !root.ok ? Theme.error : (root.n > 0 ? Theme.accent : Theme.subtext)
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.ok && root.n > 0
            text: root.n
            size: Theme.fontSizeSmall + 1
            font.bold: true
            color: Theme.accent
        }
    }
}
