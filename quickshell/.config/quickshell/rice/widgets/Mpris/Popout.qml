import QtQuick
import "../../config"
import "../../core" as Core
import "../Volume" as Vol

Item {
    id: root
    required property var service

    function fmt(sec) {
        const s = Math.max(0, Math.floor(sec));
        const m = Math.floor(s / 60);
        const r = s % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }

    Column {
        anchors.fill: parent
        spacing: 10

        Row {
            width: parent.width
            spacing: 10

            Rectangle {
                width: 72; height: 72
                color: Theme.bg2
                border.color: Theme.bg3
                border.width: 1
                Image {
                    anchors.fill: parent
                    anchors.margins: 1
                    source: root.service.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                    visible: root.service.artUrl !== ""
                }
            }

            Column {
                width: parent.width - 82
                spacing: 2
                Core.ScrollingText {
                    width: parent.width
                    maxWidth: parent.width
                    text: root.service.title || "(nothing playing)"
                    color: Theme.purpleBright
                    pixelSize: Theme.fontSize + 1
                    bold: true
                }
                Core.ScrollingText {
                    width: parent.width
                    maxWidth: parent.width
                    text: root.service.artist
                    color: Theme.purpleDim
                    visible: text !== ""
                }
                Core.ScrollingText {
                    width: parent.width
                    maxWidth: parent.width
                    text: root.service.album
                    color: Theme.grey
                    pixelSize: Theme.fontSize - 1
                    visible: text !== ""
                }
            }
        }

        Column {
            width: parent.width
            spacing: 2

            Rectangle {
                width: parent.width
                height: 6
                color: Theme.bg2
                border.color: Theme.bg3
                border.width: 1

                Rectangle {
                    width: root.service.length > 0 ? Math.max(0, Math.min(1, root.service.position / root.service.length)) * parent.width : 0
                    height: parent.height
                    color: Theme.purple
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: root.service.canSeek && root.service.length > 0
                    onClicked: mouse => {
                        const t = Math.max(0, Math.min(1, mouse.x / width));
                        root.service.seek(t * root.service.length);
                    }
                }
            }

            Item {
                width: parent.width
                height: endT.height
                Text {
                    anchors.left: parent.left
                    text: root.fmt(root.service.position)
                    color: Theme.purpleDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                }
                Text {
                    id: endT
                    anchors.right: parent.right
                    text: root.fmt(root.service.length)
                    color: Theme.purpleDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                }
            }
        }

        Row {
            width: parent.width
            spacing: 6

            Rectangle {
                width: (parent.width - 12) / 3
                height: 28
                color: prevH.hovered ? Theme.bg3 : Theme.bg2
                border.color: Theme.bg3; border.width: 1
                opacity: root.service.canPrev ? 1 : 0.4
                Text {
                    anchors.centerIn: parent
                    text: "\uf048"
                    color: Theme.purple
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
                HoverHandler { id: prevH }
                TapHandler { onTapped: if (root.service.canPrev) root.service.previous() }
            }

            Rectangle {
                width: (parent.width - 12) / 3
                height: 28
                color: playH.hovered ? Theme.bg3 : Theme.bg2
                border.color: Theme.bg3; border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: root.service.playing ? "\uf04c" : "\uf04b"
                    color: Theme.purple
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
                HoverHandler { id: playH }
                TapHandler { onTapped: root.service.togglePlay() }
            }

            Rectangle {
                width: (parent.width - 12) / 3
                height: 28
                color: nextH.hovered ? Theme.bg3 : Theme.bg2
                border.color: Theme.bg3; border.width: 1
                opacity: root.service.canNext ? 1 : 0.4
                Text {
                    anchors.centerIn: parent
                    text: "\uf051"
                    color: Theme.purple
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
                HoverHandler { id: nextH }
                TapHandler { onTapped: if (root.service.canNext) root.service.next() }
            }
        }

        Row {
            width: parent.width
            spacing: 6

            Rectangle {
                width: 42; height: 22
                color: shufH.hovered ? Theme.bg3 : Theme.bg2
                border.color: Theme.bg3; border.width: 1
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    anchors.centerIn: parent
                    text: "\uf074"
                    color: Theme.purple
                    opacity: root.service.shuffle ? 1 : 0.4
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
                HoverHandler { id: shufH }
                TapHandler { onTapped: root.service.toggleShuffle() }
            }

            Rectangle {
                width: 42; height: 22
                color: loopH.hovered ? Theme.bg3 : Theme.bg2
                border.color: Theme.bg3; border.width: 1
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    anchors.centerIn: parent
                    text: root.service.loop === 2 ? "\uf01e" : (root.service.loop === 1 ? "\uf0e2" : "\uf178")
                    color: Theme.purple
                    opacity: root.service.loop > 0 ? 1 : 0.4
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
                HoverHandler { id: loopH }
                TapHandler { onTapped: root.service.cycleLoop() }
            }

            Vol.Slider {
                width: parent.width - 96
                anchors.verticalCenter: parent.verticalCenter
                min: 0
                max: 100
                accentColor: Theme.purple
                value: Math.round(root.service.volume * 100)
                onCommit: p => root.service.setVolume(p / 100)
            }
        }
    }
}
