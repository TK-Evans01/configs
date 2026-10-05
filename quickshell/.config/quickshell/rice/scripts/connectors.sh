#!/usr/bin/env bash
# Status checks and login plumbing for the settings › Connections page.
#
#   connectors.sh check <id>          → one line: "<state>\t<detail>"
#                                        state: ok | off | missing | error
#   connectors.sh save <id> <field>   ← secret on stdin, written mode 600
#   connectors.sh login <id>          interactive login (run in a terminal)
#   connectors.sh logout <id>
#
# Details never include secrets (no emails, tokens, account numbers).
# --preview (first argument) or RICE_CONNECTORS_PREVIEW=1: save writes to ~/.cache/rice/connectors-preview/
# instead of ~/.config/rice/, login/logout only print what they would run.
set -uo pipefail
# The shell may start without the login PATH (claude lives in ~/.local/bin).
export PATH="$HOME/.local/bin:$PATH"
here="$(dirname "$(realpath "$0")")"
secrets="$HOME/.config/rice"
preview="${RICE_CONNECTORS_PREVIEW:-0}"
[ "${1:-}" = --preview ] && { preview=1; shift; }
[ "$preview" = 1 ] && secrets="$HOME/.cache/rice/connectors-preview"

out() { printf '%s\t%s\n' "$1" "$2"; exit 0; }
need() { command -v "$1" >/dev/null 2>&1 || out missing "$1 isn't installed"; }

# Preview walk-through: login-based connectors start unconnected; connect /
# save mark them connected, disconnect clears it.
marks="$HOME/.cache/rice/connectors-preview"
preview_check() {
    case "$1" in weather|lyrics|github-ssh|docker) return 1 ;; esac
    [ -e "$marks/$1.connected" ] && out ok "connected (preview)" || out off "not connected (preview)"
}
mark() { [ "$preview" = 1 ] && { install -d -m 700 "$marks"; touch "$marks/$1.connected"; }; return 0; }
unmark() { rm -f "$marks/$1.connected"; }

check() {
    [ "$preview" = 1 ] && preview_check "$1"
    case "$1" in
    claude)
        need claude
        j=$(timeout 15 claude auth status --json 2>/dev/null) || out off "not signed in"
        python3 -c 'import json,sys
d=json.loads(sys.argv[1])
print(("ok" if d.get("loggedIn") else "off")+"\t"+("signed in · "+d.get("authMethod","") if d.get("loggedIn") else "not signed in"))' "$j" ;;
    mullvad)
        need mullvad
        a=$(mullvad account get 2>/dev/null) || out off "not logged in"
        exp=$(sed -n 's/^Expires at: *\([0-9-]*\).*/\1/p' <<<"$a")
        dev=$(sed -n 's/^Device name: *//p' <<<"$a")
        [ -n "$exp" ] && out ok "expires $exp · device ${dev:-?}" || out off "not logged in" ;;
    github)
        need gh
        s=$(gh auth status -h github.com 2>&1) || out off "not signed in"
        u=$(sed -n 's/.*Logged in to github.com account \([^ ]*\).*/\1/p' <<<"$s" | head -1)
        p=$(sed -n 's/.*Git operations protocol: *//p' <<<"$s" | head -1)
        out ok "${u:-signed in} · git over ${p:-https}" ;;
    github-ssh)
        need ssh
        s=$(timeout 10 ssh -n -T -o BatchMode=yes -o ConnectTimeout=5 git@github.com 2>&1 </dev/null)
        u=$(sed -n 's/^Hi \([^!]*\)!.*/\1/p' <<<"$s")
        [ -n "$u" ] && out ok "key accepted for $u" || out off "no key accepted (${s%%$'\n'*})" ;;
    bridge)
        need protonmail-bridge-core
        pgrep -f 'protonmail/bridge/bridge' >/dev/null || out off "Bridge isn't running"
        [ -s "$secrets/proton-bridge.netrc" ] || out off "Bridge runs; IMAP login not saved"
        [ "$preview" = 1 ] && out ok "IMAP login saved (preview)"
        r=$(timeout 20 python3 "$here/proton-mail.py" 2>/dev/null | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: print("error\tno answer"); raise SystemExit
st=d.get("state","error")
print(("ok\t%d unread · %d in inbox" % (d.get("unread",0), d.get("total",0))) if st=="ok" else ("off\t"+st+(": "+d.get("error","") if d.get("error") else "")))')
        out "${r%%$'\t'*}" "${r#*$'\t'}" ;;
    calendar)
        [ -s "$secrets/proton-calendar.url" ] || out off "no share link saved"
        [ "$preview" = 1 ] && out ok "share link saved (preview)"
        # URL via curl's config on stdin, not argv (it's a secret link).
        code=$(printf 'url = "%s"\n' "$(cat "$secrets/proton-calendar.url")" | curl -s -o /dev/null -w '%{http_code}' --max-time 15 -K -)
        [ "$code" = 200 ] && out ok "share link works" || out error "share link answered HTTP $code" ;;
    spotify)
        need spotify_player
        [ -s "$secrets/spotify-client-id" ] || out off "no client id saved"
        [ -s "$HOME/.cache/spotify-player/user_client_token.json" ] || out off "client id saved; not authenticated"
        pgrep -f '^spotify_player -d' >/dev/null && out ok "authenticated · daemon running" || out ok "authenticated · daemon not running" ;;
    discord)
        need discordo
        secret-tool lookup service discordo username token >/dev/null 2>&1 && out ok "token in keyring" || out off "not logged in" ;;
    docker)
        need docker
        docker info >/dev/null 2>&1 && out ok "daemon $(docker info --format '{{.ServerVersion}}' 2>/dev/null)" \
            || { systemctl is-active -q docker && out error "daemon up; you're not in the docker group" || out off "daemon not running"; } ;;
    weather)
        code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "https://api.open-meteo.com/v1/forecast?latitude=0&longitude=0&current=temperature_2m")
        [ "$code" = 200 ] && out ok "Open-Meteo reachable · no account needed" || out error "Open-Meteo answered HTTP $code" ;;
    lyrics)
        code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "https://lrclib.net/api/search?q=test")
        [ "$code" = 200 ] && out ok "lrclib reachable · no account needed" || out error "lrclib answered HTTP $code" ;;
    *) out error "unknown connector $1" ;;
    esac
}

