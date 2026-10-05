import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services" as Svc

// Feed list editor: name + URL rows, remove, add.
ColumnLayout {
    id: root
    spacing: Theme.spacing
    readonly property var feeds: Settings.feeds
    function commit(v) { Prefs.override("feeds", v); Svc.Feeds.refresh(); }

    Repeater {
        model: root.feeds
        ListRow {
            required property var modelData
            required property int index
            clickable: false
            icon: "󰑫"
            title: modelData.name
            subtitle: modelData.url
            note: Svc.Feeds.errors[modelData.name] || ""
            IconButton {
                icon: "󰆴"
                fg: Theme.error
                size: Theme.controlHeight - 8
                onClicked: root.commit(root.feeds.filter((f, i) => i !== index))
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacing
        TextField { id: nameF; Layout.preferredWidth: 160; Layout.fillWidth: false; placeholder: "name" }
        TextField {
            id: urlF
            placeholder: "https://…/feed.xml"
            onAccepted: add.clicked()
        }
        IconButton {
            id: add
            icon: "󰐕"
            text: "add"
            enabledState: /^https?:\/\//.test(urlF.text.trim())
            onClicked: {
                const url = urlF.text.trim();
                if (!/^https?:\/\//.test(url)) return;
                root.commit(root.feeds.concat([{ name: nameF.text.trim() || url.replace(/^https?:\/\/(www\.)?/, "").split("/")[0], url: url }]));
                nameF.clear(); urlF.clear();
            }
        }
    }
}
