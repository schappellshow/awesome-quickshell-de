#!/usr/bin/env python3
"""Exercise the real QML backend with a fake xrandr; never reconfigure X."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
COMMON = ROOT / "config/.config/quickshell/common"

MOCK = r'''#!/usr/bin/env python3
import json, os, pathlib, sys
p = pathlib.Path(os.environ["DISPLAY_TEST_STATE"])
state = json.loads(p.read_text())
args = sys.argv[1:]
if args == ["--query"]:
    for name, o in state.items():
        print(f"{name} connected {'primary ' if o['primary'] else ''}"
              f"1920x1080+{o['x']}+{o['y']} (normal left inverted right)")
        print("   1920x1080 60.00*+")
    sys.exit(0)
with p.with_suffix(".log").open("a") as log:
    log.write(json.dumps(args) + "\n")
name = None
for i, arg in enumerate(args):
    if arg == "--output": name = args[i+1]
    elif arg == "--pos":
        state[name]["x"], state[name]["y"] = map(int, args[i+1].split("x"))
    elif arg == "--primary":
        for key in state: state[key]["primary"] = key == name
    elif arg == "--noprimary":
        for key in state: state[key]["primary"] = False
p.write_text(json.dumps(state))
if "--pos" in args and "666x0" in args:
    print("Simulated partial RandR failure", file=sys.stderr)
    sys.exit(1)
'''

HARNESS = r'''
import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "common"
import "settings/pages"
ShellRoot {
    id: test
    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 840
        implicitHeight: 560
        Loader {
            id: pageLoader
            anchors.fill: parent
            source: "settings/pages/DisplayPage.qml"
        }
    }
    property var editor: pageLoader.item
    TestCase { id: mouse; when: false }
    property int stage: 0
    property int ticks: 0
    property string saved: ""
    property bool finished: false
    Process {
        id: outcome
        onExited: Qt.quit()
    }
    function finish(message) {
        finished = true;
        outcome.command = ["python3", "-c",
            "import os,sys;open(os.environ['DISPLAY_TEST_RESULT'],'w').write(sys.argv[1])",
            message];
        outcome.running = true;
    }
    function check(ok, message) {
        if (!ok) {
            finish("FAIL: " + message);
            throw new Error(message);
        }
    }
    function shifted(x) {
        return { "DP-1": { x: 1920, y: x }, "DP-2": { x: 0, y: 0 } };
    }
    Component.onCompleted: DisplayConfig.init()
    Timer {
        interval: 100
        running: !test.finished
        repeat: true
        onTriggered: {
            test.ticks++;
            test.check(test.ticks < 200, "state machine timeout at " + test.stage
                + " operation=" + DisplayConfig.operation + " error=" + DisplayConfig.error);
            const idle = !DisplayConfig.applying && !DisplayConfig.probing;
            if (test.stage === 0 && idle && DisplayConfig.outputs.length === 2) {
                const monitor = mouse.findChild(editor, "monitor-DP-1");
                test.check(monitor !== null && monitor.width > 0, "monitor preview loaded");
                mouse.mouseDrag(monitor, monitor.width / 2, monitor.height / 2, 60, 60);
                test.check(Object.keys(editor.chosen).length > 0, "mouse drag stages position");
                editor.chosen = ({});
                // Overlap fails validation before running a writer.
                DisplayConfig.apply({ "DP-2": { x: 0 } });
                test.stage = 1;
            } else if (test.stage === 1 && idle) {
                test.check(DisplayConfig.error.indexOf("overlaps") >= 0, "overlap error");
                DisplayConfig.apply(test.shifted(200));
                test.stage = 2;
            } else if (test.stage === 2 && DisplayConfig.confirming) {
                test.check(Settings.displayCmd === "", "not persisted before Keep");
                DisplayConfig.apply(test.shifted(300)); // duplicate ignored
                DisplayConfig.revert();
                test.stage = 3;
            } else if (test.stage === 3 && idle) {
                test.check(DisplayConfig.outputs[0].x === 0, "manual revert geometry");
                test.check(Settings.displayCmd === "", "revert not persisted");
                DisplayConfig.apply(test.shifted(200));
                test.stage = 4;
            } else if (test.stage === 4 && DisplayConfig.confirming) {
                DisplayConfig.secondsLeft = 1; // exercise actual countdown callback
                pageLoader.active = false; // rollback survives page destruction
                test.stage = 5;
            } else if (test.stage === 5 && idle) {
                test.check(Settings.displayCmd === "", "timeout not persisted");
                pageLoader.active = true;
                test.stage = 50;
            } else if (test.stage === 50 && idle && editor !== null) {
                DisplayConfig.apply({ "DP-1": { x: 1920 }, "DP-2": { x: 0 } });
                test.stage = 6;
            } else if (test.stage === 6 && DisplayConfig.confirming) {
                DisplayConfig.keep();
                test.saved = Settings.displayCmd;
                test.check(test.saved.indexOf("--pos 1920x0") >= 0, "Keep saved");
                test.stage = 7;
            } else if (test.stage === 7 && idle) {
                // Gap is valid but mock writer fails after partially applying.
                DisplayConfig.apply({
                    "DP-1": { x: 666, y: 0 },
                    "DP-2": { x: 0, y: 1080 }
                });
                test.stage = 8;
            } else if (test.stage === 8 && idle) {
                test.check(DisplayConfig.error.indexOf("Simulated") >= 0, "writer error visible");
                test.check(Settings.displayCmd === test.saved, "failure not saved");
                test.check(DisplayConfig.outputs[0].x === 1920, "partial failure rolled back");
                test.finish("PASS: mouse dragging, validation, duplicate Apply, Keep, manual/timed rollback, page destruction, partial failure");
            }
        }
    }
}
'''


def main():
    with tempfile.TemporaryDirectory(prefix="display-test-") as tmp:
        tmp = Path(tmp)
        common = tmp / "common"
        common.mkdir()
        for name in ("DisplayConfig.qml", "DisplayLayout.js"):
            shutil.copy2(COMMON / name, common / name)
        shutil.copy2(COMMON / "Theme.qml", common / "Theme.qml")
        pages = tmp / "settings/pages"
        pages.mkdir(parents=True)
        shutil.copy2(ROOT / "config/.config/quickshell/settings/pages/DisplayPage.qml",
                     pages / "DisplayPage.qml")
        shutil.copytree(ROOT / "config/.config/quickshell/settings/components",
                        tmp / "settings/components")
        (common / "Settings.qml").write_text(
            'pragma Singleton\nimport QtQuick\nimport Quickshell\n'
            'Singleton { property string displayCmd: ""; property bool darkMode: true;'
            'property string accentColor: "#2080bb"; property var colors: ({}) }\n')
        (common / "qmldir").write_text(
            "singleton Settings Settings.qml\n"
            "singleton DisplayConfig DisplayConfig.qml\n"
            "singleton Theme Theme.qml\n")
        (tmp / "shell.qml").write_text(HARNESS)
        mock = tmp / "xrandr"
        mock.write_text(MOCK)
        mock.chmod(0o755)
        state = tmp / "state.json"
        state.write_text(json.dumps({
            "DP-1": {"x": 0, "y": 0, "primary": True},
            "DP-2": {"x": 1920, "y": 0, "primary": False},
        }))
        env = dict(os.environ, PATH=f"{tmp}:{os.environ['PATH']}",
                   QT_QPA_PLATFORM="offscreen", DISPLAY_TEST_STATE=str(state),
                   DISPLAY_TEST_RESULT=str(tmp / "result"),
                   XDG_STATE_HOME=str(tmp / "settings"))
        result = subprocess.run(["qs", "-p", str(tmp / "shell.qml")],
                                env=env, capture_output=True, text=True, timeout=30)
        outcome = (tmp / "result").read_text() if (tmp / "result").exists() else "No result"
        if not outcome.startswith("PASS:"):
            print(result.stdout)
            print(result.stderr)
        assert result.returncode == 0, "QML integration harness failed"
        assert outcome.startswith("PASS:"), outcome
        print(outcome)
        writes = state.with_suffix(".log").read_text().splitlines()
        assert len(writes) == 7, f"Unexpected RandR writes: {len(writes)}"
        print("PASS: exactly seven serialized writes; no real displays touched.")
        # Exercise the exact pre-WM Python block without sourcing unrelated
        # session environment/theme setup. Include a missing dock output.
        state.with_suffix(".log").unlink()
        profiles = tmp / "settings/quickshell/by-shell"
        profile = profiles / "active/settings.json"
        profile.parent.mkdir(parents=True)
        profile.write_text(json.dumps({"displayCmd":
            "--output disconnected-dock --mode 1920x1080 --pos 0x0 "
            "--output DP-1 --mode 1920x1080 --pos 0x0 "
            "--output DP-2 --mode 1920x1080 --pos 1920x0 "
            "--output DP-1 --primary"}))
        empty = profiles / "empty/settings.json"
        empty.parent.mkdir(parents=True)
        empty.write_text('{"displayCmd": ""}')
        script = (ROOT / "session/.xprofile").read_text().split(
            "    python3 - <<'PY'\n", 1)[1].split("\nPY\n", 1)[0]
        restored = subprocess.run([sys.executable, "-c", script], env=env,
                                  capture_output=True, text=True, timeout=20)
        assert restored.returncode == 0 and restored.stderr == "", restored.stderr
        startup_args = json.loads(state.with_suffix(".log").read_text())
        assert "disconnected-dock" not in startup_args
        assert json.loads(state.read_text())["DP-1"]["x"] == 0
        print("PASS: login restores a nonempty profile and filters absent outputs.")


if __name__ == "__main__":
    main()
