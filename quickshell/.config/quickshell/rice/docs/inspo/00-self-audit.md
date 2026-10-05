# 00 — Self-audit of the rice (baseline)

Scope: everything under `rice/` (≈8.5k lines), `hypr/external/keybindings.conf`, `hyprland.conf`,
`look_and_feel.conf`, `randomWallpaper.sh`, `dunst/dunstrc`. Screenshots were taken live on DP-3
(`scratchpad/shots/*.png`): bar, all six dashboard tabs, QS main/notifications/sound/nightlight,
launcher, keybinds. Snapshot date 2026-10-05. Live process: `quickshell -c rice` RSS ≈ **494 MB**
after 6.7 h, with 7 tethered children.

---

## 1. Inventory

### Bar (`modules/bar/`, one `PanelWindow` per screen, 44 px, square, hairline bottom)
| Island | Item | One line |
|---|---|---|
| left | `LauncherButton` | Arch glyph → launcher popup |
| left | `Workspaces` | this monitor's workspace numbers, underline on shown one; re-implements BarButton |
| left | `ActiveWindow` | class tag (aqua) + `ScrollingText` title |
| center | `ClockButton` | HH:mm + date → Dashboard › Overview |
| center | `MediaButton` | state glyph + scrolling track; click Media tab / mid play-pause / right next / wheel vol |
| center | `SystemButton` | CPU sparkline, numbers slide out on hover → Dashboard › System |
| center | `WeatherButton` | glyph + temp → Dashboard › Weather |
| right | `Tray` + `TrayMenu` | SNI icons; right-click opens a shell-styled `BarPopup` menu with submenu stack |
| right | `MailButton` | unread count → QS › Mail; middle = webmail |
| right | `QuickSettingsButton` | folded status glyphs (VPN, uplink, BT, mic, DND, caffeine, volume) → QS; mid mute, right DND, wheel vol |

### Popups (all `components/BarPopup` — drop-down layer surfaces, Overlay layer, focus grab)
| Surface | Contents |
|---|---|
| Dashboard (900 px, `DashboardWindow`) | `TabBar` + sliding `Loader` pages |
| › Overview | ClockCard, MonthCard, AgendaCard ‖ PlayerCard, ResourcesCard, GithubCard |
| › Media | CoverArt 380², title/artist/album, LyricsView, Progress, Transport, volume Slider, LibraryCard (liked/playlists/albums, filter) |
| › System | StatCard CPU/GPU(+VRAM)/Memory with sparklines, Storage meters, Network row, footer |
| › Weather | now card, 24 h column chart, 7-day range bars |
| › GitHub | profile stats, full-year ContributionGrid, recent commits, repos, open PR/review/issues |
| › Docker | container list with start/stop/restart (currently "0 / 0 running") |
| Quick Settings (540 px) | `MainPage`: ProfileCard (avatar, 3 tools, 5 power buttons) + 6 Tiles (VPN, BT, Night light, DND, Caffeine, Sound) |
| › network / bluetooth / sound / nightlight / notifications / mail / screenshot | `PageHeader` + Cards; slide-in sub-pages |
| Launcher (640 px) | modes apps / clipboard / keybinds (chips, Alt+1-3), prompt, ListView, hint footer |
| Tray menu (300 px) | DBus menu via `QsMenuOpener` |
| Lock (`modules/lock/LockScreen`) | `WlSessionLock`, per-output blurred wallpaper, bar-like strip, 132 px clock, avatar card, PAM prompt, power buttons |

