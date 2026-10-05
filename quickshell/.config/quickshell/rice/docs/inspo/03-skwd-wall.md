# 03 · skwd-wall (liixini/skwd-wall)

Repo: https://github.com/liixini/skwd-wall. Reviewed from a shallow clone of `main` (HEAD `965e9e0`, "Publish Wall beta.24", version `1.0.0-beta.24`).
Paths marked "theirs" are relative to the repo root. Paths marked "ours" are relative to `quickshell/.config/quickshell/rice/`.
The brief asked for depth on goals 3 and 4, so this report spends most of its length on the picker, the catalog, theming and displays.

---

## 1. What it is

skwd-wall v2 is a standalone, GPU-rendered **wallpaper picker** for most Wayland compositors (Hyprland, Niri, KDE, Sway, COSMIC…). It is not a Quickshell config.
The v1 of this tool was part of the author's Quickshell shell "Skwd". v2 is a rewrite in **Rust**: iced 0.14 + wgpu 27 (Vulkan) + `iced_layershell`, about 102k lines in `src/`, of which a large share is tests. It has 14 locales (Fluent `.ftl`), Forgejo CI, `cargo deny`, and AUR/COPR/Nix packages.
This repo is only the **client** (the picker UI). The other parts live in sibling repos that were not cloned:
- `skwd-deck` / `skwd-walld`: the long-running wallpaper daemon. It owns the library DB, thumbnails, colour extraction and theming backends, and applies wallpapers.
- `skwd-paper`: the renderer for images, video and Wallpaper Engine scenes.
- `skwd-lens`: the local SigLIP2 visual-search and auto-tagging helper.

The picker talks to the daemon over JSON-RPC (`wall.apply`, `wall.retheme`, `theme.preview`, `wall.shell_preview`…).
Maturity: beta. It is ambitious and works on many setups, but the README admits to Wallpaper Engine gaps.
License: **GPL-3.0-or-later**. Reimplement the ideas and copy no code, as we did with lyne-dots and impasto.

Because the daemon is not in this repo, we cannot see how it extracts colours (the README says "Iris", reimplemented from Harman1307/iris) or how it builds thumbnails. What we can see is everything those parts hand to the client.

## 2. Architecture

```
src/
  app/            iced App: state/, update/ (message handlers), view/, runtime/, warm.rs (startup timing)
  domain/         pure logic: library/{catalog,filter,search}, theme/candidate.rs, schedule/blocks.rs, effects
  contracts/      shared types: picker/mode.rs (7 picker modes), preview/{buffer_pool,upload}.rs
  infrastructure/ IO: library/wall_list.rs (decode daemon rows), preview/decode.rs (thumbnail workers),
                  theme/{saved,palette}.rs, semantic.rs (lens sidecar), ipc/, config/
  frontend/       widgets: scene/ (slices, hex, wall, sandy, hand…), settings/, theme_designer/,
                  schedule_editor/, tagcloud/, playlists/, browser/ (Wallhaven/Steam/Bing)
  rendering/      wgpu pipelines + texture atlases (scene/atlas.rs)
shaders/          transition.wgsl, sandy*.wgsl, item.wgsl
locales/<lang>/   Fluent strings (these are the best plain-language spec of every feature)
data/contracts/lens-taxonomy-v1.json   closed tag vocabulary with aliases
```

Patterns worth noting:

- **Picker as a throwaway process.** The picker starts in about 150 ms, renders 0 FPS when nothing moves, and **exits completely when closed** (`locales/en-US/settings/launch.ftl`). The daemon owns all lasting state, so the picker costs nothing while it is closed. Memory cost is paid only during a pick.
- **Catalog = daemon rows decoded into flat structs** (`src/domain/library/catalog/catalog.rs`). Each `Wallpaper` has:
  - identity: `key`, `name` (path relative to the library), `kind` (static/video/we), `thumb`, `preview`
  - file facts: `mtime`, `width`, `height`, `filesize`, `duration_ms`
  - **derived colour stats**: `hue` (a bucket 0–11, or `99` for neutral/grey), `sat`, `richness`
  - **usage stats**: `apply_count`, `last_applied`

  User metadata sits in side maps keyed by `key`: `tags`, `weather` (a list per wallpaper), `favourites`, plus `tag_counts` and `tag_vocab`. Derived data and user data are kept apart. That separation is the right shape for us too.
