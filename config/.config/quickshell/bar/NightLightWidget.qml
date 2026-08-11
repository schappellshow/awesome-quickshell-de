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

    Column {
        id: stack
        anchors.centerIn: parent
        spacing: 1

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "NGT"
            font.family: Theme.fontFamily
            font.bold: true
            font.pointSize: 7
            color: Theme.muted
        }

        // Nerd Font glyphs: nf-fa-moon_o (U+F186) / nf-fa-sun_o (U+F185).
        // Monochrome like the padlock, so they honour `color` — the emoji
        // ☀/🌙 would not.
        //
        // Written as \u escapes, not literal characters: these live in the
        // Unicode private use area, and pasting them around silently loses
        // them (this shipped as two empty strings the first time). The
        // escape also greps.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.on ? "\uf186" : "\uf185"
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
