import QtQuick
import QtQuick.Layouts
import "../config"

// Labelled segmented usage bar: NAME  detail ........ 42%
//                               [■■■■■■■■□□□□□□□□□□□□]
ColumnLayout {
    id: root

    property string name: ""
    property string detail: ""
    property int percent: 0
    property color accent: Theme.info
    property int segments: 24
    property bool showLabel: true     // the NAME detail … 42% row
    property bool usage: true         // warm/red past 75/90% (off for volume)
    readonly property color barColor: usage ? Theme.usageColor(percent, accent) : accent

    Layout.fillWidth: true
    spacing: 4

    RowLayout {
        visible: root.showLabel
        Layout.fillWidth: true
        spacing: Theme.spacing
        Label {
            visible: root.name !== ""
            text: root.name
            color: root.accent
            size: Theme.fontBase
            font.bold: true
        }
        Label {
            Layout.fillWidth: true
            text: root.detail
            color: Theme.subtext
            size: Theme.fontBase
            elide: Text.ElideRight
        }
        Label {
            text: root.percent + "%"
            color: root.barColor
            size: Theme.fontBase
        }
    }

    Item {
        id: bar
        Layout.fillWidth: true
        implicitHeight: 10
        readonly property real cellW: (width - (root.segments - 1) * 2) / root.segments
        readonly property int lit: Math.round(root.segments * Math.max(0, Math.min(100, root.percent)) / 100)
        Repeater {
            model: root.segments
            Rectangle {
                required property int index
                x: Math.round(index * (bar.cellW + 2))
                width: Math.max(1, Math.round(bar.cellW))
                height: bar.height
                radius: Theme.round ? 2 : 0
                color: index < bar.lit ? root.barColor : Theme.surface2
                Behavior on color { ColorAnimation { duration: Theme.anim } }
            }
        }
    }
}
