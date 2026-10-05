# 04 · caelestia-kde (ladybug-me/caelestia-kde)

Repo: https://github.com/ladybug-me/caelestia-kde. Reviewed from a shallow clone of `main`.
"Theirs" paths are relative to `shell/` unless they start with `src/`, `scripts/`, `docs/` or `installer/`.
It is a port of `caelestia-dots/shell`, which is **Hyprland-native**. So the parts that matter to us (the drawer system, the sidebar, the settings app) come from a Hyprland codebase and transfer cleanly. The KDE glue is a layer on top, listed in §7.

---

## 1. What it is

caelestia-kde runs the Caelestia Quickshell shell on KDE Plasma 6 (KWin, Wayland) instead of Hyprland. It targets Arch, Fedora and Debian/Ubuntu.
It is a big, product-grade project:
- about 556 QML/C++/JS files under `shell/`, plus a large C++ QML plugin (`plugin/src/Caelestia/{Config,Blobs,Services,Components,Images,Models,Settings}`) that is built with CMake
- a C++ TUI installer (`installer/tui/`), numbered install steps (`scripts/0*-*.sh`), an AUR PKGBUILD, a self-updater (`src/bin/caelestia-update` + systemd timer)
- bash tests (`tests/`) and around 20 CI checks (`.github/scripts/check_qml_*.py`)
- 30 translations
- an upstream-sync tool (`tools/sync-shell.py`, `docs/upstream-sync.md`)

The look is Material 3: big radii, a vertical left bar in the screenshot, wallpaper-derived (matugen) or named schemes (`src/schemes/<name>/<flavour>/<mode>.txt`), and "blob" SDF backgrounds that make panels melt into a thin screen-frame border.
The license is **GPL-3.0-or-later**. As with lyne-dots and impasto, we reimplement ideas and copy no code.

## 2. Architecture

```
shell/
  shell.qml              ShellRoot: Background, Drawers, Shortcuts, IpcHandlers, deferred service init (Timer 250ms)
  modules/drawers/       THE core: one full-screen layer window per screen hosting every panel
    Drawers.qml          Variants over screens → Exclusions + ContentWindow
    ContentWindow.qml    full-screen StyledWindow; mask = Regions; blob backgrounds; focus/keyboard policy
    Panels.qml           positions every panel Item (dashboard, launcher, session, sidebar, osd, utilities, popouts, notifs, toasts)
    Regions.qml          input mask: whole-screen Xor (frame + each panel's current rect)
    Interactions.qml     one MouseArea: edge hover/drag gestures that open/close panels
    Exclusions.qml       four 1×1 invisible windows that only reserve exclusiveZone (frame/bar thickness)
  modules/<panel>/Wrapper.qml + Content.qml   each drawer = Wrapper (slide state) + lazily loaded Content
  modules/nexus/         settings app (FloatingWindow): NavPane + Pages + PageDictionary (search index)
  modules/sidebar/       right drawer: tabs Notifications / AI Assistant / News
  services/              ~36 singletons (Notifs, Wallpapers, Weather, Visibilities, ShellState, Kwin, …)
  services/api/          plugin API facade (UiApi, VisualsApi, …) for third-party plugins
  components/            Styled* primitives, Anim/CAnim (motion tokens), AnimLoader, DrawerVisibilities
plugin/src/Caelestia/Config   C++ config tree, an attached property `Config.screen: name` for per-monitor overrides
```

Notable patterns:

- **Single-window drawers.** Each screen has *one* `WlrLayershell` window anchored on all four edges with `ExclusionMode.Ignore`. Every panel is a plain `Item` inside it, so panels can touch, push each other and share one background shape.
  - Input passes through to apps because `mask` is a `Region` built as "full screen **Xor** (frame strip + each panel's on-screen rect)" (`Regions.qml`). The open rect shrinks with the slide animation (`panel.height * (1 - offsetScale)`).
  - When any modal drawer is open, `mask` switches to `fullRegion`, so a click anywhere lands in `Interactions.onPressed`, which closes everything that was not hit.
  - `keyboardFocus` is `OnDemand` only while `wantsKeyboard`. On close it restores focus to the window that had it before (`focusReturn`).
  - The layer moves Top→Overlay only while needed (an overlay is open, a fullscreen transition is running, or notifications are set to show over fullscreen apps).
