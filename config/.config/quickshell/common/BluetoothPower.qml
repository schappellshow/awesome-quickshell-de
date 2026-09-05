pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

// Adapter power, with the rfkill step BlueZ won't do for you.
//
// `adapter.enabled = true` is a D-Bus write of Powered=true, and that write
// FAILS — silently, from QML's point of view — while rfkill soft-blocks the
// adapter. bluetoothd logs "Failed to set mode: Failed (0x03)" and the
// toggle springs back with no explanation. A block survives reboots
// (systemd-rfkill saves and restores it), so once you have blocked
// bluetooth once, every later attempt to turn it on from the shell does
// nothing until something runs `rfkill unblock`.
//
// Under Plasma that something is bluedevil. Nothing filled the role here,
// which is the whole of "bluetooth doesn't work under awesome".
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool present: adapter !== null
    readonly property bool enabled: present && adapter.enabled

    // Soft-blocked at the rfkill layer. Powering on has to clear this
    // first; the Settings toggle shows it so a blocked radio isn't just an
    // unresponsive switch.
    property bool blocked: false

    property bool restored: false

    function init() {
        probe();
        // The adapter can appear after the shell does (bluetooth.service
        // still starting, firmware still loading), so restore on arrival
        // rather than only right now.
        restore();
    }

    Connections {
        target: Bluetooth

        function onDefaultAdapterChanged() { root.probe(); root.restore(); }
    }

    // Put the adapter back the way it was left. Off by default in the
    // sense that it only ever reasserts a state the user themselves chose:
    // btPowered is written by setEnabled below, never guessed.
    function restore() {
        if (restored || !present || !Settings.btRestorePower)
            return;
        restored = true;
        if (Settings.btPowered && !adapter.enabled)
            setEnabled(true);
    }

    function setEnabled(on) {
        Settings.btPowered = on;
        if (!present)
            return;
        if (on)
            unblockProc.running = true;     // powers on when rfkill clears
        else
            adapter.enabled = false;
    }

    function toggle() {
        setEnabled(!enabled);
    }

    // rfkill unblock is a no-op when nothing is blocked, so this is safe to
    // run on every power-on rather than only when `blocked` says to — the
    // block state is read asynchronously and may be stale at the moment the
    // user clicks.
    Process {
        id: unblockProc
        command: ["rfkill", "unblock", "bluetooth"]
        onExited: (exitCode, exitStatus) => {
            if (root.present)
                root.adapter.enabled = true;
            root.probe();
        }
    }

    function probe() {
        if (!probeProc.running)
            probeProc.running = true;
    }

    Process {
        id: probeProc
        command: ["rfkill", "--noheadings", "--output", "TYPE,SOFT,HARD",
                  "list", "bluetooth"]
        stdout: StdioCollector {
            onStreamFinished: {
                // "bluetooth blocked unblocked" — soft is the second field.
                // No output at all means no bluetooth rfkill switch, which
                // is not the same as blocked.
                let soft = false;
                for (const line of text.split("\n")) {
                    const f = line.trim().split(/\s+/);
                    if (f.length >= 2 && f[1] === "blocked")
                        soft = true;
                }
                root.blocked = soft;
            }
        }
    }

    // rfkill state changes from outside the shell (a laptop radio key,
    // another session), and there is no D-Bus signal for it worth wiring
    // up — a slow poll while the panel might be open is enough.
    Timer {
        running: true
        repeat: true
        interval: 10000
        onTriggered: root.probe()
    }
}
