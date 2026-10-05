# 05 · Clavis Shell (StatIndet/quickshell)

Repo: https://github.com/StatIndet/quickshell. Reviewed from a shallow clone of `main` (HEAD `3c74393`, 2026-10-04).
Paths marked "theirs" are relative to the repo root; "ours" are relative to `quickshell/.config/quickshell/rice/`.

---

## 1. What it is

Clavis is a full desktop shell for **niri** (not Hyprland), built with Quickshell + QML + Qt 6, plus native C++ QML plugins (`core/plugin/{niri,weather,cava,lyrics,gamma,windowpreview,…}`) built with CMake/Ninja.
It is very large: about 106k lines of QML across about 600 files, 12k lines of C++, Python helpers, a PKGBUILD, a systemd user unit, CI, and i18n (en/zh_CN/zh_TW).
It also depends on a sibling project, `key-cli`, which handles screen recording, clipboard, sysmon streams and file search, and talks to the shell over a JSON machine protocol.
The look is **Material 3 Expressive**: matugen colours generated from the wallpaper, M3Shapes "cookie" masks, overshooting bezier curves, pill shapes and Google Sans Flex. That is the opposite of our retro identity.
It is actively maintained and has unusually strict internal conventions (`AGENTS.md`, `docs/ui-guidelines.md`).
The license is **GPL-3.0**, with MIT/MPL pieces from DMS, Zen and others listed in `licenses/README.md`. As with lyne-dots, we reimplement ideas and do not copy code.
There is **no AI, voice or assistant integration**.

## 2. Architecture

```
shell.qml → AppShell.qml        top-level assembly (357 lines)
Common/      tokens + pure helpers: Appearance (m3 colours), Metrics, Sizes, Typography, Fonts,
             Animations, WidgetState (open/closed flags), SidebarPolicy.js, settings-routes.json,
             generated/SearchCatalog.js
Services/    ~90 singletons: PersonalizationConfig (config.json), UiPreferences (ui-preferences.json),
             ThemeService (matugen), FontService, NotificationManager, Wallpaper*, Spotlight*, …
Widgets/     presentation-only controls (rule: never create a Process here)
Modules/     Bar, Sidebars (Dashboard + QuickSettings), ControlCenter (settings window), Keystone
             (dynamic island), Launcher ("Spotlight"), Lock, Wallpaper, Dock, DesktopCards, …
core/        C++ plugins (Clavis.Niri, Clavis.Weather, …)
scripts/     theme/matugen helpers, niri KDL config writer, dev/generate-search-catalog.py
```

Notable patterns:

- **Layering rule.** `Widgets/` may not spawn processes. Services own all I/O. Our `components/` vs `services/` split is the same idea, but we never wrote it down as a rule.
- **Two config files.**
  - `PersonalizationConfig` → `config.json` holds the "look": wallpaper, theme, bar layout, sidebar sides, panel sizes.
  - `UiPreferences` → `ui-preferences.json` holds volatile toggles and units: DND, dark mode, temperature unit, spotlight style, clock style.
  - Both use `FileView` with `atomicWrites: true` and `watchChanges: true`, a 50 ms reload debounce, and a `mkdir -p` step before `storeReady`.
  - Persistence is hand-written `toJson()` / `loadFromObject()`, not `JsonAdapter`. Every field passes through a `normalized*()` validator (`normalizedBoundedInt`, `normalizedOption`, `normalizedBezier`, …).
  - On load they also run `needs*Migration()`. If the normalized object differs from the file, they **repair** it by rewriting the file (`Services/PersonalizationConfig.qml:2283-2320`).
- **IPC** (`docs/ipc.md`):
  - Each module owns its `IpcHandler` (`sidebar`, `spotlight`, `keystone`, `control-center`, `lock`, …).
  - Methods return status strings (`DASHBOARD_OPEN`, `INVALID_SIDE`, `SCREEN_UNAVAILABLE`) instead of `void`.
  - Binds are plain argv: `spawn "qs" "-c" "clavis" "ipc" "call" …`.
- **One catalog for routes and actions.**
  - `Common/settings-routes.json` declares the settings pages.
  - `scripts/system/niri-actions.json` declares the actions.
  - `scripts/dev/generate-search-catalog.py` compiles both, plus the `SettingsSearchAnchor` declarations in each page, into `Common/generated/SearchCatalog.js`.
  - Actions carry `policy` (`include` / `unsafe` / `internal` / …), `confirmation` (`none` / `power-menu`) and `availability`. The generator refuses actions whose fixed argv disagrees with the shortcut, and requires every power action to go through the existing confirmation UI.
