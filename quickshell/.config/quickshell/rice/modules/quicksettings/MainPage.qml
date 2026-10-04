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
        Tile {
            icon: Svc.Lock.caffeine ? "󰅶" : "󰛊"
            label: "Caffeine"
            sublabel: Svc.Lock.caffeine ? "staying awake" : "lock after " + Settings.lockAfterMin + " min"
            active: Svc.Lock.caffeine
            activeColor: Theme.yellow
            onToggled: Svc.Lock.caffeine = !Svc.Lock.caffeine
        }
        Tile {
            icon: Svc.Audio.outMuted ? "󰝟" : (Svc.Audio.outPercent >= 66 ? "󰕾" : Svc.Audio.outPercent >= 33 ? "󰖀" : "󰕿")
            label: "Sound"
            sublabel: Svc.Audio.outMuted ? "muted" : Svc.Audio.outPercent + "%  ·  " + root.shortSink(Svc.Audio.outDefault)
            active: !Svc.Audio.outMuted
            activeColor: Theme.aqua
            hasDetails: true
            onToggled: Svc.Audio.toggleMute()
            onOpenDetails: Svc.Ui.showPage("sound")
        }
    }
}
