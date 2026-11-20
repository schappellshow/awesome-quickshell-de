import QtQuick
import Quickshell
import "../common"

// DRV: removable drives (USB sticks, SD cards, external disks). Takes no
// space unless at least one is plugged in. Left-click: the drives popup.
// Blue while something is mounted (it can be opened, and wants ejecting
// before it is pulled), gray when everything plugged in is unmounted.
Item {
    id: root

    property var barWindow
    property bool panelOpen: false

    readonly property bool anyMounted: Drives.list.some(d => d.mounted)

    visible: Settings.showDrives && Drives.any
    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    Grid {
        id: col
        anchors.centerIn: parent
        columns: BarEdge.vertical ? 1 : 99
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
        spacing: BarEdge.vertical ? 1 : 4

        Text {
            text: "DRV"
            font.family: Theme.labelFont
            font.bold: true
            font.pointSize: 7
            color: Theme.muted
        }

        // nf-fa-usb (U+F287), as an escape like the other glyphs
        Text {
            text: ""
            font.family: Theme.iconFont
            font.pointSize: 10
            color: root.anyMounted ? Theme.accentBright : Theme.subtext
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            root.panelOpen = !root.panelOpen;
            if (root.panelOpen) {
                Drives.error = "";
                Drives.refresh();
            }
        }
    }

    BarTip {
        barWindow: root.barWindow
        anchorItem: root
        hovered: mouse.containsMouse && root.visible && !root.panelOpen
        text: Drives.list.map(d => d.name).join("\n")
    }
}
