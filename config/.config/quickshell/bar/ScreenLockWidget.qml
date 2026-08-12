import QtQuick
import Quickshell
import "../common"

// SCN: shows whether the screen will auto-lock on idle.
//   closed padlock = keep-awake ON  → screen stays on, won't auto-lock
//   open padlock   = keep-awake OFF → screen auto-locks after the timeout
// Left-click toggles keep-awake (same as Super+Z); right-click locks now.
Item {
    id: root

    visible: Settings.showScreenLock

    // Closed for either hold: the manual one (Super+Z) or an app asking to
    // stay awake (video playback). Both genuinely mean "won't auto-lock".
    readonly property bool closed: PowerConfig.holdAwake
    // Bar convention: "on" = accent blue, "off/inactive" = gray. Closed
    // padlock = keep-awake ON (screen held on) = blue; open = will
    // auto-lock = gray.
    readonly property color col: closed ? Theme.accentBright : Theme.subtext

    implicitWidth: stack.implicitWidth
    implicitHeight: stack.implicitHeight

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
            text: "SCN"
            font.family: Theme.labelFont
            font.bold: true
            font.pointSize: 7
            color: Theme.muted
        }

        // Nerd Font padlock glyph: nf-fa-lock (U+F023) / nf-fa-unlock
        // (U+F09C). Monochrome, so it honours `color` like the bar text.
        Text {
            text: root.closed ? "" : ""
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
                Quickshell.execDetached(["loginctl", "lock-session"]);
            else
                PowerConfig.keepAwake = !PowerConfig.keepAwake;
        }
    }
}
