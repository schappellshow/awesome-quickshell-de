pragma Singleton
import QtQuick
import Quickshell

// The shell's palette. Ships the OpenMandriva colours (dark values match
// the original awesome theme.lua) and lets every one of them be overridden
// from Settings → Appearance, saved as a named scheme, and shared as a file.
//
// Surfaces carry a value per mode so the dark/light toggle keeps working
// inside a scheme; the accent colours are shared between modes, which is
// how this palette was already built.
//
// Overrides live in Settings.colors and are resolved per key, so a scheme
// written before a colour was added still picks up a sensible default for
// it rather than rendering that one element transparent.
Singleton {
    id: root

    readonly property bool isDark: Settings.darkMode
    readonly property string mode: isDark ? "dark" : "light"

    readonly property var defaultColors: ({
        dark: {
            base: "#232627", surface: "#444444", surfaceAlt: "#333637",
            text: "#ffffff", subtext: "#afb3bd", muted: "#767676"
        },
        light: {
            base: "#ecf2ff", surface: "#d6dce8", surfaceAlt: "#e1e6f2",
            text: "#232627", subtext: "#4a5158", muted: "#8f96a3"
        },
        palette: {
            red: "#cc2263", green: "#40da76", orange: "#da7340",
            blue: "#2080bb", purple: "#a740da", teal: "#61c583",
            gold: "#dac040", brightBlue: "#40a5da"
        }
    })

    // Editable colours, in the order the Appearance page lists them.
    readonly property var surfaceKeys: [
        { key: "base",       label: "Background" },
        { key: "surface",    label: "Surface" },
        { key: "surfaceAlt", label: "Surface (alt)" },
        { key: "text",       label: "Text" },
        { key: "subtext",    label: "Subtext" },
        { key: "muted",      label: "Muted" }
    ]
    readonly property var paletteKeys: [
        { key: "red",        label: "Red" },
        { key: "green",      label: "Green" },
        { key: "orange",     label: "Orange" },
        { key: "blue",       label: "Blue" },
        { key: "purple",     label: "Purple" },
        { key: "teal",       label: "Teal" },
        { key: "gold",       label: "Gold" },
        { key: "brightBlue", label: "Bright blue" }
    ]

    // Reading Settings.colors here is what subscribes every colour binding
    // below to it, so reassigning that object restyles the shell live.
    function colorOf(group, key) {
        const all = Settings.colors || ({});
        const g = all[group];
        if (g !== undefined && g !== null
                && g[key] !== undefined && g[key] !== "")
            return g[key];
        return defaultColors[group][key];
    }

    // Surfaces / text
    readonly property color base:       colorOf(mode, "base")
    readonly property color surface:    colorOf(mode, "surface")
    readonly property color surfaceAlt: colorOf(mode, "surfaceAlt")
    readonly property color text:       colorOf(mode, "text")
    readonly property color subtext:    colorOf(mode, "subtext")
    readonly property color muted:      colorOf(mode, "muted")

    // Accents
    readonly property color red:        colorOf("palette", "red")
    readonly property color green:      colorOf("palette", "green")
    readonly property color orange:     colorOf("palette", "orange")
    readonly property color blue:       colorOf("palette", "blue")
    readonly property color purple:     colorOf("palette", "purple")
    readonly property color teal:       colorOf("palette", "teal")
    readonly property color gold:       colorOf("palette", "gold")
    readonly property color brightBlue: colorOf("palette", "brightBlue")

    // Accent follows Settings; an accent that matches the scheme's own blue
    // keeps that scheme's hand-picked bright variant, others derive theirs.
    readonly property color accent:       Settings.accentColor
    readonly property color accentBright: Qt.colorEqual(accent, blue)
                                            ? brightBlue : Qt.lighter(accent, 1.25)
    readonly property color urgent:       red

    readonly property string fontFamily: "Hack"
    // Nerd Font for icon glyphs (fonts-ttf-nerd-jetbrains-mono). Only used
    // for icons — text stays in Hack. Glyphs are monochrome and honour
    // QML `color`, unlike emoji.
    //
    // Deliberately NOT user-selectable: this is glyph coverage, not taste.
    // Pointing it at a font without the Nerd Font private-use area turns
    // every icon in the bar into a tofu box.
    readonly property string iconFont: "JetBrainsMono Nerd Font"

    // Bar fonts, user-selectable from Settings → Bar. Each falls back to
    // fontFamily when unset, so an empty setting and an uninstalled font
    // both land on the theme default instead of Qt's generic fallback.
    readonly property string labelFont: Settings.fontLabels !== ""
                                            ? Settings.fontLabels : fontFamily
    readonly property string clockFont: Settings.fontClock !== ""
                                            ? Settings.fontClock : fontFamily
    readonly property string appFont:   Settings.fontApps !== ""
                                            ? Settings.fontApps : fontFamily
    readonly property int radius: 10
}
