import QtQuick
import "../../core"
import "../../config"
import "../../services" as Svc

Widget {
    id: win
    readonly property var t: Svc.Hyprland.activeToplevel
    label: {
        if (!t) return "";
        const s = t.title || "";
        return s.length > 50 ? s.substring(0, 50) + "…" : s;
    }
    labelColor: Theme.grey
}
