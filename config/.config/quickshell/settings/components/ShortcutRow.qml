import QtQuick
import "../../common"

// One shortcut: what it does, what it is bound to, and the one thing you can
// do about that besides rebinding it.
//
// The same row serves both kinds. A shortcut from awesome's registry can be
// reverted to its default; one the user added has no default to go back to,
// so its button removes it instead. Everything else — the chord, the
// capture, the conflict — behaves identically, which is the point of using
// one component rather than two that drift.
Item {
    id: root

    required property var modelData

    readonly property string shortcutId: root.modelData.id
    readonly property bool custom: Shortcuts.isCustom(root.shortcutId)
    readonly property string chord: Shortcuts.chordFor(root.shortcutId)
    readonly property bool listening: Shortcuts.capturing === root.shortcutId
    readonly property bool overridden: !root.custom
        && Shortcuts.isOverridden(root.shortcutId)

    width: parent.width
    height: 30

    Text {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 200
        elide: Text.ElideRight
        // A registry label is a sentence fragment written for awesome's own
        // cheatsheet, so it gets a capital here. A custom one is a command,
        // and "Warp-terminal" is not a command.
        text: root.custom
            ? Shortcuts.labelFor(root.shortcutId)
            : Shortcuts.labelFor(root.shortcutId).charAt(0).toUpperCase()
              + Shortcuts.labelFor(root.shortcutId).slice(1)
        font.family: Theme.fontFamily
        // A command is longer than a label and needs the room more than it
        // needs the size.
        font.pointSize: root.custom ? 9 : 10
        color: root.chord === "" ? Theme.muted : Theme.text
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        spacing: 6

        Rectangle {
            width: 26
            height: 24
            radius: 5
            visible: root.custom || root.overridden
            color: sideHover.hovered
                ? (root.custom ? Theme.urgent : Theme.surface)
                : Theme.surfaceAlt

            Text {
                anchors.centerIn: parent
                text: root.custom ? "✕" : "↺"
                font.family: Theme.fontFamily
                font.pointSize: 9
                color: Theme.subtext
            }

            HoverHandler { id: sideHover }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (root.custom)
                        Shortcuts.removeCustom(root.shortcutId);
                    else
                        Shortcuts.reset(root.shortcutId);
                }
            }
        }

        Rectangle {
            width: 150
            height: 24
            radius: 5
            color: root.listening ? Theme.accent
                : (chordHover.hovered ? Theme.surface : Theme.surfaceAlt)
            border.width: root.overridden ? 1 : 0
            border.color: Theme.accent

            Text {
                anchors.centerIn: parent
                width: parent.width - 12
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: root.listening ? "Press a chord…"
                    : (root.chord === "" ? "Click to set"
                       : Shortcuts.pretty(root.chord))
                font.family: Theme.fontFamily
                font.pointSize: 9
                color: root.listening ? Theme.base
                    : (root.chord === "" ? Theme.muted : Theme.text)
            }

            HoverHandler { id: chordHover }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (root.listening)
                        Shortcuts.stopCapture();
                    else
                        Shortcuts.startCapture(root.shortcutId);
                }
            }
        }
    }
}
