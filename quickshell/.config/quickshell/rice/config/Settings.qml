pragma Singleton
import QtQuick
import Quickshell

// Every tunable value reads Prefs.get(key, default): the settings window
// stores overrides in prefs.json and they apply live. Internal plumbing
// (tether, music/bridge commands, dashboard tab ids) stays constant.
QtObject {
    readonly property int barHeight: Prefs.get("barHeight", 44)

    // Prefix for long-running helpers: the kernel kills them when the shell
    // dies (restart, crash, kill), so they can't pile up as orphans.
    readonly property var tether: ["setpriv", "--pdeathsig", "TERM", "--"]

    // Label width caps (px) and carousel tuning for text that scrolls.
    readonly property int windowLabelWidth: Prefs.get("windowLabelWidth", 420)
    readonly property int mediaLabelWidth: Prefs.get("mediaLabelWidth", 260)
    readonly property int scrollMsPerPx: Prefs.get("scrollMsPerPx", 28)
    readonly property int scrollGap: Prefs.get("scrollGap", 48)

    // Bar: optional items. Layout itself is fixed (left / center / right islands).
    readonly property bool showLauncher: Prefs.get("showLauncher", true)
    readonly property bool showMedia: Prefs.get("showMedia", true)
    readonly property bool showSystem: Prefs.get("showSystem", true)
    readonly property bool showTray: Prefs.get("showTray", true)
    readonly property bool showWeather: Prefs.get("showWeather", true)
    readonly property bool showMail: Prefs.get("showMail", true)
    readonly property string terminal: Prefs.get("terminal", "ghostty")

    // Music: spotify_player in the tmux session `musicSession`. Its MPRIS
    // identity is preferred by the bar (playerctl name: spotify_player).
    readonly property string musicPlayer: "spotify_player"
    readonly property string musicSession: "music"
    // TUI opened by SUPER+S: a remote for the daemon (`spotify_player -d`) —
    // no MPRIS (the daemon has it) and its own CLI port (the daemon has 8080).
    readonly property var musicTuiArgs: ["-o", "enable_media_control=false", "-o", "client_port=8081"]
    readonly property int spotifyLibraryMaxAgeH: Prefs.get("spotifyLibraryMaxAgeH", 6)   // library cache age before a background refetch
    // Same face SDDM shows (AccountsService convention).
    readonly property string avatar: Prefs.get("avatar", Quickshell.env("HOME") + "/.face.icon")

    // Launcher
    readonly property int launcherWidth: Prefs.get("launcherWidth", 640)
    readonly property int launcherRows: Prefs.get("launcherRows", 9)   // visible result rows
    readonly property int launcherFrequent: Prefs.get("launcherFrequent", 6)   // "frequent" shown on an empty query
    // Desktop entry ids (file name without .desktop) never shown: settings
    // dialogs for an XFCE we don't run, test/debug tools, replaced apps.
    readonly property var launcherHidden: Prefs.get("launcherHidden", [
        "Alacritty", "vim", "xfce4-about", "xfce4-notifyd-config", "xfce4-screensaver-preferences",
        "xfce-wm-settings", "xfce-wmtweaks-settings", "xfce-workspaces-settings", "panel-preferences",
        "thunar-volman-settings", "thunar-settings", "avahi-discover", "bssh", "bvnc", "lstopo",
        "qv4l2", "qvidcap", "xgps", "xgpsspeed", "uuctl", "jconsole-java-openjdk", "jshell-java-openjdk",
        "xdvi"
    ])

    // Dashboard tabs, in order. Each id needs a component in DashboardWindow.
    readonly property var dashboardTabs: [
        { id: "overview", label: "Overview", icon: "󰕮" },
        { id: "media",    label: "Media",    icon: "󰝚" },
        { id: "system",   label: "System",   icon: "󰍛" },
        { id: "weather",  label: "Weather",  icon: "󰖐" },
        { id: "github",   label: "GitHub",   icon: "\uf09b" },
        { id: "docker",   label: "Docker",   icon: "󰡨" }
    ]
    readonly property int dashboardWidth: Prefs.get("dashboardWidth", 900)
    readonly property int quickSettingsWidth: Prefs.get("quickSettingsWidth", 540)
    readonly property int trayMenuWidth: Prefs.get("trayMenuWidth", 300)

    // Weather (Open-Meteo, no key; only these coordinates are sent).
    readonly property string weatherPlace: Prefs.get("weatherPlace", "York, ME")
    readonly property real weatherLat: Prefs.get("weatherLat", 43.1617)
    readonly property real weatherLon: Prefs.get("weatherLon", -70.6484)
    readonly property bool weatherImperial: Prefs.get("weatherImperial", true)   // °F + mph, else °C + km/h
    readonly property int weatherRefreshMin: Prefs.get("weatherRefreshMin", 15)

    // Proton Mail via Bridge (scripts/proton-mail.py; creds in
    // ~/.config/rice/proton-bridge.netrc). Bar icon is dimmed until set up.
    readonly property int mailRefreshSec: Prefs.get("mailRefreshSec", 120)
    readonly property bool mailNotify: Prefs.get("mailNotify", true)   // notify-send on new unread
    readonly property string mailUrl: Prefs.get("mailUrl", "https://mail.proton.me/u/0/inbox")

    // Proton Calendar share link (scripts/proton-calendar.py; link in
    // ~/.config/rice/proton-calendar.url). Hidden until configured.
    readonly property int calendarRefreshMin: Prefs.get("calendarRefreshMin", 30)
    readonly property string calendarUrl: Prefs.get("calendarUrl", "https://calendar.proton.me")

    // Screenshots (grimblast) and OCR (tesseract)
    readonly property string screenshotDir: Prefs.get("screenshotDir", Quickshell.env("HOME") + "/Pictures/Screenshots")
    readonly property string ocrLang: Prefs.get("ocrLang", "eng")

    // Clipboard history (cliphist)
    readonly property int clipboardMax: Prefs.get("clipboardMax", 200)

    // GitHub card on the Overview (gh CLI login)
    readonly property bool showGithub: Prefs.get("showGithub", true)
    readonly property int githubRefreshMin: Prefs.get("githubRefreshMin", 10)
    readonly property int githubRepos: Prefs.get("githubRepos", 8)   // most recently pushed repos (commits are read from these)
    readonly property int githubCommits: Prefs.get("githubCommits", 8)

    // Lock screen / idle
    readonly property int lockAfterMin: Prefs.get("lockAfterMin", 10)   // 0 = never auto-lock
    readonly property int screenOffAfterMin: Prefs.get("screenOffAfterMin", 15)   // 0 = never turn screens off
    readonly property bool lockBeforeSleep: Prefs.get("lockBeforeSleep", true)

    // Synced lyrics from lrclib.net (sends artist/title/album to it).
    readonly property bool lyrics: Prefs.get("lyrics", true)

    // Night light tile: hyprsunset temperature when on.
    readonly property int nightLightTemp: Prefs.get("nightLightTemp", 5500)
    readonly property int nightLightGamma: Prefs.get("nightLightGamma", 80)   // % — matches hyprsunset.conf
    readonly property int nightLightMinTemp: Prefs.get("nightLightMinTemp", 2500)
    readonly property int nightLightMaxTemp: Prefs.get("nightLightMaxTemp", 6500)

    // Samples kept for sparklines (Sys polls every 2s → 60s of history).
    readonly property int historySize: Prefs.get("historySize", 30)
    readonly property int notifyHistory: Prefs.get("notifyHistory", 100)   // notifications kept (and saved across restarts)

    // Notifications: which group an app's notifications land in, matched
    // case-insensitively against the app name (first match wins; else "system").
    readonly property var notifySources: Prefs.get("notifySources", [
        { id: "mail",    label: "Mail",    icon: "󰇮", apps: ["proton mail", "thunderbird", "mail", "evolution"] },
        { id: "chat",    label: "Discord & chat", icon: "󰙯", apps: ["discord", "vesktop", "discordo", "webcord", "signal", "telegram"] },
        { id: "dev",     label: "Dev",     icon: "󰚩", apps: ["claude code", "claude", "github", "gh", "git", "docker"] },
        { id: "media",   label: "Media",   icon: "󰎆", apps: ["spotify", "spotify_player", "mpd", "ncmpcpp", "firefox"] },
        { id: "system",  label: "System",  icon: "󰒓", apps: [] }
    ])
    readonly property int toastTimeout: Prefs.get("toastTimeout", 6000)   // ms, when the app doesn't say
    readonly property int toastMax: Prefs.get("toastMax", 4)   // on screen at once
    readonly property int toastPerSourceWindow: Prefs.get("toastPerSourceWindow", 30000)   // ms
    readonly property int toastPerSourceMax: Prefs.get("toastPerSourceMax", 3)   // toasts per source per window; the rest only go to the sidebar
    readonly property int toastWidth: Prefs.get("toastWidth", 420)
    readonly property int sidebarWidth: Prefs.get("sidebarWidth", 460)

    // Feeds tab (RSS / Atom). Arch news carries manual-intervention notices.
    readonly property var feeds: Prefs.get("feeds", [
        { name: "Arch Linux", url: "https://archlinux.org/feeds/news/" },
        { name: "Phoronix", url: "https://www.phoronix.com/rss.php" },
        { name: "Hacker News", url: "https://hnrss.org/frontpage?points=150" }
    ])
    readonly property int feedsRefreshMin: Prefs.get("feedsRefreshMin", 30)
    readonly property int feedsPerSource: Prefs.get("feedsPerSource", 12)

    // Focus mode (a started session can't be cancelled). Profiles: minutes /
    // break / rounds, site
    // bundles (config/focus-bundles.json) + extra sites, app rules (hide or
    // close windows whose initial class matches), notification level
    // (off | focus = critical only | total), optional Spotify playlist id.
    readonly property var focusProfiles: Prefs.get("focusProfiles", [
        { id: "deep", label: "Deep work", icon: "󰽥", minutes: 50, breakMin: 10, rounds: 2,
          bundles: ["youtube", "reddit", "twitch", "x", "news", "discord-web"], sites: [],
          apps: [{ re: "^(discord|steam|steam_app_\\d+|dev\\.rice\\.discordo)$", action: "hide" }],
          dnd: "focus", playlist: "" },
        { id: "study", label: "Study", icon: "󰑴", minutes: 25, breakMin: 5, rounds: 4,
          bundles: ["youtube", "reddit", "twitch", "x"], sites: [],
          apps: [{ re: "^(discord|dev\\.rice\\.discordo)$", action: "hide" }],
          dnd: "focus", playlist: "" },
        { id: "gaming-off", label: "Gaming off", icon: "󰊴", minutes: 120, breakMin: 0, rounds: 1,
          bundles: ["twitch", "steam-web"], sites: [],
          apps: [{ re: "^(steam|steam_app_\\d+|gamescope)$", action: "close" }],
          dnd: "off", playlist: "" }
    ])
    readonly property string focusDefault: Prefs.get("focusDefault", "deep")


    // Wallpapers (services/Wallpaper.qml; replaces the old cron rotation).
    readonly property string wallpaperDir: Prefs.get("wallpaperDir", Quickshell.env("HOME") + "/Pictures/Wallpapers")
    readonly property int wallpaperRotateMin: Prefs.get("wallpaperRotateMin", 30)     // 0 = never
    // "fixed": wallpapers only suggest themes. "follow": applying one with a
    // tagged theme switches to it (and browsing previews its palette).
    readonly property string wallpaperThemePolicy: Prefs.get("wallpaperThemePolicy", "fixed")
    readonly property string wallpaperPlacement: Prefs.get("wallpaperPlacement", "crop")  // crop | fit | span
}
