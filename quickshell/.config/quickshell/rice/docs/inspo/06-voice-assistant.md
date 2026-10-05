# 06: Local voice assistant ("Hey Computer"): feasibility + architecture

Goal 5 from the brief. This is a design study, not a repo review. Facts were checked on
2026-10-05 against `pacman -Si` / `yay -Si`, `claude --help`, `spotify_player --help`,
`qs -c rice ipc show`, `wpctl status` and the web. Lines marked *(measure)* are estimates that
phase 0 must confirm.

**Verdict: feasible, and most of it ships in the official repos.** `extra/whisper-cpp` 1.9.4
and `extra/llama-cpp` both link the system `ggml`, and `extra/ggml-vulkan` 0.25.3 adds the
RADV GPU backend, so we need no ROCm, no CUDA and no AUR builds for the heavy parts. On RDNA4,
Vulkan is currently *faster* than ROCm for small-model decode. An 8-9B model at Q4 fits in
about 7 GB of the 16 GB VRAM. The hard parts are not compute:
- a "Hey Computer" wake word (no pretrained openWakeWord model; needs training or a stand-in),
- VRAM contention with games (needs idle unload),
- endpointing latency,
- keeping the action surface closed.

---

## 0. What we already have (relevant to this goal)

| Thing | Where | Use for voice |
|---|---|---|
| Mic sources | `wpctl status`: default **Blue Snowball** (id 65), Arctis Pro Wireless Chat, Brio 101, AB13X adapter | Snowball is a desk mic and will hear the speakers. Arctis is close-talk, so it gives fewer false wakes. Make the source a setting. |
| `pw-record` | `pipewire` (installed) | `pw-record --rate 16000 --channels 1 --format s16 --target <src> -` gives raw PCM on stdout, so we need no portaudio/sounddevice. |
| Python | `python 3.14.7`, `python-numpy`, `python-pipx` installed; no `uv` | Daemon language |
| IPC | `shell.qml` `IpcHandler target:"rice"`: `dashboard, quicksettings, launcher, music, playpause, next, previous, dnd, nightlight, caffeine, lock, screenshot, mail, close, refresh, focused` | Binds call into the voice service. Several new fns are needed (see §3.4). |
| Tether | `Settings.tether = ["setpriv","--pdeathsig","TERM","--"]` | Wrap the daemon *and* its model-server children. |
| App launch | `services/Launcher.qml` `search(q)` / `launch(e)` over `DesktopEntries` (terminal apps via `Settings.terminal`) | `open_app` reuses ranking and launch. No `Exec=` string ever goes through `sh`. |
| Spotify | `services/Spotify.qml` `playPlaylist/playAlbum/playLiked`, cached library (`spotify_player get key user-playlists`) | "play my alt rock playlist" becomes a fuzzy match over the cached names, then `playPlaylist(id)`. |
| spotify_player CLI | `playback start context --name/--id <playlist\|album\|artist> [-s]`, `playback start liked/radio/track`, `search <q>`, `playback play-pause/next/previous/volume` | Backing commands |
| Claude sessions | `~/.claude/projects/<dash-encoded-dir>/*.jsonl` (+ `subagents/` subdirs) | Many sessions start from `~` (`-home-tk`), so **the directory name is not the project**. Read the first `"cwd"` field of each top-level jsonl instead. |
| tmux | sessions `main`, `music`, `2`; resurrect saves `~/.local/share/tmux/resurrect/tmux_resurrect_*.txt` | Project lookup from windows or the resurrect file |
| Free binds | `SUPER+Space`, `SUPER+F`, `SUPER+Z`, `SUPER+U` unused in `hypr/.config/hypr/external/keybindings.conf` | Push-to-talk on `SUPER+Space` |

---

## 1. Pipeline options and picks

### 1.1 Wake word

| Option | Local? | "Hey Computer"? | Cost idle | Notes |
|---|---|---|---|---|
| **openWakeWord** (AUR `python-openwakeword` 0.6.0, deps `python-onnxruntime`) | yes, ONNX on CPU | **No pretrained model.** The pretrained set is `alexa, hey_jarvis, hey_mycroft, hey_rhasspy` + timer/weather. You train a custom ONNX with synthetic (Piper-generated) clips. | about 1-3% of one core; ~100-150 MB RSS *(measure)* | The upstream training pipeline is pinned to 2022-era torch/TF and breaks on modern Python. Working routes in 2026: the `openwakeword-colab-2026` notebook (~75-90 min on Colab), WakeLab (desktop trainer), or a dockerized trainer. Output: one `hey_computer.onnx` file you drop in. Training needs no GPU, but CPU-only local training is slow (hours). |
| Porcupine (Picovoice) | inference local, **AccessKey + online activation/check-in** | built-in "computer"; custom "hey computer" via their console | very low | Account-bound, non-commercial free tier, phones home. **Reject** under "runs locally". |
| Whisper-tiny on VAD segments | yes | any phrase, no training | Runs STT on *every* speech segment, including music, Discord and games. tiny.en on 8 threads is ~0.1-0.3 s per segment *(measure)*, so it's spiky but OK. | Good **fallback / bootstrap**. Lots of false-reject edge cases ("hey, computer", "a computer"); fuzzy-match the first 3 words. |
| Rustpotter | yes | personal wake word from about 5-10 recorded samples, no training pipeline | very low | Less robust to other speakers; reasonable if openWakeWord training hurts. Not packaged; cargo. |
| microWakeWord | yes (tflite-micro) | needs training | very low | Made for ESP32, no gain on desktop. |

