import QtQuick
import Quickshell
import "../components"
import "../../common"

// Start button, pinned launchers and the open-window list.
//
// There is no "app mode" switch. These are three ordinary bar sections, so
// they are enabled and placed on the Bar page like every other section, and a
// KDE- or GNOME-shaped bar is an arrangement rather than a mode. The preset
// below just sets that arrangement up in one go; everything it does can be
// undone or adjusted piecemeal afterwards.
SettingsPage {
    id: page
    title: "Apps"

    SectionLabel { text: "LAYOUT PRESET" }

    Text {
        width: parent.width
        text: "Turns on the start button, pinned apps and the open-window "
            + "list, and arranges them at the start of the bar: start, pins, "
            + "tags, windows. Everything stays adjustable on the Bar page "
            + "afterwards — this only sets the same switches you would."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }

    ButtonRow {
        label: "Desktop-style bar"
        buttonText: "Set up"
        onClicked: {
            Settings.showStart = true;
            Settings.showPinned = true;
            Settings.showWindowList = true;
            BarSections.arrange(["start", "pinned", "tags", "windows"], "start");
        }
    }

    SectionLabel { text: "START BUTTON" }

    TextFieldRow {
        label: "Icon (path or theme icon name, Enter to apply)"
        text: Settings.startIcon
        placeholder: "start-here"
        onAccepted: value => Settings.startIcon = value
    }

    Text {
        width: parent.width
        text: "Empty falls back to the \"start-here\" theme icon, then a "
            + "drawn menu glyph. Opens the same menu as right-clicking the "
            + "desktop, so its contents live in awesome's modules/keys.lua."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }

    SectionLabel { text: "PINNED APPS" }

    Text {
        width: parent.width
        visible: PinnedApps.ids.length === 0
        text: Settings.showWindowList
            ? "Nothing pinned. Pick one below, or right-click any icon in "
              + "the bar's open-window section."
            : "Nothing pinned. Pick one below."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.italic: true
        font.pointSize: 9
        color: Theme.muted
    }

    Repeater {
        model: PinnedApps.ids

        Item {
            id: pinRow

            required property var modelData
            required property int index

            width: parent.width
            height: 30

            // AppLookup directly rather than bar/AppIcon.qml: a settings
            // page reaching into the bar's components is the wrong
            // direction, and this only needs the resolved icon.
            readonly property string iconSource: AppLookup.iconFor([pinRow.modelData])
            readonly property string appName: AppLookup.nameFor([pinRow.modelData])

            Image {
                id: pinIcon
                anchors.verticalCenter: parent.verticalCenter
                x: 2
                width: 18
                height: 18
                source: pinRow.iconSource
                sourceSize.width: 36
                sourceSize.height: 36
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                visible: status === Image.Ready
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                x: 30
                width: parent.width - 130
                elide: Text.ElideRight
                text: pinRow.appName !== "" ? pinRow.appName : pinRow.modelData
                font.family: Theme.fontFamily
                font.pointSize: 10
                color: Theme.text
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                spacing: 4

                Repeater {
                    model: [
                        { glyph: "↑", delta: -1 },
                        { glyph: "↓", delta: 1 },
                        { glyph: "✕", delta: 0 }
                    ]

                    Rectangle {
                        id: btn

                        required property var modelData

                        readonly property bool isRemove: btn.modelData.delta === 0
                        readonly property bool enabled: btn.isRemove
                            || (btn.modelData.delta < 0 ? pinRow.index > 0
                                : pinRow.index < PinnedApps.ids.length - 1)

                        width: 26
                        height: 22
                        radius: 5
                        opacity: btn.enabled ? 1 : 0.3
                        color: btnHover.hovered && btn.enabled
                            ? (btn.isRemove ? Theme.urgent : Theme.surface)
                            : Theme.surfaceAlt

                        Text {
                            anchors.centerIn: parent
                            text: btn.modelData.glyph
                            font.family: Theme.fontFamily
                            font.pointSize: 9
                            color: Theme.subtext
                        }

                        HoverHandler { id: btnHover }

                        MouseArea {
                            anchors.fill: parent
                            enabled: btn.enabled
                            onClicked: {
                                if (btn.isRemove)
                                    PinnedApps.unpin(pinRow.modelData);
                                else
                                    PinnedApps.move(pinRow.index,
                                                    pinRow.index + btn.modelData.delta);
                            }
                        }
                    }
                }
            }
        }
    }

    AppPicker {
        label: "Add an application"
        excluded: PinnedApps.ids
        onPicked: id => PinnedApps.pin(id)
    }

    Text {
        width: parent.width
        text: "Click an application to pin it. Already-pinned entries are "
            + "greyed out."
            + (Settings.showWindowList
                ? " Right-clicking a running window in the bar pins it too, "
                  + "without coming here."
                : " Turning on \"Open windows\" on the Bar page also lets you "
                  + "pin a running app by right-clicking it there.")
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }
}
