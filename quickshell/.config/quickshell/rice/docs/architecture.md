# Architecture

Quickshell shell for Hyprland on Arch. Layout and behaviour follow
[lyne-dots](https://github.com/caioax/lyne-dots) (GPLv3 — patterns were
reimplemented, no code copied); the look stays retro: gruvbox-material,
DepartureMono Nerd Font, radius 0, 1px borders, accent underlines, segmented
meters and column sparklines.

## Entry point

`shell.qml` — `ShellRoot` with a `Variants` over `Quickshell.screens` (one
`modules/bar/Bar` per screen) and an `IpcHandler` (`target: "rice"`) exposing
`dashboard(tab)`, `quicksettings(page)`, `launcher()`, `clipboard()`, `keybinds()`, `screenshot(target, action)`, `nightlight()`, `dnd()`, `mail()`, `refresh()`, `close()`;
they act on the focused monitor. `//@ pragma IconTheme Gruvbox-Plus-Dark` sets
the icon theme for desktop-entry and tray icons; `//@ pragma UseQApplication`
is required for tray (platform) menus.

## Directory layout

```
rice/
├── shell.qml
├── config/          Theme + Settings singletons
├── services/        singletons: data + control, no UI
├── components/      shared retro widgets
├── scripts/         python helpers run by services (JSON on stdout)
├── modules/
│   ├── bar/         Bar + buttons
│   ├── dashboard/   DashboardWindow + tabs/cards
│   ├── launcher/    LauncherWindow
│   └── quicksettings/ QuickSettingsWindow + pages
└── docs/
```

Directories are imported by relative path (`import "../../components"`);
`services` is imported `as Svc`. Each dir with singletons has a `qmldir`.

## Layers

### `config/`

