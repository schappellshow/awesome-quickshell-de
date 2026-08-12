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
            text: Audio.muted ? "MUT" : "VOL"
            font.family: Theme.labelFont
            font.bold: true
            font.pointSize: 7
            color: Audio.muted ? Theme.urgent : Theme.muted
        }

        Text {
            text: Math.round(Audio.volume * 100) + "%"
            font.family: Theme.labelFont
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
