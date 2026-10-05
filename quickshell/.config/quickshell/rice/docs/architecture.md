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

- `Theme.qml` — tokens; see `docs/ui-rules.md` for how to use them.
  - **Colour**: raw gruvbox-material hues (`bg0..4`, `fg0/1`, `red…purple` with `Dim`/`Bright`); **semantic roles** (`background`, `surface0..3`, `text`, `textBright`, `textReverse`, `subtext`, `muted`, `accent`, `success`, `warning`, `error`, `info`, `pending`); **domain colours** (`catMedia`/`catMediaBright`, `catSystem`, `catNet`, `catTime`, `catWeather`, `catDev`, `catNotify`); `series[0..3]` (cpu, gpu, mem, disk). Helpers `usageColor(pct, calm)`, `tempColor(c)`.
  - **Type**: `fontXs 11 · fontSm 12 · fontBase 14 · fontTitle 15 · fontMd 18 · fontLg 22 · fontXl 44 · fontHuge 66`; `iconSize 22`, `iconSizeLarge 33`.
  - **Shape**: `shape` ("square" | "round") → `round`, `radius`, `radiusSmall`, `radiusPill`, `accentStyle` ("underline" | "pill").
  - **Geometry**: `pad`, `gap`, `spacing`, `border`, `accentThickness`, `rowHeight`, `rowHeightCompact`, `controlHeight`. **Motion**: `animShort/anim/animLong`, `easing`.
- `Prefs.qml` — runtime choices (`theme`, `shape`, `font`, `dnd`) and `overrides` (settings changed in the settings window: `get(key, default)`, `override`, `reset`, `isSet`) in `~/.local/state/rice/prefs.json` via `FileView` + `JsonAdapter`; `set(key, value)` waits until the file loaded and coalesces writes.
- `Fmt.qml` — `age()`, `since()`.
- `actions.json` — the action allowlist (id, title, icon, group, `call` = IPC function + args, aliases, `confirm`, `voice`); `scripts/check-actions.py` checks it against the `IpcHandler`.
- `settings-schema.json` — the settings window: pages → sections → items (`key`, `type` bool/int/real/string/list, label, help, range, unit); pages/sections may name a `custom` component.
- `Settings.qml` — every tunable reads `Prefs.get("key", default)`, so overrides apply live; internal plumbing (tether, music/bridge commands, dashboard tab ids) stays constant. Bar height, label caps/carousel tuning, show flags (`showLauncher/Media/System/Tray/Weather/Mail/Github`), `terminal` + `tether`, launcher sizes + `launcherHidden` (desktop ids never listed), dashboard tabs + widths, `lyrics`, night light, weather (location, units, refresh), mail/calendar/github refresh, lock (idle timeouts, avatar), music (`musicPlayer`, `musicSession`, `musicTuiArgs`), screenshot dir.

### `services/`

