import QtQuick
import "../../config"
import "../../components"
import "../../services" as Svc

// Square cover with a hairline frame; a big note glyph stands in without art.
Rectangle {
    color: Theme.surface1
    border.width: Theme.border
    border.color: Theme.surface2

    Label {
        anchors.centerIn: parent
        visible: img.status !== Image.Ready
        text: "󰝚"
        size: Math.round(parent.height / 3)
        color: Theme.surface3
    }
    Image {
        id: img
        anchors.fill: parent
        anchors.margins: 1
        source: Svc.Mpris.artUrl
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: width
        sourceSize.height: height
    }
}
