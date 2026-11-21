import QtQuick
import Quickshell
import "../common"
import "../common/Drives.js" as DrivesJs

// Removable-drives popup: one block per drive, one row per volume on it.
// Volumes can be opened in the default file manager, mounted or unmounted;
// the drive's own Eject unmounts everything on it and powers it off.
// All of it runs through common/Drives.qml, which keeps the error text.
PopupWindow {
    id: panel

    property var barWindow
    property Item anchorItem
    property bool shown: false

    // Emitted when the panel wants to close; the bar owns the open state
    signal dismiss()

    visible: shown
    color: "transparent"
    implicitWidth: 320
    implicitHeight: card.implicitHeight

    anchor.window: barWindow
    anchor.rect.x: BarEdge.popupX(panel.barWindow, panel.anchorItem,
                                  panel.implicitWidth)
    anchor.rect.y: BarEdge.popupY(panel.barWindow, panel.anchorItem,
                                  panel.implicitHeight)

    // Small flat button used throughout the popup
    component Chip: Rectangle {
        id: chip
        property string label
        property bool enabled: Drives.busy === ""
        signal clicked()

        implicitWidth: chipText.implicitWidth + 16
        implicitHeight: 22
        radius: 6
        opacity: enabled ? 1 : 0.5
        color: chipHover.hovered && enabled ? Theme.surfaceAlt : Theme.surface

        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.label
            font.family: Theme.fontFamily
            font.pointSize: 8
            color: Theme.text
        }
        HoverHandler { id: chipHover }
        MouseArea {
            anchors.fill: parent
            onClicked: if (chip.enabled) chip.clicked()
        }
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
                text: "REMOVABLE DRIVES"
                font.family: Theme.fontFamily
                font.bold: true
                font.pointSize: 8
                font.letterSpacing: 1.5
                color: Theme.accentBright
            }

            Repeater {
                model: Drives.list

                Column {
                    id: drive

                    required property var modelData

                    width: col.width
                    spacing: 6

                    Rectangle { width: parent.width; height: 1; color: Theme.surface }

                    Item {
                        width: parent.width
                        height: 22

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - ejectChip.width - 8
                            text: drive.modelData.name + "  "
                                + DrivesJs.humanSize(drive.modelData.size)
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.bold: true
                            font.pointSize: 9
                            color: Theme.text
                        }

                        Chip {
                            id: ejectChip
                            anchors.right: parent.right
                            label: "Eject"
                            onClicked: Drives.eject(drive.modelData)
                        }
                    }

                    Text {
                        visible: drive.modelData.volumes.length === 0
                        text: "Nothing to mount on this drive"
                        font.family: Theme.fontFamily
                        font.pointSize: 8
                        color: Theme.muted
                    }

                    Repeater {
                        model: drive.modelData.volumes

                        Column {
                            id: vol

                            required property var modelData

                            width: drive.width
                            spacing: 3

                            Text {
                                width: parent.width
                                text: (vol.modelData.label || vol.modelData.fstype || "Volume")
                                    + "  ·  " + DrivesJs.humanSize(vol.modelData.size)
                                    + (vol.modelData.fstype ? "  ·  " + vol.modelData.fstype : "")
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pointSize: 9
                                color: vol.modelData.mounted ? Theme.text : Theme.subtext
                            }

                            Text {
                                visible: vol.modelData.mounted
                                width: parent.width
                                text: vol.modelData.used >= 0
                                    ? DrivesJs.humanSize(vol.modelData.used) + " used, "
                                      + DrivesJs.humanSize(vol.modelData.avail) + " free"
                                    : "Usage unknown"
                                font.family: Theme.fontFamily
                                font.pointSize: 8
                                color: Theme.muted
                            }

                            Text {
                                visible: vol.modelData.mounted
                                width: parent.width
                                text: vol.modelData.mountpoint
                                elide: Text.ElideMiddle
                                font.family: Theme.fontFamily
                                font.pointSize: 8
                                color: Theme.muted
                            }

                            Text {
                                visible: !vol.modelData.mounted
                                text: "Not mounted"
                                font.family: Theme.fontFamily
                                font.pointSize: 8
                                color: Theme.muted
                            }

                            Row {
                                spacing: 6

                                Chip {
                                    visible: vol.modelData.mounted
                                    label: "Open"
                                    onClicked: {
                                        Drives.openVolume(vol.modelData);
                                        panel.dismiss();
                                    }
                                }
                                Chip {
                                    visible: !vol.modelData.mounted
                                    label: "Mount"
                                    onClicked: Drives.mount(vol.modelData)
                                }
                                Chip {
                                    visible: vol.modelData.mounted
                                    label: "Unmount"
                                    onClicked: Drives.unmount(vol.modelData)
                                }
                            }
                        }
                    }
                }
            }

            Text {
                visible: Drives.busy !== ""
                text: Drives.busy + "…"
                font.family: Theme.fontFamily
                font.pointSize: 8
                color: Theme.muted
            }

            // The reason an action failed, in words
            Text {
                visible: Drives.error !== ""
                width: parent.width
                text: Drives.error
                wrapMode: Text.Wrap
                font.family: Theme.fontFamily
                font.pointSize: 8
                color: Theme.urgent
            }
        }
    }
}
