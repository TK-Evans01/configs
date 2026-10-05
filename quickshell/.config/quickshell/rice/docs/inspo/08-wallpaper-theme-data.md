# 08 · Wallpaper + theme data model (goals 3 and 4)

This doc settles the concrete data design. Earlier reviews already chose these, and this doc does not revisit them:
- JSON store via `FileView` + `JsonAdapter` (01 P1)
- palette registry (01 P2, 00 §3)
- `scripts/wall-index.py` with hue buckets and thumbs (03 P1)
- user metadata kept apart from computed data (03 P2)
- soft suggestions: sort and dim, never an empty filter (03 P4)
- palette-only preview on focus (03 P4, 04 P6, 05 P7)
- a rule schedule instead of cron (03 P7)

## 0. What is on disk today (inspected read-only, 2026-10-05)

| Item | Finding |
|---|---|
| Library | `~/Pictures/Wallpapers`: 21 files, 62 MB. 18 jpg, 1 jpeg, 1 png, 1 webp. 9 classical paintings at the root and 12 Doré engravings in `dore/`. Sizes run from 1920×1079 to 6767×4404; all RGB except `dore/g19-gruvbox.png` (RGBA, 5243×1441, apparently a gruvbox-filtered span variant). |
| Rotation | `cron/crontab` runs `*/10 * * * * ~/.config/hypr/external/randomWallpaper.sh`, and Hyprland `exec-once` runs it once at login. It only reads `dore/`, only `*.jpg/jpeg/png` (the `.webp` is never picked), and slices span-width images with PIL into `~/.cache/wallpaper-span`. |
| Tools | Installed: `python-pillow 12.3` (WebP + AVIF), `python-numpy 2.5`, `sqlite 3.53`, `lutgen 1.0.1` (`~/.cargo/bin`), `gm`, `vips`, `awww`. **Not installed:** `imagemagick`, `exiftool`/`perl-image-exiftool`, `exiv2`, scipy, scikit-learn. |
| Stow folding | `~/.config/nvim` is a symlink into the repo, so anything written there lands in git. `~/.config/{dunst,ghostty,hypr,btop}` are real dirs whose files are individual symlinks; `~/.config/ghostty/themes` and `~/.config/btop/themes` are real, unmanaged dirs. `~/.tmux.conf` is a file symlink. |
| External palette copies | `ghostty/.config/ghostty/themes/gruvbox-material`, `dunstrc` (7 hex, `corner_radius = 0`, font), `hypr/external/look_and_feel.conf` (`col.active_border rgba(d4be98ff)`, `rounding = 0`), tmux plugin `hasundue/tmux-gruvbox-material`, nvim `ellisonleao/gruvbox.nvim` (**plain gruvbox, not material**, so it already drifts from the rest), `btop color_theme = gruvbox_material_dark`, `sddm/rice` (baked `background.jpg` + font, installed with sudo), firefox textfox (copied into the profile by `install.sh`). |

## 1. Where metadata lives

| Option | Survives copy/rename | Mutates images | Formats | QML read | Git/stow | Verdict |
|---|---|---|---|---|---|---|
| Embedded XMP/IPTC keywords (exiftool/exiv2) | Yes, travels with the file | **Yes**, rewrites every file; WebP/PNG XMP support varies by tool | JPEG good, PNG via iTXt, WebP via RIFF XMP chunk (exiftool only) | Needs a helper process; QML cannot read XMP | Images are not in git, so tags are not versioned; neither tool is installed | **No.** It breaks the never-modify-originals rule, needs a new package, and tags would be invisible to git. |
| Sidecar `foo.jpg.xmp` | Only if copied with the file | No | Any | Helper needed (XML) | One file per image beside the images, outside git | **No.** It doubles the file count, and only darktable/digiKam would benefit. |
| **One JSON file** | Keyed by relative path, with a `sha` fallback to re-link renames | No | Any | `FileView` + `JSON.parse`/`JsonAdapter`, already our pattern | One small diffable file; can live in the repo | **Yes.** |
| SQLite | Same as JSON | No | Any | `QtQuick.LocalStorage` puts the db in Qt's own offline-storage dir, or a helper is needed | Binary, not diffable | **No.** Overkill for a library of 21 to a few hundred images. |

**Recommendation: three JSON files, split by who writes them and how long they need to last.**

| File | Writer | Content | Location | In git |
|---|---|---|---|---|
| `wallpapers.json` (curated) | the picker (user edits), the bootstrap script | themes, seasons, tags, fav, placement, review flags | `rice/data/wallpapers.json` (inside the stowed rice dir) | **yes** |
| `index.json` (computed) | `scripts/wall-index.py` | size, sha, swatch, Lab stats, hue bucket, per-theme distance, thumbs, derived variants | `~/.cache/quickshell/rice/wallpapers/index.json` | no; rebuildable |
| `usage.json` (volatile) | `services/Wallpaper.qml` | applied count, last applied, current per output | `~/.local/state/rice/wallpaper-usage.json` | no |

