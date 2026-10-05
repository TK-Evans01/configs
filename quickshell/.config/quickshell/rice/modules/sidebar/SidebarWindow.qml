import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../dashboard"
import "../../services" as Svc

// Right-edge panel: Notifications · Weather · Feeds. Opened by tab
// (`Ui.toggle("sidebar", screen, tab)`); the same tab again closes it.
// Ctrl+Tab cycles tabs, Alt+1…3 jumps.
EdgePanel {
    id: root

    required property string screenName
    readonly property var tabs: [
        { id: "notifications", label: "notifications", icon: "󰂚" },
        { id: "weather", label: "weather", icon: "󰖐" },
        { id: "feeds", label: "feeds", icon: "󰑫" }
    ]
    readonly property string tab: Svc.Ui.page || "notifications"

    wanted: Svc.Ui.isOpen("sidebar", screenName)
    panelWidth: Settings.sidebarWidth
    onDismissed: Svc.Ui.dismiss()

    // The notifications list counts as read while it is on screen.
    Binding {
        target: Svc.Notifications
        property: "panelOpen"
        value: root.wanted && root.tab === "notifications"
    }

    keyTargets: [keys]
    Item {
        id: keys
        Keys.onPressed: e => {
            const ctrl = e.modifiers & Qt.ControlModifier;
            const ids = root.tabs.map(t => t.id);
            const i = ids.indexOf(root.tab);
            if (ctrl && e.key === Qt.Key_Tab) Svc.Ui.page = ids[(i + 1) % ids.length];
            else if (ctrl && e.key === Qt.Key_Backtab) Svc.Ui.page = ids[(i - 1 + ids.length) % ids.length];
            else if ((e.modifiers & Qt.AltModifier) && e.key >= Qt.Key_1 && e.key < Qt.Key_1 + ids.length) Svc.Ui.page = ids[e.key - Qt.Key_1];
            else return;
            e.accepted = true;
        }
    }

    content: ColumnLayout {
        spacing: Theme.pad

        TabBar {
            tabs: root.tabs
            current: root.tab
            onSelected: id => Svc.Ui.page = id
        }

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: root.tab === "weather" ? weather : root.tab === "feeds" ? feeds : notify
        }

        Component { id: notify; NotifyPage {} }
        Component { id: feeds; FeedsPage {} }
        Component {
            id: weather
            Flickable {
                contentHeight: w.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                WeatherTab { id: w; width: parent.width }
            }
        }
    }
}
