import QtQuick
import "../../common"

// Read-only label/value pair.
Item {
    id: root

    property string label
    property string value

    width: parent.width
    height: Math.max(20, valueText.implicitHeight)

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        font.family: Theme.fontFamily
        font.pointSize: 10
        color: Theme.text
    }

    Text {
        id: valueText
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width * 0.6
        horizontalAlignment: Text.AlignRight
        text: root.value
        elide: Text.ElideLeft
        font.family: Theme.fontFamily
        font.pointSize: 10
        color: Theme.subtext
    }
}