- **Filtering is a pure function**: `filter_sort(catalog, filters) -> Vec<u32>` (`src/domain/library/filter/filter.rs`). It returns indices, not copies.
  - Filters: folder (prefix match, dot-folders hidden), kind, hue bucket, favourites, orientation, resolution range, tags (all/any, with `-tag` to exclude), numeric predicates.
  - Sorts: `color` (default), `date`, `recent`, `pop`, `richness`, `minimalist`, `res`.
- **Search grammar** (`src/domain/library/search/{search,numeric}.rs`): free text resolves to vocabulary tags using stemming, edit distance and taxonomy aliases (built from `data/contracts/lens-taxonomy-v1.json` by `build.rs`). Numeric predicates are typed inline: `width:1920..3840 · duration:<30s · size:>=10MiB · | = OR · - excludes` (`locales/en-US/tags.ftl`).
- **Theme pipeline** (`src/app/update/theme.rs`, `src/app/theme_bar.rs`, `src/domain/theme/candidate.rs`):
  - A three-way **policy**: `fixed` (a static preset such as nord or gruvbox), `wallpaper` (derived by an engine: iris, matugen, wallust, pywal…, or handed to a shell such as noctalia or dms), or `off`.
  - Palettes are 9 Material-like roles (`Primary, PrimaryText, Tertiary, Surface, SurfaceText, SurfaceVariant, SurfaceContainer, Background, Outline`). Each palette has a dark and a light variant (`colors` / `alternate`).
  - **Per-wallpaper profiles** go under the config key `theme.wallpaperProfiles` (see section 4).
- **Config**: a JSON document with dotted keys (`theme.backend`, `matugen.colorIndex`…) behind `skwd_config` accessors, persisted by the client. Same idea as impasto's settings store.
- **External control**: UI commands over IPC (`src/app/update/ui_command.rs`): `select <key>`, `flip`, `reveal`, `bar show|hide|toggle`, `kind`, `settings-search <q>`, `clear`. A keybind can open the picker already filtered.

## 3. Feature inventory

| Feature | How it works (theirs) | We have it? | Worth adopting? |
|---|---|---|---|
| Picker exits on close | separate process; daemon keeps state (`launch.ftl`, `src/app/warm.rs`) | no picker at all | **Yes, adapted**: `LazyLoader` so the picker's QML tree and textures exist only while it is open |
| Two-tier thumbnails | far 160×88 BC1, near 640×360 BC7 + mips, built once by the daemon (`rendering/scene/atlas.rs`, `infrastructure/preview/decode.rs`) | no | **Yes, the idea**: prebuilt 160 px + 640 px WebP thumbs; skip the GPU block compression |
| Visible-first decode queue | `visible` deque popped LIFO (newest scroll position first), `backfill` FIFO, `wanted` set cancels off-screen near-tier jobs | no | Partly. Qt does this for us if delegates use `asynchronous` + `sourceSize` and are destroyed off-screen |
| Hue bucket + sat + richness per wallpaper | daemon-computed; 12 hue swatches + neutral in the filter bar (`frontend/ui/bar/model/builder.rs` `color_items`) | no | **Yes**: cheap to compute in Python; enables "sort by colour" and "fits this palette" |
| Colour-sorted default order | `cmp_color` default sort | no | Yes. Makes a grid look curated even with no tags |
| Usage stats | `apply_count`, `last_applied`; "Recently applied" sort | no | Yes. Also lets random mode avoid recent repeats |
| Tags (all/any, exclude) + tag cloud | `Catalog.tags`, `tags_ok`, `frontend/tagcloud/` | no | **Yes**, as theme + season tags (goal 3) |
| Auto-tagging + "describe" search | `skwd-lens` sidecar (SigLIP2), spawned on demand, killed on close (`infrastructure/semantic.rs`) | no | No for ~21 paintings. The lifecycle pattern is useful for goal 5 |
| Weather-tag soft filter | `weather_active`: narrows only if **at least one** wallpaper matches, else shows all (`filter_sort`) | no | **Yes**: the same "suggest, never empty" rule for season/theme |
| Per-wallpaper theme profile | `theme.wallpaperProfiles[] = {key, enabled, dark{}, light{}, settingsPinned, settings{}}` | no | **Yes**: this *is* "wallpaper ↔ known-fitting theme" |
| Hover-to-preview theme | 50 ms dwell gate, palette cache per card, smoothstep fade, revert on leave (`app/theme_bar.rs`) | palette cross-fade only (impasto idea) | **Yes**: preview a wallpaper's linked theme on focus; revert on Esc |
| Theme audition | `theme.previews` returns N palettes for one wallpaper; side-by-side compare (`theme-audition.ftl`) | no | Yes, as the Theme page: each preset rendered over the current wallpaper |
| Theme designer | 9 roles, HSV/hex/recents, seed→palette, saved palettes (`frontend/theme_designer/`) | no | Later / maybe. Our identity is fixed presets |
| Per-display apply + placement + lock | "Choose displays" step; Fill/Fit/Stretch/Center/Tile/Span; per-monitor Lock = "only change via multipicker" (`effects.ftl`, `settings/displays.ftl`) | span-slicing in `hypr/.../randomWallpaper.sh` only | **Yes**: lock + target + span as a placement |
| Picker opens on focused monitor, applies there by default | `settings-general-apply-picker-monitor-desc` | n/a | Yes. Matches our "act on focused monitor" IPC rule |
| Ordered rule schedule | first match wins; blocks: weekday, time (incl. sunrise/sunset), date `MM-DD..MM-DD`, year, weather, power, battery, output, output count; nested ALL/ANY groups; action = wallpaper/playlist/random + light/dark (`domain/schedule/blocks.rs`) | cron + random script | **Yes, small subset**: date ranges = seasons, time = day/night |
| Playlists | manual or filter-based, shuffle/sequential, per-display | no | Maybe. A "playlist" = saved filter (theme+season) is enough |
| Card back (details) | flip shows resolution, size, modified, times applied, tags, actions (`card-back.ftl`) | no | Yes, as a details strip/pane |
| Settings search with aliases | `settings-search-alias-monitor-terms = display output screen` | no | Yes for goal 3's settings shell |
| Rebindable keys + conflict warnings | `settings/keybinds.ftl` | Hyprland binds only | No. Fixed picker keys are fine |
| Image optimiser | replaces PNG/JPEG with WebP under a PSNR floor | no | **No**. Rewriting the art originals is a trap |
| Video / Wallpaper Engine / 39 transitions / sand shader | skwd-paper + wgsl | no | No (see section 7) |

