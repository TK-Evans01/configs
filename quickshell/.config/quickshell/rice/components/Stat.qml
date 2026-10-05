import QtQuick
import QtQuick.Layouts
import "../config"

// A number over its caption: "28 / this year".
ColumnLayout {
    id: root

    property string value: ""
    property string label: ""
    property color tint: Theme.textBright
    property int size: Theme.fontLg

    spacing: 0

    Label {
        text: root.value
        size: root.size
        color: root.tint
    }
    Label {
        visible: root.label !== ""
        text: root.label
        size: Theme.fontXs
        color: Theme.subtext
    }
}
