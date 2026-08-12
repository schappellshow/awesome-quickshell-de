import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "../common"

// BT indicator, hidden when no adapter exists. "off" / "on" / connected
// count. Left-click: bluetooth popup. Right-click: blueman-manager.
Item {
    id: root

    property bool panelOpen: false

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var connectedDevices:
        Bluetooth.devices.values.filter(d => d.connected)

    visible: adapter !== null && Settings.showBluetooth
    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    // Label over value on a vertical bar, label beside it on a horizontal
    // one — a two-line stack is taller than a horizontal bar is thick.
    Grid {
        id: col
        anchors.centerIn: parent
        columns: BarEdge.vertical ? 1 : 99
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
        spacing: BarEdge.vertical ? 1 : 4

        Text {
            text: "BT"
            font.family: Theme.labelFont
            font.bold: true
            font.pointSize: 7
            color: Theme.muted
        }

        // fa-bluetooth-b rune (U+F294): blue when a device is connected,
        // gray when the adapter is on but idle, dim when off.
        Text {
            text: String.fromCodePoint(0xf294)
            font.family: Theme.iconFont
            font.pointSize: 10
            color: !root.adapter || !root.adapter.enabled ? Theme.muted
                 : root.connectedDevices.length > 0
                     ? Theme.accentBright : Theme.subtext
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouseEvent => {
            if (mouseEvent.button === Qt.RightButton)
                Quickshell.execDetached(["blueman-manager"]);
            else
                root.panelOpen = !root.panelOpen;
        }
    }
}
