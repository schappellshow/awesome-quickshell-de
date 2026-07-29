pragma Singleton
import QtQuick
import Quickshell

// Keyboard layout + repeat rate via setxkbmap/xset. Values live in
// Settings and are replayed at login (X doesn't persist them).
Singleton {
    id: root

    function init() { apply(); }

    function apply() {
        // "-option ''" clears all XKB options — OMLx's 90-zap.conf enables
        // terminate:ctrl_alt_bksp (Ctrl+Alt+Backspace kills the X server),
        // one slip away from the Super+BackSpace power menu. Single
        // setxkbmap invocation so the layout and the clear can't race.
        const cmd = ["setxkbmap"];
        if (Settings.kbLayout !== "") {
            const parts = Settings.kbLayout.split(":");
            cmd.push(parts[0]);
            if (parts.length > 1)
                cmd.push("-variant", parts[1]);
        }
        cmd.push("-option", "");
        Quickshell.execDetached(cmd);
        Quickshell.execDetached(["xset", "r", "rate",
            String(Settings.kbRepeatDelay), String(Settings.kbRepeatRate)]);
    }

    Connections {
        target: Settings
        function onKbLayoutChanged() { root.apply(); }
        function onKbRepeatDelayChanged() { debounce.restart(); }
        function onKbRepeatRateChanged() { debounce.restart(); }
    }

    // Sliders fire continuously while dragged
    Timer {
        id: debounce
        interval: 300
        onTriggered: root.apply()
    }
}
