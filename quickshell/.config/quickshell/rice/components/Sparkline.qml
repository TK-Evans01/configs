import QtQuick
import "../config"

// Column-bar history graph (retro, no curves). Values in percent, oldest
// first; empty slots on the left until the history fills up. With
// autoScale the tallest bar sets the scale (floored at minScale) so light
// loads still show shape — color carries the severity.
Item {
    id: root

    property var values: []
    property int capacity: Settings.historySize
    property color color: Theme.accent
    property bool autoScale: false
    property real minScale: 20
    property int gapPx: 1

    readonly property real scale100: {
        if (!autoScale) return 100;
        let hi = minScale;
        for (const v of values) hi = Math.max(hi, v);
        return Math.min(100, hi);
    }
    readonly property real barW: Math.max(1, (width - gapPx * (capacity - 1)) / capacity)

    Repeater {
        model: root.capacity
        Rectangle {
            required property int index
            readonly property int vi: index - (root.capacity - root.values.length)
            readonly property real v: vi >= 0 ? root.values[vi] : 0
            x: Math.round(index * (root.barW + root.gapPx))
            width: Math.ceil(root.barW)
            height: vi >= 0 ? Math.max(1, Math.round(root.height * Math.min(1, v / root.scale100))) : 0
            y: root.height - height
            color: root.color
            opacity: vi >= 0 ? 0.35 + 0.65 * (index + 1) / root.capacity : 0
        }
    }
    // Baseline
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Theme.surface2
        z: -1
    }
}
