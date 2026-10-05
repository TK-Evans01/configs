# 02 · mochi-desktop (miflow13/mochi-desktop)

Repo: https://github.com/miflow13/mochi-desktop. Reviewed from a shallow clone of `main` (v0.4 alpha line).
"Theirs" paths are relative to the repo root. "Ours" paths are relative to `quickshell/.config/quickshell/rice/`.

**Bottom line up front:** this is **not a rice**. It is a GTK4/Python desktop pet: a pixel-art sprite that wanders the desktop and reacts to what you do.
It has no bar, no theme system, no wallpaper flow and no notification center, so almost nothing here overlaps impasto.
It is still worth mining for four things, all of them about behaviour rather than looks:

- a well-specified **Pomodoro/focus session model** (goal 6),
- a **logind session-lifecycle monitor** that is cleaner than our `gdbus monitor` grep,
- a **rate-limited, priority-queued "should I speak now?" engine**, a good template for the voice assistant's proactive side and for notification toasts,
- a **privacy-reduction pattern** for desktop context signals.

---

## 1. What it is

Mochi is a "desktop buddy". An animated 256×256 sprite (Cairo-drawn frames, `assets/mochi/*`) lives in a borderless GTK4 window.
It walks, sleeps, reacts to clicks and drags, and shows speech bubbles. It also reacts to coarse desktop context: typing, the focused app category, media playing, battery, network, files and downloads.
On top of that it has a "bond XP" progression and an emote catalogue, plus a "Focus with Mochi" Pomodoro timer with an optional looping rain soundscape.

- **Stack:** Python 3.11, PyGObject, GTK4, Cairo, GStreamer (`playbin` for ambience), Gio D-Bus. A companion GNOME Shell extension (`gnome-extension/mochi-typing@miflow13/extension.js`) reduces window titles and typing to anonymous signals and sends them over D-Bus.
- **Targets:** Fedora + GNOME + Wayland. The buddy uses an **XWayland** window (`src/mochi/x11.py`, `windowing.py`) because GNOME will not let a native Wayland client position itself. Niri support is experimental, Hyprland is untested, and there is no layer-shell.
- **Maturity:** early public alpha, about 25k lines of Python in `src/`. About 90 pytest files cover it (`tests/`) and CI runs them (`.github/workflows/tests.yml`). The repo also has unusually thorough design docs (`docs/STATE_MACHINE_AUDIT.md`, `REGRESSION_WATCHLIST.md`, `docs/superpowers/specs|plans/*`).
- It ships a self-updater with a staged restart and rollback (`src/mochi/update/*`).
- **License:** MIT, so copying is allowed. Little of it applies to us anyway, because it is Python/GTK and we are QML.

## 2. Architecture

```
src/mochi/
  app.py, main.py          Gtk.Application, CLI flags (--debug, --reset-position)
  buddy.py (1.4k)          interaction coordinator; feature mixins composed via MRO
  state.py, state_controller.py, behavior.py   one authoritative StateMachine + priority policy
  animation.py, sprites.py, sprite_loader.py   frame playback, manifest-driven
  config.py                ConfigStore: ~/.config JSON, atomic write, corrupt-file preservation
  focus.py                 PURE focus clock/reward model (no GTK)
  sound.py                 SoundManager (one-shots via CLI player) + FocusAmbienceManager (GStreamer loop)
  media_activity.py, music_activity.py, typing_activity*.py, file_activity.py   detectors
  presence/                "AmbiSense": engine.py (decision), cooldowns.py, signals.py, session.py (logind),
                           phrases.py, bubble.py (speech), focus_session.py (Focus UI + mixin), curiosity.py …
  update/                  checker/worker/window: GitHub release polling, staged install, rollback
gnome-extension/           GNOME Shell JS: emits AppCategoryChanged, BrowserTabChanged, YouTubeFocused*, typing pulses
```

Notable patterns:

- **Detectors own facts, the state layer owns presentation** (`docs/STATE_MACHINE_AUDIT.md` §1).
  - Every detector (typing, MPRIS, files, app focus) calls an entry point. Only `BehaviorStateController.request()` together with `behavior.can_transition()` may change state.
  - The "recovery order" is written down explicitly: Focus > Fedora mode > terminal > VS Code > video > music > files > idle timers.
  - This is the same idea as impasto's island arbitration, applied to a single character instead of a single island.
