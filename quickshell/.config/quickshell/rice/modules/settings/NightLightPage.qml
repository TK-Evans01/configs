import QtQuick
import QtQuick.Layouts
import "../../config"
import "../quicksettings" as QS

// Live controls (the Quick Settings page); defaults are the items below it.
ColumnLayout {
    spacing: Theme.pad
    QS.NightLightPage { Layout.fillWidth: true; embedded: true }
}