- **Theming.**
  - `Appearance` holds the m3 colour roles read from the matugen-generated `colors.json`, plus `mix` / `applyAlpha` / `solveOverlayColor` helpers.
  - `Metrics` holds static spacing, corner and control-height tokens. `Typography` is the M3 type scale bound to `Fonts.ui`.
  - `Animations` holds named curves and durations, and `Appearance.animation.*` bundles duration, type and curve together.
  - Matugen pushes to kitty, btop, cava and yazi through templates that can be toggled one by one (`MatugenTemplateService`).
- **Keyed consumer registration.** `SystemIdentityService.setUptimeConsumer("left-sidebar-info:" + screen, bool)` makes a service poll only while at least one keyed consumer is visible.

## 3. Feature inventory

| Feature | How it works (theirs) | We have it? | Worth adopting? |
|---|---|---|---|
| Edge side panels (left info, right quick settings) | `Modules/Sidebars/SidebarHostWindow.qml` is one full-screen Overlay `PanelWindow` per retained screen that hosts both panels. `Widgets/common/EdgeRevealSurface.qml` does a clip-wipe reveal. `Common/SidebarPolicy.js` arbitrates panels that share an edge | no (drop-downs only) | **Yes.** The best mechanism in the repo for goal 2 |
| Present-after-ready | `DashboardSidebar.qml`: async `Loader` → `readyForPresentation` → reveal. `keepSidebarsLoaded` keeps content warm after the first open | partial (Loaders live while open) | Yes. No half-built first frame |
| Sidebar view tabs (info / drawer / weather) | `DashboardSidebarContent.qml`: one Loader per view, plus a "stretchy" indicator with fast and slow edges | partial (dashboard `TabBar`) | Indicator: **yes**. It maps directly onto our underline |
| Notification centre | `Services/NotificationManager.qml` (end-4 lineage) groups by `appName`, persists to `$XDG_STATE_HOME/.../notifications.json`, and keeps at most 3 popups. `NotificationGroup.qml` has swipe-to-dismiss with neighbour "sympathy" offsets and expand/collapse | no (dunst) | Mostly the same as impasto/mochi. Take two details (§4) |
| Popups suppressed while the centre is open | `popupInhibited: silent \|\| (dashboardSidebarOpen && view === "info")`. `InfoView` calls `hideAllPopups()` + `markAllRead()` when it comes to the foreground | n/a | Yes. Small, and it feels right |
| Settings window | `Modules/ControlCenter/ControlCenterWindow.qml` is an xdg `FloatingWindow` with a navigation rail. Pages come from `settings-routes.json` | no | Structure yes. Window type is our choice |
| Settings page transitions | `SettingsPageHost.qml`: peer pages cross-fade in place. Deeper or back navigation slides along one axis, with direction taken from `navigationDepth` | partial (QS sub-pages slide) | Yes. Cheap and coherent |
| Settings search | `SettingsSearch.qml` (search field morphs out of the title bar) + `SettingsSearchAnchor.qml` (declared JSON per section, scroll-into-view in every enclosing Flickable, 1.1 s highlight frame) + the generated catalog | no | Later. Worth it once there are more than ~6 pages |
| Typed action catalog | `niri-actions.json` → generator → `SpotlightCatalog.execute(id)` with `available()` gates and a confirmation policy | no (IPC methods only) | **Yes.** It is the allowlist the voice assistant needs |
| Font roles | `Common/Fonts.qml` has `ui` / `mono` / `numeric` / `expressive`. "configured" is kept apart from "effective" and checked against `Qt.fontFamilies()`. `Services/FontService.qml` lists families and hides symbol fonts | no (one hard-coded family) | **Yes**, for goal 3's font picker |
| Draft/commit preview session | `Services/WallpaperPaletteSession.qml`: `begin()` returns a token, `update(token, state)`, `commit(token)` does an atomic write through a fresh `FileView`, and it auto-cancels if a context fingerprint changes | no | Yes, for theme and wallpaper previews |
| Validated config + migrations | `normalized*()` per field, `needs*Migration()`, repair-on-load | no (readonly `Settings.qml`) | Yes, combined with impasto's `JsonAdapter` store |
| Wallpaper | Quickshell-rendered wallpaper with 7 shader transitions (`assets/shaders/wallpaper/frag/wp_{fade,wipe,disc,stripes,iris_bloom,pixelate,portal}.frag`, DMS lineage) **or** an awww backend. Per-monitor, per-light/dark-mode, auto-cycle by interval or daily time, parallax | awww only | Pixelate transition: maybe (§6). The rest is the same as skwd-wall or tied to niri |
| Wallpaper picker in the launcher | `Modules/Launcher/SpotlightWallpaperProvider.qml`: a "wallpapers" mode with paginated results (`pageSize: 30`, `loadMore`) | no | Yes, as a cheap second path to the picker |
| Hover-to-preview island | `Modules/Keystone/Styles/Shared/KeystoneHoverController.qml` has open and close delays, and the trigger and the surface each keep it open | no | Optional (bar hover previews) |
| Busy indicator rule | `Widgets/common/BrailleSpinner.qml` (3×3 dot spiral, 90 ms) inside `InlineBusyIndicator.qml`, which always reserves its layout slot. Rule: busy states never shift layout | no | **Yes.** It is retro-native with square dots |
| UI copy rules | `docs/ui-guidelines.md`: no subtitle that repeats the title, no text that restates a switch's state, no backend jargon | no | Yes, as a written checklist for goal 1 |
| Desktop cards / dock / map / lyrics island / recording | Large modules, many with native code | partial (lyrics) | No |
| AI / voice | none | — | — |

