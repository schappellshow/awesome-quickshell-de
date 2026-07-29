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

    Column {
        id: col
        anchors.centerIn: parent
        spacing: 1

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "BT"
            font.family: Theme.fontFamily
            font.bold: true
            font.pointSize: 7
            color: Theme.muted
        }

        // fa-bluetooth-b rune (U+F294): blue when a device is connected,
        // gray when the adapter is on but idle, dim when off.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
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
