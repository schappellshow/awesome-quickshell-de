import QtQuick
import Quickshell.Services.UPower
import "../common"

// CHG/BAT label over percentage, hidden on machines without a battery
Column {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool present: device && device.ready && device.isLaptopBattery
    readonly property int pct: present ? Math.round(device.percentage * 100) : 0
    readonly property bool charging: present && device.state === UPowerDeviceState.Charging

    visible: present && Settings.showBattery
    spacing: 1

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.charging ? "CHG" : "BAT"
        font.family: Theme.fontFamily
        font.bold: true
        font.pointSize: 7
        color: Theme.muted
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.pct + "%"
        font.family: Theme.fontFamily
        font.pointSize: 9
        color: root.pct <= 15 ? Theme.urgent
             : root.pct <= 30 ? Theme.gold
             : Theme.subtext
    }
}
