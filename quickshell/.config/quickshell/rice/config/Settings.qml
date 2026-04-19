pragma Singleton
import QtQuick

QtObject {
    readonly property int barHeight: 32

    readonly property var leftWidgets:   ["Workspaces", "Window", "Mpris"]
    readonly property var centerWidgets: ["Clock"]
    readonly property var rightWidgets:  ["Docker", "Mullvad", "Volume", "Cpu", "Memory"]
}
