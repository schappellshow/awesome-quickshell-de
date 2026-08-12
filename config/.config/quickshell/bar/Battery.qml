import QtQuick
import Quickshell.Services.UPower
import "../common"

// CHG/BAT label over the percentage (beside it on a horizontal bar), hidden
// on machines without a battery
Grid {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool present: device && device.ready && device.isLaptopBattery
    readonly property int pct: present ? Math.round(device.percentage * 100) : 0
    readonly property bool charging: present && device.state === UPowerDeviceState.Charging

    visible: present && Settings.showBattery

    columns: BarEdge.vertical ? 1 : 99
    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter
    spacing: BarEdge.vertical ? 1 : 4

    Text {
        text: root.charging ? "CHG" : "BAT"
        font.family: Theme.labelFont
        font.bold: true
        font.pointSize: 7
        color: Theme.muted
    }

    Text {
        text: root.pct + "%"
        font.family: Theme.labelFont
        font.pointSize: 9
        color: root.pct <= 15 ? Theme.urgent
             : root.pct <= 30 ? Theme.gold
             : Theme.subtext
    }
}
