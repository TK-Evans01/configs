# Inspo round 2: synthesis

Date: 2026-10-05. Inputs: nine agent reports in this folder. This page consolidates them into decisions and candidate epics for discussion. Nothing here is scheduled yet; tickets come after we agree scope.

| # | Report | Verdict in one line |
|---|---|---|
| 00 | [self-audit](00-self-audit.md) | Solid layering and process hygiene; weak on visual consistency, keyboard reach, and memory (≈494 MB). Nothing for goals 2–6 exists yet. |
| 01 | [impasto](01-impasto.md) | Best source for the **settings store**, palette registry, wallpaper service basics, notification server, OSD arbitration. GPL: ideas only. |
| 02 | [mochi-desktop](02-mochi-desktop.md) | A desktop pet, not a rice. Useful: Pomodoro focus model, logind session watcher, toast rate-limiting. |
| 03 | [skwd-wall](03-skwd-wall.md) | Best source for the **wallpaper picker** and theme-per-wallpaper preview. Don't adopt it as a backend. Found the lock-screen decode bug. |
| 04 | [caelestia-kde](04-caelestia-kde.md) | Best source for **edge drawers + tabbed right sidebar** and a dictionary-driven settings app. KDE layer not transferable. |
| 05 | [StatIndet/quickshell](05-statindet-quickshell.md) | Best QML mechanics: edge-wipe panel, present-after-ready loading, stretchy tab underline, **action catalogue** allowlist, font roles, validated store. |
| 06 | [voice assistant](06-voice-assistant.md) | Feasible fully local on the RX 9070 via Vulkan (whisper.cpp + llama.cpp, Qwen3.5-9B). Wake word "hey computer" needs training. |
| 07 | [focus mode](07-focus-mode.md) | Site blocking via a root-owned DNS sinkhole helper (resolved `static.d`) + Hyprland `openwindow` app hiding; profiles; hard/soft. |
| 08 | [wallpaper + theme data](08-wallpaper-theme-data.md) | Concrete schemas, 10 default themes, 11 retro fonts, season ranking, apply pipeline via include files. Prototyped palette matching (1.1 s for the library). |

---

## 1. Where the reports agree

These came up independently in three or more reports, so treat them as settled unless you object.

