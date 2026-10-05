import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../../config"
import "../../components"
import "../../services" as Svc

// StatusNotifier icons. Left: activate (or menu for menu-only items),
// right: the item's menu, middle: secondary action.
Row {
    id: root

    required property var barWindow
    required property string screenName
    property var menuItem: null
    readonly property var items: SystemTray.items.values
    readonly property bool hasItems: items.length > 0

    visible: Settings.showTray && hasItems
    spacing: 0

    Repeater {
        id: trayRep
        model: root.items

        BarButton {
            id: btn
            required property var modelData

            onClicked: {
                if (modelData.onlyMenu && modelData.hasMenu) openMenu();
                else modelData.activate();
            }
            onRightClicked: if (modelData.hasMenu) openMenu()
            onMiddleClicked: modelData.secondaryActivate()

            active: Svc.Ui.isOpen("traymenu", root.screenName) && root.menuItem === modelData
            function openMenu() {
                // Same item again closes; another item switches the menu over.
                if (Svc.Ui.isOpen("traymenu", root.screenName) && root.menuItem !== modelData) {
                    root.menuItem = modelData;
                    menu.anchorItem = btn;
                    menu._place();
                    return;
                }
                root.menuItem = modelData;
                menu.anchorItem = btn;
                Svc.Ui.toggle("traymenu", root.screenName, modelData.id);
            }

            Image {
                width: Theme.iconSize - 2
                height: width
                sourceSize.width: width
                sourceSize.height: height
                source: btn.modelData.icon
                smooth: false
            }
        }
    }

    TrayMenu {
        id: menu
        screen: root.barWindow.screen
        barWindow: root.barWindow
        screenName: root.screenName
        item: root.menuItem
    }
}
