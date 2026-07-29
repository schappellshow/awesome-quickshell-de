pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Backlight control via brightnessctl. `available` stays false on machines
// with no backlight device (desktops), making up/down harmless no-ops.
// Steps are applied optimistically for a snappy OSD, then trued up against
// the real value once the burst of keypresses settles.
Singleton {
    id: root

    property bool available: false
    property int percent: 0

    function up() { step("5%+", 5); }
    function down() { step("5%-", -5); }

    function step(arg, delta) {
        if (!available)
            return;
        Quickshell.execDetached(["brightnessctl", "-q", "set", arg]);
        percent = Math.max(0, Math.min(100, percent + delta));
        probeDebounce.restart();
    }

    Process {
        id: probe
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            // e.g. "intel_backlight,backlight,4437,37%,11812"
            onStreamFinished: {
                const m = text.match(/,(\d+)%,/);
                if (m) {
                    root.percent = parseInt(m[1]);
                    root.available = true;
                }
            }
        }
    }

    Timer {
        id: probeDebounce
        interval: 250
        onTriggered: probe.running = true
    }

    Component.onCompleted: probe.running = true
}
