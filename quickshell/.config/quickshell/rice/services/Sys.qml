pragma Singleton
import QtQuick
import Quickshell.Io
import "../config"

// Everything the System widget shows: CPU, GPU, RAM, disks, load. Live
// numbers are direct file reads (/proc, /sys) every 2 s — no processes;
// disks via df once a minute. Lines are "key value…" for one parser.
QtObject {
    id: root

    // CPU
    property int cpuPercent: 0
    property real cpuTemp: 0
    property string cpuModel: ""
    property int cpuCores: 0

    // GPU (amdgpu / any drm card exposing gpu_busy_percent)
    property int gpuPercent: 0
    property real gpuTemp: 0
    property real gpuVramUsed: 0
    property real gpuVramTotal: 0
    property string gpuModel: ""

    // Memory, in bytes
    property real memUsed: 0
    property real memTotal: 0
    property real swapUsed: 0
    property real swapTotal: 0
    readonly property int memPercent: memTotal > 0 ? Math.round(memUsed * 100 / memTotal) : 0

    property int procs: 0
    property string kernel: ""
    property string host: ""
    property string loadAvg: ""

    // Rolling samples (oldest first) for sparklines.
    property var cpuHistory: []
    property var gpuHistory: []
    property var memHistory: []
    function _push(list, v) {
        const out = list.concat([v]);
        return out.length > Settings.historySize ? out.slice(out.length - Settings.historySize) : out;
    }


    // [{ target, size, used, percent }]
    property var disks: []

    property var _prevCpu: null

    function fmtBytes(b) {
        if (!b) return "0 B";
        const u = ["B", "K", "M", "G", "T"];
        let i = 0;
        while (b >= 1024 && i < u.length - 1) { b /= 1024; i++; }
        return (b >= 100 || i === 0 ? Math.round(b) : b.toFixed(1)) + u[i];
    }

    // Static bits + where the live numbers live. Run once at startup.
    readonly property var _once: Process {
        running: true
        command: ["sh", "-c", `
awk -F': ' '/^model name/{print "cpumodel", $2; exit}' /proc/cpuinfo
echo "cores $(nproc)"
echo "kernel $(uname -r)"
echo "host $(cat /etc/hostname 2>/dev/null || uname -n)"
lspci -mm -d ::0300 2>/dev/null | head -n1 | awk -F'"' '{print $6}' |
  sed -E 's/.*\\[([^]]*)\\].*/\\1/; s@/.*@@; s/^/gpumodel /'
for h in /sys/class/hwmon/*; do
  case "$(cat "$h/name" 2>/dev/null)" in
    k10temp|coretemp|zenpower) [ -r "$h/temp1_input" ] && echo "path cputemp $h/temp1_input" && break ;;
  esac
done
for d in /sys/class/drm/card*/device; do
  [ -r "$d/gpu_busy_percent" ] || continue
  echo "path gpu $d/gpu_busy_percent"
  [ -r "$d/mem_info_vram_used" ] && echo "path vramused $d/mem_info_vram_used" && echo "vramtotal $(cat "$d/mem_info_vram_total")"
  for h in "$d"/hwmon/hwmon*; do [ -r "$h/temp1_input" ] && echo "path gputemp $h/temp1_input" && break; done
  break
done
`]
        stdout: StdioCollector {
            onStreamFinished: root._parse(this.text)
        }
    }

    // Live numbers: plain file reads every 2 s, no processes. Paths for
    // sensors come from _once.
    property var _paths: ({})
    component Src: FileView { blockLoading: true; printErrors: false }
    readonly property var _stat: Src { path: "/proc/stat" }
    readonly property var _meminfo: Src { path: "/proc/meminfo" }
    readonly property var _loadavg: Src { path: "/proc/loadavg" }
    readonly property var _cpuTempF: Src { path: root._paths.cputemp || "" }
    readonly property var _gpuF: Src { path: root._paths.gpu || "" }
    readonly property var _vramF: Src { path: root._paths.vramused || "" }
    readonly property var _gpuTempF: Src { path: root._paths.gputemp || "" }
    function _read(f) { if (!f.path) return ""; f.reload(); return f.text(); }

    function _sample() {
        const out = [];
        out.push(_read(_stat).split("\n")[0]);
        const mem = {};
        for (const l of _read(_meminfo).split("\n")) { const m = /^(\w+):\s+(\d+)/.exec(l); if (m) mem[m[1]] = Number(m[2]) * 1024; }
        out.push("mem " + mem.MemTotal + " " + (mem.MemTotal - mem.MemAvailable));
        out.push("swap " + mem.SwapTotal + " " + (mem.SwapTotal - mem.SwapFree));
        const la = _read(_loadavg).trim().split(" ");
        out.push("load " + la.slice(0, 3).join(" "));
        // "running/total" scheduling entities (threads).
        if (la[3]) out.push("procs " + la[3].split("/")[1]);
        if (_cpuTempF.path) out.push("cputemp " + _read(_cpuTempF).trim());
        if (_gpuF.path) out.push("gpu " + _read(_gpuF).trim());
        if (_vramF.path) out.push("vramused " + _read(_vramF).trim());
        if (_gpuTempF.path) out.push("gputemp " + _read(_gpuTempF).trim());
        _parse(out.join("\n"));
    }

    // Disks change slowly: df once a minute.
    readonly property var _df: Process {
        running: true
        command: ["sh", "-c", "df -B1 -x tmpfs -x devtmpfs -x efivarfs -x overlay -x squashfs --output=target,size,used 2>/dev/null | tail -n +2 | awk 'NF==3 {print \"disk\", $1, $2, $3}'"]
        stdout: StdioCollector { onStreamFinished: root._parse(this.text) }
    }
    readonly property var _dfTimer: Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: if (!root._df.running) root._df.running = true
    }

    function _parse(text) {
        const ds = [];
        for (const line of text.trim().split("\n")) {
            const f = line.trim().split(/\s+/);
            switch (f[0]) {
            case "cpu": {
                const n = f.slice(1).map(Number);
                const idle = n[3] + n[4];
                const total = n.reduce((a, b) => a + b, 0);
                if (root._prevCpu) {
                    const dt = total - root._prevCpu.total;
                    const di = idle - root._prevCpu.idle;
                    root.cpuPercent = dt > 0 ? Math.round((1 - di / dt) * 100) : 0;
                }
                root._prevCpu = { total, idle };
                break;
            }
            case "cputemp":  root.cpuTemp = Number(f[1]) / 1000; break;
            case "cpumodel":
                root.cpuModel = f.slice(1).join(" ")
                    .replace(/\(R\)|\(TM\)/g, "")
                    .replace(/\s*\d+-Core Processor/, "")
                    .replace(/\s+CPU.*$/, "")
                    .trim();
                break;
            case "cores":    root.cpuCores = Number(f[1]); break;
            case "gpu":      root.gpuPercent = Number(f[1]); break;
            case "gputemp":  root.gpuTemp = Number(f[1]) / 1000; break;
            case "gpumodel": root.gpuModel = f.slice(1).join(" "); break;
            case "vramused": root.gpuVramUsed = Number(f[1]); break;
            case "vramtotal": root.gpuVramTotal = Number(f[1]); break;
            case "path": { const p = Object.assign({}, root._paths); p[f[1]] = f.slice(2).join(" "); root._paths = p; break; }
            case "mem":      root.memTotal = Number(f[1]); root.memUsed = Number(f[2]); break;
            case "swap":     root.swapTotal = Number(f[1]); root.swapUsed = Number(f[2]); break;
            case "procs":    root.procs = Number(f[1]); break;
            case "load":     root.loadAvg = f.slice(1).join(" "); break;
            case "kernel":   root.kernel = f[1] || ""; break;
            case "host":     root.host = f[1] || ""; break;
            case "disk": {
                const size = Number(f[2]), used = Number(f[3]);
                if (size > 0) ds.push({ target: f[1], size, used, percent: Math.round(used * 100 / size) });
                break;
            }
            }
        }
        if (ds.length) root.disks = ds;
        if (/^cpu /m.test(text) && root._prevCpu) {
            root.cpuHistory = root._push(root.cpuHistory, root.cpuPercent);
            root.gpuHistory = root._push(root.gpuHistory, root.gpuPercent);
            root.memHistory = root._push(root.memHistory, root.memPercent);
        }
    }

    readonly property var _timer: Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: root._sample()
    }
}
