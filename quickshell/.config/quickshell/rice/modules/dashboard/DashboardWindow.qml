import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services" as Svc

// Tabbed dashboard under the bar's center island. Tabs slide sideways and the
// panel follows the current tab's height. Ctrl+Tab / Ctrl+Shift+Tab cycle,
// Alt+1…N jump (one per tab in Settings.dashboardTabs).
BarPopup {
    id: root

    required property string screenName
    readonly property var tabs: Settings.dashboardTabs
    readonly property int tabIndex: Math.max(0, tabs.findIndex(t => t.id === Svc.Ui.tab))
    // The tab sliding out stays loaded for the slide, then is dropped.
    property int prevIndex: -1
    onTabIndexChanged: { prevIndex = _shown; _shown = tabIndex; dropPrev.restart(); }
    property int _shown: tabIndex
    Timer { id: dropPrev; interval: Theme.animLong + 50; onTriggered: root.prevIndex = -1 }

    wanted: Svc.Ui.isOpen("dashboard", screenName)
    popupWidth: Settings.dashboardWidth
    contentHeight: tabBar.implicitHeight + Theme.pad + pages.currentHeight
    keyTargets: [keys]
    onDismissed: Svc.Ui.dismiss()

    Item {
        id: keys
        Keys.onPressed: e => {
            const ctrl = e.modifiers & Qt.ControlModifier;
            if (ctrl && (e.key === Qt.Key_Tab || e.key === Qt.Key_PageDown)) Svc.Ui.cycleTab(1);
            else if (ctrl && (e.key === Qt.Key_Backtab || e.key === Qt.Key_PageUp)) Svc.Ui.cycleTab(-1);
            else if ((e.modifiers & Qt.AltModifier) && e.key >= Qt.Key_1 && e.key < Qt.Key_1 + root.tabs.length)
                Svc.Ui.tab = root.tabs[e.key - Qt.Key_1].id;
            else return;
            e.accepted = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.pad

        TabBar {
            id: tabBar
            tabs: root.tabs
            current: Svc.Ui.tab
            onSelected: id => Svc.Ui.tab = id
        }

        Item {
            id: pages
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            readonly property real currentHeight: {
                rep.count;
                const l = rep.itemAt(root.tabIndex);
                return l && l.item ? l.item.implicitHeight : 0;
            }

            Row {
                x: -root.tabIndex * pages.width
                Behavior on x {
                    enabled: root.shownState
                    NumberAnimation { duration: Theme.animLong; easing.type: Easing.OutExpo }
                }

                Repeater {
                    id: rep
                    model: root.tabs
                    Loader {
                        required property var modelData
                        required property int index
                        width: pages.width
                        // Only the shown tab (and the one sliding out) is built.
                        active: root.visible && (index === root.tabIndex || index === root.prevIndex)
                        sourceComponent: ({
                            overview: overviewC,
                            media: mediaC,
                            system: systemC,
                            weather: weatherC,
                            github: githubC,
                            docker: dockerC
                        })[modelData.id] || null
                    }
                }
            }
        }
    }

    readonly property bool onTab: shownState
    Component { id: overviewC; OverviewTab { screenName: root.screenName } }
    Component { id: mediaC; MediaTab { shownTab: root.onTab && Svc.Ui.tab === "media" } }
    Component { id: systemC; SystemTab {} }
    Component { id: weatherC; WeatherTab {} }
    Component { id: githubC; GithubTab {} }
    Component { id: dockerC; DockerTab {} }
}
