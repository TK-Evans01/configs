import QtQuick
import "../../core" as Core
import "../../config"
import "../../services" as Svc

Core.Widget {
    id: n

    // Shield set: locked = tunnelled, plain = connecting, off = exposed,
    // network-off = no link at all.
    label: {
        if (!Svc.Network.anyLinkUp) return "󰲛";   // nf-md-network-off
        if (Svc.Network.connected) return "󰦝";    // nf-md-shield-lock
        if (Svc.Network.connecting) return "󰒘";   // nf-md-shield
        return "󰦜";                               // nf-md-shield-off-outline
    }
    labelSize: Theme.iconSize
    labelColor: {
        if (!Svc.Network.anyLinkUp) return Theme.greyDim;
        if (Svc.Network.connected) return Svc.Network.online ? Theme.green : Theme.yellow;
        if (Svc.Network.connecting) return Theme.yellow;
        return Theme.red;
    }
    onClicked: Svc.Network.toggle()
    onRightClicked: Svc.Network.reconnect()

    Core.Popout {
        owner: n
        preferredWidth: 560
        preferredHeight: 108 + Svc.Network.links.length * 22
        contentComponent: Component {
            Popout {}
        }
    }
}
