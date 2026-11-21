import QtQuick
import "../common"

// A flat toolbar button for the screenshot editor.
Rectangle {
    id: b

    property string label: ""
    property string hint: ""          // shown after the label, muted ("Ctrl+Z")
    property bool active: false
    property color swatch: "transparent"
    property bool isSwatch: false
    signal clicked()

    implicitWidth: isSwatch ? 24 : Math.max(32, row.implicitWidth + 20)
    implicitHeight: isSwatch ? 24 : 30
    radius: isSwatch ? 12 : 6
    opacity: enabled ? 1 : 0.4
    color: isSwatch ? swatch : (active ? Theme.accent : (hover.hovered && enabled ? Theme.surface : "transparent"))
    border.width: isSwatch ? (active ? 3 : 1) : 0
    border.color: isSwatch && active ? Theme.accentBright : Theme.muted

    Row {
        id: row
        visible: !b.isSwatch
        anchors.centerIn: parent
        spacing: 6
        Text {
            text: b.label
            font.family: Theme.fontFamily
            font.pointSize: 9
            color: b.active ? Theme.base : Theme.text
        }
        Text {
            visible: b.hint !== ""
            text: b.hint
            font.family: Theme.fontFamily
            font.pointSize: 8
            color: b.active ? Theme.base : Theme.muted
        }
    }

    HoverHandler { id: hover }
    MouseArea {
        anchors.fill: parent
        enabled: b.enabled
        onClicked: b.clicked()
    }
}
