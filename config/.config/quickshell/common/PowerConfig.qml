pragma Singleton
import QtQuick
import Quickshell

// Screen blank/DPMS timeouts via xset (this is what triggers xss-lock's
// idle lock), plus a non-persisted keep-awake override. Owns the values
// that used to be hard-coded in awesome's autostart.
Singleton {
    id: root

    // Manual hold (Super+Z / the SCN pill / Settings)
    property bool keepAwake: false
    // Held by an app via org.freedesktop.ScreenSaver — video playback etc.
    // (see local/.local/bin/screensaver-inhibitor). Kept separate from
    // keepAwake so a video ending can't switch off a hold the user set by
    // hand, and vice versa.
    property bool appInhibited: false

    readonly property bool holdAwake: keepAwake || appInhibited

    function init() { apply(); }

    function apply() {
        if (holdAwake) {
            Quickshell.execDetached(["sh", "-c", "xset s off; xset -dpms"]);
            return;
        }
        const b = Settings.blankMinutes * 60;
        const d = Settings.dpmsMinutes * 60;
        Quickshell.execDetached(["sh", "-c",
            (b > 0 ? "xset s " + b + " " + b : "xset s off") + "; " +
            (d > 0 ? "xset dpms 0 0 " + d : "xset -dpms")]);
    }

    // Watch the derived property, NOT its two inputs: a change handler on
    // keepAwake/appInhibited runs before the holdAwake binding has
    // re-evaluated, so apply() would act on the previous value and leave
    // xset exactly one step behind (screen stayed lockable during video,
    // then stayed awake after it ended).
    onHoldAwakeChanged: apply()

    Connections {
        target: Settings
        function onBlankMinutesChanged() { debounce.restart(); }
        function onDpmsMinutesChanged() { debounce.restart(); }
    }

    Timer {
        id: debounce
        interval: 300
        onTriggered: root.apply()
    }
}
