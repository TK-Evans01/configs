pragma Singleton
import QtQuick
import Quickshell

QtObject {
    readonly property int barHeight: 44

    // Prefix for long-running helpers: the kernel kills them when the shell
    // dies (restart, crash, kill), so they can't pile up as orphans.
    readonly property var tether: ["setpriv", "--pdeathsig", "TERM", "--"]

    // Label width caps (px) and carousel tuning for text that scrolls.
    readonly property int windowLabelWidth: 420
    readonly property int mediaLabelWidth: 260
    readonly property int scrollMsPerPx: 28
    readonly property int scrollGap: 48

    // Bar: optional items. Layout itself is fixed (left / center / right islands).
    readonly property bool showLauncher: true
    readonly property bool showMedia: true
    readonly property bool showSystem: true
    readonly property bool showTray: true
    readonly property bool showWeather: true
    readonly property bool showMail: true
    readonly property string terminal: "alacritty"

    // Music: spotify_player in the tmux session `musicSession`. Its MPRIS
    // identity is preferred by the bar (playerctl name: spotify_player).
    readonly property string musicPlayer: "spotify_player"
    readonly property string musicSession: "music"
    readonly property int spotifyLibraryMaxAgeH: 6   // library cache age before a background refetch
    // Same face SDDM shows (AccountsService convention).
    readonly property string avatar: Quickshell.env("HOME") + "/.face.icon"

    // Launcher
    readonly property int launcherWidth: 640
    readonly property int launcherRows: 9        // visible result rows
    readonly property int launcherFrequent: 6    // "frequent" shown on an empty query

    // Dashboard tabs, in order. Each id needs a component in DashboardWindow.
    readonly property var dashboardTabs: [
        { id: "overview", label: "Overview", icon: "󰕮" },
        { id: "media",    label: "Media",    icon: "󰝚" },
        { id: "system",   label: "System",   icon: "󰍛" },
        { id: "weather",  label: "Weather",  icon: "󰖐" },
        { id: "github",   label: "GitHub",   icon: "\uf09b" },
        { id: "docker",   label: "Docker",   icon: "󰡨" }
    ]
    readonly property int dashboardWidth: 900
    readonly property int quickSettingsWidth: 540
    readonly property int trayMenuWidth: 300

    // Weather (Open-Meteo, no key; only these coordinates are sent).
    readonly property string weatherPlace: "York, ME"
    readonly property real weatherLat: 43.1617
    readonly property real weatherLon: -70.6484
    readonly property bool weatherImperial: true      // °F + mph, else °C + km/h
    readonly property int weatherRefreshMin: 15

    // Proton Mail via Bridge (scripts/proton-mail.py; creds in
    // ~/.config/rice/proton-bridge.netrc). Bar icon is dimmed until set up.
    readonly property int mailRefreshSec: 120
    readonly property bool mailNotify: true                 // notify-send on new unread
    readonly property string mailUrl: "https://mail.proton.me/u/0/inbox"
    readonly property var bridgeCommand: ["protonmail-bridge", "--noninteractive"]   // background, after first sign-in

    // Proton Calendar share link (scripts/proton-calendar.py; link in
    // ~/.config/rice/proton-calendar.url). Hidden until configured.
    readonly property int calendarRefreshMin: 30
    readonly property string calendarUrl: "https://calendar.proton.me"

    // Screenshots (grimblast) and OCR (tesseract)
    readonly property string screenshotDir: Quickshell.env("HOME") + "/Pictures/Screenshots"
    readonly property string ocrLang: "eng"

    // Clipboard history (cliphist)
    readonly property int clipboardMax: 200

    // GitHub card on the Overview (gh CLI login)
    readonly property bool showGithub: true
    readonly property int githubRefreshMin: 10
    readonly property int githubRepos: 8        // most recently pushed repos (commits are read from these)
    readonly property int githubCommits: 8

    // Lock screen / idle
    readonly property int lockAfterMin: 10          // 0 = never auto-lock
    readonly property int screenOffAfterMin: 15     // 0 = never turn screens off
    readonly property bool lockBeforeSleep: true

    // Synced lyrics from lrclib.net (sends artist/title/album to it).
    readonly property bool lyrics: true

    // Night light tile: hyprsunset temperature when on.
    readonly property int nightLightTemp: 5500
    readonly property int nightLightGamma: 80     // % — matches hyprsunset.conf
    readonly property int nightLightMinTemp: 2500
    readonly property int nightLightMaxTemp: 6500

    // Samples kept for sparklines (Sys polls every 2s → 60s of history).
    readonly property int historySize: 30
}