**Pick:** openWakeWord with the pretrained **`hey_jarvis`** as a stand-in for phase 2. Train
**`hey_computer.onnx`** on Colab or WakeLab once and swap it in through a setting
(`voiceWakeModel`). Keep "whisper-tiny on VAD" as a config fallback (`wake: "stt"`). Always gate
the wake model with Silero VAD so it scores only speech frames: this cuts false triggers from
music. Threshold around 0.5-0.6 plus a 2-frame patience; tune on the Snowball and the Arctis
separately.

### 1.2 VAD / endpointing

- **Silero VAD** (ONNX, ~2 MB). Already a dependency path of openWakeWord (`vad_threshold`), and
  available as AUR `python-pysilero-vad` / `silero-vad-onnx-model`. whisper.cpp 1.9.4 also ships
  `whisper-vad-speech-segments` with built-in Silero support.
- Endpoint: after the wake word (or PTT press), record until **~600 ms of non-speech** or 8 s
  max, with a 300 ms pre-roll ring buffer. In PTT mode the endpoint is the key release, so no
  silence wait is needed. That is why PTT feels faster.
- `python-webrtcvad` (extra) is a lighter fallback, but worse in noise.

### 1.3 STT

| Option | Runs on | Latency on 3-5 s utterance *(measure)* | Memory | Notes |
|---|---|---|---|---|
| **whisper.cpp `large-v3-turbo` q5_0, Vulkan** (`extra/whisper-cpp` + `ggml-vulkan`) | GPU | ~0.2-0.5 s | ~0.9-1.2 GB VRAM | Best accuracy for names ("alt rock", app names). `whisper-server` (HTTP, resident) is in the package. |
| whisper.cpp `small.en` / `base.en` q5_1, CPU | CPU 8 threads | ~0.8-1.5 s / ~0.3 s | ~0.3-0.5 GB RAM | No VRAM, so it is the *game-mode fallback*. |
| **Parakeet TDT 0.6B v3** (`parakeet-cli` ships in `whisper-cpp` 1.9.4!) | CPU or GPU | very fast (thousands x RT on leaderboard) | ~0.6-1 GB | Better WER than whisper-large-v3 on the Open ASR board, English-strong. Worth an A/B in phase 0. |
| faster-whisper (AUR `python-faster-whisper` + `python-ctranslate2`) | CPU only on AMD | slower than whisper.cpp-Vulkan | ~1 GB RAM | Adds a CTranslate2 build. **Skip.** |
| Moonshine base | CPU | very fast | 58 MB | English-only, less accurate on proper nouns |

**Pick:** `whisper-server` with `ggml-large-v3-turbo-q5_0.bin` on Vulkan, and `base.en` on CPU
when VRAM is reserved (game mode). Pass an `--prompt` / initial prompt containing playlist and
app names; it biases decoding toward our vocabulary, and the list comes from the shell (see the
context channel in §3.3). Drop the known silence hallucinations ("Thank you.", "you", "[BLANK_AUDIO]").

### 1.4 LLM runtime (RDNA4, no ROCm)

- Community boards in 2026: llama.cpp **Vulkan (RADV) beats ROCm** on RDNA4 for small-model and
  MoE decode. The 9070 XT does ~130 tok/s on Qwen3-8B Q4_K_M. Our non-XT will be somewhat lower;
  ~90-110 tok/s *(measure)*.
- **`llama-server`** from `extra/llama-cpp` + `extra/ggml-vulkan`. It exposes an OpenAI-compatible
  `/v1/chat/completions` with `--jinja` tool calling and `response_format: {type: json_schema}`
  (GBNF-constrained, so it always emits *valid* JSON). `--sleep-idle-seconds N` unloads the
  model when idle and wakes it on the next request; `GET /props` reports `is_sleeping`. That is
  the skwd-wall on-demand pattern, built in.
- **`ollama-vulkan`** (extra 0.35.1, needs `OLLAMA_VULKAN=1`). It is easier (model pulls,
  `keep_alive`, `format: <schema>`), but it runs as a system/user service outside our tether and
  adds a second model store. It's an OK alternative; **not the pick**.
- Skip `python-llama-cpp-vulkan` (AUR, out of date) and vLLM (ROCm).

### 1.5 Model (tool calling, about 7-9B)

