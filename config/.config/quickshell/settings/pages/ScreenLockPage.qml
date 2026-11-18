import QtQuick
import "../components"
import "../../common"

SettingsPage {
    title: "Screen Lock"

    SliderRow {
        label: "Blank and lock after (0 = never)"
        from: 0
        to: 30
        step: 1
        suffix: " min"
        value: Settings.blankMinutes
        onMoved: value => Settings.blankMinutes = value
    }

    SliderRow {
        label: "Display power off after (0 = never)"
        from: 0
        to: 60
        step: 5
        suffix: " min"
        value: Settings.dpmsMinutes
        onMoved: value => Settings.dpmsMinutes = value
    }

    ToggleRow {
        label: "Keep awake (until shell restart)"
        checked: PowerConfig.keepAwake
        onToggled: value => Settings.keepAwake = value
    }

    Text {
        width: parent.width
        text: "Screen blanking triggers the lock via xss-lock. Power-button "
            + "and lid behavior belong to systemd-logind "
            + "(/etc/systemd/logind.conf), which needs root to change."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }
}
