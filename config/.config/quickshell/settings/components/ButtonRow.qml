import QtQuick
import "../../common"

Item {
    id: root

    property string label
    property string buttonText
    signal clicked()

    width: parent.width
    height: 30

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
        width: btnText.implicitWidth + 24
        height: 26
        radius: 8
        color: hover.hovered ? Theme.accent : Theme.surface

        Text {
            id: btnText
            anchors.centerIn: parent
            text: root.buttonText
            font.family: Theme.fontFamily
            font.pointSize: 9
            color: Theme.text
        }

        HoverHandler { id: hover }

        MouseArea {
            anchors.fill: parent
            onClicked: root.clicked()
        }
    }
}