| Model | Q4_K_M size | Why |
|---|---|---|
| **Qwen3.5-9B Instruct** (pick) | ~5.7 GB | Strongest small tool-caller in 2026 comparisons; reported clean llama-server tool calls; 262k ctx (we use 8k). Run **non-thinking** (`enable_thinking=false` / `/no_think`). |
| Qwen3-8B (fallback) | ~5.0 GB | Proven: 0.919 tool-call F1 at Q4_K_M in Docker's 2025 local eval |
| Gemma 4 12B | ~7.5 GB | Better multi-step reasoning, native function calling; slower. Still fits, but leaves less headroom. |
| Qwen3.5-4B / Gemma 4 E4B | ~2.5-3 GB | **CPU or low-VRAM tier** (~15-25 tok/s on the 5800X *(measure)*). Enough for picking 1 of ~15 tools under a JSON schema. |
| Llama 3.1 8B | ~4.9 GB | Clearly weaker at tool calls (0.79 F1). Skip. |

Note on the job: the model fills **one** JSON object from a closed schema, often with enums
injected from live context. That is a classification-plus-slot-filling task, not an agent loop,
so a 4B model may suffice. Phase 0 should A/B 9B against 4B on a 50-utterance test set.

### 1.6 TTS

**v1: none.** Feedback is the on-screen voice OSD plus a short chime (`pw-play` of a bundled
.oga). Reasons: most actions are self-evident (music starts, a window opens), and it saves memory.

v2, optional: **Piper** (AUR `piper-tts` 1.8.0 + `piper-voices-en-us`, ONNX on CPU, ~60 MB
voice, faster than realtime), only for answers and escalation results. Skip Kokoro: AUR
`python-kokoro` pulls in torch (GBs). If wanted later, use kokoro-onnx in a venv.

---

## 2. Latency + memory budget

### 2.1 Latency (from end of speech / key release to action) *(measure all)*

| Stage | PTT, warm | Wake word, warm | Cold (model asleep) |
|---|---|---|---|
| wake detect | none | 0.1-0.2 s | same |
| endpoint (silence wait) | 0 (key up) | 0.6 s | same |
| STT turbo/Vulkan (resident) | 0.2-0.5 s | 0.2-0.5 s | +0.5-1 s if `whisper-server` slept |
| fast-path intent (regex) | <10 ms | <10 ms | n/a |
| LLM intent (only if fast path misses) | 0.4-0.9 s (prefix-cached system prompt; ~60 tokens out) | same | **+2-5 s** load of 5.7 GB from page cache/NVMe (+ first-ever Vulkan shader compile) |
| action | 0.05-1 s (Spotify Web API is the slow one) | same | same |
| **Total, fast path** | **~0.4-1.5 s** | **~1-2 s** | ~1-2 s |
| **Total, LLM path** | **~1-2.5 s** | **~1.5-3 s** | **~4-8 s** |

Implication: the regex fast path should cover the top ~80% of utterances, so most commands
never touch the LLM. Pre-warm the LLM when the wake word fires or PTT goes down, *in parallel*
with recording. A `GET /props` probe does not count as a task, so send a 1-token completion to
wake it.

### 2.2 Memory

| State | RAM | VRAM | CPU |
|---|---|---|---|
| **Off** (`voiceEnabled=false`) | 0 | 0 | 0 |
| **Idle, PTT only** | daemon ~40-60 MB (python+numpy, no models) | 0 | ~0 |
| **Idle, wake word** | ~120-200 MB (onnxruntime + melspec/embedding/wake + Silero) + `pw-record` ~5 MB | 0 | ~1-3% of one core |
| **Active, STT resident** | +~100 MB | +~1.0 GB (turbo q5) | burst |
| **Active, LLM loaded** | page cache ~6 GB (reclaimable, mmap) | +~6.5-7 GB (9B Q4_K_M weights + 8k KV, flash-attn) | burst |
| **Peak** | ~0.4 GB anon + ~7 GB cache | **~8 GB of 16** | |

**What to keep resident:**
- wake word + VAD always while enabled (cheap);
- `whisper-server` with `--sleep`-style on-demand behaviour: spawn on first utterance, exit
  after `voiceSttIdleMin` (default 15);
- `llama-server --sleep-idle-seconds 600`;
- **game mode**: when a fullscreen client from a `Settings.gameClasses` list is focused (we
  already track `Hyprland.activeToplevel`), or Steam is running, force-sleep the LLM and switch
  STT to `base.en` on CPU. The fast path keeps working with zero VRAM. Optionally, LLM fallback
  to the 4B on CPU.

---

## 3. Architecture

### 3.1 Processes

```
quickshell (rice)
 └─ services/Voice.qml ── Process [Settings.tether…, python3, scripts/voiced.py]   (stdin/stdout JSON lines)
       └─ voiced.py  (single asyncio daemon, no network listener)
            ├─ pw-record --target <src> --rate 16000 …          (child, pdeathsig)
            ├─ whisper-server  -m turbo-q5_0 --host 127.0.0.1 --port <rand>   (on demand, pdeathsig, idle exit)
            └─ llama-server -m qwen3.5-9b-q4_k_m --jinja -ngl 99 -c 8192 --host 127.0.0.1
                            --port <rand> --sleep-idle-seconds 600            (on demand, pdeathsig)
 └─ claude -p … (escalation only; spawned by Voice.qml after user confirm, tethered, timeout)
```

