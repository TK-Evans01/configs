pragma Singleton
import QtQuick
import Quickshell.Io
import "../config"

// Whole-network state: internet reachability, Mullvad VPN, and every physical
// link (wifi / ethernet / USB tether). Virtual bridges and tunnels are skipped;
// the tunnel shows up as the VPN row instead.
QtObject {
    id: root

    // VPN
    property string vpnState: ""
    property string relay: ""
    property string location: ""
    property string vpnIp: ""

    readonly property bool connected: vpnState === "Connected"
    readonly property bool connecting: vpnState.startsWith("Connecting")

    // Internet
    property bool routed: false     // a default route exists
    property bool online: false     // that route actually reaches the internet
    property string gateway: ""

    // [{ name, kind, up, ip, extra, uplink }] where kind is wifi | eth | usb.
    // uplink = this link carries the default route; everything else is LAN-only.
    property var links: []

    readonly property bool anyLinkUp: {
        for (const l of links) if (l.up) return true;
        return false;
    }

    // The reachability ping runs every 6th poll (30 s) while online, but on
    // every poll while offline or right after the default route changed.
    property bool _pingNow: true
    property bool _routeChanged: false

    // VPN: mullvad pushes its state (JSON, one line per change).
    readonly property var _vpn: Process {
        running: true
        command: Settings.tether.concat(["mullvad", "status", "-j", "listen"])
        stdout: SplitParser {
            onRead: line => {
                let d = null;
                try { d = JSON.parse(line); } catch (e) { return; }
                const st = d.state || "";
                root.vpnState = st ? st.charAt(0).toUpperCase() + st.slice(1) : "";
                const loc = d.details && d.details.location ? d.details.location : null;
                root.relay = loc && loc.hostname ? loc.hostname : "";
                root.location = loc ? [loc.country, loc.city].filter(x => x).join(", ") : "";
                root.vpnIp = loc && loc.ipv4 ? loc.ipv4 : "";
            }
        }
        // Daemon restarted / not running yet: try again shortly.
        onRunningChanged: if (!running) _vpnRetry.restart()
    }
    readonly property var _vpnRetry: Timer { interval: 5000; onTriggered: root._vpn.running = true }

    // Links / addresses / routes: the kernel tells us when they change.
    readonly property var _mon: Process {
        running: true
        command: Settings.tether.concat(["ip", "-o", "monitor", "link", "address", "route"])
        stdout: SplitParser {
            onRead: line => {
                if (/default|route/.test(line)) root._routeChanged = true;
                root._debounce.restart();
            }
        }
        onRunningChanged: if (!running) _monRetry.restart()
    }
    readonly property var _monRetry: Timer { interval: 5000; onTriggered: root._mon.running = true }
    readonly property var _debounce: Timer { interval: 600; onTriggered: root.refresh(root._routeChanged) }

    // Re-read links (+ ping when asked). If one is already running, run once more after.
    property bool _again: false
    function refresh(ping) {
        if (ping) _pingNow = true;
        if (_poll.running) { _again = true; return; }
        _routeChanged = false;
        _poll.running = true;
    }

    readonly property var _poll: Process {
        command: ["sh", "-c", `
route="$(ip route show default 2>/dev/null | head -n1)"
[ -n "$route" ] && echo "gw $(echo "$route" | awk '{print $3}')"
if [ "$1" = 1 ]; then ping -c1 -W1 -n 1.1.1.1 >/dev/null 2>&1 && echo "online 1" || echo "online 0"; fi

for i in /sys/class/net/*; do
  n="$(basename "$i")"
  case "$n" in lo|docker*|veth*|br-*|virbr*|wg*|tun*|tap*) continue ;; esac
  [ -e "$i/device" ] || continue
  state="$(cat "$i/operstate" 2>/dev/null)"
  ip4="$(ip -br -4 addr show "$n" 2>/dev/null | awk '{print $3}')"
  if [ -d "$i/wireless" ]; then
    kind=wifi
    extra="$(iwgetid -r 2>/dev/null)"
  elif readlink -f "$i/device" | grep -q usb; then
    kind=usb
    extra="$(cat "$i/speed" 2>/dev/null)"
  else
    kind=eth
    extra="$(cat "$i/speed" 2>/dev/null)"
  fi
  [ -z "$ip4" ] && ip4="-"
  [ -z "$extra" ] && extra="-"
  uplink=no
  [ -n "$route" ] && [ "$(echo "$route" | awk '{print $5}')" = "$n" ] && uplink=yes
  echo "link $n $kind $state $ip4 $extra $uplink"
done
`, "sh", root._pingNow ? "1" : "0"]
        stdout: StdioCollector {
            onStreamFinished: root._parse(this.text)
        }
        onRunningChanged: if (!running) { root._pingNow = false; if (root._again) { root._again = false; running = true; } }
    }

    function _parse(text) {
        const ls = [];
        let gw = "";
        for (const line of text.split("\n")) {
            const f = line.trim().split(/\s+/);
            if (f[0] === "gw") {
                gw = f[1] || "";
            } else if (f[0] === "online") {
                root.online = f[1] === "1";
            } else if (f[0] === "link" && f.length >= 7) {
                ls.push({
                    name: f[1],
                    kind: f[2],
                    up: f[3] === "up" || f[3] === "unknown",
                    ip: f[4] === "-" ? "" : f[4],
                    extra: f[5] === "-" || f[5] === "-1" ? "" : f[5],
                    uplink: f[6] === "yes"
                });
            }
        }

        const moved = gw !== root.gateway;
        root.gateway = gw;
        root.routed = gw !== "";
        if (!root.routed) root.online = false;
        if (JSON.stringify(ls) !== JSON.stringify(root.links)) root.links = ls;
        // New default route: check reachability right away.
        if (moved && root.routed) root.refresh(true);
    }

    // Reachability: once a minute while online, every 10 s while not.
    readonly property var _timer: Timer {
        interval: root.online ? 60000 : 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh(true)
    }

    readonly property var _toggleProc: Process {
        id: toggleProc
        command: ["sh", "-c", "if [ \"$(mullvad status | head -n1)\" = \"Connected\" ]; then mullvad disconnect; else mullvad connect; fi"]
        running: false
        onRunningChanged: if (!running) root.refresh(false)
    }

    readonly property var _reconnectProc: Process {
        id: reconnectProc
        command: ["mullvad", "reconnect"]
        running: false
        onRunningChanged: if (!running) root.refresh(false)
    }

    function toggle()    { toggleProc.running = true; }
    function reconnect() { reconnectProc.running = true; }
}
