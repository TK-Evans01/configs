# 07 · Focus mode: enforcement layer, profiles, hooks (goal 6)

This builds on what was already decided in `02-mochi-desktop.md` §6.1–6.3:

- a `services/Focus.qml` singleton with a persisted `endsAt`;
- IPC and the SUPER+SHIFT+F bind;
- a Quick Settings tile, a sub-page and a bar countdown;
- app enforcement via Hyprland `openwindow`, hiding to a special workspace by default with close as opt-in;
- idle-pause as an explicit setting.

None of that is repeated here. This document covers **how blocks are enforced**, **profiles**, and the **voice and notification hooks**.

## 0. What the machine looks like today (checked read-only, 2026-10-05)

| Fact | Evidence | Consequence |
|---|---|---|
| DNS path is glibc → `nss-resolve` → systemd-resolved stub | `/etc/nsswitch.conf`: `hosts: mymachines resolve [!UNAVAIL=return] files myhostname dns`; `resolv.conf` = stub 127.0.0.53; `systemd-resolved` active | `files` is **never reached** while resolved runs. /etc/hosts still works only because resolved itself reads it (`ReadEtcHosts=yes` default, "entries in /etc/hosts have highest priority"). |
| Mullvad 2025.14 connected, `wg0-mullvad` link DNS 10.64.0.1 with `~.`; all `mullvad dns` blocklists off | `resolvectl status`, `mullvad dns get` | Mullvad pushes its DNS **into resolved**. It does not bypass resolved's local answers (hosts, static records), so a local sinkhole wins over Mullvad. |
| systemd **262** | `systemctl --version` | Has **`/run/systemd/resolve/static.d/*.rr`** (JSON static RRs, `ReadStaticRecords=yes` by default, added in v261). These take precedence over /etc/hosts. This is a drop-in dir, so the shared /etc/hosts never has to be edited. |
| /etc/hosts is 10,564 lines (331 KB): a permanent Mullvad "social" list plus a custom X/Twitter block, written by hand | `/etc/hosts` markers `BEGIN mullvad social blocklist`, `BEGIN custom blocklist 2026-08-27` | Social media and X are **already permanently blocked**. Focus mode is for the *other* sites (YouTube, Reddit, Twitch, news, HN, Discord web…). Don't let a script rewrite this file. |
| Firefox 157, only browser installed. Profile `y9n7haa7.default-release`, `user.js` symlinked from `~/Projects/configs/firefox/user.js` | `pacman -Q`, `profiles.ini`, `ls -la …/user.js` | One browser to cover. Chromium/Brave/etc. are absent. |
| Firefox DoH is **off**: `network.trr.mode = 5` in `prefs.js` (set via the UI, **not** in our `user.js`) | `prefs.js` | Firefox uses the system resolver today, so DNS blocks bite. Nothing pins this: one click in Settings re-enables DoH and bypasses every DNS block. |
| Firefox clears cookies, history and cache on shutdown (`privacy.clearOnShutdown_v2.*` in user.js) | `user.js` | A Firefox restart means logging into everything again. Any approach that **needs a browser restart to toggle** (enterprise `policies.json` WebsiteFilter) is a poor fit. |
| Extensions: uBlock Origin, Multi-Account Containers, Tree Style Tab, Dark Reader, Proton Pass… No LeechBlock | `extensions/` | uBO could block, but it can only be driven by the shell through managed storage (`policies.json` `3rdparty`), which is read at startup only. |
| Hyprland 0.56.2, new `windowrule = match:…` syntax | `hyprctl version`, `hyprland.conf:209` | |
| Discord = `discord` (class `discord`). **discordo** = `ghostty -e discordo` (SUPER+D in `external/keybindings.conf:16`). Steam = `steam` (SUPER+G) | `hyprland.conf:23,27` | discordo is just another ghostty window: the class is `com.mitchellh.ghostty` and the title is unreliable (see §2.3). |
| dunst **1.13.2** with `set-pause-level` / `get-pause-level` | `dunstctl --help` | Pause *levels* plus a per-rule `override_pause_level` let critical notifications through during DND (§4.2). |
| `polkit` 127, `pkexec` present; `sudo -n` needs a password; ports 80/443 not bound locally; no `inotifywait`, no `conntrack`; `python3` present | | A sinkhole to `0.0.0.0` lands on a closed local port, so it fails fast with "Unable to connect". |

## 1. Site blocking: options compared

### 1.1 Matrix