save() {
    id="$1"; field="$2"
    install -d -m 700 "$secrets"
    umask 077
    case "$id/$field" in
    calendar/url)      f=proton-calendar.url ;;
    spotify/clientId)  f=spotify-client-id ;;
    bridge/netrc)      f=proton-bridge.netrc ;;   # stdin: "user\npassword"
    mullvad/account)
        n=$(tr -dc '0-9' </dev/stdin)
        if [ "$preview" = 1 ]; then mark mullvad; echo "preview — would run: mullvad account login <${#n} digits>"; exit 0; fi
        mullvad account login "$n"; exit $? ;;
    *) echo "nothing to save for $id/$field" >&2; exit 2 ;;
    esac
    if [ "$f" = proton-bridge.netrc ]; then
        { read -r user; read -r pass; } </dev/stdin
        # Quoted so spaces / # in the password survive (python's netrc reads quotes).
        printf 'machine 127.0.0.1\nlogin "%s"\npassword "%s"\n' "$user" "$pass" > "$secrets/$f.tmp"
    else
        tr -d '\r\n' </dev/stdin > "$secrets/$f.tmp"
    fi
    chmod 600 "$secrets/$f.tmp" && mv "$secrets/$f.tmp" "$secrets/$f"
    mark "$id"
    echo "saved $secrets/$f"
}

# Interactive logins. In preview they only say what they would do.
run() {
    if [ "$preview" = 1 ]; then echo "preview — would run: $*"; return 0; fi
    "$@"
}
reset_preview() { rm -rf "$marks"; echo "preview reset"; }
login() {
    [ "$preview" = 1 ] && mark "$1"
    case "$1" in
    claude)   run claude auth login ;;
    github)   run gh auth login --web -h github.com -p ssh ;;
    bridge)   # The headless daemon holds the instance lock; stop it for the CLI login.
              run sh -c 'pkill -f protonmail/bridge/bridge; sleep 1; protonmail-bridge-core --cli; setsid -f protonmail-bridge-core --noninteractive >/dev/null 2>&1' ;;
    spotify)  run spotify_player authenticate ;;
    discord)  run discordo ;;
    *) echo "no interactive login for $1" ;;
    esac
}
logout() {
    [ "$preview" = 1 ] && unmark "$1"
    case "$1" in
    claude)   run claude auth logout ;;
    github)   run gh auth logout -h github.com ;;
    mullvad)  run mullvad account logout ;;
    calendar) run rm -f "$secrets/proton-calendar.url" ;;
    bridge)   run rm -f "$secrets/proton-bridge.netrc" ;;
    spotify)  run rm -f "$HOME/.cache/spotify-player/user_client_token.json" ;;
    *) echo "no logout for $1" ;;
    esac
}

cmd="${1:-}"; shift || true
case "$cmd" in
check) check "$1" ;;
save) save "$1" "$2" ;;
login) login "$1" ;;
logout) logout "$1" ;;
reset-preview) reset_preview ;;
*) sed -n '2,13p' "$0"; exit 2 ;;
esac
