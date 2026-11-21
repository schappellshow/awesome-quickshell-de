import QtQuick
import Quickshell
import "../common"

// PRF: shown only while performance mode is on, and takes no space
// otherwise. Looks like its neighbours (NGT, SCN): small label over a glyph.
// Hover says why it is on; click turns it off by the same path as the key
// (Super+Alt+G) and `qs ipc call perf off`.
Item {
    id: root

    property var barWindow

    visible: Settings.showPerfIndicator && PerformanceMode.active

    implicitWidth: stack.implicitWidth
    implicitHeight: stack.implicitHeight

    // "On" colour per the bar convention (accent blue)
    readonly property color col: Theme.accentBright

    Grid {
        id: stack
        anchors.centerIn: parent
        columns: BarEdge.vertical ? 1 : 99
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
        spacing: BarEdge.vertical ? 1 : 4

        Text {
            text: "PRF"
            font.family: Theme.labelFont
            font.bold: true
            font.pointSize: 7
            color: Theme.muted
        }

        // nf-fa-bolt (U+F0E7), written as an escape like the other glyphs
        Text {
            text: ""
            font.family: Theme.iconFont
            font.pointSize: 10
            color: mouse.containsMouse ? Theme.text : root.col
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: PerformanceMode.set(false)
    }

    BarTip {
        barWindow: root.barWindow
        anchorItem: root
        hovered: mouse.containsMouse && root.visible
        text: (PerformanceMode.reason === "game"
                ? "Performance mode: on automatically, a game is running"
                : "Performance mode: on, turned on by hand")
            + "\nClick to turn it off"
    }
}
