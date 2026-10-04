import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../config"
import "../../components"
import "../../services" as Svc

// A tray app's DBus menu drawn in the shell's style (replaces Qt's native
// popup): attached under its icon, separators, check/radio marks, icons,
// submenus that slide in place with a back row.
BarPopup {
    id: root

    required property string screenName
    property var item: null            // SystemTrayItem whose menu is shown

    wanted: Svc.Ui.isOpen("traymenu", screenName) && item !== null && item.hasMenu
    popupWidth: Settings.trayMenuWidth
    contentHeight: col.implicitHeight
    onDismissed: Svc.Ui.dismiss()
    onWantedChanged: if (!wanted) stack = []

    // Entered submenus: [{ entry, label }]; empty = root menu.
    property var stack: []
    readonly property var current: stack.length ? stack[stack.length - 1] : null

    // A menu only stays loaded while an opener holds it, so keep the root and
    // every entered level open, not just the one on screen.
    QsMenuOpener { id: rootOpener; menu: root.visible && root.item ? root.item.menu : null }
    Instantiator {
        model: root.stack
        QsMenuOpener { required property var modelData; menu: modelData.entry }
    }
    QsMenuOpener {
        id: opener
        menu: root.current ? root.current.entry : (root.item ? root.item.menu : null)
    }

    function clean(t) { return (t || "").replace(/_(?!_)/g, "").replace(/__/g, "_"); }
    function iconSource(icon) {
        if (!icon) return "";
        if (icon.indexOf("://") >= 0 || icon.startsWith("/")) return icon;
        return Quickshell.iconPath(icon, true);
    }

    readonly property var entries: opener.children ? opener.children.values : []
    readonly property bool anyLeading: entries.some(e => !e.isSeparator
        && (e.buttonType !== QsMenuButtonType.None || (e.icon || "") !== ""))

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 0

        // title: app name, or the submenu path
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: Theme.spacing
            spacing: Theme.spacing
            IconButton {
                visible: root.current !== null
                icon: "󰁍"
                size: Theme.fontSizeSmall + Theme.spacing * 2
                onClicked: root.stack = root.stack.slice(0, -1)
            }
            Label {
                Layout.fillWidth: true
                text: (root.current ? root.current.label : (root.item ? (root.item.tooltipTitle || root.item.title || root.item.id) : "")).toUpperCase()
                size: Theme.fontSizeSmall - 1
                font.bold: true
                font.letterSpacing: 1
                color: Theme.accent
                elide: Text.ElideRight
            }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.surface2; Layout.bottomMargin: 4 }

        Repeater {
            model: root.entries

            Item {
                id: row
                required property var modelData
                readonly property var entry: modelData
                readonly property bool sep: entry && entry.isSeparator
                readonly property bool on: entry && entry.enabled
                readonly property bool toggle: entry && entry.buttonType !== QsMenuButtonType.None

                Layout.fillWidth: true
                implicitHeight: sep ? 9 : Theme.fontSize + 14

                Rectangle {
                    visible: row.sep
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 1
                    color: Theme.surface2
                }

                Rectangle {
                    visible: !row.sep
                    anchors.fill: parent
                    color: hov.containsMouse && row.on ? Theme.surface1 : "transparent"
                    opacity: row.on ? 1 : 0.4

                    Rectangle {
                        visible: hov.containsMouse && row.on
                        width: Theme.accentThickness
                        height: parent.height
                        color: Theme.accent
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.pad
                        anchors.rightMargin: Theme.spacing
                        spacing: Theme.spacing

                        // leading slot: [x] / (•) or the entry's icon
                        Item {
                            visible: root.anyLeading
                            implicitWidth: Theme.fontSize
                            implicitHeight: Theme.fontSize
                            Label {
                                anchors.centerIn: parent
                                visible: row.toggle
                                text: !row.entry ? "" : row.entry.buttonType === QsMenuButtonType.RadioButton
                                      ? (row.entry.checkState === Qt.Checked ? "󰐾" : "󰄰")
                                      : (row.entry.checkState === Qt.Checked ? "󰄲" : "󰄱")
                                color: row.entry && row.entry.checkState === Qt.Checked ? Theme.accent : Theme.subtext
                            }
                            Image {
                                anchors.fill: parent
                                visible: !row.toggle && status === Image.Ready
                                source: row.entry && !row.toggle ? root.iconSource(row.entry.icon) : ""
                                sourceSize.width: width * 2
                                sourceSize.height: height * 2
                                asynchronous: true
                            }
                        }
                        Label {
                            Layout.fillWidth: true
                            text: row.entry ? root.clean(row.entry.text) : ""
                            size: Theme.fontSizeSmall + 1
                            color: hov.containsMouse && row.on ? Theme.textBright : Theme.text
                            elide: Text.ElideRight
                        }
                        Label {
                            visible: row.entry && row.entry.hasChildren
                            text: "󰅂"
                            color: Theme.subtext
                        }
                    }

                    MouseArea {
                        id: hov
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !row.sep
                        cursorShape: row.on ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (!row.on || !row.entry) return;
                            if (row.entry.hasChildren) {
                                root.stack = root.stack.concat([{ entry: row.entry, label: root.clean(row.entry.text) }]);
                                return;
                            }
                            row.entry.triggered();
                            Svc.Ui.close();
                        }
                    }
                }
            }
        }

        Label {
            visible: root.entries.length === 0
            Layout.alignment: Qt.AlignHCenter
            Layout.margins: Theme.pad
            text: "empty menu"
            size: Theme.fontSizeSmall
            color: Theme.muted
        }
    }
}
