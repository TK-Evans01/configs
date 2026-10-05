import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services" as Svc

// Track position: seekable bar + elapsed / length.
ColumnLayout {
    id: root
    property bool showTimes: true

    function fmt(sec) {
        const s = Math.max(0, Math.floor(sec));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    Layout.fillWidth: true
    spacing: 2

    Rectangle {
        radius: Theme.radiusPill
        Layout.fillWidth: true
        implicitHeight: 8
        color: Theme.surface0
        border.width: Theme.border
        border.color: Theme.surface2
        Rectangle {
            radius: Theme.radiusPill
            x: 1; y: 1
            height: parent.height - 2
            width: Svc.Mpris.length > 0 ? (parent.width - 2) * Math.min(1, Svc.Mpris.position / Svc.Mpris.length) : 0
            color: Theme.catMedia
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            enabled: Svc.Mpris.canSeek && Svc.Mpris.length > 0
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: m => Svc.Mpris.seek(Math.max(0, Math.min(1, m.x / width)) * Svc.Mpris.length)
        }
    }
    RowLayout {
        visible: root.showTimes
        Layout.fillWidth: true
        Label { text: root.fmt(Svc.Mpris.position); size: Theme.fontSm; color: Theme.subtext }
        Item { Layout.fillWidth: true }
        Label { text: root.fmt(Svc.Mpris.length); size: Theme.fontSm; color: Theme.subtext }
    }
}
