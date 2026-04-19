import QtQuick
import "../../core"
import "../../config"

Widget {
    id: clock

    property string current: format()
    label: current

    function format() {
        return Qt.formatDateTime(new Date(), "ddd MMM dd  HH:mm");
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clock.current = clock.format()
    }
}
