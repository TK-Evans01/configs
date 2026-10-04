import QtQuick
import "../config"

Rectangle {
    implicitWidth: Theme.border
    implicitHeight: Math.round(Settings.barHeight * 0.5)
    width: implicitWidth
    height: implicitHeight
    color: Theme.surface2
}
