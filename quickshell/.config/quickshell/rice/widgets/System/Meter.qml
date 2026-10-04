import QtQuick
import "../../config"
import "../../core" as Core

// One labelled row: name on the left, detail text, usage bar + percent.
Item {
    id: row

    property string name: ""
    property string detail: ""
    property int percent: 0
    property color accent: Theme.blue

    readonly property color barColor: percent >= 90 ? Theme.red
                                    : percent >= 75 ? Theme.orange
                                    : accent

    implicitHeight: 30

    Text {
        id: nameT
        anchors.left: parent.left
        anchors.top: parent.top
        width: 62
        text: row.name
        color: row.accent
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 2
        font.bold: true
    }

    Core.ScrollingText {
        anchors.left: nameT.right
        anchors.right: pctT.left
        anchors.rightMargin: 6
        anchors.top: parent.top
        text: row.detail
        color: Theme.grey
        pixelSize: Theme.fontSize - 3
        scrolling: false
    }

    Text {
        id: pctT
        anchors.right: parent.right
        anchors.top: parent.top
        text: row.percent + "%"
        color: row.barColor
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 2
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        height: 4
        color: Theme.bg3

        Rectangle {
            width: parent.width * Math.min(100, Math.max(0, row.percent)) / 100
            height: parent.height
            color: row.barColor

            Behavior on width {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
        }
    }
}
