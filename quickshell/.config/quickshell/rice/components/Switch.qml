import QtQuick
import "../config"

// Two-cell retro switch: [ ON | OFF ] with the live half filled.
Rectangle {
    id: root

    property bool checked: false
    signal toggled()

    implicitWidth: 2 * cellW + 2
    implicitHeight: Theme.fontSize + 6
    readonly property int cellW: Theme.fontSizeSmall * 2 + 4
    color: Theme.surface0
    border.width: Theme.border
    border.color: mouse.containsMouse ? Theme.accent : Theme.surface2

    Rectangle {
        x: root.checked ? root.width - width - 1 : 1
        y: 1
        width: root.cellW
        height: parent.height - 2
        color: root.checked ? Theme.accent : Theme.surface2
        Behavior on x { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
    }
    Label {
        x: 1; width: root.cellW; height: parent.height
        horizontalAlignment: Text.AlignHCenter
        text: "OFF"
        size: Theme.fontSizeSmall - 2
        color: root.checked ? Theme.muted : Theme.text
    }
    Label {
        x: root.width - root.cellW - 1; width: root.cellW; height: parent.height
        horizontalAlignment: Text.AlignHCenter
        text: "ON"
        size: Theme.fontSizeSmall - 2
        color: root.checked ? Theme.textReverse : Theme.muted
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
