pragma Singleton
import QtQuick
import Quickshell

// Open/closed state of the native system dashboard (dashboard/Dashboard.qml),
// and the one toggle the SYS pill and `qs ipc call sysmon toggle` share.
//
// Two display modes (Settings.dashboardMode):
//   popout  hidden until toggled; hugs the bar, above windows.
//   pinned  always on the bar screen's desktop, below every window. The
//           pill / key then *raises* it above the windows until pressed again
//           (a peek), instead of hiding it.
// Which dashboard exists at all is Settings.sysmonDashboard: "native" (this)
// or "conky" (SysMon.toggleConky, unchanged).
Singleton {
    id: root

    readonly property bool useNative: Settings.sysmonDashboard !== "conky"
    readonly property bool pinned: useNative && Settings.dashboardMode === "pinned"

    // Popout shown / pinned dashboard raised
    property bool open: false
    property bool raised: false

    // The window exists (and sampling runs) only while this is true
    readonly property bool visible: useNative && (pinned || open)
    // Drawn above the windows
    readonly property bool above: useNative && (pinned ? raised : open)

    function toggle() {
        if (pinned)
            raised = !raised;
        else
            open = !open;
    }

    // A mode or dashboard change starts from a clean state
    onUseNativeChanged: { open = false; raised = false; }
    onPinnedChanged: { open = false; raised = false; }

    Binding {
        target: SysStats
        property: "active"
        value: root.visible
    }
}