Why the curated file is in git even though the images are not: tags are the expensive human work. If the images come back from a backup, the tags re-attach by path, or by `sha` after a rename. It holds no secrets, so it does not belong in `~/.config/rice/`, which is reserved for secrets.

Gotchas:
- `rice/` is a directory symlink into the repo, so the JSON inside is a real file. Never make the JSON file *itself* a stow symlink: atomic writes (temp file + rename) would replace the symlink with a plain file.
- **Verify** that Quickshell's hot-reload watcher ignores non-QML files under the config dir. It is believed to watch only files the engine loaded. If saving the JSON triggers a reload, move it to a sibling stow package (e.g. `configs/rice-data/.local/share/rice/wallpapers.json`).
- Keys are paths relative to `Settings.wallpaperDir`, with forward slashes, e.g. `dore/5.jpg`. The index helper re-links any orphan curated record whose `sha` matches a new key, and reports the move.

## 2. Schemas

### 2.1 `rice/themes/<id>.json`

Role names mirror `config/Theme.qml`:
- semantic roles: `background`, `surface0..3`, `text`, `textBright`, `textReverse`, `subtext`, `muted`, `accent`, `success`, `warning`, `error`, `info`
- raw ramp: `bg0..bg4`, `fg0`, `fg1`, `grey`, `greyDim`, and 7 hues × `{base, Dim, Bright}`. The 108 raw references in the modules (00 §2) still use these, so every theme must define them all.
- new roles planned by the token pass (00 §3): `cat*` and `chart0..4`

Roles hold **references** to palette keys (`"accent": "yellow"`) or a literal hex, so most themes only override 1 to 3 roles.

```json
{
  "schema": 1,
  "id": "gruvbox-material-dark",
  "name": "Gruvbox Material",
  "variant": "dark",
  "shape": "square",
  "font": "departure-mono",
  "palette": {
    "bg0": "#1d2021", "bg1": "#282828", "bg2": "#32302f", "bg3": "#45403d", "bg4": "#5a524c",
    "fg0": "#d4be98", "fg1": "#ddc7a1", "grey": "#a89984", "greyDim": "#7c6f64",
    "red":    ["#ea6962", "#a94b47", "#f28985"],
    "orange": ["#e78a4e", "#a55f35", "#f0a670"],
    "yellow": ["#d8a657", "#9c763e", "#e8bf7c"],
    "green":  ["#a9b665", "#788348", "#c2cf85"],
    "aqua":   ["#89b482", "#5e815a", "#a7c9a1"],
    "blue":   ["#7daea3", "#567c73", "#9ec5bb"],
    "purple": ["#d3869b", "#9d6b82", "#e8a5b8"]
  },
  "roles": {
    "background": "bg1", "surface0": "bg0", "surface1": "bg2", "surface2": "bg3", "surface3": "bg4",
    "text": "fg0", "textBright": "fg1", "textReverse": "bg0", "subtext": "grey", "muted": "greyDim",
    "accent": "yellow", "success": "green", "warning": "orange", "error": "red", "info": "blue",
    "catMedia": "purple", "catSystem": "blue", "catNet": "aqua", "catDev": "green",
    "catCalendar": "aqua", "catWeather": "yellow",
    "chart": ["bg2", "greenDim", "green", "greenBright", "yellow"]
  },
  "terminal": {
    "background": "bg1", "foreground": "fg0", "cursor": "fg0", "selectionBg": "bg3", "selectionFg": "fg0",
    "ansi": ["#282828", "#ea6962", "#a9b665", "#d8a657", "#7daea3", "#d3869b", "#89b482", "#d4be98",
             "#7c6f64", "#ea6962", "#a9b665", "#d8a657", "#7daea3", "#d3869b", "#89b482", "#ddc7a1"]
  },
  "apps": {
    "nvim":  { "plugin": "sainnhe/gruvbox-material", "colorscheme": "gruvbox-material", "background": "dark",
               "globals": { "gruvbox_material_background": "medium" } },
    "btop":  "gruvbox_material_dark",
    "gtk":   { "colorScheme": "prefer-dark", "iconTheme": "Gruvbox-Plus-Dark" },
    "lutgen": { "palette": "gruvbox-material-dark-medium" }
  },
  "hypr": { "activeBorder": "fg0", "inactiveBorder": "bg3", "inactiveAlpha": "aa" }
}
```

