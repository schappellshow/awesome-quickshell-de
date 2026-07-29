import QtQuick
import Quickshell.Io
import "../components"
import "../../common"

SettingsPage {
    id: page

    title: "Appearance"

    property var iconThemes: []

    Process {
        id: iconProbe
        running: true
        command: ["sh", "-c",
            "for d in /usr/share/icons/*/ \"$HOME/.local/share/icons\"/*/; do " +
            "[ -f \"$d/index.theme\" ] && basename \"$d\"; done | sort -u"]
        stdout: StdioCollector {
            onStreamFinished:
                page.iconThemes = text.trim().split("\n").filter(s => s !== "")
        }
    }

    SectionLabel { text: "THEME" }

    ToggleRow {
        label: "Dark mode"
        checked: Settings.darkMode
        onToggled: value => Settings.darkMode = value
    }

    ColorRow {
        label: "Accent color"
        colors: ["#2080bb", "#cc2263", "#40da76", "#da7340",
                 "#a740da", "#61c583", "#dac040"]
        current: Theme.accent
        onPicked: value => Settings.accentColor = value
    }

    SectionLabel { text: "ICONS" }

    ComboRow {
        label: "Icon theme"
        options: [{ label: "System default", value: "" }].concat(page.iconThemes)
        current: Settings.iconTheme
        onSelected: value => Settings.iconTheme = value
    }

    Text {
        width: parent.width
        text: "Dark/light mode is pushed to GTK, Qt/KDE, xsettingsd and the "
            + "portal (Electron apps). Icon theme changes may need an app "
            + "restart to fully apply."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }
}
