import QtQuick
import QtQuick.Layouts
import "../config"

// The list row: leading glyph (or `leading` item), title, subtitle, trailing
// slot. `active` marks the selected / in-use row with the accent indicator.
Rectangle {
    id: root

    property string icon: ""
    property color iconColor: active ? Theme.accent : accent
    property string title: ""
    property string subtitle: ""
    property string note: ""               // right-aligned meta (age, count)
    property color accent: Theme.text      // title colour when not active
    property color indicator: Theme.accent
    property bool active: false
    property bool clickable: true
    property bool compact: false           // single-line height (menus)
    property int titleSize: Theme.fontTitle
    property int titleMaxLines: 1
    property int subtitleMaxLines: 1
    property Component leading: null       // replaces the glyph (app icon, avatar)
    default property alias trailing: tail.data
    readonly property alias hovered: mouse.containsMouse
    signal clicked()
    signal rightClicked()

    Layout.fillWidth: true
    implicitHeight: Math.max(compact ? Theme.rowHeightCompact : Theme.rowHeight, row.implicitHeight + 8)
    radius: Theme.radiusSmall
    color: mouse.containsMouse && clickable ? Theme.surface1 : "transparent"

    AccentIndicator {
        edge: "left"
        active: root.active
        tint: root.indicator
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: m => {
            if (!root.clickable) return;
            if (m.button === Qt.RightButton) root.rightClicked();
            else root.clicked();
        }
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: Theme.pad
        anchors.rightMargin: Theme.spacing
        spacing: Theme.pad

        Loader {
            active: root.leading !== null
            visible: active
            sourceComponent: root.leading
        }
        Label {
            visible: root.leading === null && root.icon !== ""
            Layout.preferredWidth: Theme.fontMd * 1.4
            text: root.icon
            color: root.iconColor
            size: Theme.fontMd
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Label {
                Layout.fillWidth: true
                text: root.title
                size: root.titleSize
                color: root.active ? Theme.textBright : root.accent
                elide: Text.ElideRight
                wrapMode: root.titleMaxLines > 1 ? Text.Wrap : Text.NoWrap
                maximumLineCount: root.titleMaxLines
            }
            Label {
                Layout.fillWidth: true
                visible: root.subtitle !== ""
                text: root.subtitle
                size: Theme.fontSm
                color: Theme.subtext
                elide: Text.ElideRight
                wrapMode: root.subtitleMaxLines > 1 ? Text.Wrap : Text.NoWrap
                maximumLineCount: root.subtitleMaxLines
            }
        }
        Label {
            visible: root.note !== ""
            text: root.note
            size: Theme.fontSm
            color: Theme.muted
        }
        RowLayout {
            id: tail
            spacing: Theme.spacing / 2
        }
    }
}
