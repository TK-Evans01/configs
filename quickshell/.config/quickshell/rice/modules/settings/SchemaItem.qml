import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"

// A schema item ({ key, type, label, help, min, max, step, unit }) as a
// SettingRow with the control its type needs. Changes are live overrides.
SettingRow {
    id: root

    required property var item
    readonly property var value: Settings[item.key]

    key: item.key
    label: item.label
    help: item.help || ""

    function commit(v) { Prefs.override(item.key, v); }

    Loader {
        sourceComponent: root.item.type === "bool" ? boolC
            : root.item.type === "enum" ? enumC
            : root.item.type === "int" ? intC
            : root.item.type === "list" ? listC
            : textC
    }

    Component {
        id: boolC
        Switch {
            checked: root.value === true
            onToggled: root.commit(!root.value)
        }
    }
    // enum: options [[value, label], …] as chips.
    Component {
        id: enumC
        RowLayout {
            spacing: 4
            Repeater {
                model: root.item.options || []
                IconButton {
                    required property var modelData
                    text: modelData[1]
                    checked: root.value === modelData[0]
                    onClicked: root.commit(modelData[0])
                }
            }
        }
    }
    Component {
        id: intC
        RowLayout {
            spacing: Theme.spacing
            IconButton {
                icon: "󰍴"
                size: Theme.controlHeight - 6
                onClicked: root.commit(Math.max(root.item.min, root.value - root.item.step))
            }
            Slider {
                Layout.preferredWidth: 240
                Layout.fillWidth: false
                value: root.value
                min: root.item.min
                max: root.item.max
                step: root.item.step
                suffix: root.item.unit ? " " + root.item.unit : ""
                showPercent: true
                valueWidth: Theme.fontBase * 6
                onMoved: p => root.commit(p)
            }
            IconButton {
                icon: "󰐕"
                size: Theme.controlHeight - 6
                onClicked: root.commit(Math.min(root.item.max, root.value + root.item.step))
            }
        }
    }
    // string / real: commit on Enter or when focus leaves.
    Component {
        id: textC
        TextField {
            id: tf
            implicitWidth: 300
            Layout.preferredWidth: 300
            Layout.fillWidth: false
            text: String(root.value)
            function apply() {
                if (root.item.type === "real") {
                    const v = parseFloat(text);
                    if (isNaN(v)) { text = Qt.binding(() => String(root.value)); return; }
                    root.commit(Math.max(root.item.min, Math.min(root.item.max, v)));
                } else if (text !== root.value) root.commit(text);
            }
            onAccepted: apply()
            input.onActiveFocusChanged: if (!input.activeFocus) apply()
            onKeyPressed: e => { if (e.key === Qt.Key_Escape) { text = Qt.binding(() => String(root.value)); e.accepted = true; } }
        }
    }
    // Lists of strings: chips with ×, plus an add field.
    Component {
        id: listC
        ColumnLayout {
            implicitWidth: 420
            Layout.preferredWidth: 420
            spacing: Theme.spacing
            Flow {
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: root.value
                    IconButton {
                        required property string modelData
                        text: modelData
                        icon: "󰅖"
                        size: Theme.controlHeight - 8
                        onClicked: root.commit(root.value.filter(x => x !== modelData))
                    }
                }
            }
            TextField {
                placeholder: "add…"
                prefix: "+"
                onAccepted: {
                    const v = text.trim();
                    if (v && root.value.indexOf(v) < 0) root.commit(root.value.concat([v]));
                    clear();
                }
            }
        }
    }
}
