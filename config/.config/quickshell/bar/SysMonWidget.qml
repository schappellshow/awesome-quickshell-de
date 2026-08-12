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
            text: "CPU"
            font.family: Theme.labelFont
            font.bold: true
            font.pointSize: 7
            // Accent hints that the conky dashboard is open
            color: SysMon.conkyRunning ? Theme.accentBright : Theme.muted
        }

        Text {
            text: SysMon.cpuPct + "%"
            font.family: Theme.labelFont
            font.pointSize: 9
            color: root.pctColor(SysMon.cpuPct)
        }

        Text {
            text: "RAM"
            font.family: Theme.labelFont
            font.bold: true
            font.pointSize: 7
            color: SysMon.conkyRunning ? Theme.accentBright : Theme.muted
        }

        Text {
            text: SysMon.memPct + "%"
            font.family: Theme.labelFont
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
