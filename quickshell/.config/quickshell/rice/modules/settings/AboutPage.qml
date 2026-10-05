import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../config"
import "../../components"

ColumnLayout {
    id: root
    spacing: Theme.pad

    property string rss: ""
    Process {
        running: root.visible
        command: ["sh", "-c", "ps -o rss= -p $PPID 2>/dev/null; ps -o rss= -p $(pgrep -x quickshell | head -1)"]
        stdout: StdioCollector { onStreamFinished: root.rss = Math.round(Number(this.text.trim().split("\n").pop()) / 1024) + " MB" }
    }

    Card {
        Layout.fillWidth: true
        CardHeader { icon: "󰋽"; title: "rice" }
        Repeater {
            model: [
                { k: "Config", v: Quickshell.shellDir },
                { k: "Prefs", v: Prefs.path },
                { k: "Themes", v: Theme.themesDir },
                { k: "Theme", v: Theme.themeId + "  ·  " + Theme.shape + "  ·  " + Theme.fontFamily },
                { k: "Overrides", v: Object.keys(Prefs.overrides || {}).length + " changed settings" },
                { k: "Memory", v: root.rss }
            ]
            SettingRow {
                required property var modelData
                label: modelData.k
                Label { text: modelData.v; size: Theme.fontSm; color: Theme.subtext; elide: Text.ElideMiddle; Layout.maximumWidth: 520 }
            }
        }
    }

    Card {
        Layout.fillWidth: true
        CardHeader { icon: "󰑓"; title: "Reset"; accent: Theme.error }
        SettingRow {
            label: "Reset every setting"
            help: "Clears all overrides (theme, shape and font stay)."
            IconButton {
                property bool armed: false
                text: armed ? "click again" : "reset all"
                fg: Theme.error
                enabledState: Object.keys(Prefs.overrides || {}).length > 0
                onClicked: {
                    if (!armed) { armed = true; disarm.restart(); return; }
                    armed = false;
                    for (const k of Object.keys(Prefs.overrides)) Prefs.reset(k);
                }
                Timer { id: disarm; interval: 3000; onTriggered: parent.armed = false }
            }
        }
    }
}
