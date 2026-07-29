import QtQuick
import "../../common"

// Label with a click-to-cycle value chip — for short option lists.
Item {
    id: root

    property string label
    property string value
    signal cycle()

    width: parent.width
    height: 28

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        font.family: Theme.fontFamily
        font.pointSize: 10
        color: Theme.text
    }

    Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: valueText.implicitWidth + 20
        height: 24
        radius: 12
        color: hover.hovered ? Theme.surfaceAlt : Theme.surface

        Text {
            id: valueText
            anchors.centerIn: parent
            text: root.value
            font.family: Theme.fontFamily
            font.pointSize: 9
            color: Theme.accentBright
        }

        HoverHandler { id: hover }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.cycle()
    }
}
