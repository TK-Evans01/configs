import QtQuick
import "../config"

// Text that carousels: when it does not fit, it slides left continuously and
// wraps around through a second copy, so there is no back-and-forth bounce.
Item {
    id: root

    property string text: ""
    property color color: Theme.fg0
    property int pixelSize: Theme.fontSize
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

    NumberAnimation {
        id: carousel
        target: row
        property: "x"
        from: 0
        to: -(root.textWidth + root.gap)
        duration: Math.max(1, (root.textWidth + root.gap) * Settings.scrollMsPerPx)
        loops: Animation.Infinite
        running: root.scrolling && root.overflowing

        onRunningChanged: if (!running) row.x = 0;
    }

    // Restart from the left whenever the string changes, so a new track or
    // window title is read from its beginning.
    onTextChanged: {
        row.x = 0;
        if (carousel.running) carousel.restart();
    }
}
