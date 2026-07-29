import QtQuick
import Quickshell
import "../common"

// SYS pill: CPU and RAM percentages. Left-click (or Super+Shift+M) toggles
// the conky dashboard; right-click opens htop in a terminal.
Item {
    id: root

    visible: Settings.showSysMon
    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    function pctColor(p) {
        return p >= 90 ? Theme.urgent
             : p >= 70 ? Theme.gold
             : Theme.subtext;
    }

    Column {
        id: col
        anchors.centerIn: parent
        spacing: 1

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "CPU"
            font.family: Theme.fontFamily
            font.bold: true
            font.pointSize: 7
            // Accent hints that the conky dashboard is open
            color: SysMon.conkyRunning ? Theme.accentBright : Theme.muted
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: SysMon.cpuPct + "%"
            font.family: Theme.fontFamily
            font.pointSize: 9
            color: root.pctColor(SysMon.cpuPct)
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "RAM"
            font.family: Theme.fontFamily
            font.bold: true
            font.pointSize: 7
            color: SysMon.conkyRunning ? Theme.accentBright : Theme.muted
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: SysMon.memPct + "%"
            font.family: Theme.fontFamily
            font.pointSize: 9
            color: root.pctColor(SysMon.memPct)
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouseEvent => {
            if (mouseEvent.button === Qt.RightButton)
                Quickshell.execDetached(["sh", "-c",
                    "command -v ghostty >/dev/null && ghostty -e htop || " +
                    "kitty htop || xterm -e htop"]);
            else
                SysMon.toggleConky();
        }
    }
}
