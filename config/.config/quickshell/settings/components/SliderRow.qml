import QtQuick
import "../../common"

Column {
    id: root

    property string label
    property real from: 0
    property real to: 100
    property real step: 1
    property real value
    property string suffix: ""

    signal moved(real value)

    width: parent.width
    spacing: 6

    Item {
        width: parent.width
        height: labelText.implicitHeight

        Text {
            id: labelText
            text: root.label
            font.family: Theme.fontFamily
            font.pointSize: 10
            color: Theme.text
        }

        Text {
            anchors.right: parent.right
            text: root.value + root.suffix
            font.family: Theme.fontFamily
            font.pointSize: 10
            color: Theme.subtext
        }
    }

    Item {
        width: parent.width
        height: 20

        readonly property real ratio: (root.value - root.from) / (root.to - root.from)

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4
            radius: 2
            color: Theme.surface
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.ratio * parent.width
            height: 4
            radius: 2
            color: Theme.accent
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: parent.ratio * (parent.width - width)
            width: 14
            height: 14
            radius: 7
            color: Theme.accentBright
        }

        MouseArea {
            anchors.fill: parent
            function update(mouseX) {
                let r = Math.max(0, Math.min(1, mouseX / width));
                let v = root.from + r * (root.to - root.from);
                v = Math.round(v / root.step) * root.step;
                root.moved(v);
            }
            onPressed: mouseEvent => update(mouseEvent.x)
            onPositionChanged: mouseEvent => {
                if (pressed)
                    update(mouseEvent.x);
            }
        }
    }
}
