import QtQuick
import Quickshell.Bluetooth as QsBt
import "../../config"
import "../../services" as Svc
import "../Network" as NetW

Item {
    id: root

    readonly property string icoBt:       "󰂯"       // nf-md-bluetooth
    readonly property string icoBtOff:    "󰂲"   // nf-md-bluetooth_off
    readonly property string icoScan:     "󰂳"   // nf-md-bluetooth_settings
    readonly property string icoHeadset:  "󰋋"     // nf-md-headphones
    readonly property string icoSpeaker:  "󰓃"      // nf-md-speaker
    readonly property string icoKeyboard: "󰌌"      // nf-md-keyboard
    readonly property string icoMouse:    "󰍽"    // nf-md-mouse
    readonly property string icoPad:      "󰊗"      // nf-md-gamepad_variant
    readonly property string icoPhone:    "󰄜"    // nf-md-cellphone

    // BlueZ hands back freedesktop icon names.
    function deviceIcon(d) {
        const i = d.icon || "";
        if (i.startsWith("audio-head")) return icoHeadset;
        if (i.startsWith("audio")) return icoSpeaker;
        if (i === "input-gaming") return icoPad;
        if (i === "input-keyboard") return icoKeyboard;
        if (i === "input-mouse" || i === "input-tablet") return icoMouse;
        if (i === "phone") return icoPhone;
        return icoBt;
    }

    function deviceColor(d) {
        if (d.connected) return Theme.blue;
        if (d.pairing || d.state === QsBt.BluetoothDeviceState.Connecting) return Theme.yellow;
        return d.paired ? Theme.fg0 : Theme.grey;
    }

    function deviceDetail(d) {
        if (d.pairing) return "pairing…";
        const bits = [];
        if (d.state === QsBt.BluetoothDeviceState.Connecting) bits.push("connecting…");
        else if (d.state === QsBt.BluetoothDeviceState.Disconnecting) bits.push("disconnecting…");
        else if (d.connected) bits.push("connected");
        else bits.push(d.paired ? "paired" : "new · click to pair");
        if (d.batteryAvailable) bits.push(Math.round(d.battery * 100) + "%");
        bits.push(d.address);
        return bits.join(" · ");
    }

    // Clickable wrapper around the network popout's row.
    component ClickRow: Rectangle {
        id: row
        property alias icon: entry.icon
        property alias name: entry.name
        property alias detail: entry.detail
        property alias accent: entry.accent
        signal activated()

        implicitHeight: entry.implicitHeight
        color: rowHover.hovered ? Theme.bg3 : "transparent"

        NetW.Entry {
            id: entry
            anchors.fill: parent
        }
        HoverHandler { id: rowHover }
        TapHandler { onTapped: row.activated() }
    }

    Column {
        anchors.fill: parent
        spacing: 2

        ClickRow {
            width: parent.width
            icon: Svc.Bluetooth.enabled ? root.icoBt : root.icoBtOff
            name: "power"
            accent: Svc.Bluetooth.enabled ? Theme.green : Theme.red
            detail: {
                if (!Svc.Bluetooth.present) return "no adapter";
                const n = Svc.Bluetooth.connectedDevices.length;
                return (Svc.Bluetooth.enabled ? "on" : "off")
                     + (n ? " · " + n + " connected" : "")
                     + " · " + Svc.Bluetooth.adapter.name;
            }
            onActivated: Svc.Bluetooth.togglePower()
        }

        ClickRow {
            width: parent.width
            icon: root.icoScan
            name: "scan"
            accent: Svc.Bluetooth.discovering ? Theme.yellow : Theme.grey
            detail: Svc.Bluetooth.discovering
                    ? "searching · put device in pairing mode"
                    : "click to find new devices"
            onActivated: Svc.Bluetooth.toggleScan()
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.bg3
        }

        Text {
            visible: Svc.Bluetooth.devices.length === 0
            height: 22
            verticalAlignment: Text.AlignVCenter
            text: "no devices"
            color: Theme.greyDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 3
        }

        Repeater {
            model: Svc.Bluetooth.devices
            delegate: ClickRow {
                required property var modelData
                width: root.width
                icon: root.deviceIcon(modelData)
                // Nameless scan hits: "audio-headset" -> "headset".
                name: modelData.deviceName !== "" || modelData.paired
                      ? modelData.name
                      : modelData.icon.split("-").pop()
                accent: root.deviceColor(modelData)
                detail: root.deviceDetail(modelData)
                onActivated: Svc.Bluetooth.activate(modelData)
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.bg3
        }

        Text {
            text: "click: power    ·    right click: scan    ·    row: connect / pair"
            color: Theme.greyDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 4
        }
    }
}
