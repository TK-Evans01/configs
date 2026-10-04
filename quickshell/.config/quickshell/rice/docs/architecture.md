# Architecture

Quickshell bar for Hyprland on Arch. Retro look: gruvbox-material palette, DepartureMono Nerd Font, square corners. Top anchor, one bar per monitor. Sole status bar (waybar retired).

## Entry point

`shell.qml` — creates a `Scope` with a `Variants` over `Quickshell.screens`, instantiating one `core/Bar` per screen. `screenRef` is passed down so each bar binds to its own output.

Autostart: `exec-once = quickshell -c rice` in `~/.config/hypr/hyprland.conf`.

## Directory layout

```
rice/
├── shell.qml           entry — one Bar per screen
├── core/               reusable bar / widget / popout primitives
├── config/             Theme + Settings singletons
├── services/           singleton data/control layer
├── widgets/            per-widget UI (Bar.qml, optional Popout.qml + parts)
└── docs/               this file
```

Every subdir has a `qmldir` so imports resolve as QML modules rather than file paths.

## Layers

### `config/` — singletons

- `Theme.qml` — gruvbox-material colors (`bg0..3`, `fg0/1`, `grey`, and `base/Dim/Bright` triples for red, orange, yellow, green, aqua, blue, purple), font (`DepartureMono Nerd Font Mono`, 18px), `iconSize=32`, spacing (`pad=11`, `gap=16`, `radius=0`, `accentThickness=2`).
- `Settings.qml` — `barHeight=44`, label width caps + carousel tuning (`windowLabelWidth`, `mprisLabelWidth`, `scrollMsPerPx`, `scrollGap`), and layout arrays (`leftWidgets`, `centerWidgets`, `rightWidgets`) driving `core/Bar.qml` via its widget registry.

Both `pragma Singleton`.

### `core/` — primitives

- **`Bar.qml`** — the `PanelWindow`. Declares one inline `Component` per widget type and exposes a `registry` map `name → Component`. Three `Row`s (left / center / right) each run a `Repeater` over the matching `Settings.*Widgets` array, instantiating widgets via `Loader { sourceComponent: bar.registry[modelData] }`. Layout is config-driven.
- **`Widget.qml`** — base component for bar items. Props: `label`, `labelPrefix`, `labelColor`, `labelSize`, `hasPopout`, `maxLabelWidth`, `scrollLabel`. Exposes `hovered`, `clicked`. Labels past `maxLabelWidth` carousel via `ScrollingText`.
- **`Popout.qml`** — slide-down dropdown under its owner widget. A `PopupWindow` anchored to the owner's rect, so Hyprland places it on the owner's output (no manual screen math). Slide animation (`slideDuration=220`). Stays open while owner or popout is hovered; `hideDelay=150` bridges the gap. `rendered` keeps the window alive through the close animation.
- **`ScrollingText.qml`** — text that carousels left through a second copy when it overflows (no bounce). Falls back to elide when `scrolling` is off.

### `services/` — singletons for data + control

Widgets bind to properties and call methods. No widget does its own IO.

| Service | Source | Update model |
|---------|--------|--------------|
| `Hyprland` | `Quickshell.Hyprland` | reactive. `workspaces`, `monitors`, `focusedWorkspace`, `activeToplevel`, `dispatch(cmd)` |
| `Audio` | `pactl` | event-driven: long-running `pactl subscribe` re-triggers a poll; writes via one-shot `pactl set-*`. Outputs + inputs, default device, mute |
| `Mpris` | `Quickshell.Services.Mpris` | reactive + 500ms position tick. Prefers player with identity `ncspot`, else first. `launch()` attaches to (or creates) a detached `tmux` session `ncspot` in alacritty |
| `Sys` | `/proc`, `/sys` (amdgpu), `df` | 2s poll. CPU %/temp/model, GPU %/temp/VRAM, RAM, disks, process count |
| `Network` | `mullvad status`, `ip`, `/sys/class/net`, ping | 5s poll. **Mullvad VPN** state/relay/location/IP + `toggle()` / `reconnect()`; internet reachability; physical links (wifi / eth / usb) with uplink flag |
| `Docker` | `docker ps` + `docker events` | event-driven, 10s fallback poll; restarts the events stream if the daemon bounces |
| `Bluetooth` | `Quickshell.Bluetooth` (BlueZ DBus) | reactive. Sorted `devices`; `activate(d)` = disconnect / connect / pair→trust→connect. Runs a `bluetoothctl` NoInputNoOutput agent; scans auto-stop after 60s |

### `widgets/` — per-widget UI

Conventions:

- `Bar.qml` extends `Core.Widget`, binding `label` / `labelColor` to service properties.
- `Popout.qml` takes `required property var service` and binds/calls on the singleton directly — all state stays reactive.
- Extra parts live beside them (`Volume/Slider.qml`, `Network/Entry.qml`, `System/Meter.qml`…).
- Widgets hold no Process/Timer logic.

Current widgets (placement from `Settings.qml`):

| Position | Widget     | Service       | Popout |
|----------|------------|---------------|--------|
| left     | Workspaces | `Hyprland`    | no     |
| left     | Window     | `Hyprland.activeToplevel` | no |
| left     | Mpris      | `Mpris`       | yes    |
| center   | Clock      | local Timer   | no     |
| right    | Docker     | `Docker`      | yes    |
| right    | Network    | `Network` (incl. Mullvad) | yes |
| right    | Bluetooth  | `Bluetooth`   | yes    |
| right    | Volume     | `Audio`       | yes    |
| right    | System     | `Sys`         | yes    |

### Popout service-passthrough pattern

```qml
Core.Popout {
    owner: vol
    contentComponent: Component {
        Popout { service: Svc.Audio }
    }
}
```

Adding a field to the service flows to every popout that binds it.

## Hot reload

Quickshell watches the source tree; saving any file re-parses the shell. Dev loop: `quickshell -c rice` against `~/.config/quickshell/rice`, a symlink into this repo.

Note: `qmllint` misses property-shadow-of-FINAL errors (e.g. declaring `property int z` on an Item). The shell then fails only at load time. Avoid names that collide with Item built-ins (`z`, `state`, `data`, `parent`…) and verify by actually loading the shell.

## Roadmap

Borrowing layout + behavior from [lyne-dots](https://github.com/caioax/lyne-dots) (GPLv3 — reimplement, don't copy) while keeping the retro look:

- Semantic theme tokens loaded from JSON presets (gruvbox-material default).
- Shared `components/` (card, slider, switch, ring, sparkline, animated popup).
- `state.json` over defaults instead of hardcoded `Settings.qml`.
- New surfaces: OSD, notifications (replace dunst), launcher (replace tofi), dashboard, lyrics.

## Rough edges

- Theme has 30+ flat color props — candidate for semantic tokens (see roadmap).
- Poll/timer boilerplate repeats across `Sys`/`Network`/`Docker` — candidate for a `PollingProcess` helper in `core/`.
- `Mpris` player selection hardcodes `ncspot` identity preference.
