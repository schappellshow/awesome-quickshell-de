import QtQuick
import Quickshell
import "../components"
import "../../common"

SettingsPage {
    id: page

    title: "Default Apps"

    // Re-read on every show, not just on creation: handlers can change from
    // outside (an app claiming a type on install, xdg-mime on the CLI), and
    // the page instance is reused when you navigate back to it.
    Component.onCompleted: DefaultApps.refresh()
    onVisibleChanged: if (visible) DefaultApps.refresh()

    SectionLabel { text: "OPEN WITH" }

    Repeater {
        model: DefaultApps.categories

        ComboRow {
            required property var modelData

            label: modelData.label
            options: DefaultApps.choices[modelData.mime] || []
            current: DefaultApps.current[modelData.mime] || ""
            onSelected: value => DefaultApps.setDefault(modelData.mime, value)
        }
    }

    Text {
        width: parent.width
        text: "Written to ~/.config/mimeapps.list with xdg-mime, the shared "
            + "freedesktop standard — so other apps and file managers honour "
            + "these too. Picking a browser also claims https and HTML files; "
            + "images, video and audio each cover the common sibling formats."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }

    ButtonRow {
        label: "Re-read handlers from disk"
        buttonText: "Refresh"
        onClicked: DefaultApps.refresh()
    }
}
