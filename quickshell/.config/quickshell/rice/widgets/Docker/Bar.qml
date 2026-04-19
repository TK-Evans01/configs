import QtQuick
import "../../core" as Core
import "../../config"
import "../../services" as Svc

Core.Widget {
    id: d
    label: {
        if (!Svc.Docker.daemonUp) return "\uf395  off";
        return "\uf395  " + Svc.Docker.running + "/" + Svc.Docker.total;
    }
    labelColor: {
        if (!Svc.Docker.daemonUp) return Theme.red;
        if (Svc.Docker.total === 0) return Theme.grey;
        return Svc.Docker.running === Svc.Docker.total ? Theme.blue : Theme.yellow;
    }

    Core.Popout {
        owner: d
        preferredWidth: 420
        preferredHeight: 280
        contentComponent: Component {
            Popout { service: Svc.Docker }
        }
    }
}
