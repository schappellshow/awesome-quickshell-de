import QtQuick
import Quickshell.Widgets
import "../../common"

// One tray app: its icon, its name, and whether the bar draws it.
//
// A hidden app that isn't running still gets a row — that's the only way
// back once you've hidden something and then quit it — so the row also has
// to say which of the two it is.
Item {
    id: root

    property string label
    property string iconSource
    property bool shown: true
    property bool running: true

    signal toggled(bool value)

    width: parent.width
    height: 30

    IconImage {
        id: icon
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        height: 18
        source: root.iconSource
        // The app isn't running, so there's no icon to ask it for. Dim the
        // gap rather than leaving a hole where every other row has an icon.
        visible: root.iconSource !== ""
        opacity: root.shown ? 1 : 0.45
    }

    Rectangle {
        anchors.centerIn: icon
        width: 8
        height: 8
        radius: 4
        visible: root.iconSource === ""
        color: Theme.surfaceAlt
    }

    Text {
        anchors.left: icon.right
        anchors.leftMargin: 10
        anchors.right: statusText.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        elide: Text.ElideRight
        font.family: Theme.fontFamily
        font.pointSize: 10
        color: root.shown ? Theme.text : Theme.muted
    }

    Text {
        id: statusText
        anchors.right: track.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.running
        // An invisible item still takes its width in an anchor chain, which
        // would stop every running app's name short by the width of a label
        // that isn't drawn.
        width: statusText.visible ? statusText.implicitWidth : 0
        text: "not running"
        font.family: Theme.fontFamily
        font.italic: true
        font.pointSize: 9
        color: Theme.muted
    }

    Rectangle {
        id: track
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 38
        height: 20
        radius: 10
        color: root.shown ? Theme.accent : Theme.surface

        Rectangle {
            width: 14
            height: 14
            radius: 7
            y: 3
            x: root.shown ? track.width - width - 3 : 3
            color: Theme.text
            Behavior on x {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.toggled(!root.shown)
    }
}
