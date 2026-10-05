import QtQuick
import "../config"

// Text in the shell font. `size` is the pixel size.
Text {
    property int size: Theme.fontMd
    color: Theme.text
    font.family: Theme.fontFamily
    font.pixelSize: size
    verticalAlignment: Text.AlignVCenter
}
