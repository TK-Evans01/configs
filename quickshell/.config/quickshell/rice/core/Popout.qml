import QtQuick
import Quickshell
import "../config"

// Slide-down popout anchored to its owner via the compositor.
// Uses PopupWindow so Hyprland places it on the SAME output as the owner
// widget — no manual screen/margin math, no cross-monitor misfires.
PopupWindow {
    id: root

    required property Item owner
    property Component contentComponent: null
    property int preferredWidth: 300
    property int preferredHeight: 160
    property int hideDelay: 150
    property int slideDuration: 220

    readonly property var ownerAttached: owner ? owner.QsWindow : null
    readonly property bool ownerHovered: owner ? owner.hovered === true : false

    property bool opened: false
    property bool rendered: false

    // Anchor to the owner widget's rect within ITS window. edges/gravity =
    // Bottom → popup sits centered directly below the widget, on that screen.
    anchor.window: ownerAttached ? ownerAttached.window : null
    anchor.rect.x: {
        if (!ownerAttached || !ownerAttached.window) return 0;
        owner.x; owner.width;
        let p = owner.parent;
        while (p) { p.x; p = p.parent; }
        return ownerAttached.itemRect(owner).x;
    }
    anchor.rect.y: {
        if (!ownerAttached || !ownerAttached.window) return 0;
        owner.y; owner.height;
        let p = owner.parent;
        while (p) { p.y; p = p.parent; }
        return ownerAttached.itemRect(owner).y;
    }
    anchor.rect.width: owner ? owner.width : 0
    anchor.rect.height: owner ? owner.height : 0
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom

    implicitWidth: preferredWidth
    implicitHeight: preferredHeight
    color: "transparent"
    visible: owner !== null && (ownerAttached ? ownerAttached.window !== null : false)
        && contentComponent !== null && rendered

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

    mask: Region { item: content }

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
