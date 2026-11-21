import QtQuick
import Quickshell.Io
import "../components"
import "../../common"

SettingsPage {
    id: page

    title: "Theme"

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

    // ---- Colours from wallpaper ----------------------------------------
    SectionLabel { text: "COLORS FROM WALLPAPER" }

    ButtonRow {
        label: WallpaperPalette.busy ? "Reading the wallpaper…"
             : "Derive a palette from the current wallpaper"
        buttonText: "Preview"
        onClicked: WallpaperPalette.generate()
    }

    Text {
        visible: WallpaperPalette.error !== ""
        width: parent.width
        text: WallpaperPalette.error
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 9
        color: Theme.red
    }

    // Everything below is drawn from the PREVIEW scheme, in the mode that is
    // active now; the live colours do not change until Apply.
    Item {
        id: preview

        readonly property var scheme: WallpaperPalette.preview
        readonly property var s: scheme === null ? null
                                 : scheme[Settings.darkMode ? "dark" : "light"]

        // Black or white, whichever reads on `bg`.
        function onColor(bg) {
            const c = Qt.color(bg);
            const lum = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
            return lum > 0.45 ? "#161819" : "#ffffff";
        }

        visible: scheme !== null
        width: parent.width
        height: visible ? mock.height + swatches.height + note.height + 24 : 0

        Rectangle {
            id: mock
            width: parent.width
            height: 150
            radius: 10
            color: preview.s ? preview.s.base : "transparent"
            border.width: 1
            border.color: preview.s ? preview.s.surface : "transparent"

            // bar: pills on the background
            Row {
                x: 10; y: 10
                spacing: 8

                Rectangle {
                    width: 54; height: 24; radius: 12
                    color: preview.s ? preview.s.surface : "transparent"
                    Rectangle {
                        x: 8; anchors.verticalCenter: parent.verticalCenter
                        width: 10; height: 10; radius: 5
                        color: preview.scheme ? preview.scheme.accent : "transparent"
                    }
                    Text {
                        x: 24; anchors.verticalCenter: parent.verticalCenter
                        text: "1 2"
                        font.family: Theme.fontFamily; font.pointSize: 8
                        color: preview.scheme ? preview.scheme.accent : "transparent"
                    }
                }
                Rectangle {
                    width: 62; height: 24; radius: 12
                    color: preview.s ? preview.s.surface : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "12:34"
                        font.family: Theme.fontFamily; font.pointSize: 8
                        color: preview.s ? preview.s.text : "transparent"
                    }
                }
                Rectangle {
                    width: 96; height: 24; radius: 12
                    color: preview.s ? preview.s.surface : "transparent"
                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        Repeater {
                            model: ["green", "gold", "red"]
                            Rectangle {
                                required property string modelData
                                width: 10; height: 10; radius: 5
                                color: preview.scheme ? preview.scheme.palette[modelData] : "transparent"
                            }
                        }
                    }
                }
            }

            // popup card
            Rectangle {
                x: 10; y: 46
                width: parent.width - 20
                height: 94
                radius: 10
                color: preview.s ? preview.s.surfaceAlt : "transparent"

                Column {
                    x: 12; y: 10
                    spacing: 3
                    Text {
                        text: "Popup title"
                        font.family: Theme.fontFamily; font.pointSize: 10
                        font.bold: true
                        color: preview.s ? preview.s.text : "transparent"
                    }
                    Text {
                        text: "Secondary text on the popup"
                        font.family: Theme.fontFamily; font.pointSize: 8
                        color: preview.s ? preview.s.subtext : "transparent"
                    }
                    Text {
                        text: "muted hint"
                        font.family: Theme.fontFamily; font.pointSize: 8
                        color: preview.s ? preview.s.muted : "transparent"
                    }
                    Row {
                        spacing: 10
                        Repeater {
                            model: [["accent text", "accent"], ["error", "red"],
                                    ["ok", "green"], ["warning", "gold"]]
                            Text {
                                required property var modelData
                                text: modelData[0]
                                font.family: Theme.fontFamily; font.pointSize: 8
                                color: !preview.scheme ? "transparent"
                                    : modelData[1] === "accent" ? preview.scheme.accent
                                    : preview.scheme.palette[modelData[1]]
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 10
                    width: 70; height: 26; radius: 8
                    color: preview.scheme ? preview.scheme.accent : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "Button"
                        font.family: Theme.fontFamily; font.pointSize: 9
                        color: preview.scheme ? preview.onColor(preview.scheme.accent) : "transparent"
                    }
                }
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    width: 40; height: 20; radius: 10
                    color: preview.scheme ? preview.scheme.accent : "transparent"
                    Rectangle {
                        x: parent.width - width - 3; y: 3
                        width: 14; height: 14; radius: 7
                        color: preview.s ? preview.s.text : "transparent"
                    }
                }
            }
        }

        // 6 surfaces, accent, 8 palette colours
        Row {
            id: swatches
            y: mock.height + 8
            spacing: 4
            Repeater {
                model: {
                    const sc = preview.scheme;
                    if (sc === null)
                        return [];
                    const m = sc[Settings.darkMode ? "dark" : "light"];
                    return [m.base, m.surface, m.surfaceAlt, sc.accent]
                        .concat(Theme.paletteKeys.map(k => sc.palette[k.key]));
                }
                Rectangle {
                    required property string modelData
                    width: Math.max(14, (preview.width - 11 * 4) / 12)
                    height: 22
                    radius: 5
                    color: modelData
                    border.width: 1
                    border.color: Theme.surface
                }
            }
        }

        Text {
            id: note
            y: swatches.y + swatches.height + 6
            width: parent.width
            text: preview.scheme === null ? "" :
                (preview.scheme.meta.fallback
                    ? "No usable color in this wallpaper — the default palette is kept."
                    : "Hue " + Math.round(preview.scheme.meta.hue) + "°, strength "
                      + Math.round(preview.scheme.meta.strength * 100) + "%. "
                      + "Text and accents are lightness-adjusted to stay readable.")
                + " Shown in " + (Settings.darkMode ? "dark" : "light") + " mode."
            wrapMode: Text.Wrap
            font.family: Theme.fontFamily
            font.pointSize: 8
            color: Theme.muted
        }
    }

    ButtonRow {
        visible: WallpaperPalette.preview !== null
        label: "Save as \"" + WallpaperPalette.schemeName(WallpaperPalette.previewSource)
               + "\" and apply"
        buttonText: "Apply"
        onClicked: WallpaperPalette.applyPreview()
    }

    ButtonRow {
        visible: WallpaperPalette.preview !== null
        label: "Leave the colors as they are"
        buttonText: "Cancel"
        onClicked: WallpaperPalette.cancel()
    }

    ToggleRow {
        label: "Follow wallpaper changes"
        checked: Settings.followWallpaper
        onToggled: value => Settings.followWallpaper = value
    }

    Text {
        width: parent.width
        text: "Off by default. When on, a new wallpaper re-derives the colors and "
            + "updates the scheme \"" + WallpaperPalette.followName + "\" "
            + "(one scheme, rewritten each time). Turning it off keeps the "
            + "current colors; Reset above or any saved scheme goes back."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
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
