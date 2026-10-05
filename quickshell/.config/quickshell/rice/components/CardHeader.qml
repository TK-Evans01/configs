import QtQuick
import QtQuick.Layouts
import "../config"

// Card title row: glyph, UPPERCASE title, optional subtitle, trailing slot.
RowLayout {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property color accent: Theme.accent
    default property alias trailing: tail.data

    Layout.fillWidth: true
    spacing: Theme.spacing

    Label {
        visible: root.icon !== ""
        text: root.icon
        color: root.accent
        size: Theme.fontMd
    }
    Label {
        text: root.title.toUpperCase()
        color: root.accent
        size: Theme.fontBase
        font.bold: true
        font.letterSpacing: 1
    }
    Label {
        Layout.fillWidth: true
        visible: root.subtitle !== ""
        text: root.subtitle
        color: Theme.subtext
        size: Theme.fontBase
        elide: Text.ElideRight
    }
    // Pushes the trailing slot right when there is no subtitle to do it.
    Item {
        visible: root.subtitle === ""
        Layout.fillWidth: true
    }
    RowLayout {
        id: tail
        spacing: Theme.spacing / 2
    }
}