## 4. Layout and UX patterns

**Edge reveal (the standout).** `EdgeRevealSurface` animates a single `revealProgress` from 0 to 1:

- `revealViewport` grows from the panel's edge (`width = root.width * revealProgress`) with `clip: true`.
- The inner `contentFrame` is placed at `x: -revealViewport.x`, so the **content never moves**. The edge of the panel wipes across content that is already laid out. Nothing reflows and no texture is snapshotted.
- A 24 px gradient "seam shade" sits at the moving edge.
- When a reveal is interrupted, the duration is scaled by the remaining distance: `duration = base * |target - progress|`. A quick close-then-reopen therefore does not stall.
- The easing curve is chosen *before* `start()`. Their comment explains that a separate easing binding can lag one frame behind the direction change.
- Enter takes 350 ms and exit takes 200 ms. Exit is faster on purpose.

A hard-edged wipe with a fixed interior reads as "retro terminal window being drawn". It fits our identity better than the slide or fade we use now.

**Sidebar host + policy.**

- One `PanelWindow` per screen is anchored on all four edges with `exclusionMode: Ignore`. Its `mask` covers the region only while a panel is open. One `MouseArea` closes whichever panel did not contain the click, and an `Esc` `Shortcut` closes all panels.
- `SidebarPolicy.resolveOpenState()` handles two panels set to the same edge: the most recently opened one wins, and the loser finishes its exit before the winner reveals (`presentationAllowed: !sameEdge || !other.panelPresented`). Panels on opposite edges can be open together.
- Moving a panel's edge in settings retires the losing panel immediately.
- `retainedScreenName` survives DPMS replacing the `Screen` object.
- Weakness: `keyboardFocus: Exclusive` while any panel is open. That is heavy, and our `OnDemand` + focus-grab approach (`components/BarPopup.qml`) is better for Hyprland.

**Stretchy tab indicator.** The indicator in `DashboardSidebarContent.qml` tracks four values:

- `leftFast` and `rightFast` move in 50 ms (OutSine).
- `leftSlow` and `rightSlow` move in 220 ms (OutSine).
- The indicator spans `min(leftFast, leftSlow)` → `max(rightFast, rightSlow)`. The leading edge therefore jumps ahead, the trailing edge catches up, and the indicator stretches like a worm.

Our `components/TabBar.qml` underline animates `x` and `width` together in 200 ms OutCubic. Swapping in this four-value trick keeps the underline identity and adds a lot of feel.

**Settings UX.**

- Navigation rail plus page host. Pages load asynchronously, and the old layer is retired only after the new one is ready, so there is no blank flash.
- Search morphs out of the title bar slot (`barGeometry` → centred 720×600 surface, 500 ms emphasized). A hit scrolls each enclosing Flickable in its own coordinates, then fades in a primary-tinted frame over the section for 1.1 s. A `FrameAnimation` keeps the frame aligned while things move.
- `docs/ui-guidelines.md` is the most transferable part. Its rules:
  - No supporting text unless it carries new information.
  - Never restate a switch's state in words.
  - Waiting is shown by an overlay spinner beside the control that triggered it, never by inserting a row.
  - Errors get an `InlineStatusBanner`.

**Notifications.**