Rules:
- `shape` is the only geometry input. `Theme.qml` derives `radius` (0 or 8), `radiusSmall` (0/4), `radiusLarge` (0/12), `accentStyle` (`"underline"` or `"pill"`), plus Hyprland `rounding` and dunst `corner_radius`. Accent style is never stored, so it cannot disagree with the shape.
- `font` refers to an id in `rice/themes/fonts.json` (§3.2). The user's override lives in prefs: `{ theme, shapeOverride?, fontOverride? }` in `~/.local/state/rice/prefs.json` (01 P1).
- Loading: `rice/themes/` holds read-only presets, so use `FileView.text()` + `JSON.parse`, not a `JsonAdapter`, which needs declared properties and is meant for typed, writable state. List the presets with `Qt.labs.folderlistmodel` `FolderListModel { nameFilters: ["*.json"] }`. Resolve roles once, in a JS function `resolve(theme) → {role: color}`. `Theme.qml` binds to `active` and, while a preview runs, to `previewId`.
- Status roles (`success`, `warning`, `error`) must stay green-ish, amber and red-ish in every theme, mono themes included (impasto rule).
- Validation: `scripts/theme-check.py` checks that all roles resolve, all 16 ANSI entries exist, that `text`/`background` has a WCAG contrast of at least 4.5, and that the font id exists. Run it by hand or from a git pre-commit hook. Effort S.

### 2.2 Curated record (`rice/data/wallpapers.json`)

```json
{
  "schema": 1,
  "root": "~/Pictures/Wallpapers",
  "items": {
    "dore/5.jpg": {
      "sha": "9f2c41d0a7e3",
      "themes": ["gruvbox-material-dark", "kanagawa-dragon"],
      "seasons": ["any"],
      "tags": ["engraving", "dore", "night"],
      "fav": false,
      "placement": "crop",
      "lockTheme": null,
      "auto": { "themes": true, "seasons": true },
      "reviewed": false,
      "added": "2026-10-05"
    },
    "Christinas_World-Andrew_Wyeth.jpg": {
      "sha": "51be0c66d9a2",
      "themes": ["gruvbox-material-light"],
      "seasons": ["autumn", "summer"],
      "tags": ["painting", "field"],
      "fav": true, "placement": "crop", "lockTheme": null,
      "auto": { "themes": false, "seasons": false }, "reviewed": true, "added": "2026-10-05"
    }
  }
}
```

- The vocabulary is closed. `themes` must be ids from the registry. `seasons` must be from `spring | summer | autumn | winter | any`. `tags` are free text but lower-case and offered by autocomplete from existing tags.
- `placement` is one of `crop | fit | span`.
- `lockTheme` makes this wallpaper force its theme when `themePolicy = follow` (03 P5).
- `auto.*` stays true until the user touches that field, and the bootstrap or re-suggest only ever rewrites fields where it is still `true`. `reviewed` drives a "Needs review (N)" chip in the picker.
- Links are stored in one direction only (wallpaper → themes). A theme's "known wallpapers" list is derived from these records at load time.

### 2.3 Computed record (`index.json`)

```json
{
  "schema": 1, "built": "2026-10-05T16:10:00", "themesHash": "c0ffee12",
  "items": {
    "dore/5.jpg": {
      "sha": "9f2c41d0a7e3", "mtime": 1745012345, "bytes": 1394688, "format": "JPEG",
      "w": 2721, "h": 2153, "aspect": 1.264, "spanOk": false,
      "lab": { "L": 27.1, "C": 2.4, "lStd": 18.3 },
      "hue": 99, "sat": 0.03, "richness": 1,
      "swatch": [ { "hex": "#1b1a18", "w": 0.41 }, { "hex": "#3a3833", "w": 0.22 },
                  { "hex": "#5e5b54", "w": 0.15 }, { "hex": "#8a867c", "w": 0.11 },
                  { "hex": "#b9b4a8", "w": 0.07 }, { "hex": "#e0dbcf", "w": 0.04 } ],
      "dist": { "gruvbox-material-dark": 2.5, "kanagawa-dragon": 4.0, "everforest-dark": 8.4,
                "gruvbox-material-light": 14.9, "nord": 15.2, "crt-amber": 9.8 },
      "season": { "guess": ["any"], "green": 0.0, "warm": 0.02, "snow": 0.01 },
      "thumbs": { "s": "thumbs/9f2c41d0a7e3-160.webp", "m": "thumbs/9f2c41d0a7e3-640.webp" },
      "derived": { "nord": "derived/nord/9f2c41d0a7e3.jpg" }
    }
  }
}
```

