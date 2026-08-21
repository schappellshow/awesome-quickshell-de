import QtQuick
import "../../common"

// One editable colour: name, swatch, hex field, and a revert button that
// only appears once the value differs from the theme's built-in default.
//
// The field commits on Enter or focus loss and rejects anything that isn't
// #rrggbb, snapping back to the live value — a half-typed "#ab" must never
// reach Settings, or the shell restyles itself mid-keystroke.
Item {
    id: root

    property string label
    property string value          // live colour, always #rrggbb
    property string defaultValue   // theme built-in, for the revert button

    signal edited(string value)
    signal reverted()

    readonly property bool modified: value.toLowerCase() !== defaultValue.toLowerCase()

    width: parent.width
    height: 30

    // commit() assigns hex.text, which breaks its declarative binding to
    // `value`. Re-push it here so applying a scheme still updates the field,
    // but never while it has focus — that would rewrite what is being typed.
    onValueChanged: if (!hex.activeFocus) hex.text = root.value

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        font.family: Theme.fontFamily
        font.pointSize: 10
        color: Theme.text
    }

    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        // Revert. Kept in the layout when unmodified so the fields below it
        // stay aligned in a column of rows where only some have changed.
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 22
            radius: 11
            visible: root.modified
            color: revertHover.hovered ? Theme.surface : "transparent"

            Text {
                anchors.centerIn: parent
                text: "↺"
                font.family: Theme.fontFamily
                font.pointSize: 10
                color: Theme.subtext
            }

            HoverHandler { id: revertHover }

            MouseArea {
                anchors.fill: parent
                onClicked: root.reverted()
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 90
            height: 24
            radius: 8
            color: Theme.surfaceAlt
            border.width: hex.activeFocus ? 1 : 0
            border.color: Theme.accent

            TextInput {
                id: hex

                readonly property var valid: /^#[0-9A-Fa-f]{6}$/

                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                verticalAlignment: TextInput.AlignVCenter
                text: root.value
                font.family: Theme.fontFamily
                font.pointSize: 9
                color: valid.test(text) ? Theme.text : Theme.red
                maximumLength: 7
                clip: true
                selectByMouse: true

                function commit() {
                    if (valid.test(text) && text.toLowerCase() !== root.value.toLowerCase())
                        root.edited(text.toLowerCase());
                    else
                        text = root.value;
                }

                onAccepted: commit()
                onActiveFocusChanged: if (!activeFocus) commit()
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            height: 24
            radius: 6
            color: root.value
            border.width: 1
            border.color: Theme.muted
        }
    }
}
