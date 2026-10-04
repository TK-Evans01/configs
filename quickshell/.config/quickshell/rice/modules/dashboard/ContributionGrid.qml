import QtQuick
import "../../config"
import "../../components"
import "../../services" as Svc

// GitHub contribution grid: week columns × weekday rows, as many weeks as fit
// (newest on the right), month labels on top, today outlined. `hovered` is the
// day under the mouse.
Item {
    id: grid

    property int cell: 11
    property int gap: 2
    property var hovered: null
    readonly property int step: cell + gap
    readonly property int labelH: Theme.fontSizeSmall
    implicitHeight: labelH + 7 * step

    readonly property var days: Svc.Github.days
    readonly property int firstDow: days.length ? days[0].date.getDay() : 0
    readonly property int totalWeeks: days.length ? Math.floor((days.length - 1 + firstDow) / 7) + 1 : 0
    readonly property int shownWeeks: Math.min(totalWeeks, Math.floor((width + gap) / step))
    readonly property int firstWeek: totalWeeks - shownWeeks
    readonly property var colors: [Theme.surface1, Qt.darker(Theme.greenDim, 1.4), Theme.greenDim, Theme.green, Theme.greenBright]

    Repeater {
        model: {
            const out = [];
            let last = -1;
            for (let i = 0; i < grid.days.length; i++) {
                const w = Math.floor((i + grid.firstDow) / 7);
                const m = grid.days[i].date.getMonth();
                if (w >= grid.firstWeek && m !== last && grid.days[i].date.getDate() <= 7)
                    out.push({ x: (w - grid.firstWeek) * grid.step, label: Qt.formatDate(grid.days[i].date, "MMM").toLowerCase() });
                last = m;
            }
            return out;
        }
        Label {
            required property var modelData
            x: modelData.x
            text: modelData.label
            size: Theme.fontSizeSmall - 4
            color: Theme.muted
        }
    }

    Repeater {
        model: grid.days.length
        Rectangle {
            required property int index
            readonly property var day: grid.days[index]
            readonly property int week: Math.floor((index + grid.firstDow) / 7)
            readonly property bool isToday: index === grid.days.length - 1
            visible: week >= grid.firstWeek
            x: (week - grid.firstWeek) * grid.step
            y: grid.labelH + day.date.getDay() * grid.step
            width: grid.cell
            height: grid.cell
            color: grid.colors[day.level]
            border.width: isToday || dayHov.containsMouse ? 1 : 0
            border.color: dayHov.containsMouse ? Theme.textBright : Theme.accent
            MouseArea {
                id: dayHov
                anchors.fill: parent
                hoverEnabled: true
                onContainsMouseChanged: grid.hovered = containsMouse ? parent.day : (grid.hovered === parent.day ? null : grid.hovered)
            }
        }
    }

    function describe(d) {
        return d.count + (d.count === 1 ? " contribution" : " contributions") + " on " + Qt.formatDate(d.date, "ddd dd MMM").toLowerCase();
    }
}
