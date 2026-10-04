import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth as QsBt
import "../../config"
import "../../components"
import "../../services" as Svc

ColumnLayout {
    id: page
    spacing: Theme.pad
    readonly property var bt: Svc.Bluetooth

    // BlueZ hands back freedesktop icon names.
    function deviceIcon(d) {
        const i = d.icon || "";
        if (i.startsWith("audio-head")) return "󰋋";
        if (i.startsWith("audio")) return "󰓃";
        if (i === "input-gaming") return "󰊗";
        if (i === "input-keyboard") return "󰌌";
        if (i === "input-mouse" || i === "input-tablet") return "󰍽";
        if (i === "phone") return "󰄜";
        return "󰂯";
    }
    function deviceDetail(d) {
        if (d.pairing) return "pairing…";
        const bits = [];
        if (d.state === QsBt.BluetoothDeviceState.Connecting) bits.push("connecting…");
        else if (d.state === QsBt.BluetoothDeviceState.Disconnecting) bits.push("disconnecting…");
        else if (d.connected) bits.push("connected");
        else bits.push(d.paired ? "paired" : "new · click to pair");
        if (d.batteryAvailable) bits.push(Math.round(d.battery * 100) + "%");
        return bits.join("  ·  ");
    }

    PageHeader {
        icon: page.bt.enabled ? "󰂯" : "󰂲"
        title: "Bluetooth"
        subtitle: !page.bt.present ? "no adapter" : page.bt.adapter.name
        onBackClicked: Svc.Ui.back()
        Switch {
            checked: page.bt.enabled
            onToggled: page.bt.togglePower()
        }
    }

    Card {
        Layout.fillWidth: true
        CardHeader {
            icon: "󰂳"
            title: "Devices"
            subtitle: page.bt.discovering ? "scanning · put the device in pairing mode" : page.bt.devices.length + " known"
            accent: page.bt.discovering ? Theme.yellow : Theme.blue
            IconButton {
                icon: "󰑓"
                text: page.bt.discovering ? "stop" : "scan"
                checked: page.bt.discovering
                enabledState: page.bt.present
                onClicked: page.bt.toggleScan()
            }
        }
        Label {
            visible: page.bt.devices.length === 0
            text: page.bt.enabled ? "no devices" : "bluetooth is off"
            size: Theme.fontSizeSmall
            color: Theme.muted
        }
        Repeater {
            model: page.bt.devices
            DeviceRow {
                id: devRow
                required property var modelData
                icon: page.deviceIcon(modelData)
                // Nameless scan hits: "audio-headset" -> "headset".
                title: modelData.deviceName !== "" || modelData.paired ? modelData.name : modelData.icon.split("-").pop()
                subtitle: page.deviceDetail(modelData)
                active: modelData.connected
                accent: modelData.paired ? Theme.text : Theme.subtext
                onClicked: page.bt.activate(modelData)

                IconButton {
                    visible: devRow.modelData.paired && devRow.hovered
                    icon: "󰆴"
                    fg: Theme.red
                    onClicked: page.bt.forget(devRow.modelData)
                }
            }
        }
    }
}
