import QtQuick
import "../config"

// Group label inside a list ("FREQUENT", "ALL APPS · 33"): small caps, muted.
// Page titles use PageHeader, card titles CardHeader.
Label {
    property string label: ""
    text: label.toUpperCase()
    size: Theme.fontSm
    font.letterSpacing: 1
    color: Theme.accent
}