| Service | Source | Notes |
|---------|--------|-------|
| `Notifications` | `NotificationServer` (owns org.freedesktop.Notifications) | `history` (records, newest first, saved to `~/.local/state/rice/notifications.json`), `groups` by source (`Settings.notifySources`), `toasts` (rate-limited per source; critical always; none under DND or while the sidebar shows them), `unread`, `dnd`/`setDnd`, `activate`/`invoke`/`dismiss`/`clearSource`/`clearAll`; live `Notification` objects kept for actions |
| `Feeds` | `XMLHttpRequest` (RSS/Atom, `Settings.feeds`) | `items` newest first, `errors`, `unread` (per session), `refresh()` every `feedsRefreshMin` |
| `Actions` | `config/actions.json` + one per theme | `all`, `byId`, `search(q)` (Launcher scoring on title/aliases/group), `run(a)` → `qs ipc call rice …` |
| `Ui` | — | Popup state: `open` ("" / "dashboard" / "quicksettings" / "launcher" / "traymenu" / "sidebar" / "session"), `screen`, `tab`, `page`; `toggle(name, screen, where)`, `close()`, `dismiss()` (outside click / Escape — a toggle of the same popup within 300ms is then swallowed, so its bar button closes it), `showPage()`, `back()`, `cycleTab()` |
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
| `Audio` | `Quickshell.Services.Pipewire` | event-driven, no processes: default sink/source volume % + mute, device lists, per-app streams (tracked only while shown); setters write the nodes |
| `Privacy` | `Quickshell.Services.Pipewire` | apps using the mic (audio input streams), the camera (active links out of v4l2/libcamera sources) or the screen (other video sources); the bar's red indicator |
| `LatestRun` | (helper type) | run a command where only the newest request counts (search as you type, lyrics); older output is dropped |
| `CmdQueue` | (helper type, not a singleton) | runs commands one at a time without dropping any; `run(args, key)` replaces a queued command with the same key (latest volume wins); `busy`, `drained()`. Used by `Audio`, `Desktop`, `Docker` setters |
| `Mpris` | `Quickshell.Services.Mpris` | `players`, `select(p)`; active = hand-picked › playing (`Settings.musicPlayer` first) › music player › first. Transport, seek, shuffle/loop, volume; `launch()` makes sure the headless player (`spotify_player -d`, from Hyprland) runs, then opens/attaches its TUI in tmux session `Settings.musicSession` as a remote (`Settings.musicTuiArgs`: no MPRIS, CLI port 8081; `enable_streaming = "DaemonOnly"` keeps audio in the daemon) |
| `Spotify` | `spotify_player` CLI (`get key user-playlists` / `user-saved-albums` / `playback`, `playback start context\|liked`, `playback shuffle\|repeat`) | library for the Media tab's `LibraryCard`; `playPlaylist` / `playAlbum` / `playLiked` (optional shuffle); `playbackShuffle` / `playbackRepeat`, which spotify_player doesn't expose over MPRIS — `Mpris.toggleShuffle` / `cycleLoop` route through `cli()` for it |
| `Lyrics` | lrclib.net via `curl` | fetches only while `wanted` (Media tab open) and the track changed; cached in `~/.cache/quickshell/lyrics`; `status`, `lines`, `currentIndex` |
| `Sys` | `/proc`, `/sys`, `df` | direct file reads every 2 s (sensor paths found once at start), `df` once a minute: CPU/GPU/RAM/disks/temps + histories, load, kernel, host |
| `Network` | `mullvad status -j listen`, `ip -o monitor`, `ping` | VPN state pushed by mullvad; links re-read when the kernel reports link/address/route changes; reachability ping once a minute (10 s while offline) |
| `Bluetooth` | `Quickshell.Bluetooth` | sorted devices, `activate(d)` (pair→trust→connect), scan with 60s timeout, `bluetoothctl` agent |
| `Docker` | `docker ps` + `docker events` | containers, start/stop/restart |
| `Desktop` | `hyprctl hyprsunset`, `systemctl` | night light (`nightLight`, `nightTemp`, `nightGamma`, setters debounced 60ms; defaults follow Settings), user, power actions. The state file is watched; hyprsunset itself is re-read every 5 min (its profiles switch on their own). hyprsunset reports its last temperature even under `identity`, so night-light state lives in `$XDG_RUNTIME_DIR/rice-nightlight` as `on|off <K> <gamma>` (on = `temperature`+`gamma`, off = `identity`+`gamma 100`) |

### `components/`

Shared building blocks: use these instead of hand-rolling (see `docs/ui-rules.md`).