## 4. Layout and UX patterns

**Picker shapes.** There are seven picker modes (`contracts/picker/mode.rs`): Slices (skewed vertical strips, the signature look), Depth, Hex (tessellated tiles bent into arcs or cylinders), Wall/Grid (uniform, brick, masonry, justified, editorial), Sandy (hero image plus a thumbnail row, with sand transitions), Hand (a hand of cards), and Collection.
Every mode has many sliders (skew, gap, corner radii, wobble). That is far too many knobs for us. The core lesson is simpler: **one hero/focused item plus a strip of neighbours** reads well at desktop scale, and the focused item is the only one that needs a big texture.

**Filter bar.** One horizontal row along the bottom edge holds:
- type chips `ALL PIC VID WE`
- 13 parallelogram colour swatches (12 hue buckets + neutral)
- sort menu (Default by colour / Newest / Recently applied / Colour pop / Colourful / Minimalist / Highest res)
- shape `WIDE/TALL`, size, folder dropdown, favourites
- a background-task strip (Tags / Index / Scan / Download with pause/stop)

Filters can be "sticky" across openings (`settings-filter-sticky-desc`).
In our retro style this maps to a row of underlined text chips plus square swatches.

**Search panel.** It drops below the picker and has two modes:
- **Tags**: autocomplete, `Space` adds a chip, `-` excludes, plus metadata predicates.
- **Describe**: semantic search.

It shows the result count and a "Clear N" button. Tag editing is "type + Space to add · × removes", including bulk "Apply to N" on a multi-selection.

**Card flip.** `F` (keybind "Flip card for details") turns the focused card around. The back shows `Library / Image`, Resolution, Size, Modified, Applied N times, up to a few tags with "+N more", and the actions Add tag / Playlist / Effects / Delete / Reset thumbnail.
This keeps the grid clean and still puts the details one key away.

