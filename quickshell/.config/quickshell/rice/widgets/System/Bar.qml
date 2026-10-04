import QtQuick
import "../../core" as Core
import "../../config"
import "../../services" as Svc

Core.Widget {
    id: s

    // nf-md-chip — one icon for the whole machine; numbers live in the popout.
    label: "󰘚"
    labelSize: Theme.iconSize
    labelColor: {
        const hi = Math.max(Svc.Sys.cpuPercent, Svc.Sys.memPercent, Svc.Sys.gpuPercent);
        if (hi >= 90) return Theme.red;
        if (hi >= 75) return Theme.orange;
        return Theme.fg0;
    }

    Core.Popout {
        owner: s
        preferredWidth: 560
        preferredHeight: 150 + Svc.Sys.disks.length * 34
        contentComponent: Component {
            Popout {}
        }
    }
}
