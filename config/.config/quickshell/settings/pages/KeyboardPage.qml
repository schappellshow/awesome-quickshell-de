import QtQuick
import "../components"
import "../../common"

SettingsPage {
    title: "Keyboard"

    SectionLabel { text: "LAYOUT" }

    ComboRow {
        label: "Layout"
        options: [
            { label: "System default", value: "" },
            { label: "US English", value: "us" },
            { label: "US International", value: "us:intl" },
            { label: "UK English", value: "gb" },
            { label: "German", value: "de" },
            { label: "French", value: "fr" },
            { label: "Spanish", value: "es" },
            { label: "Italian", value: "it" },
            { label: "Portuguese (Brazil)", value: "br" },
            { label: "Russian", value: "ru" },
            { label: "Dvorak", value: "us:dvorak" },
            { label: "Colemak", value: "us:colemak" }
        ]
        current: Settings.kbLayout
        onSelected: value => Settings.kbLayout = value
    }

    SectionLabel { text: "KEY REPEAT" }

    SliderRow {
        label: "Repeat delay"
        from: 200
        to: 1000
        step: 50
        suffix: " ms"
        value: Settings.kbRepeatDelay
        onMoved: value => Settings.kbRepeatDelay = value
    }

    SliderRow {
        label: "Repeat rate"
        from: 10
        to: 100
        step: 5
        suffix: "/s"
        value: Settings.kbRepeatRate
        onMoved: value => Settings.kbRepeatRate = value
    }
}