| # | Mechanism | Scope | Root at toggle time? | Applies how fast | Subdomains | Bypass by | Verdict |
|---|---|---|---|---|---|---|---|
| A | **resolved static records** `/run/systemd/resolve/static.d/rice-focus.rr` written by a root helper | every process using the stub (Firefox with DoH off, Electron/Discord, Steam, curl, discordo) | via one locked-down helper (sudoers/polkit, no prompt) | new lookups: immediately after the helper reloads resolved. Firefox: ≤ `network.dnsCacheExpiration` (60 s). Open connections: not at all (§1.4) | exact names only (list each one) | DoH/DoT in an app, an IP literal, the real `sudo` | **Primary** |
| B | A marked block in **/etc/hosts** via the same helper | same as A | same | resolved re-stats the file, so near-immediate | exact names only | same | Fallback *backend* for A only (if `.rr` misbehaves). It means rewriting a 331 KB hand-curated file: avoid. |
| C | Group-writable include file (no helper) | — | — | — | — | — | **Not possible as stated.** /etc/hosts has no include. A user-writable `.rr` file would let any user process **redirect any domain to any IP** for the whole system, which is a phishing/MITM primitive. Reject. |
| D | dnsmasq / Unbound in front of resolved | system | helper again | fast; wildcards (`address=/youtube.com/`) | **yes** | same | Wildcards are nice, but it adds a daemon and has to coexist with Mullvad's resolved integration. Not installed. Not worth it. |
| E | nftables IP sets | system | helper | instant, **kills open flows** | n/a | CDN IP churn, shared Google/Cloudflare IPs block unrelated sites, everything rides inside the WireGuard tunnel anyway | Reject for sites. |
| F | `mullvad dns set default --block-social-media` (+ `--block-adult-content`, `--block-gambling`) | system, only while connected | **no** (the user owns the daemon setting) | seconds (brief DNS reconfig) | yes, server-side | disconnecting Mullvad | Zero-root **stopgap only**: categories, no custom domains, and social is already in /etc/hosts. |
| G | Firefox `policies.json` `WebsiteFilter {Block, Exceptions}` | Firefox, all profiles | root to write `/etc/firefox/policies/policies.json` | **next Firefox start only.** Policies are read at startup | yes (match patterns) | — | Wrong shape for timed blocks, given the clear-on-shutdown setup. **Do** use policies for one static thing: lock DoH off (§1.3). Not per-profile: the policy file is installation-wide. |
| H | Own small WebExtension ("rice-focus") + native messaging | Firefox only | no | ~instant; can **close/redirect open tabs** | yes (`declarativeNetRequest` `requestDomains` matches subdomains) | disabling the add-on (`about:addons`) | **Fallback / precision layer**, phase 2 |
| I | LeechBlock NG | Firefox | no | instant | yes | disabling it | Good standalone, but its repo has no `storage.managed` / native-messaging hook, so the shell can't drive it. It would be a second, separately configured timer. Reject for integration. |

**Recommendation:**

- **Primary: A**, a root-owned, sudoers-scoped helper that writes sinkhole-only static RRs to `/run`. It works for every app and every future browser, and it is the only thing that also catches Discord's Electron client, discordo and Steam's web views.
- **Fallback: H**, our own tiny Firefox extension, driven by the same state file. It covers what DNS can't: open tabs, wildcard subdomains, a friendly "blocked until 14:25" page, and the case where DoH gets switched back on.
- **F** (Mullvad categories) stays as a documented zero-root stopgap until the helper is installed.

### 1.2 The root helper (`rice-focus-dns`): avoiding prompts safely

Design rules (security):

1. **Root-owned copy.** It is installed to `/usr/local/bin/rice-focus-dns` as `root:root 0755`.
   - Never point sudoers at the stow repo path. A user-writable script with NOPASSWD is root for any process running as `tk`.
   - The repo keeps the source (`rice/scripts/rice-focus-dns`), and re-running the setup line re-installs it.
2. **Sinkhole-only output.** The helper accepts hostnames on stdin and writes **only** `A 0.0.0.0` / `AAAA ::` records.
   - Worst case, a malicious user process can black-hole names (a self-DoS). It can never *redirect* them.
   - Validate every line with `^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$`, cap it at 5,000 names, lowercase and dedupe.
   - Refuse a small protect-list so a typo can't break updates or the VPN: `archlinux.org`, `*.pkgbuild.com`, `mullvad.net`, `proton.me`, `localhost`, and the machine's own hostname.