- **Reserved space is separate from the drawing surface.** `Exclusions.qml` creates four empty 1×1 windows whose only job is `exclusiveZone` (bar thickness on one side, frame thickness on the rest). This is how a full-screen overlay can still keep tiled windows out from under the bar and frame.
- **Drawer state.** `DrawerVisibilities` is a `PersistentProperties` with one bool per drawer (`sidebar`, `session`, `dashboard`, `launcher`, `utilities`, `osd`, `overview`), one per screen, registered in `services/Visibilities.qml` (`getForActive()`). It survives reloads.
- **Wrapper/Content split.** `sidebar/Wrapper.qml` has `offsetScale: shouldBeActive ? 0 : 1` with `Behavior { Anim {} }`. It derives `visible: offsetScale < 1`, `opacity: 1 - offsetScale`, and slides with `anchors.rightMargin: (-implicitWidth - 5) * offsetScale`. Its `Loader { active: shouldBeActive || visible }` keeps the content alive only during the slide-out. Every drawer uses this ~40-line recipe.
- **Panels push each other** (`Panels.qml`). The OSD's right margin is `sidebar.width*(1-sidebar.offsetScale) + session.width*(1-session.offsetScale)`, so the OSD and session menu slide out *beside* an open sidebar instead of overlapping it. `popoutIntersectsSidebar` / `popoutIntersectsRight` reposition bar popouts.
- **Motion tokens.** `components/Anim.qml` takes a `type` enum (`DefaultSpatial`, `FastEffects`, `SlowEffects`, `StandardExtraLarge` …) that maps to M3 expressive durations/curves. `AnimLoader` fades out → swaps `sourceComponent` → fades in.
- **Config read/write split.** Widgets *read* `Config.sidebar.enabled` (resolved for this screen through the attached property) and *write* `GlobalConfig.sidebar.enabled = checked`. Everything persists to `~/.config/caelestia/shell.json`.
- **IPC**: `IpcHandler { target: "drawers" }` with `toggle(drawer)`, `toggleTab(drawer, tab)` and `list()`, where `list()` introspects the bools of `DrawerVisibilities`. Nexus has `open()` / `openPage(pageIdx, subPageIdx)`.

## 3. Feature inventory

