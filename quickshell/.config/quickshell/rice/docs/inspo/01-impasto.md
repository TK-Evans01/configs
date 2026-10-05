# 01 · impasto (andreumassanet/impasto)

Repo: https://github.com/andreumassanet/impasto. Reviewed from a shallow clone of `main` (HEAD `42dbfbe`).
Paths marked "theirs" are relative to `home/.config/quickshell/` unless they start with `home/`, `system/` or `.github/`.

---

## 1. What it is

impasto is a complete Arch + Hyprland 0.56 (Lua config) desktop built around a Quickshell 0.3 shell.
Its signature pieces are a pure-black **dynamic island** that morphs into every panel, a grid of widgets on the wallpaper, a dock, an in-shell lock screen with a matching SDDM theme, and a palette taken from the wallpaper and pushed to roughly 15 other programs (kitty, btop, cava, yazi, nvim, GTK3/4, Qt/KDE, Papirus folders, Vesktop, Spicetify, VSCodium, Zen).
It is big and mature for a rice: about 70.8k lines of QML across about 300 files, Python helpers (`scripts/theme_manager.py` alone is 4.1k lines), a `./setup` installer with install/update/uninstall/sync/check verbs, CI that only checks syntax (`.github/workflows/check.yml`), a release workflow, a docs site, i18n (`theme/Tr.qml`, English and Spanish), and 40 bundled wallpapers.
The license is **GPL-3.0**, so we should reimplement ideas the same way we did with lyne-dots and not copy code.
The look is the opposite of ours: Inter/JetBrains Mono, big radii, black capsules, Apple-like semantic colours, optional glass.

## 2. Architecture

```
home/.config/quickshell/
  shell.qml            ShellRoot: per-screen Bar/Desktop/Deck/Dock, LockScreen, 3 IpcHandlers
  theme/               Theme (tokens), Palettes (registry), Motion (Hyprland anim presets), Board, Tr (i18n)
  services/            ~50 singletons (Settings, Theme, Wallpaper, Profile, Notification, Osd, Font, …)
  scripts/             python backends, JSON on stdout (theme_manager, fonts, weather, claude_usage, …)
  bar/                 Bar.qml, widgets/DynamicIsland.qml, modules/*Module.qml, island/*Panel.qml|*Detail.qml
  settings/            SettingsWindow (xdg toplevel) + SettingsPanel (sidebar/pages) + *Section.qml
  desktop/ deck/ dock/ lock/ capture/   wallpaper widgets, edge note tabs, dock, lock, screenshot/record
  components/          ~70 shared pieces (SettingRow/Group/Tiles, SegmentedControl, Carousel, PreviewTile…)
home/.local/share/impasto/profiles/*.json   bundled "desks" (wallpaper + palette + settings)
```

Patterns worth noting:

- **Settings persistence** (`services/SettingsService.qml`):
  - A single `JsonAdapter` schema (`component Store`) sits inside a `FileView` at `$XDG_STATE_HOME/quickshell/settings.json`, with `watchChanges: true`.
  - Every key is exposed as `readonly property alias`, and writes go through `set(key, value)`.
  - Guards:
    - `arrived` refuses writes until the file has loaded, so an early `set` cannot overwrite the file with defaults.
    - `onAdapterUpdated` → `Timer { interval: 0 }` → `writeAdapter()` merges several changes from one event-loop pass into a single write. Their comment says two `writeAdapter()` calls in one pass lose the second change.
    - On `FileNotFound` it writes the defaults.
  - A second instance named `pristine` holds the defaults for "reset".
- **Theme** (`theme/Theme.qml` + `services/ThemeService.qml` + `theme/Palettes.qml`):
  - `Palettes.list` is the only place a palette is defined: `{id, name, badge, swatches[4], colors{background, surface, surfaceHover, border, text, textMuted, accent, accentHover, accentText, red, green, yellow, blue}}`. The picker and the theme read the same entry.
  - `Theme` holds mutable role properties, each with a `Behavior on <role> { ColorAnimation { 260ms } }`, so a palette switch cross-fades the whole shell.
  - Status colours (`indicatorGood/Warn/Bad`, privacy colours) stay fixed on purpose, so a wallpaper-derived accent cannot change what a battery ring means.
  - `ThemeService.setTheme(id)` → `Theme.apply(colors)` → `theme_manager.py push-terminal-palette <json>`, which writes theme fragments for every program and reloads the ones that support it.
