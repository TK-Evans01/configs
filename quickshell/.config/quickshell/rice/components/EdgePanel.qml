import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../config"

// Full-height panel on a screen edge, under the bar. Square: a clipped
// wipe from the edge while the content stays still (hairline on the moving
// edge). Round: the panel slides in. Only the visible part takes input; a
// click outside or Escape → `dismissed`. Content loads while open (and for
// the closing animation) unless `keepLoaded`.
PanelWindow {
    id: root

    property string edge: "right"          // "right" | "left"
    property bool wanted: false
    property int panelWidth: 460
    property bool keepLoaded: false
    property Component content: null
    property list<Item> keyTargets
    property Item initialFocus: null
    readonly property Item contentItem: loader.item
    signal dismissed()
    property real _grabbedAt: 0

    WlrLayershell.namespace: "rice-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: wanted ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: false

    anchors {
        top: true
        bottom: true
        right: edge === "right"
        left: edge === "left"
    }
    margins.top: Settings.barHeight - Theme.outlineWidth
    implicitWidth: panelWidth + Theme.joinRadius
    mask: Region { item: panel }

    // 0 = hidden, 1 = fully shown. The animation's duration scales with the
    // distance left, so an interrupted open/close never snaps.
    property real progress: 0
    NumberAnimation on progress {
        id: anim
        running: false
        easing.type: Theme.easing
    }
    function _animateTo(v) {
        anim.stop();
        anim.from = progress;
        anim.to = v;
        anim.duration = Math.max(1, Math.abs(v - progress) * (v > 0 ? Theme.animLong : Theme.anim));
        anim.start();
    }

    // Bar.qml creates panels lazily, already wanted: open on creation too.
    Component.onCompleted: if (wanted) _sync()
    onWantedChanged: _sync()
    function _sync() {
        if (wanted) {
            visible = true;
            _animateTo(1);
            grabTimer.restart();
        } else {
            grab.active = false;
            _animateTo(0);
            if (progress === 0) visible = false;   // closed before it moved
        }
    }
    onProgressChanged: if (progress === 0 && !wanted) visible = false

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

    // Round shape: inverted corners on the inner side join the panel to the
    // bar (top) and the screen edge (bottom), so they read as one surface.
    readonly property int ear: Theme.joinRadius
    readonly property bool _right: edge === "right"

    // Visible part of the panel, growing from the edge.
    Item {
        id: clipper
        readonly property real shown: Math.round(root.panelWidth * root.progress)
        x: Theme.round ? 0 : (root._right ? root.width - shown : 0)
        y: 0
        width: Theme.round ? root.width : shown
        height: root.height
        clip: true

        Item {
            id: panel
            // Square: fixed in place (the clipper wipes over it).
            // Round: the whole panel (with its joins) slides with `progress`.
            x: Theme.round
                ? (root._right ? root.ear + root.panelWidth * (1 - root.progress) : -root.panelWidth * (1 - root.progress))
                : (root._right ? clipper.width - root.panelWidth : 0)
            width: root.panelWidth
            height: parent.height

            PanelShape {
                x: root._right ? -root.ear : 0
                attach: root.edge
                ear: root.ear
                bodyWidth: root.panelWidth
                bodyHeight: parent.height
            }

            // Swallow clicks so they don't fall through.
            MouseArea { anchors.fill: parent }

            Loader {
                id: loader
                anchors.fill: parent
                anchors.margins: Theme.pad + 4
                active: root.wanted || root.visible || root.keepLoaded
                sourceComponent: root.content
            }
        }

        // The moving edge (square wipe).
        Rectangle {
            visible: !Theme.round && root.progress > 0 && root.progress < 1
            x: root.edge === "right" ? 0 : parent.width - width
            width: Theme.accentThickness
            height: parent.height
            color: Theme.accent
        }
    }
}
