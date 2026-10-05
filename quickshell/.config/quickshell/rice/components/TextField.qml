import QtQuick
import QtQuick.Layouts
import "../config"

// Text input: hairline frame (accent when focused), optional prefix glyph,
// placeholder, blinking block cursor. Keys the field doesn't consume arrive
// through `keyPressed` (set e.accepted to swallow them).
Rectangle {
    id: root

    property alias text: input.text
    property alias input: input
    property string placeholder: ""
    property string prefix: ""
    property int fontSize: Theme.fontBase
    default property alias trailing: tail.data
    signal keyPressed(var e)
    signal accepted()

    Layout.fillWidth: true
    implicitHeight: fontSize + Theme.spacing * 2 + (fontSize >= Theme.fontMd ? 6 : 0)
    radius: Theme.radiusSmall
    color: Theme.surface0
    border.width: Theme.border
    border.color: input.activeFocus ? Theme.accent : Theme.surface2

    function clear() { input.text = ""; }
    function focusInput() { input.forceActiveFocus(); }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacing + (Theme.round ? 4 : 0)
        anchors.rightMargin: Theme.spacing + (Theme.round ? 4 : 0)
        spacing: Theme.spacing

        Label {
            visible: root.prefix !== ""
            text: root.prefix
            font.bold: true
            size: root.fontSize
            color: Theme.accent
        }
        Item {
            Layout.fillWidth: true
            implicitHeight: input.implicitHeight

            TextInput {
                id: input
                anchors.fill: parent
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.textBright
                selectionColor: Theme.accent
                selectedTextColor: Theme.textReverse
                font.family: Theme.fontFamily
                font.pixelSize: root.fontSize
                clip: true
                cursorDelegate: Rectangle {
                    width: Math.round(root.fontSize * 0.6)
                    radius: Theme.round ? 2 : 0
                    color: Theme.accent
                    opacity: input.activeFocus ? 1 : 0
                    SequentialAnimation on opacity {
                        running: input.activeFocus
                        loops: Animation.Infinite
                        NumberAnimation { to: 1; duration: 0 }
                        PauseAnimation { duration: 530 }
                        NumberAnimation { to: 0; duration: 0 }
                        PauseAnimation { duration: 530 }
                    }
                }
                Keys.onPressed: e => root.keyPressed(e)
                onAccepted: root.accepted()
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                x: input.activeFocus ? Math.round(root.fontSize * 0.6) + 4 : 0
                visible: input.text === ""
                text: root.placeholder
                color: Theme.muted
                size: root.fontSize
                elide: Text.ElideRight
                width: parent.width - x
            }
        }
        RowLayout {
            id: tail
            spacing: Theme.spacing
        }
    }
}
