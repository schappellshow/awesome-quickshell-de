import QtQuick
import "../common"

// Awesome taglist. Left-click: view tag; right-click: toggle tag into view;
// scroll: next/prev tag (down = next, matching the vertical list).
//
// Every monitor's section renders identically — same pill size, and only
// tags that are selected, occupied or urgent. An empty tag isn't drawn at
// all: its absence is the information (nothing is running there), and the
// tags are reached by keybind rather than by clicking a fixed position.
Grid {
    id: root

    property var awScreen
    property bool vertical: true

    rows: root.vertical ? 0 : 1
    columns: root.vertical ? 1 : 0
    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter

    // Gap between entries. Has to stay comfortably larger than the 2px
    // inside each entry, or an underline reads as belonging to the pill
    // below it rather than its own.
    spacing: 6

    Repeater {
        model: {
            const tags = root.awScreen ? root.awScreen.tags : [];
            return tags.filter(t => t.selected || t.occupied || t.urgent);
        }

        // Pill plus its underline. Wrapping them means the underline can sit
        // outside the pill without being clipped by the rounded silhouette,
        // and the number goes back to being genuinely centred.
        delegate: Column {
            id: entry

            required property var modelData

            // Pill over underline in either orientation: the marker belongs
            // to the tag above it, not to the direction of the bar.
            spacing: 2

            Rectangle {
                id: tagPill

                width: 16
                height: 18
                anchors.horizontalCenter: parent.horizontalCenter
                radius: width / 2
                color: entry.modelData.urgent   ? Theme.urgent
                     : entry.modelData.selected ? Theme.accent
                     : entry.modelData.occupied ? Theme.surface
                     : "transparent"

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Theme.accent
                    opacity: mouse.containsMouse && !entry.modelData.selected ? 0.33 : 0
                }

                Text {
                    anchors.centerIn: parent
                    text: entry.modelData.name
                    font.family: Theme.labelFont
                    font.bold: true
                    font.pointSize: 7
                    color: entry.modelData.urgent   ? Theme.text
                         : entry.modelData.selected ? Theme.text
                         : entry.modelData.occupied ? Theme.subtext
                         : Theme.muted
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouseEvent => {
                        if (mouseEvent.button === Qt.RightButton)
                            AwesomeState.toggleTag(root.awScreen.index, entry.modelData.index);
                        else
                            AwesomeState.viewTag(root.awScreen.index, entry.modelData.index);
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

            // "Something is minimized on this tag." Occupancy is already the
            // pill's fill colour, so hidden-ness needs its own channel —
            // gold reads against the selected, urgent and occupied fills
            // alike, and is not otherwise used in the taglist.
            //
            // Always present, only the colour changes: reserving the space
            // unconditionally is what keeps the pills from shifting as
            // windows are minimized and restored.
            Rectangle {
                width: 10
                height: 2
                radius: 1
                anchors.horizontalCenter: parent.horizontalCenter
                color: (entry.modelData.minimized || 0) > 0
                    ? Theme.gold : "transparent"
            }
        }
    }
}
