import QtQuick
import "../../core" as Core
import "../../config"
import "../../services" as Svc

Core.Widget {
    id: m
    label: {
        if (Svc.Mullvad.connected) return "\uf023  " + Svc.Mullvad.relay;
        if (Svc.Mullvad.connecting) return "\uf023  …";
        return "\uf13e  off";
    }
    labelColor: Svc.Mullvad.connected ? Theme.green : (Svc.Mullvad.connecting ? Theme.yellow : Theme.red)

    Core.Popout {
        owner: m
        preferredWidth: 280
        preferredHeight: 150
        contentComponent: Component {
            Popout { service: Svc.Mullvad }
        }
    }
}
