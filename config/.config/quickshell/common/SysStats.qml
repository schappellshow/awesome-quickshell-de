pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Sampling for the native system dashboard (dashboard/Dashboard.qml).
//
// Nothing here runs while the dashboard is closed: `active` (bound to
// Dashboard.visible) gates the one timer, and the history is dropped when
// it goes false, so reopening starts a fresh graph rather than splicing in
// an old one. Polling is a third as often in performance mode, like
// SysMon.
//
// One shell script per tick prints every reading under "@@name" markers;
// parse() splits it. Deltas (CPU, disk, network, per-process CPU) are
// computed here between ticks, so the first tick only primes them.
//
//   CPU      /proc/stat (total + per-core), scaling_cur_freq, a k10temp /
//            coretemp / zenpower hwmon (else the x86_pkg_temp thermal zone)
//   Memory   /proc/meminfo
//   Drives   df on /, /proc/diskstats summed over whole physical disks
//   Network  the default-route interface: /proc/net/dev, `ip` for its
//            address; Wi-Fi name and signal come from common/Network.qml
//   GPU      /sys/class/drm/card*/device (amdgpu: gpu_busy_percent,
//            mem_info_vram_*, hwmon temp1_input) — readable without root
//   Procs    /proc/<pid>/stat, grouped by command name
Singleton {
    id: root

    property bool active: false
    readonly property int historyLen: 60
    readonly property int intervalMs: PerformanceMode.active ? 6000 : 2000

    // ── System ──
    property string hostname: ""
    property string distro: ""
    property string kernel: ""
    property real uptimeSec: 0

    // ── CPU ──
    property real cpuPct: 0
    property var cpuHist: []
    property var cores: []            // per-thread 0-100
    property real cpuMhz: 0
    property real cpuTemp: -1         // °C, -1 = unreadable
    property var topCpu: []           // [{ name, cpu, mem }]

    // ── Memory ──
    property real memUsed: 0          // bytes
    property real memTotal: 0
    property real swapUsed: 0
    property real swapTotal: 0
    property var topMem: []

    // ── Drives ──
    property real rootUsed: 0
    property real rootSize: 0
    property real diskRead: 0         // bytes/s
    property real diskWrite: 0
    property var diskReadHist: []
    property var diskWriteHist: []

    // ── Network ──
    property string iface: ""
    property string ip: ""
    property bool wifi: false
    property real netDown: 0          // bytes/s
    property real netUp: 0
    property var netDownHist: []
    property var netUpHist: []

    // ── GPU ──
    property bool gpuPresent: false
    property real gpuPct: 0
    property var gpuHist: []
    property real vramUsed: 0
    property real vramTotal: 0
    property real gpuTemp: -1

    // Previous-tick state for the deltas
    property var prev: ({})

    onActiveChanged: {
        if (active) {
            tick.restart();
            sample();
        } else {
            tick.stop();
            sampler.running = false;
            prev = {};
            cpuHist = []; diskReadHist = []; diskWriteHist = [];
            netDownHist = []; netUpHist = []; gpuHist = [];
            topCpu = []; topMem = []; cores = [];
        }
    }

    function sample() {
        if (!sampler.running)
            sampler.running = true;
    }

    Timer {
        id: tick
        interval: root.intervalMs
        repeat: true
        onTriggered: root.sample()
    }

    Process {
        id: sampler
        command: ["sh", "-c", root.script]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }

    readonly property string script: `
exec 2>/dev/null
echo @@sys
cat /proc/sys/kernel/hostname /proc/sys/kernel/osrelease
sed -n 's/^PRETTY_NAME=//p' /etc/os-release | tr -d '"'
cut -d' ' -f1 /proc/uptime
echo @@stat
grep '^cpu' /proc/stat
echo @@mem
grep -E '^(MemTotal|MemAvailable|SwapTotal|SwapFree):' /proc/meminfo
echo @@freq
cat /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_cur_freq | awk '{s+=$1;n++} END{if(n) print s/n}'
echo @@temp
for h in /sys/class/hwmon/hwmon*; do
  case "$(cat $h/name)" in k10temp|coretemp|zenpower|cpu_thermal)
    cat $h/temp1_input; break;; esac
done
echo @@df
df -B1 --output=size,used / | tail -1
echo @@disk
awk '$3 ~ /^(sd[a-z]+|vd[a-z]+|nvme[0-9]+n[0-9]+|mmcblk[0-9]+)$/ {r+=$6; w+=$10} END{print r*512, w*512}' /proc/diskstats
echo @@net
dev=$(ip route show default | awk '{for(i=1;i<NF;i++) if($i=="dev"){print $(i+1); exit}}')
echo "$dev"
if [ -n "$dev" ]; then
  ip -4 -o addr show dev "$dev" | awk '{sub(/\\/.*/,"",$4); print $4; exit}'
  [ -d /sys/class/net/$dev/wireless ] && echo wifi || echo wired
  awk -v d="$dev:" '$1==d {print $2, $10}' /proc/net/dev
fi
echo @@gpu
for c in /sys/class/drm/card[0-9]*/device; do
  [ -r $c/gpu_busy_percent ] || continue
  cat $c/gpu_busy_percent $c/mem_info_vram_used $c/mem_info_vram_total
  cat $c/hwmon/hwmon*/temp1_input | head -1
  break
done
echo @@ps
awk '{
  line=$0; o=index(line,"("); match(line,/\\)[^)]*$/)
  comm=substr(line,o+1,RSTART-o-1); n=split(substr(line,RSTART+2),f," ")
  print $1 "\\t" f[12]+f[13] "\\t" f[22] "\\t" comm
}' /proc/[0-9]*/stat
`

    function num(s) {
        const v = parseFloat(s);
        return isNaN(v) ? 0 : v;
    }

    function push(arr, v) {
        const out = arr.length >= historyLen ? arr.slice(arr.length - historyLen + 1) : arr.slice();
        out.push(v);
        return out;
    }

    // Split the script output into { name: [lines] }
    function sections(text) {
        const out = {};
        let cur = null;
        for (const line of text.split("\n")) {
            if (line.startsWith("@@")) {
                cur = [];
                out[line.slice(2)] = cur;
            } else if (cur && line !== "") {
                cur.push(line);
            }
        }
        return out;
    }

    function parse(text) {
        const s = sections(text);
        const now = Date.now();
        const p = prev;
        const dt = p.t ? (now - p.t) / 1000 : 0;
        const np = { t: now };

        const sys = s.sys || [];
        hostname = sys[0] || "";
        kernel = sys[1] || "";
        distro = sys[2] || "";
        uptimeSec = num(sys[3]);

        // CPU: jiffy deltas, total and per core
        const cpuLines = s.stat || [];
        const jiffies = {};
        for (const l of cpuLines) {
            const f = l.split(/\s+/);
            const v = f.slice(1).map(Number);
            jiffies[f[0]] = [v.reduce((a, b) => a + b, 0), v[3] + (v[4] || 0)];
        }
        np.jiffies = jiffies;
        const pct = k => {
            const a = jiffies[k], b = p.jiffies ? p.jiffies[k] : null;
            if (!a || !b || a[0] <= b[0])
                return 0;
            return 100 * (1 - (a[1] - b[1]) / (a[0] - b[0]));
        };
        const havePrev = !!p.t;
        if (havePrev) {
            cpuPct = pct("cpu");
            cpuHist = push(cpuHist, cpuPct);
            const names = Object.keys(jiffies).filter(k => k !== "cpu");
            cores = names.map(pct);
        }

        cpuMhz = num((s.freq || [])[0]) / 1000;
        const t = (s.temp || [])[0];
        cpuTemp = t !== undefined ? num(t) / 1000 : -1;

        // Memory
        const mem = {};
        for (const l of s.mem || []) {
            const f = l.split(/\s+/);
            mem[f[0].replace(":", "")] = num(f[1]) * 1024;
        }
        memTotal = mem.MemTotal || 0;
        memUsed = memTotal - (mem.MemAvailable || 0);
        swapTotal = mem.SwapTotal || 0;
        swapUsed = swapTotal - (mem.SwapFree || 0);

        // Root filesystem and disk throughput
        const df = ((s.df || [])[0] || "").trim().split(/\s+/);
        rootSize = num(df[0]);
        rootUsed = num(df[1]);
        const dk = ((s.disk || [])[0] || "").split(" ");
        np.dr = num(dk[0]);
        np.dw = num(dk[1]);
        if (havePrev && dt > 0) {
            diskRead = Math.max(0, (np.dr - p.dr) / dt);
            diskWrite = Math.max(0, (np.dw - p.dw) / dt);
            diskReadHist = push(diskReadHist, diskRead);
            diskWriteHist = push(diskWriteHist, diskWrite);
        }

        // Network (default-route interface)
        const net = s.net || [];
        // [dev, ip (if it has one), wifi|wired, "rx tx"]; none without a route
        const hasNet = net.length >= 3;
        iface = hasNet ? net[0] : "";
        ip = net.length > 3 ? net[1] : "";
        wifi = hasNet && net[net.length - 2] === "wifi";
        const rxtx = (hasNet ? net[net.length - 1] : "").split(" ");
        np.iface = iface;
        np.rx = num(rxtx[0]);
        np.tx = num(rxtx[1]);
        if (havePrev && dt > 0 && p.iface === iface && iface !== "") {
            netDown = Math.max(0, (np.rx - p.rx) / dt);
            netUp = Math.max(0, (np.tx - p.tx) / dt);
            netDownHist = push(netDownHist, netDown);
            netUpHist = push(netUpHist, netUp);
        }

        // GPU
        const g = s.gpu || [];
        gpuPresent = g.length >= 3;
        if (gpuPresent) {
            gpuPct = num(g[0]);
            vramUsed = num(g[1]);
            vramTotal = num(g[2]);
            gpuTemp = g.length > 3 ? num(g[3]) / 1000 : -1;
            gpuHist = push(gpuHist, gpuPct);
        }

        // Processes: per-pid CPU jiffy deltas against the total, grouped by
        // name. Memory is resident pages against MemTotal.
        const procs = {};
        const cur = {};
        const total = jiffies.cpu ? jiffies.cpu[0] : 0;
        const dTotal = havePrev && p.jiffies && p.jiffies.cpu ? total - p.jiffies.cpu[0] : 0;
        const ncpu = Math.max(1, Object.keys(jiffies).length - 1);
        for (const l of s.ps || []) {
            const f = l.split("\t");
            const pid = f[0], j = num(f[1]);
            cur[pid] = j;
            const e = procs[f[3]] || (procs[f[3]] = { name: f[3], cpu: 0, mem: 0 });
            if (p.ps && p.ps[pid] !== undefined && dTotal > 0)
                e.cpu += 100 * ncpu * Math.max(0, j - p.ps[pid]) / dTotal;
            if (memTotal > 0)
                e.mem += 100 * num(f[2]) * 4096 / memTotal;
        }
        np.ps = cur;
        const list = Object.values(procs);
        topCpu = havePrev ? list.slice().sort((a, b) => b.cpu - a.cpu).slice(0, 9) : [];
        topMem = list.slice().sort((a, b) => b.mem - a.mem).slice(0, 9);

        prev = np;
    }
}