- **A domain session is not a state.** The Focus timer runs independently of the sprite's animation state.
  - Clicks, drags and level-ups can interrupt the visual while the clock keeps running, and the visual resumes afterwards (`presence/focus_session.py` `_finish_reaction`, `_ensure_focus_visual`).
- **Pure model, thin UI.**
  - `focus.py` (`FocusPlan`, `FocusSession.advance(elapsed) -> FocusAdvance`) is deterministic and fully unit-tested.
  - The GTK side does only two things:
    - It ticks every 500 ms and passes **real elapsed monotonic time** in (`_advance_focus_clock`), so a stalled main loop cannot drift the clock.
    - It renders whatever `FocusAdvance` reports: `xp_earned`, `encouragements_due`, `transitions`.
- **Event queue with priorities and transient invalidation** (`presence/engine.py`):
  - `_EVENT_PRIORITY` covers network, battery, media, user return and builds.
  - The queue is a `deque(maxlen=16)` that de-duplicates by name.
  - When a newer fact contradicts a queued one, the queued one is dropped (`_TRANSIENT_EVENT_STATES`: `network_lost` is dropped when `network_restored` arrives).
  - At a session boundary (lock or suspend), environmental events are dropped and user requests are kept (`note_session_away`).
- **Rate limiting** (`presence/cooldowns.py` `CooldownTracker`) applies three limits:
  - a global gap,
  - a maximum per rolling hour,
  - a per-category cooldown.
  - It can also return a reason string, for example `"hourly speech limit reached"`, which goes into the debug log.
- **Habituation** (`presence/curiosity.py` `_habituated_cooldown`): `cooldown = min(base * 1.5^streak, cap)`. The more often something has fired recently, the longer the next wait.
- **Display time scales with text length** (`engine.py` `speech_display_seconds`): 3.5 s up to 28 characters, 5 s up to 52, 6.5 s beyond that.
- **Config hygiene** (`config.py`):
  - `_save` writes to a `.tmp` file and then calls `replace()`.
  - If the JSON cannot be parsed, `_preserve_corrupt_config` moves it to `config.json.corrupt-<uuid>` before defaults are written over it.
- **Session lifecycle** (`presence/session.py` `SessionSignalMonitor`):
  - It resolves the real session with `GetSession("auto")`. Their note: `/session/auto` does not emit `PropertiesChanged`.
  - It subscribes to `PrepareForSleep` and to `LockedHint`/`Active` on that session.
  - On resume it re-reads properties before un-blocking, and if that read fails it assumes "locked".
  - The result is one `blocked` boolean with `on_away`/`on_returned` edges.

## 3. Feature inventory

