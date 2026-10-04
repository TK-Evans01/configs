import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services" as Svc

// Profile + full-year grid · recent commits · repositories · open work.
Item {
    id: root
    implicitHeight: col.implicitHeight
    readonly property real half: (width - Theme.pad) / 2

    // One clickable line: tag, text, right-hand note.
    component Line: Rectangle {
        id: line
        property string tag: ""
        property color tagColor: Theme.aqua
        property string text: ""
        property string note: ""
        property string url: ""
        Layout.fillWidth: true
        implicitHeight: lrow.implicitHeight + 6
        color: lhov.containsMouse ? Theme.surface1 : "transparent"
        RowLayout {
            id: lrow
            anchors.fill: parent
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            spacing: Theme.spacing
            Label {
                Layout.preferredWidth: Theme.fontSizeSmall * 8
                visible: line.tag !== ""
                text: line.tag
                size: Theme.fontSizeSmall - 2
                color: line.tagColor
                elide: Text.ElideRight
            }
            Label {
                Layout.fillWidth: true
                text: line.text
                size: Theme.fontSizeSmall - 1
                color: lhov.containsMouse ? Theme.textBright : Theme.text
                elide: Text.ElideRight
            }
            Label {
                text: line.note
                size: Theme.fontSizeSmall - 2
                color: Theme.subtext
            }
        }
        MouseArea {
            id: lhov
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: line.url ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (line.url) { Svc.Ui.close(); Svc.Github.open(line.url); }
        }
    }
    component Stat: ColumnLayout {
        property string value: ""
        property string label: ""
        spacing: 0
        Label { text: parent.value; size: Theme.fontSizeLarge; color: Theme.textBright }
        Label { text: parent.label; size: Theme.fontSizeSmall - 3; color: Theme.subtext }
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: Theme.pad

        Card {
            Layout.fillWidth: true
            visible: Svc.Github.state_ !== "ok"
            Label {
                text: Svc.Github.state_ === "loading" ? "loading…" : "gh: " + Svc.Github.error + "  (run gh auth login)"
                color: Theme.muted
            }
        }

        // --- profile + year ---
        Card {
            Layout.fillWidth: true
            visible: Svc.Github.state_ === "ok"
            CardHeader {
                icon: ""
                title: Svc.Github.name
                subtitle: "@" + Svc.Github.login + "  ·  updated " + Qt.formatTime(Svc.Github.updated, "HH:mm")
                accent: Theme.green
                IconButton { icon: "󰑓"; onClicked: Svc.Github.refresh() }
                IconButton { icon: "󰖟"; text: "profile"; onClicked: { Svc.Ui.close(); Svc.Github.openProfile(); } }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.pad * 3
                Stat { value: Svc.Github.total; label: "this year" }
                Stat { value: Svc.Github.today; label: "today" }
                Stat { value: Svc.Github.thisWeek; label: "this week" }
                Stat { value: Svc.Github.streak + "d"; label: "streak" }
                Stat { value: Svc.Github.longestStreak + "d"; label: "longest" }
                Stat { value: Svc.Github.repoCount; label: "repos" }
                Stat { value: Svc.Github.followers + " / " + Svc.Github.following; label: "followers / ing" }
                Item { Layout.fillWidth: true }
            }
            ContributionGrid {
                id: year
                Layout.fillWidth: true
                Layout.topMargin: Theme.spacing
                cell: 12
            }
            Label {
                text: year.hovered ? year.describe(year.hovered)
                    : Svc.Github.busiest.date ? "busiest day: " + year.describe(Svc.Github.busiest) : ""
                size: Theme.fontSizeSmall - 1
                color: year.hovered ? Theme.textBright : Theme.subtext
            }
        }

        RowLayout {
            visible: Svc.Github.state_ === "ok"
            spacing: Theme.pad

            // --- recent commits ---
            Card {
                Layout.preferredWidth: root.half
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignTop
                CardHeader { icon: "󰜘"; title: "Recent commits"; accent: Theme.aqua }
                Repeater {
                    model: Svc.Github.commits
                    Line {
                        required property var modelData
                        tag: (modelData.private ? "󰌾 " : "") + modelData.repo
                        text: modelData.message
                        note: Svc.Github.age(modelData.date)
                        url: modelData.url
                    }
                }
                Item { Layout.fillHeight: true }
            }

            // --- repositories ---
            Card {
                Layout.preferredWidth: root.half
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignTop
                CardHeader { icon: "󰳏"; title: "Repositories"; subtitle: Svc.Github.repoCount + " total"; accent: Theme.yellow }
                Repeater {
                    model: Svc.Github.repos
                    Rectangle {
                        id: repo
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: rcol.implicitHeight + 6
                        color: rhov.containsMouse ? Theme.surface1 : "transparent"
                        ColumnLayout {
                            id: rcol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 4
                            anchors.rightMargin: 4
                            spacing: 0
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacing
                                Label {
                                    Layout.fillWidth: true
                                    text: (repo.modelData.private ? "󰌾 " : "") + repo.modelData.name
                                    size: Theme.fontSizeSmall
                                    color: rhov.containsMouse ? Theme.textBright : Theme.text
                                    elide: Text.ElideRight
                                }
                                Rectangle { visible: repo.modelData.lang !== ""; width: 8; height: 8; color: repo.modelData.langColor }
                                Label { visible: repo.modelData.lang !== ""; text: repo.modelData.lang.toLowerCase(); size: Theme.fontSizeSmall - 3; color: Theme.subtext }
                                Label { text: "★" + repo.modelData.stars; size: Theme.fontSizeSmall - 3; color: Theme.yellow }
                                Label { text: Svc.Github.age(repo.modelData.pushed); size: Theme.fontSizeSmall - 3; color: Theme.muted }
                            }
                            Label {
                                Layout.fillWidth: true
                                visible: repo.modelData.description !== ""
                                text: repo.modelData.description
                                size: Theme.fontSizeSmall - 3
                                color: Theme.muted
                                elide: Text.ElideRight
                            }
                        }
                        MouseArea {
                            id: rhov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { Svc.Ui.close(); Svc.Github.open(repo.modelData.url); }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }

        // --- open work ---
        Card {
            Layout.fillWidth: true
            visible: Svc.Github.state_ === "ok"
            CardHeader {
                icon: "󰓂"
                title: "Open"
                subtitle: Svc.Github.prCount + " pull requests  ·  " + Svc.Github.reviewCount + " review requests  ·  "
                          + Svc.Github.issueCount + " issues"
                accent: Theme.purple
                IconButton {
                    icon: "󰂚"
                    text: Svc.Github.notifications + (Svc.Github.notifications === 1 ? " notification" : " notifications")
                    fg: Svc.Github.notifications > 0 ? Theme.accent : Theme.text
                    onClicked: { Svc.Ui.close(); Svc.Github.openNotifications(); }
                }
            }
            Repeater {
                model: Svc.Github.reviews
                Line { required property var modelData; tag: "󰈈 review"; tagColor: Theme.orange
                       text: modelData.repo.split("/").pop() + " #" + modelData.number + "  " + modelData.title
                       note: Svc.Github.age(modelData.updated); url: modelData.url }
            }
            Repeater {
                model: Svc.Github.prs
                Line { required property var modelData; tag: modelData.draft ? "󰓂 draft" : "󰓂 pr"; tagColor: Theme.purple
                       text: modelData.repo.split("/").pop() + " #" + modelData.number + "  " + modelData.title
                       note: Svc.Github.age(modelData.updated); url: modelData.url }
            }
            Repeater {
                model: Svc.Github.issues
                Line { required property var modelData; tag: "󰐗 issue"; tagColor: Theme.green
                       text: modelData.repo.split("/").pop() + " #" + modelData.number + "  " + modelData.title
                       note: Svc.Github.age(modelData.updated); url: modelData.url }
            }
            Label {
                visible: Svc.Github.prCount + Svc.Github.issueCount + Svc.Github.reviewCount === 0
                text: "nothing open — all clear"
                size: Theme.fontSizeSmall
                color: Theme.muted
            }
        }
    }
}
