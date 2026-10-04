import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services" as Svc

// Pick what to do with the capture, then what to capture. The panel closes
// before the shot is taken.
ColumnLayout {
    id: page
    spacing: Theme.pad

    readonly property bool shown: Svc.Ui.page === "screenshot" && Svc.Ui.open === "quicksettings"
    onShownChanged: if (shown) Svc.Screenshot.refreshLatest()

    readonly property var actions: [
        { id: "save", label: "save + copy", icon: "󰆓", ok: true },
        { id: "copy", label: "copy", icon: "󰆏", ok: true },
        { id: "text", label: "text (OCR)", icon: "󰊄", ok: Svc.Screenshot.hasOcr },
        { id: "edit", label: "edit", icon: "󰏫", ok: Svc.Screenshot.hasEditor }
    ]
    readonly property var targets: [
        { id: "area", label: "Region", sub: "drag, or click a window", icon: "󰩭" },
        { id: "active", label: "Window", sub: "focused window", icon: "󱂬" },
        { id: "output", label: "Monitor", sub: "this screen", icon: "󰍹" },
        { id: "screen", label: "All screens", sub: "both monitors", icon: "󰍺" }
    ]

    PageHeader {
        icon: "󰹑"
        title: "Screenshot"
        subtitle: Settings.screenshotDir.replace(/^\/home\/[^/]+/, "~")
        onBackClicked: Svc.Ui.back()
        IconButton {
            icon: "󰉋"
            onClicked: { Svc.Ui.close(); Svc.Screenshot.openFolder(); }
        }
    }

    Card {
        Layout.fillWidth: true
        CardHeader { icon: "󰐊"; title: "Then"; accent: Theme.accent }
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Theme.spacing / 2
            rowSpacing: Theme.spacing / 2
            Repeater {
                model: page.actions
                IconButton {
                    required property var modelData
                    Layout.fillWidth: true
                    icon: modelData.icon
                    text: modelData.label
                    checked: Svc.Screenshot.action === modelData.id
                    enabledState: modelData.ok
                    onClicked: Svc.Screenshot.action = modelData.id
                }
            }
        }
        Label {
            visible: !Svc.Screenshot.hasOcr || !Svc.Screenshot.hasEditor
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: (!Svc.Screenshot.hasOcr ? "OCR needs tesseract-data-" + Settings.ocrLang + ". " : "")
                  + (!Svc.Screenshot.hasEditor ? "Edit needs satty." : "")
            size: Theme.fontSizeSmall - 3
            color: Theme.muted
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Theme.spacing
        rowSpacing: Theme.spacing
        Repeater {
            model: page.targets
            Tile {
                required property var modelData
                icon: modelData.icon
                label: modelData.label
                sublabel: modelData.sub
                onToggled: { Svc.Ui.close(); Svc.Screenshot.take(modelData.id); }
            }
        }
    }

    Card {
        Layout.fillWidth: true
        visible: Svc.Screenshot.latest !== ""
        CardHeader {
            icon: "󰋩"
            title: "Last"
            subtitle: Svc.Screenshot.latest.split("/").pop()
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Math.min(220, width * 9 / 16)
            color: Theme.bg0
            border.width: Theme.border
            border.color: lastHov.containsMouse ? Theme.accent : Theme.surface2
            Image {
                anchors.fill: parent
                anchors.margins: 1
                source: Svc.Screenshot.latest ? "file://" + Svc.Screenshot.latest : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
                sourceSize.width: width * 2
            }
            MouseArea {
                id: lastHov
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { Svc.Ui.close(); Svc.Screenshot.openLatest(); }
            }
        }
    }
}