| Component | What |
|---|---|
| `Label` | shell-font Text; `size` takes a `Theme.font*` token |
| `BarButton` | bar cell: hover = raised, `active` (its popup is open) = raised + `AccentIndicator`; `indicator` colour, `minWidth`; click/right/middle/wheel. `Workspaces` cells are BarButtons |
| `AccentIndicator` | the selection mark: 2px underline/side bar (square) or soft pill (round); `edge`, `tint`, `active`. Declare first in the parent so content draws on top |
| `ListRow` | the list row: glyph or `leading` component, title, subtitle, `note`, trailing slot, `active` (indicator on the left), `compact` (menus); click/right-click. Used by device lists, the library, tray menus |
| `SectionLabel` | small-caps group label inside lists |
| `Card` + `CardHeader` | inset panel + its title row (domain-coloured glyph/title, subtitle, trailing slot) |
| `PageHeader` | Quick Settings sub-page header (back, glyph, title/subtitle, trailing) |
| `TabBar` | text tabs; indicator stretches between tabs (leading edge fast, trailing slow) |
| `Tile` | QS toggle with ▸ details cell; on = filled accent icon cell + accent border |
| `IconButton` | glyph (+ text) button; `checked` = filled accent (chips / segmented choices) |
| `TextField` | framed input: prefix glyph, placeholder, block cursor; unhandled keys via `keyPressed(e)` |
| `PowerRow` | power actions that arm on the first click and fire on the second; `instant` ids skip arming |
| `Slider`, `Switch`, `Meter`, `Sparkline` | controls / data; tracks and handles follow `radiusPill` |
| `Stat` | big value over a caption |
| `Spinner` | 3×3 block spinner; reserves its size |
| `PanelShape` | silhouette of a bar-attached panel (top-hung or side): one path for fill + outline, concave joins in round shape |
| `EdgePanel` | full-height side panel (sidebar, session) with wipe / slide reveal |
| `ScrollingText`, `BarDivider` | carousel text, bar separator |

`config/Fmt` (singleton): `age(seconds)`, `since(dateOrUnixSeconds)` → "now", "5m", "3h", "2d".

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

- **Overview**: `ClockCard` (big time, date, weather line, user@host), `MonthCard` (Monday-first grid, today filled, ‹ › months, event dots, click a day to pick it), `AgendaCard` (Proton Calendar: picked day or upcoming), `PlayerCard`, `ResourcesCard` (CPU/GPU/RAM/root meters), `GithubCard` (commit frequency: `ContributionGrid` + today/streak/week; ▸ → GitHub tab)
- **Media**: `CoverArt`, player picker chips, title/artist/album, `LyricsView`, `Progress` (seek), `Transport` (shuffle/prev/play/next/loop), player volume
- **System**: `StatCard`s for CPU / GPU (+VRAM) / Memory with sparklines, storage meters, network + Mullvad row, host/kernel/procs footer
- **Weather**: now (big glyph, °, condition, feels-like, hi/lo, humidity, wind, sunrise/sunset), next 24h column chart (height = temperature, color = condition, blue ticks = rain chance), 7 days with min–max bars on the week's scale
- **GitHub**: profile stats, full-year `ContributionGrid` (hover a day; busiest day), recent commits, repositories, open PRs / review requests / issues, notifications button; rows open in the browser
- **Docker**: container list with start/stop/restart

### `modules/lock/`

`LockScreen` — `WlSessionLock` loaded by `shell.qml` while `Lock.locked`; one `WlSessionLockSurface` per output: blurred wallpaper (`MultiEffect`), bar-like strip, clock, avatar card with prompt/status, shake on failure. Keys go to `Lock.buffer`, so every screen mirrors the prompt; the first surface to see `authSucceeded` fades out and releases the lock.

Long-running helpers (pactl, docker events, bluetoothctl, wl-paste, systemd-inhibit, gdbus) are launched through `Settings.tether` (`setpriv --pdeathsig TERM`) and never through an `sh` wrapper, so they die with the shell instead of piling up as orphans.

### Lazy windows

`modules/bar/Bar.qml` creates each popup / panel (dashboard, launcher, Quick Settings, wallpaper picker, sidebar, session) with a `LazyLoader` only while it is open on that monitor, keeps it through its closing animation, then frees it. Toasts exist only while there are some, on the focused monitor. Popups therefore run their open logic from `Component.onCompleted` as well as `onWantedChanged`; the focus grab retries if it is cleared while the surface is still mapping. The dashboard builds only the shown tab (and the one sliding out).

### `modules/sidebar/`, `modules/session/`, `modules/osd/`

