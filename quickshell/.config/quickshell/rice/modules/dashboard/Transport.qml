import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services" as Svc

// prev / play / next, plus shuffle + loop when `full`.
RowLayout {
    property bool full: false
    spacing: Theme.spacing

    IconButton {
        visible: parent.full
        icon: "󰒝"
        checked: Svc.Mpris.shuffle
        onClicked: Svc.Mpris.toggleShuffle()
    }
    IconButton { icon: "󰒮"; enabledState: Svc.Mpris.canPrev; onClicked: Svc.Mpris.previous() }
    IconButton {
        icon: Svc.Mpris.playing ? "󰏤" : "󰐊"
        fg: Theme.catMedia
        size: Theme.fontMd + Theme.spacing * 3
        onClicked: Svc.Mpris.togglePlay()
    }
    IconButton { icon: "󰒭"; enabledState: Svc.Mpris.canNext; onClicked: Svc.Mpris.next() }
    IconButton {
        visible: parent.full
        icon: Svc.Mpris.loop === 1 ? "󰑘" : "󰑖"
        checked: Svc.Mpris.loop > 0
        onClicked: Svc.Mpris.cycleLoop()
    }
}
