import QtQuick
import "../../common"

// Label over a single-line text input; emits accepted(text) on Enter.
Column {
    id: root

    property string label
    property string text
    property string placeholder: ""
    signal accepted(string value)

    width: parent.width
    spacing: 4

    Text {
        text: root.label
        font.family: Theme.fontFamily
        font.pointSize: 10
        color: Theme.text
    }

    Rectangle {
        width: parent.width
        height: 28
        radius: 8
        color: Theme.surfaceAlt
        border.width: input.activeFocus ? 1 : 0
        border.color: Theme.accent

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter
            text: root.text
            font.family: Theme.fontFamily
            font.pointSize: 9
            color: Theme.text
            clip: true
            selectByMouse: true
            onAccepted: root.accepted(text)
        }

        Text {
            anchors.fill: input
            verticalAlignment: Text.AlignVCenter
            visible: input.text.length === 0 && !input.activeFocus
            text: root.placeholder
            font.family: Theme.fontFamily
            font.pointSize: 9
            color: Theme.muted
        }
    }
}
