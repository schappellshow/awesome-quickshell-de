import QtQuick
import Quickshell
import Quickshell.Io
import "../common"

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

    // Nothing is checked unless the grabs come back; this is the backstop.
    Timer {
        id: watchdog
        interval: 4000
        onTriggered: health.finish(["grab timed out"])
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

        let waiting = bars.length;
        if (waiting === 0) {
            health.finish([]);
            return;
        }
        const files = [];
        watchdog.restart();
        for (const b of bars) {
            b.snapshotSections(health.dir + "/aqs-bar-grab-" + gen + "-" + b.screenName,
                (paths, missing) => {
                    if (gen !== health.generation)
                        return;
                    for (const id of missing)
                        problems.push(b.screenName + ": section '" + id + "' could not be grabbed");
                    for (const p of paths)
                        files.push(p);
                    if (--waiting === 0) {
                        watchdog.stop();
                        health.checkPixels(files, problems);
                    }
                });
        }
    }

    // One ImageMagick call for every grabbed file: prints "<max alpha> <path>"
    // per line. A section with any painted pixel has a max alpha above 0.
    function checkPixels(files, problems) {
        if (files.length === 0) {
            health.finish(problems);
            return;
        }
        pixelProbe.pending = problems;
        pixelProbe.files = files;
        pixelProbe.command = ["sh", "-c",
            'for f in "$@"; do printf "%s %s\\n" "$(magick "$f" -alpha extract -format "%[fx:maxima]" info: 2>&1)" "$f"; rm -f "$f"; done',
            "aqs-heal"].concat(files);
        pixelProbe.running = true;
    }

    Process {
        id: pixelProbe
        property var pending: []
        property var files: []
        stdout: StdioCollector {
            onStreamFinished: {
                const problems = pixelProbe.pending;
                const seen = {};
                for (const line of text.split("\n")) {
                    const m = line.match(/^(\S+) (.*)$/);
                    if (!m)
                        continue;
                    seen[m[2]] = true;
                    if (!(parseFloat(m[1]) > 0))
                        problems.push("blank: " + m[2].replace(/.*aqs-bar-grab-/, ""));
                }
                for (const f of pixelProbe.files)
                    if (!seen[f])
                        problems.push("unchecked: " + f);
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
