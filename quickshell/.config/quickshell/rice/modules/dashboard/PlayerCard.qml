import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services" as Svc

// Compact player for the Overview; the cover opens the Media tab.
Card {
    CardHeader {
        icon: "󰝚"
        title: "Now playing"
        subtitle: Svc.Mpris.running ? Svc.Mpris.identity : ""
        accent: Theme.catMedia
    }

    RowLayout {
        visible: Svc.Mpris.running
        Layout.fillWidth: true
        spacing: Theme.pad

        CoverArt {
            implicitWidth: 96
            implicitHeight: 96
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Svc.Ui.tab = "media"
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            ScrollingText {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                text: Svc.Mpris.title || "—"
                color: Theme.catMediaBright
                bold: true
            }
            ScrollingText {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                text: Svc.Mpris.artist
                color: Theme.subtext
                pixelSize: Theme.fontBase
            }
            Progress { showTimes: false; Layout.topMargin: Theme.spacing }
            Transport { Layout.topMargin: 4 }
        }
    }

    RowLayout {
        visible: !Svc.Mpris.running
        Layout.fillWidth: true
        Label {
            Layout.fillWidth: true
            text: "nothing playing"
            color: Theme.muted
            size: Theme.fontBase
        }
        IconButton {
            icon: "󰐊"
            text: "spotify"
            onClicked: Svc.Mpris.launch()
        }
    }
}
