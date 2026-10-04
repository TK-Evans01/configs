import QtQuick
import "../../core" as Core
import "../../config"
import "../../services" as Svc

Core.Widget {
    id: d
    label: "󰡨"   // nf-md-docker
    labelSize: Theme.iconSize
    labelColor: Svc.Docker.daemonUp ? Theme.blue : Theme.red

    Core.Popout {
        owner: d
        preferredWidth: 420
        preferredHeight: 280
        contentComponent: Component {
            Popout { service: Svc.Docker }
        }
    }
}