| Feature | How it works (theirs) | We have it? | Worth adopting? |
|---|---|---|---|
| Pomodoro focus session (focus/break/rounds, pause, stop) | `src/mochi/focus.py` pure model + `presence/focus_session.py` window + 500 ms tick on monotonic delta | no | **Yes**, as the timer core of goal 6. We would add the blocking half, which they don't have. |
| Encouragement at 35% / 72% of a block | `FOCUS_ENCOURAGEMENT_MARKS`, threshold-crossing check in `advance()` | no | Maybe: a quiet toast at the marks. Off by default. |
| Looping focus soundscape with its own volume | `sound.py` `GStreamerFocusAmbienceBackend` (`playbin` + `about-to-finish` re-set uri) | no | Cheap with QtMultimedia `MediaPlayer { loops: MediaPlayer.Infinite }`. Optional. |
| Auto-sleep deferred during focus, manual sleep pauses focus | `_on_user_idle` / `_begin_sleep` overrides in `focus_session.py` | partial (caffeine stops idle-lock) | Yes: focus should inhibit idle-lock **or** pause on lock. Pick one rule and state it. |
| logind away/return monitor | `presence/session.py` (Gio D-Bus, `GetSession("auto")`, `LockedHint`, `Active`, `PrepareForSleep`) | partial: `services/Lock.qml` greps `gdbus monitor` for `PrepareForSleep` only | Yes: a cleaner `Session` service with an `away` bool for focus, voice and notifications. |
| "Welcome back" after unlock/resume, deferred until dialogue is free | `engine.note_session_returned`, `_welcome_back_pending` | no | Yes: a "while you were away" summary (grouped notifications, mail) on unlock. |
| Priority event queue + transient invalidation | `presence/engine.py` `_EVENT_PRIORITY`, `_TRANSIENT_EVENT_STATES` | no (impasto covers OSD debounce) | Yes, for voice-assistant proactive prompts and toast arbitration. |
| Global / hourly / per-category rate limits | `presence/cooldowns.py` | no | Yes for toasts by source (Discord spam) and voice "I noticed…" prompts. |
| Habituating cooldown | `curiosity.py` `_habituated_cooldown` | no | Yes for notification grouping: collapse a source after N within a window. |
| Text-length-scaled display time | `engine.speech_display_seconds` | no (dunst fixed timeout) | Yes, for our in-shell toasts once we have them. |
| Coarse app categories from window class | GNOME extension → `AppCategoryChanged(s)` | partial: we have `Hyprland.activeToplevel` | Yes: a category map (`terminal`, `browser`, `editor`, `media`, `game`) feeds focus blocking and voice context. |
| Browser tab-change pulse (title digest, input-gated) | `extension.js`, documented in `docs/ambisense.md` | no | No. Interesting privacy design, but focus mode needs the URL/site, not a pulse. |
| MPRIS "is it video?" heuristics (browser player names, file extensions) | `media_activity.py` `_BROWSER_PLAYER_MARKERS`, `VIDEO_FILE_EXTENSIONS` | partial: `services/Mpris.qml` picks the active player | Minor: useful if focus mode should pause/block YouTube playback. |
| Typing activity (AT-SPI, content-blind) | `typing_activity*.py` | no | No. Not needed. |
| Atomic config write + corrupt-file quarantine | `config.py` `_save`, `_preserve_corrupt_config` | n/a (impasto's FileView/JsonAdapter is planned) | Yes, as a guard to add to the FileView store (see Proposals). |
| Self-updater with staged restart and rollback | `src/mochi/update/*` | no | No. We use stow and git. |
| Bond XP / emotes / feeding | `presence/bond_*`, `emote_catalogue.py` | no | No. Not our identity. |
| State-machine audit and regression watchlist docs | `docs/STATE_MACHINE_AUDIT.md`, `REGRESSION_WATCHLIST.md` | partial: `docs/architecture.md` "Gotchas" | Yes (doc practice): a `docs/regressions.md` checklist for popups, focus grab and lock. |

## 4. Layout and UX patterns

There is no shell layout to compare: one sprite window, one right-click menu, and a few small GTK windows (Focus, Emote Catalogue, Update, Mochi Lab).

What feels good:

- **The Focus window can be closed without stopping the session.** Opening it again goes straight back to the live timer (`present_session` vs `present_setup`). For us this means a Focus popup that is a *view* of a `Focus` service, not the owner of the timer.
- **Two pages, one window:** a setup page (spin rows for Focus / Break / Rounds, an encouragement switch, the soundscape row, a "Start focusing" primary button) and a session page (`Focus 1 of 4`, a big `MM:SS`, a progress bar, minutes earned, Pause / Stop). This is a compact, readable pattern that would fit a Quick Settings sub-page or a sidebar section.
- **Non-punitive copy** ("stopped. no worries"). Stopping early keeps whatever was earned and never adds friction.
- **Smart popup placement:** `_focus_window_position_for_anchor` tries beside the anchor first, then above, then below, and only clamps as a last resort. It picks the nearest monitor geometry. Our `BarPopup` only centres under the anchor and clamps, which is fine for a bar, but a side panel would need this kind of fallback.
- **Speech bubble "typing preview"** for low-priority ambient lines only (`PresenceAction.__post_init__`, `priority < 40`). Urgent lines appear immediately. The same rule fits toasts: animate low-priority ones in, and snap urgent ones.
- The spec docs consistently write down **suppression rules**: quiet mode, a menu being open, a drag in progress, a higher-priority presentation. The rule is that a reaction is either shown or dropped, **never queued forever**.

What is clunky:

- XWayland positioning hacks, an invisible-input-grab watchlist, and a GNOME Overview freeze (#45). None of this applies under layer-shell.
- Heavy mixin MRO in `buddy.py` + `presence/click_dialogue.py`. Ordering bugs are a recurring theme in their watchlist.
- Global shortcuts depend on the GNOME extension. We have Hyprland binds and IPC, so this is a non-issue for us.

## 5. Against our goals

### Goal 1: cohesion / less clunky

There is no visual help here. The one transferable habit is **documentation discipline**: a written arbitration order (who wins when two things want the screen) and a regression checklist.
We have popups, a lock screen, focus grabs and soon toasts plus sidebars, all competing. Writing the precedence down once in `docs/architecture.md` (for example, lock > OSD > toast > popup hover) prevents a lot of the inconsistency.

### Goal 2: side panels / notifications grouped by source

There is no panel. But `CooldownTracker` (global gap + hourly cap + per-category cooldown) and `_habituated_cooldown` are exactly the throttles a **per-source toast policy** needs. Example: Discord gets at most one toast per 20 s, and after 3 in 5 minutes it collapses into "Discord (5)" in the sidebar only.
The `speech_display_seconds` length-scaling should also set the toast timeout. The notification server itself is "same as impasto".

### Goal 3 / 4: settings shell, themes, wallpapers

Not relevant. There is no theming beyond a GTK CSS string (`FOCUS_CSS`) and `color_scheme.py` (light/dark detection).
The only applicable bit is `config.py`'s **corrupt-file quarantine**, which should be added to our planned FileView/JsonAdapter store. That store is "same as impasto"; see Proposal 4.

### Goal 5: voice assistant

AmbiSense is explicitly "not an LLM", but its decision engine shows the right shape for the assistant's **proactive / ambient** half, and for gating:

- **Silence is a valid result** (`PresenceEngine` docstring: "Choose at most one … action; silence remains a valid result"). The assistant should never speak unprompted unless it clears a priority threshold and a cooldown.
- Detection does not own presentation:
  - wake word / STT / intent produce *events*,
  - one arbiter decides whether to speak, show a toast or ask a confirmation,
  - and the arbiter respects lock state, focus mode and DND.
- `note_session_away()` → drop stale environmental events, keep user requests. The same rule fits the assistant: if you lock mid-request, a pending "play my playlist" survives, and a stale "network came back" does not.
- Rule-based fast path first. Mochi handles everything with deterministic rules and phrase banks. Our assistant should likewise answer "open firefox", "focus 50 minutes" and "play alt rock" with a **grammar/regex intent table** before the 8B LLM is involved, and escalate (with a confirmation) only after that.

### Goal 6: focus mode

This is the main contribution. Mochi gives a complete, tested **timer model**. It has **no blocking at all**, which is the half we have to build. What to take:

- **`FocusPlan` clamps:**
  - focus 5–120 min (default 25),
  - break 1–30 min (default 5),
  - rounds 1–8 (default 4).
- **Transitions:** `FOCUS → BREAK → FOCUS … → COMPLETE`. Breaks lift the blocks, and focus phases re-apply them.
- **Pause and stop are free:** no penalty, no streaks.
- **Clock settlement from monotonic deltas, not tick counting.** In QML we would store `phaseEndsAt` (wall-clock ms) and recompute on each `Timer` tick. That is even simpler and survives suspend correctly: decide whether suspend time counts (Mochi does not decide this explicitly).
- **Sleep and lock interplay:** Mochi defers auto-sleep during an unpaused focus block and pauses focus on manual sleep. For us, the choice is whether focus **pauses on lock** (Mochi-like) or keeps running (blocker-like). Recommendation: keep running, because a lock-screen break should not extend the block. Make it a setting.

## 6. Proposals for us (ranked)

1. **`services/Focus.qml`: pure focus-session service (timer half of goal 6)**
   - What:
     - A singleton with `plan {focusMin, breakMin, rounds, blockProfile}`, `phase` ("" / focus / break / complete), `round` and `endsAt`.
     - Derived: `remaining`, `progress`, `phaseLabel`.
     - Methods: `start(plan)`, `pause()`, `resume()`, `stop()`. A 1 s `Timer` runs only while active and recomputes from `Date.now()` rather than decrementing.
     - It emits `phaseChanged`, which the blocker, the bar and the voice assistant all listen to.
   - IPC: `focus(minutes)`, `focusStop()`. A SUPER+SHIFT+F bind.
   - Persist `{phase, endsAt, plan}` to `$XDG_STATE_HOME`, so a shell reload or crash restores the session instead of silently ending the block.
   - Files: new `services/Focus.qml`, `services/qmldir`, `shell.qml` (IPC), `config/Settings.qml` (defaults 25/5/4).
   - Effort: **S**.
   - Risk: low. Keep it separate from the blocking mechanism so the timer is testable alone.

2. **Focus enforcement via Hyprland (blocking half of goal 6, user-level, no sudo)**
   - What:
     - Subscribe to `Quickshell.Hyprland` raw events (`openwindow`). If the window class is in the active profile's `blockedApps` and `Focus.phase === "focus"`, dispatch `closewindow address:0x…` and show a toast ("blocked until 14:25").
     - Also sweep existing clients when a block starts.
     - Sites: a user-level option is not airtight. Options in order of preference:
       - a Firefox/Chromium managed policy `URLBlocklist`. Needs root once to install the policy file, then can be toggled by a user-writable include.
       - a small local proxy.
       - an `/etc/hosts` block (root).
     - Hand the user a one-time setup one-liner rather than running sudo.
   - Files: `services/Focus.qml` (or `services/FocusBlock.qml`), `services/Hyprland.qml`, `config/Settings.qml` (`focusProfiles: [{id, label, apps:[classes], sites:[domains]}]`).
   - Effort: **M** for apps, **M–L** for sites.
   - Risk:
     - Closing windows loses unsaved work. Prefer `movetoworkspacesilent special:focus` + a toast as the default, and make "close" opt-in.
     - Blocking breaks are a voice-assistant "mode" too, so expose it through IPC.

3. **Focus UI: Quick Settings tile + sub-page, bar countdown**
   - What:
     - Tile "Focus" (sublabel `18:42 · 2/4` while active).
     - The ▸ opens a `focus` page: setup state (three stepper rows, profile chips, Start) or session state (big `MM:SS` in `fontSizeHuge`, segmented `Meter` for progress, Pause / Stop).
     - The bar gets a small `󰔟 18:42` cell with an underline in `Theme.accent` during focus and in `Theme.info` during a break.
     - Closing the popup never stops the session (Mochi's view-not-owner rule).
   - Files: `modules/quicksettings/MainPage.qml`, new `modules/quicksettings/FocusPage.qml`, `QuickSettingsWindow.qml` (page map), `modules/bar/QuickSettingsButton.qml` or a new `modules/bar/FocusButton.qml`.
   - Effort: **S–M**.
   - Risk: none. Accent style follows corner style per our theme rules (underline when square, pill when round).

4. **Harden the planned JSON settings store: atomic write + corrupt quarantine**
   - What:
     - Before `JsonAdapter` gets defaults written over a file that failed to parse, copy it to `settings.json.corrupt-<ts>` and toast once.
     - Quickshell's `FileView` already writes atomically by default (`atomicWrites`). Verify that, then add only the quarantine via a `Process` `cp` in `onLoadFailed` when the error is a parse error, not `FileNotFound`.
   - Files: the future `services/SettingsStore.qml` (impasto proposal).
   - Effort: **S**.
   - Risk: low. Prevents losing a hand-tuned theme list to one bad edit.

5. **`services/Session.qml`: proper logind away/return**
   - What: replace `Lock.qml`'s `gdbus monitor … | grep PrepareForSleep` with one tethered helper. Two candidate helpers:
     - `busctl --system --json=short monitor` filtered to `PrepareForSleep` plus `PropertiesChanged` on the *resolved* session path. Resolve it via `loginctl show-session $(loginctl show-user $USER -p Display --value)` or `busctl call … GetSession s auto`, because `/session/auto` does not emit property changes (their finding).
     - our own `Lock.locked` for the lock part, which we own anyway.
   - Expose `away` (sleeping ‖ locked ‖ !active) and `returned()` / `wentAway()` signals. Consumers:
     - the toast queue (hold and summarize),
     - the voice assistant (mute the mic while away),
     - focus (policy setting).
   - Files: new `services/Session.qml`, `services/Lock.qml` (delegate its sleep watch).
   - Effort: **S–M**.
   - Risk: the delay-inhibitor handshake in `Lock.qml` works today. Refactor carefully and keep `_releaseFallback`.

6. **"While you were away" card on unlock**
   - What:
     - On `Session.returned()` (or `Lock.finishUnlock`), if anything arrived while away, show one grouped summary toast or open the notification sidebar section: "3 mail · 5 Discord · 1 system".
     - Defer it if a popup is open. Show it at most once per return, and drop it if empty.
   - Files: notification service (impasto-derived), `services/Lock.qml`.
   - Effort: **S** once the notification server exists.
   - Risk: none.

7. **Toast arbiter: priority + per-source rate limit + habituation + length-scaled timeout**
   - What:
     - A small JS module (`services/ToastPolicy.js` or inside the notification service) that ports `CooldownTracker`: `globalGapMs`, `maxPerHour`, `categoryUntil{}`.
     - Add `habituated(base, cap, streak) = min(base*1.5^streak, cap)` per app.
     - Urgency maps to priority: critical bypasses everything, as Mochi's `priority >= 40` does.
     - Timeout: 3.5 / 5 / 6.5 s by body length.
     - Throttled notifications still land in the grouped sidebar. Only the *toast* is suppressed.
   - Files: notification service, `config/Settings.qml` (per-source overrides).
   - Effort: **S–M**.
   - Risk: tuning. Start conservative and log the suppression reason (their `can_speak()` returns a reason string, a nice debugging affordance).

8. **App-category map from window class**
   - What: `Settings.appCategories: { "com.mitchellh.ghostty": "terminal", "firefox": "browser", "steam": "game", … }` plus `Hyprland.activeCategory`. Consumers:
     - focus profiles ("block category `game`"),
     - voice context ("the claude code project from last night" → terminal windows),
     - optional bar tag colours in `ActiveWindow.qml`.
   - Files: `config/Settings.qml`, `services/Hyprland.qml`, `modules/bar/ActiveWindow.qml`.
   - Effort: **S**.
   - Risk: none.

9. **Optional focus ambience**
   - What: `QtMultimedia` `MediaPlayer` + `AudioOutput` looping a local file from `~/.local/share/rice/ambience/*.ogg`, with its own volume slider on the Focus page. It pauses with focus and stops at the break.
   - Effort: **S**.
   - Risk:
     - QtMultimedia import cost.
     - It must not grab MPRIS or fight spotify_player. A plain `MediaPlayer` does not register MPRIS.

10. **`docs/regressions.md` checklist**
    - What: borrow `REGRESSION_WATCHLIST.md`'s format for our known traps:
      - popup re-toggle within 300 ms,
      - focus grab handing keys to the bar,
      - lock surface on monitor hot-plug,
      - tray menu levels,
      - hot-reload "X is not a type".
    - Effort: **S**.
    - Risk: none.

## 7. Don't copy

- **The pet itself, bond XP, emotes, feeding, nameplate.** Cute, but not our retro tool-shell identity, and a constant animated window costs CPU/GPU for no information.
- **The GNOME Shell extension / AT-SPI typing monitor.** We are on Hyprland: `Quickshell.Hyprland` already gives us the active toplevel, and we do not want keystroke observation at all.
- **XWayland window positioning** (`x11.py`, `windowing.py`). Layer-shell `PanelWindow` makes all of this unnecessary.
- **The self-updater** (`src/mochi/update/*`). We deploy with stow + git, and hot reload covers it.
- **The mixin-MRO feature composition** (`buddy.py` + 15 mixins). Their own watchlist shows the ordering bugs it causes. Keep our singleton services + small modules.
- **The non-punitive "relationship" framing for focus.** Keep the clean timer model, but our focus mode is an actual *lockout* the user asked for. Breaks lift it, and "stop" should require a deliberate action (for example, hold or confirm twice, like our power buttons) rather than one click.
- **Browser tab "pulses" from title digests.** A clever privacy hack, but useless for blocking and fragile.
- **Treating the focus timer as `paused` on idle by default.** For a blocker, auto-pausing on idle lets the block quietly stretch past its end time. Make it explicit in Settings.
