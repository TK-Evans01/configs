import QtQuick
import QtQuick.Layouts
import "../config"

// Icon (click = mute) + blocky track + value. Drag, click or wheel to set.
// value runs min..max (percent by default); `moved` fires with the new value.
RowLayout {
    id: root

    property string icon: ""
    property int value: 0
    property int min: 0
    property int max: 100
    property int step: 5
    property string suffix: "%"
    property bool muted: false
    property color fill: Theme.accent
    property bool showPercent: true

    signal moved(int pct)
    signal iconClicked()

    Layout.fillWidth: true
    spacing: Theme.spacing

    IconButton {
        visible: root.icon !== ""
        icon: root.icon
        fg: root.muted ? Theme.error : Theme.text
        onClicked: root.iconClicked()
    }

    Item {
        id: track
        Layout.fillWidth: true
        implicitHeight: Theme.fontSize + Theme.spacing * 2
        readonly property real frac: Math.max(0, Math.min(1, (root.value - root.min) / (root.max - root.min)))

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 10
            color: Theme.surface0
            border.width: Theme.border
            border.color: Theme.surface2

            Rectangle {
                x: 1; y: 1
                width: Math.max(0, (parent.width - 2) * track.frac)
                height: parent.height - 2
                color: root.muted ? Theme.surface3 : root.fill
                Behavior on width { enabled: !drag.pressed; NumberAnimation { duration: Theme.animShort } }
            }
        }
        // Block handle
        Rectangle {
            x: Math.round(track.frac * (track.width - width))
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: 20
            color: drag.containsMouse || drag.pressed ? Theme.textBright : (root.muted ? Theme.surface3 : root.fill)
            border.width: Theme.border
            border.color: Theme.bg0
        }

        MouseArea {
            id: drag
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            function pctAt(x) {
                const raw = root.min + Math.max(0, Math.min(1, x / width)) * (root.max - root.min);
                return Math.round(raw / root.step) * root.step;
            }
            onPressed: m => root.moved(pctAt(m.x))
            onPositionChanged: m => { if (pressed) root.moved(pctAt(m.x)); }
            onWheel: w => root.moved(Math.max(root.min, Math.min(root.max, root.value + (w.angleDelta.y > 0 ? root.step : -root.step))))
        }
    }

    Label {
        visible: root.showPercent
        Layout.preferredWidth: Theme.fontSizeSmall * (root.suffix.length > 1 ? 4 : 3)
        horizontalAlignment: Text.AlignRight
        text: root.value + root.suffix
        size: Theme.fontSizeSmall
        color: root.muted ? Theme.muted : Theme.subtext
    }
}