### Services (`services/`, all `pragma Singleton` QtObjects)
| Service | One line |
|---|---|
| `Ui` | which popup/screen/tab/page is open; toggle/dismiss/back; 300 ms "dismiss then toggle" swallow |
| `Hyprland` | thin wrapper over `Quickshell.Hyprland` + `dispatch()` |
| `Audio` | `pactl` multi-section poll, re-run on `pactl subscribe` events; single `_runner` for setters |
| `Bluetooth` | native `Quickshell.Bluetooth` + `bluetoothctl` agent kept alive (restart 5 s) |
| `Network` | 5 s `sh` poll: `mullvad status`, default route, `ping 1.1.1.1`, `/sys/class/net` |
| `Sys` | 2 s `sh` poll: `/proc/stat`, hwmon, meminfo, drm, loadavg, `ls /proc`, `df`; histories |
| `Docker` | `docker ps` + `docker events` stream + 10 s fallback poll |
| `Desktop` | 5 s poll hyprsunset + dunstctl; night light state file; dunst history; power actions |
| `Mpris` | player pick, optimistic play state, 500 ms position ticker, `launch()` of spotify_player TUI in tmux |
| `Spotify` | spotify_player CLI library (disk-cached), shuffle/repeat state, play contexts |
| `Lyrics` | lrclib via `curl`, on-disk cache, only while Media tab shown |
| `Weather` | Open-Meteo `curl`, 15 min |
| `Mail` | `scripts/proton-mail.py` (Bridge IMAP, read-only), notify-send for new uids |
| `Calendar` | `scripts/proton-calendar.py` (ICS), `byDay` map |
| `Github` | one `gh api graphql` + notifications count, 10 min |
| `Launcher` | DesktopEntries, scorer, usage counts, `= calc` via `Function()` |
| `Clipboard` | cliphist list/decode/delete, two `wl-paste --watch` children, thumb cache |
| `Keybinds` | `hyprctl binds -j` → readable rows, runnable flag |
| `Screenshot` | grimblast/tesseract/satty actions, latest file |
| `Lock` | PAM, caps, `awww query` wallpapers, logind delay inhibitor + `gdbus monitor`, 2 IdleMonitors, caffeine |

External pieces: dunst (notifications + popups), hyprsunset, awww + cron `randomWallpaper.sh` every 10 min
from `~/Pictures/Wallpapers/dore` (12 images), SDDM theme `sddm/rice`.

---

## 2. Cohesion audit

### Spacing / sizes
- Popup content margin is `Theme.pad + 4` (15) while Cards pad 11 and gaps are 11 (`Theme.pad`) between cards but 8 (`Theme.spacing`) between QS tiles and 4 (`spacing / 2`) between chips — three different gutters on one screen (QS main: tiles 8, cards 11).
- Row heights are each hand-computed: `DeviceRow` `fontSize*2+8`, launcher `fontSize*2+10`, TrayMenu `fontSize+14`, GithubTab `Line` `implicitHeight+6`, notification row `+12`. No shared `ListRow`.
- Fixed px leaks: `MediaTab.coverSize 380`, volume slider `220`, Docker list max `520`, library list `300`, notifications max `560`, weather chart `150`/`40`/`50`/`90`, lock card `460`, lock clock `132`, avatar `96`, Meter bar `10`, Slider handle `8×20`, Progress `8`, Contribution cell `11/12`.
- Dashboard panel height jumps per tab (Docker ≈ 110 px, Media ≈ 800 px) — the sliding animation also animates the height, which reads as jitter.

### Typography
- Theme declares 4 text sizes (14/18/22/66) + 2 icon sizes, but code uses **65 offset expressions** producing ~13 distinct sizes (10, 11, 12, 13, 14, 15, 16, 18, 22, 33, 44, 66, 132). Most common: `fontSizeSmall - 2` ×20, `- 3` ×13, `- 1` ×10, `+ 1` ×8. Off the 11 px DepartureMono grid (12, 13, 15 render soft); `fontSizeSmall` (14) and `fontSize` (18) themselves are off-grid despite the comment.
- Headings: CardHeader = UPPERCASE bold small + letterSpacing 1; PageHeader = UPPERCASE bold normal, no spacing; TrayMenu title = `fontSizeSmall-1` letterSpacing; launcher section header = `fontSizeSmall-2`, not bold; MonthCard title = separate copy of CardHeader styling. Five heading styles.
- Raw `Text`/`TextInput` bypassing `Label`: `Workspaces`, `ScrollingText` (×2), `LibraryCard` filter, launcher input.

### Colours
- Semantic roles are used 333 times, but **108 raw palette references** bypass them (purple ×19, yellow ×17, red ×15, green ×11, aqua ×11, blue ×9, orange ×8, bg0 ×5 …). Each card picks its own header accent (Agenda aqua, Player purple, Resources info, Github green, Repos yellow, Open purple, Docker blue, Storage yellow…), so the dashboard is a rainbow of header colours with no rule.
- QS tiles: each active tile fills its icon cell with a different hue (VPN green, BT blue, Night orange, DND purple, Caffeine yellow, Sound aqua) — 4 lit tiles on screen = 4 colours (see `qs-main.png`).
- "Sound" tile is *active when unmuted*, so it is lit almost always — inverts the meaning of "active" used by every other tile.
- Media button glyph shows **state** (󰏤 = paused) while PlayerCard/Transport show the **action** (▶ = press to play) — opposite semantics side by side.