- `sha` is the first 12 hex digits of the SHA-1 of the file contents. The whole library hashes in well under a second, so there is no need to hash only part of each file.
- Thumbs and derived files are keyed by `sha`, so renaming an image costs nothing.
- `themesHash` is a hash of all theme palettes. When it changes (a theme was edited or added), the helper recomputes only `dist`, from the stored swatch. It does not decode any image.

## 3. Default themes and fonts

### 3.1 Theme list (10)

All dark unless noted. The hex values are the upstream palettes. Background ramp and fg are the bg0..bg4 / fg0..fg1 slots, and the hues are the base slots. Dim and Bright variants are taken from upstream where it has them, otherwise derived as Lab L ±12.

| id | shape | font | bg0..bg4 | fg0 / grey | red · orange · yellow · green · aqua · blue · purple | accent | lutgen |
|---|---|---|---|---|---|---|---|
| `gruvbox-material-dark` (**default**) | square | departure-mono | 1d2021 282828 32302f 45403d 5a524c | d4be98 / a89984 | ea6962 e78a4e d8a657 a9b665 89b482 7daea3 d3869b | yellow | gruvbox-material-dark-medium |
| `gruvbox-material-light` (light) | square | departure-mono | fbf1c7 f4e8be f2e5bc eee0b7 e5d5ad | 654735 / 928374 | c14a4a c35e0a b47109 6c782e 4c7a5d 45707a 945e80 | orange | gruvbox-material-light-medium |
| `kanagawa-dragon` | square | 3270 | 0d0c0c 181616 282727 393836 625e5a | c5c9c5 / a6a69c | c4746e b6927b c4b28a 8a9a7b 8ea4a2 8ba4b0 a292a3 | yellow | custom colours (`lutgen … -- <hex…>`) |
| `everforest-dark` | round | departure-mono | 232a2e 2d353b 343f44 3d484d 475258 | d3c6aa / 859289 | e67e80 e69875 dbbc7f a7c080 83c092 7fbbb3 d699b6 | green | everforest-dark-medium |
| `nord` | round | terminess | 242933 2e3440 3b4252 434c5e 4c566a | d8dee9 / a3abb9 | bf616a d08770 ebcb8b a3be8c 8fbcbb 81a1c1 b48ead | blue (88c0d0) | nord |
| `rose-pine` | round | departure-mono | 191724 1f1d2e 26233a 403d52 524f67 | e0def4 / 908caa | eb6f92 ebbcba f6c177 31748f 9ccfd8 c4a7e7 ebbcba | purple (iris) | rose-pine |
| `tokyonight-night` | round | gohu | 16161e 1a1b26 292e42 3b4261 414868 | c0caf5 / 737aa2 | f7768e ff9e64 e0af68 9ece6a 73daca 7aa2f7 bb9af7 | blue | tokyo-night-dark |
| `catppuccin-mocha` | round | proggy | 11111b 1e1e2e 313244 45475a 585b70 | cdd6f4 / a6adc8 | f38ba8 fab387 f9e2af a6e3a1 94e2d5 89b4fa cba6f7 | purple (mauve) | catppuccin-mocha |
| `solarized-dark` | square | profont | 00212b 002b36 073642 0a4050 586e75 | 839496 / 657b83 | dc322f cb4b16 b58900 859900 2aa198 268bd2 6c71c4 | yellow | solarized-dark |
| `crt-amber` (mono) | square | bigblue-437 | 0a0700 140e02 1f1605 2e2108 4a350d | ffb000 / b37b00 | **ff5f3a** ff8c1a ffb000 d9a400 e6a817 cc8f00 ff9a5a | yellow | custom colours |

Notes:
- `crt-amber` sets all hues to amber shades except `error`, which stays a distinct red-orange `#ff5f3a`, and `success`, which stays a desaturated yellow-green. Its ANSI table uses amber shades for colours 1–6 except red. A `crt-green` sibling (P1 phosphor `#33ff66` on `#020a03`) costs one file to add.
- An `etching` light theme (sepia paper `#e9dfc8`, ink `#2a2118`, rust accent `#9c4a2a`) is the obvious extra for this particular library. All 12 Doré engravings are near-greyscale (mean Lab chroma 2–10; see §5).
- Shape defaults split the list roughly half square, half round, so both accent styles get used. Square goes to the "retro" set (gruvbox, kanagawa, solarized, crt); round goes to the soft pastel themes.

### 3.2 Font registry `rice/themes/fonts.json`

The `extra/` packages are from `pacman -Ss nerd-fonts`; AUR names are from the AUR RPC (2026-10-05). The family strings are the usual Nerd Font v3 names. **Verify each with `fc-list : family` after installing**, because Qt silently substitutes a missing family (01 P8).

