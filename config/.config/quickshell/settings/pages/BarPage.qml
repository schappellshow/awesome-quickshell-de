import QtQuick
import Quickshell
import "../components"
import "../../common"

SettingsPage {
    title: "Bar"

    SectionLabel { text: "GEOMETRY" }

    SliderRow {
        label: "Bar width"
        from: 28
        to: 48
        step: 2
        suffix: "px"
        value: Settings.barWidth
        onMoved: value => Settings.barWidth = value
    }

    SliderRow {
        label: "Background opacity"
        from: 0
        to: 100
        step: 5
        suffix: "%"
        value: Settings.barOpacity
        onMoved: value => Settings.barOpacity = value
    }

    SliderRow {
        label: "Background blur"
        from: 0
        to: 100
        step: 5
        suffix: "%"
        value: Settings.barBlur
        onMoved: value => Settings.barBlur = value
    }

    CycleRow {
        label: "Bar screen"
        value: Settings.barScreen === "" ? "All screens" : Settings.barScreen
        onCycle: {
            const opts = [""].concat(Quickshell.screens.map(s => s.name));
            const i = opts.indexOf(Settings.barScreen);
            Settings.barScreen = opts[(i + 1) % opts.length];
        }
    }

    SectionLabel { text: "FONTS" }

    FontRow {
        label: "Section labels"
        sample: "NGT  VOL  NET  CPU"
        current: Settings.fontLabels
        onSelected: family => Settings.fontLabels = family
    }

    FontRow {
        label: "Clock"
        sample: "07 48 AM"
        current: Settings.fontClock
        onSelected: family => Settings.fontClock = family
    }

    FontRow {
        label: "App names"
        sample: "Firefox  Ghostty  Slack"
        current: Settings.fontApps
        onSelected: family => Settings.fontApps = family
    }

    Text {
        width: parent.width
        text: "Icon glyphs always use the Nerd Font — that's glyph coverage, "
            + "not styling, and changing it would turn every bar icon into a "
            + "box. App names apply once the Apps section exists."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }

    SectionLabel { text: "SECTIONS" }

    ToggleRow {
        label: "Media button"
        checked: Settings.showMediaPill
        onToggled: value => Settings.showMediaPill = value
    }

    ToggleRow {
        label: "System tray"
        checked: Settings.showTray
        onToggled: value => Settings.showTray = value
    }

    ToggleRow {
        label: "Notification bell"
        checked: Settings.showNotifBell
        onToggled: value => Settings.showNotifBell = value
    }

    ToggleRow {
        label: "Night light"
        checked: Settings.showNightLight
        onToggled: value => Settings.showNightLight = value
    }

    ToggleRow {
        label: "Screen lock (auto-lock state)"
        checked: Settings.showScreenLock
        onToggled: value => Settings.showScreenLock = value
    }

    ToggleRow {
        label: "Volume"
        checked: Settings.showVolume
        onToggled: value => Settings.showVolume = value
    }

    ToggleRow {
        label: "Network"
        checked: Settings.showNetwork
        onToggled: value => Settings.showNetwork = value
    }

    ToggleRow {
        label: "Bluetooth"
        checked: Settings.showBluetooth
        onToggled: value => Settings.showBluetooth = value
    }

    ToggleRow {
        label: "Battery"
        checked: Settings.showBattery
        onToggled: value => Settings.showBattery = value
    }

    ToggleRow {
        label: "Layout indicator"
        checked: Settings.showLayoutBox
        onToggled: value => Settings.showLayoutBox = value
    }

    SectionLabel { text: "SYSTEM MONITOR" }

    ToggleRow {
        label: "CPU/RAM pill"
        checked: Settings.showSysMon
        onToggled: value => Settings.showSysMon = value
    }

    TextFieldRow {
        label: "Conky config for the popout (Enter to apply)"
        text: Settings.conkyConfig
        placeholder: "~/.conky/my.conkyrc (optional)"
        onAccepted: value => {
            if (value !== "")
                Settings.conkyConfig = value;
        }
    }

    Text {
        width: parent.width
        text: "Click the CPU/RAM pill (or Super+Shift+M) to toggle the "
            + "conky dashboard — it pops out beside the bar, above your "
            + "windows, and toggles away again. Right-click opens htop."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }
}
