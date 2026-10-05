# quickshell-rice

Quickshell shell for a Hyprland rice. Retro gruvbox look (DepartureMono, square
corners, hairline borders, underline accents) with a lyne-dots-style layout:
three bar islands, a tabbed dashboard and a Quick Settings panel.

```
 launcher · workspaces │ window    clock · media · system · weather    tray │ mail · ⛨ ⇄ ᛒ 🔇 vol
 └ Launcher                          └────── Dashboard ──────┘            └ Quick Settings
```

## Layout

- `shell.qml` — entry point: one Bar per screen + `IpcHandler`
- `config/` — Theme (palette + semantic tokens) and Settings singletons
- `services/` — singleton data/control layer (no UI)
- `components/` — shared retro widgets (BarButton, Card, Tile, Slider, Sparkline, Meter, BarPopup…)
- `modules/bar/` — the bar and its buttons
- `modules/dashboard/` — tabbed dashboard: Overview, Media, System, Weather, GitHub, Docker
- `modules/quicksettings/` — Quick Settings: profile/power, tiles, sound, sub-pages
- `modules/launcher/` — launcher with three modes: apps (icons, fuzzy, frequent, `=` calculator), clipboard (cliphist), keybinds
- `scripts/` — Python helpers: `proton-mail.py` (Bridge IMAP), `proton-calendar.py` (ICS)
- `docs/architecture.md` — deeper overview
- `.qmlls.ini` — qmlls LSP config

## Using it

| Where | Click | Middle | Right | Wheel |
|-------|-------|--------|-------|-------|
| Arch glyph | Launcher | | | |
| Workspace number | go to it | | | walk this monitor's workspaces |
| Clock | Dashboard › Overview | | | |
| Media | Dashboard › Media (opens spotify_player if nothing runs) — player, lyrics, and a **Library** card: Liked Songs / playlists / albums, filter, shuffle; click to play | play/pause | next | player volume |
| System sparkline | Dashboard › System (hover shows numbers) | | | |
| Weather | Dashboard › Weather | | | |
| Tray icon | activate | secondary | menu (shell-styled) | |
| Mail | Quick Settings › Mail (setup steps until configured) | open webmail | | |
| Status glyphs | Quick Settings | mute | do-not-disturb | volume |

Popups close on Escape or a click outside. Dashboard: Ctrl+Tab / Ctrl+Shift+Tab
cycle tabs, Alt+1…6 jump. Quick Settings: ‹ or Escape goes back from a sub-page.
Power buttons arm on the first click and fire on the second (3s window).

Quick Settings' profile card (avatar = `~/.face.icon`, same as SDDM) row:
**screenshot**, **clipboard**, **keybinds** │ lock, log out, suspend, reboot,
shut down (hover names the button). Tiles: Mullvad, Bluetooth, Night light,
Do not disturb, Caffeine, Sound (click mutes; ▸ = volume sliders + devices).

## Lock screen

SUPER+Escape or the lock button. One surface per monitor: that monitor's
wallpaper blurred, bar-style top strip (lock time, clock, now playing,
suspend/reboot/power off), big clock, avatar card with a `>` prompt — your
password is checked by PAM (`login`). Caps-lock and wrong-password messages.
Auto-locks after `Settings.lockAfterMin` (10) idle minutes, turns screens off
after `screenOffAfterMin` (15), and locks before suspend (logind delay
inhibitor). Caffeine (tile or SUPER+SHIFT+C) pauses both. The SDDM theme in
`sddm/rice` has the same look.

Launcher modes — chips at the top, or Alt+1 / Alt+2 / Alt+3: **apps**, **clipboard**
(cliphist history incl. image thumbnails; Enter copies, Shift+Del removes,
"wipe" clears; the shell runs the `wl-paste --watch cliphist store` watchers),
**keybinds** (every Hyprland bind with a readable label, searchable; Enter runs
it — `exit` and mouse binds are view-only).

Screenshot page (Quick Settings › screenshot, or PRINT): choose *save + copy*,
*copy*, *text (OCR → clipboard, tesseract)* or *edit (satty)*, then Region /
Window / Monitor / All screens. Saves to `~/Pictures/Screenshots`; shows the
last capture.

Launcher: type to search (name, generic name, keywords, binary; fuzzy; your
most-launched apps rank higher). ↑↓ / Tab / Ctrl+J/K move, Enter launches,
Esc closes. `= 2^10 + 3` evaluates; Enter copies the result (wl-copy).
Terminal apps open in `Settings.terminal`.

