import QtQuick
import "../../common"

// Label + row of color swatches; the current one gets a ring.
Item {
    id: root

    property string label
    property var colors: []      // array of color strings
    property color current
    signal picked(string value)

    width: parent.width
    height: 30

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

        Repeater {
            model: root.colors

            Rectangle {
                id: swatch

                required property var modelData

                width: 22
                height: 22
                radius: 11
                color: modelData
                border.width: Qt.colorEqual(root.current, modelData) ? 2 : 0
                border.color: Theme.text

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.picked(swatch.modelData)
                }
            }
        }
    }
}
