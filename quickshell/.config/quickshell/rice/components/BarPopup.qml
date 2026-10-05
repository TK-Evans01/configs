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
    property real _grabbedAt: 0

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
    // Overlap the bar's bottom outline so the panel reads as attached.
    margins.top: Settings.barHeight - Theme.outlineWidth
    // Round shape: the window also holds the inverted corners (ears) that
    // join the panel to the bar, `ear` px either side (less at a screen edge).
    readonly property int ear: Theme.joinRadius
    readonly property real _sw: screen ? screen.width : 2560
    readonly property real _winX: Math.max(0, panelX - ear)
    readonly property real _off: panelX - _winX
    margins.left: _winX

    // Centered under the anchor, kept on screen. Re-read when it opens
    // (mapToItem is not reactive to the bar re-laying out).
    property real panelX: 0
    function _place() {
        const sw = screen ? screen.width : 2560;
        let x = sw - popupWidth;
        if (anchorItem) x = anchorItem.mapToItem(null, anchorItem.width / 2, 0).x - popupWidth / 2;
        panelX = Math.round(Math.max(0, Math.min(x, sw - popupWidth)));
    }

    implicitWidth: Math.min(popupWidth + _off + ear, _sw - _winX)
    implicitHeight: maxHeight
    color: "transparent"
    visible: false
    mask: Region { item: panel }

    readonly property bool shownState: wanted && visible

    // Bar.qml creates popups lazily, already wanted: open on creation too.
    Component.onCompleted: if (wanted) _sync()
    onWantedChanged: _sync()
    function _sync() {
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
            root._grabbedAt = Date.now();
            (root.initialFocus || focusItem).forceActiveFocus();
        }
    }

    HyprlandFocusGrab {
        id: grab
        // Only the popup: with the bar in the grab Hyprland hands keyboard
        // focus to the bar. A bar click dismisses first; Ui.toggle then
        // treats the same button's click as the close.
        windows: [root]
        // A grab cleared within the first moments is the surface still mapping
        // (lazily created windows): grab again instead of closing.
        onCleared: {
            if (!root.wanted) return;
            if (Date.now() - root._grabbedAt < 200) { grabTimer.restart(); return; }
            root.dismissed();
        }
    }

    Item {
        id: focusItem
        focus: root.initialFocus === null
        Keys.forwardTo: root.keyTargets
        Keys.onEscapePressed: root.dismissed()
    }

    Item {
        id: clipper
        width: root.width
        height: root.panelHeight + Theme.outlineWidth
        clip: true

        // The body; its silhouette (ears + outline) is drawn by PanelShape.
        Item {
            id: panel
            width: root.popupWidth
            height: root.panelHeight
            y: root.shownState ? 0 : -height - Theme.outlineWidth * 2
            x: root._off
            Behavior on y { NumberAnimation { duration: Theme.anim; easing.type: Theme.easing } }
            Behavior on height { NumberAnimation { duration: Theme.anim; easing.type: Theme.easing } }

            PanelShape {
                x: -root.ear
                attach: "top"
                ear: root.ear
                bodyWidth: root.popupWidth
                bodyHeight: parent.height
            }

            // Swallow clicks so they don't fall through to the window behind.
            MouseArea { anchors.fill: parent }

            Item {
                id: inner
                anchors.fill: parent
                anchors.margins: root.contentMargin
                clip: true
            }
        }
    }
}
