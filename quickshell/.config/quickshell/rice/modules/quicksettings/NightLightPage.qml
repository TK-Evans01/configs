import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services" as Svc

// Warmth + brightness for hyprsunset. Moving a slider turns night light on.
ColumnLayout {
    id: page
    spacing: Theme.pad
    // In the settings window: no back-button header (the window has its own).
    property bool embedded: false
    readonly property var presets: [
        { label: "candle", k: 2700 },
        { label: "warm", k: 3500 },
        { label: "evening", k: 4500 },
        { label: "soft", k: 5500 }
    ]

    PageHeader {

        visible: !page.embedded
        icon: "󰖔"
        title: "Night light"
        subtitle: Svc.Desktop.nightLight
                  ? Svc.Desktop.nightTemp + "K  ·  " + Svc.Desktop.nightGamma + "% brightness"
                  : "off"
        onBackClicked: Svc.Ui.back()
        Switch {
            checked: Svc.Desktop.nightLight
            onToggled: Svc.Desktop.toggleNightLight()
        }
    }

    Card {
        Layout.fillWidth: true

        CardHeader { icon: "󰔏"; title: "Warmth"; subtitle: "lower = warmer"; accent: Theme.orange }
        Slider {
            icon: "󰖨"
            min: Settings.nightLightMinTemp
            max: Settings.nightLightMaxTemp
            step: 100
            suffix: "K"
            value: Svc.Desktop.nightTemp
            fill: Theme.orange
            muted: !Svc.Desktop.nightLight
            onMoved: k => Svc.Desktop.setNightTemp(k)
            onIconClicked: Svc.Desktop.toggleNightLight()
        }
        // warm → cool strip under the slider, as a legend
        Row {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.fontMd + Theme.spacing * 3
            Layout.rightMargin: Theme.fontBase * 4 + Theme.spacing
            height: 4
            Repeater {
                model: 12
                Rectangle {
                    required property int index
                    width: parent.width / 12
                    height: 4
                    color: Qt.rgba(1, 0.55 + index * 0.035, 0.25 + index * 0.06, 0.8)
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Theme.spacing
            spacing: Theme.spacing / 2
            Repeater {
                model: page.presets
                IconButton {
                    required property var modelData
                    Layout.fillWidth: true
                    text: modelData.label + " " + modelData.k
                    size: Theme.fontBase + Theme.spacing * 2
                    checked: Svc.Desktop.nightLight && Svc.Desktop.nightTemp === modelData.k
                    onClicked: Svc.Desktop.setNightTemp(modelData.k)
                }
            }
        }
    }

    Card {
        Layout.fillWidth: true
        CardHeader { icon: "󰃟"; title: "Brightness"; subtitle: "display gamma"; accent: Theme.yellow }
        Slider {
            icon: "󰃞"
            min: 40
            max: 100
            step: 5
            value: Svc.Desktop.nightGamma
            fill: Theme.yellow
            muted: !Svc.Desktop.nightLight
            onMoved: g => Svc.Desktop.setNightGamma(g)
            onIconClicked: Svc.Desktop.setNightGamma(100)
        }
    }

    Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: "hyprsunset.conf profiles (05:00 / 17:00) re-apply their own values when they trigger."
        size: Theme.fontXs
        color: Theme.muted
    }
}
