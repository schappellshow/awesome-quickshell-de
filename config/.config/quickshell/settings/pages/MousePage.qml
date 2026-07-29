import QtQuick
import "../components"
import "../../common"

SettingsPage {
    title: "Mouse"

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
}
