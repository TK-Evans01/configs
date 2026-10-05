import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services" as Svc

// Session drawer (right edge): lock / log out / suspend / reboot / shut down.
// j/k or ↑/↓ move, Enter fires (keyboard is deliberate, no second press),
// Esc closes. With the mouse, power actions arm on the first click.
EdgePanel {
    id: root

    required property string screenName
    property int current: 0
    readonly property var actions: Svc.Desktop.actions

    wanted: Svc.Ui.isOpen("session", screenName)
    panelWidth: 300
    onDismissed: Svc.Ui.dismiss()
    onWantedChanged: if (wanted) { current = 0; armed = ""; }

    property string armed: ""
    Timer { id: disarm; interval: 3000; onTriggered: root.armed = "" }

    function fire(id) {
        Svc.Ui.close();
        Svc.Desktop.power(id);
    }

    keyTargets: [keys]
    Item {
        id: keys
        Keys.onPressed: e => {
            const n = root.actions.length;
            if (e.key === Qt.Key_J || e.key === Qt.Key_Down || e.key === Qt.Key_Tab) root.current = (root.current + 1) % n;
            else if (e.key === Qt.Key_K || e.key === Qt.Key_Up || e.key === Qt.Key_Backtab) root.current = (root.current - 1 + n) % n;
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) root.fire(root.actions[root.current].id);
            else return;
            e.accepted = true;
        }
    }

    content: ColumnLayout {
        spacing: Theme.spacing

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: Theme.spacing
            spacing: Theme.spacing
            Label { text: "󰐥"; size: Theme.fontLg; color: Theme.accent }
            ColumnLayout {
                spacing: 0
                Label { text: "SESSION"; font.bold: true; color: Theme.textBright }
                Label { text: Svc.Desktop.user + "@" + Svc.Sys.host; size: Theme.fontSm; color: Theme.subtext }
            }
        }

        Repeater {
            model: root.actions
            ListRow {
                required property var modelData
                required property int index
                readonly property bool isArmed: root.armed === modelData.id
                icon: modelData.icon
                iconColor: isArmed || modelData.id === "poweroff" ? Theme.error : (active ? Theme.accent : Theme.text)
                title: isArmed ? "click again to " + modelData.label.toLowerCase() : modelData.label
                accent: isArmed ? Theme.error : Theme.text
                active: root.current === index
                onHoveredChanged: if (hovered) root.current = index
                onClicked: {
                    if (modelData.id === "lock" || isArmed) root.fire(modelData.id);
                    else { root.armed = modelData.id; disarm.restart(); }
                }
            }
        }

        Item { Layout.fillHeight: true }
        Label {
            Layout.alignment: Qt.AlignHCenter
            text: "j k  move    ↵  select    esc  close"
            size: Theme.fontXs
            color: Theme.muted
        }
    }
}
