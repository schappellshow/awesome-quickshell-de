import QtQuick
import Quickshell
import "../common"

// Network popup: status, wifi radio toggle, saved connections (click to
// connect/disconnect), and an escape hatch to nm-connection-editor.
PopupWindow {
    id: panel

    property var barWindow
    property Item anchorItem
    property bool shown: false

    // Emitted when the panel wants to close; the bar owns the open state
    signal dismiss()

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
                text: "NETWORK"
                font.family: Theme.fontFamily
                font.bold: true
                font.pointSize: 8
                font.letterSpacing: 1.5
                color: Theme.accentBright
            }

            Text {
                width: parent.width
                text: !Network.connected ? "Disconnected"
                    : Network.type === "wifi"
                        ? Network.ssid + "  (" + Network.signalStrength + "%)"
                        : Network.connectionName
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.bold: true
                font.pointSize: 10
                color: Network.connected ? Theme.text : Theme.urgent
            }

            // Wi-Fi radio toggle
            Item {
                width: parent.width
                height: 24

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Wi-Fi"
                    font.family: Theme.fontFamily
                    font.pointSize: 10
                    color: Theme.text
                }

                Rectangle {
                    id: wifiTrack
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    height: 22
                    radius: 11
                    color: Network.wifiEnabled ? Theme.accent : Theme.surface

                    Rectangle {
                        width: 16
                        height: 16
                        radius: 8
                        y: 3
                        x: Network.wifiEnabled ? wifiTrack.width - width - 3 : 3
                        color: Theme.text
                        Behavior on x {
                            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Network.toggleWifi()
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.surface }

            // Saved connections
            Repeater {
                model: Network.savedConnections

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
                        color: row.modelData.active ? Theme.green : Theme.surface
                    }

                    Text {
                        x: 16
                        width: parent.width - 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.name
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pointSize: 9
                        color: row.modelData.active ? Theme.text : Theme.subtext
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (row.modelData.active)
                                Network.deactivate(row.modelData.name);
                            else
                                Network.activate(row.modelData.name);
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 26
                radius: 6
                color: editHover.hovered ? Theme.surfaceAlt : Theme.surface

                Text {
                    anchors.centerIn: parent
                    text: "Edit connections…"
                    font.family: Theme.fontFamily
                    font.pointSize: 9
                    color: Theme.text
                }

                HoverHandler { id: editHover }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        Quickshell.execDetached(["nm-connection-editor"]);
                        panel.dismiss();
                    }
                }
            }
        }
    }
}