3. **Atomic write to `/run`** (tmpfs) as tmp file + `rename`. A reboot clears it, and `Focus.qml` re-applies on start if `endsAt` is still in the future.
4. **Self-expiry independent of the shell.** `apply` also runs `systemd-run --unit=rice-focus-expire --on-calendar="<end, local time>" --timer-property=AccuracySec=1s /usr/local/bin/rice-focus-dns clear` (after stopping any older `rice-focus-expire.timer`).
   - If Quickshell crashes or is killed, the block still ends on time. If the machine suspends past the end, the realtime timer fires on resume.
   - This is a transient root timer, not a long-lived process.
5. After every change: `systemctl reload systemd-resolved` (re-reads static records; `resolvectl flush-caches` needs root/polkit `auth_admin_keep` anyway, and the helper is root) + `resolvectl flush-caches`.
6. **Hard mode is enforced by root.** `apply --hard` writes `/run/rice-focus/until`, and then `clear` **refuses** before that time.
   - The sudoers line does **not** allow `clear --force`. The only early exit is a real `sudo` with a password, a deliberate act, which is the right amount of friction for self-control.
7. Subcommands: `apply [--hard] <END_EPOCH>` (names on stdin), `clear`, `status` (prints JSON `{active, until, hard, count}` so the shell can reconcile after a reload).

Polkit vs sudoers:

- **sudoers** with `sudo -n` is the simplest, it is auditable, and it can pin arguments:
  ```
  tk ALL=(root) NOPASSWD: /usr/local/bin/rice-focus-dns apply *, /usr/local/bin/rice-focus-dns clear, /usr/local/bin/rice-focus-dns status
  ```
  `sudo -n` never prompts. It fails fast, and the shell shows "DNS blocking not set up" with the setup line.
- **polkit** (`/etc/polkit-1/rules.d/50-rice-focus.rules`) can do the same:
  ```js
  action.id == "org.freedesktop.policykit.exec" && action.lookup("program") == "/usr/local/bin/rice-focus-dns" && subject.user == "tk" && subject.local && subject.active → polkit.Result.YES
  ```
  Then call it with `pkexec`. Pinning arguments is clumsier (you'd have to parse `command_line`).
- Pick **sudoers**. Polkit's `subject.active` check is a nice extra but not needed.

**Backend switch (fallback B).** The helper has `BACKEND=rr|hosts`. With `hosts` it rewrites only between `# --- BEGIN rice-focus ---` / `# --- END rice-focus ---` markers in /etc/hosts. It holds a lock (`flock /run/rice-focus/lock`) and keeps a `.bak`. Use it only if static records turn out not to hot-reload (verify step in §5).

### 1.3 Gotchas: DoH, caches, open tabs

- **DoH bypasses everything DNS-based.** Firefox DoH (`network.trr.mode` 2/3) talks HTTPS to Cloudflare/NextDNS directly.
  - Mullvad's firewall stops port-53 leaks, but not DoH on 443.
  - Fix: add `user_pref("network.trr.mode", 5);` to `~/Projects/configs/firefox/user.js`. This needs no root and is re-asserted at every start.
  - Optionally lock it with `/etc/firefox/policies/policies.json` → `{"policies":{"DNSOverHTTPS":{"Enabled":false,"Locked":true}}}`. Side effect: about:preferences shows "managed by your organization".
  - Chromium-family browsers (none installed) have "Secure DNS" on by default in some builds: re-check if one is added.
- **HTTPS (type 65) records.** resolved's local data covers A/AAAA only and "will not affect lookups for non-address types". Firefox on Linux fetches HTTPS RRs natively, and those can carry `ipv4hint`.
  - Verify after setup that a blocked YouTube really fails.
  - If it doesn't, set `network.dns.native_https_query false` in user.js (costs ECH). The `.rr` backend could also add an empty/sinkhole answer once type 65 is supported (it isn't today).
- **Firefox DNS cache.** Entries live `network.dnsCacheExpiration` = 60 s (+60 s grace), so a block can take up to ~2 min to bite for a site you just used. `about:networking#dns` → "Clear DNS Cache" is the manual flush. The extension (H) makes this moot.
- **Open connections and tabs.**
  - An already-loaded YouTube tab keeps working. HTTP/2 and HTTP/3 (QUIC) connections are reused with no new DNS lookup, and QUIC idle timeouts are minutes.
  - Service workers can serve cached app shells.
  - DNS blocking only stops *new* connections. Only H (redirecting matching tabs) or killing flows (nftables, rejected) fixes this.
  - Phase 1 mitigation: at focus start, scan Firefox window titles (`hyprctl -j clients`, the title ends `— Mozilla Firefox`) for bundle keywords ("YouTube", "Reddit", "Twitch"). Toast "close the YouTube tab: it keeps working until reloaded".
