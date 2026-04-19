import QtQuick
import "../../config"

Item {
    id: root
    property int value: 0
    property int min: 0
    property int max: 150
    property color accentColor: Theme.yellow
    signal commit(int pct)

    implicitHeight: 18

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        color: Theme.bg2
        border.color: Theme.bg3
        border.width: 1

        Rectangle {
            width: Math.max(0, Math.min(1, (root.value - root.min) / (root.max - root.min))) * parent.width
            height: parent.height
            color: root.accentColor
        }

        Rectangle {
            x: Math.max(0, Math.min(1, (root.value - root.min) / (root.max - root.min))) * parent.width - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 6; height: 14
            color: root.accentColor
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        property bool dragging: false

        function pctAt(x) {
            const t = Math.max(0, Math.min(1, x / width));
            return Math.round(root.min + t * (root.max - root.min));
        }

        onPressed: mouse => { dragging = true; root.commit(pctAt(mouse.x)); }
        onReleased: dragging = false
        onPositionChanged: mouse => { if (dragging) root.commit(pctAt(mouse.x)); }
        onWheel: wheel => {
            const step = wheel.angleDelta.y > 0 ? 5 : -5;
            root.commit(Math.max(root.min, Math.min(root.max, root.value + step)));
        }
    }
}