| Feature | How it works (theirs) | We have it? | Worth adopting? |
|---|---|---|---|
| Edge drawers (one window per screen) | `modules/drawers/*`; mask Xor regions; `Interactions` hover/drag gestures | no (one `BarPopup` window per popup, all drop from the bar) | **Idea yes, wholesale no.** See P1/P8 |
| Right sidebar with tabs | `sidebar/Content.qml`: Notifications / AI / News, sliding pages, `Visibilities.initialSidebarTab` | no | **Yes**: the shape of our goal-2 panel |
| Notification centre grouped by app | `sidebar/NotifDock*.qml`, `NotifGroup.qml` (group = `appName`, expanded set in `Props.expandedNotifs`) | partial (dunst history page in QS) | same as impasto; grouping key is the plain `appName`, ours is better (source map) |
| Swipe-to-dismiss notif rows | `sidebar/NotifSwipeDelegate.qml` | no | maybe (mouse-only, low value for keyboard use) |
| News feed tab | `sidebar/News.qml`: `XMLHttpRequest` + regex RSS parse, distro feed map | no | **Yes**: no helper process; we would add a feed list |
| Session menu drawer | `session/Content.qml`: 4 big buttons in a column, j/k/Tab/Enter, 0.5 scrim, slides from the right edge, sits beside the sidebar | partial (power row in QS ProfileCard, confirm on second click) | **Yes, cheap** (P5) |
| Utilities corner drawer | `utilities/Content.qml`: keep-awake, screen recorder, quick toggles; bottom-right | partial (our QS tiles) | no; QS already covers it |
| OSD on the right edge, also on edge hover | `osd/Wrapper.qml`; hover on the right edge shows volume/brightness sliders | no (OSD planned) | the hover-to-peek part, maybe |
| Dashboard as a top-edge drawer | `dashboard/Wrapper.qml` (`showOnHover`, drag from the top edge); tabs Dash/Media/Performance/Weather/Wallhaven/Terminal | yes (bar-anchored popup) | no; ours is richer |
| Launcher as a bottom-edge drawer | `launcher/` + drag up from the bottom | yes (bar popup) | no |
| Bar popouts on hover, "detach" to a larger mode | `bar/popouts/Wrapper.qml` `detach(mode)`, `isDetached` | no (click only) | no; hover popups fight keyboard flow |
| Settings app "Nexus" | `nexus/*`: FloatingWindow singleton, NavPane, sub-page stack, fuzzy search over a keyword index | no | **Yes**, refines impasto P6 (P3) |
| Settings search with deep links | `nexus/PageDictionary.qml` (label, keywords, pagePath, subPageIdx) → `PageRegistry.buildIndex()` + fzf.js | no | **Yes** |
| Grouped "connected" rows | `nexus/common/ConnectedRect.qml` (`first`/`last` pick the radii), `ToggleRow`, `StepperRow`, `SelectRow`, `SliderRow`, `TextFieldRow`, `ListEditor`, `KeyCaptureDialog` | no | **Yes**: maps cleanly to our shape option (P4) |
| Live scheme preview on hover | `ColourSelect.qml` → `Colours.previewNamed(...)` on hover, `caelestia scheme set` on click | no | **Yes** (P6) |
| Wallpaper picker | `WallpaperSelect.qml`: sub-folder = category, filter chips (all/image/gif/video), **sort by colour distance**, hover preview (`Wallpapers.preview/stopPreview`) | partial (impasto plan) | **Yes**, colour sort → theme suggestion (P7) |
| Named scheme files | `src/schemes/<name>/<flavour>/<mode>.txt`, role/hex pairs incl. `term0..15` | no (palette registry planned, same as impasto) | format idea only: flavour × mode tree |
| Wallhaven search tab | `services/WallhavenSearcher.qml`, `dashboard/WallhavenTab.qml` | no | low; nice-to-have for the wallpaper manager |
| AI assistant | `sidebar/AiAssistant.qml` (3.3k lines): Ollama/Claude/OpenAI/…; text `<tool_call>` parsing; fixed tool set | no | the **closed tool vocabulary** idea only (§5 goal 5) |
| Per-monitor config | C++ attached `Config.screen` | no | not now; too heavy without the C++ plugin |
| Plugins + store | `services/PluginLoader.qml`, `services/api/*` | no | no |
| Frame border + blob SDF backgrounds | `Caelestia.Blobs` C++ (BlobGroup/BlobRect/BlobInvertedRect + shaders) | no | no (round/organic; needs C++) |
| Screen corners, Bad Apple, dino game, bongocat | `ScreenCorners`, `BadAppleOverlay`, `sidebar/DinoGame.qml` | — | no |

## 4. Layout and UX patterns

**What feels good**
- **Everything comes out of a screen edge, and the edge stays the same.** Top = dashboard, bottom = launcher, right = sidebar/session/OSD, bottom-right = utilities. You learn the layout spatially. The thin frame makes the panels read as part of the screen, not as floating cards.
- **The sidebar is one tall surface with a tab strip.** Notifications are the default tab, and IPC `toggleTab sidebar news` opens a given tab. The tabs slide horizontally (`x` + `opacity` Behaviors). The AI tab is a lazy `Loader` that stays alive once opened (`hasBeenActive`).
- **Neighbours make room.** Opening the session menu while the sidebar is open makes it slide out *next to* the sidebar (`sidebarOffset`), and the OSD moves left as well. Nothing ever overlaps.
- **Lazy content.** `Loader.active = shouldBeActive || visible` means a closed drawer costs one `Item`. This matches our "Loaders live only while open" rule for the dashboard.
- **Session menu is fully keyboard-driven**: arrow keys, j/k, n/p, Tab, Enter and Esc, with a scrim behind it. It is quick and hard to trigger by accident, because it needs a deliberate open.
- **Settings search is first-class.** Every setting row has a dictionary entry with keywords. A result jumps to `(pageIdx, subPageIdx)` through `nState.goToSubPage`, and a pending sub-page opens once the page has finished switching.
- **Preview before commit.** Hovering a scheme card or wallpaper tile previews it shell-wide. Click commits. `previewColourLock` stops the preview from flickering while the pointer moves between tiles.

