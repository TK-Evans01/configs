# quickshell-rice

Quickshell shell for a Hyprland rice. Retro by default (gruvbox-material,
DepartureMono, square corners, hairline borders, underline accents) with ten
switchable themes, a round shape option, and a lyne-dots-style layout: three
bar islands, a tabbed dashboard, Quick Settings, and a right sidebar for
notifications, weather and feeds. It is also the notification daemon.

```
 launcher · workspaces │ window    clock · media · system · weather    tray │ 󰇮 󰂚 · ⛨ ⇄ ᛒ 🔇 vol
 └ Launcher                          └────── Dashboard ──────┘            │    └ Quick Settings
                                                                          └ Sidebar (right edge) ┐
                                                                    notifications · weather · feeds
```

## Layout

- `shell.qml` — entry point: one Bar per screen + `IpcHandler`
- `config/` — `Theme` (tokens, loads `themes/<id>.json`), `Prefs` (runtime choices in `~/.local/state/rice/prefs.json`), `Settings` (readonly defaults), `Fmt`, `actions.json` (action allowlist)
- `themes/` — theme presets + `fonts.json` (font registry with per-font sizes)
- `services/` — singleton data/control layer (no UI)
- `components/` — shared building blocks (BarButton, AccentIndicator, ListRow, TextField, Card, Tile, EdgePanel, BarPopup…); rules in `docs/ui-rules.md`
- `modules/bar/` — the bar and its buttons
- `modules/dashboard/` — tabbed dashboard: Overview, Media, System, Weather, GitHub, Docker
- `modules/quicksettings/` — Quick Settings: profile/power, tiles, sound, sub-pages
- `modules/launcher/` — launcher with three modes: apps (icons, fuzzy, frequent, `=` calculator, `>` actions, `@` windows), clipboard (cliphist), keybinds
- `modules/sidebar/` — right-edge panel (Notifications + mail · Weather · Feeds) and notification toasts
- `modules/session/` — session drawer (lock / log out / suspend / reboot / shut down, j/k + Enter)
- `modules/osd/` — volume OSD
- `modules/settings/` — the settings window (pages from `config/settings-schema.json`)
- `scripts/` — Python helpers: `proton-mail.py` (Bridge IMAP), `proton-calendar.py` (ICS), `check-actions.py` (actions.json vs IPC)
- `docs/architecture.md` — deeper overview
- `docs/ui-rules.md` — colour, type, shape and interaction rules

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
| Mail + bell | Sidebar › Notifications (unread mail on top, then groups: chat, dev, media, system) | open webmail | | |
| Status glyphs | Quick Settings | mute | Sidebar › Notifications | volume |

Popups and side panels close on Escape or a click outside. Dashboard: Ctrl+Tab / Ctrl+Shift+Tab
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

