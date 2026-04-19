import QtQuick
import "../../core" as Core
import "../../config"
import "../../services" as Svc

Core.Widget {
    id: vol
    label: Svc.Audio.muted ? "muted \uf026" : (Svc.Audio.percent + "% \uf028")
    labelColor: Svc.Audio.muted ? Theme.red : Theme.fg0

    Core.Popout {
        owner: vol
        preferredWidth: 320
        preferredHeight: 240
        contentComponent: Component {
            Popout { service: Svc.Audio }
        }
    }
}
