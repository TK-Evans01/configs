import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services" as Svc

ColumnLayout {
    id: page
    spacing: Theme.pad
    readonly property var net: Svc.Network

    function linkIcon(l) {
        if (l.kind === "wifi") return l.up ? "󰖩" : "󰖪";
        if (l.kind === "usb") return "󰕓";
        return "󰈀";
    }

    PageHeader {
        icon: "󰛳"
        title: "Network"
        subtitle: page.net.online ? "online via " + page.net.gateway : (page.net.routed ? "route up, no reply" : "no default route")
        onBackClicked: Svc.Ui.back()
    }

    Card {
        Layout.fillWidth: true
        CardHeader {
            icon: page.net.connected ? "󰦝" : (page.net.connecting ? "󰒘" : "󰦜")
            title: "Mullvad"
            subtitle: (page.net.vpnState || "unknown").toLowerCase()
            accent: page.net.connected ? Theme.green : (page.net.connecting ? Theme.yellow : Theme.red)
            Switch {
                checked: page.net.connected || page.net.connecting
                onToggled: page.net.toggle()
            }
        }
        DeviceRow {
            visible: page.net.relay !== ""
            clickable: false
            icon: "󰒍"
            title: page.net.relay
            subtitle: "relay"
        }
        DeviceRow {
            visible: page.net.location !== ""
            clickable: false
            icon: "󰍎"
            title: page.net.location
            subtitle: page.net.vpnIp ? "exit · " + page.net.vpnIp : "visible location"
        }
        IconButton {
            Layout.alignment: Qt.AlignRight
            icon: "󰑓"
            text: "reconnect"
            enabledState: page.net.connected || page.net.connecting
            onClicked: page.net.reconnect()
        }
    }

    Card {
        Layout.fillWidth: true
        CardHeader {
            icon: page.net.online ? "󰇧" : "󰆖"
            title: "Links"
            subtitle: page.net.links.length + (page.net.links.length === 1 ? " interface" : " interfaces")
            accent: page.net.online ? Theme.green : Theme.red
        }
        Repeater {
            model: page.net.links
            DeviceRow {
                required property var modelData
                clickable: false
                active: modelData.uplink
                icon: page.linkIcon(modelData)
                accent: modelData.up ? Theme.text : Theme.muted
                title: modelData.name
                subtitle: !modelData.up ? "down"
                        : [modelData.uplink ? "uplink" : "lan only", modelData.ip,
                           modelData.extra ? (modelData.kind === "wifi" ? modelData.extra : modelData.extra + " Mb/s") : ""]
                          .filter(x => x).join("  ·  ")
            }
        }
    }
}
