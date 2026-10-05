import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services" as Svc

// Settings › Wallpaper: library status and quick actions; the picker is
// where you browse and tag (SUPER+SHIFT+W).
Card {
    id: root
    Layout.fillWidth: true
    readonly property int untagged: Svc.Wallpaper.ranked.filter(r => !r.reviewed).length
    CardHeader {
        icon: "󰋩"
        title: Svc.Wallpaper.ranked.length + " wallpapers"
        subtitle: Svc.Wallpaper.suggested.length + " suit " + Theme.themeId + " in " + Svc.Wallpaper.season
        Spinner { visible: Svc.Wallpaper.indexing }
        IconButton { icon: "󰑓"; text: "re-index"; onClicked: Svc.Wallpaper.reindex() }
    }
    RowLayout {
        spacing: Theme.spacing
        IconButton { icon: "󰋩"; text: "open picker"; checked: true; onClicked: { Svc.Ui.toggle("wallpaper", Svc.Hyprland.focusedMonitor ? Svc.Hyprland.focusedMonitor.name : "", ""); } }
        IconButton { icon: "󰒭"; text: "next now"; onClicked: Svc.Wallpaper.next("all") }
    }
    Label {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        size: Theme.fontSm
        color: Theme.subtext
        text: (root.untagged ? root.untagged + " still carry suggested tags (from their colours) — confirm or change them in the picker. " : "")
            + "Your tags live in rice/data/wallpapers.json (in git); thumbnails and colour data in ~/.cache/rice/wallpapers (rebuilt any time)."
    }
    Label {
        visible: Svc.Wallpaper.error !== ""
        text: Svc.Wallpaper.error
        color: Theme.error
        size: Theme.fontSm
    }
}
