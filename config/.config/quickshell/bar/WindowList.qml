import QtQuick
import Quickshell
import "../common"

// Every window currently on screen, across all monitors, left to right.
//
// The counterpart to HiddenWindows: that one shows only what the layout
// cannot (minimized windows), this one shows only what it can. Together they
// account for every client.
//
// Ordering is done by the bridge, on absolute geometry, so this list is
// already in reading order and does not re-sort. That is what makes a window
// on the left-most monitor come first and a second terminal tiled beside
// something appear between its neighbours — see modules/quickshell.lua.
//
// Windows are NOT grouped by application: two browser windows on two
// monitors are two icons, in their two places, because the whole point is
// spatial. Grouping them would put one icon in neither place.
Grid {
    id: root

    property bool vertical: BarEdge.vertical

    readonly property var items: AwesomeState.clients || []

    columns: root.vertical ? 1 : 99
    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter

    spacing: 4
    visible: Settings.showWindowList && root.items.length > 0

    Repeater {
        model: root.items

        delegate: Rectangle {
            id: entry

            required property var modelData

            width: 24
            height: 24
            radius: 5

            // The focused window is the one you are typing into, so it gets
            // the accent the same way a selected tag does. Everything else
            // stays quiet — this section is a map, not a notification.
            color: entry.modelData.focused ? Theme.accent
                 : hover.hovered ? Theme.surface : "transparent"

            Behavior on color {
                ColorAnimation { duration: 100 }
            }

            AppIcon {
                anchors.centerIn: parent
                appClass: entry.modelData.class || ""
                appInstance: entry.modelData.instance || ""
                iconSize: 18
            }

            HoverHandler { id: hover }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouseEvent => {
                    if (mouseEvent.button === Qt.RightButton)
                        // Pin what is already running: the fast path, versus
                        // finding it again in the Settings list.
                        PinnedApps.pinFromWindow(entry.modelData);
                    else
                        AwesomeState.focusClient(entry.modelData.id);
                }
            }
        }
    }
}
