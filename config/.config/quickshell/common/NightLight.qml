pragma Singleton
import QtQuick
import Quickshell

// Night light via gammastep in one-shot mode. State lives in Settings so the
// settings window, `qs ipc call nightlight toggle`, and restarts all agree.
Singleton {
    id: root

    function toggle() {
        Settings.nightLightEnabled = !Settings.nightLightEnabled;
    }

    function apply() {
        if (Settings.nightLightEnabled)
            Quickshell.execDetached(["gammastep", "-O", String(Settings.nightLightTemp), "-P"]);
        else
            Quickshell.execDetached(["gammastep", "-x"]);
    }

    Connections {
        target: Settings
        function onNightLightEnabledChanged() { root.apply(); }
        function onNightLightTempChanged() {
            if (Settings.nightLightEnabled)
                debounce.restart();
        }
    }

    // Don't hammer gammastep while the temperature slider is dragged
    Timer {
        id: debounce
        interval: 300
        onTriggered: root.apply()
    }

    // ── Optional schedule ──────────────────────────────────────────────
    // Edge-triggered: it only flips nightLightEnabled when crossing the
    // start/stop boundary, so manual toggles (Super+Shift+N) stay in
    // control between boundaries. Off by default (schedule is opt-in).
    property bool lastInWindow: false

    function parseTime(t) {
        const m = /^(\d{1,2}):(\d{2})$/.exec(t);
        if (!m)
            return null;
        return parseInt(m[1]) * 60 + parseInt(m[2]);
    }

    function inWindow() {
        const now = new Date();
        const cur = now.getHours() * 60 + now.getMinutes();
        const s = parseTime(Settings.nightLightStart);
        const e = parseTime(Settings.nightLightStop);
        if (s === null || e === null)
            return false;
        // Overnight windows (21:00 → 07:00) wrap midnight
        return s <= e ? (cur >= s && cur < e) : (cur >= s || cur < e);
    }

    Timer {
        interval: 30000
        repeat: true
        triggeredOnStart: true
        running: Settings.nightLightSchedule
        onTriggered: {
            const inw = root.inWindow();
            if (inw !== root.lastInWindow) {
                root.lastInWindow = inw;
                Settings.nightLightEnabled = inw;
            }
        }
    }

    Component.onCompleted: {
        if (Settings.nightLightEnabled)
            apply();
    }
}
