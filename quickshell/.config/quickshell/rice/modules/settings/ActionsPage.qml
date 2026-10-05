import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services" as Svc

// The action allowlist (config/actions.json + themes): what the launcher's
// > mode and the voice assistant may run. Click runs one.
ColumnLayout {
    id: root
    spacing: Theme.pad

    readonly property var groups: {
        const g = [];
        for (const a of Svc.Actions.all) {
            let e = g.find(x => x.id === a.group);
            if (!e) { e = { id: a.group, items: [] }; g.push(e); }
            e.items.push(a);
        }
        return g;
    }

    Label {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        size: Theme.fontSm
        color: Theme.subtext
        text: "Edit config/actions.json to add or change actions; scripts/check-actions.py checks them against the IPC. " + Svc.Actions.all.length + " actions."
    }

    Repeater {
        model: root.groups
        Card {
            id: grp
            required property var modelData
            Layout.fillWidth: true
            CardHeader { title: grp.modelData.id; subtitle: grp.modelData.items.length + "" }
            Repeater {
                model: grp.modelData.items
                ListRow {
                    required property var modelData
                    compact: true
                    icon: modelData.icon
                    title: modelData.title
                    note: (modelData.confirm === "confirm" ? "confirm  ·  " : "") + (modelData.voice === false ? "no voice  ·  " : "") + modelData.call.join(" ")
                    onClicked: if (modelData.confirm !== "confirm") Svc.Actions.run(modelData)
                }
            }
        }
    }
}
