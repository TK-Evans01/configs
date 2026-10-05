import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services" as Svc

// Focus mode: pick a profile (and length), start; while running, the
// countdown and what's blocked. A started session can't be stopped — it runs
// out. Profiles are edited in Settings › Focus.
ColumnLayout {
    id: page
    spacing: Theme.pad
    property bool embedded: false
    property string pick: Settings.focusDefault
    property int minutes: 0          // 0 = the profile's own length
    readonly property var picked: Settings.focusProfiles.find(p => p.id === pick) || Settings.focusProfiles[0]
    readonly property var fs: Svc.Focus

    PageHeader {
        visible: !page.embedded
        icon: page.fs.active ? "󰌾" : "󰔟"
        title: "Focus"
        subtitle: page.fs.active ? (page.fs.profile ? page.fs.profile.label : "") + "  ·  until " + page.fs.endsText : "block distractions for a while"
        onBackClicked: Svc.Ui.back()
    }

    // --- running ---
    Card {
        Layout.fillWidth: true
        visible: page.fs.active
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gap
            Label {
                text: page.fs.remainingText
                size: Theme.fontXl
                font.bold: true
                color: page.fs.focusing ? Theme.catTime : Theme.subtext
            }
            ColumnLayout {
                spacing: 2
                Label {
                    text: page.fs.focusing ? "FOCUS" : "BREAK"
                    font.bold: true
                    color: page.fs.focusing ? Theme.textBright : Theme.subtext
                }
                Label {
                    text: "round " + page.fs.round + " of " + (page.fs.profile ? page.fs.profile.rounds : 1) + "  ·  ends " + page.fs.endsText
                    size: Theme.fontSm
                    color: Theme.subtext
                }
            }
        }
        ListRow {
            clickable: false
            compact: true
            icon: "󰖟"
            title: page.fs.helper === "ready"
                ? (page.fs.blockedCount ? page.fs.blockedCount + " site names blocked" : (page.fs.focusing ? "no sites blocked" : "sites open (break)"))
                : "site blocking isn't set up"
            note: page.fs.helper === "ready" ? "" : "Settings › Focus"
            iconColor: page.fs.helper === "ready" ? Theme.success : Theme.warning
        }
        ListRow {
            clickable: false
            compact: true
            visible: Object.keys(page.fs.hidden).length > 0
            icon: "󰘔"
            title: Object.keys(page.fs.hidden).length + " windows hidden until the end"
        }
        ListRow {
            clickable: false
            compact: true
            icon: "󰂛"
            title: page.fs.quiet === "total" ? "notifications held" : page.fs.quiet === "focus" ? "only critical notifications" : "notifications as usual"
        }

        Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            size: Theme.fontSm
            color: Theme.subtext
            text: "No stopping early: this session ends at " + page.fs.endsText + (page.fs.profile && page.fs.profile.rounds > page.fs.round ? " (then the next round)" : "") + "."
        }
    }

    // --- start ---
    Card {
        Layout.fillWidth: true
        visible: !page.fs.active
        CardHeader { icon: "󰔟"; title: "Start"; accent: Theme.catTime }
        Repeater {
            model: Settings.focusProfiles
            ListRow {
                required property var modelData
                icon: modelData.icon || "󰽥"
                title: modelData.label
                subtitle: modelData.minutes + " min" + (modelData.rounds > 1 ? " × " + modelData.rounds + " · " + modelData.breakMin + " min breaks" : "")
                          + "  ·  " + Svc.Focus.hostsFor(modelData).length + " site names"
                          + ((modelData.apps || []).length ? "  ·  apps" : "")
                active: page.pick === modelData.id
                onClicked: { page.pick = modelData.id; page.minutes = 0; }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing
            Label { text: "length"; size: Theme.fontSm; color: Theme.subtext }
            IconButton { icon: "󰍴"; size: Theme.controlHeight - 6; onClicked: page.minutes = Math.max(5, (page.minutes || page.picked.minutes) - 5) }
            Label { text: (page.minutes || page.picked.minutes) + " min"; font.bold: true }
            IconButton { icon: "󰐕"; size: Theme.controlHeight - 6; onClicked: page.minutes = Math.min(480, (page.minutes || page.picked.minutes) + 5) }
            Item { Layout.fillWidth: true }
            IconButton {
                icon: "󰐊"
                text: "start " + page.picked.label.toLowerCase()
                checked: true
                onClicked: page.fs.start(page.pick, page.minutes)
            }
        }
        Label {
            visible: page.fs.helper !== "ready"
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            size: Theme.fontSm
            color: Theme.warning
            text: "Site blocking needs a one-time setup (Settings › Focus). Apps and notifications work without it."
        }
    }
}
