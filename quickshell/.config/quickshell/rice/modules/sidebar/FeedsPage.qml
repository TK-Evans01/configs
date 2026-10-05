import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services" as Svc

// RSS / Atom items from Settings.feeds, newest first; chips filter by feed.
Flickable {
    id: root

    contentHeight: col.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    property string feed: ""      // "" = all
    readonly property var shown: Svc.Feeds.items.filter(i => root.feed === "" || i.feed === root.feed)

    ColumnLayout {
        id: col
        width: root.width
        spacing: Theme.pad

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing
            Label {
                Layout.fillWidth: true
                text: Svc.Feeds.unread + " unread  ·  updated " + Fmt.since(Svc.Feeds.updated)
                size: Theme.fontSm
                color: Theme.subtext
            }
            Spinner { visible: Svc.Feeds.loading }
            IconButton { icon: "󰄬"; onClicked: Svc.Feeds.markAllRead() }
            IconButton { icon: "󰑓"; onClicked: Svc.Feeds.refresh() }
        }

        Flow {
            Layout.fillWidth: true
            spacing: Theme.spacing / 2
            Repeater {
                model: [""].concat(Settings.feeds.map(f => f.name))
                IconButton {
                    required property var modelData
                    text: modelData === "" ? "all" : modelData.toLowerCase()
                    size: Theme.controlHeight - 6
                    checked: root.feed === modelData
                    onClicked: root.feed = modelData
                }
            }
        }

        Repeater {
            model: Object.keys(Svc.Feeds.errors)
            Label {
                required property string modelData
                text: "󰀦 " + modelData + ": " + Svc.Feeds.errors[modelData]
                size: Theme.fontSm
                color: Theme.warning
            }
        }

        Repeater {
            model: root.shown
            ListRow {
                required property var modelData
                readonly property bool isRead: Svc.Feeds.isRead(modelData)
                icon: isRead ? "󰄳" : "󰑫"
                iconColor: isRead ? Theme.muted : Theme.accent
                title: modelData.title
                titleMaxLines: 2
                subtitle: modelData.feed.toLowerCase() + (modelData.summary ? "  ·  " + modelData.summary : "")
                subtitleMaxLines: 2
                note: modelData.date ? Fmt.since(modelData.date) : ""
                accent: isRead ? Theme.subtext : Theme.textBright
                onClicked: { Svc.Ui.close(); Svc.Feeds.open(modelData); }
            }
        }

        Label {
            visible: root.shown.length === 0 && !Svc.Feeds.loading
            Layout.alignment: Qt.AlignHCenter
            text: "nothing yet"
            color: Theme.muted
        }
    }
}
