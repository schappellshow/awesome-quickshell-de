import QtQuick
import Quickshell
import "../common"

// Volume/brightness on-screen display: a small pill bottom-center of every
// screen, shown by the audio/brightness IPC handlers in shell.qml and
// auto-hidden shortly after the last change.
Scope {
    id: root

    property string mode: "volume"
    property bool shown: false

    readonly property real level: mode === "volume"
        ? Audio.volume
        : Brightness.percent / 100
    readonly property string label: mode === "volume"
        ? (Audio.muted ? "MUTE" : "VOL")
        : "BRI"

    function showVolume() { pop("volume"); }
    function showBrightness() { pop("brightness"); }

    function pop(newMode) {
        mode = newMode;
        shown = true;
        hideTimer.restart();
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.shown = false
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData

            screen: modelData
            visible: root.shown
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true

            anchors.bottom: true
            margins.bottom: 48
            implicitWidth: 280
            implicitHeight: 48

            Rectangle {
                anchors.fill: parent
                radius: Theme.radius
                color: Theme.base
                border.width: 1
                border.color: Theme.surface

                Row {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.label
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.pointSize: 9
                        color: root.mode === "volume" && Audio.muted
                            ? Theme.urgent : Theme.accentBright
                    }

                    Item {
                        width: 150
                        height: 6
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: 3
                            color: Theme.surface
                        }

                        Rectangle {
                            width: Math.max(0, Math.min(1, root.level)) * parent.width
                            height: parent.height
                            radius: 3
                            color: root.mode === "volume" && Audio.muted
                                ? Theme.muted : Theme.accent
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(root.level * 100) + "%"
                        font.family: Theme.fontFamily
                        font.pointSize: 9
                        color: Theme.subtext
                    }
                }
            }
        }
    }
}