**Theme while browsing** (`app/theme_bar.rs`). The flow:
1. The cursor or keyboard focus rests on a card for 50 ms (`THEME_DEBOUNCE_MS`, `dwell_gate`).
2. The picker requests that wallpaper's palette (`theme.preview` with the thumb path and any pinned profile settings), caches it per card, and cross-fades its own chrome to it (`start_fade` → smoothstep `lerp`).
3. Optionally it also tells the shell (`wall.shell_preview`) so the whole desktop recolours.
4. When focus leaves, or the picker closes, it fades back to `base_palette` and sends `wall.shell_preview_end`.

Applying makes the preview permanent. A small 6-swatch strip in the bottom-left corner shows the palette being previewed, labelled with its engine.
This is the best idea in the repo for goal 3: **you see the theme a wallpaper brings before committing, and nothing changes if you back out.**

**Per-wallpaper profile** (`save_wallpaper_profile`, `toggle_wallpaper_settings`). In the colour panel, "Save for this wallpaper" stores the current palette (dark and light) under the wallpaper's key, with an `enabled` toggle. A second toggle, `settingsPinned`, snapshots the theme settings (backend, scheme, mode…) for that wallpaper and restores them when it is applied.
`wallpaper_theme_state_for(key)` merges the global config with the pinned settings to decide what the wallpaper will produce. Even a `static` theme previews on hover when it is pinned.

**Multi-monitor.**
- The picker opens on the focused monitor (or a chosen one) and applies there by default.
- "Choose displays" opens a target sheet: one tile per display with resolution, orientation, offline state, current vs incoming thumbnail, `◆ Selected` / `◇ Add`, and a placement choice per display. The button reads "Apply to N displays".
- Each display keeps its own placement and audio.
- **Lock** on a display means "only update this monitor's wallpaper through the multipicker": schedules and random changes skip it.

**Clunky bits.**
- The settings surface is enormous (`frontend/settings/tabs/builder.rs` is 1k lines; the selector settings alone have about 80 strings).
- There are seven picker modes with mode-specific presets.
- Theming offers 14 backends with sub-options (`theme-bar.ftl`).

It is a toolkit for wallpaper collectors with thousands of files. The README says itself that it is not for "someone that can reasonably name all the wallpapers you have". The user's library is **~21 images in `~/Pictures/Wallpapers/` (12 in `dore/`)**, so we should take the interaction ideas and leave the scale machinery.

## 5. Against our goals

### 5.1 Goal 1: clean up clunkiness
- **Details behind a flip.** Their card back hides metadata until asked. The same "summary first, details on one key" rule fits our cramped dashboard cards.
- **Sticky filters with an explicit "Clear N".** The UI always shows how much filtering is active.

### 5.3 Goal 3: settings shell (theme + wallpaper)
- **The data model the user asked for already exists here in pieces.** Combining them gives us:
  - derived per-image facts (hue/sat/richness/size)
  - user tags in a side map
  - a closed vocabulary with aliases (their taxonomy JSON; ours would be tiny: theme ids + `spring|summer|autumn|winter` + maybe `day|night`)
  - per-wallpaper profiles that pin a theme
