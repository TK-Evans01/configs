import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../config"
import "../../components"
import "../../services" as Svc

// Packages: search repo + AUR, details, installed, updates, bundles.
// Every change shows its exact command first; "run" opens it in a terminal
// (Svc.Packages.installer) where you type your password and see pacman / yay.
ColumnLayout {
    id: root
    spacing: Theme.pad

    readonly property string tab: Svc.Packages.tab
    property var pending: null           // { title, cmd } waiting for "run"
    readonly property string open: Svc.Packages.openKey

    Component.onCompleted: { Svc.Packages.loadInstalled(); Svc.Packages.checkUpdates(); }

    function ask(spec) { pending = spec; }

    TabBar {
        tabs: [
            { id: "search", label: "search", icon: "󰍉" },
            { id: "installed", label: "installed", icon: "󰏓" },
            { id: "updates", label: "updates" + (Svc.Packages.updates ? " · " + (Svc.Packages.updates.repo.length + Svc.Packages.updates.aur.length) : ""), icon: "󰚰" },
            { id: "bundles", label: "bundles", icon: "󰆧" }
        ]
        current: root.tab
        onSelected: id => { Svc.Packages.tab = id; root.pending = null; }
    }

    // --- the command about to run (every change goes through here) ---
    Card {
        Layout.fillWidth: true
        visible: root.pending !== null || Svc.Packages.busy || Svc.Packages.lastResult !== ""
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing
            Label {
                text: Svc.Packages.busy ? "󰔟" : root.pending ? "" : "󰄬"
                size: Theme.fontLg
                color: Svc.Packages.busy ? Theme.pending : Theme.accent
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label {
                    Layout.fillWidth: true
                    text: Svc.Packages.busy ? "running in the terminal: " + Svc.Packages.running
                        : root.pending ? "will run in a terminal:" : Svc.Packages.lastResult
                    size: Theme.fontSm
                    color: Theme.subtext
                    elide: Text.ElideRight
                }
                Label {
                    Layout.fillWidth: true
                    visible: root.pending !== null && !Svc.Packages.busy
                    text: root.pending ? "$ " + root.pending.cmd : ""
                    size: Theme.fontBase
                    color: Theme.textBright
                    wrapMode: Text.WrapAnywhere
                }
            }
            IconButton {
                visible: root.pending !== null && !Svc.Packages.busy
                icon: "󰐊"
                text: "run in terminal"
                checked: true
                onClicked: { Svc.Packages.run(root.pending); root.pending = null; }
            }
            IconButton {
                visible: root.pending !== null && !Svc.Packages.busy
                icon: "󰅖"
                onClicked: root.pending = null
            }
            IconButton {
                visible: root.pending === null && !Svc.Packages.busy && Svc.Packages.lastResult !== ""
                icon: "󰅖"
                onClicked: Svc.Packages.lastResult = ""
            }
        }
    }

    // ============================ search ============================
    ColumnLayout {
        visible: root.tab === "search"
        Layout.fillWidth: true
        spacing: Theme.pad

        TextField {
            id: query
            prefix: "󰍉"
            placeholder: "search packages (repos + AUR)"
            onTextChanged: debounce.restart()
            onAccepted: { debounce.stop(); Svc.Packages.search(text); }
            Spinner { visible: Svc.Packages.searching }
            Timer { id: debounce; interval: 400; onTriggered: Svc.Packages.search(query.text) }
        }

        Repeater {
            model: Svc.Packages.results ? [
                { title: "Official repositories", items: Svc.Packages.results.repo },
                { title: "AUR", items: Svc.Packages.results.aur || [], error: Svc.Packages.results.aurError }
            ] : []
            Card {
                id: sect
                required property var modelData
                Layout.fillWidth: true
                visible: modelData.items.length > 0 || modelData.error === true
                CardHeader {
                    title: sect.modelData.title
                    subtitle: sect.modelData.error ? "AUR didn't answer" : sect.modelData.items.length + " matches"
                    accent: sect.modelData.title === "AUR" ? Theme.warning : Theme.accent
                }
                Label {
                    visible: sect.modelData.title === "AUR" && sect.modelData.items.length > 0
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    size: Theme.fontXs
                    color: Theme.muted
                    text: "AUR packages are user-submitted build scripts: check votes, maintainer and last update, and read the PKGBUILD yay shows you before building."
                }
                Repeater {
                    model: sect.modelData.items
                    PackageRow { required property var modelData; pkg: modelData }
                }
            }
        }
        Label {
            visible: Svc.Packages.results !== null && Svc.Packages.results.repo.length === 0 && (Svc.Packages.results.aur || []).length === 0
            text: "nothing matches"
            color: Theme.muted
        }
    }

    // =========================== installed ===========================
    ColumnLayout {
        id: instTab
        visible: root.tab === "installed"
        Layout.fillWidth: true
        spacing: Theme.pad
        readonly property var inst: Svc.Packages.installed

        Card {
            Layout.fillWidth: true
            visible: instTab.inst !== null
            RowLayout {
                spacing: Theme.gap
                Stat { value: instTab.inst ? instTab.inst.total : ""; label: "packages" }
                Stat { value: instTab.inst ? instTab.inst.explicit.length : ""; label: "you installed" }
                Stat { value: instTab.inst ? instTab.inst.foreign.length : ""; label: "from the AUR" }
                Stat { value: instTab.inst ? instTab.inst.orphans.length : ""; label: "orphans" }
            }
        }

        Card {
            Layout.fillWidth: true
            visible: instTab.inst !== null && instTab.inst.orphans.length > 0
            CardHeader {
                icon: "󰚃"
                title: "Orphans"
                subtitle: "installed as dependencies, nothing needs them now"
                accent: Theme.warning
                IconButton {
                    icon: "󰆴"
                    text: "remove all"
                    fg: Theme.error
                    onClicked: root.ask(Svc.Packages.orphansSpec(Svc.Packages.installed.orphans))
                }
            }
            Flow {
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: Svc.Packages.installed ? Svc.Packages.installed.orphans : []
                    Label { required property string modelData; text: modelData + "  "; size: Theme.fontSm; color: Theme.subtext }
                }
            }
        }

        Card {
            Layout.fillWidth: true
            visible: instTab.inst !== null
            CardHeader {
                icon: "󰏓"
                title: "You installed"
                subtitle: "explicitly installed; click for details"
                TextField { id: filt; Layout.preferredWidth: 220; Layout.fillWidth: false; placeholder: "filter" }
            }
            Repeater {
                model: Svc.Packages.installed
                    ? Svc.Packages.installed.explicit.filter(p => p.name.indexOf(filt.text.trim().toLowerCase()) >= 0).slice(0, 80) : []
                PackageRow {
                    required property var modelData
                    pkg: ({ name: modelData.name, version: modelData.version, repo: modelData.aur ? "aur" : "repo", installed: true, desc: "" })
                }
            }
        }

        Card {
            Layout.fillWidth: true
            CardHeader {
                icon: "󰆓"
                title: "Package cache"
                subtitle: Svc.Packages.cache ? (Svc.Packages.cache.bytes / 1073741824).toFixed(1) + " GB in /var/cache/pacman/pkg" : "not checked"
                IconButton { icon: "󰑓"; text: "check"; onClicked: Svc.Packages.loadCache() }
                IconButton {
                    visible: Svc.Packages.cache !== null && Svc.Packages.cache.paccache
                    icon: "󰃢"
                    text: "clean"
                    onClicked: root.ask(Svc.Packages.cacheSpec())
                }
            }
            Label {
                visible: Svc.Packages.cache !== null && Svc.Packages.cache.paccache
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                size: Theme.fontSm
                color: Theme.subtext
                text: Svc.Packages.cache && Svc.Packages.cache.keep2
                    ? "Clean keeps the last 2 versions of installed packages (frees " + Svc.Packages.cache.keep2.saves
                      + ") and drops cached uninstalled ones (" + Svc.Packages.cache.uninstalled.saves + ")." : ""
            }
        }
    }

    // ============================ updates ============================
    ColumnLayout {
        id: updTab
        visible: root.tab === "updates"
        Layout.fillWidth: true
        spacing: Theme.pad
        readonly property var up: Svc.Packages.updates
        readonly property int count: up ? up.repo.length + up.aur.length : 0

        Card {
            Layout.fillWidth: true
            CardHeader {
                icon: "󰚰"
                title: "Updates"
                subtitle: Svc.Packages.checkingUpdates ? "checking (syncs a temporary database, no root)"
                        : updTab.up === null ? "" : updTab.count + " available"
                Spinner { visible: Svc.Packages.checkingUpdates }
                IconButton { icon: "󰑓"; text: "check"; enabledState: !Svc.Packages.checkingUpdates; onClicked: Svc.Packages.checkUpdates() }
                IconButton {
                    icon: "󰚰"
                    text: "upgrade all"
                    checked: updTab.count > 0
                    enabledState: updTab.count > 0
                    onClicked: root.ask(Svc.Packages.upgradeSpec())
                }
            }
            Label {
                visible: updTab.up !== null && !updTab.up.checkupdates
                text: "checkupdates isn't installed (pacman-contrib, in Bundles › Maintenance) — repo updates can't be checked safely"
                size: Theme.fontSm
                color: Theme.warning
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            Label {
                visible: updTab.up !== null && !!updTab.up.lastUpgrade
                text: "last full upgrade: " + (updTab.up && updTab.up.lastUpgrade ? updTab.up.lastUpgrade.replace("T", " ").slice(0, 16) : "")
                size: Theme.fontSm
                color: Theme.subtext
            }
            Repeater {
                model: updTab.up ? updTab.up.repo.map(u => Object.assign({ aur: false }, u)).concat(updTab.up.aur.map(u => Object.assign({ aur: true }, u))) : []
                ListRow {
                    required property var modelData
                    compact: true
                    clickable: false
                    icon: modelData.aur ? "󰣇" : "󰏗"
                    iconColor: modelData.aur ? Theme.warning : Theme.text
                    title: modelData.name
                    note: modelData.from + "  →  " + modelData.to
                }
            }
        }

        // Read before upgrading: manual interventions are announced here.
        Card {
            id: newsCard
            Layout.fillWidth: true
            readonly property var news: Svc.Feeds.items.filter(i => i.feed === "Arch Linux").slice(0, 4)
            readonly property var since: updTab.up && updTab.up.lastUpgrade ? new Date(updTab.up.lastUpgrade) : null
            CardHeader {
                icon: "󰣇"
                title: "Arch news"
                subtitle: "read before upgrading — manual interventions show up here"
                accent: Theme.info
            }
            Repeater {
                model: newsCard.news
                ListRow {
                    required property var modelData
                    readonly property bool fresh: newsCard.since !== null && !!modelData.date && modelData.date > newsCard.since
                    icon: fresh ? "󰀦" : "󰎕"
                    iconColor: fresh ? Theme.warning : Theme.subtext
                    title: modelData.title
                    subtitle: (fresh ? "new since your last upgrade · " : "") + (modelData.date ? Qt.formatDate(modelData.date, "yyyy-MM-dd") : "")
                    onClicked: Svc.Feeds.open(modelData)
                }
            }
            Label {
                visible: newsCard.news.length === 0
                text: "no Arch news loaded (Feeds)"
                size: Theme.fontSm
                color: Theme.muted
            }
        }
    }

    // ============================ bundles ============================
    ColumnLayout {
        visible: root.tab === "bundles"
        Layout.fillWidth: true
        spacing: Theme.pad
        Repeater {
            model: Svc.Packages.bundles
            Card {
                id: b
                required property var modelData
                Layout.fillWidth: true
                readonly property var missing: modelData.packages.filter(p => !Svc.Packages.installedSet[p])
                CardHeader {
                    icon: b.modelData.icon
                    title: b.modelData.name
                    subtitle: b.missing.length === 0 ? "all installed" : b.missing.length + " of " + b.modelData.packages.length + " missing"
                    accent: b.missing.length === 0 ? Theme.success : Theme.accent
                    IconButton {
                        visible: b.missing.length > 0
                        icon: "󰇚"
                        text: "install missing"
                        onClicked: root.ask(Svc.Packages.installSpec(b.missing, !!b.modelData.aur))
                    }
                }
                Label { Layout.fillWidth: true; text: b.modelData.about; wrapMode: Text.Wrap; size: Theme.fontSm; color: Theme.subtext }
                Flow {
                    Layout.fillWidth: true
                    spacing: Theme.spacing
                    Repeater {
                        model: b.modelData.packages
                        Label {
                            required property string modelData
                            readonly property bool has: Svc.Packages.installedSet[modelData] === true
                            text: (has ? "󰄬 " : "󰄱 ") + modelData
                            size: Theme.fontSm
                            color: has ? Theme.success : Theme.text
                        }
                    }
                }
            }
        }
    }

    // A package row; click opens its details with install / remove.
    component PackageRow: ColumnLayout {
        id: row
        property var pkg: ({})
        readonly property string key: (pkg.repo === "aur" ? "aur" : "repo") + "/" + pkg.name
        readonly property bool shown: root.open === key
        readonly property var info: Svc.Packages.details[key] || null
        Layout.fillWidth: true
        spacing: 0

        ListRow {
            icon: row.pkg.repo === "aur" ? "󰣇" : "󰏗"
            iconColor: row.pkg.installed ? Theme.success : (row.pkg.repo === "aur" ? Theme.warning : Theme.text)
            title: row.pkg.name + "  " + (row.pkg.version || "")
            subtitle: row.pkg.desc || ""
            compact: !row.pkg.desc
            active: row.shown
            note: [row.pkg.repo, row.pkg.installed ? "installed" : "",
                   row.pkg.repo === "aur" ? "▲" + row.pkg.votes : "",
                   row.pkg.outOfDate ? "out of date" : ""].filter(x => x).join("  ·  ")
            onClicked: {
                const opening = !row.shown;
                Svc.Packages.openKey = opening ? row.key : "";
                if (opening) Svc.Packages.info(row.pkg.name, row.pkg.repo === "aur" ? "aur" : "repo");
            }
        }

        ColumnLayout {
            visible: row.shown
            Layout.fillWidth: true
            Layout.leftMargin: Theme.gap * 2
            Layout.bottomMargin: Theme.spacing
            spacing: 4
            Spinner { visible: row.shown && !row.info }
            Label { visible: !!(row.info && row.info.error); text: row.info ? row.info.error || "" : ""; color: Theme.error; size: Theme.fontSm }

            Repeater {
                model: row.info && !row.info.error ? [
                    ["repo", row.info.repo], ["version", row.info.version + (row.info.installedVersion && row.info.installedVersion !== row.info.version ? "  (installed " + row.info.installedVersion + ")" : "")],
                    ["size", row.info.size ? row.info.size + (row.info.download ? "  ·  download " + row.info.download : "") : ""],
                    ["votes", row.pkg.repo === "aur" || row.info.repo === "aur" ? row.info.votes + " votes  ·  popularity " + row.info.popularity : ""],
                    ["maintainer", row.info.repo === "aur" ? (row.info.maintainer || "⚠ orphaned (no maintainer)") : (row.info.packager || "")],
                    ["updated", row.info.updated ? row.info.updated + (row.info.outOfDate ? "  ·  ⚠ flagged out of date" : "") : (row.info.built || "")],
                    ["depends", (row.info.depends || []).join("  ")],
                    ["build deps", (row.info.makedepends || []).join("  ")],
                    ["optional", (row.info.optional || []).join("  ·  ")],
                    ["needed by", (row.info.requiredBy || []).join("  ")],
                    ["installed as", row.info.reason || ""],
                    ["license", row.info.license || ""],
                    ["url", row.info.url || ""]
                ].filter(f => f[1]) : []
                RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: Theme.pad
                    Label { Layout.preferredWidth: Theme.fontBase * 7; text: modelData[0]; size: Theme.fontSm; color: Theme.muted }
                    Label {
                        Layout.fillWidth: true
                        text: modelData[1]
                        size: Theme.fontSm
                        color: modelData[1].indexOf("⚠") >= 0 ? Theme.warning : Theme.text
                        wrapMode: Text.Wrap
                        maximumLineCount: 4
                        elide: Text.ElideRight
                    }
                }
            }
            RowLayout {
                visible: !!(row.info && !row.info.error)
                spacing: Theme.spacing
                IconButton {
                    visible: !row.pkg.installed
                    icon: "󰇚"
                    text: row.pkg.repo === "aur" ? "install (yay)" : "install"
                    checked: true
                    onClicked: root.ask(Svc.Packages.installSpec([row.pkg.name], row.pkg.repo === "aur"))
                }
                IconButton {
                    visible: row.pkg.installed
                    icon: "󰆴"
                    text: "remove"
                    fg: Theme.error
                    onClicked: root.ask(Svc.Packages.removeSpec([row.pkg.name]))
                }
                IconButton {
                    visible: !!(row.info && (row.info.aurPage || row.info.url))
                    icon: "󰖟"
                    text: row.info && row.info.aurPage ? "AUR page" : "website"
                    onClicked: Quickshell.execDetached(["xdg-open", row.info.aurPage || row.info.url])
                }
            }
        }
    }
}
