import QtQuick
import "../config"

// 3×3 block spinner: one lit cell walks the ring. Reserves its size whether
// or not it runs, so a loading state never shifts the layout.
Item {
    id: root

    property bool running: true
    property int cell: 4
    property color tint: Theme.accent

    implicitWidth: cell * 3 + 2 * 2
    implicitHeight: implicitWidth

    // Ring order around the centre cell.
    readonly property var ring: [0, 1, 2, 5, 8, 7, 6, 3]
    property int step: 0

    Timer {
        interval: 90
        running: root.running && root.visible
        repeat: true
        onTriggered: root.step = (root.step + 1) % 8
    }

    Grid {
        columns: 3
        spacing: 2
        Repeater {
            model: 9
            Rectangle {
                required property int index
                width: root.cell
                height: root.cell
                radius: Theme.round ? root.cell / 2 : 0
                readonly property int pos: root.ring.indexOf(index)
                readonly property int behind: pos < 0 ? 99 : (root.step - pos + 8) % 8
                color: !root.running || pos < 0 ? Theme.surface2
                     : behind === 0 ? root.tint
                     : behind <= 2 ? Qt.alpha(root.tint, 0.45)
                     : Theme.surface2
            }
        }
    }
}
