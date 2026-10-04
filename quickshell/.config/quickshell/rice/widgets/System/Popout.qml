import QtQuick
import "../../config"
import "../../services" as Svc

Item {
    id: root

    function temp(t) {
        return t > 0 ? "  " + Math.round(t) + "°C" : "";
    }

    Column {
        anchors.fill: parent
        spacing: 4

        Meter {
            width: parent.width
            name: "CPU"
            accent: Theme.blue
            percent: Svc.Sys.cpuPercent
            detail: Svc.Sys.cpuModel + (Svc.Sys.cpuCores ? "  " + Svc.Sys.cpuCores + "t" : "")
                    + root.temp(Svc.Sys.cpuTemp)
        }

        Meter {
            width: parent.width
            name: "GPU"
            accent: Theme.purple
            percent: Svc.Sys.gpuPercent
            visible: Svc.Sys.gpuVramTotal > 0 || Svc.Sys.gpuModel !== ""
            detail: Svc.Sys.gpuModel
                    + (Svc.Sys.gpuVramTotal > 0
                       ? "  " + Svc.Sys.fmtBytes(Svc.Sys.gpuVramUsed) + "/" + Svc.Sys.fmtBytes(Svc.Sys.gpuVramTotal)
                       : "")
                    + root.temp(Svc.Sys.gpuTemp)
        }

        Meter {
            width: parent.width
            name: "RAM"
            accent: Theme.aqua
            percent: Svc.Sys.memPercent
            detail: Svc.Sys.fmtBytes(Svc.Sys.memUsed) + " / " + Svc.Sys.fmtBytes(Svc.Sys.memTotal)
                    + (Svc.Sys.swapUsed > 0 ? "   swap " + Svc.Sys.fmtBytes(Svc.Sys.swapUsed) : "")
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.bg3
        }

        Repeater {
            model: Svc.Sys.disks
            delegate: Meter {
                required property var modelData
                width: root.width
                name: modelData.target
                accent: Theme.yellow
                percent: modelData.percent
                detail: Svc.Sys.fmtBytes(modelData.used) + " / " + Svc.Sys.fmtBytes(modelData.size)
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.bg3
        }

        Text {
            text: "󰆠  " + Svc.Sys.procs + " processes"   // nf-md-format-list-bulleted
            color: Theme.grey
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
        }
    }
}