**What is clunky**
- **Mouse-gesture heavy.** `Interactions.qml` (413 lines) is a thicket of drag thresholds, `grabWidth`, `hoverThickness` and per-bar-position branches. Hover-to-open dashboard/OSD/utilities fires by accident, which is why they had to add `*ShortcutActive` flags.
- **Position combinatorics.** Supporting four bar positions means every panel has `State`s for left/right/top/bottom, plus long nested ternaries for corner radii (`ContentWindow.qml` sidebarBg/utilsBg). Picking one fixed layout avoids all of it.
- **One full-screen overlay window per monitor**, with `layer.enabled` and a `MultiEffect` shadow over the whole screen, is expensive. They also need `dragMaskPadding` hacks and a KDE focus-grab polling `Timer` (100 ms) because KWin has no `HyprlandFocusGrab`.
- **Monolith files**: `AiAssistant.qml` is 3,315 lines and builds `Process` objects with `Qt.createQmlObject` from strings. `ContentWindow.qml` is 882 lines.
- The sidebar's tab strip only appears when AI or News is enabled, so the layout shifts depending on settings.

## 5. Against our goals

### Goal 1: cohesion
- The **Wrapper/Content + `offsetScale`** recipe gives every surface the same motion: one property drives slide, opacity, visibility and loader lifetime. Our `BarPopup` already does slide-down. Adopting `offsetScale` as the shared vocabulary for bar popups *and* the new edge panels would make them all move the same way.
- **Motion tokens with named types** (`Anim { type: Anim.DefaultSpatial }`) are better than our three durations (`animShort/anim/animLong`). Adding easing per *kind* (spatial vs effects) is S effort in `config/Theme.qml`.
- The row library (`ToggleRow`, `StepperRow`, `SelectRow`, `SliderRow` on top of `ConnectedRect`) is what our QS pages lack. Today each page lays out its own rows. The self-audit's "component reuse" finding applies here.

### Goal 2: pop-out side panels (the main takeaway)
- Their sidebar is the closest thing to what the user described: a right-edge, full-height panel with tabs, notifications first, and other feeds as more tabs.
- What to take:
  1. **one right panel, tabbed**, not one panel per topic (Notifications · Weather · Feeds, later Mail/Calendar)
  2. **`toggleTab`-style IPC** so SUPER+N opens notifications, SUPER+W weather and so on, and pressing the same bind again closes it
  3. the **lazy loader** with a keep-alive flag for expensive tabs
  4. **push rules**: the session menu and the OSD sit beside the open sidebar
  5. **RSS via `XMLHttpRequest`** in QML for feeds, with no helper process to tether
- What not to take: the single full-screen window. On Hyprland a normal right-anchored `PanelWindow` (top+bottom+right anchors, `exclusiveZone: 0`, slide via `offsetScale`) gets the same effect at a fraction of the complexity. A separate 2 px edge strip window can provide hover-peek if wanted (impasto P11 already sketches the strip).
- Grouping: theirs groups by raw `appName` (`NotifGroup.qml:21`). Keep our planned source map (email/Discord/system). Borrow their `expandedNotifs` list (which groups are expanded survives the panel closing) and the per-group "clear" action (`NotifDockList.qml:77`).

