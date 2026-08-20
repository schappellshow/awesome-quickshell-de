import QtQuick
import Quickshell
import "../common"

// Minimized windows on the tag(s) this screen is currently viewing.
//
// The inverse of a tasklist: it deliberately does NOT show running windows,
// because the tiling layout already does. It shows only what the layout
// can't — the windows you hid and would otherwise have no trace of. So it
// is empty, and takes no space, in the normal case.
//
// Click an icon to restore that specific window (awesome's Super+Ctrl+N can
// only pop the most recently minimized one).
Grid {
    id: root

    property var awScreen
    property bool vertical: BarEdge.vertical

    readonly property var items: root.awScreen ? (root.awScreen.hidden || []) : []

    columns: root.vertical ? 1 : 99
    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter

    spacing: 4
    visible: root.items.length > 0

    Repeater {
        model: root.items

        delegate: Rectangle {
            id: entry

            required property var modelData

            width: 20
            height: 20
            radius: 5
            // Dimmed at rest: these windows are hidden, and shouldn't pull
            // attention the way the taglist or an urgent tag does.
            color: hover.hovered ? Theme.surface : "transparent"
            opacity: hover.hovered ? 1.0 : 0.75

            Behavior on opacity {
                NumberAnimation { duration: 100 }
            }

            // WM_CLASS -> desktop entry -> icon, shared with the visible
            // window list and the pinned launchers (see AppIcon.qml).
            AppIcon {
                anchors.centerIn: parent
                appClass: entry.modelData.class || ""
                appInstance: entry.modelData.instance || ""
                iconSize: 16
            }

            HoverHandler { id: hover }

            MouseArea {
                anchors.fill: parent
                onClicked: AwesomeState.restoreClient(entry.modelData.id)
            }
        }
    }
}
