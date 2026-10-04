import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../config"
import "../../components"
import "../dashboard"
import "../quicksettings"
import "../launcher"

// One per screen. Docked, square, hairline bottom border.
//   left:   launcher (→ Launcher) · workspaces │ window
//   center: clock · media · system · weather → Dashboard (tabs)
//   right:  tray │ mail · quick-settings glyphs → Quick Settings
PanelWindow {
    id: bar

    required property var screenRef
    readonly property string screenName: screenRef ? screenRef.name : ""
    screen: screenRef

    WlrLayershell.namespace: "rice-bar"
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Settings.barHeight
    color: Theme.background

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: Theme.border
        color: Theme.surface2
    }

    // --- left ---
    Row {
        anchors.left: parent.left
        anchors.top: parent.top
        spacing: 0

        LauncherButton {
            id: launcherButton
            screenName: bar.screenName
        }
        Workspaces {
            screenRef: bar.screenRef
        }
        BarDivider {
            anchors.verticalCenter: parent.verticalCenter
            visible: win.visible
        }
        Item { width: Theme.pad; height: 1; visible: win.visible }
        ActiveWindow {
            id: win
        }
    }

    // --- center ---
    Row {
        id: center
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        spacing: 0

        ClockButton { screenName: bar.screenName }
        MediaButton { screenName: bar.screenName }
        SystemButton { screenName: bar.screenName }
        WeatherButton { screenName: bar.screenName }
    }

    // --- right ---
    Row {
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 0

        Tray {
            id: tray
            barWindow: bar
            screenName: bar.screenName
        }
        BarDivider {
            anchors.verticalCenter: parent.verticalCenter
            visible: tray.visible
        }
        MailButton {
            screenName: bar.screenName
        }
        QuickSettingsButton {
            id: qsButton
            screenName: bar.screenName
        }
    }

    DashboardWindow {
        screen: bar.screenRef
        barWindow: bar
        anchorItem: center
        screenName: bar.screenName
    }

    LauncherWindow {
        screen: bar.screenRef
        barWindow: bar
        anchorItem: launcherButton
        screenName: bar.screenName
    }

    QuickSettingsWindow {
        screen: bar.screenRef
        barWindow: bar
        anchorItem: qsButton
        screenName: bar.screenName
    }
}