- **Adaptive palette** (`theme_manager.py build_palette`):
  - ImageMagick reduces the image to 24 colours.
  - `pick_accent` takes the most saturated mid-tone.
  - Surfaces are near-black tinted 4–5% toward the accent. Text and status colours are fixed.
- **Wallpaper** (`services/WallpaperService.qml` + `theme_manager.py set-wallpaper/restore`):
  - Sets the image with `awww img --transition-type <t>`. State goes to a JSON file plus a `current` symlink, then the colours are re-extracted.
  - At login, `restore` paints only blank outputs and exits 3 while `awww-daemon` is still starting; QML retries up to 8 times, 1.5 s apart.
  - It also re-runs `restore` when Hyprland reports a `monitoradded` event.
  - Videos play through `mpvpaper` over a poster frame.
- **Profiles** (`services/ProfileService.qml`):
  - The active profile *is* `settings.json`. The other profiles wait in `profiles.json`.
  - Switching saves the current profile, adopts the next one, and applies its palette and then its wallpaper.
  - The export is versioned (`"impasto": 1`). It never carries machine keys (screens, keyboard) or user data.
- **Island arbitration** (`bar/island/IslandState.qml`):
  - Ranked layers: `panel > notification > osd > summary > modules`.
  - `layer` is one binding.
  - Opening a panel drops the OSD and the toast.
  - An OSD that arrives while a panel is open is dropped, not queued ("would look like a ghost").
- **OSD bus** (`services/OsdService.qml`):
  - One `signal requested(icon, label, progress)`.
  - `armed` after 600 ms, so startup bindings don't flash.
  - 16 ms debounce.
  - Volume is ignored for 2 s after an audio device switch.
- **IPC**: three `IpcHandler`s in `shell.qml` (wallpaper `set(path)`, `toggle`, `reload`). Keys mostly go through Hyprland binds that call `qs ipc`.

## 3. Feature inventory

| Feature | How it works (theirs) | We have it? | Worth adopting? |
|---|---|---|---|
| Persistent settings store | `services/SettingsService.qml` FileView+JsonAdapter, `arrived` guard, 0 ms save timer | **no** (`config/Settings.qml` is all `readonly`) | **Yes, foundation for goal 3** |
| Palette registry + live switch | `theme/Palettes.qml`, `Theme.apply`, ColorAnimation per role | no (one hard-coded gruvbox) | Yes |
| Push palette to other apps | `scripts/theme_manager.py push-terminal-palette` (kitty, btop, cava, yazi, nvim, GTK, Qt…) | no | Yes, a small subset (ghostty, tmux, nvim, hypr borders, btop) |
| Wallpaper-derived palette | `build_palette` via `magick -colors 24` | no | Optional "adaptive" entry only; curated themes stay primary |
| Wallpaper set/restore/hotplug | `WallpaperService.qml` + `restore` exit-3 retry + `monitoradded` | partial (awww is used, Lock reads `awww query`) | Yes |
| Wallpaper carousel picker | `bar/island/AppearancePanel.qml` + `components/Carousel.qml`, Left/Right/Enter, lazy decode near the centre | no | Yes (keyboard-first) |
| Animated wallpapers | mpvpaper + ffmpeg poster | no | No (memory, orphans; see §7) |
| Profiles ("desks") | `ProfileService.qml`, `profiles/*.json` {wallpaper, palette, settings} | no | Yes, as our "theme = palette + shape + font + wallpapers" bundle |
| Font picker from fontconfig | `services/FontService.qml` (lazy) + `scripts/fonts.py` + `settings/FontPicker.qml` | no | Yes |
| Settings window | `settings/SettingsWindow.qml` (xdg toplevel) + `SettingsPanel.qml` sidebar, keyword search, tabs, help links | no | Yes (structure, not look) |
| Live-preview options | `components/PreviewTile.qml`, `BarPreview`, `MotionPreview`; options drawn as the real component | no | Yes, for shape/font/palette tiles |
| In-shell notification server | `services/NotificationService.qml` (NotificationServer, `keepOnReload`, actions, image locks, persisted history) | no (dunst + `dunstctl history`) | **Yes** (goal 2) |
| Notification grouping | none (flat list, `bar/island/controls/NotificationList.qml`) | no | We do better (see §5.2) |
| OSD (volume/brightness) | `OsdService.qml` signal bus → `island/OsdLayer.qml` | no | Yes |
| Layer arbitration | `bar/island/IslandState.qml` | partial (`Ui.open` single string) | Yes, small |
| Launcher sigils | `services/LauncherService.qml` modes: `=` calc, `@` windows, `!` timer, `'` clipboard, `:` emoji, `>` shell places | partial (`=` calc, chips for clipboard/keybinds) | `>` "go to setting/panel" and `@` windows: yes |
| Control centre grid editor | `ControlsService.qml`, block grid 6×8, drag to arrange | no | No, too heavy for us |
| Bar layout editor | `settings/LayoutEditor.qml` (1.1k lines), three bar styles | no (fixed three islands) | Maybe later; low value |
| Desktop widgets (3 faces) | `desktop/`, `DesktopService.qml` (1.5k lines) | no | No |
| Edge note tabs (peek) | `deck/Deck.qml`: full-screen layer + computed input mask, strips that slide out on hover | no | The pattern, yes, for sidebars (goal 2) |
| Notes / kanban / games / pets | `NotesService`, `TasksService`, `bar/island/games/*`, `PetService` | no | No |
| Claude Code usage | `scripts/claude_usage.py` (reads transcripts JSONL incrementally + rate-limit headers) | no | Nice small dashboard card |
| Lock + SDDM sharing look | `lock/`, `system/usr/share/sddm/themes/impasto` | yes (`modules/lock`, `sddm/rice`) | Already have it |
| Face unlock | howdy + `FaceService.qml` + polkit | no | No |
| Hyprland animation presets | `theme/Motion.qml` pushed by `CompositorService` | no | Low; possible "motion" option in the theme |
| i18n | `theme/Tr.qml` | no | No |

