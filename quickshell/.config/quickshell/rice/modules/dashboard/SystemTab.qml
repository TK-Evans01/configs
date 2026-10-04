import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services" as Svc

Item {
    id: root
    implicitHeight: col.implicitHeight
    readonly property real half: (width - Theme.pad) / 2

    function temp(t) { return t > 0 ? Math.round(t) + "°C" : ""; }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: Theme.pad

        RowLayout {
            spacing: Theme.pad
            StatCard {
                Layout.preferredWidth: root.half
                Layout.fillHeight: true
                icon: "󰻠"
                title: "CPU"
                subtitle: Svc.Sys.cpuModel
                accent: Theme.blue
                percent: Svc.Sys.cpuPercent
                history: Svc.Sys.cpuHistory
                chips: [root.temp(Svc.Sys.cpuTemp), Svc.Sys.cpuCores + " threads", "load " + Svc.Sys.loadAvg.split(" ")[0]]
            }
            StatCard {
                Layout.preferredWidth: root.half
                Layout.fillHeight: true
                icon: "󰢮"
                title: "GPU"
                subtitle: Svc.Sys.gpuModel
                accent: Theme.purple
                percent: Svc.Sys.gpuPercent
                history: Svc.Sys.gpuHistory
                chips: [root.temp(Svc.Sys.gpuTemp)]
                Meter {
                    visible: Svc.Sys.gpuVramTotal > 0
                    name: "VRAM"
                    accent: Theme.purple
                    percent: Svc.Sys.gpuVramTotal > 0 ? Math.round(Svc.Sys.gpuVramUsed * 100 / Svc.Sys.gpuVramTotal) : 0
                    detail: Svc.Sys.fmtBytes(Svc.Sys.gpuVramUsed) + " / " + Svc.Sys.fmtBytes(Svc.Sys.gpuVramTotal)
                }
            }
        }

        RowLayout {
            spacing: Theme.pad
            StatCard {
                Layout.preferredWidth: root.half
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignTop
                icon: "󰘚"
                title: "Memory"
                subtitle: Svc.Sys.fmtBytes(Svc.Sys.memUsed) + " / " + Svc.Sys.fmtBytes(Svc.Sys.memTotal)
                accent: Theme.aqua
                percent: Svc.Sys.memPercent
                history: Svc.Sys.memHistory
                chips: Svc.Sys.swapTotal > 0 ? ["swap " + Svc.Sys.fmtBytes(Svc.Sys.swapUsed)] : []
            }
            Card {
                Layout.preferredWidth: root.half
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignTop
                CardHeader { icon: "󰋊"; title: "Storage"; accent: Theme.yellow }
                Repeater {
                    model: Svc.Sys.disks
                    Meter {
                        required property var modelData
                        name: modelData.target
                        accent: Theme.yellow
                        percent: modelData.percent
                        detail: Svc.Sys.fmtBytes(modelData.used) + " / " + Svc.Sys.fmtBytes(modelData.size)
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }

        Card {
            Layout.fillWidth: true
            CardHeader {
                icon: "󰛳"
                title: "Network"
                subtitle: Svc.Network.online ? "online via " + Svc.Network.gateway : "offline"
                accent: Svc.Network.online ? Theme.green : Theme.red
            }
            Flow {
                Layout.fillWidth: true
                spacing: Theme.pad * 2
                Label {
                    text: (Svc.Network.connected ? "󰦝 " : "󰦜 ") + "mullvad " + (Svc.Network.vpnState || "—").toLowerCase()
                          + (Svc.Network.connected ? "  " + Svc.Network.relay : "")
                    size: Theme.fontSizeSmall
                    color: Svc.Network.connected ? Theme.green : Theme.red
                }
                Repeater {
                    model: Svc.Network.links
                    Label {
                        required property var modelData
                        text: (modelData.kind === "wifi" ? "󰖩 " : modelData.kind === "usb" ? "󰕓 " : "󰈀 ")
                              + modelData.name + (modelData.ip ? "  " + modelData.ip : "  down")
                        size: Theme.fontSizeSmall
                        color: !modelData.up ? Theme.muted : modelData.uplink ? Theme.text : Theme.subtext
                    }
                }
            }
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: Svc.Sys.host + "  ·  linux " + Svc.Sys.kernel + "  ·  " + Svc.Sys.procs + " procs"
            size: Theme.fontSizeSmall - 2
            color: Theme.muted
        }
    }
}
