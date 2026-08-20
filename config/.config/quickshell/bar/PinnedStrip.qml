import QtQuick
import Quickshell
import "../common"

// Pinned application launchers.
//
// Unlike the window list beside it, this is deliberately static: it shows
// what you put there, in the order you put it, whether or not anything is
// running. That makes it the launcher half of a KDE/GNOME-style bar, with
// the window list as the task half.
//
// A pinned app that IS running is not specially marked. The window list
// already shows every running window, in its real position, so an indicator
// here would be saying the same thing in a place that cannot be spatially
// honest about it.
Grid {
    id: root

    property bool vertical: BarEdge.vertical

    readonly property var items: PinnedApps.ids

    columns: root.vertical ? 1 : 99
    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter

    spacing: 4
    visible: Settings.showPinned && root.items.length > 0

    Repeater {
        model: root.items

        delegate: Rectangle {
            id: entry

            required property var modelData

            width: 24
            height: 24
            radius: 5
            color: hover.hovered ? Theme.surface : "transparent"

            Behavior on color {
                ColorAnimation { duration: 100 }
            }

            AppIcon {
                anchors.centerIn: parent
                entryId: entry.modelData
                iconSize: 18
            }

            HoverHandler { id: hover }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouseEvent => {
                    if (mouseEvent.button === Qt.RightButton)
                        PinnedApps.unpin(entry.modelData);
                    else
                        AppLookup.launch(entry.modelData);
                }
            }
        }
    }
}