| id | family (fontconfig) | package | pixel grid / crisp sizes | notes |
|---|---|---|---|---|
| `departure-mono` | DepartureMono Nerd Font Mono | AUR `otf-departure-mono-nerd` (today a manual copy in `~/.local/share/fonts`) | 11 px; crisp at 11/22/33/44/66 | current font |
| `bigblue-437` | BigBlueTerm437 Nerd Font Mono | `extra/ttf-bigblueterminal-nerd` | DOS 8×8 cell; test multiples of 8 | IBM PC look |
| `3270` | 3270 Nerd Font Mono | `extra/ttf-3270-nerd` | outline; any size | mainframe terminal |
| `terminess` | Terminess Nerd Font Mono | `extra/ttf-terminus-nerd` | Terminus bitmap heritage; 12/14/16/20 | very legible |
| `gohu` | GohuFont 14 Nerd Font Mono | `extra/ttf-gohu-nerd` | 11 and 14 px | tiny and crisp |
| `proggy` | ProggyClean Nerd Font Mono | `extra/ttf-proggyclean-nerd` | 16 px nominal | |
| `profont` | ProFont IIx Nerd Font Mono | `extra/ttf-profont-nerd` | 12/15 | classic Mac |
| `heavydata` | HeavyData Nerd Font Mono | `extra/ttf-heavydata-nerd` | pixel-ish display | headings only? |
| `sharetech` | ShureTechMono Nerd Font Mono | `extra/ttf-sharetech-mono-nerd` | outline | sci-fi HUD |
| `monocraft` | Monocraft Nerd Font | AUR `ttf-monocraft-nerd` | 9 px grid | Minecraft; has ligatures |
| `cozette` | CozetteVector | AUR `cozette-ttf` (+ `nerd-fonts-cozette-ttf`, stale 1.28) | 13 px | |

Each entry carries `{ id, family, package, source: "extra"|"aur"|"manual", grid, sizes: {xs, sm, md, lg, xl, huge, icon, iconLg}, terminalSize, dunstSize }`. Sizes are **per font**, not scaled from a base (01 risk, 05 P5). Filling in the `sizes` for each font is a one-off calibration job during the token pass. At runtime, `services/Fonts.qml` hides any entry whose family is not in `Qt.fontFamilies()` and shows it greyed out with an install hint instead.

## 4. Seasons and ranking

York, Maine is at 43.1° N, so northern hemisphere.

| Mode | Winter | Spring | Summer | Autumn |
|---|---|---|---|---|
| `meteorological` (default) | Dec–Feb | Mar–May | Jun–Aug | Sep–Nov |
| `astronomical` | Dec 21 → Mar 19 | Mar 20 → Jun 20 | Jun 21 → Sep 21 | Sep 22 → Dec 20 |
| `maine` preset | Dec 1 → Mar 31 (snow cover) | Apr–May (mud season) | Jun–Aug | Sep–Nov (foliage peaks early to mid Oct) |

- Settings fields: `Settings.season = { mode: "meteorological", hemisphere: "north", blendDays: 14 }`. The `maine` preset is just a month table (`{12:"winter",1:"winter",…,3:"winter",4:"spring"}`), so custom tables cost nothing. The astronomical boundaries use fixed dates, which can be off by a day; that does not matter here.
- Blend: within `blendDays` of a boundary, the adjacent season counts as half a match. On 2026-10-05 the season is `autumn` with no blend; on Nov 20 it is `autumn` with winter half-matching.
- `any` means "fits all year". It matches every season, but one tier below an exact match.

**Ranking.** Sort lexicographically by this tuple, ascending, in JS inside `services/Wallpaper.qml`:

```js
// t = active (or previewed) theme id, s = current season, a = adjacent season if in blend window
function rankKey(k) {
    const m = meta[k] || {}, x = index[k] || {}, u = usage[k] || {};
    const themeTier  = (m.themes||[]).includes(t) ? (m.auto?.themes ? 1 : 0)  // 0 curated, 1 auto
                     : (x.dist?.[t] ?? 99) <= fitThreshold ? 2 : 3;
    const ss = m.seasons || x.season?.guess || ["any"];
    const seasonTier = ss.includes(s) ? 0 : (ss.includes("any") || ss.includes(a)) ? 1 : 2;
    const pal  = Math.round((x.dist?.[t] ?? 99) / 2);       // 2-dE bins, so ties fall through
    const fav  = m.fav ? 0 : 1;
    const rec  = u.last || 0;                              // least recently applied first
    return [themeTier, seasonTier, pal, fav, rec];
}
```

- The sort order is theme match > season match > palette distance > favourite > recency, as the brief asked. Curated theme tags beat auto tags, and auto tags beat "close by distance" (`fitThreshold`, default 8 dE).
- The picker dims everything with `themeTier ≥ 2 || seasonTier == 2` but never hides it.
- The rule schedule's "random" draws from the best non-empty `(themeTier, seasonTier)` bucket, excluding the last N applied (03 P7). If the best bucket holds fewer than 3 items, it merges in the next bucket so rotation does not get stuck on one image.

