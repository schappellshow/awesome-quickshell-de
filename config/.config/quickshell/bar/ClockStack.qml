import QtQuick
import Quickshell
import "../common"

// 12-hour clock. Stacked hours / minutes / AM-PM on a vertical bar, where
// there is height to spare and no width; laid out along one line on a
// horizontal bar, where a three-line stack would be taller than the bar.
Item {
    id: root

    property bool vertical: true

    readonly property int hours12: (clock.hours % 12) === 0 ? 12 : clock.hours % 12
    readonly property string hh: String(root.hours12).padStart(2, "0")
    readonly property string mm: String(clock.minutes).padStart(2, "0")
    readonly property string meridiem: clock.hours < 12 ? "AM" : "PM"

    implicitWidth: (root.vertical ? stack : line).implicitWidth
    implicitHeight: (root.vertical ? stack : line).implicitHeight

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Column {
        id: stack
        visible: root.vertical
        anchors.centerIn: parent
        spacing: 1

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.hh
            font.family: Theme.clockFont
            font.bold: true
            font.pointSize: 13
            color: Theme.text
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.mm
            font.family: Theme.clockFont
            font.pointSize: 11
            color: Theme.subtext
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.meridiem
            font.family: Theme.clockFont
            font.pointSize: 7
            color: Theme.muted
        }
    }

    // Horizontal form. The hour keeps its weight and the minutes their
    // lighter tone, so the two forms read as the same clock — the stack
    // simply lies down.
    Row {
        id: line
        visible: !root.vertical
        anchors.centerIn: parent
        spacing: 3

        // The two big texts set the row's height between them; only the
        // small meridiem needs centring against it, which is also why it is
        // the only one that may carry a vertical anchor here.
        Text {
            text: root.hh + ":"
            font.family: Theme.clockFont
            font.bold: true
            font.pointSize: 12
            color: Theme.text
        }

        Text {
            text: root.mm
            font.family: Theme.clockFont
            font.pointSize: 12
            color: Theme.subtext
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.meridiem
            font.family: Theme.clockFont
            font.pointSize: 7
            color: Theme.muted
        }
    }
}
