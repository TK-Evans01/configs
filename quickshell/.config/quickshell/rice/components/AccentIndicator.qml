import QtQuick
import "../config"

// Marks the selected / current item, in the theme's accent style:
//   underline (square) — a 2px bar along `edge` that grows in;
//   pill (round)       — a soft rounded fill behind the item.
// Fills its parent; declare it first so content draws on top.
Item {
    id: root

    property bool active: false
    property string edge: "bottom"   // "bottom" | "left"
    property color tint: Theme.accent
    property real inset: 4           // underline is this much shorter at each end

    anchors.fill: parent

    Rectangle {
        id: bar
        visible: Theme.accentStyle === "underline"
        readonly property bool horiz: root.edge === "bottom"
        anchors.bottom: horiz ? parent.bottom : undefined
        anchors.horizontalCenter: horiz ? parent.horizontalCenter : undefined
        anchors.left: horiz ? undefined : parent.left
        anchors.verticalCenter: horiz ? undefined : parent.verticalCenter
        width: horiz ? (root.active ? parent.width - root.inset * 2 : 0) : Theme.accentThickness
        height: horiz ? Theme.accentThickness : (root.active ? parent.height : 0)
        color: root.tint
        Behavior on width { enabled: bar.horiz; NumberAnimation { duration: Theme.anim; easing.type: Theme.easing } }
        Behavior on height { enabled: !bar.horiz; NumberAnimation { duration: Theme.anim; easing.type: Theme.easing } }
    }

    Rectangle {
        visible: Theme.accentStyle === "pill"
        anchors.fill: parent
        anchors.margins: 2
        radius: Theme.radiusSmall
        color: Qt.alpha(root.tint, 0.2)
        opacity: root.active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.anim } }
    }
}
