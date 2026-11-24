import QtQuick
import Quickshell

// Opt a quickshell surface into compositor blur, with one line:
//
//     PanelWindow {
//         id: panel
//         color: "transparent"
//         BlurHint { window: panel }          // enabled: true by default
//     }
//
//     BlurHint { window: panel; enabled: Settings.somePopupBlur; radius: 16 }
//
// picom blurs nothing that is a dock (every PanelWindow, the bar included),
// so a surface asks for it. How, and why this does not use a window title or
// id, is in modules/blur.lua; the picom side is the _AQS_BLUR rules at the end
// of picom/fx-normal.conf.
//
//   window    the PanelWindow (or any QsWindow) to blur behind. Required.
//   enabled   blur on or off; follows the window being visible.
//   radius    corner radius of the blur in px, matching the surface's own
//             rounded corners. Only these exist: 0, 10, 16, 24, and "round"
//             (any value above 24), which suits the ring. Anything else
//             snaps to the nearest one, up to 24.
//   refresh() call after moving the window (changing its margins) without
//             resizing it, so awesome learns the new rectangle.
//
// Blur only shows through a translucent surface: give the window
// `color: "transparent"` and draw the panel with an alpha below 1, around
// 0.5-0.75. Performance mode removes blur in the compositor, nothing to do here.
Scope {
    id: root

    property var window: null
    property bool enabled: true
    property int radius: 10

    // The X property level picom's rules key on (see fx-normal.conf).
    readonly property int level: {
        const r = root.radius;
        if (r <= 0) return 4;
        if (r > 24) return 5;
        if (r <= 13) return 1;
        if (r <= 20) return 2;
        return 3;
    }

    // Settings -> Transparency & blur can turn blur off everywhere; then no
    // surface asks for it (picom would not blur anyway).
    readonly property bool active:
        root.enabled && Settings.blurEnabled && root.window !== null && root.window.backingWindowVisible
    readonly property string key: "blur" + Math.random().toString(36).slice(2, 10)

    // Last request sent, so an unchanged one is not sent twice.
    property string sent: ""

    function refresh() {
        settle.restart();
    }

    function lua(code) {
        Quickshell.execDetached(["awesome-client", code]);
    }

    function apply() {
        if (!root.active) {
            if (root.sent !== "") {
                root.lua(`shell_blur_clear("${root.key}")`);
                root.sent = "";
            }
            return;
        }
        const w = root.window;
        const p = w.contentItem.mapToGlobal(0, 0);
        const args = `${Math.round(p.x)}, ${Math.round(p.y)}, `
            + `${Math.round(w.width)}, ${Math.round(w.height)}, ${root.level}`;
        if (args === root.sent)
            return;
        root.sent = args;
        root.lua(`shell_blur("${root.key}", ${args})`);
    }

    // Let the window finish mapping and awesome finish placing it before
    // reading where it ended up.
    Timer {
        id: settle
        interval: 150
        onTriggered: root.apply()
    }

    onActiveChanged: settle.restart()
    onLevelChanged: if (root.active) settle.restart()

    Connections {
        target: root.window
        ignoreUnknownSignals: true
        function onWidthChanged() { if (root.active) settle.restart(); }
        function onHeightChanged() { if (root.active) settle.restart(); }
        function onScreenChanged() { if (root.active) settle.restart(); }
    }

    Component.onDestruction: {
        if (root.sent !== "")
            root.lua(`shell_blur_clear("${root.key}")`);
    }
}
