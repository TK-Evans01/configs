import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services" as Svc

ColumnLayout {
    id: page
    spacing: Theme.pad
    // In the settings window: no back-button header (the window has its own).
    property bool embedded: false

    PageHeader {

        visible: !page.embedded
        icon: "󰓃"
        title: "Sound"
        subtitle: "volume and devices"
        onBackClicked: Svc.Ui.back()
    }

    Card {
        Layout.fillWidth: true
        CardHeader { icon: "󰕾"; title: "Volume"; accent: Theme.catMedia }
        Slider {
            icon: Svc.Audio.outMuted ? "󰝟" : "󰕾"
            value: Svc.Audio.outPercent
            max: 150
            muted: Svc.Audio.outMuted
            fill: Theme.catMedia
            onMoved: p => Svc.Audio.setOutputVolume(p)
            onIconClicked: Svc.Audio.toggleMute()
        }
        Slider {
            icon: Svc.Audio.inMuted ? "󰍭" : "󰍬"
            value: Svc.Audio.inPercent
            max: 150
            muted: Svc.Audio.inMuted
            fill: Theme.catMedia
            onMoved: p => Svc.Audio.setInputVolume(p)
            onIconClicked: Svc.Audio.toggleInputMute()
        }
    }

    component Section: Card {
        id: sec
        property string icon: ""
        property string heading: ""
        property var devices: []
        property string current: ""
        property bool sink: true

        Layout.fillWidth: true
        CardHeader {
            icon: sec.icon
            title: sec.heading
            subtitle: sec.devices.length + (sec.devices.length === 1 ? " device" : " devices")
        }
        Repeater {
            model: sec.devices
            ListRow {
                required property var modelData
                icon: sec.sink ? (/hdmi|displayport/i.test(modelData.name) ? "󰡁" : /headset|usb/i.test(modelData.name) ? "󰋋" : "󰓃")
                               : (/usb|headset/i.test(modelData.name) ? "󰋎" : "󰍬")
                title: modelData.description
                subtitle: modelData.name === sec.current ? "in use" : ""
                active: modelData.name === sec.current
                onClicked: sec.sink ? Svc.Audio.setDefaultSink(modelData.name) : Svc.Audio.setDefaultSource(modelData.name)
            }
        }
    }

    Section {
        icon: "󰓃"
        heading: "Output"
        devices: Svc.Audio.outputs
        current: Svc.Audio.outDefault
        sink: true
    }
    Section {
        icon: "󰍬"
        heading: "Input"
        devices: Svc.Audio.inputs
        current: Svc.Audio.inDefault
        sink: false
    }
}
