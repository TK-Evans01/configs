import QtQuick
import "../../core" as Core
import "../../config"
import "../../services" as Svc

Core.Widget {
    id: b

    label: {
        if (!Svc.Bluetooth.enabled) return "󰂲";                          // nf-md-bluetooth_off
        if (Svc.Bluetooth.discovering || Svc.Bluetooth.busy) return "󰂳";  // nf-md-bluetooth_settings
        if (Svc.Bluetooth.anyConnected) return "󰂱";                       // nf-md-bluetooth_connect
        return "󰂯";                                                           // nf-md-bluetooth
    }
    labelSize: Theme.iconSize
    labelColor: {
        if (!Svc.Bluetooth.enabled) return Theme.greyDim;
        if (Svc.Bluetooth.discovering || Svc.Bluetooth.busy) return Theme.yellow;
        if (Svc.Bluetooth.anyConnected) return Theme.blue;
        return Theme.fg0;
    }
    onClicked: Svc.Bluetooth.togglePower()
    onRightClicked: Svc.Bluetooth.toggleScan()

    Core.Popout {
        owner: b
        preferredWidth: 560
        preferredHeight: 96 + Math.max(1, Svc.Bluetooth.devices.length) * 24
        contentComponent: Component {
            Popout {}
        }
    }
}
