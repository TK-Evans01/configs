import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../config"
import "../../components"
import "../../services" as Svc

// Notification toasts, top-right under the bar, on the focused monitor.
// Newest on top. Click = default action; 󰅖 = dismiss. Critical stays.
PanelWindow {
    id: root

    required property var screenRef
    screen: screenRef
    readonly property bool focusedHere: {
        const m = Svc.Hyprland.focusedMonitor;
        return m !== null && screenRef !== null && m.name === screenRef.name;
    }

    WlrLayershell.namespace: "rice-toast"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; right: true }
    margins.top: Settings.barHeight + 10
    margins.right: 10
    implicitWidth: Settings.toastWidth
    implicitHeight: Math.max(1, stack.implicitHeight)
    color: "transparent"
    visible: focusedHere && Svc.Notifications.toasts.length > 0 && Svc.Ui.open !== "sidebar"
    mask: Region { item: stack }

    ColumnLayout {
        id: stack
        width: parent.width
        spacing: Theme.spacing

        Repeater {
            model: Svc.Notifications.toasts.slice().reverse()

            Rectangle {
                id: toast
                required property var modelData
                readonly property var rec: Svc.Notifications.byId(modelData)
                Layout.fillWidth: true
                implicitHeight: body.implicitHeight + Theme.pad * 2
                radius: Theme.radius
                color: Theme.background
                border.width: Theme.border
                border.color: rec && rec.urgency === "critical" ? Theme.error : Theme.surface2
                visible: rec !== null

                // Time left along the bottom (deadline kept in Notifications,
                // so rebuilding this delegate doesn't restart it).
                readonly property bool timed: Svc.Notifications.timeoutFor(modelData) > 0
                Rectangle {
                    visible: toast.timed
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.margins: Theme.border
                    height: Theme.accentThickness
                    color: Theme.catNotify
                    width: (parent.width - 2) * Svc.Notifications.toastLeft(toast.modelData)
                    radius: Theme.radiusPill
                }

                MouseArea {
                    id: hov
                    anchors.fill: parent
                    hoverEnabled: true
                    onContainsMouseChanged: containsMouse ? Svc.Notifications.pauseToast(toast.modelData) : Svc.Notifications.resumeToast(toast.modelData)
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: m => {
                        if (m.button === Qt.RightButton) Svc.Notifications.expireToast(toast.modelData);
                        else Svc.Notifications.activate(toast.modelData);
                    }
                }

                RowLayout {
                    id: body
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.pad
                    spacing: Theme.pad

                    Label {
                        Layout.alignment: Qt.AlignTop
                        text: toast.rec ? Svc.Notifications.sourceInfo(toast.rec.source).icon : ""
                        size: Theme.fontLg
                        color: toast.rec && toast.rec.urgency === "critical" ? Theme.error : Theme.catNotify
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label {
                            Layout.fillWidth: true
                            text: toast.rec ? toast.rec.app.toLowerCase() : ""
                            size: Theme.fontSm
                            color: Theme.subtext
                            elide: Text.ElideRight
                        }
                        Label {
                            Layout.fillWidth: true
                            text: toast.rec ? toast.rec.summary : ""
                            size: Theme.fontTitle
                            font.bold: true
                            color: Theme.textBright
                            elide: Text.ElideRight
                        }
                        Label {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: toast.rec ? toast.rec.body : ""
                            size: Theme.fontSm
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                        }
                        RowLayout {
                            visible: toast.rec && toast.rec.actions.some(a => a.id !== "default")
                            spacing: Theme.spacing / 2
                            Repeater {
                                model: toast.rec ? toast.rec.actions.filter(a => a.id !== "default").slice(0, 3) : []
                                IconButton {
                                    required property var modelData
                                    text: modelData.text
                                    size: Theme.controlHeight - 8
                                    onClicked: Svc.Notifications.invoke(toast.modelData, modelData.id)
                                }
                            }
                        }
                    }
                    IconButton {
                        Layout.alignment: Qt.AlignTop
                        icon: "󰅖"
                        size: Theme.controlHeight - 8
                        onClicked: Svc.Notifications.dismiss(toast.modelData)
                    }
                }
            }
        }
    }
}
