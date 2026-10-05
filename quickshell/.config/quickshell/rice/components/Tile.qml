import QtQuick
import QtQuick.Layouts
import "../config"

// Quick-settings toggle tile. Body click toggles; the ▸ cell opens its page.
Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property string sublabel: ""
    property bool active: false
    property bool busy: false
    property bool hasDetails: false
    property color activeColor: Theme.accent

    signal toggled()
    signal openDetails()

    Layout.fillWidth: true
    implicitHeight: Theme.fontMd * 2 + Theme.pad * 2
    radius: Theme.radius
    clip: true
    color: body.containsMouse ? Theme.surface1 : Theme.surface0
    border.width: Theme.border
    border.color: active ? activeColor : Theme.surface2
    Behavior on color { ColorAnimation { duration: Theme.animShort } }
    scale: body.pressed ? 0.98 : 1
    Behavior on scale { NumberAnimation { duration: Theme.animShort } }

    MouseArea {
        id: body
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.border
        spacing: Theme.pad

        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: height
            radius: Theme.radius
            color: root.active ? root.activeColor : Theme.surface1
            Behavior on color { ColorAnimation { duration: Theme.anim } }
            Label {
                anchors.centerIn: parent
                text: root.icon
                size: Theme.fontLg
                color: root.active ? Theme.textReverse : (root.busy ? Theme.warning : Theme.text)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Label {
                Layout.fillWidth: true
                text: root.label
                size: Theme.fontTitle
                font.bold: true
                color: Theme.textBright
                elide: Text.ElideRight
            }
            Label {
                Layout.fillWidth: true
                visible: root.sublabel !== ""
                text: root.sublabel
                size: Theme.fontSm
                color: root.active ? root.activeColor : Theme.subtext
                elide: Text.ElideRight
            }
        }

        Rectangle {
            visible: root.hasDetails
            Layout.fillHeight: true
            Layout.preferredWidth: Theme.fontMd + Theme.spacing * 2
            radius: Theme.radius
            color: more.containsMouse ? Theme.surface2 : "transparent"
            Rectangle { width: 1; height: parent.height; color: Theme.surface2 }
            Label {
                anchors.centerIn: parent
                text: "󰅂"
                color: more.containsMouse ? Theme.accent : Theme.subtext
            }
            MouseArea {
                id: more
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openDetails()
            }
        }
    }
}
