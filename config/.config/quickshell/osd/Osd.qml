import QtQuick
import Quickshell
import "../common"

// Volume/brightness on-screen display: a small pill bottom-center of every
// screen, shown by the audio/brightness IPC handlers in shell.qml and
// auto-hidden shortly after the last change.
Scope {
    id: root

    // "volume", "brightness" or "text". Text shows `message` in place of the
    // level bar — `qs ipc call osd text "..."`, for anything that wants to
    // say a short thing without a notification (performance mode, ...).
    property string mode: "volume"
    property string message: ""
    property bool shown: false

    readonly property real level: mode === "volume"
        ? Audio.volume
        : Brightness.percent / 100
    readonly property string label: mode === "volume"
        ? (Audio.muted ? "MUTE" : "VOL")
        : "BRI"

    function showVolume() { pop("volume"); }
    function showBrightness() { pop("brightness"); }
    function showText(msg) {
        message = msg;
        pop("text");
    }

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
            id: win
            required property var modelData

            screen: modelData
            visible: root.shown
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true

            anchors.bottom: true
            margins.bottom: 48
            // The level pill is a fixed width so it does not jump between
            // 9% and 100%; a message is as wide as it needs to be.
            implicitWidth: root.mode === "text"
                ? Math.max(280, Math.min(win.screen.width - 80, msgMetrics.width + 48))
                : 280
            implicitHeight: 48

            Rectangle {
                anchors.fill: parent
                radius: Theme.radius
                color: Theme.base
                border.width: 1
                border.color: Theme.surface

                TextMetrics {
                    id: msgMetrics
                    text: root.message
                    font.family: Theme.fontFamily
                    font.pointSize: 10
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 32
                    visible: root.mode === "text"
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: root.message
                    font.family: Theme.fontFamily
                    font.pointSize: 10
                    color: Theme.text
                }

                Row {
                    visible: root.mode !== "text"
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
