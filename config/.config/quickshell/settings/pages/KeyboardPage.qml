import QtQuick
import Quickshell
import "../components"
import "../../common"

// Layout, key repeat, and every rebindable shortcut.
//
// The shortcuts live here rather than on a page of their own: they are the
// other half of "how this keyboard behaves", and splitting them off left two
// entries in the sidebar that people would have to guess between.
SettingsPage {
    id: page

    title: "Keyboard"

    // The registry arrives from awesome. An empty one means awesome has not
    // been reloaded since this shipped — worth saying out loud, because the
    // section would otherwise just look broken.
    readonly property bool ready: Shortcuts.registry.length > 0

    // awesome's group names, spelled for a settings page. "layout" becomes
    // WINDOW LAYOUT because this page already has a LAYOUT section and it
    // means the keyboard's.
    readonly property var groupTitles: ({
        "awesome":  "AWESOME",
        "launcher": "LAUNCHERS",
        "misc":     "SHELL",
        "media":    "MEDIA",
        "client":   "WINDOWS",
        "layout":   "WINDOW LAYOUT",
        "tag":      "TAGS"
    })

    // The picker deals in desktop entry ids, awesome in command lines, so the
    // entry's own Exec is what gets stored — already stripped of the %U/%F
    // field codes by quickshell. It stays visible and editable afterwards,
    // which matters for the entries that expect a terminal to be wrapped
    // around them.
    function addApp(entryId) {
        const e = DesktopEntries.byId(entryId);
        if (!e)
            return;
        Shortcuts.addCustom(e.command || e.execString || entryId);
    }

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

    SectionLabel { text: "SHORTCUTS" }

    Text {
        width: parent.width
        visible: !page.ready
        text: "No shortcuts to show yet. awesome publishes them when it "
            + "starts, so reload it with Super+Ctrl+R and come back."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.italic: true
        font.pointSize: 9
        color: Theme.muted
    }

    Text {
        width: parent.width
        visible: page.ready
        text: "Click a shortcut and press the combination you want. Escape "
            + "cancels, ↺ puts a shortcut back to its default. Changes apply "
            + "immediately — awesome does not need reloading."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }

    // Only when there is something to undo, so the page does not offer to
    // reset a set of shortcuts nobody has touched.
    ButtonRow {
        visible: page.ready && Shortcuts.overriddenCount() > 0
        label: Shortcuts.overriddenCount() === 1
            ? "1 shortcut changed" : Shortcuts.overriddenCount() + " shortcuts changed"
        buttonText: "Reset all"
        onClicked: Shortcuts.resetAll()
    }

    Text {
        width: parent.width
        visible: Shortcuts.conflict !== ""
        text: "That combination already belongs to \"" + Shortcuts.conflict
            + "\". Change or reset that one first."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 9
        color: Theme.urgent
    }

    Repeater {
        model: page.ready ? Shortcuts.groups() : []

        Column {
            id: groupCol

            required property var modelData

            width: parent.width
            spacing: 6

            SectionLabel {
                text: page.groupTitles[groupCol.modelData]
                    || groupCol.modelData.toUpperCase()
            }

            Repeater {
                model: Shortcuts.inGroup(groupCol.modelData)

                ShortcutRow {}
            }
        }
    }

    SectionLabel { text: "YOUR OWN SHORTCUTS" }

    Text {
        width: parent.width
        text: "Bind a command to a chord of your own — a second terminal, a "
            + "specific project, anything you would otherwise open by hand. "
            + "Pick an application below or type a command, then click its "
            + "chord to set one. They clash-check against everything above."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }

    Repeater {
        model: Shortcuts.custom

        ShortcutRow {}
    }

    AppPicker {
        label: "Add an application"
        onPicked: id => page.addApp(id)
    }

    TextFieldRow {
        label: "Or add a command (Enter to add)"
        placeholder: "e.g. warp-terminal"
        onAccepted: value => Shortcuts.addCustom(value)
    }

    SectionLabel {
        visible: page.ready
        text: "NOT REBINDABLE"
    }

    Text {
        width: parent.width
        visible: page.ready
        text: "Tag keys (Super+1…9, with Shift to move a window and Ctrl to "
            + "toggle) come from one pattern rather than 27 separate "
            + "bindings, so they are fixed. So are the hardware media keys on "
            + "the Fn row: they duplicate chords already listed above, and a "
            + "key with its job printed on it is not really a setting. "
            + "Neither is checked for clashes, so a shortcut set to Super+1 "
            + "would fire alongside the tag it lands on rather than instead "
            + "of it."
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: Theme.muted
    }
}
