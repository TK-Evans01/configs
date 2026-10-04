import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services" as Svc

Card {
    id: card
    readonly property var rootDisk: Svc.Sys.disks.find(d => d.target === "/") || null

    CardHeader {
        icon: "󰍛"
        title: "Resources"
        subtitle: Svc.Sys.loadAvg ? "load " + Svc.Sys.loadAvg : ""
        accent: Theme.info
    }
    Meter {
        name: "CPU"
        percent: Svc.Sys.cpuPercent
        detail: Svc.Sys.cpuTemp > 0 ? Math.round(Svc.Sys.cpuTemp) + "°C" : ""
        accent: Theme.blue
    }
    Meter {
        visible: Svc.Sys.gpuModel !== "" || Svc.Sys.gpuVramTotal > 0
        name: "GPU"
        percent: Svc.Sys.gpuPercent
        detail: Svc.Sys.gpuTemp > 0 ? Math.round(Svc.Sys.gpuTemp) + "°C" : ""
        accent: Theme.purple
    }
    Meter {
        name: "RAM"
        percent: Svc.Sys.memPercent
        detail: Svc.Sys.fmtBytes(Svc.Sys.memUsed) + " / " + Svc.Sys.fmtBytes(Svc.Sys.memTotal)
        accent: Theme.aqua
    }
    Meter {
        visible: card.rootDisk !== null
        name: "DSK"
        percent: card.rootDisk ? card.rootDisk.percent : 0
        detail: card.rootDisk ? "/  " + Svc.Sys.fmtBytes(card.rootDisk.used) + " / " + Svc.Sys.fmtBytes(card.rootDisk.size) : ""
        accent: Theme.yellow
    }
}
