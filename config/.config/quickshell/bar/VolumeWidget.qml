import QtQuick
import Quickshell
import "../common"

// VOL indicator: scroll to adjust, click to mute, right-click for the
// pavucontrol-qt mixer. Shares Audio.qml with the hotkey OSD path.
Item {
    id: root

    visible: Settings.showVolume
    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    Column {
        id: col
        anchors.centerIn: parent
        spacing: 1

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Audio.muted ? "MUT" : "VOL"
            font.family: Theme.fontFamily
            font.bold: true
            font.pointSize: 7
            color: Audio.muted ? Theme.urgent : Theme.muted
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Math.round(Audio.volume * 100) + "%"
            font.family: Theme.fontFamily
            font.pointSize: 9
            color: Audio.muted ? Theme.muted : Theme.subtext
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouseEvent => {
            if (mouseEvent.button === Qt.RightButton)
                Quickshell.execDetached(["pavucontrol-qt"]);
            else
                Audio.toggleMute();
        }
        onWheel: wheelEvent => {
            if (wheelEvent.angleDelta.y > 0)
                Audio.raise();
            else
                Audio.lower();
        }
    }
}
