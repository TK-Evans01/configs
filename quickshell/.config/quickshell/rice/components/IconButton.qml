import QtQuick
import "../config"

// Small square glyph button with a hairline border.
Rectangle {
    id: root

    property string icon: ""
    property string text: ""
    property color fg: Theme.text
    property bool enabledState: true
    property bool checked: false
    property int size: Theme.fontSize + Theme.spacing * 2
    readonly property alias hovered: mouse.containsMouse

    signal clicked()

    implicitHeight: size
    implicitWidth: text === "" ? size : row.implicitWidth + Theme.pad * 2
    radius: Theme.radius
    color: checked ? Theme.accent : (mouse.containsMouse && enabledState ? Theme.surface2 : Theme.surface1)
    border.width: Theme.border
    border.color: checked ? Theme.accent : Theme.surface2
    opacity: enabledState ? 1 : 0.4
    Behavior on color { ColorAnimation { duration: Theme.animShort } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.spacing
        Label {
            visible: root.icon !== ""
            text: root.icon
            color: root.checked ? Theme.textReverse : root.fg
            size: Theme.fontSize
        }
        Label {
            visible: root.text !== ""
            text: root.text
            color: root.checked ? Theme.textReverse : root.fg
            size: Theme.fontSizeSmall
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabledState ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.enabledState) root.clicked()
    }
}
