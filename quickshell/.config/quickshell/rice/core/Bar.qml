import QtQuick
import Quickshell
import "../config"
import "../widgets/Clock" as ClockW
import "../widgets/Window" as WindowW
import "../widgets/Mpris" as MprisW
import "../widgets/Workspaces" as WorkspacesW
import "../widgets/Volume" as VolumeW
import "../widgets/Mullvad" as MullvadW
import "../widgets/Cpu" as CpuW
import "../widgets/Memory" as MemoryW
import "../widgets/Docker" as DockerW

PanelWindow {
    id: bar

    required property var screenRef
    screen: screenRef

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: Settings.barHeight
    color: Theme.bg1

    Component { id: cWorkspaces; WorkspacesW.Bar {} }
    Component { id: cWindow;     WindowW.Bar {} }
    Component { id: cClock;      ClockW.Bar {} }
    Component { id: cMpris;      MprisW.Bar {} }
    Component { id: cMullvad;    MullvadW.Bar {} }
    Component { id: cVolume;     VolumeW.Bar {} }
    Component { id: cCpu;        CpuW.Bar {} }
    Component { id: cMemory;     MemoryW.Bar {} }
    Component { id: cDocker;     DockerW.Bar {} }

    readonly property var registry: ({
        "Workspaces": cWorkspaces,
        "Window":     cWindow,
        "Clock":      cClock,
        "Mpris":      cMpris,
        "Mullvad":    cMullvad,
        "Volume":     cVolume,
        "Cpu":        cCpu,
        "Memory":     cMemory,
        "Docker":     cDocker
    })

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Theme.bg3
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: Theme.pad
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.gap
        Repeater {
            model: Settings.leftWidgets
            Loader { sourceComponent: bar.registry[modelData] || null }
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.gap
        Repeater {
            model: Settings.centerWidgets
            Loader { sourceComponent: bar.registry[modelData] || null }
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: Theme.pad
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.gap
        Repeater {
            model: Settings.rightWidgets
            Loader { sourceComponent: bar.registry[modelData] || null }
        }
    }
}