- **One Python daemon, started by the shell** (not systemd), the same pattern as
  `scripts/proton-mail.py` but long-lived. It is launched with `Settings.tether` and
  `setpriv --pdeathsig TERM`. Its children use `prctl(PR_SET_PDEATHSIG)` in `preexec_fn`, or the
  same `setpriv` prefix. The result: shell dies → daemon dies → model servers die. No orphans,
  no listening sockets beyond 127.0.0.1 random ports. Use a `--api-key` with a random token
  passed via env, so other local users or processes can't drive the model.
- **The daemon only perceives and proposes; the shell executes.** `voiced.py` turns
  audio → text → *proposed intent* `{tool, args, source, confidence}`. `Voice.qml` validates
  against the same schema and runs the action through existing services (`Svc.Spotify`,
  `Svc.Launcher`, `Svc.Desktop`, …). The whitelist then lives in one place, QML. A compromised
  or confused model can only emit JSON that the shell may ignore.
- Python deps stay minimal: system `python-numpy` + `python-onnxruntime-cpu` (extra) +
  `python-openwakeword` (AUR, pure python). HTTP to the local servers uses `urllib`, so no
  `requests`/`openai` packages.

### 3.2 Talking to Quickshell

- **Shell → daemon**: `Process.write()` JSON lines on stdin, e.g.
  `{"cmd":"ptt","down":true}`, `ptt up`, `mute`, `unmute`, `cancel`, `wake on|off`,
  `source <name>`, `game on|off`, and
  `{"cmd":"context","playlists":[…],"apps":[…],"projects":[…],"modes":[…]}`. The context is
  re-sent when `Svc.Spotify` / `Svc.Launcher` lists change; it feeds STT prompt biasing and
  LLM schema enums.
- **Daemon → shell**: stdout JSON lines via `SplitParser`:
  `state` (`idle|listening|recording|transcribing|thinking|confirm|acting|error`),
  `level` (RMS for a meter, throttled to 20 Hz), `wake {score}`, `transcript {text, final}`,
  `intent {tool,args,source,confidence}`, `escalate {summary, task}`,
  `answer {text}` (LLM chit-chat), `log`.
- **Binds → shell**: new `IpcHandler` fns in `shell.qml`:
  `voice(action)` (`ptt-down|ptt-up|toggle|mute|cancel|confirm`).
  Hyprland:
  ```
  bind  = $mainMod, Space, exec, $rice voice ptt-down
  bindr = $mainMod, Space, exec, $rice voice ptt-up
  bind  = $mainMod SHIFT, Space, exec, $rice voice mute
  ```

### 3.3 UI surfaces

1. **`modules/voice/VoiceOsd.qml`**: a small layer-shell `PanelWindow` on the Overlay layer,
   top-center under the bar of the focused monitor (reuse `BarPopup` geometry, no focus grab
   unless confirming). Rows:
   - state glyph + segmented `Meter` for mic level;
   - live transcript (`ScrollingText`);
   - the **planned action** in plain words (`▸ play playlist "Alt Rock" (shuffle)`), with a
     `rule`/`llm` tag;
   - for confirm tiers, a card with `[↵ yes] [esc no]` and a countdown bar. Keyboard mode
     `OnDemand` only while confirming.
   - It auto-hides 2.5 s after `acting`.
   - New dir under `modules/` means a shell restart (architecture.md gotcha).
2. **Bar indicator**: fold into `QuickSettingsButton`, as with mic-muted today:
   - dim mic glyph = wake word armed;
   - accent + underline = recording;
   - red slash = voice muted;
   - hidden = voice off.
   This is the privacy indicator, and it is driven by daemon `state`, not by guessing.
3. **Dashboard tab `voice`** (`Settings.dashboardTabs`):
   - history (time, transcript, intent, result, escalations);
   - settings: enable, wake on/off, model, source picker reusing `Svc.Audio.inputs`,
     thresholds, idle timers, game mode;
   - a "test phrase" button.
   History is kept in memory plus `~/.cache/quickshell/voice-history.jsonl`, capped at 200
   lines, transcripts only and **never audio**.

### 3.4 Intent routing layers

1. **Normalize**: lowercase, strip punctuation and wake phrase, convert number words
   ("forty five" → 45), drop STT hallucinations.
2. **Fast path (rules)**: an ordered regex/grammar table in `voiced.py` (or `config/VoiceRules`
   JSON), each mapping to a tool with typed captures. Order matters: specific before generic.
   - `^(?:open|resume|go to) (?:the )?claude(?: code)? project(?: from)? (?P<when>last night|today|yesterday|earlier)?$` → `open_project{when}`
   - `^(?:play|put on) (?:my )?(?P<name>.+?) playlist$` → `play_playlist{name}`
   - `^(?:play|put on) (?:my )?liked(?: songs)?$` → `play_liked`
   - `^(?:google|search(?: for)?|look up) (?P<q>.+)$` → `web_search{q}`
   - `^(?:start )?focus(?: mode)?(?: for)? (?P<n>\d+) (?P<u>minutes?|hours?)$` → `focus_start{minutes}`
   - `^(?:open|launch|start) (?P<app>.+)$` → `open_app{query}`, only if `Launcher.search` gives
     a confident top hit (score gap); otherwise fall through
   - `^(pause|resume|play|next|skip|previous|back)(?: song| track| music)?$` → `media`
   - `^(?:set )?volume (?:to )?(?P<p>\d+)(?: percent)?$` / `volume (up|down)` → `volume`
   - `^(?:turn )?(?P<mode>night light|do not disturb|dnd|caffeine|focus)(?: mode)? (?P<on>on|off)$` → `set_mode`
