import QtQuick
import "../config"

// Square bar button: hover lifts the cell, `active` (its popup is open) adds
// the accent underline. Content goes inside; the button sizes to it.
Item {
    id: root

    property bool active: false
    default property alias content: holder.data
    readonly property alias hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed

    signal clicked()
    signal rightClicked()
    signal middleClicked()
    signal wheeled(int delta)

    implicitWidth: holder.childrenRect.width + Theme.pad * 2
    implicitHeight: Settings.barHeight - 1

    Rectangle {
        anchors.fill: parent
        color: root.active ? Theme.surface1 : (root.hovered ? Theme.surface2 : "transparent")
        Behavior on color { ColorAnimation { duration: Theme.animShort } }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.active ? parent.width - Theme.spacing : 0
        height: Theme.accentThickness
        color: Theme.accent
        Behavior on width { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
    }

    Item {
        id: holder
        anchors.centerIn: parent
        width: childrenRect.width
        height: childrenRect.height
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: m => {
            if (m.button === Qt.RightButton) root.rightClicked();
            else if (m.button === Qt.MiddleButton) root.middleClicked();
            else root.clicked();
        }
        onWheel: w => root.wheeled(w.angleDelta.y)
    }
}