- **Soft suggestion, not hard filtering.** `filter_sort` applies the weather filter only when at least one item matches. For "suggest by theme and time of year", go one step further: **sort** matches first and dim non-matches, never hide them.
- **Theme preview on hover/focus, revert on leave** (50 ms dwell). With our impasto-style palette cross-fade this is cheap: `Theme.preview(id)` / `Theme.endPreview()`.
- **Theme audition page.** Render every theme in the default list over the current wallpaper thumbnail, side by side (a mock bar strip + one card per theme, drawn in that theme's palette, shape and font). That gives a "Themes" settings page with real previews instead of names.
- **Settings search with aliases** (`settings-search-alias-*`): "monitor" finds "display", "colour" finds "theme". Cheap to add once settings is one page model.
- **Policy tri-state** (`fixed` / `wallpaper` / `off`). For us this becomes: *fixed theme* (picked by hand) / *follow wallpaper* (applying a wallpaper switches to its linked theme) / *off*.

### 5.4 Goal 4: wallpaper manager/selector
- A picker layout of **hero + neighbour strip** (their Sandy/Slices), keyboard first, with a details flip and a filter row of theme chips, season chips, hue swatches and sort.
- **Sorts**: by colour (the default, it makes any library look curated), recently applied, newest, "fits current theme" (palette distance).
- **Multi-monitor**: target sheet + per-display lock + per-display placement, with **span** as one placement. Our `randomWallpaper.sh` already slices spans with PIL; it moves into the service.
- **Schedule** as a short ordered rule list: date ranges (seasons), time windows (sunrise/sunset, since we already have `Weather` daily data), optionally weather. Action = "random from filter" + optional theme. This replaces the cron job.
- **Memory**: their numbers (6 MiB static daemon; picker gone when closed) come from (a) the process exiting and (b) never decoding originals in the UI. Both translate to QML: `LazyLoader`, prebuilt thumbs, `Image.sourceSize`.

### 5.5 Goal 5: voice assistant (pattern only)
- `infrastructure/semantic.rs` shows how to run a heavy local model **only while needed**:
  - the helper is a child process with a JSON-lines protocol on stdin/stdout, spawned lazily on the first query
  - queries are debounced for 350 ms and coalesced (`debounce_query` drains newer queries)
  - each query carries a `generation` number so stale answers are dropped
  - the helper gets SIGKILL when the panel closes
  - each index is tied to its model (`index_model_matches`)

  This is the right lifecycle for whisper/LLM helpers too, and it matches our `Settings.tether` rule.

## 6. Proposals for us (ranked)

1. **Wallpaper index helper.** Effort: **S–M**.
   - **What:** `scripts/wall-index.py`, JSON on stdout like our other helpers. It walks `Settings.wallpaperDir` and writes `~/.cache/quickshell/wallpapers/index.json`. Each entry has `key` (path relative to the library), `mtime`, `w`, `h`, `size`, `hue` (12 buckets + 99 neutral, taken from a 64×64 downscale in HSV, ignoring low saturation), `sat`, `richness` (count of distinct hue bins above a threshold), `swatch` (5 dominant colours), and thumbs at `thumbs/<sha1(key+mtime)>-{160,640}.webp`.
   - It is incremental: reuse an entry when `mtime` is unchanged, and remove thumbs for deleted keys.
   - Run it when the picker opens (it finishes in milliseconds when nothing changed) and after a new file arrives.
   - **Files:** new `scripts/wall-index.py`, new `services/Wallpaper.qml` (impasto-style service; that part is the same as impasto), `config/Settings.qml` (`wallpaperDir`, thumb sizes).
   - **Risk:** Pillow is already used by `randomWallpaper.sh`. Thumbnails are cheap. The index is cache and can be rebuilt any time.

2. **User metadata file separate from the index.** Effort: **S**.
   - **What:** `~/.config/rice/wallpapers.json` (or `wallpapers.json` in the stow repo if the user wants it versioned; it holds no secrets) shaped as `{ "<key>": { "themes": ["gruvbox-retro"], "seasons": ["autumn","winter"], "fav": true, "lock": false } }`, plus a usage section `{ applied: n, last: ts }`.
   - Keep a closed vocabulary (theme ids from the palette registry + 4 seasons) the way their taxonomy JSON does, so typos can't create orphan tags.
   - **Files:** `services/Wallpaper.qml` (FileView + JsonAdapter, same as impasto's settings store).
   - **Risk:** keys are relative paths, so renaming a file loses its tags. Accept that, or add a content-hash fallback later.

3. **Picker module: hero + strip, keyboard first.** Effort: **M**.
   - **What:** `modules/wallpaper/WallpaperPicker.qml` in a `LazyLoader` (its whole tree is freed on close; this is our version of "the picker exits"). It shows on the focused monitor.
   - Layout: a big focused preview (640 px thumb) above a `ListView` strip of 160 px thumbs. Every delegate `Image` sets `asynchronous: true`, `sourceSize`, `cache: false`. `cacheBuffer` is about one screen.
   - Keys:

     | Key | Action |
     |---|---|
     | ←/→ | move |
     | Enter | apply to this monitor |
     | Shift+Enter | target sheet |
     | `F` | toggle favourite |
     | Tab | details flip (resolution, size, applied N×, tags, linked themes) |
     | `/` | tag search |
     | Esc | back / close |

   - Opened with SUPER+SHIFT+W and `qs -c rice ipc call rice wallpaper [filter]`, following their `select`/`kind` UI commands.
   - **Files:** new `modules/wallpaper/`, `shell.qml` (IpcHandler `wallpaper(arg)`), `services/Ui.qml` (`open = "wallpaper"`), Hyprland keybinds, README.
   - **Risk:** the brief notes the impasto carousel "only decodes centre images". The difference here is the two tiers: thumbs from the index for the strip, the larger thumb for the centre, and the original never loads in the UI.

4. **Theme suggestions: soft sort + focus preview.** Effort: **M**.
   - **What:**
     - Sort order = (linked to the current theme or tagged with the current season) first, then by palette distance between the wallpaper `swatch` and the theme's accent/background, then by hue.
     - Non-matching items stay visible but dimmed. If nothing matches, sort by colour only (their weather fallback rule).
     - The season comes from the date: meteorological seasons for the northern hemisphere (Mar–May spring, Jun–Aug summer, Sep–Nov autumn, Dec–Feb winter), configurable in Settings.
     - When focus has rested on an item for about 150 ms (their 50 ms is tuned for mouse hover; keyboard stepping needs longer), and the wallpaper has a linked theme and the policy is "follow wallpaper", call `Theme.preview(id)`. The cross-fade runs; Esc or close calls `Theme.endPreview()`; Enter commits.
   - **Files:** `services/Wallpaper.qml`, `config/Theme.qml` (or the planned palette registry: add a `previewId` that wins over `activeId`), picker module.
   - **Risk:** previewing a font or shape change on focus is too jumpy. Preview **palette only** on focus, and show shape and font in the details pane.

5. **Theme policy + wallpaper ↔ theme links.** Effort: **S**.
   - **What:** a `Settings.themePolicy` of `"fixed" | "follow" | "off"`.
     - In `follow`, applying a wallpaper with a single linked theme switches to it. With several linked themes, it prefers the current one if listed, else the first.
     - In `fixed`, links only feed the suggestions.
   - Each theme in the default list ships a `wallpapers: [keys]` hint and each wallpaper record has `themes: [ids]`. Store one direction only (on the wallpaper) and derive the other, so they can't drift apart.
   - **Files:** settings store, palette registry, `services/Wallpaper.qml`.
   - **Risk:** keep status colours fixed across themes (impasto rule), so red still means bad.

6. **Multi-monitor: target sheet, per-display lock, span as a placement.** Effort: **M**.
   - **What:**
     - Default target is the picker's monitor.
     - Shift+Enter opens a sheet with one square tile per `Hyprland.monitors` entry, drawn to scale from monitor geometry, showing current → incoming thumbs and a placement chip (`crop | fit | span`).
     - `lock` per output is stored in the metadata or settings; random and schedule skip locked outputs.
     - **Span** moves the PIL slicing from `hypr/.config/hypr/external/randomWallpaper.sh` into `scripts/wall-span.py`, keyed by `sha1(key:WxH)` with the same purge rule. The service then calls `awww img -o <out>` per slice.
   - **Files:** `services/Wallpaper.qml`, new `scripts/wall-span.py`, picker sheet component, retire `randomWallpaper.sh` and its cron entry.
   - **Risk:** span only handles one horizontal row of equal-height monitors (same limit as the script today). Tell the user so.

7. **Small rule schedule replacing cron.** Effort: **S–M**.
   - **What:** `Settings.wallpaperRules`, an ordered list where the first match wins: `{ when: { date: "09-01..11-30", time: "sunset..sunrise" }, pick: { seasons: ["autumn"], themes: ["current"] }, every: "60m" }`.
   - A QML `Timer` evaluates the rules. Sunrise and sunset come from `Svc.Weather.daily`, which we already fetch. `random` excludes the last N applied (from the usage stats) and locked outputs.
   - Weather blocks can wait. Their `weather:` tags assume a tagged library, and with ~21 paintings "rainy" is a stretch.
   - **Files:** `services/Wallpaper.qml`, `config/Settings.qml`, settings page later.
   - **Risk:** keep the vocabulary tiny. Their nested ALL/ANY editor is 1.6k lines (`frontend/schedule_editor/view.rs`) and we do not need it.

8. **Filter row + search grammar (minimal).** Effort: **S**.
   - **What:** a picker row of chips `ALL ★ │ theme chips │ season chips │ 12 hue swatches + ◌ neutral │ sort: colour/recent/new/fit`. In `/` search, words resolve to vocabulary tags (prefix match), `-tag` excludes, and `w:>=3840` gives a resolution predicate (useful for span candidates). Show "N wallpapers · Clear N".
   - **Files:** picker module, `services/Wallpaper.qml` (`filterSort(filters)` returning index arrays, as in their `filter_sort`).
   - **Risk:** none. It is pure JS over at most a few hundred records.

9. **Themes settings page with audition previews.** Effort: **M**. Lands with the goal-3 settings shell.
   - **What:** a grid of tiles, each a miniature bar strip + one card drawn in that theme's palette, shape (square/underline vs round/pill) and font, over the current wallpaper's 640 thumb. Enter applies; focus previews the palette (proposal 4). A "Save for this wallpaper" button writes the link (proposal 5).
   - **Files:** future `modules/settings/ThemesPage.qml`, palette registry.
   - **Risk:** rendering N fonts at once is fine. Rendering N full shells is not, so keep the tiles as mocks.

10. **Side fix found while comparing: lock-screen wallpaper decode size.** Effort: **S**.
    - `modules/lock/LockScreen.qml` loads `Svc.Lock.wallpapers[...]` with no `sourceSize`. Our library has 30 MP originals (`John_Martin1.jpg` is 6767×4404, about 119 MB as RGBA), and the lock decodes one per monitor at full size just to blur it.
    - Add `sourceSize: Qt.size(surface.width / 2, surface.height / 2)`. With `PreserveAspectCrop` Qt scales to cover; half resolution is invisible under `blur: 1.0`.
    - Once proposal 1 exists, use the 640 thumb or a 1080p cache instead.
    - **Files:** `modules/lock/LockScreen.qml`.
    - **Risk:** none.

11. **Lazy model sidecar pattern for goal 5** (no wallpaper work). Effort: **S** to adopt as a convention.
    - Spawn on first use through `Settings.tether`, JSON lines on stdin/stdout, a `generation` id per request, a 350 ms debounce, and SIGTERM/SIGKILL when the panel closes. Document it in `docs/architecture.md` next to the tether rule.

**Alternative considered: run skwd-wall itself as the backend.**
- It is on AUR (`skwd-wall-v2-bin`), supports Hyprland, and replaces awww with `skwd-walld`. It brings per-display apply and locks, schedules and tags for free, and it has a static `gruvbox` preset plus a `colors.json` our shell could read (`infrastructure/theme/palette.rs` shows the keys).
- **Against:**
  - Its UI has its own look (Roboto Condensed, skewed slices), which clashes with the retro identity.
  - It adds a Rust daemon and a Vulkan client for 21 images.
  - Its theme model is Material roles, not our palette + shape + font.
  - It would split wallpaper state between two programs.
- Verdict: not recommended. Reconsider if the library grows to thousands of images or video wallpapers become a goal.

## 7. Don't copy

- **Video, Wallpaper Engine scenes, and the 39 transitions (sand, Möbius…).** Huge surface area, a GPU renderer, and audio mixing. Our awww fade is enough, and the user's wallpapers are paintings.
- **BC1/BC7 texture atlases and custom decode pools** (`rendering/scene/atlas.rs`, `infrastructure/preview/decode.rs`). They only make sense for a wgpu renderer with thousands of cards. In QML, `sourceSize` + `asynchronous` + delegates destroyed off-screen + prebuilt small WebP thumbs gets 95% of the benefit.
- **SigLIP2 auto-tagging / "Describe" search.** It needs a model download and a background index for ~21 hand-picked images that we can tag by hand in a minute. Revisit only if the library grows a lot.
- **Image optimiser** (replaces PNG/JPEG originals with WebP under a PSNR floor). Never rewrite the art originals; thumbs belong in a cache.
- **14 colour backends** (matugen/wallust/pywal/iris/noctalia/dms/end-4…) and **50-role Material schemes.** Our goal is curated palettes + shape + font, not extraction. Wallpaper-derived colour at most drives *suggestions* (palette distance), never the palette itself.
- **Seven picker modes, each with its own presets and dozens of sliders.** Ship one layout (hero + strip) with fixed metrics from `Theme`. Their settings sprawl is the clunkiness goal 1 wants to remove.
- **Hard weather/season filters that can empty the grid.** Suggest by sorting and dimming instead.
- **Nested ALL/ANY schedule editor.** A flat ordered rule list with date/time is all goal 3 needs.
- **Download browsers (Wallhaven, Steam Workshop, Bing daily).** Network-facing scope creep. If wanted later, a separate small script is better.
- **Code.** GPL-3.0-or-later: reimplement the ideas, copy nothing.
