import QtQuick
import QtQuick.Layouts
import "../../config"

Item {
    id: root
    required property string screenName
    implicitHeight: row.implicitHeight

    RowLayout {
        id: row
        width: parent.width
        spacing: Theme.pad

        ColumnLayout {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: (row.width - row.spacing) / 2
            spacing: Theme.pad
            ClockCard { Layout.fillWidth: true }
            MonthCard { id: month; Layout.fillWidth: true }
            AgendaCard { Layout.fillWidth: true; day: month.picked }
        }
        ColumnLayout {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: (row.width - row.spacing) / 2
            spacing: Theme.pad
            PlayerCard { Layout.fillWidth: true }
            ResourcesCard { Layout.fillWidth: true }
        }
    }
}
