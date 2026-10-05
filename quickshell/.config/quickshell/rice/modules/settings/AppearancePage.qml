import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../config"
import "../../components"
import "../../services" as Svc

// Theme grid (hover previews the palette, click applies), shape, font.
ColumnLayout {
    id: root
    spacing: Theme.pad

    Card {
        Layout.fillWidth: true
        CardHeader {
            icon: "󰏘"
            title: "Theme"
            subtitle: "hover to preview · click to apply"
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: Theme.spacing
            rowSpacing: Theme.spacing
            Repeater {
                model: Theme.themeIds
                ThemeTile {
                    required property string modelData
                    themeId: modelData
                    Layout.fillWidth: true
                }
            }
        }
    }

    Card {
        Layout.fillWidth: true
        CardHeader { icon: "󰝣"; title: "Shape" }
        SettingRow {
            label: "Corners and accents"
            help: "Square: sharp corners, underline accents (retro). Round: rounded corners, pill accents. Default follows the theme."
            Repeater {
                model: [{ id: "", label: "theme default" }, { id: "square", label: "square" }, { id: "round", label: "round" }]
                IconButton {
                    required property var modelData
                    text: modelData.label
                    checked: Prefs.shape === modelData.id
                    onClicked: Prefs.set("shape", modelData.id)
                }
            }
        }
    }

    Card {
        Layout.fillWidth: true
        CardHeader {
            icon: "󰛖"
            title: "Font"
            subtitle: "now: " + Theme.fontFamily
        }
        IconButton {
            text: "theme default"
            checked: Prefs.font === ""
            onClicked: Prefs.set("font", "")
        }
        Repeater {
            model: Theme.fonts
            ListRow {
                required property var modelData
                readonly property bool installed: Theme.fontInstalled(modelData)
                icon: installed ? "󰛖" : "󰀦"
                iconColor: installed ? Theme.text : Theme.muted
                title: modelData.name
                subtitle: installed ? "The quick brown fox · 0123456789" : "not installed · sudo pacman -S " + modelData.package
                accent: installed ? Theme.text : Theme.muted
                active: Theme.fontId === modelData.id
                clickable: installed
                onClicked: Prefs.set("font", modelData.id)
            }
        }
    }

    Card {
        Layout.fillWidth: true
        CardHeader {
            icon: "󰍹"
            title: "Elsewhere"
            subtitle: "applied on every theme / shape change"
            IconButton { icon: "󰑓"; text: "re-apply"; onClicked: Svc.ThemeSync.apply() }
        }
        Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            size: Theme.fontSm
            color: Theme.subtext
            text: "Live: Hyprland windows (rounding + borders), ghostty, tmux, Neovim, GTK dark/light. Next start: btop, zathura, Firefox (textfox). Next login: SDDM."
        }
        Repeater {
            model: Svc.ThemeSync.lastResult.replace(/^[^:]*:\s*/, "").split("; ").filter(x => x)
            ListRow {
                required property string modelData
                compact: true
                clickable: false
                readonly property bool warn: modelData.indexOf("not copied") >= 0 || modelData.indexOf("no textfox") >= 0
                icon: warn ? "󰀦" : "󰄬"
                iconColor: warn ? Theme.warning : Theme.success
                title: modelData.split(":")[0]
                note: modelData.slice(modelData.indexOf(":") + 1).trim()
            }
        }
        Label {
            Layout.fillWidth: true
            visible: Svc.ThemeSync.lastResult.indexOf("not copied") >= 0
            wrapMode: Text.Wrap
            size: Theme.fontSm
            color: Theme.warning
            text: "Login screen: run once  ~/Projects/configs/sddm/install.sh  (sudo) — it makes the SDDM colour file yours, so theme switches reach it without sudo after that."
        }
    }

    // A theme as a mini mock: its background, a card, the hue swatches.
    component ThemeTile: Rectangle {
        id: tile
        property string themeId: ""
        property var t: ({})
        readonly property var pal: t.palette || {}
        function hue(k) { const v = pal[k]; return Array.isArray(v) ? v[0] : (v || "#888"); }
        readonly property bool current: Theme.themeId === themeId
        readonly property string accentKey: t.roles && t.roles.accent ? t.roles.accent : "yellow"
        readonly property color accentCol: accentKey.charAt(0) === "#" ? accentKey : hue(accentKey)

        implicitHeight: 92
        radius: t.shape === "round" ? 8 : 0
        color: pal.bg1 || Theme.surface0
        border.width: current ? 2 : 1
        border.color: current ? Theme.accent : (mouse.containsMouse ? Theme.textBright : Theme.surface2)

        FileView {
            path: Theme.themesDir + "/" + tile.themeId + ".json"
            onLoaded: { try { tile.t = JSON.parse(text()); } catch (e) {} }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 6
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: tile.t.name || tile.themeId
                    color: tile.pal.fg0 || Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTitle
                    font.bold: tile.current
                    elide: Text.ElideRight
                }
                Text {
                    text: (tile.t.shape || "square") + (tile.t.variant === "light" ? " · light" : "")
                    color: tile.pal.grey || Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontXs
                }
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 18
                radius: tile.t.shape === "round" ? 4 : 0
                color: tile.pal.bg0 || "#000"
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: 44
                    height: tile.t.shape === "round" ? parent.height : 2
                    radius: parent.radius
                    color: tile.t.shape === "round" ? Qt.alpha(tile.accentCol, 0.35) : tile.accentCol
                }
            }
            Row {
                spacing: 3
                Repeater {
                    model: ["red", "orange", "yellow", "green", "aqua", "blue", "purple"]
                    Rectangle {
                        required property string modelData
                        width: 16; height: 12
                        radius: tile.t.shape === "round" ? 3 : 0
                        color: tile.hue(modelData)
                    }
                }
            }
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: Theme.preview(tile.themeId)
            onExited: Theme.endPreview()
            onClicked: { Theme.endPreview(); Prefs.set("theme", tile.themeId); }
        }
    }
}
