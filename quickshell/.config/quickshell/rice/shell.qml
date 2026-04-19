import Quickshell
import QtQuick
import "core"

Scope {
    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData
            screenRef: modelData
        }
    }
}
