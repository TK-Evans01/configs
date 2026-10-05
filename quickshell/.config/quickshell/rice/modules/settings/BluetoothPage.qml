import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../quicksettings" as QS
import "../../services" as Svc

ColumnLayout {
    spacing: Theme.pad
    Card {
        Layout.fillWidth: true
        SettingRow {
            label: "Bluetooth"
            help: !Svc.Bluetooth.present ? "no adapter" : Svc.Bluetooth.adapter.name
            Switch {
                checked: Svc.Bluetooth.enabled
                onToggled: Svc.Bluetooth.togglePower()
            }
        }
    }
    QS.BluetoothPage { Layout.fillWidth: true; embedded: true }
}