- Grouping by app name with an expand button is standard end-4.
- Two good details:
  - Popups are inhibited, and everything is marked read, while the centre is on screen.
  - When one card is swiped, its neighbours follow at 30% / 10% of the drag until a 70 px confirm threshold, then snap back.
- Clunky: the group key is the raw `appName`. Discord, Vesktop and the web client become separate groups, and anything from `notify-send` without `-a` lands in "System". Our "group by source" goal needs a mapping table (see §5).

**What feels heavy.**

- Everything is gated behind Material Expressive overshoot curves (`expressiveDefaultSpatial: [0.38, 1.21, …]`), so it bounces.
- The weather sidebar alone is about 3k lines, including a Canvas weather scene.
- `PersonalizationConfig.qml` is 2325 lines with roughly 100 hand-written setters, which makes it a god-object.

## 5. Against our goals

### Goal 1: clunkiness and cohesion

- Write a `docs/ui-rules.md` modelled on their `ui-guidelines.md`:
  - no subtitle that echoes the title;
  - no "ON" label next to a switch;
  - busy states never change geometry;
  - errors only in a banner.
- Then audit the QS pages and the dashboard against it. Our `Switch` already shows OFF│ON, so drop the text that duplicates it.
- Separate motion tokens by direction: their exits are deliberately shorter than their entries (sidebar 350/200). Ours share `Theme.anim`.
- Write the "widgets never spawn processes" rule into `docs/architecture.md`. We mostly follow it already.

### Goal 2: pop-out side panels

- Copy the **mechanisms**, not the visuals:
  - `EdgeRevealSurface` (clip-wipe with fixed content, distance-scaled durations);
  - a per-screen host with `SidebarPolicy`-style arbitration;
  - present-after-ready async content.
- For "notifications grouped by source", do not group by raw `appName`. Map `appName` / `desktopEntry` → `source` ∈ {mail, chat, system, media, dev, other} through a table in `Settings` (for example `vesktop|discord|WebCord → chat`, `rice-mail|Proton Mail → mail`). Then group by source, with app sub-groups inside each.
- Also take their two niceties: inhibit popups while the panel is open, and mark all read when it comes to the foreground.
- Weather and news panels can reuse the same host as tabbed views (their info / drawer / weather pattern with the stretchy underline).

### Goal 3: settings shell (theme = palette + shape + font)

- **Fonts.**
  - Adopt `Fonts.qml`'s split between configured and effective families: keep the saved choice even when it is uninstalled, resolve to a fallback, and never lose the user's setting.
  - Adopt the `FontService.refresh()` listing from `Qt.fontFamilies()` with symbol fonts filtered out.
  - Add what they lack and we need: per-family metrics. DepartureMono is drawn on an 11 px grid (sizes 14/18/22/66 in `config/Theme.qml`), while a proportional font wants different sizes. So a theme's font entry should carry `{family, sizeScale or explicit sizes, mono: bool}`.
- **Persistence.**
  - Use impasto's `JsonAdapter` store, already covered in that review.
  - Add Clavis's per-field `normalized*()` clamps, a `schemaVersion` + `needsMigration()` + repair-on-load step, and the two-file split: `theme.json` for palette, shape, font and wallpaper versus `prefs.json` for DND, units and volatile toggles. Then flipping DND never rewrites the theme file, and dotfile diffs stay clean.
- **Preview.** Use the `WallpaperPaletteSession` pattern so that hovering over or scrolling through themes previews live without committing:
  - `begin()` returns a token;
  - stale tokens are ignored;
  - a context fingerprint (`JSON.stringify` of the inputs that matter) auto-cancels the draft if something else changes the config underneath;
  - commit is an atomic write, and the change is published only after `onSaved`.
- **Structure.** Use `settings-routes.json`-style page routes (id, title, icon, source) so the navigation, IPC (`rice settings theme`) and later search all read one list. `SettingsPageHost`'s depth-aware transition gives sub-pages (theme → palette editor) the right motion for free.

### Goal 4: wallpaper manager

