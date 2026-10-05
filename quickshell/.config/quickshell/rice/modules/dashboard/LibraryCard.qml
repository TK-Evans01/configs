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
        subtitle: Svc.Spotify.error || ""
        accent: Theme.catMedia
        Spinner { visible: Svc.Spotify.loading; tint: Theme.catMedia }
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
            text: Svc.Spotify.startingId === "liked" ? "starting…" : "liked songs"
            fg: Theme.error
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
        TextField {
            id: filter
            placeholder: "filter"
            onKeyPressed: e => { if (e.key === Qt.Key_Escape && text !== "") { clear(); e.accepted = true; } }
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

        delegate: ListRow {
            id: row
            required property var modelData
            width: ListView.view.width
            icon: modelData.album ? "󰀥" : "󰲸"
            accent: Theme.text
            title: modelData.title
            subtitle: modelData.sub
            onClicked: modelData.album ? Svc.Spotify.playAlbum(modelData.id) : Svc.Spotify.playPlaylist(modelData.id)
            Label {
                readonly property bool starting: Svc.Spotify.startingId === row.modelData.id
                visible: row.hovered || starting
                text: starting ? "starting…" : (Svc.Spotify.shuffle ? "󰒝 ▶" : "▶")
                size: starting ? Theme.fontSm : Theme.fontMd
                color: Theme.catMedia
            }
        }

        Label {
            anchors.centerIn: parent
            visible: list.count === 0 && !Svc.Spotify.loading
            text: Svc.Spotify.error ? "open spotify_player (SUPER+S), then 󰑓" : "nothing matches"
            size: Theme.fontBase
            color: Theme.muted
        }
    }
}
