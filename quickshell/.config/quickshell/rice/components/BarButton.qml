import QtQuick
import "../config"

// Bar button: hover lifts the cell, `active` (its popup is open) adds the
// accent indicator. Content goes inside; the button sizes to it.
Item {
    id: root

    property bool active: false
    property color indicator: Theme.accent
    property real minWidth: 0
    default property alias content: holder.data
    readonly property alias hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed

    signal clicked()
    signal rightClicked()
    signal middleClicked()
    signal wheeled(int delta)

    implicitWidth: Math.max(minWidth, holder.childrenRect.width + Theme.pad * 2)
    implicitHeight: Settings.barHeight - Theme.outlineWidth

    // Hover is quieter than open: open = raised + accent indicator.
    Rectangle {
        anchors.fill: parent
        anchors.margins: Theme.round ? 4 : 0
        radius: Theme.radiusSmall
        color: root.active || root.hovered ? Theme.surface1 : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.animShort } }
    }

    AccentIndicator {
        active: root.active
        tint: root.indicator
        anchors.margins: Theme.round ? 4 : 0
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
