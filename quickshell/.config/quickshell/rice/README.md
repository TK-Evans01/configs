# quickshell-rice

Quickshell config for Hyprland rice. Retro gruvbox top bar (replaced waybar).

## Layout

- `shell.qml` — entry point, one Bar per screen
- `core/` — Bar, Widget, Popout primitives
- `config/` — Theme + Settings singletons
- `services/` — singleton data/control layer
- `widgets/` — per-widget UI
- `docs/architecture.md` — deeper overview
- `.qmlls.ini` — qmlls LSP config

## Dev

Linked into `~/.config/quickshell/rice`. Hot-reloads on save.

```
quickshell -c rice           # run
qmlls -p .                   # editor LSP
```

## Autostart

`~/.config/hypr/hyprland.conf`: `exec-once = quickshell -c rice`