### Hover / active states
- `BarButton`: hover = `surface2` (bg3, lighter), active = `surface1` (bg2, darker) → hover is louder than "open". `Workspaces` hover = surface2, `TabBar` hover = surface1, `DeviceRow` hover = surface1, launcher hover = surface0 and selected = surface1, `Tile` hover surface1, `IconButton` base surface1 → hover surface2.
- Accent appears in **five idioms**: underline (BarButton, TabBar, Workspaces), left bar (DeviceRow active, launcher selected, TrayMenu hover, Agenda event, critical notification), full fill (IconButton `checked`, Tile icon cell, Switch, MonthCard today), border (Tile active, input focus, Switch hover, lock prompt), text colour (headers). No single "selected" treatment.
- `Tile` press scales 0.98; nothing else has press feedback.

### Component reuse (re-implementations)
| Should reuse | Re-implemented in |
|---|---|
| `BarButton` | `Workspaces` cells (own hover rect, underline, MouseArea, raw Text) |
| `CardHeader` | `MonthCard` title row, `TrayMenu` title, launcher section header |
| `DeviceRow` / a `ListRow` | GithubTab `Line` + repo rows, NotificationsPage delegate, launcher delegate, TrayMenu rows, AgendaCard rows |
| `Meter`/track | `Progress` (seek bar), WeatherTab 7-day range bar, NightLight warm strip |
| a `TextField` | launcher prompt, LibraryCard filter, lock prompt (3 copies, 2 blinking-cursor copies) |
| a `Chip`/segmented control | launcher mode chips, Library kind chips, Screenshot action grid, NightLight presets, Mpris player picker (all `IconButton text: … checked:`) |
| a `ConfirmButton` | power arm/fire logic duplicated in `ProfileCard` and `LockScreen.PowerButtons` |
| `Stat` | `GithubTab.Stat`, `WeatherTab` Stat/Val, `StatCard` big number — three local components |
| `fmtAge` | `Desktop.fmtAge`, `Github.age`, `MailPage.age` — three copies |

### Naming
- `state_` (Mail, Calendar, Github) vs `status` (Lyrics) vs `available`/`daemonUp`/`present`.
- `Svc.Docker.restartC` (name clash workaround); `Mpris.running` and `hasPlayer` aliases; `Audio.percent`/`muted` aliases unused.
- Popup ids: `Ui.open` comment lists `"dashboard" | "quicksettings"` but values also `launcher`, `traymenu`.

### Interaction model
- Right-click means three different things: tray = menu, QS glyphs = toggle DND, media = next track. Middle-click: mute, play-pause, webmail, tray secondary.
- Escape: BarPopup closes; QS sub-page goes back; launcher closes; LibraryCard filter clears text; lock clears buffer. Consistent enough.
- Keyboard: launcher is fully keyboard-driven; Dashboard only Ctrl+Tab/Alt+N (no focus movement into cards; library filter and month grid are mouse-only); **Quick Settings has no keyboard navigation at all** (tiles, sliders, device rows, power buttons are click-only); tray menu mouse-only.
- Focus grab is per popup; opening a second popup closes the first (good), but clicking a bar button on the *other* monitor while one is open dismisses then needs a second click.

---

## 3. Clunkiness / usability

