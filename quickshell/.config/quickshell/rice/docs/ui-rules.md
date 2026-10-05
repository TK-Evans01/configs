# UI rules

House rules for the rice. When adding or changing UI, follow these. Tokens live in `config/Theme.qml`; building blocks in `components/` (list in `architecture.md`).

## Colour

1. **Semantic roles first.** Surfaces `surface0..3`, text `text / textBright / subtext / muted`, status `success / warning / error / pending / info`, emphasis `accent`.
2. **Domain colour for headers and charts.** A card header, page glyph or chart takes the colour of what it is about: `catMedia`, `catSystem`, `catTime`, `catWeather`, `catDev`, `catNotify`. Same domain = same colour everywhere (bar, dashboard, Quick Settings).
3. **Data series** use `Theme.series[i]` in a fixed order: cpu, gpu, mem, disk.
4. **Raw hues** (`Theme.red`, `Theme.yellow`, …) only when the hue *is* the meaning: sun, rain, warmth, weekend, GitHub's PR/issue/review tags, stars. Every theme defines them.
5. **"On" colour.** Switches and chips use `accent`. Quick Settings tiles light in their domain colour (VPN `catNet`, Bluetooth `catSystem`, night light `orange`, DND `catNotify`, caffeine `accent`, sound `catMedia`) so each is recognisable at a glance; never an arbitrary hue.
6. Destructive actions (remove, wipe, power off) use `error` for their glyph.

## Type

One scale, nothing in between: `fontXs` captions/hints · `fontSm` meta (ages, counts, sublabels) · `fontBase` body · `fontTitle` row/tile/bar item titles · `fontMd` glyphs, emphasis · `fontLg` page glyphs, big values · `fontXl` hero numbers · `fontHuge` clock. No `+1`/`-2` offsets. Multiplying a token for a *layout* width is fine.

Headings: `PageHeader` (page), `CardHeader` (card), `SectionLabel` (group inside a list). Nothing else styles its own heading.

## Shape and accent

`Theme.shape` is `square` (retro default) or `round`. Never hard-code a radius: surfaces use `radius`, controls/rows/inputs `radiusSmall`, tracks and handles `radiusPill`. Circles that are always circles (avatars) are the only literal radii.

**Edges.** The bar and everything attached to it (popups, sidebar, session drawer, OSD) are one surface with one outline: `Theme.outline` (the theme's light text colour, overridable), `Theme.outlineWidth` px, continuing the bar's bottom edge. `PanelShape` traces each attached panel as a single path (fill + outline share it): in round shape with concave joins (`joinRadius`) where it meets the bar and the screen edge and rounded free corners; in square shape flush, sharp corners. Don't draw panel borders by hand. Inner cards keep the quiet `surface2` hairline. Hyprland window rounding and borders follow the theme too (`ThemeSync`).

The accent has four jobs, each with one look:

| Job | Look |
|---|---|
| **Selected / current** (tab, workspace, open bar button, list row) | `AccentIndicator`: underline or side bar in square, soft pill in round |
| **On** (tile, switch, chip, today) | filled `accent`, `textReverse` on top |
| **Focus / attention** (input focus, active tile border) | `accent` border |
| **Title** (card/section headers) | domain colour or `accent` text |

## States

- Hover = `surface1`. Open/selected = `surface1` + indicator. Hover is never louder than open.
- Buttons with a resting fill (`IconButton`) hover to `surface2`.
- Disabled = opacity 0.4, no pointer cursor.

## Interaction

- Left click = primary. **Right click = secondary/context** (menu, or the next most useful action). Middle click = a quick toggle (mute, play/pause). Wheel = adjust (volume, workspace).
- Bar indicators show **state** (playing, muted); controls show the **action** they perform (▶ on a paused player's play button).
- Escape closes the popup; inside a sub-page it goes back first. Every popup has a SUPER bind or IPC.
- Power actions arm on the first click and fire on the second (`PowerRow`); lock is instant.

## Copy and layout

- No subtitle that repeats the title; no text restating a switch's state.
- Loading uses `Spinner` (it reserves its slot). Short status words, no trailing "…".
- Lists use `ListRow` (`rowHeight`, or `rowHeightCompact` for menus). Gutters: `Theme.pad` between cards, `Theme.spacing` inside them.
- Ages use `Fmt.age` / `Fmt.since`.
