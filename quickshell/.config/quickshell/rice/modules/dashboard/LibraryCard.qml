import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services" as Svc

// spotify_player library: Liked Songs, playlists, saved albums. Click a row to
// play it (shuffle chip applies). Type to filter.
Card {
    id: root

    property bool shownTab: false
    property string kind: "playlists"           // playlists | albums
    readonly property string q: filter.text.trim().toLowerCase()

    Binding { target: Svc.Spotify; property: "wanted"; value: root.shownTab }

    readonly property var rows: {
        const src = kind === "albums"
            ? Svc.Spotify.albums.map(a => ({ id: a.id, title: a.name, sub: a.artist + (a.year ? "  ·  " + a.year : ""), album: true }))
            : Svc.Spotify.playlists.map(p => ({ id: p.id, title: p.name, sub: p.owner, album: false }));
        return q ? src.filter(r => (r.title + " " + r.sub).toLowerCase().indexOf(q) >= 0) : src;
    }

    CardHeader {
        icon: "󰲸"
        title: "Library"
        subtitle: Svc.Spotify.error || (Svc.Spotify.loading ? "loading…" : "")
        accent: Theme.purple
        IconButton {
            icon: "󰒝"
            checked: Svc.Spotify.shuffle
            onClicked: Svc.Spotify.shuffle = !Svc.Spotify.shuffle
        }
        IconButton { icon: "󰑓"; onClicked: Svc.Spotify.load() }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacing / 2
        IconButton {
            icon: "󰋑"
            text: "liked songs"
            fg: Theme.red
            onClicked: Svc.Spotify.playLiked()
        }
        IconButton {
            text: "playlists  " + Svc.Spotify.playlists.length
            checked: root.kind === "playlists"
            onClicked: root.kind = "playlists"
        }
        IconButton {
            text: "albums  " + Svc.Spotify.albums.length
            checked: root.kind === "albums"
            onClicked: root.kind = "albums"
        }
        // filter
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Theme.fontSize + Theme.spacing * 2
            color: Theme.surface0
            border.width: Theme.border
            border.color: filter.activeFocus ? Theme.accent : Theme.surface2
            Label {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacing
                anchors.verticalCenter: parent.verticalCenter
                visible: filter.text === ""
                text: "filter"
                size: Theme.fontSizeSmall
                color: Theme.muted
            }
            TextInput {
                id: filter
                anchors.fill: parent
                anchors.leftMargin: Theme.spacing
                anchors.rightMargin: Theme.spacing
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.textBright
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                clip: true
                Keys.onEscapePressed: text = ""
            }
        }
    }

    ListView {
        id: list
        Layout.fillWidth: true
        implicitHeight: Math.min(contentHeight, 300)
        clip: true
        spacing: 1
        boundsBehavior: Flickable.StopAtBounds
        model: root.rows

        delegate: DeviceRow {
            id: row
            required property var modelData
            width: ListView.view.width
            icon: modelData.album ? "󰀥" : "󰲸"
            accent: Theme.text
            title: modelData.title
            subtitle: modelData.sub
            onClicked: modelData.album ? Svc.Spotify.playAlbum(modelData.id) : Svc.Spotify.playPlaylist(modelData.id)
            Label {
                visible: row.hovered
                text: Svc.Spotify.shuffle ? "󰒝 ▶" : "▶"
                color: Theme.purple
            }
        }

        Label {
            anchors.centerIn: parent
            visible: list.count === 0 && !Svc.Spotify.loading
            text: Svc.Spotify.error ? "open spotify_player (SUPER+S), then 󰑓" : "nothing matches"
            size: Theme.fontSizeSmall
            color: Theme.muted
        }
    }
}
