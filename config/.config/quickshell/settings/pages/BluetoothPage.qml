import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "../components"
import "../../common"

SettingsPage {
    id: page

    title: "Bluetooth"

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var pairedDevices:
        Bluetooth.devices.values.filter(d => d.paired || d.bonded)

    SectionLabel { text: "ADAPTER" }

    InfoRow {
        visible: page.adapter === null
        label: "State"
        value: "No bluetooth adapter found"
    }

    ToggleRow {
        visible: page.adapter !== null
        label: "Enabled"
        checked: page.adapter !== null && page.adapter.enabled
        onToggled: value => {
            if (page.adapter)
                page.adapter.enabled = value;
        }
    }

    ToggleRow {
        visible: page.adapter !== null
        label: "Discoverable"
        checked: page.adapter !== null && page.adapter.discoverable
        onToggled: value => {
            if (page.adapter)
                page.adapter.discoverable = value;
        }
    }

    SectionLabel { text: "PAIRED DEVICES" }

    Text {
        visible: page.pairedDevices.length === 0
        text: "No paired devices"
        font.family: Theme.fontFamily
        font.pointSize: 9
        color: Theme.muted
    }

    Repeater {
        model: page.pairedDevices

        Item {
            id: row

            required property var modelData

            width: parent.width
            height: 26

            Rectangle {
                width: 8
                height: 8
                radius: 4
                anchors.verticalCenter: parent.verticalCenter
                color: row.modelData.connected ? Theme.green : Theme.surface
            }

            Text {
                x: 16
                width: parent.width - 160
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.name
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pointSize: 9
                color: row.modelData.connected ? Theme.text : Theme.subtext
            }

            Text {
                anchors.right: connectBtn.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                visible: row.modelData.connected && row.modelData.batteryAvailable
                text: Math.round(row.modelData.battery * 100) + "%"
                font.family: Theme.fontFamily
                font.pointSize: 8
                color: Theme.muted
            }

            Rectangle {
                id: connectBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: btnLabel.implicitWidth + 16
                height: 22
                radius: 7
                color: btnHover.hovered ? Theme.accent : Theme.surface

                Text {
                    id: btnLabel
                    anchors.centerIn: parent
                    text: row.modelData.connected ? "Disconnect" : "Connect"
                    font.family: Theme.fontFamily
                    font.pointSize: 8
                    color: Theme.text
                }

                HoverHandler { id: btnHover }

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
    }

    ButtonRow {
        label: "Pair a new device"
        buttonText: "Open blueman…"
        onClicked: Quickshell.execDetached(["blueman-manager"])
    }
}
