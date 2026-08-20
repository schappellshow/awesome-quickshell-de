import QtQuick
import Quickshell
import "../common"

// Start button: opens awesome's existing desktop right-click menu.
//
// The menu is NOT redrawn here. modules/keys.lua already defines it
// (Apps, Terminal, Files, Settings, System Monitor, Keybindings, Awesome,
// Power), themed by theme.lua's menu_* settings and bound to right-click on
// the desktop. Reusing it means one definition and one appearance, rather
// than a bar menu that drifts from the desktop one.
Item {
    id: root

    property bool vertical: BarEdge.vertical

    visible: Settings.showStart
    implicitWidth: 26
    implicitHeight: 26

    // Icon resolution, best first:
    //   1. whatever the user set (a path, or a theme icon name)
    //   2. "start-here", the freedesktop name for exactly this button, which
    //      most icon themes ship
    //   3. the distro logo some distributions drop in /usr/share/pixmaps
    //   4. a drawn glyph, so the button is never invisible
    readonly property string iconSource: {
        const p = Settings.startIcon;
        if (p !== "") {
            if (p.startsWith("/"))
                return "file://" + p;
            if (p.startsWith("~/"))
                return "file://" + Quickshell.env("HOME") + p.slice(1);
            const themed = Quickshell.iconPath(p, true);
            if (themed !== "")
                return themed;
        }
        for (const n of ["start-here", "distributor-logo"]) {
            const hit = Quickshell.iconPath(n, true);
            if (hit !== "")
                return hit;
        }
        return "";
    }

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: hover.hovered ? Theme.surface : "transparent"

        Behavior on color {
            ColorAnimation { duration: 100 }
        }
    }

    Image {
        id: logo
        anchors.centerIn: parent
        width: 20
        height: 20
        source: root.iconSource
        sourceSize.width: 40
        sourceSize.height: 40
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        visible: status === Image.Ready
    }

    // Drawn fallback: three bars, the universally understood "menu". Drawn
    // rather than a glyph character because the emoji fonts hijack most
    // menu-ish codepoints and ignore `color` (the same trap the media
    // button's play/pause hit).
    Column {
        anchors.centerIn: parent
        visible: logo.status !== Image.Ready
        spacing: 3

        Repeater {
            model: 3
            Rectangle {
                width: 14
                height: 2
                radius: 1
                color: Theme.subtext
            }
        }
    }

    HoverHandler { id: hover }

    MouseArea {
        anchors.fill: parent
        onClicked: AwesomeState.exec("main_menu_toggle()")
    }
}
