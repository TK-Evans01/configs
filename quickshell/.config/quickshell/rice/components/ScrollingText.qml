import QtQuick
import "../config"

// Text that carousels: when it does not fit, it slides left continuously and
// wraps around through a second copy, so there is no back-and-forth bounce.
Item {
    id: root

    property string text: ""
    property color color: Theme.text
    property int pixelSize: Theme.fontMd
    property bool bold: false

    // 0 = no cap; otherwise the widest the item will ever be.
    property int maxWidth: 0
    property bool scrolling: true
    // Used when scrolling is off: clip with an ellipsis instead of carouseling.
    property bool elide: true
    property int gap: Settings.scrollGap

    readonly property real textWidth: t1.implicitWidth
    readonly property bool overflowing: textWidth > width + 0.5

    implicitWidth: maxWidth > 0 ? Math.min(textWidth, maxWidth) : textWidth
    implicitHeight: t1.implicitHeight
    clip: true

    Row {
        id: row
        spacing: root.gap
        x: 0

        Text {
            id: t1
            text: root.text
            color: root.color
            font.family: Theme.fontFamily
            font.pixelSize: root.pixelSize
            font.bold: root.bold
            width: (!root.scrolling && root.elide) ? root.width : implicitWidth
            elide: (!root.scrolling && root.elide) ? Text.ElideRight : Text.ElideNone
        }

        Text {
            id: t2
            text: root.text
            visible: root.overflowing
            color: root.color
            font.family: Theme.fontFamily
            font.pixelSize: root.pixelSize
            font.bold: root.bold
        }
    }

    // Whole-pixel steps on a timer (one px per scrollMsPerPx ≈ 36 fps), not
    // an animation: an animation repaints at the monitor's rate (360 Hz here)
    // for as long as a title scrolls, and pixel fonts stay crisp on whole px.
    Timer {
        id: carousel
        interval: Math.max(10, Settings.scrollMsPerPx)
        repeat: true
        running: root.scrolling && root.overflowing && root.visible
        onRunningChanged: if (!running) row.x = 0
        onTriggered: row.x = row.x - 1 <= -(root.textWidth + root.gap) ? 0 : row.x - 1
    }

    // Restart from the left whenever the string changes, so a new track or
    // window title is read from its beginning.
    onTextChanged: row.x = 0
}