## 4. Layout and UX patterns

**What feels good**
- **One rule for where things open.** Every module opens its detail in the same place (the island), with no title bar and no close button, sized to its content. That is very cohesive. Our current mix is dashboard tabs, quick-settings pages and a launcher. The right fix for us is not an island but making sure each popup type has *one* home (see §6.6).
- **Shared measurements for detail pages** (`Theme.detailRow 36`, `detailLabel 128`, `detailGap 14`, `detailSection(rows)`): every row's label takes the same column, so sliders and bars on a page all start at the same x. This is the single best anti-cramping trick in the repo, and it fits goal 1 directly.
- **A fixed toast width** (`NotificationService.toastWidth 400`), with buttons inline only if ≤2 and ≤20 letters total, else a stacked button row. The decision is made up front, so the layout never reflows.
- **Settings filed by what they change, not how they are applied.** Two levels of navigation at most: sidebar group → section → `TabStrip` parts. Every section has a `keywords` string for search. History-based back navigation.
- **Options drawn as the thing they change**: the bar figure/no-figure tiles in `.github/assets/settings.jpg`, the pet styles, motion presets as looping miniatures, and wallpaper transitions as looping thumbnails (`WallpaperTransitionPreview.qml`). Because they are built from live components, they follow the palette.
- **Carousel picker**: the centre tile is large and its neighbours step away. Only tiles near the centre decode images (the comment notes that decoding every wallpaper at once left the visible tiles black for over a second). Keyboard: ←/→ slide, Enter applies, ↑/↓ switch page (animated → stills → palettes).
- **Status colours fixed across palettes.** This matters once we have several themes. A "warning" orange must stay orange-ish even in Nord.
- **Edge tabs** (`deck/Deck.qml`): a thin coloured strip at rest, which slides out with titles on hover and peeks the content beside it. This is a good shape for a notification/feed sidebar that doesn't eat screen space.

**What is clunky**
- Everything is clickable, and dragging is first-class (layout editor, widget grid, control-centre grid). Keyboard coverage exists (`SUPER+H` key list, launcher), but configuration is mouse-centric.
- Very wordy, whimsical design (pets, games, handwriting notes). Huge files: `DesktopService` is 1.5k lines and `Inspector` 1.2k.
- `theme_manager.py` is one 4.1k-line monolith that patches third-party apps (Spotify via spicetify, Zen userChrome, VSCodium settings JSONC editing). That is fragile across upgrades.
- The notification history is flat, newest first, with no grouping by app.

