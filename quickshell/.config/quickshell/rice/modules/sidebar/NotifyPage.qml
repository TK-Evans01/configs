import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../config"
import "../../components"
import "../../services" as Svc

// Notifications, grouped by source. Mail on top shows the inbox's unread
// messages (Bridge IMAP); mail notifications themselves only toast. Each
// group shows its latest five until expanded.
Flickable {
    id: root

    contentHeight: col.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    property var expanded: ({})    // source → true
    function toggleExpanded(id) {
        const e = Object.assign({}, expanded); e[id] = !e[id]; expanded = e;
    }

    function iconFor(n) {
        if (n.image) return n.image;
        if (n.icon && n.icon.startsWith("/")) return "file://" + n.icon;
        if (n.icon && n.icon.indexOf("://") > 0) return n.icon;
        const guess = (n.icon || n.app || "").toLowerCase().replace(/\s+/g, "-");
        return guess ? Quickshell.iconPath(guess, true) : "";
    }

    readonly property var groups: Svc.Notifications.groups.filter(g => g.id !== "mail" || !Svc.Mail.configured)

    ColumnLayout {
        id: col
        width: root.width
        spacing: Theme.pad

        // --- header: DND + clear ---
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing
            Label {
                Layout.fillWidth: true
                text: Svc.Notifications.history.length + " kept"
                size: Theme.fontSm
                color: Theme.subtext
            }
            Label {
                text: "󰂛 do not disturb"
                size: Theme.fontSm
                color: Svc.Notifications.dnd ? Theme.warning : Theme.subtext
            }
            Switch {
                checked: Svc.Notifications.dnd
                onToggled: Svc.Notifications.toggleDnd()
            }
            IconButton {
                icon: "󰎟"
                fg: Theme.error
                enabledState: Svc.Notifications.history.length > 0
                onClicked: Svc.Notifications.clearAll()
            }
        }

        // --- mail (inbox) ---
        Card {
            Layout.fillWidth: true
            visible: Svc.Mail.configured || Svc.Mail.state_ === "offline"
            CardHeader {
                icon: Svc.Mail.unread > 0 ? "󰇰" : "󰇮"
                title: "Mail"
                subtitle: Svc.Mail.state_ === "ok" ? Svc.Mail.unread + " unread"
                        : Svc.Mail.state_ === "offline" ? "Bridge isn't running" : Svc.Mail.error
                accent: Theme.catNotify
                Spinner { visible: Svc.Mail.state_ === "loading" }
                IconButton { icon: "󰑓"; onClicked: Svc.Mail.refresh() }
                IconButton { icon: "󰖟"; onClicked: { Svc.Ui.close(); Svc.Mail.openWebmail(); } }
            }
            Repeater {
                model: Svc.Mail.messages.slice(0, root.expanded.mailbox ? 50 : 5)
                ListRow {
                    required property var modelData
                    icon: "󰇮"
                    iconColor: Theme.catNotify
                    title: modelData.subject || "(no subject)"
                    subtitle: modelData.from
                    note: Fmt.since(modelData.date)
                    onClicked: { Svc.Ui.close(); Svc.Mail.openWebmail(); }
                }
            }
            Label {
                visible: Svc.Mail.state_ === "ok" && Svc.Mail.messages.length === 0
                text: "inbox zero"
                size: Theme.fontBase
                color: Theme.muted
            }
            IconButton {
                visible: Svc.Mail.messages.length > 5
                text: root.expanded.mailbox ? "show less" : "show all " + Svc.Mail.messages.length
                icon: root.expanded.mailbox ? "󰅃" : "󰅀"
                size: Theme.controlHeight - 6
                onClicked: root.toggleExpanded("mailbox")
            }
        }

        // --- notification groups ---
        Repeater {
            model: root.groups

            Card {
                id: group
                required property var modelData
                readonly property bool open: root.expanded[modelData.id] === true
                Layout.fillWidth: true

                CardHeader {
                    icon: group.modelData.icon
                    title: group.modelData.label
                    subtitle: group.modelData.items.length + (group.modelData.unread ? "  ·  " + group.modelData.unread + " new" : "")
                    accent: Theme.catNotify
                    IconButton {
                        icon: "󰎟"
                        fg: Theme.error
                        onClicked: Svc.Notifications.clearSource(group.modelData.id)
                    }
                }

                Repeater {
                    model: group.modelData.items.slice(0, group.open ? 100 : 5)

                    ListRow {
                        id: row
                        required property var modelData
                        title: modelData.summary || modelData.app
                        subtitle: modelData.body
                        subtitleMaxLines: 3
                        note: Fmt.since(modelData.time / 1000)
                        active: modelData.urgency === "critical"
                        indicator: Theme.error
                        accent: modelData.read ? Theme.text : Theme.textBright
                        leading: Component {
                            Item {
                                implicitWidth: Theme.iconSize
                                implicitHeight: Theme.iconSize
                                Image {
                                    id: img
                                    anchors.fill: parent
                                    source: root.iconFor(row.modelData)
                                    sourceSize.width: width * 2
                                    sourceSize.height: height * 2
                                    visible: status === Image.Ready
                                    asynchronous: true
                                    mipmap: true
                                }
                                Label {
                                    anchors.centerIn: parent
                                    visible: !img.visible
                                    text: Svc.Notifications.sourceInfo(row.modelData.source).icon
                                    color: Theme.catNotify
                                }
                            }
                        }
                        onClicked: Svc.Notifications.activate(modelData.id)

                        Repeater {
                            model: Svc.Notifications.hasLive(row.modelData.id)
                                ? row.modelData.actions.filter(a => a.id !== "default").slice(0, 2) : []
                            IconButton {
                                required property var modelData
                                text: modelData.text
                                size: Theme.controlHeight - 8
                                onClicked: Svc.Notifications.invoke(row.modelData.id, modelData.id)
                            }
                        }
                        IconButton {
                            opacity: row.hovered || hovered ? 1 : 0
                            icon: "󰅖"
                            size: Theme.controlHeight - 8
                            onClicked: Svc.Notifications.dismiss(row.modelData.id)
                        }
                    }
                }

                IconButton {
                    visible: group.modelData.items.length > 5
                    text: group.open ? "show less" : "show all " + group.modelData.items.length
                    icon: group.open ? "󰅃" : "󰅀"
                    size: Theme.controlHeight - 6
                    onClicked: root.toggleExpanded(group.modelData.id)
                }
            }
        }

        Label {
            visible: root.groups.length === 0
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.gap
            text: "no notifications"
            color: Theme.muted
        }
    }
}
