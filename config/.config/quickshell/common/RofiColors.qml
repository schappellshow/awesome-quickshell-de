pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Keeps rofi's colours in step with the live palette.
//
// rofi cannot read the shell's settings, so this renders the colours it uses
// into a small rasi file (bin/rofi-colors) that openmandriva.rasi imports.
// It follows whatever Theme resolves — any scheme, either mode, hand-edited
// colours — not only wallpaper-derived ones. rofi reads the file on launch,
// so there is nothing to reload; a rofi that is already open keeps the old
// colours until it is reopened.
//
// bright-blue is Theme.accentBright rather than brightBlue: that is the role
// it plays in the rasi (window border, prompt), and it is what the window
// borders use too, so the launcher and the windows agree.
Singleton {
    id: root

    readonly property string helper: Quickshell.env("HOME") + "/.local/bin/rofi-colors"

    function init() {
        // Touching the singleton is the point; the trigger binding below
        // does the work once it exists.
        settle.restart();
    }

    readonly property var args: [
        "base=" + Theme.base,
        "surface=" + Theme.surface,
        "muted=" + Theme.muted,
        "text=" + Theme.text,
        "subtext=" + Theme.subtext,
        "blue=" + Theme.blue,
        "bright-blue=" + Theme.accentBright,
        "red=" + Theme.red
    ]

    onArgsChanged: settle.restart()

    // Several colours change together on a scheme switch; write once.
    Timer {
        id: settle
        interval: 300
        onTriggered: Quickshell.execDetached([root.helper].concat(root.args))
    }
}
