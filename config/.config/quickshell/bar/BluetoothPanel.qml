import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "../common"

// Bluetooth popup: adapter power toggle and paired devices (click to
// connect/disconnect). Pairing new devices is delegated to blueman-manager.
PopupWindow {
    id: panel

    property var barWindow
    property Item anchorItem
    property bool shown: false

    // Emitted when the panel wants to close; the bar owns the open state
    signal dismiss()

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var pairedDevices:
        Bluetooth.devices.values.filter(d => d.paired || d.bonded)

    visible: shown
    color: "transparent"
    implicitWidth: 250
    implicitHeight: card.implicitHeight

    anchor.window: barWindow
    anchor.rect.x: barWindow ? barWindow.implicitWidth + 6 : 42
    anchor.rect.y: {
        if (!anchorItem)
            return 100;
        const p = anchorItem.mapToItem(null, 0, anchorItem.height / 2);
        return Math.max(8, p.y - panel.implicitHeight / 2);
    }

    Rectangle {
        id: card

        width: parent.width
        implicitHeight: col.implicitHeight + 28
        radius: Theme.radius
        color: Theme.base
        border.color: Theme.accentBright
        border.width: 2

        Column {
            id: col

            x: 14
            y: 14
            width: parent.width - 28
            spacing: 10

            Text {
                text: "BLUETOOTH"
                font.family: Theme.fontFamily
                font.bold: true
                font.pointSize: 8
                font.letterSpacing: 1.5
                color: Theme.accentBright
            }

            // Adapter power toggle
            Item {
                width: parent.width
                height: 24

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Enabled"
                    font.family: Theme.fontFamily
                    font.pointSize: 10
                    color: Theme.text
                }

                Rectangle {
                    id: btTrack
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    height: 22
                    radius: 11
                    color: panel.adapter && panel.adapter.enabled
                        ? Theme.accent : Theme.surface

                    Rectangle {
                        width: 16
                        height: 16
                        radius: 8
                        y: 3
                        x: panel.adapter && panel.adapter.enabled
                            ? btTrack.width - width - 3 : 3
                        color: Theme.text
                        Behavior on x {
                            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (panel.adapter)
                            panel.adapter.enabled = !panel.adapter.enabled;
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.surface }

            Text {
                visible: panel.pairedDevices.length === 0
                text: "No paired devices"
                font.family: Theme.fontFamily
                font.pointSize: 9
                color: Theme.muted
            }

            Repeater {
                model: panel.pairedDevices

                Item {
                    id: row

                    required property var modelData

                    width: col.width
                    height: 22

                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        anchors.verticalCenter: parent.verticalCenter
                        color: row.modelData.connected ? Theme.green : Theme.surface
                    }

                    Text {
                        x: 16
                        width: parent.width - 16
                            - (battery.visible ? battery.implicitWidth + 4 : 0)
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.name
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pointSize: 9
                        color: row.modelData.connected ? Theme.text : Theme.subtext
                    }

                    Text {
                        id: battery
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: row.modelData.connected && row.modelData.batteryAvailable
                        text: Math.round(row.modelData.battery * 100) + "%"
                        font.family: Theme.fontFamily
                        font.pointSize: 8
                        color: Theme.muted
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (row.modelData.connected)
                                row.modelData.disconnect();
                            else
                                row.modelData.connect();
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 26
                radius: 6
                color: mgrHover.hovered ? Theme.surfaceAlt : Theme.surface

                Text {
                    anchors.centerIn: parent
                    text: "Pair new device…"
                    font.family: Theme.fontFamily
                    font.pointSize: 9
                    color: Theme.text
                }

                HoverHandler { id: mgrHover }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        Quickshell.execDetached(["blueman-manager"]);
                        panel.dismiss();
                    }
                }
            }
        }
    }
}