## 5. Against our goals

### 5.1 Goal 1: clean up clunkiness
- Adopt the **detail-metric tokens** idea: add `Theme.rowHeight`, `Theme.labelColumn`, `Theme.sectionGap`, and a `function sectionHeight(rows)`. Make `Card`/`DeviceRow`/`Slider` use them, so quick-settings pages line up (`modules/quicksettings/*Page.qml`).
- **Decide sizes up front** for toasts and popups instead of letting content reflow (the toast-width rule).
- Fixed status colours (`indicatorGood/Warn/Bad`) separate from the themed accent. Our `Theme.usageColor()` already does this with palette reds and oranges, so we need to make sure every theme defines them.

### 5.2 Goal 2: pop-out side panels
- impasto has no side panel. Its two relevant pieces are `NotificationService` (the server) and `Deck` (edge strips that peek).
- Their history is a plain list. For our grouped panel, group entries in QML by a `source` key derived from `desktopEntry || appName`:
  - "Proton Mail Bridge"/our own `Mail` notify-send → email
  - `vesktop`/`discord` → Discord
  - everything else → system
- Pair this with a right-anchored `PanelWindow` that has the `Deck` idea of a thin strip, plus a SUPER bind to slide it open.

### 5.3 Goal 3: settings shell (theme + wallpaper)
- Copy the *architecture*:
  - a persisted JsonAdapter store (§2)
  - a `Palettes.qml`-style registry as the single source for both picker and theme
  - `Theme` roles that animate on change
  - a `FontService` that lists families from fontconfig, loaded only when the settings window opens
  - an xdg-toplevel settings window with sidebar + search
- Their profile JSON (`{name, wallpaper, palette, settings}`) is almost exactly our "theme with known-fitting wallpapers". We add `shape` and `font`, and derive the accent style from `shape`.

### 5.4 Goal 4: wallpaper manager
- `WallpaperService` + `theme_manager.py set-wallpaper/restore` is a solid awww recipe:
  - transition passthrough with a whitelist
  - state kept in JSON plus a `current` symlink (useful for SDDM/lock)
  - restore only blank outputs, retry on exit 3 at login, re-run on `monitoradded`
- Their wallpapers have **no metadata**; a profile names exactly one wallpaper. Our theme+season tags would be new. Their carousel UI is a good model for the picker.

### 5.5 Goal 5: voice assistant
Nothing relevant: no audio input pipeline and no LLM integration. `scripts/claude_usage.py` only reads Claude Code transcripts for token counts.

### 5.6 Goal 6: focus mode
- Their "Focus" tile (`services/ControlsService.qml:258`) is just do-not-disturb.
- One useful detail: DND is stored in persisted settings, critical notifications ignore it, and notifications are still recorded while it is on (`NotificationService.present`). Our focus mode should keep that behaviour and suppress toasts, not history.

## 6. Proposals for us (ranked)

1. **Persisted settings store (S→M)**
   - **What:** split `config/Settings.qml` into defaults that stay readonly (hardware, paths, refresh intervals) and a new `services/Prefs.qml`: a `FileView { path: ~/.local/state/quickshell/rice/prefs.json; watchChanges: true }` + `JsonAdapter`. Include the `arrived` write guard and the `Timer { interval: 0 }` → `writeAdapter()` save coalescing. Expose `set(key, value)`, and keep a second `JsonAdapter` instance holding the defaults (their `pristine`) for reset.
   - **Files:** new `services/Prefs.qml`, `services/qmldir`, `config/Settings.qml`, `docs/architecture.md`.
   - **Notes:** state, not secrets, so `~/.local/state`, never `~/.config/rice/`. Keep the file out of stow.

