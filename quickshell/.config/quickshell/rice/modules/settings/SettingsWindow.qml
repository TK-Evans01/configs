import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../config"
import "../../components"
import "../../services" as Svc

// "rice settings": a normal floating window (Hyprland rule floats + sizes
// it). Pages come from config/settings-schema.json; every change is live
// and saved. Search matches pages and individual options — matching options
// are editable right in the results. Keys: / or Ctrl+F search, j/k or ↑/↓
// pages, Esc clears the search, then closes.
FloatingWindow {
    id: root

    title: "rice settings"
    implicitWidth: 1120
    implicitHeight: 780
    minimumSize: Qt.size(820, 520)
    color: Theme.background
    visible: true
    onVisibleChanged: if (!visible) Svc.Ui.settingsOpen = false

    property var pages: []
    readonly property string pageId: Svc.Ui.settingsPage || "appearance"
    readonly property var page: pages.find(p => p.id === pageId) || pages[0] || null
    readonly property string query: search.text.trim().toLowerCase()

    FileView {
        path: Quickshell.shellDir + "/config/settings-schema.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.pages = JSON.parse(text()).pages; } catch (e) { console.warn("settings schema", e); } }
    }

    function _hit(s) { return (s || "").toLowerCase().indexOf(root.query) >= 0; }
    // Search: [{ page, items: [schema items that match] }] for pages that
    // match by title/keywords or have matching items.
    readonly property var results: {
        if (query === "") return [];
        const out = [];
        for (const p of pages) {
            const items = [];
            for (const s of (p.sections || []))
                for (const it of (s.items || []))
                    if (_hit(it.label) || _hit(it.help) || _hit(it.key) || _hit(s.title)) items.push(it);
            const pageHit = _hit(p.title) || (p.keywords || []).some(k => _hit(k))
                || (p.sections || []).some(s => s.custom && (_hit(s.title) || (s.keywords || []).some(k => _hit(k))));
            if (pageHit || items.length) out.push({ page: p, items: items });
        }
        return out;
    }
    readonly property var navPages: query === "" ? pages : results.map(r => r.page)

    function go(id) { Svc.Ui.settingsPage = id; scroll.contentY = 0; }
    function step(n) {
        const ids = navPages.map(p => p.id);
        if (!ids.length) return;
        const i = Math.max(0, ids.indexOf(pageId));
        go(ids[(i + n + ids.length) % ids.length]);
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: e => {
            const ctrl = e.modifiers & Qt.ControlModifier;
            if (e.key === Qt.Key_Slash || (ctrl && e.key === Qt.Key_F)) search.focusInput();
            else if (e.key === Qt.Key_J || e.key === Qt.Key_Down) root.step(1);
            else if (e.key === Qt.Key_K || e.key === Qt.Key_Up) root.step(-1);
            else if (e.key === Qt.Key_Escape) root.visible = false;
            else return;
            e.accepted = true;
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // --- navigation ---
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 250
                color: Theme.surface0
                Rectangle { anchors.right: parent.right; width: Theme.border; height: parent.height; color: Theme.surface2 }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.pad
                    spacing: Theme.spacing

                    RowLayout {
                        Layout.bottomMargin: Theme.spacing
                        spacing: Theme.spacing
                        Label { text: "󰒓"; size: Theme.fontLg; color: Theme.accent }
                        Label { text: "SETTINGS"; font.bold: true; color: Theme.textBright }
                    }
                    TextField {
                        id: search
                        prefix: "/"
                        placeholder: "search"
                        onKeyPressed: e => {
                            if (e.key === Qt.Key_Escape) { clear(); root.contentItem.forceActiveFocus(); e.accepted = true; }
                            else if (e.key === Qt.Key_Down) { root.step(1); e.accepted = true; }
                            else if (e.key === Qt.Key_Up) { root.step(-1); e.accepted = true; }
                        }
                        onAccepted: if (root.navPages.length) root.go(root.navPages[0].id)
                    }
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 1
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.navPages
                        delegate: ListRow {
                            required property var modelData
                            width: ListView.view.width
                            compact: true
                            icon: modelData.icon
                            title: modelData.title
                            note: {
                                if (root.query === "") return "";
                                const r = root.results.find(x => x.page.id === modelData.id);
                                return r && r.items.length ? String(r.items.length) : "";
                            }
                            active: modelData.id === root.pageId
                            onClicked: root.go(modelData.id)
                        }
                    }
                    Label {
                        text: "/ search   j k pages   esc close"
                        size: Theme.fontXs
                        color: Theme.muted
                    }
                }
            }

            // --- content ---
            Flickable {
                id: scroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: content.implicitHeight + Theme.gap * 2
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: content
                    x: Theme.gap
                    y: Theme.gap
                    width: scroll.width - Theme.gap * 2
                    spacing: Theme.pad

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacing
                        Label { text: root.page ? root.page.icon : ""; size: Theme.fontLg; color: Theme.accent }
                        Label {
                            Layout.fillWidth: true
                            text: root.page ? root.page.title.toUpperCase() : ""
                            size: Theme.fontMd
                            font.bold: true
                            color: Theme.textBright
                        }
                    }

                    // Matching options on this page, editable in place.
                    Card {
                        Layout.fillWidth: true
                        readonly property var hit: root.results.find(r => root.page && r.page.id === root.page.id)
                        visible: root.query !== "" && hit !== undefined && hit.items.length > 0
                        CardHeader { icon: "󰍉"; title: "Matches"; subtitle: "“" + root.query + "”" }
                        Repeater {
                            model: parent.hit ? parent.hit.items : []
                            SchemaItem { required property var modelData; item: modelData }
                        }
                    }

                    // Keyed on the page: a new page builds a fresh SchemaPage
                    // (pages keep their own state). No imperative Loader toggling —
                    // that broke its binding when the schema loaded late.
                    Repeater {
                        model: root.page ? [root.page] : []
                        SchemaPage {
                            required property var modelData
                            Layout.fillWidth: true
                            page: modelData
                        }
                    }
                }
            }
        }
    }
}
