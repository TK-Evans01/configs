import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services" as Svc

ColumnLayout {
    id: page
    spacing: Theme.pad

    PageHeader {
        icon: "󰓃"
        title: "Sound"
        subtitle: "default devices"
        onBackClicked: Svc.Ui.back()
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
            DeviceRow {
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