- **Exact names only.** Neither `.rr` nor hosts does wildcards, so ship curated **site bundles** (§3) that list the real hostnames.
  - Example: `youtube.com www.youtube.com m.youtube.com music.youtube.com youtu.be youtubei.googleapis.com i.ytimg.com yt3.ggpht.com`.
  - Don't block shared Google hosts (`googleapis.com`, `gstatic.com`).
- **resolved cache.** Local static data is answered before any cache or network lookup, and the helper flushes caches anyway.
- **Electron (Discord) and Steam** keep their persistent gateway sockets after a DNS block. DNS only prevents reconnects, which is why apps are handled by the Hyprland layer (§2), not DNS.

### 1.4 Fallback H: `rice-focus` Firefox extension (phase 2)

- MV3, permissions `declarativeNetRequest`, `tabs`, `nativeMessaging`, `storage`.
- On state change it replaces dynamic rules with `{action: redirect → blocked.html?until=…, condition: {requestDomains: […], resourceTypes: ["main_frame","sub_frame"]}}`. It then walks `tabs.query({})` and redirects matching open tabs, which solves the open-tab problem.
- **State source:** a native-messaging host `~/.mozilla/native-messaging-hosts/rice_focus.json` → `rice/scripts/rice-focus-host.py`.
  - The host is ~30 lines. It stats `$XDG_RUNTIME_DIR/rice/focus.json` (written by `Focus.qml`) every 2 s and pushes changes over the length-prefixed stdio protocol.
  - It is a child of Firefox (started by `connectNative`, it dies with the port), so it can't become an orphan. That is consistent with the tether rule.
- **Signing:** release Firefox refuses unsigned add-ons. Sign once as **unlisted** on AMO (`web-ext sign --channel=unlisted`, API keys in `~/.config/rice/amo.env`) and install the `.xpi` from file. That is a one-off per version bump.
- Effort **M** (extension ~150 lines + host + signing chore). Optional; do it after A proves its gaps matter in practice.

## 2. App blocking on Hyprland 0.56

### 2.1 Event path

- `Quickshell.Hyprland` exposes `Hyprland.rawEvent(HyprlandEvent event)` (`event.name`, `event.data`, `event.parse(n)`) on socket2.
- `openwindow>>ADDR,WORKSPACE,CLASS,TITLE`: use `parse(4)` so commas in titles stay in the last field. `ADDR` has no `0x`; dispatchers need `address:0x<ADDR>`.
- Put this in a new `services/FocusApps.qml` (or inside `Focus.qml`), not in `services/Hyprland.qml`, which is a thin wrapper and should stay one:

```qml
Connections {
    target: Hypr.Hyprland
    enabled: Focus.blocking            // phase === "focus" && profile.apps.length
    function onRawEvent(ev) {
        if (ev.name === "openwindow") {
            const [addr, ws, cls, title] = ev.parse(4);
            root.consider("0x" + addr, cls, cls, title, ws);   // class == initialClass at map time
        } else if (ev.name === "windowtitlev2") {           // title rules only (discordo fallback)
            const [addr, title] = ev.parse(2);
            root.considerTitle("0x" + addr, title);
        } else if (ev.name === "activespecial" && Focus.hard) {
            if (ev.parse(2)[0] === "special:focus") Hyprland.dispatch("togglespecialworkspace focus");
        }
    }
}
```

- **Matching:** each app rule is `{field: "class"|"initialClass"|"title", re: "…"}`, compiled once per profile. Default to `initialClass`, because some apps (Steam's game windows, browsers' PWA windows) change `class` after mapping.
- **Action:**
  - `hide` (default): `movetoworkspacesilent special:focus,address:0x…`. Remember `{addr: originalWorkspace}` and restore them all at the end, with a toast "restored 3 windows".
  - `close`: `closewindow address:0x…` (opt-in per rule).
  - `kill`: a per-rule `exec` such as `steam -shutdown` (opt-in) for apps whose background activity is the problem.
