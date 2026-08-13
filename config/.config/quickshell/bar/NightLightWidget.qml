import QtQuick
import Quickshell
import "../common"

// NGT: night light on/off, sitting just above the lock widget.
//   moon = night light ON  → gammastep is warming the screen
//   sun  = night light OFF → normal colour temperature
//
// Left-click calls NightLight.toggle(), the exact function Super+Shift+N
// reaches via `qs ipc call nightlight toggle`, so keybind and click cannot
// drift apart. Right-click opens the Night Light settings page for the
// temperature and schedule.
Item {
    id: root

    visible: Settings.showNightLight

    implicitWidth: stack.implicitWidth
    implicitHeight: stack.implicitHeight

    readonly property bool on: Settings.nightLightEnabled
    // Bar convention: "on" = accent blue, "off/inactive" = gray.
    readonly property color col: on ? Theme.accentBright : Theme.subtext

    // Label over value on a vertical bar, label beside it on a horizontal
    // one — a two-line stack is taller than a horizontal bar is thick.
    Grid {
        id: stack
        anchors.centerIn: parent
        columns: BarEdge.vertical ? 1 : 99
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
        spacing: BarEdge.vertical ? 1 : 4

        Text {
            text: "NGT"
            font.family: Theme.labelFont
            font.bold: true
            font.pointSize: 7
            color: Theme.muted
        }

        // Nerd Font glyphs: nf-fa-moon_o (U+F186) for on, and the Weather
        // Icons filled sun (U+E368) for off. Monochrome like the padlock, so
        // they honour `color` — the emoji ☀/🌙 would not.
        //
        // The sun used to be nf-fa-sun_o (U+F185), whose disc is small enough
        // that at 10pt the eight rays close up into a ring and the whole
        // thing reads as a gear. This one keeps a solid disc with the rays
        // still separated at that size.
        //
        // Written as \u escapes, not literal characters: these live in the
        // Unicode private use area, and pasting them around silently loses
        // them (this shipped as two empty strings the first time). The
        // escape also greps.
        Text {
            text: root.on ? "\uf186" : "\ue368"
            font.family: Theme.iconFont
            font.pointSize: 10
            color: root.col
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouseEvent => {
            if (mouseEvent.button === Qt.RightButton)
                // Page *id*, not its title — pageById falls back to the
                // first page on a miss rather than erroring.
                Quickshell.execDetached(
                    ["qs", "ipc", "call", "settings", "open", "nightlight"]);
            else
                NightLight.toggle();
        }
    }
}
