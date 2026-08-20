import QtQuick
import Quickshell
import "../common"

// An application's icon, resolved from its WM_CLASS or desktop entry id.
//
// A thin renderer over AppLookup, which owns the resolution rules. Shared by
// the hidden-window list, the visible-window list and the pinned launchers:
// getting the lookup right is most of the work in any of them, and three
// copies would drift apart.
Item {
    id: root

    // From a window: both halves of WM_CLASS. Either may be empty.
    property string appClass: ""
    property string appInstance: ""

    // From a pinned app: a desktop entry id, tried ahead of the class pair.
    property string entryId: ""

    property int iconSize: 16

    implicitWidth: root.iconSize
    implicitHeight: root.iconSize

    readonly property var names: [root.entryId, root.appClass, root.appInstance]

    // True once something actually rendered, so callers can style the
    // degraded case differently if they want to.
    readonly property bool resolved: icon.status === Image.Ready

    readonly property string displayName: AppLookup.nameFor(root.names)

    Image {
        id: icon
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        source: AppLookup.iconFor(root.names)
        sourceSize.width: root.iconSize * 2
        sourceSize.height: root.iconSize * 2
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        visible: status === Image.Ready
    }

    // Degraded fallback when nothing resolved: the app's initial. Uses the
    // last dotted segment, so com.teamviewer.TeamViewer gives "T" rather
    // than a useless "C".
    Text {
        anchors.centerIn: parent
        visible: !root.resolved
        text: root.displayName === ""
            ? "?" : root.displayName.charAt(0).toUpperCase()
        font.family: Theme.labelFont
        font.bold: true
        font.pointSize: Math.max(6, root.iconSize / 2)
        color: Theme.subtext
    }
}
