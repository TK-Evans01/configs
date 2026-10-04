import QtQuick
import "../../config"
import "../../components"
import "../../services" as Svc

// Now playing. Click: dashboard Media tab (or start ncspot when nothing runs).
// Middle: play/pause. Right: next. Wheel: player volume.
BarButton {
    id: root

    required property string screenName
    readonly property bool has: Svc.Mpris.running
    readonly property string track: {
        if (!has) return "";
        const parts = [];
        if (Svc.Mpris.title) parts.push(Svc.Mpris.title);
        if (Svc.Mpris.artist) parts.push(Svc.Mpris.artist);
        return parts.join(" · ") || Svc.Mpris.identity;
    }

    visible: Settings.showMedia
    active: Svc.Ui.isOpen("dashboard", screenName) && Svc.Ui.tab === "media"
    onClicked: has ? Svc.Ui.toggle("dashboard", screenName, "media") : Svc.Mpris.launch()
    onMiddleClicked: Svc.Mpris.togglePlay()
    onRightClicked: Svc.Mpris.next()
    onWheeled: d => Svc.Mpris.setVolume(Svc.Mpris.volume + (d > 0 ? 0.05 : -0.05))

    Row {
        spacing: Theme.spacing
        Label {
            text: !root.has ? "󰝚" : (Svc.Mpris.playing ? "󰐊" : "󰏤")
            size: Theme.iconSize
            color: !root.has ? Theme.muted : (Svc.Mpris.playing ? Theme.purple : Theme.subtext)
        }
        ScrollingText {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.has
            text: root.track
            pixelSize: Theme.fontSizeSmall + 1
            color: Svc.Mpris.playing ? Theme.purple : Theme.subtext
            maxWidth: Settings.mediaLabelWidth
            scrolling: Svc.Mpris.playing || root.hovered
        }
    }
}
