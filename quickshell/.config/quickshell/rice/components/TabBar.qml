import QtQuick
import QtQuick.Layouts
import "../config"

// Text tabs with an underline that slides to the current one.
Item {
    id: root

    property var tabs: []          // [{ id, label, icon }]
    property string current: ""
    signal selected(string id)

    Layout.fillWidth: true
    implicitHeight: row.implicitHeight + Theme.accentThickness + 2

    Row {
        id: row
        spacing: 0
        Repeater {
            id: rep
            model: root.tabs
            Rectangle {
                required property var modelData
                readonly property bool isCurrent: modelData.id === root.current
                width: lbl.implicitWidth + Theme.pad * 3
                height: Theme.fontSize + Theme.pad * 2
                color: hov.containsMouse && !isCurrent ? Theme.surface1 : "transparent"
                Label {
                    id: lbl
                    anchors.centerIn: parent
                    text: modelData.icon + "  " + modelData.label.toUpperCase()
                    size: Theme.fontSizeSmall
                    font.bold: parent.isCurrent
                    color: parent.isCurrent ? Theme.accent : Theme.subtext
                }
                MouseArea {
                    id: hov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selected(parent.modelData.id)
                }
            }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Theme.surface2
    }
    Rectangle {
        id: underline
        readonly property Item cur: {
            rep.count;
            for (let i = 0; i < rep.count; i++)
                if (rep.itemAt(i) && rep.itemAt(i).isCurrent) return rep.itemAt(i);
            return null;
        }
        anchors.bottom: parent.bottom
        x: cur ? cur.x : 0
        width: cur ? cur.width : 0
        height: Theme.accentThickness
        color: Theme.accent
        Behavior on x { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
    }
}
