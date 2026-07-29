pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Low-battery safety net: warn at 15%, suspend at 5% while discharging.
// Flags reset when power is plugged in, so resuming still-critical gives a
// window to reach a charger instead of suspend-looping.
Singleton {
    id: root

    // Referenced from shell.qml's Component.onCompleted to force
    // instantiation (singletons are lazy).
    function init() {}

    readonly property var device: UPower.displayDevice
    readonly property bool onBattery: device && device.ready
        && device.isLaptopBattery
        && device.state === UPowerDeviceState.Discharging
    readonly property int pct: device && device.ready
        ? Math.round(device.percentage * 100) : 100

    property bool warnedLow: false
    property bool handledCritical: false

    onPctChanged: evaluate()
    onOnBatteryChanged: {
        if (!onBattery) {
            warnedLow = false;
            handledCritical = false;
        }
        evaluate();
    }

    function evaluate() {
        if (!onBattery)
            return;
        if (pct <= Settings.batteryCriticalPct && !handledCritical) {
            handledCritical = true;
            Quickshell.execDetached(["notify-send", "-u", "critical",
                "Battery critical", "Suspending now (" + pct + "%)"]);
            Quickshell.execDetached(["systemctl", "suspend"]);
        } else if (pct <= Settings.batteryWarnPct && !warnedLow) {
            warnedLow = true;
            Quickshell.execDetached(["notify-send", "-u", "critical",
                "Battery low", pct + "% remaining — plug in soon"]);
        }
    }
}
