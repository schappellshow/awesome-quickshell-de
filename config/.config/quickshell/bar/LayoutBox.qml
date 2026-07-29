import QtQuick
import "../common"

// Awesome layout indicator. Click / scroll-up: next layout;
// right-click / scroll-down: previous.
Item {
    id: root

    property int screenIndex: 1
    property string layoutName: ""

    readonly property var abbrev: ({
        "dwindle":  "dwi",
        "tile":     "til",
        "tileleft": "tll",
        "fairv":    "fai",
        "fairh":    "fai",
        "max":      "max",
        "floating": "flt",
    })

    width: 24
    height: 18

    Text {
        anchors.centerIn: parent
        text: root.abbrev[root.layoutName] ?? (root.layoutName ? root.layoutName.slice(0, 3) : "---")
        font.family: Theme.fontFamily
        font.bold: true
        font.pointSize: 8
        color: mouse.containsMouse ? Theme.text : Theme.muted
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouseEvent =>
            AwesomeState.cycleLayout(root.screenIndex, mouseEvent.button === Qt.RightButton ? -1 : 1)
        onWheel: wheelEvent =>
            AwesomeState.cycleLayout(root.screenIndex, wheelEvent.angleDelta.y > 0 ? 1 : -1)
    }
}
