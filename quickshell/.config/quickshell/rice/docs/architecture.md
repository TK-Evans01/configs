# Architecture

Quickshell-based bar for Hyprland on Arch. Gruvbox-material palette, top anchor, per-monitor replication. Currently running alongside waybar during migration.

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
├── widgets/            per-widget UI (Bar.qml, optional Popout.qml)
└── docs/               this file
```

Every subdir has a `qmldir` so imports resolve as QML modules rather than file paths.

## Layers

### `config/` — singletons

- `Theme.qml` — gruvbox-material colors, font (`DepartureMono Nerd Font Mono`, 13pt), spacing (`pad=8`, `gap=12`, `radius=0`, `accentThickness=2`).
- `Settings.qml` — `barHeight=32` plus layout arrays (`leftWidgets`, `centerWidgets`, `rightWidgets`) driving `core/Bar.qml` via its widget registry.

Both `pragma Singleton`, imported via `import "../config"`.

### `core/` — primitives

- **`Bar.qml`** — the `PanelWindow`. Anchors top/left/right, height `Settings.barHeight`, bg `Theme.bg1`, 1px `bg3` bottom border. Declares one inline `Component` per widget type and exposes a `registry` map `name → Component`. Three `Row`s (left / center / right) each run a `Repeater` over the matching `Settings.*Widgets` array, instantiating widgets via `Loader { sourceComponent: bar.registry[modelData] }`. Layout is therefore config-driven.
- **`Widget.qml`** — base component for bar items. Props: `label`, `labelColor`, `hasPopout`. Exposes `hovered`, `hoverEntered/Exited`, `clicked`. Renders a text label inside a hover-highlighted rectangle sized `implicitWidth + Theme.pad*2 × Settings.barHeight`.
- **`Popout.qml`** — dropdown panel anchored under an owner widget. Own `PanelWindow` positioned by computing the owner's center X via `mapToItem(null, …)` and clamping to screen bounds. Slide-in animation (`y: opened ? 0 : -height`, 220ms OutCubic). Shown while either the owner or the popout itself is hovered; a 150ms `hideTimer` bridges widget→popout cursor movement. `rendered` flag keeps the window alive through the close animation.

### `services/` — singletons for data + control

Each is a `QtObject` marked `pragma Singleton`. Widgets bind to properties and call imperative methods. No widget does its own IO.

- **`Hyprland.qml`** — thin wrapper over `Quickshell.Hyprland`. Exposes `workspaces`, `focusedWorkspace`, `activeToplevel`, and `dispatch(cmd)`.
- **`Audio.qml`** — PulseAudio/pipewire via `pactl`. **Event-driven**: a long-running `pactl subscribe` Process streams events through a `SplitParser`; any sink/source/server event re-triggers the poll Process (`pactl get-* / list …`) which parses `---marker---` sections. Write path: `_run([...])` fires a one-shot `pactl set-*` then re-triggers poll on exit. No periodic timer — the subscription supplies change signals.
- **`Mpris.qml`** — wraps `Quickshell.Services.Mpris`. Picks the `ncspot` player by identity, falls back to the first available. Exposes title/artist/album/art, playing state, position (ticked by a 500ms timer), capabilities, shuffle/loop/volume, and transport methods. `launch()` spawns `alacritty -e ncspot`.
- **`Cpu.qml`** — polls `head -n1 /proc/stat` every 2s, computes delta percent from prior total/idle.
- **`Memory.qml`** — polls `/proc/meminfo` every 5s via awk, exposes used percent.
- **`Mullvad.qml`** — polls `mullvad status` every 2s, parses state/relay/location/ip with regex. `toggle()` connect/disconnect, `reconnect()`. Convenience bools `connected`, `connecting`.

### `widgets/` — per-widget UI

Each folder is a QML module (`qmldir`) referenced from `core/Bar.qml`.

Conventions:

- `Bar.qml` is the in-bar component, extending `Core.Widget` and binding `label` / `labelColor` directly to service singleton properties.
- `Popout.qml` (where present) is the dropdown content. It accepts a single `required property var service` — the service singleton — and binds/calls on it directly. No snapshot `model` object; all state is reactive because bindings live on the singleton.
- Widgets hold no Process/Timer logic.

Current widgets:

| Position | Widget     | Service       | Popout |
|----------|------------|---------------|--------|
| left     | Workspaces | `Svc.Hyprland` | no    |
| left     | Window     | `Svc.Hyprland.activeToplevel` | no |
| center   | Clock      | local Timer   | no     |
| right    | Mpris      | `Svc.Mpris`   | yes    |
| right    | Mullvad    | `Svc.Mullvad` | yes    |
| right    | Volume     | `Svc.Audio`   | yes    |
| right    | Cpu        | `Svc.Cpu`     | no     |
| right    | Memory     | `Svc.Memory`  | no     |

Placement controlled entirely by `Settings.leftWidgets` / `centerWidgets` / `rightWidgets`.

### Popout service-passthrough pattern

```qml
Core.Popout {
    owner: vol
    contentComponent: Component {
        Popout { service: Svc.Audio }
    }
}
```

The popout binds directly to the service singleton (`root.service.outPercent`, `root.service.toggleMute()`, …). Adding a new field to the service auto-flows to every popout that binds it.

## Hot reload

Quickshell watches the source tree; saving any file re-parses the shell. Dev loop: `quickshell -c rice` running against `~/.config/quickshell/rice` which is a symlink into this repo.

## Remaining rough edges

- Theme has 30+ flat color props — could group into nested `palette.red.{base,dim,bright}` `QtObject`s.
- Poll/timer boilerplate repeats across Cpu/Memory/Mullvad — candidate for a `PollingProcess` helper in `core/`.
- Mpris player-selection hardcodes `ncspot` identity preference.