All built on `components/EdgePanel`: a full-height layer surface on a screen edge under the bar. Square shape: a clipped wipe from the edge with the content standing still and an accent line on the moving edge; round: the panel slides and fades. Animation time scales with the distance left, so interrupting an open/close never snaps. `mask` = the visible part; same focus handling as `BarPopup` (grab the panel only, `OnDemand` keyboard set before mapping, Escape / outside click → `dismissed`). Content loads only while open unless `keepLoaded`.

- `SidebarWindow` — right edge, `Settings.sidebarWidth`. Tabs (`Ui.page`): **notifications** (`NotifyPage`: mail inbox card from `Mail`, then a card per source group, latest five until "show all"; rows = `ListRow` with app icon / image, body up to 3 lines, age, action buttons, dismiss; critical rows get the error indicator), **weather** (the dashboard `WeatherTab` in a Flickable), **feeds** (`FeedsPage`: per-feed chips, two-line rows, read state). Ctrl+Tab cycles, Alt+1…3 jumps. Binds `Notifications.panelOpen`.
- `ToastWindow` — top-right under the bar on the focused monitor; newest on top; timeout bar (pauses on hover); click = default action, right-click = hide, 󰅖 = dismiss. Hidden while the sidebar is open.
- `SessionWindow` — right edge, power actions as `ListRow`s; j/k/↑↓ move, Enter fires, mouse arms then fires.
- `OsdWindow` — volume meter under the bar centre on the focused monitor; armed 2 s after start and after an output switch; hidden while any popup is open.

### `modules/settings/`

`SettingsWindow` — a `FloatingWindow` titled "rice settings" (Hyprland `windowrule` floats/sizes it), created by a `Loader` in `shell.qml` while `Ui.settingsOpen`. Left: search + page list; right: the page. `SchemaPage` renders a schema page: its custom component (Appearance, Sound, Bluetooth, Network, NightLight, Actions, About — the device pages embed the Quick Settings pages with `embedded: true`), then a card per section with `SchemaItem`s (Switch / stepper+Slider / TextField committing on Enter or blur / string-list chips) or a custom section (`FeedsSection`, `SourcesSection`). `SettingRow` = label + help + control + ↺ when overridden. Search matches page titles/keywords and item labels/help/keys; matching items are rendered (editable) on top of the page.

### `modules/launcher/`

`LauncherWindow` — in apps mode a query starting with `>` lists `Actions` (confirm-tier ones need Enter twice; the row turns red) and `@` lists open windows (Enter focuses). Mode chips (apps / clipboard / keybinds = `Ui.page`, Alt+1-3), then prompt (`>`/`=`, blinking block cursor) + `ListView` of rows: section headers ("frequent", "all apps") on an empty query, ranked matches otherwise, or one calculator row. Rows show the theme icon (lettered tile fallback), name, generic name/comment, a terminal marker; the selected row gets the accent bar and ↵. Mouse hover selects, click launches.

### `modules/quicksettings/`

`QuickSettingsWindow` — sub-pages slide in/out by `Ui.page`.

- **Main**: `ProfileCard` (avatar, user@host; one icon row: screenshot page, clipboard + keybinds launcher modes, settings │ `PowerRow`: lock, log out, suspend, reboot, shut down with confirm-on-second-click), tiles (Mullvad VPN ▸, Bluetooth ▸, Night light ▸, Do not disturb ▸ sidebar notifications, Focus ▸, Caffeine, Sound ▸ — click mutes), each lit in its domain colour
- **network**: Mullvad switch, relay, exit location/IP, reconnect; links list
- **bluetooth**: power switch, scan, device rows (click = connect / disconnect / pair, hover 󰆴 = forget)
- **sound**: default output / input pickers
- **nightlight**: switch, warmth slider (2500–6500K, 100K steps) + presets, brightness (gamma 40–100%)
- **screenshot**: action chips (save + copy / copy / text / edit — the last two disabled until tesseract-data / satty exist), 4 target tiles, last-capture preview (click opens it), folder button
- **focus**: profile list + length and start; while running the countdown, what's blocked, and when it ends (no stop)

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
