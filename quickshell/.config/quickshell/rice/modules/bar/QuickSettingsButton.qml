import QtQuick
import "../../config"
import "../../components"
import "../../services" as Svc

// One button for every status glyph: VPN, network, bluetooth, mic, DND,
// volume. Click: Quick Settings. Middle: mute. Wheel: volume. Right: DND.
BarButton {
    id: root

    required property string screenName

    active: Svc.Ui.isOpen("quicksettings", screenName)
    onClicked: Svc.Ui.toggle("quicksettings", screenName, "")
    onMiddleClicked: Svc.Audio.toggleMute()
    onRightClicked: Svc.Desktop.toggleDnd()
    onWheeled: d => Svc.Audio.setOutputVolume(Svc.Audio.outPercent + (d > 0 ? 5 : -5))

    readonly property var glyphs: {
        const N = Svc.Network, B = Svc.Bluetooth, A = Svc.Audio;
        const out = [];
        // VPN shield: locked = tunnelled, plain = connecting, off = exposed.
        if (N.connected) out.push({ g: "󰦝", c: N.online ? Theme.success : Theme.warning });
        else if (N.connecting) out.push({ g: "󰒘", c: Theme.warning });
        else out.push({ g: "󰦜", c: Theme.error });
        // Uplink type; red when nothing gets out.
        const up = N.links.find(l => l.uplink);
        if (!N.anyLinkUp || !N.online) out.push({ g: "󰲛", c: Theme.error });
        else out.push({ g: up && up.kind === "wifi" ? "󰖩" : "󰈀", c: Theme.text });
        if (B.enabled) {
            if (B.busy || B.discovering) out.push({ g: "󰂳", c: Theme.warning });
            else if (B.anyConnected) out.push({ g: "󰂱", c: Theme.info });
        }
        if (A.inMuted) out.push({ g: "󰍭", c: Theme.warning });
        if (Svc.Desktop.dnd) out.push({ g: "󰂛", c: Theme.warning });
        if (Svc.Lock.caffeine) out.push({ g: "󰅶", c: Theme.yellow });
        if (A.outMuted) out.push({ g: "󰝟", c: Theme.error });
        else out.push({ g: A.outPercent >= 66 ? "󰕾" : (A.outPercent >= 33 ? "󰖀" : "󰕿"), c: Theme.text });
        return out;
    }

    Row {
        spacing: Theme.spacing + 2
        Repeater {
            model: root.glyphs
            Label {
                required property var modelData
                text: modelData.g
                size: Theme.iconSize
                color: root.active && modelData.c === Theme.text ? Theme.accent : modelData.c
            }
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: Svc.Audio.outPercent
            size: Theme.fontSizeSmall
            color: Svc.Audio.outMuted ? Theme.muted : Theme.subtext
        }
    }
}
