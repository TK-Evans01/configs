import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../config"
import "../../components"
import "../../services" as Svc

// Wallpaper picker, hanging from the bar's centre. Big preview + details
// (fit, your tags — click to edit, favourite) over a strip of thumbnails,
// best for the current theme + season first; others are dimmed, never hidden.
//   ← →  move   ↵ this monitor   shift+↵ all   S span   F favourite
//   Tab  filter (all / suggested / favourites)   Esc close
BarPopup {
    id: root

    required property string screenName
    wanted: Svc.Ui.isOpen("wallpaper", screenName)
    popupWidth: 1180
    contentHeight: col.implicitHeight
    keyTargets: [keys]
    onDismissed: Svc.Ui.dismiss()
    function _opened() { Svc.Wallpaper.today = new Date(); Svc.Wallpaper.reindex(); filter = "all"; strip.currentIndex = 0; _previewCur(); }
    onWantedChanged: wanted ? _opened() : Theme.endPreview()
    Component.onCompleted: if (wanted) _opened()

    property string filter: "all"      // all | suggested | fav
    readonly property var items: filter === "suggested" ? Svc.Wallpaper.suggested
        : filter === "fav" ? Svc.Wallpaper.ranked.filter(r => r.fav) : Svc.Wallpaper.ranked
    readonly property var cur: items.length ? items[Math.max(0, Math.min(strip.currentIndex, items.length - 1))] : null
    readonly property string here: screenName

    // Follow policy: browsing previews the wallpaper's theme palette.
    // Deferred: previewing re-ranks the list, which would re-evaluate `cur` mid-binding.
    onCurChanged: Qt.callLater(_previewCur)
    function _previewCur() {
        if (wanted && cur && Settings.wallpaperThemePolicy === "follow" && cur.themes.length) Theme.preview(cur.themes[0]);
    }

    function applyCur(output, placement) {
        if (!cur) return;
        Theme.endPreview();
        Svc.Wallpaper.apply(cur.key, output, placement);
    }

    Item {
        id: keys
        Keys.onPressed: e => {
            const shift = e.modifiers & Qt.ShiftModifier;
            if (e.key === Qt.Key_Right || e.key === Qt.Key_L) strip.incrementCurrentIndex();
            else if (e.key === Qt.Key_Left || e.key === Qt.Key_H) strip.decrementCurrentIndex();
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.applyCur(shift ? "all" : root.here, "crop");
            else if (e.key === Qt.Key_S) root.applyCur("all", "span");
            else if (e.key === Qt.Key_F && root.cur) Svc.Wallpaper.toggleFav(root.cur.key);
            else if (e.key === Qt.Key_Tab) { const f = ["all", "suggested", "fav"]; root.filter = f[(f.indexOf(root.filter) + 1) % 3]; strip.currentIndex = 0; }
            else return;
            e.accepted = true;
        }
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: Theme.pad

        // --- header: filter + status ---
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing / 2
            Repeater {
                model: [{ id: "all", label: "all · " + Svc.Wallpaper.ranked.length, icon: "󰋩" },
                        { id: "suggested", label: "for " + Theme.themeId + " · " + Svc.Wallpaper.season, icon: "󰄬" },
                        { id: "fav", label: "favourites", icon: "󰓎" }]
                IconButton {
                    required property var modelData
                    icon: modelData.icon
                    text: modelData.label
                    size: Theme.controlHeight - 6
                    checked: root.filter === modelData.id
                    onClicked: { root.filter = modelData.id; strip.currentIndex = 0; }
                }
            }
            Item { Layout.fillWidth: true }
            Spinner { visible: Svc.Wallpaper.indexing }
            Label {
                visible: Svc.Wallpaper.error !== "" || Svc.Wallpaper.lastResult !== ""
                text: Svc.Wallpaper.error || Svc.Wallpaper.lastResult
                size: Theme.fontSm
                color: Theme.error
            }
        }

        // --- preview + details ---
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.pad
            Rectangle {
                Layout.preferredWidth: 720
                Layout.preferredHeight: 405
                color: Theme.surface0
                radius: Theme.radius
                clip: true
                Image {
                    anchors.fill: parent
                    source: root.cur ? "file://" + root.cur.thumbs.m : ""
                    sourceSize: Qt.size(720, 405)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                }
                Label {
                    anchors.centerIn: parent
                    visible: !root.cur
                    text: Svc.Wallpaper.indexing ? "indexing…" : "no wallpapers in " + Settings.wallpaperDir
                    color: Theme.muted
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: Theme.spacing
                visible: root.cur !== null
                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        Layout.fillWidth: true
                        text: root.cur ? root.cur.name : ""
                        size: Theme.fontTitle
                        font.bold: true
                        color: Theme.textBright
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                    IconButton {
                        icon: root.cur && root.cur.fav ? "󰓎" : "󰓒"
                        fg: root.cur && root.cur.fav ? Theme.accent : Theme.subtext
                        onClicked: Svc.Wallpaper.toggleFav(root.cur.key)
                    }
                }
                Label {
                    text: root.cur ? root.cur.w + "×" + root.cur.h + (root.cur.folder ? "  ·  " + root.cur.folder : "")
                        + (root.cur.uses ? "  ·  shown " + root.cur.uses + "×" : "") : ""
                    size: Theme.fontSm
                    color: Theme.subtext
                }
                Row {
                    spacing: 2
                    Repeater {
                        model: root.cur ? root.cur.swatch : []
                        Rectangle { required property var modelData; width: 260 * modelData.w; height: 10; color: modelData.hex }
                    }
                }

                SectionLabel { label: "themes" + (root.cur && root.cur.autoThemes ? " · suggested" : "") }
                Flow {
                    Layout.fillWidth: true
                    spacing: 4
                    Repeater {
                        // Tagged first, then the closest fits.
                        model: root.cur ? root.cur.themes.concat(Object.keys(root.cur.dist).filter(t => root.cur.themes.indexOf(t) < 0)).slice(0, 8) : []
                        IconButton {
                            required property string modelData
                            readonly property bool on: root.cur.themes.indexOf(modelData) >= 0
                            text: modelData + (modelData === Theme.themeId ? " ●" : "")
                            size: Theme.controlHeight - 10
                            checked: on
                            onClicked: Svc.Wallpaper.toggleTheme(root.cur.key, modelData)
                        }
                    }
                }
                SectionLabel { label: "seasons" + (root.cur && root.cur.autoSeasons ? " · suggested" : "") + "  (now " + Svc.Wallpaper.season + ")" }
                Flow {
                    Layout.fillWidth: true
                    spacing: 4
                    Repeater {
                        model: ["any", "spring", "summer", "autumn", "winter"]
                        IconButton {
                            required property string modelData
                            text: modelData
                            size: Theme.controlHeight - 10
                            checked: root.cur && root.cur.seasons.indexOf(modelData) >= 0
                            onClicked: Svc.Wallpaper.toggleSeason(root.cur.key, modelData)
                        }
                    }
                }
                Item { Layout.fillHeight: true }
                RowLayout {
                    spacing: Theme.spacing / 2
                    IconButton { icon: "󰍹"; text: "this monitor"; checked: true; onClicked: root.applyCur(root.here, "crop") }
                    IconButton { icon: "󰍺"; text: "all"; onClicked: root.applyCur("all", "crop") }
                    IconButton {
                        icon: "󰹑"
                        text: "span"
                        enabledState: root.cur !== null && root.cur.w / root.cur.h > 2.2
                        onClicked: root.applyCur("all", "span")
                    }
                }
            }
        }

        // --- strip ---
        ListView {
            id: strip
            Layout.fillWidth: true
            implicitHeight: 118
            orientation: ListView.Horizontal
            spacing: Theme.spacing
            clip: true
            model: root.items
            highlightFollowsCurrentItem: true
            highlightMoveDuration: Theme.animShort
            preferredHighlightBegin: width / 2 - 100
            preferredHighlightEnd: width / 2 + 100
            highlightRangeMode: ListView.ApplyRange
            cacheBuffer: 800
            delegate: Item {
                id: th
                required property var modelData
                required property int index
                readonly property bool sel: ListView.isCurrentItem
                readonly property bool shownHere: Svc.Wallpaper.shownOn(root.here) === modelData.path
                width: 190
                height: strip.height
                opacity: sel || modelData.themeHit || root.filter !== "all" ? 1 : 0.5
                Rectangle {
                    anchors.fill: parent
                    anchors.bottomMargin: 8
                    color: Theme.surface0
                    radius: Theme.radiusSmall
                    clip: true
                    border.width: th.sel ? Theme.outlineWidth : 0
                    border.color: Theme.accent
                    Image {
                        anchors.fill: parent
                        anchors.margins: th.sel ? Theme.outlineWidth : 0
                        source: "file://" + th.modelData.thumbs.s
                        sourceSize: Qt.size(190, 110)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    Label {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 4
                        visible: th.modelData.fav || th.shownHere
                        text: (th.shownHere ? "󰍹" : "") + (th.modelData.fav ? "󰓎" : "")
                        color: Theme.accent
                        style: Text.Outline
                        styleColor: Theme.background
                    }
                }
                AccentIndicator { active: th.sel; anchors.fill: undefined; width: parent.width; height: parent.height }
                MouseArea {
                    anchors.fill: parent
                    onClicked: strip.currentIndex = th.index
                    onDoubleClicked: { strip.currentIndex = th.index; root.applyCur(root.here, "crop"); }
                }
            }
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: "← →  browse    ↵  this monitor    shift+↵  all    S  span    F  favourite    tab  filter    esc  close"
            size: Theme.fontXs
            color: Theme.muted
        }
    }
}
