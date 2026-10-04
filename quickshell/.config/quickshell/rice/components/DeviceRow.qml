import QtQuick
import QtQuick.Layouts
import "../config"

// Clickable list row: glyph, title, subtitle, trailing slot. `active` marks
// the in-use one with the accent bar on the left.
Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property color accent: Theme.text
    property bool active: false
    property bool clickable: true
    default property alias trailing: tail.data
    readonly property alias hovered: mouse.containsMouse
    signal clicked()

    Layout.fillWidth: true
    implicitHeight: Math.max(Theme.fontSize * 2 + 8, row.implicitHeight + 8)
    color: mouse.containsMouse && clickable ? Theme.surface1 : "transparent"

    Rectangle {
        visible: root.active
        width: Theme.accentThickness
        height: parent.height
        color: Theme.accent
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.clickable) root.clicked()
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: Theme.pad
        anchors.rightMargin: Theme.spacing
        spacing: Theme.pad

        Label {
            Layout.preferredWidth: Theme.fontSize * 1.4
            text: root.icon
            color: root.active ? Theme.accent : root.accent
            size: Theme.fontSize
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Label {
                Layout.fillWidth: true
                text: root.title
                size: Theme.fontSizeSmall + 1
                color: root.active ? Theme.textBright : root.accent
                elide: Text.ElideRight
            }
            Label {
                Layout.fillWidth: true
                visible: root.subtitle !== ""
                text: root.subtitle
                size: Theme.fontSizeSmall - 2
                color: Theme.subtext
                elide: Text.ElideRight
            }
        }
        RowLayout {
            id: tail
            spacing: Theme.spacing / 2
        }
    }
}
