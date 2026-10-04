import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services" as Svc

// Now · next 24 hours · 7 days.
Item {
    id: root
    implicitHeight: col.implicitHeight

    readonly property var now: Svc.Weather.current
    readonly property var today: Svc.Weather.daily.length ? Svc.Weather.daily[0] : null

    // Range of the week, for the min–max bars.
    readonly property real weekMin: Svc.Weather.daily.reduce((m, d) => Math.min(m, d.min), 999)
    readonly property real weekMax: Svc.Weather.daily.reduce((m, d) => Math.max(m, d.max), -999)

    ColumnLayout {
        id: col
        width: parent.width
        spacing: Theme.pad

        Card {
            Layout.fillWidth: true
            visible: root.now === null
            Label {
                Layout.alignment: Qt.AlignHCenter
                text: Svc.Weather.loading ? "fetching weather…" : (Svc.Weather.error || "no data yet")
                color: Theme.muted
            }
            IconButton {
                Layout.alignment: Qt.AlignHCenter
                icon: "󰑓"
                text: "retry"
                onClicked: Svc.Weather.refresh()
            }
        }

        // --- now ---
        Card {
            Layout.fillWidth: true
            visible: root.now !== null

            CardHeader {
                icon: "󰍎"
                title: Settings.weatherPlace
                subtitle: "updated " + Qt.formatDateTime(Svc.Weather.updated, "HH:mm")
                accent: Theme.aqua
                IconButton {
                    icon: "󰑓"
                    enabledState: !Svc.Weather.loading
                    onClicked: Svc.Weather.refresh()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.pad * 2

                Label {
                    text: root.now ? Svc.Weather.icon(root.now.code, root.now.isDay) : ""
                    size: Theme.fontSizeHuge
                    color: root.now ? Svc.Weather.color(root.now.code, root.now.isDay) : Theme.muted
                }
                ColumnLayout {
                    spacing: 0
                    Label {
                        text: root.now ? Svc.Weather.fmtTemp(root.now.temp) + Svc.Weather.tempUnit.slice(1) : ""
                        size: Theme.fontSizeHuge - 22
                        color: Theme.textBright
                    }
                    Label {
                        text: root.now ? Svc.Weather.describe(root.now.code) : ""
                        color: Theme.text
                    }
                }
                Item { Layout.fillWidth: true }
                GridLayout {
                    columns: 2
                    columnSpacing: Theme.pad
                    rowSpacing: 2
                    component Stat: Label { size: Theme.fontSizeSmall; color: Theme.subtext }
                    component Val: Label { size: Theme.fontSizeSmall; color: Theme.text; Layout.alignment: Qt.AlignRight }
                    Stat { text: "feels like" }
                    Val { text: root.now ? Svc.Weather.fmtTemp(root.now.feels) : "" }
                    Stat { text: "high / low" }
                    Val { text: root.today ? Svc.Weather.fmtTemp(root.today.max) + " / " + Svc.Weather.fmtTemp(root.today.min) : "" }
                    Stat { text: "humidity" }
                    Val { text: root.now ? root.now.humidity + "%" : "" }
                    Stat { text: "wind" }
                    Val { text: root.now ? Math.round(root.now.wind) + " " + Svc.Weather.windUnit : "" }
                    Stat { text: "sun" }
                    Val {
                        text: root.today ? "󰖜 " + Qt.formatTime(root.today.sunrise, "HH:mm") + "  󰖛 " + Qt.formatTime(root.today.sunset, "HH:mm") : ""
                    }
                }
            }
        }

        // --- next 24 hours ---
        Card {
            Layout.fillWidth: true
            visible: Svc.Weather.hourly.length > 0
            CardHeader { icon: "󰥔"; title: "Next 24 hours"; accent: Theme.blue }

            Item {
                id: hours
                Layout.fillWidth: true
                implicitHeight: 150
                readonly property var list: Svc.Weather.hourly
                readonly property real lo: list.reduce((m, h) => Math.min(m, h.temp), 999)
                readonly property real hi: list.reduce((m, h) => Math.max(m, h.temp), -999)
                readonly property real colW: width / Math.max(1, list.length)

                Repeater {
                    model: hours.list
                    Item {
                        required property var modelData
                        required property int index
                        readonly property bool showLabel: index % 3 === 0
                        x: index * hours.colW
                        width: hours.colW
                        height: hours.height

                        // temperature column (taller = warmer within the day)
                        Rectangle {
                            readonly property real frac: hours.hi > hours.lo ? (modelData.temp - hours.lo) / (hours.hi - hours.lo) : 0.5
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 40 + (1 - frac) * 50
                            width: Math.max(2, hours.colW - 3)
                            height: 90 - (y - 40)
                            color: Svc.Weather.color(modelData.code, modelData.isDay)
                            opacity: 0.35 + 0.4 * frac
                        }
                        // rain chance tick along the bottom
                        Rectangle {
                            anchors.bottom: timeL.top
                            anchors.bottomMargin: 2
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.max(2, hours.colW - 3)
                            height: Math.round(10 * modelData.pop / 100)
                            color: Theme.blue
                        }
                        Label {
                            visible: parent.showLabel
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 0
                            text: Svc.Weather.icon(modelData.code, modelData.isDay)
                            size: Theme.fontSize
                            color: Svc.Weather.color(modelData.code, modelData.isDay)
                        }
                        Label {
                            visible: parent.showLabel
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 20
                            text: Svc.Weather.fmtTemp(modelData.temp)
                            size: Theme.fontSizeSmall - 2
                            color: Theme.text
                        }
                        Label {
                            id: timeL
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            text: parent.showLabel ? Qt.formatTime(modelData.time, "HH") : ""
                            size: Theme.fontSizeSmall - 3
                            color: Theme.muted
                        }
                    }
                }
            }
            Label {
                text: "bars: temperature  ·  blue ticks: chance of rain"
                size: Theme.fontSizeSmall - 3
                color: Theme.muted
            }
        }

        // --- 7 days ---
        Card {
            Layout.fillWidth: true
            visible: Svc.Weather.daily.length > 0
            CardHeader { icon: "󰃭"; title: "7 days"; accent: Theme.yellow }

            Repeater {
                model: Svc.Weather.daily
                RowLayout {
                    id: day
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: Theme.pad

                    Label {
                        Layout.preferredWidth: Theme.fontSizeSmall * 4
                        text: day.index === 0 ? "today" : Qt.formatDate(day.modelData.date, "ddd").toLowerCase()
                        size: Theme.fontSizeSmall
                        font.bold: day.index === 0
                        color: day.index === 0 ? Theme.accent : Theme.text
                    }
                    Label {
                        Layout.preferredWidth: Theme.fontSize * 1.5
                        text: Svc.Weather.icon(day.modelData.code, true)
                        color: Svc.Weather.color(day.modelData.code, true)
                    }
                    Label {
                        Layout.preferredWidth: Theme.fontSizeSmall * 4
                        text: day.modelData.pop > 0 ? "󰖌 " + day.modelData.pop + "%" : ""
                        size: Theme.fontSizeSmall - 2
                        color: Theme.blue
                    }
                    Label {
                        Layout.preferredWidth: Theme.fontSizeSmall * 3
                        horizontalAlignment: Text.AlignRight
                        text: Svc.Weather.fmtTemp(day.modelData.min)
                        size: Theme.fontSizeSmall
                        color: Theme.subtext
                    }
                    // min–max range on the week's scale
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 8
                        readonly property real span: Math.max(1, root.weekMax - root.weekMin)
                        Rectangle { anchors.fill: parent; color: Theme.surface1 }
                        Rectangle {
                            x: parent.width * (day.modelData.min - root.weekMin) / parent.span
                            width: Math.max(4, parent.width * (day.modelData.max - day.modelData.min) / parent.span)
                            height: parent.height
                            color: Theme.orange
                        }
                    }
                    Label {
                        Layout.preferredWidth: Theme.fontSizeSmall * 3
                        text: Svc.Weather.fmtTemp(day.modelData.max)
                        size: Theme.fontSizeSmall
                        color: Theme.textBright
                    }
                    Label {
                        Layout.preferredWidth: Theme.fontSizeSmall * 7
                        horizontalAlignment: Text.AlignRight
                        text: Svc.Weather.describe(day.modelData.code)
                        size: Theme.fontSizeSmall - 2
                        color: Theme.subtext
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
