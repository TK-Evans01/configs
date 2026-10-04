import QtQuick
import "../../core" as Core
import "../../config"
import "../../services" as Svc

Core.Widget {
    id: vol
    label: {
        if (Svc.Audio.muted) return "\uf026";                  // nf-fa-volume_off
        return Svc.Audio.percent >= 50 ? "\uf028" : "\uf027"; // volume_up / volume_down
    }
    labelSize: Theme.iconSize
    labelColor: Svc.Audio.muted ? Theme.red : Theme.fg0
    onClicked: Svc.Audio.toggleMute()

    Core.Popout {
        owner: vol
        preferredWidth: 320
        preferredHeight: 240
        contentComponent: Component {
            Popout { service: Svc.Audio }
        }
    }
}