### Goal 3: full settings shell
- Nexus is the most complete settings UI of the repos reviewed so far. The parts to steal, beyond impasto's "window with sidebar + search":
  - **`PageDictionary` as data**: `{label, key, icon, description, category, settings:[{label, keywords, pagePath, subPageIdx}]}`. One table feeds the nav pane, the search index and deep-link IPC.
  - **Sub-page stack** in a tiny state object (`NexusState.subPageIdxStack`, `openSubPage`, `closeSubPage`, `goToSubPage` with `pendingSubPageIdx`). This is the same idea as our QS `Ui.page`/`back()`, generalised.
  - **Singleton window factory** (`WindowFactory.create()`): a second open raises and focuses the existing window and navigates it, so you never get two copies. On Hyprland, `Hyprland.dispatch("focuswindow title:…")` replaces their `Kwin.focusWindow`.
  - **Read-resolved / write-global** split: rows read the effective value and write the stored one. For us that means read `Theme.radius` and write `Prefs.set("shape", "round")`.
  - **`ConnectedRect` first/last radii**: rows in a group share a container. In round mode the first/last rows get the big radius and the middle rows a small one. In square mode all radii are 0 and the rows are separated by hairlines. This maps exactly onto our "accent follows corner style" rule.
  - `KeyCaptureDialog` + `ShortcutManagerPage`: rebinding is KDE kglobalaccel-specific, but a read-only "keybinds" page fed by our `Keybinds` service fits there.

### Goal 4: wallpaper manager
- `WallpaperSelect.qml` gives us four concrete ideas:
  1. **sub-folder = category** (so `~/Pictures/walls/<theme>/` could double as theme tagging with no metadata file)
  2. **filter chips**
  3. **sort by perceptual colour distance** to a swatch (their `colorDistance` is the "redmean" formula on a dominant colour from the C++ `ImageAnalyser`)
  4. **hover preview, click commit** (`Wallpapers.preview(path)` / `stopPreview()` swap `current` without touching awww until commit)
- For us: compute each wallpaper's dominant colour once and cache it in the metadata JSON, using `magick img -resize 1x1\! -format '%[hex:p{0,0}]' info:`. Then "suggest for this theme" = sort by distance to the palette's `background`/`accent`, used when a wallpaper has no explicit `theme` tag. Season stays an explicit tag.

### Goal 5: voice assistant
- `AiAssistant.qml` has a useful pattern: a **closed tool vocabulary** that is parsed from `<tool_call>{json}</tool_call>` in plain text (`parseTextToolCalls`). It works with any Ollama model, even one without native tool calling. The tools are `take_screenshot`, `web_search`, `read_webpage`, `open_app`, `set_timer`, `get_weather` and `caelestia_command`, each mapped to a fixed argv. This is the right shape for our action registry (impasto P9).
- Do not copy: no confirmation step, `--dangerously-skip-permissions` as a setting, an `open_app` that pipes a `.desktop` `Exec=` line into `xargs sh -c`, and chat history stored inside the config JSON. Our "ask before escalating to `claude -p`" rule needs a pending-action confirm card that they do not have.

### Goal 6: focus mode
- Nothing relevant. `GameMode.qml` auto-toggles on fullscreen windows (it disables effects and video wallpaper). A "mode" that changes shell behaviour on a trigger is the same shape as focus mode, but the Pomodoro/openwindow enforcement model is already covered elsewhere.

## 6. Proposals for us (ranked)

1. **`EdgePanel` component with the `offsetScale` recipe (S)**
   - **What:** `components/EdgePanel.qml`, a `PanelWindow` with `edge: "right" | "left" | "top"`, the anchors that edge needs (full height for left/right), `exclusiveZone: 0`, and `WlrLayer.Overlay` while open.
     - `property real offsetScale: open ? 0 : 1` with a Behavior; the panel slides via a margin `(-width) * offsetScale`; `visible: offsetScale < 1`.
     - `mask: Region { item: panel }`, so only the visible rect takes input.
     - `Loader { active: open || visible }` for content; `keepAlive` opt-in.
     - Reuse BarPopup's focus logic: `HyprlandFocusGrab` over the panel only, set keyboard `OnDemand` before mapping, Escape → `Ui.dismiss()`.
   - **Files:** new component; factor the shared focus/escape bits out of `components/BarPopup.qml` into it (or into a small mixin both use).
   - **Risk:** our known Hyprland gotcha. The focus grab must not include the bar. Test on both monitors.

