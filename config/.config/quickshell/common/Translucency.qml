pragma Singleton
import QtQuick
import Quickshell

// Transparency & blur (Settings -> Transparency & blur).
//
// The values live in Settings; this is where they reach the parts of the
// desktop that are not QML:
//
//   * picom (blur on/off and strength, menu / dropdown / tooltip opacity,
//     inactive window opacity): handed to picom-effects by PerformanceMode,
//     because that is the one place that restarts picom.
//   * awesome's desktop and start menu (menuOpacity): pushed here, through
//     awesome-client. awful.menu reads its colors only when it is created, so
//     awesome rebuilds the menu (modules/translucency.lua); an open menu is
//     closed. awesome also reads menuOpacity from settings.json by itself
//     when it starts, so nothing is pushed at startup.
//   * shell popups (dashboard, ring): they read Settings directly.
//
// Nothing is applied per slider tick: a change is sent once the value has
// been still for a moment.
Singleton {
    id: root

    // Whether blur is really on right now: the setting, and not performance
    // mode (which removes it in the compositor). Surfaces that draw
    // differently with and without blur read this.
    readonly property bool blurOn: Settings.blurEnabled && !PerformanceMode.active

    function init() {}

    Timer {
        id: menuTimer
        interval: 400
        onTriggered: Quickshell.execDetached(
            ["awesome-client", "shell_menu_opacity(" + Settings.menuOpacity + ")"])
    }

    Connections {
        target: Settings
        function onMenuOpacityChanged() { menuTimer.restart(); }
    }
}
