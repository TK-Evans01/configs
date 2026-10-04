import QtQuick
import QtQuick.Layouts
import "../config"

// Darker inset panel with a hairline border; children stack in a column.
Rectangle {
    id: root

    default property alias content: col.data
    property alias spacing: col.spacing
    property int padding: Theme.pad

    implicitWidth: col.implicitWidth + padding * 2
    implicitHeight: col.implicitHeight + padding * 2
    color: Theme.surface0
    border.width: Theme.border
    border.color: Theme.surface2
    radius: Theme.radius

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: root.padding
        spacing: Theme.spacing
    }
}