The bar shows the unread count (checked every `mailRefreshSec`, backing off
while Bridge is down); the sidebar's notifications tab lists unread subjects at
the top. INBOX is opened read-only with `BODY.PEEK`, so nothing gets marked
read. New mail fires a notification. Bridge must be running
(`protonmail-bridge-core --noninteractive` runs it headless after the first
sign-in; Settings › Connections tests it and runs the CLI login).

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
| SUPER+S | Music: spotify_player's TUI (tmux session `music`) as a remote for the headless player `spotify_player -d` started at login — closing it never stops playback |
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
| SUPER+, / SUPER+. | previous / next track (`playerctl`, spotify_player first) |
| media keys | play-pause / next / previous; volume keys via `wpctl` |
| SUPER+SHIFT+M | Log out of Hyprland (two modifiers so it can't be hit by accident) |

| SUPER+SHIFT+A | Settings window |
| SUPER+Y | Sidebar › Notifications + mail |
| SUPER+SHIFT+Y | Sidebar › Feeds |
| SUPER+SHIFT+Escape | Session drawer |

Quick Settings tiles: the ▸ on **Night light** opens warmth (2500–6500K,
presets) and brightness (gamma) sliders — moving one turns it on; the ▸ on
**Do not disturb** opens the sidebar's notifications.

## Notifications

The shell is the notification daemon (`services/Notifications.qml`); dunst is
retired and blocked from D-Bus auto-start by the `dbus` stow package.

- Every notification is kept (`notifyHistory`, saved in
  `~/.local/state/rice/notifications.json`) and grouped by source:
  `Settings.notifySources` maps app names → mail / chat / dev / media / system.
- Toasts pop up top-right on the focused monitor with a timeout bar; hover
  pauses it, click runs the default action, right-click hides it, 󰅖 dismisses.
  Critical ones stay and ignore DND. At most `toastPerSourceMax` per source per
  30 s; the rest only land in the sidebar.
- DND (tile, `dnd` IPC, sidebar switch) silences toasts and is remembered.
- While the sidebar shows notifications, nothing toasts and everything is read.

## Settings window

SUPER+SHIFT+A, the 󰒓 button in Quick Settings, `>settings` in the launcher, or
`qs -c rice ipc call rice settings <page>`. A normal floating window ("rice
settings"; a Hyprland rule floats and sizes it), loaded only while open.

- Pages: Appearance (theme tiles — hover previews, click applies — shape,
  font), Bar, Panels, Notifications (toasts, history, source → app-name map),
  Sound (devices + **per-app volume**), Bluetooth, Network & VPN, Night light,
  Lock & idle, Weather, Mail & calendar, Feeds (add / remove), Launcher (hidden
  apps), Music, GitHub, Tools, Actions (the allowlist), About (paths, memory,
  reset all).
- Every change is live and saved as an override in `prefs.json`; a changed
  option shows its label in the accent colour and a ↺ to go back to the default.
- `/` or Ctrl+F searches pages *and* options; matching options are editable
  right in the results. j/k or ↑/↓ change page, Esc closes.
- From the CLI: `setting <key> <json>`, `settingGet <key>`, `settingReset <key>`.
- Adding an option: give it a default in `Settings.qml` as
  `Prefs.get("key", default)` and an entry in `config/settings-schema.json`.

## Connections

Settings › Connections lists third-party services with their live state:
Claude Code, GitHub (gh + SSH key), Spotify, Discord (discordo), Mullvad,
Proton Mail Bridge, Proton Calendar, Docker, Open-Meteo, lrclib. Each has
**test** (a real check), **connect** (the service's own login in a terminal,
or a typed value — saved mode 600 to `~/.config/rice/`, passed on stdin) and
**disconnect** (click twice). Definitions: `config/connectors.json`; plumbing:
`scripts/connectors.sh check|save|login|logout <id>`.

**Preview mode** walks every flow without touching real accounts: login
connectors start unconnected, connect / disconnect only report the command
they'd run, typed values land in `~/.cache/rice/connectors-preview/`.
From the CLI (handy for testing): `connectorsPreview on|off`, `connectors`,
`connectorTest|connectorLogin|connectorLogout <id>`, and
`connectorSave <id> <field> <value>` (preview only).

## Wallpapers

SUPER+SHIFT+W (or `>wallpaper`, Settings › Wallpaper) opens the picker under
the bar: a big preview, its colours, theme fit and your tags over a strip of
thumbnails — best for the current theme + season first, the rest dimmed.
←/→ browse, ↵ this monitor, shift+↵ all, S span both screens (wide images),
F favourite, Tab filter (all / suggested / favourites). Click a theme or
season chip to tag it.

- `scripts/wallpaper.py index` builds thumbnails + colour data
  (`~/.cache/rice/wallpapers`, incremental, ~0.3 s per new image) and how close
  each image sits to every theme's palette (Lab ΔE).
- Your tags live in `data/wallpapers.json` (in git, keyed by path with a
  content hash to re-link renames). `wallpaper.py bootstrap --write` fills
  suggestions for untagged images; anything you edit stops being auto.
- Rotation (replaces the old cron job): every `wallpaperRotateMin` (30) among
  the best few for now, skipping recent ones; `wallpaperNext` IPC rotates now.
- Placement: fill / fit / span (slices a wide image across both monitors).
- Theme policy: "suggest only" (default) or "follow" — applying a wallpaper
  tagged with a theme switches to it, and browsing previews its palette.

## Focus mode

Quick Settings › Focus tile (▸ for the page), `>focus` in the launcher, or
`qs -c rice ipc call rice focus <profile> <minutes>` (`""` / `0` = defaults;
`focusStatus`, `focusProfiles`). The bar's date turns into the
time left. Profiles (Settings › Focus): length, breaks, rounds,
site bundles (`config/focus-bundles.json`) + extra hosts, app rules, and a
notification level (as usual / critical only / hold all). While focusing:

- **sites**: the root helper `rice-focus-dns` (`scripts/`) sinkholes the
  profile's host names for every app; a root timer lifts it at the end even if
  the shell is gone. Sinkhole-only, validated, with a protect list.
- **apps**: windows whose initial class matches are moved to `special:focus`
  (or closed) — also ones opened later — and put back at the end; the launcher
  refuses them until then (discordo runs as `dev.rice.discordo` so it can match).
- **notifications**: only critical (or none) toast; everything is kept, and
  you get a "while you focused" summary at the end.

Breaks lift the blocks. **A started session can't be cancelled** — it runs
out: no stop button or IPC, the hidden apps' workspace stays shut, and root
keeps the sites blocked until each focus phase ends (a running block can only
grow; the only way around it is a real `sudo rice-focus-dns …` with your
password). The session survives shell reloads and downtime
(`~/.local/state/rice/focus.json`; time missed while the shell was down counts).

One-time setup for site blocking (Settings › Focus shows it with a copy
button; re-run after editing the helper — sudoers only ever points at the
root-owned copy):

```
sudo sh -c 'set -e; R="$1"; install -o root -g root -m 0755 "$R/rice-focus-dns" /usr/local/bin/rice-focus-dns; install -o root -g root -m 0440 "$R/rice-focus.sudoers" /etc/sudoers.d/rice-focus; visudo -cf /etc/sudoers.d/rice-focus || { rm -f /etc/sudoers.d/rice-focus; exit 1; }' _ "$HOME/.config/quickshell/rice/scripts"
```

## Packages

Settings › Packages (`>packages` in the launcher): search official repos +
AUR (votes, popularity, maintainer, last update, out-of-date / orphaned
warnings), details (deps, optional deps, size, what needs it), **Installed**
(explicit, AUR, orphans, cache size + clean), **Updates** (checked when the page
opens: `checkupdates` + `yay -Qua`, no root; Arch news shown above "upgrade
all", flagged when newer than your last upgrade) and **Bundles**
(`config/package-bundles.json`: retro fonts, maintenance, images, voice).

Every change shows its exact command first (`sudo pacman -S --needed …`,
`yay -S …`, `sudo pacman -Rns …`, `yay -Syu`, `paccache`); **run in terminal**
opens it in ghostty, where you type your password, answer pacman / yay and
review AUR PKGBUILDs. No `--noconfirm`, never `-Sy` alone. Data comes from
`scripts/pkg.py` (read-only JSON). The install step is a single backend
function (`Packages.run`), so the way changes are executed lives in one place.
CLI: `packagesTab <tab>`, `packagesSearch <q>`, `packagesShow <name> repo|aur`.

## Themes

`qs -c rice ipc call rice themes` lists the presets in `themes/`;
`theme <id>`, `shape square|round|""`, `font <id>|""` switch live (colours
cross-fade) and are saved in `~/.local/state/rice/prefs.json`. A theme file
gives a palette and optional role overrides; its `shape` (square → underline
accents, round → pill accents) and `font` are defaults that `shape`/`font`
override. Fonts not installed fall back to DepartureMono (`fonts` lists them).
Every theme / shape change is pushed outside the shell too (`ThemeSync` →
`scripts/theme-apply.py`, files in `~/.local/state/rice/theme/`, which stowed
configs include): Hyprland rounding + borders, ghostty, tmux (status line),
Neovim (`mini.base16` from the palette), GTK dark/light — live; btop, zathura,
Firefox textfox (`config.css`) — next start; SDDM — next login, after a one-time
`sddm/install.sh` makes its colour file yours. `themeApply` / `themeApplied`
re-run it / show the last result; Settings › Appearance › Elsewhere too.

## IPC

```
qs -c rice ipc call rice dashboard overview   # overview | media | system | weather | github | docker
qs -c rice ipc call rice dashboard weather
qs -c rice ipc call rice quicksettings ""     # "" | network | bluetooth | sound | nightlight | screenshot
qs -c rice ipc call rice sidebar notifications # notifications | weather | feeds (same tab again closes)
qs -c rice ipc call rice session              # session drawer
qs -c rice ipc call rice settings sound       # settings window (page optional; same page again closes)
qs -c rice ipc call rice setting weatherImperial false   # settingGet / settingReset too
qs -c rice ipc call rice launcher
qs -c rice ipc call rice clipboard
qs -c rice ipc call rice keybinds
qs -c rice ipc call rice screenshot area save  # area|active|output|screen  save|copy|text|edit
qs -c rice ipc call rice nightlight           # toggle
qs -c rice ipc call rice dnd                  # toggle; dndSet on|off, nightlightSet, caffeineSet too
qs -c rice ipc call rice lock
qs -c rice ipc call rice caffeine             # toggle
qs -c rice ipc call rice mail                 # Sidebar › Notifications (mail on top)
qs -c rice ipc call rice music                # open / attach spotify_player
qs -c rice ipc call rice playpause            # also: next, previous
qs -c rice ipc call rice refresh              # weather + mail + calendar + github now
qs -c rice ipc call rice close
qs -c rice ipc call rice actions              # the action allowlist (config/actions.json + themes)
qs -c rice ipc call rice action dnd.on ""     # run one; power actions need "confirm" as 2nd arg
qs -c rice ipc call rice theme nord           # themes, shape, font, fonts
qs -c rice ipc call rice power suspend        # lock | logout | suspend | reboot | poweroff
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