3. **LLM with a JSON schema**: one `/v1/chat/completions` call.
   - Inputs: a short system prompt (tool descriptions, ~800 tokens, prefix-cached) plus the
     utterance plus tiny context (time, focused window class).
   - `response_format.json_schema` = `oneOf` over tool objects with `enum`s filled from live
     context: playlist names, mode names, dashboard tabs. A free-string slot only where
     unavoidable (search query, app query), and those slots are re-validated in QML.
   - Meta-tools: `clarify{question}`, `answer{text}` (plain question, no action),
     `escalate{summary, task}` ("needs more than these tools"), `none`.
   - Temperature 0.
4. **Ask to escalate**: `escalate` never runs anything. It shows the confirm card (§5).
5. **`claude -p`**: only after an explicit yes.

**Confidence handling:**
- LLM output with `source:"llm"` for a T1/T2 tool always shows the plan before running.
- Fuzzy-match slots (playlist, app, project) need a score threshold. Below it, show the top 3
  as choices: `1/2/3` keys, or say "the first one".

### 3.5 Safety model

- **Closed tool vocabulary** (§4). Each tool maps to a fixed QML function or fixed argv array.
  - **No `sh -c`, no `exec` of model text, no shell passthrough tool, ever.**
  - Free strings are only ever used as: a URL-encoded query param on a fixed search URL; a
    fuzzy-match key against a known list (playlists, DesktopEntries, project dirs); or a
    `claude -p` prompt after confirm.
- **Arg validation in QML**: enums, int ranges (`focus 5-240 min`, `volume 0-100`), string
  length ≤ 200. Reject unknown keys.
- **Tiers:**

  | Tier | Behaviour | Tools |
  |---|---|---|
  | T0 | Instant | media, volume, open dashboard/QS page, web search, play playlist, open app, timer, screenshot |
  | T1 | 3 s countdown with `esc`/"cancel" | focus start, open project (when it creates a tmux window), lock, VPN on |
  | T2 | Explicit confirm (key or click; voice "yes" only within 5 s and only in PTT) | suspend, VPN **off**, escalate, anything `source:"llm"` with confidence < threshold |
  | Never by voice | Not in the vocabulary | reboot/shutdown/logout, focus **stop** (per goal 6: a deliberate action only), file ops, sending mail/messages, killing processes, arbitrary URLs, Docker stop |

- **No auto-escalation and no permission-bypass flags anywhere.** Enforce it in code:
  `Voice.qml` builds the `claude` argv from a constant, and a startup assertion refuses to run
  if the argv contains `--dangerously-skip-permissions`, `--allow-dangerously-skip-permissions`
  or `bypassPermissions`.

### 3.6 Privacy

- PTT is the default mode. In PTT the mic stream does not exist until key-down; `pw-record`
  starts on press, and that costs ~50 ms, so keep a 0 ms pre-roll.
- Wake mode is opt-in. A persistent capture stream keeps the source un-SUSPENDED and is visible
  in `pactl list short source-outputs`, so the bar glyph must be honest.
- **Mute** = kill `pw-record` (stream gone), not "ignore frames". Auto-mute while `Lock.locked`,
  during DND if the user wishes (`voiceMuteOnDnd`), and on a manual `SUPER+SHIFT+Space`.
- Audio stays in RAM ring buffers and is never written to disk. A debug flag can write the last
  utterance WAV to `$XDG_RUNTIME_DIR` (tmpfs).
- The only outbound traffic is the actions themselves (Spotify API, the browser) and an
  escalation the user approved.
- Web search engine is a setting (`voiceSearchUrl`). Default to what the user said ("Google"),
  but allow DuckDuckGo.

---

## 4. Action catalogue v1

All handlers live in `services/Voice.qml` (new) unless noted. "IPC" means it also gets a
`rice` IPC fn so binds and scripts can use it.