## 5. Auto-suggest pipeline (palette distance)

Prototype run read-only over the whole library (`scratchpad/wt/proto.py`, Pillow + numpy only):

1. Decode with `Image.draft("RGB", (160,160))`. For JPEG this decodes at 1/8 scale, so a 30 MP file costs about 20 ms. PNG and WebP have no draft mode and cost 180–190 ms. Then `thumbnail((96,96))`.
2. sRGB → Lab with `ImageCms` (built in, no new package). **Gotcha:** Pillow's `LAB` mode stores a\*/b\* as signed bytes, so read them with `.view(np.int8)`. The first prototype run got chroma values of about 170 because of this.
3. k-means with k = 6 in Lab, 12 iterations, plain numpy (about 1 ms). The result is cluster centres plus pixel-share weights, which become the `swatch`.
4. For each theme, the palette set is bg0..bg4, fg0, fg1, grey, greyDim and the 7 hues (16 colours). Distance is the weighted mean, over the clusters, of the smallest CIE76 ΔE from each cluster to the palette:
   `dist = Σ wᵢ · minⱼ ‖Cᵢ − Pⱼ‖`. Add a light/dark penalty, `+ 0.2·max(0, |L̄_img − L_bg| − 35)`, so a bright image does not land on a dark theme only because its accents match. CIEDE2000 is about 30 lines of numpy if CIE76 ranks badly. It did not in the test.
5. Cost: **20–190 ms per image, 1.13 s for all 21** on the 5800X, single-threaded. Recomputing `dist` alone from stored swatches is microseconds. That fits comfortably inside the "run when the picker opens" model from 03 P1, and only new or changed files are decoded.

Measured top-3 (lower is closer; using an earlier 10-theme draft):

| Image | L̄ / C̄ | Best | 2nd | 3rd |
|---|---|---|---|---|
| Doré ×12 | 26–48 / 2–10 | gruvbox-material-dark 2.5–5.4 (best on all 12) | kanagawa-dragon 3.4–7.0 | everforest-dark ~8–11 |
| John_Martin1 | 9 / 4.9 | kanagawa-dragon 4.6 | crt-amber 6.5 | gruvbox-material-dark 9.0 |
| Caravaggio Taking of Christ | 12 / 15.9 | crt-amber 12.1 | kanagawa-dragon 13.3 | catppuccin-mocha 15.6 |
| School of Athens | 55 / 18.5 | gruvbox-material-light 7.7 | gruvbox-material-dark 11.2 | kanagawa-dragon 12.8 |
| Christina's World | 42 / 19.7 | gruvbox-material-light 12.2 | kanagawa-dragon 16.8 | gruvbox-material-dark 17.9 |
| Sea of Acheron | 33 / 7.0 | everforest-dark 7.1 | kanagawa-dragon 7.4 | gruvbox-material-dark 9.5 |
| Fallen Angel (Cabanel) | 51 / 12.8 | kanagawa-dragon 9.7 | nord 13.1 | catppuccin-mocha 13.1 |

**Finding:** the library is warm, dark and low-chroma. Nord, tokyonight, catppuccin, rose-pine and solarized have **no natural fits**: their best ΔE is above 13. Each default theme needs its "known wallpapers", so there are two fixes, and both are cheap:
- (a) ship a few CC0/public-domain images per cool theme, e.g. Hiroshige or Hasui woodblocks for nord and tokyonight, Monet nocturnes for rose-pine;
- (b) generate theme-matched variants with lutgen.

**lutgen variants (optional, derived, never overwriting).**
- Command: `lutgen apply -p <apps.lutgen.palette> -c <src> -o ~/.cache/quickshell/rice/wallpapers/derived/<theme>/<sha>.jpg`. For themes without a built-in palette (kanagawa-dragon, crt-amber), pass `-- <16 hex>` instead.
- Measured on output written to the scratchpad: **0.26 s** for `dore/5.jpg` and **0.95 s** for the 30 MP `John_Martin1.jpg`, including LUT generation; `-c` caches the LUT for repeat runs.
- Each variant is listed under the parent's `index.derived[theme]` and shown in the picker as a stacked badge on the original (the "nord ✦" chip). It is not a separate library entry.
- Variants live in the cache, so deleting them is safe. Optionally, a "Keep" action copies one into `~/Pictures/Wallpapers/derived/<theme>/` as a new library file with its own curated record (`tags: ["lutgen", "of:dore/5.jpg"]`).
- `-P` (preserve luminance) usually looks better on engravings. Expose it as a per-theme `apps.lutgen.preserve`.

