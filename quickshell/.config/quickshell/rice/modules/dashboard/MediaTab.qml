import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services" as Svc

// Full player: cover, metadata, transport, player volume, player picker, lyrics.
Item {
    id: root

    property bool shownTab: false
    Binding {
        target: Svc.Lyrics
        property: "wanted"
        value: root.shownTab && Svc.Mpris.running
    }

    readonly property int coverSize: 380
    implicitHeight: Svc.Mpris.running ? row.implicitHeight : empty.implicitHeight

    Card {
        id: empty
        visible: !Svc.Mpris.running
        width: parent.width
        Label {
            Layout.alignment: Qt.AlignHCenter
            text: "󰝛"
            size: Theme.fontSizeHuge
            color: Theme.surface3
        }
        Label {
            Layout.alignment: Qt.AlignHCenter
            text: "no player running"
            color: Theme.muted
        }
        IconButton {
            Layout.alignment: Qt.AlignHCenter
            icon: "󰐊"
            text: "start ncspot"
            onClicked: Svc.Mpris.launch()
        }
    }

    RowLayout {
        id: row
        visible: Svc.Mpris.running
        width: parent.width
        spacing: Theme.pad

        CoverArt {
            Layout.alignment: Qt.AlignTop
            implicitWidth: root.coverSize
            implicitHeight: root.coverSize
        }

        Card {
            Layout.fillWidth: true
            Layout.preferredHeight: root.coverSize
            Layout.alignment: Qt.AlignTop

            // Player picker (only with more than one)
            Flow {
                Layout.fillWidth: true
                visible: Svc.Mpris.players.length > 1
                spacing: Theme.spacing / 2
                Repeater {
                    model: Svc.Mpris.players
                    IconButton {
                        required property var modelData
                        text: Svc.Mpris.playerName(modelData).toLowerCase()
                        icon: modelData.isPlaying ? "󰐊" : ""
                        size: Theme.fontSizeSmall + Theme.spacing * 2
                        checked: modelData === Svc.Mpris.player
                        onClicked: Svc.Mpris.select(modelData)
                    }
                }
            }

            ScrollingText {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                text: Svc.Mpris.title || "—"
                color: Theme.purpleBright
                pixelSize: Theme.fontSizeLarge
                bold: true
            }
            ScrollingText {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                visible: text !== ""
                text: Svc.Mpris.artist
                color: Theme.text
            }
            ScrollingText {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                visible: text !== ""
                text: Svc.Mpris.album
                color: Theme.subtext
                pixelSize: Theme.fontSizeSmall
            }

            LyricsView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: Settings.lyrics
            }
            Item { Layout.fillHeight: true; visible: !Settings.lyrics }

            Progress {}
            RowLayout {
                Layout.fillWidth: true
                Transport { full: true }
                Item { Layout.fillWidth: true }
                Slider {
                    Layout.fillWidth: false
                    Layout.preferredWidth: 220
                    icon: "󰕾"
                    fill: Theme.purple
                    value: Math.round(Svc.Mpris.volume * 100)
                    onMoved: p => Svc.Mpris.setVolume(p / 100)
                }
            }
        }
    }
}
