import QtQuick
import "../../core"
import "../../config"
import "../../services" as Svc

Widget {
    id: win
    readonly property var t: Svc.Hyprland.activeToplevel
    label: t ? (t.title || "") : ""
    labelColor: Theme.grey
    maxLabelWidth: Settings.windowLabelWidth
}
