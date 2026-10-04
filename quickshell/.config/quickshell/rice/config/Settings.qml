pragma Singleton
import QtQuick

QtObject {
    readonly property int barHeight: 44

    // Label width caps (px) and carousel tuning for widgets that scroll.
    readonly property int windowLabelWidth: 300
    readonly property int mprisLabelWidth: 240
    readonly property int scrollMsPerPx: 28
    readonly property int scrollGap: 48

    readonly property var leftWidgets:   ["Workspaces", "Window", "Mpris"]
    readonly property var centerWidgets: ["Clock"]
    readonly property var rightWidgets:  ["Docker", "Network", "Bluetooth", "Volume", "System"]
}
