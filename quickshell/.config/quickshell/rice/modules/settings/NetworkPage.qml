import QtQuick
import QtQuick.Layouts
import "../../config"
import "../quicksettings" as QS

ColumnLayout {
    spacing: Theme.pad
    QS.NetworkPage { Layout.fillWidth: true; embedded: true }
}
