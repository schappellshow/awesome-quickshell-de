import QtQuick
import Quickshell
import Quickshell.Io
import "../components"
import "../../common"

SettingsPage {
    id: page

    title: "Mouse"

    property var cursorThemes: []

    // cursor-preview lists every theme that ships a `cursors/` directory and
    // renders each one's own arrow to a PNG, so the dropdown can show what a
    // theme looks like instead of only naming it. Both user-writable icon
    // directories are searched, so a theme unpacked into
    // ~/.local/share/icons appears the next time this page opens — which is
    // every time it is navigated to, since SettingsWindow rebuilds the page.
    Process {
        id: cursorProbe
        running: true
        command: [Quickshell.env("HOME") + "/.local/bin/cursor-preview"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                for (const line of text.trim().split("\n")) {
                    const i = line.indexOf("\t");
                    if (i > 0)
                        list.push({ label: line.slice(0, i),
                                    value: line.slice(0, i),
                                    icon: line.slice(i + 1) });
                }
                page.cursorThemes = list;
            }
        }
    }

    SectionLabel { text: "POINTERS (ALL DEVICES)" }

    SliderRow {
        label: "Acceleration"
        from: -1
        to: 1
        step: 0.1
        value: Math.round(Settings.mouseAccel * 10) / 10
        onMoved: value => Settings.mouseAccel = value
    }

    ToggleRow {
        label: "Natural scrolling"
        checked: Settings.naturalScroll
        onToggled: value => Settings.naturalScroll = value
    }

    ToggleRow {
        label: "Tap to click (touchpads)"
        checked: Settings.tapToClick
        onToggled: value => Settings.tapToClick = value
    }

    Text {
        width: parent.width
        text: "Applied to every pointer device via libinput; options a "
            + "device doesn't support are skipped automatically."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }

    SectionLabel { text: "CURSOR" }

    ComboRow {
        label: "Cursor theme"
        options: [{ label: "System default", value: "" }].concat(page.cursorThemes)
        current: Settings.cursorTheme
        onSelected: value => Settings.cursorTheme = value
    }

    ComboRow {
        label: "Cursor size"
        options: [16, 24, 32, 48, 64].map(n => ({ label: n + " px", value: n }))
        current: Settings.cursorSize
        onSelected: value => Settings.cursorSize = value
    }

    Text {
        width: parent.width
        text: "The desktop background changes immediately and GTK apps follow "
            + "within a second; Qt apps and already-open windows keep their "
            + "old pointer until they restart. Reload awesome "
            + "(Super+Ctrl+R) to refresh the resize and move cursors.\n\n"
            + "New themes: unpack one into ~/.local/share/icons/ and reopen "
            + "this page — anything with a cursors/ folder is listed, with a "
            + "preview drawn from the theme's own arrow."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }
}
