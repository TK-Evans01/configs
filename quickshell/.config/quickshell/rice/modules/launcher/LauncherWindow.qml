import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../config"
import "../../components"
import "../../services" as Svc

// Launcher under the arch button, in three modes (Svc.Ui.page):
//   ""          apps — fuzzy search, frequent first; "= expr" calculates
//   "clipboard" cliphist history — Enter copies, Shift+Del removes
//   "keybinds"  Hyprland binds — Enter runs the bind
// ↑↓ / Tab / Ctrl+J/K move, Alt+1/2/3 switch mode, Esc closes.
BarPopup {
    id: root

    required property string screenName

    wanted: Svc.Ui.isOpen("launcher", screenName)
    popupWidth: Settings.launcherWidth
    contentHeight: col.implicitHeight
    initialFocus: field.input
    onDismissed: Svc.Ui.dismiss()
    // Also on creation: Bar.qml creates the launcher lazily, already open.
    function _opened() { field.clear(); root.reload(); list.currentIndex = firstSelectable(); }
    onWantedChanged: if (wanted) _opened()
    Component.onCompleted: if (wanted) _opened()

    readonly property string mode: wanted ? Svc.Ui.page : ""
    onModeChanged: { field.clear(); reload(); }
    function reload() {
        if (mode === "clipboard") Svc.Clipboard.load();
        else if (mode === "keybinds") Svc.Keybinds.load();
    }

    readonly property var modes: [
        { id: "", label: "apps", icon: "󰀻" },
        { id: "clipboard", label: "clipboard", icon: "󰅌" },
        { id: "keybinds", label: "keybinds", icon: "󰌌" }
    ]

    readonly property string query: field.text
    readonly property string calcResult: mode === "" ? Svc.Launcher.calc(query) : ""

    function _has(hay, q) { return hay.toLowerCase().indexOf(q) >= 0; }

    // Rows: header | app | calc | clip | bind
    readonly property var rows: {
        const q = query.trim().toLowerCase();
        if (mode === "clipboard") {
            return Svc.Clipboard.entries.filter(e => !q || _has(e.text, q)).map(e => ({ kind: "clip", clip: e }));
        }
        if (mode === "keybinds") {
            const out = [];
            let group = "";
            for (const b of Svc.Keybinds.rows) {
                if (q && !_has(b.keys + " " + b.label + " " + b.group, q)) continue;
                if (!q && b.group !== group) {
                    group = b.group;
                    out.push({ kind: "header", label: group });
                }
                out.push({ kind: "bind", bind: b });
            }
            return out;
        }
        if (calcResult !== "") return [{ kind: "calc", value: calcResult }];
        // > actions (shell allowlist), @ open windows
        if (query.startsWith(">")) return Svc.Actions.search(query.slice(1)).map(a => ({ kind: "action", action: a }));
        if (query.startsWith("@")) return windows(query.slice(1));
        if (q) return Svc.Launcher.search(query).map(e => ({ kind: "app", entry: e }));
        const out = [];
        const freq = Svc.Launcher.frequent;
        if (freq.length) {
            out.push({ kind: "header", label: "frequent" });
            for (const e of freq) out.push({ kind: "app", entry: e });
        }
        out.push({ kind: "header", label: "all apps · " + Svc.Launcher.apps.length });
        for (const e of Svc.Launcher.apps) out.push({ kind: "app", entry: e });
        return out;
    }
    onRowsChanged: { list.currentIndex = firstSelectable(); armed = ""; }

    function windows(q) {
        q = q.trim().toLowerCase();
        const out = [];
        for (const t of Svc.Hyprland.toplevels.values) {
            const ipc = t.lastIpcObject || {};
            const cls = ipc.class || "";
            const s = !q ? 1 : Math.max(Svc.Launcher.score(q, t.title), Svc.Launcher.score(q, cls));
            if (s > 0) out.push({ kind: "window", win: t, cls: cls, ws: ipc.workspace ? ipc.workspace.name : "", s: s });
        }
        return out.sort((a, b) => b.s - a.s);
    }
    // A confirm-tier action needs Enter twice.
    property string armed: ""

    function firstSelectable() {
        for (let i = 0; i < rows.length; i++) if (rows[i].kind !== "header") return i;
        return -1;
    }
    function move(step) {
        if (!rows.length) return;
        let i = list.currentIndex;
        for (let n = 0; n < rows.length; n++) {
            i = (i + step + rows.length) % rows.length;
            if (rows[i].kind !== "header") break;
        }
        list.currentIndex = i;
    }
    function activate(i) {
        const r = rows[i];
        if (!r) return;
        if (r.kind === "calc") Svc.Launcher.copy(r.value);
        else if (r.kind === "app") Svc.Launcher.launch(r.entry);
        else if (r.kind === "clip") Svc.Clipboard.copy(r.clip);
        else if (r.kind === "action") {
            if (r.action.confirm === "confirm" && armed !== r.action.id) { armed = r.action.id; return; }
            Svc.Ui.close();
            Svc.Actions.run(r.action);
            return;
        }
        else if (r.kind === "window") {
            Svc.Ui.close();
            Svc.Hyprland.dispatch("focuswindow address:0x" + r.win.address);
            return;
        }
        else if (r.kind === "bind") {
            if (!r.bind.runnable) return;
            Svc.Ui.close();
            Svc.Hyprland.dispatch(r.bind.dispatcher + " " + r.bind.arg);
            return;
        }
        else return;
        Svc.Ui.close();
    }
    function setMode(id) { Svc.Ui.page = id; }

    readonly property int rowH: Theme.fontMd * 2 + 10
    readonly property int clipImageH: 72
    readonly property int headerH: Theme.fontBase + 14

    ColumnLayout {
        id: col
        width: parent.width
        spacing: Theme.spacing

        // --- mode chips ---
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing / 2
            Repeater {
                model: root.modes
                IconButton {
                    required property var modelData
                    icon: modelData.icon
                    text: modelData.label
                    size: Theme.fontBase + Theme.spacing * 2
                    checked: root.mode === modelData.id
                    onClicked: root.setMode(modelData.id)
                }
            }
            Item { Layout.fillWidth: true }
            IconButton {
                visible: root.mode === "clipboard" && Svc.Clipboard.entries.length > 0
                icon: "󰎟"
                text: "wipe"
                fg: Theme.error
                size: Theme.fontBase + Theme.spacing * 2
                onClicked: Svc.Clipboard.wipe()
            }
        }

        // --- prompt ---
        TextField {
            id: field
            fontSize: Theme.fontMd
            prefix: root.mode === "clipboard" ? "󰅌" : root.mode === "keybinds" ? "󰌌"
                : root.query.startsWith(">") ? "󰘳" : root.query.startsWith("@") ? "󰖯"
                : (root.calcResult !== "" || root.query.startsWith("=") ? "=" : ">")
            placeholder: root.mode === "clipboard" ? "search clipboard history"
                : root.mode === "keybinds" ? "search keybinds"
                : "search apps   ·   > actions   ·   @ windows   ·   = calc"
            onKeyPressed: e => {
                            const ctrl = e.modifiers & Qt.ControlModifier;
                            const alt = e.modifiers & Qt.AltModifier;
                            const shift = e.modifiers & Qt.ShiftModifier;
                            if (e.key === Qt.Key_Escape) root.dismissed();
                            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.activate(list.currentIndex);
                            else if (alt && e.key >= Qt.Key_1 && e.key <= Qt.Key_3) root.setMode(root.modes[e.key - Qt.Key_1].id);
                            else if (shift && e.key === Qt.Key_Delete && root.mode === "clipboard") {
                                const r = root.rows[list.currentIndex];
                                if (r && r.clip) Svc.Clipboard.remove(r.clip);
                            }
                            else if (e.key === Qt.Key_Down || e.key === Qt.Key_Tab || (ctrl && (e.key === Qt.Key_J || e.key === Qt.Key_N))) root.move(1);
                            else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab || (ctrl && (e.key === Qt.Key_K || e.key === Qt.Key_P))) root.move(-1);
                            else if (e.key === Qt.Key_PageDown) { for (let i = 0; i < Settings.launcherRows; i++) root.move(1); }
                            else if (e.key === Qt.Key_PageUp) { for (let i = 0; i < Settings.launcherRows; i++) root.move(-1); }
                            else return;
                            e.accepted = true;
                        }

            Label {
                visible: root.query.trim() !== "" && root.calcResult === ""
                text: list.count + (list.count === 1 ? " match" : " matches")
                size: Theme.fontSm
                color: Theme.subtext
            }
        }

        // --- results ---
        ListView {
            id: list
            Layout.fillWidth: true
            implicitHeight: Math.max(root.rowH, Math.min(contentHeight, root.rowH * Settings.launcherRows))
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.rows
            highlightMoveDuration: Theme.animShort
            highlightFollowsCurrentItem: true
            keyNavigationEnabled: false

            delegate: Item {
                id: row
                required property var modelData
                required property int index
                readonly property string kind: modelData.kind
                readonly property bool isHeader: kind === "header"
                readonly property bool selected: ListView.isCurrentItem
                readonly property var entry: kind === "app" ? modelData.entry : null
                readonly property var clip: kind === "clip" ? modelData.clip : null
                readonly property var bind: kind === "bind" ? modelData.bind : null
                readonly property string iconSrc: entry && entry.icon ? Quickshell.iconPath(entry.icon, true) : ""

                width: ListView.view.width
                height: isHeader ? root.headerH : (clip && clip.image ? root.clipImageH : root.rowH)

                // section header
                RowLayout {
                    visible: row.isHeader
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacing
                    spacing: Theme.spacing
                    SectionLabel {
                        label: row.isHeader ? row.modelData.label : ""
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.surface2 }
                }

                // selectable row
                Rectangle {
                    visible: !row.isHeader
                    anchors.fill: parent
                    radius: Theme.radiusSmall
                    // Hover moves the selection, so only "selected" is drawn.
                    color: row.selected ? Theme.surface1 : "transparent"

                    AccentIndicator {
                        edge: "left"
                        active: row.selected
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.pad
                        anchors.rightMargin: Theme.pad
                        spacing: Theme.pad

                        // key combo chip (keybinds)
                        Rectangle {
                            visible: row.bind !== null
                            Layout.preferredWidth: Theme.fontBase * 15
                            implicitHeight: keysL.implicitHeight + 8
                            radius: Theme.radiusSmall
                            color: Theme.surface0
                            border.width: Theme.border
                            border.color: row.selected ? Theme.accent : Theme.surface2
                            Label {
                                id: keysL
                                anchors.centerIn: parent
                                width: parent.width - Theme.spacing
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                text: row.bind ? row.bind.keys : ""
                                size: Theme.fontSm
                                font.bold: true
                                color: row.selected ? Theme.accent : Theme.text
                            }
                        }

                        // icon / thumbnail / lettered tile
                        Item {
                            visible: row.bind === null
                            implicitWidth: row.clip && row.clip.image ? root.clipImageH * 1.6 : Theme.iconSizeLarge - 3
                            implicitHeight: row.clip && row.clip.image ? root.clipImageH - 10 : Theme.iconSizeLarge - 3
                            Image {
                                id: icon
                                anchors.fill: parent
                                visible: status === Image.Ready
                                source: row.clip ? (row.clip.image ? row.clip.thumb + "?v=" + Svc.Clipboard.thumbsVersion : "") : row.iconSrc
                                fillMode: row.clip ? Image.PreserveAspectFit : Image.Stretch
                                sourceSize.width: width * 2
                                sourceSize.height: height * 2
                                asynchronous: true
                                cache: !row.clip
                                smooth: true
                                mipmap: true
                            }
                            Rectangle {
                                anchors.fill: parent
                                visible: !icon.visible
                                radius: Theme.radiusSmall
                                color: row.kind === "calc" ? Theme.accent : Theme.surface2
                                Label {
                                    anchors.centerIn: parent
                                    text: row.kind === "calc" ? "󰃬"
                                    : row.kind === "action" ? row.modelData.action.icon
                                    : row.kind === "window" ? "󰖯"
                                        : row.clip ? (row.clip.image ? "󰋩" : "󰅍")
                                        : (row.entry ? row.entry.name.charAt(0).toUpperCase() : "")
                                    font.bold: true
                                    color: row.kind === "calc" ? Theme.textReverse
                                    : row.kind === "action" && root.armed === row.modelData.action.id ? Theme.error : Theme.text
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Label {
                                Layout.fillWidth: true
                                text: row.kind === "calc" ? row.modelData.value
                                    : row.kind === "action" ? row.modelData.action.title
                                    : row.kind === "window" ? row.modelData.win.title
                                    : row.clip ? row.clip.text.replace(/\s+/g, " ").trim()
                                    : row.bind ? row.bind.label
                                    : (row.entry ? row.entry.name : "")
                                size: row.kind === "calc" ? Theme.fontLg : Theme.fontTitle
                                font.bold: row.selected && !row.clip
                                color: row.selected ? Theme.textBright : Theme.text
                                elide: Text.ElideRight
                            }
                            Label {
                                Layout.fillWidth: true
                                readonly property string sub: row.kind === "calc" ? "enter to copy"
                                    : row.kind === "action" ? (root.armed === row.modelData.action.id ? "press enter again to confirm" : row.modelData.action.group)
                                    : row.kind === "window" ? row.modelData.cls + (row.modelData.ws ? "  ·  workspace " + row.modelData.ws : "")
                                    : row.clip ? (row.clip.image ? "image · " + row.clip.info : row.clip.text.length + " chars")
                                    : row.bind ? row.bind.group + (row.bind.runnable ? "" : "  ·  key only")
                                    : row.entry ? (row.entry.genericName || row.entry.comment || "") : ""
                                visible: sub !== ""
                                text: sub
                                size: Theme.fontSm
                                color: Theme.subtext
                                elide: Text.ElideRight
                            }
                        }

                        Label {
                            visible: row.entry !== null && row.entry.runInTerminal
                            text: "󰆍"
                            size: Theme.fontBase
                            color: Theme.muted
                        }
                        IconButton {
                            visible: row.clip !== null && (row.selected || hov.containsMouse)
                            icon: "󰆴"
                            fg: Theme.error
                            onClicked: Svc.Clipboard.remove(row.clip)
                        }
                        Label {
                            visible: row.selected && !(row.bind && !row.bind.runnable)
                            text: "↵"
                            color: Theme.accent
                        }
                    }

                    MouseArea {
                        id: hov
                        anchors.fill: parent
                        z: -1
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: list.currentIndex = row.index
                        onClicked: root.activate(row.index)
                    }
                }
            }

            Label {
                anchors.centerIn: parent
                visible: list.count === 0
                text: root.mode === "clipboard"
                      ? (!Svc.Clipboard.available ? "cliphist isn't installed" : root.query ? "nothing matches" : "clipboard history is empty")
                      : root.mode === "keybinds" ? "no binds match"
                      : root.query.startsWith("=") ? "not an expression" : "no apps match “" + root.query + "”"
                size: Theme.fontBase
                color: Theme.muted
            }
        }

        // --- hints ---
        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.surface2 }
        Label {
            Layout.alignment: Qt.AlignHCenter
            text: root.mode === "clipboard" ? "↑↓ select    ↵  copy    shift+del  remove    alt+1-3  mode    esc  close"
                : root.mode === "keybinds" ? "↑↓ select    ↵  run    alt+1-3  mode    esc  close"
                : root.query.startsWith(">") ? "↑↓ select    ↵  run (power: twice)    esc  close"
                : root.query.startsWith("@") ? "↑↓ select    ↵  focus window    esc  close"
                : "↑↓ tab  select    ↵  launch    > actions    @ windows    = calc    esc  close"
            size: Theme.fontXs
            color: Theme.muted
        }
    }
}
