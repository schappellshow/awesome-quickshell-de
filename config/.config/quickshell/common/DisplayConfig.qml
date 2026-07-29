pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// xrandr wrapper: probes connected outputs/modes for the Displays page and
// replays the saved layout (Settings.displayCmd) at login — xrandr state
// doesn't persist on its own.
Singleton {
    id: root

    // [{ name, primary, x, y, rotation, currentMode, modes: [string] }]
    property var outputs: []

    // Settings load asynchronously: at startup-chain time displayCmd may
    // still be the "" default, so the replay also triggers when the value
    // arrives (onDisplayCmdChanged). Guarded so a user Apply — which runs
    // xrandr itself and then writes displayCmd — doesn't double-fire.
    property bool replayed: false

    function init() {
        // Seed the output set first, so the replay's own screen events
        // aren't mistaken for a hotplug
        lastOutputs = currentOutputKey();
        tryReplay();
    }

    function tryReplay() {
        if (replayed || Settings.displayCmd === "")
            return;
        replayed = true;
        Quickshell.execDetached(["sh", "-c", "xrandr " + Settings.displayCmd]);
    }

    Connections {
        target: Settings
        function onDisplayCmdChanged() { root.tryReplay(); }
    }

    // ── Hotplug ────────────────────────────────────────────────────────
    // Monitors plugged/unplugged mid-session leave X in whatever default
    // arrangement the driver picks (mirrored/stacked at 0,0), losing the
    // saved layout — most visible when docking a laptop. Quickshell.screens
    // tracks RandR, so a change in the connected-output set re-applies the
    // saved layout.
    //
    // Guarded three ways: only when the set of output NAMES actually
    // changes (not on a resolution/position change, which our own xrandr
    // run causes → would loop); debounced, since a hotplug emits several
    // events; and skipped while `applying` is set so a user Apply from the
    // Displays page doesn't trigger a replay on top of itself.
    property string lastOutputs: ""
    property bool applying: false

    function currentOutputKey() {
        return Quickshell.screens.map(s => s.name).sort().join(",");
    }

    Connections {
        target: Quickshell
        function onScreensChanged() {
            const key = root.currentOutputKey();
            if (key === root.lastOutputs)
                return;             // same outputs — geometry-only change
            root.lastOutputs = key;
            if (root.applying || Settings.displayCmd === "")
                return;
            hotplugDebounce.restart();
        }
    }

    Timer {
        id: hotplugDebounce
        interval: 1200
        onTriggered: {
            // Re-apply only the outputs that are actually connected now;
            // xrandr errors out on the whole command if any --output names
            // a disconnected one.
            const connected = Quickshell.screens.map(s => s.name);
            const kept = [];
            for (const chunk of Settings.displayCmd.split("--output ")) {
                if (chunk.trim() === "")
                    continue;
                const name = chunk.trim().split(/\s+/)[0];
                if (connected.indexOf(name) >= 0)
                    kept.push("--output " + chunk.trim());
            }
            if (kept.length === 0)
                return;
            Quickshell.execDetached(["sh", "-c", "xrandr " + kept.join(" ")]);
            root.probe();
        }
    }

    function probe() {
        xrandrProc.running = true;
    }

    // profile: { outputName: { mode, primary, rotate } }, missing entries
    // keep current
    function apply(profile) {
        const args = [];
        for (const o of outputs) {
            const p = profile[o.name] || {};
            args.push("--output", o.name,
                "--mode", p.mode || o.currentMode,
                "--pos", o.x + "x" + o.y,
                "--rotate", p.rotate || o.rotation);
            if (p.primary === true || (p.primary === undefined && o.primary))
                args.push("--primary");
        }
        const cmd = args.join(" ");
        // Hold off the hotplug watcher: our own xrandr run emits screen
        // changes that would otherwise look like a hotplug
        applying = true;
        applyGuard.restart();
        Quickshell.execDetached(["sh", "-c", "xrandr " + cmd]);
        replayed = true;   // this IS the apply; don't replay on the write
        Settings.displayCmd = cmd;
        reprobe.restart();
    }

    Timer {
        id: applyGuard
        interval: 3000
        onTriggered: {
            root.applying = false;
            root.lastOutputs = root.currentOutputKey();
        }
    }

    Timer {
        id: reprobe
        interval: 2000
        onTriggered: root.probe()
    }

    Process {
        id: xrandrProc
        command: ["xrandr", "--query"]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }

    function parse(t) {
        const outs = [];
        let cur = null;
        for (const line of t.split("\n")) {
            // "DisplayPort-2 connected primary 1920x1080+1080+0 (normal ...)"
            // Rotated outputs carry the rotation before the paren list:
            // "HDMI-A-0 connected 1080x1920+0+0 left (normal left ...)"
            let m = line.match(/^(\S+) (connected|disconnected)( primary)?( (\d+)x(\d+)\+(\d+)\+(\d+))?( (left|right|inverted))?/);
            if (m) {
                cur = null;
                if (m[2] === "connected") {
                    cur = {
                        name: m[1],
                        primary: !!m[3],
                        x: m[7] !== undefined ? parseInt(m[7]) : 0,
                        y: m[8] !== undefined ? parseInt(m[8]) : 0,
                        rotation: m[10] || "normal",
                        currentMode: "",
                        modes: []
                    };
                    outs.push(cur);
                }
                continue;
            }
            // "   1920x1080     60.00*+  59.94"
            m = line.match(/^\s+(\d+x\d+i?)\s+(.*)/);
            if (m && cur) {
                if (!cur.modes.includes(m[1]))
                    cur.modes.push(m[1]);
                if (m[2].includes("*"))
                    cur.currentMode = m[1];
            }
        }
        outputs = outs;
    }
}