2. **Theme registry with shape + font + accent style (M)**
   - **What:** a new `config/Themes.qml` list of entries `{id, name, palette{…semantic roles + status colours}, shape: "square"|"round", font, wallpapers: [...]}`.
   - **Theme.qml changes:**
     - It becomes mutable roles fed from `Themes.byId(Prefs.theme)`, with `Behavior on <role> { ColorAnimation }`.
     - `radius` derives from `shape` (0 or e.g. 8).
     - Add `accentStyle: shape === "square" ? "underline" : "pill"`.
     - Keep the raw gruvbox colours as the default entry.
   - **Files:** `config/Theme.qml`, new `config/Themes.qml`, `components/BarButton.qml` + `components/TabBar.qml` (underline vs pill indicator), `components/Card.qml`, `components/Tile.qml`.
   - **Risk:** DepartureMono sizes are tied to an 11px grid (`fontSize 18/22`). Each font entry needs its own type scale, so size tokens should live per theme.

3. **Wallpaper service with metadata (M)**
   - **What:** a `services/Wallpaper.qml` + `scripts/wallpaper.py` (`list`, `set <path> [transition]`, `restore`).
     - Use `awww img`, a `current` symlink in `~/.local/state/rice/`, and restore of blank outputs with an exit-3 retry plus a re-run on Hyprland `monitoradded` (`Quickshell.Hyprland` `rawEvent`).
     - Metadata in a sidecar `wallpapers.json` (`{file: {themes: [...], seasons: [...], tags: [...]}}`). `suggest(themeId, month)` ranks by theme match, then season.
   - **Files:** new service + script, `services/Lock.qml` (read the current symlink instead of `awww query`).
   - **Notes:** the script is one-shot (no tether needed).

4. **In-shell notification server + grouped sidebar (L)**
   - **What:** replace dunst with `NotificationServer` (`keepOnReload: true`, `notification.tracked = true`, actions, images).
     - Per-notification expiry timers.
     - `RetainableLock` for image-hint pixels.
     - History persisted to state JSON behind a `restored` guard.
     - Critical urgency bypasses DND/focus.
     - Add a `source` classifier (email / discord / system / …) and a `groups` model.
   - **UI:** a toast surface (fixed width, inline-vs-stacked buttons rule) + a right sidebar `PanelWindow` grouped by source with collapse/clear-per-group.
   - **Files:** new `services/Notifications.qml`, new `modules/notifications/{Toast,Sidebar}.qml`, `modules/quicksettings/NotificationsPage.qml` (point at the new service or drop it), `services/Desktop.qml` (remove the dunstctl parts), `services/Mail.qml` (could emit straight into the service instead of notify-send), and Hyprland autostart (stop dunst).
   - **Risk:** only one owner of `org.freedesktop.Notifications` is allowed. Their server simply stays unregistered while another daemon holds the name, so dunst must be removed first.

5. **OSD bus + popup arbitration (S→M)**
   - **What:**
     - `services/Osd.qml` with `signal requested(icon, label, progress)`, a 600 ms arm delay, a 16 ms debounce, and 2 s suppression after a default-sink change. `Audio.qml` emits on volume/mute.
     - A small OSD `PanelWindow` near the bar, styled with our segmented `Meter`.
     - Extend `services/Ui.qml` with a ranked `layer` (popup > toast > osd): an OSD under an open popup is dropped, and opening a popup dismisses the toast without marking it read.
   - **Files:** new `services/Osd.qml`, `services/Audio.qml`, `services/Ui.qml`, `shell.qml`.

6. **Settings window (M→L, after 1–3)**
   - **What:** a `FloatingWindow` (xdg toplevel, so Hyprland floats/sizes it by a window rule) titled "rice settings".
     - Sidebar groups: Look (Theme, Wallpaper, Font), Bar, Panels, Session.
     - A search field filtering on per-section `keywords`.
     - Pages built from `SettingRow`-like components.
     - Options shown as live mini-previews: a `BarButton` drawn square/round in each theme's palette, and a font sample line.
     - All keyboard: j/k or arrows in the sidebar, `/` focuses search, Esc back.
   - **Files:** new `modules/settings/`, new `components/SettingRow.qml`, `components/SegmentedControl.qml`, IPC `settings()` in `shell.qml`, SUPER bind in Hyprland.
   - **Notes:** a new `modules/` dir needs a shell restart (see architecture gotchas).

