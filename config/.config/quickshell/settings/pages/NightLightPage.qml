import QtQuick
import "../components"
import "../../common"

SettingsPage {
    title: "Night Light"

    SectionLabel { text: "GAMMASTEP" }

    ToggleRow {
        label: "Enabled"
        checked: Settings.nightLightEnabled
        onToggled: value => Settings.nightLightEnabled = value
    }

    SliderRow {
        label: "Temperature"
        from: 1500
        to: 4500
        step: 100
        suffix: "K"
        value: Settings.nightLightTemp
        onMoved: value => Settings.nightLightTemp = value
    }

    Text {
        width: parent.width
        text: "Also on Super+Shift+N. Lower temperature = warmer screen."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }

    SectionLabel { text: "SCHEDULE" }

    ToggleRow {
        label: "Automatic schedule"
        checked: Settings.nightLightSchedule
        onToggled: value => Settings.nightLightSchedule = value
    }

    TextFieldRow {
        label: "Turn on at (HH:MM, Enter to apply)"
        text: Settings.nightLightStart
        placeholder: "21:00"
        onAccepted: value => {
            if (/^\d{1,2}:\d{2}$/.test(value))
                Settings.nightLightStart = value;
        }
    }

    TextFieldRow {
        label: "Turn off at (HH:MM, Enter to apply)"
        text: Settings.nightLightStop
        placeholder: "07:00"
        onAccepted: value => {
            if (/^\d{1,2}:\d{2}$/.test(value))
                Settings.nightLightStop = value;
        }
    }

    Text {
        width: parent.width
        text: "The schedule only acts at the on/off times — toggling "
            + "manually in between always wins. Overnight ranges "
            + "(21:00 → 07:00) work fine."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }
}
