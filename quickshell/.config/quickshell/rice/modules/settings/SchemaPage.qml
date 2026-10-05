import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"

// A settings page from the schema: its custom component (if any), then one
// card per section — custom section component or schema items.
ColumnLayout {
    id: root

    required property var page
    spacing: Theme.pad

    function customComponent(name) {
        return ({
            Appearance: appearance, Sound: sound, Bluetooth: bluetooth, Network: network,
            NightLight: nightlight, Actions: actions, About: about, Feeds: feeds, Sources: sources,
            Connections: connections, Packages: packages, Focus: focus, Wallpaper: wallpaper
        })[name] || null;
    }

    Loader {
        Layout.fillWidth: true
        active: !!root.page.custom
        visible: active
        sourceComponent: root.customComponent(root.page.custom)
    }

    Repeater {
        model: root.page.sections || []
        Card {
            id: sec
            required property var modelData
            Layout.fillWidth: true
            spacing: Theme.pad
            CardHeader { title: sec.modelData.title }
            Loader {
                Layout.fillWidth: true
                active: !!sec.modelData.custom
                visible: active
                sourceComponent: root.customComponent(sec.modelData.custom)
            }
            Repeater {
                model: sec.modelData.items || []
                SchemaItem {
                    required property var modelData
                    item: modelData
                }
            }
        }
    }

    Component { id: appearance; AppearancePage {} }
    Component { id: sound; SoundPage {} }
    Component { id: bluetooth; BluetoothPage {} }
    Component { id: network; NetworkPage {} }
    Component { id: nightlight; NightLightPage {} }
    Component { id: actions; ActionsPage {} }
    Component { id: about; AboutPage {} }
    Component { id: feeds; FeedsSection {} }
    Component { id: sources; SourcesSection {} }
    Component { id: connections; ConnectionsPage {} }
    Component { id: packages; PackagesPage {} }
    Component { id: focus; FocusSection {} }
    Component { id: wallpaper; WallpaperSection {} }
}
