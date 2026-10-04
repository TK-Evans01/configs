import QtQuick
import "../../config"
import "../../services" as Svc

Item {
    id: root

    readonly property string icoEarth:    "󰇧"   // nf-md-earth
    readonly property string icoEarthOff: "󰆖"   // nf-md-earth-off
    readonly property string icoLock:     "󰦝"   // nf-md-shield-lock
    readonly property string icoShield:   "󰒘"   // nf-md-shield
    readonly property string icoNoShield: "󰦜"   // nf-md-shield-off-outline
    readonly property string icoWifi:     "󰖩"   // nf-md-wifi
    readonly property string icoWifiOff:  "󰖪"   // nf-md-wifi-off
    readonly property string icoEth:      "󰈀"   // nf-md-ethernet
    readonly property string icoUsb:      "󰪛"   // nf-md-usb

    function linkIcon(l) {
        if (l.kind === "wifi") return l.up ? icoWifi : icoWifiOff;
        if (l.kind === "usb") return icoUsb;
        return icoEth;
    }

    function linkColor(l) {
        if (!l.up) return Theme.greyDim;
        return l.uplink ? Theme.green : Theme.blue;
    }

    function linkDetail(l) {
        if (!l.up) return "down";
        const bits = [];
        bits.push(l.uplink ? "uplink" : "LAN only");
        if (l.ip) bits.push(l.ip);
        if (l.extra) bits.push(l.kind === "wifi" ? l.extra : l.extra + "Mb");
        return bits.join(" \u00b7 ");
    }

    Column {
        anchors.fill: parent
        spacing: 2

        Entry {
            width: parent.width
            icon: Svc.Network.online ? root.icoEarth : root.icoEarthOff
            name: "internet"
            accent: Svc.Network.online ? Theme.green : Theme.red
            detail: Svc.Network.online
                    ? ("via " + Svc.Network.gateway + (Svc.Network.vpnIp ? " \u00b7 " + Svc.Network.vpnIp : ""))
                    : (Svc.Network.routed ? "route up, no reply" : "no default route")
        }

        Entry {
            width: parent.width
            icon: Svc.Network.connected ? root.icoLock
                : (Svc.Network.connecting ? root.icoShield : root.icoNoShield)
            name: "vpn"
            accent: Svc.Network.connected ? Theme.green
                  : (Svc.Network.connecting ? Theme.yellow : Theme.red)
            detail: {
                if (Svc.Network.connected)
                    return Svc.Network.relay + (Svc.Network.location ? " \u00b7 " + Svc.Network.location : "");
                return Svc.Network.vpnState || "disconnected";
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.bg3
        }

        Repeater {
            model: Svc.Network.links
            delegate: Entry {
                required property var modelData
                width: root.width
                icon: root.linkIcon(modelData)
                name: modelData.name
                accent: root.linkColor(modelData)
                detail: root.linkDetail(modelData)
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.bg3
        }

        Text {
            text: "click: toggle vpn    ·    right click: reconnect"
            color: Theme.greyDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 4
        }
    }
}
