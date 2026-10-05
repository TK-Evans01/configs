import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services" as Svc

// Overview: commit frequency only. The GitHub tab has the rest.
Card {
    id: root

    visible: Settings.showGithub && Svc.Github.state_ !== "loading"

    CardHeader {
        icon: ""
        title: "GitHub"
        subtitle: Svc.Github.state_ === "ok" ? Svc.Github.total + " contributions this year" : Svc.Github.error
        accent: Svc.Github.state_ === "ok" ? Theme.catDev : Theme.error
        IconButton {
            icon: "󰅂"
            onClicked: Svc.Ui.tab = "github"
        }
    }

    ContributionGrid {
        id: grid
        visible: Svc.Github.days.length > 0
        Layout.fillWidth: true
    }

    Label {
        visible: Svc.Github.state_ === "ok"
        Layout.fillWidth: true
        text: grid.hovered ? grid.describe(grid.hovered)
            : "today " + Svc.Github.today + "   ·   streak " + Svc.Github.streak + "d   ·   this week " + Svc.Github.thisWeek
        size: Theme.fontSm
        color: grid.hovered ? Theme.textBright : Theme.subtext
    }
}