7. **Push the theme to other apps (M)**
   - **What:** `scripts/theme-push.py <theme-json>` writes include fragments and reloads each app:
     - ghostty (`config-file = ` fragment; ghostty reloads on SIGUSR2 or via its reload keybind)
     - tmux (`source-file`)
     - nvim (write a colors file; remote via `--server` sockets if any)
     - Hyprland border colours (`hyprctl keyword`)
     - btop theme file
   - Keep it one function per target, about 300 lines, not a 4k monolith.
   - **Files:** new script, called from the theme switch in `Theme.qml`/`Prefs.qml`; stow-managed configs get an `include` line pointing to `~/.local/state/rice/…`.

8. **Font list from fontconfig (S)**
   - **What:** `scripts/fonts.py` (`fc-list : family spacing` → `{sans, mono}`) + lazy `services/Fonts.qml` (`load()` only when settings opens).
   - **Notes:** Qt silently substitutes missing families, so pick from an installed list only.

9. **Launcher `>` mode = shell places + `@` windows (S→M)**
   - **What:** add entries for every dashboard tab, quick-settings page, settings section and mode ("focus 25m", "theme gruvbox", "wallpaper …") as launcher rows under a `>` prefix. Add `@` to search open toplevels (`Hyprland.toplevels`) and focus them.
   - **Files:** `services/Launcher.qml`, `modules/launcher/LauncherWindow.qml`.
   - **Notes:** this doubles as the action registry the voice assistant (goal 5) can call later.

10. **Layout metrics for cohesion (S)**
    - **What:** add `Theme.rowHeight`, `labelColumn`, `sectionGap`, `sectionHeight(rows)`, and refactor quick-settings pages and dashboard cards to use them.
    - **Files:** `config/Theme.qml`, `components/{Card,DeviceRow,Slider,Tile}.qml`, `modules/quicksettings/*Page.qml`.

11. **Edge-strip sidebar shell (M)**
    - **What:** a generic `components/SidePanel.qml`. It is a `PanelWindow` anchored top/bottom/right with `exclusiveZone: 0` and an input `mask` that covers only the strip until expanded. At rest a 3px accent strip shows (underline style) or a pill tab (round style); hover or SUPER+N slides it open.
    - **Uses:** host notifications, weather and feeds as sidebar pages.
    - **Files:** new component, `services/Ui.qml` (`sidebar` state).

12. **Claude Code usage card (S)**
    - **What:** reimplement the idea of `claude_usage.py`: incremental JSONL offset reads of `~/.claude/projects/**` summing token usage for the 5 h block and 7 d. Show it as a card or Overview tile. This also gives the voice assistant "the claude code project from last night" (the most recently modified project dir).
    - **Files:** new script + `services/ClaudeUsage.qml`, `modules/dashboard/OverviewTab.qml`.

## 7. Don't copy

- **The island/black-capsule identity, glass surfaces and the hyprglass plugin.** These clash with our square/hairline retro look, and plugins built against the running compositor break on every Hyprland update.
- **The adaptive palette as default.** A wallpaper-derived accent over fixed near-black surfaces makes every theme look the same. At most, offer it as one "from wallpaper" entry.
- **mpvpaper animated wallpapers.** `start_motion` launches via `sh -c 'sleep; exec …'` with `start_new_session=True`, which detaches it from the shell. That orphan pattern is exactly what `Settings.tether` exists to prevent, and a video decoder running all the time costs memory and GPU.
- **Patching third-party apps** (spicetify, Zen userChrome, VSCodium JSONC rewrite, Papirus folder recolour, Thunar actions). That is high upkeep, and those apps aren't in our stack.
- **The `./setup` copy-not-link installer.** We use stow. Their "edited file → `.new` beside it" logic solves a problem we don't have.
- **Drag-to-arrange editors** (bar layout, control-centre grid, desktop widget grid, 1–1.5k lines each). They are mouse-first, large, and outside our goals.
- **Pets, games, handwriting notes, kanban, i18n (`Tr.qml`), face unlock.** These are scope creep.
- **Rebinding compositor keys from the shell** (Settings → Keys rewrites Hyprland binds per profile). It is fragile, and our binds live in stowed Hyprland config.
- **Code itself.** GPL-3.0: reimplement the patterns, keep a credit line in `docs/architecture.md` as we do for lyne-dots.
