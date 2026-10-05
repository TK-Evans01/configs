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
            activeColor: Theme.catNet
            sublabel: Svc.Network.connected ? (Svc.Network.location || Svc.Network.relay)
                    : (Svc.Network.vpnState || "disconnected").toLowerCase()
            active: Svc.Network.connected
            busy: Svc.Network.connecting
            hasDetails: true
            onToggled: Svc.Network.toggle()
            onOpenDetails: Svc.Ui.showPage("network")
        }
        Tile {
            icon: !Svc.Bluetooth.enabled ? "󰂲" : (Svc.Bluetooth.anyConnected ? "󰂱" : "󰂯")
            label: "Bluetooth"
            activeColor: Theme.catSystem
            sublabel: !Svc.Bluetooth.present ? "no adapter"
                    : !Svc.Bluetooth.enabled ? "off"
                    : Svc.Bluetooth.anyConnected ? Svc.Bluetooth.connectedDevices.map(d => d.name).join(", ")
                    : "on"
            active: Svc.Bluetooth.enabled
            busy: Svc.Bluetooth.busy || Svc.Bluetooth.discovering
            hasDetails: true
            onToggled: Svc.Bluetooth.togglePower()
            onOpenDetails: Svc.Ui.showPage("bluetooth")
        }
        Tile {
            icon: "󰖔"
            label: "Night light"
            activeColor: Theme.orange
            sublabel: Svc.Desktop.nightLight ? Svc.Desktop.nightTemp + "K · " + Svc.Desktop.nightGamma + "%" : "off"
            active: Svc.Desktop.nightLight
            hasDetails: true
            onToggled: Svc.Desktop.toggleNightLight()
            onOpenDetails: Svc.Ui.showPage("nightlight")
        }
        Tile {
            icon: Svc.Notifications.dnd ? "󰂛" : "󰂚"
            label: "Do not disturb"
            activeColor: Theme.catNotify
            sublabel: Svc.Notifications.unread ? Svc.Notifications.unread + " new" : (Svc.Notifications.dnd ? "on" : "off")
            active: Svc.Notifications.dnd
            hasDetails: true
            onToggled: Svc.Notifications.toggleDnd()
            onOpenDetails: Svc.Ui.toggle("sidebar", Svc.Ui.screen, "notifications")
        }
        Tile {
            icon: Svc.Focus.active ? "󰌾" : "󰔟"
            label: "Focus"
            activeColor: Theme.catTime
            sublabel: Svc.Focus.active ? (Svc.Focus.focusing ? "" : "break · ") + Svc.Focus.remainingText + " left"
                    : (Settings.focusProfiles.find(p => p.id === Settings.focusDefault) || { label: "off" }).label
            active: Svc.Focus.active
            hasDetails: true
            // Running sessions can't be stopped: the tile then just shows the page.
            onToggled: Svc.Focus.active ? Svc.Ui.showPage("focus") : Svc.Focus.start("", 0)
            onOpenDetails: Svc.Ui.showPage("focus")
        }
        Tile {
            icon: Svc.Lock.caffeine ? "󰅶" : "󰛊"
            label: "Caffeine"
            activeColor: Theme.accent
            sublabel: Svc.Lock.caffeine ? "staying awake" : "lock after " + Settings.lockAfterMin + " min"
            active: Svc.Lock.caffeine
            onToggled: Svc.Lock.caffeine = !Svc.Lock.caffeine
        }
        Tile {
            icon: Svc.Audio.outMuted ? "󰝟" : (Svc.Audio.outPercent >= 66 ? "󰕾" : Svc.Audio.outPercent >= 33 ? "󰖀" : "󰕿")
            label: "Sound"
            activeColor: Theme.catMedia
            sublabel: Svc.Audio.outMuted ? "muted" : Svc.Audio.outPercent + "%  ·  " + root.shortSink(Svc.Audio.outDefault)
            active: !Svc.Audio.outMuted
            hasDetails: true
            onToggled: Svc.Audio.toggleMute()
            onOpenDetails: Svc.Ui.showPage("sound")
        }
    }
}