## 6. Theme apply pipeline (outside Quickshell)

- **Mechanism:** one-shot `scripts/theme-apply.py --theme <id> [--only a,b] [--dry-run]`. It runs on **commit** only, never during preview.
  1. Resolve the theme JSON plus prefs overrides into a flat var dict (`bg0`, `accent`, `ansi0..15`, `radius`, `font`, `fontSize`…).
  2. Render `rice/templates/*.tmpl` with `string.Template` (`${accent}`; no Jinja dependency).
  3. Write each result atomically (temp + rename) into **`~/.local/state/rice/theme/`**.
  4. Run that target's reload command.
- **Stow rule:** stowed configs only ever gain one static include line pointing at the state dir. The generated files never live inside a stow tree; `~/.config/nvim` in particular is folded into the repo.
- The output is JSON lines of `{target, ok, msg}` so the settings page can show per-target ticks.

| Target | Generated file | One-time change in the stowed config | Live reload | Notes |
|---|---|---|---|---|
| Quickshell | none (reads theme JSON) | n/a | bindings + `Behavior on color` | preview = `previewId` |
| Hyprland | `hypr.conf` (`general:col.*`, `decoration:rounding`) | add `source = ~/.local/state/rice/theme/hypr.conf` at the end of `external/look_and_feel.conf` | `hyprctl --batch "keyword general:col.active_border rgba(…); keyword general:col.inactive_border …; keyword decoration:rounding 0"` | A missing source file shows Hyprland's red error bar, so the bootstrap must write it first. |
| ghostty | `ghostty` theme file (palette 0–15, bg, fg, cursor, selection) + `font-family` | replace `theme = gruvbox-material` with `theme = rice`, and symlink `~/.config/ghostty/themes/rice` (an unmanaged real dir) → state file | `pkill -USR2 -x ghostty` (config reload on SIGUSR2, Ghostty ≥ 1.2; we have 1.3.1) | `font-family` lives in the main config, so put the font line in a separate `config-file = ?…/ghostty-font.conf` |
| tmux | `tmux.conf` with `*-style`, `pane-border-*`, `message-style`, `status-left`, window formats | drop the `hasundue/tmux-gruvbox-material` plugin; add `source-file -q ~/.local/state/rice/theme/tmux.conf` **before** the resurrect/continuum plugins | `tmux source-file ~/.local/state/rice/theme/tmux.conf` | **Never set `status-right` in the template.** Continuum hooks its autosave into `status-right`, which is the comment in `.tmux.conf` line 26. Keep `status-right` in the stowed file and use colour-only styles. |
| nvim | `nvim.lua` returning `{plugin, colorscheme, background, globals}` | lazy specs for every theme plugin with `lazy = true`; one loader does `pcall(dofile, state.."/nvim.lua")`, sets globals and `:colorscheme`; `vim.uv.new_fs_event` watches the file | the fs watcher re-applies it in every running nvim, with no sockets or `--remote-send` key injection | Fixes today's drift (`ellisonleao/gruvbox` → `sainnhe/gruvbox-material`). |
| dunst (until the in-shell notif server, 01 P4) | `dunst.conf` (urgency colours, `frame_color`, `font`, `corner_radius`) | symlink `~/.config/dunst/dunstrc.d/50-rice.conf` → state file (dunst 1.13 reads drop-ins); remove those keys from `dunstrc` | `dunstctl reload` | Once the in-shell server replaces dunst, this row goes away. |
| btop | `rice.theme` | `color_theme = "rice"`; symlink `~/.config/btop/themes/rice.theme` → state | next launch | btop rewrites `btop.conf` (a symlink into the repo) on exit, as it already does today. |
| GTK | none | n/a | `gsettings set org.gnome.desktop.interface color-scheme prefer-dark|prefer-light`; icon theme from `apps.gtk` | only light vs dark matters |
| Firefox textfox | `rice-theme.css` (`--tf-bg`, `--tf-accent`, `--tf-border`, `--tf-rounding`, font) | `install.sh` appends `@import` of a profile-local symlink to the state file | Firefox restart | Optional; mark it "applies next launch". |
| SDDM | n/a | n/a | **manual** button "Use as login background", which hands over the `sddm/make-background.sh <img> && sudo sddm/install.sh` one-liner | Needs root (`/usr/share/sddm/themes`). Never automatic. |
| spotify_player / bat / fzf | optional templates later | | | |

- **Order:** Quickshell first (instant), then Hyprland, then terminals. The slow or optional targets run last, and a failing target does not stop the others.
- **Wiring:** `Theme.commit()` → `Process { command: ["python3", scripts + "/theme-apply.py", "--theme", id] }`. It is one-shot, so no tether is needed.

