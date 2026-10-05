import QtQuick
import "../../config"
import "../../components"
import "../../services" as Svc

// Inbox: Proton unread (via Bridge) + unread notifications. Click: sidebar ›
// notifications. Middle: webmail. Mail glyph dims until Bridge is set up.
BarButton {
    id: root

    required property string screenName
    readonly property int n: Svc.Mail.unread
    readonly property bool ok: Svc.Mail.state_ === "ok"
    readonly property int notes: Svc.Notifications.unread

    active: Svc.Ui.isOpen("sidebar", screenName) && Svc.Ui.page === "notifications"
    onClicked: Svc.Ui.toggle("sidebar", screenName, "notifications")
    onMiddleClicked: Svc.Mail.openWebmail()

    Row {
        spacing: Theme.spacing
        Label {
            visible: Settings.showMail
            text: !root.ok ? "󰇮" : (root.n > 0 ? "󰇰" : "󰇮")
            size: Theme.iconSize
            color: Svc.Mail.state_ === "unconfigured" || Svc.Mail.state_ === "loading" ? Theme.muted
                 : !root.ok ? Theme.error : (root.n > 0 ? Theme.accent : Theme.subtext)
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            visible: Settings.showMail && root.ok && root.n > 0
            text: root.n
            size: Theme.fontTitle
            font.bold: true
            color: Theme.accent
        }
        Label {
            text: Svc.Notifications.dnd ? "󰂛" : (root.notes > 0 ? "󰂚" : "󰂜")
            size: Theme.iconSize
            color: Svc.Notifications.dnd ? Theme.warning : (root.notes > 0 ? Theme.catNotify : Theme.subtext)
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.notes > 0
            text: root.notes
            size: Theme.fontTitle
            font.bold: true
            color: Theme.catNotify
        }
    }
}
