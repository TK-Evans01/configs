import QtQuick
import "../../core" as Core
import "../../config"
import "../../services" as Svc

Core.Widget {
    id: m
    readonly property string joined: {
        if (!Svc.Mpris.running) return "";
        const parts = [];
        if (Svc.Mpris.artist) parts.push(Svc.Mpris.artist);
        if (Svc.Mpris.title) parts.push(Svc.Mpris.title);
        return parts.join(" — ");
    }
    labelPrefix: {
        if (!Svc.Mpris.running) return "\uf001";
        return Svc.Mpris.playing ? "\uf04b" : "\uf04c";
    }
    label: {
        if (!Svc.Mpris.running) return "ncspot";
        return joined || "…";
    }
    maxLabelWidth: Settings.mprisLabelWidth
    labelColor: Svc.Mpris.running ? Theme.purple : Theme.grey
    onClicked: Svc.Mpris.launch()

    Core.Popout {
        owner: m
        preferredWidth: 360
        preferredHeight: 220
        contentComponent: Svc.Mpris.running ? popoutComp : null

        Component {
            id: popoutComp
            Popout { service: Svc.Mpris }
        }
    }
}
