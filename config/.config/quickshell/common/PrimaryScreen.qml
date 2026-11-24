pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The primary monitor: the one the shell treats as "home" for surfaces that
// live on a single screen (the system dashboard today).
//
//   * Bar on one monitor: that monitor is the primary, whatever is saved.
//   * Bar on every monitor: Settings.primaryScreen, by output name. If that
//     is empty or not connected, X's RandR primary, else the first monitor.
//
// `screen` is therefore never null while any monitor exists, and `name` is
// never empty; `fellBack` says a saved choice was unusable so the settings
// page can tell the user.
Singleton {
    id: root

    // Output name RandR calls primary ("" if none is flagged)
    property string xPrimary: ""

    readonly property bool barOnOne:
        Quickshell.screens.some(s => s.name === Settings.barScreen)

    // The monitor the user (or the bar) chose, if it is connected
    readonly property var chosen: {
        const want = root.barOnOne ? Settings.barScreen : Settings.primaryScreen;
        return Quickshell.screens.find(s => s.name === want) ?? null;
    }

    // What an empty or stale choice becomes
    readonly property var fallback:
        Quickshell.screens.find(s => s.name === root.xPrimary)
        ?? (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)

    readonly property var screen: root.chosen ?? root.fallback
    readonly property string name: root.screen ? root.screen.name : ""

    // A saved name that is no longer connected (an empty one is just unset)
    readonly property bool fellBack:
        !root.barOnOne && Settings.primaryScreen !== "" && root.chosen === null

    function contains(scr, gx, gy) {
        return gx >= scr.x && gx < scr.x + scr.width
            && gy >= scr.y && gy < scr.y + scr.height;
    }

    // The monitor containing a global point, or null
    function screenAt(gx, gy) {
        return Quickshell.screens.find(s => root.contains(s, gx, gy)) ?? null;
    }

    function refresh() {
        if (!probe.running)
            probe.running = true;
    }

    Component.onCompleted: root.refresh()

    Connections {
        target: Quickshell
        function onScreensChanged() { root.refresh(); }
    }

    // `xrandr --listmonitors` marks the primary with a star: " 0: +*DP-3 ..."
    Process {
        id: probe
        command: ["timeout", "5s", "xrandr", "--listmonitors"]
        stdout: StdioCollector {
            onStreamFinished: {
                let found = "";
                for (const line of text.split("\n")) {
                    const m = line.match(/^\s*\d+:\s*([+*]*)(\S+)/);
                    if (m && m[1].includes("*")) {
                        found = m[2];
                        break;
                    }
                }
                root.xPrimary = found;
            }
        }
    }
}
