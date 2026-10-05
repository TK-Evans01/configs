import QtQuick
import "../config"
import "../services" as Svc

// Power actions. Each arms on the first click (turns red) and fires on a
// second click within 3 s; ids in `instant` fire straight away.
Row {
    id: root

    property var actions: Svc.Desktop.actions     // [{ id, label, icon }]
    property var instant: ["lock"]
    property string armed: ""                      // id waiting for its second click
    property string hoveredLabel: ""               // lower-case label under the pointer
    signal fire(string id)

    spacing: 4
    onVisibleChanged: armed = ""

    Timer {
        id: disarm
        interval: 3000
        onTriggered: root.armed = ""
    }

    Repeater {
        model: root.actions
        IconButton {
            required property var modelData
            readonly property bool isArmed: root.armed === modelData.id
            icon: modelData.icon
            fg: isArmed ? Theme.textReverse : (modelData.id === "poweroff" ? Theme.error : Theme.text)
            color: isArmed ? Theme.error : (hovered ? Theme.surface2 : Theme.surface1)
            onHoveredChanged: {
                const l = modelData.label.toLowerCase();
                root.hoveredLabel = hovered ? l : (root.hoveredLabel === l ? "" : root.hoveredLabel);
            }
            onClicked: {
                if (root.instant.indexOf(modelData.id) >= 0 || isArmed) {
                    root.armed = "";
                    root.fire(modelData.id);
                } else {
                    root.armed = modelData.id;
                    disarm.restart();
                }
            }
        }
    }
}