- **Hard mode** re-hides the special workspace if the user toggles it open (`activespecial` above).
- **Already-open windows at focus start:** sweep once with `Process { command: ["hyprctl","-j","clients"] }`. Parse it and run the same `consider()` on each client's `address/class/initialClass/title`.
  - Prefer this over `Hyprland.toplevels[*].lastIpcObject`: that one is populated asynchronously after `refreshToplevels()`, while a one-shot `hyprctl -j` gives deterministic data.
- **No-flash alternative** (not default): a sourced `~/.config/hypr/focus-rules.conf` with `windowrule = match:initial_class ^(discord)$, workspace special:focus silent`, toggled by rewriting the file and running `hyprctl reload`.
  - It applies before the first frame, but `reload` re-applies monitors and all config. That is too heavy to do on every pomodoro phase.
  - Keep it in mind only if the 1-frame flash of a hidden app bothers you.

### 2.2 Known classes (seed list for the profile editor)

| App | Match | Notes |
|---|---|---|
| Discord (Electron) | `initialClass ^discord$` | Hiding leaves it connected, and its notifications still arrive. Combine with notification suppression for `appname=discord` (§4.2), or use `close` for this rule. |
| Steam client | `initialClass ^steam$` | Hiding is fine. The SUPER+G bind still launches it, then it gets hidden. |
| Steam games | `initialClass ^steam_app_\d+$`, plus `^gamescope$` | Native games use their own class. Add per game from "pick running window". |
| Firefox windows | **do not match** | Sites are DNS/extension territory. Hiding the browser is too blunt. |
| **discordo in ghostty** | see 2.3 | |

### 2.3 discordo (TUI inside ghostty)

