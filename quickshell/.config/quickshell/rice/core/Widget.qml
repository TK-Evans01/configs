import QtQuick
import "../config"

Item {
    id: root

    property string label: ""
    property color labelColor: Theme.fg0
    property bool hasPopout: false

    readonly property alias hovered: hover.hovered

    signal hoverEntered()
    signal hoverExited()
    signal clicked()

    implicitWidth: content.implicitWidth + Theme.pad * 2
    implicitHeight: Settings.barHeight

    Rectangle {
        id: bg
        anchors.fill: parent
        color: hover.hovered ? Theme.bg3 : "transparent"
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: root.label
            color: root.labelColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    HoverHandler {
        id: hover
        onHoveredChanged: hovered ? root.hoverEntered() : root.hoverExited()
    }

    TapHandler {
        onTapped: root.clicked()
    }
}
