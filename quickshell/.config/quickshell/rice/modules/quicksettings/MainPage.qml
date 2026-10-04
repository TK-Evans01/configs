import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services" as Svc

ColumnLayout {
    id: root
    spacing: Theme.pad

    function shortSink(name) {
        const o = Svc.Audio.outputs.find(x => x.name === name);
        return o ? o.description : name;
    }

    ProfileCard { Layout.fillWidth: true }

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Theme.spacing
        rowSpacing: Theme.spacing

        Tile {
            icon: Svc.Network.connected ? "󰦝" : (Svc.Network.connecting ? "󰒘" : "󰦜")
            label: "Mullvad VPN"
            sublabel: Svc.Network.connected ? (Svc.Network.location || Svc.Network.relay)
                    : (Svc.Network.vpnState || "disconnected").toLowerCase()
            active: Svc.Network.connected
            busy: Svc.Network.connecting
            activeColor: Theme.green
            hasDetails: true
            onToggled: Svc.Network.toggle()
            onOpenDetails: Svc.Ui.showPage("network")
        }
        Tile {
            icon: !Svc.Bluetooth.enabled ? "󰂲" : (Svc.Bluetooth.anyConnected ? "󰂱" : "󰂯")
            label: "Bluetooth"
            sublabel: !Svc.Bluetooth.present ? "no adapter"
                    : !Svc.Bluetooth.enabled ? "off"
                    : Svc.Bluetooth.anyConnected ? Svc.Bluetooth.connectedDevices.map(d => d.name).join(", ")
                    : "on"
            active: Svc.Bluetooth.enabled
            busy: Svc.Bluetooth.busy || Svc.Bluetooth.discovering
            activeColor: Theme.blue
            hasDetails: true
            onToggled: Svc.Bluetooth.togglePower()
            onOpenDetails: Svc.Ui.showPage("bluetooth")
        }
        Tile {
            icon: "󰖔"
            label: "Night light"
            sublabel: Svc.Desktop.nightLight ? Svc.Desktop.nightTemp + "K · " + Svc.Desktop.nightGamma + "%" : "off"
            active: Svc.Desktop.nightLight
            activeColor: Theme.orange
            hasDetails: true
            onToggled: Svc.Desktop.toggleNightLight()
            onOpenDetails: Svc.Ui.showPage("nightlight")
        }
        Tile {
            icon: Svc.Desktop.dnd ? "󰂛" : "󰂚"
            label: "Do not disturb"
            sublabel: Svc.Desktop.dnd ? (Svc.Desktop.waitingCount ? Svc.Desktop.waitingCount + " held" : "on")
                    : Svc.Desktop.historyCount + " in history"
            active: Svc.Desktop.dnd
            activeColor: Theme.purple
            hasDetails: true
            onToggled: Svc.Desktop.toggleDnd()
            onOpenDetails: Svc.Ui.showPage("notifications")
        }
    }

    Card {
        Layout.fillWidth: true
        CardHeader {
            icon: "󰓃"
            title: "Sound"
            subtitle: root.shortSink(Svc.Audio.outDefault)
            IconButton {
                icon: "󰅂"
                onClicked: Svc.Ui.showPage("sound")
            }
        }
        Slider {
            icon: Svc.Audio.outMuted ? "󰝟" : "󰕾"
            value: Svc.Audio.outPercent
            max: 150
            muted: Svc.Audio.outMuted
            onMoved: p => Svc.Audio.setOutputVolume(p)
            onIconClicked: Svc.Audio.toggleMute()
        }
        Slider {
            icon: Svc.Audio.inMuted ? "󰍭" : "󰍬"
            value: Svc.Audio.inPercent
            max: 150
            muted: Svc.Audio.inMuted
            fill: Theme.aqua
            onMoved: p => Svc.Audio.setInputVolume(p)
            onIconClicked: Svc.Audio.toggleInputMute()
        }
    }
}
