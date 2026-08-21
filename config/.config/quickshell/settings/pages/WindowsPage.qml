import QtQuick
import Quickshell
import "../components"
import "../../common"

// Window mode: how windows are arranged, across the whole desktop.
//
// awesome has no global layout — layout is a per-tag property and every
// screen has its own tags, so three different layouts can be live at once.
// This page presents one setting and lets WindowMode impose it, with an
// optional per-monitor override.
SettingsPage {
    id: page
    title: "Windows"

    readonly property var layoutOptions: [
        { label: "Dwindle (spiral)",   value: "dwindle" },
        { label: "Tile (master left)", value: "tile" },
        { label: "Tile left",          value: "tileleft" },
        { label: "Tile bottom",        value: "tilebottom" },
        { label: "Fair",               value: "fairv" },
        { label: "Maximised",          value: "max" }
    ]

    SectionLabel { text: "MODE" }

    CycleRow {
        label: "Window mode"
        value: Settings.windowMode === "floating" ? "Floating" : "Tiling"
        onCycle: Settings.windowMode =
            Settings.windowMode === "floating" ? "tiling" : "floating"
    }

    Text {
        width: parent.width
        text: Settings.windowMode === "floating"
            ? "Windows float and can be moved and resized freely, on every "
              + "monitor and every tag. Tiling layouts do not apply."
            : "Windows are arranged automatically. Choose the pattern below, "
              + "and override it per monitor if one screen suits a different "
              + "shape."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }

    SectionLabel {
        text: "DEFAULT LAYOUT"
        visible: Settings.windowMode !== "floating"
    }

    ComboRow {
        visible: Settings.windowMode !== "floating"
        label: "Every monitor"
        options: [{ label: "Automatic (match monitor shape)", value: "" }]
            .concat(page.layoutOptions)
        current: Settings.defaultLayout
        onSelected: value => Settings.defaultLayout = value
    }

    Text {
        width: parent.width
        visible: Settings.windowMode !== "floating" && Settings.defaultLayout === ""
        text: "Automatic keeps the shipped behaviour: portrait monitors stack "
            + "windows top to bottom, landscape monitors use dwindle. Choosing "
            + "a layout here replaces that on every monitor."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }

    SectionLabel {
        text: "PER MONITOR"
        visible: Settings.windowMode !== "floating"
    }

    Repeater {
        model: Settings.windowMode !== "floating" ? Quickshell.screens : []

        ComboRow {
            required property var modelData

            readonly property string ov:
                (Settings.monitorLayouts || ({}))[modelData.name] || ""

            label: modelData.name + "  ("
                + modelData.width + "x" + modelData.height + ")"
            options: [{ label: "Use the default", value: "" }]
                .concat(page.layoutOptions)
            current: ov
            onSelected: value => WindowMode.setMonitorLayout(modelData.name, value)
        }
    }

    Text {
        width: parent.width
        visible: Settings.windowMode !== "floating"
        text: "Only monitors you set explicitly are stored, so unplugging one "
            + "loses nothing and a new monitor picks up the default. These "
            + "survive switching to Floating and back."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }

    ButtonRow {
        visible: Settings.windowMode !== "floating"
            && Object.keys(Settings.monitorLayouts || ({})).length > 0
        label: "Clear every per-monitor override"
        buttonText: "Clear"
        onClicked: WindowMode.clearOverrides()
    }

    SectionLabel { text: "NOTE" }

    Text {
        width: parent.width
        text: "These are defaults, not locks. Changing a layout by hand — the "
            + "bar's layout indicator, or Super+Space — still works and sticks "
            + "until awesome restarts or a monitor is plugged in, at which "
            + "point these settings are applied again."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }
}