2. **Right sidebar: tabbed Notifications · Weather · Feeds (M, after the notification server)**
   - **What:** `modules/sidebar/SidebarWindow.qml` on `EdgePanel`.
     - Tab strip using our `TabBar` (sliding underline in square mode, pill in round mode).
     - Pages slide horizontally like the dashboard.
     - `Ui.toggle("sidebar", screen, tab)` semantics: the same bind on the same tab closes it, another tab switches.
     - `expandedGroups` kept in `Ui` so expansion survives closing.
     - Feeds tab: `services/Feeds.qml` using `XMLHttpRequest` + a small RSS/Atom parser, feed list in Settings, refresh while the tab is open, plus a slow background timer for an unread count.
     - Weather tab reuses the dashboard `WeatherTab` delegates in a narrow layout.
   - **Files:** new `modules/sidebar/`, `services/Ui.qml` (`sidebar` + `tab`), `shell.qml` IPC `sidebar(tab)`, Hyprland binds. New module dir → restart the shell.
   - **Risk:** the dashboard Weather tab and the sidebar Weather tab could drift apart. Share card components rather than duplicate them.

3. **Settings window built on a page dictionary (M→L)**
   - **What:** on top of impasto P6, a `modules/settings/Pages.qml` data table (`key, label, icon, keywords, component, sub-pages`). It drives the nav list, a fuzzy search index (reuse `Launcher.search` scoring) and IPC `settings(key)` deep links ("theme", "theme/font", "wallpaper").
     - Singleton window: a second `settings()` call focuses and navigates the existing window (`hyprctl dispatch focuswindow title:^rice settings$`).
     - Sub-page stack generalised from `Ui.page/back()`.
   - **Files:** new `modules/settings/`, `services/Ui.qml` or a new `SettingsNav` object, `shell.qml` IpcHandler.
   - **Notes:** the dictionary doubles as entries for the launcher `>` mode and voice-assistant actions ("open wallpaper settings").

4. **Row library that follows the shape option (S→M)**
   - **What:** `components/RowGroup.qml` (container) + `ToggleRow`, `SelectRow`, `SliderRow`, `StepperRow`. `RowGroup` gives children `first`/`last`.
     - Round shape: outer radius `Theme.radiusLarge` on the first/last row, `Theme.radiusSmall` between, pill accents.
     - Square shape: radius 0, 1px `Theme.surface2` separators, underline accent on focus.
     - Then port QS sub-pages (sound, nightlight, network) onto the rows.
   - **Files:** `components/`, `config/Theme.qml` (radius tokens per shape), `modules/quicksettings/*Page.qml`.

5. **Session drawer with keyboard nav (S)**
   - **What:** a right-edge `EdgePanel` with a vertical column of lock / log out / suspend / reboot / shut down. j/k/↑↓/Tab move, Enter fires, Esc closes, with a scrim (`Theme.background` at 50%) on the same window.
     - When the sidebar is open, it slides out beside it (offset = sidebar width).
     - SUPER+Escape stays lock. Add SUPER+SHIFT+Escape → session.
     - Keep our arm-on-second-click for mouse. Keyboard Enter is already deliberate.
   - **Files:** new `modules/session/SessionWindow.qml`, `services/Ui.qml`, Hyprland bind; `ProfileCard` buttons could open it instead of acting inline.

6. **Hover-preview, click-commit for themes and wallpapers (S→M, after the palette registry)**
   - **What:** `Theme.preview(paletteId)` / `Theme.stopPreview()` swap the role colours, which cross-fade through the existing Behaviors, without writing Prefs or pushing to ghostty/tmux. `commit()` writes and pushes.
     - Same for the wallpaper: show the preview image inside the picker and the bar (no awww call) until Enter.
     - Debounce 120 ms so arrow-key scrolling does not thrash.
   - **Files:** `config/Theme.qml`, the planned `services/Wallpaper.qml`, settings pages.

