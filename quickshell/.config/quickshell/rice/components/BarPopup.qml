import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../config"

// Panel that grows out of the bar under a button: flush with the bar's bottom
// edge, square, hairline sides. One window per bar; shows while `wanted`.
// Closes on Escape or a click outside (focus grab) via `dismissed`.
PanelWindow {
    id: root

    required property var barWindow
    property Item anchorItem: null
    property bool wanted: false
    property int popupWidth: 400
    property real contentHeight: 0
    property int contentMargin: Theme.pad + 4
    default property alias content: inner.data
    // Items whose Keys handlers see key presses (the panel keeps focus).
    property list<Item> keyTargets
    // Takes focus on open instead of the panel (e.g. a search field).
    property Item initialFocus: null

    signal dismissed()

    readonly property real maxHeight: (screen ? screen.height : 1440) - Settings.barHeight - 40
    readonly property real panelHeight: Math.min(maxHeight, contentHeight + contentMargin * 2)

    WlrLayershell.namespace: "rice-popup"
    WlrLayershell.layer: WlrLayer.Overlay
    // From `wanted`, not `shownState`: Hyprland hands out keyboard focus when
    // the surface maps, so the mode must already be set by then.
    WlrLayershell.keyboardFocus: wanted ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        left: true
    }
    // Overlap the bar's 1px bottom border so the panel reads as attached.
    margins.top: Settings.barHeight - 1
    margins.left: panelX

    // Centered under the anchor, kept on screen. Re-read when it opens
    // (mapToItem is not reactive to the bar re-laying out).
    property real panelX: 0
    function _place() {
        const sw = screen ? screen.width : 2560;
        let x = sw - popupWidth;
        if (anchorItem) x = anchorItem.mapToItem(null, anchorItem.width / 2, 0).x - popupWidth / 2;
        panelX = Math.round(Math.max(0, Math.min(x, sw - popupWidth)));
    }

    implicitWidth: popupWidth
    implicitHeight: maxHeight
    color: "transparent"
    visible: false
    mask: Region { item: panel }

    readonly property bool shownState: wanted && visible

    onWantedChanged: {
        if (wanted) {
            _place();
            hideTimer.stop();
            visible = true;
            grabTimer.restart();
        } else {
            grab.active = false;
            hideTimer.restart();
        }
    }

    Timer {
        id: hideTimer
        interval: Theme.anim + 20
        onTriggered: if (!root.wanted) root.visible = false
    }
    // The grab only takes once the surface is mapped.
    Timer {
        id: grabTimer
        interval: 10
        onTriggered: {
            grab.active = root.wanted;
            (root.initialFocus || focusItem).forceActiveFocus();
        }
    }

    HyprlandFocusGrab {
        id: grab
        // Only the popup: with the bar in the grab Hyprland hands keyboard
        // focus to the bar. A bar click dismisses first; Ui.toggle then
        // treats the same button's click as the close.
        windows: [root]
        onCleared: if (root.wanted) root.dismissed()
    }

    Item {
        id: focusItem
        focus: root.initialFocus === null
        Keys.forwardTo: root.keyTargets
        Keys.onEscapePressed: root.dismissed()
    }

    Item {
        id: clipper
        width: root.popupWidth
        height: root.panelHeight + 2
        clip: true

        Rectangle {
            id: panel
            width: parent.width
            height: root.panelHeight
            y: root.shownState ? 0 : -height - 2
            color: Theme.background
            Behavior on y { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }

            // Swallow clicks so they don't fall through to the window behind.
            MouseArea { anchors.fill: parent }

            Rectangle { width: Theme.border; height: parent.height; color: Theme.surface2 }
            Rectangle { x: parent.width - width; width: Theme.border; height: parent.height; color: Theme.surface2 }
            Rectangle { y: parent.height - height; width: parent.width; height: Theme.border; color: Theme.surface2 }
            // Accent seam where the panel meets the bar.
            Rectangle { width: parent.width; height: Theme.border; color: Theme.surface2 }

            Item {
                id: inner
                anchors.fill: parent
                anchors.margins: root.contentMargin
                clip: true
            }
        }
    }
}