| Tool | Args schema | Backing | Tier |
|---|---|---|---|
| `open_app` | `{query: str≤64}` | `Svc.Launcher.search(query)[0]` above a score threshold → `Svc.Launcher.launch(e)` (DesktopEntry `execute()`, terminal apps via `Settings.terminal`); otherwise top-3 chooser | T0 |
| `web_search` | `{query: str≤200, engine?: enum[google,ddg]}` | `Qt.openUrlExternally(base + encodeURIComponent(query))`; default browser is firefox.desktop | T0 |
| `play_playlist` | `{name: enum<cached playlists>\|str, shuffle?: bool}` | fuzzy match over `Svc.Spotify` library → `Svc.Spotify.playPlaylist(id, shuffle)` (`spotify_player playback start context playlist --id … [-s]`); starts the `spotify_player -d` daemon via `Svc.Mpris.launch()` path if it is down | T0 |
| `play_liked` | `{shuffle?: bool}` | `Svc.Spotify.playLiked` | T0 |
| `play_search` (v1.5) | `{kind: enum[track,album,artist], query: str}` | `spotify_player search <q>` (JSON) → first hit → `playback start track\|context --id` | T0 |
| `media` | `{action: enum[play,pause,toggle,next,previous]}` | `Svc.Mpris.*` (same as IPC `playpause/next/previous`) | T0 |
| `volume` | `{percent?: int 0-100, step?: enum[up,down]}` | `Svc.Audio` setters (`wpctl set-volume @DEFAULT_AUDIO_SINK@`) | T0 |
| `show` | `{panel: enum[dashboard:<tabs>, quicksettings:<pages>, launcher, clipboard, keybinds]}` | existing IPC `dashboard(tab)` / `quicksettings(page)` / `launcher()` | T0 |
| `screenshot` | `{target: enum[area,active,output,screen], action: enum[save,copy,text,edit]}` | `Svc.Screenshot.take` (OSD hides first) | T0 |
| `timer` | `{minutes: int 1-480, label?: str≤40}` | QML `Timer` + `notify-send` (later the shell's own toast) | T0 |
| `set_mode` | `{mode: enum[night_light,dnd,caffeine], on: bool}` | **needs idempotent setters**: `Svc.Desktop.setDnd(b)`, `setNightLight(b)`, `Svc.Lock.caffeine = b`. Today's IPC only toggles; add `setMode(name,on)` IPC. | T0 |
| `focus_start` | `{minutes: int 5-240, profile?: enum<focus profiles>}` | goal 6 `Focus` service `start(minutes, profile)` + IPC `focus(minutes)`. **Dependency: goal 6.** | T1 |
| `focus_status` | `{}` | `Focus.remaining` → OSD text | T0 |
| `open_project` | `{name?: enum<~/Projects dirs>, when?: enum[last_night,today,yesterday,latest]}` | `scripts/recent-projects.py` (see below) → tmux select-window or new-window → focus the ghostty client | T1 if it creates a window, else T0 |
| `lock` | `{}` | `Svc.Lock.lock()` | T1 |
| `vpn` | `{on: bool}` | `Svc.Network` connect/disconnect (`mullvad`) | on T1 / **off T2** |
| `suspend` | `{}` | `Svc.Desktop` power action | T2 |
| `clarify` / `answer` / `none` | `{question}` / `{text≤600}` / `{}` | OSD text only | none |
| `escalate` | `{summary: str≤200, task: str≤1000}` | §5 | T2 always |

**`open_project` resolver** (`scripts/recent-projects.py`, JSON on stdout like the other helpers):

1. Scan `~/.claude/projects/*/*.jsonl` (top level only; skip `subagents/`) for mtime. Read the
   first `"cwd"` value from the head of each file (≤8 KB). Keep cwds under `~/Projects/`.
2. Map `when`: `last_night` = yesterday 17:00 → today 05:00 local (or "today before 05:00"
   when asked in the early morning); `today`; `yesterday`; `latest`. Pick the cwd with the
   newest mtime in the window. If several projects fall in the window, return the top 3 for the
   chooser. Also return the `sessionId`.
3. tmux: `tmux list-windows -a -F '#S:#I #W #{pane_current_path}'`.
   - If a window has `pane_current_path` under that dir (or name == basename), use
     `tmux select-window -t S:I`.
   - Otherwise `tmux new-window -t main -n <basename> -c <dir>` (T1). The user's usual layout
     (nvim + claude tabs) can be a later `--layout` option.
   - If tmux isn't running, check the newest `~/.local/share/tmux/resurrect/tmux_resurrect_*.txt`
     and offer "restore session first".
4. Focus: `hyprctl dispatch focuswindow class:com.mitchellh.ghostty` (verify class); if no
   client is attached, launch `ghostty -e tmux attach -t main`.
5. **Optional and opt-in:** offer "resume that Claude session?". If yes, run
   `claude --resume <sessionId>` *interactively* in the project window's claude pane via
   `tmux send-keys`. The user sees and drives it. This is not headless.

---

## 5. Escalation design

**When:**
- the LLM returns `escalate`;
- the LLM fails schema validation twice;
- the user says "ask Claude …" (a fast-path rule that still asks for confirmation).

**The ask** (VoiceOsd confirm card, T2; it never auto-runs and times out to "no" after 20 s):

```
 󰚩  Out of my depth
 "what's the difference between hyprland windowrule v2 and v3 syntax"
 Ask Claude Code (headless, read-only, ~$ / uses your plan)?
 context: question only · cwd: ~
 [↵ ask]  [e edit]  [esc no]
```

`e` opens the launcher prompt pre-filled with the task text, so the user can fix STT errors
before sending.

**Two escalation modes, picked by the local model and shown on the card:**

1. **Answer (headless, read-only)**: questions, lookups, "explain", "summarize my project's
   README". Spawned by `Voice.qml` via `Process` with `Settings.tether`, a timeout of 180 s,
   and `esc` to kill:
   ```
   claude -p "<task>"
     --restricted                       # removes Bash/code-running tools + WebFetch unless named; confines file tools to cwd/--add-dir; refuses bypassPermissions
     --tools "Read,Grep,Glob,WebSearch,WebFetch"
     --permission-mode dontAsk --permission-prompts none   # anything that would prompt is denied, not asked
     --output-format json --no-session-persistence
     --append-system-prompt "You are answering a spoken question from a desktop voice assistant. Reply in <= 120 words, plain text, no markdown tables. Do not propose shell commands for the user to paste."
     --model sonnet --effort low   (configurable)
     [--max-budget-usd 0.25]           # only effective with API-key billing
   ```
   - cwd is `~` for general questions, or the project dir when the utterance names one. No
     `--add-dir` unless the card shows it.
   - **Context passed:** the confirmed task text, the local model's one-line summary, the date,
     and, only when relevant and shown on the card, the project path. **Not passed:** clipboard,
     screen, mail, history, audio.
   - Result: parse the JSON `result` field and show it in the OSD (expandable, scrollable, `c`
     to copy). Append it to voice history, and optionally Piper-speak the first sentence (v2).
     Non-zero exit or timeout → error card.
2. **Do work (interactive hand-off, never headless)**: anything that would edit files or run
   commands ("fix the failing test in octivium").
   - Do **not** run `claude -p` with write tools. Instead open or select the project's tmux
     window (as in `open_project`) and launch an **interactive** `claude "<task>"` in the
     claude pane.
   - The user's normal permission prompts apply. The assistant only typed the prompt, after
     confirmation.
   - This satisfies "ask before escalating" and "never bypass permissions" without inventing a
     permission bridge.

**v2:**
- `--json-schema` for headless answers, returning `{answer, suggested_actions:[<our tool
  objects>]}`. Suggested actions render as buttons and still go through the same QML
  validation and tiers.
- A `--permission-prompt-tool` bridge that shows Claude's tool permission requests in our OSD.
  More moving parts; only if mode 1 proves too limited.

---

## 6. Phased plan

**Phase 0: bench (S, ~1 evening).** No shell changes. Run `whisper-cli` and `parakeet-cli` on
20 recorded utterances, Vulkan vs CPU. Run `llama-server` with Qwen3.5-9B and Qwen3.5-4B
against a 50-utterance intent test set with the JSON schema. Record latency, VRAM
(`Svc.Sys` already shows it) and accuracy. Check `llama-server --list-devices` shows the RADV
device, and test `--sleep-idle-seconds` wake time.
```
sudo pacman -S --needed whisper-cpp llama-cpp ggml-vulkan python-onnxruntime-cpu
```
Models go to `~/.local/share/rice-voice/models/`, as user downloads from Hugging Face, ~7 GB:
- `ggml-large-v3-turbo-q5_0.bin`, `ggml-base.en-q5_1.bin`;
- Qwen3.5-9B-Instruct and 4B GGUF Q4_K_M;
- optional Parakeet GGUF.

The AUR `whisper.cpp-model-*` packages exist but date from 2024; plain downloads are simpler.

**Phase 1: push-to-talk MVP, fast path only (M).**
- `scripts/voiced.py` (pw-record on PTT, whisper-server on demand, regex table, JSON lines),
  `services/Voice.qml`, `VoiceOsd`, the bar glyph, the `voice()` IPC, and the `SUPER+Space`
  `bind`/`bindr`.
- Tools: `media, volume, play_playlist, play_liked, web_search, open_app, show, timer,
  set_mode` (add idempotent setters to `Desktop`/`Lock`).
- No new packages beyond phase 0.

**Phase 2: LLM fallback + open_project (M).**
- llama-server child with sleep-idle, the schema builder with live enums, meta-tools,
  confidence → tiers, `scripts/recent-projects.py`, top-3 chooser, game-mode VRAM release.
- No new packages.

**Phase 3: escalation (S-M).** Confirm card, "answer" mode `claude -p` argv constant plus the
bypass-flag assertion, result card, history tab, and "do work" interactive hand-off via tmux.
No packages (claude is at `~/.local/bin/claude`).

**Phase 4: wake word (M; +L if training locally).**
- openWakeWord + Silero gating with `hey_jarvis` first; train `hey_computer.onnx` (Colab
  notebook or WakeLab); per-source thresholds; auto-mute on lock/DND; dashboard settings tab.
- Packages:
  ```
  yay -S --needed python-openwakeword python-pysilero-vad silero-vad-onnx-model
  ```
  `pysilero-vad` builds with cmake. Alternatively, use the Silero ONNX directly through
  onnxruntime and skip it.

**Phase 5: focus + modes integration (S once goal 6 exists).** Wire `focus_start` and
`focus_status` to goal 6's `Focus` service; voice cannot stop focus.

**Phase 6: optional TTS (S).**
```
yay -S --needed piper-tts piper-voices-en-us
```
Speak answers and escalation summaries only.

---

## 7. Risks / unknowns

| Risk | Impact | Mitigation |
|---|---|---|
| **No pretrained "hey computer"**; openWakeWord training stack is bit-rotted | Phase 4 slips | Ship `hey_jarvis` first; Colab/WakeLab route; Rustpotter or whisper-tiny-on-VAD fallbacks |
| False wakes from speakers (Snowball is the default source, and "computer" is common in media) | annoyance, privacy | VAD gating, higher threshold, prefer the Arctis when the headset is the active sink, auto-mute while a game is fullscreen |
| VRAM contention with games (16 GB; LLM + STT ≈ 8 GB) | stutter/OOM in games | `--sleep-idle-seconds`, game-mode force-sleep, CPU `base.en` + fast path only |
| `extra/llama-cpp` versioning ("0.5.0") and the dynamic `ggml-vulkan` backend split are new; the backend might not be picked up | no GPU accel | Phase 0 `--list-devices`; fallback `llama.cpp-vulkan-git` (AUR, Aug 2026) or `ollama-vulkan` |
| RDNA4 RADV regressions in Mesa updates (`vulkan-radeon` 26.2.4 now) | sudden slowdowns | Keep the phase-0 bench script; pin via `IgnorePkg` if needed |
| Qwen3.5 tool-call template quirks in llama-server `--jinja` | malformed calls | We use `response_format: json_schema` (grammar-constrained), not native tool calls; template quirks matter less |
| STT mishears proper nouns (playlist names, "Hyprland", project names) | wrong action | Initial-prompt biasing, enum + fuzzy match, top-3 chooser, plan shown before T1/T2 |
| Endpointing cuts off long requests or waits too long | latency/accuracy | PTT default; adaptive silence (shorter after a complete-sounding command) |
| Python 3.14 wheels for openwakeword deps | install friction | Use the system `python-onnxruntime-cpu` + AUR pure-python `python-openwakeword`; avoid pip into system; venv `--system-site-packages` as fallback |
| `claude -p` semantics drift (`--restricted`, `dontAsk`, `--permission-prompts` are 2026 flags) | escalation breaks or over-permits | Startup check: parse `claude --help` for the flags; refuse escalation if missing; never fall back to looser flags |
| `--max-budget-usd` is a no-op on subscription auth | cost visibility | Show "uses your plan" on the card; keep `--effort low` |
| Spotify fuzzy match picks the wrong playlist ("alt rock" vs "Alt Rock 2019") | wrong music | Show the matched name in the OSD; "no, the other one" reopens the chooser (v2) |
| Focus-mode dependency (goal 6 not built) | `focus_start` missing in v1 | Phase 5; the tool is hidden until `Focus` exists |
| Daemon crash loops | CPU churn | `Voice.qml` restarts with backoff (1, 5, 30 s), then stays off with an error glyph |

**Open questions for the user:**
- PTT bind preference: hold vs tap-to-toggle.
- Is Google OK as the default search URL?
- Should "do work" escalations open in the project's existing claude pane or a new window?
- Is one Colab session acceptable for training the wake word?

---

Sources:
- [Docker: local LLM tool-calling evaluation](https://www.docker.com/blog/local-llm-tool-calling-a-practical-evaluation/)
- [RDNA4 Vulkan vs ROCm 7.2 (runaihome)](https://runaihome.com/blog/rdna4-vulkan-vs-rocm-local-llm-benchmark-2026/)
- [llama.cpp RDNA4 discussion #21043](https://github.com/ggml-org/llama.cpp/discussions/21043)
- [Phoronix: ROCm 7.1 vs RADV for llama.cpp](https://www.phoronix.com/review/rocm-71-llama-cpp-vulkan/2)
- [Gemma 4 vs Qwen 3.5 (MindStudio)](https://www.mindstudio.ai/blog/gemma-4-vs-qwen-3-5-open-weight-comparison)
- [Gemma 4 12B vs Qwen3.5 9B (BetterClaw)](https://www.betterclaw.io/blog/gemma-4-12b-vs-qwen-3-5-9b)
- [openwakeword-colab-2026](https://github.com/alfiedennen/openwakeword-colab-2026)
- [WakeLab](https://gitblind.noratr.app/avalon60/WakeLab)
- [Home Assistant: create a wake word](https://home-assistant.io/voice_control/create_wake_word)
- [Parakeet vs Whisper vs Nemotron (OpenWhispr)](https://openwhispr.com/blog/parakeet-vs-whisper-vs-nemotron)
- [llama.cpp sleep-idle issue #19318](https://github.com/ggml-org/llama.cpp/issues/19318)
- [Arch llama-cpp files](https://archlinux.org/packages/extra/x86_64/llama-cpp/files/)
- [Arch whisper-cpp files](https://archlinux.org/packages/extra/x86_64/whisper-cpp/files/)
