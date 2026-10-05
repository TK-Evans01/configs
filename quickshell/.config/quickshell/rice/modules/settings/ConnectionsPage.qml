import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services" as Svc

// Third-party connections: state, test, connect (terminal flow or typed
// value), disconnect. Preview mode walks the flows without real accounts.
ColumnLayout {
    id: root
    spacing: Theme.pad

    Component.onCompleted: if (!Object.keys(Svc.Connectors.status).length) Svc.Connectors.checkAll()

    readonly property var groups: {
        const g = [];
        for (const d of Svc.Connectors.defs) {
            let e = g.find(x => x.name === d.group);
            if (!e) { e = { name: d.group, items: [] }; g.push(e); }
            e.items.push(d);
        }
        return g;
    }
    function stateColor(s) {
        return s === "ok" ? Theme.success : s === "error" ? Theme.error
             : s === "missing" ? Theme.warning : s === "checking" ? Theme.pending : Theme.muted;
    }
    function stateText(s) {
        return ({ ok: "connected", off: "not connected", missing: "not installed", error: "problem", checking: "checking" })[s] || "unknown";
    }

    Card {
        Layout.fillWidth: true
        SettingRow {
            label: "Preview mode"
            help: "Walk the connect flows safely: everything starts unconnected, connect / disconnect only show what they would run, typed values go to ~/.cache/rice/connectors-preview/."
            Switch {
                checked: Svc.Connectors.preview
                onToggled: Svc.Connectors.preview = !Svc.Connectors.preview
            }
        }
        RowLayout {
            spacing: Theme.spacing
            IconButton { icon: "󰑓"; text: "test all"; onClicked: Svc.Connectors.checkAll() }
            IconButton {
                visible: Svc.Connectors.preview
                icon: "󰦛"
                text: "reset preview"
                onClicked: Svc.Connectors.resetPreview()
            }
            Label {
                visible: Svc.Connectors.preview
                text: "PREVIEW — nothing real is changed"
                size: Theme.fontSm
                font.bold: true
                color: Theme.warning
            }
        }
    }

    Repeater {
        model: root.groups
        Card {
            id: grp
            required property var modelData
            Layout.fillWidth: true
            spacing: Theme.pad
            CardHeader { title: grp.modelData.name }
            Repeater {
                model: grp.modelData.items
                Connector { required property var modelData; def: modelData }
            }
        }
    }

    component Connector: ColumnLayout {
        id: c
        property var def: ({})
        readonly property var st: Svc.Connectors.status[def.id] || ({ state: "checking" })
        readonly property bool ok: st.state === "ok"
        property bool open: false          // the typed-value form
        property bool armedOut: false      // disconnect needs a second click
        Layout.fillWidth: true
        spacing: Theme.spacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.pad
            Label {
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: Theme.fontLg * 1.4
                text: c.def.icon
                size: Theme.fontLg
                color: root.stateColor(c.st.state)
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                spacing: 1
                RowLayout {
                    spacing: Theme.spacing
                    Label { text: c.def.name; size: Theme.fontTitle; color: Theme.textBright }
                    Label {
                        text: root.stateText(c.st.state)
                        size: Theme.fontXs
                        font.bold: true
                        color: root.stateColor(c.st.state)
                    }
                    Spinner { visible: c.st.state === "checking"; cell: 3 }
                }
                Label {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: c.st.detail || ""
                    size: Theme.fontSm
                    color: Theme.subtext
                    elide: Text.ElideRight
                }
                Label {
                    Layout.fillWidth: true
                    text: c.def.about
                    size: Theme.fontXs
                    color: Theme.muted
                    wrapMode: Text.Wrap
                }
            }
            IconButton { icon: "󰑓"; text: "test"; size: Theme.controlHeight - 6; onClicked: Svc.Connectors.check(c.def.id) }
            IconButton {
                visible: !!c.def.fields && !c.ok
                icon: c.open ? "󰅖" : "󰏫"
                text: c.open ? "cancel" : "enter"
                size: Theme.controlHeight - 6
                onClicked: c.open = !c.open
            }
            IconButton {
                visible: !!c.def.login
                icon: "󰍂"
                text: c.def.loginLabel || "connect"
                size: Theme.controlHeight - 6
                checked: !c.ok && c.st.state === "off" && !c.def.fields
                onClicked: Svc.Connectors.login(c.def.id)
            }
            IconButton {
                visible: !!c.def.logout && c.ok
                icon: "󰍃"
                text: c.armedOut ? "click again" : "disconnect"
                fg: Theme.error
                size: Theme.controlHeight - 6
                onClicked: {
                    if (!c.armedOut) { c.armedOut = true; disarm.restart(); return; }
                    c.armedOut = false;
                    Svc.Connectors.logout(c.def.id);
                }
                Timer { id: disarm; interval: 3000; onTriggered: c.armedOut = false }
            }
        }

        // Manual step (needs sudo): shown, never run.
        RowLayout {
            visible: !!c.def.manual && !c.ok
            Layout.leftMargin: Theme.fontLg * 1.4 + Theme.pad
            spacing: Theme.spacing
            Label { text: "run:"; size: Theme.fontSm; color: Theme.subtext }
            Label {
                Layout.fillWidth: true
                text: c.def.manual || ""
                size: Theme.fontSm
                color: Theme.text
                font.family: Theme.fontFamily
                elide: Text.ElideRight
            }
        }

        // Typed values. A field with `pair` asks for two (user + password).
        RowLayout {
            visible: c.open
            Layout.fillWidth: true
            Layout.leftMargin: Theme.fontLg * 1.4 + Theme.pad
            spacing: Theme.spacing
            readonly property var f: c.def.fields ? c.def.fields[0] : ({})
            TextField {
                id: v1
                placeholder: parent.f.label + (parent.f.placeholder ? " — " + parent.f.placeholder : "")
                input.echoMode: parent.f.secret ? TextInput.Password : TextInput.Normal
                onAccepted: parent.f.pair ? v2.focusInput() : go.clicked()
            }
            TextField {
                id: v2
                visible: !!parent.f.pair
                placeholder: parent.f.pair || ""
                input.echoMode: TextInput.Password
                onAccepted: go.clicked()
            }
            IconButton {
                id: go
                icon: "󰄬"
                text: Svc.Connectors.preview ? "save (preview)" : "save"
                enabledState: v1.text.trim() !== "" && (!parent.f.pair || v2.text !== "")
                onClicked: {
                    const f = parent.f;
                    Svc.Connectors.save(c.def.id, f.key, f.pair ? v1.text.trim() + "\n" + v2.text : v1.text.trim());
                    v1.clear(); v2.clear();
                    c.open = false;
                }
            }
        }

        Label {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.fontLg * 1.4 + Theme.pad
            visible: !!c.st.note
            text: "› " + (c.st.note || "")
            size: Theme.fontSm
            color: Svc.Connectors.preview ? Theme.warning : Theme.accent
            wrapMode: Text.Wrap
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.surface1 }
    }
}
