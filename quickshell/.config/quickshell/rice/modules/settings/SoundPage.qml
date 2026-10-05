import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../config"
import "../../components"
import "../quicksettings" as QS
import "../../services" as Svc

// Volume + devices (the Quick Settings page) and per-app volume.
ColumnLayout {
    id: root
    spacing: Theme.pad

    Binding { target: Svc.Audio; property: "streamsWanted"; value: root.visible }

    QS.SoundPage { Layout.fillWidth: true; embedded: true }

    Card {
        Layout.fillWidth: true
        CardHeader {
            icon: "󰎆"
            title: "Apps"
            subtitle: Svc.Audio.streams.length + (Svc.Audio.streams.length === 1 ? " stream" : " streams")
            accent: Theme.catMedia
        }
        Label {
            visible: Svc.Audio.streams.length === 0
            text: "nothing is playing"
            color: Theme.muted
            size: Theme.fontBase
        }
        Repeater {
            model: Svc.Audio.streams
            ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 2
                Label {
                    Layout.fillWidth: true
                    text: modelData.app + (modelData.title && modelData.title !== "AudioStream" ? "  ·  " + modelData.title : "")
                    size: Theme.fontSm
                    color: Theme.subtext
                    elide: Text.ElideRight
                }
                Slider {
                    icon: modelData.muted ? "󰝟" : "󰕾"
                    value: modelData.volume
                    max: 150
                    muted: modelData.muted
                    fill: Theme.catMedia
                    onMoved: p => Svc.Audio.setStreamVolume(modelData.id, p)
                    onIconClicked: Svc.Audio.toggleStreamMute(modelData.id)
                }
            }
        }
    }
}
