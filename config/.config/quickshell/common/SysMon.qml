pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Lightweight CPU/RAM sampling for the bar's SYS pill, plus the conky
// popout: conky is not always-on — the pill (or Super+Shift+M) toggles it
// like a dashboard. Graphs/charts stay conky's job; the pill just shows
// numbers a 36px vertical bar can fit.
Singleton {
    id: root

    property int cpuPct: 0
    property int memPct: 0
    property bool conkyRunning: false

    // ── "Only when busy" ──────────────────────────────────────────────
    // cpuBusy / memBusy say whether the bar should be showing that figure
    // in "busy" mode. A figure turns busy once it has been at or above its
    // threshold for showAfterMs, and turns idle again once it has been
    // `hysteresis` points below it for hideAfterMs, so a figure hovering
    // around the threshold doesn't flicker.
    //
    // Time is measured between samples, not counted in samples, because the
    // sample period changes (3 s normally, 10 s in performance mode). A
    // sample stands for the interval since the previous one, so at 10 s a
    // single high reading already covers more than showAfterMs and counts;
    // at 3 s it takes two.
    readonly property int showAfterMs: 5000
    readonly property int hideAfterMs: 10000
    readonly property int hysteresis: 15
    property bool cpuBusy: false
    property bool memBusy: false
    property real lastSampleAt: 0
    property real cpuSince: 0   // start of the current run above (or below)
    property real memSince: 0

    // Pure state step for one figure, so tests can drive it with fixtures:
    // returns { busy, since } after a reading `pct` at time `now`.
    function step(busy, since, pct, threshold, now, prev) {
        const crossing = busy ? pct < threshold - hysteresis : pct >= threshold;
        if (!crossing)
            return { busy: busy, since: 0 };
        // A run starts where the previous sample ended.
        const start = since > 0 ? since : (prev > 0 ? prev : now);
        const need = busy ? hideAfterMs : showAfterMs;
        return now - start >= need
            ? { busy: !busy, since: 0 }
            : { busy: busy, since: start };
    }

    function judge(now) {
        const c = step(cpuBusy, cpuSince, cpuPct,
                       Settings.sysmonCpuThreshold, now, lastSampleAt);
        const m = step(memBusy, memSince, memPct,
                       Settings.sysmonRamThreshold, now, lastSampleAt);
        cpuBusy = c.busy;
        cpuSince = c.since;
        memBusy = m.busy;
        memSince = m.since;
        lastSampleAt = now;
    }

    // Previous /proc/stat sample
    property real lastTotal: 0
    property real lastIdle: 0

    function toggleConky() {
        const cfg = Wallpaper.expand(Settings.conkyConfig);
        // Pop out hugging the bar: -a/-x/-y override the conkyrc's
        // alignment/gap (tuned for the old always-on KDE setup). Conky
        // treats the gap as relative to its xinerama head — the primary
        // monitor, which is where the bar lives — so no screen-origin
        // offset here. (The awesome rule additionally pins the window to
        // the bar's screen.)
        // +11: conky positions its window ~11px left of the requested gap
        // (own-window margin quirk), measured against awesome's geometry.
        // The popout hugs whichever edge the bar is on, and anchors to that
        // same corner so it grows away from the bar rather than under it.
        const clear = Settings.barWidth + 19;
        const align = BarEdge.edge === "right" ? "top_right"
                    : BarEdge.edge === "bottom" ? "bottom_left"
                    : "top_left";
        const x = BarEdge.vertical ? clear : 20;
        const y = BarEdge.vertical ? 20 : clear;
        // Optional integration: conky is not required by this desktop. With
        // no config set (or the file missing) fall back to any *.conkyrc in
        // ~/.conky, then to conky's own defaults; if conky isn't installed
        // at all, say so rather than no-op silently.
        // cfg is passed as $1 (not interpolated) to avoid quoting issues.
        Quickshell.execDetached(["sh", "-c",
            "if pgrep -u $USER -x conky >/dev/null; then killall conky; exit 0; fi; " +
            "command -v conky >/dev/null || { " +
            "  notify-send 'System monitor' 'conky is not installed'; exit 0; }; " +
            "cfg=\"$1\"; " +
            "[ -f \"$cfg\" ] || cfg=$(find -L \"$HOME/.conky\" -maxdepth 1 " +
            "  -name '*.conkyrc' 2>/dev/null | sort | head -1); " +
            "cd \"$HOME/.conky\" 2>/dev/null; " +
            "if [ -n \"$cfg\" ] && [ -f \"$cfg\" ]; then " +
            "  conky -c \"$cfg\" -a " + align + " -x " + x + " -y " + y + " >/dev/null 2>&1 & " +
            "else " +
            "  conky -a " + align + " -x " + x + " -y " + y + " >/dev/null 2>&1 & " +
            "fi",
            "conky-toggle", cfg]);
        conkyRunning = !conkyRunning;
        confirm.restart();
    }

    // Re-check reality a moment after toggling (conky may fail to start)
    Timer {
        id: confirm
        interval: 1500
        onTriggered: checkProc.running = true
    }

    Process {
        id: checkProc
        command: ["sh", "-c", "pgrep -u $USER -x conky >/dev/null && echo yes || echo no"]
        stdout: StdioCollector {
            onStreamFinished: root.conkyRunning = text.trim() === "yes"
        }
    }

    // Performance mode polls a third as often. Reading PerformanceMode here
    // also brings that singleton to life wherever the monitor is alive.
    Timer {
        interval: PerformanceMode.active ? 10000 : 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: sample.running = true
    }

    Process {
        id: sample
        command: ["sh", "-c",
            "head -1 /proc/stat; awk '/^MemTotal|^MemAvailable/{print $2}' /proc/meminfo"]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }

    function parse(t) {
        const lines = t.trim().split("\n");
        // "cpu  user nice system idle iowait irq softirq steal ..."
        const f = lines[0].trim().split(/\s+/).slice(1).map(Number);
        const idle = f[3] + (f[4] || 0);
        const total = f.reduce((a, b) => a + b, 0);
        const first = lastTotal === 0;
        if (lastTotal > 0 && total > lastTotal) {
            const dTotal = total - lastTotal;
            const dIdle = idle - lastIdle;
            cpuPct = Math.round(100 * (1 - dIdle / dTotal));
        }
        lastTotal = total;
        lastIdle = idle;

        if (lines.length >= 3) {
            const memTotal = parseInt(lines[1]);
            const memAvail = parseInt(lines[2]);
            if (memTotal > 0)
                memPct = Math.round(100 * (1 - memAvail / memTotal));
        }
        // The first sample has no CPU delta yet, so cpuPct is meaningless
        // until the second.
        if (!first)
            judge(Date.now());
    }

    Component.onCompleted: checkProc.running = true
}