- Their wallpaper side is mostly the same as skwd-wall (index, thumbnails) and the awww work already covered.
- Things that differ:
  - **Launcher wallpaper mode** with paginated results (`SpotlightWallpaperProvider`, 30 at a time, `loadMore` near the end). Wallpapers become reachable from `SUPER+Space` → Alt+4 without opening settings.
  - **Auto-cycle** by interval or at a fixed daily time (`WallpaperService.qml:661-680`). Pair this with our season tags: "on the 1st of each season, rotate within the current theme's seasonal set".
  - **Per light/dark-mode wallpaper slot** (`perModeWallpaper`, `pathLight` / `pathDark`). For us, the analogue is a wallpaper list per theme, which skwd-wall already covers.
  - **Pixelate transition shader** (`wp_pixelate.frag`): cells shrink from 10–80% of the screen down to 1 px, then a sharpen pass. It is very on-brand for retro, but only possible if Quickshell draws the wallpaper. awww has no pixelate transition.

### Goal 5: voice assistant

- No voice or LLM code. The **typed action catalog** is the reusable piece:
  - Each action has `{id, target, method, args, title, aliases, availability, confirmation, policy}`.
  - A build-time check proves that every action maps to a real IPC call with fixed args.
  - Power actions are forced to `confirmation: "power-menu"`.
  - `SpotlightCatalog.execute(id)` refuses anything that is unavailable and sends a notification instead.
- For "Hey Computer", this is exactly the allowlist:
  - The LLM picks an `id` from the catalog (with `aliases` as few-shot hints) and never builds shell commands itself.
  - `policy: unsafe` or anything missing from the catalog → ask the user, then escalate to `claude -p`.
  - `confirmation` drives a spoken or on-screen confirm.
- The same catalog would also feed a launcher "actions" mode.

### Goal 6: focus mode

- Nothing beyond a sidebar `PomodoroTimer.qml`, `TimerWidget`, `Stopwatch` and `TodoWidget`. Mochi already covers focus with Hyprland enforcement.

## 6. Proposals for us (ranked)

1. **`components/SidePanel.qml`: edge-wipe side panel** (M)
   - What: reimplement the `EdgeRevealSurface` mechanism:
     - `revealProgress`;
     - a clipped viewport anchored to the edge, with content counter-offset so it never moves;
     - a hairline border on the moving edge instead of their gradient seam, to keep it square and retro;
     - duration × remaining distance;
     - easing chosen before `start()`;
     - enter `Theme.animLong`, exit `Theme.anim`.
   - Files: new `components/SidePanel.qml`; new `modules/sidepanel/SidePanelHost.qml` (one `PanelWindow` per screen, Overlay layer, `mask` = visible panel, keep our `OnDemand` + `HyprlandFocusGrab` focus model from `BarPopup`); `services/Ui.qml` (add `left` / `right` panel state + same-edge arbitration as a 20-line pure JS helper); `shell.qml` (Variants + IPC `rice panel <name>`).
   - Risk: an Overlay surface covering the whole screen. Keep `mask` null while closed, as they do.
2. **Present-after-ready loading for panels and dashboard tabs** (S)
   - What: async `Loader`; reveal only once `item.ready`; optional `keepLoaded` after the first open.
   - Files: `SidePanel.qml`, `modules/dashboard/DashboardWindow.qml`.
   - Risk: none. Memory stays low with `keepLoaded: false` by default.
3. **Stretchy underline in `TabBar`** (S)
   - What: four animated edges, fast (50 ms) and slow (≈ `Theme.anim`). The underline spans the min to the max.
   - Files: `components/TabBar.qml` only.
   - Risk: none. Pure feel, and on-identity.
4. **Action catalog as the single allowlist** (M)
   - What: `config/actions.json` with `{id, target, method, args, title, aliases, availability, confirmation: none|confirm|power, policy: safe|confirm|unsafe}` for every `rice` IPC method, plus a small `scripts/check-actions.py` that cross-checks it against the `IpcHandler` in `shell.qml`.
   - It feeds (a) a launcher "actions" mode and (b) the voice assistant's tool list.
   - Files: new `config/actions.json`, new `services/Actions.qml` (`available(id)`, `execute(id)`), `modules/launcher/LauncherWindow.qml` (new mode).
   - Risk: keeping it in sync, which the check script handles.
5. **Font roles + font list** (S–M)
   - What: `Theme.fontFamily` → `Fonts.{ui,mono,numeric}`, with configured-vs-effective resolution and per-family size metrics. Add `services/Fonts.qml` (the `Qt.fontFamilies()` list, symbol and Nerd "Propo" duplicates filtered out, mono flagged).
   - Files: `config/Theme.qml`, `components/Label.qml`, new `services/Fonts.qml`.
   - Risk: DepartureMono's crisp 11 px grid. Store sizes per font, do not scale blindly.
