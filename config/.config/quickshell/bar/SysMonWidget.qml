import QtQuick
import Quickshell
import "../common"

// SYS pill: CPU and RAM percentages. Left-click (or Super+Shift+M) toggles
// the dashboard (native or conky, per Settings); right-click opens htop in a terminal.
Item {
    id: root

    // "busy" mode: each figure is there only while SysMon says it is high.
    readonly property bool always: Settings.sysmonMode === "always"
    readonly property bool showCpu: always || SysMon.cpuBusy
    readonly property bool showRam: always || SysMon.memBusy

    visible: Settings.showSysMon && (showCpu || showRam)
    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    // In "busy" mode a visible figure is by definition a warning, so it is
    // never the quiet subtext colour.
    function pctColor(p) {
        return p >= 90 ? Theme.urgent
             : (p >= 70 || !root.always) ? Theme.gold
             : Theme.subtext;
    }

    // Accent hints that the conky dashboard is open; a warning shows its
    // label in the warning colour too.
    readonly property color labelColor: (SysMon.conkyRunning || DashboardState.above) ? Theme.accentBright
                                       : root.always ? Theme.muted : Theme.gold

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
            visible: root.showCpu
            text: "CPU"
            font.family: Theme.labelFont
            font.bold: true
            font.pointSize: 7
            color: root.labelColor
        }

        Text {
            visible: root.showCpu
            text: SysMon.cpuPct + "%"
            font.family: Theme.labelFont
            font.pointSize: 9
            color: root.pctColor(SysMon.cpuPct)
        }

        Text {
            visible: root.showRam
            text: "RAM"
            font.family: Theme.labelFont
            font.bold: true
            font.pointSize: 7
            color: root.labelColor
        }

        Text {
            visible: root.showRam
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
                SysMon.toggleDashboard();
        }
    }
}
