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
        // Every side is written on every push, so moving the bar from one
        // edge to another clears the padding it used to reserve.
        const lua =
            "local t=\"" + target + "\" " +
            "for s in screen do " +
            "local m=(t==\"\") " +
            "for name in pairs(s.outputs) do if name==t then m=true end end " +
            "local p={left=0,right=0,top=0,bottom=0} " +
            "if m then p[\"" + BarEdge.edge + "\"]=" + w + " end " +
            "s.padding = p " +
            "end";
        Quickshell.execDetached(["awesome-client", lua]);
    }

    Connections {
        target: Settings
        function onBarWidthChanged() { debounce.restart(); }
        function onBarScreenChanged() { root.push(); }
        function onBarPositionChanged() { root.push(); }
    }

    Timer {
        id: debounce
        interval: 300
        onTriggered: root.push()
    }
}
