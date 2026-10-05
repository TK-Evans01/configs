import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"

// Notification sources: which app names land in which group. "system" takes
// everything unmatched.
ColumnLayout {
    id: root
    spacing: Theme.pad
    readonly property var sources: Settings.notifySources
    function setApps(i, apps) {
        const s = sources.map((x, j) => j === i ? Object.assign({}, x, { apps: apps }) : x);
        Prefs.override("notifySources", s);
    }

    Repeater {
        model: root.sources
        ColumnLayout {
            id: src
            required property var modelData
            required property int index
            Layout.fillWidth: true
            spacing: 4
            Label { text: src.modelData.icon + "  " + src.modelData.label; font.bold: true; size: Theme.fontBase; color: Theme.catNotify }
            Label {
                visible: src.modelData.id === "system"
                text: "everything that matches nothing else"
                size: Theme.fontSm
                color: Theme.subtext
            }
            Flow {
                visible: src.modelData.id !== "system"
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: src.modelData.apps
                    IconButton {
                        required property string modelData
                        text: modelData
                        icon: "󰅖"
                        size: Theme.controlHeight - 8
                        onClicked: root.setApps(src.index, src.modelData.apps.filter(a => a !== modelData))
                    }
                }
                TextField {
                    width: 160
                    placeholder: "app name…"
                    prefix: "+"
                    onAccepted: {
                        const v = text.trim().toLowerCase();
                        if (v && src.modelData.apps.indexOf(v) < 0) root.setApps(src.index, src.modelData.apps.concat([v]));
                        clear();
                    }
                }
            }
        }
    }
}
