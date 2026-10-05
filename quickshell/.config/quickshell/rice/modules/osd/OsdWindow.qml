import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../config"
import "../../components"
import "../../services" as Svc

// Volume OSD under the bar's centre, on the focused monitor. Appears when
// volume / mute changes (keys, wheel, other apps) — not at startup, not
// right after the output device switches, not while a popup is open.
PanelWindow {
    id: root

    required property var screenRef
    screen: screenRef
    readonly property bool focusedHere: {
        const m = Svc.Hyprland.focusedMonitor;
        return m !== null && screenRef !== null && m.name === screenRef.name;
    }

    WlrLayershell.namespace: "rice-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    anchors.top: true
    // Round: hangs from the bar like a popup (inverted corners). Square: a
    // separate card a little below it.
    margins.top: Theme.round ? Settings.barHeight - Theme.outlineWidth : Settings.barHeight + 10
    implicitWidth: 320 + Theme.joinRadius * 2
    implicitHeight: box.implicitHeight
    color: "transparent"
    mask: Region {}
    visible: focusedHere && showing && Svc.Ui.open === ""

    property bool showing: false
    property bool armed: false
    Timer { interval: 2000; running: true; onTriggered: root.armed = true }
    // Device switches report a new volume; don't flash for those.
    Connections {
        target: Svc.Audio
        function onOutDefaultChanged() { root.armed = false; rearm.restart(); }
        function onOutPercentChanged() { root.poke(); }
        function onOutMutedChanged() { root.poke(); }
    }
    Timer { id: rearm; interval: 2000; onTriggered: root.armed = true }
    Timer { id: hide; interval: 1500; onTriggered: root.showing = false }
    function poke() {
        if (!armed) return;
        showing = true;
        hide.restart();
    }

    Item {
        id: box
        x: Theme.joinRadius
        width: 320
        implicitHeight: row.implicitHeight + Theme.pad * 2
        height: implicitHeight

        // Round: hangs from the bar (joins + outline). Square: a separate card.
        PanelShape {
            visible: Theme.round
            x: -Theme.joinRadius
            attach: "top"
            bodyWidth: parent.width
            bodyHeight: parent.height
        }
        Rectangle {
            visible: !Theme.round
            anchors.fill: parent
            color: Theme.background
            border.width: Theme.outlineWidth
            border.color: Theme.outline
        }

        RowLayout {
            id: row
            anchors.fill: parent
            anchors.margins: Theme.pad
            spacing: Theme.pad
            Label {
                text: Svc.Audio.outMuted ? "󰝟" : Svc.Audio.outPercent > 66 ? "󰕾" : Svc.Audio.outPercent > 33 ? "󰖀" : "󰕿"
                size: Theme.fontLg
                color: Svc.Audio.outMuted ? Theme.error : Theme.catMedia
            }
            Meter {
                Layout.fillWidth: true
                percent: Svc.Audio.outMuted ? 0 : Math.min(100, Svc.Audio.outPercent)
                accent: Theme.catMedia
                segments: 20
                showLabel: false
                usage: false
            }
            Label {
                Layout.preferredWidth: Theme.fontBase * 3
                horizontalAlignment: Text.AlignRight
                text: Svc.Audio.outMuted ? "mute" : Svc.Audio.outPercent + "%"
                size: Theme.fontBase
                color: Theme.subtext
            }
        }
    }
}
