import QtQuick
import "../common"

// Awesome taglist. Left-click: view tag; right-click: toggle tag into view;
// scroll: next/prev tag (down = next, matching the vertical list).
// compact mode (other monitors' sections): smaller pills, empty tags hidden.
Column {
    id: root

    property var awScreen
    property bool compact: false

    spacing: root.compact ? 3 : 4

    Repeater {
        model: {
            const tags = root.awScreen ? root.awScreen.tags : [];
            return root.compact
                ? tags.filter(t => t.selected || t.occupied || t.urgent)
                : tags;
        }

        delegate: Rectangle {
            id: tagPill

            required property var modelData

            width: root.compact ? 16 : 22
            height: root.compact ? 18 : 26
            anchors.horizontalCenter: parent.horizontalCenter
            radius: width / 2
            color: modelData.urgent   ? Theme.urgent
                 : modelData.selected ? Theme.accent
                 : modelData.occupied ? Theme.surface
                 : "transparent"

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Theme.accent
                opacity: mouse.containsMouse && !tagPill.modelData.selected ? 0.33 : 0
            }

            Text {
                anchors.centerIn: parent
                text: tagPill.modelData.name
                font.family: Theme.fontFamily
                font.bold: true
                font.pointSize: root.compact ? 7 : 9
                color: tagPill.modelData.urgent   ? Theme.text
                     : tagPill.modelData.selected ? Theme.text
                     : tagPill.modelData.occupied ? Theme.subtext
                     : Theme.muted
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouseEvent => {
                    if (mouseEvent.button === Qt.RightButton)
                        AwesomeState.toggleTag(root.awScreen.index, tagPill.modelData.index);
                    else
                        AwesomeState.viewTag(root.awScreen.index, tagPill.modelData.index);
                }
                // Scroll down = next tag, matching the downward visual
                // order of the vertical taglist
                onWheel: wheelEvent => {
                    if (wheelEvent.angleDelta.y > 0)
                        AwesomeState.viewPrev(root.awScreen.index);
                    else
                        AwesomeState.viewNext(root.awScreen.index);
                }
            }
        }
    }
}
