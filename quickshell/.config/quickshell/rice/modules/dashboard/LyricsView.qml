import QtQuick
import "../../config"
import "../../components"
import "../../services" as Svc

// Synced lyrics: the sung line lit and kept centered. Plain lyrics just scroll.
Item {
    id: root

    ListView {
        id: list
        anchors.fill: parent
        visible: Svc.Lyrics.lines.length > 0
        clip: true
        model: Svc.Lyrics.lines
        spacing: 4
        interactive: !Svc.Lyrics.synced
        currentIndex: Svc.Lyrics.currentIndex
        highlightFollowsCurrentItem: true
        preferredHighlightBegin: height / 2 - Theme.fontMd
        preferredHighlightEnd: height / 2 + Theme.fontMd
        highlightRangeMode: Svc.Lyrics.synced ? ListView.ApplyRange : ListView.NoHighlightRange
        highlightMoveDuration: Theme.animLong

        delegate: Label {
            required property var modelData
            required property int index
            readonly property bool current: index === Svc.Lyrics.currentIndex
            width: list.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: modelData.text || "♪"
            size: current ? Theme.fontMd : Theme.fontBase
            font.bold: current
            color: !Svc.Lyrics.synced ? Theme.text
                 : current ? Theme.catMediaBright
                 : index < Svc.Lyrics.currentIndex ? Theme.muted : Theme.subtext
            Behavior on color { ColorAnimation { duration: Theme.anim } }
        }
    }

    Label {
        anchors.centerIn: parent
        visible: !list.visible
        text: ({
            loading: "looking up lyrics…",
            instrumental: "♪ instrumental ♪",
            none: "no lyrics found",
            idle: Settings.lyrics ? "" : "lyrics off"
        })[Svc.Lyrics.status] || ""
        size: Theme.fontBase
        color: Theme.muted
    }
}
