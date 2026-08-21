import QtQuick
import Quickshell.Io
import "../components"
import "../../common"

SettingsPage {
    id: page

    title: "Appearance"

    property var iconThemes: []
    property bool saving: false

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

    Component.onCompleted: ColorScheme.refresh()

    SectionLabel { text: "THEME" }

    ToggleRow {
        label: "Dark mode"
        checked: Settings.darkMode
        onToggled: value => Settings.darkMode = value
    }

    // Editing any colour clears Settings.colorScheme, so "Custom" is what
    // shows whenever the live palette isn't one of the saved schemes.
    ComboRow {
        label: "Color scheme"
        options: [{ label: "Custom", value: "" }].concat(
            ColorScheme.schemes.map(s => ({ label: s.name, value: s.name })))
        current: Settings.colorScheme
        onSelected: value => {
            if (value === "")
                return;
            for (const s of ColorScheme.schemes)
                if (s.name === value) {
                    ColorScheme.apply(s);
                    return;
                }
        }
    }

    ButtonRow {
        label: "Save current colors as a scheme"
        buttonText: page.saving ? "Cancel" : "Save as…"
        onClicked: page.saving = !page.saving
    }

    TextFieldRow {
        visible: page.saving
        label: "Scheme name"
        text: Settings.colorScheme
        placeholder: "My theme"
        onAccepted: value => {
            ColorScheme.save(value);
            page.saving = false;
        }
    }

    ButtonRow {
        visible: Settings.colorScheme !== ""
        label: "Delete \"" + Settings.colorScheme + "\""
        buttonText: "Delete"
        onClicked: ColorScheme.remove(Settings.colorScheme)
    }

    ButtonRow {
        label: "Reset every color to the default palette"
        buttonText: "Reset"
        onClicked: ColorScheme.resetAll()
    }

    // Surfaces are stored per mode so the dark/light toggle keeps working
    // inside a scheme. Rather than showing twelve fields, this edits the
    // mode that is currently active — what you see is what you're changing.
    SectionLabel {
        text: "SURFACES — " + (Settings.darkMode ? "DARK MODE" : "LIGHT MODE")
    }

    Repeater {
        model: Theme.surfaceKeys

        ColorEditRow {
            required property var modelData

            label: modelData.label
            value: String(Theme.colorOf(Theme.mode, modelData.key))
            defaultValue: Theme.defaultColors[Theme.mode][modelData.key]
            onEdited: v => ColorScheme.setColor(Theme.mode, modelData.key, v)
            onReverted: ColorScheme.resetColor(Theme.mode, modelData.key)
        }
    }

    Text {
        width: parent.width
        text: "Toggle dark mode above to edit the other mode's surfaces. A "
            + "scheme carries both, so switching modes keeps its colors."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }

    SectionLabel { text: "PALETTE" }

    Repeater {
        model: Theme.paletteKeys

        ColorEditRow {
            required property var modelData

            label: modelData.label
            value: String(Theme.colorOf("palette", modelData.key))
            defaultValue: Theme.defaultColors.palette[modelData.key]
            onEdited: v => ColorScheme.setColor("palette", modelData.key, v)
            onReverted: ColorScheme.resetColor("palette", modelData.key)
        }
    }

    SectionLabel { text: "ACCENT" }

    // Drawn from the palette above, so a scheme's own colours are the
    // choices here rather than a fixed list that would clash with it.
    ColorRow {
        label: "Accent color"
        colors: Theme.paletteKeys.map(k => String(Theme.colorOf("palette", k.key)))
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
        text: "Colors apply to the shell — bar, notifications, launcher, "
            + "power menu and this app. Dark/light mode is also pushed to "
            + "GTK, Qt/KDE, xsettingsd and the portal (Electron apps); icon "
            + "theme changes may need an app restart to fully apply.\n\n"
            + "Schemes are single files in " + ColorScheme.directory + " — "
            + "copy one there to install it, or send it to share it."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }
}
