import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"

// Big-number card with a history graph: CPU / GPU / RAM in the System tab.
Card {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property color accent: Theme.info
    property int percent: 0
    property var history: []
    property var chips: []        // short strings under the number
    default property alias extra: more.data

    CardHeader {
        icon: root.icon
        title: root.title
        subtitle: root.subtitle
        accent: root.accent
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.pad

        ColumnLayout {
            spacing: 0
            Layout.preferredWidth: Theme.fontSize * 5
            Label {
                text: root.percent + "%"
                size: Theme.iconSizeLarge + 11
                color: Theme.usageColor(root.percent, Theme.textBright)
            }
            Repeater {
                model: root.chips
                Label {
                    required property string modelData
                    text: modelData
                    size: Theme.fontSizeSmall - 2
                    color: Theme.subtext
                }
            }
        }
        Sparkline {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 56
            values: root.history
            color: Theme.usageColor(root.percent, root.accent)
        }
    }

    ColumnLayout {
        id: more
        Layout.fillWidth: true
        spacing: Theme.spacing
    }
}
