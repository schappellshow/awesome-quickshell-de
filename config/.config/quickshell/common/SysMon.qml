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
        // (own-window margin quirk), measured against awesome's geometry
        const x = Settings.barWidth + 19;
        const y = 20;
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
            "  conky -c \"$cfg\" -a top_left -x " + x + " -y " + y + " >/dev/null 2>&1 & " +
            "else " +
            "  conky -a top_left -x " + x + " -y " + y + " >/dev/null 2>&1 & " +
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

    Timer {
        interval: 3000
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
    }

    Component.onCompleted: checkProc.running = true
}
