import QtQuick
import "../../config"
import "../../core" as Core

// One row in the network popout: glyph, name, scrolling detail.
Item {
    id: entry

    property string icon: ""
    property string name: ""
    property string detail: ""
    property color accent: Theme.fg0

    implicitHeight: 22

    Text {
        id: glyph
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 24
        text: entry.icon
        color: entry.accent
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }

    Text {
        id: nameT
        anchors.left: glyph.right
        anchors.verticalCenter: parent.verticalCenter
        width: 100
        text: entry.name
        color: entry.accent
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 2
        elide: Text.ElideRight
    }

    Core.ScrollingText {
        anchors.left: nameT.right
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: entry.detail
        color: Theme.grey
        pixelSize: Theme.fontSize - 3
        scrolling: false
    }
}
