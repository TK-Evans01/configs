import QtQuick
import QtQuick.Layouts
import "../config"

// Sub-page header: back button, glyph, title/subtitle, trailing slot.
RowLayout {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    default property alias trailing: tail.data
    signal backClicked()

    Layout.fillWidth: true
    spacing: Theme.spacing

    IconButton {
        icon: "󰁍"
        onClicked: root.backClicked()
    }
    Label {
        text: root.icon
        color: Theme.accent
        size: Theme.fontSizeLarge
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        Label {
            text: root.title.toUpperCase()
            size: Theme.fontSize
            font.bold: true
            color: Theme.textBright
        }
        Label {
            Layout.fillWidth: true
            visible: root.subtitle !== ""
            text: root.subtitle
            size: Theme.fontSizeSmall
            color: Theme.subtext
            elide: Text.ElideRight
        }
    }
    RowLayout {
        id: tail
        spacing: Theme.spacing
    }
}