6. **Validated, migrating, two-file settings store** (M)
   - What: impasto's `JsonAdapter` store plus Clavis's normalizers, `schemaVersion` migrations, repair-on-load, and a separate `prefs.json` for DND, units and other volatile toggles.
   - Files: `config/Settings.qml` (split readonly defaults vs writable), new `services/Store.qml`.
   - Risk: early-write clobbering, which impasto's `arrived` guard covers.
7. **Draft/commit preview session for theme and wallpaper pickers** (M)
   - What: `services/ThemeSession.qml` with a `begin` / `update` / `commit` / `cancel` token API, auto-cancel on a context fingerprint, and atomic commit before publishing.
   - Files: new service; the settings Theme page.
   - Risk: none. Avoids "preview stuck as real" bugs.
8. **Notification source mapping + panel-aware popups** (S, once the in-shell server lands)
   - What: an `appName` → source map in Settings; group by source, then by app; inhibit popups and mark read while the notifications panel is in the foreground; neighbour-sympathy swipe.
   - Files: the future `services/Notifications.qml` and the notifications panel.
   - Risk: none.
9. **Busy indicator rule + 3×3 dot spinner** (S)
   - What: `components/Spinner.qml` (a 3×3 grid of square cells lit in a spiral, 90 ms per step), wrapped so it always reserves its slot. Replace the text "loading…" rows in Mail, Calendar and GitHub.
   - Files: new component; `modules/quicksettings/MailPage.qml`, `modules/dashboard/{GithubTab,AgendaCard}.qml`.
   - Risk: none.
10. **Settings routes + depth-aware page transitions** (S)
    - What: `settings-routes.json`-style list; peers cross-fade, deeper and back slide by `Theme.gap`.
    - Files: the future settings window, and possibly `QuickSettingsWindow.qml` sub-pages.
    - Risk: none.
11. **Launcher wallpaper mode with pagination** (S)
    - What: Alt+4 "wallpapers" mode; results come from the skwd-wall-style index, 30 at a time, applied through the awww service.
    - Files: `services/Launcher.qml`, `modules/launcher/LauncherWindow.qml`.
    - Risk: thumbnail decoding cost. Use the prebuilt thumbnails.
12. **Seasonal auto-cycle** (S)
    - What: interval, or a fixed daily time, rotating within the current theme's tagged set for the current season.
    - Files: the wallpaper service.
    - Risk: none.
13. **Pixelate wallpaper transition** (L, optional)
    - What: only if we ever render the wallpaper in Quickshell (a `Background` layer `PanelWindow` + `ShaderEffect`, precompiled `.qsb`). Otherwise keep awww.
    - Files: new `modules/wallpaper/`.
    - Risk: a second wallpaper path and more GPU and memory use. The shader comes from DMS (MIT), so it would need attribution if we ever copy it.
14. **UI copy and layout rules doc** (S)
    - What: `docs/ui-rules.md`, adapted from their guidelines (see §5, goal 1).
    - Risk: none.

## 7. Don't copy

- **Material 3 Expressive motion and shapes.**
  - Overshooting curves (`expressive*Spatial` with a y1 above 1) and M3Shapes cookie masks clash with square, hairline, underline-accent retro.
  - Pill tab indicators and rounded `SettingsRow` (`cornerM: 17`) only fit our future "round" shape variant, and even then without the bounce.
- **Matugen palette from the wallpaper.** Our themes are curated palettes with wallpapers matched to them, not the other way round. Their template toggles for pushing to other apps are the same idea as impasto's theme push.
- **niri-specific machinery.** The overview wallpaper surface, column-following parallax, the KDL config writer and include-chain conflict checks, and `Clavis.Niri` minimize.
- **Native C++ plugins + CMake build + `key-cli` dependency.** That is far too much infrastructure for a stow-managed rice. Use QML plus small Python helpers, as we do now.
- **The 2325-line hand-written `PersonalizationConfig`.** Take the normalize/migrate idea and leave the ~100 setter functions. `JsonAdapter` + `set(key, value)` is leaner.
- **`keyboardFocus: Exclusive` on the sidebar host.** It steals the keyboard from Hyprland. Keep our `OnDemand` + focus-grab model.
- **Canvas weather scenes and scroll-reveal card staggering** (`WeatherBackground`, `WeatherRevealCard`, 200 ms stagger per card). They cost a lot and feel slow. Our column charts are the right density.
- **Compositor blur regions, the dynamic island, the dock and desktop cards.** None of these are in our layout, and impasto already covers the island.
- **i18n tooling and their test-policy bureaucracy.** Not useful for a single-user rice.
