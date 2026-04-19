import QtQuick
import "../../config"

Item {
    id: root
    property var items: []
    property string selected: ""
    property bool open: false
    signal picked(string name)

    readonly property string currentDesc: {
        for (let i = 0; i < items.length; i++) if (items[i].name === selected) return items[i].description;
        return selected || "(none)";
    }

    implicitHeight: header.height + (open ? list.height : 0)

    Rectangle {
        id: header
        width: parent.width
        height: 22
        color: hdrHover.hovered ? Theme.bg3 : Theme.bg2
        border.color: Theme.bg3
        border.width: 1

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.right: caret.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.currentDesc
            color: Theme.fg0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
            elide: Text.ElideRight
        }
        Text {
            id: caret
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: root.open ? "\u25b4" : "\u25be"
            color: Theme.grey
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
        HoverHandler { id: hdrHover }
        TapHandler { onTapped: root.open = !root.open }
    }

    Column {
        id: list
        anchors.top: header.bottom
        width: parent.width
        visible: root.open

        Repeater {
            model: root.items
            delegate: Rectangle {
                required property var modelData
                width: list.width
                height: 20
                color: optHover.hovered ? Theme.bg3 : Theme.bg1
                border.color: Theme.bg3
                border.width: 1

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: (modelData.name === root.selected ? "\u2713 " : "   ") + modelData.description
                    color: modelData.name === root.selected ? Theme.yellow : Theme.fg0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                    elide: Text.ElideRight
                }
                HoverHandler { id: optHover }
                TapHandler { onTapped: { root.picked(modelData.name); root.open = false; } }
            }
        }
    }
}