7. **Wallpaper picker: folder categories + colour-distance suggestions (M)**
   - **What:**
     - Treat `walls/<theme>/` sub-folders as implicit `theme` tags (explicit metadata still wins).
     - Cache each wallpaper's dominant colour (one `magick` call per new file, stored in the metadata JSON).
     - Sort "suggested for <theme>" by redmean distance to the palette.
     - Filter chips: theme · season (auto from the date) · all.
     - Keyboard grid, preview from P6.
   - **Files:** planned `services/Wallpaper.qml`, a small `scripts/wall-index.py` (one shot, exits; no tether needed), settings wallpaper page.

8. **Motion tokens by kind (S)**
   - **What:** `Theme.anim.{spatial, spatialFast, effects, effectsFast}` (duration + `easing.bezierCurve`) and an `Anim { kind: "spatial" }` wrapper in `components/`. Replace the ad-hoc `NumberAnimation`s.
   - **Files:** `config/Theme.qml`, new `components/Anim.qml`, grep-and-replace.

9. **Panel-collision rule in `Ui` (S)**
   - **What:** a computed `Ui.rightStackOffset(screen)` = width of the open sidebar. The session drawer and the future OSD add it to their right margin, as `Panels.qml` does for `osdWrapper`.
   - **Files:** `services/Ui.qml`, `EdgePanel`.

10. **Optional, later: per-screen single drawer window (L)**
    - **What:** only if we ever want hover-from-edge gestures or panels that visually merge with the bar. It would replace all `BarPopup`/`EdgePanel` windows with one full-screen layer per screen, using an Xor mask + `Exclusions`-style 1×1 exclusive-zone windows.
    - **Risk:** high. It changes focus behaviour, adds per-screen GPU cost, and needs a rewrite of `BarPopup`. Not recommended now.

## 7. Don't copy

- **KDE/Plasma-only APIs** (unusable on Hyprland):
  - `services/Kwin.qml` + the C++ `KWinActiveWindowBridge` (plasma-window-management protocol) and `KWinWorkspaceState` (D-Bus virtual desktops)
  - `GlobalShortcut` via kglobalaccel (`modules/Shortcuts.qml` `CustomShortcut`)
  - the `kdeFocusGrab` polling Timer in `ContentWindow.qml` (we have `HyprlandFocusGrab`)
  - `qdbus6 org.kde.Shutdown` logout (`session/Content.qml:27`)
  - `syncPlasmaWallpaper` (PlasmaShell `evaluateScript`) and the `kwriteconfig6` lock-screen sync (`services/Wallpapers.qml:132`)
  - Krohnkite tiling pages, `kwin-effects/`, Darkly Qt/GTK, `spectacle` screenshots in the AI tools, the SDDM `kwriteconfig` sync (`src/sddm/sync.sh`)
  - Upstream Hyprland equivalents exist for all of these, and we already use the Hyprland ones.
- **`Caelestia.Blobs` SDF backgrounds and the screen frame.** They need a custom C++ plugin build, are organic/rounded by nature, and fight the square retro identity. In round mode a plain `Rectangle` with radius is enough.
- **The C++ config tree / plugin system / plugin store / per-monitor attached Config.** This is product-scale infrastructure. Our JsonAdapter store (same as impasto) is the right size.
- **Four bar positions.** That flexibility created most of their complexity (`State`s and radius ternaries everywhere). We keep one top bar.
- **Hover-to-open dashboard/OSD/utilities and drag-from-edge gestures** as the primary trigger. The user is keyboard + SUPER driven, and accidental opens were enough of a problem upstream that they had to add override flags.
- **`Qt.createQmlObject` with QML source strings** to spawn `Process`es (`AiAssistant.qml`, `News.qml`). This is fragile and leaks objects if `destroy()` is missed. Use declared `Process` items with `Settings.tether`.
- **The AI sidebar as written**: no confirmation, an optional `--dangerously-skip-permissions`, `sh -c` over `.desktop` Exec lines, and history inside the config file. It is the opposite of our "ask before escalating" rule.
- **Installer TUI, self-updater, AUR packaging, translations, CI gauntlet.** Irrelevant for a single-user stow rice.
- **Novelty assets** (Bad Apple overlay, dino game in the empty notification list, bongocat).
