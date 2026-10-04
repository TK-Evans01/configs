import QtQuick
import "../../config"

// Icon toggle sized to its glyph, so the label can never overflow the box.
Rectangle {
    id: btn

    property bool muted: false
    property string onIcon: ""    // nf-fa-volume_up
    property string offIcon: ""   // nf-fa-volume_off
    signal toggled()

    implicitWidth: 30
    implicitHeight: 22
    color: hover.hovered ? Theme.bg3 : Theme.bg2
    border.color: btn.muted ? Theme.red : Theme.bg3
    border.width: 1

    Text {
        anchors.centerIn: parent
        text: btn.muted ? btn.offIcon : btn.onIcon
        color: btn.muted ? Theme.red : Theme.fg0
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 2
    }

    HoverHandler { id: hover }
    TapHandler { onTapped: btn.toggled() }
}
