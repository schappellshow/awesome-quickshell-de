pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Pointer settings (libinput props via xinput), applied to every slave
// pointer device. Props a device lacks (e.g. tapping on a mouse) fail
// silently, which is fine.
Singleton {
    id: root

    property var pointerIds: []

    function init() { probe.running = true; }

    Process {
        id: probe
        command: ["sh", "-c",
            "xinput list | awk '/slave +pointer/ && !/XTEST/ { " +
            "for (i=1;i<=NF;i++) if ($i ~ /^id=/) { sub(\"id=\",\"\",$i); print $i } }'"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.pointerIds = text.trim().split("\n").filter(s => s !== "");
                root.apply();
            }
        }
    }

    function apply() {
        for (const id of pointerIds) {
            Quickshell.execDetached(["xinput", "set-prop", id,
                "libinput Accel Speed", String(Settings.mouseAccel)]);
            Quickshell.execDetached(["xinput", "set-prop", id,
                "libinput Natural Scrolling Enabled", Settings.naturalScroll ? "1" : "0"]);
            Quickshell.execDetached(["xinput", "set-prop", id,
                "libinput Tapping Enabled", Settings.tapToClick ? "1" : "0"]);
        }
    }

    Connections {
        target: Settings
        function onMouseAccelChanged() { debounce.restart(); }
        function onNaturalScrollChanged() { root.apply(); }
        function onTapToClickChanged() { root.apply(); }
    }

    Timer {
        id: debounce
        interval: 300
        onTriggered: root.apply()
    }
}
