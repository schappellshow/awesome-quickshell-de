import QtQuick
import "../components"
import "../../common"

SettingsPage {
    title: "Notifications"

    SectionLabel { text: "POPUPS" }

    ToggleRow {
        label: "Do not disturb"
        checked: Settings.doNotDisturb
        onToggled: value => Settings.doNotDisturb = value
    }

    ToggleRow {
        label: "Silence alert sounds with DND"
        checked: Settings.dndSilenceSounds
        onToggled: value => Settings.dndSilenceSounds = value
    }

    Text {
        width: parent.width
        text: "Mutes streams tagged as system alerts while do-not-disturb is "
            + "on; music and video keep playing. The shell plays no sound "
            + "itself — a notification's ping comes from the app that sent "
            + "it, which is why DND alone hides the popup but not the sound. "
            + "Apps that play their own audio without tagging it as an alert "
            + "(most Electron apps) look like media and still ping — use "
            + "their own notification settings for those."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }

    SliderRow {
        label: "Popup timeout"
        from: 2
        to: 15
        step: 1
        suffix: "s"
        value: Settings.notifTimeoutMs / 1000
        onMoved: value => Settings.notifTimeoutMs = value * 1000
    }

    Text {
        width: parent.width
        text: "Apps can request their own timeout; this is the default when "
            + "they don't (very short app-requested timeouts are floored "
            + "at 3s so a popup can't flash by unread). Do-not-disturb "
            + "hides popups entirely."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }

    SectionLabel { text: "PLACEMENT" }

    ComboRow {
        label: "Popup corner"
        options: [
            { label: "Top right", value: "top-right" },
            { label: "Top left", value: "top-left" },
            { label: "Bottom right", value: "bottom-right" },
            { label: "Bottom left", value: "bottom-left" }
        ]
        current: Settings.notifPosition
        onSelected: value => Settings.notifPosition = value
    }
}
