import QtQuick
import "../config"

Item {
    id: root

    property string label: ""
    property string labelPrefix: ""
    property color labelColor: Theme.fg0
    property int labelSize: Theme.fontSize
    property bool hasPopout: false

    // 0 = no cap. Past this width the label is clipped and carousels.
    property int maxLabelWidth: 0
    property bool scrollLabel: true

    readonly property alias hovered: hover.hovered

    signal hoverEntered()
    signal hoverExited()
    signal clicked()
    signal rightClicked()

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
            text: root.labelPrefix
            visible: root.labelPrefix !== ""
            color: root.labelColor
            font.family: Theme.fontFamily
            font.pixelSize: root.labelSize
            anchors.verticalCenter: parent.verticalCenter
        }

        ScrollingText {
            id: labelText
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: root.labelColor
            pixelSize: root.labelSize
            maxWidth: root.maxLabelWidth
            scrolling: root.scrollLabel
        }
    }

    HoverHandler {
        id: hover
        onHoveredChanged: hovered ? root.hoverEntered() : root.hoverExited()
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: root.clicked()
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.rightClicked()
    }
}
