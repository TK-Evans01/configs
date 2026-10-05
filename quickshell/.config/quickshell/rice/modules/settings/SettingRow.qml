import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"

// One option: label + help on the left, its control on the right, and ↺
// (back to the default) once it has been changed.
RowLayout {
    id: root

    property string key: ""
    property string label: ""
    property string help: ""
    default property alias control: slot.data
    readonly property bool changed: key !== "" && Prefs.overrides && Object.prototype.hasOwnProperty.call(Prefs.overrides, key)

    Layout.fillWidth: true
    spacing: Theme.pad

    ColumnLayout {
        Layout.fillWidth: true
        Layout.preferredWidth: 0
        Layout.minimumWidth: 150
        spacing: 1
        Label {
            Layout.fillWidth: true
            text: root.label
            size: Theme.fontTitle
            color: root.changed ? Theme.accent : Theme.textBright
            elide: Text.ElideRight
        }
        Label {
            Layout.fillWidth: true
            visible: root.help !== ""
            text: root.help
            size: Theme.fontSm
            color: Theme.subtext
            wrapMode: Text.Wrap
        }
    }
    RowLayout {
        id: slot
        spacing: Theme.spacing
    }
    IconButton {
        opacity: root.changed ? 1 : 0
        enabledState: root.changed
        icon: "󰑓"
        size: Theme.controlHeight - 6
        onClicked: Prefs.reset(root.key)
    }
}
