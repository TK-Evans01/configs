import QtQuick
import QtQuick.Layouts
import "../config"

// Text tabs; the accent indicator (underline or pill) stretches to the current one.
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
                height: Theme.fontMd + Theme.pad * 2
                radius: Theme.radiusSmall
                color: hov.containsMouse && !isCurrent ? Theme.surface1 : "transparent"
                Label {
                    id: lbl
                    anchors.centerIn: parent
                    text: modelData.icon + "  " + modelData.label.toUpperCase()
                    size: Theme.fontBase
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
    // Selection: the edge moving toward the new tab leads (fast), the other
    // trails (slow), so the indicator stretches as it travels.
    Item {
        id: sel
        readonly property Item cur: {
            rep.count;
            for (let i = 0; i < rep.count; i++)
                if (rep.itemAt(i) && rep.itemAt(i).isCurrent) return rep.itemAt(i);
            return null;
        }
        readonly property real targetL: cur ? cur.x : 0
        readonly property real targetR: cur ? cur.x + cur.width : 0
        property real l: targetL
        property real r: targetR
        property bool movingRight: true
        onTargetLChanged: movingRight = targetL > l
        Behavior on l { NumberAnimation { duration: sel.movingRight ? Theme.anim + 60 : 50; easing.type: Theme.easing } }
        Behavior on r { NumberAnimation { duration: sel.movingRight ? 50 : Theme.anim + 60; easing.type: Theme.easing } }

        x: l
        width: r - l
        height: row.height
        z: -1

        Rectangle {
            visible: Theme.accentStyle === "underline"
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -(root.height - row.height)
            width: parent.width
            height: Theme.accentThickness
            color: Theme.accent
        }
        Rectangle {
            visible: Theme.accentStyle === "pill"
            anchors.fill: parent
            anchors.margins: 3
            radius: Theme.radiusSmall
            color: Qt.alpha(Theme.accent, 0.2)
        }
    }
}
