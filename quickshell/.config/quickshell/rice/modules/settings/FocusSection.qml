import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../config"
import "../../components"
import "../../services" as Svc

// Settings › Focus: site-blocking setup + profile editor.
ColumnLayout {
    id: root
    spacing: Theme.pad

    readonly property string setupCmd: "sudo sh -c 'set -e; R=" + Quickshell.shellDir + "/scripts; "
        + "install -o root -g root -m 0755 \"$R/rice-focus-dns\" /usr/local/bin/rice-focus-dns; "
        + "install -o root -g root -m 0440 \"$R/rice-focus.sudoers\" /etc/sudoers.d/rice-focus; "
        + "visudo -cf /etc/sudoers.d/rice-focus || { rm -f /etc/sudoers.d/rice-focus; exit 1; }'"

    function setProfiles(list) { Prefs.override("focusProfiles", list); }
    function patch(i, change) {
        setProfiles(Settings.focusProfiles.map((p, j) => j === i ? Object.assign({}, p, change) : p));
    }

    // --- site blocking setup ---
    Card {
        Layout.fillWidth: true
        CardHeader {
            icon: "󰖟"
            title: "Site blocking"
            subtitle: Svc.Focus.helper === "ready" ? "ready" : "not set up"
            accent: Svc.Focus.helper === "ready" ? Theme.success : Theme.warning
            IconButton { icon: "󰑓"; text: "check"; onClicked: Svc.Focus._checkStatus() }
        }
        Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            size: Theme.fontSm
            color: Theme.subtext
            text: "A small root helper points the profile's site names at 0.0.0.0 for the session (every app, not just Firefox), and a root timer lifts it at the end even if the shell is gone. It can only block names, never redirect them; updates, VPN, Proton and GitHub are protected. One-time setup (re-run after updating the helper):"
        }
        RowLayout {
            Layout.fillWidth: true
            visible: Svc.Focus.helper !== "ready"
            spacing: Theme.spacing
            Label {
                Layout.fillWidth: true
                text: root.setupCmd
                size: Theme.fontXs
                color: Theme.textBright
                wrapMode: Text.WrapAnywhere
            }
            IconButton {
                icon: "󰆏"
                text: "copy"
                onClicked: Quickshell.execDetached(["wl-copy", root.setupCmd])
            }
        }
        Label {
            visible: Svc.Focus.siteNote !== ""
            Layout.fillWidth: true
            text: "› " + Svc.Focus.siteNote
            size: Theme.fontSm
            color: Theme.subtext
            wrapMode: Text.Wrap
        }
        Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            size: Theme.fontXs
            color: Theme.muted
            text: "Blocks apply to new connections: an already-open tab keeps working until reloaded, and Firefox may cache a name for up to 2 minutes."
        }
    }

    // --- profiles ---
    Repeater {
        model: Settings.focusProfiles
        Card {
            id: pc
            required property var modelData
            required property int index
            Layout.fillWidth: true
            spacing: Theme.spacing
            CardHeader {
                icon: pc.modelData.icon || "󰽥"
                title: pc.modelData.label
                subtitle: pc.modelData.id === Settings.focusDefault ? "default" : ""
                accent: Theme.catTime
                IconButton {
                    visible: pc.modelData.id !== Settings.focusDefault
                    text: "make default"
                    onClicked: Prefs.override("focusDefault", pc.modelData.id)
                }
                IconButton {
                    icon: "󰆴"
                    fg: Theme.error
                    enabledState: Settings.focusProfiles.length > 1
                    onClicked: root.setProfiles(Settings.focusProfiles.filter((p, j) => j !== pc.index))
                }
            }
            SettingRow {
                label: "Name"
                TextField {
                    Layout.preferredWidth: 220
                    Layout.fillWidth: false
                    text: pc.modelData.label
                    onAccepted: if (text.trim()) root.patch(pc.index, { label: text.trim() })
                }
            }
            Repeater {
                model: [["minutes", "Focus", 5, 240, 5, "min"], ["breakMin", "Break", 0, 60, 1, "min"], ["rounds", "Rounds", 1, 8, 1, ""]]
                SettingRow {
                    required property var modelData
                    label: modelData[1]
                    IconButton { icon: "󰍴"; size: Theme.controlHeight - 6; onClicked: root.patch(pc.index, { [modelData[0]]: Math.max(modelData[2], pc.modelData[modelData[0]] - modelData[4]) }) }
                    Label { Layout.preferredWidth: Theme.fontBase * 5; horizontalAlignment: Text.AlignHCenter; text: pc.modelData[modelData[0]] + (modelData[5] ? " " + modelData[5] : "") }
                    IconButton { icon: "󰐕"; size: Theme.controlHeight - 6; onClicked: root.patch(pc.index, { [modelData[0]]: Math.min(modelData[3], pc.modelData[modelData[0]] + modelData[4]) }) }
                }
            }
            SettingRow {
                label: "Notifications"
                Repeater {
                    model: [["off", "as usual"], ["focus", "critical only"], ["total", "hold all"]]
                    IconButton { required property var modelData; text: modelData[1]; checked: (pc.modelData.dnd || "off") === modelData[0]; onClicked: root.patch(pc.index, { dnd: modelData[0] }) }
                }
            }
            SettingRow {
                label: "Sites"
                help: Svc.Focus.hostsFor(pc.modelData).length + " names"
                Flow {
                    Layout.preferredWidth: 400
                    spacing: 4
                    Repeater {
                        model: Svc.Focus.bundles
                        IconButton {
                            required property var modelData
                            readonly property bool on: (pc.modelData.bundles || []).indexOf(modelData.id) >= 0
                            text: modelData.name
                            checked: on
                            size: Theme.controlHeight - 8
                            onClicked: root.patch(pc.index, { bundles: on ? pc.modelData.bundles.filter(b => b !== modelData.id) : (pc.modelData.bundles || []).concat([modelData.id]) })
                        }
                    }
                }
            }
            SettingRow {
                label: "Extra sites"
                help: "exact host names, e.g. www.example.com"
                ColumnLayout {
                    Layout.preferredWidth: 400
                    Flow {
                        Layout.fillWidth: true
                        spacing: 4
                        Repeater {
                            model: pc.modelData.sites || []
                            IconButton {
                                required property string modelData
                                text: modelData; icon: "󰅖"; size: Theme.controlHeight - 8
                                onClicked: root.patch(pc.index, { sites: pc.modelData.sites.filter(s => s !== modelData) })
                            }
                        }
                    }
                    TextField {
                        placeholder: "add a host…"
                        prefix: "+"
                        onAccepted: {
                            const h = text.trim().toLowerCase().replace(/^https?:\/\//, "").split("/")[0];
                            if (/^([a-z0-9-]+\.)+[a-z]{2,}$/.test(h)) root.patch(pc.index, { sites: (pc.modelData.sites || []).concat([h]) });
                            clear();
                        }
                    }
                }
            }
            SettingRow {
                label: "Apps"
                help: "windows whose class matches are hidden (or closed) while focusing"
                ColumnLayout {
                    Layout.preferredWidth: 400
                    Repeater {
                        model: pc.modelData.apps || []
                        RowLayout {
                            required property var modelData
                            required property int index
                            Label { Layout.fillWidth: true; text: modelData.re; size: Theme.fontSm; elide: Text.ElideRight }
                            Repeater {
                                model: ["hide", "close"]
                                IconButton {
                                    required property string modelData
                                    text: modelData
                                    size: Theme.controlHeight - 8
                                    checked: parent.modelData.action === modelData
                                    onClicked: {
                                        const apps = pc.modelData.apps.map((a, j) => j === parent.index ? Object.assign({}, a, { action: modelData }) : a);
                                        root.patch(pc.index, { apps: apps });
                                    }
                                }
                            }
                            IconButton {
                                icon: "󰅖"
                                size: Theme.controlHeight - 8
                                onClicked: root.patch(pc.index, { apps: pc.modelData.apps.filter((a, j) => j !== parent.index) })
                            }
                        }
                    }
                    TextField {
                        placeholder: "window class, e.g. steam  (regex ok)"
                        prefix: "+"
                        onAccepted: {
                            const v = text.trim();
                            if (v) root.patch(pc.index, { apps: (pc.modelData.apps || []).concat([{ re: v.indexOf("^") === 0 ? v : "^(" + v + ")$", action: "hide" }]) });
                            clear();
                        }
                    }
                }
            }
        }
    }

    IconButton {
        icon: "󰐕"
        text: "new profile"
        onClicked: root.setProfiles(Settings.focusProfiles.concat([{
            id: "p" + Date.now().toString(36), label: "New profile", icon: "󰽥", minutes: 30, breakMin: 5, rounds: 1,
            bundles: [], sites: [], apps: [], dnd: "focus", playlist: "" }]))
    }
}
