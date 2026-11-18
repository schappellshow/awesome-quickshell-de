import QtQuick
import "../components"
import "../../common"

SettingsPage {
    title: "Battery"

    SliderRow {
        label: "Low battery warning"
        from: 5
        to: 30
        step: 1
        suffix: "%"
        value: Settings.batteryWarnPct
        onMoved: value => Settings.batteryWarnPct = value
    }

    SliderRow {
        label: "Critical: suspend at"
        from: 2
        to: 10
        step: 1
        suffix: "%"
        value: Settings.batteryCriticalPct
        onMoved: value => Settings.batteryCriticalPct = value
    }

    Text {
        width: parent.width
        text: "These thresholds apply to laptops only; they have no effect "
            + "on desktops without a battery."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }
}
