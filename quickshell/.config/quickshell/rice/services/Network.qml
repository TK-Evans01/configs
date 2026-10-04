pragma Singleton
import QtQuick
import Quickshell.Io

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

    readonly property var _poll: Process {
        running: true
        command: ["sh", "-c", `
mullvad status 2>/dev/null | sed 's/^/vpn /'

route="$(ip route show default 2>/dev/null | head -n1)"
[ -n "$route" ] && echo "gw $(echo "$route" | awk '{print $3}')"
ping -c1 -W1 -n 1.1.1.1 >/dev/null 2>&1 && echo "online 1" || echo "online 0"

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
`]
        stdout: StdioCollector {
            onStreamFinished: root._parse(this.text)
        }
    }

    function _parse(text) {
        const ls = [];
        let vpn = [];
        for (const line of text.split("\n")) {
            const f = line.trim().split(/\s+/);
            if (f[0] === "vpn") {
                vpn.push(line.replace(/^\s*vpn\s?/, ""));
            } else if (f[0] === "gw") {
                root.gateway = f[1] || "";
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

        const out = vpn.join("\n");
        root.vpnState = (vpn[0] || "").trim();
        const relayM = out.match(/Relay:\s+(\S+)/);
        root.relay = relayM ? relayM[1] : "";
        // "USA, Los Angeles, CA. IPv4: 1.2.3.4" — the address is parsed separately.
        const locM = out.match(/Visible location:\s+(.+)/);
        root.location = locM ? locM[1].split("IPv4:")[0].trim().replace(/\.$/, "") : "";
        const ipM = out.match(/IPv4:\s+(\S+)/);
        root.vpnIp = ipM ? ipM[1] : "";

        root.routed = root.gateway !== "";
        root.links = ls;
    }

    readonly property var _timer: Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: if (!root._poll.running) root._poll.running = true
    }

    readonly property var _toggleProc: Process {
        id: toggleProc
        command: ["sh", "-c", "if [ \"$(mullvad status | head -n1)\" = \"Connected\" ]; then mullvad disconnect; else mullvad connect; fi"]
        running: false
        onRunningChanged: if (!running) root._poll.running = true
    }

    readonly property var _reconnectProc: Process {
        id: reconnectProc
        command: ["mullvad", "reconnect"]
        running: false
        onRunningChanged: if (!running) root._poll.running = true
    }

    function toggle()    { toggleProc.running = true; }
    function reconnect() { reconnectProc.running = true; }
}
