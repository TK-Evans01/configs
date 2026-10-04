import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../config"
import "../../components"
import "../../services" as Svc

// Unread Proton mail (read-only; nothing gets marked read). Row → webmail.
ColumnLayout {
    id: page
    spacing: Theme.pad

    function age(ts) {
        const s = Date.now() / 1000 - ts;
        if (s < 3600) return Math.max(1, Math.floor(s / 60)) + "m";
        if (s < 86400) return Math.floor(s / 3600) + "h";
        return Math.floor(s / 86400) + "d";
    }

    PageHeader {
        icon: Svc.Mail.unread > 0 ? "󰇰" : "󰇮"
        title: "Mail"
        subtitle: ({
            ok: Svc.Mail.unread + " unread  ·  " + Svc.Mail.total + " in inbox",
            offline: "Proton Mail Bridge isn't running",
            unconfigured: "not set up",
            loading: "checking…",
            error: Svc.Mail.error
        })[Svc.Mail.state_] || ""
        onBackClicked: Svc.Ui.back()
        IconButton {
            icon: "󰑓"
            onClicked: Svc.Mail.refresh()
        }
        IconButton {
            icon: "󰖟"
            text: "open"
            onClicked: { Svc.Ui.close(); Svc.Mail.openWebmail(); }
        }
    }

    // --- setup ---
    Card {
        Layout.fillWidth: true
        visible: Svc.Mail.state_ === "unconfigured"
        CardHeader { icon: "󰒓"; title: "Set up"; subtitle: "Proton Mail Bridge"; accent: Theme.accent }
        component Step: RowLayout {
            property string n: ""
            property string body: ""
            Layout.fillWidth: true
            spacing: Theme.pad
            Label { Layout.alignment: Qt.AlignTop; text: parent.n; color: Theme.accent; font.bold: true }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: parent.body
                size: Theme.fontSizeSmall
                color: Theme.text
            }
        }
        Step { n: "1"; body: "Open Bridge and sign in to your Proton account." }
        Step { n: "2"; body: "In Bridge, open your account's mailbox settings and copy the IMAP username and the Bridge password (not your Proton password)." }
        Step { n: "3"; body: "Save them (terminal):" }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: cmd.implicitHeight + Theme.spacing * 2
            color: Theme.bg0
            border.width: Theme.border
            border.color: Theme.surface2
            Label {
                id: cmd
                anchors.fill: parent
                anchors.margins: Theme.spacing
                wrapMode: Text.WrapAnywhere
                text: "umask 077; printf 'machine 127.0.0.1 login %s password %s\\n' USER PASS > ~/.config/rice/proton-bridge.netrc"
                size: Theme.fontSizeSmall - 3
                color: Theme.subtext
            }
        }
        Step { n: "4"; body: "Click check — the unread count shows up here and in the bar." }
        RowLayout {
            Layout.fillWidth: true
            IconButton {
                icon: "󰐊"
                text: "open bridge"
                // The headless copy holds Bridge's lock; stop it before opening the window.
                onClicked: { Svc.Ui.close(); Svc.Mail.openBridgeWindow(); }
            }
            IconButton {
                icon: "󰑓"
                text: "check"
                onClicked: Svc.Mail.refresh()
            }
        }
    }

    Card {
        Layout.fillWidth: true
        visible: Svc.Mail.state_ === "offline"
        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: "Bridge serves your mailbox on 127.0.0.1:1143. Start it and the count fills in."
            size: Theme.fontSizeSmall
            color: Theme.subtext
        }
        IconButton {
            icon: "󰐊"
            text: "start bridge"
            onClicked: Svc.Mail.startBridge()
        }
    }

    Card {
        Layout.fillWidth: true
        visible: Svc.Mail.state_ === "error"
        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: Svc.Mail.error + "\n\nCheck ~/.config/rice/proton-bridge.netrc against Bridge's IMAP username/password."
            size: Theme.fontSizeSmall
            color: Theme.error
        }
    }

    Card {
        Layout.fillWidth: true
        visible: Svc.Mail.state_ === "ok"

        CardHeader {
            icon: "󰇰"
            title: "Unread"
            subtitle: "updated " + Qt.formatTime(Svc.Mail.updated, "HH:mm")
        }
        Label {
            visible: Svc.Mail.messages.length === 0
            Layout.alignment: Qt.AlignHCenter
            Layout.margins: Theme.pad
            text: "inbox zero"
            size: Theme.fontSizeSmall
            color: Theme.muted
        }
        Repeater {
            model: Svc.Mail.messages
            DeviceRow {
                required property var modelData
                icon: "󰇮"
                accent: Theme.text
                title: modelData.subject
                subtitle: modelData.from + "  ·  " + page.age(modelData.date)
                onClicked: { Svc.Ui.close(); Svc.Mail.openWebmail(); }
            }
        }
        Label {
            visible: Svc.Mail.unread > Svc.Mail.messages.length
            text: "+" + (Svc.Mail.unread - Svc.Mail.messages.length) + " more"
            size: Theme.fontSizeSmall - 2
            color: Theme.muted
        }
    }
}