- **Notifications live in the wrong place**: history is QS › DND tile ▸ (or SUPER+Y). It is a flat list of dunst JSON with no grouping — the current history is 23 near-identical "Claude Code · Task finished/Awaiting input" rows (`qs-notifications.png`). Icon lookup guesses from app name, so most rows fall back to a bell.
- **Mail is a QS sub-page**: mail has nothing to do with quick settings; it is reached from the bar mail icon only.
- **ProfileCard row is cramped**: 8 unlabeled 34 px icon buttons (screenshot, clipboard, keybinds │ lock, logout, suspend, reboot, poweroff) with names only on hover in the subtitle line.
- **QS tile grid**: Caffeine has no ▸ cell so its right edge does not line up with the others; Sound tile body click = mute (surprising for a big tile).
- **Dashboard Overview** columns end at different heights; Docker tab costs a whole tab for "no containers".
- **Media tab**: LibraryCard capped at 300 px inside a popup that is already ~800 px tall; long lists (37 playlists) scroll inside a scroll-less popup.
- **System tab**: network row wraps unevenly; memory sparkline reads as a solid block, CPU/GPU sparklines near-flat (bar uses `autoScale`, StatCard does not — same data, two scalings).
- **Launcher** shows junk entries (About Xfce, Avahi ×3) and Alacritty after the switch to ghostty; no hidden-app list.
- **Laggy/lossy controls**: `Audio`, `Desktop`, `Docker` funnel setters through one `Process` (`_runner`). Setting `running = true` while it runs is a no-op, so fast wheel scrolls and slider drags **drop steps**, and the slider snaps back to the polled value afterwards. Night light avoids this with a debounce timer; Audio does not.
- **Ui 300 ms dismiss-swallow** (`Ui.toggle`) is a workaround for focus-grab ordering; works but can eat a genuine re-open click.
- **Screenshot** waits `animLong + 80` ms for the popup to leave — fine; but OCR/edit availability is reprobed only when the page opens.
- **Duplicated entry points** (fine individually, confusing in sum): clipboard (launcher chip, QS tool button, SUPER+SHIFT+V); keybinds (chip, QS tool, SUPER+SHIFT+/); DND (tile, tile ▸ page switch, bar right-click, SUPER+SHIFT+D); system monitor (bar button → System tab, SUPER+I, SUPER+X btop).
- **Mouse-only**: all QS controls, tray menus, month navigation, library rows, power arming, notification actions.
- **Hyprland binds**: `SUPER+M` = `exit` with no confirm (one key from SUPER+N/SUPER+,); no bind for Media/GitHub/Docker tabs or mail; README claims SUPER+, / . include play-pause (they don't); volume keys go to `wpctl` directly so there is no OSD.
- **dunst** still says `dmenu = /usr/bin/tofi` (tofi replaced by launcher), uses a 3 px frame (shell uses 1 px), offset 60 px vs bar 44 px.

---

## 4. Theming readiness

**Today**: `config/Theme.qml` is a `pragma Singleton` of **readonly** properties: 30 hex literals (all colour hex is here — good), semantic roles, one `fontFamily`, a size scale, `radius: 0`, `border: 1`, `accentThickness: 2`. `Settings.qml` is likewise all readonly. Nothing is loaded from disk; there is no runtime mutability or persistence.

### Hard-coded occurrence counts (outside Theme.qml)
| File | raw palette | size offsets | radius literal | Qt colour fn | raw Text |
|---|---|---|---|---|---|
| dashboard/DockerTab | 10 | 0 | – | – | – |
| dashboard/SystemTab | 10 | 1 | – | – | – |
| dashboard/GithubTab | 9 | 9 | – | – | – |
| services/Weather | 8 | 0 | – | – | – |
| dashboard/WeatherTab | 6 | 6 | – | – | – |
| quicksettings/MainPage | 6 | 0 | – | – | – |
| quicksettings/NotificationsPage | 5 | 6 | – | – | – |
| quicksettings/NetworkPage | 5 | 0 | – | – | – |
| lock/LockScreen | 4 | 1 (+literal 132) | 1 (`width/2`) | 1 (`Qt.alpha`) | – |
| dashboard/MonthCard, ResourcesCard, ContributionGrid | 4 each | 2 / 0 / 1 | – | ContributionGrid 1 (`Qt.darker`) | – |
| quicksettings/NightLightPage | 4 | 1 | – | 1 (`Qt.rgba` warm strip) | – |
| quicksettings/BluetoothPage, AgendaCard, LibraryCard | 3 each | 0 / 3 / 1 | – | – | LibraryCard 1 |
| MediaButton, GithubCard, MediaTab, PlayerCard, launcher | 2 each | 1/1/0/0/10 | – | – | launcher 1 |
| QuickSettingsButton, Slider, ScrollingText, LyricsView, Progress, Transport, MailPage, ScreenshotPage, SoundPage, services/Github | 1 each | various | – | – | ScrollingText 2 |
| quicksettings/ProfileCard | 0 | 1 | 1 (`width/2`) | – | – |
| bar/Workspaces | 0 | 0 | – | – | 1 |
| **Totals** | **108** | **65** | **2 round literals** | **3** | **6** |

- `Theme.radius` is referenced in only **2** files (`Card`, `IconButton`) out of ~73 `Rectangle`s (components 27, dashboard 15, QS 8, launcher 8, lock 8, bar 7). Switching to round today would round cards and buttons only; tiles, chips, inputs, rows, meters, tabs, popups stay square.
- Accent geometry is baked into components: underline (`BarButton`, `TabBar`, `Workspaces`), left bar (`DeviceRow`, launcher, TrayMenu, Agenda, Notifications) via `accentThickness` (8 files).
- Fonts: one family string (good), but sizes are tuned to DepartureMono's 11 px grid; a proportional font needs its own scale and different row heights.
- External consumers with their own copies: `dunstrc` (7 hex, `corner_radius 0`, font), `hypr/look_and_feel.conf` (2 border rgba, `rounding = 0`), `sddm/rice` (palette + font), ghostty/nvim/tmux/btop/gtk palettes.

### What runtime theme switching needs
1. `Theme` becomes mutable: palette/shape/font loaded from `~/.config/rice/theme.json` via `FileView` + `JsonAdapter` (Quickshell 0.3), with `themes/<name>.json` presets in the repo. Keep semantic names; add **categorical** roles (`catMedia`, `catSystem`, `catNet`, `catDev`, `catCalendar`, `catWeather`) to replace the 108 raw refs, and `chart0..4` for heat/contribution levels.
2. Shape tokens: `radius`, `radiusSmall`, `radiusPill`, `border`, plus **`accentStyle: "underline" | "pill"`** derived from `shape` (square → underline, round → pill). Components then render *one* `AccentIndicator` that is either a 2 px underline/left bar or a filled pill behind the item.
3. Type tokens per font: `{ family, sizes: { xs, sm, md, lg, xl, huge }, gridPx }` so the 13 ad-hoc sizes collapse to ~6 named ones.
4. A `ThemeSync` service that writes dunstrc include, `hyprctl keyword general:col.active_border …` / `decoration:rounding`, and templated configs for ghostty/nvim/tmux on change.
5. Every `Rectangle` that is a surface uses `radius: Theme.radius*`; round-only literals (avatars) stay.

Effort: tokens + JSON load **M**; sweeping 108 + 65 + ~60 radius sites **M-L**; external sync **M**.

---

## 5. Architecture health

**Good**
- Clean layering: config → services (no UI) → components → modules; one `IpcHandler`.
- Long-lived helpers all go through `Settings.tether` (`setpriv --pdeathsig`); verified 7 children, no orphans.
- Lazy where it matters: Lyrics/Spotify/notification history gated by `wanted`; Dashboard tabs are `Loader`s; Lock surfaces loaded only while locked; secrets in `~/.config/rice/`.
- Services degrade gracefully (Mail/Calendar "unconfigured", Clipboard reprobe, Weather retry).

**Problems**
- **Memory: 494 MB RSS** for a bar. Contributors: every bar (×2 screens) instantiates Dashboard, Launcher, QuickSettings and TrayMenu windows; all 8 QS pages are plain children (not Loaders) per screen; Dashboard `Loader { active: root.visible }` loads **all six tabs** on open (two ContributionGrids ≈ 2×365 Rectangles, 42 MonthCard cells each calling `Calendar.eventsOn`). `UseQApplication` + MultiEffect lock + icon caches add baseline. Worth measuring with tabs lazily loaded and popups shared per screen.
- **Process churn**: ~60 `sh` forks/min at idle (Sys 30, Network 12, Desktop 12, Docker 6) each with several children (`ls /proc | wc`, `ping`, `mullvad status`, `dunstctl ×3`, `hyprctl ×2`). Network pings 1.1.1.1 every 5 s forever.
- **Singleton lifetime**: once the Dashboard opened once, `Docker` keeps `docker events` (35 MB RSS) + 10 s polls forever even with zero containers; `Github`/`Weather` timers run regardless of visibility (fine), Desktop 5 s poll regardless of QS.
- **Lossy single-runner setters** (Audio/Desktop/Docker `_run`): see §3; fix with a queue or "latest-value" debounce.
- **Error handling**: exit codes ignored in Audio/Network/Docker/Desktop; `Github._parse` returns silently on bad JSON (state stays "loading" → card hidden forever); `Keybinds` swallows errors into `[]`; `Launcher.calc` uses `Function()` (input is regex-filtered — acceptable, but note it).
- **Dead code**: `Audio.percent/muted`, `Mpris.hasPlayer/all`, `Weather.available`, `Github.starred`, `Hyprland.raw/focusedWorkspace`, `Desktop.temperature` exposed but unread, `Settings.show*` flags partly undocumented.
- **Duplication**: three `age()` helpers, two power-arm implementations, three text inputs, three Stat components (§2).
- **Fragile**: `.qmlls.ini` is a symlink into `/run/user/1000/quickshell/vfs/…` (breaks after reboot); `.claude/settings.local.json` lives inside the rice dir (references a deleted `core/PopoutHost.qml`).
- **Wallpaper flow**: cron every 10 min picks from one folder; in span mode `CURRENT` is a slice path, so the "not the current one" exclusion never matches. Lock reads wallpapers via `awww query` at lock time only.

**Docs drift vs `docs/architecture.md`**
- QS Main described as "2×2 tiles + Sound card (output + mic sliders)"; reality is 6 tiles (incl. Caffeine, Sound) and no sound card.
- IPC list omits `lock`, `caffeine`, `music`, `playpause/next/previous`.
- `Ui.open` values omit `launcher`, `traymenu`; DashboardWindow header comment says Alt+1…4 (there are 6 tabs).
- Settings summary omits weather/mail/calendar/github/lock/spotify keys.
- "Rough edges / next" still lists notification center + OSD + theme presets — all still open.
- README keybind table claims SUPER+, / . do play-pause.

---

## 6. Gaps vs user goals

| Goal | Exists | Missing |
|---|---|---|
| 1 Cohesion / fewer cramped widgets | shared Theme, Card/Tile/Slider/TabBar, consistent popup chrome | §2 list: 5 heading styles, 13 sizes, 5 accent idioms, rainbow headers, cramped ProfileCard, QS not keyboardable |
| 2 Side panels | none — every surface is a drop-down `BarPopup` | a `SidePanel` (right-anchored, full-height layer surface); notification center grouped by source (mail/Discord/system/Claude Code) needs an in-shell `NotificationServer` (replace dunst); weather & feeds panels; no RSS/news service |
| 3 Settings shell | none; `Theme`/`Settings` are readonly constants | JSON-backed settings + theme store, settings window with pages (Appearance, Wallpaper, Bar, Services, Privacy), theme = palette + shape + font, accent style follows shape |
| 4 Wallpaper manager | cron random picker, span slicing, awww, lock reads per-output wallpaper | in-shell picker grid with thumbnails, metadata sidecar (`wallpapers.json`: theme, season, tags, span), suggest by theme + month, "pin" vs rotate, IPC `wallpaper next/set` |
| 5 Voice assistant | useful hooks: `IpcHandler`, `Launcher.search/launch`, `Spotify.playlists` + `playPlaylist`, `Mpris`, `Keybinds.rows.runnable` (an allowlist seed), `Github.repos`, tmux/ghostty conventions | wake word, whisper STT (Vulkan build; no ROCm), local 8B LLM (llama.cpp Vulkan) with a tool schema, command allowlist, "ask before escalating to `claude -p`" confirm UI, listening OSD, recent-project index ("last night's claude code project" needs a history of `claude` sessions / tmux sessions) |
| 6 Focus mode | caffeine (opposite), DND toggle | timer UI + countdown in bar, app blocking (Hyprland `windowrule`/close on open via event socket), site blocking without root (browser policy needs root once; alternatives: Firefox extension or a user-level DNS/proxy), mode presets that also flip DND |

---

## 7. Proposals (ranked)

| # | Proposal | Files | Effort |
|---|---|---|---|
| 1 | **Token pass**: add named type scale (xs/sm/md/lg/xl/huge), categorical colour roles, `radius*`, `accentStyle`; replace the 108 raw palette refs and 65 size offsets | `config/Theme.qml`, every module listed in §4 | M |
| 2 | **Make Theme/Settings live**: `FileView`+`JsonAdapter` for `~/.config/rice/{settings,theme}.json`, presets in `rice/themes/*.json`; keep current values as defaults | `config/Theme.qml`, `config/Settings.qml`, new `config/themes/` | M |
| 3 | **Shared primitives**: `ListRow`, `TextField` (blinking block cursor), `Chip`/`Segmented`, `ConfirmButton`, `Stat`, `AccentIndicator` (underline ⇄ pill), `SectionHeader`; port Workspaces to BarButton | `components/*`, launcher, QS pages, GithubTab, NotificationsPage, LockScreen, ProfileCard | M |
| 4 | **Fix lossy setters**: latest-value queue for `Audio`, `Desktop`, `Docker` (`_run` → pending command; re-run on exit) and debounce slider drags like night light | `services/Audio.qml`, `Desktop.qml`, `Docker.qml` | S |
| 5 | **In-shell notifications + side panel**: `Notifications` service (`NotificationServer`, history persisted, grouped by app/category), popups (toasts) + right `SidePanel` with groups (Mail, Discord, System, Dev); retire dunst | new `services/Notifications.qml`, `components/SidePanel.qml`, `modules/notifications/`, `hyprland.conf` (drop `exec-once = dunst`) | L |
| 6 | **Settings window** (Appearance: theme/shape/font/preview; Wallpaper; Bar items; Services/refresh; Privacy/lyrics) reachable from QS profile + SUPER+, | new `modules/settings/`, `shell.qml` IPC `settings(page)` | L |
| 7 | **Wallpaper service + picker**: `Wallpaper` service owning awww, `wallpapers.json` metadata (theme, season, span), suggest by theme + month, replace cron with a shell Timer | new `services/Wallpaper.qml`, `modules/settings/WallpaperPage.qml`, `randomWallpaper.sh` (keep span slicer as helper), `cron/crontab` | M |
| 8 | **Theme sync** to dunst (until #5), Hyprland borders/rounding (`hyprctl keyword`), ghostty/nvim/tmux templates | new `services/ThemeSync.qml` + `scripts/theme-apply.sh` | M |
| 9 | **Lazy & lighter**: Dashboard loads only the current tab (keep last one alive), QS pages as `Loader`s, one Dashboard/QS window shared across screens (re-parent via `screen`), Docker service stops `docker events` when tab hidden, Network ping every 30 s; re-measure RSS | `DashboardWindow.qml`, `QuickSettingsWindow.qml`, `Bar.qml`, `services/Docker.qml`, `Network.qml` | M |
| 10 | **Declutter QS**: move Mail to the notification/side panel, notifications out of the DND tile, tools row → labelled "Tools" chips page, power into a `Session` sub-page or a 2-row grid with labels; add arrow/Enter keyboard nav over tiles | `modules/quicksettings/*` | M |
| 11 | **Interaction rules**: right-click = context/secondary everywhere (QS glyph right-click opens notifications instead of silently toggling DND), state-vs-action glyph rule for media, Sound tile active = muted-off semantics like others | bar buttons, `MainPage.qml`, `MediaButton.qml` | S |
| 12 | **Focus mode**: `Focus` service (duration, blocklist apps via Hyprland events → `closewindow`, DND on, bar countdown island), presets in settings JSON; site blocking via Firefox policy installed once (user runs the sudo one-liner) | new `services/Focus.qml`, QS tile, bar segment | M |
| 13 | **Voice assistant scaffold**: separate tethered daemon (`scripts/voice/`) — openWakeWord → whisper.cpp (Vulkan) → llama.cpp 8B with JSON tool calls mapped to `qs ipc` + allowlist; shell side = `Voice` service + listening OSD + confirm card for `claude -p` escalation | new `services/Voice.qml`, `modules/voice/`, `scripts/voice/` | L |
| 14 | **Hygiene**: fix docs drift (§5), remove dead props, dedupe `age()`, drop `.qmlls.ini` symlink from repo, move `.claude/` out, dunst `dmenu`, hide junk desktop entries (`Settings.launcherHidden`), confirm on SUPER+M, add SUPER binds for media tab/mail/settings | docs, services, `keybindings.conf`, `dunstrc` | S |
| 15 | **Docker tab → System sub-card** shown only when containers exist; reclaim the tab slot for a feeds/news tab or the side panel | `Settings.dashboardTabs`, `SystemTab.qml`, `DockerTab.qml` | S |

Suggested order: 4 → 14 → 1 → 3 → 2 → 9 → 10/11 → 5 → 6 → 7 → 8 → 12 → 13.
