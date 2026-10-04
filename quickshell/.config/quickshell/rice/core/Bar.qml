import QtQuick
import Quickshell
import "../config"
import "../widgets/Clock" as ClockW
import "../widgets/Window" as WindowW
import "../widgets/Mpris" as MprisW
import "../widgets/Workspaces" as WorkspacesW
import "../widgets/Volume" as VolumeW
import "../widgets/Network" as NetworkW
import "../widgets/Bluetooth" as BluetoothW
import "../widgets/Docker" as DockerW
import "../widgets/System" as SystemW

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
    Component { id: cNetwork;    NetworkW.Bar {} }
    Component { id: cBluetooth;  BluetoothW.Bar {} }
    Component { id: cVolume;     VolumeW.Bar {} }
    Component { id: cDocker;     DockerW.Bar {} }
    Component { id: cSystem;     SystemW.Bar {} }

    readonly property var registry: ({
        "Workspaces": cWorkspaces,
        "Window":     cWindow,
        "Clock":      cClock,
        "Mpris":      cMpris,
        "Network":    cNetwork,
        "Bluetooth":  cBluetooth,
        "Volume":     cVolume,
        "Docker":     cDocker,
        "System":     cSystem
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