- **Title is unreliable.** discordo doesn't promise to set an OSC title, and ghostty's shell-integration title is the running command only when launched through a shell.
- **Recommended: give it its own class.** Change `hyprland.conf:23` to `$discord = ghostty --class=dev.rice.discordo -e discordo` (ghostty requires a valid GTK app-id).
  - Then match `initialClass ^dev\.rice\.discordo$`. This is deterministic, and the window rule doubles as a nice Hyprland hook.
  - Cost: a separate ghostty instance (ghostty's single-instance logic is keyed on class), so it adds a few tens of MB while open.
- **discordo started by hand inside the main tmux session** can't be seen by Hyprland. Optional sweep: `tmux list-panes -a -F '#{pane_id} #{pane_current_command}'`. If `discordo` is found, toast or `tmux send-keys -t <pane> C-c` (opt-in). Effort S.

### 2.4 Launcher and keybinds

- **Launcher (`services/Launcher.qml`):** add `Focus.blocksEntry(e)`. It matches the entry's `StartupWMClass` (if exposed), `e.id` and the command basename (`bin`, already computed in `search()`) against the profile's app rules plus an optional `launcherIds` list.
  - In `LauncherWindow.qml`, show the row **dimmed with 󰌾 and "until 14:25"** instead of hiding it (hiding feels like a bug).
  - `launch()` returns early with a toast, and the same check is reused by the voice assistant's "open X" tool.
  - Effort S.
- **Keybinds:** SUPER+D / SUPER+G `exec` directly from Hyprland, bypassing the shell. Options:
  - (a) Do nothing. The `openwindow` handler hides the window within one frame. **Default.**
  - (b) Route launches through the shell: `bind = $mainMod, G, exec, qs -c rice ipc call rice launch steam` → `Launcher`-level check. Cleanest long-term, since it gives a single policy point. S, but touches `external/keybindings.conf` and `Keybinds.qml`'s `_describe` regex (`ipc call rice (\w+)` already matches).
  - (c) `hyprctl keyword unbind` at start / `keyword bind` at end. Fragile (the state is lost on `hyprctl reload`). Reject.

### 2.5 Ending early: soft vs hard

| | Soft (default for "study") | Hard (opt-in per profile) |
|---|---|---|
| Stop button / `focusStop` IPC | immediate, no penalty (Mochi's non-punitive rule) | opens "end early?": type a phrase shown on screen (e.g. *"i am choosing to stop"*), then a **60 s countdown** you can cancel. Phrase + wait defeats reflexive quitting without trapping you. |
| Temporary pass | "5 min pass" for one site bundle or app, once per session | none |
| DNS helper `clear` | allowed | **refused by root until `until`**. Real `sudo rice-focus-dns clear --force` is the escape hatch. |
| Special workspace | can be opened | re-hidden on `activespecial` |
| Voice assistant | may stop (with spoken confirm) | **cannot stop**. It answers "hard focus ends at 14:25". |
| Shell reload / crash | restores from persisted `endsAt` | same, and DNS stays blocked via the root timer even if the shell never comes back |

Breaks in a multi-round plan (`02` §6.1) **lift** site and app blocks. The helper is called per phase with the phase's end, so the expiry timer always matches the phase.

## 3. Profiles

### 3.1 Storage

- Profiles live in the planned persisted store (`01-impasto.md` §6.1: `services/Prefs.qml`, FileView + JsonAdapter at `~/.local/state/quickshell/rice/prefs.json`) under a `focus` key.
- If the store splits config from state, profiles belong to the **config** half (`~/.config/rice/settings.json`): they are user-authored and worth backing up. Runtime (`phase`, `endsAt`, `profileId`, `hiddenWindows`) stays in the state file from `02` §6.1.
- Site bundles ship as repo defaults in `rice/config/focus-bundles.json`, because the hostname lists are maintenance data. User additions go in the store.

```json
"focus": {
  "defaultProfile": "deep",
  "graceSeconds": 60, "endPhrase": "i am choosing to stop",
  "profiles": [
    { "id": "deep",  "label": "Deep work", "icon": "󰽥", "minutes": 50, "breakMin": 10, "rounds": 2,
      "mode": "hard", "bundles": ["youtube","reddit","twitch","news","discord-web"], "sites": [],
      "apps": [{"field":"initialClass","re":"^(discord|steam|steam_app_\\d+|dev\\.rice\\.discordo)$","action":"hide"}],
      "dnd": "focus", "playlist": null, "pauseOnLock": false },
    { "id": "study", "label": "Study", "icon": "󰑴", "minutes": 25, "breakMin": 5, "rounds": 4,
      "mode": "soft", "bundles": ["youtube","reddit","twitch"], "apps": [/* discord, discordo */],
      "dnd": "focus", "playlist": "spotify:playlist:<lofi id>" },
    { "id": "gaming-off", "label": "Gaming off", "icon": "󰊴", "minutes": 120, "rounds": 1, "mode": "soft",
      "bundles": ["twitch","steam-web"], "apps": [{"field":"initialClass","re":"^(steam|steam_app_\\d+|gamescope)$","action":"close"}],
      "dnd": "off" }
  ]
}
```

- `dnd`: `"off"` | `"focus"` (critical + allow-listed apps only) | `"total"`.
- `playlist`: a Spotify id passed to `Spotify.playPlaylist(id)` (`services/Spotify.qml:122`) at the start. Only start it if nothing is playing (`Mpris`). At the end, leave the music alone.
- The **effective blocklist** is the union of the bundles' hostnames and `sites`, validated with the same regex as the helper, so the UI never sends something the helper will reject.

### 3.2 Settings page (in the planned settings shell, goal 3)

The "Focus" section is a two-column layout like the other settings sections.

**Left column:** the profile list, with add / duplicate / delete and "set default".

**Right column:** the editor:
- Name and icon.
- Steppers for minutes, break and rounds (reuse the `02` §6.3 clamps).
- A soft/hard segmented switch, with a one-line explanation of what hard means.
- **Sites:** bundle chips (toggle), plus a domain text area with live validation (red underline on bad lines). It shows the expanded hostname count ("43 names").
- **Apps:** rows of `field / regex / action`.
  - Button "add from open windows" lists the classes in `Hyprland.toplevels`.
  - Button "add from apps" picks from `DesktopEntries` (`StartupWMClass` → `initialClass`).
- **DND level:** three-way.
- **Playlist:** a picker from `Spotify.playlists`.

**Footer:** a status line for the helper (`sudo -n rice-focus-dns status`):
- "DNS blocking ready".
- Or "not set up: copy setup command" (`wl-copy` of the §5.2 line).
- A "Test" button runs `resolvectl query <first host>` and shows whether it answers `0.0.0.0`.

The Quick Settings Focus sub-page (`02` §6.3) only shows profile chips plus duration override. Editing happens only here.

## 4. Integration hooks

### 4.1 Voice assistant (goal 5)

- **IPC (added to the `rice` IpcHandler in `shell.qml`):**
  - `focus(profile: string, minutes: int)`: empty profile means default, 0 minutes means the profile's own duration.
  - `focusStop(): string`: returns `"stopped"`, `"needs-confirm"` (hard), or `"none"`.
  - `focusStatus(): string`: JSON `{active, profile, phase, remainingSec, endsAt, hard}`, so the assistant can say "38 minutes left in deep work".
  - `focusProfiles(): string`: ids and labels, used as the assistant's slot vocabulary.
- **Rule-table fast path** (before the LLM, per `02` §5):
  - `^(start|begin|enter) (?:(?<p>[\w ]+?) mode|focus(?: mode)?)(?: for (?<n>\d+) ?(?<u>min|minutes|hours?))?$`
  - `p` is fuzzy-matched against profile labels ("study mode", "deep work"). Hours are converted to minutes.
  - "stop focus", "how long left" map to `focusStop` / `focusStatus`.
- **Policy:**
  - Starting is safe and needs no confirmation.
  - Stopping soft needs a spoken confirm. Stopping hard is refused.
  - During focus, the assistant's own "open app" / "web search" tools go through `Launcher.launch` / `Focus.blocksEntry`, so it reports "Discord is blocked until 14:25" instead of fighting the blocker.
  - A web search for a blocked site would hit the DNS block anyway.

### 4.2 Notifications

**Today (dunst 1.13):**

- Focus start sets `dunstctl set-pause-level 50` (not `set-paused true`, which is level 100). Focus end restores the previous level, read once with `get-pause-level`.
- Add to `dunstrc` (dunst config lives outside the rice; the user owns that edit):
  ```ini
  [focus-critical]
  urgency = critical
  override_pause_level = 90
  [focus-calendar]
  appname = rice-calendar
  override_pause_level = 60
  ```
- Profile `dnd: "total"` uses level 100, so even critical notifications wait.
- **Deferred summary:** dunst keeps paused notifications in its waiting queue (`dunstctl count waiting`) and can't list them.
  - At the end, `Focus` reads the count, shows one toast "focus done · 12 notifications held", then restores the level.
  - dunst then releases them, capped by its `notification_limit`.

**After the in-shell `NotificationServer` lands (`00-self-audit` #5 / `01` §6.2):**

- `Notifications.present(n)` asks `Focus.allowsToast(n)`. That is true for critical, for the profile's allow-list appnames, and for the calendar.
- Every notification is still **recorded** (impasto's "suppress toasts, not history").
- At the end, show a grouped summary toast: "while you focused: Discord 7 · Mail 3 · System 1". Clicking it opens the notification side panel filtered to `since: focusStartedAt`. This replaces the dunst pause logic, which is why `Focus` should call a `Notifications.setFocusPolicy()` seam rather than `dunstctl` directly.

`services/Mail.qml` uses `notify-send` today. That needs no change; it is covered by either path.

## 5. Implementation plan

### 5.1 Files

| Piece | Files (rice = `quickshell/.config/quickshell/rice/`) | Effort |
|---|---|---|
| Timer core (from `02` §6.1) | `services/Focus.qml`, `services/qmldir`, `shell.qml` IPC | S (decided elsewhere) |
| **Enforcement orchestrator**: on phase change, compute the effective profile, call helper `apply/clear` via `sudo -n` `Process`, write `$XDG_RUNTIME_DIR/rice/focus.json` for the extension, reconcile with `status` at startup | `services/Focus.qml` (or `services/FocusBlock.qml` to keep the timer pure) | M |
| Root helper + sudoers drop-in source | new `rice/scripts/rice-focus-dns` (bash, ~120 lines: validate, protect-list, `.rr` JSON via `printf`, `systemd-run` expiry, reload/flush, `--hard` until-file, `status`), new `rice/scripts/rice-focus.sudoers` | M |
| App enforcement (`openwindow`, sweep, hide/restore, hard re-hide) | new `services/FocusApps.qml` | M |
| discordo class | `hypr/.config/hypr/hyprland.conf:23` | S |
| Launcher gating | `services/Launcher.qml` (`blocksEntry`, `launch` guard), `modules/launcher/LauncherWindow.qml` (dimmed row) | S |
| Optional bind routing | `hypr/.config/hypr/external/keybindings.conf`, `shell.qml` `launch(id)` IPC | S |
| Firefox DoH pin | `firefox/user.js` (+ optional root policy in setup line) | S |
| Profiles + bundles | `config/focus-bundles.json`, `focus` key in planned `services/Prefs.qml` | S |
| Settings page "Focus" | new `modules/settings/FocusSection.qml` (in the planned settings shell) | M |
| End-early dialog (phrase + 60 s) | new `modules/quicksettings/FocusEndDialog.qml` (or a lock-style layer surface for hard mode) | S |
| Notifications: dunst pause-level now, `allowsToast` seam later | `services/Desktop.qml` (pause-level helpers), `~/.config/dunst/dunstrc` (user) → later `services/Notifications.qml` | S now / S later |
| Voice hooks | `shell.qml` IPC (`focusStatus`, `focusProfiles`), the assistant's intent table | S |
| Firefox extension (phase 2) | new `rice/extras/firefox-focus/` (manifest, background.js, blocked.html), `rice/scripts/rice-focus-host.py`, `~/.mozilla/native-messaging-hosts/rice_focus.json` | M |

### 5.2 One-time root setup (hand to the user; never run by us)

After the helper exists in the repo, this single command:

- installs a **root-owned copy**;
- adds a sudoers line that allows exactly the three subcommands, syntax-checked with `visudo -c` (if the check fails, it removes the file and does not leave a broken sudoers);
- creates the static.d dir;
- pins Firefox DoH off via policy.

```sh
sudo sh -c 'set -e; R=/home/tk/Projects/configs/quickshell/.config/quickshell/rice/scripts; install -o root -g root -m 0755 "$R/rice-focus-dns" /usr/local/bin/rice-focus-dns; install -o root -g root -m 0440 "$R/rice-focus.sudoers" /etc/sudoers.d/rice-focus; visudo -cf /etc/sudoers.d/rice-focus || { rm -f /etc/sudoers.d/rice-focus; exit 1; }; install -d -m 0755 /run/systemd/resolve/static.d; install -d -m 0755 /etc/firefox/policies; [ -e /etc/firefox/policies/policies.json ] || printf "%s\n" "{\"policies\":{\"DNSOverHTTPS\":{\"Enabled\":false,\"Locked\":true}}}" > /etc/firefox/policies/policies.json'
```

- The helper itself does `mkdir -p /run/systemd/resolve/static.d`, since `/run` is recreated at boot.
- **Re-run the same line after editing the helper.** The repo copy is never executed as root.
- **Verify once:**
  ```sh
  echo youtube.com | sudo -n rice-focus-dns apply $(( $(date +%s) + 120 )) && resolvectl query youtube.com
  ```
  It should answer `0.0.0.0`. Wait for the expiry timer or run `sudo -n rice-focus-dns clear`.
  - If resolved ignores new `.rr` files until restart even after `reload`, switch the helper to `BACKEND=hosts`.

### 5.3 Risks

- **Static-record hot reload is unverified.** It is new in systemd 261. Mitigations: the helper reloads resolved, and the `hosts` backend is the fallback.
- **Open tabs and live sockets survive DNS blocks.** The phase-1 title-scan toast is a nudge only. Extension H is the real fix.
- **DoH re-enabled = silent bypass.** Pin it via user.js plus the optional policy. The Settings "Test" button also catches a broken setup.
- **Over-blocking shared hosts** (`googleapis.com`, `discord.gg` used by invites in other apps, `steampowered.com` used by Steam login). Curate bundles conservatively, and keep the protect-list in the helper.
- **Hidden apps keep running.** Hidden Discord still pings, and Steam still downloads. Pair app rules with notification policy, and offer `close`/`kill` per rule.
- **Two-monitor special workspace:** `special:focus` shows on whichever monitor toggles it. Restore uses the remembered workspace, so nothing ends up lost.
- **sudoers foot-gun:** NOPASSWD must only ever point at the root-owned `/usr/local/bin` copy. Note it in a comment inside `rice-focus.sudoers`.
- **Suspend/lock:** the expiry timer and `endsAt` are wall-clock based. Suspend time counts toward the block, consistent with the "keep running on lock" default from `02`.

## 6. Don't

- Don't make /etc/hosts or any `.rr` file user-writable. That turns a self-control tool into a system-wide redirect primitive.
- Don't use `policies.json` `WebsiteFilter` for timed blocks. It needs a restart, and restarts wipe the session here.
- Don't block with nftables IP sets. Shared CDNs cause collateral blocks, and the traffic is all inside WireGuard anyway.
- Don't hide or close Firefox windows as "site blocking".
- Don't let the voice assistant or a reload be a way out of hard mode.
- Don't rely on the shell process for expiry. The root transient timer guarantees blocks end even if Quickshell is dead.
