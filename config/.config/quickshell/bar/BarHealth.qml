import QtQuick
import Quickshell
import Quickshell.Io
import "../common"

// The paint check captures the bar's real X window and looks inside each
// section's rectangle (see Bar.qml sectionRects); Item.grabToImage is not used.
// Makes the bar verify itself after anything that has been seen to break it,
// and rebuild its windows (what Super+B does) if the check fails.
//
// Two failures are covered, both cured by destroying and recreating the bar
// PanelWindows and by nothing else:
//   * a section that lays out at its proper size but paints nothing;
//   * the bar sitting on a different monitor than Settings.barScreen names.
//
// Triggers (the owner calls trigger()): config load, awesome restart, a
// screen added or removed, a change of Settings.barScreen. A moment after
// each, verify() runs once. There is no timer loop. If it finds a problem it
// emits heal() and checks again; after two heals in a row for the same
// trigger it logs that it gave up and stops, so a persistent problem can
// never become a rebuild loop.
//
// Every verify and heal is appended to $XDG_RUNTIME_DIR/aqs-bar-heal.log.
// Written with a shell rather than console.log, which does not reach
// `qs log`.
Scope {
    id: health

    // The Variants that creates the bars.
    required property var variants
    signal heal()

    readonly property int maxHeals: 2
    readonly property int settleMs: 1500

    readonly property string dir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property string logPath: dir + "/aqs-bar-heal.log"

    property int heals: 0
    property string reason: ""
    // Bumped per verify so a stale grab callback from an earlier run can't
    // be counted against this one.
    property int generation: 0

    function log(msg) {
        Quickshell.execDetached(["sh", "-c",
            'printf "%s %s\\n" "$(date +%FT%T)" "$1" >> "$2"',
            "aqs-heal", msg, health.logPath]);
    }

    // An outside event: starts a fresh budget of heals.
    function trigger(why) {
        health.heals = 0;
        health.reason = why;
        settle.restart();
    }

    Timer {
        id: settle
        interval: health.settleMs
        onTriggered: health.verify()
    }

    function wantNames() {
        // Worked out from Settings afresh, not from what the shell last
        // handed Variants: the point is to catch the two disagreeing.
        const one = Quickshell.screens.filter(s => s.name === Settings.barScreen);
        return (one.length > 0 ? one : Quickshell.screens).map(s => s.name).sort();
    }

    function verify() {
        health.generation++;
        const gen = health.generation;
        const problems = [];

        const want = health.wantNames();
        const bars = health.variants.instances.filter(b => b && b.screen);
        const have = bars.map(b => b.screen.name).sort();
        if (want.join(",") !== have.join(","))
            problems.push("screens: want [" + want + "] have [" + have + "]");

        // Screen mismatch: no point grabbing, the rebuild fixes both.
        if (problems.length > 0) {
            health.finish(problems);
            return;
        }

        // Capture each bar's real X window (what the server holds for it,
        // which is what the screen shows) and count the distinct colors
        // inside every section's rectangle. The pill behind a section is one
        // flat color, so a section that painted nothing crops to exactly one
        // color and any text or icon makes it several.
        const jobs = [];
        for (const b of bars) {
            for (const r of b.sectionRects())
                jobs.push({ size: b.sizeKey, pos: b.posKey, name: b.screenName + "/" + r.id,
                            geo: r.w + "x" + r.h + "+" + r.x + "+" + r.y });
        }
        if (jobs.length === 0) {
            health.finish(problems);
            return;
        }
        pixelProbe.pending = problems;
        pixelProbe.names = jobs.map(j => j.name);
        const tmp = health.dir + "/aqs-bar-grab-" + gen + ".png";
        // Window ids by geometry: the inner window named "quickshell" whose
        // size and absolute position match this bar's.
        let script = 'find() { xwininfo -root -tree | grep -F "quickshell\\": ()  $1+" | grep -F " $2" | head -1 | grep -o "0x[0-9a-f]*"; }; ';
        for (const j of jobs)
            script += 'W=$(find ' + j.size + ' ' + j.pos + '); import -window "$W" png:"' + tmp + '" 2>/dev/null'
                + ' && echo "$(magick "' + tmp + '" -crop ' + j.geo
                + ' +repage -format %k info: 2>&1) ' + j.name + '" || echo "0 ' + j.name + ' capture-failed"; ';
        script += 'rm -f "' + tmp + '"';
        pixelProbe.command = ["sh", "-c", script];
        pixelProbe.running = true;
    }

    Process {
        id: pixelProbe
        property var pending: []
        property var names: []
        stdout: StdioCollector {
            onStreamFinished: {
                const problems = pixelProbe.pending;
                const seen = {};
                for (const line of text.split("\n")) {
                    const m = line.match(/^(\d+) (\S+)( capture-failed)?/);
                    if (!m)
                        continue;
                    seen[m[2]] = true;
                    if (m[3])
                        problems.push("capture failed: " + m[2]);
                    else if (parseInt(m[1]) < 2)
                        problems.push("blank: " + m[2]);
                }
                for (const n of pixelProbe.names)
                    if (!seen[n])
                        problems.push("unchecked: " + n);
                health.finish(problems);
            }
        }
    }

    function finish(problems) {
        if (problems.length === 0) {
            health.log("ok (" + health.reason + ", heals so far " + health.heals + ")");
            return;
        }
        if (health.heals >= health.maxHeals) {
            health.log("GAVE UP after " + health.heals + " heals (" + health.reason
                       + "): " + problems.join("; "));
            return;
        }
        health.heals++;
        health.log("HEAL " + health.heals + "/" + health.maxHeals + " (" + health.reason
                   + "): " + problems.join("; "));
        health.heal();
        // Look again once the rebuilt windows have settled.
        health.reason = "recheck";
        settle.restart();
    }
}
