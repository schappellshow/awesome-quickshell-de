import QtQuick
import Quickshell
import "../common"

// Stacked 12-hour clock: hours / minutes / AM-PM
Column {
    spacing: 1

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    readonly property int hours12: (clock.hours % 12) === 0 ? 12 : clock.hours % 12

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: String(parent.hours12).padStart(2, "0")
        font.family: Theme.fontFamily
        font.bold: true
        font.pointSize: 13
        color: Theme.text
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: String(clock.minutes).padStart(2, "0")
        font.family: Theme.fontFamily
        font.pointSize: 11
        color: Theme.subtext
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: clock.hours < 12 ? "AM" : "PM"
        font.family: Theme.fontFamily
        font.pointSize: 7
        color: Theme.muted
    }
}
