import QtQuick
import QtQuick.Window
import Quickshell
import "../config"

PanelWindow {
    id: root

    required property Item owner
    property Component contentComponent: null
    property int preferredWidth: 300
    property int preferredHeight: 160
    property int hideDelay: 150
    property int slideDuration: 220

    readonly property var ownerWin: owner ? owner.Window.window : null
    readonly property bool ownerHovered: owner ? owner.hovered === true : false

    readonly property real ownerCenterX: {
        if (!owner || !ownerWin) return 0;
        owner.x; owner.y; owner.width;
        let p = owner.parent;
        while (p) { p.x; p.y; p.width; p = p.parent; }
        return owner.mapToItem(null, owner.width / 2, 0).x;
    }

    readonly property var resolvedScreen: {
        if (ownerWin && ownerWin.screen) {
            const name = ownerWin.screen.name;
            for (let i = 0; i < Quickshell.screens.length; i++) {
                if (Quickshell.screens[i].name === name) return Quickshell.screens[i];
            }
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    property bool opened: false
    property bool rendered: false

    onOwnerHoveredChanged: {
        if (ownerHovered) { hideTimer.stop(); opened = true; rendered = true; }
        else if (!self.hovered) hideTimer.restart();
    }

    Connections {
        target: self
        function onHoveredChanged() {
            if (self.hovered) hideTimer.stop();
            else if (!root.ownerHovered) hideTimer.restart();
        }
    }

    Timer {
        id: hideTimer
        interval: root.hideDelay
        onTriggered: root.opened = false
    }

    screen: resolvedScreen
    visible: owner !== null && ownerWin !== null && contentComponent !== null && rendered

    anchors {
        top: true
        left: true
    }
    margins.top: 0
    margins.left: ownerWin
        ? Math.max(0, Math.min(ownerWin.width - preferredWidth, ownerCenterX - preferredWidth / 2))
        : 0

    implicitWidth: preferredWidth
    implicitHeight: preferredHeight
    color: "transparent"

    mask: Region {
        item: content
    }

    HoverHandler { id: self }

    Item {
        anchors.fill: parent
        clip: true

        Rectangle {
            id: content
            width: parent.width
            height: parent.height
            y: root.opened ? 0 : -height
            color: Theme.bg1
            border.color: Theme.bg3
            border.width: 1

            Behavior on y {
                NumberAnimation {
                    duration: root.slideDuration
                    easing.type: Easing.OutCubic
                    onFinished: {
                        if (!root.opened) root.rendered = false;
                    }
                }
            }

            Loader {
                anchors.fill: parent
                anchors.margins: Theme.pad
                sourceComponent: root.contentComponent
            }
        }
    }
}
