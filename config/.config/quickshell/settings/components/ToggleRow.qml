import QtQuick
import "../../common"

Item {
    id: root

    property string label
    property bool checked
    signal toggled(bool value)

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
        id: track
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 44
        height: 24
        radius: 12
        color: root.checked ? Theme.accent : Theme.surface

        Rectangle {
            width: 18
            height: 18
            radius: 9
            y: 3
            x: root.checked ? track.width - width - 3 : 3
            color: Theme.text
            Behavior on x {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.toggled(!root.checked)
    }
}