## 7. Bootstrap (`scripts/wall-bootstrap.py`, one-off, idempotent)

1. Run `wall-index.py` (index, swatches, `dist`, thumbs).
2. For each key **without** a curated record, or with `auto.*` still true:
   - `themes`: every theme with `dist ≤ min(best + 2, best × 1.25)` and `dist ≤ 12`, at most 3.
   - `seasons`: from the heuristics below.
   - Set `reviewed: false`, `auto: {themes: true, seasons: true}`, `placement: spanOk ? "span" : "crop"`, `added: today`.
3. Season heuristics, coarse on purpose, all from the 96 px Lab sample:
   - filename keywords first (`snow|winter|frost|ice` → winter, `harvest|autumn|fall` → autumn, `spring|blossom` → spring, `summer|beach|sea` → summer);
   - else C̄ < 10 → `any` (all 12 Doré engravings land here);
   - else `snow` (share with L > 80 and C < 8) > 0.25 → winter;
   - `green` (h 95–160°, C > 15) > 0.25 → summer, plus spring if L̄ > 55;
   - `warm` (h 20–80°, C > 15) > 0.35 → autumn;
   - otherwise `any`.
4. Flags:
   - `--dry-run` prints the proposed table; `--write` backs up `wallpapers.json` to `wallpapers.json.bak` and writes atomically;
   - `--resuggest` reruns only the fields still marked `auto`;
   - existing user fields are never touched.
5. Review in the picker: the "Needs review" chip, then `T` cycles theme suggestions and `S` toggles seasons on the focused item. Any edit flips `auto.*` to false and sets `reviewed`. 21 images take about five minutes.

Expected seed for today's library, using the §5 thresholds:
- Doré ×12 → `[gruvbox-material-dark, kanagawa-dragon]`, `any`.
- John Martin → `[kanagawa-dragon, crt-amber]`.
- School of Athens → `[gruvbox-material-light]`.
- Caravaggio → `[crt-amber, kanagawa-dragon]`.
- Christina's World / Breezing Up → summer or autumn by the green/warm shares.
- The five cool themes start with zero links. The bootstrap should print that, and suggest adding images or generating lutgen variants.

## 8. Effort and risks

| Piece | Effort | Risk / notes |
|---|---|---|
| Theme JSON schema + 10 preset files + `theme-check.py` | M | Getting the palette values right; deriving the Dim/Bright steps for themes that lack them |
| `Theme.qml` loading the registry (FolderListModel + FileView + resolve) and `previewId` | M | Depends on the token pass (00 §3) replacing the 108 raw references first |
| `fonts.json` + `services/Fonts.qml` + per-font size calibration | S (+S per font calibrated) | Pixel fonts blur off-grid; sizes are subjective and need on-screen review |
| `wall-index.py` with Lab k-means, `dist`, season stats, `themesHash` | S–M | Pillow LAB signed-byte gotcha (§5); PNG/WebP decode is 10× slower than JPEG (fine) |
| Curated `wallpapers.json` + `Wallpaper.qml` load/save + rank function | S | Quickshell reload-watcher behaviour on JSON writes (verify); key re-linking by `sha` |
| Season settings + blend | S | none |
| `wall-bootstrap.py` | S | Seasons for paintings are guesswork, so everything is flagged `auto` for review |
| lutgen variants + picker badge | S | Disk: about 1–2 MB per variant per theme; it is cache, so a size cap with LRU pruning |
| `theme-apply.py` + templates: hypr, ghostty, tmux, nvim, dunst | M | tmux `status-right`/continuum interaction; ghostty font change may only affect new surfaces; nvim plugin downloads on first use of each theme (lazy) |
| btop / gtk / textfox templates | S | textfox and btop need a restart |
| SDDM | S (manual button only) | sudo; never automated |
| Sourcing more wallpapers for the cool themes | S (curation) | licensing: stick to public domain / CC0 |

**Order:**
1. Theme schema, registry and `Theme.qml`, after the token pass.
2. `theme-apply.py` for hypr, ghostty and tmux.
3. Index helper, curated JSON and bootstrap.
4. Ranking in the picker.
5. nvim, dunst and the rest.
6. lutgen variants.

## 9. Don't

- Don't write tags into the images (exif/XMP). It mutates 60 MB of originals and needs a package we don't have.
- Don't let `theme-apply.py` edit stowed files in place, `sed`-style. Use includes only.
- Don't store `accentStyle` or `radius` in theme files. Derive them from `shape`.
- Don't hard-filter by season or theme. With 21 images, a filter shows an empty grid most of the year.
- Don't run lutgen or `theme-apply` on preview. Preview stays palette-only and in-shell.