Icons come from the **Gruvbox-Plus-Dark** theme (`//@ pragma IconTheme` in
`shell.qml`), installed per-user from
[gruvbox-plus-icon-pack](https://github.com/SylEleuth/gruvbox-plus-icon-pack):

```
curl -LO https://github.com/SylEleuth/gruvbox-plus-icon-pack/releases/download/v6.6.0/gruvbox-plus-icon-pack-6.6.0.zip
unzip -q gruvbox-plus-icon-pack-6.6.0.zip 'Gruvbox-Plus-Dark/*' -d ~/.local/share/icons/
```

Weather: Open-Meteo (no key) for `Settings.weatherLat/Lon` ("York, ME"),
°F/mph by default, refreshed every 15 min.

## Proton Mail + Calendar

The mail icon is dimmed and the agenda hidden until configured. Secrets live in `~/.config/rice/` (mode 600,
**never in git**).

**Mail** — via [Proton Mail Bridge](https://proton.me/mail/bridge) (paid plan,
`pacman -S protonmail-bridge`). Sign in to Bridge once, copy the IMAP username
and Bridge password from its mailbox settings, then:

```
umask 077; printf 'machine 127.0.0.1 login %s password %s\n' 'USERNAME' 'BRIDGE_PASSWORD' > ~/.config/rice/proton-bridge.netrc
```

The bar shows the unread count (polled every 2 min); Quick Settings › Mail lists
unread subjects. INBOX is opened read-only with `BODY.PEEK`, so nothing gets
marked read. New mail fires a `notify-send`. Bridge must be running
(`protonmail-bridge-core --noninteractive` runs it headless after the first sign-in; the Mail page has a start button).

Startup: Bridge needs a Secret Service keychain — `gnome-keyring`, whose
keyring must be named `login` with your login password so SDDM's PAM
(`pam_gnome_keyring`) unlocks it at login. Hyprland ignores
`~/.config/autostart`, so Bridge starts from `hyprland.conf`:
`exec-once = sleep 3 && protonmail-bridge-core --noninteractive` — the core
directly: in 3.27 the launcher (`protonmail-bridge --noninteractive`) waits for a
gRPC handshake the headless core never sends and pops "Server did not provide
gRPC service configuration in time". The first sync
of a large mailbox takes a while; counts fill in as it goes.

**Calendar** — Proton Calendar › Settings › calendar › *Share via link*, then
`umask 077; echo 'LINK' > ~/.config/rice/proton-calendar.url`. Anyone with the
link can read that calendar. Events (recurrences expanded, timezones converted)
show as dots on the Overview month, and the agenda under it lists upcoming
events — click a day for that day's. Refreshes every 30 min; cached offline.

## GitHub

Uses the `gh` CLI's login (`gh auth login`); nothing is stored by the shell.
The Overview card shows commit frequency only (contribution grid, today /
streak / this week); its ▸ opens the **GitHub** tab: profile stats, full-year
grid (busiest day, longest streak), recent commits across your recently pushed
repos, repositories (language, stars, last push, private), open PRs / review
requests / issues and the unread notification count. Refreshes every 10 min.

## Keybinds (in `~/.config/hypr/external/keybindings.conf`)

| Keys | Opens |
|------|-------|
| SUPER+R | Launcher (`$menu`) |
| SUPER+S | Music: spotify_player in tmux session `music` (close the window = detach, playback continues) |
| SUPER+A | Quick Settings |
| SUPER+O | Dashboard › Overview |
| SUPER+I | Dashboard › System |
| SUPER+W | Dashboard › Weather |
| SUPER+Y | Notification history |
| SUPER+SHIFT+N | Night light on/off |
| SUPER+SHIFT+D | Do not disturb on/off |
| SUPER+Escape | Lock |
| SUPER+SHIFT+C | Caffeine on/off |
| SUPER+SHIFT+V | Clipboard history |
| SUPER+SHIFT+/ | Keybinds |
| SUPER+SHIFT+S | Screenshot region → `~/Pictures/Screenshots` + clipboard |
| SUPER+SHIFT+T | Region → OCR text to clipboard |
| PRINT | Screenshot page |
| SUPER+, / SUPER+. / media keys | previous / next / play-pause (`playerctl`, spotify_player first) |

Quick Settings tiles: the ▸ on **Night light** opens warmth (2500–6500K,
presets) and brightness (gamma) sliders — moving one turns it on; the ▸ on
**Do not disturb** opens dunst's notification history (click a row to show it
again, 󰆴 to remove, clear all).

## IPC

```
qs -c rice ipc call rice dashboard overview   # overview | media | system | weather | github | docker
qs -c rice ipc call rice dashboard weather
qs -c rice ipc call rice quicksettings ""     # "" | network | bluetooth | sound | nightlight | notifications | mail | screenshot
qs -c rice ipc call rice launcher
qs -c rice ipc call rice clipboard
qs -c rice ipc call rice keybinds
qs -c rice ipc call rice screenshot area save  # area|active|output|screen  save|copy|text|edit
qs -c rice ipc call rice nightlight           # toggle
qs -c rice ipc call rice dnd                  # toggle
qs -c rice ipc call rice lock
qs -c rice ipc call rice caffeine             # toggle
qs -c rice ipc call rice mail                 # Quick Settings › Mail
qs -c rice ipc call rice music                # open / attach spotify_player
qs -c rice ipc call rice playpause            # also: next, previous
qs -c rice ipc call rice refresh              # weather + mail + calendar + github now
qs -c rice ipc call rice close
```

## Dev

Linked into `~/.config/quickshell/rice`. Hot-reloads on save.

```
quickshell -c rice           # run
quickshell log -c rice       # logs (load errors show here)
# new directories / pragma changes need a restart, not just a hot reload
qmlls -p .                   # editor LSP
```

## Autostart

`~/.config/hypr/hyprland.conf`: `exec-once = quickshell -c rice`