1. **Foundation before features.** Every goal (themes, settings, sidebar, focus, voice) needs the same three things first: design tokens, a writable settings store, and shared components. The self-audit counted 108 raw colour references, 65 ad-hoc font sizes, 5 accent idioms, and `Theme.radius` used in only 2 of ~73 rectangles. Round/square switching is impossible until that is fixed.
2. **Writable store = `FileView` + `JsonAdapter`** in `~/.local/state/rice/`, with a write guard until loaded, coalesced saves, validation/migration on load, and the look kept in a different file from volatile toggles (DND, units) so flipping DND never rewrites the theme.
3. **Theme = palette + shape + font.** `radius` and `accentStyle` are *derived* from shape, never stored. Status colours (good/warn/bad) stay fixed across palettes. Fonts get per-font size scales (DepartureMono's 11 px grid).
4. **Preview is palette-only and in-shell; commit pushes outward.** Hover/focus previews cross-fade colours; Enter commits and then runs the external apply (ghostty, tmux, Hyprland, nvim, dunst). Never run lutgen or app reloads on preview.
5. **External apps are themed through include files** generated into `~/.local/state/rice/theme/`, one include line per stowed config. Never `sed` stowed files.
6. **Replace dunst with an in-shell `NotificationServer`**, then group by *source* (mail, Discord, system, Claude Code, …) through an app-name → source map, not by raw app name.
7. **Side panels are a reusable edge component** with a single progress value, content loaded only while open, input mask covering just the visible area, and our existing focus-grab rules (grab the panel only).
8. **One action catalogue** (`config/actions.json`) is the allowlist for the launcher `>` mode, the settings search, voice tools, and focus profiles.
9. **Wallpaper metadata in JSON, not in image files.** Curated tags in git, computed data in cache, usage stats in state. Suggest by theme then season; dim non-matches, never hide them.
10. **Heavy helpers are on-demand and tethered** (models, indexers): spawn on use, exit on idle, `Settings.tether`.

## 2. Design decisions to confirm

Where reports offered alternatives, here is my pick. Push back on any.

| Topic | Options seen | My pick | Why |
|---|---|---|---|
| Side panel motion | slide via `offsetScale` (04) vs clipped edge-wipe with still content (05) | **Edge-wipe**, square hairline on the moving edge; in round shape, slide | Wipe reads "retro terminal"; content not moving keeps text crisp. |
| Panel host | one full-screen drawer window per screen (04 P10) vs a window per panel (04 P1, 05 P1) | **Window per edge**, mask only the visible rect | Full-screen layer changes focus behaviour and costs GPU. |
| Settings UI | layer-shell panel vs `FloatingWindow` (01, 04) | **FloatingWindow** "rice settings", singleton, deep links `settings("theme/font")` | Big forms belong in a real window; Hyprland can float/size it by rule. |
| Notification sidebar | right sidebar tabs Notifications · Weather · Feeds (04) | **Yes**, plus a **Mail** group inside Notifications (Mail leaves Quick Settings) | Matches your "orged by emails, discord, system" ask. |
| Weather | dashboard tab vs sidebar tab | **Both, sharing card components**; bar button opens the sidebar tab | Sidebar for glance, dashboard for the 24 h chart. |
| News | RSS in QML `XMLHttpRequest` (04) | **Feeds tab, RSS/Atom, no helper process** | Cheap; feed list in settings. |
| Docker tab | keep vs demote (00) | **Demote** to a System sub-card shown only when containers exist | It's a whole tab for "0 / 0 running". |
| Wallpaper picker | launcher mode (05) vs dedicated hero+strip picker (03) vs settings page (01) | **Dedicated picker** (SUPER+SHIFT+W) plus a settings page that embeds it | Keyboard-first, 2-tier thumbs, frees memory on close. |
| Wallpaper rotation | cron (today) vs in-shell rule schedule (03) | **In-shell Timer + small rule list**, retire cron | Season rules need the shell's theme state. |
| Site blocking | /etc/hosts, Firefox policy, extension, DNS sinkhole (07) | **resolved static.d sinkhole via a root helper + narrow sudoers line**; own Firefox extension later | Works without browser restart; expires even if shell dies. |
| Voice pipeline | many (06) | **PTT first** (SUPER+Space), regex fast-path → Qwen3.5-9B JSON-schema → ask → `claude -p` read-only | Wake word is the risky part; ship value before it. |
| Accent in round shape | pill vs rounded underline | **Pill** behind selected item (your answer) | Already decided. |

## 3. Candidate epics

Sizes: S ≤ a session, M a few sessions, L a multi-session project. "Needs" = hard dependency.

| ID | Epic | Contents (from reports) | Size | Needs |
|---|---|---|---|---|
| **E0** | Quick fixes + hygiene | Lossy setters in Audio/Desktop/Docker (latest-value queue); lock-screen `sourceSize` (~119 MB/monitor); SUPER+M exit confirm; hide junk launcher entries (Alacritty, Xfce, Avahi); dunst `dmenu=tofi`; docs drift; `.qmlls.ini` symlink + `.claude/` out of rice dir; Network ping 5 s → 30 s; dead props; one `fmtAge`; pin Firefox DoH off in user.js | S | – |
| **E1** | Design system | Type scale (xs…huge, per font), categorical colour roles replacing 108 raw refs, radius + `accentStyle` tokens, motion tokens, layout metrics (row height, label column); shared components: `ListRow`, `TextField`, `Chip/Segmented`, `ConfirmButton`, `Stat`, `AccentIndicator`, `RowGroup` rows, `Spinner` (3×3), stretchy `TabBar` underline; `docs/ui-rules.md`; interaction rules (right-click = secondary, state vs action glyphs, Sound tile semantics) | L | – |
| **E2** | Live settings + theme store | `services/Store.qml` (state.json + prefs.json, validation, migration); `Theme.qml` becomes mutable from `themes/*.json`; `previewId`; font registry + `Fonts.qml`; 10 theme presets + `theme-check.py` | M | E1 |
| **E3** | Lighter shell | Load only the current dashboard tab; QS pages as Loaders; share popup windows across screens; stop `docker events` when hidden; present-after-ready loading; re-measure RSS (target < 300 MB) | M | – (easier after E1) |
| **E4** | Panels + notification centre | `EdgePanel` component; in-shell `NotificationServer` (dunst retired, history persisted, critical bypasses DND); source map + grouping; toasts with rate limits; OSD bus + popup arbitration; right sidebar tabs Notifications(+Mail) · Weather · Feeds; session drawer (keyboard j/k); QS declutter (notifications/mail out, labelled tools) | L | E1 |
| **E5** | Settings window | FloatingWindow, page dictionary (nav, fuzzy search, deep links, sub-page stack); pages: Appearance (theme/shape/font with live mock previews), Wallpaper, Bar, Panels, Services, Focus, Voice, Privacy | L | E2 |
| **E6** | Theme apply pipeline | `theme-apply.py` + templates → includes for Hyprland, ghostty, tmux, nvim (switch to gruvbox-material), dunst/notifs, btop, GTK, textfox; SDDM as a manual button (sudo) | M | E2 |
| **E7** | Wallpaper manager | `wall-index.py` (Lab k-means, thumbs 160/640), `data/wallpapers.json` curated tags, `wall-bootstrap.py`, `services/Wallpaper.qml` (awww, current symlink, hotplug), hero+strip picker, season ranking, rule schedule replacing cron, multi-monitor target sheet + span; lutgen variants for themes with no fitting art | L | E2 (picker preview needs `previewId`) |
| **E8** | Action catalogue | `config/actions.json` + `services/Actions.qml` + check script; launcher `>` actions mode and `@` window switcher; idempotent setters (DND/night light/caffeine on/off) | M | – |
| **E9** | Focus mode | `services/Focus.qml` (end time, persisted), profiles, Hyprland `openwindow` hiding to `special:focus`, launcher dimming, root DNS helper + sudoers (one command for you), hard mode (typed phrase + 60 s), DND via notif server, bar countdown + QS tile, end-of-session summary | M–L | E8; E4 for DND integration (dunst pause level works meanwhile) |
| **E10** | Voice assistant | P0 bench; P1 PTT + regex; P2 LLM + project resolver; P3 ask-to-escalate `claude -p`; P4 wake word; P5 focus; P6 Piper TTS. VoiceOsd + bar mic glyph | L | E8; E9 for focus intents |
| **E11** | Extras (optional) | Claude Code usage card; ContributionGrid perf; pixelate wallpaper shader (only if shell draws wallpaper) | S each | – |

### Suggested order

```
E0 ─► E1 ─► E2 ─┬─► E6
       │        ├─► E5 ──┐
       │        └─► E7 ──┤ (settings pages land as each epic finishes)
       ├─► E4 ──────────┤
       └─► E3           │
E8 (any time) ─► E9 ─► E10
```

E0 and E8 are independent and small; they can slot in anywhere. E1 is the big unglamorous one that makes everything after it cheaper.

## 4. Don't copy (merged)

- Island/glass/blob looks, bouncy Material motion, wallpaper-derived palettes as default, C++ plugins needing a custom build.
- Video wallpapers, Wallpaper Engine, 39 transitions, auto-tagging models, image optimisers that overwrite originals.
- Hover-to-open as the main trigger; exclusive keyboard grabs on sidebars.
- Any assistant that runs actions without confirmation, passes `.desktop` Exec through `sh -c`, or offers permission-bypass flags.
- skwd-wall as a backend; copy-based installers; i18n, pets, face unlock.

## 5. Questions for our discussion

1. **Scope**: all of E0–E10, or a first wave (suggest E0, E1, E2, E4, E8) with the rest queued?
2. **Sidebar contents**: Notifications(+Mail) · Weather · Feeds right. Anything for a *left* panel (e.g. calendar/agenda, music library)?
3. **Feeds**: which sources? (RSS URLs, subreddits via `.rss`, HN.)
4. **Theme list**: the 10 in report 08 (gruvbox-material dark/light, kanagawa-dragon, everforest, nord, rose-pine, tokyonight, catppuccin-mocha, solarized-dark, crt-amber) plus the suggested sepia "etching"? Fonts: install the 11 retro Nerd fonts?
5. **Wallpapers**: 5 themes have no fitting art today. Source more (public domain/CC0) or rely on lutgen-recoloured variants?
6. **Focus mode**: OK with a root-owned helper + a sudoers line limited to `apply/clear/status`? Hard mode by default or opt-in?
7. **Voice**: PTT hold vs tap-to-toggle? Google as default search? Escalations that edit code: open in the project's existing claude pane or a new window? OK to do one Colab session to train "hey computer"?
8. **Memory budget**: target for the shell after E3 (suggest < 300 MB), and is ~150 MB idle for the voice daemon acceptable?
9. **Tickets**: format: markdown files in `docs/tickets/`, or GitHub issues on TK-Evans01/configs (with a milestone per epic)?
