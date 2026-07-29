pragma Singleton
import QtQuick
import Quickshell

// Keeps awesome's screen padding in sync with the bar (the bar sets no X11
// strut — see Bar.qml). The lua is inlined with values baked in, so it
// works even if awesome's cached quickshell module predates
// apply_bar_padding; awesome also self-applies at startup/restart.
Singleton {
    id: root

    function init() { push(); }

    function push() {
        // Mirror the Variants fallback: unknown output = bars everywhere
        const known = Quickshell.screens.some(
            s => s.name === Settings.barScreen);
        const target = known ? Settings.barScreen : "";
        const w = Settings.barWidth + 3;
        const lua =
            "local t=\"" + target + "\" " +
            "for s in screen do " +
            "local m=(t==\"\") " +
            "for name in pairs(s.outputs) do if name==t then m=true end end " +
            "s.padding = m and { left = " + w + " } or { left = 0 } " +
            "end";
        Quickshell.execDetached(["awesome-client", lua]);
    }

    Connections {
        target: Settings
        function onBarWidthChanged() { debounce.restart(); }
        function onBarScreenChanged() { root.push(); }
    }

    Timer {
        id: debounce
        interval: 300
        onTriggered: root.push()
    }
}
