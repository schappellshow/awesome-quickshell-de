import QtQuick
import "../common"

// Small clickable pill used by the gear panel
Rectangle {
    id: chip
    property string text
    property bool active: false
    property bool dim: false
    signal clicked()
    width: chipText.implicitWidth + 16
    height: 22
    radius: 11
    color: chip.active ? Theme.accent : chipHover.hovered ? Theme.surfaceAlt : Theme.surface
    opacity: chip.dim ? 0.5 : 1
    Text {
        id: chipText
        anchors.centerIn: parent
        text: chip.text
        font.family: Theme.fontFamily
        font.pointSize: 8
        color: chip.active ? Theme.base : Theme.text
    }
    HoverHandler { id: chipHover }
    MouseArea { anchors.fill: parent; onClicked: chip.clicked() }
}
