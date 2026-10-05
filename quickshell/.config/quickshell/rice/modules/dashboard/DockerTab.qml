import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services" as Svc

Item {
    id: root
    implicitHeight: card.implicitHeight

    function stateColor(s, health) {
        if (s === "running") {
            if (health === "unhealthy") return Theme.error;
            if (health === "starting") return Theme.pending;
            return Theme.success;
        }
        if (s === "restarting" || s === "created") return Theme.pending;
        if (s === "paused") return Theme.warning;
        return Theme.muted;
    }

    Card {
        id: card
        width: parent.width

        CardHeader {
            icon: "󰡨"
            title: "Containers"
            subtitle: Svc.Docker.daemonUp ? Svc.Docker.running + " / " + Svc.Docker.total + " running" : "daemon down"
            accent: Svc.Docker.daemonUp ? Theme.catSystem : Theme.error
        }

        Label {
            visible: Svc.Docker.containers.length === 0
            Layout.alignment: Qt.AlignHCenter
            Layout.margins: Theme.pad
            text: Svc.Docker.daemonUp ? "no containers" : "start dockerd to manage containers"
            size: Theme.fontBase
            color: Theme.muted
        }

        ListView {
            Layout.fillWidth: true
            implicitHeight: Math.min(contentHeight, 520)
            visible: count > 0
            clip: true
            spacing: 1
            model: Svc.Docker.containers

            delegate: ListRow {
                id: row
                required property var modelData
                width: ListView.view.width
                icon: "●"
                accent: root.stateColor(modelData.state, modelData.health)
                title: modelData.name + "  " + modelData.image
                subtitle: modelData.status + (modelData.ports ? "  ·  " + modelData.ports : "")
                clickable: false

                IconButton {
                    icon: row.modelData.state === "running" ? "󰓛" : "󰐊"
                    fg: row.modelData.state === "running" ? Theme.error : Theme.success
                    onClicked: row.modelData.state === "running" ? Svc.Docker.stop(row.modelData.id) : Svc.Docker.start(row.modelData.id)
                }
                IconButton {
                    icon: "󰜉"
                    fg: Theme.pending
                    enabledState: row.modelData.state === "running"
                    onClicked: Svc.Docker.restartC(row.modelData.id)
                }
            }
        }
    }
}
