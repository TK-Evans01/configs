pragma Singleton
import QtQuick
import Quickshell.Io

// One poller for everything the System widget shows: CPU, GPU, RAM, disks,
// process count. Emits "key value..." lines so parsing stays line-oriented.
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

    // Static bits: model strings and core count. Read once at startup.
    readonly property var _once: Process {
        running: true
        command: ["sh", "-c", `
awk -F': ' '/^model name/{print "cpumodel", $2; exit}' /proc/cpuinfo
echo "cores $(nproc)"
lspci -mm -d ::0300 2>/dev/null | head -n1 | awk -F'"' '{print $6}' |
  sed -E 's/.*\\[([^]]*)\\].*/\\1/; s@/.*@@; s/^/gpumodel /'
`]
        stdout: StdioCollector {
            onStreamFinished: root._parse(this.text)
        }
    }

    readonly property var _poll: Process {
        running: true
        command: ["sh", "-c", `
head -n1 /proc/stat | sed 's/^cpu /cpu /'
for h in /sys/class/hwmon/*; do
  case "$(cat "$h/name" 2>/dev/null)" in
    k10temp|coretemp|zenpower) [ -r "$h/temp1_input" ] && echo "cputemp $(cat "$h/temp1_input")" ;;
  esac
done
awk '/^MemTotal/{t=$2} /^MemAvailable/{a=$2} END{print "mem", t*1024, (t-a)*1024}' /proc/meminfo
awk '/^SwapTotal/{t=$2} /^SwapFree/{f=$2} END{print "swap", t*1024, (t-f)*1024}' /proc/meminfo
for d in /sys/class/drm/card*/device; do
  [ -r "$d/gpu_busy_percent" ] || continue
  echo "gpu $(cat "$d/gpu_busy_percent")"
  [ -r "$d/mem_info_vram_total" ] && echo "vram $(cat "$d/mem_info_vram_used") $(cat "$d/mem_info_vram_total")"
  for h in "$d"/hwmon/hwmon*; do
    [ -r "$h/temp1_input" ] && echo "gputemp $(cat "$h/temp1_input")" && break
  done
  break
done
echo "procs $(ls -d /proc/[0-9]* 2>/dev/null | wc -l)"
df -B1 -x tmpfs -x devtmpfs -x efivarfs -x overlay -x squashfs --output=target,size,used 2>/dev/null |
  tail -n +2 | awk 'NF==3 {print "disk", $1, $2, $3}'
`]
        stdout: StdioCollector {
            onStreamFinished: root._parse(this.text)
        }
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
            case "vram":     root.gpuVramUsed = Number(f[1]); root.gpuVramTotal = Number(f[2]); break;
            case "mem":      root.memTotal = Number(f[1]); root.memUsed = Number(f[2]); break;
            case "swap":     root.swapTotal = Number(f[1]); root.swapUsed = Number(f[2]); break;
            case "procs":    root.procs = Number(f[1]); break;
            case "disk": {
                const size = Number(f[2]), used = Number(f[3]);
                if (size > 0) ds.push({ target: f[1], size, used, percent: Math.round(used * 100 / size) });
                break;
            }
            }
        }
        if (ds.length) root.disks = ds;
    }

    readonly property var _timer: Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: if (!root._poll.running) root._poll.running = true
    }
}
