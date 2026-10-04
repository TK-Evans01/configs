import QtQuick
import "../../config"
import "../../components"
import "../../services" as Svc

// Focused window: app class tag + scrolling title.
Row {
    id: root

    readonly property var toplevel: Svc.Hyprland.activeToplevel
    readonly property string title: toplevel ? (toplevel.title || "") : ""
    readonly property string rawClass: toplevel && toplevel.lastIpcObject ? (toplevel.lastIpcObject.class || "") : ""
    // "org.mozilla.firefox" -> "firefox"; dropped when the title already says it.
    readonly property string appClass: {
        const c = rawClass.split(".").pop().toLowerCase();
        return c && c !== title.toLowerCase() ? c : "";
    }

    visible: title !== ""
    spacing: Theme.spacing
    height: Settings.barHeight - 1

    Label {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.appClass !== ""
        text: root.appClass
        size: Theme.fontSizeSmall
        color: Theme.info
    }
    ScrollingText {
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        color: Theme.subtext
        maxWidth: Settings.windowLabelWidth
    }
}
