import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../config"
import "../../components"
import "../../services" as Svc
import "../dashboard"
import "../quicksettings"
import "../launcher"
import "../sidebar"
import "../session"
import "../osd"
import "../wallpaper"

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

    // The bar's outer edge. Popups and side panels cover it where they
    // attach, so bar + panel read as one outlined surface.
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: Theme.outlineWidth
        color: Theme.outline
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

    // Popups and panels exist only while open (and for their closing
    // animation): a closed dashboard / launcher / … costs nothing, on either
    // monitor. `keep` holds one loaded until it has finished hiding.
    component Lazy: LazyLoader {
        id: lz
        required property string popup
        readonly property bool wanted: Svc.Ui.isOpen(popup, bar.screenName)
        // Stay loaded through the closing animation, then free it.
        property bool keep: false
        onWantedChanged: if (!wanted) { keep = true; drop.restart(); }
        property var drop: Timer { interval: Theme.animLong + 200; onTriggered: lz.keep = false }
        active: wanted || keep
    }

    Lazy {
        popup: "dashboard"
        DashboardWindow { screen: bar.screenRef; barWindow: bar; anchorItem: center; screenName: bar.screenName }
    }
    Lazy {
        popup: "launcher"
        LauncherWindow { screen: bar.screenRef; barWindow: bar; anchorItem: launcherButton; screenName: bar.screenName }
    }
    Lazy {
        popup: "quicksettings"
        QuickSettingsWindow { screen: bar.screenRef; barWindow: bar; anchorItem: qsButton; screenName: bar.screenName }
    }
    Lazy {
        popup: "wallpaper"
        WallpaperPicker { screen: bar.screenRef; barWindow: bar; anchorItem: center; screenName: bar.screenName }
    }
    Lazy {
        popup: "sidebar"
        SidebarWindow { screen: bar.screenRef; screenName: bar.screenName }
    }
    Lazy {
        popup: "session"
        SessionWindow { screen: bar.screenRef; screenName: bar.screenName }
    }
    // Toasts: only while there are some, and only on the focused monitor.
    LazyLoader {
        active: Svc.Notifications.toasts.length > 0 && Svc.Hyprland.focusedMonitor !== null
                && Svc.Hyprland.focusedMonitor.name === bar.screenName
        ToastWindow { screenRef: bar.screenRef }
    }

    OsdWindow {
        screenRef: bar.screenRef
    }
}