- `Theme.qml` — the raw gruvbox-material palette (`bg0..4`, `fg0/1`, `red/orange/…` with `Dim`/`Bright`) plus **semantic roles** components bind to: `background`, `surface0..3`, `text`, `textBright`, `subtext`, `muted`, `accent` (yellow), `success`, `warning`, `error`, `info`. Helpers `usageColor(pct, calm)`, `tempColor(c)`. Type scale (`fontSizeSmall 14 / fontSize 18 / fontSizeLarge 22 / fontSizeHuge 66`, `iconSize 22` — multiples of DepartureMono's 11px grid stay crisp), geometry (`pad`, `gap`, `spacing`, `radius 0`, `border 1`, `accentThickness 2`), motion (`animShort/anim/animLong`).
- `Settings.qml` — bar height, label caps/carousel tuning, show flags (`showLauncher/Media/System/Tray`), `launcherCommand`, dashboard tabs + widths, `lyrics`, `nightLightTemp`, `historySize`.

### `services/`

| Service | Source | Notes |
|---------|--------|-------|
| `Ui` | — | Popup state: `open` ("" / "dashboard" / "quicksettings" / "launcher"), `screen`, `tab`, `page`; `toggle(name, screen, where)`, `close()`, `dismiss()` (outside click / Escape — a toggle of the same popup within 300ms is then swallowed, so its bar button closes it), `showPage()`, `back()`, `cycleTab()` |
| `Launcher` | `DesktopEntries` | `apps` (visible, deduped, by name), `frequent`, `search(q)` (exact › prefix › word › substring › tight fuzzy, + usage bonus), `calc("= expr")`, `launch(e)` (terminal apps via `Settings.terminal`), usage counts in `~/.cache/quickshell/launcher-usage.json` |
| `Mail` | `scripts/proton-mail.py` → Proton Mail Bridge IMAP (127.0.0.1:1143, STARTTLS, self-signed) | creds from `~/.config/rice/proton-bridge.netrc`; INBOX `readonly` + `BODY.PEEK` (never marks read); `state_` (ok / unconfigured / offline / error), `unread`, `total`, `messages`; notify-send for new uids after the first load; `openWebmail()`, `startBridge()` |
| `Calendar` | `scripts/proton-calendar.py` → Proton share-link ICS | link from `~/.config/rice/proton-calendar.url`; RRULE/EXDATE/RECURRENCE-ID expanded with dateutil, TZID via zoneinfo, cancelled dropped, 60-day window, cached in `~/.cache/quickshell/calendar.json` (`stale` offline); `byDay`, `eventsOn(date)`, `upcoming(n)` |
| `Keybinds` | `hyprctl binds -j` | readable `rows` ({ keys, label, group, dispatcher, arg, runnable }); labels derived from dispatcher/arg (rice IPC, playerctl, wpctl…); 1…0 workspace runs collapsed; loaded when the keybinds mode opens |
| `Clipboard` | `cliphist` + `wl-paste --watch` | runs the text + image watchers itself while cliphist exists (re-probed on use); `entries` ({ id, text, image, info, thumb }), image thumbs decoded to `~/.cache/quickshell/cliphist/`; `copy`, `remove`, `wipe` |
| `Screenshot` | `grimblast`, `tesseract`, `satty` | `take(target, action)` after the popup has closed; targets area/active/output/screen; actions save (copysave → `Settings.screenshotDir`) / copy / text (OCR → wl-copy + notify) / edit (satty); `latest`, `hasOcr`, `hasEditor` (re-probed) |
| `Github` | `gh api graphql` + `gh api notifications` (gh's login) | one query: profile, contribution calendar (`days` with GitHub-style quartile `level`s), recently pushed `repos` + their latest `commits`, open `prs` / `issues` / review requests; derived `today`, `thisWeek`, `streak`, `longestStreak`, `busiest`; refresh every `githubRefreshMin` |
| `Lock` | `PamContext` (login), `hyprctl devices`, `awww query`, `systemd-inhibit` + `gdbus monitor` (logind) | `locked`, shared `buffer`, `submit()` → PAM, `failed`/`failMessage`/`attempts`, `capsLock`, per-output `wallpapers`; lock-before-sleep via a delay inhibitor released once `secure`; `IdleMonitor`s for auto-lock and dpms; `caffeine` |
| `Weather` | Open-Meteo via `curl` | `current`, `hourly` (24h), `daily` (7d); WMO code → `icon()`, `describe()`, `color()`; refresh every `weatherRefreshMin` |
| `Hyprland` | `Quickshell.Hyprland` | workspaces, monitors, `focusedMonitor`, `activeToplevel`, `monitorFor(screen)`, `dispatch()`. Refreshes toplevels on start so the title isn't blank after a reload |
| `Audio` | `pactl` | event-driven (`pactl subscribe`); outputs/inputs, defaults, mute, volume setters |
| `Mpris` | `Quickshell.Services.Mpris` | `players`, `select(p)`; active = hand-picked › playing (`Settings.musicPlayer` first) › music player › first. Transport, seek, shuffle/loop, volume; `launch()` attaches a terminal to the tmux session `Settings.musicSession` (creating it with spotify_player the first time) |
| `Spotify` | `spotify_player` CLI (`get key user-playlists` / `user-saved-albums` / `playback`, `playback start context\|liked`, `playback shuffle\|repeat`) | library for the Media tab's `LibraryCard`; `playPlaylist` / `playAlbum` / `playLiked` (optional shuffle); `playbackShuffle` / `playbackRepeat`, which spotify_player doesn't expose over MPRIS — `Mpris.toggleShuffle` / `cycleLoop` route through `cli()` for it |
| `Lyrics` | lrclib.net via `curl` | fetches only while `wanted` (Media tab open) and the track changed; cached in `~/.cache/quickshell/lyrics`; `status`, `lines`, `currentIndex` |
| `Sys` | `/proc`, `/sys`, `df` | 2s poll: CPU/GPU/RAM/disks/temps + `cpuHistory/gpuHistory/memHistory`, uptime, load, kernel, host |
| `Network` | `mullvad`, `ip`, `/sys/class/net` | **Mullvad** state/relay/location/IP + `toggle()`/`reconnect()`; reachability; physical links with uplink flag |
| `Bluetooth` | `Quickshell.Bluetooth` | sorted devices, `activate(d)` (pair→trust→connect), scan with 60s timeout, `bluetoothctl` agent |
| `Docker` | `docker ps` + `docker events` | containers, start/stop/restart |
| `Desktop` | `hyprctl hyprsunset`, `dunstctl`, `systemctl` | night light (`nightLight`, `nightTemp`, `nightGamma`, setters debounced 60ms), DND + counts, notification `history` (from `dunstctl history` while `historyWanted`; `showAgain`, `removeNotification`, `clearHistory`), power actions. hyprsunset reports its last temperature even under `identity`, so night-light state lives in `$XDG_RUNTIME_DIR/rice-nightlight` as `on|off <K> <gamma>` (on = `temperature`+`gamma`, off = `identity`+`gamma 100`) |

### `components/`

`Label` (shell-font Text), `BarButton` (hover cell + accent underline when its popup is open; click/right/middle/wheel), `BarDivider`, `BarPopup` (see below), `Card` + `CardHeader`, `Tile` (QS toggle with ▸ details cell), `Slider` (icon=mute, blocky track, %), `Switch` (OFF│ON), `IconButton`, `DeviceRow`, `PageHeader`, `TabBar` (sliding underline), `Meter` (segmented bar), `Sparkline` (column history), `ScrollingText` (carousel).

**`BarPopup`** — a layer-shell `PanelWindow` per bar on the Overlay layer. It sits flush under the bar (overlapping its 1px border so it reads as attached), centered on `anchorItem` and clamped to the screen. Slides down and follows its content height. `mask` limits input to the panel. Keyboard mode is `OnDemand` from `wanted` (set *before* mapping — Hyprland gives focus at map time); `initialFocus` takes focus on open (the launcher's search field). A `HyprlandFocusGrab` over the popup only (including the bar made Hyprland hand keyboard focus to the bar) closes it on an outside click → `dismissed`; Escape too (`keyTargets` get keys first, so pages can use Escape for "back").

### `modules/bar/`

`Bar.qml` — docked, full width, `Theme.background`, hairline bottom border. Three `Row`s:

- left: `LauncherButton` · `Workspaces` (this monitor's workspaces; shown one lit, accent+underline on the focused monitor; wheel walks `m±1`) │ `ActiveWindow` (class tag + scrolling title)
- center: `ClockButton` · `MediaButton` · `SystemButton` · `WeatherButton` → `DashboardWindow` anchored to the center row
- `LauncherButton` → `LauncherWindow` (anchored to it)
- right: `Tray` │ `MailButton` (unread; only once Mail is configured) · `QuickSettingsButton` → `QuickSettingsWindow`

`Tray` right-click opens `TrayMenu` (a `BarPopup` under the icon) instead of Qt's native menu: entries via `QsMenuOpener` (root + every entered level kept open), separators, check/radio marks, entry icons, submenus with a back row; `Ui.open = "traymenu"`.

`QuickSettingsButton` folds every status icon into one button: VPN shield (green / orange = tunnel but no internet / red), uplink type or offline, BT (only when connected/busy), mic muted, DND, volume glyph + %.

### `modules/dashboard/`

`DashboardWindow` — `TabBar` + horizontally sliding pages (Loaders, live only while open). The panel height tracks the current tab.

- **Overview**: `ClockCard` (big time, date, weather line, uptime, user@host), `MonthCard` (Monday-first grid, today filled, ‹ › months, event dots, click a day to pick it), `AgendaCard` (Proton Calendar: picked day or upcoming), `PlayerCard`, `ResourcesCard` (CPU/GPU/RAM/root meters), `GithubCard` (commit frequency: `ContributionGrid` + today/streak/week; ▸ → GitHub tab)
- **Media**: `CoverArt`, player picker chips, title/artist/album, `LyricsView`, `Progress` (seek), `Transport` (shuffle/prev/play/next/loop), player volume
- **System**: `StatCard`s for CPU / GPU (+VRAM) / Memory with sparklines, storage meters, network + Mullvad row, host/kernel/uptime/procs footer
- **Weather**: now (big glyph, °, condition, feels-like, hi/lo, humidity, wind, sunrise/sunset), next 24h column chart (height = temperature, color = condition, blue ticks = rain chance), 7 days with min–max bars on the week's scale
- **GitHub**: profile stats, full-year `ContributionGrid` (hover a day; busiest day), recent commits, repositories, open PRs / review requests / issues, notifications button; rows open in the browser
- **Docker**: container list with start/stop/restart

### `modules/lock/`

`LockScreen` — `WlSessionLock` loaded by `shell.qml` while `Lock.locked`; one `WlSessionLockSurface` per output: blurred wallpaper (`MultiEffect`), bar-like strip, clock, avatar card with prompt/status, shake on failure. Keys go to `Lock.buffer`, so every screen mirrors the prompt; the first surface to see `authSucceeded` fades out and releases the lock.

Long-running helpers (pactl, docker events, bluetoothctl, wl-paste, systemd-inhibit, gdbus) are launched through `Settings.tether` (`setpriv --pdeathsig TERM`) and never through an `sh` wrapper, so they die with the shell instead of piling up as orphans.

### `modules/launcher/`

`LauncherWindow` — mode chips (apps / clipboard / keybinds = `Ui.page`, Alt+1-3), then prompt (`>`/`=`, blinking block cursor) + `ListView` of rows: section headers ("frequent", "all apps") on an empty query, ranked matches otherwise, or one calculator row. Rows show the theme icon (lettered tile fallback), name, generic name/comment, a terminal marker; the selected row gets the accent bar and ↵. Mouse hover selects, click launches.

### `modules/quicksettings/`

`QuickSettingsWindow` — sub-pages slide in/out by `Ui.page`.

- **Main**: `ProfileCard` (user@host, uptime, log out / suspend / reboot / shut down with confirm-on-second-click; tool row: screenshot page, clipboard + keybinds launcher modes), 2×2 tiles (Mullvad VPN ▸, Bluetooth ▸, Night light, Do not disturb), Sound card (output + mic sliders, ▸ sound page)
- **network**: Mullvad switch, relay, exit location/IP, reconnect; links list
- **bluetooth**: power switch, scan, device rows (click = connect / disconnect / pair, hover 󰆴 = forget)
- **sound**: default output / input pickers
- **nightlight**: switch, warmth slider (2500–6500K, 100K steps) + presets, brightness (gamma 40–100%)
- **screenshot**: action chips (save + copy / copy / text / edit — the last two disabled until tesseract-data / satty exist), 4 target tiles, last-capture preview (click opens it), folder button
- **mail**: unread list (subject, sender, age), refresh, open webmail; Bridge-offline card with a start button; error card
- **notifications**: DND switch, dunst history (newest first, app icon, age, summary, body; click = `history-pop`, 󰆴 = `history-rm`, clear all)

## Hot reload

Quickshell watches the tree; saving re-parses the shell. If a reload fails the
old shell keeps running and `quickshell log -c rice` shows the error.

Gotchas:
- `qmllint` misses property-shadow-of-FINAL errors (`property var top`, `z`, `state`, `data`, `parent`…) — they fail only at load. Verify by loading the shell.
- QML property names cannot start with an uppercase letter.
- Children of `Card`/`BarButton` are reparented into an inner layout via a default alias, so `parent` inside them is not the card — use ids.
- In layouts use `Layout.fillWidth` + `Layout.preferredWidth: 0` for `ScrollingText`, not `maxWidth: width` (binding loop).
- `pkill -f 'quickshell …'` from a shell also matches that shell's own command line — kill by PID.
- A new directory under `modules/` (or a `//@ pragma` change) isn't picked up by hot reload ("X is not a type") — restart the shell.

## Rough edges / next

- Notifications are still dunst; an in-shell notification center + OSD would complete the lyne set.
- Theme presets from JSON + syncing alacritty/nvim/hyprland borders.
- Poll boilerplate across `Sys`/`Network`/`Docker`/`Desktop` could share a helper.
